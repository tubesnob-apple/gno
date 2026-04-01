****************************************************************
*
*  FORML -  Resolve Symbolic Parameters in a Line
*
*  INPUTS:
*	LINE - input line
*
*  OUTPUTS:
*	LINE - line ready for the standard assembler
*
****************************************************************
*
FORML	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG FORML
;
;  Initialization.
;
	STZ	ERR	initialize the variables
	STZ	LERR
	JSR	SOPFN	evaluate the operation code
	BCS	IN6
	LM	OPF,#$6D
	LM	OP,#200
	BNE	IN7
IN6	JSR	SOPCD
IN7	LDA	SYMBOLICS	continue to the expansion phase only
	BNE	MV1	 if the line contains some symbolic
	RTS		 parameters

!			If entered at FORML2, the op code flags
!			 are set to 0
FORML2	ENTRY
	STZ	ERR	initialize the variables
	STZ	LERR
	STZ	OPF
	LDA	SYMBOLICS	continue to the expansion phase only
	BNE	MV1	 if the line contains some symbolic
	RTS		 parameters
;
;  Scan the line to locate a symbolic parameter.
;
MV1	LDX	#0	initialize variables
	LDY	#0
	STZ	FIELD
MV2	LDA	LINE,Y	check the next character
	CMP	#' '
	BNE	MV3
MV2A	STA	WORK,X
	INY
	INX
	BEQ	LP3
	LDA	LINE,Y
	CMP	#' '
	BEQ	MV2A
	INC	FIELD
MV3	CMP	#'&'
	BNE	LP1
	LDA	LINE+1,Y	skip if not followed by an alphabetic
	JSR	SALID	 character
	BCC	SP3
;
;  Resolve the symbolic parameter.
;
	LDA	FIELD	Check the field to insure that the
	BNE	SP1	 symbolic parameter should be expanded
	LDA	OPF	-> label field
	AND	#EXLB
	BNE	SP2
	BRA	SP3

SP1	CMP	#2	-> operand field
	BNE	SP2
	LDA	OPF
	AND	#OPRF
	BEQ	SP3
SP2	LDA	LINE-1,Y	skip expansion if this is an attribute
	CMP	#':'
	BEQ	SP3
	JSR	SYMBL	expand the symbolic parameter
	LDA	ERR
	BEQ	LP2	avoid looping on bad parms
	LDA	LINE,Y
	CMP	#'&'
	BNE	LP2
SP3	LDA	LINE,Y	restore the character
;
;  Save a character.
;
LP1	STA	WORK,X	save the character
	INY		next character
	INX
	BEQ	LP3
LP2	CMP	#RETURN
	BNE	MV2
;
;  Crunch the blanks.
;
LP3	LDA	#RETURN
	STA	WORK,X
	BRL	SETCL

FIELD	DS	1	field being expanded
	END

****************************************************************
*
*  SALID - Check for an Alphabetic Character
*  SANID - Check for an Alpha-numeric Character
*
*  INPUTS:
*	A - character to check
*
*  OUTPUTS:
*	C - set if alphabetic (alphanumeric), else clear
*
*  NOTES:
*	_ and ~ are considered alphabetic
*
****************************************************************
*
SALID	START
	LONGA OFF
	LONGI OFF
	DEBUG SALID

al1	phx
	tax
	lda	table,X
	lsr	A
	txa
	plx
	rts

SANID	ENTRY
	JSR	SNMID	check for numeric
	BCC	AL1	br if not numeric
	RTS

table	dc	i1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'	nul..si
	dc	i1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'	dle..us
	dc	i1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'	' '../
	dc	i1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'	0..?
	dc	i1'0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'	@..O
	dc	i1'1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,1'	P.._
	dc	i1'0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'	`..o
	dc	i1'1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,0'	p..rub
	dc	i1'1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'	$80..$8F
	dc	i1'1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'	$90..$9F
	dc	i1'0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,1'	$A0..$AF
	dc	i1'0,0,0,0,1,1,1,1,1,1,0,1,1,1,1,1'	$B0..$BF
	dc	i1'0,0,0,0,1,0,1,0,0,0,0,1,1,1,1,1'	$C0..$CF
	dc	i1'0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,1'	$D0..$DF
	dc	i1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'	$E0..$EF
	dc	i1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'	$F0..$FF
	END

****************************************************************
*
*  SETCL - Set Line to Standard Columns
*
*  INPUTS:
*	WORK - line to set
*
*  OUTPUTS:
*	LINE - line placed at the standard tab stops
*
****************************************************************
*
SETCL	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SETCL

	STZ	QUOTE	init for quoted string search
	LM	FIELD,#$FF	init the field count
	LDA	WORK	set it to 3 if this is a comment
	JSR	SCMNT2
	BCC	ST0
	LM	FIELD,#3
ST0	LDX	#0	pointer into LINE
	LDY	#0	pointer into WORK
ST1	LDA	WORK,Y	move a character
	STA	LINE,X
	INY		update the pointers
	INX
	CMP	QUOTE	check for start/stop of quoted string
	BNE	ST1A
	STZ	QUOTE
ST1A	JSR	SQUOT
	BCC	ST1B
	STA	QUOTE
ST1B	CMP	#' '	if a blank, check for tab settings
	BEQ	ST3
	CMP	#RETURN	if RETURN, quit
	BEQ	ST2
ST1C	CPX	#255	if line is longer than 255, quit
	BLT	ST1
	LDA	#RETURN
	STA	LINE+255
ST2	RTS

ST3	LDA	QUOTE	abort if in quoted string
	BNE	ST1C
	CPY	CMTCOL	if past comment col and
	BLT	ST3B
	LDA	WORK+1,Y	  there are two blanks then
	CMP	#' '
	BNE	ST3B
ST3A	CPX	CMTCOL	    write spaces to comment col
	BGT	ST3B
	STA	LINE,X
	INX
	BRA	ST3A
ST3B	INC	FIELD	set Y as a disp into the tab columns
	STY	TY
	LDY	FIELD
	CPY	#3
	BLT	ST4
	LDY	TY
	BNE	ST1
ST4	TXA		add blanks to LINE until the proper
	CMP	TAB,Y	 column is reached
	BGE	ST5
	LDA	#' '
	STA	LINE,X
	INX
	BNE	ST4
ST5	LDY	TY
	DEY
	LDA	#' '
ST6	INY
	CMP	WORK,Y
	BEQ	ST6
	CPY	CMTCOL	if past comment col and
	BLT	ST1
	CMP	WORK-2,Y	  there were two blanks then
	BEQ	ST3A	    skip to comment
	BRA	ST1

TAB	DC	I1'9,15,40'
TY	DS	1
FIELD	DS	1
	END

****************************************************************
*
*  SFNOP - Find Operation Code Field
*
*  INPUTS:
*	LINE - LINE
*
*  OUTPUTS:
*	Y - points to 1st char of the op code
*	C - set if found, else clear
*
****************************************************************
*
SFNOP	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SFNOP

	LDY	#0	init col #
	JSR	SSKPB	skip to blank
	BCC	RTS
	JSR	SSKPL	skip to letter
	BCC	RTS
	LDA	LINE-2,Y	skip 40 col rule if only one blank
	CMP	#' '
	BNE	OK
	STY	R14	40 character rule
	LDA	CMTCOL
	CMP	R14
RTS	RTS

OK	SEC
	RTS
	END

****************************************************************
*
*  SHIFT - Convert to Upper-Case
*
*  INPUTS:
*	A - character to convert
*
*  OUTPUTS:
*	A - upper-case character
*
****************************************************************
*
SHIFT	START
	LONGA OFF
	LONGI OFF
	DEBUG SHIFT

	CMP	#'a'
	BLT	RTS
	CMP	#'z'+1
	BGE	RTS
	SBC	#'a'-'A'-1
RTS	RTS
	END

****************************************************************
*
*  SINMT - Incriment R0 to Point to the Next Symbolic Parm
*
*  INPUTS:
*	R0 - pointer to a symbolic parm
*
*  OUTPUTS:
*	R0 - points to the next symbolic parm in the symbol
*		table
*
****************************************************************
*
SINMT	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SINMT

	LONG	I,M
	LDA	R0
	ORA	R2
	BEQ	RTS
	LDY	#4
	LDA	[R0],Y
	TAX
	INY
	INY
	LDA	[R0],Y
	STA	R2
	STX	R0
RTS	SHORT I,M
	RTS
	END

****************************************************************
*
*  SLABL - Check Label Syntax
*
*  INPUTS:
*	LINE - source line
*	Y - pointer to the character in LINE
*
*  OUTPUTS:
*	A - character after the label
*	C - set if error, else clear
*	LNAME - characters of the label
*
****************************************************************
*
SLABL	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SLABL

	DEY		dec Y so that the loop works
LB0	INY
	LDA	LINE,Y
	JSR	SALID	branch if not alpha
	BCC	NOTOK
	LDX	#0

LB1	CPX	#255	branch if length exceeded
	BEQ	LB1A
	INX		inc the pointers
	STA	LNAME,X	save the character
LB1A	INY
	LDA	LINE,Y	get the next character
	JSR	SANID	branch if still a part of the label
	BCS	LB1
	TXA		make sure there are an odd # of chars
	LSR	A
	BCS	LB1B
	INX
	LDA	#' '
	STA	LNAME,X
LB1B	STX	LNAME	set length
	LDA	LINE,Y	fetch next char
	CLC
	RTS		return with a good label

NOTOK	SEC		mark label as bad
	STZ	LNAME	set length to zero
	RTS
	END

****************************************************************
*
*  SOPCD - Evaluate the Op Code
*
*  INPUTS:
*	STRING - op code characters
*	OPLEN - op code length
*
*  OUTPUTS:
*	OP - op code number
*	OPF - op code flags
*
****************************************************************
*
SOPCD	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SOPCD
;
;  Initialization.
;
	LM	OP,#200	quit if the op code is longer than
	LM	OPF,#$6D	 8 characters, since no valid op
	STZ	INDXF	 code can be that long
	STZ	ACUMF
	LDA	OPLEN
	CMP	#9
	BGE	OP6
;
;  Check for a match to a table code.
;
	LDA	STRING	hash into table
	EOR	STRING+1
	EOR	STRING+2
	AND	#$1F
	ASL	A
	TAX
	LONG	M
	LDA	OPSC,X
	BEQ	OP6
	STA	R0
OP2	LDY	#0	check this op code for a match
	LDX	#3
OP3	LDA	STRING,Y
	CMP	(R0),Y
	BNE	OP4
	INY
	INY
	DBPL	X,OP3
	BMI	FN1

OP4	LDY	#10	next op code
	LDA	(R0),Y
	BEQ	OP6
	STA	R0
	BRL	OP2

OP6	SHORT M
	RTS
;
;  Op code found - do checks and set up.
;
FN1	SHORT M
	LDY	#9	check for alias
	LDA	(R0),Y
	TAX
	SEC
	SBC	#IXCE+1
	BMI	FN2
	CMP	#3
	BGE	FN2
	TAX
	LDA	OPALIAS,X
	TAX
FN2	CPX	#IXCE+1	check for unavailable 65816 and
	BGE	FN4	 65C02 op codes
	LDA	F65816
	BNE	FN4
	LDA	F65C02
	BNE	FN3
	BIT	AVOP,X
	BVS	FN4
	BRA	OP6
FN3	BIT	AVOP,X
	BPL	OP6
FN4	STX	OP	set op code number
	LDY	#8	set op code flags
	LDA	(R0),Y
	STA	OPF
	LDX	#0	set register size flags
FN5	LDA	ACUMLIST,X
	BEQ	FN6
	CMP	OP
	BEQ	FN8
	INX
	BNE	FN5
FN6	LDX	#0
FN7	LDA	INDXLIST,X
	BEQ	RTS
	CMP	OP
	BEQ	FN9
	INX
	BNE	FN7

FN8	INC	ACUMF
	RTS

FN9	INC	INDXF
RTS	RTS
	END

****************************************************************
*
*  SOPFN - Move Op Code to STRING
*
*  INPUTS:
*	LINE - source line
*
*  OUTPUTS:
*	STRING - OPLEN character op code
*	OPLEN - number of characters in the op code
*	C - clear if not found
*
****************************************************************
*
SOPFN	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SOPFN

	JSR	SCMNT	skip comment lines
	BCC	PF0
	CLC
	RTS

PF0	JSR	SFNOP	find the op code
	BCS	PF1
ERR1	ERROR #1	missing operation
!			move it to WORK
PF1	LONG	M	init fixed length op code to blanks
	LDA	#'  '
	STA	WORK
	STA	WORK+2
	STA	WORK+4
	STA	WORK+6
	SHORT M
	LDX	#0	init disp in line
PF3	LDA	LINE,Y	get a character
	CMP	#'&'
	BNE	PF4
	JSR	SYMBL	evaluate symbolic parameter:
	LDA	ERR	...skip if error
	BEQ	PF3
	LDA	LINE,Y
	CMP	#'&'
	BNE	PF3
PF4	CMP	#' '	check for done
	BEQ	PF5
	CMP	#RETURN
	BEQ	PF5
	STA	WORK,X	save the character
	INY		next character
	INX
	BNE	PF3

PF5	CPX	#0	error if op code is of length 0
	BEQ	ERR1
	STX	OPLEN	save length
	LONG	M	init fixed length op code to blanks
	LDA	#'  '
	STA	STRING
	STA	STRING+2
	STA	STRING+4
	STA	STRING+6
	SHORT M
PF6	LDA	WORK-1,X	move to STRING
	JSR	SHIFT
	STA	STRING-1,X
	DBNE	X,PF6
	SEC
	RTS
	END

****************************************************************
*
*  SOPRF - Locates the Operand Field
*
*  INPUTS:
*	LINE - source line
*
*  OUTPUTS:
*	Y - points to 1st char of operand field
*	C - set if operand found, else clear
*
****************************************************************
*
SOPRF	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SOPRF

	JSR	SFNOP	find op code
	BCC	RTS	quit if not found

	JSR	SSKPB	skip to the next blank
	BCC	RTS
	JSR	SSKPL	skip to the next character
	BCC	RTS
	CPY	CMTCOL	apply 40 char rule
	BLT	OK
	LDA	LINE-2,Y	apply 1 char rule
	CMP	#' '
	CLC
	BEQ	RTS
OK	SEC
RTS	RTS
	END

****************************************************************
*
*  SSKPB - Skip to Blank
*
*  INPUTS:
*	LINE - source line
*	Y - current character count
*
*  OUTPUTS:
*	Y - new character count
*	C - set if found, else clear
*
****************************************************************
*
SSKPB	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SSKPB

S1	LDA	LINE,Y	check for blank
	CMP	#' '
	BEQ	FND
	CMP	#RETURN
	BEQ	NFND
	INY		not found; loop
	BNE	S1

NFND	CLC		blank not found
FND	RTS		blank found
	END

****************************************************************
*
*  SSKPL - Skip to Letter
*
*  INPUTS:
*	LINE - source line
*	Y current character counter
*
*  OUTPUTS:
*	Y - new character counter
*	C - set if found, else clear
*
****************************************************************
*
SSKPL	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKPBL

KP1	LDA	LINE,Y	check this character
	CMP	#RETURN	if RETURN, char not found
	BEQ	KP2
	CMP	#' '	if not blank, char found
	BNE	KP3
	INY		try the next char
	BNE	KP1

KP2	CLC		char not found
	RTS

KP3	SEC		char found
	RTS
	END

****************************************************************
*
*  SSPCK - Find Symbolic Parameter in Symbol Table
*
*  INPUTS:
*	Y - disp in symbol table of symbolic parameter
*	LINE - source line
*
*  OUTPUTS:
*	SMPARM - symbolic parameter name pointer
*	SPT - type
*	SPCT - count
*	SPL - length
*	R4 - address of value
*	R8 - address of disp
*	Y - next character
*	C - clear if error
*
****************************************************************
*
SSPCK	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SSPCK
;
;  Get symbolic parameter.
;
	LDA	LINE,Y
	CMP	#'&'
	BEQ	CK2
	STY	RY
ERR4	ERROR #4,R	label syntax
	LDA	#16
	CMP	LERR
	BLT	RTS
	STA	LERR
RTS	LDY	RY
	CLC
	RTS

SSPCK2	ENTRY
CK2	INY
	STY	RY
	JSR	SSPFN	check for parm
	LDA	ERR
	BNE	RTS
	ADD4	R4,#8,R8
;
;  Evaluate subscript.
;
	STY	RY	save disp
	LA	SBC,1	init subscripts
	LDA	LINE,Y	check for '('
	CMP	#'('
	BNE	EV1
	INY		skip '('
	LONG	M	evaluate number
	LDX	#8
MV1	LDA	R2,X
	STA	SAVE,X
	DEX
	DBPL	X,MV1
	SHORT M
	JSR	FEVAL
	LDA	OPFIXED
	LONG	M
	BNE	MV1A
	ERROR #25,R	expression too complex
	LLA	OPV,1
MV1A	LDX	#8
MV2	LDA	SAVE,X
	STA	R2,X
	DEX
	DBPL	X,MV2
	SHORT M
	LDA	LERR
	CMP	#16
	BGE	RTS
	LDA	LINE,Y	make sure ')' is there
	CMP	#')'
	JNE	ERR4
	INY
	LDA	OPV	save subscript
	BEQ	ERR28
	STA	SBC
SC2	LDA	OPV+1
	ORA	OPV+2
	ORA	OPV+3
	BNE	ERR28
;
;  Set information.
;
EV1	LDA	LINE,Y	eat periods
	CMP	#'.'
	BNE	EV2
	INY
EV2	STY	RY	save line disp
	LDY	#DISPSPL	move NAME, SPT, SPCT
EV3	LDA	[R4],Y
	STA	SMPARM,Y
	DBPL	Y,EV3
	MOVE4 SMPARM,R12
	LDA	[R12]
	STA	LNAME
	TAY
EV3A	LDA	[R12],Y
	STA	LNAME,Y
	DBNE	Y,EV3A
	LDA	SPT	split on type
	CMP	#'Y'
	BGE	EV4

	LDA	SPCT	type A
	CMP	SBC	check subscript range
	BLT	ERR28
	LONG	M	set address
	LDA	SBC
	DEC	A
	ASL	A
	ASL	A
	INC	A
	STA	SBC
	SHORT M
	BRA	EV5

EV4	BNE	EV7	type B
	LDA	SPCT	check subscript range
	CMP	SBC
	BGE	EV5
ERR28	ERROR #28,R	subscript exceeded
	LDY	RY
	CLC
	RTS

EV5	CLC		set address
	LONG	M
	LDA	#DISPVAL-1
	ADC	SBC
	CLC
	ADC	R4
	STA	R4
	BCC	EV6
	INC	R6
EV6	SHORT M
RTS2	LDY	RY
	SEC
	RTS

EV7	LDX	SPCT	save start
	BNE	EV7B	handle zero subscripts
	LDA	SBC
	CMP	#1
	BNE	ERR28
	LDA	#0
	STA	SPL
	BEQ	RTS2
EV7B	CPX	SBC	check subscript range
	BCC	ERR28
	LONG	I,M	set [R4] to addr of string ptr
	ADD4	R4,#DISPVAL-4
	LDA	SBC
	ASL	A
	ASL	A
	CLC
	ADC	R4
	STA	R4
	BCC	EV11
	INC	R6
EV11	LDA	[R4]	WR0 = pointer to string
	STA	WR0
	LDY	#2
	LDA	[R4],Y
	STA	WR2
	ORA	WR0	branch if string pointer <> NIL
	SHORT I,M
	BNE	EV12
	STZ	SPL	set length of nil string to 0
	BRL	RTS2

EV12	LDA	[WR0]
	STA	SPL
	BRL	RTS2

RY	DS	1	temp Y register
SBC	DS	2
SAVE	DS	10
	END

****************************************************************
*
*  SSPFN - Locate a Sym Parm in the Symbol Table
*
*  INPUTS:
*	Y disp of sym parm in the line
*	LINE - source line
*
*  OUTPUTS:
*	SMTNL - macro table nest level where symbol resides
*	M1L - value of sym parm
*	R4 - addr of sym parm
*	Y - disp to 1st char past sym parm
*
****************************************************************
*
SSPFN	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SSPFN
;
;  Get symbolic parameter name.
;
	JSR	SLABL
	STY	LY
	BCC	CS0
	ERROR #4	label syntax
;
;  Set up case sensitivity.
;
CS0	LDA	FCASE	branch if case sensitive
	BNE	CS2
	LDX	LNAME	set LNAME case bits
CS1	LDA	LNAME,X
	TAY
	LDA	UPPERCASE,Y
	STA	LNAME,X
	DBNE	X,CS1
	LDY	LY
;
;  Search the symbol tables
;
CS2	LM	LMTNL,MTNL
PF1	JSR	SETSP	set up pointers
	MOVE4 CFIRST,R0
PF2	LONG	M	check for done
	LDA	R0
	ORA	R2
	SHORT M
	BEQ	PF3
	JSR	SCPL0	check this one
	BEQ	FND
	JSR	SINMT	incriment table
	BRA	PF2
PF3	DEC	MTNL	next symbol level
	LDA	MTNL
	CMP	#$FE
	BNE	PF1
;
;  Sym parm not found.
;
	LM	MTNL,LMTNL
	ERROR #22	symbolic parameter not found
;
;  Symbolic parameter found.
;
FND	LM	SMTNL,MTNL	set level where symbol is at
	LM	MTNL,LMTNL	restore normal MTNL
	LONG	I,M
	MOVE4 R0,R4	set addr
	STZ	M1L
	STZ	M1L+2
	SHORT I,M

	LDY	#DISPSPT	split on type
	LDA	[R4],Y
	CMP	#'Y'
	BCS	PF7
	LDY	#DISPVAL+3	A type - get value
	LDX	#3
PF6A	LDA	[R4],Y
	STA	M1L,X
	DEY
	DBPL	X,PF6A
	LDY	LY
	RTS

PF7	BNE	PF8	B type - get value
	LDY	#DISPVAL
	LDA	[R4],Y
	STA	M1L
	LDY	LY
	RTS

PF8	LONG	I,M	C type - set value to first 4 chars
	MOVE4 R8,SAVE	 of first string
	LDY	#DISPVAL	...save regs
	LDA	[R4],Y	...fetch addr of string
	STA	R8
	INY
	INY
	LDA	[R4],Y
	STA	R10
	STZ	M1L	...M1L = 0
	STZ	M1L+2
	ORA	R8
	SHORT I,M	...Y = min(4,length of string)
	BEQ	PF11
	LDA	[R8]
	BEQ	PF11
	CMP	#4
	BLT	PF9
	LDA	#4
PF9	TAY
PF10	LDA	[R8],Y	...fetch characters
	TYX
	STA	M1L-1,X
	DBNE	Y,PF10
PF11	MOVE4 SAVE,R8	...restore regs
	LDY	LY
	RTS

LMTNL	DS	1	local MTNL
LY	DS	1	temp Y storage
SAVE	DS	4
	END

****************************************************************
*
*  SWHIT - Is the character whitespace?
*
*  Inputs:
*	A - character to check
*
*  Outputs:
*	C - set if character is white space, else clear
*
****************************************************************
*
SWHIT	START
	USING COMMON
	LONGA OFF
	LONGI OFF
TAB	EQU	9	TAB key code

	CMP	#' '
	BEQ	RTS
	CMP	#RETURN
	BEQ	RTS
	CMP	#TAB
	BEQ	RTS
	CLC
RTS	RTS
	END

****************************************************************
*
*  SYMBL - Evaluate Symbolic Parameter
*
*  INPUTS:
*	Y - disp in LINE of sym parm
*	X - disp in WORK to put characters
*
*  OUTPUTS:
*	Y - first char in LINE past sym parm
*	X - first char in WORK past those inserted
*
****************************************************************
*
SYMBL	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SYMBL

	STX	TX	locate sym parm
	STY	TY
	JSR	SSPCK
	LDA	ERR
	CMP	#22
	JEQ	RTS
	STY	TY
	LDA	SPT	split on type
	CMP	#'Y'
	BEQ	SPY
	BGE	SPZ
;
;  Arithmetic type.
;
	LONG	I,M	load the value
	LDA	[R4]
	STA	M1L
	LDY	#2
	LDA	[R4],Y
	STA	M1L+2
	STZ	LSIGN
	BPL	SS1
	INC	LSIGN
	SUB4	#0,M1L,M1L
SS1	SHORT I,M
SPX0	JSR	SCVDC	convert to characters
	LDX	#0	skip leading zeros
	LDA	#'0'
SPX1	CMP	STRING,X
	BNE	SPX2
	INX
	CPX	#9
	BNE	SPX1

SPX2	LDY	TX	save the digits
	LDA	LSIGN	set sign
	BEQ	SPX3
	LDA	#'-'
	STA	WORK,Y
	INY
SPX3	LDA	STRING,X
	STA	WORK,Y
	INY
	INX
	CPX	#10
	BNE	SPX3
	STY	TX
	BEQ	RTS
;
;  Binary type.
;
SPY	LDA	[R4]	get value
	STA	M1L
	STZ	M1L+1
	STZ	M1L+2
	STZ	M1L+3
	BRA	SPX0	type A does the rest
;
;  Character type.
;
SPZ	LONG	M	dereference pointer to pointer to string
	LDA	[R4]
	STA	TEMPZP
	LDY	#2
	LDA	[R4],Y
	STA	TEMPZP+2
	ORA	TEMPZP
	SHORT M
	BEQ	RTS
	LDA	[TEMPZP]	quit if length is zero
	BEQ	RTS
	STA	LOOP	save length as loop ctr
	LDX	TX	fetch disp into output string
	LDY	#0	set disp into sym parm string
SPZ1	INY		move the string
	LDA	[TEMPZP],Y
	STA	WORK,X
	INX
	BEQ	RTS
	DBNE	LOOP,SPZ1
	STX	TX	save new disp into output string
RTS	LDX	TX	recover registers
	LDY	TY
	RTS

LOOP	DS	1
LSIGN	DS	2
	END

	APPEND FSNTX.ASM
