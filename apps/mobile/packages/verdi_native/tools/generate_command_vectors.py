"""Independent standard-library expectations, shared by Dart and Swift tests."""
import hashlib
import json
from pathlib import Path

cases = [
    ("null", None),
    ("empty-array", []),
    ("empty-object", {}),
    ("booleans", [True, False, None]),
    ("integer-extremes", [-9007199254740991, -1, 0, 1, 9007199254740991]),
    ("nested-sorting", {"z": [2, 1], "a": {"x": None, "B": 'É\n/"'}}),
    ("control-escaping", "".join(chr(i) for i in range(32)) + '"\\/'),
    ("unicode", "Plant 🌿 𐐀 中文 café \u2028\u2029 <>&"),
    ("composed", "é"),
    ("decomposed", "e\u0301"),
    ("ascii-keys", {"z": 1, "Z": 2, "a": 3, "A": 4, "_": 5, "0": 6, "\n": 7, "": 8}),
    ("retained-order", [{"b": 2, "a": 1}, False, 3, 2, 1]),
]
payload = {"draftRevision": 1, "draftId": "00000000-0000-4000-8000-000000000001"}
cases.append(("save-plant", {"commandType": "SavePlant", "normalisedPayload": payload}))

vectors = []
for name, value in cases:
    canonical = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    raw = canonical.encode("utf-8")
    vector = {"name": name, "input": value, "canonical": canonical,
              "utf8_hex": raw.hex(), "sha256": hashlib.sha256(raw).hexdigest()}
    if name == "save-plant":
        vector.update(command_type="SavePlant", payload=payload)
    vectors.append(vector)

raw_cases = [
    ("lone-high", [0xd800]),
    ("lone-low", [0xdc00]),
    ("interrupted-pair", [0xd800, 0x78]),
    ("valid-pair", [0xd83c, 0xdf3f]),
    ("consecutive-highs", [0xd800, 0xd800]),
    ("mixed-raw", [0xd800, 0x61, 0xd83c, 0xdf3f, 0xdc00]),
    ("save-draft-raw", [0xd800, 0x61, 0xd83c, 0xdf3f, 0xdc00]),
]
for name, units in raw_cases:
    packed = b"".join(unit.to_bytes(2, "little") for unit in units)
    value = packed.decode("utf-16-le", errors="surrogatepass")
    metadata = {}
    if name == "save-draft-raw":
        metadata = {"command_type": "SaveDraft", "raw_payload_field": "notes"}
        value = {"commandType": "SaveDraft", "normalisedPayload": {"notes": value}}
    text = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
    raw = text.encode("utf-8", errors="backslashreplace")
    vectors.append({"name": name, "utf16_units": units, "canonical": raw.decode("utf-8"),
                    "utf8_hex": raw.hex(), "sha256": hashlib.sha256(raw).hexdigest(), **metadata})

destination = Path(__file__).resolve().parents[1] / "Tests/VerdiNativeTests/Fixtures/canonical-command-v1.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps({"version": 1, "vectors": vectors}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {len(vectors)} independently computed command vectors")
