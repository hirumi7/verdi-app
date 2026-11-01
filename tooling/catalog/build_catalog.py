"""Reproduce the reviewed offline package. Run from any directory; no network."""
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'apps/mobile/assets/catalog'
def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
entries = json.loads((HERE / 'reviewed-entries.json').read_text())
raw = encode(entries)
asset = json.loads((HERE / 'generic-asset.json').read_text())
assert hashlib.sha256((ROOT / 'apps/mobile/assets/illustrations/empty-plants.png').read_bytes()).hexdigest() == asset['sha256']
species = json.loads((HERE / 'species-assets.json').read_text())
for art in species['assets']:
    assert hashlib.sha256((ROOT / 'apps/mobile/assets/catalog_art' / (art['resourceName'] + '.png')).read_bytes()).hexdigest() == art['sha256']
manifest = dict(schemaVersion=1, catalogVersion='verdi-2026-11-01.1', normalizationVersion='verdi-name-v1', entriesSha256=hashlib.sha256(raw).hexdigest(), entryCount=len(entries), preparedAt='2026-11-01T10:00:00.000Z', preparedBy='Codex (AI assistant)', entryIds=[e['id'] for e in entries], popularPolicyId='popular-v1', popularIds=[e['id'] for e in entries], genericAssetId='generic_plant', assets=[asset, *species['assets']], speciesArt=species['speciesArt'])
OUT.mkdir(exist_ok=True, parents=True)
(OUT / 'entries.json').write_bytes(raw)
(OUT / 'manifest.json').write_bytes(encode(manifest))
print(f'Built {len(entries)} reviewed entries; {len(raw)} bytes')
