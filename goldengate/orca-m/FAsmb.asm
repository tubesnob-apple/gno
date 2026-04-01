****************************************************************
*
*  FASMB - Top Level Control
*
*  OUTPUTS:
*	MERR - largest error level found
*
****************************************************************
*
FASMB	START
	USING COMMON
	USING OPCODE
	USING MACDAT
	USING KEEPCOM
	LONGA ON
	LONGI ON
STROBE	EQU	$C010
KEYBOARD EQU	$C000

;..............................................................;
;
;  Initialize for assembly
;
;..............................................................;
;
	PHK		set data bank to local value
	PLB
	PHA
	LDA	REST_FL	is this a restart
	BEQ	LB0
	LDX	CHECKSUM
	JSR	SCPCS	compute check sum
	CPX	CHECKSUM	make sure it is ok
	BEQ	AS0
	PLA
	STX	CHECKSUM
	ERROUT
	PRINT 'Failed checksum: Could not restart'
	BRA	LB1

LB0	JSR	VERSION
	BCC	AS0
	PLA
	ERROUT
	PRINT 'Requires shell version 2.0 or higher'
LB1	PRINT
	STDOUT
	jsr	ErrorLInfo1	Set language info for an error exit
	LDA	#$FFFF
	RTL
;
;  Handle restartability
;
AS0	JSR	SRSTR
	PLA
	ORA	#$0100	use a level so we can restart
	STA	USER_ID	save user ID
	SHORT I,M
	DEBUG FASMB
	JSR	SINIT	initialize variables
;..............................................................;
;
;  Pass 1
;
;..............................................................;
;
AS1	JSR	AssembleCheck	check to see if assembly is required
	BCC	AS5
	JSR	SPREP	do the pre-pass
	BCC	AS5
	JSR	SPAS1	initialize for pass 1

AS2	JSR	SINLN	check
	BCC	AS3
	JSR	FPAS1	do pass 1 on the line
	JSR	SLOOP	next line
	BNE	AS2
;..............................................................;
;
;  Pass 2
;
;..............................................................;
;
AS3	ANOP
	JSR	SPAS2	initialize for pass 2

AS4	JSR	SINLN	check for end of file
	BCC	AS5
	JSR	FPAS2	do pass 2 on the line
	JSR	SLOOP	next line
	BNE	AS4
;
;  Loop to pass 1.
;
	DEC	PASS	PASS = 1
	JSR	SINLN	next line
	BCS	AS1	branch if line found
;..............................................................;
;
;  End of assembly processing.
;
;..............................................................;
;
AS5	ANOP
	JSR	SFINI	fini
	JSR	Purge	purge the last source file
	JSR	SMDRP	purge any macro files
!			do the best job possible of disposing
	DISPOSEALL	 of memory used
	jsr	SetLInfo	return information to the shell
	jsr	StopSpin	stop the spinner
	LONG	I,M
	JSR	SCPCS	compute checksum
	LDA	#0
	JMP	QUIT

	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SCESC - Check for Escape; Exit if Found
*
****************************************************************
*
SCESC	START
	USING COMMON
KEYBOARD EQU	$C000
STROBE	EQU	$C010
FLAGS	EQU	$C025
	LONGA OFF
	LONGI OFF

	PHP
	SHORT I,M
	PRINT		write the carriage return
	jsr	Stop	see if we need to quit
	JCS	TERR11
	LDA	>KEYBOARD	no - see if we need to pause
	BPL	LB3
	STA	>STROBE	yes - clear strobe
	LONG	I,M                      write the hourglass
	OSCONSOLEOUT RC27
	OSCONSOLEOUT RC15
	OSCONSOLEOUT RC67
	OSCONSOLEOUT RC24
	OSCONSOLEOUT RC14
	OSCONSOLEOUT RC8
	SHORT	I,M
LB1	LDA	>KEYBOARD	wait for keypress
	BPL	LB1
	PHA		erase the hourglass
	LONG	I,M
	OSCONSOLEOUT RC32
	OSCONSOLEOUT RC8
	SHORT	I,M
	PLA      
	CMP	#'.'+$80	quit if is an open apple .
	BNE	LB2
	LDA	>FLAGS
	JMI	TERR11
LB2	STA	>STROBE	clear strobe
LB3	PLP
	RTS

RC8	DC	I'1,8'	parameter blocks for OSWriteConsole calls
RC14	DC	I'1,14'
RC15	DC	I'1,15'
RC24	DC	I'1,24'
RC27	DC	I'1,27'
RC32	DC	I'1,32'
RC67	DC	I'1,67'
	END

****************************************************************
*
*  SCHAN - Chain a hash table together
*
*  Inputs:
*	R0 - addr of first entry
*
*  Outputs:
*	R0 - header of table
*
****************************************************************
*
SCHAN	START
	USING COMMON
	LONGA OFF
	LONGI OFF
ARRAYPTR EQU	R0	pointer to hash table (array of ptrs)
NSYM	EQU	WR0	pointer to next symbol in chain
HEAD	EQU	WR4	pointer to head of list
I	EQU	MR0	loop counter
HASHOFI	EQU	MR2	ith entry in hash table

	LONG	I,M
	STZ	NSYM	NSYM := NIL;
	STZ	NSYM+2
	STZ	HEAD	HEAD := NIL;
	STZ	HEAD+2
	LDA	#HASHSIZE-1	FOR I := HASHSIZE-1 DOWNTO 0 DO BEGIN
	STA	I
LB1	LDA	I	  HASHOFI := ARRAYPTR^[I];
	ASL	A
	ASL	A
	TAY
	LDA	[ARRAYPTR],Y
	STA	HASHOFI
	INY
	INY
	LDA	[ARRAYPTR],Y
	STA	HASHOFI+2
	LDA	HEAD	  IF HEAD = 0 THEN
	ORA	HEAD+2
	BNE	LB2
	LDA	HASHOFI	    HEAD := HASHOFI;
	STA	HEAD
	LDA	HASHOFI+2
	STA	HEAD+2
LB2	LDA	NSYM	  IF NSYM <> NIL THEN BEGIN
	ORA	NSYM+2
	BEQ	LB6
LB3	LDY	#LNEXT-LBPTR	    WHILE NSYM^.LNEXT <> NIL DO
	LDA	[NSYM],Y
	TAX
	INY
	INY
	LDA	[NSYM],Y
	BNE	LB4
	CPX	#0
	BEQ	LB5
LB4	STA	NSYM+2	      NSYM := NSYM^.LNEXT;
	STX	NSYM
	BRA	LB3
LB5	LDA	HASHOFI+2	    NSYM^.NEXT := HASHOFI;
	STA	[NSYM],Y
	DEY
	DEY
	LDA	HASHOFI
	STA	[NSYM],Y
	BRA	LB7	    END
LB6	LDA	HASHOFI	  ELSE NSYM := HASHOFI;
	STA	NSYM
	LDA	HASHOFI+2
	STA	NSYM+2
LB7	DEC	I	  END;
	BPL	LB1
	LDA	HEAD	R0 := HEAD;
	STA	R0
	LDA	HEAD+2
	STA	R2
	SHORT I,M
	RTS
	END

****************************************************************
*
*  SCOUT - Output a Character
*
*  INPUTS:
*	A - character to write
*	STOUT - standard out?
*
****************************************************************
*
SCOUT	START
	USING COMMON

	PHP
	LONG	I,M
	PHX
	PHY
	PHA
	PHA
	LDA	STOUT
	BEQ	LB1
	_WRITECHAR
	BRA	LB2
LB1	_ERRWRITECHAR
LB2	PLA
	PLY
	PLX
	PLP
	RTS

	LONGI OFF
	LONGA OFF
	END

****************************************************************
*
*  SCPCS - Compute checksum
*
*  Inputs:
*	ASM41 - start of program
*
*  Outputs:
*	CHECKSUM - checksum value
*
****************************************************************
*
SCPCS	START
	USING COMMON
	DEBUG SCPCS
	LONGA ON
	LONGI ON

LEN	EQU	ENDPROG-ASM41-2

	STZ	CHECKSUM
	STZ	REST_FL
	LDY	#LEN
	TYA
	LSR	A
	BCC	LB1
	DEY
	LDA	ASM41+LEN-1
	AND	#$00FF
	BRA	LB2
LB1	LDA	#0
LB2	EOR	ASM41,Y
	DEY
	DEY
	BNE	LB2
	EOR	ASM41
	STA	CHECKSUM
	LDY	#1
	STY	REST_FL
	RTS

REST_FL	ENTRY		restart flasg
	DS	2
CHECKSUM ENTRY		check sum
	DS	2
	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SCVDC - Converts a Binary Integer to a String
*
*  INPUTS:
*	M1L - binary number to convert
*
*  OUTPUTS:
*	STRING - ASCII character string
*
****************************************************************
*
SCVDC	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SCVDC

	LDX	#3	if # is maxint then
MX1	LDA	M1L,X
	CMP	BMAXINT,X
	BNE	CV0
	DBPL	X,MX1
	MOVE	MAXINT,STRING,#10	  set string
	RTS

CV0	LM	LOOP,#10	set the loop counters
	LM	CNT,#1
CV1	LDA	CNT	set the denominator
	ASL	A
	ASL	A
	TAY
	LDX	#3
CV2	LDA	DEN-1,Y
	STA	M3L,X
	DEY
	DBPL	X,CV2
	JSR	SDIV4	peel off the high digit by dividing
	LDA	M1L
	ORA	#'0'
	LDX	CNT
	STA	STRING-1,X
	MOVE4 M1L+4,M1L	move in the remainder
	INC	CNT
	DBNE	LOOP,CV1
	RTS

DEN	DC	I4'1000000000'
	DC	I4'100000000'
	DC	I4'10000000'
	DC	I4'1000000'
	DC	I4'100000'
	DC	I4'10000'
	DC	I4'1000'
	DC	I4'100'
	DC	I4'10'
	DC	I4'1'
CNT	DS	1	index into integer tables
LOOP	DS	1	loop counter
MAXINT	DC	C'2147483648'
BMAXINT	DC	I4'$80000000'
	END

****************************************************************
*
*  SDIV4 - Four Byte Signed Integer Divide
*
*  INPUTS:
*	M1L - denominator
*	M3L - numerator
*
*  OUTPUTS:
*	M1L - result
*
*  NOTES:
*	1) Uses SSIG4.
*
****************************************************************
*
SDIV4	START
	LONGA OFF
	LONGI OFF
	DEBUG SDIV4
;
;  Initialize
;
	LONG	M
	LDA	M3L	check for division by zero
	ORA	M3L+2
	BNE	DV1
	SEP	#$60	division by zero
	RTS

DV1	JSR	SSIG4	convert to positive numbers
;
;  32 bit divide
;
	LDY	#32	32 bits to go
DV3	ASL	M1L	roll up the next number
	ROL	M1L+2
	ROL	M1L+4
	ROL	M1L+6
	SEC		subtract for this digit
	LDA	M1L+4
	SBC	M3L
	STA	FR1
	LDA	M1L+6
	SBC	M3L+2
	STA	FR1+2
	BCC	DV4	branch if minus
	LDA	FR1	save the result of the subtraction
	STA	M1L+4
	LDA	FR1+2
	STA	M1L+6
	INC	M1L	turn the bit on
DV4	DBNE	Y,DV3	next bit
;
;  Set the sign.
;
	LDA	SIGN	branch if positive
	AND	#$FF
	BEQ	DV5
	SEC		negate the result
	LDA	#0
	SBC	M1L
	STA	M1L
	LDA	#0
	SBC	M1L+2
	STA	M1L+2
DV5	CLV
	SHORT M
	RTS
	END

****************************************************************
*
*  SFINI - Termination Processing for FASMB
*
****************************************************************
*
SFINI	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SFINI
;
;  Close the keep file.
;
	JSR	SaveFile
;
;  Shut down SANE
;
	LONG	I,M
	_SANEShutDown
	SHORT I,M
;
;  Write the global symbol table.
;
	LDX	SYM	skip if symbol table printing is off
	BEQ	FN1
	MOVE	MSG3,SNAME,#6	set the table name
	SEC		print the table
	JSR	STABL
;
;  Write out the error messages.
;
FN1	LDA	NERR	skip if there were no errors
	ORA	NERR+1
	BEQ	FN2
	PRINT
	PRINT	       
	PRINT
	LONG	M	print the number of errors
	LDA	NERR
	STA	M1L
	SHORT M
	JSR	SPNUM
	PRINT ' errors found'
	LDA	MERRF	print the max error level
	STA	M1L
	STZ	M1L+1
	JSR	SPNUM
	PRINT ' was highest error level'
;
;  Print assembly statistics.
;
FN2	LDA	PROGRESS	skip if -p used
	BEQ	FN3
	PRINT		skip a line
	MOVE4 LC,M1L	print the number of source lines
	JSR	SPNUM4
	PRINT ' source lines'
	MOVE4 MCNT,M1L	print the number of macro expansions
	JSR	SPNUM4
	PRINT ' macros expanded'
	MOVE4 GLC,M1L	print the number of lines generated
	JSR	SPNUM4
	PRINT ' lines generated'
	LDA	REDIRECT
	BEQ	FN3
	HOME
FN3	STA	>$C010	clear keyboard strobe
	RTS

MSG3	DC	C'Global'	global symbol table title
	END

****************************************************************
*
*  SHEAD - Write the Header
*
****************************************************************
*
SHEAD	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SHEAD

	LDA	PROGRESS
	BEQ	TM3
	PRINT 'ORCA/M Asm65816 2.1.0'	write the name of the assembler
  	PRINT
TM3	RTS
	END

****************************************************************
*
*  SINIT - Initialize all Variables
*
****************************************************************
*
SINIT	START
	USING COMMON
	USING KEEPCOM
	LONGA OFF
	LONGI OFF
	DEBUG SINIT
;
;  Do OS initialization
;
	JSR	FileInit1	initialize file module scalars
	JSR	PageLength	find out how long a page is
	JSR	DetectRedirection	detect output redirection
;
;  Do chip selection.
;
	CURSOR_OFF	turn off the silly cursor
	LDA	CHIP
	PHA
	LDA	#0	set the chip flags based on CHIP
	LSR	CHIP
	ROL	A
	STA	F65C02
	LSR	A
	LSR	CHIP
	ROL	A
	STA	F65816
	PLA
	STA	CHIP
;
;  Set up local and global symbol tables
;
	LONG	I,M	reserve global table area
	NEW	GHAND,#GSIZE
	JCS	ERR
	LOCK	GHAND,GSTART	lock it
	JCS	ERR
	CLC		set up table parameters
	LDA	GSTART
	STA	GSP
	ADC	#GSIZE
	STA	GEND
	LDA	GSTART+2
	STA	GSP+2
	ADC	#^GSIZE
	STA	GEND+2
	NEW	LHAND,#LSIZE	reserve local table area
	JCS	ERR
	LOCK	LHAND,LSTART	lock it
	JCS	ERR
	ADD4	LSTART,#4,LSP	set up table parameters
	ADD4	LSTART,#LSIZE,LEND
	MOVE4 LSTART,R0	init forward handle pointer to nil
	LDA	#0
	LDY	#2
	STA	[R0]
	STA	[R0],Y
;
;  Set up AINPUT buffer
;
	NEW	AHAND,#ASIZE
	JCS	ERR
	LOCK	AHAND,ASTART
	JCS	ERR
	ADD4	ASTART,#4,ASP
	ADD4	ASTART,#ASIZE,AEND
	MOVE4 ASTART,R0	init forward handle pointer to nil
	LDA	#0
	LDY	#2
	STA	[R0]
	STA	[R0],Y
;
;  Set up macro table buffer
;
	NEW	THAND,#MSIZE
	JCS	ERR
	LOCK	THAND,MSTART
	JCS	ERR
	ADD4	MSTART,#MSIZE,MEND
	ADD4	MSTART,#4,MSP
	MOVE4 MSTART,R0	init forward handle pointer to nil
	LDA	#0
	LDY	#2
	STA	[R0]
	STA	[R0],Y
;
;  Set up symbolic parameter table buffers
;
	NEW	PHAND,#PSIZE
	JCS	ERR
	LOCK	PHAND,SSTART
	JCS	ERR
	NEW	PHAND+4,#PSIZE
	JCS	ERR
	LOCK	PHAND+4,SSTART+4
	JCS	ERR
	NEW	PHAND+8,#PSIZE
	JCS	ERR
	LOCK	PHAND+8,SSTART+8
	JCS	ERR
	NEW	PHAND+12,#PSIZE
	JCS	ERR
	LOCK	PHAND+12,SSTART+12
	JCS	ERR
	NEW	PHAND+16,#PSIZE
	JCS	ERR
	LOCK	PHAND+16,SSTART+16
	JCS	ERR
	ADD4	SSTART,#4,SSP
	ADD4	SSTART+4,#4,SSP+4
	ADD4	SSTART+8,#4,SSP+8
	ADD4	SSTART+12,#4,SSP+12
	ADD4	SSTART+16,#4,SSP+16
	ADD4	SSTART,#PSIZE,SEND
	ADD4	SSTART+4,#PSIZE,SEND+4
	ADD4	SSTART+8,#PSIZE,SEND+8
	ADD4	SSTART+12,#PSIZE,SEND+12
	ADD4	SSTART+16,#PSIZE,SEND+16
	LDX	#18
SS1	LDA	SSTART,X
	STA	TEMPZP,X
	DEX
	DBPL	X,SS1
	LDY	#2
	LDA	#0
SS2	STA	[TEMPZP],Y
	STA	[TEMPZP+4],Y
	STA	[TEMPZP+8],Y
	STA	[TEMPZP+12],Y
	STA	[TEMPZP+16],Y
	DEY
	DBPL	Y,SS2
	JSR	SETSP
;
;  Allocate hash tables
;
	NEW	LHHAND,#HTABLESIZE	allocate local symbol table hash table
	JCS	ERR
	LOCK	LHHAND,LHASH
	JCS	ERR
	NEW	GHHAND,#HTABLESIZE	allocate global symbol table hash table
	JCS	ERR
	LOCK	GHHAND,GHASH
	JCS	ERR
	NEW	MHHAND,#HTABLESIZE	allocate macro buffer hash table
	JCS	ERR
	LOCK	MHHAND,MHASH
	JCS	ERR
	MOVE4 LHASH,R0	zero hash tables
	MOVE4 GHASH,R4
	MOVE4 MHASH,R8
	LDY	#HTABLESIZE-2
	LDA	#0
IN2B	STA	[R0],Y
	STA	[R4],Y
	STA	[R8],Y
	DEY
	DBPL	Y,IN2B
;
;  Set up predeclared variables.
;
	MOVE4 SSP,CSP	set CSP to start of global
	SHORT I,M	 sym parm table
	LDY	#SCNTEND-SCNT-1	move the value into the table
SV1	LDA	SCNT,Y
	STA	[CSP],Y
	DBPL	Y,SV1
	LONG	I,M
	CLC		turn the disp into a location
	LDA	CSP
	ADC	[CSP]
	STA	[CSP]
	LDY	#2
	LDA	CSP+2
	ADC	[CSP],Y
	STA	[CSP],Y
	MOVE4 SSP,SFIRST
	ADD4	SSP,#SCNTEND-SCNT
;
;  Retrieve and set up inputs from the O/S.
;
	jsr	GetTabs	read the tab line
	jsr	GetLInfo	get the command line information
	jsr	Open	open the input file and read in the
!			 first line
;
;  Initialize the I/O flags
;
	LONG	M
	LDA	PLUS_F+2	set the list ouput flag
	AND	#^SET_L
	BEQ	ST1
	SHORT M
	LDA	#1
	STA	LIST
	LONG	M
	BRA	ST2
ST1	LDA	MINUS_F+2
	AND	#^SET_L
	BEQ	ST2
	SHORT M
	STZ	LIST
	LONG	M

ST2	LONG	M
	LDA	MINUS_F+2	set the progress info flag
	AND	#^SET_P
	BEQ	ST2A
	SHORT M
	LDA	#1
	STZ	PROGRESS
	LONG	M
	BRA	ST2B
ST2A	SHORT M
	LDA	#1
	STA	PROGRESS
	LONG	M

ST2B	LDA	PLUS_F	set the list symbols flag
	AND	#SET_S
	BEQ	ST3
	SHORT M
	LDA	#1
	STA	SYM
	LONG	M
	BRA	ST4
ST3	LDA	MINUS_F
	AND	#SET_S
	BEQ	ST4
	SHORT M
	STZ	SYM
	LONG	M

ST4	LDA	PLUS_F+2	set the return to editor flag
	AND	#^SET_E
	BEQ	ST5
	SHORT M
	LDA	#1
	STA	EDITOR
	LONG	M
	BRA	ST6
ST5	LDA	MINUS_F+2
	AND	#^SET_E
	BEQ	ST6
	SHORT M
	STZ	EDITOR
	LONG	M

ST6	LDA	PLUS_F	set the terminal flag
	AND	#SET_T
	BEQ	ST7
	SHORT M
	LDA	#1
	STA	TERMINAL
	LONG	M
	BRA	ST8
ST7	LDA	MINUS_F
	AND	#SET_T
	BEQ	ST8
	SHORT M
	STZ	TERMINAL
	LONG	M

ST8	LDA	PLUS_F	set the pause on error flag
	AND	#SET_W
	BEQ	ST9
	SHORT M
	LDA	#1
	STA	WAIT
	LONG	M
	BRA	ST10
ST9	LDA	MINUS_F
	AND	#SET_W
	BEQ	ST10
	SHORT M
	STZ	WAIT
;
;  Initialize SANE
;
ST10	LONG	I,M
	CLC
	PHD
	PLA
	ADC	#$0100
	PHA
	_SANESTARTUP
;
;  Set msc variables.
;
	JSR	SHEAD	write the header
	JSR	STIME	format the time string
	STZ	KEEPHANDLE	no keep file yet
	STZ	KEEPHANDLE+2
	SHORT I,M
	JSR	FileInit2	initialize file module variables
	RTS

ERR	SHORT I,M
	BRL	TERR5	memory managment error

SCNT	DC	I4'15'	disp to name
	DC	I4'0'	pointer to next symbol
	DC	C'X'	type attribute
	DC	I1'1'	count attribute
	DC	I1'4'	length attribute
	DC	I4'1'	initial value
	DC	I1'L:SCNTNAME'
SCNTNAME DC	C'SYSCNT '
SCNTEND	ANOP
	END

****************************************************************
*
*  SINLN - Finds the Next Line to Assemble
*
*  INPUTS:
*	AP - pointer to the next line in this file
*	COPY - copy level
*
*  OUTPUTS:
*	AP - points to the new line
*	LINE - contains the new line
*	C - set if a line was found; else clear
*
****************************************************************
*
SINLN	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SINLN
;
;  Check for the end of the file.
;
	LDA	SWITCH	quit if changing languages
	BNE	CF2
	LDA	AP+2	branch if at the end of the file
	CMP	SRCEND+2
	BNE	EF1
	LDA	AP+1
	CMP	SRCEND+1
	BNE	EF1
	LDA	AP
	CMP	SRCEND
EF1	BGE	CF1
	SEC
	RTS
;
;  Check for the end of the assembly.
;
CF1	LONG	M	branch if this file was copied
	LDA	CBUFF
	ORA	CBUFF+2
	SHORT M
	BNE	CP1
CF2	CLC		flag the end of the assembly
	RTS
;
;  Load the file that copied this one.
;
CP1	JSR	LOADLASTFILE
	BRL	SINLN	repeat the EOF check
	END

****************************************************************
*
*  SINTP - Increment the Text Pointer
*
*  INPUTS:
*	AP - points to the current line
*
*  OUTPUTS:
*	AP - points to the new line
*	LINE - contains the text line
*
*  NOTES:
*	Entry at SRLIN copies the line from [AP] to LINE.
*
****************************************************************
*
SINTP	start
	using Common
	longa off
	longi off
	debug SINTP

	lda	ap+2	check for EOF
	cmp	srcend+2
	bne	in0
	lda	ap+1
	cmp	srcend+1
	bne	in0
	lda	ap
	cmp	srcend
in0	jge	in12

	long	I
	ldy	#$FFFF
in1	iny		fetch char
	lda	[ap],Y
	cmp	#RETURN	quit if at EOL
	bne	in1
	long	M
	tya		add line length to ap
	sec
	adc	ap
	sta	ap
	bcc	in2
	inc	ap+2
in2	short I,M

SRLIN	entry
	stz	quote	not processing a string
	stz	symbolics	no symbolic parameters, yet

	lda	ap+2	check for EOF
	cmp	srcend+2
	bne	in3
	lda	ap+1
	cmp	srcend+1
	bne	in3
	lda	ap
	cmp	srcend
in3	jge	in12

	ldy	#0	move the line to LINE
	tyx
in5	lda	[ap],Y
	sta	line,X
	cmp	#RETURN
	beq	in8
	cmp	#TAB	...while expanding tabs
	bne	in5a
	lda	quote	(don't expand tabs in strings)
	beq	tb1
	lda	#TAB
	bra	st3
tb1	lda	#' '
	sta	line,X
	inx
	beq	in6
	lda	tabs,X
	beq	tb1
	dex
	bra	in5b
in5a	cmp	#'&'	...and looking for symbolic parms
	bne	in5b
	inc	symbolics
in5b	cmp	#'"'	...and keeping track of strings
	bne	st1
	cmp	quote
	beq	st2
	lda	quote
	bne	st3
	lda	#'"'
	sta	quote
	bra	st3

st1	cmp	#''''	...and keeping track of strings
	bne	st3
	cmp	quote
	beq	st2
	lda	quote
	bne	st3
	lda	#''''
	sta	quote
	bra	st3

st2	stz	quote	(end of string detected)

st3	iny
	inx
	bne	in5
in6	inc	ap+1	line exceeds 256 characters - skip to
in7	lda	[ap],Y	 RETURN
	cmp	#RETURN
	beq	in8
	iny
	bne	in7
	bra	in6
	lda	#RETURN	make sure our line ends with RETURN
	sta	line+255
	ldx	#255	set Y to disp to RETURN
in8	txa		check for trailing white space
	beq	in11
	lda	line-1,X
	cmp	#' '
	bne	in11
in9	dex		there is some trailing white space -
	beq	in10	 remove it
	lda	line-1,X
	cmp	#' '
	beq	in9
in10	lda	#RETURN
	sta	line,X
in11	rts

in12	lm	line,#RETURN	fake a line at the end of the file
	rts

quote	ds	1	quote character
	end

****************************************************************
*
*  SKEYN - Read a Character
*
*  OUTPUS:
*	A - character read
*
****************************************************************
*
SKEYN	START

	PHP
	LONG	I,M
	PHX
	PHY
	LDA	#0
	PHA
	INC	A
	PHA
	_READCHAR
	PLA
	PLY
	PLX
	PLP
	RTS

	LONGI OFF
	LONGA OFF
	END

****************************************************************
*
*  SLERR - Set Error Number and Level
*
*  INPUTS:
*	X - error number
*
*  OUTPUTS:
*	ERR - error number
*	LERR - maximum error level found so far
*
****************************************************************
*
SLERR4	START
	USING COMMON
	LONGA OFF
	LONGI OFF

	LDX	#4	high use entry points
	BNE	LR
SLERR6	ENTRY
	LDX	#6
	BNE	LR
SLERR7	ENTRY
	LDX	#7
	BNE	LR
SLERR9	ENTRY
	LDX	#9
	BNE	LR
SLERR11	ENTRY
	LDX	#11
	BNE	LR
SLERR13	ENTRY
	LDX	#13
	BNE	LR
SLERR24	ENTRY
	LDX	#24
	BNE	LR
SLERR29	ENTRY
	LDX	#29
	BNE	LR
SLERR30	ENTRY
	LDX	#30
	BNE	LR
SLERR31	ENTRY
	LDX	#31
	BNE	LR
SLERR35	ENTRY
	LDX	#35
	BNE	LR

SLERR	ENTRY
LR	PHP
	SHORT I,M
	LM	TLERR,LERR
	LM	TERR,ERR
	BNE	LR0
	STX	ERR
LR0	LDA	LERRT-1,X
	STA	LERR
	PLP
	RTS

SLERR2	ENTRY
	PHP
	SHORT I,M
	LM	ERR,TERR
	LM	LERR,TLERR
	PLP
	RTS

TERR	DS	1
TLERR	DS	1
LERRT	DC	I1'16,08,04,16,02,16,16,02'
	DC	I1'08,02,08,08,16,02,02,16'
	DC	I1'02,04,04,04,16,08,16,04'
	DC	I1'08,04,02,08,04,04,04,16'
	DC	I1'08,16,08,08'
	END

****************************************************************
*
*  SLOOP - Loop Control for FASMB
*
*  Check the loop conditions common to both passes.
*
****************************************************************
*
SLOOP	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SLOOP

	LDA	ERR	next line
	BNE	LP1
	LDX	OP
	CPX	#ICOPY	check for COPY or APPEND
	BEQ	LP2
	CPX	#IAPPEND
	BEQ	LP2
LP1	JSR	SUPST	update the location counter
	JSR	SINTP	read the next line
	LDX	OP	check for END
LP2	CPX	#IEND
	RTS
	END

****************************************************************
*
*  SMUL4 - Four Byte Signed Integer Multiply
*
*  INPUTS:
*	M1L - multiplicand
*	M3L - multipier
*
*  OUTPUTS:
*	M1L - result
*
*  NOTES:
*	1) Uses SYSSIG4.
*
****************************************************************
*
SMUL4	START
	LONGA OFF
	LONGI OFF
	DEBUG SMUL4
;
;  Initialize the sign.
;
	LONG	M
	JSR	SSIG4
;
;  Do a 32 bit by 32 bit multiply.
;
	LDY	#32	32 bit multiply
ML1	LDA	M1L	M1L*M1L+2+M1L+2 -> M1L,M1L+2
	LSR	A
	BCC	ML2
	CLC		add multiplicand to the partial product
	LDA	M1L+4
	ADC	M3L
	STA	M1L+4
	LDA	M1L+6
	ADC	M3L+2
	STA	M1L+6
ML2	ROR	M1L+6	shift the interem result
	ROR	M1L+4
	ROR	M1L+2
	ROR	M1L
	DBNE	Y,ML1	loop til done
;
;  Check for overflows and set the sign.
;
	LDA	M1L+2	check for an overflow
	AND	#$8000
	ORA	M1L+4
	ORA	M1L+6
	BEQ	ML3
	SEP	#$60	overflow
	RTS

ML3	LDA	SIGN	set the sign
	AND	#$FF
	BEQ	ML4
	SEC		negate the result
	LDA	#0
	SBC	M1L
	STA	M1L
	LDA	#0
	SBC	M1L+2
	STA	M1L+2
ML4	CLV
	SHORT M
	RTS
	END

****************************************************************
*
*  SNPGE - Sets the Printer to the Next Page
*
*  INPUTS:
*	LNS - next line number on the current page
*
****************************************************************
*
SNPGE	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SNPGE

	LDA	LIST	quit if list off
	BEQ	RTS
	LDA	REDIRECT	if output redirected
	BEQ	NP1
	LDA	LPERPAGE	  and not infininte length pages then
	BEQ	NP1
	LDA	LNUM	  skip if at top of page
	BEQ	NP3
	HOME		  do a form feed
	BRL	NP2
NP1	PRINT		else print 3 blank lines
	PRINT
	PRINT
NP2	STZ	LNUM	reset the line number
NP3	INC2	PNUM	inc the page number
	BRL	STITL	write the title line
RTS	RTS
	END

****************************************************************
*
*  SNSYM - Find next symbol in symbol table
*
*  Inputs:
*	R10 - head of remaining symbols
*
*  Outputs:
*	R0 - pointer to first symbol, alphabetically
*
****************************************************************
*
SNSYM	START
	USING COMMON
HEAD	EQU	R10	pointer to head of symbol list
SYM	EQU	R0	pointer to symbol to print
PARENT	EQU	WR0	parent of SYM
T	EQU	WR4	temp pointer
TPARENT	EQU	MR0	parent of T
P0	EQU	TEMPZP	temp pointers
P1	EQU	TEMPZP+4

	LONG	M,I
	STZ	PARENT	parent := nil;
	STZ	PARENT+2
	MOVE4 HEAD,SYM	sym := head;
	LDA	HEAD	if head <> nil then begin
	ORA	HEAD+2
	JEQ	LB4
	LDY	#LNEXT-LBPTR	  t := head^.lnext;
	LDA	[HEAD],Y
	STA	T
	INY
	INY
	LDA	[HEAD],Y
	STA	T+2
	MOVE4 HEAD,TPARENT	  tparent := head;
LB1	LDA	T	  while t <> nil do begin
	ORA	T+2
	BEQ	LB2A
	LDA	[SYM]	    if sym^.lbptr^ > t^.lbptr^ then
	STA	P0	      begin
	LDA	[T]
	STA	P1
	LDY	#2
	LDA	[SYM],Y
	STA	P0+2
	LDA	[T],Y
	STA	P1+2
	JSR	CMP
	BLT	LB2
	MOVE4 TPARENT,PARENT	      parent := tparent;
	MOVE4 T,SYM	      sym := t;
LB2	ANOP		      end;
	MOVE4 T,TPARENT	    tparent := t;
	LDY	#LNEXT-LBPTR	    t := t^.lnext;
	LDA	[T],Y
	TAX
	INY
	INY
	LDA	[T],Y
	STA	T+2
	STX	T
	BRL	LB1	    end; *
LB2A	LDA	PARENT	  if parent <> nil then
	ORA	PARENT+2
	BEQ	LB3
	LDY	#LNEXT-LBPTR	    parent^.lnext := sym^.lnext
	LDA	[SYM],Y
	STA	[PARENT],Y
	INY
	INY
	LDA	[SYM],Y
	STA	[PARENT],Y
	BRA	LB4	  else
LB3	LDY	#LNEXT-LBPTR	    head := sym^.lnext;
	LDA	[SYM],Y
	STA	HEAD
	INY
	INY
	LDA	[SYM],Y
	STA	HEAD+2
LB4	SHORT I,M	  end;
	RTS
;
;  CMP - Compare strings P0^ and P1^
;
	LONGI ON
CMP	SHORT M	get length of shortest string
	LDA	[P0]
	CMP	[P1]
	BLT	CP1
	LDA	[P1]
CP1	LONG	M
	AND	#$FF
	TAX
	SHORT M
	LDY	#1	compare strings
CP2	LDA	[P0],Y
	CMP	[P1],Y
	BNE	CP3
	INY
	DBNE	X,CP2
	LDA	[P0]	characters match:
	CMP	[P1]	  shortest string is first
CP3	LONG	M
	RTS
	LONGA OFF
	LONGI OFF
	END

****************************************************************
*
*  SPNUM - Print a Number
*
*  Prints an integer after leading zero suppression.
*
*  INPUTS:
*	M1L - number to print
*
****************************************************************
*
SPNUM	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SPNUM

	STZ	M1L+2
	STZ	M1L+3
SPNUM4	ENTRY
	JSR	SCVDC	convert the binary value to a string
	LDX	#0	scan the string for the first non-zero
PN1	LDA	STRING,X	 character
	CMP	#'0'
	BNE	PN2
	INX
	CPX	#9
	BNE	PN1

PN2	LDA	STRING,X	write the string
	COUT	A
	INX
	CPX	#10
	BNE	PN2
	RTS
	END

****************************************************************
*
*  SPRBL - Print Blanks
*
*  INPUTS:
*	X - number of blanks to print
*
****************************************************************
*
SPRBL	START
	LONGA OFF
	LONGI OFF
	DEBUG SPRBL

	LDA	#' '
PR1	COUT	A
	DBNE	X,PR1
	RTS
	END

****************************************************************
*
*  SPREP - Pre-Pass
*
*  Assembles all lines outside of the START without requiring
*  two passes.
*
****************************************************************
*
SPREP	START
	USING COMMON
	USING OPCODE
	LONGA OFF
	LONGI OFF
	DEBUG SPREP

	LLA	STR,$1000	STR = $1000
PR1	JSR	FORML	form the line
	LDA	OP	quit if it is a START or DATA
	CMP	#ISTART
	BEQ	RTS
	CMP	#IDATA
	BEQ	RTS
	CMP	#IPRIVATE
	BEQ	RTS
	CMP	#IPRIVDATA
	BEQ	RTS
	JSR	FPAS3	process the line
	BCC	RTS
	LDA	ERR
	BNE	PR1A
	LDA	OP	don't incriment TP if the line processed
	CMP	#IAPPEND	 is an APPEND or COPY
	BEQ	PR2
	CMP	#ICOPY
	BEQ	PR2
PR1A	JSR	SINTP	incriment TP and read the next line
PR2	JSR	SINLN	check for end of file condion
	BCS	PR1
RTS	RTS
	END

****************************************************************
*
*  SPRHX - Print a Hex Byte
*
*  INPUTS:
*	A - byte to print
*
****************************************************************
*
SPRHX	START
	LONGA OFF
	LONGI OFF

	PHA		save the byte
	LSR	A	get the high nybble
	LSR	A
	LSR	A
	LSR	A
	JSR	HX1	print it
	PLA		recover the byte
	AND	#$F	get the low nybble
HX1	ORA	#'0'	print a nybble
	CMP	#'9'+1
	BLT	HX2
	ADC	#6
HX2	COUT
	RTS
	END

****************************************************************
*
*  SPROF - Turn the printer off
*
****************************************************************
*
SPROF	START

	RTS
	END

****************************************************************
*
*  SPRON - Turn the printer on
*
****************************************************************
*
SPRON	START

	RTS
	END

****************************************************************
*
*  SRITE - Write a Line
*
*  INPUTS:
*	1st byte after RTS -
*	   0 - flag indicating whether or not to end with a
*		 RETURN; if 0, no RETURN is issued
*	   1 - flag indicating type of input; if 1, the
*		 address of the characters to be printed must
*		 be in the input list, otherwise, the
*		 characters must be there
*	2nd byte past RTS -
*	   length of the line, in characters
*
****************************************************************
*
SRITE	START
	USING COMMON
	LONGA OFF
	LONGI OFF
LINEFEED EQU	10	linefeed character
;
;  Initialize for the print.
;
	PHP		save register sizes
	SHORT I,M
	PLA
	STA	LP
	PLA		get the return address
	STA	RETAD
	PLA
	STA	RETAD+1
	LDY	#1	get the input flags
	LDA	(RETAD),Y
	STA	FLAGS
	INY		get the # of characters
	LDA	(RETAD),Y
	TAX
	INY
	BIT	FLAGS	set the character address
	BVC	RT1
	LDA	(RETAD),Y	-> process an absolute address
	STA	CHRAD
	INY
	LDA	(RETAD),Y
	STA	CHRAD+1
	ADD2	RETAD,#5
	BRL	RT2
RT1	ADD2	RETAD,#3	-> immediate address
	LONG	M
	LDA	RETAD
	STA	CHRAD
	SHORT M
	CLC
	TXA
	ADC	RETAD
	STA	RETAD
	BCC	RT2
	INC	RETAD+1
;
;  Print the characters.
;
RT2	LDY	#0
RT3	LDA	(CHRAD),Y
	COUT	A
	INY
	DBNE	X,RT3
;
;  Issue a RETURN.
;
	LDA	FLAGS	skip if a RETURN was not requested
	BPL	RT5
RT4	LDA	#RETURN	do the RETURN
	COUT	A
	LDA	#LINEFEED
	COUT	A
	LDA	REDIRECT	skip if redirection off
	BEQ	RT5
	LDA	LPERPAGE	skip if infinite page length
	BEQ	RT5
	INC	LNUM	incriment the line number
	LDA	LNUM	if at the end of a page then
	CMP	LPERPAGE
	BLT	RT5
	LDA	LIST
	BEQ	RT5
	STZ	LNUM	  mark top of new page
	INC2	PNUM	  inc page number
	LONG	M	  write title
	LDA	RETAD
	PHA
	SHORT M
	JSR	STITL
	LONG	M
	PLA
	STA	RETAD
RT5	LONG	M
	LDA	RETAD
	DEC	A
	PHA
	SHORT M
	LDA	LP	restore register sizes
	PHA
	PLP
	RTS
;
;  SRITE2 - Issue a return with page break checks
;
SRITE2	ENTRY
	PHP		save register sizes
	SHORT I,M
	PLA
	STA	LP
	PLA		get the return address
	STA	RETAD
	PLA
	STA	RETAD+1
	INC2	RETAD
	BRL	RT4

FLAGS	DS	1
LP	DS	1	local P register
	END

****************************************************************
*
*  SRSTR - Handle restartability
*
****************************************************************
*
SRSTR	START
	USING COMMON
	LONGA ON
	LONGI ON
DATALEN	EQU	$F71	length of data area to save
ANAMELEN EQU	$EB1	length of variables initialized to 0

	LDA	FIRSTTIME
	BEQ	RS1
	STZ	FIRSTTIME
	MOVE	ASM41,TASM41,#DATALEN
	RTS

RS1	MOVE	TASM41,ASM41,#DATALEN
	MOVE	#0,TEMPASS,#ANAMELEN
	RTS

FIRSTTIME DC	I'1'	first execution?
TASM41	DS	DATALEN
	END

****************************************************************
*
*  SSIG4 - Obtain the Sign for Four Byte Integer Operations
*
*  INPUTS:
*	M1L - first number
*	M3L - second number
*
*  OUTPUTS:
*	M1L - ABS(M1L)
*	M3L - ABS(M3L)
*	M1L+4 to M1L+7 - 0
*	SIGN - 0 if M1L*M3L > 0, else non-zero
*
****************************************************************
*
SSIG4	START
	LONGI OFF
	LONGA ON
;
;  Initialize
;
	STZ	M1L+4
	STZ	M1L+6
	STZ	SIGN
;
;  Make the numbers positive.
;
	LDA	M1L+2
	BPL	PS1
	LDX	#M1L
	JSR	SUB
	INC	SIGN
PS1	LDA	M3L+2
	BPL	RTS
	LDX	#M3L
	DEC	SIGN
SUB	SEC
	LDA	#0
	SBC	0,X
	STA	0,X
	LDA	#0
	SBC	2,X
	STA	2,X
RTS	RTS
	LONGA OFF
	END

****************************************************************
*
*  STABL - Print the Symbol Table
*
*  INPUTS:
*	R0,R1 - start of table
*	R2,R3 - end of table
*	SNAME - table name
*
****************************************************************
*
STABL	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG STABL
;
;  Check for no entries.
;
	LONG	I,M
	BCC	CE1	set addr to symbol table
	MOVE4 GHASH,R0
	BRA	CE2
CE1	MOVE4 LHASH,R0
CE2	SHORT I,M
	JSR	SCHAN	chain a hash table
	LONG	M
	LDA	R0	quit if empty
	ORA	R2
	BNE	ST1
	SHORT M
	RTS
;
;  Print the header.
;
ST1	MOVE4 R0,R10	set symbol chain head
	PRINT		skip 3 lines
	PRINT	       
	PRINT
	WRITE2 SNAME,6	print header
	PRINT ' Symbols'
;
;  Print the symbols.
;
ST2	JSR	SCESC	issue return
	STZ	CC

ST4	JSR	SNSYM	get pointer to next symbol
	LONG	M	quit if no more
	LDA	R0
	ORA	R2
	SHORT M
	BNE	ST4A
	BRL	SCESC

ST4A	LDY	#LBFLAG-LBPTR	fetch the entry
ST5	LDA	[R0],Y
	STA	LBPTR,Y
	DBPL	Y,ST5
	LONG	M,I	fetch label name
	LDA	LBPTR
	STA	R4
	LDA	LBPTR+2
	STA	R6
	LDA	[R4]
	AND	#$FF
	DEC	A
	TAY
ST6	LDA	[R4],Y
	STA	LNAME,Y
	DEY
	DBPL	Y,ST6
	SHORT M,I
	LDY	LNAME	if last char is a space, remove it
	LDA	LNAME,Y
	CMP	#' '
	BNE	ST6A
	DEC	LNAME
ST6A	CLC		see if the label will fit on the line
	LDA	CC
	ADC	LNAME
	BCS	ST7
	ADC	#8
	BCS	ST7
	CMP	COLS
	BLT	ST8
ST7	JSR	SCESC	no - start a new line
	STZ	CC
ST8	LDA	LBT	write the label value
	CMP	#'G'
	BEQ	ST8A
	CMP	#'Q'
	BEQ	ST9
	SUB4	LBV,H1000
	BRA	ST9
ST8A	LDA	LBFLAG
	AND	#LBEXPR
	BEQ	ST9
	LONG	M
	STZ	LBV
	STZ	LBV+2
	SHORT M
ST9	LDA	LBV+2
	PRHEX
	LDA	LBV+1
	PRHEX
	LDA	LBV
	PRHEX
	LDA	#' '
	COUT	A
	CLC		update CC
	LDA	CC
	ADC	#7
	STA	CC
	LDX	LNAME	write the label name
	LDY	#1
ST10	LDA	LNAME,Y
	COUT	A
	INC	CC
	LDA	CC
	INC	A
	CMP	COLS
	BGE	ST11
	INY
	DBNE	X,ST10
	LDY	CC	skip writting spaces if at EOL
	INY
	INY
	INY
	CPY	COLS
	BGE	ST11
	DEY
	STY	CC
	LDA	#' '
	COUT	A
	LDA	#' '
	COUT	A
ST11	LDX	#0	skip to tab stop
	LDY	CC
ST11A	INY
	CPY	COLS
	BGE	ST12
	LDA	TABS-1,Y
	BNE	ST11B
	STY	CC
	INX
	BRA	ST11A
ST11B	TXA
	BEQ	ST13
ST11C	LDA	#' '
	COUT	A
	DBNE	X,ST11C
	BRL	ST4
ST12	JSR	SCESC	skip to next line
	STZ	CC
ST13	BRL	ST4

CC	DC	I'0'
H1000	DC	I4'4096'
TABS	DC	I1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1'
	DC	11I1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1'
	LONGA OFF
	END

****************************************************************
*
*  STERRS - Terminal Error Messages
*
****************************************************************
*
STERRS	START
	USING COMMON
	LONGA OFF
	LONGI OFF
KEYBOARD EQU	$C000
STROBE	EQU	$C010

TERR1	ENTRY
	LA	R0,ER1
	BRA	SWTERR

TERR2	ENTRY
	LA	R0,ER2
	BRA	SWTERR

TERR3	ENTRY
	LA	R0,ER3
	BRA	SWTERR

TERR4	ENTRY
	LA	R0,ER4
	BRA	SWTERR

TERR5	ENTRY
	LA	R0,ER5
	BRA	SWTERR

TERR6	ENTRY
	LA	R0,ER6
	BRA	SWTERR

TERR7	ENTRY
	LA	R0,ER7
	BRA	SWTERR

TERR8	ENTRY
	LA	R0,ER8
	BRA	SWTERR

TERR9	ENTRY
	LA	R0,ER9
	BRA	SWTERR

TERR10	ENTRY
	LA	R0,ER10
 	BRA	SWTERR

TERR11	ENTRY
	LA	R0,ER11
;	BRA	SWTERR
;
;  Write a terminal error
;
SWTERR	ENTRY
	LDA	WAIT	if wait || ! editor || ! terminal
	BNE	WT1
	LDA	EDITOR
	BNE	WT2
WT1	ERROUT 	  write the error message
	JSR	FormError	  write standard form stuff
	LDA	(R0)	  write the error message
	STA	MLEN
	ADD2	R0,#1,MADDR
	JSR	SRITE
	DC	H'40'
MLEN	DS	1
MADDR	DS	2
	STDOUT
	JSR	SCESC
WT2	LDA	WAIT	if wait
	BEQ	WT4
	STA	>STROBE	  wait for a key press
WT3	LDA	>KEYBOARD
	BPL	WT3
	STA	>STROBE

WT4	BRL	SABORT	abort assembly

ER1	DW	'Out of memory'
ER2	DW	'Unable to write to object module'
ER3	DW	'Keep file could not be opened'
ER4	DW	'File could not be opened'
ER5	DW	'Could not allocate needed memory'
ER6	DW	'Macro file could not be opened'
ER7	DW	'Could not read file'
ER8	DW	'No end'
ER9	DW	'AINPUT table damaged'
ER10	DW	'Could not overwrite keep file'
ER11	DW	'Stopped with open-apple .'
	END

****************************************************************
*
*  STIME - Form the Time and Date String
*
*  OUTPUTS:
*	STRING - string containing the time and date, ending
*		with a $00
*	TIMESTR - time in HH:MM format
*	DATESTR - date in DD MMM YY format
*
****************************************************************
*
STIME	START
	USING COMMON
	DEBUG STIME

	LONG	I,M
	PHA		push space for result
	PHA
	PHA
	PHA
	_READTIMEHEX	call read time
	BCC	RT2

	PLA		if error return no date
	PLA
	PLA
	PLA
	SHORT M	move the no time field into
	LDY	#L:NOTIME-1	 the string
RT1	LDA	NOTIME,Y
	STA	STRING,Y
	DEY
	BPL	RT1
	SHORT I,M
	RTS
	LONGA ON
	LONGI ON

RT2	SHORT I,M
	LDY	#20	initialize the string
	LDA	#' '
RT3	STA	STRING,Y
	DBPL	Y,RT3
	STZ	STRING+21
;
;  Format the date
;
	PLA		set the second
	JSR	DEC
	LDA	#':'
	STA	STRING+18
	JSR	XZERO	if X is blank then set X to '0'
	STX	STRING+19
	STY	STRING+20
	PLA		set the minute
	JSR	DEC
	LDA	#':'
	STA	STRING+15
	JSR	XZERO	if X is blank then set X to '0'
	STX	STRING+16
	STY	STRING+17
	CPX	#' '
	BNE	LB1
	LDX	#'0'
LB1	STX	TIMESTR+4
	STY	TIMESTR+5
	PLA		set the hour
	JSR	DEC
	JSR	XZERO	if X is blank then set X to '0'
	STX	STRING+13
	STY	STRING+14
	STX	TIMESTR+1
	STY	TIMESTR+2
	PLA		set the year
	CMP	#100
	BLT	RT4
	SEC
	SBC	#100
	JSR	DEC
	LDA	#'2'
	STA	STRING+7
	LDA	#'0'
	STA	STRING+8
	BRA	RT5
RT4	JSR	DEC
	LDA	#'1'
	STA	STRING+7
	LDA	#'9'
	STA	STRING+8
RT5	JSR	XZERO	if X is blank then set X to '0'
	STX	STRING+9
	STY	STRING+10
	STX	DATESTR+8
	STY	DATESTR+9
	PLA		set the day
	INC	A
	JSR	DEC
	STX	STRING+0
	STY	STRING+1
	CPX	#' '
	BNE	LB2
	LDX	#'0'
LB2	STX	DATESTR+1
	STY	DATESTR+2
	PLA		set the month
	LONG	I,M
	AND	#$00FF
	ASL	A
	ASL	A
	TAX
	LDA	MONTH,X
	STA	STRING+3
	STA	DATESTR+4
	LDA	MONTH+2,X
	STA	STRING+5
	STA	DATESTR+6
	PLA		don't care about day
	SHORT I,M
	RTS
;
;  If X is blank, convert to 0
;
XZERO	CPX	#' '
	BNE	XZRTS
	LDX	#'0'
XZRTS	RTS
;
;  Convert hex to decimal
;
DEC	LDX	#$FF
	SEC
DC1	SBC	#10
	INX
	BCS	DC1
	ADC	#10
	ORA	#'0'
	TAY
	TXA
	BEQ	DC2
	ORA	#'0'
	TAX
	RTS

DC2	LDX	#' '
	RTS
;
;  Local data area
;
NOTIME	DC	C'<No Date> ',I1'0'
MONTH	DC	C'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec '
	END

****************************************************************
*
*  STITL - Write the Title Line
*
*  INPUTS:
*	PNUM - page number
*	TITLE - title in use flag
*
*  OUTPUTS:
*	PNUM - updated
*
****************************************************************
*
STITL	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG STITL

	LDA	TITLE	quit if TITLE is not in use
	BEQ	RTS
	PRINT2 'Page '	print the page number
	LONG	M
	LDA	PNUM
	STA	M1L
	SHORT M
	JSR	SPNUM
	PRBL	#3
	WRITE TITLE,60	print the title
	PRINT
RTS	RTS
	END

****************************************************************
*
*  STRCE - Debug Trace Facility
*
*  If the global constant DEBUG is true this subroutine will
*  be placed in the code.  If the variable TRACE is true, it
*  will print the characters appearing on the DEBUG macros
*  used in the program.
*
*  INPUTS:
*	TRACE - trace on flag
*
****************************************************************
*
STRCE	START
	USING MACDAT
	USING EVALDT
	USING COMMON

	AIF	DEBUG=0,.A
	PHP		save variables
	LONG	I,M
	STA	LA
	STY	LY
	STX	LX
	SHORT I,M
	PLA
	STA	LPS
	LONG	M
	LDA	R0
	STA	TR0
	SHORT M
	PLA		get the address of the characters
	STA	R0
	PLA
	STA	R1
	INC2	R0
	LDA	TRACE	quit if trace is off
	JEQ	LB2

;	VARIABLE OUTPUT GOES HERE

	LDY	#0	write the characters
	LDA	(R0),Y
	TAX
	INY
LB1	LDA	(R0),Y
	COUT	A
	INY
	DBNE	X,LB1

	LDA	SRCBUFF+3
	JSR	BYTE
	LDA	SRCBUFF+2
	JSR	BYTE
	LDA	SRCBUFF+1
	JSR	BYTE
	LDA	SRCBUFF
	JSR	BYTE
;YY	LDA	>$C000
;	BPL	YYY
;	STA	>$C010
	JSR	SCESC

LB2	CLC		get the return address
	LDY	#0
	LDA	(R0),Y
	ADC	R0
	STA	R0
	BCC	LB2A
	INC	R1
LB2A	LDA	R1
	PHA
	LDA	R0
	PHA
	LONG	I,M	restore variables
	LDA	TR0
	STA	R0
	LDY	LY
	LDX	LX
	SHORT I,M
	LDA	LPS
	PHA
	LONG	M
	LDA	LA
	PLP
	RTS
;
;  Write a byte to the screen.
;
	LONGA OFF
	LONGI OFF
BYTE	PHA
	MLSR	A,4
	ORA	#'0'
	CMP	#'9'+1
	BLT	BT1
	ADC	#6
BT1	COUT	A
	PLA
	AND	#$F
	ORA	#'0'
	CMP	#'9'+1
	BLT	BT2
	ADC	#6
BT2	COUT	A
	RTS

LA	DS	2
LX	DS	2
LY	DS	2
LPS	DS	1
TR0	DS	2
.A
	END

****************************************************************
*
*  SUPST - Update the Location Counter
*
*  INPUTS:
*	STR - location counter
*	LENGTH - length of the last instruction
*
*  OUTPUTS:
*	STR = STR+LENGTH
*
****************************************************************
*
SUPST	START
	USING COMMON
	LONGA OFF
	LONGI OFF
	DEBUG SUPST

	LONG	I,M
	ADD4	STR,LENGTH
	ADD4	ABSADDR,LENGTH
	SHORT I,M
	RTS
	END

	APPEND FPAS1.ASM
