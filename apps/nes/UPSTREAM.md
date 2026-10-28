# Emulator provenance

The accelerated 6502/PPU core derives from Steve Francia's MIT-licensed
[Universe 2026 Badge Hacks](https://github.com/spf13/universe-2026-badge-hacks),
commit `fd83dde7ac6562ac8a440fa6d39b4f980b5a2239`. See LICENSE_upstream.txt.

This app has its own launcher, controller handling and paced rendering. It does
not install upstream branding, other apps, stock firmware, ROM profiles or ROMs.
The original core is modified for validated cartridge loading, bounded bank
switching, safe SRAM persistence and disabled untrusted full-state imports.

No audio synthesis or audio buffers are included. Cartridge support is limited
to tested subsets of iNES NTSC mapper 0/1/2/3; that is not a promise of compatibility
with every game using those mappers. No overclock is performed.
