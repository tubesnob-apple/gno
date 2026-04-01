****************************************************************
*
*  FPAS1 - Pass 1
*
*  INPUTS:
*	TP - text pointer
*
****************************************************************
*
FPAS1	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG FPAS1
;
;  Evaluate a line.
;
	JSR	FSNTX	do syntax analysis
	LONG	M	set the length attribute
	LDA	LENGTH
	STA	LLBL
	SHORT M
	LDA	OBJFLAG	if in an OBJ area, labels are constant
	BEQ	P1
	LM	LLBT,#'G'
;
;  Check for a START directive.
;
P1	LDA	OP	skip if a START was not found
	CMP	#ISTART
	BEQ	P2
	CMP	#IDATA
	BEQ	P2
	CMP	#IPRIVATE
	BEQ	P2
	CMP	#IPRIVDATA
	BNE	P3
P2	LDX	LLNAME	save the name of the file
	STX	SNAME
LB1	LDA	LLNAME,X
	STA	SNAME,X
	DEX
	BNE	LB1
	LDA	LIST	write the start message
	BNE	P5
	LDA	PROGRESS
	BEQ	P5
	PRINT
	PRINT2 'Pass 1: '
	LDY	#0
P2A	LDA	SNAME+1,Y
	COUT	A
	INY
	CPY	SNAME
	BNE	P2A
	PRINT
	BRA	P5
;
;  Put the label in the symbol table.
;
P3	LDA	LLNAME	skip if there is no label
	BEQ	P5
	LDA	OP	GEQU is the only true global label
	CMP	#IGEQU
	BNE	P4
	SEC
	JSR	SINLB
	BRA	P5

P4	CLC		put the label in the local symbol table
	JSR	SINLB
;
;  Check for early exit
;
p5	jsr	Stop	see if we need to quit
	bcs	p6
	rts

p6	stz	work	abort the assembly with a null error
	la	r0,work	 message
	brl	SABORT
	end

****************************************************************
*
*  FPAS2 - Pass 2
*
*  INPUTS:
*	TP - text pointer
*
****************************************************************
*
FPAS2	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG FPAS2
;
;  Evaluate the line.
;
	LDA	MTNL	if the line is from the source file then
	BPL	EL1
	INC4	LC	  incriment the source line count
	BRL	EL2	else
EL1	INC4	GLC	  incriment the global line count
EL2	JSR	FSNTX	do syntax analysis
;
;  Check for addressing errors.
;
	LDA	LLNAME	skip if the line has no label
	BEQ	CA1
	DEC	A
	BNE	CA0
	LDA	LLNAME+1
	CMP	#' '
	BEQ	CA1
CA0	LDX	LLNAME
	STX	LNAME
LB1	LDA	LLNAME,X
	STA	LNAME,X
	DEX
	BNE	LB1
	JSR	SLCHK	find the label in the symbol table
	BCC	CA1A
CA1	BRL	SS1

CA1A	LDA	OP	check the label values if it is an
	CMP	#IEQU	 equate
	BEQ	CA1B
	CMP	#IGEQU
	BNE	CA2
CA1B	LDA	LBFLAG	...but skip the check if it's an
	AND	#LBEXPR	 expression
	BNE	SS1
	LDY	#LLBV-LLBPTR+3
	LDX	#3
CA1C	LDA	[R0],Y
	CMP	LLBV,X
	JNE	CA3
	DEY
	DBPL	X,CA1C
	BRL	SS1

CA2	MOVE	STR,LLBV,#4	if in an OBJ area, be sure and check
	LDA	OBJFLAG	 the OBJed label value
	BEQ	CA2A
	LONG	I,M
	SUB4	STR,OBJSTR,LLBV
	ADD4	LLBV,OBJORG
	SHORT I,M
CA2A	CMPW	LLBV,LBV	branch if the addresses match
	BNE	CA3
	CMPW	LLBV+2,LBV+2
	BEQ	SS1
CA3	ERROR #23,R	Addressing Error
;
;  Listing control.
;
SS1	LDA	ERR
	BNE	SS1A
	LDA	OP
	CMP	#ICOPY
	BEQ	SS2
	CMP	#IAPPEND
	BEQ	SS2
SS1A	JSR	SLIST
;
;  Check the error level.
;
SS2	JSR	SERCK
;
;  Check for early exit
;
	jsr	Stop	see if we need to quit
	bcs	ss3
	rts

ss3	stz	work	abort the assembly with a null error
	la	r0,work	 message
	brl	SABORT
	end

****************************************************************
*
*  FPAS3 - Pass 3
*
*  Performs the pre-pass on a line.
*
*  INPUTS:
*	TP - text pointer
*
*  OUTPUTS:
*	C - clear if at end of assembly
*
****************************************************************
*
FPAS3	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG FPAS3

	JSR	FORML	check for a statement that is not
	LDA	OPF	 valid outside of a code segment
	AND	#STRT
	BNE	AA1
	ERROR #16,R
	JSR	SLIST
	SEC
	RTS

AA1	LM	LMERRF,MERRF
	LM	LERRN,ERR
	MOVE	NERR,LNERR
	LDA	FSTART
	PHA
	STZ	SNAME
	JSR	FPAS1
	PLA
	STA	FSTART
	LM	TLERR,ERR
	LM	MERRF,LMERRF
	LM	ERR,LERRN
	MOVE	LNERR,NERR
	LDA	OP
	CMP	#IAPPEND
	BEQ	AA4
	CMP	#ICOPY
	BEQ	AA4

AA3	INC	PASS
	JSR	FPAS2
	DEC	PASS
	SEC
	RTS

AA4	LDA	TLERR
	BEQ	AA5
	STA	ERR
	JSR	SLIST
	JSR	SERCK
AA5	SEC
	RTS

LMERRF	DS	1
LNERR	DS	2
LERRN	DS	1
TLERR	DS	1
	END

****************************************************************
*
*  SCMNT - Check for a Comment
*
*  INPUTS:
*	LINE - line to check
*
*  OUTPUTS:
*	C - set if comment, else clear
*	OPF - set to $6C if the line is a comment, else
*		unchanged
*
*  NOTES:
*	1)  Entry at SCMNT2 is for non-blank lines with the
*	    first character in the line already in A.
*
****************************************************************
*
SCMNT	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SCMNT

	LDA	LINE	check for a blank line
	CMP	#RETURN
	BEQ	COMENT

SCMNT2	ENTRY
	LDX	#4	check for a line starting with
CM1	CMP	CHAR,X	 "*", ";", "!", "."
	BEQ	COMENT
	DBPL	X,CM1
	CLC		not a comment
	RTS

COMENT	LM	OPF,#$6D	comment found
	LM	OP,#200
	SEC
	RTS

CHAR	DC	C'*;!.',H'0C'
	END

****************************************************************
*
*  SCPLN - Compute the number of lines in the file
*
*  INPUTS:
*	AP - location of current line
*	SRCBUFF - start of file
*
*  OUTPUTS:
*	M1L - number of lines
*
****************************************************************
*
SCPLN	START
	USING COMMON
	USING MACDAT
	USING KEEPCOM

	LONG	I,M
	LDA	#1
	STA	M1L	initialize line counter
	LDA	MTNL	  recover AP from src lev stack frame
	AND	#$0080
	BNE	CP1
	MOVE4 MSTK,R4
	BRA	CP2
CP1	MOVE4 AP,R4
CP2	SUB4	R4,SRCBUFF
	LDA	R6
	BMI	RTS
	ORA	R4
	BEQ	RTS
	MOVE4 SRCBUFF,LOCKP
	LDY	#0

CP3	DEC4	R4
	LDA	[LOCKP]
	AND	#$00FF
	INC4	LOCKP
	CMP	#RETURN
	BNE	CP3
	INC	M1L
	LDA	R4
	ORA	R6
	BNE	CP3
RTS	SHORT I,M
	RTS
	END

****************************************************************
*
*  SCPL0 - Compare 'LABEL' to the label at [R0]
*
*  INPUTS:
*	LNAME - first label
*	R0 - pointer to the second label
*
*  OUTPUTS:
*	Z - =0 if 'LABEL'=(R0)
*
****************************************************************
*
SCPL0	START
	USING COMMON
	LONGI OFF
	DEBUG SCPL0

	LONG	I,M
	MOVE4 R4,SAVE	save zp regs
	LDA	[R0]	get ptr to name
	STA	R4
	LDY	#2
	LDA	[R0],Y
	STA	R6
	SHORT I,M
	AGO	.SCPL0A	print symbols being compared
	LDA	[R4]
	TAX
	LDY	#1
DB1	LDA	[R4],Y
	COUT	A
	INY
	DBNE	X,DB1
	PRBL	#4
	LDX	LNAME
	LDY	#1
DB2	LDA	LNAME,Y
	COUT	A
	INY
	DBNE	X,DB2
	JSR	SCESC
.SCPL0A
LB0	LDA	[R4]	see if lengths match
	CMP	LNAME
	BNE	LB2
	TAY
	LDA	FCASE	branch if not case sensitive
	BNE	NC1

LB1	LDA	[R4],Y	do a case insensitive compare
	TAX
	LDA	UPPERCASE,X
	CMP	LNAME,Y
	BNE	LB2
	DBNE	Y,LB1
	BRA	LB2

NC1	LDA	[R4],Y	do a case sensitive compare
	CMP	LNAME,Y
	BNE	LB2
	DBNE	Y,NC1

LB2	PHP		save compare result
	MOVE4 SAVE,R4	restore zp
	PLP
	RTS

SAVE	DS	4
	END

****************************************************************
*
*  SERCK - Checks for Errors, Updates Error Level
*
*  INPUTS:
*	ERR - error number in the current line
*	MERR - max error level so far
*	NERR - number of errors
*
*  OUTPUTS:
*	MERR - max (ERR,MERR)
*	NERR = NERR+1 if err <> 0
*
****************************************************************
*
SERCK	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SERCK

	LDX	ERR	check for no error
	BEQ	ER
	INC2	NERR	NERR = NERR + 1
ER	LDA	LERR	get error severity
	CMP	MERRF
	BLT	RTS	save the highest severity
	STA	MERRF
RTS	RTS
	END

****************************************************************
*
*  SHASH - Compute hash table entry
*
*  Inputs:
*	LNAME - name of label to compute hash for
*
*  Outputs:
*	R0 - disp into the hash table
*
*  Notes: may be called in long or short mode
*
****************************************************************
*
SHASH	start
	using Common

	php		save reg sizes
	long	I,M	use long registers
	stz	r0	r0 = disp into table
	stz	r2
	lda	lname	Y = disp to last usable word of name
	and	#$FF
	dec	A
	cmp	#9
	blt	hs1
	lda	#8
hs1	tay
hs2	lda	lname,Y	fetch a word
	ora	#$2020	force lowercase
	and	#$003F	crunch the characters
	sta	temp
	lda	lname,Y
	ora	#$2020
	and	#$3F00
	lsr	A
	lsr	A
	ora	temp
	adc	r0	add into hash disp
	sta	r0
	dey		next word
	dbpl	Y,hs2
	lda	r0	R0 = R0 mod HASHSIZE
hs3	cmp	#hashSize
	blt	hs4
	sbc	#hashSize
	bra	hs3
hs4	asl	A	convert to disp
	asl	A
	sta	r0
	plp		reset register sizes
	rts

temp	ds	2
	longa off
	longi off
	end

****************************************************************
*
*  SINLB - Inserts Label in Symbol Table
*
*  INPUTS:
*	C - set for global symbol table; clear for local symbols
*	LLNAME - label name
*	LLBV - label value
*	LLBT - label type
*	LLBL - label length
*
*  OUTPUTS:
*	C - clear if duplicate label
*
****************************************************************
*
SINLB	START
	USING COMMON
	USING EVALDT
	LONGA OFF
	LONGI OFF
	DEBUG SINLB
;..............................................................;
;
;  Check for duplicate labels.
;
;..............................................................;
;
	LDA	#0	set the stable flag
	ROL	A
	STA	TFLAG
	LDX	LLNAME	try to find the label
	STX	LNAME
IN1	LDA	LLNAME,X
	STA	LNAME,X
	DEX
	BNE	IN1
	LDA	TFLAG
	LSR	A
	JSR	SRCHL
	BCS	IN8
;
;  Duplicate label
;
	LDY	#LLBFLAG-LLBPTR	get disp to LBF field
	LDA	[R0],Y	set duplicate flag
	ORA	#LBDUP
	STA	[R0],Y
	CLC
	RTS
;..............................................................;
;
;  Insert the label in the table.
;
;..............................................................;
;
IN8	LONG	I,M	make sure there is room for the name
	LDX	TFLAG
	LDA	LLNAME
	AND	#$FF
	INC	A
	JSR	SROOM
	LDA	LLNAME	put name in the table
	AND	#$FF
	DEC	A
	TAY
IN8A	LDA	LLNAME,Y
	STA	[R0],Y
	DEY
	DBPL	Y,IN8A
	MOVE4 R0,LLBPTR	save disp to table
	LDA	LLBFLAG	branch if not expression
	AND	#LBEXPR
	BEQ	IN8E
	LDY	#0	find length of the expression
	SHORT I,M
IN8B	LDA	PFIX,Y
	BMI	IN8C
	CLC
	TYA
	ADC	#TOKEN_LEN
	TAY
	BRA	IN8B
IN8C	CLC
	TYA
	ADC	#TOKEN_LEN
	LONG	I,M
	AND	#$FF
	PHA
	LDX	TFLAG	find a spot for the expression
	INC	A
	JSR	SROOM
	PLY		place the expression in the table
	SHORT M
IN8D	LDA	PFIX,Y
	STA	[R0],Y
	DBPL	Y,IN8D
	LONG	M
	LDA	R0
	STA	LLBV
	LDA	R2
	STA	LLBV+2
IN8E	SHORT I,M
	JSR	SHASH	R4 = addr of hash table ptr
	LONG	I,M	LLNEXT = hash table ptr
	LDA	TFLAG
	BEQ	IN9
	ADD4	R0,GHASH,R4
	BRA	IN10
IN9	ADD4	R0,LHASH,R4
IN10	LDY	#2
	LDA	[R4]
	STA	LLNEXT
	LDA	[R4],Y
	STA	LLNEXT+2
	LDX	TFLAG	make sure there is room for the entry
	LDA	#LLBFLAG-LLBPTR+1
	JSR	SROOM
	SHORT M,I
	LDY	#LLBFLAG-LLBPTR	put entry in table
IN11	LDA	LLBPTR,Y
	STA	[R0],Y
	DBPL	Y,IN11
	LONG	M	set pointer in hash table
	LDA	R0
	STA	[R4]
	LDY	#2
	LDA	R2
	STA	[R4],Y
	SHORT M
	SEC
	RTS

TFLAG	DC	I'0'	set for global table, else clear
	END

****************************************************************
*
*  SLCHK - Searches Symbol Table for Label
*      LABEL
*
*  INPUTS:
*	LABEL - label to search for
*
*  OUTPUTS:
*	LBV - value of the label
*	LBL - length attribute
*	LBT - type attribute
*	LBFLAG - label flags
*	LBC - count attribute
*	C - clear if found, else set
*
****************************************************************
*
SLCHK	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SLCHK

	LDA	ENDF	don't check local table if not in a
	BNE	LB1	 segment
	CLC		check the local table
	JSR	SRCHL
	BCC	RTS
LB1	SEC		check the global table
	JSR	SRCHL	search table
RTS	RTS
	END

****************************************************************
*
*  SLIST - Controls Listing of Lines on Screen
*
*  INPUTS:
*	LINE - line to list
*	LLNAME - line label, to check for errors
*	EQUCNT - to check for unresolved pass 1 equates
*	DPCNT - to check for duplicate labels
*
****************************************************************
*
SLIST	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SLIST
;..............................................................;
;
;  Check for label errors in the line.
;
;..............................................................;
;
	LDA	ERR	br if errors found
	BNE	L9
	LDA	TRCEFL	print anything if trace on
	BNE	L1
	LDA	LINE	don't print sequence symbols
	CMP	#'.'
	BEQ	RTS
;
;  Check for duplicate labels
;
L1	LDA	LLNAME	don't check if there is no label
	BEQ	L9
	DEC	A
	BNE	L5
	LDA	LLNAME+1
	CMP	#' '
	BEQ	L9
L5	LDX	LLNAME	ckeck for a duplicate
	STX	LNAME
L6	LDA	LLNAME,X
	STA	LNAME,X
	DEX
	BNE	L6
	JSR	SLCHK
	LDA	LBFLAG	(LBDUP is $80)
	BPL	L9
	STZ	ERR	error found
	STZ	LERR
	ERROR #3,R	Duplicate Label
;..............................................................;
;
;  Determine if the line should be printed.
;
;..............................................................;
;
L9	LDA	OP	print anything but END if trace is on
	CMP	#IEND
	BEQ	L10
	LDA	TRCEFL
	BNE	PRINT
L9A	LDA	ERR
	BEQ	L10
	LDA	ERRORS
	BNE	PRINT
L10	LDA	MTNL	check for macro expansion
	BMI	L10A
	LDA	GENER
	BEQ	RTS
L10A	LDA	LIST	check for print enabled
	BEQ	RTS
	LDA	OPF	check for non-printing line
	AND	#PFLG
	BNE	PRINT
RTS	RTS		don't print it
;..............................................................;
;
;  Print the line.
;
;..............................................................;
;
;  Print the line number.
;
PRINT	DEBUG PRINT
	LDA	ERR
	BEQ	P1
	LDA	ERRORS
	JEQ	ERS
	LDA	WAIT
	BNE	P1
	LDA	EDITOR
	BEQ	P1
	LDA	TERMINAL
	JNE	ERS

P1	LDA	MTNL	print the line number
	BMI	P2
	PRBL	#5
	BRL	P3
P2	MOVE4 LC,M1L
	JSR	SCVDC
	WRITE2 STRING+6,4
	LDA	#' '
	COUT	A
;
;  Print the "absolute" address
;
P3	LDA	FABSADDR
	BEQ	P4
	LDA	ABSADDR+2
	PRHEX
	LDA	ABSADDR+1
	PRHEX
	LDA	ABSADDR
	PRHEX
	LDA	#' '
	COUT	A
;
;  Print the address.
;
P4	SEC
	LDA	STR+1
	SBC	#$10
	PRHEX
	LDA	STR
	PRHEX
	LDA	#' '
	COUT	A
;
;  Print 4 bytes of code.
;
	STZ	R0	set the byte count
	JSR	SPRCD
	LONG	M
	LDA	R0
	STA	TR0
	SHORT M
;
;  Print the instruction times, if needed.
;
	LDA	FINSTIME
	BEQ	P5A
	LDA	INSTIME
	COUT	A
	LDA	INSTIME+1
	COUT	A
;
;  Print macro expansion symbol, if needed.
;
P5A	LDA	#' '	check for expansion
	LDX	MTNL
	BMI	P6	macro expansion
	LDA	#'+'
P6	COUT	A
;
;  Print the line.
;
	LDX	#0
P7	LDA	LINE,X
	CMP	#RETURN
	BEQ	P8
	COUT	A
	INX
	BNE	P7
P8	LDA	ERR
	BNE	P9
	JSR	SCESC
	BRA	P10
P9	JSR	SRITE2
;
;  Generate for DC.
;
P10	LDX	EXP	br if not generate
	BEQ	ERS
	LDX	OP	br if not DC
	CPX	#IDC
	BNE	ERS

	LONG	M	set length counter
	LDA	TR0
	STA	R0
	SHORT M
G1	LDX	R0	check for completion
	CPX	LENGTH
	BGE	ERS
	CPX	#16
	BGE	ERS
	PRBL	#5	skip line number
	LDA	FABSADDR	skip abs addr, if not used
	BEQ	G3
	CLC		print abs addr
	LDA	R0
	ADC	ABSADDR
	PHA
	LDA	ABSADDR+1
	ADC	#0
	PHA
	LDA	ABSADDR+2
	ADC	#0
	PRHEX
	PLA
	PRHEX
	PLA
	PRHEX
	LDA	#' '
	COUT	A
G3	CLC		compute the address
	LDA	STR
	ADC	R0
	PHA
	LDA	STR+1
	ADC	#$F0
	PRHEX		print the address
	PLA
	PRHEX
	PRBL	#1
	JSR	SPRCD	print the code
	JSR	SCESC
	BRL	G1	next 4 bytes
;..............................................................;
;
;  Print the error line, if any.
;
;..............................................................;
;
ERS	LDA	ERR	check for errors
	BNE	ERS1
	RTS

ERS1	DEBUG AFTERERR
	LA	R0,ER	inc to correct message
	LDX	ERR
ERS2	DEX
	BEQ	ERS3
	SEC
	LDA	(R0)
	ADC	R0
	STA	R0
	BCC	ERS2
	INC	R0+1
	BNE	ERS2

ERS3	BRL	SWERR	write out the error message

ER	DW	'Missing Operation'
	DW	'Invalid Operand'
	DW	'Duplicate Label'
	DW	'Label Syntax'
	DW	'Macro file not in use'
	DW	'Missing Operand'
	DW	'Operand Syntax'
	DW	'Address Length Not Valid'
	DW	'Nest Level Exceeded'
	DW	'Missing label'

	DW	'Numeric Error in Operand'
	DW	'Rel Branch Out of Range'
	DW	'Unidentified Operation'
	DW	'Too Many MACRO Libs'
	DW	'Unresolved Label not Allowed'
	DW	'Misplaced Statement'
	DW	'17'
	DW	'No MEND'
	DW	'Set Symbol Type Mismatch'
	DW	'Sequence Symbol Not Found'

	DW	'ACTR Count Exceeded'
	DW	'Undefined Symbolic Parameter'
	DW	'Addressing Error'
	DW	'24'
	DW	'Expression Too Complex'
	DW	'Too Many Positional Parameters'
	DW	'Duplicate Ref in MACRO Operand'
	DW	'Subscript Exceeded'
	DW	'Length Exceeded'
	DW	'MACRO Operand Syntax Error'

	DW	'31'
	DW	'32'
	DW	'Undefined Directive in Attribute'
	DW	'34'
	DW	'Operand Value Not Allowed'
	DW	'Duplicate Segment'

TR0	DS	2
	END

****************************************************************
*
*  SPRCD - Prints 4 Bytes of Code for SLIST
*
*  INPUTS:
*	LENGTH - length of code to be printed
*	R0 - points to start of code
*
****************************************************************
*
SPRCD	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SPRCD

	LDY	#4	byte count
P1	LDX	R0
	CPX	LENGTH
	BEQ	P3
P2	LDA	CODE,X	print byte
	PRHEX
	LDA	#' '
	COUT	A
	INC	R0
	DBNE	Y,P1
	RTS

P3	PRBL	#3	finish with some blanks
	DBNE	Y,P3
	RTS
	END

****************************************************************
*
*  SRCHL - Searches the Symbol Table for a Label
*
*  INPUTS:
*	LNAME - label to search for
*	C - set for global symbol table, clear for local
*
*  OUTPUTS:
*	LBV - value of label
*	LBT - type attribute
*	LBL - label length attribute
*	LBC - count attriblute
*	LBFLAG - label flags
*	C - clear if found, else set
*	R0 - insert point
*
****************************************************************
*
SRCHL	start
	using Common
	debug SRCHL
;
;  Check for an empty table.
;
	phy		save the line displacement
	long	I,M	set the symbol table flag
	lda	#0
	rol	A
	sta	global
	move4 r4,save	save zp area
	jsr	SHASH	compute hash
	lda	global
	beq	hs1
	add4	r0,ghash,r4
	bra	hs2
hs1	add4	r0,lhash,r4
hs2	ldy	#2
	lda	[r4]
	sta	r0
	lda	[r4],Y
	sta	r2
;
;  For case insensitivity, switch to lowercase.
;
	lda	fcase	branch if case sensitive
	and	#$FF
	bne	ck1
	short I,M
	ldx	lname	X = length of symbol
cs1	lda	lname,X	save symbol and switch case
	sta	work,X
	tay
	lda	Uppercase,Y
	sta	lname,X
	dbne	X,cs1
	long	I,M
;
;  Check for the label.
;
ck1	lda	r0	quit if no more labels
	ora	r2
	beq	notFound

	lda	[r0]	get ptr to name
	sta	r4
	ldy	#2
	lda	[r0],Y
	sta	r6
	short I,M
	lda	[r4]	see if lengths match
	cmp	lname
	bne	cp2
	tay
	lda	fCase	check for case sensitivity
	bne	cp1a

cp1	lda	[r4],Y	do a case insensitive compare
	tax
	lda	Uppercase,X
	cmp	lname,Y
	bne	cp2
	dbne	Y,cp1
	bra	found

cp1a	lda	[r4],Y	do a case sensitive compare
	cmp	lname,Y
	bne	cp2
	dbne	Y,cp1a
	bra	found

cp2	long	I,M	next label
	ldy	#lnext-lbptr
	lda	[r0],Y
	tax
	iny
	iny
	lda	[r0],Y
	sta	r2
	stx	r0
	bra	ck1
;
;  Set label information.
;
	longa off
	longi off
found	long	I,M
	move4 save,r4
	short M,I
	ldy	#lbflag-lbptr
fd1	lda	[r0],Y
	sta	lbptr,Y
	dbpl	Y,fd1
	clc
	bra	fd2

	longa on
	longi on
notFound move4 r4,save
	short I,M
	stz	lbflag
	sec
fd2	php		for case insensitive, resore LNAME
	lda	fcase
	bne	fd4
	ldx	lname
fd3	lda	work,X
	sta	lname,X
	dbne	X,fd3
fd4	plp
	ply
	rts

global	ds	2	global symbol table?
save	ds	4	save area for r4-r7
	longa off
	longi off
	end

****************************************************************
*
*  SROOM - Make sure symbol table has room
*
*  Inputs:
*	X - table flag
*		0 - local symbol table
*		1 - global symbol table
*		2 - macro table
*		3 - symbolic parameter table
*	A - # of bytes needed
*
*  Outputs:
*	R0 - pointer to spot in table to use
*
*  Notes:
*	Must be called in full native mode
*
****************************************************************
*
SROOM	START
	USING COMMON
CHAIN	EQU	TEMPZP	next hash chain
SYMBOL	EQU	TEMPZP+4	next symbol
LOOP	EQU	TEMPZP+8	# hash chains left
	LONGA ON	use long regs
	LONGI ON

	STA	BYTES	save # bytes needed
	CPX	#1	branch if not global
	JNE	RM2
;
;  Global symbol table
;
	CLC		set address to use & compute new end
	LDA	GSP
	STA	R0
	ADC	BYTES
	STA	GSP
	LDA	GSP+2
	STA	R2
	BCC	RM1
	INC	GSP+2
RM1	LDA	GSP+2	branch if not past end
	CMP	GEND+2
	BNE	RM1A
	LDA	GSP
	CMP	GEND
RM1A	JLT	RTS
	NEW	GHAND,#GSIZE	get a new area
	JCS	ERR
	LOCK	GHAND,GSTART
	JCS	ERR
	ADD4	GSTART,#GSIZE,GEND
	MOVE4 GSTART,R0
	ADD4	R0,BYTES,GSP
RTS	RTS		all done
;
;  Local symbol table
;
RM2	JGE	RM4	branch if not local
	CLC		set address to use & compute new end
	LDA	LSP
	STA	R0
	ADC	BYTES
	STA	LSP
	LDA	LSP+2
	STA	R2
	BCC	RM3
	INC	LSP+2
RM3	LDA	LSP+2	quit if new end is in old table
	CMP	LEND+2
	BNE	RM3A
	LDA	LSP
	CMP	LEND
RM3A	BLT	RTS
	NEW	HAND,#LSIZE	get a new area
	JCS	ERR
	LOCK	HAND,LSTART
	JCS	ERR
	MOVE4 LSTART,CHAIN	save old area's handle in new table
	LDY	#2
	LDA	LHAND
	STA	[CHAIN]
	LDA	LHAND+2
	STA	[CHAIN],Y
	MOVE4 HAND,LHAND	lock down the new area
	ADD4	LSTART,#LSIZE,LEND
	ADD4	LSTART,#4,R0
	ADD4	R0,BYTES,LSP
	RTS
;
;  Macro names table
;
RM4	CPX	#3	branch for sym parm
	JGE	RM5
	ADD4	MSP,BYTES,HAND	if HAND = MSP+BYTES < MEND then
	LDA	HAND+2
	CMP	MEND+2
	BNE	RM4A
	LDA	HAND
	CMP	MEND
RM4A	BGE	RM4B
	MOVE4 MSP,R0	  R0 = MSP
	MOVE4 HAND,MSP	  MSP = HAND
	RTS		  return
RM4B	ANOP		endif
	NEW	HAND,#MSIZE	HAND = new(MSIZE)
	JCS	ERR
	LOCK	HAND,MSTART	MSTART = lock(HAND)
	JCS	ERR
	MOVE4 MSTART,R0	*MSTART = THAND
	LDY	#2
	LDA	THAND
	STA	[R0]
	LDA	THAND+2
	STA	[R0],Y
	MOVE4 HAND,THAND	THAND = HAND
	ADD4	MSTART,#MSIZE,MEND	MEND = MSTART+MSIZE
	ADD4	MSTART,#4,R0	R0 = MSTART+4
	ADD4	R0,BYTES,MSP	MSP = R0+BYTES
	RTS
;
;  Symbolic parameter table
;
RM5	ADD4	CSP,BYTES,HAND	if HAND = CSP+BYTES < CEND then
	LDA	HAND+2
	CMP	CEND+2
	BNE	RM6
	LDA	HAND
	CMP	CEND
RM6	BGE	RM7
	MOVE4 CSP,R0	  R0 = CSP
	MOVE4 HAND,CSP	  CSP = HAND
	RTS		  return
RM7	ANOP		endif
	NEW	HAND,#PSIZE	HAND = new(PSIZE)
	JCS	ERR
	LOCK	HAND,CSTART	CSTART = lock(HAND)
	JCS	ERR
	MOVE4 CSTART,R0	*CSTART = SPHAND
	LDY	#2
	LDA	SPHAND
	STA	[R0]
	LDA	SPHAND+2
	STA	[R0],Y
	MOVE4 HAND,SPHAND	SPHAND = HAND
	ADD4	CSTART,#PSIZE,CEND	CEND = CSTART+ASIZE
	ADD4	CSTART,#4,R0	R0 = CSTART+4
	ADD4	R0,BYTES,CSP	CSP = R0+BYTES
	RTS

ERR	SHORT I,M
	BRL	TERR1	out of memory

	LONGA OFF
	LONGI OFF
BYTES	DC	I4'0'
HAND	DS	4
	END

****************************************************************
*
*  SWERR - Write out an error message
*
*  Inputs:
*	R0 - pointer to error message
*
*  Uses:
*	TERMINAL - exit on error
*	EDITOR - abort to editor
*	WAIT - pause on keypress
*
*  Notes:
*	This routine will write an error message, pause for
*	a key press, and continue or exit back to the editor
*	or shell.
*
****************************************************************
*
SWERR	START
	USING COMMON
	USING MACDAT
	USING KEEPCOM
	LONGA OFF	use long regs
	LONGI OFF
KEYBOARD EQU	$C000
STROBE	EQU	$C010

	LDA	WAIT	if wait || ! editor || ! terminal
	BNE	WE1
	LDA	EDITOR
	BEQ	WE1
	LDA	TERMINAL
	BNE	WE2
WE1	ERROUT
	JSR	FormError	write standard form stuff
	LDA	(R0)
	STA	MLEN
	ADD2	R0,#1,MADDR
	JSR	SRITE
	DC	H'40'
MLEN	DS	1
MADDR	DS	2
	JSR	SCESC
	STDOUT
WE2	LDA	WAIT	if wait
	BEQ	WE3
	STA	>STROBE	  wait for a key press
WE2A	LDA	>KEYBOARD
	BPL	WE2A
	STA	>STROBE

WE3	LDA	TERMINAL	if terminal
	BNE	WE4
	RTS
;
;  Terminal Abort Entry Point
;
SABORT	ENTRY
	STA	>$C010	reset keyboard strobe
WE4	JSR	SPROF
	LDA	EDITOR	  if editor flag
	BEQ	WE6

	LDA	MTNL	  recover AP from src lev stack frame
	BMI	WE5
	MOVE4 MSTK,AP
WE5	LONG	I,M
	SUB4	AP,SRCBUFF,ORG
	JSR	SetSFileFName	  set file name
	JSR	SetErrorMessage	  set the terminal error message
	SHORT I,M
	LM	MERRF,#$FF	  set error level

WE6	JSR	Purge	  purge the open file, if any
	DISPOSEALL	  dispose memory
	jsr	ErrorLInfo	return LInfo to the shell
	jsr	StopSpin	stop the spinner
	LONG	I,M
	JSR	SCPCS	compute checksum
	LDA	#0
	JMP	QUIT

	LONGA OFF
	LONGI OFF
	END

	APPEND FKEEP.ASM
