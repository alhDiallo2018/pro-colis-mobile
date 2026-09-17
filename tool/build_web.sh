#!/usr/bin/env bash
set -euo pipefail

# Build web Flutter avec injection de la clé Google Maps, équivalent local du
# Dockerfile. `flutter build web` copie web/index.html tel quel : il ne remplace
# que $FLUTTER_BASE_HREF, jamais __GOOGLE_MAPS_API_KEY__. Le remplacement est
# donc fait ici (comme dans le Dockerfile) après le build.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

API_BASE_URL="${API_BASE_URL:-/api/v1}"
APP_BASE_URL="${APP_BASE_URL:-}"

if [[ -z "${GOOGLE_MAPS_API_KEY:-}" ]]; then
  echo "ERREUR: GOOGLE_MAPS_API_KEY doit être définie (env ou .env)." >&2
  exit 1
fi

flutter build web --release --no-wasm-dry-run \
  --dart-define=API_BASE_URL="${API_BASE_URL}" \
  --dart-define=APP_BASE_URL="${APP_BASE_URL}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}"

sed -i "s|__GOOGLE_MAPS_API_KEY__|${GOOGLE_MAPS_API_KEY}|g" build/web/index.html

if grep -q "__GOOGLE_MAPS_API_KEY__" build/web/index.html; then
  echo "ERREUR: le placeholder Google Maps n'a pas été remplacé dans build/web/index.html." >&2
  exit 1
fi

echo "Build web OK: clé Google Maps injectée dans build/web/index.html."
