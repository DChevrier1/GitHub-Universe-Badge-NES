"""Reproduce the reviewed MIT Minekart Madness v1.0 header conversion.

Usage: python3 normalize_header.py ORIGINAL.nes OUTPUT.nes
Only this exact author-published input is accepted. Game code/assets are intact.
"""

import hashlib
from pathlib import Path
import sys

EXPECTED = "45d18d8b3662e6c08043759e550e658bcd23e48394a00f24de5e5fbe57e4900a"
RESULT = "7defa774cdf37c66e651e90cb6b20922ac20b4fc47135a3a40f633f255100663"


def convert(original):
    if hashlib.sha256(original).hexdigest() != EXPECTED:
        raise ValueError("Input is not the reviewed Minekart Madness v1.0 MMC1 release")
    if original[:16].hex() != "4e45531a081013080000700000000000":
        raise ValueError("Unexpected original cartridge metadata")
    # Equivalent iNES1: mapper 1, vertical mirroring, battery, 128 KiB PRG,
    # 128 KiB CHR, 8 KiB PRG RAM, NTSC. NES2 originally declares 8 KiB NVRAM.
    header = bytes.fromhex("4e45531a081013000100000000000000")
    converted = header + original[16:]
    if hashlib.sha256(converted).hexdigest() != RESULT:
        raise ValueError("Converted ROM failed its reviewed digest")
    return converted


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: normalize_header.py ORIGINAL.nes OUTPUT.nes")
    Path(sys.argv[2]).write_bytes(convert(Path(sys.argv[1]).read_bytes()))
