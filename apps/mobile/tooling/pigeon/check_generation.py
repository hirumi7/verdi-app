#!/usr/bin/env python3
"""Generate both outputs into a temporary directory and reject drift."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--write", action="store_true", help="Regenerate both committed outputs")
arguments = parser.parse_args()
root = Path(__file__).resolve().parent
mobile = root.parent.parent
with tempfile.TemporaryDirectory(prefix="verdi-pigeon-") as temporary:
    target = Path(temporary)
    dart = target / "draft_bridge.g.dart"
    swift = target / "DraftBridge.g.swift"
    # ConfigurePigeon annotations override CLI output flags in this pinned
    # generator. Rewrite only output destinations in a temporary input copy.
    source = (root / "pigeons/draft_repository.dart").read_text()
    source = source.replace("../../lib/core/native/draft_bridge.g.dart", str(dart))
    source = source.replace("../../ios/Runner/DraftBridge.g.swift", str(swift))
    definition = target / "draft_repository.dart"
    definition.write_text(source)
    subprocess.run(
        [os.environ.get("DART_BIN", "dart"), "run", "pigeon", "--input", str(definition)],
        cwd=root, check=True,
    )
    subprocess.run(
        [os.environ.get("DART_BIN", "dart"), "format", "--line-length=80",
         "--language-version=3.13", str(dart)], cwd=root, check=True,
    )
    for generated, committed in [
        (dart, mobile / "lib/core/native/draft_bridge.g.dart"),
        (swift, mobile / "ios/Runner/DraftBridge.g.swift"),
    ]:
        if arguments.write:
            committed.write_bytes(generated.read_bytes())
        elif generated.read_bytes() != committed.read_bytes():
            raise SystemExit(f"Generated bridge drift: {committed.relative_to(mobile)}")
print("Dart and Swift bridge outputs match the pinned generator and formatter.")
