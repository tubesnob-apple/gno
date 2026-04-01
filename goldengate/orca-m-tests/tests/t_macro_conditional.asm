******************************************************************
* t_macro_conditional.asm
*
* AIF (Assemble IF): conditional emission of instructions.
* AIF expr,.label branches to .label if expr is TRUE (non-zero).
*
* MAYBE_LDA 1 → condition true  → emit LDA #$AA
* MAYBE_LDA 0 → condition false → emit nothing (branches to .SKIP)
*
* Macro defined in t_macro_conditional.mac.
*
* Expected bytes: A9 AA 60
*   A9 AA = LDA #$AA    (from call with flag=1)
*           (nothing from call with flag=0)
*   60    = RTS
******************************************************************
         MCOPY t_macro_conditional.mac
         LONGA OFF
         LONGI OFF

TEST     START

         MAYBE_LDA 1
         MAYBE_LDA 0
         RTS

         END
