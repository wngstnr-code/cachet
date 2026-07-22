#!/usr/bin/env bash
set -Eeuo pipefail

# Runs on the OVH VPS after GitHub Actions uploads this file, compose.ovh.yml,
# and cachetctl.sh into one private temporary release directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_SOURCE="${SCRIPT_DIR}/compose.ovh.yml"
CACHETCTL_SOURCE="${SCRIPT_DIR}/cachetctl.sh"
COMPOSE_TARGET="/opt/cachet/compose.yml"
CACHETCTL_TARGET="/opt/cachet/cachetctl"
DEPLOY_ENV="/opt/cachet/deploy.env"
BACKUP_ROOT="/var/backups/cachet"
SIMPLEART_HEALTH_URL="https://simpleartch.com/api/health"

log() {
  printf '[cachet-ci] %s\n' "$*"
}

die() {
  printf '[cachet-ci] ERROR: %s\n' "$*" >&2
  exit 1
}

simpleart_healthy() {
  curl --fail --silent --show-error \
    --retry 5 --retry-all-errors --retry-delay 3 \
    "${SIMPLEART_HEALTH_URL}" >/dev/null
}

valid_sha() {
  [[ "${1:-}" =~ ^[0-9a-f]{40}$ ]]
}

write_deploy_env() {
  local sha="$1"
  local destination="$2"

  {
    printf 'ENGINE_IMAGE=ghcr.io/scientivan/cachet-engine:sha-%s\n' "${sha}"
    printf 'GATEWAY_IMAGE=ghcr.io/scientivan/cachet-gateway:sha-%s\n' "${sha}"
    printf 'CACHET_DATA_ROOT=/var/lib/cachet\n'
    printf 'CACHET_RUNTIME_ENV=/opt/cachet/.env\n'
  } >"${destination}"
  chmod 0600 "${destination}"
}

main() {
  [[ "${EUID}" -eq 0 ]] || die "run as root"
  [[ "$#" -eq 1 ]] || die "usage: ci-deploy.sh <full-main-commit-sha>"

  local sha="$1"
  valid_sha "${sha}" || die "image SHA must be 40 lowercase hex characters"

  if [[ -n "${CACHET_CI_DOCKER_CONFIG:-}" ]]; then
    [[ "${CACHET_CI_DOCKER_CONFIG}" =~ ^/run/cachet-docker-auth-[0-9]+-[0-9]+$ ]] \
      || die "CACHET_CI_DOCKER_CONFIG is outside the permitted runtime path"
    [[ -d "${CACHET_CI_DOCKER_CONFIG}" ]] || die "temporary Docker config is missing"
    export DOCKER_CONFIG="${CACHET_CI_DOCKER_CONFIG}"
  fi

  [[ -f "${COMPOSE_SOURCE}" ]] || die "missing uploaded compose.ovh.yml"
  [[ -f "${CACHETCTL_SOURCE}" ]] || die "missing uploaded cachetctl.sh"
  [[ -f "${DEPLOY_ENV}" ]] || die "missing ${DEPLOY_ENV}"

  log "checking SimpleArt before Cachet mutation"
  simpleart_healthy || die "SimpleArt pre-deploy health check failed"

  local timestamp rollback_dir rollback_env new_env
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  rollback_dir="${BACKUP_ROOT}/${timestamp}-ci-previous"
  rollback_env="${rollback_dir}/deploy.env"
  new_env="$(mktemp /opt/cachet/deploy.env.ci.XXXXXX)"
  trap 'rm -f -- "${new_env:-}"' EXIT

  install -d -o root -g root -m 0700 "${BACKUP_ROOT}" "${rollback_dir}"
  install -o root -g root -m 0600 "${DEPLOY_ENV}" "${rollback_env}"
  [[ -f "${COMPOSE_TARGET}" ]] \
    && install -o root -g root -m 0600 "${COMPOSE_TARGET}" "${rollback_dir}/compose.yml"
  [[ -f "${CACHETCTL_TARGET}" ]] \
    && install -o root -g root -m 0700 "${CACHETCTL_TARGET}" "${rollback_dir}/cachetctl"

  install -o root -g root -m 0644 "${COMPOSE_SOURCE}" "${COMPOSE_TARGET}"
  install -o root -g root -m 0755 "${CACHETCTL_SOURCE}" "${CACHETCTL_TARGET}"
  write_deploy_env "${sha}" "${new_env}"
  chown root:root "${new_env}"
  mv -f -- "${new_env}" "${DEPLOY_ENV}"
  trap - EXIT

  log "deploying immutable images for ${sha}"
  if "${CACHETCTL_TARGET}" deploy; then
    simpleart_healthy || die "SimpleArt post-deploy health check failed"
    log "deployment accepted; previous assets retained at ${rollback_dir}"
    return 0
  fi

  log "deployment failed; restoring previous image tags and deployment assets"
  install -o root -g root -m 0600 "${rollback_env}" "${DEPLOY_ENV}"
  [[ -f "${rollback_dir}/compose.yml" ]] \
    && install -o root -g root -m 0644 "${rollback_dir}/compose.yml" "${COMPOSE_TARGET}"
  [[ -f "${rollback_dir}/cachetctl" ]] \
    && install -o root -g root -m 0755 "${rollback_dir}/cachetctl" "${CACHETCTL_TARGET}"

  if "${CACHETCTL_TARGET}" deploy; then
    simpleart_healthy || die "image rollback completed but SimpleArt is unhealthy"
    die "new deployment failed; previous Cachet images were restored"
  fi

  die "new deployment and automatic image rollback both failed; inspect ${rollback_dir}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
