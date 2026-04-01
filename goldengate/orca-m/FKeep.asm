****************************************************************
*
*  FKEEP - Keep Object Code
*
*  This collection of subroutines provides the interface
*  between the assembler and the O/S necessary to write
*  information to the object module.
*
****************************************************************
*
	EJECT
****************************************************************
*
*  SAVER - Save Registers
*
*  INPUTS:
*	A,X,Y - registers to save
*
*  OUTPUTS:
*	KA,KX,KY - saved registers
*
*  NOTES:
*	1)  If KFLAG=0, control is returned to the subroutine
*		that called this one.
*
****************************************************************
*
SAVER	START
	USING COMMON
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SAVER

	STA	KA	save the registers
	STX	KX
	STY	KY
	LDA	KFLAG	check the KEEP flag
	BEQ	AV1
	LDA	PASS
	CMP	#1
	BEQ	AV1
	LDA	KA	KEEP on, restore A
	RTS

AV1	PLA		KEEP off
	PLA
	LDA	KA
	RTS
	END

****************************************************************
*
*  SKBWR - Write the Keep Buffer to the Keep Handle
*
*  Inputs:
*	BUFFER - buffer to write
*	KEEPHANDLE - buffer handle
*	MARK - # of bytes actually used so far
*
****************************************************************
*
SKBWR	START
	USING KEEPCOM
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKBWR

	LONG	I,M
	ADD4	MARK,#MAXBCNT,TEMP	if the buffer is full then
	PHA
	PHA
	PH4	KEEPHANDLE
	_GETHANDLESIZE
	PLA
	PLX
	CPX	TEMP+2
	BNE	LB0
	CMP	TEMP
LB0	JLT	LB5
	PHA		  allocate a new, larger block
	PHA
	CLC
	LDA	MARK
	ADC	#KEEPSIZE
	TAX
	LDA	MARK+2
	ADC	#^KEEPSIZE
	PHA
	PHX
	PH2	USER_ID
	PH2	#$8000
	PH4	#0
	_NEWHANDLE
	PL4	KEEPHANDLE2
	JCS	TERR1
	PH4	KEEPHANDLE	  lock the old keep area
	_HLOCK
	LDY	#2	  dereference the two handles
	LDA	[KEEPHANDLE]
	STA	KP1
	LDA	[KEEPHANDLE],Y
	STA	KP1+2
	LDA	[KEEPHANDLE2]
	STA	KP2
	LDA	[KEEPHANDLE2],Y
	STA	KP2+2
	LDX	MARK+2	  move 64K blocks of code
	BEQ	LB2
	LDY	#0
LB1	LDA	[KP1],Y
	STA	[KP2],Y
	DEY
	DEY
	BNE	LB1
	INC	KP1+2
	INC	KP2+2
	DEX
	BNE	LB1
LB2	LDA	MARK	  move a partial bank of code
	BEQ	LB4
	TAY
	LSR	A
	BCC	LB2A
	DEY
	SHORT M
	LDA	[KP1],Y
	STA	[KP2],Y
	LONG	M
	TYA
	BEQ	LB4
LB2A	DEY
	DEY
	BEQ	LB3A
LB3	LDA	[KP1],Y
	STA	[KP2],Y
	DEY
	DEY
	BNE	LB3
LB3A	LDA	[KP1]
	STA	[KP2]
LB4	PH4	KEEPHANDLE	  dispose of the old block
	_DISPOSEHANDLE
	MOVE4 KEEPHANDLE2,KEEPHANDLE	  start using the old handle
LB5	ANOP		endif
	PH4	KEEPHANDLE	lock the buffer
	_HLOCK
	LDY	#2	dereference keephandle^+mark
	CLC
	LDA	[KEEPHANDLE]
	ADC	MARK
	STA	KP1
	LDA	[KEEPHANDLE],Y
	ADC	MARK+2
	STA	KP1+2
	LDY	#MAXBCNT-2	move the bytes into the buffer
LB6	LDA	BUFFER,Y
	STA	[KP1],Y
	DEY
	DEY
	BPL	LB6
	PH4	KEEPHANDLE	unlock the buffer
	_HUNLOCK
	SHORT I,M
	RTS

TEMP	DS	4
	END

****************************************************************
*
*  SKCNS - Keep a Constant Byte
*
*  INPUTS:
*	A - byte to keep
*	KCNT - number of constant bytes saved so far
*
****************************************************************
*
SKCNS	START
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SKCNS

	JSR	SAVER	save registers
	LDX	KCNT	save the byte
	STA	CBYTES,X
	INC	KCNT	inc the constant count
	CPX	#$DE	if the constant buffer is full, write it
	BLT	KC1	 to disk
	JSR	SPURG
KC1	BRL	SREST	restore the registers
	END

****************************************************************
*
*  SKDAT - Keep a DATA Area Use
*
*  INPUTS:
*	LNAME - name of DATA area
*
****************************************************************
*
SKDAT	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKDAT

	JSR	SAVER	save the registers
	JSR	SPURG
	LDA	#$E4	output the DATA op code
	JSR	SKEEP
	JSR	SKNME
	BRL	SREST	restore the registers
	END

****************************************************************
*
*  SKEEP - Keep a Byte
*
*  INPUTS:
*	A - byte to keep
*	DSCNT - number of bytes at end of old code
*	BCNT - number of buffered bytes
*
*  OUTPUTS:
*	BCNT - updated
*	BUFFER - buffered bytes
*
****************************************************************
*
SKEEP	START
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SKEEP

	PHA		save the byte to output
	LDA	DSCNT	see if any space needs to be reserved
	ORA	DSCNT+1
	ORA	DSCNT+2
	ORA	DSCNT+3
	BEQ	KP1
	LDA	#$F1	yes -> output the reserve space op code
	JSR	KP2
	LDA	DSCNT	output the number of bytes to reserve
	JSR	KP2
	LDA	DSCNT+1
	JSR	KP2
	LDA	DSCNT+2
	JSR	KP2
	LDA	DSCNT+3
	JSR	KP2
	STZ	DSCNT	zero the DS count
	STZ	DSCNT+1
	STZ	DSCNT+2
	STZ	DSCNT+3
KP1	PLA		recover the byte to save

	AIF	DEBUGK,.SKEEP1
KP2	PHX		place the byte in the output buffer
	PHA
	LDX	BCNT
	STA	BUFFER,X
	CPX	#MAXBCNT-1	if the buffer is full then
	BLT	KP3
	PHY		  write it out
	JSR	SKBWR
	ADD4	MARK,#MAXBCNT	update MARK
	PLY
	ADD4	OLEN,#MAXBCNT	update the obj module length
	LDX	#$FF
	STX	BCNT
KP3	INC	BCNT
	PLA
	PLX
	RTS

	AGO	.SKEEP2
.SKEEP1
KP2	PHA
	PRHEX
	PLA
	RTS
.SKEEP2
	END

****************************************************************
*
*  SKEND - Close the Current Code Segment
*
*  INPUTS:
*	CBYTES - number of constant bytes
*	BCNT - number of bytes in buffer
*	DSCNT - number of bytes at end of module
*	OLEN - object module length
*	HEAD - pointer to the header of the object module
*	KINDUSED - was a KIND directive specified?
*	KINDVAL - kind field value
*
****************************************************************
*
SKEND	START
	USING COMMON
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SKEND

	AIF	DEBUGK,.SKENDA
	JSR	SAVER	save registers
	JSR	SPURG	clear out the constant buffer
	LONG	M,I
	MOVE4 DSCNT,TDSCNT	save space at end of routine
	STZ	DSCNT	zero it for the keep
	STZ	DSCNT+2
	SHORT M,I
	LDA	#0	flag the end of the current code
	JSR	SKEEP	 segment
	JSR	SKBWR	write out remaining bytes
	LONG	I,M
	CLC		update MARK
	LDA	BCNT
	AND	#$00FF
	ADC	MARK
	STA	MARK
	BCC	KN1
	INC	MARK+2
KN1	CLC		update the object module length
	LDA	BCNT
	AND	#$00FF
	ADC	OLEN
	STA	OLEN
	BCC	KN2
	INC	OLEN+2
KN2	PH4	R0	save R0
	PH4	KEEPHANDLE	lock the buffer
	_HLOCK
	LDY	#2	get the pointer to the start of the seg
	CLC
	LDA	HEAD
	ADC	[KEEPHANDLE]
	STA	R0
	LDA	HEAD+2
	ADC	[KEEPHANDLE],Y
	STA	R2
	LDA	OLEN+2	write the number of bytes, the number
	STA	[R0],Y	 of zero bytes at the end of the module,
	LDA	OLEN	 and the length of the module into the
	STA	[R0]	 header
	LDY	#4
	LDA	TDSCNT
	STA	[R0],Y
	INY
	INY
	LDA	TDSCNT+2
	STA	[R0],Y
	SEC
	LDA	STR
	SBC	#$1000
	INY
	INY
	STA	[R0],Y
	LDA	STR+2
	SBC	#0
	INY
	INY
	STA	[R0],Y
	LDA	KINDUSED	if a KIND was specified, write it, too
	AND	#$00FF
	BEQ	KN3
	LDA	KINDVAL
	LDY	#20
	STA	[R0],Y
KN3	PH4	KEEPHANDLE	unlock the handle
	_HUNLOCK
	PL4	R0
	SHORT I,M
	STZ	BCNT	clear the buffer counter
	BRL	SREST	restore registers
	AGO	.SKENDB
.SKENDA
	RTS
.SKENDB

TDSCNT	DS	4	temp storage for DSCNT
	END

****************************************************************
*
*  SKEXP - Keep an Expression
*
*  INPUTS:
*	A - number of bytes for the result
*	X - op code for the expression:
*		$EB - no special treatment
*		$EC - truncated bits must be 0
*		$ED - trucated bits must match *
*		$F3 - references to dynamic segments are allowed
*	WORK - postfix expression to enter
*	FCODECHK - if true, disable bank checking by mapping $ED
*		expressions to $EB expressions for code bank instructions
*	FDATACHK - if true, disable bank checking by mapping $ED
*		expressions to $EB expressions for data bank instructions
*	FDYNCHK - if true, allow all expressions to reference
*		dynamic segments by mapping $EB and $ED expressions
*		to $F3 expressions
*
*  NOTES:
*	1) Entry at SKEXP2 is for SKREL, which has done its
*		own specialized initialization
*
****************************************************************
*
SKEXP	START
	USING EVALDT
	USING COMMON
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SKEXP
;
;  Initialization.
;
	JSR	SAVER	save registers
;
;  Check for disabled bank checks
;
	PHA
	LDY	BANKTYPE
	BEQ	BC1
	LDA	FDATACHK-1,Y
	BNE	BC1
	CPX	#$ED
	BNE	BC1
	LDX	#$EB
BC1	PLA
;
;  Check for allowed references to dynamic segments
;
	LDY	FDYNCHK
	BNE	DC2
	CPX	#$EB
	BEQ	DC1
	CPX	#$ED
	BNE	DC2
DC1	LDX	#$F3
DC2	ANOP
;
;  Save the constant result of a definite valued expression.
;
	LDY	OPFIXED	branch if not a fixed value
	BEQ	KP0C
	LDY	BSHIFT	do immediate shifts
	BEQ	SH2
SH1	LSR	OPV+3
	ROR	OPV+2
	ROR	OPV+1
	ROR	OPV
	INC	BSHIFT
	BNE	SH1
SH2	CPX	#$ED	branch if matching to *
	BEQ	KP0C
	STA	NUM	save # of bytes
	CPX	#$EC	check zero page variables
	BNE	KP0A
	TAY
	LDA	#0
KP0	ORA	OPV,Y
	INY
	CPY	#4
	BLT	KP0
	TAY
	BEQ	KP0A
	ERROR #29,R	length exceeded
KP0A	STZ	NUM2
KP0B	LDX	NUM2
	LDA	OPV,X
	LDX	KCNT
	STA	CBYTES,X
	INC	KCNT
	CPX	#$DE
	BLT	KP0D
	JSR	SPURG
KP0D	INC	NUM2
	DBNE	NUM,KP0B
	BRL	SREST

NUM	DS	1
NUM2	DS	1
;
;  Keep an expression.
;
KP0C	PHA		save # of bytes
	PHX		output the op code
	JSR	SPURG
	PLA
	JSR	SKEEP
	PLA		output the # of bytes
	JSR	SKEEP

SKEXP2	ENTRY
	STZ	TOP2	initialize the expression pointer
KP1	JSR	SGETT	remove a token from the stack
	LDA	TOK_TYPE	split on type
	JMI	KP12
	JEQ	KP11

	LDA	TOK_ISP	operand
	BNE	KP2	  0 - local label
	LDA	#$87
	BNE	KP4
KP2	CMP	#2	  1 - label name
	BGE	KP3
	LDA	LLBT
	CMP	#'L'
	BNE	KP2A
	LDA	#$82
	BNE	KP8
KP2A	LDA	#$83
	BNE	KP8
KP3	BNE	KP5	  2 - constant
	LDA	#$81
KP4	JSR	SKEEP
	LDY	#4
	LDX	#0
KP4A	LDA	TOK_OP,X
	JSR	SKEEP
	INX
	DBNE	Y,KP4A
	BRA	KP1
KP5	CMP	#4	  3 - length attribute
	BGE	KP6
	LDA	#$84
	BRA	KP8
KP6	BNE	KP7	  4 - type attribute
	LDA	#$85
	BRA	KP8
KP7	LDA	#$86	  5 - count attribute
KP8	JSR	SKEEP
	LONG	I,M	save the label name
	MOVE4 R0,SAVE
	MOVE4 TOK_OP,R0
	SHORT I,M
	LDA	[R0]
	STA	LNAME
	TAY
KP9	LDA	[R0],Y
	STA	LNAME,Y
	DBNE	Y,KP9
	JSR	SKNME
	MOVE4 SAVE,R0
	BRL	KP1

KP11	LDX	TOK_OP	operation
	LDA	OPCODE,X
	JSR	SKEEP
	BRL	KP1

KP12	ANOP		end of expression -
	LDA	DPPROMOTE	  if a direct page promotion occurred	
	BEQ	KP12A	    add in the dp value
	LDA	#$81
	JSR	SKEEP
	LDA	DPVALUE
	JSR	SKEEP
	LDA	DPVALUE+1
	JSR	SKEEP
	LDA	#0
	JSR	SKEEP
	JSR	SKEEP
	INC	A
	JSR	SKEEP
KP12A	LDA	BSHIFT	  if a bit shift is needed, do it
	BEQ	KP13
	LDA	#$81
	JSR	SKEEP
	LDA	BSHIFT
	JSR	SKEEP
	LDA	#$FF
	JSR	SKEEP
	JSR	SKEEP
	JSR	SKEEP
	LDA	#7
	JSR	SKEEP
KP13	LDA	#0	  save end of expression marker
	JSR	SKEEP
	BRL	SREST

OPCODE	DC	I1'01,02,03,04,07,07,06,11'
	DC	I1'08,09,10,12,13,14,15,16'
	DC	I1'17'
SAVE	DS	4
	END

****************************************************************
*
*  SKHRD - Keep a Hard Reference
*
*  INPUTS:
*	LNAME - name of label
*
****************************************************************
*
SKHRD	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKHRD

	JSR	SAVER	save the registers
	JSR	SPURG
	LDA	#$E5	output the hard reference
	JSR	SKEEP
	JSR	SKNME
	BRL	SREST	restore registers
	END

****************************************************************
*
*  SKINT - Keep Initialization
*
*  INPUTS:
*	KNAME - keep file name
*	KFLAG - indicates current status of keep:
*		1 - open ROOT file
*		2 - open .A file
*		3 - open a partial file
*
*  OUTPUTS:
*	CKNAME - current keep file name
*	KFLAG - updated
*	KEEP_HANDLE - handle for file buffer area
*
****************************************************************
*
SKINT	START
	USING COMMON
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SKINT

	AIF	DEBUGK,.SKINTA
	LDA	KFLAG	split based on keep type
	CMP	#3
	BEQ	KN1
	JSR	RootName	open a root file
	LM	KFLAG,#2
	BRL	KN1A
KN1	JSR	KeepName	open a .x file

KN1A	LDA	PLUS_F+2	if the +m flag is not set then
	AND	#^SET_M
	BNE	KN3
	JSR	DeleteFile	  delete any existing file
	BCS	KN5

KN3	LONG	I,M
	PHA		get space for an initial file buffer
	PHA
	PH4	#KEEPSIZE
	PH2	USER_ID
	PH2	#$0000
	PH4	#0
	_NEWHANDLE
	PL4	KEEPHANDLE
	JCS	TERR1	(out of memory)
	STZ	MARK	set the length of the buffer to 0
	STZ	MARK+2
	SHORT I,M
	RTS

KN5	SHORT I,M
	BRL	TERR3	Keep file could not be opened
	AGO	.SKINTB
.SKINTA
	RTS
.SKINTB
	END

****************************************************************
*
*  SKLDF - Keep a Label Definition
*
*  INPUTS:
*	LLNAME - name of label to keep
*	OP - op code; tells what kind of a label it is
*	LLBT - label type attribute
*	LLBL - label length attribute
*
****************************************************************
*
SKLDF	START
	USING COMMON
	USING OPCODE
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SKLDF

	JSR	SAVER	save registers
	LDA	ENDF	skip if not in segment
	JNE	KL8
	LDA	KEEPHANDLE	exit if no keep file
	ORA	KEEPHANDLE+2
	JEQ	KL8
KL0A	LDA	LLNAME	exit if no label on line
	JEQ	KL8
	DEC	A
	BNE	KL0B
	LDA	LLNAME+1
	CMP	#' '
	JEQ	KL8
KL0B	LDA	OPF	don't save local labels if in a code
	AND	#GBL	 segment
	BNE	KL0
	LDA	DATAF
	AND	#$01
	JEQ	KL8
KL0	LDA	OP
	CMP	#ISTART
	JEQ	KL8
	CMP	#IDATA
	JEQ	KL8
	CMP	#IPRIVATE
	JEQ	KL8
	CMP	#IPRIVDATA
	JEQ	KL8
	JSR	SPURG
	LDX	LLNAME	recover length attribute
	STX	LNAME
LB1	LDA	LLNAME,X
	STA	LNAME,X
	DEX
	BNE	LB1
	JSR	SLCHK
	LDA	OP	select the op code
	CMP	#IEQU
	BNE	KL1
	LDA	#$F0
	BNE	KL4
KL1	CMP	#IENTRY
	BNE	KL1A
	LDA	OBJFLAG
	BEQ	KL2
	BNE	KL1B
KL1A	CMP	#IGEQU
	BNE	KL2
KL1B	LDA	#$E7
	BNE	KL4
KL2	LDA	OPF
	AND	#GBL
	BEQ	KL3
	LDA	#$E6
	BNE	KL4
KL3	LDA	#$EF
KL4	PHA
	JSR	SKEEP	save the op code
	JSR	SKNME	save the label
	LDA	LBL	save the attributes
	JSR	SKEEP
	LDA	LBL+1
	JSR	SKEEP
	LDA	LLBT
	JSR	SKEEP
	PLA		if EQU, GEQU, LOCAL, or GLOBAL then
	CMP	#$E6	 save the private byte
	BEQ	KL4A
	CMP	#$E7
	BEQ	KL4A
	CMP	#$EF
	BEQ	KL4A
	CMP	#$F0
	BNE	KL4B
KL4A	LDA	PRIVATE
	JSR	SKEEP
KL4B	LDA	OP	if an EQU or GEQU, save the value
	CMP	#IEQU
	BNE	KL5A
	LDA	DATAF	(don't save EQU if in a code segment)
	AND	#$01
	BNE	KL6
KL5A	CMP	#IGEQU
	BEQ	KL6
	CMP	#IENTRY
	BNE	KL8
	LDA	OBJFLAG
	BEQ	KL8
KL6	LDA	LLBFLAG	keep the expression if the equate is
	AND	#LBFIXED	 not a constant
	JEQ	SKEXP2
	LDA	#$81	save the constant operand code
	JSR	SKEEP
	LDX	#0	save the value
	LDY	#4
KL7	LDA	LLBV,X
	JSR	SKEEP
	INX
	DBNE	Y,KL7
	LDA	#0	mark end of expression
	JSR	SKEEP
KL8	BRL	SREST	restore registers
	END

****************************************************************
*
*  SKLNT - Load Module Initialization
*
*  INPUTS:
*	X,A - type of segment
*		0 - subroutine
*		1 - data area
*	LLNAME - name of the code segment
*	SEGNAME - name of the load segment
*
****************************************************************
*
SKLNT	START
	USING KEEPCOM
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKLNT

	JSR	SAVER	save regs
	STA	TYPE
	STX	TYPE+1
	AND	#1	if segment is a data segment then
	EOR	#1	  BSIZE = 0 else BSIZE = $10000
	STA	BSIZE+2
	LONG	I,M
	MOVE4 ORGVAL,ORG	set ORG
	MOVE4 ALIGNVAL,ALIGN	set alignment
	MOVE4 MARK,HEAD	record the start position of the seg
	STZ	OLEN	set the length of the seg to 0
	STZ	OLEN+2
	SHORT I,M
	STZ	KCNT
	STZ	BCNT
	LDY	#9	set load segment name
KL1	LDA	SEGNAME,Y
	LDX	FOBJCASE	observe case sensitivity flag
	BNE	KL2
	JSR	SHIFT
KL2	STA	LDNAME,Y
	DBPL	Y,KL1
	LONG	I,M
	LDA	LLNAME	set disp to data
	AND	#$00FF
	TAY
	LDA	LLNAME,Y
	AND	#$FF
	CMP	#' '
	BNE	KL3
	DEY
KL3	TYA
	CLC
	ADC	#HEADEND-HEADR+1
	STA	DISP
	STZ	DSCNT	write the header to the keep file
	STZ	DSCNT+2
	SHORT I,M
	LDX	#0
	LDY	#HEADEND-HEADR
KL4	LDA	HEADR,X
	JSR	SKEEP
	INX
	DBNE	Y,KL4
	LDX	LLNAME	save segment name
	STX	LNAME
KL5	LDA	LLNAME,X
	STA	LNAME,X
	DEX
	BNE	KL5
	JSR	SKNME
	BRL	SREST	restore regs and return

HEADR	DC	I4'0'	number of bytes in routine
	DC	I4'0'	length of reserved space at end
	DC	I4'0'	length of the routine
	DC	I1'0'	type of segment
	DC	I1'0'	length of labels
	DC	I1'4'	length of numbers
	DC	I1'2'	earliest version of linker
BSIZE	DC	I4'65536'	size of bank
TYPE	DS	2	object file kind
	DC	I'0'	unused
ORG	DC	I4'0'	ORG for the subroutine
ALIGN	DC	I4'0'	alignment for the subroutine
	DC	I1'0'	0 indicates least sig byte first
	DC	I1'0'	language card bank
	DC	I'0'	segment number
	DC	I4'0'	disp to segment entry point
	DC	I'HEADEND-HEADR-10'	disp to name fields
DISP	DS	2	disp to start of data
	DS	4	temp org field (unused; unneeded)
LDNAME	DS	10	load segment name
HEADEND	ANOP
	END

****************************************************************
*
*  SKMEM - Keep a MEM Directive
*
*  INPUTS:
*	R8-R11 - first MEM address
*	OPV - second MEM address
*
****************************************************************
*
SKMEM	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKMEM

	JSR	SAVER	save registers
	JSR	SPURG	save constant bytes
	LDA	#$E8	output the MEM op code
	JSR	SKEEP
	LDX	#0	output the first MEM value
	LDY	#4
KM1	LDA	R8,X
	JSR	SKEEP
	INX
	DBNE	Y,KM1
	LDX	#0	output the second MEM value
	LDY	#4
KM2	LDA	OPV,X
	JSR	SKEEP
	INX
	DBNE	Y,KM2
	BRL	SREST	restore registers
	END

****************************************************************
*
*  SKNME - Keep a name
*
*  Inputs:
*	LNAME - name to keep
*
****************************************************************
*
SKNME	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKNME

	LDX	#1	X is disp into LNAME
	LDY	LNAME	save length field
	PHY
	LDA	LNAME,Y	if label ends in blank, decrease
	CMP	#' '	 length by one
	BNE	LB1
	DEY
	DEC	LNAME
LB1	LDA	LNAME	save the length
	JSR	SKEEP
	LDA	FOBJCASE	select save method
	BEQ	LB3
LB2	LDA	LNAME,X	save the bytes (case sensitive)
	JSR	SKEEP
	INX
	DBNE	Y,LB2
	BRA	LB5
LB3	LDA	LNAME,X	save the bytes (case insensitive)
	PHX
	TAX
	LDA	UPPERCASE,X
	PLX
	JSR	SKEEP
	INX
	DBNE	Y,LB3
LB5	PLA		restore length field
	STA	LNAME
	RTS
	END

****************************************************************
*
*  SKORG - Keep an ORG Directive
*
*  INPUTS:
*	OPV - Address to ORG to
*
****************************************************************
*
SKORG	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKORG

	JSR	SAVER	save registers
	JSR	SPURG	save constant bytes
	LDA	#$E1	output the ORG op code
	JSR	SKEEP
	LDX	#0	output the ORG value
	LDY	#4
KR1	LDA	OPV,X
	JSR	SKEEP
	INX
	DBNE	Y,KR1
	BRL	SREST	restore registers
	END

****************************************************************
*
*  SKPDS - Keep a DS Directive
*
*  INPUTS:
*	LENGTH - number of bytes to declare
*
****************************************************************
*
SKPDS	START
	USING KEEPCOM
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SKPDS

	JSR	SAVER	save registers
	JSR	SPURG	save constant bytes
	ADD4	DSCNT,LENGTH	update # bytes at end
	BRL	SREST	restore registers
	END

****************************************************************
*
*  SKREL - Keep a Relative Branch
*
*  INPUTS:
*	A - number of bytes in the result
*	WORK - postfix expression to keep
*
****************************************************************
*
SKREL	START
	LONGA OFF
	LONGI OFF
	DEBUG SKREL

	JSR	SAVER	save registers
	PHA		save the length
	JSR	SPURG	write out current constants
	LDA	#$EE	write out the op code
	JSR	SKEEP
	PLA		write out the length
	JSR	SKEEP
	JSR	SKEEP	write out the disp to the location
	LDA	#0	 to keep the code for
	JSR	SKEEP
	JSR	SKEEP
	JSR	SKEEP
	BRL	SKEXP2	SKEXP writes out the expression
	END

****************************************************************
*
*  SPURG - Purge CBYTES
*
*  Writes any constant bytes to the obj module.
*
*  INPUTS:
*	KCNT - number of bytes to save
*	CBYTES - bytes to save
*
*  OUTPUTS:
*	KCNT - 0
*
****************************************************************
*
SPURG	START
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SPURG

	LDA	KCNT	quit if there are no bytes in CBYTES
	BEQ	PR2
	JSR	SKEEP
	TAY		save the bytes to disk
	LDX	#0
PR1	LDA	CBYTES,X
	JSR	SKEEP
	INX
	DBNE	Y,PR1
	STY	KCNT	KCNT = 0
PR2	RTS
	END

****************************************************************
*
*  SREST - Restore Registers
*
*  INPUTS:
*	KA,KX,KY - register contenets
*
*  OUTPUTS:
*	A,X,Y - restored
*
****************************************************************
*
SREST	START
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SREST

	LDA	KA
	LDX	KX
	LDY	KY
	RTS
	END

	APPEND FORML.ASM
