"""Original synthetic mapper checks; no external cartridge bytes.

Specifications: https://www.nesdev.org/wiki/MMC3
https://www.nesdev.org/wiki/Programming_MMC3
https://www.nesdev.org/wiki/CPU_interrupts

The core's >=10-dot A12 approximation is tested only with unambiguous
short/long intervals. This is not a cycle-accurate or hardware conformance claim.
"""
import array
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps" / "nes"
sys.path.insert(0, str(APP))
import emu_mmc3 as m
from cartridge_mmc3 import parse_header, CartridgeError


def original_cartridge(program=b'', prg_pages=8, chr_pages=16):
    """Original tags and instructions; pages are 8 KiB PRG and 1 KiB CHR."""
    assert prg_pages >= 4 and prg_pages & (prg_pages - 1) == 0
    assert chr_pages >= 8 and chr_pages & (chr_pages - 1) == 0
    header = bytearray(b'NES\x1a' + bytes(12))
    header[4:8] = bytes((prg_pages // 2, chr_pages // 8, 0x42, 0))
    prg = bytearray(b''.join(bytes((page,)) * 8192 for page in range(prg_pages)))
    base = len(prg) - 8192
    prg[base:base + len(program)] = program
    stop = 0xe000 + len(program)
    prg[base + len(program):base + len(program) + 3] = bytes((0x4c, stop & 255, stop >> 8))
    for vector in (0x1ffa, 0x1ffc, 0x1ffe):
        prg[base + vector:base + vector + 2] = b'\x00\xe0'
    chr_rom = b''.join(bytes((page,)) * 1024 for page in range(chr_pages))
    return bytes(header) + prg + chr_rom


class SyntheticMapperTests(unittest.TestCase):
    def test_loader_limits_mmc3_to_reviewed_standard_boards(self):
        def header(prg, chr_count):
            data = bytearray(b'NES\x1a' + bytes(12))
            data[4:8] = bytes((prg, chr_count, 0x42, 0))
            return data
        for prg in (2, 4, 8, 16, 32):
            for chr_count in (1, 2, 4, 8, 16, 32):
                info = parse_header(header(prg, chr_count), 16 + prg * 16384 + chr_count * 8192)
                self.assertEqual(info['mapper'], 4)
        for prg, chr_count in ((1, 1), (3, 1), (64, 1), (2, 0), (2, 3), (2, 64)):
            with self.subTest(prg=prg, chr=chr_count):
                with self.assertRaises(CartridgeError):
                    parse_header(header(prg, chr_count), 16 + prg * 16384 + chr_count * 8192)
        for byte, value in ((6, 0x46), (6, 0x4a), (7, 8), (8, 2), (9, 1)):
            data = header(2, 1)
            data[byte] = value
            with self.assertRaises(CartridgeError):
                parse_header(data, 16 + 32768 + 8192)

    def state(self, prg=8, chr_pages=16):
        st = array.array('i', [0] * 128)
        st[m.M3_PRG_MASK] = prg - 1
        st[m.M3_CHR_MASK] = chr_pages - 1
        for i, value in enumerate((0, 2, 4, 5, 6, 7, 0, 1)):
            st[m.M3_R0 + i] = value
        m.mmc3_map(st)
        return st

    def bank(self, st, register, value, mode=0):
        m.mmc3_write(st, 0x8000, mode | register)
        m.mmc3_write(st, 0x8001, value)

    def prg(self, st):
        return tuple(st[m.M3_PRG0 + i] // 8192 for i in range(4))

    def chr(self, st):
        return tuple(st[m.M3_CHR0 + i] // 1024 for i in range(8))

    def test_prg_mode_write_immediately_swaps_only_first_and_third_windows(self):
        st = self.state()
        self.bank(st, 6, 1)
        self.bank(st, 7, 3)
        self.assertEqual(self.prg(st), (1, 3, 6, 7))
        m.mmc3_write(st, 0x8000, 0x40)
        self.assertEqual(self.prg(st), (6, 3, 1, 7))
        m.mmc3_write(st, 0x8000, 0)
        self.assertEqual(self.prg(st), (1, 3, 6, 7))

    def test_chr_pairs_align_even_and_mode_inverts_the_two_halves(self):
        st = self.state()
        for index, value in enumerate((3, 7, 9, 11, 13, 15)):
            self.bank(st, index, value)
        self.assertEqual(self.chr(st), (2, 3, 6, 7, 9, 11, 13, 15))
        m.mmc3_write(st, 0x8000, 0x80)
        self.assertEqual(self.chr(st), (9, 11, 13, 15, 2, 3, 6, 7))

    def test_register_and_physical_address_masks_keep_all_offsets_in_bounds(self):
        for count in (4, 8, 16, 64):
            st = self.state(prg=count, chr_pages=256)
            for mode in (0, 0x40, 0x80, 0xc0):
                for value in (0, 1, 0x3f, 0x40, 0x7f, 0xff):
                    for register in range(8):
                        self.bank(st, register, value, mode)
                    self.assertTrue(all(0 <= offset <= (count - 1) * 8192
                                        and offset % 8192 == 0
                                        for offset in st[m.M3_PRG0:m.M3_PRG0 + 4]))
                    self.assertTrue(all(0 <= offset <= 255 * 1024 and offset % 1024 == 0
                                        for offset in st[m.M3_CHR0:m.M3_CHR0 + 8]))
                    r6_slot = 2 if mode & 0x40 else 0
                    self.assertEqual(self.prg(st)[r6_slot], (value & 0x3f) & (count - 1))
                    self.assertEqual(self.prg(st)[3], count - 1)
                    self.assertEqual(len(st), 128)
        st = self.state(chr_pages=8)
        for index in range(6):
            self.bank(st, index, 255)
        self.assertEqual(self.chr(st), (6, 7, 6, 7, 7, 7, 7, 7))

    def test_register_mirrors_decode_address_region_and_parity(self):
        st = self.state()
        m.mmc3_write(st, 0x9ffe, 0x36)  # ignored mode bits; select R6
        m.mmc3_write(st, 0x9fff, 5)
        self.assertEqual(self.prg(st), (5, 1, 6, 7))
        m.mmc3_write(st, 0xbffe, 0xfe)
        self.assertEqual(st[26], 1)  # MMC3 0 = vertical; core 1 = vertical.
        m.mmc3_write(st, 0xbffe, 0xff)
        self.assertEqual(st[26], 0)
        m.mmc3_write(st, 0xbfff, 0xff)
        self.assertEqual(st[m.M3_RAM], 0xc0)
        m.mmc3_write(st, 0xbfff, 0x3f)
        self.assertEqual(st[m.M3_RAM], 0)

    def test_irq_reload_is_deferred_and_latch_writes_do_not_reset_counter(self):
        st = self.state()
        m.mmc3_write(st, 0xc000, 2)
        m.mmc3_write(st, 0xc001, 123)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 0)
        self.assertEqual(st[m.M3_IRQ_RELOAD], 1)
        m.mmc3_write(st, 0xe001, 0)
        self.assertEqual(st[m.M3_IRQ_PENDING], 0)
        m.mmc3_irq_clock(st)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 2)
        m.mmc3_write(st, 0xc000, 7)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 2)
        m.mmc3_irq_clock(st)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 1)
        self.assertEqual(st[m.M3_IRQ_PENDING], 0)
        m.mmc3_irq_clock(st)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 0)
        self.assertEqual(st[m.M3_IRQ_PENDING], 1)
        m.mmc3_irq_clock(st)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 7)
        self.assertEqual(st[m.M3_IRQ_PENDING], 1)

    def test_disable_ack_does_not_stop_counter_and_enable_does_not_reset_it(self):
        st = self.state()
        m.mmc3_write(st, 0xc000, 2)
        m.mmc3_write(st, 0xe001, 0)
        for _ in range(3):
            m.mmc3_irq_clock(st)
        self.assertEqual(st[m.M3_IRQ_PENDING], 1)
        m.mmc3_write(st, 0xe000, 0xff)
        self.assertEqual((st[m.M3_IRQ_ENABLE], st[m.M3_IRQ_PENDING]), (0, 0))
        m.mmc3_irq_clock(st)
        m.mmc3_irq_clock(st)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 1)
        self.assertEqual(st[m.M3_IRQ_PENDING], 0)
        m.mmc3_write(st, 0xe001, 0)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 1)
        self.assertEqual(st[m.M3_IRQ_PENDING], 0)
        m.mmc3_irq_clock(st)
        self.assertEqual(st[m.M3_IRQ_PENDING], 1)

    def test_reload_and_enable_do_not_acknowledge_an_asserted_irq(self):
        st = self.state()
        st[m.M3_IRQ_PENDING] = 1
        m.mmc3_write(st, 0xc001, 0)
        m.mmc3_write(st, 0xe001, 0)
        self.assertEqual(st[m.M3_IRQ_PENDING], 1)
        m.mmc3_write(st, 0xe000, 0)
        self.assertEqual(st[m.M3_IRQ_PENDING], 0)

    def test_sharp_revision_zero_latch_reasserts_on_each_qualified_clock(self):
        st = self.state()
        m.mmc3_write(st, 0xc000, 0)
        m.mmc3_write(st, 0xc001, 0)
        for _ in range(3):
            m.mmc3_write(st, 0xe001, 0)
            self.assertEqual(st[m.M3_IRQ_PENDING], 0)
            m.mmc3_irq_clock(st)
            self.assertEqual(st[m.M3_IRQ_PENDING], 1)
            m.mmc3_write(st, 0xe000, 0)

    def test_a12_filter_rejects_short_lows_and_steady_highs(self):
        st = self.state()
        st[m.M3_IRQ_COUNTER] = 5
        st[m.M3_A12] = 1
        m.mmc3_a12(st, 0, 1)
        m.mmc3_a12(st, 0x1000, 5)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 5)
        m.mmc3_a12(st, 0x1000, 100)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 5)
        m.mmc3_a12(st, 0, 101)
        m.mmc3_a12(st, 0, 111)  # Still low; must not restart the interval.
        m.mmc3_a12(st, 0x1000, 113)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 4)
        m.mmc3_a12(st, 0x1fff, 200)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 4)

    def test_a12_elapsed_time_wraps_without_losing_a_valid_edge(self):
        st = self.state()
        st[m.M3_IRQ_COUNTER] = 3
        st[m.M3_A12] = 1
        m.mmc3_a12(st, 0, (1 << 30) - 6)
        m.mmc3_a12(st, 0x1000, 6)
        self.assertEqual(st[m.M3_IRQ_COUNTER], 2)


class SyntheticExecutionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.e = m

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='original-mmc3-fixture-')
        self.addCleanup(self.directory.cleanup)

    def core(self, program=b'', **kwargs):
        data = original_cartridge(program, **kwargs)
        path = Path(self.directory.name) / 'original-fixture.nes'
        path.write_bytes(data)
        return self.e.NES(str(path))

    @staticmethod
    def write(address, value):
        return bytes((0xa9, value & 255, 0x8d, address & 255, address >> 8))

    @staticmethod
    def read(address, target):
        return bytes((0xad, address & 255, address >> 8, 0x85, target))

    def bank(self, register, value, mode=0):
        return self.write(0x8000, register | mode) + self.write(0x8001, value)

    def ppu_read(self, address, target):
        return (b'\xad\x02\x20' + self.write(0x2006, address >> 8)
                + self.write(0x2006, address & 255) + b'\xad\x07\x20'
                + self.read(0x2007, target))

    def test_cpu_reads_follow_eight_kib_mapping_and_mode_change(self):
        program = self.bank(6, 1) + self.bank(7, 3)
        for index, address in enumerate((0x8000, 0xa000, 0xc000, 0xe800)):
            program += self.read(address, 0x10 + index)
        program += self.write(0x8000, 0x40)
        for index, address in enumerate((0x8000, 0xa000, 0xc000, 0xe800)):
            program += self.read(address, 0x14 + index)
        core = self.core(program)
        core.step_frame()
        self.assertEqual(list(core.mem[0x10:0x18]), [1, 3, 6, 7, 6, 3, 1, 7])
        self.assertEqual(len(core.mem), 32768)

    def test_cpu_operand_fetch_can_cross_an_eight_kib_boundary(self):
        core = self.core()
        e = self.e
        # LDA immediate at $9FFF: opcode from bank 0, operand from bank 3.
        self.e.mmc3_write(core.st, 0x8000, 7)
        self.e.mmc3_write(core.st, 0x8001, 3)
        core.prg[0x1fff] = 0xa9
        core.prg[3 * 8192:3 * 8192 + 6] = b'\x5a\x85\x20\x4c\x03\xa0'
        core.st[e.REG_PC] = 0x9fff
        core.step_frame()
        self.assertEqual(core.mem[0x20], 0x5a)

    def test_ppu_reads_follow_chr_mapping_and_inversion(self):
        program = b''
        for register, value in enumerate((3, 7, 9, 11, 13, 15)):
            program += self.bank(register, value)
        for slot in range(8):
            program += self.ppu_read(slot * 1024, 0x40 + slot)
        program += self.write(0x8000, 0x80)
        for slot in range(8):
            program += self.ppu_read(slot * 1024, 0x48 + slot)
        core = self.core(program)
        core.step_frame()
        self.assertEqual(list(core.mem[0x40:0x48]), [2, 3, 6, 7, 9, 11, 13, 15])
        self.assertEqual(list(core.mem[0x48:0x50]), [9, 11, 13, 15, 2, 3, 6, 7])
        self.assertEqual(len(core.chr_rom), 16384)

    def test_sram_enable_and_protect_control_actual_bus_writes(self):
        program = self.write(0xa001, 0x80) + self.write(0x6000, 0x41)
        program += self.read(0x6000, 0x50)
        program += self.write(0xa001, 0xc0) + self.write(0x6000, 0x42)
        program += self.read(0x6000, 0x51)
        program += self.write(0xa001, 0x00) + self.write(0x6000, 0x43)
        program += self.read(0x6000, 0x52)
        program += self.write(0xa001, 0x80) + self.read(0x6000, 0x53)
        core = self.core(program)
        core.step_frame()
        self.assertEqual(core.mem[0x50], 0x41)
        self.assertEqual(core.mem[0x51], 0x41)
        self.assertNotEqual(core.mem[0x52], 0x41, 'Disabled RAM must not reveal its stored byte')
        self.assertEqual(core.mem[0x53], 0x41)
        self.assertEqual(core.mem[0x4000], 0x41)

    def test_irq_cli_delay_stack_vector_ack_and_rti_resume(self):
        core = self.core(b'\x58\xea\xa9\x41\x85\x20')
        e = self.e
        last = len(core.prg) - 8192
        handler = bytes.fromhex('ba bd 01 01 85 30 bd 02 01 85 31 bd 03 01 85 32 a9 00 8d 00 e0 e6 33 40')
        core.prg[last + 0x100:last + 0x100 + len(handler)] = handler
        core.prg[last + 0x1ffe:last + 0x2000] = b'\x00\xe1'
        core.st[e.M3_IRQ_PENDING] = 1
        core.st[e.M3_IRQ_ENABLE] = 1
        core.step_frame()
        self.assertEqual(core.mem[0x20], 0x41)
        self.assertEqual(core.mem[0x30] & 0x34, 0x20, 'IRQ pushes pre-entry I, B clear and bit 5 set')
        self.assertEqual((core.mem[0x31], core.mem[0x32]), (0x02, 0xe0), 'CLI must allow one NOP before servicing pending IRQ')
        self.assertEqual(core.mem[0x33], 1)
        self.assertEqual(core.st[e.REG_SP], 0xfd)
        self.assertEqual(core.st[e.M3_IRQ_PENDING], 0)
        self.assertEqual(core.st[e.M3_IRQ_COUNT], 1)

    def test_interrupt_disable_masks_irq_without_clearing_pending_level(self):
        core = self.core(b'\x78\xa9\x56\x85\x20')
        e = self.e
        core.st[e.M3_IRQ_PENDING] = 1
        core.step_frame()
        self.assertEqual(core.mem[0x20], 0x56)
        self.assertEqual(core.st[e.M3_IRQ_COUNT], 0)
        self.assertEqual(core.st[e.M3_IRQ_PENDING], 1)
        self.assertEqual(core.st[e.REG_SP], 0xfd)

    def test_mirroring_register_changes_actual_nametable_aliases(self):
        for setting, expected in ((0, [0x33, 0x44, 0x33, 0x44]),
                                  (1, [0x22, 0x22, 0x44, 0x44])):
            with self.subTest(setting=setting):
                program = self.write(0xa000, setting)
                for address, value in zip((0x2000, 0x2400, 0x2800, 0x2c00), (0x11, 0x22, 0x33, 0x44)):
                    program += (self.write(0x2006, address >> 8)
                                + self.write(0x2006, 0) + self.write(0x2007, value))
                for slot, address in enumerate((0x2000, 0x2400, 0x2800, 0x2c00)):
                    program += self.ppu_read(address, 0x60 + slot)
                core = self.core(program)
                core.step_frame()
                self.assertEqual(list(core.mem[0x60:0x64]), expected)

    def test_irq_is_level_sensitive_and_repeats_without_acknowledgment(self):
        core = self.core(b'\x58\xea')
        e = self.e
        last = len(core.prg) - 8192
        core.prg[last + 0x100:last + 0x103] = b'\xe6\x33\x40'
        core.prg[last + 0x1ffe:last + 0x2000] = b'\x00\xe1'
        core.st[e.M3_IRQ_PENDING] = 1
        core.step_frame()
        self.assertGreater(core.st[e.M3_IRQ_COUNT], 1)
        self.assertEqual(core.st[e.M3_IRQ_PENDING], 1)

    def test_nmi_has_priority_and_does_not_discard_pending_mapper_irq(self):
        core = self.core(b'\xea')
        e = self.e
        last = len(core.prg) - 8192
        nmi = bytes.fromhex('e6 30 40')
        irq = bytes.fromhex('a5 30 85 31 a9 00 8d 00 e0 e6 32 40')
        core.prg[last + 0x100:last + 0x100 + len(nmi)] = nmi
        core.prg[last + 0x200:last + 0x200 + len(irq)] = irq
        core.prg[last + 0x1ffa:last + 0x1ffc] = b'\x00\xe1'
        core.prg[last + 0x1ffe:last + 0x2000] = b'\x00\xe2'
        core.st[e.REG_P] = 0x20
        core.st[e.M3_POLL_I] = 0
        core.st[e.REG_NMI_PENDING] = 1
        core.st[e.M3_IRQ_PENDING] = 1
        core.step_frame()
        self.assertEqual(tuple(core.mem[0x30:0x33]), (1, 1, 1))
        self.assertEqual(core.st[e.M3_IRQ_COUNT], 1)
        self.assertEqual(core.st[e.REG_SP], 0xfd)


if __name__ == '__main__':
    unittest.main()
