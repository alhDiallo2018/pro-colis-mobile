#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
flutter="${FLUTTER_BIN:-.flutter-sdk/bin/flutter}"
target="${1:-all}"
case "$target" in
  all|aab|apk) ;;
  *) echo 'Usage: bash tool/build_android_release.sh [all|aab|apk]' >&2; exit 1 ;;
esac

# Gradle autorise un repli debug pour les essais locaux. Un livrable Play
# doit au contraire échouer avant compilation si sa signature manque.
python3 - <<'PY'
from pathlib import Path
p = Path('android/key.properties')
if not p.is_file():
    raise SystemExit('Signature release absente : android/key.properties requis.')
props = dict(line.split('=', 1) for line in p.read_text().splitlines()
             if '=' in line and not line.lstrip().startswith('#'))
if not all(props.get(key, '').strip() for key in ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']):
    raise SystemExit('Configuration de signature release incomplète.')
if not (Path('android/app') / props['storeFile']).is_file():
    raise SystemExit('Keystore release introuvable.')
PY

# Même origine explicite pour les deux binaires : une configuration de
# développement présente dans le shell ne doit jamais les envoyer en local.
args=(--release
  --dart-define=API_BASE_URL=https://sendprocolis.com/api/v1
  --dart-define=APP_BASE_URL=https://sendprocolis.com)
if [[ -n "${GOOGLE_MAPS_API_KEY:-}" ]]; then
  args+=("--dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY")
fi

if [[ "$target" == all || "$target" == aab ]]; then
  "$flutter" build appbundle "${args[@]}"
fi
if [[ "$target" == all || "$target" == apk ]]; then
  "$flutter" build apk "${args[@]}"
fi
