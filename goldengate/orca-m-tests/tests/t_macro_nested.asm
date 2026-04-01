******************************************************************
* t_macro_nested.asm
*
* Nested macro invocation: OUTER calls INNER during expansion.
* INNER must appear before OUTER in the .mac file so it is known
* when OUTER is defined.
*
* OUTER expands to: PHA  [INNER → NOP]  PLA
* Macros defined in t_macro_nested.mac.
*
* Expected bytes: 48 EA 68 60
*   48 = PHA
*   EA = NOP   (from INNER)
*   68 = PLA
*   60 = RTS
******************************************************************
         MCOPY t_macro_nested.mac
         LONGA OFF
         LONGI OFF

TEST     START

         OUTER
         RTS

         END
