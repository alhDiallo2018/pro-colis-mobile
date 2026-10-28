"""Configure Google Sign-In from a real iOS OAuth client (no secret).
Run: python3 tool/configure_google_ios.py --client-id <id>.apps.googleusercontent.com
Then rebuild the iOS application; hot reload cannot register a URL scheme.
"""
import argparse, plistlib, re
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--client-id',required=True)
args=parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_-]+\.apps\.googleusercontent\.com',args.client_id):
    parser.error('Identifiant OAuth iOS invalide')
path=Path(__file__).resolve().parents[1]/'ios/Runner/Info.plist'
data=plistlib.loads(path.read_bytes())
old=data.get('GIDClientID','');scheme='.'.join(reversed(args.client_id.split('.')))
types=data.get('CFBundleURLTypes',[])
# Ne pas supprimer les liens profonds des autres services.
for entry in types:
    entry['CFBundleURLSchemes']=[s for s in entry.get('CFBundleURLSchemes',[]) if s!='.'.join(reversed(old.split('.')))]
if not any(scheme in entry.get('CFBundleURLSchemes',[]) for entry in types):
    types.append({'CFBundleTypeRole':'Editor','CFBundleURLSchemes':[scheme]})
data['GIDClientID']=args.client_id;data['CFBundleURLTypes']=types
path.write_bytes(plistlib.dumps(data,sort_keys=False))
print('Configuration iOS enregistrée. Vérifiez le bundle ID dans Google Cloud, puis reconstruisez l’application.')
