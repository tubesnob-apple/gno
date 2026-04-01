******************************************************************
* t_macro_label_param.asm
*
* LAB: label-field parameter.  When the macro is invoked with a
* label in the label column, LAB receives that label string.
* The macro then emits that label on the relevant instruction.
*
* LABELED_NOP with label → label: NOP
* LABELED_NOP without    → (anonymous) NOP
*
* The emitted bytes are identical regardless of the label; what
* changes is the symbol table.  We verify byte output AND that
* the label MYMARK is reachable (used in BRA target — if missing,
* assembler would report "unresolved reference").
*
* Macro defined in t_macro_label_param.mac.
*
* Expected bytes: EA EA 80 FC 60
*   EA    = NOP at MYMARK     (first call, with label)
*   EA    = NOP               (second call, no label)
*   80 FC = BRA MYMARK        (offset = -4: back from PC after BRA)
*   60    = RTS
*
* BRA MYMARK offset calculation:
*   MYMARK is at segment offset 0.
*   BRA is at segment offset 2 (after 2 NOP bytes).
*   Branch source = end of BRA instruction = offset 4.
*   Offset = 0 - 4 = -4 = $FC (signed 8-bit).
******************************************************************
         MCOPY t_macro_label_param.mac
         LONGA OFF
         LONGI OFF

TEST     START

MYMARK   LABELED_NOP
         LABELED_NOP
         BRA  MYMARK
         RTS

         END
