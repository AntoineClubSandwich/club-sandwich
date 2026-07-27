#!/usr/bin/env bash

set -euo pipefail

readonly FLUTTER_VERSION="3.44.7"
readonly FLUTTER_REPOSITORY="https://github.com/flutter/flutter.git"
readonly BUILD_CACHE_ROOT="${NETLIFY_CACHE_DIR:-${TMPDIR:-/tmp}/club-sandwich-netlify-cache}"
readonly FLUTTER_SDK_DIR="${BUILD_CACHE_ROOT}/flutter-${FLUTTER_VERSION}"

mkdir -p "${BUILD_CACHE_ROOT}"

if [[ ! -x "${FLUTTER_SDK_DIR}/bin/flutter" ]]; then
  if [[ -e "${FLUTTER_SDK_DIR}" ]]; then
    printf 'Erreur : le cache Flutter existe mais il est incomplet : %s\n' \
      "${FLUTTER_SDK_DIR}" >&2
    printf '%s\n' 'Videz uniquement ce dossier de cache puis relancez le build.' >&2
    exit 1
  fi

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
