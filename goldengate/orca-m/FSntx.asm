****************************************************************
*
*  FSNTX - Syntax Analysis and Code Generation
*
*  INPUTS:
*	LINE - source line
*
*  OUTPUTS:
*	ERR - error code
*	CODE - code for printed line
*
****************************************************************
*
FSNTX	START
	USING COMMON
	USING EVALDT
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG FSNTX
;..............................................................;
;
;  Initialization.
;
;..............................................................;
;
	STZ	OP	zero op type
	STZ	LENGTH	zero length of code
	STZ	LENGTH+1
	STZ	LENGTH+2
	STZ	LENGTH+3
	STZ	BANKTYPE	default bank type is a directive
	STZ	RECL	zero recursion level
	STZ	LLNAME	blank the label
	STZ	DPPROMOTE	not promoting a DP value (yet)
	LDA	#' '	set inst time field
	STA	INSTIME
	STA	INSTIME+1
	LM	LLBT,#'M'	set type and length attributes
	STZ	LLBL
	STZ	LLBL+1
	CALL	FORML	form the line
	JSR	SCMNT	quit if the line is a comment
	BCC	EL
RTS	RTS

EL	LDA	OPF	see if label should be evaluated
	AND	#LBF
	BEQ	CD
	JSR	SELAB	evaluate the label

CD	LDA	DATAF	if odd(DATAF) and (VDATA & OPF)=0 then
	LSR	A
	BCC	EV
	LDA	#VDATA
	AND	OPF
	BNE	EV
	ERROR #16	  misplaced statement
;..............................................................;
;
;  Evaluate Instructions.
;
;..............................................................;
;
EV	LDX	OP	get op code
	CPX	#IGBLA	br if not an instruction
	JGE	DIR1
	JSR	SKLDF
	CPX	#ICLI	br if implied operand
	JGE	IMP

	CALL	SOPND	evaluate operand
	LDX	OP	br if relative branch
	CPX	#IPER
	JGE	RL1
;
;  General instructions.
;
	LDX	OP	set the type of bank checking
	LDA	BANKKIND-IADC,X
	STA	BANKTYPE
	LDA	F65C02	if processor is 6502
	ORA	F65816
	BNE	EV2A
	LDA	OPR	  and operand is (ZP) then
	CMP	#11
	BNE	EV2A
	SEC		    change it to (ABS)
	SBC	#5
	STA	OPR
	STZ	CODE+2
	INC	LENGTH
EV2A	LDX	OP	handle PEA as immediate
	CPX	#IPEA
	BNE	EV3
	LDA	OPR
	CMP	#2	...# is not really valid
	JEQ	ERR2
	CMP	#3	...zp, abs and long are valid - convert
	BEQ	EV2B	    them to immediate
	CMP	#8
	BEQ	EV2B
	CMP	#16
	BNE	EV3
EV2B	LM	LENGTH,#3
	LM	OPR,#2
	LM	FORCED,#1

EV3	CPX	#IJMP	JMP, JSR are always at least 2 byte
	BEQ	EV3A
	CPX	#IJSR
	BNE	EV4
EV3A	LDA	OPR
	CMP	#8
	BNE	EV4
	LM	LENGTH,#3
	LM	OPR,#3
EV4	LONG	M	get op code
	LDA	OP	M1L = OP*20
	AND	#$00FF
	DEC	A
	ASL	A
	ASL	A
	STA	M1L
	ASL	A
	ASL	A
	ADC	M1L
	CLC		M1L = M1L+#OPTBL (address of op codes)
	ADC	#OPTBL
	STA	M1L
	SHORT M
	LDY	OPR
	DEY
	LDA	(M1L),Y
	BNE	EV5
	LDX	FORCED	try changing type from ZP to ABS
	BNE	EV4A
	CPY	#7
	JLT	EV6
	LDX	FDIRECT
	BNE	EV4B
	LDX	F65816	... but not for 65816
	BEQ	EV4B
EV4A	PHY		(invalid operand, but try for correct	
	PHA		 code anyway)
	ERROR #2,R
	PLA
	PLY
EV4B	CPY	#12
	JGE	ERR2
	SEC
	TYA
	SBC	#5
	TAY
	STY	OPR
	INC	OPR
	INC	LENGTH
	LDA	(M1L),Y
	JEQ	EV6
	LDX	F65816	if this is a 65816 then
	BEQ	EV5
	PHA		  save op code
	INC	DPPROMOTE	  add in direct page value
	STZ	OPFIXED
	ADD2	CODE+1,DPVALUE
	PLA		  recover op code
EV5	STA	CODE	save op code
	LDX	F65816	check for availability
	BNE	AV2
	LDX	F65C02
	BNE	AV1
	TAX
	BIT	AVAIL,X
	BVS	AV2
	BRA	ERR2
AV1	TAX
	BIT	AVAIL,X
	BPL	ERR2
AV2	LDX	OP	MVN and MVP get special handleling
	CPX	#IMVN
	BEQ	EV5E
	CPX	#IMVP
	BNE	EV5D
EV5E	BRL	RTS2
EV5D	JSR	SKCNS	write op code to keep file
	LDX	LENGTH	write operand to keep file
	DEX
	BEQ	RTS2
	TXA
	LDX	#$ED
	CMP	#1
	BNE	EV5B
	LDX	#$EC
EV5B	LDY	GLOBUSE
	BEQ	EV5C
	LDY	FORCED
	BEQ	EV5A
EV5C	LDX	#$EB
EV5A	LDY	CODE
	CPY	#$22	(op code for JSL)
	BNE	EV5F
	LDX	#$F3
EV5F	JSR	SKEXP
	LDA	OPFIXED
	BNE	RTS2
	STZ	CODE+3
RTS2	LDY	CODE	set the INSTIME field
	LDA	TIME,Y
	STA	INSTIME
	LDA	COMTIME,Y
	STA	INSTIME+1
	RTS

ERR2	ERROR #2	invalid operand

EV6	CPY	#2	try changing from ZP or ABS to LONG
	BEQ	EV7
	CPY	#3
	BNE	ERR2
	LDY	#16
	BNE	EV8
EV7	LDY	#15
EV8	LDA	(M1L),Y
	STY	OPR
	INC	OPR
	TAX
	BEQ	ERR2

	LM	LENGTH,#4
	LDA	(M1L),Y
	BRL	EV5
;
;  Relative branch instructions.
;
RL1	LM	BANKTYPE,#2	check against code bank
	LDA	OPR	check operand type
	CMP	#3
	BEQ	RL2
	CMP	#16
	BEQ	RL2
	CMP	#8
	JNE	ERR2
RL2	LM	LENGTH,#2	split on range
	LDA	OP
	CMP	#IBRA
	BGE	RL3
	INC	LENGTH
RL3	LONG	I,M	compute branch
	LDA	OBJFLAG
	AND	#$00FF
	BEQ	RL3A
	SUB4	STR,OBJSTR,M1L
	ADD4	M1L,OBJORG
	ADD4	M1L,LENGTH
	BRA	RL3B
RL3A	ADD4	STR,LENGTH,M1L
	SUB4	M1L,#$1000
RL3B	SUB4	OPV,M1L,CODE+1
	SHORT I,M
	LDA	GLOBUSE	if globals used then skip out
	BNE	RL7	 of range check
	LDA	COMPLEX	if anything but +, - used then skip out
	BNE	RL7	 of range check
	LDY	CODE+2	check for branch out of range
	LDX	LENGTH
	LDA	CODE+4
	BMI	RL5
	ORA	CODE+3
	CPX	#2
	BNE	RL4
	ORA	CODE+2
	LDY	CODE+1
RL4	TAX
	BNE	ERR12
	TYA
	BPL	RL8
	BMI	ERR12
RL5	CMP	#$FF
	BNE	ERR12
	CMP	CODE+3
	BNE	ERR12
	CPX	#2
	BNE	RL6
	CMP	CODE+2
	BNE	ERR12
	LDY	CODE+1
RL6	TYA
	BMI	RL8
ERR12	ERROR #12,R	Rel Branch Out of Range
RL7	JSR	IMP2	keep external rel branch
	LDX	LENGTH
	DEX
	TXA
	JSR	SKREL
	BRL	RTS2

RL8	JSR	IMP2	keep fixed rel branch
	LDA	CODE+1
	JSR	SKCNS
	LDX	LENGTH
	DEX
	DEX
	BEQ	RL9
	LDA	CODE+2
	JSR	SKCNS
RL9	BRL	RTS2
;
;  Implied operand instructions.
;
IMP	LM	LENGTH,#1	set code length
IMP2	LDA	OP	set op code
	SEC
	SBC	#IPER
	TAX
	LDA	OPHX,X
	BEQ	IMP4
IMP3	STA	CODE
	JSR	SKCNS
	BRL	RTS2
;
;  Special handleing for 65816 BRK
;
IMP4	LDX	F65816	quit if 65816 is not on
	BEQ	IMP3
	STA	CODE+1	set code for listing
	STA	CODE
	JSR	SKCNS	keep op code
	JSR	SOPRF	branch if no operand
	BCC	IMP6
	JSR	SOPND	handle operand - must be ZP!
	LDA	OPR
	CMP	#8
	BNE	IMP5
	LDA	#1	keep operand
	LDX	#$EC
	BRL	SKEXP

IMP5	ERROR #2	imvalid operand

IMP6	LDA	#0	no operand - generate 0 second byte
	INC	LENGTH
	JSR	SKCNS
	BRL	RTS2
;..............................................................;
;
;  Pass control to proper assembler directive routine.
;
;..............................................................;
;
DIR1	LM	LLBT,#'N'	set type attribute
	CPX	#<IDS	conditional assembly
	JLT	PCOND
	CPX	#<IEJECT	immediate operand
	JLT	PIMDR
	CPX	#<IDC	implied operand
	JLT	PMPDR
	JEQ	PDCEV	DC evaluation
	CPX	#<IKEEP	file control
	JLT	PFLDR
DIR6	CPX	#<IMEND+1
	JLT	PDOSC	O/S control
DIR7	CPX	#<IBLT	macro call
	JGT	FMCRO
DIR8	ERROR #13	Unidentified Operation
;..............................................................;
;
;  Data areas.
;
;..............................................................;
;
OPHX	ANOP		op codes for implied and relative
!			 branch instructions
	DC	H'62 82 80'
	DC	H'F0 30 D0 10 50 70 90 B0'
	DC	H'58 B8 CA 88 E8 C8 EA 48'
	DC	H'68 08 28 40 60 38 F8 78'
	DC	H'AA A8 BA 8A 9A 98 00 18'
	DC	H'D8 DA 5A FA 7A 3A 1A 8B'
	DC	H'0B 4B AB 2B 42 6B DB 5B'
	DC	H'1B 7B 3B 9B BB CB EB FB'

TIME	DC	C'7674535632246465'	       $00
	DC	C'2557546624226475'	       $10
	DC	C'6684335642254465'	       $20
	DC	C'2557446624224475'	       $30
	DC	C'6624735632233465'	       $40
	DC	C'2557746624324475'	       $50
	DC	C'6664335642265465'	       $60
	DC	C'2557446624426475'	       $70
	DC	C'3644333622234445'	       $80
	DC	C'2657444625224555'	       $90
	DC	C'2624333622244445'	       $A0
	DC	C'2557444624224445'	       $B0
	DC	C'2634335622234465'	       $C0
	DC	C'2557646624336475'	       $D0
	DC	C'2634335622234465'	       $E0
	DC	C'2557546624428475'	       $F0

COMTIME	DC	C'******** *  ****'	       $00
	DC	C'******** *  ****'	       $10
	DC	C' * ***** *  ****'	       $20
	DC	C'******** *  ****'	       $30
	DC	C'**********   ***'	       $40
	DC	C'******** **  ***'	       $50
	DC	C' * *******  ****'	       $60
	DC	C'******** **  ***'	       $70
	DC	C'** ***** *  ****'	       $80
	DC	C'******** *  ****'	       $90
	DC	C'******** *  ****'	       $A0
	DC	C'******** *  ****'	       $B0
	DC	C'** ***** * *****'	       $C0
	DC	C'******** *** ***'	       $D0
	DC	C'** ***** *  ****'	       $E0
	DC	C'**** *** **  ***'	       $F0

OPTBL	ANOP
	DC	H'00696D7D 79000065 75007261 7173636F 7F677700' ADC
	DC	H'00292D3D 39000025 35003221 3133232F 3F273700' AND
	DC	H'00C9CDDD D90000C5 D500D2C1 D1D3C3CF DFC7D700' CMP
	DC	H'00494D5D 59000045 55005241 5153434F 5F475700' EOR
	DC	H'00A9ADBD B90000A5 B500B2A1 B1B3A3AF BFA7B700' LDA
	DC	H'00090D1D 19000005 15001201 1113030F 1F071700' ORA
	DC	H'00E9EDFD F90000E5 F500F2E1 F1F3E3EF FFE7F700' SBC
	DC	H'0A000E1E 00000006 16000000 00000000 00000000' ASL
	DC	H'4A004E5E 00000046 56000000 00000000 00000000' LSR
	DC	H'6A006E7E 00000066 76000000 00000000 00000000' ROR
	DC	H'2A002E3E 00000026 36000000 00000000 00000000' ROL
	DC	H'00892C3C 00000024 34000000 00000000 00000000' BIT
	DC	H'00E0EC00 000000E4 00000000 00000000 00000000' CPX
	DC	H'00C0CC00 000000C4 00000000 00000000 00000000' CPY
	DC	H'3A00CEDE 000000C6 D6000000 00000000 00000000' DEC
	DC	H'1A00EEFE 000000E6 F6000000 00000000 00000000' INC
	DC	H'00A2AE00 BE0000A6 00B60000 00000000 00000000' LDX
	DC	H'00A0ACBC 000000A4 B4000000 00000000 00000000' LDY
	DC	H'00008D9D 99000085 95009281 9193838F 9F879700' STA
	DC	H'00008E00 00000086 00960000 00000000 00000000' STX
	DC	H'00008C00 00000084 94000000 00000000 00000000' STY
	DC	H'00004C00 006C7C00 00000000 0000005C 000000DC' JMP
	DC	H'00002000 0000FC00 00000000 00000022 00000000' JSR
	DC	H'00009C9E 00000064 74000000 00000000 00000000' STZ
	DC	H'00001C00 00000014 00000000 00000000 00000000' TRB
	DC	H'00000C00 00000004 00000000 00000000 00000000' TSB
	DC	H'00000000 00000000 00000000 00000022 00000000' JSL
	DC	H'00000000 00DC0000 00000000 0000005C 000000DC' JML
	DC	H'00000000 00000002 00000000 00000000 00000000' COP
	DC	H'00005400 00000000 00000000 00000000 00000000' MVN
	DC	H'00004400 00000000 00000000 00000000 00000000' MVP
	DC	H'00F40000 00000000 00000000 00000000 00000000' PEA
	DC	H'00000000 000000D4 0000D400 00000000 00000000' PEI
	DC	H'00C20000 00000000 00000000 00000000 00000000' RSP
	DC	H'00E20000 00000000 00000000 00000000 00000000' SEP

BANKKIND DC	I1'1,1,1,1,1,1,1,1,1,1'
	DC	I1'1,1,1,1,1,1,1,1,1,1'
	DC	I1'1,2,2,1,1,1,2,2,1,1'
	DC	I1'1,2,2,1,1'
	END

****************************************************************
*
*  PCOND - Evaluate Conditional Assembly Directives
*
*  INPUTS:
*	OP - operation code
*	LINE - source line
*
****************************************************************
*
PCOND	START
	USING COMMON
	USING OPCODE
	USING MACDAT
	LONGA OFF
	LONGI OFF
	DEBUG PCOND
;..............................................................;
;
;  Symbolic parameter definition.
;
;..............................................................;
;
	LM	SMTNL,MTNL	set default macro table nest level
	LDX	OP	br if not LCLX or GBLX
	CPX	#ISETA
	BGE	SETA1

	TXA		find type code
	SEC		   a=0
	SBC	#IGBLA	   b=1
	CMP	#3	   c=2
	BLT	SPD1
	SEC
	SBC	#3

SPD1	CMP	#1	create entry
	BGE	SPD2
	SEC
	JSR	SDSPA	type a
	BRA	SPD4
SPD2	BNE	SPD3
	JSR	SDSPB	type b
	BRA	SPD4
SPD3	JSR	SDSPC	type c
SPD4	LDA	LERR	insert sym parm
	JEQ	SINSP
	RTS
;..............................................................;
;
;  Set symbols.
;
;..............................................................;
;
;  SETA
;
SETA1	BNE	SETB1

	JSR	OPRF	find operand
	JSR	FEVAL	evaluate operand
	LDA	LINE,Y	insure end of line
	CMP	#' '
	BEQ	SA0
	CMP	#RETURN
	JNE	ERR7
SA0	JSR	ERCHK
	MOVE4 OPV,LOPV
SA1	JSR	SPCK	find insert point
	LDA	SPT	check type
	CMP	#'X'
	BNE	TYPMS
	PHY
	LONG	M	set value
	LDA	LOPV
	STA	[R4]
	LDY	#2
	LDA	LOPV+2
	STA	[R4],Y
	SHORT M
	PLY
	RTS
;
;  SETB
;
SETB1	CPX	#<ISETC
	BGE	SETC1

	JSR	OPRF	evaluate logical expression
	JSR	FEVAL
	LM	LOPV,OPV
	LDA	LINE,Y	insure end of line
	CMP	#' '
	BEQ	SB1
	CMP	#RETURN
	BEQ	SB1
ERR7	ERROR #7	operand syntax
SB1	JSR	SPCK	find insert point
	LDA	SPT	check type
	CMP	#'Y'
	BEQ	SB2
TYPMS	ERROR #19	set symbol type mismatch
SB2	LDA	LOPV	move value
	STA	[R4]
	RTS
;
;  SETC
;
SETC1	BNE	AMID1

	JSR	OPRF	find operation
	JSR	SCHEX	evaluate character expression
	BRL	STRING	insert string
;..............................................................;
;
;  String directives.
;
;..............................................................;
;
;  AMID
;
AMID1	CPX	#IASEARCH
	BGE	ASRCH1

	JSR	OPRF	find operand
	JSR	SWORD2	place the string in word
	BCC	ERR7
	JSR	COMMA
	JSR	FEVAL	get start point
	JSR	RANGE

	STA	LOPV
	JSR	COMMA
	JSR	FEVAL	get length
	JSR	RANGE
	LDY	#0	move string
	LDX	LOPV
AM4	CPX	WORD	 check length
	BGT	AM6
	LDA	WORD,X	 move char
	STA	WORK+1,Y
	INY		 loop
	INX
	CPY	OPV
	BNE	AM4

AM6	STY	WORK	save length
	STY	STLEN
	BRL	STRING	save string
;
;  ASEARCH
;
ASRCH1	JNE	ANP1

	JSR	OPRF	find operand
	JSR	SWORD2	place search string in code
	BCC	SR3
	LDX	WORD
	STX	WORK
SR2	LDA	WORD,X
	STA	WORK,X
	DBNE	X,SR2
	JSR	COMMA
	BCS	SR4	place target string in word
SR3	ERROR #7	operand syntax
SR4	JSR	SWORD2
	BCC	SR3
	JSR	COMMA
	BCC	SR3
	JSR	FEVAL	get start point
	JSR	ERCHK
	JSR	RANGE
	SEC		set last valid search disp
	LDA	WORK
	SBC	WORD
	BCC	SR8
	SEC
	ADC	#<WORK
	STA	R0
	LDA	#>WORK
	ADC	#0
	STA	R1
	ADD2	OPV,#WORK,R2	set start pnt
SR5	CMPW	R0,R2	insure length ok
	BLT	SR8
	LDY	WORD	check for match
	DEY
SR6	LDA	(R2),Y
	CMP	WORD+1,Y
	BNE	SR7
	DBPL	Y,SR6
	BMI	SR9
SR7	INC	OPV	loop
	INC2	R2
	BNE	SR5

SR8	STZ	OPV	recover value of start of string
SR9	LM	LOPV,OPV	save value
	STZ	LOPV+1
	STZ	LOPV+2
	STZ	LOPV+3
	BRL	SA1	insert value
;
;  String insert routine.
;
STRING	DEBUG STRING	insert string in C type sym parm
	JSR	SPCK
	LDA	SPT
	CMP	#'Z'
	JEQ	STRNG
	ERROR #19
;
;  AINPUT - assembler input.
;
ANP1	CPX	#IAIF
	JGE	AIF1

	LDX	PASS	branch if pass 2
	DEX
	JNE	AN8
	JSR	SOPRF	print prompt
	BCC	AN2
	JSR	SWORD2
	LDX	WORD
	BEQ	AN2
	LDA	WORD	write message
	STA	AN1
	JSR	SRITE
	DC	H'40'
AN1	DS	1
	DC	A'WORD+1'
AN2	LM	WORK,#$FE	get input
	GETS	WORK
	PRINT
	LDY	#0	set operand
AN4	LDA	WORK+1,Y
	STA	WORK,Y
	INY
	BNE	AN4
	DEY
	LDY	WORK
	STY	STLEN
	JSR	SAINS	move string into AINPUT buffer
	MOVE	WORK,WORK2,#256	reset the line
	JSR	FORML
	MOVE	WORK2,WORK,#256
	BRL	STRING

AN8	JSR	SAINR	recover string for pass 2
	BRL	STRING
;..............................................................;
;
;  Conditional assembly branches.
;
;..............................................................;
;
;  AIF
;
AIF1	JSR	SKLDF
	CPX	#IAIF
	BNE	AGO1

	JSR	OPRF	evaluate logical expression
	JSR	FEVAL
	LDA	OPV	return if false
	ORA	OPV+1
	ORA	OPV+2
	ORA	OPV+3
	BEQ	RTS
	JSR	COMMA
	BRL	SGOTO
;
;  AGO
;
AGO1	CPX	#IACTR
	BGE	ACTR1

	JSR	OPRF	find operation
	BRL	SGOTO
;..............................................................;
;
;  ACTR
;
;..............................................................;
;
ACTR1	BNE	MNT1

	JSR	SOPND
	STZ	LENGTH
	STZ	LENGTH+1
	STZ	LENGTH+2
	JSR	ERCHK
	JSR	RANGE
	LM	ACTR,OPV
RTS	RTS
;..............................................................;
;
;  MNOTE and ANOP
;
;..............................................................;
;
MNT1	CPX	#IMNOTE
	BNE	RTS	br for anop

	BRL	SMNOT
;..............................................................;
;
;  Local subroutines and error returns.
;
;..............................................................;
;
;  ERCHK - don't return if lerr>=16.
;
ERCHK	DEBUG ERCHK
	LDA	LERR
	CMP	#16
	BLT	RTS
ER1	PLA
	PLA
	RTS
;
;  OPRF - find operand; don't return without it.
;
OPRF	DEBUG OPRF
	JSR	SOPRF	find operand
	BCS	RTS	br if ok
	PLA
	PLA
	ERROR #6	missing operand
;
;  SPCK - Find insert point for the symbolic parameter in the label
;  field.  Don't return without it.
;
SPCK	DEBUG SPCK
	LDA	LINE	insure sym parm
	CMP	#'&'
	BEQ	SP1
	PLA
	PLA
	ERROR #10	label syntax
SP1	LDY	#0	find data point
	JSR	SSPCK
	BCC	ER1
	BRA	ERCHK
;
;  COMMA - Checks for comma, advances to first character past comma.
;
COMMA	DEBUG COMMA
	LDA	LINE,Y	insure comma
	CMP	#','
	BEQ	CM2
CM1	PLA
	PLA
	ERROR #7	operand syntax
CM2	INY		check for continued
	LDA	LINE,Y
	CMP	#' '
	BEQ	CM1
	CMP	#RETURN
	BEQ	CM1
CMRTS	RTS
;
;  RANGE - insure that 0<OPV<256.
;
RANGE	DEBUG RANGE
	LDA	OPV+1
	ORA	OPV+2
	ORA	OPV+3
	BNE	RA1
	LDA	OPFIXED
	BEQ	RA2
	LDA	OPV
	BNE	CMRTS
RA1	PLA
	PLA
	ERROR #29	Length Exceeded
RA2	PLA
	PLA
	ERROR #15	Unresolved Label not Allowed

LOPV	DS	4	local OPV storage
	END

****************************************************************
*
*  PDCEV - Evaluate DC Statement
*
*  INPUTS:
*	LINE - source line
*
****************************************************************
*
PDCEV	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG PDCEV

	JSR	SOPRF	find the operand
	BCS	DC0
	ERROR #6	Missing Operand

DC0	STY	CC	set label type
DC0D	LDA	LINE,Y
	JSR	SNMID
	BCC	DC0C
	INY
	BNE	DC0D
DC0C	LDA	LINE,Y
	JSR	SHIFT
	STA	M1L
	LDX	#0
DC0A	LDA	TYPES,X
	BEQ	DC1
	CMP	M1L
	BEQ	DC0B
	INX
	BNE	DC0A
DC0B	LDA	TYPEC,X
	STA	LLBT
	JSR	SKLDF
	LDY	CC

DC1	STY	CC	save the position of the operand
DC2	LM	RPCT,#1	set the default repeat count
	LDY	CC	see if the line specifies a repeat count
	LDA	LINE,Y
	JSR	SNMID
	BCC	DC3
	JSR	SNMEV	yes -> evaluate it
	LM	RPCT,M1L
	STY	CC
	LDA	M1L+1
	ORA	M1L+2
	ORA	M1L+3
	BNE	ERR29
	LDA	M1L
	BNE	DC3
ERR29	ERROR #29	length exceeded
	LDY	CC

DC3	LDA	LINE,Y	fetch the letter identifying the type
	JSR	SHIFT	 of DC statement
	STA	M1L
	LDX	#0	scan the types table for it
DC4	LDA	TYPES,X
	BEQ	ERR7
	CMP	M1L
	BEQ	DC5
	INX
	BNE	DC4

DC5	TXA		use the displacement into TYPES to
	ASL	A	 create an indirect JSR to the proper
	TAX		 subroutine
	LDA	ADDRS,X
	STA	DC7+1
	LDA	ADDRS+1,X
	STA	DC7+2
	INC	CC	set the char counter past the id
DC6	LDY	CC	get the start position
DC7	JSR	DC7	evaluate the DC statement
	BCC	RTS
	DBNE	RPCT,DC6	loop if repeat count is not 0

	LDA	LINE,Y	check for another DC on the same line
	CMP	#','
	BNE	DC8
	INY		found -> go process it
	STY	CC
	BRL	DC1

DC8	CMP	#' '	make sure that the DC is followed by a
	BEQ	RTS	 blank or RETURN
	CMP	#TAB
	BEQ	RTS
	CMP	#RETURN
	BEQ	RTS
ERR7	ERROR #7	Operand Syntax
RTS	RTS

TYPES	DC	C'ABCDFHIRSE',I1'0'
TYPEC	DC	C'ABCDFHIKLD'

ADDRS	DC	A'SDCAD'	A
	DC	A'SDCBN'	B
	DC	A'SDCCH'	C
	DC	A'SDCDP'	D
	DC	A'SDCFP'	F
	DC	A'SDCHX'	H
	DC	A'SDCIX'	I
	DC	A'SDCHD'	R
	DC	A'SDCAD'	S
	DC	A'SDCEX'	E

CC	DS	1	character counter
RPCT	DS	1	repeat count
	END

****************************************************************
*
*  PDOSC - Evaluate ProDOS Control Directives
*
*  inputs:
*	OP - operation code (also in X)
*	LINE - source line
*
****************************************************************
*
PDOSC	START
	USING COMMON
	USING OPCODE
	USING MACDAT
	LONGA OFF
	LONGI OFF
	DEBUG PDOSC
;..............................................................;
;
;  Evaluate operand.
;
;..............................................................;
;
	LDA	OPF	check for statements valid only in
	AND	#ONLY_IN_MACRO	 macros
	BNE	ERR16
	JSR	SKLDF	keep label
	JSR	SOPRF	find operation
	BCS	OK
	ERROR #6	missing operand

ERR7	ERROR #7	Operand Syntax Error
ERR16	ERROR #16	Misplaced statement

OK	JSR	SWORD2	collect file name
	BCC	ERR7
	LDA	LINE,Y	make sure it is followed by a blank
	CMP	#' '
	BEQ	OK2
	CMP	#TAB
	BEQ	OK2
	CMP	#RETURN
	BNE	ERR7
OK2	LONG	M	make sure the name is not too long
	LDA	WORD
	AND	#$00FF
	CMP	#MAXNAME
	SHORT M
	BGT	ERR7
	jsr	SaveName	save the file name
;..............................................................;
;
;  Do command.
;
;..............................................................;
;
;  KEEP
;
	LDX	OP
	CPX	#ICOPY
	BGE	COPY1
	LDY	FSTART	if a KEEP has been specified or
	BNE	ERR	 a segment has been found, flag error
	LDA	KEEPSPEC	if a command line keep was specified,
	BEQ	KP2	 ignore the first source file keep
	DEC	KEEPSPEC
	RTS

KP2	INC	FSTART	indicate that KEEP was found
	LDA	PASS	all work done on pass 1 call
	CMP	#1
	BNE	RTS2
	jsr	SetKeepName	set keep file name
	LM	KFLAG,#1	set keep flag
	jsr	PartialNames	if not a partial assembly then
	BCS	RTS2
	JSR	DeleteObj	  delete old object modules
	JSR	SKINT	  open the keep segment
RTS2	RTS

ERR	ERROR #16	Misplaced Statement
;
;  COPY
;
COPY1	JNE	APND1

	LDA	MTNL	if in a macro then
	BPL	ERR	  error(16)
	LDA	PASS	skip building a copy segment if this is
	CMP	#2	 pass 2 and not in code segment
	BNE	CP0
	LDA	ENDF
	JNE	CP1
CP0	INC	COPYDEPTH	inc depth indicator
	NEW	WORK,#nameBuff+13	find a location for the copy segment
	JCS	TERR
	LOCK	WORK,R0
	JCS	TERR
	jsr	SaveFNameR0	move FNAME, CBUFF, TP and the memory
	LDY	#nameBuff	 segment number into the copy segment
	LONG	M
	LDA	CBUFF
	STA	[R0],Y
	INY
	INY
	LDA	CBUFF+2
	STA	[R0],Y
	INY
	INY
	SEC
	LDA	AP
	SBC	SRCBUFF
	STA	[R0],Y
	INY
	INY
	LDA	AP+2
	SBC	SRCBUFF+2
	STA	[R0],Y
	INY
	INY
	LDA	CBUFFHAND
	STA	[R0],Y
	INY
	INY
	LDA	CBUFFHAND+2
	STA	[R0],Y
	INY
	INY
	SHORT M
	LDA	ENDF	save ENDF status
	STA	[R0],Y
	MOVE4 R0,CBUFF	set the buffer pointer
	MOVE4 WORK,CBUFFHAND

CP1	LDA	PASS	make sure the right line gets
	CMP	#2	 printed
	BEQ	CP2
	LDA	ENDF
	BEQ	CP3
	INC4	LC
CP2	JSR	SLIST
CP3	JSR	CopyFile
	RTS

TERR	BRL	TERR1	Out of Memory

CP4	BRL	TERR4	File could not be opened
;
;  APPEND
;
APND1	CPX	#IMCOPY
	BGE	MCPY1
	LDA	MTNL	if in a macro then
	JPL	ERR	  error(16)
	LONG	I,M
	JSR	GetLanguage
	CMP	LANGNM
	SHORT I,M
	JEQ	CP1
	INC	SWITCH
	JSR	SetSFileName
	RTS
;
;  MCOPY
;
MCPY1	BNE	MDROP1

MCPY0	JSR	DuplicateName	check for duplicate
	BCS	RTS
	LDX	#3	find unused area
MCPY2	LDA	MLIB,X
	BEQ	MCPY3
	DBPL	X,MCPY2

	ERROR #14	too many libs

MCPY3	INC	MLIB,X	set use flag
	STX	R0
	jsr	SaveMName	save library name
	LDX	R0
RTS	LDA	OP	set min file if loaded
	CMP	#IMCOPY
	BEQ	RTS3
	BRL	LoadMacros
;
;  MDROP
;
MDROP1	CPX	#IMDROP
	BNE	MLOAD1

	LDA	PASS	skip if not pass 2
	DEC	A
	BEQ	RTS3
	JSR	DuplicateName	find macro lib to drop
	BCS	MDRP1
	ERROR #5	macro file not declared
MDRP1	LDA	#0	drop it
	STA	MLIB,X
	CPX	MIN
	BNE	RTS3
	JSR	SMDRP
	LM	MIN,#$FF
RTS3	RTS
;
;  MLOAD
;
MLOAD1	BRL MCPY0                    do mcopy
	END

****************************************************************
*
*  PFLDR - Evaluate File Control Directives
*
*  INPUTS:
*	OP - operation code (also in X)
*	LINE - source line
*
****************************************************************
*
PFLDR	START
	USING COMMON
	USING OPCODE
	USING MACDAT
	LONGA OFF
	LONGI OFF
	DEBUG PFLDR
;
;  USING
;
	CPX	#IENTRY
	BGE	ENT1

	JSR	SKLDF
	JSR	SOPRF	find operand
	JCC	ERR6A
	JSR	SLABL	mark keep name
	BCS	ER7B
	CMP	#' '
	BEQ	US1
	CMP	#RETURN
	BNE	ER7B
US1	BRL	SKDAT

ER7B	ERROR #7	Operand Syntax
;
;  ENTRY
;
ENT1	BNE	OBJ1	action by pass 1
	LDA	LLNAME
	BEQ	ERR10
	BRL	SKLDF

ERR10	ERROR #10	Missing label
;
;  OBJEND
;
OBJ1	CPX	#IOBJEND
	BNE	DAT1

	STZ	OBJFLAG
RTS2	RTS
;
;  DATA
;
DAT1	CPX	#IDATA
	BNE	PD1

	LDA	#1
	LDX	#0
	BRL	START1
;
;  PRIVDATA - private data segment
;
PD1	CPX	#IPRIVDATA
	BNE	END1

	INC	PRIVATE
	LDA	#$01
	LDX	#$40
	BRL	START1
;	
;  END
;
END1	CPX	#IEND
	JNE	PAGE1

	LDA	MTNL	check for END in a macro expansion
	BMI	END1A
	BRL	ERR16
END1A	JSR	SKLDF
	JSR	SKEND
	STZ	OBJFLAG	reset OBJ flag
	STZ	PRIVATE	reset private flag
	STZ	DATAF	reset data area flag
	STZ	DATAF+1
	LM	ENDF,#1	set end flag
	LM	ACTR,#$FF	reset asm counter
	STA	MTNL	set macro table nest level
	LONG	I,M
	MOVE4 PHAND,R0	delete extents to sym parm table
	JSR	SDELT
	MOVE4 R0,PHAND	restore table parameters
	LDY	#2
	LDA	[R0]
	STA	SSTART
	LDA	[R0],Y
	STA	SSTART+2
	ADD4	SSTART,#ASIZE,SEND
	ADD4	SSTART,#23+4,SSP	empty the symbolic parm table
	ADD4	SSTART,#4,SFIRST	(allow room for SYSCNT)
	MOVE4 SFIRST,R0
	LDY	#DISPVAL	& syscnt=1
	LDA	#1
	STA	[R0],Y
	STA	HSCNT
	INY
	INY
	DEC	A
	STA	[R0],Y
	STZ	HSCNT+2
	LDY	#4	set forward pointer to nil
	STA	[R0],Y
	INY
	INY
	STA	[R0],Y
	JSR	SETSP
	SHORT I,M
	LDX	PASS	branch if not pass 2
	DEX
	BEQ	RTS3
	LSR	OPF	list the END
	SEC
	ROL	OPF
	JSR	SLIST
	LSR	OPF
	ASL	OPF
	BRL	SENDP	do end of segment processing

RTS3	RTS
;
;  ALIGN
;
PAGE1	CPX	#ISTART
	BGE	START

	LM	LLBT,#'P'
	JSR	SKLDF
	JSR	SOPRF
	JCC	ERR6A
	JSR	FEVAL
	LDA	OPFIXED
	JEQ	ERR7A
	BRL SALIN

ERR6A	ERROR #6	missing operand
;
;  START
;
START	JNE	PR1
	LDA	#0	set start flag
	TAX
START1	STA	DATAF
	STX	DATAF+1
	STZ	KINDUSED	no KIND directive found so far
	LDA	MTNL	check for START or DATA in a macro
	BMI	START1B
	BRL	ERR16
START1B	STZ	COPYDEPTH	init copy depth counter
	LM	FSTART,#1	a segment has been found
	LDA	LLNAME	insure that there is a label
	BNE	START1A
	ERROR #10,R
	LM	LLNAME,#1
	LM	LLNAME+1,#'?'
START1A	JSR	SEGNM	set segment name and check for dups
	JSR	SYMPM	set up the predefined symbolic parms
	MOVE	#$20,SEGNAME,#10	set the load segment name
	JSR	SOPRF
	BCC	STAR2
	JSR	SLABL
	JCS	ERR7C
	CMP	#' '
	BEQ	STAR1
	CMP	#RETURN
	BNE	ERR7C
STAR1	MOVE	#$20,SEGNAME,#10
	LDY	LNAME
	CPY	#11
	BLT	STAR1A
	LDY	#10
STAR1A	DEY
STAR1B	LDA	LNAME+1,Y
	STA	SEGNAME,Y
	DBPL	Y,STAR1B
STAR2	LDA	KFLAG	pass dependent processing
	BEQ	STRT5
	LDX	STNUM
	BEQ	START2
	CMP	#3
	BEQ	START2
	jsr	PartialNames
	BCS	START2
	JSR	SaveFile
	LM	KFLAG,#3
	JSR	SKINT
START2	LDX	PASS	update keep file
	DEX
	BEQ	STRT5
	STX	STNUM
	LDA	DATAF
	LDX	DATAF+1
	JSR	SKLNT
STRT5	LDA	ENDF	check for no end error
	BNE	STRT2
	BRL	TERR8	no end error

STRT2	STZ	ENDF	set ENDF for START
	RTS

ERR7C	ERROR #7	operand syntax error
ERR6B	ERROR #6	missing operand
;
;  PRIVATE - private segment
;
PR1	CPX	#IPRIVATE
	BNE	MM1
	INC	PRIVATE
	LDA	#$00
	LDX	#$40
	BRL	START1
;
;  MEM - memory reservation
;
MM1	CPX	#ITITLE
	BGE	TL1
	JSR	SKLDF
	JSR	SOPRF
	BCC	ERR6B
	JSR	FEVAL
	LDA	OPFIXED
	BEQ	ERR7A
	LDA	LINE,Y
	CMP	#','
	BNE	ERR7A
	INY
	MOVE4 OPV,LOPV
	JSR	FEVAL
	LDA	OPFIXED
	BEQ	ERR7A
	LDA	LINE,Y
	CMP	#' '
	BEQ	MM2
	CMP	#RETURN
	BNE	ERR7A
MM2	MOVE4 LOPV,R8
	BRL SKMEM

ERR7A	ERROR #7	operand syntax
;
;  TITLE - title line
;
TL1	BNE	RN1
	JSR	SKLDF
	MOVE	#$20,WORD+1,#256
	JSR	SOPRF
	BCC	TL2
	JSR	SWORD2
	BCC	ERR7
TL2	MOVE	WORD+1,TITLE,#256
TL3	RTS

ERR6	ERROR #6	missing operand
ERR7	ERROR #7	operand syntax
ERR13	ERROR #13	unidentified operation
ERR16	ERROR #16	misplaced statement
;
;  RENAME - rename an op code
;
RN1	LDA	ENDF	error if in a segment
	BEQ	ERR16
	LDX	PASS	skip if pass 1
	DEX
	BEQ	TL3
	JSR	SOPRF	error if no operand found
	BCC	ERR6
	JSR	SWORD	error if a string is not found
	BCC	ERR7
	PHY		initialize the op code to blanks
	MOVE	#$20,STRING,#10
	PLY
	STY	TY
	LDX	WORD	error if new name > 8 chars
	CPX	#9
	BGE	ERR7
	STX	OPLEN	save length
RN2	LDA	WORD,X	set op code name
	STA	STRING-1,X
	DBNE	X,RN2
	JSR	SOPCD	find it in the op code table
	LDA	OP	error if not in table
	CMP	#IMEND+1
	BGE	ERR13
	LDY	TY	make sure there is a comma
	LDA	LINE,Y
	CMP	#','
	BNE	ERR7
	INY		read the new name
	JSR	SWORD
	BCC	ERR7
	LDA	LINE,Y	error if name is not followed by a space
	CMP	#' '
	BEQ	RN2A
	CMP	#RETURN
	BNE	ERR7
RN2A	LDX	WORD	error if new name is > 8 chars
	CPX	#9
	BGE	ERR7
	LDA	STRING	break the old chain
	EOR	STRING+1
	EOR	STRING+2
	AND	#$1F
	ASL	A
	TAX
	LDA	OPSC,X
	STA	R2
	LDA	OPSC+1,X
	STA	R3
	CMP	R1
	BNE	RN2B
	LDA	R2
	CMP	R0
	BNE	RN2B
	LDY	#10
	LDA	(R2),Y
	STA	OPSC,X
	INY
	LDA	(R2),Y
	STA	OPSC+1,X
	BRL	RN2E
RN2B	LDY	#10
	LDA	(R2),Y
	TAX
	INY
	LDA	(R2),Y
	CMP	R1
	BNE	RN2C
	CPX	R0
	BEQ	RN2D
RN2C	STA	R3
	STX	R2
	BRL	RN2B
RN2D	LDY	#10
	LONG	M
	LDA	(R0),Y
	STA	(R2),Y
	SHORT M
RN2E	LDY	#7	blank out the old name
	LDA	#' '
RN3	STA	(R0),Y
	STA	STRING,Y
	DBPL	Y,RN3
	LDY	WORD	fill in the new name
	DEY
RN4	LDA	WORD+1,Y
	JSR	SHIFT
	STA	(R0),Y
	STA	STRING,Y
	DBPL	Y,RN4
	LDA	STRING	insert into the hash table
	EOR	STRING+1
	EOR	STRING+2
	AND	#$1F
	ASL	A
	TAX
	LDY	#10
	LDA	OPSC,X
	STA	(R0),Y
	LDA	R0
	STA	OPSC,X
	INY
	LDA	OPSC+1,X
	STA	(R0),Y
	LDA	R1
	STA	OPSC+1,X
	LM	OP,#IRENAME	reset op code
	LM	OPF,#$4F	reset flags
	RTS

LOPV	DS	4	local OPV storage
	END

****************************************************************
*
*  PIMDR - Evaluate Immediate Operand Directives
*
*  INPUTS:
*	OP - operation number
*
****************************************************************
*
PIMDR	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG PIMDR
;
;  Evaluate operand.
;
	LDA	OP	don't evaluate the operand if this is
	CMP	#IDIRECT	 DIRECT and it is OFF
	BNE	DR1
	JSR	SOPRF
	BCC	EV1
	LDA	LINE,Y
	JSR	SHIFT
	CMP	#'O'
	BNE	EV1
	LDA	LINE+1,Y
	JSR	SHIFT
	CMP	#'F'
	BNE	EV1
	LDA	LINE+2,Y
	JSR	SHIFT
	CMP	#'F'
	BNE	EV1
	LDA	LINE+3,Y
	JSR	SWHIT
	BCC	EV1
	STZ	FDIRECT	turn off DIRECT and quit
	RTS

DR1	CMP	#IORG	skip operand read if this is an ORG
	BNE	EV1	 inside a subroutine
	LDA	ENDF
	BEQ	EV2
EV1	JSR	SOPND	evaluate operand
	STZ	LENGTH	reset length
	LDA	LERR
	CMP	#16
	BGE	RTS2
	LDA	OPR	check op type
	CMP	#3
	BEQ	EV2
	CMP	#8
	BEQ	EV2
	CMP	#16
	BEQ	EV2
	ERROR #2,R	operand mismatch

RTS2	RTS
;
;  DS - declare storage.
;
EV2	LDX	OP
	CPX	#IORG
	BCS	EV3

	MOVE4 OPV,LENGTH	move length
	LDA	OPFIXED	error if not a fixed value
	BNE	EV2A
	ERROR #2	invalid operand
EV2A	LM	LLBT,#'S'	set type
	JSR	SKLDF
	MOVE	#0,CODE,#16	set code
	BRL SKPDS
;
;  ORG - set location counter.
;
EV3	JNE	EV3C	branch if not ORG

	LM	LLBT,#'O'	set label type
	JSR	SKLDF
	LDA	ENDF	branch if in a segment
	BEQ	EV3A

	LDA	OPFIXED	flag error if not a constant
	BEQ	ERR25
	LDA	PASS	skip if not pass 2
	CMP	#2
	BNE	RTS
	LDA	ORGVAL	flag error if this is the second one
	ORA	ORGVAL+1	 for the current routine
	ORA	ORGVAL+2
	ORA	ORGVAL+3
	BNE	ERR16
	LDX	#3	set the ORG
RG1	LDA	OPV,X
	STA	ORGVAL,X
	STA	ABSADDR,X
	DBPL	X,RG1
RTS	RTS

ERR6	ERROR #6	operand not found
ERR16	ERROR #16	misplaced statement
ERR25	ERROR #25	unresolved ref not allowed

EV3A	JSR	SOPRF	locate the operand
	BCC	ERR6
	LDA	LINE,Y	insure that it starts with a *
	CMP	#'*'
	BNE	ERR16
	INY		evaluate the operand
	JSR	FEVAL
	LDA	OPFIXED	make sure it is fixed
	BEQ	ERR25
	LDA	LINE,Y	make sure it ends with a space
	JSR	SWHIT
	BCC	ERR25
EV3B	LONG	I,M
	ADD4	STR,OPV	update STR
	LDA	STR+2	if < $1000 then
	BMI	ERR35
	BNE	PS1
	LDA	STR
	CMP	#$1000
	BGE	PS1
ERR35	ERROR #35,R	  we backed up too far
PS1	ADD4	ABSADDR,OPV
	ADD4	LLBV,OPV	correct label value
	SHORT I,M
	BRL SKORG
;
;  OBJ - object location
;
EV3C	CPX	#IOBJ
	BNE	EV4

	JSR	SKLDF
	LONG	I,M
	MOVE4 STR,OBJSTR
	MOVE4 OPV,OBJORG
	SHORT I,M
	LM	OBJFLAG,#1
	LDY	OPFIXED
	JEQ	ERR25
	RTS
;
;  GEQU - set global label value.
;  EQU - set label value.
;
EV4	CPX	#IMERR
	BGE	EV5

	LDA	LLNAME	error if no label
	BEQ	ERR10
	LDA	LERR	quit if error
	BNE	EV5A
	MOVE4 OPV,LLBV	set label value
	LM	LLBT,#'G'	set label type
	LDA	ENDF	skip keep if not in seg
	BNE	SK1
	JSR	SKLDF	keep the label
	BRA	SK2
SK1	LDA	OPFIXED	outside segment - if operand is not
	BNE	SK2	 a constant, flag the error
	ERROR #25,R
SK2	LDA	LLBFLAG	set the expression kind flag
	EOR	#LBREL
	LDY	OPFIXED
	BNE	EV4A
	ORA	#LBEXPR
	BRA	EV4B
EV4A	ORA	#LBFIXED
EV4B	STA	LLBFLAG
	RTS

ERR10	ERROR #10	Missing label
;
;  MERR - set max allowed error.
;
EV5	BNE	EV5B
	LM	MERR,OPV
EV5A	RTS
;
;  DIRECT - set direct page value
;
EV5B	CPX	#IDIRECT
	BNE	KN1
	LDA	OPFIXED
	JEQ	ERR25
	LM	FDIRECT,#1
	MOVE	OPV,DPVALUE
	BRA	KN2
!	LDA	OPV+2
!	ORA	OPV+3
!	BNE	ERR29
!	RTS
;
;  KIND - set the kind of the segment
;
KN1	CPX	#IKIND
	BNE	EV6
	LDA	OPFIXED
	JEQ	ERR25
	LM	KINDUSED,#1
	MOVE	OPV,KINDVAL
KN2	LDA	OPV+2
	ORA	OPV+3
	BNE	ERR29
	RTS
;
;  SETCOM - get comment column.
;
EV6	JSR	SKLDF
	LDA	OPV+1
	ORA	OPV+2
	ORA	OPV+3
	BNE	ERR29
	LDA	OPV
	BEQ	ERR29
	CMP	#81
	BGE	ERR29
	STA	CMTCOL
	RTS

ERR29	ERROR #29	Length Exceeded
	END

****************************************************************
*
*  PMPDR - Evaluates Imlied Operand and ON|OFF Directives
*
*  INPUTS:
*	X - op code number
*
****************************************************************
*
PMPDR	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG PMPDR
;
;  EJECT - eject printer page.
;
	JSR	SKLDF
	CPX	#IERR
	BGE	MP1
	LDA	PASS
	CMP	#1
	JEQ	RTS
	BRL SNPGE
;
;  Read operand.
;
MP1	JSR	SOPRF	locate operand
	JSR	SWORD	read it
	BCC	ERR7
	LDA	LINE,Y
	CMP	#' '
	BEQ	MP1A
	CMP	#RETURN
	BNE	ERR7
MP1A	LDX	WORD
	CPX	#3
	BEQ	MP3
	CPX	#2
	BEQ	MP2
ERR7	ERROR #7	syntax error

MP2	LDY	#5	check for ON or OFF
	BNE	MP3A
MP3	LDY	#3
MP3A	LDA	WORD,X
	CMP	OFF-1,Y
	BNE	ERR7
	DEY
	DBNE	X,MP3A
	TYA		set flag
	BEQ	SL0
	LDY	#1

!			these checks make source line inputs
!			 top priority
SL0	LDX	OP	for LIST, skip if OUTF <> 2
	CPX	#ILIST
	BNE	SL1
	LONG	M
	LDA	PLUS_F+2
	ORA	MINUS_F+2
	AND	#^SET_L
	SHORT M
	BEQ	MP4
	RTS
SL1	CPX	#ISYMBOL	for SYMBOL, skip if SYMF <> 2
	BNE	MP4
	LONG	M
	LDA	PLUS_F
	ORA	MINUS_F
	AND	#SET_S
	SHORT M
	BEQ	MP4
	RTS

MP4	SEC		store it in the proper variable
	LDA	OP
	SBC	#IERR
	TAX
	TYA
	STA	ERRORS,X

	CPX	#IPRINTER-IERR	for PRINTER, turn it on or off
	BNE	MP6
	LDY	ENDF
	BEQ	ERR16
	TAY
	JNE	SPRON
	BRL	SPROF

ERR16	ERROR #16	Misplaced statement

MP6	CPX	#IMSB-IERR	for MSB, the flag is backwards
	BNE	MP7
	EOR	#1
	STA	ASCII
RTS	RTS

MP7	CPX	#ICASE-IERR	for CASE, set OBJCASE the same way
	BNE	RTS
	STA	FOBJCASE
	RTS

OFF	DC	C'OFFON'
	END

****************************************************************
*
*  SAINR - Recover string from AINPUT table
*
*  Inputs:
*	AFIRST - pointer to next string to recover
*
*  Outputs:
*	AFIRST - pointer to next string to recover
*	STLEN - length of string
*
****************************************************************
*
SAINR	START
	USING COMMON
	DEBUG SAINR

	LONG	I,M
	LDA	AFIRST	if AFIRST == 0 then
	ORA	AFIRST+2
	BNE	LB1
	SHORT I,M
	BRL	TERR9	  real bad error
	LONGA ON
	LONGI ON
LB1	ANOP		endif
	MOVE4 AFIRST,R0	R0 = AFIRST
	LDY	#2	AFIRST = *R0
	LDA	[R0]
	STA	AFIRST
	LDA	[R0],Y
	STA	AFIRST+2
	ADD4	R0,#4	R0 += 4
	LDA	[R0]	WORK = *R0
	AND	#$00FF
	TAY
	SHORT M
LB2	LDA	[R0],Y
	STA	WORK,Y
	DBPL	Y,LB2
	STA	STLEN
	SHORT I
	RTS

	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SAINS - Save string in AINPUT table
*
*  Inputs:
*	ASP - pointer to next spot
*	WORK - ProDOS format string to save
*	AEND - end of current table
*	AHAND - handle of current table
*	AFIRST - points to first string (may be nil)
*	ALAST - points to last string in table
*
****************************************************************
*
SAINS	START
	USING COMMON
	DEBUG SAINR

	LONG	I,M
	CLC		if (R4 = ASP + 5 + strlen(WORK))
	LDA	WORK
	AND	#$00FF
	ADC	#5
	ADC	ASP
	STA	R4
	LDA	ASP+2
	ADC	#0
	STA	R6
	CMP	AEND+2	  < AEND then
	BNE	LB1
	LDA	R4
	CMP	AEND
LB1	BGE	LB2
	MOVE4 ASP,R0	  R0 = ASP
	MOVE4 R4,ASP	  ASP = R4
	BRL	LB3	else
LB2	NEW	HAND,#ASIZE	  HAND = new(ASIZE)
	JCS	ERR
	LOCK	HAND,ASTART	  R0 =
	JCS	ERR	  ASTART = lock(HAND)
	MOVE4 ASTART,R0
	LDY	#2	  *R0 = AHAND
	LDA	AHAND
	STA	[R0]
	LDA	AHAND+2
	STA	[R0],Y
	MOVE4 HAND,AHAND	  AHAND = HAND
	ADD4	ASTART,#ASIZE,AEND	  AEND = ASTART+ASIZE
	ADD4	R0,#4	  R0 += 4
	CLC		  ASP = R0+5+strlen(WORK)
	LDA	WORK
	AND	#$00FF
	ADC	#5
	ADC	R0
	STA	ASP
	LDA	R2
	ADC	#0
	STA	ASP+2
LB3	ANOP		endif
	LDA	AFIRST	if AFIRST == nil then
	ORA	AFIRST+2
	BNE	LB4
	MOVE4 R0,AFIRST	  AFIRST = R0
	BRA	LB5	else
LB4	MOVE4 ALAST,R4	  *ALAST = R0
	LDY	#2
	LDA	R0
	STA	[R4]
	LDA	R2
	STA	[R4],Y
LB5	ANOP		endif
	MOVE4 R0,ALAST	ALAST = R0
	LDY	#2	*R0 = 0
	LDA	#0
	STA	[R0]
	STA	[R0],Y
	ADD4	R0,#4	R0 += 4
	LDA	WORK	*R0 = WORK
	AND	#$00FF
	TAY
	SHORT M
LB6	LDA	WORK,Y
	STA	[R0],Y
	DBPL	Y,LB6
	SHORT I
	RTS

ERR	SHORT I,M
	BRL	TERR5	could not allocate memory

HAND	DS	4
	END

****************************************************************
*
*  SALIN - Align Code
*
*  INPUTS:
*	OPV - value to align to
*	ENDF - end encountered flag
*	STR - location counter
*
*  OUTPUTS:
*	LENGTH - number of bytes needed to align (used if
*		inside a segment)
*	ALIGNVAL - alignment for the subroutine (used if
*		outside a segment)
*
****************************************************************
*
SALIN	START
	USING COMMON
	USING MACDAT
	LONGA OFF
	LONGI OFF
	DEBUG SALIN
;
;  Insure that the alignment is a power of 2.
;
	MOVE4 OPV,R0
	LDX	#0
	LDY	#32
AL1	LSR	R3
	ROR	R2
	ROR	R1
	ROR	R0
	BCC	AL2
	INX
AL2	DBNE	Y,AL1
	CPX	#1
	BLT	RTS2
	BEQ	AL3
	ERROR #35	operand value not allowed
RTS2	RTS
;
;  Split based on inside or outside of segment.
;
AL3	LDA	ENDF
	JEQ	AL5
;
;  Handle ALIGN before the START.
;
	LDA	PASS	skip if not pass 2
	CMP	#2
	BNE	RTS2
	LDA	ALIGNVAL	flag error if this is not the first one
	ORA	ALIGNVAL+1
	ORA	ALIGNVAL+2
	ORA	ALIGNVAL+3
	BEQ	AL4
	ERROR #16	misplaced statement

AL4	MOVE4 OPV,ALIGNVAL	set allignment
	STZ	TSTR	align ABSADDR
	STZ	TSTR+1
	STZ	TSTR+2
	STZ	TSTR+3
	LONG	M
AB1	LSR	OPV+2	form bit mask
	ROR	OPV
	BCS	AB2
	SEC
	ROL	TSTR
	ROL	TSTR+2
	BRL	AB1
AB2	SHORT M
	LDA	TSTR	 check for done
	AND	ABSADDR
	BNE	AB3
	LDA	TSTR+1
	AND	ABSADDR+1
	BNE	AB3
	LDA	TSTR+2
	AND	ABSADDR+2
	BNE	AB3
	LDA	TSTR+3
	AND	ABSADDR+3
	BEQ	RTS
AB3	INC	ABSADDR	update ABSADDR
	BNE	AB2
	INC	ABSADDR+1
	BNE	AB2
	INC	ABSADDR+2
	BNE	AB2
	INC	ABSADDR+3
	BNE	AB2
RTS	RTS
;
;  Handle ALIGN after the START.
;
AL5	CMPW	ALIGNVAL+2,OPV+2	make sure subroutine alignment is
	BNE	AL6	 sufficient
	CMPW	ALIGNVAL,OPV
AL6	BGE	AL7
	ERROR #35	operand value not allowed

AL7	STZ	R0	initialize alignment mask
	STZ	R1
	STZ	R2
	STZ	R3
	LONG	M
AL8	LSR	OPV+2	quit if mask is finished
	ROR	OPV
	BCS	AL9
	SEC		put a new bit in the mask
	ROL	R0
	ROL	R2
	BCC	AL8
AL9	SHORT M
	STZ	R4	see if alignment is required
	LONG	M
	SEC
	LDA	STR
	SBC	#$1000
	STA	LSTR
	STA	TSTR
	LDA	STR+2
	SBC	#0
	STA	LSTR+2
	STA	TSTR+2
	SHORT M
	LDX	#3
AL10	LDA	R0,X
	AND	LSTR,X
	ORA	R4
	STA	R4
	DBPL	X,AL10
	LDA	R4
	BNE	AL10A
	RTS

AL10A	LDX	#3	yes - zero the low bits
AL11	LDA	R0,X
	EOR	#$FF
	AND	LSTR,X
	STA	LSTR,X
	DBPL	X,AL11
	LONG	M,I	inc to next boundary
	SEC
	LDA	LSTR
	ADC	R0
	STA	R0
	LDA	LSTR+2
	ADC	R2
	STA	R2
	SUB4	R0,TSTR,LENGTH	compute length
	MOVE	#0,CODE,#16	do fake DS
	SHORT M,I
	BRL	SKPDS

LSTR	DS	4
TSTR	DS	4
	END

****************************************************************
*
*  SAVSP - Save Symbolic Parameter Pointers
*
*  Inputs:
*	MTNL - macro table nest level
*	CSP,CSTART,CEND,SPHAND,CFIRST - values to save
*
*  Outputs:
*	SSP,SSTART,SEND,PHAND,SFIRST - updated
*
*  Notes:
*	Can be called with 8 or 16 bit registers.
*
****************************************************************
*
SAVSP	START
	USING COMMON

	PHP		save register sizes
	LONG	I,M
	LDA	MTNL	X = disp into tables
	INC	A
	AND	#$FF
	ASL	A
	ASL	A
	TAX
	LDA	CSTART	save pointers
	STA	SSTART,X
	LDA	CSTART+2
	STA	SSTART+2,X
	LDA	CEND
	STA	SEND,X
	LDA	CEND+2
	STA	SEND+2,X
	LDA	CSP
	STA	SSP,X
	LDA	CSP+2
	STA	SSP+2,X
	LDA	SPHAND
	STA	PHAND,X
	LDA	SPHAND+2
	STA	PHAND+2,X
	LDA	CFIRST
	STA	SFIRST,X
	LDA	CFIRST+2
	STA	SFIRST+2,X
	PLP		restore register status
	RTS

	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SBASC - Convert double precision to AppleSoft BASIC
*
*  Inputs:
*	FR1 - SANE double precision number
*
*  Outputs:
*	FR1 - AppleSoft BASIC floating point number
*
****************************************************************
*
SBASC	START
	USING COMMON
	DEBUG SBASC
	LONGA ON
	LONGI ON

	CLC		change exponent to Applesoft bias
	LDA	FR1+6
	ADC	#$0020
	TAX
	EOR	FR1+6
	BMI	ERR11
	STX	FR1+6
	STX	FR1+8	save the sign bit
	JSR	ROLL	roll the number
	LDA	FR1+6	make sure most sig bits of exponent
	AND	#$F000	 match
	CMP	#$8000
	BEQ	LB1
	CMP	#$7000
	BNE	ERR11
LB1	JSR	ROLL	finish rolling out unneeded part of
	JSR	ROLL	 exponent
	ASL	FR1+6	restore sign
	SHORT M
	ASL	FR1+9
	ROR	FR1+6
	ASL	FR1+7	set msb
	ASL	FR1+9
	ROR	FR1+7
	LONG	M
	LDA	FR1+6	place in MSB first order
	XBA
	STA	FR1
	LDA	FR1+4
	XBA
	TAX
	LDA	FR1+2
	XBA
	STA	FR1+4
	STX	FR1+2
	RTS

ERR11	SHORT I,M
	ERROR #11,R
	LONG	I,M
	RTS
	
ROLL	ASL	FR1
	ROL	FR1+2
	ROL	FR1+4
	ROL	FR1+6
	RTS
	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SCHEK - Check for a Sequence Symbol
*
*  INPUTS:
*	LP - points to the line to check
*	TLE - sequence symbol to check for
*
*  NOTES:
*	1)  Does not return if there was a match.
*
****************************************************************
*
SCHEK	START
	USING COMMON
	USING MACDAT
	LONGA OFF
	LONGI OFF
	DEBUG SCHEK

	LDA	[AP]	quit if at EOF or if the line isn't
	CMP	#'.'	 a sequence symbol
	BNE	RTS
	LDA	AP+2
	CMP	SRCEND+2
	BNE	LB1
	LDA	AP+1
	CMP	SRCEND+1
	BNE	LB1
	LDA	AP
	CMP	SRCEND
LB1	BGE	RTS
	STZ	M3L	save the start of the line
	LDY	#1	compare TLB to the sequence symbol
	LDX	#0
CH1	INX
	LDA	[AP],Y
	CMP	#' '
	BEQ	CH2
	CMP	#RETURN
	BEQ	CH2
	CMP	TLB,X
	BEQ	CH1A
	LDA	FCASE
	BNE	RTS
	PHX
	LDA	[AP],Y
	TAX
	LDA	UPPERCASE,X
	PLX
	CMP	TLB,X
	BNE	RTS
CH1A	INY
	CPX	TLB
	BNE	CH1
	LDA	[AP],Y
	CMP	#' '
	BEQ	CH3
	CMP	#RETURN
	BEQ	CH3
	RTS
CH2	DEX
	CPX	TLB
	BNE	RTS

CH3	LDA	ACTR	check for an ACTR count exceeded error
	BEQ	ERR21
	DEC	ACTR
	BNE	CH4
ERR21	ERROR #21	ACTR count exceeded

CH4	PLA		match found
	PLA
	BRL	SRLIN	form the new line

RTS	RTS		no match - return
	END

****************************************************************
*
*  SCHEX - Character String Evaluation
*
*  INPUTS:
*	LINE - source line
*
*  OUTPUTS:
*	WORK - length of string
*	WORK+1 - string
*
****************************************************************
*
SCHEX	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SCHEX
;
;  Initialization.
;
	STZ	WORK	init length
;
;  Evaluate string.
;
CH1	LDA	LINE,Y	check for continuation
	CMP	#' '
	BEQ	SNTX
	CMP	#RETURN
	BEQ	SNTX
CH2	JSR	SWORD2	get 1st part
	LDA	WORD	check for format
	BEQ	CH4	 error
	BCC	SNTX
	LDX	WORK	move string
	STY	R0
	LDY	#0
CH3	LDA	WORD+1,Y
	STA	WORK+1,X
	INY
	INX
	CPY	WORD
	BNE	CH3

	STX	WORK	update length
	STX	STLEN
	LDY	R0	check for
CH4	LDA	LINE,Y	 concatination
	CMP	#'+'
	BNE	CH5
	INY		concatinate
	BNE	CH1

CH5	CMP	#' '	check for end
	BEQ	RTS
	CMP	#RETURN
	BEQ	RTS
SNTX	ERROR #7	operand syntax
RTS	RTS
	END

****************************************************************
*
*  SDCAD - Evaluate Address DC Statements
*  SDCSF - Evaluate Soft Reference DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCAD	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCAD

	LDA	LINE,Y	see if there is a size specified
	CMP	#'1'
	BLT	AD1
	CMP	#'4'+1
	BGE	AD1
	INY		yes -> use it
	BNE	AD2
AD1	LDA	#'2'	no -> use 2
AD2	BRL	SDCI4	evaluate the numbers
	END

****************************************************************
*
*  SDCBN - Evaluate Binary DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCBN	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCBN

	LDA	LINE,Y	get the initial quote mark
	JSR	SQUOT
	BCC	ERR7
	STA	QUOTE
	INY
	LDA	#' '	skip initial blanks
BN0	CMP	LINE,Y
	BNE	BN0A
	INY
	BNE	BN0
BN0A	LDA	LINE,Y	check for nul entry
	CMP	QUOTE
	BEQ	ERR7

BN1	LM	R0,#8	init the bit counter
	STZ	R1	init the byte
BN2	LDA	LINE,Y	skip blanks
	CMP	#' '
	BEQ	BN4
	CMP	QUOTE	quit if the end quote is found
	BEQ	BN5
	CMP	#'0'	make sure we have a 1 or 0
	BEQ	BN3
	CMP	#'1'
	BNE	ERR7
BN3	LSR	A	roll in the 1 or 0
	ROL	R1
	INY		next bit
	DBNE	R0,BN2

	LDA	R1	save a completed byte
	JSR	SDCCB
	BRL	BN1	next byte

BN4	INY		next character after a space
	BRL	BN2

BN5	INY		inc past the closing quote
	LDX	R0	quit now if the byte is not partially
	CPX	#8	 filled
	BEQ	BN7
	CLC		right pad the partially full byte
	LDA	R1	 with 0s
BN6	ROL	A
	DBNE	X,BN6
	JSR	SDCCB	save the filled byte
BN7	SEC		normal completion
RTS	RTS

ERR7	ERROR #7,R	Syntax Error
	CLC
	RTS
	END

****************************************************************
*
*  SDCCB - Keep a Constant Byte from a DC
*
*  INPUTS:
*	A - byte to save
*	LENGTH - current line length
*
*  OUTPUTS:
*	CODE - contains the byte if the length was OK
*	LENGTH - updated
*
*  NOTES:
*	1)  Entry at SDCCB2 does not save the byte to the
*		keep file.
*
****************************************************************
*
SDCCB	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCCB

	JSR	SKCNS	output the byte to the object module
SDCCB2	ENTRY
	PHY		save Y before wiping it
	LDY	LENGTH+1	insure that the length is < 16
	BNE	DC1
	LDY	LENGTH
	CPY	#16
	BGE	DC1
	STA	CODE,Y	save the byte for SLIST
DC1	PLY		restore Y
	INC2	LENGTH	update the length
	RTS
	END

****************************************************************
*
*  SDCCH - Evaluate Character DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCCH	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCCH

	LDA	LINE,Y	get the initial quote mark
	JSR	SQUOT
	BCC	ERR7
	STA	QUOTE
	INY

	LDA	ASCII	create the high bit mask
	LSR	A
	ROR	A
	EOR	#$80
	STA	R8
CH1	LDA	LINE,Y	get a character
	CMP	#RETURN	flag the error if at the end of the
	BEQ	ERR7	 line
	CMP	QUOTE	if a quote, quit if it is not doubled
	BNE	CH2
	INY
	LDA	LINE,Y
	CMP	QUOTE
	BNE	CH3
CH2	ORA	R8	set or clear the high bit
	JSR	SDCCB	save the character
	INY		next character
	BRL	CH1

CH3	SEC		normal return
RTS	RTS

ERR7	ERROR #7,R	Opernad Syntax
	CLC
	RTS
	END

****************************************************************
*
*  SDCDP - Evaluate Double Precision DC Statements
*  SDCFP - Evaluate Floating Point DC Statements
*  SDCEX - Evaluate SANE Extended FP DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCDP	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCDP

	LDA	#8	get the length
	BRA	FP0	go to common code

SDCEX	ENTRY
	DEBUG SDCEX
	LDA	#10
	BRA	FP0

SDCFP	ENTRY
	DEBUG SDCFP

	LDA	#5	get the length
	SEC
	SBC	FIEEE
FP0	STA	PREC	save the length
	LDA	LINE,Y	get the initial quote mark
	JSR	SQUOT
	BCC	ERR7
	STA	QUOTE
	INY

FP1	JSR	SFLOT	read and convert the number
	LDX	#0
FP2	LDA	FR1,X
	JSR	SDCCB
	INX
	CPX	PREC
	BNE	FP2
FP3	LDA	LINE,Y	skip blanks
	CMP	#' '
	BNE	FP4
	INY
	BNE	FP3
FP4	CMP	QUOTE	quit if a quote is found
	BEQ	FP5
	CMP	#','	loop if a comma is found
	BNE	ERR7
	INY
	BRL	FP1

FP5	INY		skip past the closing quote
	SEC		normal return
RTS	RTS

ERR7	ERROR #7,R	Operand Syntax
	CLC
	RTS
	END

****************************************************************
*
*  SDCHD - Evaluate Hard Reference DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*
****************************************************************
*
SDCHD	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCHD

	LDA	LINE,Y	get the initial quote mark
	JSR	SQUOT
	BCC	ERR7
	STA	QUOTE

HD1	INY
	JSR	SSKPL	skip blanks
	LDA	LINE,Y	error if nul entry
	CMP	QUOTE
	BEQ	ERR7
	CMP	#','
	BEQ	ERR7
	JSR	SLABL	read the label
	BCS	ERR7
	JSR	SKHRD	save the reference
	JSR	SSKPL	skip blanks
	LDA	LINE,Y	loop if there is a comma
	CMP	#','
	BEQ	HD1
	CMP	QUOTE	flag an error if there is not a
	BNE	ERR7	 closing quote
	INY		skip the closing quote
	SEC		normal return
RTS	RTS

ERR7	ERROR #7,R	Operand Syntax
	CLC
	RTS
	END

****************************************************************
*
*  SDCHX - Evaluate Hex DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCHX	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCHX

	LDA	LINE,Y	get the initial quote mark
	JSR	SQUOT
	BCC	ERR7
	STA	QUOTE
	LDA	#' '	skip initial blanks
BN0	CMP	LINE+1,Y
	BNE	BN0A
	INY
	BNE	BN0
BN0A	LDA	LINE+1,Y	check for nul entry
	CMP	QUOTE
	BEQ	ERR7

	LM	R0,#1	set the nibble counter
HX1	INY		skip over initial blanks
	LDA	LINE,Y
	CMP	#' '
	BEQ	HX1
	JSR	SHIFT	make sure its upper-case
	CMP	QUOTE	quit if we get a quote
	BEQ	HX3
	JSR	SHXID	make sure its hex
	BCC	ERR7
	JSR	SHXVL	change the char to a value
	LDX	R0	split based on which nibble is needed
	BEQ	HX2
	DEC	R0	place the digit in the most significant
	MASL	A,4	 nibble
	STA	R1
	BRL	HX1
HX2	INC	R0	place the right digit in the least
	ORA	R1	 significant digit
	JSR	SDCCB	save the nibble
	BRL	HX1	next byte

HX3	INY		point past the quote
	LDA	R0	if the byte is half full then
	BNE	HX4
	LDA	R1	 save it
	JSR	SDCCB
HX4	SEC		normal return
RTS	RTS

ERR7	ERROR #7,R	Operand Syntax
	CLC
	RTS
	END

****************************************************************
*
*  SDCI4 - Evaluate 1 to 4 Byte Integer DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*	X - label type
*	A - size of integers (ASCII character)
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCI4	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCI4

	AND	#$F	save the size of the integers
	STA	LEN
	STZ	LBSH
	LDA	LINE,Y	check for a bit shift operator
	CMP	#'<'
	BEQ	DC0B
	CMP	#'>'
	BEQ	DC0
	CMP	#'^'
	BNE	DC0C
	LDA	#16
	BNE	DC0A
DC0	LDA	#8
DC0A	STA	LBSH
DC0B	INY
	LDA	LINE,Y
DC0C	JSR	SQUOT	get the initial quote mark
	BCC	ERR7
	STA	QUOTE
	INY

DC1	JSR	SSKPL	skip blanks
	BCC	ERR7
	LDA	LINE,Y	error if nul entry
	CMP	QUOTE
	BEQ	ERR7
	CMP	#','
	BEQ	ERR7
	JSR	FEVAL	evaluate the expression
	LDA	LERR	quit if a severe error was found
	CMP	#16
	BGE	ERTS
	LONG	M	shift the bytes before saving
	LDA	OPV
	STA	LOPV
	LDA	OPV+2
	STA	LOPV+2
	LDX	LBSH
	BEQ	DC1B
DC1A	LSR	LOPV+2
	ROR	LOPV
	DBNE	X,DC1A
DC1B	SHORT M
	LDX	LEN	save the bytes for printing by SLIST
	STY	R0
	LDY	#0
DC2	LDA	LOPV,Y
	JSR	SDCCB2
	INY
	DBNE	X,DC2
	SEC		set the bit shift operator
	LDA	#0
	SBC	LBSH
	STA	BSHIFT
	LDA	LEN	save the expression
	LDX	#$EB
	JSR	SKEXP
	LDY	R0
	JSR	SSKPL	skip blanks
	LDA	LINE,Y
	CMP	QUOTE	quit if the closing quote is found
	BEQ	DC3
	CMP	#','	if a comma is found, do it all again
	BNE	ERR7
	INY
	BNE	DC1

DC3	INY		inc past the closing quote
	SEC		normal return
	RTS

ERR7	ERROR #7,R	Operand Syntax
ERTS	CLC		error return
RTS	RTS

LBSH	DS	1	local BSHIFT
LEN	DS	1	length of integers
LOPV	DS	4	local OPV
	END

****************************************************************
*
*  SDCI8 - Evaluate 5 to 8 Byte Integers
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*	X - label type
*	A - length of integers (ASCII characters)
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCI8	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCI8

	AND	#$0F	save the integer length
	STA	R0
	LDA	LINE,Y	get the initial quote mark
	JSR	SQUOT
	JCC	ERR7
	STA	QUOTE
	INY

DC1	LDX	#7	initialize the number
	LDA	#0
DC1A	STA	FR1,X
	DBPL	X,DC1A
	STZ	SIGN	set the sign of the number
	JSR	SSKPL
	LDA	LINE,Y
	CMP	#','	error if there is no entry
	JEQ	ERR7
	CMP	QUOTE
	JEQ	ERR7
	CMP	#'+'
	BEQ	DC2
	CMP	#'-'
	BNE	DC3
	INC	SIGN
DC2	INY		make sure there is at least one digit
DC3	JSR	SSKPL
	LDA	LINE,Y
	JSR	SNMID
	BCC	ERR7
DC4	JSR	SSKPL	read and convert the number
	LDA	LINE,Y
	JSR	SNMID
	BCC	DC5
	JSR	SDIGT
	BCS	OVRC
	INY
	BNE	DC4
DC5	LDX	#7	check for overflow
DC6	CPX	R0
	BLT	DC7
	LDA	FR1,X
	BNE	OVRC
	DBNE	X,DC6
DC7	LDA	FR1,X
	BMI	OVRC
	LDA	SIGN	check the sign
	BEQ	DC9
	SEC		FR1 = -FR1
	STY	R1
	LDY	#8
	LDX	#0
DC8	LDA	#0
	SBC	FR1,X
	STA	FR1,X
	INX
	DBNE	Y,DC8
	LDY	R1
DC9	LDX	#0	save the number
DC10	LDA	FR1,X
	JSR	SDCCB
	INX
	CPX	R0
	BLT	DC10
	LDA	LINE,Y	loop if the next character is a comma
	INY
	CMP	#','
	JEQ	DC1
	CMP	QUOTE	check for a closing quote
	BNE	ERR7
	SEC
	RTS

ERR7	ERROR #7,R	Operand Syntax
	CLC
	RTS

OVRC	STY	R1	overflow recovery
	ERROR #11,R	Numeric Error in Operand
	LDY	R1
OV1	JSR	SSKPL
	LDA	LINE,Y
	JSR	SNMID
	BCC	DC9
	INY
	BNE	OV1
	END

****************************************************************
*
*  SDCIX - Evaluate Integer DC Statements
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of the start of the DC
*	LENGTH - current line length
*
*  OUTPUTS:
*	Y - disp past DC
*	C - set if there are no errors, else clear
*	LENGTH - updated
*
****************************************************************
*
SDCIX	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDCIX

	LDA	LINE,Y	see if a size is specified
	CMP	#'1'
	BLT	DC1
	CMP	#'8'+1
	BGE	DC1
	INY		yes -> use it
	CMP	#'4'+1
	BGE	DC3
	BLT	DC2
DC1	LDA	#'2'	no -> use 2
DC2	BRL	SDCI4	evaluate the numbers

DC3	BRL	SDCI8	do special processing for 5 to 8 byte
	END		 integers

****************************************************************
*
*  SDELT - Delete extra symbol table areas
*
*  Inputs:
*	R0 - handle of first area
*
*  Outputs:
*	R0 - handle of main area
*
****************************************************************
*
SDELT	START
	DEBUG SDELT
	LONGA ON
	LONGI ON

LB1	MOVE4 R0,HAND	while next pointer <> nil do
	LDY	#2
	LDA	[R0]
	TAX
	LDA	[R0],Y
	STA	R2
	STX	R0
	LDA	[R0]
	ORA	[R0],Y
	BEQ	LB2
	LDA	[R0]	  get new handle
	TAX
	LDA	[R0],Y
	STA	R2
	STX	R0
	DISPOSE HAND	  dispose of old handle
	BRA	LB1	endwhile
LB2	MOVE4 HAND,R0
	RTS

HAND	DS	4
	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SDIGT - Multiplies FR1 by 10 and Adds in the New Digit
*
*  INPUTS:
*	A - new digit
*	FR1 - old number
*
*  OUTPUTS:
*	FR1 = FR1*10 + A
*	C - set if overflow to last byte
*
****************************************************************
*
SDIGT	START
	LONGA OFF
	LONGI OFF
	DEBUG SDIGT

	AND	#$F	save digit
	STA	R2
	STY	R3
	LDX	#7	TEMPZP=0
	LDA	#0
DG1	STA	TEMPZP,X
	DBPL	X,DG1
	LM	R1,#10	10 adds
DG2	LDX	#0
	LDY	#8
	CLC
DG3	LDA	FR1,X
	ADC	TEMPZP,X
	STA	TEMPZP,X
	INX
	DBNE	Y,DG3

	BCS	RTS
	DBNE	R1,DG2

	LDA	R2	FR1=digit+R2
	ADC	TEMPZP
	STA	FR1
	LDX	#1
	LDY	#7
DG4	LDA	TEMPZP,X
	ADC	#0
	STA	FR1,X
	INX
	DBNE	Y,DG4

RTS	LDY	R3	restore Y
	RTS
	END

****************************************************************
*
*  SDSPA - Define A Type Symbolic Parameter
*
*  INPUTS:
*	LINE - source line
*
*  OUTPUTS:
*	R0 - length
*	WORK - parameter for table, numbers initialized to 0
*
****************************************************************
*
SDSPA	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDSPA
LEN	EQU	R0
;
;  Set up common parts.
;
	JSR	SDSPX
	LDA	LERR
	BNE	RTS
;
;  Set type and length.
;
	LDA	#'X'
	STA	WORK+DISPSPT	type
	LDA	#4
	STA	WORK+DISPSPL	length
;
;  initialize numbers
;
	LONG	I,M
	LDA	WORK+DISPSPCT
	AND	#$00FF
	TAX
	PHY
	LDY	#0	disp
	TYA
DSPA1	STA	WORK+DISPVAL,Y	set to 0
	STA	WORK+DISPVAL+2,Y
	INY
	INY
	INY
	INY
	DBNE	X,DSPA1
	PLY
	LDA	WORK+DISPSPCT	set length
	AND	#$FF
	ASL	A
	ASL	A
	CLC
	ADC	#DISPVAL
	STA	LEN
	SHORT I,M
RTS	RTS
	END

****************************************************************
*
*  SDSPB - Define B Type Symbolic Parameter
*
*  INPUTS:
*	LINE - source line
*
*  OUTPUTS:
*	R0 - length
*	WORK - parameter for table, variables initialized
*		to false
*
****************************************************************
*
SDSPB	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDSPB
LEN	EQU	R0
;
;  Set up common parts.
;
	JSR	SDSPX
	LDA	LERR
	BNE	RTS
;
;  Set type and length.
;
	LM	WORK+DISPSPT,#'Y'
	LM	WORK+DISPSPL,#1
;
;  Initialize variables.
;
	LDX	WORK+DISPSPCT
	LDA	#0
DSPB1	STA	WORK+DISPVAL-1,X
	DBNE	X,DSPB1
DSPB2	LONG	M	set length
	CLC
	LDA	WORK+DISPSPCT
	AND	#$00FF
	ADC	#DISPVAL
	STA	LEN
	SHORT M
RTS	RTS
	END

****************************************************************
*
*  SDCPC - Define C Type Symbolic Parameter
*
*  INPUTS:
*	LINE - source line
*	Y - position in line
*
*  OUTPUTS:
*	R0 - length
*	WORK - parameter for table, variables initialized to
*		zero length
*
****************************************************************
*
SDSPC	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SDSPC

	JSR	SDSPA
	LDA	#'Z'	set type
	STA	WORK+DISPSPT
	STZ	WORK+DISPSPL	set length
	RTS
	END

****************************************************************
*
*  SDSPX - Common Initialization for Symbolic Parm Routines
*
*  INPUTS:
*	LINE - source line
*	C - clear if Y given
*	Y - position to evaluate
*
*  OUTPUTS:
*	WORK - name and number
*
****************************************************************
*
SDSPX	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SDSPX
;
;  Find operand & name.
;
	BCC	PX1	br if Y given
	JSR	SOPRF	find opnd
	BCS	PX1

	ERROR #6	no opnd

PX1	LDA	LINE,Y	check for &
	CMP	#'&'
	BEQ	PX2

SNTX	ERROR #7	Syntax Error
ERR15	ERROR #15	Unresolved Label not Allowed

PX2	INY		evaluate name
	JSR	SLABL
	BCS	SNTX
	LDX	LNAME	move name
	STX	TLAB
PX3	LDA	LNAME,X
	STA	TLAB,X
	DBNE	X,PX3
	LONG	M	set forward link
	STZ	WORK+4
	STZ	WORK+6
	SHORT M
;
;  Set count.
;
	LM	WORK+DISPSPCT,#1	init count
	LDA	LINE,Y	check for blank
	CMP	#' '
	BEQ	PX6
	CMP	#','	check for comma
	BEQ	END
	CMP	#'('	perhaps a '('
	BNE	END
	INY		get value
	JSR	FEVAL
	LDA	LERR
	BMI	PX6
	LDA	OPFIXED
	BEQ	ERR15
	LDA	LINE,Y	check for ') '
	CMP	#')'
	BNE	SNTX
	INY
	LDA	LINE,Y
	CMP	#','	check for comma
	BEQ	PX4
	CMP	#RETURN
	BEQ	PX4
	CMP	#' '
	BNE	END
PX4	LDA	OPV+1	move length
	ORA	OPV+2
	ORA	OPV+3
	BNE	PX5
	LDA	OPV
	BNE	PX5A
PX5	ERROR #28,R	subscript exceeded
	BRA	END

PX5A	STA	WORK+DISPSPCT

END	LDA	LINE,Y	eat periods
	CMP	#'.'
	BNE	PX6
	INY
PX6	STY	RY
;
;  Check for previous definitions.
;
	LDA	FCASE	check the case
	BNE	LB0

	LDY	TLAB	move the label; case insensitive
	STY	LNAME
PX7	LDA	TLAB,Y
	TAX
	LDA	UPPERCASE,X
	STA	LNAME,Y
	DBNE	Y,PX7

LB0	LDY	TLAB	move the label; case sensitive
	STY	LNAME
PX7A	LDA	TLAB,Y
	STA	LNAME,Y
	DBNE	Y,PX7A

	LDA	MTNL	set MTNL to $FF if doing global
	PHA
	LDA	OP
	CMP	#ILCLA
	BGE	PD0
	LM	MTNL,#$FF
PD0	JSR	SMTR0	set search limits
	PLA
	STA	MTNL
PD1	LONG	M	search table
	LDA	R0
	ORA	R2
	SHORT M
	BEQ	RTS
PD2	JSR	SCPL0
	BEQ	PD3
	JSR	SINMT
	BRA	PD1
PD3	ERROR #3,R	Found - Duplicate Label
RTS	LDY	TLAB	move the label, preserving case
	STY	LNAME
MV1	LDA	TLAB,Y
	STA	LNAME,Y
	DBNE	Y,MV1
	LDY	RY
	RTS

TLAB	DS	256	temp label
RY	DS	1	temp Y reg
	END

****************************************************************
*
*  SEGNM - set the name of the segment and check for dups
*
*  Inputs:
*	LLNAME - label name
*	SEGPTR - pointer to head of segment table list
*	SEGDISP - disp into segment name table
*
*  Outputs:
*	SEGSTR - name of the segment
*
****************************************************************
*
SEGNM	START
	USING COMMON
	LONGA OFF
	LONGI OFF

	LDX	LLNAME	save the segment name
	STX	SEGSTR
SG0	LDA	LLNAME,X
	STA	SEGSTR,X
	DEX
	BNE	SG0
	LDX	SEGSTR	if the last char is a blank then
	LDA	SEGSTR,X
	CMP	#' '
	BNE	SG1
	DEC	SEGSTR	  delete it
SG1	LDA	PASS
	CMP	#2
	BNE	RTS
	JSR	SISGL	see if symbol is in segment list
	BCC	SG2
	ERROR #36	  yes, flag duplicate segment
RTS	RTS
;
;  Insert segment into segment list
;
SG2	LONG	I,M
	CLC		compute # of bytes we need
	LDA	SEGSTR
	AND	#$00FF
	ADC	#5
	LDX	#1
	JSR	SROOM	find room in global symbol table

	LDA	SEGPTR	if no entries
	ORA	SEGPTR+2
	BNE	SG3
	MOVE4 R0,SEGPTR	  set the list pointer
	BRA	SG4

SG3	MOVE4 SEGLAST,R4	else
	LDY	#2	  set the link
	LDA	R0
	STA	[R4]
	LDA	R0+2
	STA	[R4],Y
SG4	MOVE4 R0,SEGLAST	set up new link pointer
	LDY	#2	next = nil
	LDA	#0
	STA	[R0]
	STA	[R0],Y
	ADD4	R0,#4
	SHORT I,M	copy over the name
	LDY	SEGSTR
SG5	LDA	SEGSTR,Y
	STA	[R0],Y
	DBPL	Y,SG5
	RTS
;
; See if segment is already in list
;
SISGL	LONG	I,M
	MOVE4 SEGPTR,R0

SI1	LDA	R0	if at end of list
	ORA	R0+2
	BNE	SI2
	SHORT I,M
	CLC		  return not in list
	RTS
	LONGI OFF
	LONGA OFF

SI2	ADD4	R0,#4,R4	else
	SHORT I,M
	LDA	SEGSTR	  if names match
	CMP	[R4]
	BNE	SI4
	TAY
SI3	LDA	SEGSTR,Y
	CMP	[R4],Y
	BNE	SI4
	DEY
	BNE	SI3
	SEC		    return found
	RTS

SI4	LONG	I,M
	LDY	#2	  else
	LDA	[R0]	    next entry
	TAX
	LDA	[R0],Y
	STA	R0+2
	STX	R0
	BRA	SI1
	LONGI OFF
	LONGA OFF
	END

****************************************************************
*
*  SELAB - Evaluate Label Field
*
*  INPUTS:
*	LINE - source line
*	Y - column to start label
*
*  OUTPUTS:
*	LLNAME - label name if found, blank if not
*	LLBV - location counter at label
*	C - set if good label, else clear
*
****************************************************************
*
SELAB	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SELAB

	STZ	LLNAME	blank out the label
	LM	LLBFLAG,#LBREL	assume the label is rel
	JSR	SCMNT	check for comment
	BCS	RTS	br if comment
	LDA	LINE	check for no label
	CMP	#' '
	BEQ	RTS
	LDY	#0	check label syntax
	JSR	SLABL
	BCS	LB2	br if not ok
	CMP	#' '	check last char for blank
	BEQ	LB3
LB2	ERROR #4,R	label syntax error
RTS	CLC
	RTS

LB3	MOVE4 STR,LLBV	set label value
	LDA	OBJFLAG	if label is in an OBJed area then
	BEQ	LB4
	LDA	OP	  if label is not an equ or gequ then
	CMP	#IEQU
	BEQ	LB4
	CMP	#IGEQU
	BEQ	LB4
	LONG	I,M	    adjust the label value
	SUB4	STR,OBJSTR,LLBV
	ADD4	LLBV,OBJORG
	SHORT I,M
	LDA	LLBFLAG	  mark it as fixed
	EOR	#LBREL
	STA	LLBFLAG
LB4	LDX	LNAME
	STX	LLNAME
LB5	LDA	LNAME,X
	STA	LLNAME,X
	DEX
	BNE	LB5
	SEC
	RTS
	END

****************************************************************
*
*  SENDP - End of segment processing
*
****************************************************************
*
SENDP	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SENDP
;
;  List the symbol table
;
	LDX	SYM	if SYM then
	BEQ	EP1
	MOVE	LOCAL,SNAME,#6	  list the symbol table
	CLC
	JSR	STABL
EP1	JSR	SNPGE	do a page eject
;
;  Reset scalars
;
	LONG	I,M	reset ORG and ALIGN for the next
	STZ	ORGVAL	 routine
	STZ	ORGVAL+2
	STZ	ALIGNVAL
	STZ	ALIGNVAL+2
;
;  Restore local symbol table
;
	MOVE4 LHAND,R0	delete extents to symbol table
	JSR	SDELT
	MOVE4 R0,LHAND	restore table parameters
	LDY	#2
	LDA	[R0]
	STA	LSTART
	LDA	[R0],Y
	STA	LSTART+2
	ADD4	LSTART,#4,LSP
	ADD4	LSTART,#LSIZE,LEND
;
;  Restore AINPUT buffer
;
	MOVE4 AHAND,R0	delete extents to symbol table
	JSR	SDELT
	MOVE4 R0,AHAND	restore table parameters
	LDY	#2
	LDA	[R0]
	STA	ASTART
	LDA	[R0],Y
	STA	ASTART+2
	ADD4	ASTART,#4,ASP
	ADD4	ASTART,#ASIZE,AEND
	STZ	AFIRST
	STZ	AFIRST+2
	STZ	ALAST
	STZ	ALAST+2
	SHORT I,M
	RTS

LOCAL	DC	C'Local '
	END

****************************************************************
*
*  SETSP - Set Symbolic Parameter Pointers
*
*  Inputs:
*	MTNL - macro table nest level
*	SSP,SSTART,SEND,PHAND,SFIRST - values to set
*
*  Outputs:
*	CSP,CSTART,CEND,SPHAND,CFIRST - set
*
*  Notes:
*	1. Can be called with 8 or 16 bit registers.
*	2. Entry at SETSP2 is with X already set.
*
****************************************************************
*
SETSP	START
	USING COMMON

	PHP		save register sizes
	LONG	I,M
	LDA	MTNL	X = disp into tables
	INC	A
	AND	#$FF
	ASL	A
	ASL	A
	TAX
LB1	LDA	SSTART,X	set pointers
	STA	CSTART
	LDA	SSTART+2,X
	STA	CSTART+2
	LDA	SEND,X
	STA	CEND
	LDA	SEND+2,X
	STA	CEND+2
	LDA	SSP,X
	STA	CSP
	LDA	SSP+2,X
	STA	CSP+2
	LDA	PHAND,X
	STA	SPHAND
	LDA	PHAND+2,X
	STA	SPHAND+2
	LDA	SFIRST,X
	STA	CFIRST
	LDA	SFIRST+2,X
	STA	CFIRST+2
	PLP		restore register status
	RTS
	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SFLOT - Floating Point Number Conversion
*
*  INPUTS:
*	LINE - line containing floating point string
*	Y - disp in line
*	PREC - precision of number
*
*  OUTPUTS:
*	FR1 - floating point number
*	Y - disp to first character past number
*
****************************************************************
*
SFLOT	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SFLOT

	LDA	LINE,Y	if first char is ',', ''', '"', error
	CMP	#','
	BEQ	ERR7A
	CMP	#''''
	BEQ	ERR7A
	CMP	#'"'
	BNE	LB0
	INY
ERR7A	ERROR #7

LB0	LDX	#0	move the number into a holding area
LB1	LDA	LINE,Y
	CMP	#','
	BEQ	LB2
	CMP	#''''
	BEQ	LB2
	STA	HOLD,X
	INX
	INY
	BNE	LB1
LB2	LDA	#0	nul terminate the string
	STA	HOLD,X
	PHY		save line pointer
	LONG	I,M
	PH4	#HOLD	convert from ASCII to DECREC
	PH4	#INDEX
	PH4	#DECREC
	PH4	#VALID
	STZ	INDEX
	STZ	INDEX+2
	FCSTR2DEC
	LDA	VALID	error if not a valid prefix
	BEQ	ERR
	LDY	INDEX	  or entire string not processed
	LDA	HOLD,Y
	AND	#$00FF
	BEQ	LB2A
ERR	SHORT I,M
ERR7	ERROR #7,R	operand syntax error
	LONG	I,M
LB2A	PH4	#DECREC	convert decimal record to FP
	PHD
	CLC
	PLA
	ADC	#FR1
	PEA	0
	PHA
	LDA	PREC	convert to proper SANE format
	AND	#$00FF
	CMP	#4
	BNE	LB3
	FDEC2S
	LDA	FNUMSEX
	AND	#$00FF
	BEQ	LB5
	LDA	FR1
	XBA
	TAX
	LDA	FR1+2
	XBA
	STA	FR1
	STX	FR1+2
	BRA	LB5
LB3	CMP	#10
	BEQ	LB4
	FDEC2D
	LDA	PREC
	AND	#$00FF
	CMP	#5
	BEQ	LB3A
	LDA	FNUMSEX
	AND	#$00FF
	BEQ	LB5
	LDA	FR1
	XBA
	TAX
	LDA	FR1+6
	XBA
	STA	FR1
	STX	FR1+6
	LDA	FR1+2
	XBA
	TAX
	LDA	FR1+4
	XBA
	STA	FR1+2
	STX	FR1+4
	BRA	LB5
LB3A	JSR	SBASC
	BRA	LB5
LB4	FDEC2X
	LDA	FNUMSEX
	AND	#$00FF
	BEQ	LB5
	LDA	FR1
	XBA
	TAX
	LDA	FR1+8
	XBA
	STA	FR1
	STX	FR1+8
	LDA	FR1+2
	XBA
	TAX
	LDA	FR1+6
	XBA
	STA	FR1+2
	STX	FR1+6
	LDA	FR1+4
	XBA
	STA	FR1+4
	BRA	LB5
LB5	SHORT I,M
	PLY		reset Y
	RTS

HOLD	DS	256	holding area for string
INDEX	DS	4	index into string
DECREC	DS	33	decimal record for conversion
VALID	DS	4	valid prefix flag
	END

****************************************************************
*
*  SGOTO - Conditional Assembly GOTO
*
*  INPUTS:
*	LINE - source line
*	Y - disp in source line of destination label
*
*  OUTPUTS:
*	LINE - source line after goto
*
****************************************************************
*
SGOTO	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SGOTO
;
;  Initialization.
;
	MOVE4 AP,LTP	save the text pointer
	LDA	LINE,Y	make sure that the destination label
	CMP	#'.'	 starts with . or ^
	BEQ	IN1
	CMP	#'^'
	BEQ	IN1
	ERROR #7	Operand Syntax

IN1	PHA		save the branch direction characters
	INY		read the destination label
	JSR	SLABL
	PHY
	LDA	FCASE	check case sensitivity
	BNE	IN1B

	LDX	LNAME	case insensitive save
	STX	TLB
IN1A	LDA	LNAME,X
	TAY
	LDA	UPPERCASE,Y
	STA	TLB,X
	DBNE	X,IN1A
	BRA	IN1D

IN1B	LDX	LNAME	case sensitive save
	STX	TLB
IN1C	LDA	LNAME,X
	STA	TLB,X
	DBNE	X,IN1C

IN1D	LDY	TLB	remove last char if it is a blank
	LDA	TLB,Y
	CMP	#' '
	BNE	IN2
	DEC	TLB
IN2	PLY
	PLA		recover the branch direction character
	CMP	#'^'	skip searching down if it is ^
	BEQ	UP1
;
;  Search down.
;
DW1	LDY	#0	find the end of line mark
	LDA	#RETURN
DW2	CMP	[AP],Y
	BEQ	DW2A
	INY
	BNE	DW2
DW2A	SEC		AP = AP + line length
	TYA
	ADC	AP
	STA	AP
	BCC	DW2B
	INC	AP+1
	BNE	DW2B
	INC	AP+2
DW2B	LDA	AP+2	quit if at end of file
	CMP	SRCEND+2
	BNE	DW2C
	LDA	AP+1
	CMP	SRCEND+1
	BNE	DW2C
	LDA	AP
	CMP	SRCEND
DW2C	BGE	DW3
	JSR	SCHEK	see if it's the destination
	LDA	ERR
	BNE	ERR20
	JSR	SMEND	loop if it's not an MEND
	BCC	DW1
DW3	MOVE4 LTP,AP	reset TP
;
;  Search up.
;
UP1	LONG	M	error if at start of file
	LDA	AP
	CMP	SRCBUFF
	BNE	UP1A
	LDA	AP+1
	CMP	SRCBUFF+1
	BNE	UP1A
	SHORT M
ERR20	MOVE4 LTP,AP	restore the text pointer
	JSR	SRLIN	re-read the line
	ERROR #20	Sequence Symbol not Found

UP1A	LDA	AP	skip back to EOL mark on last line
	BNE	UP1B
	DEC	AP+2
UP1B	DEC	AP
UP2	LONG	M
	LDA	AP	see if we are at the start of the file
	CMP	SRCBUFF
	BNE	UP3
	LDA	AP+1
	CMP	SRCBUFF+1
UP3	SHORT M
	BEQ	UP8
	LONG	M
	LDA	AP
	BNE	UP4
	DEC	AP+2
UP4	DEC	AP
	SHORT M
	LDA	[AP]	see if we are at the end of the last
	CMP	#RETURN	 line
	BNE	UP2
	LONG	M
	INC	AP	inc past EOL mark
	BNE	UP5
	INC	AP+2
UP5	SHORT M
UP8	JSR	SCHEK	see if this is the destination
	LDA	ERR
	BNE	ERR20
	JSR	SMACR	quit if it is a MACRO directive
	BCS	ERR20
	BRL	UP1	next line

LTP	DS	4	storage for TP
	END

****************************************************************
*
*  SHXID - Hex Identification
*
*  INPUTS:
*	A - input character
*
*  OUTPUTS:
*	C - set if hex, else clear
*
****************************************************************
*
SHXID	START
	DEBUG SHXID
	LONGA OFF
	LONGI OFF

	JSR	SNMID	check for #
	BCS	RTS
	CMP	#'A'	check for letter
	BCC	RTS
	CMP	#'G'
	BCC	HEX
	CLC		not hex
RTS	RTS
HEX	SEC		hex
	RTS
	END

****************************************************************
*
*  SHXVL - Changes a Hex Print Char to a Hex Number
*
*  INPUTS:
*	A - print character
*
*  OUTPUTS:
*	A - hex number
*
****************************************************************
*
SHXVL	START
	LONGA OFF
	LONGI OFF
	DEBUG SHXVL

	CMP	#'A'	br if #
	BCC	RTS
	SEC		change letter
	SBC	#7
RTS	AND	#$F	mask out non hex
	RTS
	END

****************************************************************
*
*  SINSP - Insert Symbolic Parameter in Table
*
*  INPUTS:
*	OP - operand
*	WORK - operand to insert
*	R0 - number of bytes to insert
*
*  NOTES: updates table pointers
*
****************************************************************
*
SINSP	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SINSP
;
;  Find insert point.
;
	LM	TMTNL,MTNL	save macro table nest level
	LONG	M	save the length
	LDA	R0
	STA	LEN
	SHORT M
	LDA	OP	branch if local
	CMP	#ILCLA
	BCS	SP1	set addrs of sym parm pointers
	LM	MTNL,#$FF
SP1	LONG	I,M
	JSR	SETSP
	LDA	LEN	find a spot in the table
	LDX	#3
	JSR	SROOM
	JSR	SAVSP
;
;  chain to the new symbol
;
	MOVE4 CFIRST,R4	set R4 to head of list
	LDA	R6	branch if list is empty
	ORA	R4
	BEQ	LL4
LL1	LDY	#4	trace the list
	LDA	[R4],Y
	TAX
	INY
	INY
	LDA	[R4],Y
	BNE	LL2
	CPX	#0
	BEQ	LL3
LL2	STA	R6
	STX	R4
	BRA	LL1
LL3	LDY	#4	set the forward link
	LDA	R0
	STA	[R4],Y
	INY
	INY
	LDA	R2
	STA	[R4],Y
	BRA	LN1
LL4	MOVE4 R0,CFIRST	point head of list to new symbol
;
;  Save the label name
;
LN1	MOVE4 R0,R4	save pointer to sym parm insert point
	LDA	LNAME	find a spot
	AND	#$00FF
	INC	A
	LDX	#3
	JSR	SROOM
	JSR	SAVSP
	LDA	LNAME	move the name to its spot
	AND	#$00FE
	TAY
LN2	LDA	LNAME,Y
	STA	[R0],Y
	DEY
	DBPL	Y,LN2
	MOVE4 R0,WORK	set pointer to name
;
;  Move in symbolic parameter.
;
	LDY	LEN
	DEY
	SHORT M
MS1	LDA	WORK,Y
	STA	[R4],Y
	DBPL	Y,MS1
	SHORT I
	AGO	.SINSPA
;
;  Print the symbolic parameter table
;
SPRSM	PRINT2 'Symbolic parameter table:'
	JSR	SCESC
	JSR	SCESC

	MOVE4 CFIRST,R0	set ptr to head of list
PT1	LDY	#2	print pointer to name
PT2	LDA	[R0],Y
	PRHEX
	DBPL	Y,PT2
	LDA	#' '	print pointer to next symbol
	COUT	A
	LDX	#3
	LDY	#6
PT3	LDA	[R0],Y
	PRHEX
	DEY
	DBNE	X,PT3
	LDA	#' '	print type
	COUT	A
	LDY	#DISPSPT
	LDA	[R0],Y
	COUT	A
	LDA	#' '	print count
	COUT	A
	LDY	#DISPSPCT
	LDA	[R0],Y
	PRHEX
	LDA	#' '	print length
	COUT	A
	LDY	#DISPSPL
	LDA	[R0],Y
	PRHEX
	LDA	#' '	print name
	COUT	A
	LONG	M
	LDA	[R0]
	STA	R4
	LDY	#2
	LDA	[R0],Y
	STA	R6
	SHORT M
	LDA	[R4]
	TAX
	LDY	#1
PT4	LDA	[R4],Y
	COUT	A
	INY
	DBNE	X,PT4
	JSR	SCESC	print eol
	JSR	SINMT	next symbol
	LONG	M
	LDA	R2
	ORA	R0
	SHORT M
	JNE	PT1
.SINSPA
	LM	MTNL,TMTNL	reset MTNL
	BRL	SETSP

LEN	DS	2	length of parm
TMTNL	DS	1	temp macro table nest level
	END

****************************************************************
*
*  SMACR - Check for a MACRO
*
*  INPUTS:
*	LN - points to the line to check
*
*  OUTPUTS:
*	C - set if the line is a MACRO
*
****************************************************************
*
SMACR	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SMACR

	LDY	#0
	LDA	#' '	skip to the first blank
MN1	CMP	[AP],Y
	BEQ	MN2
	INY
	BNE	MN1

MN2	INY		skip to the next character
	CMP	[AP],Y
	BEQ	MN2
	LDX	#0	check for a match
MN3	LDA	[AP],Y
	AND	#%01011111
	CMP	MACRO,X
	BNE	MN4
	CMP	#' '
	BEQ	MN4
	INY
	INX
	CPX	#8
	BLT	MN3
	RTS		macro found

MN4	CMP	#' '	if line has space or return
	BEQ	MN5
	CMP	#RETURN
	BNE	NO
MN5	LDA	MACRO,X	  and macro has space
	CMP	#' '
	BNE	NO
	RTS		    then its MACRO

NO	CLC		macro not found
	RTS
	END

****************************************************************
*
*  SMDRP - Drop the Current Macro Library
*
*  INPUTS:
*	MSTART - start of macro name table
*	MSP - end of macro table
*
****************************************************************
*
SMDRP	START
	USING COMMON
	DEBUG SMDRP

	LONG	M,I
	jsr	MacroPurge	if there is a macro file in the FastFile
!			 system, purge it
	LDA	MSP+2	check for no table
	CMP	MSTART+2
	BNE	RT0A
	LDA	MSP
	CMP	MSTART
RT0A	BEQ	RTS
	MOVE4 MHASH,MSP	zero hash table
	LDY	#HTABLESIZE-2
	LDA	#0
RT1	STA	[MSP],Y
	DEY
	DBPL	Y,RT1
	MOVE4 THAND,R0	delete extents to symbol table
	JSR	SDELT
	MOVE4 R0,THAND	restore table parameters
	LDY	#2
	LDA	[R0]
	STA	MSTART
	LDA	[R0],Y
	STA	MSTART+2
	ADD4	MSTART,#4,MSP
	ADD4	MSTART,#MSIZE,MEND
RTS	SHORT M,I
	RTS
	END

****************************************************************
*
*  SMEND - Check for a MEND
*
*  INPUTS:
*	LN - points to the line to check
*
*  OUTPUTS:
*	C - set if the line is a MEND
*
****************************************************************
*
SMEND	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SMEND

	LDY	#0
MN1	LDA	[AP],Y	skip to the first blank
	CMP	#RETURN
	BEQ	NO
	CMP	#' '
	BEQ	MN2
	INY
	BNE	MN1

MN2	INY		skip to the next character
	LDA	[AP],Y
	CMP	#RETURN
	BEQ	NO
	CMP	#' '
	BEQ	MN2
	LDX	#0	check for a match
MN3	LDA	[AP],Y
	AND	#%01011111
	CMP	MENDCH,X
	BNE	MN4
	CMP	#' '
	BEQ	MN4
	INY
	INX
	CPX	#8
	BLT	MN3
	RTS		macro found

MN4	CMP	#' '	if line has space or return
	BEQ	MN5
	CMP	#RETURN
	BNE	NO
MN5	LDA	MENDCH,X	  and macro has space
	CMP	#' '
	BNE	NO
	RTS		    then its MACRO

NO	CLC		macro not found
	RTS
	END

****************************************************************
*
*  SMNOT - MNOTE Resolution
*
****************************************************************
*
SMNOT	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SMNOT

	LDA	PASS	skip if not pass 2
	CMP	#2
	BNE	RTS

	JSR	SOPRF	find operand
	BCS	MNT2
	ERROR #6	missing operand

ERR7	ERROR #7	macro operand syntax error

MNT2	JSR	SWORD2	print message
	BCC	ERR7
	STY	TY
	LDX	WORD
	BEQ	MNT5
	STX	MNT4
	JSR	SRITE
	DC	H'C0'
MNT4	DS	1
	DC	A'WORD+1'

MNT5	LDY	TY	set LERR if coded
	LDA	LINE,Y
	CMP	#','
	BNE	RTS

	INC2	NERR	inc # errors
	INY		set LERR
	JSR	FEVAL
	LDA	OPV
	CMP	MERRF
	BCC	RTS
	STA	MERRF
RTS	RTS
	END

****************************************************************
*
*  SNMEV - Evaluate Decimal Number
*
*  INPUTS:
*	Y - position of number in line
*	LINE - source line
*
*  OUTPUTS:
*	Y - next character
*	M1L - value of number
*
****************************************************************
*
SNMEV	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SNMEV

	STZ	M1L
	STZ	M1L+1
	STZ	M1L+2
	STZ	M1L+3
NM1	LDA	LINE,Y
	JSR	SNMID
	BCC	RTS
	STY	R0
	STZ	M3L+1
	STZ	M3L+2
	STZ	M3L+3
	LM	M3L,#10
	JSR	SMUL4
	BVS	ERR11
	LDY	R0
	CLC
	LDA	LINE,Y
	INY
	AND	#$0F
	ADC	M1L
	STA	M1L
	BCC	NM1
	INC	M1L+1
	BNE	NM1
	INC	M1L+2
	BNE	NM1
	INC	M1L+3
	BNE	NM1

ERR11	ERROR #11	Numeric Error in Operand

RTS	RTS
	END

****************************************************************
*
*  SNMID - Check a for Numeric Character
*
*  INPUTS:
*	A - character to be checked
*
*  OUTPUTS:
*	C - set if numeric, else clear
*
****************************************************************
*
SNMID	START
	LONGA OFF
	LONGI OFF
	DEBUG SNMID

	CMP	#'0'
	BLT	RTS
	CMP	#'9'+1
	BLT	SEC
	CLC
RTS	RTS

SEC	SEC
	RTS
	END

****************************************************************
*
*  SOPND - Evaluate Instruction Operand
*
*  INPUTS:
*	LINE - source line
*
*  OUTPUTS:
*	LENGTH - length of instruction
*	OPV - operand value
*	OPR - operand number
*
****************************************************************
*
SOPND	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SOPND
;..............................................................;
;
;  Initialization.
;
;..............................................................;
;
	STZ	OPV	init operand value
	STZ	OPV+1
	STZ	OPV+2
	STZ	OPV+3
	STZ	AMODE
	STZ	GLOBUSE	init global use flag for rel br
	LM	(LENGTH,OPR),#3	set default opr and length
	JSR	SOPRF	find operand
	BCS	MV1
	LDA	OP	MVN and MVP can do without
	CMP	#IMVN
	BEQ	IN1
	CMP	#IMVP
	BNE	IN2
IN1	STZ	CODE+1
	STZ	CODE+2
	SEC
	LDA	OP
	SBC	#IMVN
	TAX
	LDA	MVOP,X
	JSR	SKCNS
	LDX	#0
	LDY	#MVOPNDE-MVOPND
IN1A	LDA	MVOPND,X
	JSR	SKCNS
	INX
	DBNE	Y,IN1A
	RTS

MVOP	DC	H'54 44'	MVN and MVP op codes
MVOPND	DC	2H'EB 01 80 81 10 00 00 00 07 00' KEEP operand for bank byte
MVOPNDE	ANOP

IN2	ERROR #6	operand not found
;..............................................................;
;
;  Evaluate operand.
;
;..............................................................;
;
;  Special: block move.
;
MV1	LDA	OP	skip if this is not a block move
	CMP	#IMVN	 instruction
	BEQ	MV2
	CMP	#IMVP
	BNE	LB1
MV2	SEC		save the op code
	LDA	OP
	SBC	#IMVN
	TAX
	LDA	MVOP,X
	JSR	SKCNS
	JSR	FEVAL	evaluate the first operand
	LDA	LINE,Y	skip to the next operand
	CMP	#','
	BNE	ERR7C
	INY
	JSR	FEVAL	evaluate it
	JSR	MV3	save the expression to disk
	LDA	OPV	save the value for the code buffer
	PHA
	JSR	SOPRF	reevaluate the first operand
	JSR	FEVAL
	JSR	MV3	save the expression to disk
	LM	CODE+2,OPV	set the code buffer values for the
	PLA		 listing
	STA	CODE+1
	RTS

MV3	LM	BSHIFT,#-16	keep an expression
	LDA	#1
	LDX	#$EB
	JMP	SKEXP

ERR7C	ERROR #7	invalid format
;
;  1: accumulator
;
LB1	JSR	GETC
	CMP	#'A'
	BNE	LB3
	LDA	LINE+1,Y
	CMP	#' '
	BEQ	LB2
	CMP	#RETURN
	BNE	LB2A
LB2	LM	OPR,#1
	STA	LENGTH
	RTS

LB2A	JSR	GETC
;
;  2: immediate.
;
LB3	CMP	#'#'
	BEQ	SH1
	CMP	#'/'
	JNE	LB7
	LM	IMCH,#'>'
	BRA	LB3B
SH1	LM	IMCH,#'<'
	LDA	LINE+1,Y
	CMP	#'<'
	BEQ	LB3A
	CMP	#'>'
	BEQ	LB3A
	CMP	#'^'
	BNE	LB3B
LB3A	STA	IMCH
	INY

LB3B	INY
	JSR	EVAL
	LM	(OPR,LENGTH),#2
	LM	FORCED,#1

LB4	LDA	F65816
	BEQ	LB5C
	LDA	ACUMF
	BEQ	LB5
	LDA	FLONGA
	BEQ	LB5C
	BNE	LB5A
LB5	LDA	INDXF
	BEQ	LB5C
	LDA	FLONGI
	BEQ	LB5C
LB5A	INC	LENGTH
LB5C	LDX	IMCH
	CPX	#'<'
	BEQ	LB6
	CPX	#'>'
	BNE	LB5B
	LM	CODE+1,CODE+2
	LM	CODE+2,CODE+3
	LM	BSHIFT,#-8
	BRL	LB6
LB5B	LM	CODE+1,CODE+3
	STZ	CODE+2
	LM	BSHIFT,#-16

LB6	LDA	LINE,Y
	JSR	BLANK
	CMP	#' '
	BNE	ERR7B
	RTS

IMCH	DS	1
ERR7B	ERROR #7	invalid format
;
;  3: abs
;  8: zp
;  16: long
;
LB7	CMP	#'('
	BEQ	LB7A
	CMP	#'['
	BNE	LB7B
LB7A	BRL	LB12

LB7B	JSR	EVAL
	JSR	GETC
	CMP	#' '
	BNE	LB10
	LM	(LENGTH,OPR),#3
	BIT	AMODE
	BPL	LB8
	INC	LENGTH
	LM	OPR,#16
	RTS
LB8	BVS	LB9
	LDA	AMODE
	LSR	A
	BCC	LB9
	DEC	LENGTH
	LM	OPR,#8
LB9	RTS
;
;  4: abs,X
;  9: zp,X
;  17: long,X
;
LB10	CMP	#','
	BNE	ERR7
	LDA	LINE+2,Y
	JSR	BLANK
	CMP	#' '
	BNE	ERR7
	LDA	LINE+1,Y
	JSR	SHIFT
	CMP	#'X'
	BNE	LB11

	LM	LENGTH,#3
	LM	OPR,#4
	BIT	AMODE
	BPL	LB10A
	INC	LENGTH
	LM	OPR,#17
	RTS

LB10A	BVS	LB10B
	LDA	AMODE
	LSR	A
	BCC	LB10B
	DEC	LENGTH
	LM	OPR,#9
LB10B	RTS

ERR7	ERROR #7	invalid format
;
;  5: abs,Y
;  10: zp,Y
;
LB11	CMP	#'Y'
	BNE	LB11B

	LM	LENGTH,#3
	LM	OPR,#5
	BIT	AMODE
	BMI	ERR8A
	BVS	LB11A
	LDA	AMODE
	LSR	A
	BCC	LB11A
	DEC	LENGTH
	LM	OPR,#10
LB11A	RTS
;
;  15: zp,S
;
LB11B	CMP	#'S'
	BNE	ERR7

	LM	OPR,#15
	LM	LENGTH,#2
	BIT	AMODE
	BMI	ERR8A
	BVS	ERR8A
	LDA	AMODE
	LSR	A
	BCC	ERR8A
LB11D	RTS

ERR8A	ERROR #8	length error
;
;  6: (abs)
;  11: (zp)
;  18: .l (zp)
;  20: .l (abs)
;
LB12	STA	INDTYPE
	INY
	JSR	EVAL
	LDA	LINE+1,Y
	JSR	BLANK
	CMP	#' '
	BNE	LB15
	LDA	LINE,Y
	JSR	RIGHT
	BCC	ERR7
	LDA	AMODE
	BMI	ERR8A
	LSR	A
	BCS	LB13

	LDA	INDTYPE
	CMP	#'['
	BNE	LB12A
LB12C	LDA	#20
	BNE	LB12B
LB12A	LDA	#6
LB12B	STA	OPR
	LM	LENGTH,#3
	RTS
LB13	LM	LENGTH,#2
	LDA	INDTYPE
	CMP	#'['
	BEQ	LB14
	LM	OPR,#11
	RTS
LB14	LM	OPR,#18
	RTS
;
;  7: (abs,X)
;  12: (zp,X)
;
LB15	LDA	LINE,Y
	CMP	#','
	JNE	LB18
	LDA	INDTYPE
	CMP	#'['
	BEQ	ERR7A
	LDA	LINE+1,Y
	JSR	SHIFT
	CMP	#'X'
	BNE	LB17
	LDA	LINE+2,Y
	JSR	RIGHT
	BCC	ERR7A
	LDA	LINE+3,Y
	JSR	BLANK
	CMP	#' '
	BNE	ERR7A

	LM	OPR,#7
	LM	LENGTH,#3
	BIT	AMODE
	BVS	LB16
	BMI	ERR8
	LDA	AMODE
	LSR	A
	BCC	LB16
	DEC	LENGTH
	LM	OPR,#12
LB16	RTS

ERR7A	ERROR #7	invalid format
ERR8B	ERROR #8	length error
;
;  14: (zp,S),Y
;
LB17	CMP	#'S'
	BNE	ERR7A
	LDA	LINE+2,Y
	JSR	RIGHT
	BCC	ERR7A
	LDA	LINE+3,Y
	CMP	#','
	BNE	ERR7A
	LDA	LINE+4,Y
	JSR	SHIFT
	CMP	#'Y'
	BNE	ERR7A
	LDA	LINE+5,Y
	BMI	ERR7A
	BIT	AMODE
	BVS	ERR8
	BMI	ERR8

	LM	OPR,#14
	LM	LENGTH,#2
	LDA	AMODE
	LSR	A
	BCC	LB17A
LB17A	RTS

ERR8	ERROR #8	length error
;
;  13: (zp),y
;  19: .l (zp),y
;
LB18	LDA	LINE,Y
	JSR	RIGHT
	BCC	ERR7A
	LDA	LINE+1,Y
	CMP	#','
	BNE	ERR7A
	LDA	LINE+2,Y
	JSR	SHIFT
	CMP	#'Y'
	BNE	ERR7A
	LDA	LINE+3,Y
	JSR	BLANK
	CMP	#' '
	BNE	ERR7A

	LM	LENGTH,#2
	BIT	AMODE
	BVS	ERR8
	BMI	ERR8
	LDA	INDTYPE
	CMP	#'['
	BEQ	LB19
	LDA	#13
	BNE	LB20
LB19	LDA	#19
LB20	STA	OPR
	LDA	AMODE
	LSR	A
	BCC	ERR8
LB20A	RTS
;
;  EVAL - local use evaluation routine
;
EVAL	DEBUG EVAL	set the forced addressing mode flag
	STZ	FORCED
	LDA	LINE,Y
	CMP	#'<'
	BNE	EV1
	LDA	#1
	BNE	EV4
EV1	CMP	#'|'
	BEQ	EV2
	CMP	#'!'
	BNE	EV3
EV2	LDA	#$40
	BNE	EV4
EV3	CMP	#'>'
	BNE	EV5
	LDA	#$80
EV4	STA	AMODE
	INY
	INC	FORCED
EV5	JSR	FEVAL
	PHY
	MOVE4 OPV,CODE+1
	PLY
	LDA	FORCED
	BNE	EV7
	LDA	OPFIXED
	BEQ	EV7
	LDA	OPV+2
	BEQ	EV6
	CMP	#$FF
	BNE	EV5A
	CMP	OPV+3
	BEQ	EV7
EV5A	LM	AMODE,#$80
EV6	ORA	OPV+1
	BNE	EV7
	LM	AMODE,#1
EV7	RTS
;
;  GETC - get a capitolized character.
;
GETC	DEBUG GETC
	LDA	LINE,Y
	PHP
	JSR	SHIFT
	CMP	#RETURN
	BNE	GC1
	LDA	#' '
GC1	PLP
	RTS
;
;  RIGHT - check for a matching ) or ].
;
RIGHT	DEBUG RIGHT
	PHA
	LDA	INDTYPE
	CMP	#'('
	BEQ	RT2
	PLA
	CMP	#']'
	BEQ	RT3
RT1	CLC
	RTS

RT2	PLA
	CMP	#')'
	BNE	RT1
RT3	SEC
	RTS
;
;  BLANK - convert RETURNs to blanks.
;
BLANK	DEBUG BLANK
	CMP	#RETURN
	BNE	BL1
	LDA	#' '
BL1	RTS

INDTYPE	DS	1	indirect type character
	END

****************************************************************
*
*  SQUOT - Identify Quote Marks
*
*  INPUTS:
*	A - character to check
*
*  OUTPUTS:
*	C - set if a was a quote mark
*
****************************************************************
*
SQUOT	START
	LONGA OFF
	LONGI OFF
	DEBUG SQUOT

	CMP	#''''
	BEQ	RTS
	CMP	#'"'
	BEQ	RTS
	CLC
RTS	RTS
	END

****************************************************************
*
*  STRNG - Insert String in Symbolic Parameter
*
*  INPUTS:
*	R4 - addr of pointer to string
*	WORK - string to insert
*
****************************************************************
*
STRNG	START
	USING COMMON
	DEBUG STRNG

	LM	TMTNL,MTNL	set macro table nest level to the
	LM	MTNL,SMTNL	 level where the symbolic parm is
!			 defined
	LONG	I,M	set addresses of current table
	JSR	SETSP
	LDA	WORK	find a spot for the new string
	AND	#$00FF
	INC	A
	LDX	#3
	JSR	SROOM
	JSR	SAVSP
	LDA	R0	set up the pointer to the string
	STA	[R4]
	LDY	#2
	LDA	R2
	STA	[R4],Y
	SHORT I,M
	LDY	WORK	move the string into the table
	TYA
	STA	[R0]
LB1	LDA	WORK,Y
	STA	[R0],Y
	DBNE	Y,LB1
	LM	MTNL,TMTNL	reset MTNL
	RTS

TMTNL	DS	1	temp macro table nest level
	END

****************************************************************
*
*  SWORD - Read a Word
*
*  Reads a word, stopping at a blank or comma.	Blanks or
*  commas are allowed if enclosed in ' characters.  Strings
*  starting ' characters must be enclosed in them, and
*  enclosed ' characters must be doubled.
*
*  INPUTS:
*	Y - first char of word
*	LINE - line
*
*  OUTPUTS:
*	WORD+1 - word
*	WORD - length of word
*	C - set if found and ok, else clear
*	Y - 1st char past word
*
*  NOTES:
*	1)  Entry at SWORD2 does not capitolize the string.
*
****************************************************************
*
SWORD	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SWORD

	LDA	#1
	BNE	W0
SWORD2	ENTRY
	LDA	#0
W0	STA	CAPFLAG

	LDX	#0	set length
	STX	WORD
	STX	QUOTE
	LDA	LINE,Y	check for tic
	JSR	SQUOT
	BCS	W4

WD1	CMP	#RETURN	check for end of line
	BEQ	W2
	LDA	QUOTE	split on type
	BNE	WD2
	LDA	LINE,Y	handle stuff outside of quotes
	CMP	#' '
	BEQ	W2
	CMP	#RETURN
	BEQ	W2
	CMP	#','
	BEQ	W2
	CMP	#TAB
	BEQ	W2
	INX
	JSR	SHIFT2
	STA	WORD,X
	INY
	JSR	SQUOT
	BCC	WD1
	STA	QUOTE
	BCS	WD1
WD2	LDA	LINE,Y	handle stuff inside quotes
	CMP	#RETURN
	BEQ	W3
WD4	CMP	QUOTE
	BNE	WD6
	CMP	LINE+1,Y
	BNE	WD5
	INY
	BNE	WD6
WD5	STZ	QUOTE
	LDA	LINE,Y
WD6	INX
	JSR	SHIFT2
	STA	WORD,X
	INY
	BNE	WD1

W2	CPX	#0	check for no word
	BEQ	W3
W2A	STX	WORD	save length
	SEC		word found
	RTS

W3	CLC		word not found or error
	RTS
;
;  Word is in tic marks.
;
W4	STA	QUOTE
	INY

W5	CMP	#RETURN	check for end of line
	BEQ	W3
	LDA	LINE,Y	get char
	JSR	SHIFT2

	CMP	QUOTE	check for tic
	BNE	W6
	INY		next one tic?
	LDA	LINE,Y
	JSR	SHIFT2
	CMP	QUOTE
	BNE	W2A	finished if not tic

W6	INX		save char
	STA	WORD,X
	INY		loop next char
	BNE	W5
	RTS

SHIFT2	ASL	CAPFLAG
	ROR	CAPFLAG
	BEQ	SH1
	JSR	SHIFT
SH1	RTS

CAPFLAG	DS	1	capitolization flag
	END

****************************************************************
*
*  SYMPM - Set up all predefined symbolic parameters except SYSCNT
*
*  Inputs:
*	SEGSTR - name of the current load segment
*	DATESTR - current date string
*	TIMESTR - current time string
*
****************************************************************
*
SYMPM	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF

	LDA	OP	set op code to place the symbol in
	PHA		 the global sym parm table
	LDA	#IGBLC
	STA	OP
	LONG	I,M	insert the SYSNAME parm
	MOVE	SYSNAME,WORK,#L:SYSNAME
	LA	R0,L:SYSNAME
	MOVE	LSYSNAME,LNAME,#L:LSYSNAME
	SHORT I,M
	JSR	SINSP
	LONG	I,M	insert the SYSTIME parm
	MOVE	SYSTIME,WORK,#L:SYSTIME
	LA	R0,L:SYSTIME
	MOVE	LSYSTIME,LNAME,#L:LSYSTIME
	SHORT I,M
	JSR	SINSP
	LONG	I,M	insert the SYSDATE parm
	MOVE	SYSDATE,WORK,#L:SYSDATE
	LA	R0,L:SYSDATE
	MOVE	LSYSDATE,LNAME,#L:LSYSDATE
	SHORT I,M
	JSR	SINSP
	PLA		restore incomming OP code
	STA	OP
	RTS

SYSNAME	DC	2I4'0',C'Z',I1'1,0',A4'SEGSTR'
LSYSNAME DC	I1'7',C'SYSNAME'
SYSDATE	DC	2I4'0',C'Z',I1'1,0',A4'DATESTR'
LSYSDATE DC	I1'7',C'SYSDATE'
SYSTIME	DC	2I4'0',C'Z',I1'1,0',A4'TIMESTR'
LSYSTIME DC	I1'7',C'SYSTIME'
	END

	APPEND FEVAL.ASM
