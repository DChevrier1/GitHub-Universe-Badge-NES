# Emulator provenance

The accelerated 6502/PPU core derives from Steve Francia's MIT-licensed
[Universe 2026 Badge Hacks](https://github.com/spf13/universe-2026-badge-hacks),
commit `fd83dde7ac6562ac8a440fa6d39b4f980b5a2239`. See LICENSE_upstream.txt.

This app has its own launcher, controller handling and paced rendering. It does
not install upstream branding, other apps, stock firmware, ROM profiles or ROMs.
The original core is modified for validated cartridge loading, bounded bank
switching, safe SRAM persistence and disabled untrusted full-state imports.

No audio synthesis or audio buffers are included. Cartridge support is limited
to tested subsets of iNES NTSC mappers 0/1/2/3 and experimental standard MMC3B-style
mapper 4; that is not a promise of compatibility with every game using those
mappers. No overclock is performed.

The separate MMC3 module adds bounded 8 KiB PRG and 1 KiB CHR mapping, mapper IRQs,
RAM protection and row-based rendering, following the [NESdev MMC3 register
description](https://www.nesdev.org/wiki/MMC3) and [CPU interrupt behavior](https://www.nesdev.org/wiki/CPU_interrupts).
It supports 32–512 KiB PRG and 8–256 KiB CHR ROM with power-of-two bank counts.
MMC6, CHR RAM and four-screen boards are excluded. CPU/PPU scheduling and A12
filtering are approximate; cycle-perfect raster effects and full-speed play are
not claimed. Original synthetic tests cover bank boundaries, RAM protection,
mirroring and interrupt behavior without using commercial game bytes.
