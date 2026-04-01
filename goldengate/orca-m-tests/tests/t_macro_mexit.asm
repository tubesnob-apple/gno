******************************************************************
* t_macro_mexit.asm
*
* MEXIT: unconditional early exit from a macro body.
* When the FLAG parameter is non-zero, AIF branches to .DONE, skipping PHA.
*
* COND_PHA 1 → NOP then MEXIT → emits: NOP
* COND_PHA 0 → NOP then falls through → emits: NOP PHA
*
* Macro defined in t_macro_mexit.mac.
*
* Expected bytes: EA EA 48 60
*   EA    = NOP          (from first call,  flag=1)
*   EA 48 = NOP + PHA    (from second call, flag=0)
*   60    = RTS
******************************************************************
         MCOPY t_macro_mexit.mac
         LONGA OFF
         LONGI OFF

TEST     START

         COND_PHA 1
         COND_PHA 0
         RTS

         END
