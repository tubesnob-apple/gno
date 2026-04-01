******************************************************************
* t_macro_basic.asm
*
* Simplest possible macro: no parameters.  THREE_NOP emits three
* NOP instructions.  Macro is defined in t_macro_basic.mac and
* included via MCOPY.
*
* Expected bytes: EA EA EA 60
*   EA EA EA = NOP NOP NOP
*   60       = RTS
******************************************************************
         MCOPY t_macro_basic.mac
         LONGA OFF
         LONGI OFF

TEST     START

         THREE_NOP
         RTS

         END
