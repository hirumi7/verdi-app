#!/usr/bin/env python3
"""Run opt-in ENOSPC tests only on a disposable 256 MiB APFS image (macOS)."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    if sys.platform != "darwin":
        raise SystemExit("This test harness requires macOS and hdiutil.")
    package = Path(__file__).resolve().parents[1]
    if shutil.disk_usage(tempfile.gettempdir()).free < 1024**3:
        raise SystemExit("At least 1 GiB host free space is required; no image created.")
    root = Path(tempfile.mkdtemp(prefix="verdi-backup-enospc-")).resolve()
    image, mount = root / "fault.sparseimage", root / "volume"
    mount.mkdir()
    attached = False
    try:
        subprocess.run(["hdiutil", "create", "-size", "256m", "-fs", "APFS",
                        "-type", "SPARSE", "-volname", "VerdiSyntheticFaults",
                        "-nospotlight", str(image)], check=True)
        subprocess.run(["hdiutil", "attach", str(image), "-mountpoint", str(mount),
                        "-nobrowse", "-noautoopen"], check=True)
        attached = True
        if not os.path.ismount(mount):
            raise RuntimeError("Expected isolated mount is absent; refusing tests.")
        (mount / "verdi-synthetic-volume").write_text("verdi-test-volume-v1")
        env = os.environ.copy()
        env["VERDI_CAPACITY_VOLUME"] = str(mount)
        result = subprocess.run(["swift", "test", "--package-path", str(package),
                                 "--filter", "testBackupRealDiskFull"], env=env)
        return result.returncode
    finally:
        if attached or os.path.ismount(mount):
            result = subprocess.run(["hdiutil", "detach", str(mount)])
            if result.returncode or os.path.ismount(mount):
                raise RuntimeError(f"Detach failed; retained test image at {root}")
        # Remove only this invocation's temporary root after verified detachment.
        shutil.rmtree(root)


if __name__ == "__main__":
    sys.exit(main())
