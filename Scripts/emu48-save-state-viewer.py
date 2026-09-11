#!/usr/bin/env python3

"""
dump_e48.py - decode the readable state in an Emu48 .e48/.e49 file.

The parser supports:
  * the older 8648-byte Chipset_t found in older Emu48 state files
  * the newer 8712-byte Chipset_t in the current source
  * the optional macOS UI48 block
  * the optional CINF calculator-info NSKeyedArchive

All integer values in the state file are little-endian on the macOS build.

2026-09-11  Kyle Wadsten v1.0 - Update VERSION when updating script.

"""

import argparse
import struct
import plistlib
import sys
from pathlib import Path

VERSION = "1.0"

def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def i16(b, o):
    return struct.unpack_from("<h", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def i32(b, o):
    return struct.unpack_from("<i", b, o)[0]


def u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def saturn_reg(raw):
    # Emu48 stores Saturn registers as 16 individual nibbles.
    # Display them in conventional most-significant-nibble-first order.
    return "".join(f"{x:x}" for x in raw[::-1])


def hx(v, digits=0):
    return f"0x{v:0{digits}X}"


# ---------------------------------------------------------------------------
# NSKeyedArchiver / Calculator Info
# ---------------------------------------------------------------------------

def _decode_nskeyed_archive(blob):
    """Decode an NSKeyedArchiver Foundation object graph."""
    plist = plistlib.loads(blob)

    if not isinstance(plist, dict) or "$objects" not in plist:
        raise ValueError("not an NSKeyedArchiver object graph")

    objects = plist["$objects"]
    top = plist.get("$top", {})

    def uid_index(value):
        return value.data if isinstance(value, plistlib.UID) else None

    def decode_ref(ref, stack=None):
        stack = set() if stack is None else stack

        idx = uid_index(ref)

        if idx is None:
            return decode_value(ref, stack)

        if idx < 0 or idx >= len(objects):
            return f"<invalid UID {idx}>"

        if idx in stack:
            return f"<recursive UID {idx}>"

        obj = objects[idx]

        if obj is None:
            return None

        next_stack = set(stack)
        next_stack.add(idx)

        return decode_value(obj, next_stack)

    def class_name(obj):
        cls = obj.get("$class")

        # In an NSKeyedArchiver plist, $class is normally a UID pointing
        # into $objects, rather than an inline dictionary.
        if isinstance(cls, plistlib.UID):
            idx = cls.data

            if 0 <= idx < len(objects):
                cls = objects[idx]

        if isinstance(cls, dict):
            return cls.get("$classname") or (
                cls.get("$classes", [None])[0]
                if cls.get("$classes")
                else None
            )

        return None

    def decode_value(obj, stack):
        if isinstance(obj, list):
            return [decode_ref(v, stack) for v in obj]

        if not isinstance(obj, dict):
            return obj

        cname = class_name(obj)

        if cname in ("NSDictionary", "NSMutableDictionary"):
            keys = obj.get("NS.keys", [])
            vals = obj.get("NS.objects", [])

            return {
                str(decode_ref(k, stack)): decode_ref(v, stack)
                for k, v in zip(keys, vals)
            }

        if cname in ("NSArray", "NSMutableArray"):
            return [
                decode_ref(v, stack)
                for v in obj.get("NS.objects", [])
            ]

        if cname in ("NSString", "NSMutableString") and "NS.string" in obj:
            return obj["NS.string"]

        if cname in ("NSNumber", "NSCFNumber", "__NSCFNumber"):
            for key in ("NS.intval", "NS.longlongval", "NS.real"):
                if key in obj:
                    return obj[key]

        if cname in ("NSData", "NSMutableData", "NSConcreteData"):
            if "NS.data" in obj:
                return obj["NS.data"]

        # CalcRect is archived as an NSValue using @encode(CalcRect).
        if cname and "NSValue" in cname:
            result = {"__NSValue__": True}

            if "NS.objCType" in obj:
                result["objCType"] = obj["NS.objCType"]

            if "NS.bytes" in obj:
                raw = obj["NS.bytes"]

                if isinstance(raw, bytes):
                    result["bytes"] = raw.hex(" ")
                else:
                    result["bytes"] = raw

            # NSValue can encode simple structs such as CGRect directly.
            if "NS.rectval" in obj:
                result["rect"] = decode_ref(
                    obj["NS.rectval"],
                    stack,
                )

            return result

        result = {"__class__": cname or "<unknown>"}

        for key, value in obj.items():
            if not str(key).startswith("$"):
                result[str(key)] = decode_ref(value, stack)

        return result

    root_ref = top.get("root")

    if root_ref is None and top:
        root_ref = next(iter(top.values()))

    if root_ref is None:
        raise ValueError("archive has no root object")

    return decode_ref(root_ref)


def _print_calculator_info(info):
    if not isinstance(info, dict):
        print(f"  Decoded object: {info!r}")
        return

    for key in (
        "magic",
        "version",
        "title",
        "author",
        "model",
        "rom",
        "class",
        "displayModel",
        "path",
        "imagePath",
        "background",
        "offset",
        "size"
    ):
        if key not in info:
            continue

        value = info[key]

        if key == "offset":
          value = f"0x{value:08X}"

        if key == "size":
          value = str(value) + " bytes"
  
        if key == "background" and isinstance(value, dict):
            if value.get("rect") is not None:
                prtkey = "background rect:"
                print(f"{prtkey:18} {value.get('rect')}")
        else:
            dispkey = key + ":"
            print(f"{dispkey:18} {value}")


def parse_cinf(data, offset):
  """Parse the appended CINF calculator-info block."""
  
  if data[offset:offset + 4] != b"CINF":
    return offset
  
  print()
  print("Calculator Info (CINF)")
  print("----------------------")
  
  magic = data[offset:offset + 4]
  
  if len(data) < offset + 12:
    print(f"  magic:             {magic.decode('ascii', errors='replace')}")
    print(f"  offset:            0x{offset:08X}")
    print("  ERROR: truncated CINF header")
    return len(data)
  
  version, length = struct.unpack_from("<II", data, offset + 4)
  
  archive_start = offset + 12
  archive_end = archive_start + length
  cinf_size = 12 + length
  
  if archive_end > len(data):
    available = max(0, len(data) - archive_start)
    
    print(f"  Version:           {version}")
    print(
      f"  ERROR: truncated archive "
      f"({available} of {length} bytes)"
    )
    
    return len(data)
  
  archive = data[archive_start:archive_end]
  
  try:
    info = _decode_nskeyed_archive(archive)
    if isinstance(info, dict):
      info = {
        "magic": magic.decode("ascii", errors="replace"),
        "offset": offset,
        "size": cinf_size,
        "version": version,
        **info,
      }
    _print_calculator_info(info)
    
  except Exception as exc:
    print(f"  NSKeyedArchiver decode failed: {exc}")
    print(f"  Archive hex: {archive.hex(' ')}")
    
  return archive_end


# ---------------------------------------------------------------------------
# CHIPSET
# ---------------------------------------------------------------------------

def parse_chipset(c, size):
    """
    The 8648-byte legacy structure and 8712-byte current structure have the
    same fields through d0memory. The legacy version has 8128 bytes of
    d0memory; the current version has 8192.
    """

    if size not in (8648, 8712):
        raise ValueError(f"unsupported CHIPSET size: {size}")

    d0memory_size = 8128 if size == 8648 else 8192

    # These offsets are the 64-bit macOS ABI offsets.
    # Port pointers occupy 24..47 and PC starts at 48.
    f = {}

    f["nPosX"] = i16(c, 0)
    f["nPosY"] = i16(c, 2)
    f["type"] = chr(c[4])

    f["Port0Size"] = u32(c, 8)
    f["Port1Size"] = u32(c, 12)
    f["Port2Size"] = u32(c, 16)

    f["Port0_pointer"] = u64(c, 24)
    f["Port1_pointer"] = u64(c, 32)
    f["Port2_pointer"] = u64(c, 40)

    f["pc"] = u32(c, 48)
    f["d0"] = u32(c, 52)
    f["d1"] = u32(c, 56)
    f["rstkp"] = u32(c, 60)

    f["rstk"] = [
        u32(c, 64 + n * 4)
        for n in range(8)
    ]

    names = (
        "A",
        "B",
        "C",
        "D",
        "R0",
        "R1",
        "R2",
        "R3",
        "R4",
    )

    off = 96

    for name in names:
        f[name] = c[off:off + 16]
        off += 16

    f["ST"] = c[240:244]
    f["HST"] = c[244]
    f["P"] = c[245]
    f["out"] = u16(c, 246)
    f["in"] = u16(c, 248)

    off = 252

    for name in (
        "SoftInt",
        "Shutdn",
        "mode_dec",
        "inte",
        "intk",
        "intd",
        "carry",
    ):
        f[name] = i32(c, off)
        off += 4

    f["crc"] = u16(c, 280)
    f["wPort2Crc"] = u16(c, 282)
    f["wRomCrc"] = u16(c, 284)
    f["cycles"] = u32(c, 288)
    f["cycles_reserved"] = u32(c, 292)
    f["dwKdnCycles"] = u32(c, 296)

    f["Bank_FF"] = u32(c, 300)
    f["FlashRomState"] = u32(c, 304)
    f["cards_status"] = c[308]
    f["IORam"] = c[309:373]
    f["IOBase"] = u32(c, 376)
    f["IOCfig"] = i32(c, 380)

    off = 384

    for name in (
        "P0Base",
        "BSBase",
        "P1Base",
        "P2Base",
        "P0Size",
        "BSSize",
        "P1Size",
        "P2Size",
        "P0End",
        "BSEnd",
        "P1End",
        "P2End",
    ):
        f[name] = c[off]
        off += 1

    # Compiler padding brings the BOOL array to the next 4-byte boundary.
    off = 396

    for name in (
        "P0Cfig",
        "BSCfig",
        "P1Cfig",
        "P2Cfig",
        "P0Cfg2",
        "BSCfg2",
        "P1Cfg2",
        "P2Cfg2",
    ):
        f[name] = i32(c, off)
        off += 4

    f["t1"] = c[428]
    f["t2"] = u32(c, 432)
    f["bShutdnWake"] = i32(c, 436)

    f["Keyboard_Row"] = c[440:449]
    f["IR15X"] = u16(c, 450)
    f["Keyboard_State"] = u32(c, 452)

    f["loffset"] = i16(c, 456)
    f["width"] = i32(c, 460)
    f["boffset"] = u32(c, 464)
    f["lcounter"] = u32(c, 468)
    f["sync"] = u32(c, 472)
    f["contrast"] = c[476]
    f["dispon"] = i32(c, 480)
    f["start1"] = u32(c, 484)
    f["start12"] = u32(c, 488)
    f["end1"] = u32(c, 492)
    f["start2"] = u32(c, 496)
    f["end2"] = u32(c, 500)

    f["d0size"] = u32(c, 504)

    f["d0memory"] = c[
        508:508 + d0memory_size
    ]

    f["d0offset"] = u32(
        c,
        508 + d0memory_size,
    )

    f["d0address"] = u32(
        c,
        512 + d0memory_size,
    )

    expected = 520 + d0memory_size

    if expected > size:
        raise ValueError(
            "CHIPSET is too small for its declared layout"
        )

    return f


# ---------------------------------------------------------------------------
# Main dump
# ---------------------------------------------------------------------------

def dump(filename, show_memory=False, extract=False):
    path = Path(filename)
    data = path.read_bytes()

    if len(data) < 24:
        raise ValueError(
            "file is too small to be an Emu48 state file"
        )

    print(f"Emu48 Calculator State v{VERSION}")
    print("===========================")
    print(f"File:              {path}")
    print(f"File size:         {len(data):,} bytes")
    print()

    # -----------------------------------------------------------------------
    # File Header
    # -----------------------------------------------------------------------

    sig = data[:16]

    print("File Header")
    print("-----------")
    print(f"Signature:         {sig!r}")

    if not sig.startswith(b"Emu48 Document"):
        print(
            "WARNING: this is not an Emu48 Document signature"
        )

    fmt_byte = sig[14]

    print(f"Format byte:       0x{fmt_byte:02X}")

    # -----------------------------------------------------------------------
    # KML
    # -----------------------------------------------------------------------

    kml_len = u32(data, 16)

    kml_start = 20
    kml_end = kml_start + kml_len

    if kml_end + 4 > len(data):
        raise ValueError("truncated KML path")

    kml_raw = data[kml_start:kml_end]
    kml = kml_raw.decode("utf-8", errors="replace")

    print(f"KML length:        {kml_len} bytes")
    print(f"KML path:          {kml}")
    print(f"KML offset:        0x{kml_start:04X}")

    # -----------------------------------------------------------------------
    # CHIPSET
    # -----------------------------------------------------------------------

    chipset_size = u32(data, kml_end)

    chipset_start = kml_end + 4
    chipset_end = chipset_start + chipset_size

    if chipset_end > len(data):
        raise ValueError("truncated CHIPSET")

    c = data[chipset_start:chipset_end]

    print()
    print("CHIPSET")
    print("-------")
    print(f"CHIPSET size:      {chipset_size:,} bytes")
    print(f"CHIPSET offset:    0x{chipset_start:04X}")

    if chipset_size not in (8648, 8712):
        raise ValueError(
            f"unsupported CHIPSET size {chipset_size}; "
            "expected 8648 or 8712"
        )

    f = parse_chipset(c, chipset_size)

    print(f"Model:             {f['type']!r}")
    print(
        f"Window position:   "
        f"({f['nPosX']}, {f['nPosY']})"
    )

    # -----------------------------------------------------------------------
    # Memory Sizes
    # -----------------------------------------------------------------------

    print()
    print("Memory Sizes")
    print("------------")

    for name in (
        "Port0Size",
        "Port1Size",
        "Port2Size",
    ):
        kb = f[name]

        print(
            f"{name:<16} "
            f"{kb:>5} KB  "
            f"({kb * 2048:,} bytes)"
        )

    # -----------------------------------------------------------------------
    # CPU
    # -----------------------------------------------------------------------

    print()
    print("CPU / Saturn")
    print("------------")
    print(f"PC:                {hx(f['pc'], 5)}")
    print(f"D0:                {hx(f['d0'], 5)}")
    print(f"D1:                {hx(f['d1'], 5)}")
    print(f"RSTKP:             {hx(f['rstkp'], 5)}")

    print("RSTK:")

    for i, value in enumerate(f["rstk"]):
        print(
            f"  R{i}:              "
            f"{hx(value, 5)}"
        )

    for name in (
        "A",
        "B",
        "C",
        "D",
        "R0",
        "R1",
        "R2",
        "R3",
        "R4",
    ):
        print(
            f"{name:<20} "
            f"{saturn_reg(f[name])}"
        )

    print(
        f"ST:                "
        f"{saturn_reg(f['ST'])}"
    )

    print(f"HST:               {hx(f['HST'], 2)}")
    print(f"P:                 {hx(f['P'], 1)}")
    print(f"OUT:               {hx(f['out'], 4)}")
    print(f"IN:                {hx(f['in'], 4)}")

    # -----------------------------------------------------------------------
    # CPU Flags
    # -----------------------------------------------------------------------

    print()
    print("CPU Flags")
    print("---------")

    for name in (
        "SoftInt",
        "Shutdn",
        "mode_dec",
        "inte",
        "intk",
        "intd",
        "carry",
    ):
        print(
            f"{name:<18} "
            f"{'TRUE' if f[name] else 'FALSE'}"
        )

    # -----------------------------------------------------------------------
    # Checksums / Timing
    # -----------------------------------------------------------------------

    print()
    print("Checksums / Timing")
    print("------------------")

    for name in (
        "crc",
        "wPort2Crc",
        "wRomCrc",
    ):
        print(
            f"{name:<18} "
            f"{hx(f[name], 4)}"
        )

    for name in (
        "cycles",
        "cycles_reserved",
        "dwKdnCycles",
    ):
        print(
            f"{name:<18} "
            f"{f[name]:,}"
        )

    # -----------------------------------------------------------------------
    # MMU / I/O
    # -----------------------------------------------------------------------

    print()
    print("MMU / I/O")
    print("---------")

    for name in (
        "Bank_FF",
        "FlashRomState",
        "cards_status",
        "IOBase",
    ):
        print(
            f"{name:<18} "
            f"{hx(f[name])}"
        )

    print(
        f"{'IORam':<18} "
        f"{f['IORam'].hex()}"
    )

    print(
        f"{'IOCfig':<18} "
        f"{'TRUE' if f['IOCfig'] else 'FALSE'}"
    )

    # -----------------------------------------------------------------------
    # Memory Mapping
    # -----------------------------------------------------------------------

    print()
    print("Memory Mapping")
    print("--------------")

    for group, names in (
        (
            "Base",
            (
                "P0Base",
                "BSBase",
                "P1Base",
                "P2Base",
            ),
        ),
        (
            "Size",
            (
                "P0Size",
                "BSSize",
                "P1Size",
                "P2Size",
            ),
        ),
        (
            "End",
            (
                "P0End",
                "BSEnd",
                "P1End",
                "P2End",
            ),
        ),
    ):
        print(group + ":")

        print(
            "  "
            + "  ".join(
                f"{n}={f[n]}"
                for n in names
            )
        )

    print("Configuration:")

    for name in (
        "P0Cfig",
        "BSCfig",
        "P1Cfig",
        "P2Cfig",
        "P0Cfg2",
        "BSCfg2",
        "P1Cfg2",
        "P2Cfg2",
    ):
        print(
            f"  {name:<16} "
            f"{'TRUE' if f[name] else 'FALSE'}"
        )

    # -----------------------------------------------------------------------
    # Timers / Keyboard
    # -----------------------------------------------------------------------

    print()
    print("Timers / Keyboard")
    print("-----------------")
    print(f"T1:                {hx(f['t1'], 2)}")
    print(f"T2:                {hx(f['t2'], 8)}")

    print(
        f"bShutdnWake:       "
        f"{'TRUE' if f['bShutdnWake'] else 'FALSE'}"
    )

    print(
        f"Keyboard_Row:      "
        f"{f['Keyboard_Row'].hex()}"
    )

    print(f"IR15X:             {hx(f['IR15X'], 4)}")
    print(f"Keyboard_State:    {f['Keyboard_State']}")

    # -----------------------------------------------------------------------
    # Display
    # -----------------------------------------------------------------------

    print()
    print("Display")
    print("-------")

    for name in (
        "loffset",
        "width",
        "boffset",
        "lcounter",
        "sync",
        "contrast",
        "start1",
        "start12",
        "end1",
        "start2",
        "end2",
        "d0size",
        "d0offset",
        "d0address",
    ):
        print(
            f"{name:<18} "
            f"{f[name]}"
        )

    print(
        f"{'dispon':<18} "
        f"{'TRUE' if f['dispon'] else 'FALSE'}"
    )

    print(
        f"d0memory size:     "
        f"{len(f['d0memory']):,} bytes"
    )

    print(
        f"d0memory nonzero:  "
        f"{sum(x != 0 for x in f['d0memory']):,}"
    )

    # -----------------------------------------------------------------------
    # Saved RAM
    # -----------------------------------------------------------------------

    # Saved RAM follows the CHIPSET exactly.
    memory_offset = chipset_end

    print()
    print("Saved Memory")
    print("------------")

    memories = []

    for name in (
        "Port0",
        "Port1",
        "Port2",
    ):
        size = f[name + "Size"] * 2048

        block = data[
            memory_offset:
            memory_offset + size
        ]

        if len(block) != size:
            raise ValueError(
                f"truncated {name} memory"
            )

        memories.append(
            (
                name,
                memory_offset,
                block,
            )
        )

        print(
            f"{name:<18} "
            f"{size:,} bytes "
            f"at 0x{memory_offset:08X} "
            f"(nonzero: "
            f"{sum(x != 0 for x in block):,})"
        )

        memory_offset += size

    # -----------------------------------------------------------------------
    # Optional Mac UI Settings
    # -----------------------------------------------------------------------

    print()
    print("Optional Mac UI Settings")
    print("------------------------")

    ui48size = 12

    trailing = data[memory_offset:]

    if not trailing:
        print("none")

    elif trailing.startswith(b"UI48"):
      if len(trailing) < ui48size:
        raise ValueError("truncated UI48 block")
        
      ui48_offset = memory_offset
      
      version, zoom, window_x, window_y = struct.unpack_from(
        "<iiii",
        trailing,
        4,
      )
      
      print()
      print("Mac UI Settings (UI48)")
      print("-----------------------")
      print(f"magic:             UI48")
      print(f"version:           {version}")
      print(f"zoomPercent:       {zoom}")
      print(f"offset:            0x{ui48_offset:08X}")
      print(f"size:              {ui48size} bytes")
      
      # CINF follows the fixed 12-byte UI48 block.
      cinf_offset = ui48_offset + 12
      
      if data[cinf_offset:cinf_offset + 4] == b"CINF":
        parse_cinf(data, cinf_offset)

    elif trailing.startswith(b"CINF"):
        parse_cinf(
            data,
            memory_offset,
        )

    else:
        print()
        print("Unknown trailing data")
        print("----------------------")
        print(
            f"Offset:            "
            f"{memory_offset} "
            f"(0x{memory_offset:X})"
        )
        print(
            f"Length:            "
            f"{len(trailing)} bytes"
        )
        print(
            f"First 64 bytes:    "
            f"{trailing[:64].hex(' ')}"
        )

    # -----------------------------------------------------------------------
    # Optional memory dump
    # -----------------------------------------------------------------------

    if show_memory:
        for name, start, block in memories:
            print()
            print(f"{name} first 256 bytes")
            print("--------------------")

            for off in range(
                0,
                min(256, len(block)),
                16,
            ):
                chunk = block[off:off + 16]

                ascii_part = "".join(
                    chr(x) if 32 <= x < 127 else "."
                    for x in chunk
                )

                print(
                    f"{start + off:08X}  "
                    f"{chunk.hex(' '):<47}  "
                    f"{ascii_part}"
                )

    # -----------------------------------------------------------------------
    # Extract memory
    # -----------------------------------------------------------------------

    if extract:
        for name, _, block in memories:
            outfile = path.with_name(
                path.name
                + f".{name.lower()}.bin"
            )

            outfile.write_bytes(block)

            print(
                f"Extracted {name}: "
                f"{outfile}"
            )

        outfile = path.with_name(
            path.name + ".d0memory.bin"
        )

        outfile.write_bytes(
            f["d0memory"]
        )

        print(
            f"Extracted d0memory: "
            f"{outfile}"
        )

    # -----------------------------------------------------------------------
    # Key File Offsets
    # -----------------------------------------------------------------------

    print()
    print("Key File Offsets")
    print("----------------")
    print(
        f"signature:         "
        f"0x00000000"
    )
    print(
        f"KML length:        "
        f"0x00000010"
    )
    print(
        f"KML data:          "
        f"0x{kml_start:08X}"
    )
    print(
        f"CHIPSET size:      "
        f"0x{kml_end:08X}"
    )
    print(
        f"CHIPSET data:      "
        f"0x{chipset_start:08X}"
    )
    print(
        f"saved memory:      "
        f"0x{chipset_end:08X}"
    )
    print(
        f"file end:          "
        f"0x{len(data):08X}"
    )


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description=(
            "Show readable values from an "
            "Emu48 calculator state file."
        )
    )

    ap.add_argument(
        "state_file"
    )

    ap.add_argument(
        "--memory",
        action="store_true",
        help="show the first 256 bytes of each RAM area",
    )

    ap.add_argument(
        "--extract",
        action="store_true",
        help="extract Port0/1/2 and d0memory as .bin files",
    )

    args = ap.parse_args()

    try:
        dump(
            args.state_file,
            args.memory,
            args.extract,
        )

    except (
        OSError,
        ValueError,
        struct.error,
    ) as e:
        print(
            f"error: {e}",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())