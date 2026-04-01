******************************************************************
* t_macro_gbl.asm
*
* GBLA: global arithmetic variable that persists across macro calls.
* Unlike LCLA (reset per call), GBLA retains its value between
* invocations — even across invocations of different macros that
* declare the same GBLA name.
*
* Both macros share COUNT.  INIT_COUNT resets it to 0, then each
* BUMP_LDA increments it by 1 and loads the result into A.
*
* Macros defined in t_macro_gbl.mac.
*
* Expected bytes: A9 01 A9 02 A9 03 60
*   A9 01 = LDA #$01   (first  BUMP_LDA)
*   A9 02 = LDA #$02   (second BUMP_LDA)
*   A9 03 = LDA #$03   (third  BUMP_LDA)
*   60    = RTS
******************************************************************
         MCOPY t_macro_gbl.mac
         LONGA OFF
         LONGI OFF

TEST     START

         INIT_COUNT
         BUMP_LDA
         BUMP_LDA
         BUMP_LDA
         RTS

         END
