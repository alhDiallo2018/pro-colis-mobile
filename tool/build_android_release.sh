#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
flutter="${FLUTTER_BIN:-.flutter-sdk/bin/flutter}"
# Charge également la configuration locale utilisée par le build web.
# La clé est exportée pour le SDK natif Android (Gradle).
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi
if [[ -z "${GOOGLE_MAPS_API_KEY:-}" ]]; then
  echo 'GOOGLE_MAPS_API_KEY doit être définie pour afficher la carte.' >&2
  exit 1
fi
target="${1:-all}"
case "$target" in
  all|aab|apk) ;;
  *) echo 'Usage: bash tool/build_android_release.sh [all|aab|apk]' >&2; exit 1 ;;
esac

# Gradle autorise un repli debug pour les essais locaux. Un livrable Play
# doit au contraire échouer avant compilation si sa signature manque.
python3 - "$target" <<'PY'
from pathlib import Path
import os
import re
import subprocess
import sys
p = Path('android/key.properties')
if not p.is_file():
    raise SystemExit('Signature release absente : android/key.properties requis.')
props = dict(line.split('=', 1) for line in p.read_text().splitlines()
             if '=' in line and not line.lstrip().startswith('#'))
if not all(props.get(key, '').strip() for key in ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']):
    raise SystemExit('Configuration de signature release incomplète.')
if not (Path('android/app') / props['storeFile']).is_file():
    raise SystemExit('Keystore release introuvable.')
# Le compte Play existant impose sa clé d'importation. Vérifier son certificat
# avant de compiler évite de produire un AAB que la console refusera ensuite.
# Le mot de passe passe par l'environnement du sous-processus, jamais par
# les arguments de commande ni par les logs.
if sys.argv[1] in ('all', 'aab'):
    expected = '24:BE:58:23:BE:E4:66:5A:83:C8:8C:CF:74:0C:50:09:78:1A:17:23'
    result = subprocess.run([
        'keytool', '-J-Duser.language=en', '-list', '-v',
        '-keystore', str(Path('android/app') / props['storeFile']),
        '-alias', props['keyAlias'], '-storepass:env', 'PROCOLIS_KEYSTORE_PASSWORD',
    ], env={**os.environ, 'PROCOLIS_KEYSTORE_PASSWORD': props['storePassword']},
       capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit('Impossible de vérifier le certificat de signature release.')
    match = re.search(r'SHA1:\s*([0-9A-F:]+)', result.stdout)
    actual = match.group(1) if match else 'inconnue'
    if actual != expected:
        raise SystemExit(
            'Signature incompatible avec le compte Play 6193041811945265589.\n'
            f'Attendue : {expected}\nLocale : {actual}\n'
            'Restaurer la clé d’importation d’origine. Si Google approuve une '
            'réinitialisation, mettre à jour cette empreinte après validation.')
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
