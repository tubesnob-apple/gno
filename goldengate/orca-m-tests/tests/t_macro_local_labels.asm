******************************************************************
* t_macro_local_labels.asm
*
* SYSCNT: unique counter incremented for each macro expansion.
* Using LABEL&SYSCNT creates distinct labels across invocations
* so multiple calls do not generate duplicate-label errors.
* NOTE: ORCA/M does not use the @ prefix; bare SKIP&SYSCNT is correct.
*
* SKIP_NOP branches over one NOP via a local label.
* Two calls generate SKIP1 and SKIP2 — distinct names.
*
* BRA encoding: opcode $80, 8-bit signed offset from end of instr.
* BRA skipping 1 byte → offset = $01 → bytes 80 01
*
* Macro defined in t_macro_local_labels.mac.
*
* Expected bytes: 80 01 EA 80 01 EA 60
*   80 01 = BRA +1  (skip NOP)  — first call  (@SKIP1)
*   EA    = NOP     (skipped)
*   80 01 = BRA +1              — second call (@SKIP2)
*   EA    = NOP     (skipped)
*   60    = RTS
******************************************************************
         MCOPY t_macro_local_labels.mac
         LONGA OFF
         LONGI OFF

TEST     START

         SKIP_NOP
         SKIP_NOP
         RTS

         END
