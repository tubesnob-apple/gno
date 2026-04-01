******************************************************************
* t_macro_multi_params.asm
*
* Multiple positional parameters, each substituted independently.
* SETREGS XVAL,AVAL emits LDX #XVAL then LDA #AVAL.
* Macro defined in t_macro_multi_params.mac.
*
* Expected bytes: A2 01 A9 02 60
*   A2 01 = LDX #$01
*   A9 02 = LDA #$02
*   60    = RTS
******************************************************************
         MCOPY t_macro_multi_params.mac
         LONGA OFF
         LONGI OFF

TEST     START

         SETREGS $01,$02
         RTS

         END
