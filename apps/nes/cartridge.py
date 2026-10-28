"""Bounded iNES 1 loader and 8 KiB SRAM persistence for the badge NES core.

ROM metadata is untrusted: reject unsupported board layouts before handing any
buffers to Viper, whose pointer accesses do not perform Python bounds checks.
"""

import os

SRAM_BYTES = 8192
MEMORY_BYTES = 32768


class CartridgeError(ValueError):
    pass


def _power_of_two(value):
    return value > 0 and not (value & (value - 1))


def parse_header(header, file_size):
    if len(header) != 16 or header[:4] != b"NES\x1a":
        raise CartridgeError("Not an iNES cartridge (NES header missing)")
    flags6, flags7 = header[6], header[7]
    if flags7 & 0x0c:
        raise CartridgeError("Only iNES 1.0 cartridges are supported")
    if flags7 & 3:
        raise CartridgeError("VS System and PlayChoice cartridges are unsupported")
    if flags6 & 4:
        raise CartridgeError("Cartridges with a trainer are unsupported")
    if flags6 & 8:
        raise CartridgeError("Four-screen mirroring is unsupported")
    if header[9] or header[10] & 3:
        raise CartridgeError("Only NTSC cartridges are supported")
    if header[10] & 0xfc or any(header[11:16]):
        raise CartridgeError("Unsupported or dirty iNES header")
    if header[8] > 1:
        raise CartridgeError("At most 8 KiB of cartridge RAM is supported")

    mapper = (flags7 & 0xf0) | (flags6 >> 4)
    prg_banks, chr_banks = header[4], header[5]
    if mapper not in (0, 1, 2, 3):
        raise CartridgeError("Unsupported mapper %d (supported: 0, 1, 2, 3)" % mapper)
    if not _power_of_two(prg_banks):
        raise CartridgeError("PRG ROM must have a nonzero power-of-two bank count")
    if chr_banks and not _power_of_two(chr_banks):
        raise CartridgeError("CHR ROM must have a power-of-two bank count")
    # Standard boards only: no SUROM/SXROM, UNROM-512, or CNROM protection.
    if mapper == 0 and (prg_banks not in (1, 2) or chr_banks > 1):
        raise CartridgeError("NROM requires 16/32 KiB PRG and at most 8 KiB CHR")
    if mapper == 1 and (prg_banks > 16 or chr_banks > 16):
        raise CartridgeError("MMC1 supports at most 256 KiB PRG and 128 KiB CHR")
    if mapper == 2 and (prg_banks < 2 or prg_banks > 16 or chr_banks):
        raise CartridgeError("UxROM requires 32-256 KiB PRG and 8 KiB CHR RAM")
    if mapper == 3 and (prg_banks not in (1, 2) or chr_banks not in (1, 2, 4)):
        raise CartridgeError("CNROM requires 16/32 KiB PRG and 8-32 KiB CHR")

    prg_bytes, chr_bytes = prg_banks * 16384, chr_banks * 8192
    expected = 16 + prg_bytes + chr_bytes
    if file_size != expected:
        raise CartridgeError("Cartridge size mismatch: expected %d bytes, got %d" %
                             (expected, file_size))
    return {"mapper": mapper, "prg_bytes": prg_bytes,
            "chr_bytes": chr_bytes, "battery": bool(flags6 & 2),
            "mirroring": flags6 & 1, "size": expected}


def inspect_rom(path):
    with open(path, "rb") as stream:
        header = stream.read(16)
        stream.seek(0, 2)
        size = stream.tell()
    return parse_header(header, size)


def _read_into(stream, target):
    """Bounded reads cannot resize the bytearrays passed to native pointers."""
    view = memoryview(target)
    offset = 0
    while offset < len(view):
        amount = min(4096, len(view) - offset)
        chunk = stream.read(amount)
        if not chunk:
            raise CartridgeError("Cartridge was truncated during loading")
        view[offset:offset + len(chunk)] = chunk
        offset += len(chunk)


def load_rom(path):
    # Validate and read through the same file handle so a path replacement
    # cannot substitute an unchecked cartridge between inspection and loading.
    with open(path, "rb") as stream:
        header = stream.read(16)
        stream.seek(0, 2)
        info = parse_header(header, stream.tell())
        stream.seek(16)
        prg = bytearray(info["prg_bytes"])
        chr_rom = bytearray(info["chr_bytes"])
        _read_into(stream, prg)
        _read_into(stream, chr_rom)
        if stream.read(1):
            raise CartridgeError("Cartridge changed during loading")
    return info, prg, chr_rom


def _sram_window(memory):
    if not isinstance(memory, bytearray) or len(memory) != MEMORY_BYTES:
        raise CartridgeError("SRAM requires the fixed 32 KiB emulator memory")
    return memoryview(memory)[0x4000:0x6000]


def load_sram(path, memory):
    target = _sram_window(memory)
    try:
        with open(path, "rb") as stream:
            data = stream.read(SRAM_BYTES + 1)
    except OSError as error:
        if error.args and error.args[0] == 2:
            return False
        raise
    if len(data) != SRAM_BYTES:
        raise CartridgeError("Save file must be exactly 8192 bytes")
    target[:] = data
    return True


def save_sram(path, memory):
    """Replace a complete save atomically; never delete the previous save first.

    The caller creates its app-specific save directory. A filesystem that cannot
    replace through rename reports an error while leaving the old save intact.
    """
    target = _sram_window(memory)
    temporary = path + ".tmp"
    try:
        with open(temporary, "wb") as stream:
            written = stream.write(target)
            if written != SRAM_BYTES:
                raise OSError("Incomplete SRAM write")
            stream.flush()
        if os.stat(temporary)[6] != SRAM_BYTES:
            raise OSError("Incomplete SRAM file")
        os.rename(temporary, path)
    except (OSError, ValueError):
        try:
            os.remove(temporary)
        except OSError:
            pass
        raise
    return True
