#!/usr/bin/env bash
set -Eeuo pipefail

# Operator helper for the shared SimpleArt/Cachet OVHcloud VPS.
# Install as /opt/cachet/cachetctl and run as root. It never prints env values.

COMPOSE_FILE="${CACHET_COMPOSE_FILE:-/opt/cachet/compose.yml}"
DEPLOY_ENV="${CACHET_DEPLOY_ENV:-/opt/cachet/deploy.env}"
RUNTIME_ENV="${CACHET_RUNTIME_ENV:-/opt/cachet/.env}"
BACKUP_ROOT="${CACHET_BACKUP_ROOT:-/var/backups/cachet}"
PUBLIC_URL="${CACHET_PUBLIC_URL:-https://api.cachetprotocol.xyz}"
PROJECT_NAME="cachet"
HEALTH_TIMEOUT_SECONDS="${CACHET_HEALTH_TIMEOUT_SECONDS:-120}"

log() {
  printf '[cachetctl] %s\n' "$*"
}

die() {
  printf '[cachetctl] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "run as root (sudo /opt/cachet/cachetctl ...)"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

env_value() {
  local file="$1"
  local key="$2"
  awk -v wanted="${key}" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      line=$0
      sub(/^[[:space:]]*export[[:space:]]+/, "", line)
      pos=index(line, "=")
      if (pos == 0) next
      name=substr(line, 1, pos-1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == wanted) {
        value=substr(line, pos+1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        if ((value ~ /^".*"$/) || (value ~ /^\047.*\047$/)) {
          value=substr(value, 2, length(value)-2)
        }
        print value
        exit
      }
    }
  ' "${file}"
}

compose() {
  docker compose \
    --project-name "${PROJECT_NAME}" \
    --env-file "${DEPLOY_ENV}" \
    --file "${COMPOSE_FILE}" \
    "$@"
}

assert_equals() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(env_value "${RUNTIME_ENV}" "${key}")"
  [[ "${actual}" == "${expected}" ]] || die "${key} must equal ${expected}"
}

assert_matches() {
  local key="$1"
  local regex="$2"
  local actual
  actual="$(env_value "${RUNTIME_ENV}" "${key}")"
  [[ "${actual}" =~ ${regex} ]] || die "${key} is missing or malformed"
}

assert_data_dir() {
  local path="$1"
  local owner mode
  owner="$(stat -c '%u:%g' "${path}")"
  mode="$(stat -c '%a' "${path}")"
  [[ "${owner}" == "10001:10001" ]] \
    || die "${path} must be owned by UID:GID 10001:10001"
  [[ "${mode}" == "750" ]] \
    || die "${path} must have mode 0750"
}

preflight() {
  require_root
  for command_name in awk curl docker install python3 stat; do
    require_command "${command_name}"
  done
  docker compose version >/dev/null

  [[ -f "${COMPOSE_FILE}" ]] || die "missing ${COMPOSE_FILE}"
  [[ -f "${DEPLOY_ENV}" ]] || die "missing ${DEPLOY_ENV}"
  [[ -f "${RUNTIME_ENV}" ]] || die "missing ${RUNTIME_ENV}"

  local runtime_mode
  runtime_mode="$(stat -c '%a' "${RUNTIME_ENV}")"
  [[ "${runtime_mode}" == "600" ]] || die "${RUNTIME_ENV} must have mode 0600"

  assert_equals X402_BYPASS 0
  assert_equals DEMO_MODE 0
  assert_equals CHAIN_MODE viem
  assert_equals CHAIN_ID 1952

  assert_matches GATEWAY_PK '^0x[0-9a-fA-F]{64}$'
  for address_key in ADDR_REGISTRY ADDR_CERTIFICATE ADDR_VAULT ADDR_CHALLENGE ADDR_MOCKUSDT; do
    assert_matches "${address_key}" '^0x[0-9a-fA-F]{40}$'
  done
  assert_matches RPC_URL '^https://.+'
  assert_matches CERT_PAGE_BASE '^https://.+'

  local engine_image gateway_image engine_sha gateway_sha
  engine_image="$(env_value "${DEPLOY_ENV}" ENGINE_IMAGE)"
  gateway_image="$(env_value "${DEPLOY_ENV}" GATEWAY_IMAGE)"
  [[ "${engine_image}" =~ ^ghcr\.io/wngstnr-code/cachet-engine:sha-([0-9a-f]{40})$ ]] \
    || die "ENGINE_IMAGE must use a full immutable Git SHA tag"
  engine_sha="${BASH_REMATCH[1]}"
  [[ "${gateway_image}" =~ ^ghcr\.io/wngstnr-code/cachet-gateway:sha-([0-9a-f]{40})$ ]] \
    || die "GATEWAY_IMAGE must use a full immutable Git SHA tag"
  gateway_sha="${BASH_REMATCH[1]}"
  [[ "${engine_sha}" == "${gateway_sha}" ]] || die "engine and gateway image SHAs differ"

  local data_root
  data_root="$(env_value "${DEPLOY_ENV}" CACHET_DATA_ROOT)"
  [[ "${data_root}" == /var/lib/cachet ]] || die "CACHET_DATA_ROOT must be /var/lib/cachet"
  [[ -d "${data_root}/engine" && -d "${data_root}/gateway" ]] \
    || die "persistent directories are missing; follow the provisioning runbook"
  assert_data_dir "${data_root}/engine"
  assert_data_dir "${data_root}/gateway"

  compose config --quiet

  if [[ -z "$(env_value "${RUNTIME_ENV}" X402_FACILITATOR_URL)" ]]; then
    log "warning: X402_FACILITATOR_URL is empty; paid calls will remain unavailable"
  fi
  log "preflight passed (secrets were not printed)"
}

wait_healthy() {
  local service="$1"
  local elapsed=0
  local container_id status

  while (( elapsed < HEALTH_TIMEOUT_SECONDS )); do
    container_id="$(compose ps --quiet "${service}")"
    if [[ -n "${container_id}" ]]; then
      status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_id}")"
      if [[ "${status}" == "healthy" ]]; then
        log "${service} is healthy"
        return 0
      fi
      if [[ "${status}" == "unhealthy" || "${status}" == "exited" || "${status}" == "dead" ]]; then
        compose logs --tail 80 "${service}" >&2 || true
        die "${service} entered state ${status}"
      fi
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  compose logs --tail 80 "${service}" >&2 || true
  die "${service} did not become healthy within ${HEALTH_TIMEOUT_SECONDS}s"
}

backup_state() {
  require_root
  require_command python3
  require_command install

  local timestamp backup_dir engine_db gateway_json
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_dir="${BACKUP_ROOT}/${timestamp}"
  engine_db="/var/lib/cachet/engine/index/engine.db"
  gateway_json="/var/lib/cachet/gateway/gateway.json"

  install -d -m 0700 "${BACKUP_ROOT}" "${backup_dir}"

  if [[ -f "${engine_db}" ]]; then
    python3 -c 'import sqlite3,sys; source=sqlite3.connect(sys.argv[1]); target=sqlite3.connect(sys.argv[2]); source.backup(target); target.close(); source.close()' \
      "${engine_db}" "${backup_dir}/engine.db"
    chmod 0600 "${backup_dir}/engine.db"
  fi

  if [[ -f "${gateway_json}" ]]; then
    install -m 0600 "${gateway_json}" "${backup_dir}/gateway.json"
  fi
  install -m 0600 "${DEPLOY_ENV}" "${backup_dir}/deploy.env"
  log "backup created at ${backup_dir}"
}

smoke_internal() {
  require_command curl
  curl --fail --silent --show-error http://127.0.0.1:8100/healthz >/dev/null
  curl --fail --silent --show-error http://127.0.0.1:8787/healthz >/dev/null
  log "internal engine and gateway smoke checks passed"
}

smoke_public() {
  require_command curl
  curl --fail --silent --show-error "${PUBLIC_URL}/healthz" >/dev/null

  local status
  status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --request POST "${PUBLIC_URL}/v1/verify" \
    --header 'content-type: application/json' \
    --data '{}')"
  [[ "${status}" == "402" ]] || die "unpaid public verify returned ${status}, expected 402"

  curl --fail --silent --show-error "${PUBLIC_URL}/v1/cert/6" >/dev/null
  log "public HTTPS, x402 rejection, and certificate smoke checks passed"
}

verify_corpus() {
  require_command curl
  require_command python3
  curl --fail --silent --show-error http://127.0.0.1:8100/healthz \
    | python3 -c 'import json,sys; count=int(json.load(sys.stdin).get("entries",0)); print(f"entries={count}"); raise SystemExit(0 if count >= 5000 else 1)' \
    || die "engine corpus has fewer than 5000 entries"
  log "corpus size accepted"
}

deploy_stack() {
  preflight
  backup_state

  log "pulling immutable images"
  compose pull engine gateway

  log "updating engine"
  compose up --detach --no-deps engine
  wait_healthy engine
  verify_corpus

  log "updating gateway"
  compose up --detach --no-deps gateway
  wait_healthy gateway

  smoke_internal
  smoke_public
  log "deployment completed"
}

bootstrap_engine() {
  preflight
  log "starting engine without the corpus gate for first-time seeding"
  compose pull engine
  compose up --detach --no-deps engine
  wait_healthy engine
  smoke_internal_engine
  log "engine bootstrap complete; seed through the documented SSH tunnel"
}

pause_stack() {
  preflight
  log "stopping Cachet so SimpleArt has the full deployment budget"
  compose stop gateway engine
}

resume_stack() {
  preflight
  compose up --detach --no-deps engine
  wait_healthy engine
  verify_corpus
  compose up --detach --no-deps gateway
  wait_healthy gateway
  smoke_internal
  smoke_public
  log "Cachet resumed"
}

rollback_images() {
  local previous_deploy_env="${1:-}"
  [[ -n "${previous_deploy_env}" ]] || die "usage: cachetctl rollback /var/backups/cachet/<timestamp>/deploy.env"
  [[ "${previous_deploy_env}" == "${BACKUP_ROOT}"/*/deploy.env ]] \
    || die "rollback file must be a deploy.env below ${BACKUP_ROOT}"
  [[ -f "${previous_deploy_env}" ]] || die "rollback file not found"

  require_root
  install -m 0600 "${previous_deploy_env}" "${DEPLOY_ENV}"
  log "restored previous immutable image tags"
  deploy_stack
}

show_status() {
  preflight
  compose ps
  local container_ids
  container_ids="$(compose ps --quiet)"
  if [[ -n "${container_ids}" ]]; then
    # shellcheck disable=SC2086 # docker stats expects individual container IDs.
    docker stats --no-stream ${container_ids} || true
  fi
  df -h /var/lib/cachet
  free -h
}

smoke_internal_engine() {
  require_command curl
  curl --fail --silent --show-error http://127.0.0.1:8100/healthz >/dev/null
  log "internal engine smoke check passed"
}

usage() {
  cat <<'EOF'
Usage: cachetctl <command>

Commands:
  preflight                 Validate files, safety flags, image tags, and Compose
  backup                    Create a consistent application-state backup
  bootstrap-engine          Start an empty engine for first-time corpus seeding
  deploy                    Backup, pull immutable images, deploy, and smoke test
  pause                     Stop Cachet before a SimpleArt blue-green deployment
  resume                    Start and verify Cachet after SimpleArt deployment
  rollback <deploy.env>     Restore prior image tags from a Cachet backup
  smoke                     Run internal and public smoke checks
  corpus                    Require at least 5000 engine corpus entries
  status                    Show service and host resource status
EOF
}

case "${1:-}" in
  preflight) preflight ;;
  backup) preflight; backup_state ;;
  bootstrap-engine) bootstrap_engine ;;
  deploy) deploy_stack ;;
  pause) pause_stack ;;
  resume) resume_stack ;;
  rollback) rollback_images "${2:-}" ;;
  smoke) preflight; smoke_internal; smoke_public ;;
  corpus) preflight; verify_corpus ;;
  status) show_status ;;
  *) usage; exit 2 ;;
esac
