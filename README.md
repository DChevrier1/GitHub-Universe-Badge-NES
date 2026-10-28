# NES for the GitHub Universe Badge

An experimental, silent NES emulator for the Universe 2026 Badger 2350.
Browse a small homebrew library, play with the badge controls, and return to the
supplied launcher with the physical Home button. The app uses the stock clock;
it does not overclock the badge or replace its firmware.

## On the badge

| Game library | 2048 |
| --- | --- |
| ![Native badge game library listing the three included homebrew games](screenshots/library.png) | ![2048 puzzle board rendered by the native badge emulator](screenshots/2048.png) |

| Falling | Minekart Madness |
| --- | --- |
| ![Falling active platform gameplay rendered on the native badge](screenshots/falling.png) | ![Minekart Madness active gameplay rendered on the native badge](screenshots/minekart-madness.png) |

Real 320 × 240 framebuffer captures from the badge, with verified byte counts and
checksums. These are native app captures, not browser mockups. A captured frame
does not establish full-speed play or complete game compatibility.

## Compatibility and current limits

The core supports selected iNES NTSC cartridges using mappers **0, 1, 2 and 3**.
Mapper support alone does not guarantee that a game will play correctly. This is
a small badge emulator with selective compatibility, not a replacement for a
full desktop emulator.

Short scripted checks on a **230 MHz Badger 2350**, with **HIRES + VSYNC** on
2026-10-28, completed without emulator errors for all three included games:

| Game | Final display counter (fps) | Emulated average (fps) |
| --- | ---: | ---: |
| 2048 | 15 | 29.38 |
| Falling | 18 | 35.26 |
| Minekart Madness | 22 | 46.27 |

Each measured interval lasted about 10 seconds after 720 warm-up frames. The
display figure is the final one-second counter; the emulated average covers the
whole interval. These results are **below full speed**. They are short scripted
checks, not full playthroughs or a battery-runtime test. Separately, on 2026-10-28
the owner confirmed the display, opening games with A/Start, directional controls,
holding Start + Select for 700 ms to pause, and returning to the game library.
See [HARDWARE.json](HARDWARE.json) for the method, firmware, core hash, individual
results and manual confirmation.

The local companion's NES page shows these facts and current build readiness.
It is an installation and controls page; it does not emulate NES gameplay in your
browser.

- **Silent operation:** no audio synthesis or audio buffers.
- **Safe cartridge loading:** unsupported headers, sizes and mapper combinations
  are rejected before entering the accelerated core.
- **Game saves:** supported battery-backed SRAM is kept separately from game ROMs.
  Untrusted full emulator-state files are not loaded.
- **Stock system preserved:** the download contains only this custom app, reviewed
  games, licenses and documentation.

## Included games

<!-- BUNDLED_GAMES_START -->

| Game | Author | License |
| --- | --- | --- |
| [Falling](https://github.com/xram64/falling-nes/tree/52dcb8a951200562e696dfc2aba5d4d14edd0078) | Jesse Williams (tragicmuffin) | [MIT](apps/nes/licenses/falling-MIT.txt) |
| [Minekart Madness](https://github.com/mhughson/mbh-cart/tree/70f7fc710c1135c07e62927af6653b1373e47faa) | Matthew Hughson | [MIT](apps/nes/licenses/minekart-MIT.txt) |
| [2048](https://github.com/jmgregory/2048-nes/tree/e80a02a4d60b4e017ccbb14ae9230f933b7c2a44) | Justin Gregory | [MIT](apps/nes/licenses/2048-MIT.txt) |

<!-- BUNDLED_GAMES_END -->

Exact reviewed ROM checksums and source revisions are recorded in
[games.json](apps/nes/games.json). Each game's license is included with the app.
The [game provenance guide](apps/nes/provenance/README.md) includes the original
download references, Minekart's checked header normalization, and 2048's pinned
source and reproduction script. Game code and artwork are unchanged; Minekart's
three metadata bytes are the only alteration to its author-published cartridge.

Commercial ROMs and personal ROM collections are not included. Add other games
only when you have permission to use them, and keep those additions local to your
badge. The repository build packages only explicitly reviewed game files.

## Install in five steps

You need a **GitHub Universe 2026 Badger 2350**, its supplied firmware, and a USB
cable that carries data. No firmware flashing is required.

1. Download the repository using **Code → Download ZIP**, then extract it.
2. Open the badge's **USB Disk / Mass Storage** app and connect the USB cable.
   Wait for the **BADGER** drive to appear.
3. Back up any existing `apps/nes/` folder. Copy only the complete **`nes`** folder
   from this repository's `apps/` directory into **`BADGER/apps/`**. Keep every
   module, game, license and asset together.
4. Wait for copying to finish, safely eject the drive, then restart the badge.
5. Open **NES** from the supplied launcher and select a game from its library.

The final path is `BADGER/apps/nes/__init__.py`. The BADGER root already
represents the system volume; do not create another nested `system` directory.
Keep all stock apps, credentials, settings and unrelated files. Do not replace
the whole apps directory, format the drive, or flash a UF2.

To update or roll back, replace only the NES custom app folder after making a
verified local backup. To uninstall, remove only `apps/nes/`; preserve separate
save data unless you intentionally want to reset progress.

## Controls

| Badge control | During a game |
| --- | --- |
| Directional controls | NES D-pad |
| Back touch pad or physical Select | NES A |
| Select touch pad | NES B |
| Home touch pad | NES Start |
| Menu touch pad | NES Select |
| Hold NES Start + Select for 0.7 seconds | Open pause menu |
| Physical Home button | Return to the supplied launcher |

The Home touch pad and physical Home button have different roles. A + B can be
held together without opening the pause menu.

In the library, **Up / Down** chooses a game, **A or Start** plays it, and **B**
goes back. In the pause menu, **Up / Down** chooses an option, **A** confirms,
and **B** resumes the game. Release both pause-chord pads before pausing again.

Pause before using physical Home so the app can save battery-backed SRAM. If
**SAVE FAILED** appears, resolve the storage problem before leaving; the physical
Home button can still exit through the stock launcher. Failed saves retain SRAM
in memory but cannot protect it after power loss.

## Build and test

Python 3.9+ is needed only for local testing and packaging:

```sh
python3 -m unittest discover -s tests -v
python3 build.py
```

The build creates `dist/nes-badge.zip`. It contains only the allowlisted app,
reviewed game files, licenses and installation documents. Game checksums must
match the reviewed catalog; adding an unrelated ROM to the source directory does
not add it to the package. The build also verifies every included provenance
file against its pinned hash. Personal configuration, account data and save files
are excluded. Run optional game reproduction tools in a separate working copy;
their generated objects and rebuilt cartridges are not export inputs.

## Troubleshooting

- **No BADGER drive:** open USB Disk / Mass Storage and use a data-capable cable.
- **App missing:** check the exact folder path and avoid double-nested folders.
- **Game rejected:** check the cartridge format and supported mapper/size limits.
  Renaming a ROM does not make an unsupported cartridge compatible.
- **Visual errors or slow play:** compatibility and speed are game-dependent.
  Use the physical Home button to leave the app if necessary.
- **No sound:** the emulator is intentionally silent.

## Credits and maintenance

**Created with AI by DChevrier1.** The accelerated core derives from Steve
Francia's MIT-licensed work. See [upstream provenance](apps/nes/UPSTREAM.md), the
[upstream license](apps/nes/LICENSE_upstream.txt), and [NOTICE.md](NOTICE.md).
NES is a Nintendo trademark; this unofficial app is not endorsed by Nintendo,
GitHub or Pimoroni.

Update README/help and relevant verification with each completed change. Keep
personal ROM collections, saves and device backups outside version control.
