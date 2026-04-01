#!/usr/bin/env python3
"""
make_macs.py — Generate ORCA/M macro (.mac) files with CR line endings.

ORCA/M (Asm65816) requires macro definitions to live in a separate file
included via the MCOPY directive.  MCOPY files use CR (0x0D) as the line
separator (ProDOS convention), not LF.

Each entry in MAC_FILES maps output_filename → list of text lines.
Lines are joined with CR and written as binary.

Run from anywhere; pass the tests/ directory as argv[1], or it defaults
to the 'tests' subdirectory alongside this script.
"""

import os
import sys

# ---------------------------------------------------------------------------
# Macro library content — one entry per test .mac file
# ---------------------------------------------------------------------------
#
# Column conventions for ORCA/M .mac files:
#   Col 1-8   label field  (&LAB or local label if any, else blank/spaces)
#   Col 9+    op field     (MACRO / MEND / instruction / directive)
#   rest      operand field
#
# A macro definition block:
#   [blank]   MACRO
#   [&LAB]    macname     [&p1[,&p2,...]]
#   ... body lines ...
#   [blank]   MEND

MAC_FILES = {

    # ------------------------------------------------------------------
    # t_macro_basic: simplest macro — no params, no label param
    # Three NOP instructions
    # Expected bytes: EA EA EA 60
    # ------------------------------------------------------------------
    "t_macro_basic.mac": [
        "         MACRO",
        "         THREE_NOP",
        "         NOP",
        "         NOP",
        "         NOP",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_params: one positional parameter &VAL
    # Expected bytes: A9 42 A9 FF 60
    # ------------------------------------------------------------------
    "t_macro_params.mac": [
        "         MACRO",
        "         LOADA   &VAL",
        "         LDA     #&VAL",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_multi_params: two positional parameters
    # Expected bytes: A2 01 A9 02 60
    # ------------------------------------------------------------------
    "t_macro_multi_params.mac": [
        "         MACRO",
        "         SETREGS &XVAL,&AVAL",
        "         LDX     #&XVAL",
        "         LDA     #&AVAL",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_conditional: AIF conditional emission
    # AIF expr,.label  →  branch to .label if expr != 0
    # MAYBE_LDA 1 → LDA #$AA; MAYBE_LDA 0 → nothing
    # Expected bytes: A9 AA 60
    # ------------------------------------------------------------------
    "t_macro_conditional.mac": [
        "         MACRO",
        "         MAYBE_LDA &FLAG",
        "         AIF  &FLAG=0,.SKIP",
        "         LDA  #$AA",
        ".SKIP    ANOP",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_mexit: MEXIT — unconditional early exit
    # COND_PHA 1 → NOP (then MEXIT); COND_PHA 0 → NOP + PHA
    # Expected bytes: EA EA 48 60
    # ------------------------------------------------------------------
    "t_macro_mexit.mac": [
        "         MACRO",
        "         COND_PHA &FLAG",
        "         NOP",
        "         AIF  &FLAG<>0,.DONE",
        "         PHA",
        ".DONE    ANOP",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_nested: macro calling another macro
    # Both macros in one file; INNER must appear before OUTER.
    # OUTER → PHA + INNER(NOP) + PLA
    # Expected bytes: 48 EA 68 60
    # ------------------------------------------------------------------
    "t_macro_nested.mac": [
        "         MACRO",
        "         INNER",
        "         NOP",
        "         MEND",
        "         MACRO",
        "         OUTER",
        "         PHA",
        "         INNER",
        "         PLA",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_loop: recursive compile-time loop (AIF + self-call)
    # GoldenGate ORCA/M does not support backward AGO correctly —
    # "AGO .LABEL" where .LABEL is above the AGO always hits the
    # ACTR count exceeded limit regardless of iteration count.
    # Workaround: recursive macro with AIF base-case exit.
    # NOPS_N 3 → three NOPs; NOPS_N 0 → nothing (base case)
    # Expected bytes: EA EA EA 60
    # ------------------------------------------------------------------
    "t_macro_loop.mac": [
        "         MACRO",
        "         NOPS_N  &N",
        "         AIF    &N=0,.DONE",
        "         NOP",
        "         NOPS_N  &N-1",
        ".DONE    ANOP",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_gbl: GBLA — global arithmetic variable persists
    # across separate macro invocations (unlike LCLA).
    # GBLA declared only in INIT_COUNT; BUMP_LDA uses it without
    # re-declaring (re-declaring GBLA causes Duplicate Label error).
    # 3× BUMP_LDA → LDA #1, LDA #2, LDA #3
    # Expected bytes: A9 01 A9 02 A9 03 60
    # ------------------------------------------------------------------
    "t_macro_gbl.mac": [
        "         MACRO",
        "         INIT_COUNT",
        "         GBLA   &COUNT",
        "&COUNT   SETA   0",
        "         MEND",
        "         MACRO",
        "         BUMP_LDA",
        "&COUNT   SETA   &COUNT+1",
        "         LDA    #&COUNT",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_string_ops: LCLC, SETC, AMID string operations
    # LCLC declares a local character (string) variable.
    # SETC assigns a string value.
    # AMID str,start,len  extracts a substring (1-indexed).
    # LOAD_REG A,$11 → LDA #$11 (A9 11)
    # LOAD_REG X,$22 → LDX #$22 (A2 22)
    # LOAD_REG Y,$33 → LDY #$33 (A0 33)
    # Expected bytes: A9 11 A2 22 A0 33 60
    #
    # KEY: In ORCA/M, when SGOTO branches to a sequence label, the
    # label line is consumed but NOT executed.  Execution resumes with
    # the NEXT line after the label.  Therefore, code must NOT share
    # a line with the branch target label; the label must stand alone.
    # ------------------------------------------------------------------
    "t_macro_string_ops.mac": [
        "         MACRO",
        "         LOAD_REG &REG,&VAL",
        "         LCLC   &R",
        "&R       AMID   &REG,1,1",
        "         AIF    \"&R\"<>\"A\",.TRYX",
        "         LDA    #&VAL",
        "         AGO    .DONE",
        ".TRYX",
        "         AIF    \"&R\"<>\"X\",.TRYY",
        "         LDX    #&VAL",
        "         AGO    .DONE",
        ".TRYY",
        "         LDY    #&VAL",
        ".DONE    ANOP",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_local_labels: &SYSCNT — unique counter per expansion
    # Each expansion gets a different &SYSCNT value, ensuring labels
    # like SKIP1 and SKIP2 are distinct across two calls.
    # SKIP_NOP: BRA +1 (skip 1 byte), NOP (dead), SKIPn label
    # BRA rel8 encoding: opcode $80, offset = 1 → bytes 80 01
    # Two calls → 80 01 EA 80 01 EA
    # Expected bytes: 80 01 EA 80 01 EA 60
    # NOTE: ORCA/M does NOT use @ prefix for &SYSCNT labels.
    # Correct form is bare LABEL&SYSCNT (e.g. SKIP&SYSCNT).
    # ------------------------------------------------------------------
    "t_macro_local_labels.mac": [
        "         MACRO",
        "         SKIP_NOP",
        "         BRA    SKIP&SYSCNT",
        "         NOP",
        "SKIP&SYSCNT ANOP",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # t_macro_label_param: &LAB — label-field parameter
    # When the macro call has a label, &LAB receives it.
    # MYMARK LABELED_NOP → emits NOP with label MYMARK.
    #        LABELED_NOP → emits NOP with no label.
    # BRA MYMARK (offset -4 from PC after BRA = $FC)
    # Expected bytes: EA EA 80 FC 60
    #   byte 0:  EA  = NOP  (MYMARK)
    #   byte 1:  EA  = NOP
    #   byte 2:  80  = BRA
    #   byte 3:  FC  = -4  (target is offset 0; PC after BRA = offset 4)
    #   byte 4:  60  = RTS
    # ------------------------------------------------------------------
    "t_macro_label_param.mac": [
        "         MACRO",
        "&LAB     LABELED_NOP",
        "&LAB     NOP",
        "         MEND",
    ],

    # ------------------------------------------------------------------
    # neg_macro_actr: infinitely recursive macro (no exit condition)
    # The default ACTR limit stops it after many expansions and
    # produces an error.  With +T (terminal on first error), assembly
    # must fail with a non-zero exit code.
    # ------------------------------------------------------------------
    "neg_macro_actr.mac": [
        "         MACRO",
        "         RECURSE",
        "         NOP",
        "         RECURSE",
        "         MEND",
    ],
}


# ---------------------------------------------------------------------------
# Writer
# ---------------------------------------------------------------------------

def write_mac(path, lines):
    """Write lines joined with CR (0x0D) to path."""
    content = '\r'.join(lines) + '\r'
    with open(path, 'wb') as f:
        f.write(content.encode('ascii'))


def main():
    if len(sys.argv) > 1:
        out_dir = sys.argv[1]
    else:
        here = os.path.dirname(os.path.abspath(__file__))
        out_dir = os.path.join(here, '..', 'tests')
    out_dir = os.path.abspath(out_dir)

    print(f'Writing .mac files to: {out_dir}')
    for name, lines in MAC_FILES.items():
        path = os.path.join(out_dir, name)
        write_mac(path, lines)
        print(f'  {name}  ({sum(len(l)+1 for l in lines)} bytes)')
    print(f'Done — {len(MAC_FILES)} files written.')


if __name__ == '__main__':
    main()
