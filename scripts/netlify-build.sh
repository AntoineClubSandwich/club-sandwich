#!/usr/bin/env bash

set -euo pipefail

readonly FLUTTER_VERSION="3.44.7"
readonly FLUTTER_REPOSITORY="https://github.com/flutter/flutter.git"
readonly BUILD_CACHE_ROOT="${NETLIFY_CACHE_DIR:-${TMPDIR:-/tmp}/club-sandwich-netlify-cache}"
readonly FLUTTER_SDK_DIR="${BUILD_CACHE_ROOT}/flutter-${FLUTTER_VERSION}"

mkdir -p "${BUILD_CACHE_ROOT}"

flutter_cache_is_complete() {
  [[ -x "${FLUTTER_SDK_DIR}/bin/flutter" ]] &&
    [[ -f "${FLUTTER_SDK_DIR}/bin/cache/dart-sdk/lib/libraries.json" ]] &&
    [[ -f "${FLUTTER_SDK_DIR}/bin/cache/dart-sdk/lib/_internal/dart2wasm_platform.dill" ]] &&
    [[ -f "${FLUTTER_SDK_DIR}/bin/cache/dart-sdk/bin/resources/devtools/version.json" ]]
}

if [[ -e "${FLUTTER_SDK_DIR}" ]] && ! flutter_cache_is_complete; then
  printf 'Le cache Flutter %s est incomplet, réinstallation locale.\n' \
    "${FLUTTER_VERSION}"
  rm -rf -- "${FLUTTER_SDK_DIR}"
fi

if [[ ! -x "${FLUTTER_SDK_DIR}/bin/flutter" ]]; then
  clone_root="$(mktemp -d "${BUILD_CACHE_ROOT}/flutter-clone.XXXXXX")"
  cleanup_clone() {
    rm -rf -- "${clone_root}"
  }
  trap cleanup_clone EXIT

  git clone \
    --depth 1 \
    --single-branch \
    --branch "${FLUTTER_VERSION}" \
    "${FLUTTER_REPOSITORY}" \
    "${clone_root}/flutter"
  git -C "${clone_root}/flutter" switch -c stable
  mv "${clone_root}/flutter" "${FLUTTER_SDK_DIR}"
  rmdir "${clone_root}"
  trap - EXIT
fi

export PATH="${FLUTTER_SDK_DIR}/bin:${PATH}"
export PUB_CACHE="${PUB_CACHE:-${BUILD_CACHE_ROOT}/dart-pub-cache}"

flutter_version_output="$(flutter --version)"
printf '%s\n' "${flutter_version_output}"
if [[ "${flutter_version_output}" != *"Flutter ${FLUTTER_VERSION} "* ]]; then
  printf 'Erreur : Flutter %s était attendu.\n' "${FLUTTER_VERSION}" >&2
  exit 1
fi

flutter precache --web --no-universal --force
flutter config --enable-web
flutter pub get

required_variables=(
  APP_ENV
  SUPABASE_URL
  SUPABASE_ANON_KEY
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    printf 'Erreur : la variable Netlify %s est requise.\n' \
      "${variable_name}" >&2
    exit 1
  fi
done

flutter build web --release \
  --dart-define=APP_ENV="${APP_ENV}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

resolved_app_env="production"
if [[ "${APP_ENV}" == "preprod" ]]; then
  resolved_app_env="preprod"
fi

build_commit_ref="${COMMIT_REF:-local}"
if [[ ! "${build_commit_ref}" =~ ^[a-fA-F0-9]{7,64}$ ]]; then
  build_commit_ref="local"
fi
printf '{"commit_ref":"%s","app_env":"%s"}\n' \
  "${build_commit_ref}" "${resolved_app_env}" >build/web/build-info.json

if [[ "${resolved_app_env}" == "preprod" ]]; then
  printf 'User-agent: *\nDisallow: /\n' >build/web/robots.txt
  printf '/*\n  X-Robots-Tag: noindex, nofollow\n' >build/web/_headers
fi
