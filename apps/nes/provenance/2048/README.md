# 2048

A NES number-merging puzzle by Justin Gregory, distributed under the MIT
license in `LICENSE.txt`.

- Source: https://github.com/jmgregory/2048-nes
- Revision: `e80a02a4d60b4e017ccbb14ae9230f933b7c2a44`
- Size: 40,976 bytes; mapper 0, 32 KiB PRG, 8 KiB CHR.
- Built SHA-256: `b1468ace1dcbf374a5202a26707b3d1a2fb11924a79aab877079730fe4f72ed6`
- Toolchain used: Ubuntu's `cc65` package, version `2.19-1` (ca65 and ld65).

The game has no author-published binary release. This package builds the ROM
from the pinned source and includes the original assembly, graphics, linker
configuration, license, and source tests under `source/`. No source or graphics
were modified. `SOURCE_MANIFEST.json` lists the URL and SHA-256 of every
downloaded source file. `PROVENANCE.json` records the exact compile/link steps.

With Python 3, ca65, and ld65 installed, run:

```sh
python3 build.py
```

This builds `source/2048.nes` and checks its digest against the packaged ROM.
The original Makefile can also build the cartridge with `make 2048.nes` from
`source/`. Building the game is optional; the install package already contains
the verified cartridge.

Use the directional pad to move and merge tiles. This implementation includes
tiles beginning at 1, as defined in the author's `TileDefinitions` table.
