#!/usr/bin/env python3
"""
omf_dis.py — ORCA OMF object file parser and 65816 disassembler
Usage:
    python3 omf_dis.py file.a [file2.a ...]

Parses ORCA OMF segments, extracts code/data records, and disassembles
65816 instructions with annotations for ORCA/C frame setup/teardown.

OMF record types used by ORCA/C:
    0x00  END          — end of segment
    0xE0  ALIGN        — alignment record
    0xE2  ORG          — origin record (sets PC)
    0xEB  RELOC        — relocation entry (2-byte)
    0xE7  INTERSEG     — intersegment reloc
    0xF0  DS           — define space (zeroed bytes)
    0xF1  LCONST (short) — literal constant block (1-byte length)
    0x01  CONST (long)  — literal constant block (4-byte length? actually 4-byte count)
    See also: super-reloc types 0xF5..0xFE

Reference: "Apple IIgs Toolbox Reference" Vol.3, OMF chapter.
"""

import sys
import struct
import os


# ── 65816 opcode table ────────────────────────────────────────────────────────
# Format: opcode_byte -> (mnemonic, addr_mode)
# Addr modes: imp, acc, imm8, imm16, imm24, dp, dpx, dpy, dpind,
#             dpindx, dpindy, dpindl, dpindly, abs, absx, absy,
#             absl, abslx, absind, absindx, absindl, rel8, rel16, stk, stkidy

OPCODES = {
    0x00: ("BRK", "imm8"),
    0x01: ("ORA", "dpindx"),
    0x02: ("COP", "imm8"),
    0x03: ("ORA", "stk"),
    0x04: ("TSB", "dp"),
    0x05: ("ORA", "dp"),
    0x06: ("ASL", "dp"),
    0x07: ("ORA", "dpindl"),
    0x08: ("PHP", "imp"),
    0x09: ("ORA", "immM"),
    0x0A: ("ASL", "acc"),
    0x0B: ("PHD", "imp"),
    0x0C: ("TSB", "abs"),
    0x0D: ("ORA", "abs"),
    0x0E: ("ASL", "abs"),
    0x0F: ("ORA", "absl"),
    0x10: ("BPL", "rel8"),
    0x11: ("ORA", "dpindy"),
    0x12: ("ORA", "dpind"),
    0x13: ("ORA", "stkidy"),
    0x14: ("TRB", "dp"),
    0x15: ("ORA", "dpx"),
    0x16: ("ASL", "dpx"),
    0x17: ("ORA", "dpindly"),
    0x18: ("CLC", "imp"),
    0x19: ("ORA", "absy"),
    0x1A: ("INC", "acc"),
    0x1B: ("TCS", "imp"),
    0x1C: ("TRB", "abs"),
    0x1D: ("ORA", "absx"),
    0x1E: ("ASL", "absx"),
    0x1F: ("ORA", "abslx"),
    0x20: ("JSR", "abs"),
    0x21: ("AND", "dpindx"),
    0x22: ("JSL", "absl"),
    0x23: ("AND", "stk"),
    0x24: ("BIT", "dp"),
    0x25: ("AND", "dp"),
    0x26: ("ROL", "dp"),
    0x27: ("AND", "dpindl"),
    0x28: ("PLP", "imp"),
    0x29: ("AND", "immM"),
    0x2A: ("ROL", "acc"),
    0x2B: ("PLD", "imp"),
    0x2C: ("BIT", "abs"),
    0x2D: ("AND", "abs"),
    0x2E: ("ROL", "abs"),
    0x2F: ("AND", "absl"),
    0x30: ("BMI", "rel8"),
    0x31: ("AND", "dpindy"),
    0x32: ("AND", "dpind"),
    0x33: ("AND", "stkidy"),
    0x34: ("BIT", "dpx"),
    0x35: ("AND", "dpx"),
    0x36: ("ROL", "dpx"),
    0x37: ("AND", "dpindly"),
    0x38: ("SEC", "imp"),
    0x39: ("AND", "absy"),
    0x3A: ("DEC", "acc"),
    0x3B: ("TSC", "imp"),
    0x3C: ("BIT", "absx"),
    0x3D: ("AND", "absx"),
    0x3E: ("ROL", "absx"),
    0x3F: ("AND", "abslx"),
    0x40: ("RTI", "imp"),
    0x41: ("EOR", "dpindx"),
    0x42: ("WDM", "imm8"),
    0x43: ("EOR", "stk"),
    0x44: ("MVP", "srcbank"),
    0x45: ("EOR", "dp"),
    0x46: ("LSR", "dp"),
    0x47: ("EOR", "dpindl"),
    0x48: ("PHA", "imp"),
    0x49: ("EOR", "immM"),
    0x4A: ("LSR", "acc"),
    0x4B: ("PHK", "imp"),
    0x4C: ("JMP", "abs"),
    0x4D: ("EOR", "abs"),
    0x4E: ("LSR", "abs"),
    0x4F: ("EOR", "absl"),
    0x50: ("BVC", "rel8"),
    0x51: ("EOR", "dpindy"),
    0x52: ("EOR", "dpind"),
    0x53: ("EOR", "stkidy"),
    0x54: ("MVN", "srcbank"),
    0x55: ("EOR", "dpx"),
    0x56: ("LSR", "dpx"),
    0x57: ("EOR", "dpindly"),
    0x58: ("CLI", "imp"),
    0x59: ("EOR", "absy"),
    0x5A: ("PHY", "imp"),
    0x5B: ("TCD", "imp"),
    0x5C: ("JML", "absl"),
    0x5D: ("EOR", "absx"),
    0x5E: ("LSR", "absx"),
    0x5F: ("EOR", "abslx"),
    0x60: ("RTS", "imp"),
    0x61: ("ADC", "dpindx"),
    0x62: ("PER", "rel16"),
    0x63: ("ADC", "stk"),
    0x64: ("STZ", "dp"),
    0x65: ("ADC", "dp"),
    0x66: ("ROR", "dp"),
    0x67: ("ADC", "dpindl"),
    0x68: ("PLA", "imp"),
    0x69: ("ADC", "immM"),
    0x6A: ("ROR", "acc"),
    0x6B: ("RTL", "imp"),
    0x6C: ("JMP", "absind"),
    0x6D: ("ADC", "abs"),
    0x6E: ("ROR", "abs"),
    0x6F: ("ADC", "absl"),
    0x70: ("BVS", "rel8"),
    0x71: ("ADC", "dpindy"),
    0x72: ("ADC", "dpind"),
    0x73: ("ADC", "stkidy"),
    0x74: ("STZ", "dpx"),
    0x75: ("ADC", "dpx"),
    0x76: ("ROR", "dpx"),
    0x77: ("ADC", "dpindly"),
    0x78: ("SEI", "imp"),
    0x79: ("ADC", "absy"),
    0x7A: ("PLY", "imp"),
    0x7B: ("TDC", "imp"),
    0x7C: ("JMP", "absindx"),
    0x7D: ("ADC", "absx"),
    0x7E: ("ROR", "absx"),
    0x7F: ("ADC", "abslx"),
    0x80: ("BRA", "rel8"),
    0x81: ("STA", "dpindx"),
    0x82: ("BRL", "rel16"),
    0x83: ("STA", "stk"),
    0x84: ("STY", "dp"),
    0x85: ("STA", "dp"),
    0x86: ("STX", "dp"),
    0x87: ("STA", "dpindl"),
    0x88: ("DEY", "imp"),
    0x89: ("BIT", "immM"),
    0x8A: ("TXA", "imp"),
    0x8B: ("PHB", "imp"),
    0x8C: ("STY", "abs"),
    0x8D: ("STA", "abs"),
    0x8E: ("STX", "abs"),
    0x8F: ("STA", "absl"),
    0x90: ("BCC", "rel8"),
    0x91: ("STA", "dpindy"),
    0x92: ("STA", "dpind"),
    0x93: ("STA", "stkidy"),
    0x94: ("STY", "dpx"),
    0x95: ("STA", "dpx"),
    0x96: ("STX", "dpy"),
    0x97: ("STA", "dpindly"),
    0x98: ("TYA", "imp"),
    0x99: ("STA", "absy"),
    0x9A: ("TXS", "imp"),
    0x9B: ("TXY", "imp"),
    0x9C: ("STZ", "abs"),
    0x9D: ("STA", "absx"),
    0x9E: ("STZ", "absx"),
    0x9F: ("STA", "abslx"),
    0xA0: ("LDY", "immX"),
    0xA1: ("LDA", "dpindx"),
    0xA2: ("LDX", "immX"),
    0xA3: ("LDA", "stk"),
    0xA4: ("LDY", "dp"),
    0xA5: ("LDA", "dp"),
    0xA6: ("LDX", "dp"),
    0xA7: ("LDA", "dpindl"),
    0xA8: ("TAY", "imp"),
    0xA9: ("LDA", "immM"),
    0xAA: ("TAX", "imp"),
    0xAB: ("PLB", "imp"),
    0xAC: ("LDY", "abs"),
    0xAD: ("LDA", "abs"),
    0xAE: ("LDX", "abs"),
    0xAF: ("LDA", "absl"),
    0xB0: ("BCS", "rel8"),
    0xB1: ("LDA", "dpindy"),
    0xB2: ("LDA", "dpind"),
    0xB3: ("LDA", "stkidy"),
    0xB4: ("LDY", "dpx"),
    0xB5: ("LDA", "dpx"),
    0xB6: ("LDX", "dpy"),
    0xB7: ("LDA", "dpindly"),
    0xB8: ("CLV", "imp"),
    0xB9: ("LDA", "absy"),
    0xBA: ("TSX", "imp"),
    0xBB: ("TYX", "imp"),
    0xBC: ("LDY", "absx"),
    0xBD: ("LDA", "absx"),
    0xBE: ("LDX", "absy"),
    0xBF: ("LDA", "abslx"),
    0xC0: ("CPY", "immX"),
    0xC1: ("CMP", "dpindx"),
    0xC2: ("REP", "imm8"),
    0xC3: ("CMP", "stk"),
    0xC4: ("CPY", "dp"),
    0xC5: ("CMP", "dp"),
    0xC6: ("DEC", "dp"),
    0xC7: ("CMP", "dpindl"),
    0xC8: ("INY", "imp"),
    0xC9: ("CMP", "immM"),
    0xCA: ("DEX", "imp"),
    0xCB: ("WAI", "imp"),
    0xCC: ("CPY", "abs"),
    0xCD: ("CMP", "abs"),
    0xCE: ("DEC", "abs"),
    0xCF: ("CMP", "absl"),
    0xD0: ("BNE", "rel8"),
    0xD1: ("CMP", "dpindy"),
    0xD2: ("CMP", "dpind"),
    0xD3: ("CMP", "stkidy"),
    0xD4: ("PEI", "dpind"),
    0xD5: ("CMP", "dpx"),
    0xD6: ("DEC", "dpx"),
    0xD7: ("CMP", "dpindly"),
    0xD8: ("CLD", "imp"),
    0xD9: ("CMP", "absy"),
    0xDA: ("PHX", "imp"),
    0xDB: ("STP", "imp"),
    0xDC: ("JML", "absindl"),
    0xDD: ("CMP", "absx"),
    0xDE: ("DEC", "absx"),
    0xDF: ("CMP", "abslx"),
    0xE0: ("CPX", "immX"),
    0xE1: ("SBC", "dpindx"),
    0xE2: ("SEP", "imm8"),
    0xE3: ("SBC", "stk"),
    0xE4: ("CPX", "dp"),
    0xE5: ("SBC", "dp"),
    0xE6: ("INC", "dp"),
    0xE7: ("SBC", "dpindl"),
    0xE8: ("INX", "imp"),
    0xE9: ("SBC", "immM"),
    0xEA: ("NOP", "imp"),
    0xEB: ("XBA", "imp"),
    0xEC: ("CPX", "abs"),
    0xED: ("SBC", "abs"),
    0xEE: ("INC", "abs"),
    0xEF: ("SBC", "absl"),
    0xF0: ("BEQ", "rel8"),
    0xF1: ("SBC", "dpindy"),
    0xF2: ("SBC", "dpind"),
    0xF3: ("SBC", "stkidy"),
    0xF4: ("PEA", "abs"),
    0xF5: ("SBC", "dpx"),
    0xF6: ("INC", "dpx"),
    0xF7: ("SBC", "dpindly"),
    0xF8: ("SED", "imp"),
    0xF9: ("SBC", "absy"),
    0xFA: ("PLX", "imp"),
    0xFB: ("XCE", "imp"),
    0xFC: ("JSR", "absindx"),
    0xFD: ("SBC", "absx"),
    0xFE: ("INC", "absx"),
    0xFF: ("SBC", "abslx"),
}


def insn_size(opcode, m_flag, x_flag):
    """Return the total byte length of an instruction (opcode + operands)."""
    mode = OPCODES.get(opcode, ("???", "imp"))[1]
    sizes = {
        "imp":     1,
        "acc":     1,
        "imm8":    2,
        "imm16":   3,
        "imm24":   4,
        "immM":    2 if m_flag else 3,
        "immX":    2 if x_flag else 3,
        "dp":      2,
        "dpx":     2,
        "dpy":     2,
        "dpind":   2,
        "dpindx":  2,
        "dpindy":  2,
        "dpindl":  2,
        "dpindly": 2,
        "stk":     2,
        "stkidy":  2,
        "abs":     3,
        "absx":    3,
        "absy":    3,
        "absl":    4,
        "abslx":   4,
        "absind":  3,
        "absindx": 3,
        "absindl": 3,
        "rel8":    2,
        "rel16":   3,
        "srcbank": 3,
    }
    return sizes.get(mode, 1)


def format_operand(data, offset, opcode, pc, m_flag, x_flag):
    """Return formatted operand string for the instruction at data[offset]."""
    mode = OPCODES.get(opcode, ("???", "imp"))[1]

    def b1(): return data[offset] if offset < len(data) else 0
    def b2(): return struct.unpack_from("<H", data, offset)[0] if offset + 1 < len(data) else 0
    def b3():
        lo = struct.unpack_from("<H", data, offset)[0] if offset + 1 < len(data) else 0
        hi = data[offset + 2] if offset + 2 < len(data) else 0
        return lo | (hi << 16)

    if mode == "imp" or mode == "acc":
        return ""
    elif mode == "imm8":
        return f"#${b1():02X}"
    elif mode == "imm16":
        return f"#${b2():04X}"
    elif mode == "immM":
        if m_flag:
            return f"#${b1():02X}"
        else:
            return f"#${b2():04X}"
    elif mode == "immX":
        if x_flag:
            return f"#${b1():02X}"
        else:
            return f"#${b2():04X}"
    elif mode == "dp":
        return f"${b1():02X}"
    elif mode == "dpx":
        return f"${b1():02X},X"
    elif mode == "dpy":
        return f"${b1():02X},Y"
    elif mode == "dpind":
        return f"(${b1():02X})"
    elif mode == "dpindx":
        return f"(${b1():02X},X)"
    elif mode == "dpindy":
        return f"(${b1():02X}),Y"
    elif mode == "dpindl":
        return f"[${b1():02X}]"
    elif mode == "dpindly":
        return f"[${b1():02X}],Y"
    elif mode == "stk":
        return f"${b1():02X},S"
    elif mode == "stkidy":
        return f"(${b1():02X},S),Y"
    elif mode == "abs":
        return f"${b2():04X}"
    elif mode == "absx":
        return f"${b2():04X},X"
    elif mode == "absy":
        return f"${b2():04X},Y"
    elif mode == "absl":
        return f"${b3():06X}"
    elif mode == "abslx":
        return f"${b3():06X},X"
    elif mode == "absind":
        return f"(${b2():04X})"
    elif mode == "absindx":
        return f"(${b2():04X},X)"
    elif mode == "absindl":
        return f"[${b2():04X}]"
    elif mode == "rel8":
        disp = b1()
        if disp >= 0x80:
            disp -= 0x100
        target = (pc + 2 + disp) & 0xFFFF
        return f"${target:04X}  ; rel +{disp:+d}"
    elif mode == "rel16":
        disp = b2()
        if disp >= 0x8000:
            disp -= 0x10000
        target = (pc + 3 + disp) & 0xFFFF
        return f"${target:04X}  ; rel +{disp:+d}"
    elif mode == "srcbank":
        dst = data[offset] if offset < len(data) else 0
        src = data[offset + 1] if offset + 1 < len(data) else 0
        return f"${dst:02X},${src:02X}"
    return ""


# ── ORCA/C frame pattern annotations ─────────────────────────────────────────

FRAME_ANNOTATIONS = {
    0x48: "pha       ; [FRAME] push space for return value / frame marker",
    0x3B: "tsc       ; [FRAME] A = stack pointer",
    0x0B: "phd       ; [FRAME] save direct page register",
    0x5B: "tcd       ; [FRAME] set dp = current stack (new frame base)",
    0x2B: "pld       ; [FRAME-END] restore direct page (pop 2 bytes)",
    0x1B: "tcs       ; [FRAME-END] restore stack pointer",
    0x6B: "rtl       ; [FRAME-END] far return (3-byte return address)",
    0x60: "rts       ; [FRAME-END] near return",
}

REP_ANNOTATIONS = {
    0x30: "M=16-bit, X=16-bit",
    0x20: "M=16-bit (acc wide)",
    0x10: "X=16-bit (index wide)",
    0x01: "C=16-bit",
}
SEP_ANNOTATIONS = {
    0x30: "M=8-bit, X=8-bit",
    0x20: "M=8-bit (acc narrow)",
    0x10: "X=8-bit (index narrow)",
}


def annotate(opcode, operand_str, raw_bytes):
    """Return an annotation comment if this is a notable instruction."""
    if opcode == 0xC2:  # REP
        mask = raw_bytes[1] if len(raw_bytes) > 1 else 0
        note = REP_ANNOTATIONS.get(mask, f"mask=${mask:02X}")
        return f"; REP: {note}"
    if opcode == 0xE2:  # SEP
        mask = raw_bytes[1] if len(raw_bytes) > 1 else 0
        note = SEP_ANNOTATIONS.get(mask, f"mask=${mask:02X}")
        return f"; SEP: {note}"
    if opcode == 0x69:  # ADC imm — after pld/tsc this is frame cleanup
        return "; (frame cleanup: stack adjustment)"
    return ""


# ── OMF parser ────────────────────────────────────────────────────────────────

def read_u16(data, off):
    return struct.unpack_from("<H", data, off)[0]

def read_u32(data, off):
    return struct.unpack_from("<I", data, off)[0]

def read_cstring(data, off):
    """Read a length-prefixed Pascal string (1-byte length)."""
    length = data[off]
    return data[off + 1: off + 1 + length].decode("ascii", errors="replace"), off + 1 + length


class OMFSegment:
    def __init__(self, blksize, segsize, seg_num, seg_type, name, code_bytes, raw_header):
        self.blksize    = blksize
        self.segsize    = segsize
        self.seg_num    = seg_num
        self.seg_type   = seg_type
        self.name       = name
        self.code_bytes = code_bytes   # list of (pc_offset, bytearray) slabs
        self.raw_header = raw_header


def parse_omf(data):
    """
    Parse all OMF v2 segments from a byte string. Returns list of OMFSegment.

    ORCA OMF v2 header layout (authoritative — from GoldenGate omf.cpp):
      0x00  byte_count  4   total segment size in bytes
      0x04  res_space   4
      0x08  length      4   body length
      0x0C  (unused)    1
      0x0D  lab_len     1   0 = Pascal-string labels; N = fixed N-byte labels
      0x0E  num_len     1   must be 4
      0x0F  version     1   must be 2 for v2
      0x10  bank_size   4
      0x14  kind        2   segment type (low 5 bits)
      0x16  (unused)    2
      0x18  org         4
      0x1C  alignment   4
      0x20  num_sex     1   0 = little-endian
      0x21  (unused)    1
      0x22  seg_num     2
      0x24  entry       4
      0x28  disp_name   2   offset to segment name from seg start
      0x2A  disp_data   2   offset to first record from seg start

    Record types (from GoldenGate opcodes::for_each):
      0x00         END
      0x01-0xDF    CONST — the byte value IS the count; that many data bytes follow
      0xE0         ALIGN      — num_len (4) byte operand
      0xE1         ORG        — num_len (4) byte new PC
      0xE2         RELOC      — 10 bytes
      0xE3         INTERSEG   — 14 bytes
      0xE4         USING      — lab_len label string
      0xE5         STRONG     — lab_len label string
      0xE6         GLOBAL     — lab_len + 4 bytes
      0xE7         GEQU       — complex (skip)
      0xE8         MEM        — num_len * 2 bytes
      0xEB-0xED    EXPR/ZEXPR/BKEXPR — 1 byte + expression (skip)
      0xEE         RELEXPR    — 1 + num_len + expression (skip)
      0xEF         LOCAL      — lab_len + 4 bytes
      0xF0         EQU        — complex (skip)
      0xF1         DS         — num_len (4) byte count; that many zero bytes
      0xF2         LCONST     — 4-byte count; that many data bytes follow
      0xF3         LEXPR      — 1 byte + expression (skip)
      0xF5         CRELOC     — 6 bytes
      0xF6         CINTERSEG  — 7 bytes
      0xF7         SUPER      — 4-byte count; that many bytes (skip)
    """
    segments = []
    offset = 0
    seg_num = 0

    while offset < len(data):
        if offset + 0x2C > len(data):
            break

        seg_data = data[offset:]

        # Version byte at 0x0F
        version  = seg_data[0x0F]
        if version not in (0, 1, 2):
            break

        # All relevant fields (v2 layout; v0/v1 differ but ORCA/C emits v2)
        byte_count = read_u32(seg_data, 0x00)
        if byte_count == 0:
            break

        lab_len  = seg_data[0x0D]
        num_len  = seg_data[0x0E]   # should be 4
        kind     = read_u16(seg_data, 0x14) if version == 2 else (seg_data[0x0A] & 0x1F)
        seg_type = kind & 0x1F
        dispname = read_u16(seg_data, 0x28)
        dispdata = read_u16(seg_data, 0x2A)

        seg_data = data[offset: offset + byte_count]
        seg_num += 1

        # Read segment name.
        # The name area spans [dispname, dispdata).  When lab_len=0 (Pascal
        # strings) the name is stored right-aligned within that window: leading
        # space (0x20) padding precedes the length byte + name chars.
        try:
            if lab_len == 0:
                # scan past leading spaces to find the Pascal-string length byte
                p = dispname
                while p < dispdata and seg_data[p] == 0x20:
                    p += 1
                if p < dispdata:
                    namelen  = seg_data[p]
                    seg_name = seg_data[p + 1: p + 1 + namelen].decode("ascii", errors="replace")
                else:
                    seg_name = f"<seg{seg_num}>"
            else:
                seg_name = seg_data[dispname: dispname + lab_len].rstrip(b"\x00 ").decode("ascii", errors="replace")
        except Exception:
            seg_name = f"<seg{seg_num}>"

        # ── Parse body records ────────────────────────────────────────────────
        code_slabs = []
        pc   = 0
        pos  = dispdata
        nlen = num_len if num_len in (1, 2, 4) else 4

        def skip_label(pos):
            """Advance pos past a label field (Pascal-string or fixed)."""
            if lab_len == 0:
                if pos < len(seg_data):
                    l = seg_data[pos]
                    return pos + 1 + l
                return pos + 1
            return pos + lab_len

        def skip_expr(pos):
            """Advance pos past an RPN expression (stops at 0x00 END_EXPR)."""
            while pos < len(seg_data):
                b = seg_data[pos]
                pos += 1
                if b == 0x00:
                    break
            return pos

        while pos < len(seg_data):
            rtype = seg_data[pos]
            pos  += 1

            if rtype == 0x00:                    # END
                break

            elif 0x01 <= rtype <= 0xDF:          # CONST — byte value = count
                count = rtype
                slab  = bytearray(seg_data[pos: pos + count])
                code_slabs.append((pc, slab))
                pc  += count
                pos += count

            elif rtype == 0xE0:                  # ALIGN
                pos += nlen

            elif rtype == 0xE1:                  # ORG — new PC
                if pos + nlen <= len(seg_data):
                    pc = read_u32(seg_data, pos) if nlen == 4 else read_u16(seg_data, pos)
                pos += nlen

            elif rtype == 0xE2:                  # RELOC (10 bytes)
                pos += 10

            elif rtype == 0xE3:                  # INTERSEG (14 bytes)
                pos += 14

            elif rtype in (0xE4, 0xE5):          # USING / STRONG
                pos = skip_label(pos)

            elif rtype in (0xE6, 0xEF):          # GLOBAL / LOCAL
                pos = skip_label(pos)
                pos += 4 if version == 2 else 3

            elif rtype in (0xE7, 0xF0):          # GEQU / EQU (complex)
                pos = skip_label(pos)
                pos += 4 if version == 2 else 3
                if version == 0:
                    pos += nlen
                else:
                    pos = skip_expr(pos)

            elif rtype == 0xE8:                  # MEM
                pos += nlen * 2

            elif rtype in (0xEB, 0xEC, 0xED, 0xF3):  # EXPR / ZEXPR / BKEXPR / LEXPR
                pos += 1
                pos  = skip_expr(pos)

            elif rtype == 0xEE:                  # RELEXPR
                pos += 1 + nlen
                pos  = skip_expr(pos)

            elif rtype == 0xF1:                  # DS — define space (zero bytes)
                if pos + nlen <= len(seg_data):
                    count = read_u32(seg_data, pos) if nlen == 4 else read_u16(seg_data, pos)
                else:
                    count = 0
                pc  += count
                pos += nlen

            elif rtype == 0xF2:                  # LCONST — 4-byte count + data
                if pos + 4 <= len(seg_data):
                    count = read_u32(seg_data, pos)
                    pos  += 4
                    slab  = bytearray(seg_data[pos: pos + count])
                    code_slabs.append((pc, slab))
                    pc  += count
                    pos += count
                else:
                    break

            elif rtype == 0xF5:                  # CRELOC (6 bytes)
                pos += 6

            elif rtype == 0xF6:                  # CINTERSEG (7 bytes)
                pos += 7

            elif rtype == 0xF7:                  # SUPER — 4-byte count
                if pos + 4 <= len(seg_data):
                    count = read_u32(seg_data, pos)
                    pos  += 4 + count
                else:
                    break

            else:
                # Unknown record type — stop to avoid desync
                break

        segments.append(OMFSegment(byte_count, 0, seg_num, seg_type, seg_name, code_slabs, seg_data[:dispdata]))
        offset += byte_count

    return segments


# ── Disassembler ──────────────────────────────────────────────────────────────

KIND_NAMES = {
    0x00: "CODE",
    0x01: "DATA",
    0x02: "JUMP-TABLE",
    0x04: "PATHNAME",
    0x08: "LIBRARY",
    0x10: "INIT",
    0x12: "ABSOLUTE",
}

def disassemble_slab(slab, base_pc, m_flag=False, x_flag=False):
    """
    Disassemble a byte slab.  Tracks M/X flags through REP/SEP.
    Returns list of (pc, bytes, mnemonic, operand, annotation) tuples.
    """
    results = []
    i = 0
    pc = base_pc

    while i < len(slab):
        opcode = slab[i]
        size   = insn_size(opcode, m_flag, x_flag)
        raw    = slab[i: i + size]

        mnem, _ = OPCODES.get(opcode, ("???", "imp"))
        operand  = format_operand(slab, i + 1, opcode, pc, m_flag, x_flag)
        note     = annotate(opcode, operand, raw)

        # Track M/X flags
        if opcode == 0xC2 and len(raw) >= 2:   # REP
            mask = raw[1]
            if mask & 0x20: m_flag = False       # M=16-bit
            if mask & 0x10: x_flag = False       # X=16-bit
        elif opcode == 0xE2 and len(raw) >= 2:  # SEP
            mask = raw[1]
            if mask & 0x20: m_flag = True        # M=8-bit
            if mask & 0x10: x_flag = True        # X=8-bit

        results.append((pc, bytes(raw), mnem, operand, note))
        pc += size
        i  += size

    return results


def print_segment(seg):
    kind_name = KIND_NAMES.get(seg.seg_type, f"type${seg.seg_type:02X}")
    print(f"\n{'='*70}")
    print(f"Segment {seg.seg_num}: '{seg.name}'  [{kind_name}]  "
          f"blksize={seg.blksize}  segsize={seg.segsize}")
    print(f"{'='*70}")

    if not seg.code_bytes:
        print("  (no code/data records)")
        return

    m_flag = False   # start in 16-bit mode (native mode default)
    x_flag = False

    for (base_pc, slab) in seg.code_bytes:
        print(f"\n  -- slab @ PC ${base_pc:04X}, {len(slab)} bytes --")
        insns = disassemble_slab(slab, base_pc, m_flag, x_flag)

        for (pc, raw, mnem, operand, note) in insns:
            hex_bytes = " ".join(f"{b:02X}" for b in raw)
            line = f"  ${pc:04X}:  {hex_bytes:<12}  {mnem:<6} {operand}"
            if note:
                line = f"{line:<50}  {note}"

            # Highlight frame instructions
            if mnem in ("PHD", "TCD", "PLD", "TSC", "TCS", "RTL", "RTS", "PHA") and len(raw) == 1:
                line = f"\033[1;33m{line}\033[0m"   # bold yellow
            elif "REP" in note or "SEP" in note:
                line = f"\033[1;36m{line}\033[0m"   # bold cyan
            elif mnem in ("JSL", "JSR"):
                line = f"\033[0;32m{line}\033[0m"   # green for calls

            print(line)

        # Update M/X flags from last slab for continuity
        for (pc, raw, mnem, operand, note) in insns:
            if mnem == "REP" and len(raw) >= 2:
                if raw[1] & 0x20: m_flag = False
                if raw[1] & 0x10: x_flag = False
            elif mnem == "SEP" and len(raw) >= 2:
                if raw[1] & 0x20: m_flag = True
                if raw[1] & 0x10: x_flag = True


def process_file(path):
    print(f"\n{'#'*70}")
    print(f"# File: {path}  ({os.path.getsize(path)} bytes)")
    print(f"{'#'*70}")

    with open(path, "rb") as f:
        data = f.read()

    segments = parse_omf(data)
    if not segments:
        print("  (no OMF segments found)")
        return

    print(f"  {len(segments)} segment(s) found")
    for seg in segments:
        print_segment(seg)


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} file.a [file2.a ...]")
        sys.exit(1)

    for path in sys.argv[1:]:
        if not os.path.exists(path):
            print(f"ERROR: file not found: {path}")
            continue
        process_file(path)


if __name__ == "__main__":
    main()
