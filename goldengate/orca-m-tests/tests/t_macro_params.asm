******************************************************************
* t_macro_params.asm
*
* Positional parameter substitution: the VAL parameter is replaced
* with the argument at each call site.  Macro in t_macro_params.mac.
*
* Expected bytes: A9 42 A9 FF 60
*   A9 42 = LDA #$42
*   A9 FF = LDA #$FF
*   60    = RTS
******************************************************************
         MCOPY t_macro_params.mac
         LONGA OFF
         LONGI OFF

TEST     START

         LOADA $42
         LOADA $FF
         RTS

         END
