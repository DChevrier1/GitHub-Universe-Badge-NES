# Bundled game provenance

These three homebrew games are distributed under their authors' MIT licenses.
Each directory preserves the copyright notice, source revision, file hashes,
and any build or conversion steps. The games are separate works from the badge
emulator. They are not a ranking of commercial NES titles.

| Game | Author | Included cartridge | Preparation |
| --- | --- | --- | --- |
| Falling | Jesse Williams / tragicmuffin | `roms/falling.nes` | Original author-published ROM, unchanged |
| Minekart Madness | Matthew Hughson | `roms/minekart-madness.nes` | Three header bytes normalized to equivalent iNES 1.0 metadata; all game code and assets unchanged |
| 2048 | Justin Gregory | `roms/2048.nes` | Built from the pinned original source with ca65/ld65 |

Refer to each game's `PROVENANCE.json` and `LICENSE.txt`. Cartridge names in an
upstream manifest identify the original download; the badge catalog identifies
the installed filename. Games remain silent because this emulator has no APU.
Header compatibility and successful test frames do not establish perfect game
compatibility; see the app README for the actual validation record.
