"""Generate pinned Unicode 15.1 default casefold and White_Space for Verdi.
Usage: python3 tooling/unicode/generate.py [directory containing the two UCD files]
Otherwise downloads exact official files; rejects any digest mismatch.
Run dart format on the generated Dart file afterward.
"""
import hashlib, pathlib, sys, urllib.request
root=pathlib.Path(__file__).resolve().parents[2]
hashes={'CaseFolding.txt':'4e55acfdc32825a22e87670e9056a3bf94ad7c5400065778e9e10f8314372bcf','PropList.txt':'05672956317b6296bc2ec3d6cef1f6452b57ff4f2efc6dc55b0a19277d5fcfd1'}
inputs={}
for name,digest in hashes.items():
    raw=(pathlib.Path(sys.argv[1])/name).read_bytes() if len(sys.argv)>1 else urllib.request.urlopen('https://www.unicode.org/Public/15.1.0/ucd/'+name).read()
    assert hashlib.sha256(raw).hexdigest()==digest,name
    inputs[name]=raw.decode()
fold={}
for line in inputs['CaseFolding.txt'].splitlines():
    parts=line.split('#')[0].strip().split(';')
    if len(parts)>2 and parts[1].strip() in ('C','F'):fold[int(parts[0],16)]=[int(x,16) for x in parts[2].split()]
spaces=[]
for line in inputs['PropList.txt'].splitlines():
    parts=line.split('#')[0].strip().split(';')
    if len(parts)>1 and parts[1].strip()=='White_Space':
        ends=parts[0].strip().split('..');spaces.extend(range(int(ends[0],16),int(ends[-1],16)+1))
text='// Generated from Unicode 15.1.0 CaseFolding.txt (C/F) and PropList.txt.\n// See tooling/unicode/LICENSE.txt and tooling/unicode/generate.py.\nconst catalogCaseFold = <int, List<int>>{\n'
text+=''.join(f'  {k}: [{", ".join(map(str,v))}],\n' for k,v in sorted(fold.items()))+'};\n'
text+='const catalogWhitespace = <int>{'+', '.join(map(str,spaces))+'};\n'
(root/'apps/mobile/packages/verdi_core/lib/src/catalog_unicode.dart').write_text(text)
