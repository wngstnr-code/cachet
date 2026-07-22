#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ci-deploy.sh
source "${SCRIPT_DIR}/ci-deploy.sh"

fail() {
  printf 'test-ci-deploy: %s\n' "$*" >&2
  exit 1
}

VALID_SHA="0123456789abcdef0123456789abcdef01234567"
valid_sha "${VALID_SHA}" || fail "valid full SHA was rejected"
if valid_sha "01234567"; then
  fail "short SHA was accepted"
fi
if valid_sha "0123456789ABCDEF0123456789ABCDEF01234567"; then
  fail "uppercase SHA was accepted"
fi

TEST_DIR="$(mktemp -d /tmp/cachet-ci-deploy-test.XXXXXX)"
trap 'rm -rf -- "${TEST_DIR}"' EXIT
DEPLOY_ENV_TEST="${TEST_DIR}/deploy.env"
write_deploy_env "${VALID_SHA}" "${DEPLOY_ENV_TEST}"

[[ "$(wc -l <"${DEPLOY_ENV_TEST}" | tr -d ' ')" == "4" ]] \
  || fail "deploy.env must contain exactly four lines"
grep -Fx "ENGINE_IMAGE=ghcr.io/scientivan/cachet-engine:sha-${VALID_SHA}" \
  "${DEPLOY_ENV_TEST}" >/dev/null || fail "engine image is wrong"
grep -Fx "GATEWAY_IMAGE=ghcr.io/scientivan/cachet-gateway:sha-${VALID_SHA}" \
  "${DEPLOY_ENV_TEST}" >/dev/null || fail "gateway image is wrong"
grep -Fx "CACHET_DATA_ROOT=/var/lib/cachet" "${DEPLOY_ENV_TEST}" >/dev/null \
  || fail "data root is wrong"
grep -Fx "CACHET_RUNTIME_ENV=/opt/cachet/.env" "${DEPLOY_ENV_TEST}" >/dev/null \
  || fail "runtime env path is wrong"

printf 'test-ci-deploy: passed\n'
