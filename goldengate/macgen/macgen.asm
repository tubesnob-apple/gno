	keep	obj/macgen
	mcopy macgen.mac
****************************************************************
*
*  ORCA/M Macgen 2.0
*
*  February 1990
*  Mike Westerfield
*
*  Copyright 1986-95
*  By the Byte Works, Inc.
*
****************************************************************
*
*  Version 2.0.2, 7 July 94
*  Mike Westerfield
*
*  1. Added the new I/O startup & shutdown stuff
*
****************************************************************
*
*  Version 2.0.3 B1, 16 Feb 95
*  Mike Westerfield
*
*  1. Fixed some I/O bugs
*
****************************************************************
*
Macgen	start
	using Common

	phk
	plb
	pha
	phx
	phy
	jsl	SystemEnvironmentInit	start the I/O system
	jsl	SysIOStartup
	ply
	plx
	pla
	jsr	Initialize	initialize the program
	jsr	Main	run the program
	jsr	Fini	shut down
	jsr	StopSpin	stop the console spinner
	jsl	SystemEnvironmentInit	shut down the I/O system
	lda	#0
	rtl
	end

****************************************************************
*
*  Common - common data
*
****************************************************************
*
	copy	DirectPage
Common	data
	using FileNames
;
;  Copy record
;
copyNext equ	0	next record
copyFptr equ	4	file's pointer
copyFlen equ	8	# of characters left in the file
copyName equ	12	name of the file

copySize equ	copyName+fvarSize	size of a copy record
;
;  Symbol table entry
;
disp_found equ 4	disp to found flag in symbol table
disp_name equ 6	disp to name in symbol table
;
;  Constants
;
symSize	equ	4*1024	initial size of symbol table
cb_grow	equ	16*1024	grow size for character buffer
lineSize equ	256	size of a line

RETURN	equ	13	RETURN key code
TAB	equ	9	TAB key code

SRC	equ	$B0	source file
TXT	equ	$04	text file
;
;  global variables
;
op	ds	lineSize+1	op code in LINE
progress	ds	2	print progress info?
tabs	ds	256	tab line
token	dstr	,255	command line token
user_ID	ds	2
	end

****************************************************************
*
*  SpinnerCommon - common data area for the spinner subroutines
*
****************************************************************
*
SpinnerCommon privdata

spinSpeed equ	1	calls before one spinner move

spinning	dc	i'0'	are we spinning now?
spinDisp	dc	i'0'	disp to the spinner character
spinCount ds	2	spin loop counter

spinner	dc	i1'$7C,$2F,$2D,$5C'	spinner characters
	end

****************************************************************
*
*  CharOut - write a character to the output file
*
*  Inputs:
*	A - character to write
*	chptr - pointer to character buffer
*	chdisp - disp in character buffer
*
*  Notes:
*	Must not disturb r0-r3.
*	Does not disturb X, Y
*
****************************************************************
*
CharOut	start
	using Common

	pha		save character
	jsr	CheckBuffer	make sure there's room in the buffer
	add4	chptr,chdisp,r12 	get pointer to char
	pla		save the char
	short M
	sta	[r12]
	long	M
	inc4	chdisp	update disp in buffer
	rts
	end

****************************************************************
*
*  CheckAbort - see if an abort has been flagged
*
*  Notes:
*       Returns to shell if an abort is requested
*
****************************************************************
*
CheckAbort start
keyboard equ	$C000	keyboard latch
strobe	equ	$C010	keyboard strobe
flags	equ	$C025	keyboard flags

	short M
	lda	>keyboard
	bpl	lb1
	and	#$7F
	cmp	#'.'
	bne	lb2
	lda	>flags
	bpl	lb2
	sta	>strobe
	long	M
	puts	#'Stopped from keyboard',cr=t,errout=t
	lda	#-1
	brl	Quit

lb1	sta	>strobe
lb2	long	M
	rts
	end

****************************************************************
*
*  CheckBuffer - Check buffer size
*
*  Inputs:
*	chdisp - disp to next character to write
*	chhand - handle of current buffer
*	chptr - pointer to start of character buffer
*	chsize - current size of buffer
*
*  Outputs:
*	chptr - pointer to start of character buffer
*
****************************************************************
*
CheckBuffer start
	using Common

	cmpl	chdisp,chsize	if chdisp < chsize then
	bge	lb1
rts	rts		  return

lb1	phx		save regs
	phy
	lda	chsize	if chsize = 0 then
	ora	chsize+2
	bne	lb2
	pha		  chhand = new(cb_grow)
	pha
	ph4	#cb_grow
	ph2	user_ID
	ph2	#$8000
	ph4	#0
	_NewHandle
	pl4	chhand
	bcs	oom
	lla	chsize,cb_grow	  chsize = cb_grow
	bra	lb3	  return
lb2	anop		endif

	ph4	chhand	unlock the handle
	_HUnlock
	add4	chsize,#cb_grow	chsize += cb_grow
	ph4	chsize	grow the buffer
	ph4	chhand
	_SetHandleSize
	bcs	oom
lb3	ph4	chhand	lock the handle
	_HLock
	lda	[chhand]	dereference the handle
	sta	chptr
	ldy	#2
	lda	[chhand],Y
	sta	chptr+2
	ply
	plx
	rts

oom	puts	#'Out of memory',errout=t,cr=t
	lda	#-1
	brl	Quit
	end

****************************************************************
*
*  CheckCopyAppend - See if this line is a copy or append
*
*  Inputs:
*	op - operation code
*	lptr - text line pointer
*
*  Outputs:
*	cflag - 1 if copy found
*	aflag - 1 if append found
*
****************************************************************
*
CheckCopyAppend start
	using Common
	using Opcodes

	ldy	#6	check for 'copy'
cp1	lda	op+1,Y
	cmp	copyOp,Y
	bne	cp2
	dey
	dbpl	Y,cp1
	inc	cflag
	rts

cp2	ldy	#6	check for 'append'
cp3	lda	op+1,Y
	cmp	append,Y
	bne	cp4
	dey
	dbpl	Y,cp3
	inc	aflag
cp4	rts
	end

****************************************************************
*
*  CheckForMacros - handle macros in the current source line
*
*  Inputs:
*	lptr - line to check
*
****************************************************************
*
CheckForMacros start
	using Common

	jsr	GetOperand	quit if the op code is not a
	bcs	rts	 macro
	short I,M	quit if the opcode has a &
	ldx	op
	lda	#'&'
lb1	cmp	op,X
	beq	no
	dex
	bne	lb1
	long	I,M
	jsr	Insert	insert the macro in the symbol table
rts	rts

no	long	I,M
	rts
	end

****************************************************************
*
*  CopyAppend - Do copy and append
*
*  Inputs:
*	cflag - copy flag
*	aflag - append flag
*	copyPtr - old file is recorded (for copy only)
*
*  Outputs:
*	fname - new file name
*	fptr - file pointer
*	flen - end of file pointer
*
****************************************************************
*
CopyAppend start
	using FileNames
	using Common

	jsr	CheckCopyAppend	find COPY and APPEND directives
	lda	cflag	if copy, go do it
	bne	lb1
	lda	aflag	skip if not an append
	beq	lb4

	jsr	Purge	append: dump the current file
	bra	lb3

lb1	ph2	#copySize	get memory for the copy record
	jsr	Malloc
	sta	r0
	stx	r2
	ldy	#2	set the forward link
	lda	copyPtr
	sta	[r0]
	lda	copyPtr+2
	sta	[r0],Y
	move4 r0,copyPtr	put this record in the copy list
	ldy	#copyFptr	save fptr
	lda	fptr
	sta	[r0],Y
	iny
	iny
	lda	fptr+2
	sta	[r0],Y
	ldy	#copyFlen	save flen
	lda	flen
	sta	[r0],Y
	iny
	iny
	lda	flen+2
	sta	[r0],Y
	add4	r0,#copyName	save the file name
	short M
	ldy	#fvarSize-1
lb2	lda	fname,Y
	sta	[r0],Y
	dey
	bpl	lb2
	long	M
	stz	fname	reserve this name for our use
	stz	fname+2

lb3	jsr	GetFName	read the file name
	jsr	Open	read the file
lb4	rts
	END

****************************************************************
*
*  CreateMacros - create the macro file
*
*  Inputs:
*	stable - table of macros needed
*
****************************************************************
*
CreateMacros start
	using Common

	jsr	OutFile	get an output file name
cr1	jsr	Unresolved	quit if macros are all resolved
	bcc	rts
	jsr	MacroFile	get a macro file to search
	bcc	rts
	jsr	Search	search the macro file
	bra	cr1
rts	rts
	end

****************************************************************
*
*  DoRename - handle a rename directive
*
*  Inputs:
*	lptr - pointer to the rename line
*
****************************************************************
*
DoRename start
	using Common
	using Opcodes
;
;  See if the directive is a RENAME
;
	ldy	#6
lb0	lda	rename,Y
	cmp	op+1,Y
	bne	rts
	dey
	dbpl	Y,lb0
;
;  Save the opcode table
;
	lda	saved
	bne	so1
	move	table,savedtable,#tend-table
so1	anop
;
;  Read the op codes from the line.
;
	move	#$20,opc,#10	clear the replacement op code
	move	#$20,op,#10	clear op code
	jsr	FindOperand	find operand
	bcc	rts
	ldx	#0
	short M
lb1	lda	[lptr],Y
	jsr	Shift
	cmp	#','
	beq	lb2
	sta	op+1,X
	inx
	cpx	#8
	bge	lb2
	iny
	cpy	#lineSize
	bne	lb1
rts	long	M
	rts
	longa off

lb2	txa		set length
	sta	op
	lda	[lptr],Y	find the comma
	cmp	#','
	beq	lb3
	iny
	cpy	#lineSize
	bne	lb2
	bra	rts

lb3	iny		find the replacement op code
	ldx	#0
lb4	lda	[lptr],Y
	jsr	Shift
	cmp	#' '
	beq	lb5
	cmp	#RETURN
	beq	lb5
	sta	opc,X
	inx
	cpx	#8
	beq	lb5
	iny
	cpy	#lineSize
	bne	lb4
;
;  Find the old op code in the symbol table
;
lb5	long	M
	jsr	GetOperand	find it
	bcc	rts
	ldy	#6	replace it
lb6	lda	opc,Y
	sta	(r0),Y
	dey
	dbpl	Y,lb6
	rts

opc	ds	10
	end

****************************************************************
*
*  Fini - clean up before return
*
****************************************************************
*
Fini	start
	using Common

	ph2	user_ID
	_DisposeAll
	rts
	end

****************************************************************
*
*  FindMacro - Find macro in symbol table
*
*  Inputs:
*	op - name of macro to find
*	sTable - disp to first entry in symbol table
*
*  Outputs:
*	r0 - location of entry
*	C - set if found, else clear
*
****************************************************************
*
FindMacro start
	using Common

	move4 sTable,r0
lb1	lda	r0
	ora	r2
	beq	rts
	add4	r0,#disp_name,r4
	lda	#0
	short M
	lda	[r4]
	cmp	op
	bne	lb3
	tay
lb2	lda	op,Y
	cmp	[r4],Y
	bne	lb3
	dbne	Y,lb2
	long	M
	sec
	rts
	longa off

lb3	long	M
	ldy	#2
	lda	[r0]
	tax
	lda	[r0],Y
	sta	r2
	stx	r0
	bra	lb1

rts	clc
	rts
	end

****************************************************************
*
*  FindOpcode - Find op code
*
*  Inputs:
*	lptr - pointer to text line
*	tabs - tab line
*
*  Outputs:
*	C - set if found
*	Y - disp in LINE
*
****************************************************************
*
FindOpcode start
	using Common

	ldy	#0	skip to space
	ldx	#0
	short M
fn1	lda	[lptr],Y
	cmp	#' '
	beq	fn2
	cmp	#TAB
	beq	fn2
	cmp	#RETURN
	beq	no
	inx
	iny
	cpx	comcol
	bne	fn1
	bra	no

fn2	lda	[lptr],Y	skip to char
	cmp	#RETURN
	beq	no
	cmp	#TAB
	bne	fn4
fn3	inx
	lda	tabs,X
	beq	fn3
	bra	fn5
fn4	cmp	#' '
	bne	fn6
	inx
fn5	iny
	cpx	comcol
	bne	fn2

no	long	M
	clc		opcd not found
	rts

fn6	long	M
	sec		opcd found
	rts
	end

****************************************************************
*
*  FindOperand - Find Operand
*
*  Inputs:
*	lptr - text line pointer
*	tabs - tab line
*
*  Outputs:
*	Y - disp in line
*	C - set if found
*
****************************************************************
*
FindOperand start
	using Common

	jsr	FindOpcode	find the opcode
	bcc	fn2
	short M	skip to blank
fn1	lda	[lptr],Y
	cmp	#' '
	beq	fn3
	cmp	#TAB
	beq	fn3
	cmp	#RETURN
	beq	fn2
	iny
	bne	fn1
fn2	long	M
	clc
	rts

	longa off

fn3	lda	[lptr],Y	skip to char
	cmp	#RETURN
	beq	fn2
	cmp	#TAB
	bne	fn5
fn4	inx
	lda	tabs,X
	beq	fn4
	bra	fn6
fn5	cmp	#' '
	bne	fn7
	inx
fn6	iny
	cpx	comcol
	blt	fn3

	lda	[lptr],Y	single space?
	cmp	#' '
	bne	fn2
	iny
	lda	[lptr],Y
	cmp	#' '
	beq	fn2
	dey
	dey
	cmp	#' '
	beq	fn2

	iny		yes -> accept it
	iny
fn7	long	M
	sec
	rts
	end

****************************************************************
*
*  Free - free memory allocated by Malloc
*
*  Inputs:
*	ptr - address of the parameter block
*
*  Notes:
*	No action is taken if a nil pointer is passed.
*
****************************************************************
*
Free	start

	sub	(4:ptr),0

	lda	ptr
	ora	ptr+2
	beq	rts
	pha
	pha
	ph4	ptr
	_FindHandle
	_DisposeHandle
rts	ret
	end

****************************************************************
*
*  GetFName - get a file name for a copy or append
*
*  Inputs:
*	lptr - source line pointer
*
*  Outputs:
*	fname - file name
*
****************************************************************
*
GetFName start
	using Common
	using FileNames

	jsr	FindOperand	find operand
	bcc	lb5

	ldx	#0	set file name
	short M
	lda	[lptr],Y
	cmp	#''''
	beq	lb2
lb1	lda	[lptr],Y
	cmp	#RETURN
	beq	lb6
	cmp	#TAB
	beq	lb6
	cmp	#' '
	beq	lb6
	sta	name+2,X
	inx
	cpx	#63
	beq	lb6
	iny
	cpy	#lineSize
	bne	lb1
	bra	lb6

lb2	iny		... with tic mark
	cpy	#lineSize
	beq	lb6
lb3	lda	[lptr],Y
	cmp	#RETURN
	beq	lb6
	cmp	#''''
	bne	lb4
	inx
	lda	[lptr],Y
	cmp	#''''
	bne	lb6
lb4	sta	name+2,X
	iny
	cpy	#lineSize
	beq	lb6
	inx
	cpx	#63
	blt	lb3
	bra	lb6

lb5	stz	cflag
	stz	aflag
lb6	short I
	stx	name+1
	long	I,M
	ph4	#name
	ph4	#fname
	jsr	CopyFileName
	rts

name	dstr	,255
	end

****************************************************************
*
*  GetLine - get a line
*
*  Outputs:
*	inline - points to the next character
*
****************************************************************
*
GetLine	start
	using Common

	jsr	CheckAbort
	jsr	CursorOn
	gets	line,cr=t
	jsr	CursorOff
	strlen line
	tax
	short M
	lda	#0
	sta	line+2,X
	long	M
	lla	inline,line+2
	rts

abort	lda	#0
	brl	Quit

line	dstr	,255
	dc	i1'0'
	end

****************************************************************
*
*  GetOpcode - Get Op Code
*
*  Inputs:
*	lptr - text line pointer
*
*  Outputs:
*	op - operation code
*	C - set of OP found; clear for comments, error lines
*
****************************************************************
*
GetOpcode start
	using Common

	lda	[lptr]	skip comments
	and	#$00FF
	cmp	#RETURN
	beq	none
	cmp	#'*'
	beq	none
	cmp	#';'
	beq	none
	cmp	#'.'
	beq	none
	cmp	#'!'
	beq	none

	lda	#'  '	clear op code
	sta	op+1
	sta	op+3
	sta	op+5
	sta	op+7
	jsr	FindOpcode	find op code
	bcc	none
	ldx	#0	save op code
gf1	lda	[lptr],Y
	and	#$00FF
	jsr	Shift
	cmp	#' '
	beq	gf2
	cmp	#TAB
	beq	gf2
	cmp	#RETURN
	beq	gf2
	short M
	sta	op+1,X
	long	M
	iny
	inx
	cpx	#lineSize-1
	bne	gf1
gf2	short I	save length
	stx	op
	long	I
	sec		op code found
	rts

none	clc		no op code
	rts
	end

****************************************************************
*
*  GetOperand - find an operand in the operand table
*
*  Inputs:
*	op - op code
*
*  Outputs:
*	C - set of the op code exists
*	r0 - position of entry in table (two byte addr)
*
****************************************************************
*
GetOperand start
	using Common
	using Opcodes

	lda	op	skip if longer than 8
	and	#$00FF
	cmp	#oplen+1
	bge	pt5
	lda	#table
	sta	r0

pt2	ldy	#0	check this entry
pt3	lda	(r0),Y
	cmp	op+1,Y
	bne	pt4
	iny
	iny
	cpy	#oplen
	blt	pt3

	sec		found it!
	rts

pt4	clc
	lda	r0
	adc	#oplen
	sta	r0
	cmp	#tend
	blt	pt2
pt5	clc		not found
	rts
	end

****************************************************************
*
*  Header - print the header
*
****************************************************************
*
Header	start
	using	Common

	lda	progress	if progress then
	beq	lb1
	puts	#'MacGen 2.0.3',cr=t	  write the header
	putcr
lb1	rts
	end

****************************************************************
*
*  Initalize - Program initialization
*
****************************************************************
*
Initialize start
	using FileNames
	using Opcodes
	using Common

	ora	#$0100	save user ID
	sta	user_ID
	stx	inline+2	save addr of input line
	sty	inline
	jsr	CursorOff	turn off the cursor
;
;  Initialize scalars
;
	lda	#1	crunch = true
	sta	crunch
	sta	progress	progress = true
	stz	wcard	wcard = FALSE
	sta	scan	scan = TRUE
	stz	copyPtr	copyPtr = nil
	stz	copyPtr+2
	lda	#-2	langNum = -2
	sta	langNum
	lda	#40	comment column = 40
	sta	comcol
	stz	chDisp	no characters in the output buffer
	stz	chDisp+2
	stz	chSize	no output buffer
	stz	chSize+2
	stz	chHand	no output buffer handle
	stz	chHand+2
	jsr	InitFile	initialize the file module
;
;  Restore the opcode table
;
	lda	saved
	beq	so1
	move	savedtable,table,#tend-table
so1	anop
;
;  Read and parse the command line.
;
	lda	inline	if inline = nul then
	ora	inline+2
	bne	rl1
	lla	inline,null	  inline = & null
	bra	rl2
rl1	add4	inline,#8	else skip shell name
rl2	anop		endif
	jsr	NextToken	read the command name
lb1	jsr	NextToken	skip if there is no token on the line
	strlen token
	cmp	#0
	beq	fl1
	lda	token+2	skip if the first char is not + or -
	and	#$00FF
	cmp	#'+'
	beq	lb3
	cmp	#'-'
	jne	fl3
lb3	strlen token	error if token length != 2
	cmp	#2
	bne	lb6
	ldx	#0	set or clear a flag
	lda	token+2
	and	#$00FF
	cmp	#'+'
	bne	lb5
	inx
lb5	lda	token+3
	and	#$00FF
	jsr	Shift
	cmp	#'C'
	bne	lb6
	stx	crunch
	brl	lb1
lb6	lda	token+3
	and	#$00FF
	jsr	Shift
	cmp	#'P'
	bne	lb7
	stx	progress
	brl	lb1
lb7	puts	#'Undefined flag',cr=t,errout=t
	lda	#$FFFF
	brl	Quit
;
;  Get the file name.
;
fl1	jsr	Header
	puts	#'File name: '	get prompted file name
	jsr	GetLine
	jsr	NextToken
	strlen token
	bne	fl4
	lda	#0
	brl	Quit

fl3	jsr	Header
fl4	ph4	#token
	ph4	#fname
	jsr	CopyFileName
	jsr	NextToken	next token
;
;  Reserve a symbol table buffer.
;
	ph2	#symSize	get the buffer
	jsr	Malloc
	sta	ste
	stx	ste+2
	add4	ste,#symSize,pte	mark the end
	lla	sTable,0	sTable = nil
	rts
;
;  Local data
;
null	dc	i1'0'	null string
	end

****************************************************************
*
*  Insert - Insert a Macro in the Table
*
*  Inputs:
*	op - macro name
*	ste - next available symbol table location
*	pte - end of symbol table
*
****************************************************************
*
Insert	start
	using Common

	jsr	FindMacro	find the macro
	bcs	rts	quit if successful
ad0	move4 ste,r0	save the position
	add4	ste,#7	update STE
	clc
	lda	op
	and	#$00FF
	adc	ste
	sta	ste
	bcc	ad1
	inc	ste+2
ad1	jsr	Overflow
	bcc	ad0
	jsr	Spin
	ldy	#2	create the entry
	lda	sTable
	sta	[r0]
	lda	sTable+2
	sta	[r0],Y
	lda	#0
	ldy	#4
	sta	[r0],Y
	move4 r0,sTable
	lda	op
	and	#$00FF
	tax
	inx
	ldy	#6
	short M
lb1	lda	op-6,Y
	sta	[r0],Y
	iny
	dbne	X,lb1
	long	M
rts	rts
	end

****************************************************************
*
*  IsDigit - Check A for numeric character
*
*  Inputs:
*	A - character to be checked
*
*  Outputs:
*	C - set if numeric, else clear
*
****************************************************************
*
IsDigit	start

	short M
	cmp	#'0'
	blt	rts
	cmp	#'9'+1
	blt	sec
	clc
rts	long	M
	rts

sec	sec
	long	M
	rts
	end

****************************************************************
*
*  IsMacro - See if the opcode is MACRO
*
*  Inputs:
*	op - op code
*
*  Outputs:
*	C - set if MACRO
*
****************************************************************
*
IsMacro	start
	using Common
	using Opcodes

	ldy	#0
lb1	lda	op+1,Y
	cmp	macro,Y
	bne	no
	iny
	iny
	cpy	#8
	bne	lb1
	sec
	rts

no	clc
	rts
	end

****************************************************************
*
*  IsMend - See if the opcode is MEND
*
*  Inputs:
*	op - op code
*
*  Outputs:
*	C - set if MEND
*
****************************************************************
*
IsMend	start
	using Common
	using Opcodes

	ldy	#0
lb1	lda	op+1,Y
	cmp	mend,Y
	bne	no
	iny
	iny
	cpy	#8
	bne	lb1
	sec
	rts

no	clc
	rts
	end

****************************************************************
*
*  LineOut - write a line to the output file
*
*  Inputs:
*	lptr - line pointer
*	crunch - crunch the line?
*
****************************************************************
*
LineOut	start
	using Common

	lda	crunch
	jne	OutCrunch
	brl	OutNormal
	end

****************************************************************
*
*  Main - main program
*
*  Inputs:
*	crunch - crunch the file
*	fname - file name to do macgen on
*
****************************************************************
*
Main	start
	using Common
	using FileNames

	ph4	#fname	expand devices
	jsr	ExpandDevice
	jsr	Open	open and read the file
mn1	jsr	NextLine	find the next line
	bcc	mn2
	jsr	CheckAbort
	jsr	GetOpcode	get the op code
	bcc	mn1
	jsr	CheckForMacros	check it for macros
	jsr	CopyAppend	do COPY and APPEND
	jsr	DoRename	do RENAME
	bra	mn1

mn2	inc	wcard	don't print macro list on this check
	jsr	Unresolved	check for unresolved macros
	dec	wcard
	bcs	mn3
	jsr	StopSpin
	putcr
	puts	#'No macros in the program',cr=t
	putcr
rts	rts

mn3	stz	scan	note that we aren't scanning
	jsr	Purge	get rid of source file
	jsr	CreateMacros	create the macro file
	brl	WriteFile	copy the file to its destination
	end

****************************************************************
*
*  Malloc - allocate memory
*
*  Inputs:
*	len - # of bytes to allocate
*
*  Outputs:
*	X-A - pointer to allocated memory; null if allocation failed
*
****************************************************************
*
Malloc	start
	using Common
ptr	equ	1	pointer to memory
hand	equ	5	handle of memory

	sub	(2:len),8

	stz	ptr	assume we will fail
	stz	ptr+2
	pha		reserve the memory
	pha
	pea	0
	ph2	len
	ph2	user_ID
	ph2	#$C010
	ph4	#0
	_NewHandle
	pl4	hand	pull the handle
	bcs	err	branch if there was an error
	ldy	#2	dereference the handle
	lda	[hand],Y
	sta	ptr+2
	lda	[hand]
	sta	ptr
	ora	ptr+2
	beq	err

lb1	ret	4:ptr	return

err	puts	#'Out of memory',errout=t,cr=t
	lda	#-1
	brl	Quit
	end

****************************************************************
*
*  NextLine - Form the Line
*
*  Inputs:
*	fptr - pointer to the line
*	flen - end of file pointer
*
*  Outputs:
*	fptr - pointer to the next line
*	lptr - pointer to the start of the line
*	aflag - 0
*	cflag - 0
*	C - clear if at end of file
*
****************************************************************
*
NextLine start
	using Common
	using FileNames
;
;  Reset the copy and append flags
;
	stz	aflag
	stz	cflag
;
;  Read a line from the file buffer.
;
lb1	move4 fptr,lptr	set the line pointer
	sub4	flen,fptr,r0	get the # of chars left in the file
	lda	r2	branch if at the end of the file
	beq	lb2
	ldx	#$FFFF
	bra	lb3
lb2	ldx	r0
	beq	cp1
lb3	ldy	#0	update the file pointer
	short M	find the end of the line
	lda	#RETURN
lb4	cmp	[fptr],Y
	beq	lb5
	iny
	dex
	bne	lb4
	long	M

	ph4	#fname	error - the file must end in a CR
	ph2	#1
	jsr	PrintFileName
	puts	#' must end in a RETURN.',cr=t,errout=t
	lda	#-1
	brl	Quit

lb5	long	M
	iny		update fptr and flen
	sty	r0
	stz	r2
	add4	fptr,r0
	sec		return TRUE
	rts
;
;  Reopen COPY files.
;
cp1	lda	copyPtr	if there are copied files then
	ora	copyPtr+2
	beq	cp3
	jsr	Purge	  purge this file
	ldy	#copyFptr	  fptr = copyPtr^.copyFptr
	lda	[copyPtr],Y
	sta	fptr
	iny
	iny
	lda	[copyPtr],Y
	sta	fptr+2
	ldy	#copyFlen	  flen = copyPtr^.copyFlen
	lda	[copyPtr],Y
	sta	flen
	iny
	iny
	lda	[copyPtr],Y
	sta	flen+2
         ph4	fname                      free(fname)
	jsr	Free
	add4	copyPtr,#copyName,r0	  fname = copyPtr^.copyName
	short M
	ldy	#fvarSize-1
cp2	lda	[r0],Y
	sta	fname,Y
	dey
	bpl	cp2
	long	M
	ph4	copyPtr	  temp = copyPtr
	ldy	#2	  copyPtr = copyPtr^.next
	lda	[copyPtr],Y	  free(temp)
	tax
	lda	[copyPtr]
	sta	copyPtr
	stx	copyPtr+2
	jsr	Free
	brl	lb1	  read the next line

cp3	clc		return false
	rts
	end

****************************************************************
*
*  NextToken - Read a token from the input line
*
*  Inputs:
*	inline - input line pointer
*
*  Outputs:
*	token - token read
*
****************************************************************
*
NextToken start
	using Common

	ldx	#0
lb1	lda	[inline]	skip leading blanks
	and	#$00FF
	beq	lb4
	inc4	inline
	cmp	#' '
	beq	lb1
	cmp	#TAB
	beq	lb1
	ldx	#0	X == # chars read
	bra	lb3
lb2	lda	[inline]	while (ch != ' ') && (ch != RETURN) do
	and	#$00FF
	beq	lb4
	inc4	inline
lb3	cmp	#' '
	beq	lb4
	cmp	#TAB
	beq	lb4
	short M	  save the character
	sta	token+2,X
	long	M
	inx
	bra	lb2	endwhile
lb4	txa		set token length
	short M
	sta	token+1
	long	M
	rts
	end

****************************************************************
*
*  OutCrunch - Crunch the Line
*
*  Inputs:
*	lptr - pointer to the line to be crunched
*	crunch - crunch flag
*
*  Outputs:
*	lptr - pointer to the crunched line
*	C - set if the line should be written
*
****************************************************************
*
OutCrunch start
	using Common
;
;  Skip the line if it is a comment
;
	lda	[lptr]	skip whole line comments
	and	#$00FF
	cmp	#'*'
	beq	cmt
	cmp	#'!'
	beq	cmt
	cmp	#';'
	beq	cmt
	ldy	#0	skip lines with all blanks
cm1	lda	[lptr],Y
	and	#$00FF
	cmp	#RETURN
	beq	cmt
	cmp	#' '
	beq	cm2
	cmp	#TAB
	bne	lb1
cm2	iny
	bra	cm1

cmt	clc
	rts
;
;  Write the label (if any)
;
lb1	stz	col	column zero
	move4 lptr,r0	set up our line pointer
lb2	lda	[r0]	write label characters
	and	#$00FF
	cmp	#RETURN
	beq	lb3
	cmp	#' '
	beq	lb3
	cmp	#TAB
	beq	lb3
	jsr	CharOut
	inc	col
	inc4	r0
	bra	lb2
lb3	anop
;
;  Write the opcode field
;
oc1	lda	[r0]	skip to the opcode
	and	#$00FF
	cmp	#' '
	beq	oc3
	cmp	#RETURN
	jeq	rt1
	cmp	#TAB
	bne	oc5
	ldx	col
oc2	inx
	lda	tabs,X
	beq	oc2
	dex
	stx	col
oc3	inc	col
	inc4	r0
	bra	oc1

oc5	lda	col	if col >= comcol then
	cmp	comcol
	blt	oc6
	sub4	r0,#2,r4	  if there is not exactly one space then
	lda	[r4]
	and	#$00FF
	cmp	#' '	    done with this line
	jeq	rt1
	cmp	#TAB
	jeq	rt1
	lda	[r4]
	and	#$FF00
	xba
	cmp	#' '
	jne	rt1

oc6	lda	#' '	write one space
	jsr	CharOut
oc7	lda	[r0]	write the opcode
	and	#$00FF
	cmp	#RETURN
	beq	oc8
	cmp	#' '
	beq	oc8
	cmp	#TAB
	beq	oc8
	jsr	CharOut
	inc	col
	inc4	r0
	bra	oc7
oc8	anop
;
;  Write the operand field
;
op1	lda	[r0]	skip to the operand
	and	#$00FF
	cmp	#' '
	beq	op3
	cmp	#RETURN
	jeq	rt1
	cmp	#TAB
	bne	op4
	ldx	col
op2	inx
	lda	tabs,X
	beq	op2
	dex
	stx	col
op3	inc	col
	inc4	r0
	bra	op1

op4	lda	col	if col >= comcol then
	cmp	comcol
	blt	op5
	sub4	r0,#2,r4	  if there is not exactly one space then
	lda	[r4]
	and	#$00FF
	cmp	#' '	    done with this line
	beq	rt1
	cmp	#TAB
	beq	rt1
	lda	[r4]
	and	#$FF00
	xba
	cmp	#' '
	bne	rt1

op5	lda	#' '	write one space
	jsr	CharOut

	stz	quote	not processing a string, yet
op6	lda	[r0]	get a character
	and	#$00FF	done if we hit a return
	cmp	#RETURN
	beq	op12
	cmp	#' '	if this is whitespace then
	beq	op7
	cmp	#TAB
	bne	op8
op7	ldx	quote	  if we are processing a string then
	bne	op11	    write the character
	bra	rt1	  else we are done
op8	cmp	#''''	if this is a quote then
	beq	op9
	cmp	#'"'
	bne	op11
op9	cmp	quote	  if it matches the quote character then
	bne	op10
	stz	quote	    stop processing the string
	bra	op11	  else
op10	sta	quote	    start processing a string
op11	jsr	CharOut	write the character
	inc4	r0	next character
	bra	op6
op12	anop
;
;  Write the trailing RETURN
;
rt1	lda	#RETURN
	jsr	CharOut
	rts
;
;  Local data
;
quote	ds	2	quote char/string scan flag
col	ds	2	column number
	end

****************************************************************
*
*  OutNormal - write a line to the output file
*
*  Inputs:
*	lptr - line pointer
*
****************************************************************
*
OutNormal start
	using Common

	ldy	#0	write the line
lb1	lda	[lptr],Y
	and	#$00FF
	jsr	CharOut
	lda	[lptr],Y
	iny
	and	#$00FF
	cmp	#RETURN
	bne	lb1
	rts
	end

****************************************************************
*
*  OutFile - Get an output file name
*
*  Outputs:
*	oname - name of output file
*
****************************************************************
*
OutFile	start
	using FileNames
	using Common

	strlen token	if there are no characters then
	bne	lb1b
	jsr	StopSpin
	putcr
	puts	#'Output file name: '	  read a file name
	jsr	GetLine
lb1a	jsr	NextToken	read a file name into TOKEN
	strlen token	quit if the read failed
	bne	lb1b
	lda	#0
	brl	Quit

lb1b	ph4	#token	save the file name
	ph4	#oname
	jsr	CopyFileName
	jsr	NextToken	next token
	rts
	end

****************************************************************
*
*  Overflow - Check for overflow
*
*  Inputs:
*	ste - end of symbol table
*	pte - max allowed STE
*
*  Outputs:
*	C - clear if table grown
*
****************************************************************
*
Overflow start
	using Common

	cmpl	pte,ste	see if the table is overfilled
	bge	ok
	ph2	#symSize	yes -> get a new table
	jsr	Malloc
	sta	ste
	stx	ste+2
	add4	ste,#symSize,pte	mark the end
	clc
	rts

ok	sec
	rts
	end

****************************************************************
*
*  Search - Search a macro file
*
*  Inputs:
*	stable - start of symbol table
*	ste - end of symbol table
*
****************************************************************
*
Search	start
	using Common
;
;  Find a macro
;
lb1	jsr	NextLine	form the line
	bcs	lb2
rts	rts

lb2	jsr	GetOpcode	get the op code
	bcc	lb1
	jsr	IsMacro	see if its a macro
	bcc	lb1
	jsr	CheckAbort	check for user abort
	move4 lptr,mptr	save the macro line pointer
	jsr	NextLine	get the definition line
	bcc	rts
	jsr	GetOpcode
	bcc	lb1
	jsr	FindMacro	see if its a needed macro
	bcc	lb1
	ldy	#disp_found
	lda	[r0],Y
	bne	lb1
	lda	#1	yes - mark it as found
	sta	[r0],Y
	jsr	Spin	spin the spinner
	ph4	lptr	output macro statement
	move4 mptr,lptr
	jsr	LineOut
	pl4	lptr
	jsr	LineOut	output the model line
lb3	jsr	NextLine	output the rest of the macro
	bcc	rts
	jsr	LineOut
	jsr	GetOpcode
	bcc	lb3
	jsr	CheckForMacros
	jsr	IsMend
	bcc	lb3
	brl	lb1

mptr	ds	4	ptr to macro statement
	end

****************************************************************
*
*  Shift - convert to upper-case
*
*  Inputs:
*	A - character to convert
*
*  Outputs:
*	A - upper-case character
*
****************************************************************
*
Shift	start

	php
	short M
	cmp	#'a'
	blt	rts
	cmp	#'z'+1
	bge	rts
	and	#%01011111
rts	plp
	rts

	longa on
	end

****************************************************************
*
*  Spin - spin the spinner
*
*  Notes: Starts the spinner if it is not already in use.
*
****************************************************************
*
Spin	start
	using	SpinnerCommon

	lda	spinning	if not spinning then
	bne	lb1
	inc	spinning	  spinning := true
	lda	#spinSpeed	  set the timer
	sta	spinCount

lb1	dec	spinCount	if --spinCount <> 0 then
	bne	lb3
	lda	#spinSpeed	  spinCount := spinSpeed
	sta	spinCount
	dec	spinDisp	  spinDisp--
	bpl	lb2	  if spinDisp < 0 then
	lda	#3	    spinDisp := 3
	sta	spinDisp
lb2	ldx	spinDisp	  write the spin character
	lda	spinner,X
	sta	ch
	OSConsoleOut coRec
	lda 	#8
	sta	ch
	OSConsoleOut coRec
lb3	rts

coRec	dc	i'1'
ch	ds	2
	end

****************************************************************
*
*  StopSpin - stop the spinner
*
*  Notes: The call is safe, and ignored, if the spinner is inactive
*
****************************************************************
*
StopSpin	start
	using	SpinnerCommon

	lda	spinning
	beq	lb1
	stz	spinning
	lda 	#' '
	sta	ch
	OSConsoleOut coRec
	lda 	#8
	sta	ch
	OSConsoleOut coRec
lb1	rts

coRec	dc	i'1'
ch	ds	2
	end

****************************************************************
*
*  Unresolved - check for unresolved macros
*
*  Outputs:
*	C - set if there are unresolved macros, else clear
*
****************************************************************
*
Unresolved start
	using Common
;
;  See if there are any unresolved macros.
;
	move4 sTable,r0
lb1	lda	r0
	ora	r2
	beq	rts
	ldy	#disp_found
	lda	[r0],Y
	beq	qt1

lb3	ldy	#2
	lda	[r0]
	tax
	lda	[r0],Y
	sta	r2
	stx	r0
	bra	lb1

rts	clc
	rts
;
;  Quit if there is a file name in the input buffer.
;
qt1	strlen token
	bne	qt2
;
;  Quit if a wildcard search is in progress.
;
	lda	wcard
	beq	un1
qt2	sec
	rts
;
;  Print the list of unresolved macros.
;
un1	jsr	StopSpin
	putcr
	puts	#'Unresolved macros: ',cr=t
	putcr
	la	r4,79
un2	lda	r0
	ora	r2
	jeq	un5
	ldy	#disp_found
	lda	[r0],Y
	jne	un4
	add4	r0,#disp_name,r12
	lda	[r12]
	and	#$00FF
	sta	r6
	cmp	r4
	blt	un3
	putcr
	la	r4,79
un3	sub2	r4,r6
	dec4	r12
	puts	[r12]
	dec	r4
	bmi	un3b
	dec	r4
	bmi	un3b
	puts	#'  '
	bra	un4
un3b	putcr
	la	r4,79
un4	ldy	#2
	lda	[r0]
	tax
	lda	[r0],Y
	sta	r2
	stx	r0
	brl	un2

un5	putcr
	putcr
	sec
	rts
	end
