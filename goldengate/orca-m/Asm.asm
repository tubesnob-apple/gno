	KEEP	OBJ/ASM
	MCOPY ASM.MAC
	TITLE 'ORCA/M 2.0 Source  *** CONFIDENTIAL ***'
	LONGA OFF
	LONGI OFF
****************************************************************
*
*  ORCA/M ASM65816 2.0
*  January, 1990
*
*  A macro assembler for the 6502, 65C02 and 65816
*  microprocessors.
*
*  Written by Mike Westerfield
*
*  This source code is a trade secret of The Byte Works, Inc.,
*  and cannot be copied or used in any way without the written
*  permission of that company.
*
*  Object Module Copyright 1986-1990
*  by The Byte Works, Inc.
*  All rights reserved.
*
****************************************************************
*
*  Version 1.1; March 1988; Mike Westerfield
*
*  1.  Added FastFile handling
*  2.  Skips desktop debug characters
*
****************************************************************
*
*  Version 1.2; August 1989; Mike Westerfield
*
*  1.  Eliminated floating point DC bug
*
****************************************************************
*
*  Version 2.0; January 1990; Mike Westerfield
*
*  1.  Support tabs, long lines.
*  2.  Use GS/OS and shell class 1 calls.
*  3.  Generate OMF 2.0.
*
****************************************************************
*
*  Version 2.0.1; June 1993; Mike Westerfield
*
*  1.  Fixed COPY bug that wiped a file name when a copy was done.
*  2.  Fixed bugs that wiped out the byte past a symbol table.
*
****************************************************************
*
*  Version 2.0.2; June 1994; Mike Westerfield
*
*  1.  Fixed memory trash bug in SMDRP
*
****************************************************************
*
*  Version 2.1.0; March 1996; Mike Westerfield
*
*  1.  Fixed bug in segments using > 64K on disk.
*  2.  Added support for the extended character set.
*
****************************************************************
*
	COPY	DIRECTPAGE
ASM41	START
	BRL	FASMB
;
;  LANGNUM is the external language number to be used by this program.	Current
;  values are:
;
;	6502	  2
;	65816	  3
;
LANGNM	ENTRY
	DC	I'3'
;
;  CHIP allows the assembler to be reconfigured for any of the above three CPUs
;  without reassembling the program.  Values are:
;
;	6502	  0
;	65C02	  1
;	65816	  2
;
CHIP	ENTRY
	DC	I1'2'
;
;  Number of printing lines on a page.
;
LPERPAGE ENTRY
	DC	I1'60'	lines per printed page
	AIF	.NOT.DEBUG,.ASM41A
TRACE	ENTRY
	DC	I1'TRUE'
.ASM41A
	END

****************************************************************
*
*  OPCODE - Op Code Number Assignments
*
****************************************************************
*
OPCODE	DATA
;
;  Operation Codes
;
	DO	ADC	Flags:
	DO	AND	     7 - global label
	DO	CMP	     6 - valid outside START
	DO	EOR	     5 - valid in data area
	DO	LDA	     4 - valid only in a macro file
	DO	ORA	     3 - expand the label
	DO	SBC	     2 - expand the operand
	DO	ASL	     1 - evaluate the label
	DO	LSR	     0 - list the line
	DO	ROR
	DO	ROL
	DO	BIT
	DO	CPX
	DO	CPY
	DO	DEC
	DO	INC
	DO	LDX
	DO	LDY
	DO	STA
	DO	STX
	DO	STY
	DO	JMP
	DO	JSR
	DO	STZ
	DO	TRB
	DO	TSB
	DO	JSL
	DO	JML
	DO	COP
	DO	MVN
	DO	MVP
	DO	PEA
	DO	PEI
	DO	REP
	DO	SEP
	DO	PER
	DO	BRL
	DO	BRA
	DO	BEQ
	DO	BMI
	DO	BNE
	DO	BPL
	DO	BVC
	DO	BVS
	DO	BCC
	DO	BCS
	DO	CLI
	DO	CLV
	DO	DEX
	DO	DEY
	DO	INX
	DO	INY
	DO	NOP
	DO	PHA
	DO	PLA
	DO	PHP
	DO	PLP
	DO	RTI
	DO	RTS
	DO	SEC
	DO	SED
	DO	SEI
	DO	TAX
	DO	TAY
	DO	TSX
	DO	TXA
	DO	TXS
	DO	TYA
	DO	BRK
	DO	CLC
	DO	CLD
	DO	PHX
	DO	PHY
	DO	PLX
	DO	PLY
	DO	DEA
	DO	INA
	DO	PHB
	DO	PHD
	DO	PHK
	DO	PLB
	DO	PLD
	DO	WDM
	DO	RTL
	DO	STP
	DO	TCD
	DO	TCS
	DO	TDC
	DO	TSC
	DO	TXY
	DO	TYX
	DO	WAI
	DO	XBA
	DO	XCE
	DO	CPA
	DO	BLT
	DO	BGE
	DO	GBLA
	DO	GBLB
	DO	GBLC
	DO	LCLA
	DO	LCLB
	DO	LCLC
	DO	SETA
	DO	SETB
	DO	SETC
	DO	AMID
	DO	ASEARCH
	DO	AINPUT
	DO	AIF
	DO	AGO
	DO	ACTR
	DO	MNOTE
	DO	ANOP
	DO	DS
	DO	ORG
	DO	OBJ
	DO	EQU
	DO	GEQU
	DO	MERR
	DO	DIRECT
	DO	KIND
	DO	SETCOM
	DO	EJECT
	DO	ERR
	DO	GEN
	DO	MSB
	DO	LIST
	DO	SYMBOL
	DO	PRINTER
	DO	65C02
	DO	65816
	DO	LONGA
	DO	LONGI
	DO	DATACHK
	DO	CODECHK
	DO	DYNCHK
	DO	IEEE
	DO	NUMSEX
	DO	CASE
	DO	OBJCASE
	DO	ABSADDR
	DO	INSTIME
	DO	TRACE
	DO	EXPAND
	DO	DC
	DO	USING
	DO	ENTRY
	DO	OBJEND
	DO	DATA
	DO	PRIVDATA
	DO	END
	DO	ALIGN
	DO	START
	DO	PRIVATE
	DO	MEM
	DO	TITLE
	DO	RENAME
	DO	KEEP
	DO	COPY
	DO	APPEND
	DO	MCOPY
	DO	MDROP
	DO	MLOAD
	DO	MACRO
	DO	MEXIT
	DO	MEND

OPALIAS	DC	I1'ICMP,IBCC,IBCS'
ACUMLIST DC	I1'IADC,IAND,IBIT,ICMP,IEOR,ILDA,IORA,ISBC,0'
INDXLIST DC	I1'ICPX,ICPY,ILDX,ILDY,0'

PART	DC	I1'ISTART,IDATA,IGEQU,IMERR,ISETCOM'
	DC	I1'IERR,IGEN,IMSB,ILIST,ISYMBOL,IDIRECT'
	DC	I1'IPRINTER,I65C02,I65816,ILONGA,ILONGI'
	DC	I1'IIEEE,INUMSEX,ITRACE,IEXPAND,IKEEP,ICOPY,IINSTIME'
	DC	I1'IAPPEND,IMCOPY,IMDROP,IMLOAD,IRENAME,IABSADDR'
	DC	I1'ITITLE,IPRIVDATA,IPRIVATE,ICASE,IOBJCASE,IMEM'
	DC	I1'IDATACHK,ICODECHK,IDYNCHK'
PARTEND	ANOP
NUMPART	EQU	PARTEND-PART	number of op codes valid in partial
!			 assemblies
	END

****************************************************************
*
*  Available Operations Table
*
*  For each operation code, this table has a byte.  The byte
*  has bit 7 set if the op code is valid on the 65C02, and bit
*  6 set if it is valid on the 6502.
*
****************************************************************
*
AVOP	START
	DS	1
	D6502	 ADC
	D6502	 AND
	D6502	 CMP
	D6502	 EOR
	D6502	 LDA
	D6502	 ORA
	D6502	 SBC
	D6502	 ASL
	D6502	 LSR
	D6502	 ROR
	D6502	 ROL
	D6502	 BIT
	D6502	 CPX
	D6502	 CPY
	D6502	 DEC
	D6502	 INC
	D6502	 LDX
	D6502	 LDY
	D6502	 STA
	D6502	 STX
	D6502	 STY
	D6502	 JMP
	D6502	 JSR
	D65C02 STZ
	D65C02 TRB
	D65C02 TSB
	D65816 JSL
	D65816 JML
	D65816 COP
	D65816 MVN
	D65816 MVP
	D65816 PEA
	D65816 PEI
	D65816 REP
	D65816 SEP
	D65816 PER
	D65816 BRL
	D65C02 BRA
	D6502	 BEQ
	D6502	 BMI
	D6502	 BNE
	D6502	 BPL
	D6502	 BVC
	D6502	 BVS
	D6502	 BCC
	D6502	 BCS
	D6502	 CLI
	D6502	 CLV
	D6502	 DEX
	D6502	 DEY
	D6502	 INX
	D6502	 INY
	D6502	 NOP
	D6502	 PHA
	D6502	 PLA
	D6502	 PHP
	D6502	 PLP
	D6502	 RTI
	D6502	 RTS
	D6502	 SEC
	D6502	 SED
	D6502	 SEI
	D6502	 TAX
	D6502	 TAY
	D6502	 TSX
	D6502	 TXA
	D6502	 TXS
	D6502	 TYA
	D6502	 BRK
	D6502	 CLC
	D6502	 CLD
	D65C02 PHX
	D65C02 PHY
	D65C02 PLX
	D65C02 PLY
	D65C02 DEA
	D65C02 INA
	D65816 PHB
	D65816 PHD
	D65816 PHK
	D65816 PLB
	D65816 PLD
	D65816 WDM
	D65816 RTL
	D65816 STP
	D65816 TCD
	D65816 TCS
	D65816 TDC
	D65816 TSC
	D65816 TXY
	D65816 TYX
	D65816 WAI
	D65816 XBA
	D65816 XCE
	END

****************************************************************
*
*  Available Operations Table
*
*  For each binary operation code, this table has a byte.  The
*  byte has bit 7 set if the op code is valid on the 65C02, and
*  bit 6 set if it is valid on the 6502.
*
****************************************************************
*
AVAIL	START
	D6502		$00    BRK
	D6502		$01    ORA (ZP,X)
	D65816 	$02    COP ZP
	D65816 	$03    ORA ZP,S
	D65C02 	$04    TSB ZP
	D6502		$05    ORA ZP
	D6502		$06    ASL ZP
	D65816 	$07    ORA [ZP]
	D6502		$08    PHP
	D6502		$09    ORA #
	D6502		$0A    ASL A
	D65816 	$0B    PHD
	D65C02 	$0C    TSB ABS
	D6502		$0D    ORA ABS
	D6502		$0E    ASL ABS
	D65816 	$0F    ORA LONG
	D6502		$10    BPL R
	D6502		$11    ORA (ZP),Y
	D65C02 	$12    ORA (ZP)
	D65816 	$13    ORA (ZP,S),Y
	D65C02 	$14    TRB ZP
	D6502		$15    ORA ZP,X
	D6502		$16    ASL ZP,X
	D65816 	$17    ORA [ZP],Y
	D6502		$18    CLC
	D6502		$19    ORA ABS,Y
	D65C02 	$1A    INC A
	D65816 	$1B    TCS
	D65C02 	$1C    TRB ABS
	D6502		$1D    ORA ABS,X
	D6502		$1E    ASL ABS,X
	D65816 	$1F    ORA LONG,X
	D6502		$20    JSR ABS
	D6502		$21    AND (ZP,X)
	D65816 	$22    JSL LONG
	D65816 	$23    AND ZP,S
	D6502		$24    BIT ZP
	D6502		$25    AND ZP
	D6502		$26    ROL ZP
	D65816 	$27    AND [ZP]
	D6502		$28    PLP
	D6502		$29    AND #
	D6502		$2A    ROL A
	D65816 	$2B    PLD
	D6502		$2C    BIT ABS
	D6502		$2D    AND ABS
	D6502		$2E    ROL ABS
	D65816 	$2F    AND LONG
	D6502		$30    BMI R
	D6502		$31    AND (ZP),Y
	D65C02 	$32    AND (ZP)
	D65816 	$33    AND (ZP,S),Y
	D65C02 	$34    BIT ZP,X
	D6502		$35    AND ZP,X
	D6502		$36    ROL ZP,X
	D65816 	$37    AND [ZP],Y
	D6502		$38    SEC
	D6502		$39    AND ABS,Y
	D65C02 	$3A    DEC A
	D65816 	$3B    TSC
	D65C02 	$3C    BIT ABS,X
	D6502		$3D    AND ABS,X
	D6502		$3E    ROL ABS,X
	D65816 	$3F    AND LONG,X
	D6502		$40    RTI
	D6502		$41    EOR (ZP,X)
	D65816 	$42    WDM
	D65816 	$43    EOR ZP,S
	D65816 	$44    MVP LONG,LONG
	D6502		$45    EOR ZP
	D6502		$46    LSR ZP
	D65816 	$47    EOR [ZP]
	D6502		$48    PHA
	D6502		$49    EOR #
	D6502		$4A    LSR A
	D65816 	$4B    PHK
	D6502		$4C    JMP ABS
	D6502		$4D    EOR ABS
	D6502		$4E    LSR ABS
	D65816 	$4F    EOR LONG
	D6502		$50    BVC R
	D6502		$51    EOR (ZP),Y
	D65C02 	$52    EOR (ZP)
	D65816 	$53    EOR (ZP,S),Y
	D65816 	$54    MVN LONG,LONG
	D6502		$55    EOR ZP,X
	D6502		$56    LSR ZP,X
	D65816 	$57    EOR [ZP],Y
	D6502		$58    CLI
	D6502		$59    EOR ABS,Y
	D65C02 	$5A    PHY
	D65816 	$5B    TCD
	D65816 	$5C    JMP LONG
	D6502		$5D    EOR ABS,X
	D6502		$5E    LSR ABS,X
	D65816 	$5F    EOR LONG,X
	D6502		$60    RTS
	D6502		$61    ADC (ZP,X)
	D65816 	$62    PER
	D65816 	$63    ADC ZP,S
	D65C02 	$64    STZ ZP
	D6502		$65    ADC ZP
	D6502		$66    ROR ZP
	D65816 	$67    ADC [ZP]
	D6502		$68    PLA
	D6502		$69    ADC #
	D6502		$6A    ROR A
	D65816 	$6B    RTL
	D6502		$6C    JMP (ABS)
	D6502		$6D    ADC ABS
	D6502		$6E    ROR ABS
	D65816 	$6F    ADC LONG
	D6502		$70    BVS R
	D6502		$71    ADC (ZP),Y
	D65C02 	$72    ADC (ZP)
	D65816 	$73    ADC (ZP,S),Y
	D65C02 	$74    STZ ZP,X
	D6502		$75    ADC ZP,X
	D6502		$76    ROR ZP,X
	D65816 	$77    ADC [ZP],Y
	D6502		$78    SEI
	D6502		$79    ADC ABS,Y
	D65C02 	$7A    PLY
	D65816 	$7B    TDC
	D65C02 	$7C    JMP (ABS,X)
	D6502		$7D    ADC ABS,X
	D6502		$7E    ROR ABS,X
	D65816 	$7F    ADC LONG,X
	D65816 	$80    BRA R
	D6502		$81    STA (ZP,X)
	D65816 	$82    BRL R
	D65816 	$83    STA ZP,S
	D6502		$84    STY ZP
	D6502		$85    STA ZP
	D6502		$86    STX ZP
	D65816 	$87    STA [ZP]
	D6502		$88    DEY
	D65C02 	$89    BIT #
	D6502		$8A    TXA
	D65816 	$8B    PHB
	D6502		$8C    STY ABS
	D6502		$8D    STA ABS
	D6502		$8E    STX ABS
	D65816 	$8F    STA LONG
	D6502		$90    BCC R
	D6502		$91    STA (ZP),Y
	D6502		$92    STA (ZP)
	D65816 	$93    STA (ZP,S),Y
	D6502		$94    STY ZP,X
	D6502		$95    STA ZP,X
	D6502		$96    STX ZP,Y
	D65816 	$97    STA [ZP],Y
	D6502		$98    TYA
	D6502		$99    STA ABS,Y
	D6502		$9A    TXS
	D6502		$9B    TXY
	D65C02 	$9C    STZ ABS
	D6502		$9D    STA ABS,X
	D65C02 	$9E    STZ ABS,X
	D65816 	$9F    STA LONG,X
	D6502		$A0    LDY #
	D6502		$A1    LDA (ZP,X)
	D6502		$A2    LDX #
	D65816 	$A3    LDA ZP,S
	D6502		$A4    LDY ZP
	D6502		$A5    LDA ZP
	D6502		$A6    LDX ZP
	D65816 	$A7    LDA [ZP]
	D6502		$A8    TAY
	D6502		$A9    LDA #
	D6502		$AA    TAX
	D65816 	$AB    PLB
	D6502		$AC    LDY ABS
	D6502		$AD    LDA ABS
	D6502		$AE    LDX ABS
	D65816 	$AF    LDA LONG
	D6502		$B0    BCS R
	D6502		$B1    LDA (ZP),Y
	D6502		$B2    LDA (ZP)
	D65816 	$B3    LDA (ZP,S),Y
	D6502		$B4    LDY ZP,X
	D6502		$B5    LDA ZP,X
	D6502		$B6    LDX ZP,Y
	D65816 	$B7    LDA [ZP],Y
	D6502		$B8    CLV
	D6502		$B9    LDA ABS,Y
	D6502		$BA    TSX
	D65816 	$BB    TYX
	D6502		$BC    LDA ABS,X
	D6502		$BD    LDA ABS,X
	D6502		$BE    LDX ABS,Y
	D65816 	$BF    LDA LONG,X
	D6502		$C0    CPY #
	D6502		$C1    CMP (ZP,X)
	D65816 	$C2    REP #
	D65816 	$C3    CMP ZP,S
	D6502		$C4    CPY ZP
	D6502		$C5    CMP ZP
	D6502		$C6    DEC ZP
	D65816 	$C7    CMP [ZP]
	D6502		$C8    INY
	D6502		$C9    CMP #
	D6502		$CA    DEX
	D65816 	$CB    WAI
	D6502		$CC    CPY ABS
	D6502		$CD    CMP ABS
	D6502		$CE    DEC ABS
	D65816 	$CF    CMP LONG
	D6502		$D0    BNE R
	D6502		$D1    CMP (ZP),Y
	D6502		$D2    CMP (ZP)
	D65816 	$D3    CMP (ZP,S),Y
	D65816 	$D4    PEI ABS
	D6502		$D5    CMP ZP,X
	D6502		$D6    DEC ZP,X
	D65816 	$D7    CMP [ZP],Y
	D6502		$D8    CLD
	D6502		$D9    CMP ABS,Y
	D65C02 	$DA    PHX
	D65816 	$DB    STP
	D65816 	$DC    JML [ABS]
	D6502		$DD    CMP ABS,X
	D6502		$DE    DEC ABS,X
	D65816 	$DF    CMP LONG,X
	D6502		$E0    CPX #
	D6502		$E1    SBC (ZP,X)
	D65816 	$E2    SEP #
	D65816 	$E3    SBC ZP,S
	D6502		$E4    CPX ZP
	D6502		$E5    SBC ZP
	D6502		$E6    INC ZP
	D65816 	$E7    SBC [ZP]
	D6502		$E8    INX
	D6502		$E9    SBC #
	D6502		$EA    NOP
	D65816 	$EB    XBA
	D6502		$EC    CPX ABS
	D6502		$ED    SBC ABS
	D6502		$EE    INC ABS
	D65816 	$EF    SBC LONG
	D6502		$F0    BEQ R
	D6502		$F1    SBC (ZP),Y
	D6502		$F2    SBC (ZP)
	D65816 	$F3    SBC (ZP,S),Y
	D65816 	$F4    PEA ABS
	D6502		$F5    SBC ZP,X
	D6502		$F6    INC ZP,X
	D65816 	$F7    SBC [ZP],Y
	D6502		$F8    SED
	D6502		$F9    SBC ABS,Y
	D65C02 	$FA    PLX
	D65816 	$FB    XCE
	D65816 	$FC    JSR (ABS,X)
	D6502		$FD    SBC ABS,X
	D6502		$FE    INC ABS,X
	D65816 	$FF    SBC LONG,X
	END

****************************************************************
*
*  Op Code Names Table
*
*  Notes:
*	Changes to the size of this segment will require a change
*	to the variable OPSCLEN in SRSTR.
*
****************************************************************
*
OPSC	START
	USING OPCODE
;
;  Hash table - headers to entries
;
;  Note: Hash function is EOR of first 3 characters ANDED with
;  $1F.	This gives the number of the entry in this table which
;  points to the first entry for that value.
;
	DC	A'JANOP,JEQU,JSETC,JLCLC,JINC,JAMID,JSTA,JDC'
	DC	A'JPHP,JLDA,JCPY,JJSR,JCLC,JTAX,JAIF,JEND'
	DC	A'JMEXIT,JLDY,JBCS,JGEQU,JPEA,JRTS,JBEQ,JJMP'
	DC	A'JDEY,JDEX,JBLT,JBRK,JORA,JPLA,JCMP,JSTX'
;
;  Op code table.
;
;  Entries have the following format:
;
;	Byte	Use
;	----	---
;	0-7	op code name (ASCII characters)
;	8	flags
;	9	op code number
;	10,11 pointer to next entry for this hash value
;
;  Flag Values:
;
;	Bit	Use
;	---	---
;	7	global label
;	6	valid outside START
;	5	valid in data area
;	4	valid only in a macro file
;	3	expand the label
;	2	expand the operand
;	1	evaluate the label
;	0	list the line
;
	DOP	ADC,0F,JSTART
	DOP	AND,0F,JCPX
	DOP	CMP,0F,JBPL
	DOP	EOR,0F,JPLD
	DOP	LDA,0F,JAGO
	DOP	ORA,0F,JCOP
	DOP	SBC,0F,JSED
	DOP	ASL,0F,JPLB
	DOP	LSR,0F,JTXA
	DOP	ROR,0F,JRTI
	DOP	ROL,0F,JDATA
	DOP	BIT,0F,JENTRY
	DOP	CPX,0F,JKEEP
	DOP	CPY,0F,JRTL
	DOP	DEC,0F,JSETCOM
	DOP	INC,0F,JTRB
	DOP	LDX,0F,JABSADDR
	DOP	LDY,0F,JROL
	DOP	STA,0F,JMEND
	DOP	STX,0F,JINX
	DOP	STY,0F,JASL
	DOP	JMP,0F,JDS
	DOP	JSR,0F,JAND
	DOP	STZ,0F,0
	DOP	TRB,0F,JPLX
	DOP	TSB,0F,JPLY
	DOP	JSL,0F,JMVN
	DOP	JML,0F,JMVP
	DOP	COP,0F,JPEI
	DOP	MVN,0F,JTXY
	DOP	MVP,0F,JCLD
	DOP	PEA,0F,JINSTIME
	DOP	PEI,0F,JBRL
	DOP	REP,0F,JPER
	DOP	SEP,0F,JCLI
	DOP	PER,0F,JBVS
	DOP	BRL,0F,JPHD
	DOP	BRA,0F,JNOP
	DOP	BEQ,0F,JLIST
	DOP	BMI,0F,JSEP
	DOP	BNE,0F,JGBLA
	DOP	BPL,0F,JINY
	DOP	BVC,0F,JSTP
	DOP	BVS,0F,JOBJ
	DOP	BCC,0F,JDEC
	DOP	BCS,0F,JSBC
	DOP	CLI,0F,JINA
	DOP	CLV,0F,JRENAME
	DOP	DEX,0F,JPHA
	DOP	DEY,0F,JEOR
	DOP	INX,0F,JBIT
	DOP	INY,0F,JSTY
	DOP	NOP,0F,JCASE
	DOP	PHA,0F,JCLV
	DOP	PLA,0F,JSTZ
	DOP	PHP,0F,JCODECHK
	DOP	PLP,0F,JTAY
	DOP	RTI,0F,0
	DOP	RTS,0F,JSEC
	DOP	SEC,0F,JJSL
	DOP	SED,0F,JCPA
	DOP	SEI,0F,JTSX
	DOP	TAX,0F,JLSR
	DOP	TAY,0F,JTYA
	DOP	TSX,0F,JTXS
	DOP	TXA,0F,JLONGA
	DOP	TXS,0F,JWAI
	DOP	TYA,0F,JGEN
	DOP	BRK,0F,JXBA
	DOP	CLC,0F,JMNOTE
	DOP	CLD,0F,JPRINTER
	DOP	PHX,0F,JDEA
	DOP	PHY,0F,0
	DOP	PLX,0F,JTCS
	DOP	PLY,0F,JERR
	DOP	DEA,0F,J65C02
	DOP	INA,0F,JAINPUT
	DOP	PHB,0F,JORG
	DOP	PHD,0F,JMSB
	DOP	PHK,0F,JTCD
	DOP	PLB,0F,JWDM
	DOP	PLD,0F,0
	DOP	WDM,0F,JXCE
	DOP	RTL,0F,JEJECT
	DOP	STP,0F,0
	DOP	TCD,0F,JTDC
	DOP	TCS,0F,JTSC
	DOP	TDC,0F,JDYNCHK
	DOP	TSC,0F,JALIGN
	DOP	TXY,0F,JTYX
	DOP	TYX,0F,0
	DOP	WAI,0F,JDIRECT
	DOP	XBA,0F,J65816
	DOP	XCE,0F,0
	DOP	CPA,0F,0
	DOP	BLT,0F,JPHB
	DOP	BGE,0F,JPHX
	DOP	GBLA,2A,JGBLB
	DOP	GBLB,2A,JGBLC
	DOP	GBLC,2A,JIEEE
	DOP	LCLA,2A,0
	DOP	LCLB,2A,JLCLA
	DOP	LCLC,2A,JLCLB
	DOP	SETA,24,JSETB
	DOP	SETB,24,JBCC
	DOP	SETC,24,JSETA
	DOP	AMID,24,JTSB
	DOP	ASEARCH,24,JBVC
	DOP	AINPUT,24,0
	DOP	AIF,6E,JMLOAD
	DOP	AGO,6E,JBNE
	DOP	ACTR,2E,JNUMSEX
	DOP	MNOTE,2A,JPLP
	DOP	ANOP,2F,JBGE
	DOP	DS,2F,JASEARCH
	DOP	ORG,6F,JMERR
	DOP	OBJ,2F,JTRACE
	DOP	EQU,2F,JAPPEND
	DOP	GEQU,EF,JPHK
	DOP	MERR,6F,0
	DOP	DIRECT,6F,0
	DOP	KIND,2F,0
	DOP	SETCOM,6F,0
	DOP	EJECT,6F,0
	DOP	ERR,6F,JMEM
	DOP	GEN,6F,JKIND
	DOP	MSB,6F,JCOPY
	DOP	LIST,6F,JACTR
	DOP	SYMBOL,6F,JREP
	DOP	PRINTER,4F,JPRIVATE
	DOP	65C02,6F,0
	DOP	65816,6F,JMDROP
	DOP	LONGA,6F,JLONGI
	DOP	LONGI,6F,JEXPAND
	DOP	DATACHK,6F,0
	DOP	CODECHK,6F,0
	DOP	DYNCHK,6F,0
	DOP	IEEE,6F,JTITLE
	DOP	NUMSEX,6F,0
	DOP	CASE,6F,JDATACHK
	DOP	OBJCASE,6F,0
	DOP	ABSADDR,6F,0
	DOP	INSTIME,6F,0
	DOP	TRACE,6F,JOBJEND
	DOP	EXPAND,6F,0
	DOP	DC,2F,JSYMBOL
	DOP	USING,2F,JMACRO
	DOP	ENTRY,AF,JSEI
	DOP	OBJEND,2F,JOBJCASE
	DOP	DATA,AF,JBRA
	DOP	PRIVDATA,AF,0
	DOP	END,2C,JUSING
	DOP	ALIGN,6F,0
	DOP	START,8F,JBMI
	DOP	PRIVATE,8F,JPRIVDATA
	DOP	MEM,2F,0
	DOP	TITLE,6F,0
	DOP	RENAME,4F,0
	DOP	KEEP,4F,JJML
	DOP	COPY,6F,0
	DOP	APPEND,6F,JMCOPY
	DOP	MCOPY,6F,JPHY
	DOP	MDROP,6F,0
	DOP	MLOAD,6F,0
MACRO	ENTRY
	DOP	MACRO,10,JROR
	DOP	MEXIT,1E,JLDX
MENDCH	ENTRY
	DOP	MEND,1C,JADC
	END

****************************************************************
*
*  MACDAT - Macro Processing Common Data
*
****************************************************************
*
MACDAT	DATA
;
;  Variables in this area must be stacked for recursive calls.
;
LISTTOP	ANOP
STP	DS	4	source TP
MSEND	DS	4	source END
ACTR	DC	H'FF'	assembly branch counter
LSCNT	DS	4	local SCNT
LISTEND	ANOP
;
;  These variables need not be stacked.
;
MIN	DC	H'FF'	macro library in memory
MOPLEN	DS	1	length of MOP
MOP	DS	255	macro op code
MHDISP	DS	4	disp into macro hash table
MSTK	DS	4*(LISTEND-LISTTOP)	recursive stack
HSCNT	DC	I4'1'	highest SCNT so far
MTP	DS	4	macro TP
FLAB	DC	I1'0'	was a label sym parm declared?
LISTLEN	DC	I'LISTEND-LISTTOP'	length of recursive variables
SWITCHLEN DC	I'0'	# of chars SWTCH must switch
	END

****************************************************************
*
*  KEEPCOM - FKEEP Common Data Area
*
****************************************************************
*
KEEPCOM	DATA
;
;  General Constants
;
KEEPSIZE EQU	8192	chunk size of the keep buffer
TIME	EQU	$BF90	ProDOS time location
;
;  General Purpose Variables
;
DSCNT	DS	4	# bytes at end of module
HEAD	DS	4	header mark
KA	DS	1	temp register storage
KX	DS	1
KY	DS	1
MARK	DS	4	size of the keep file buffer (keephandle)
OLEN	DS	4	object module length (this segment only)
;
;  The following areas provide for the buffering of sequential constant
;  bytes so that excessive numbers of individual constant op codes do not
;  have to appear together.
;
KCNT	DS	1	number of constant bytes
CBYTES	DS	$EF	constant byte storage
;
;  This buffer is used to avoid ProDOS overhead for each individual byte written
;  to an object module.
;
MAXBCNT	EQU	64	max number of bytes in buffer
BUFFER	DS	MAXBCNT	object module buffer
BCNT	DS	1	number of bytes in BUFFER
	END

****************************************************************
*
*  EVALDT - FEVAL Common Data Area
*
****************************************************************
*
EVALDT	DATA
;
;  Variables that require stacking for a recursive entry.
;
CC	DS	1	character counter
TOP	DS	1	top of stack
TOP2	DS	1	end of list
NPARIN	DS	1	number of unbalenced left parins
SFLAG	DS	1	sign flag

STK	DS	5	stack area

DEPTH	DC	I1'10'	depth of expression evaluation
ESHAND	DS	4	evaluation stack handle
RECL	DC	I1'0'	FEVAL recursion level
TWORK	DS	4	address of recursive stack area
TLSP	DS	4	temp LSP
;
;  Token and temporary token storage.
;
TOKEN	ANOP		token information
TOK_TYPE DS	1	token type:
!				FF - EOF
!				00 - operation
!				01 - operand
TOK_OP	DS	4	token value, number, or name
TOK_EXT	DS	1	is the token external?
TOK_ISP	DS	1	in stack priority
TOK_ICP	DS	1	in coming priority

TTOKEN	ANOP		temporary token storage
TTOK_TYPE DS	1
TTOK_OP	DS	4
TTOK_EXT DS	1
TTOK_ISP DS	1
TTOK_ICP DS	1

EXTERNAL DS	2	is an operand external? (set by SUSTN)

TOKEN_LEN EQU	7	length of token type, value and ISP
;
;  List of reserved symbols and their names.
;
TOKLIST	DT	+,PLUS
	DT	-,MINUS
	DT	*,TIMES
	DT	/,DIV
	DT	|,BITSHIFT
	DT	!,BITSHIFT2
	DT	-,UMINUS
	DT	.NOT.,NOT
	DT	.AND.,AND
	DT	.OR.,OR
	DT	.EOR.,EOR
	DT	'<=',LE
	DT	'>=',GE
	DT	'<>',NE
	DT	<,LT
	DT	>,GT
	DT	'=',EQ
	DT	'(',LPARIN
	DT	')',RPARIN
	DC	I1'0'

NUMOPS	DC	I1'2,2,2,2,2,2,1,1'	number of operands for each operation
	DC	I1'2,2,2,2,2,2,2,2'
	DC	I1'2'
	END

****************************************************************
*
*  Uppercase - used to convert lowercase to uppercase
*
****************************************************************
*
Uppercase data
 dc i1'$00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F'
 dc i1'$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F'
 dc i1'$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F'
 dc i1'$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F'
 dc c'@ABCDEFGHIJKLMNO'
 dc c'PQRSTUVWXYZ[\]^_'
 dc c'`ABCDEFGHIJKLMNO'
 dc c'PQRSTUVWXYZ{|}~',i1'$7F'
 dc i1'$80,$81,$82,$83,$84,$85,$86,$87,$CB,$89,$80,$CC,$81,$82,$83,$8F'
 dc i1'$90,$91,$92,$93,$94,$95,$84,$97,$98,$99,$85,$CD,$9C,$9D,$9E,$86'
 dc i1'$A0,$A1,$A2,$A3,$A4,$A5,$A6,$A7,$A8,$A9,$AA,$AB,$AC,$AD,$AE,$AF'
 dc i1'$B0,$B1,$B2,$B3,$B4,$B5,$C6,$B7,$B8,$B8,$BA,$BB,$BC,$BD,$AE,$AF'
 dc i1'$C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CE'
 dc i1'$D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DD,$DE,$DF'
 dc i1'$E0,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF'
 dc i1'$F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF'
	end

****************************************************************
*
*  COMMON - Common Definitions and Data Areas
*
*  Notes:
*	Changes to the size of this segment will require a change
*	to the variables DATALEN and ANAMELEN in SRSTR.
*
****************************************************************
*
COMMON	DATA
;
;  Constants
;
ESC	EQU	$1B	ESC key code
RETURN	EQU	$0D	RETURN key code
TAB	EQU	$09	TAB key code

!			op code flag masks
PFLG	GEQU	$01	print flag
LBF	GEQU	$02	evaluate label flag
OPRF	GEQU	$04	expand operand mask
EXLB	GEQU	$08	expand label mask
ONLY_IN_MACRO GEQU $10	valid only in a macro?
VDATA	GEQU	$20	valid in data area?
STRT	GEQU	$40	START mask
GBL	GEQU	$80	global label mask

!			label flags
LBFIXED	EQU	$01	is the label a fixed value?
LBREL	EQU	$02	is the label a relative offset?
LBEXPR	EQU	$04	is the label value an expression?
LBDUP	EQU	$80	is the label a duplicate?

hashSize EQU	877	# entries in hash table
HTABLESIZE EQU HASHSIZE*4	size of hash table

;		 ABCDEFGHIJKLMNOPQRSTUVWXYZ
SET_L	EQU	%00000000000100000000000000000000 set constants
SET_M	EQU	%00000000000010000000000000000000
SET_P	EQU	%00000000000000010000000000000000
SET_S	EQU	%00000000000000000010000000000000
SET_E	EQU	%00001000000000000000000000000000
SET_W	EQU	%00000000000000000000001000000000
SET_T	EQU	%00000000000000000001000000000000

GSIZE	GEQU	4096	size of global symbol table buffer
LSIZE	GEQU	4096	size of local symbol table buffer
PSIZE	GEQU	2048	size of sym parm tables buffer
ASIZE	GEQU	265	size of ainput buffer
MSIZE	GEQU	1024	size of macro name buffer
;
;  Variables saved at the start of pass 1 and restored at the start of pass 2.
;
CMTCOL	DC	I1'40'	comment column
STR	DS	4	location counter
ABSADDR	DS	4	"absolute" location counter
FSTART	DS	1	start found flag
DPPROMOTE DS	1	promoting a DP value to absolute?
FDIRECT	DC	I1'0'	direct page override?
DPVALUE	DC	I'0'	value of direct page
MLIB	DC	4I1'0'	macro library use flags
EDITOR	DC	I'1'	return to editor on terminal error
TERMINAL DC	I'0'	all errors are terminal
WAIT	DC	I'0'	pause on errors
MACROFILE DC	I'0'	opening a macro file
ERRORS	DC	I1'1'	list errors flag
GENER	DC	I1'0'	generate flag
ASCII	DC	I1'1'	character type flag
LIST	DC	I1'0'	list output flag
SYM	DC	I1'0'	list symbols flag
PRNT	DC	I1'0'	printer in use flag
F65C02	DS	1	65C02 active flag
F65816	DS	1	65816 active flag
FLONGA	DC	I1'1'	long accumulator flag
FLONGI	DC	I1'1'	long index register flag
! The relative order of the next two variables in important
FDATACHK DC	I1'1'	check for data bank crossings?
FCODECHK DC	I1'1'	check for code bank crossings?
FDYNCHK	DC	I1'1'	allow references to dynamic segments?
FIEEE	DC	I1'1'	IEEE format flag
FNUMSEX	DC	I1'0'	most sig byte first?
FCASE	DC	I1'0'	case sensitive?
FOBJCASE DC	I1'0'	object modules case sensitive?
FABSADDR DC	I1'0'	absolute address flag
FINSTIME DC	I1'0'	instruction time flag
TRCEFL	DC	I1'0'	trace flag
EXP	DC	I1'0'	expand DC flag
ENDPASS	ANOP

TAP	DS	4	temp storage for AP
;
;  Initialized Data Areas
;
SEGPTR	DC	I4'0'	pointer to segment names list
SEGLAST	DC	I4'0'	pointer to last entry stored
AFIRST	DC	I4'0'	pointer to first AINPUT string
ALAST	DC	I4'0'	pointer to last AINPUT string
ALIGNVAL DC	I4'0'	ALIGN for current routine
COLS	DC	I1'80'	number of columns on a line
DATAF	DC	I'0'	data area flag
DATESTR	DW	'DD MMM YY'	date string value
ENDF	DC	I1'1'	END found flag
GLC	DC	I4'0'	generated line count
KEEPSPEC DC	I1'0'	was KEEP specified on source line?
LC	DC	I4'0'	source file line count
	DC	C' '	buffer so label expansion works
LINE	DS	255	source file line
	DC	I1'RETURN'
LNUM	DC	I1'0'	current printer line number
MCNT	DC	I4'0'	macro expansion counter
MTNL	DC	H'FF'	macro table nest level
OBJFLAG	DC	I1'0'	flag indicating if an OBJ area is active
ORGVAL	DC	I4'0'	ORG for current routine
PASS	DC	I1'1'	pass number
PNUM	DC	I'1'	page number
PRIVATE	DC	I1'FALSE'	private labels in this segment?
REDIRECT DC	I1'FALSE'	is output redirected?
STNUM	DC	I1'0'	number of starts found so far
STOUT	DC	I'1'	output to standard out?
SWITCH	DC	I1'0'	language switch flag
TIMESTR	DW	'HH:MM'	time string value
TITLE	DC	64I4'0'	page title message

GHAND	DS	4	handle for global symbol table
LHAND	DS	4	handle for local symbol table
AHAND	DS	4	handle for AINPUT buffer
THAND	DS	4	handle for macro table
PHAND	DS	20	handle for symbolic parameters
SPHAND	DS	4	current sym parm handle
LHHAND	DS	4	handle for local symbol hash table
GHHAND	DS	4	handle for global symbol hash table
MHHAND	DS	4	handle for macro hash table
;
;  Local initializaed data for AssembleCheck
;
NSTRT	DC	H'FF'	number of starts
NSFND	DC	I1'0'	number of segments found and assembled
NLST	DC	I1'255'	number of segments in the list
HANDLE	DC	I4'LLNAME'	handle for LLABEL
;
;  Uninitialized Data Areas
;
TEMPASS	DS	ENDPASS-CMTCOL+2	temp storage for pass restart area

GHASH	DS	4	global hash table addr
LHASH	DS	4	local hash table addr
MHASH	DS	4	macro hash table addr

LBPTR	DS	4	label name pointer
LBV	DS	4	  value
LBL	DS	2	  length attribute
LBT	DS	1	  type attribute
LNEXT	DS	4	  pointer to next label in chain
LBFLAG	DS	1	  flags
LBC	DS	1	  count attribute

LLBPTR	DS	4	line label name pointer
LLBV	DS	4	  value
LLBL	DS	2	  length attribute
LLBT	DS	1	  type attribute
LLNEXT	DS	4	  pointer to next label in chain
LLBFLAG	DS	1	  flags

LNAME	DS	256	name of a label
LLNAME	DS	256	name of local label

SMPARM	DS	4	pointer to sym param name
SLINK	DS	4	next parm link
SPT	DS	1	type attribute
SPCT	DS	1	count attribute
SPL	DS	1	length attribute

DISPSPT	EQU	SPT-SMPARM	disps into symbolic parm entry
DISPSPCT EQU	SPCT-SMPARM
DISPSPL	EQU	SPL-SMPARM
DISPVAL	EQU	SPL-SMPARM+1

ACUMF	DS	1	accumulator size flag
AEND	DS	4	end of AINPUT table
AMODE	DS	1	forced addressing mode
ASTART	DS	4	start if AINPUT table
BANKTYPE DS	1	type of bank checking:
!			  0 - data
!			  1 - code
BSHIFT	DS	1	bit shift count
CBUFF	DS	4	copy buffer pointer
CBUFFHAND DS	4	copy buffer handle
CEND	DS	4	current sym parm stack end
CFIRST	DS	4	pointer to first sym parm
CODE	DS	16	code bytes for listing
COMPLEX	DS	1	Anything but +, - used in expr?
COPYDEPTH DS	1	depth of copies in a segment
CSTART	DS	4	current sym parm stack start
DPLBL	DS	60	dup label flags
DUPDCNT	DS	1	duplicate global label count
ERR	DS	1	error number
FORCED	DS	1	indicates if addr mode is forced
GEND	DS	4	end of global symbol table
GLAB	DS	10	global label
GLOBUSE	DS	1	global label use flag for rel br
GSTART	DS	4	start of global symbol table
INDXF	DS	1	index register size flag
INSTIME	DS	2	instruction time field
KINDUSED DS	1	has a KIND directive been used?
KINDVAL	DS	2	kind value
LEND	DS	4	end of local symbol table
LENGTH	DS	4	length of code in line
LERR	DS	1	error level in line
LLENGTH	DS	2	length of the current line
LSTART	DS	4	start of local symbol table
MACBUFF	DS	4	macro buffer address
MACEND	DS	4	macro buffer end
MEND	DS	4	end of macro buffer
MSTART	DS	4	start of macro buffer
NERR	DS	2	number of errors found
OBJORG	DS	4	OBJ value
OBJSTR	DS	4	STR at start of OBJ area
OP	DS	1	op code number for the current line
OPF	DS	1	op code flags
OPFIXED	DS	1	fixed operand flag
OPLEN	DS	1	op code length
OPR	DS	1	operand type
OPV	DS	4	operand value
PFIX	DS	256	postfix expression from FEVAL
PREC	DS	2	floating point precision
PROGRESS DS	1	print progress information?
QUOTE	DS	1	quote character in use
SEGNAME	DS	10	load segment name
SEGSTR	DS	256	object segment name
SEND	DS	4*5	symbolic parameter table end addrs
SFIRST	DS	4*5	pointers to first parm in each table
SMTNL	DS	1	set string macro table nest level
SOURCE	DS	1	0 if reads are from source file, 1 if
!			 from a macro file
SNAME	DS	256	subroutine name
SRCBUFF	DS	4	source buffer address
SRCEND	DS	4	first byte past the source buffer
SSTART	DS	4*5	symbolic parameter table start addrs
STLEN	DS	1	conditional asm string length
STRING	DS	256	build area for output strings
SYMBOLICS DS	1	are there symbolic parms in the line?
SSP	DS	4*5	symbolic parameter table stack pointers
TLB	DS	256	label for conditional goto
TX	DS	1	temporary X register
TY	DS	1	temporary Y register
TX1	DS	10	temp fp work area
USER_ID	DS	2	User ID
WORD	DS	256	word build area
WORK	DS	1031	work buffer
WORK2	DS	256	work buffers
;
;  Flags from the language interface with the shell
;
merr	ds	1	max error level allowed
merrf	ds	1	max error level found
lops	ds	1	operations flag
kflag	ds	1	keep flag
minus_f	ds	4	minus flags
plus_f	ds	4	plus flags
org	ds	4	origin
;
;  Tab line
;
TABS	DS	256
	END

****************************************************************
*
*  StackFrame - this segment is the stack frame for the shell
*
****************************************************************
*
StackFrame start Stack

	kind	$0012

	ds	1024
	end

	APPEND FASMB.ASM
