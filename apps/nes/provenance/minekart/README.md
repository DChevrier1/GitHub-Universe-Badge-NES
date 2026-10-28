# Minekart Madness

An arcade mine-cart game by Matthew Hughson. The original v1.0 release and
source are covered by the MIT license preserved in `LICENSE.txt`.

- Source: https://github.com/mhughson/mbh-cart
- Release: https://github.com/mhughson/mbh-cart/releases/tag/v1.0
- Revision: `70f7fc710c1135c07e62927af6653b1373e47faa`
- Original asset: `minekart_madness_mmc1.nes`, 262,160 bytes.
- Original SHA-256: `45d18d8b3662e6c08043759e550e658bcd23e48394a00f24de5e5fbe57e4900a`
- Packaged SHA-256: `7defa774cdf37c66e651e90cb6b20922ac20b4fc47135a3a40f633f255100663`

The release uses a NES 2.0 header for a standard MMC1 cartridge with 128 KiB
PRG, 128 KiB CHR, vertical mirroring, and 8 KiB battery-backed RAM. This badge
core accepts iNES 1.0 only. `normalize_header.py` changes header bytes 7, 8, and
10 to express the same supported cartridge layout in iNES 1.0. The 262,144
bytes of PRG and CHR remain byte-for-byte identical. This is a modified header,
not an unmodified copy of the author's complete cartridge file.

To reproduce it, download that exact release asset and run:

```sh
python3 normalize_header.py minekart_madness_mmc1.nes minekart-madness.nes
```

The script refuses every input except the reviewed original SHA-256 and checks
the output SHA-256. `INES1_CONVERSION.json` also records both headers and the
unchanged PRG/CHR digest.

The upstream project credits Shiru for neslib/FamiTone, nesdoug for the nesdoug
library, norill for Donut integration and mapper support, and JRoatch for Donut
compression. Source and credits remain available at the pinned revision.

Allow the title animation to finish before pressing Start. Follow the game's
on-screen controls after starting.
