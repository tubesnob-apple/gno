******************************************************************
* t_macro_loop.asm
*
* Recursive compile-time loop using AIF + self-invocation.
* GoldenGate ORCA/M does not support backward AGO (AGO to a label
* above the AGO line always hits ACTR limit).  Workaround: recursive
* macro with AIF base-case exit — NOPS_N calls itself with N-1.
*
* NOPS_N 3 → recurse 3 times → emits 3 NOP instructions
* NOPS_N 0 → base case → emits nothing
*
* Macro defined in t_macro_loop.mac.
*
* Expected bytes: EA EA EA 60
*   EA EA EA = 3× NOP   (from NOPS_N 3)
*              (nothing  from NOPS_N 0)
*   60       = RTS
******************************************************************
         MCOPY t_macro_loop.mac
         LONGA OFF
         LONGI OFF

TEST     START

         NOPS_N 3
         NOPS_N 0
         RTS

         END
