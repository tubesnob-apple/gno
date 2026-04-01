****************************************************************
*
*  FEVAL - Evaluate an Exression
*
*  INPUTS:
*	LINE - source line
*	Y - position of expression in line
*
*  OUTPUTS:
*	Y - position of first char past expression
*	OPV - value of the expression
*	OPFIXED - boolean flag; set to true if OPV is a
*		constant
*	PFIX - postfix expression
*	GLOBUSE - were global labels used?
*	COMPLEX - were operations other than +, - used?
*
****************************************************************
*
FEVAL	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG FEVAL

	JSR	SVINT	initialize for evaluation
	JSR	SPOST	parse the expression
	LDA	LERR
	CMP	#16
	BGE	LB1
	JSR	SEVAL	evaluate the expression
LB1	BRL	SVFIN	termination for evaluation
	END

****************************************************************
*
*  SATRB -  Evaluates Attributes
*
*  INPUTS:
*	LINE - source line
*	Y - disp in line
*
*  OUTPUTS:
*	X-A - numeric value of named attribute; type is the
*		ASCII value
*	TOK_ISP - for external labels, set to
*		3 - length attribute
*		4 - type attribute
*		5 - count attribute
*	TOK_OP - for external labels, set to pointer to label name
*
****************************************************************
*
SATRB	START
	USING COMMON
	USING OPCODE
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SATRB
;
;  Read attribute; split labels from symbolic parameters.
;
	LDA	LINE,Y	get attribute
	JSR	SHIFT
	CMP	#'S'
	JEQ	FL1
	PHA
	INY
	INY		check for sp
	LDA	LINE,Y
	CMP	#'&'
	BEQ	SP1
;
;  Evaluate label.
;
	JSR	SLABL	find label attributes
	BCS	ERR4
	PHY
	JSR	SLCHK
	PLY
	BCS	LB4
	PLA
	CMP	#'L'
	BNE	LB1
	LDA	LBL
	LDX	LBL+1
	RTS
LB1	CMP	#'T'	type
	BNE	LB2
	LDA	LBT
	LDX	#0
	RTS
LB2	CMP	#'C'	count
	BNE	LB3
	LDA	#1
	LDX	#0
	RTS

LB3	ERROR #7	operand syntax

LB4	PHY		unresolved label
	JSR	SAVEL
	PLY
	PLA
	CMP	#'C'
	BNE	LB5
	LDA	#2
	BNE	LB7
LB5	CMP	#'T'
	BNE	LB6
	LDA	#4
	BNE	LB7
LB6	LDA	#3
LB7	STA	TOK_ISP
	LDA	#0
	LDX	#0
	RTS

ERR4	PLA
	ERROR #4	Label Syntax
;
;  Evaluate symbolic parameter.
;
SP1	JSR	SSPCK2	find symbolic parm
	LDA	ERR
	CMP	#22
	BNE	SP3
	JSR	SLABL
	JSR	SLERR2
	PLA		allow count of unresolved parm
	CMP	#'C'
	BEQ	SP1A
ERR15	ERROR #15,R	Unresolved Parm Not Allowed
SP1A	LDA	#0
	LDX	#0
	RTS

SP3	PLA		length
	CMP	#'L'
	BNE	SP4
	LDA	SPL
	LDX	#0
	RTS

SP4	CMP	#'T'	type
	BNE	SP5
	LDA	SPT
	LDX	#0
	RTS

SP5	CMP	#'C'	count
	BNE	LB3
	LDA	SPCT
	LDX	#0
RTS	RTS
;
;  Flag attribute: set based on op code that follows.
;
FL1	INY		read the op code from the line
	INY
	PHY
	MOVE	#$20,LNAME,#8
	PLY
	LDX	#0
FL1A	LDA	LINE,Y
	JSR	SHIFT
	JSR	SANID
	BCC	FL1B
	STA	LNAME,X
	INY
	INX
	CPX	#8
	BLT	FL1A
	BGE	ERR33
FL1B	TXA
	BEQ	ERR33
	STY	RY
	LDA	LNAME	init hash address
	EOR	LNAME+1
	EOR	LNAME+2
	AND	#$1F
	ASL	A
	TAX
	LDA	OPSC+1,X
	STA	R1
	ORA	OPSC,X
	BEQ	ERR33
	LDA	OPSC,X
	STA	R0
FL2	LDY	#7	scan for op code
FL3	LDA	LNAME,Y
	CMP	(R0),Y
	BNE	FL4
	DBPL	Y,FL3
	BMI	FL5
FL4	LDY	#11
	LDA	(R0),Y
	TAX
	DEY
	LDA	(R0),Y
	STA	R0
	STX	R1
	ORA	R1
	BNE	FL2
ERR33	ERROR #33,R	undefined directive in attribute
	LDY	RY
	RTS

FL5	LDY	#9
	LDA	(R0),Y
	CMP	#IERR
	BLT	ERR33
	CMP	#IEXPAND+1
	BGE	ERR33
	LDY	RY
	SEC
	SBC	#IERR
	TAX
	LDA	ERRORS,X
	CPX	#2	flip MSB bit
	BNE	FL6
	EOR	#1
FL6	LDX	#0
	RTS

RY	DS	1	Y register storage
	END

****************************************************************
*
*  SAVEL - Save label
*
*  Inputs:
*	LNAME - name of label to save
*	X - table indicator; 0 for local, 1 for global
*
*  Outputs:
*	TOK_OP - pointer to the label name
*
****************************************************************
*
SAVEL	START
	USING COMMON
	USING EVALDT
	USING OPCODE
	DEBUG SAVEL

	LONG	I,M	find room in symbol table
	LDA	LNAME
	AND	#$FF
	PHA
	INC	A
	INC	A
	LDX	#0
	PHA		(if opcode is GEQU, use global table)
	LDA	OP
	AND	#$00FF
	CMP	#IGEQU
	BNE	LB0
	INX
LB0	PLA
	JSR	SROOM
	PLY		save symbol
LB1	LDA	LNAME,Y
	STA	[R0],Y
	DBPL	Y,LB1
	MOVE4 R0,TOK_OP	save pointer to symbol
	LDA	LNAME	update LSP
	AND	#$FF
	INC	A
	CLC
	ADC	LSP
	STA	LSP
	BCC	LB2
	INC	LSP+2
LB2	SHORT I,M
	RTS
	END

****************************************************************
*
*  SCMP4 - 4 Byte Compare
*
*  INPUTS:
*	M1L - first number
*	M3L - second number
*
****************************************************************
*
SCMP4	START
	LONGA OFF
	LONGI OFF
	DEBUG SCMP4

	LONG	M
	LDA	M1L+2
	CMP	M3L+2
	BNE	RTS
	LDA	M1L
	CMP	M3L
RTS	SHORT M
	RTS
	END

****************************************************************
*
*  SEVAL - Evaluate the Expression
*
*  INPUTS:
*	PFIX - expression
*
*  OUTPUTS:
*	OPV - value of the expression
*	OPFIXED - 1 if OPV is a constant, else 0
*
****************************************************************
*
SEVAL	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SEVAL

	STZ	TOP	init the stack and list
	STZ	TOP2
	LM	OPFIXED,#1	true until proven false
	LM	TOK_TYPE,#$FF	put on the EOF
	JSR	STACK

EV1	JSR	SGETT	get a token
	LDA	TOK_TYPE	split on token type
	BMI	EV3
	BEQ	EV2
	JSR	STACK	operand: stack it
	BRA	EV1

EV2	LDA	TOK_OP	operation: do it
	JSR	SEVOP
	LDA	LERR
	CMP	#16
	BLT	EV1
	RTS

EV3	LDA	TOP	EOF: quit
	CMP	#TOKEN_LEN*2
	BEQ	EV4
	ERROR #7	Operand Syntax
EV4	JSR	SUSTN	recover the value
	MOVE4 TOK_OP,OPV
	RTS
	END

****************************************************************
*
*  SEVOP - Evaluate a Single Operation
*
*  INPUTS:
*	TOP - top of evaluation stack
*	A - operation code
*
*  OUTPUTS:
*	TOP - modified; TOS has result
*
****************************************************************
*
SEVOP	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SEVOP
;
;  Load the operands.
;
	STZ	EXT	operands are not external yet
	PHA		save the op code
	TAX		get the number of operands
	LDA	NUMOPS,X
	CMP	#1	br if only one is needed
	BEQ	LD1

	JSR	SUSTN	unstack the 2nd operand
	MOVE	EXTERNAL,EXT
	MOVE4 TOK_OP,M3L
LD1	JSR	SUSTN	unstack the 1st operand
	LDA	EXT
	ORA	EXTERNAL
	STA	EXT
	MOVE4 TOK_OP,M1L
	PLA		recover the op code
;
;  Do the operation.
;
	CMP	#PLUS	addition
	BNE	EV1
	ADD4	M1L,M3L
	BRL	ST1

EV1	CMP	#MINUS	subtraction
	BNE	EV2
	SUB4	M1L,M3L
	BRL	ST1

EV2	CMP	#TIMES	multiplication
	BNE	EV3
	JSR	SMUL4
	BVS	ERR11
	LM	COMPLEX,#1
	BRL	ST1

ERR11	LDA	EXT	don't flag error if an operand is
	JNE	ST1	 external
	ERROR #11,R	numeric error in operand
	BRL	ST1

EV3	CMP	#DIV	division
	BNE	EV3A
	JSR	SDIV4
	BVS	ERR11
	LM	COMPLEX,#1
	BRL	ST1

EV3A	CMP	#BITSHIFT	bit shift
	BEQ	EV3G
	CMP	#BITSHIFT2
	BNE	EV4
EV3G	LM	COMPLEX,#1
	LDA	M3L+3
	BMI	EV3D
	LDA	M3L+3
	ORA	M3L+2
	ORA	M3L+1
	BNE	EV3F
	LDX	M3L
	BEQ	EV3C
EV3B	ASL	M1L
	ROL	M1L+1
	ROL	M1L+2
	ROL	M1L+3
	DBNE	X,EV3B
EV3C	BRL	ST1
EV3D	LDA	#$FF
	CMP	M3L+1
	BNE	EV3F
	CMP	M3L+2
	BNE	EV3F
	CMP	M3L+3
	BNE	EV3F
	LDX	M3L
EV3E	LDA	M1L+3
	ASL	A
	ROR	M1L+3
	ROR	M1L+2
	ROR	M1L+1
	ROR	M1L
	INX
	BNE	EV3E
	BRL	ST1
EV3F	STZ	M1L
	STZ	M1L+1
	STZ	M1L+2
	STZ	M1L+3
	BRL	ST1

EV4	CMP	#UMINUS	unary minus
	BNE	EV5
	LM	COMPLEX,#1
	STZ	M3L
	STZ	M3L+1
	STZ	M3L+2
	STZ	M3L+3
	SUB4	M3L,M1L,M1L
	BRL	ST1

EV5	CMP	#NOT	.NOT.
	BNE	EV6
	LM	COMPLEX,#1
	JSR	SLOGK
	LDA	M1L
	EOR	#1
	STA	M1L
	BRL	ST1

EV6	CMP	#AND	.AND.
	BNE	EV7
	LM	COMPLEX,#1
	JSR	SLOGK
	LDA	M1L
	AND	M3L
	STA	M1L
	BRL	ST1

EV7	CMP	#OR	.OR.
	BNE	EV8
	LM	COMPLEX,#1
	JSR	SLOGK
	LDA	M1L
	ORA	M3L
	STA	M1L
	BRL	ST1

EV8	CMP	#EOR	.EOR.
	BNE	EV9
	LM	COMPLEX,#1
	JSR	SLOGK
	LDA	M1L
	EOR	M3L
	STA	M1L
	BRL	ST1

EV9	CMP	#LT	<
	BNE	EV10
	LM	COMPLEX,#1
	JSR	SCMP4
	BLT	TRUE
	BGE	FALSE

EV10	CMP	#GT	>
	BNE	EV11
	LM	COMPLEX,#1
	JSR	SCMP4
	BGT	TRUE
	BRL	FALSE

EV11	CMP	#LE	<=
	BNE	EV12
	LM	COMPLEX,#1
	JSR	SCMP4
	BLE	TRUE
	BRL	FALSE

EV12	CMP	#GE	>=
	BNE	EV13
	LM	COMPLEX,#1
	JSR	SCMP4
	BGE	TRUE
	BLT	FALSE

EV13	CMP	#EQ	=
	BNE	EV14
	LM	COMPLEX,#1
	JSR	SCMP4
	BEQ	TRUE
	BNE	FALSE

EV14	LM	COMPLEX,#1	<>
	JSR	SCMP4
	BNE	TRUE
FALSE	LDA	#0
	BEQ	TR1
TRUE	LDA	#1
TR1	STA	M1L
	STZ	M1L+1
	STZ	M1L+2
	STZ	M1L+3
;
;  Save the result.
;
ST1	MOVE4 M1L,TOK_OP
	LM	TOK_EXT,EXT
	LM	TOK_TYPE,#1
	LM	TOK_ISP,#2
	BRL	STACK

EXT	DS	2	are the operands external?
	END

****************************************************************
*
*  SGETT - Get a Token from the Token List
*
*  INPUTS:
*	TOP2 - pointer into the list
*
*  OUTPUTS:
*	TOKEN - operand from the list
*	TOP2 - modified
*
****************************************************************
*
SGETT	START
	USING EVALDT
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SGETT

	LDY	TOP2
	LDX	#0
GT1	LDA	PFIX,Y
	STA	TOKEN,X
	INY
	INX
	CPX	#TOKEN_LEN
	BLT	GT1
	STY	TOP2
	RTS
	END

****************************************************************
*
*  SHXEV - Evaluate Hex Number
*
*  INPUTS:
*	Y - position of number in line
*	LINE - line containing number
*
*  OUTPUTS:
*	Y - next character
*	M1L - value of number
*
****************************************************************
*
SHXEV	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SHXEV

	STZ	M1L	init number
	STZ	M1L+1
	STZ	M1L+2
	STZ	M1L+3
H1	LDA	LINE,Y	get next character
	JSR	SHIFT
	JSR	SHXID	check for hex
	BCC	RTS
	JSR	SHXVL	get value
	LDX	#4
	CLC
H2	ROL	M1L
	ROL	M1L+1
	ROL	M1L+2
	ROL	M1L+3
	BCS	ER
	DBNE	X,H2
	ORA	M1L	insert new nybble
	STA	M1L
	INY
	BNE	H1

ER	ERROR #11	numeric error in operand
RTS	RTS
	END

****************************************************************
*
*  SLBEV - Evaluate Label in Operand
*
*  Inputs:
*	Y - position of label in line
*	TP - text pointer
*
*  Outputs:
*	M1L - label value, addr of expression for expressions
*	LBL - length attribute
*	LBT - type attribute
*	LBC - count attribute
*	LBFLAG - label flags
*	Y - next character
*	TOK_OP - label name if the label is not a constant
*	TOK_ISP - set to 0 for local labels, 1 for external
*		labels and expressions
*
*  Notes:
*	SLBEV2 is used by SLEXP to create tokens for labels
*	that did not exist on pass 1, but do now.
*
****************************************************************
*
SLBEV	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SLBEV

	LM	LBC,#1	set the count attribute for a defined
!			 label
LB0	JSR	SLABL	get label
	BCS	ERR4
	PHY		save char cnt
	JSR	SLCHK	find label
	PLY		reset char cnt
	BCS	ER	br if not found
SLBEV2	ENTRY
	MOVE4 LBV,M1L	move the value
	LDA	LBFLAG	br if the label is not relative
	AND	#LBREL
	BEQ	EQ1
	STZ	TOK_ISP	set flags for a local label
	SUB4	M1L,#$1000
	RTS

EQ1	LDA	LBFLAG	if the value is an expression, TOK_ISP
	AND	#LBEXPR	 is 6
	BEQ	RTS
	LM	TOK_ISP,#6
	RTS

ERR4	ERROR #4	label syntax

ER	LM	TOK_ISP,#1	handle an external or undefined label
	STA	GLOBUSE	indicate global use for rel br
	STZ	LBC
	STZ	LBT
	STZ	LBL
	STZ	LBL+1
LB1	PHY
	JSR	SAVEL
	PLY
RTS	RTS
	END

****************************************************************
*
*  SLEXP - List an expression
*
*  Inputs:
*	M1L - address of the expression
*
*  Notes:
*	SLEXP takes an expression and adds it to the current
*	expression by placing each token in the output stream
*	via calls to SOPLS.  It can be called recursively.
*
****************************************************************
*
SLEXP	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SLEXP

LX1	LDA	[M1L]	quit if at the end of the list
	BPL	LX2
	RTS

LX2	DEC	DEPTH	make sure we're not over our head
	BNE	LX2A
	INC	DEPTH
	ERROR #25	expression too complex

LX2A	LONG	M	save the expression pointer
	LDA	M1L+2
	PHA
	LDA	M1L
	PHA
	SHORT M
	LDY	#TOKEN_LEN-1	move the token into the local area
LX3	LDA	[M1L],Y
	STA	TOKEN,Y
	DBPL	Y,LX3
	LDA	TOK_TYPE	if the token is an unresolved label then
	CMP	#1
	BNE	LX6
	LDA	TOK_ISP
	CMP	#1
	BEQ	LX4
	CMP	#3
	BLT	LX6
	CMP	#6
	BLT	LX6
LX4	LONG	I,M	fetch the name
	MOVE4 TOK_OP,M1L
	LDY	#254
LX5	LDA	[M1L],Y
	STA	LNAME,Y
	DEY
	DBPL	Y,LX5
	SHORT I,M
	JSR	SLCHK	look it up
	BCS	LX6	quit if it doesn't exit (external)
	LM	TOK_ISP,#2	assume a constant label
	JSR	SLBEV2	create the proper entry
	MOVE4 M1L,TOK_OP	set the value
	LDA	LBFLAG
	AND	#LBEXPR
	BEQ	LX6
	LM	TOK_ISP,#6
LX6	JSR	SOPLS	list the token
	LONG	I,M	recover the expression pointer
	PLA
	STA	M1L
	PLA
	STA	M1L+2
	ADD4	M1L,#TOKEN_LEN	next token
	SHORT I,M
	INC	DEPTH
	BRL	LX1
	END

****************************************************************
*
*  SLOGK - Convert Operands to Logical Constants
*
*  INPUTS:
*	M1L - first operand
*	M3L - second operand
*
*  OUTPUTS:
*	M1L - 0 or 1
*	M3L - 0 or 1
*
****************************************************************
*
SLOGK	START
	LONGA OFF
	LONGI OFF
	DEBUG SLOGK

	LDX	#M1L	convert M1L
	JSR	LG1
	STA	M1L
	STZ	M1L+1
	STZ	M1L+2
	STZ	M1L+3
	LDX	#M3L	convert M3L
	JSR	LG1
	STA	M3L
	STZ	M3L+1
	STZ	M3L+2
	STZ	M3L+3
	RTS

LG1	LDA	0,X	load a 1 or 0
	ORA	1,X
	ORA	2,X
	ORA	3,X
	BEQ	LG2
	LDA	#1
LG2	RTS
	END

****************************************************************
*
*  SOPLS - List an Operand or Operation
*
*  INPUTS:
*	TOKEN - operand or operation to list
*	TOP2 - end of list
*
*  OUTPUTS:
*	TOP2 - modified
*
*  NOTES:
*	1)  If the token is an operation and the operands are
*		constant, the operation is performed locally.
*
****************************************************************
*
SOPLS	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SOPLS
;
;  Check for an operation on constants.
;
	LDA	TOK_TYPE	skip if the token is not an operation
	JNE	LS1
	LDX	TOK_OP	split based on the number of operands
	LDA	NUMOPS,X	 needed
	CMP	#2
	BEQ	CK1

	LDA	TOP2	see if there is a constant
	CMP	#TOKEN_LEN
	BLT	LS1
	TAY
	LDA	PFIX-TOKEN_LEN,Y	skip if top is not an operand
	BEQ	LS1
	LDA	PFIX-1,Y	skip if not constant
	CMP	#2
	BNE	LS1
	TXA		yes -> save the op code
	PHA
	JSR	SULST	stack the constant
	JSR	STACK
	JMP	CK2

CK1	LDA	TOP2	see if there are two constants
	CMP	#TOKEN_LEN*2
	BLT	LS1
	TAY
	LDA	PFIX-TOKEN_LEN,Y	skip if either is an operation
	BEQ	LS1
	LDA	PFIX-(2*TOKEN_LEN),Y
	BEQ	LS1
	LDA	PFIX-1,Y	if both are constant or
	BNE	CK1A	  (both are relative and operation is -)
	LDA	PFIX-1-TOKEN_LEN,Y
	BNE	LS1
	CPX	#MINUS
	BNE	LS1
	BEQ	CK1B
CK1A	CMP	#2
	BNE	LS1
	LDA	PFIX-1-TOKEN_LEN,Y
	CMP	#2
	BNE	LS1
CK1B	TXA		then -> save the op code
	PHA
	JSR	SULST	place the operands on the stack
	MOVE	TOKEN,LTOKEN,#TOKEN_LEN
	JSR	SULST
	JSR	STACK
	MOVE	LTOKEN,TOKEN,#TOKEN_LEN
	JSR	STACK
CK2	PLA		do the operation
	JSR	SEVOP
	JSR	SUSTK
;
;  If the operand is an expression, list the expression.
;
LS1	LDA	TOK_TYPE
	CMP	#1
	BNE	LS1A
	LDA	TOK_ISP
	CMP	#6
	BNE	LS1A
	JMP	SLEXP
;
;  List the token.
;
LS1A	LDY	TOP2	init the indeces
	LDX	#0
LS2	LDA	TOKEN,X	move the 12 byte token
	STA	PFIX,Y
	INY
	BEQ	ERR25
	INX
	CPX	#TOKEN_LEN
	BNE	LS2
	STY	TOP2	save the new end of list
	RTS

ERR25	ERROR #25	error in expression

LTOKEN	DS	7	local token storage
	END

****************************************************************
*
*  SPOST - Parse an Expression
*
*  Puts an expression into postfix notation.
*
*  INPUTS:
*	LINE - source line
*	Y - position of expression in the line
*
*  OUTPUTS:
*	Y - position of the first char past the expression
*	PFIX - reduced postfix expression
*
****************************************************************
*
SPOST	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SPOST
;
;  Initialization.
;
	STZ	SFLAG
	STZ	NPARIN
	STZ	TOP
	STZ	TOP2
	STZ	TOK_ISP
	STY	CC
	LM	TOK_TYPE,#$FF	stack the return code
	JSR	STACK
;
;  Read a token.
;
PS1	JSR	STOKE	read a token
	LDA	LERR	quit if a syntax error was found
	CMP	#16
	BGE	RTS

	LDA	TOK_TYPE	split on type
	BMI	PS2
	BEQ	PS3
;
;  Handle an operand.
;
	JSR	SOPLS
	BRA	PS1

RTS	RTS
;
;  Handle an EOF.
;
PS2	LDA	NPARIN	flag an error if there are unballenced
	BNE	ERR7	 left parenthesis
PS2A	LDA	TOP	quit if the stack is empty
	BEQ	RTS
	JSR	SUSTK	unstack an operation
	JSR	SOPLS	list it
	BRA	PS2A	next operation
;
;  Handle operations.
;
PS3	LDA	TOK_OP	branch if not a ')'
	CMP	#RPARIN
	BNE	PS6
PS4	JSR	SUSTK	unstack an operation
	LDA	TOK_TYPE	flag error of EOF is encountered
	BEQ	PS5
ERR7	ERROR #7	Operand Syntax

PS5	LDA	TOK_OP	if '(' then quit
	CMP	#LPARIN
	BEQ	PS1
	JSR	SOPLS	list the operation
	BRL	PS4

PS6	PHY		handle a math or logic operation
	MOVE	TOKEN,TTOKEN,#TOKEN_LEN+1
	PLY
PS7	JSR	SUSTK	list TOS operations until one with a
	LDA	TTOK_ICP	 lower ISP is found
	CMP	TOK_ISP
	BGT	PS8
	JSR	SOPLS
	BRL	PS7
PS8	JSR	STACK	restack the old operation
	PHY
	MOVE	TTOKEN,TOKEN,#TOKEN_LEN+1
	PLY
	JSR	STACK	stack the new operation
	BRL	PS1
	END

****************************************************************
*
*  STACK - Stack a Token
*
*  INPUTS:
*	TOKEN - token to stack
*	TOP - top of token stack
*
*  OUTPUTS:
*	TOP - modified
*
****************************************************************
*
STACK	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG STACK

	LDY	TOP	set indexes
	LDX	#0
TK1	LDA	TOKEN,X	move the 12 byte token
	STA	WORK2,Y
	INY
	BEQ	ERR25	quit if the stack overflows
	INX
	CPX	#TOKEN_LEN
	BNE	TK1
	STY	TOP	save the new TOS
	RTS

ERR25	ERROR #25	error in expression
	END

****************************************************************
*
*  STKOP - Parse an Operand
*
*  INPUTS:
*	CC - pointer to the operand
*	SFLAG - sign allowed flag
*
*  OUTPUTS:
*	TOKEN - token found
*	CC - modified
*	SFLAG - 1
*
****************************************************************
*
STKOP	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG STKOP

	CLC		make sure than an operand is allowed
	LDA	SFLAG	 as the next token
	BNE	RTS

	STZ	TOK_EXT	default is "not external"
	INC	SFLAG	SFLAG = 1
	LDY	CC	skip unary pluses
	LDA	LINE,Y
	CMP	#'+'
	BNE	TK1
	INC	CC
	INY
TK1	JSR	STREV	read the value
	BCC	NOT
	STY	CC
	LDA	TOK_ISP	set the operand value (set by SLBEV for
	BEQ	IN0	 local and external labels)
	CMP	#2
	BNE	IN1
IN0	MOVE4 M1L,TOK_OP
IN1	LM	TOK_TYPE,#1	set the token type
	SEC
RTS	RTS

NOT	DEC	SFLAG	not an operand - reset SFLAG
	CLC
	RTS
	END

****************************************************************
*
*  STKSM - Parse an Operation
*
*  INPUTS:
*	CC - pointer to the token in the line
*	NPARIN - number of left parenthesis
*	SFLAG - sign flag
*
*  OUTPUTS:
*	CC - modified
*	SFLAG - modified
*	TOKEN - token found
*
****************************************************************
*
STKSM	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG STKSM

	LA	R10,TOKLIST	R10 is a pointer to the token list
	STZ	TOK_OP	TOK_OP is the token number
TK1	LDX	CC	set up for a check
	LDY	#0
	LDA	(R10),Y
	BEQ	NOTFOUND
	STA	R13
	INY
TK2	LDA	LINE,X	compare the line to the token in the
	JSR	SHIFT	 list
	CMP	(R10),Y
	BNE	TK3
	INY
	INX
	DBNE	R13,TK2
	BEQ	TK5	branch if there was a match

TK3	LDY	#0	next token
	LDA	(R10),Y
	SEC
	ADC	R10
	STA	R10
	BCC	TK4
	INC	R11
TK4	INC	TOK_OP
	BNE	TK1

NOTFOUND CLC		token was not found
	RTS

TK5	STZ	TOK_TYPE	Token found -> set the type
	STX	CC	update the pointer
	LDX	TOK_OP	set the NSP and ICP
	LDA	NSP,X
	STA	TOK_ISP
	LDA	ICP,X
	STA	TOK_ICP

	LDA	TOK_OP	if the token is .NOT., make sure that
	CMP	#NOT	 an operand was expected
	BNE	TK6
	LDA	SFLAG
	BNE	ERR7
	SEC
	RTS

TK6	CMP	#MINUS	check for a unary minus
	BNE	TK7
	LDA	SFLAG
	BNE	TK9
	LDX	#UMINUS
	STX	TOK_OP
	LDA	NSP,X
	STA	TOK_ISP
	LDA	ICP,X
	STA	TOK_ICP
	SEC
	RTS

TK7	CMP	#LPARIN	check for a '('
	BNE	TK8
	LDA	SFLAG
	BNE	ERR7
	INC	NPARIN
	SEC
	RTS

ERR7	ERROR #7,R	operand syntax
	CLC
	RTS

TK8	CMP	#RPARIN	check for a ')'
	BNE	TK9
	DEC	NPARIN
	BMI	TK8A
	LDA	SFLAG
	BEQ	ERR7
	SEC
	RTS
TK8A	DEC	CC
	INC	NPARIN
	CLC
	RTS

TK9	LDA	SFLAG	general token search
	BEQ	ERR7
	DEC	SFLAG
	SEC
	RTS

ICP	DC	I1'2,2,3,3,3,3,4,4'	in comming priority
	DC	I1'3,2,2,1,1,1,1,1'
	DC	I1'1,8,8'
NSP	DC	I1'2,2,3,3,3,3,4,4'	in stack priority
	DC	I1'3,2,2,1,1,1,1,1'
	DC	I1'1,0,0'
	END

****************************************************************
*
*  STOKE - Read a Token
*
*  INPUTS:
*	CC - pointer to the token in the line
*	NPARIN - number of left parenthesis
*	SFLAG - sign flag
*
*  OUTPUTS:
*	CC - modified
*	SFLAG - modified
*	TOKEN - token found
*
****************************************************************
*
STOKE	START
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG STOKE

	JSR	STKOP	parse operands
	BCS	RTS
	JSR	STKSM	parse operations
	BCS	RTS

	LM	TOK_TYPE,#$FF	mark the end of the expression
	STZ	TOK_ISP
RTS	RTS
	END

****************************************************************
*
*  STREV - Evaluate String Value
*
*  INPUTS:
*	LINE - line containing string
*	Y - disp of string
*
*  OUTPUTS:
*	M1L - value of string
*	Y - disp to 1st char past string
*	C - set if value, else clear
*	TOK_ISP - type of operand:
*		0 - local label
*		1 - external or unresolved label
*		2 - constant
*		3 - length attribute
*		4 - type attribute
*		5 - count attribute
*		6 - label whos value is an expression
*
*  NOTES:
*	1)  For local and external labels, TOK_OP is
*		pre-set to the name of the label.
*
****************************************************************
*
STREV	START
	USING EVALDT
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG STREV

	LM	TOK_ISP,#2	flag as a constant
	STZ	M1L
	STZ	M1L+1
	STZ	M1L+2
	STZ	M1L+3
	LDA	LINE,Y	br if not a character type
	JSR	SALID
	BCC	NM1
	LDA	LINE+1,Y	split out attributes
	CMP	#':'	colon identifier?
	BNE	LB1
;
;  Attributes.
;
	JSR	SATRB
	STA	M1L
	STX	M1L+1
	STZ	M1L+2
	STZ	M1L+3
	INC	TOK_EXT
	SEC
	RTS
;
;  Handle label.
;
LB1	JSR	SLBEV	get label value
	LDA	TOK_ISP
	CMP	#2
	BEQ	LB2
	INC	TOK_EXT
LB2	SEC
	RTS
;
;  Evaluate decimal number.
;
NM1	JSR	SNMID
	BCC	HX1
	JSR	SNMEV	evaluate number
	SEC
	RTS
;
;  Evaluate hex number.
;
HX1	CMP	#'$'
	BNE	SP1
	INY		evaluate number
	JSR	SHXEV
	SEC
	RTS
;
;  Symbolic parameters.
;
SP1	CMP	#'&'
	BNE	AN1
	INY
	MOVE4 R0,SAVE
	MOVE4 R4,SAVE+4
	JSR	SSPFN
	MOVE4 SAVE,R0
	MOVE4 SAVE+4,R4
	SEC
	RTS
;
;  Alpha-numeric character.
;
AN1	JSR	SQUOT
	BCC	BN1
	JSR	SWORD2	get char(s)
	BCC	SNER

	LDA	ASCII	set and byte
	LSR	A
	ROR	A
	EOR	#$80
	STA	R0

	STY	M3L
	LDX	#0
	LDY	WORD
	BEQ	AN3
	CPY	#4
	BLT	AN2
	LDY	#4
AN2	LDA	WORD,Y
	ORA	R0
	STA	M1L,X
	INX
	DBNE	Y,AN2
AN3	LDY	M3L
RTS	SEC
	RTS

SNER	ERROR #7,R	syntax error
ERTS	CLC
	RTS
;
;  Binary constant.
;
BN1	CMP	#'%'
	BNE	OC1
	INY
BN2	LDA	LINE,Y	get next number
	CMP	#'1'
	BEQ	BN3
	CMP	#'0'
	BNE	RTS
	CLC		 0 - clear carry
	BCC	BN4
BN3	SEC		 1 - set carry
BN4	ROL	M1L	roll in new bit
	ROL	M1L+1
	ROL	M1L+2
	ROL	M1L+3
	BCS	ERR11
	INY		loop
	BNE	BN2

ERR11	ERROR #11	numeric error in operand
	SEC
	RTS
;
;  Octal constant.
;
OC1	CMP	#'@'
	BNE	ST1
	INY
	LA	R0,0	init number
OC2	LDA	LINE,Y	get next number
	CMP	#'0'	check range
	BCC	RTS
	CMP	#'8'
	BCS	RTS
	STY	R0	roll old number
	LDY	#3
OC3	CLC
	ROL	M1L
	ROL	M1L+1
	ROL	M1L+2
	ROL	M1L+3
	BCS	ERR11
	DBNE	Y,OC3
	LDY	R0
	AND	#7	insert number
	ORA	M1L
	STA	M1L
	INY		loop
	BNE	OC2
	SEC
	RTS
;
;  Location Counter.
;
ST1	CMP	#'*'
	BNE	ERTS
	LDA	OBJFLAG	if objFlag then
	BEQ	ST2
	LONG	I,M	  m1l = str-objStr+objOrg
	SUB4	STR,OBJSTR,M1L
	ADD4	M1L,OBJORG
	SHORT	I,M
	BRA	ST3	else
ST2	STZ	TOK_ISP                    flag as relocatable value
	SUB4	STR,#$1000,M1L
	INC	TOK_EXT
ST3	INY
	SEC
	RTS

SAVE	DS	8
	END

****************************************************************
*
*  SULST - Unlist an Operand
*
*  INPUTS:
*	TOP2 - end of list
*
*  OUTPUTS:
*	TOKEN - operand from end of list
*	TOP2 - updated
*
****************************************************************
*
SULST	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SULST

	LDY	TOP2
	LDX	#TOKEN_LEN-1
TK1	DEY
	LDA	PFIX,Y
	STA	TOKEN,X
	DBPL	X,TK1
	STY	TOP2
	RTS
	END

****************************************************************
*
*  SUSTK - Unstack a Token
*
*  INPUTS:
*	TOP - top of token stack
*
*  OUTPUTS:
*	TOKEN - token from TOS
*	TOP - modified
*
****************************************************************
*
SUSTK	START
	USING EVALDT
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SUSTK

	LDY	TOP
	LDX	#TOKEN_LEN-1
TK1	DEY
	LDA	WORK2,Y
	STA	TOKEN,X
	DBPL	X,TK1
	STY	TOP
	RTS
	END

****************************************************************
*
*  SUSTN - Unstack a Number
*
*  Unstacks an operand, converting it into a constant if
*  necessary.
*
*  INPUTS:
*	TOP - top of stack
*
*  OUTPUTS:
*	TOKEN - token read
*	OPFIXED - set to 0 if a non-constant was loaded
*	EXTERNAL - was the operand external?
*
****************************************************************
*
SUSTN	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SUSTN

	JSR	SUSTK	unstack the operand
	LDA	TOK_EXT	initialize external flag
	STA	EXTERNAL
	LDA	TOK_ISP	quit if its a constant
	CMP	#2
	BEQ	RTS
	STZ	OPFIXED	indicate that the expression has a
	INC	EXTERNAL	 variable
	CMP	#1
	BNE	RTS	branch if its a displacement
	STZ	TOK_OP	use $8000 for external labels
	STZ	TOK_OP+2
	STZ	TOK_OP+3
	LDA	#$80
	STA	TOK_OP+1
RTS	RTS
	END

****************************************************************
*
*  SVFIN - Evaluation Termination
*
****************************************************************
*
SVFIN	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SVFIN

	DEC	RECL	dec the recursive nest level
	BNE	VF1
	LDY	CC
	RTS

VF1	LDA	CC	restore recursive variables
	PHA
	LONG	I,M
	MOVE	STK,CC,#5
	CLC
	LDA	TWORK
	STA	M1L
	ADC	#256
	STA	TEMPZP
	LDA	TWORK+2
	STA	M1L+2
	ADC	#0
	STA	TEMPZP+2
	SHORT I,M
	LDY	#0
VF2	LDA	[M1L],Y
	STA	PFIX,Y
	LDA	[TEMPZP],Y
	STA	WORK2,Y
	DBNE	Y,VF2
	DISPOSE ESHAND
	MOVE4 TLSP,LSP	restore local symbol table end
	PLA
	TAY
	RTS
	END

****************************************************************
*
*  SVINT - Evaluation Initialization
*
****************************************************************
*
SVINT	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SVINT

	LDA	RECL	branch if not a recursive entry
	JEQ	VN2
	PHY		save char ptr
	MOVE	CC,STK,#5	stack variables
	NEW	ESHAND,#512	find some memory
	JCS	TERR
	LOCK	ESHAND,M1L
	JCS	TERR
	MOVE4 M1L,TWORK
	ADD4	M1L,#256,TEMPZP	place the stack and list in the
	LDY	#0	 reserved memory
VN1	LDA	PFIX,Y
	STA	[M1L],Y
	LDA	WORK2,Y
	STA	[TEMPZP],Y
	DBNE	Y,VN1
	PLY		restore char ptr
VN2	INC	RECL	inc the recursive nest level
	STZ	BSHIFT	init the bit shift count
	MOVE4 LSP,TLSP	save local symbol table end
	STZ	COMPLEX	assume not complex
	RTS

TERR	JMP	TERR1	Out of Memory
	END

	APPEND FMCRO.ASM
