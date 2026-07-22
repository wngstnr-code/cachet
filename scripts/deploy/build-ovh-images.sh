#!/usr/bin/env bash
set -Eeuo pipefail

# Build on Dien's Mac/CI and push linux/amd64 images to GHCR. The VPS never builds.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-ghcr.io/scientivan}"
PUBLISH_IMAGES="${PUBLISH_IMAGES:-1}"
GIT_COMMIT="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
SOURCE_URL="https://github.com/wngstnr-code/cachet"

[[ "${GIT_COMMIT}" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'Could not resolve a full Git commit SHA.\n' >&2
  exit 1
}

[[ "${PUBLISH_IMAGES}" == "0" || "${PUBLISH_IMAGES}" == "1" ]] || {
  printf 'PUBLISH_IMAGES must be 0 (load locally) or 1 (push to GHCR).\n' >&2
  exit 1
}

git -C "${REPO_ROOT}" diff --quiet || {
  printf 'Tracked working-tree changes must be committed before building images.\n' >&2
  exit 1
}
git -C "${REPO_ROOT}" diff --cached --quiet || {
  printf 'Staged changes must be committed before building images.\n' >&2
  exit 1
}

ENGINE_IMAGE="${REGISTRY_NAMESPACE}/cachet-engine:sha-${GIT_COMMIT}"
GATEWAY_IMAGE="${REGISTRY_NAMESPACE}/cachet-gateway:sha-${GIT_COMMIT}"

if [[ "${PUBLISH_IMAGES}" == "1" ]]; then
  BUILD_OUTPUT=(--push)
else
  BUILD_OUTPUT=(--load)
fi

# Root .dockerignore adalah zona shared yang tidak diubah oleh Person A. Buat
# context gateway minimal agar `.env`, `.git`, data, dan folder lain tidak pernah
# dikirim ke BuildKit walaupun Dockerfile gateway memakai layout monorepo.
CACHET_GATEWAY_CONTEXT="$(mktemp -d /tmp/cachet-gateway-context.XXXXXX)"
cleanup() {
  if [[ -d "${CACHET_GATEWAY_CONTEXT}" \
    && "$(basename "${CACHET_GATEWAY_CONTEXT}")" == cachet-gateway-context.* ]]; then
    rm -rf -- "${CACHET_GATEWAY_CONTEXT}"
  fi
}
trap cleanup EXIT

install -d \
  "${CACHET_GATEWAY_CONTEXT}/apps/server" \
  "${CACHET_GATEWAY_CONTEXT}/packages/contracts-abi"
install -m 0644 \
  "${REPO_ROOT}/tsconfig.base.json" \
  "${CACHET_GATEWAY_CONTEXT}/tsconfig.base.json"
install -m 0644 \
  "${REPO_ROOT}/apps/server/package.json" \
  "${REPO_ROOT}/apps/server/pnpm-lock.yaml" \
  "${REPO_ROOT}/apps/server/tsconfig.json" \
  "${CACHET_GATEWAY_CONTEXT}/apps/server/"
install -m 0644 \
  "${REPO_ROOT}/packages/contracts-abi/package.json" \
  "${REPO_ROOT}/packages/contracts-abi/index.ts" \
  "${REPO_ROOT}/packages/contracts-abi/addresses.testnet.json" \
  "${CACHET_GATEWAY_CONTEXT}/packages/contracts-abi/"
cp -R "${REPO_ROOT}/apps/server/src" "${CACHET_GATEWAY_CONTEXT}/apps/server/src"
cp -R "${REPO_ROOT}/packages/contracts-abi/abi" \
  "${CACHET_GATEWAY_CONTEXT}/packages/contracts-abi/abi"

printf 'Building %s\n' "${ENGINE_IMAGE}"
docker buildx build \
  --platform linux/amd64 \
  --build-arg WITH_ML=0 \
  --file "${REPO_ROOT}/services/engine/Dockerfile" \
  --tag "${ENGINE_IMAGE}" \
  --label "org.opencontainers.image.source=${SOURCE_URL}" \
  --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
  "${BUILD_OUTPUT[@]}" \
  "${REPO_ROOT}/services/engine"

printf 'Building %s\n' "${GATEWAY_IMAGE}"
docker buildx build \
  --platform linux/amd64 \
  --file "${REPO_ROOT}/apps/server/Dockerfile" \
  --tag "${GATEWAY_IMAGE}" \
  --label "org.opencontainers.image.source=${SOURCE_URL}" \
  --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
  "${BUILD_OUTPUT[@]}" \
  "${CACHET_GATEWAY_CONTEXT}"

if [[ "${PUBLISH_IMAGES}" == "1" ]]; then
  printf '\nPublished immutable images. Set these exact values in /opt/cachet/deploy.env:\n'
else
  printf '\nValidated immutable images locally without publishing:\n'
fi
printf 'ENGINE_IMAGE=%s\n' "${ENGINE_IMAGE}"
printf 'GATEWAY_IMAGE=%s\n' "${GATEWAY_IMAGE}"
