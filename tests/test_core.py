"""Native-core safety boundaries and small, original 6502 conformance fixtures."""

import array
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps" / "nes"
# Loading the core directly avoids importing the firmware-only app entrypoint.
sys.path.insert(0, str(APP))
import cartridge
spec = importlib.util.spec_from_file_location("nes_core_under_test", APP / "emu.py")
emu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(emu)


def rom_bytes(program=b"", mapper=0, prg_banks=1, chr_banks=1, flags=0):
    header = bytearray(b"NES\x1a" + bytes(12))
    header[4:8] = bytes((prg_banks, chr_banks, ((mapper & 15) << 4) | flags, mapper & 0xf0))
    prg = bytearray(b"\xea" * (prg_banks * 16384))
    prg[:len(program)] = program
    loop = len(program)
    prg[loop:loop + 3] = bytes((0x4c, loop & 255, 0x80 + (loop >> 8)))
    for vector in (0x3ffa, 0x3ffc, 0x3ffe):
        prg[len(prg) - 16384 + vector:len(prg) - 16384 + vector + 2] = b"\x00\x80"
    chr_rom = b"".join(bytes((bank,)) * 8192 for bank in range(chr_banks))
    return header + prg + chr_rom


class CartridgeSafetyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "fixture.nes"

    def write_rom(self, data):
        self.path.write_bytes(data)
        return str(self.path)

    def test_supported_mapper_limits_load_without_resizing(self):
        for mapper, prg, chr_count in ((0, 1, 1), (0, 2, 0), (1, 1, 0),
                                       (1, 16, 16), (2, 16, 0), (3, 2, 4)):
            with self.subTest(mapper=mapper, prg=prg, chr=chr_count):
                core = emu.NES(self.write_rom(rom_bytes(mapper=mapper, prg_banks=prg, chr_banks=chr_count)))
                self.assertEqual(len(core.mem), 32768)
                self.assertEqual(len(core.prg), prg * 16384)
                self.assertEqual(len(core.chr_rom), chr_count * 8192)

    def test_rejects_malformed_and_unsupported_roms_before_native_code(self):
        good = rom_bytes()
        cases = [b"", good[:15], b"BAD!" + good[4:], good[:-1], good + b"x"]
        for byte, value in ((4, 0), (4, 3), (5, 3), (6, 4), (6, 8),
                            (7, 8), (7, 4), (7, 1), (7, 2), (8, 2),
                            (9, 1), (10, 1), (10, 2), (10, 0x20), (12, 1)):
            changed = bytearray(good)
            changed[byte] = value
            cases.append(changed)
        cases += [rom_bytes(mapper=4), rom_bytes(mapper=0, prg_banks=4),
                  rom_bytes(mapper=1, prg_banks=32), rom_bytes(mapper=1, chr_banks=32),
                  rom_bytes(mapper=2, prg_banks=1, chr_banks=0),
                  rom_bytes(mapper=2, prg_banks=2, chr_banks=1),
                  rom_bytes(mapper=3, chr_banks=0), rom_bytes(mapper=3, chr_banks=8)]
        for number, data in enumerate(cases):
            with self.subTest(case=number):
                with self.assertRaises(cartridge.CartridgeError):
                    emu.NES(self.write_rom(data))

    def test_sram_exact_size_and_atomic_failure_preserve_existing_data(self):
        memory = bytearray(32768)
        memory[0x4000:0x6000] = b"\xab" * 8192
        path = str(Path(self.directory.name) / "game.sav")
        self.assertFalse(cartridge.load_sram(path, memory))
        self.assertTrue(cartridge.save_sram(path, memory))
        self.assertEqual(Path(path).read_bytes(), b"\xab" * 8192)
        memory[0x4000:0x6000] = bytes(8192)
        self.assertTrue(cartridge.load_sram(path, memory))
        self.assertEqual(memory[0x4000:0x6000], b"\xab" * 8192)
        with patch.object(cartridge.os, "rename", side_effect=OSError("simulated rename failure")):
            with self.assertRaises(OSError):
                cartridge.save_sram(path, bytearray(32768))
        self.assertEqual(Path(path).read_bytes(), b"\xab" * 8192)
        self.assertFalse(Path(path + ".tmp").exists())
        for data in (b"", bytes(8191), bytes(8193), bytes(65536)):
            Path(path).write_bytes(data)
            before = bytes(memory)
            with self.assertRaises(cartridge.CartridgeError):
                cartridge.load_sram(path, memory)
            self.assertEqual(bytes(memory), before)
            self.assertEqual(len(memory), 32768)

    def test_full_states_are_never_deserialized_or_saved(self):
        path = self.write_rom(rom_bytes())
        with self.assertRaises(ValueError):
            emu.NES(path, state_path=str(self.path) + ".state")
        core = emu.NES(path)
        before = core.st.tolist()
        self.assertFalse(core.load_state())
        self.assertFalse(core.save_state())
        self.assertEqual(core.st.tolist(), before)

    def test_renderer_checks_writable_buffer_lengths_before_viper(self):
        core = emu.NES(self.write_rom(rom_bytes()))
        frame = bytearray(320 * 240 * 2)
        palette = array.array("H", range(32))
        for fb, pal in ((frame[:-1], palette), (frame, palette[:-1]), (bytes(frame), palette),
                        ([0] * len(frame), palette), (memoryview(frame)[::2], palette)):
            with self.assertRaises(ValueError):
                core.render(fb, pal)
        with self.assertRaises(ValueError):
            core.render(frame, palette, pixel_bytes=1)
        core.render(frame, palette)
        self.assertEqual(len(frame), 320 * 240 * 2)


class OpcodeAndMapperTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)

    def core(self, program=b"", **kwargs):
        path = Path(self.directory.name) / "fixture.nes"
        path.write_bytes(rom_bytes(program, **kwargs))
        return emu.NES(str(path))

    def test_add_subtract_flags_and_stack(self):
        # 0x7f + 1 -> 0x80, overflow; 0 - 1 -> 0xff, borrow.
        core = self.core(bytes.fromhex("a9 7f 18 69 01 85 10 08 68 85 11 a9 00 38 e9 01 85 12 08 68 85 13"))
        core.step_frame()
        self.assertEqual(core.mem[0x10], 0x80)
        self.assertEqual(core.mem[0x11] & 0xc3, 0xc0)
        self.assertEqual(core.mem[0x12], 0xff)
        self.assertEqual(core.mem[0x13] & 0xc3, 0x80)
        self.assertEqual(core.st[emu.REG_SP], 0xfd)

    def test_jsr_rts_and_loop(self):
        core = self.core(bytes.fromhex("20 09 80 85 20 4c 05 80 ea a9 42 60"))
        core.step_frame()
        self.assertEqual(core.mem[0x20], 0x42)
        self.assertEqual(core.st[emu.REG_SP], 0xfd)

    def test_controller_latch_reads_each_button_and_simultaneous_actions(self):
        # Original 6502 fixture: strobe $4016 high/low, then store eight serial
        # bits at $10-$17. Bit order is A, B, Select, Start, Up, Down, Left, Right.
        program = bytes.fromhex('a9 01 8d 16 40 a9 00 8d 16 40 a2 00 '
                                'ad 16 40 29 01 95 10 e8 e0 08 d0 f4')
        for mask in (0, 1, 2, 4, 8, 16, 32, 64, 128, 3, 129, 131):
            with self.subTest(mask=mask):
                core = self.core(program)
                core.step_frame(mask)
                self.assertEqual(list(core.mem[0x10:0x18]), [(mask >> bit) & 1 for bit in range(8)])

    def test_brk_pushes_pc_plus_two_and_returns_with_rti(self):
        core = self.core(bytes.fromhex("00 ea a9 77 85 20 4c 06 80"))
        core.prg[0x100:0x103] = bytes.fromhex("e6 21 40")
        core.prg[-2:] = b"\x00\x81"
        core.step_frame()
        self.assertEqual(core.mem[0x20], 0x77)
        self.assertEqual(core.mem[0x21], 1)
        self.assertEqual(core.st[emu.REG_SP], 0xfd)

    def test_operand_fetch_wraps_cpu_address_space(self):
        core = self.core()
        core.st[emu.REG_PC] = 0xffff
        core.prg[-1] = 0xa9  # LDA immediate; operand is CPU RAM address zero.
        core.mem[:6] = bytes.fromhex("42 85 20 4c 03 00")
        core.step_frame()
        self.assertEqual(core.mem[0x20], 0x42)

    def test_cnrom_high_bank_bits_cannot_resize_memory(self):
        core = self.core(bytes.fromhex("a9 ff 8d 00 80"), mapper=3, chr_banks=4)
        core.step_frame()
        self.assertEqual(core.mem[0x2000:0x4000], b"\x03" * 8192)
        self.assertEqual(len(core.mem), 32768)

    def test_mmc1_single_prg_bank_stays_in_bounds_after_control_change(self):
        # Write five zero bits to control: 32 KiB PRG mode mirrors the 16 KiB ROM.
        core = self.core(bytes.fromhex("a9 00 " + "8d 00 80 " * 5), mapper=1)
        core.step_frame()
        self.assertEqual(core.st[emu.REG_PRG_B0_OFF], 0)
        self.assertEqual(core.st[emu.REG_PRG_B1_OFF], 0)
        self.assertEqual(len(core.mem), 32768)

    def test_reset_clears_mapper_registers_but_keeps_sram(self):
        core = self.core(mapper=1)
        core.mem[0x4000] = 0xa5
        core.st[emu.REG_MMC1_COUNT] = 4
        core.st[emu.REG_MMC1_CTRL] = 0
        core.reset_console()
        self.assertEqual(core.mem[0x4000], 0xa5)
        self.assertEqual(core.st[emu.REG_MMC1_COUNT], 0)
        self.assertEqual(core.st[emu.REG_MMC1_CTRL], 0x0c)


if __name__ == "__main__":
    unittest.main()
