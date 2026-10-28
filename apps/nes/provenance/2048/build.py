"""Rebuild the unchanged MIT 2048 game using the ca65/ld65 in PATH."""

import hashlib
from pathlib import Path
import subprocess

EXPECTED = "b1468ace1dcbf374a5202a26707b3d1a2fb11924a79aab877079730fe4f72ed6"
OBJECTS = ("2048", "blit", "board", "controller", "drawing", "header",
           "nmi", "startup", "tests", "tile-lookups")


def build():
    source = Path(__file__).resolve().parent / "source"
    (source / "obj").mkdir(exist_ok=True)
    for name in OBJECTS:
        subprocess.run(["ca65", "-o", "obj/" + name + ".o",
                        "src/" + name + ".s", "--debug-info"],
                       cwd=source, check=True)
    subprocess.run(["ld65", "-o", "2048.nes"] +
                   ["obj/" + name + ".o" for name in OBJECTS] +
                   ["-C", "nrom.cfg", "--dbgfile", "2048.nes.db"],
                   cwd=source, check=True)
    digest = hashlib.sha256((source / "2048.nes").read_bytes()).hexdigest()
    if digest != EXPECTED:
        raise RuntimeError("Built ROM differs from reviewed digest: " + digest)
    print("Built 2048.nes; SHA-256 verified: " + digest)


if __name__ == "__main__":
    build()
