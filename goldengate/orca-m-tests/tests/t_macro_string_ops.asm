******************************************************************
* t_macro_string_ops.asm
*
* LCLC / SETC / AMID: local character variables and substring ops.
*
* AMID str,start,len extracts a substring (1-indexed).  Here the
* first character of the REG parameter is extracted to dispatch the load.
*
* LOAD_REG A,$11 → LDA #$11
* LOAD_REG X,$22 → LDX #$22
* LOAD_REG Y,$33 → LDY #$33
*
* Macro defined in t_macro_string_ops.mac.
*
* Expected bytes: A9 11 A2 22 A0 33 60
*   A9 11 = LDA #$11
*   A2 22 = LDX #$22
*   A0 33 = LDY #$33
*   60    = RTS
******************************************************************
         MCOPY t_macro_string_ops.mac
         LONGA OFF
         LONGI OFF

TEST     START

         LOAD_REG A,$11
         LOAD_REG X,$22
         LOAD_REG Y,$33
         RTS

         END
