******************************************************************
*  EndProg.asm - define the ENDPROG terminal label
*
*  This replaces Z.EndP (an ORCA library object).  ORCA/M's
*  FAsmb.asm computes the assembler length as:
*      LEN  EQU  ENDPROG-ASM41-2
*  ENDPROG must therefore be an external label defined at the
*  very end of the linked program.
******************************************************************
ENDPROG	START
	END
