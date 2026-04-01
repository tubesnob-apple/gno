	keep	obj/file
	mcopy file.mac
	longa off
	longi off
****************************************************************
*
*  File
*
*  The subroutines in this module localize all I/O operations.
*  All shell and GS/OS calls are done in this module.
*
****************************************************************
	copy	directPage
****************************************************************
*
*  FileCommon - Common data area
*
****************************************************************
*
FileCommon privdata
	using Common
;
;  Language interface info
;
LInfo	dc	i'11'
sfile	ds	4	source file name
dfile	ds	4	output file name
parms	ds	4	parameter list
ldep	dc	a4'dummy'	unused language dependent info
flags	ds	16	language interface flags

dummy	dc	i'4,0'	unused GetLInfo output string parameter
;
;  General purpose file control blocks
;
kpinfo	dc	i'3'	get file info DCB
kp_name	ds	4
kp_access ds	2
kp_typ	ds	2

info_DCB dc	i'4'	get info DCB
info_name ds	4
	ds	2
	ds	2
lang	ds	4

ff_DCB	dc	i'14'	FastFile DCB
ff_action ds	2
ff_index ds	2
ff_flags ds	2
ff_filehandle ds 4
ff_pathname ds 4
ff_access ds	2
ff_filetype ds 2
ff_auxtype ds	4
ff_storagetype ds 2
ff_create ds	8
ff_mod	ds	8
ff_option ds	4
ff_filelength ds 4
ff_blocksused ds 4
;
;  File names
;
fp1	gequ	$A0	temp file name pointers
fp2	gequ	$A4

!			These buffers are allocated once, when
!			GetLInfo is used.  They should not be
!			disposed of.
fname	gequ	$A8	current file name
subs	gequ	$AC	list of partial assembly names
kname	gequ	$B0	keep file name

!			These pointers are initialized to zero.
!			Before use, dispose of any old contents.
name	gequ	$B4	misc use file name
ckname	gequ	$B8	current keep name
tkname	gequ	$BC	temp keep name
mfname	gequ	$C0	currently open macro file name
lastName gequ	$C4	last file name (for OPEN calls)
aname	gequ	$C8	fname at the start of pass 1

mlibn	ds	nameBuff*4	macro library names
amlibn	ds	nameBuff*4	macro library names at the start of pas 1
;
;  Misc variables
;
kltr	ds	1	keep file suffix letter
	end

****************************************************************
*
*  SpinnerCommon - common data area for the spinner subroutines
*
****************************************************************
*
SpinnerCommon privdata

spinSpeed equ	12	calls before one spinner move

spinning dc	i'0'	are we spinning now?
spinDisp dc	i'0'	disp to the spinner character
spinCount ds	2	spin loop counter

spinner	dc	i1'$7C,$2F,$2D,$5C'	spinner characters
	end

****************************************************************
*
*  AssembleCheck - Skips to the next subroutine that needs assembly.
*
*  inputs:
*	subs - list of subroutine names to be assembled,
*		separated by RETURNs and ending with $00.
*
*  outputs:
*	C - set if a subroutine was found that needs assembly
*
****************************************************************
*
AssembleCheck start
	using Common
	using FileCommon
	using OpCode
;
;  Return immediately if this is not a partial assembly.
;
	ldy	#2
	lda	[subs],Y
	iny
	ora	[subs],Y
	bne	cl1
	sec
	rts
;
;  Check this line.
;
cl1	lla	str,$1000	initialize the location counter
	jsr	FORML	form the line
	lda	op	branch if not END
	cmp	#iEnd
	bne	cl3
	lm	endf,#1	mark END as found
	long	M	clear ORGVAL, ALIGNVAL
	stz	orgval
	stz	orgval+2
	stz	alignval
	stz	alignval+2
	short M
	bra	cl6

cl3	ldx	endf	do ORG, ALIGN if between starts
	beq	cl4
	cmp	#iOrg
	beq	aa1
	cmp	#iAlign
	beq	aa1

cl4	cmp	#iStart	do special handling for START and DATA
	beq	sd1
	cmp	#iData
	beq	sd1
	cmp	#iPrivate
	beq	sd1
	cmp	#iPrivdata
	beq	sd1

	ldx	#numpart-1	branch if this is a line that needs
cl5	cmp	part,X	 assembly
	beq	aa1
	dbpl	X,cl5

cl6	jsr	SINTP	next line
cl7	jsr	SINLN
	bcc	cl8
	brl	cl1
cl8	clc		end of assembly
	rts
;
;   These lines are always assembled:
;      APPEND	COPY    ERR     EXPAND
;      FPLEN	GEN     GEQU    KEEP
;      LIST	MCOPY   MDROP   MERR
;      MLOAD	MSB     SYMBOL  PRINTER
;      CASE	OBJCASE
;
aa1	tax		save op code
	lda	endf	save endf
	pha
	cpx	#iGequ	for GEQU, insure ENDF = 0
	bne	aa2
	dec	endf
aa2	jsr	FPAS3	do it
	pla		restore ENDF
	sta	endf
	bcc	cl8	handle errors, etc
	lda	op
	cmp	#iAppend
	beq	cl7
	cmp	#iCopy
	beq	cl7
	bra	cl6
;
;  START or DATA - see if it is in the list.
;
sd1	stz	endf
	lda	nstrt	set the start flag
	beq	sd1a
	bpl	sd1b
sd1a	inc	nstrt
sd1b	ldy	#0	get the label
	jsr	SLABL
	bcs	cl6
	lda	fCase	if not case sensitive then
	bne	sd1d
	ldy	lname	  convert to uppercase
sd1c	lda	lname,Y
	tax
	lda	Uppercase,X
	sta	lname,Y
	dbne	Y,sd1c
sd1d	stz	nlst	initialize for a search
	long	I,M
	la	disp,4
	ldy	#2
	lda	[subs],Y
	inc	A
	inc	A
	inc	A
	sta	len
	lla	r0,handle	set handle to LLNAME
	short M
sd2	ldy	disp
	ldx	#0
	inc	nlst
sd3	lda	[subs],Y	move a label from the list to LLNAME
	cmp	#' '
	beq	sd4
	inx
	sta	llname,X
	cpy	len
	bge	sd4
	iny
	cpx	#255
	blt	sd3
sd4	iny
	sty	disp
	txa		make sure there are an odd # of chars
	lsr	A
	bcs	sd4a
	inx
	lda	#' '
	sta	llname,X
sd4a	short I
	stx	llname
	jsr	SCPL0	check for a match
	beq	sd5
	long	I
	ldx	disp	next label
	cpx	len
	ble	sd2
	short I
	lda	nlst	not in list
	cmp	nsfnd
	jne	cl6
	clc
	rts
;
;  START or DATA found.
;
sd5	inc	nsfnd
	inc	endf
	lda	kflag	quit if KEEP is off
	beq	sd9
	lda	nstrt	open a root file if this is the first
	bne	sd5a	 subroutine
	lda	kflag
	cmp	#3
	beq	sd9
	bra	sd8
sd5a	cmp	#1
	bne	sd9
	inc	nstrt

sd6	lda	kflag	close the old file and open a new one
	cmp	#3
	beq	sd9
	jsr	SaveFile
	lm	kflag,#3

sd7	jsr	KeepSuffix	find the proper suffix and open a new
sd8	jsr	SKINT	 file
sd9	sec
	rts

disp	ds	2	disp into subs array
len	ds	2	length of the subs array
	end

****************************************************************
*
*  ChOut - Write a character to the console output device
*
*  Inputs:
*	A - character to write
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
ChOut	start

	php
	long	I,M
	sta	ch
	OSConsoleOut cout_DCB
	plp
	rts

cout_DCB dc	i'1'
ch	ds	2

	longa off
	longi off
	end

****************************************************************
*
*  CopyFile - open a file for the COPY or APPEND directive
*
*  Inputs:
*	name - name of the file to open
*	fname - current file name
*
*  Outputs:
*	fname - name of the new file
*	lastName - name of the previous file
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
CopyFile start
	using FileCommon

	php
	long	I,M
	move4 name,info_name	make sure the file exists
	OSGet_File_Info info_DCB
	bcs	err
	ph4	lastName	free any old lastName
	jsr	Free
	ldy	#2	get a file name buffer
	lda	[fname],Y
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	lastname
	stx	lastname+2
	add4	fname,#2,fp1	copy the name
	move4 lastname,fp2
	jsr	MoveName
	move4 name,fp1	move name to fname
	add4	fname,#2,fp2
	jsr	MoveName
	jsr	Open
	bcs	err
	plp
	rts

err	jmp	Terr4	flag a file load error

	longa off
	longi off
	end

****************************************************************
*
*  DeleteFile - delete any existing file
*
*  Inputs:
*	tkname - name of the file to check for
*
*  Outputs:
*	C - set if the keep file cannot be opened
*
****************************************************************
*
DeleteFile start
	using FileCommon

	long	I,M
	move4 tkname,kp_name	see if there is already a file by that
	OSGet_File_Info kpInfo	   name
	short I,M
	bcc	lb1
	cmp	#$46
	beq	lb2
	bra	lb3

lb1	lda	kp_access
	and	#%10000000
	beq	lb3
	long	I,M
	move4 tkname,kpname	  yes -> delete it
	OSDestroy kpdest
	short I,M
	bcs	lb3
lb2	clc		successful return
	rts

lb3	sec		error return
	rts

kpdest	dc	i'1'	destroy DCB
kpname	ds	4
	end

****************************************************************
*
*  DeleteObj - delete the family of OBJ files
*
*  Inputs:
*	kname - keep name
*
****************************************************************
*
DeleteObj start
	using FileCommon

	jsr	RootName	form root file name
	long	I,M	make sure file is an object file
	move4 tkname,kp_name
	OSGet_File_Info kpinfo
	short I,M
	bcs	lb1
	jsr	CkFile	check the file
	long	I,M	delete it
	move4 tkname,dl_name
	OSDestroy dl_DCB
	short I,M
lb1	jsr	KeepName	form next dot file name
	long	I,M	make sure file is an object file
	move4 tkname,kp_name
	OSGet_File_Info kpinfo
	short I,M
	bcs	rts
	jsr	CkFile	check the file
	long	I,M	delete it
	move4 tkname,dl_name
	OSDestroy dl_DCB
	short I,M
	cmp	#0	quit if error - indicates all are gone
	beq	lb1
rts	rts
;
;  Make sure that the file type is in [$B1..$BF]
;
CkFile	anop
	lda	kp_typ
	cmp	#$B1
	blt	ckerr
	cmp	#$BF+1
	blt	ckrts
ckerr	brl	Terr10
ckrts	rts
;
;  Local data areas
;
dl_DCB	dc	i'1'
dl_name	ds	4
	end

****************************************************************
*
*  DetectRedirection - see if output has been redirected
*
*  Outputs:
*	redirect - set to true (non-zero) if output is redirected
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
DetectRedirection start
	using Common

	php
	stz	redirect
	long	I,M
	OSDirection dirDCB
	short I,M
	lda	dirRef
	beq	lb1
	inc	redirect
lb1	plp
	rts

dirDCB	dc	i'2'
	dc	i'1'
dirRef	ds	2
	end

****************************************************************
*
*  DuplicateName - Checks to See if NAME is Already in the Macro
*	Library
*
*  inputs:
*	name - name to check
*	mlibn - macro library names
*	mlib - macro library flags
*
*  outputs:
*	X - number of macro file, if found
*	C - set if found, else clear
*
****************************************************************
*
DuplicateName start
	using Common
	using FileCommon

	long	I,M
	la	r0,nameBuff*3	init MLIBN dis
	short M
	ldx	#3	lib number
mc1	lda	mlib,X	compare name
	beq	mc2
	long	M
	ldy	r0
	lda	mlibn,Y
	sta	fp1
	lda	mlibn+2,Y
	sta	fp1+2
	lda	[name]
	tay
	iny
	short M
mc1a	lda	[fp1],Y
	cmp	[name],Y
	bne	mc2
	dbpl	Y,mc1a
	short I
	sec		found
	rts

mc2	sub2	r0,#nameBuff	not this one; loop
mc3	dbpl	X,mc1
	short I
	clc		not found
	rts
	end

****************************************************************
*
*  ErrorLInfo - set LIfno for an error exit
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
ErrorLInfo start
	using Common
	using FileCommon

	php
	short M
	stz	lops	clear the LOPS field
	long	I,M	set the language info
	move	merr,flags,#l:flags
	OSSet_LInfo LInfo
	plp
	rts

	longa off
	longi off
	end

****************************************************************
*
*  ErrorLInfo1 - set LIfno for an error exit; shell 1.0 call
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
ErrorLInfo1 start
	using Common
	using FileCommon

	php
	long	I,M	set the language info
	Set_LInfo LInfo
	plp
	rts

LInfo	anop
sfile	dc	a4'file'	source file name
dfile	dc	a4'file'	output file name
parms	dc	a4'file'	parameter list
ldep	dc	a4'file'	unused language dependent info
merr	dc	i1'0'	max error level allowed
merrf	dc	i1'1'	max error level found
lops	dc	i1'0'	operations flag
kflag	dc	i1'0'	keep flag
minus_f	dc	i4'0'	minus flags
plus_f	dc	i4'0'	plus flags
org	dc	i4'0'	origin

file	dc	i1'0'	fake file name

	longa off
	longi off
	end

****************************************************************
*
*  FileInit1 - initialize file variables
*
*  This subroutine is called before any other calls to this
*  module.
*
****************************************************************
*
FileInit1 start
	using FileCommon

	long	I,M	clear the name buffers
	stz	name
	stz	name+2
	stz	ckname
	stz	ckname+2
	stz	tkname
	stz	tkname+2
	stz	mfname
	stz	mfname+2
	stz	lastname
	stz	lastname+2
	stz	aname
	stz	aname+2
	move	#0,mlibn,#l:mlibn
	move	#0,amlibn,#l:amlibn
	short I,M
	rts
	end

****************************************************************
*
*  FileInit2 - initialize file variables
*
*  This subroutine is called after a call to GetLInfo to
*  handle file related disk activities associated with
*  startup.
*
****************************************************************
*
FileInit2 start
	using FileCommon
	using Common
	using KeepCom

	lda	kflag	if output is to be produced and
	beq	lb4
	dec	A	  not a second language call then
	bne	lb1
	jsr	PartialNames	    if a partial assembly then
	bcs	lb4
	jsr	DeleteObj	      delete old object modules
	bra	lb3	    else
lb1	dec	A	      if suffix = 2 then
	bne	lb2
	lm	kflag,#3		next file is a dot file
	lm	kltr,#'A'		form .A file
	bra	lb3	      else
lb2	jsr	KeepSuffix		form keep suffix
	lda	kltr
	cmp	#'A'
	bge	lb3
	inc	kltr
lb3	jsr	SKINT	    initialize for keep
lb4	rts
	end

****************************************************************
*
*  FormError - Form the error message
*
*  inputs:
*	fname - file name
*
****************************************************************
*
FormError start
	using Common
	using FileCommon

	print2 'Error '
	ldy	#24-1	clear the line
	lda	#' '
hd1	sta	errm,Y
	dbne	Y,hd1

	long	I,M
	ldy	#2	strip of file name
	lda	[fname],Y
	beq	rts
	inc	A
	inc	A
	inc	A
	sta	len
	ldx	#15
	tay
	iny
	iny
	iny
	short M
hd2	lda	[fname],Y
	cmp	#'/'
	beq	hd3
	cmp	#':'
	beq	hd3
	dex
	beq	hd3
	dbne	Y,hd2
hd3	ldx	#0
hd4	iny
	lda	[fname],Y
	sta	errm,X
	inx
	cpy	len
	blt	hd4
	short I

	jsr	SCPLN	compute the line number
	stz	m1l+2
	stz	m1l+3
	jsr	SCVDC
	ldx	#0
hd5	lda	string,X
	cmp	#'0'
	bne	hd6
	inx
	cpx	#9
	bne	hd5

hd6	ldy	#16
hd7	lda	string,X
	sta	errm,Y
	iny
	inx
	cpx	#10
	bne	hd7

	lda	#22
	sta	mlen
	la	maddr,errm
	jsr	SRITE
	dc	H'40'
mlen	ds	1
maddr	ds	2
rts	short I,M
	rts

len	ds	2	length of the file name
errm	ds	24
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
*	This subroutine must be called in long mode.
*
****************************************************************
*
Free	start
	longi on
	longa on

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

	longi off
	longa off
	end

****************************************************************
*
*  GetLanguage - get the language number for a file
*
*  Inputs:
*	name - name of the file
*
*  Outputs:
*	A - language number; 0 for no file
*
*  Notes:
*	This subroutine must be called in long mode.
*
****************************************************************
*
GetLanguage start
	using FileCommon
	longa on
	longi on

	stz	lang
	move4 name,info_name
	OSGet_File_Info info_DCB
	lda	lang
	rts

	longa off
	longi off
	end

****************************************************************
*
*  GetLInfo - get the command line information
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
GetLinfo start
	using Common
	using FileCommon

	php
	long	I,M
	ph2	#maxName+4	set the initial name buffers
	jsr	Malloc
	sta	sfile
	stx	sfile+2
	sta	fname
	stx	fname+2
	ph2	#maxName+4
	jsr	Malloc
	sta	dfile
	stx	dfile+2
	sta	kname
	stx	kname+2
	ph2	#maxName+4
	jsr	Malloc
	sta	parms
	stx	parms+2
	sta	subs
	stx	subs+2
	lda	#maxName+4
	sta	[fname]	set the buffer sizes
	sta	[kname]
	sta	[subs]
	lla	ldep,dummy	set up the dummy buffer
	OSGet_LInfo LInfo	retrieve the inputs
	move	flags,merr,#l:flags
	add4	kname,#2,sfile	reset the addresses for the file names
	add4	kname,#2,dfile	 and parameters
	add4	subs,#2,parms
	lla	ldep,dummy+2
	short I,M
	lda	kflag	if KEEP was specified, set KEEPSPEC
	beq	kp1
	inc	keepSpec
kp1	long	I,M	init the abs addr
	move4 ORG,absAddr
	plp
	rts

	longa off
	longi off
	end

****************************************************************
*
*  GetTabs - Get the tab line
*
*  Inputs:
*	LANGNM - language number to read
*
*  Outputs:
*	tabs - tab line
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
GetTabs	start
	using Common
	using FileCommon

	php
	long	I,M
	move	#0,tabs,#256	initialize tab line
	ldy	#7	a tab every 8 spaces
lb4	lda	#1
	sta	tabs,Y
	tya
	clc
	adc	#8
	tay
	cpy	#255
	blt	lb4
	ldy	#79	set end of line marker
	lda	#2
	sta	tabs,Y

	lla	ff_PathName,systabs	load the tab file
	stz	ff_Action
	lda	#$C000
	sta	ff_Flags
	OSFastFile ff_DCB
	bcc	gt1
rts	plp		ok if no tab file use defaults
	rts

gt1	move4 ff_FileHandle,r4	dereference the handle
	ldy	#2
	lda	[r4]
	sta	r0
	lda	[r4],Y
	sta	r2
	jsr	FindLn	find the tab line
	jcc	rt1
	jsr	Skip	skip the editor flags
;
;  Get the tab line
;
	ldy	#0	read in the tab line
gt3	phy
	jsr	GetC
	ply
	bcs	gt4
	and	#$0F
	cmp	#RETURN
	beq	gt4
	short M
	sta	tabs,Y
	long	M
	iny
	cpy	#256
	blt	gt3
gt4	short M
	lda	#2
	sta	tabs,Y
	long	M
rt1	lda	#7	purge the file
	sta	ff_Action
	lla	ff_PathName,systabs
	OSFastFile ff_DCB
	plp
	rts
;
;  Locatate the correct tab line
;
FindLn	stz	num
fn1	jsr	GetC	Get a decimal number
	bcs	err
	short I,M
	jsr	SNMID
	long	I,M
	bcc	fn2
	and	#$000F
	pha
	lda	num
	ldx	#10
	jsl	~mul2
	clc
	adc	1,S
	plx
	sta	num
	bra	fn1

fn2	cmp	#RETURN	make sure this is the end of line
	beq	fn3
err	clc
	rts

fn3	lda	num	see if we found the tab line
	cmp	LANGNM
	beq	fn4
	jsr	Skip	skip past settings
	jsr	Skip	skip past tab line
	brl	FindLn	next tab
fn4	sec
	rts
;
;  Skip to next line
;
Skip	jsr	GetC
	bcs	srts
	cmp	#RETURN
	bne	Skip
srts	rts
;
;  GetC - get a character; return C=1 if at end of file
;
GetC	lda	ff_FileLength
	beq	sec
	dec	ff_FileLength
	lda	[r0]
	inc4	r0
	and	#$00FF
	clc
	rts

sec	sec
	rts

num	ds	2
systabs	dos	'15/systabs'

	longa off
	longi off
	end

****************************************************************
*
*  KeepName - Update the Keep Name
*
*  inputs:
*	kname - base keep name
*	kltr - suffix letter to use
*
*  outputs:
*	ckname - current keep file name
*	kltr - incremented
*	tkname - keep file name
*
****************************************************************
*
KeepName start
	using FileCommon

	long	I,M
	ph4	tkname	free old buffers
	jsr	Free
	ph4	ckname
	jsr	Free
	add4	kname,#2,fp1	get new buffers
	lda	[fp1]
	clc
	adc	#4
	pha
	pha
	jsr	Malloc
	sta	tkname
	stx	tkname+2
	jsr	Malloc
	sta	ckname
	stx	ckname+2
	sta	fp2	copy kname to ckname
	stx	fp2+2
	jsr	MoveName
	move4 tkname,fp2	copy fname to tkname
	jsr	MoveName

	lda	[tkname]	append .kltr to the names
	inc	A
	inc	A
	sta	[tkname]
	sta	[ckname]
	tay
	short M
kn1	lda	#'.'
	sta	[tkname],Y
	sta	[ckname],Y
	iny
	lda	kltr
	sta	[tkname],Y
	sta	[ckname],Y
	inc	kltr	++kltr
	short I
	rts
	end

****************************************************************
*
*  KeepSuffix - Find Keep Suffix
*
*  Scans the output disk to determine the proper keep file
*  suffix for a partial assembly.
*
*  inputs:
*	kname - name root
*
*  outputs:
*	kltr - first available suffix
*
****************************************************************
*
KeepSuffix start
	using FileCommon

	lm	kltr,#'A'
ks1	jsr	KeepName
	long	I,M
	move4 tkname,kp_name
	OSGet_File_Info kpinfo
	short I,M
	bcc	ks1
	dec	kltr
	rts
	end

****************************************************************
*
*  LoadLastFile - load the file that copied this one
*
*  Inputs:
*	copyDepth - copy depth counter
*
*  Outputs:
*	fname name of the file
*	ap - pointer to the next source line
*	line - next source line
*
****************************************************************
*
LoadLastFile start
	using Common
	using FileCommon

	dec	copyDepth	note the exit
	move4 cbuff,m1l	recover the copy buffer
	ldy	#nameBuff+12
cp2	lda	[m1l],Y
	sta	work,Y
	dbpl	Y,cp2
	long	I,M
	ph4	lastname	save the current file name
	jsr	Free
	add4	fname,#2,fp1
	lda	[fp1]
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	lastname
	stx	lastname+2
	sta	fp2
	stx	fp2+2
	jsr	MoveName
	move4 work,fp1	restore the file name
	add4	fname,#2,fp2
	jsr	MoveName
	ph4	work	free the file name buffer
	jsr	Free
	short I,M
	jsr	Open	open the new source file
	add4	work+nameBuff+4,srcbuff,ap restore AP - it was used by Open
	lda	pass	if (PASS=1)
	cmp	#1
	bne	cp3
	lda	work+nameBuff+12	 and (copy done outside of seg)
	beq	cp3
	lda	endf	 and (inside a segment now)
	beq	cp4	 then don't wipe the copy buffer
cp3	long	I,M
	dispose cBuffHand	release the copy buffer
	move4 work+nameBuff,cbuff	restore the copy dependent variables
	move4 work+nameBuff+8,cBuffHand
	short I,M
cp4	jsr	SINTP	incriment to the next line
	rts
	end

****************************************************************
*
*  LoadMacros - Load a Macro Library
*
*  inputs:
*	X - number of macro file to load
*	MIN - current macro file number
*	MACRO - macro file
*
*  outputs:
*	MHASH - hash table for the macro table
*	MIN - set to X
*	MAC_REF - opened file's reference number
*
****************************************************************
*
LoadMacros start
	using Common
	using OpCode
	using MacDat
	using FileCommon
;
;  Find and open the file.
;
	lda	min	save MIN
	stx	min
	tax		if there is an old file, remove it
	bmi	ml1
	jsr	SMDRP

ml1	long	I,M
	move4 ap,ltp	save pointer to current line
	move4 srcend,lsrcend	save the end of the source file
	la	r0,mlibn	recover the macro file name
	short I,M
	ldx	min
	beq	ml3
ml2	add2	r0,#nameBuff
	dbne	X,ml2
ml3	jsr	SwapNames	swap macro and source info
	lda	#1
	sta	macroFile
	long	I,M
	ph4	mfname
	jsr	Free
	add4	fname,#2,fp1
	lda	[fp1]
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	mfname
	stx	mfname+2
	sta	fp2
	stx	fp2+2
	jsr	MoveName
	ph4	lastname
	jsr	Free
	stz	lastname
	stz	lastname+2
	short I,M
	jsr	Open	open and read the macro file
	php
	stz	macroFile
	jsr	SwapNames	swap the info again
	plp		(carry set by OPEN if read error
	bcc	sc1	 occurred)
	stz	work	abort the assembly with a null error
	la	r0,work	 message
	brl	SABORT
;
;  Save critical variables.
;
sc1	move4 macbuff,ap
	move4 macend,srcend
	lm	tsource,source
	lm	source,#1
	lm	tlerr,lerr
	lm	tmerr,err
	AIF	.NOT.DEBUG,.SMLODA
	stz	trace
.SMLODA
;
;  Insert macro names in table.
;
mn2	jsr	SRLIN	find macro
	jsr	SOPFN
	bcc	mn2a
	jsr	SOPCD
	lda	op
	cmp	#iMacro
	jne	mn6
	jsr	SINTP	get macro name
	lda	ap+2
	cmp	srcend+2
	bne	se1
	lda	ap+1
	cmp	srcend+1
	bne	se1
	lda	ap
	cmp	srcend
se1	jge	mn7
	jsr	SOPFN
mn2a	jcc	mn6
	ldy	oplen	form a symbol
	tya
	lsr	A
	bcs	mn2b
	iny
	lda	#' '
	sta	string-1,Y
mn2b	sty	lname
mn2c	lda	string-1,Y
	sta	lname,Y
	dbne	Y,mn2c
	jsr	SHASH	get hash table address
	long	I,M
	add4	r0,mhash,r4
	clc		make sure there's room
	lda	lname
	and	#$FF
	adc	#9
	ldx	#2
	jsr	SROOM
	lda	ap	place TP in table
	sta	[r0]
	ldy	#2
	lda	ap+2
	sta	[r0],Y
	iny		place entry in hash table chain
	iny
	lda	[r4]
	sta	[r0],Y
	lda	r0
	sta	[r4]
	ldy	#2
	lda	[r4],Y
	tax
	lda	r2
	sta	[r4],Y
	ldy	#6
	txa
	sta	[r0],Y
	ldy	#8	place name in table
	lda	lname
	and	#$FF
	tax
	short M
mn3	lda	lname-8,Y
	sta	[r0],Y
	iny
	dbpl	X,mn3
	short I
mn6	jsr	SINTP	loop for next line
	lda	ap+2
	cmp	srcend+2
	bne	mn6a
	lda	ap+1
	cmp	srcend+1
	bne	mn6a
	lda	ap
	cmp	srcend
mn6a	jlt	mn2

mn7	move4 ltp,ap	restore old line
	move4 lsrcend,srcend
	lm	source,tsource
	lm	lerr,tlerr
	lm	err,tmerr
	AIF	.NOT.DEBUG,.SMLODB
	lm	trace,#1
.SMLODB
	jsr	SRLIN
	jsr	FORML
	rts

ltp	ds	4	local TP storage
lsrcend	ds	4	local SRCEND
tsource	ds	1	local SOURCE
tlerr	ds	1
tmerr	ds	1
	end

****************************************************************
*
*  MacroPurge - purge a macro file
*
*  Inputs:
*	mfname - file name to purge
*
*  Notes:
*	This subroutine must be called in long mode.
*
****************************************************************
*
MacroPurge start
	using FileCommon
	longa on
	longi on

	lda	mfName
	ora	mfName+2
	beq	ff1
	lda	[mfName]
	beq	ff1
	lda	#7
	sta	ff_action
	move4 mfname,ff_pathname
	OSFastFile ff_DCB
ff1	rts

	longa off
	longi off
	end

****************************************************************
*
*  Malloc - allocate memory
*
*  Inputs:
*	len - # of bytes to allocate
*
*  Outputs:
*	X-A - pointer to allocated memory
*
*  Notes:
*	Flags a terminal error and quits if there is not
*	emough memory.
*
*	This subroutine must be called in long mode.
*
****************************************************************
*
Malloc	start
	using Common
	longi on
	longa on
ptr	equ	1	pointer to memory
hand	equ	5	handle of memory

	sub	(2:len),8

	pha		reserve the memory
	pha
	pea	0
	ph2	len
	ph2	user_ID
	ph2	#$C010
	ph4	#0
	_NewHandle
	pl4	hand	pull the handle
	jcs	TERR1	branch if there was an error
	ldy	#2	dereference the handle
	lda	[hand],Y
	sta	ptr+2
	lda	[hand]
	sta	ptr

	ret	4:ptr	return

	longa off
	longi off
	end

****************************************************************
*
*  MoveName - move a file name
*
*  Inputs:
*	fp1 - pointer to the name to move
*	fp2 - pointer to the new file buffer
*
*  Notes:
*	This subroutine assumes that the buffer is large
*	enough.
*
*	This subroutine can be called in long or short mode.
*
****************************************************************
*
MoveName private

	php
	long	I,M
	lda	[fp1]
	inc	A
	tay
	short M
lb1	lda	[fp1],Y
	sta	[fp2],Y
	dey
	bpl	lb1
	plp
	rts

	longi off
	end

****************************************************************
*
*  Open - Open the Source File
*
*  Inputs:
*	fname - Name of file to open
*	lastname - Name of the currently open file, "" if none
*
*  Outputs:
*	srcbuff - source buffer start
*	ap - points to first line of file
*	C - set for error, else clear
*
****************************************************************
*
Open	start
	using Common
	using FileCommon
;
;  If an old file exists, purge it
;
	long	I,M
	lda	lastname	branch if there is no old file
	ora	lastname+2
	beq	op1
	lda	#7	purge the file
	sta	ff_action
	move4 lastname,ff_pathname
	OSFastFile ff_DCB
;
;  Read the new file
;
op1	stz	ff_action
	lda	#$C000
	sta	ff_flags
	add4	fname,#2,ff_pathname
	OSFastFile ff_DCB
	jcs	err1
	ph4	r0
	move4 ff_filehandle,r0	set ap, srcbuff to the start
	lda	[r0]	 of the buffer
	sta	srcbuff
	sta	ap
	ldy	#2
	lda	[r0],Y
	sta	srcbuff+2
	sta	ap+2
	add4	ff_fileLength,ap,srcend	set end of file mark
	pl4	r0
	short I,M
	jsr	SRLIN	read the first line
	clc
	rts
;
;  Errors
;
err1	short I,M	could not open file
	lda	macroFile	if in a macro file then
	jeq	Terr4
	jsr	SwapNames	  swap names
	jmp	Terr6
	end

****************************************************************
*
*  PageLength - Find the length of a printer page
*
*  Outputs:
*	lPerPage - lines on a printer page
*
****************************************************************
*
PageLength start
	using Common

	long	I,M
	lda	#100	set the buffer length
	sta	work
	OSRead_Variable read_DCB	read the string value
	ldx	work+2	skip if nul
	short I,M
	beq	pl2
	stz	r0	r0 = 0
	ldy	#1	for each character do
pl1	lda	work+2,Y	  if not a number then
	jsr	SNMID
	bcc	pl2	    error exit
	and	#$0F	  r1 = digit
	sta	r1
	asl	r0	  A = r0*10
	bcs	pl2
	lda	r0
	asl	A
	bcs	pl2
	asl	A
	bcs	pl2
	adc	r0
	bcs	pl2
	adc	r1	  r0 = A+digit
	bcs	pl2
	sta	r0
	iny		next char
	dbne	X,pl1
	sta	lPerPage
pl2	rts

read_DCB dc	i'3'	read a variable DCB
	dc	a4'name'	  name of variable
	dc	a4'work'	  place to store string
	ds	2	  export flag

name	dos	'PrinterLines'	name of the shell variable
	end

****************************************************************
*
*  PartialNames - Are there names in the partial assembly list?
*
*  Inputs:
*	subs - partial assembly list
*
*  Outputs:
*	C - set if there are names left, else clear
*
****************************************************************
*
PartialNames start
	using FileCommon

	phy
	ldy	#2
	lda	[subs],Y
	iny
	ora	[subs],Y
	ply
	cmp	#0
	beq	no
	sec
	rts

no	clc
	rts
	end

****************************************************************
*
*  Purge - purge a source file
*
*  Inputs:
*	fname - file name to purge
*
****************************************************************
*
Purge	start
	using FileCommon

	long	I,M
	lda	#7
	sta	ff_action
	add4	fname,#2,ff_pathname
	OSFastFile ff_DCB
	short I,M
	rts
	end

****************************************************************
*
*  Quit - return to the shell
*
*  Inputs:
*	A - return code
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
Quit	start

	long	I,M
	OSQuit  qt_DCB

qt_DCB	dc	i'0'	quit DCB
	dc	a4'qt_flags'
qt_flags dc	i'0'

	longa off
	longi off
	end

****************************************************************
*
*  RootName - Append .ROOT to Keep Name
*
*  inputs:
*	kname - keep name
*
*  outputs:
*	ckname - current keep file name
*	tkname - .ROOT appended to contents of kname
*	kltr - suffix letter for the main obj file
*
****************************************************************
*
RootName start
	using FileCommon

	long	I,M
	ph4	tkname	free old buffers
	jsr	Free
	ph4	ckname
	jsr	Free
	add4	kname,#2,fp1	get new buffers
	lda	[fp1]
	clc
	adc	#2+l:root
	pha
	pha
	jsr	Malloc
	sta	tkname
	stx	tkname+2
	jsr	Malloc
	sta	ckname
	stx	ckname+2
	sta	fp2	copy kname to ckname
	stx	fp2+2
	jsr	MoveName
	move4 tkname,fp2	copy fname to tkname
	jsr	MoveName

	lda	[tkname]	append root to the names
	tay
	clc
	adc	#l:root
	sta	[tkname]
	sta	[ckname]
	iny
	iny
	ldx	#0
	short M
kn1	lda	root,X
	sta	[tkname],Y
	sta	[ckname],Y
	iny
	inx
	cpx	#l:root
	bne	kn1

	lm	kltr,#'A'	initialize kltr
	short I
	rts

root	dc	c'.ROOT'
	end

****************************************************************
*
*  SaveFile - Close the Keep File
*
****************************************************************
*
SaveFile start
	using Common
	using KeepCom
	using FileCommon
OBJ	equ	$B1	OBJ file type

	aif	DEBUGK,.SKFINA
	long	I,M
	lda	mark	quit if nothing was written
	ora	mark+2
	beq	rts
	lda	plus_f+2	write the file through the FastFile
	and	#^SET_M	 system
	beq	lb1
	lda	#4
	ldx	#$0000
	bra	lb2
lb1	lda	#3
	ldx	#$C000
lb2	sta	ff_action
	stx	ff_flags
	move4 keepHandle,ff_fileHandle
	move4 mark,ff_fileLength
	move4 ckName,ff_pathName
	lda	#$C3
	sta	ff_access
	lda	#OBJ
	sta	ff_fileType
	stz	ff_auxtype
	stz	ff_auxType+2
	lda	#1
	sta	ff_storageType
	stz	ff_create
	stz	ff_create+2
	stz	ff_mod
	stz	ff_mod+2
	OSFastFile ff_DCB
	jcs	Terr2
	stz	mark	nothing in the buffer, now
	stz	mark+2
rts	short I,M
.SKFINA
	rts
	end

****************************************************************
*
*  SaveFNameR0 - save the current file name at [r0]
*
*  Inputs:
*	r0 - pointer to the save location
*	fname - current file name
*
****************************************************************
*
SaveFNameR0 start
	using FileCommon

	long	I,M
	add4	fname,#2,fp1	get a new file buffer
	lda	[fp1]
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	fp2
	sta	[r0]
	ldy	#2
	txa
	sta	fp2+2
	sta	[r0],Y
	jsr	MoveName	move the file name
	short I,M
	rts
	end

****************************************************************
*
*  SaveName - save the file name
*
*  Inputs:
*	word - string version of the file name
*
*  Outputs:
*	name - file name with devices expanded
*
****************************************************************
*
SaveName start
	using Common
	using FileCommon

	long	I,M
	ph4	name	free the old name buffer
	jsr	Free
	lda	word	get a name buffer
	and	#$00FF
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	exInName
	stx	exInName+2
	sta	name
	stx	name+2
	ph2	#maxName+4	get a buffer for the expanded name
	jsr	Malloc
	sta	exOutName
	stx	exOutName+2
	sta	fp1
	stx	fp1+2
	lda	#maxName+4	set its size
	sta	[fp1]
	lda	word	copy the file name to the name buffer
	and	#$00FF
	sta	[name]
	inc	A
	tay
	short M
lb1	lda	word-1,Y
	sta	[name],Y
	dey
	cpy	#1
	bne	lb1
	long	I,M	expand devices
	OSExpandDevices exp_DCB
	bcs	lb2
	ph4	name	free the input name buffer
	jsr	Free
	add4	exOutName,#2,fp1	allocate a new name buffer
	lda	[fp1]
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	fp2
	stx	fp2+2
	sta	name
	stx	name+2
	jsr	MoveName	copy the name
lb2	ph4	exOutName	free the output name buffer
	jsr	Free
	short I,M
	rts

exp_DCB	dc	i'2'	control block
exInName ds	4
exOutName ds	4
	end

****************************************************************
*
*  SaveMName - save name in the macro name table
*
*  Inputs:
*	X - macro name table index
*	name - file name to save
*
****************************************************************
*
SaveMName start
	using FileCommon

	long	I,M
	txa		compute mname disp
	and	#$00FF
	asl	A
	asl	A
	tay
	phy		free any old buffer
	lda	mlibn+2,Y
	pha
	lda	mlibn,Y
	pha
	jsr	Free
	lda	[name]	get a file name buffer
	inc	A
	inc	A
	pha
	jsr	Malloc
	ply
	sta	fp2
	stx	fp2+2
	sta	mlibn,Y
	txa
	sta	mlibn+2,Y
	move4 name,fp1	move the name
	jsr	MoveName
	short I,M
	rts
	end

****************************************************************
*
*  SetErrorMessage - set the terminal error message
*
*  Inputs:
*	r0 - pointer to the error message (code bank!)
*
*  Notes:
*	This subroutine must be called in long mode
*
****************************************************************
*
SetErrorMessage start
	using FileCommon
	using Common
	longa on
	longi on

	short I,M
	lda	(r0)	move the string to work+2
	sta	work
	stz	work+1
	tay
lb1	lda	(r0),Y
	sta	work+1,Y
	dey
	bne	lb1
	long	I,M
	lla	parms,work	set the error address
	rts

	longa off
	longi off
	end

****************************************************************
*
*  SetKeepName - set the keep file name
*
*  Inputs:
*	name - input file name
*
*  Outputs:
*	kname - keep file name
*
****************************************************************
*
SetKeepName start
	using FileCommon

	long	I,M
	move4 name,fp1
	add4	kname,#2,fp2
	jsr	MoveName
	short I,M
	rts
	end

****************************************************************
*
*  SetLInfo - return information to the shell
*
*  Inputs:
*	switch - are we switching languages?
*
*  Outputs:
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
SetLInfo start
	using Common
	using FileCommon

	php
	short I,M
	lda	switch	if we are not switching languages then
	bne	lb1
	lsr	lops	  prevent further assemblies
	asl	lops
	lda	kflag	  if no file was kept, clear LOPS
	bne	lb1
	stz	lops
lb1	long	I,M
	move	merr,flags,#l:flags
	OSSet_LInfo LInfo	transfer control
	plp
	rts

	longa off
	longi off
	end

****************************************************************
*
*  SetSFileFName - set the LInfo source name to fname
*
*  Inputs:
*	fname - file name
*
*  Outputs:
*	sfile - set to addr of fname
*
*  Notes:
*	This subroutine must be called in long mode
*
****************************************************************
*
SetSFileFName start
	using Common
	using FileCommon
	longa on
	longi on

	add4	fname,#2,sfile
	rts

	longa off
	longi off
	end

****************************************************************
*
*  SetSFileName - set the LInfo source name to name
*
*  Inputs:
*	name - file name
*
*  Outputs:
*	sfile - set to addr of name
*
****************************************************************
*
SetSFileName start
	using Common
	using FileCommon

	move4 name,sfile
	rts
	end

****************************************************************
*
*  SPAS1 - Initialization for Pass 1
*
****************************************************************
*
SPAS1	start
	using Common
	using FileCommon

	long	I,M
	lla	str,$1000	STR = $1000
	stz	sname	reset NAME
	move	cmtcol,tempass,#endPass-cmtcol save pass dependent variables
	ph4	aname	save the current file name
	jsr	Free
	add4	fname,#2,fp1
	lda	[fp1]
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	aname
	stx	aname+2
	sta	fp2
	stx	fp2+2
	jsr	MoveName
	move	mlibn,amlibn,#nameBuff*4 save the macro names
	sub4	ap,srcbuff,tap	save text pointer
	move4 lHash,r10	reset the hash table
	ldy	#hTableSize-2
	lda	#0
ps1	sta	[r10],Y
	dey
	dbpl	Y,ps1
	short I,M
	rts
	end

****************************************************************
*
*  SPAS2 - Initialization for Pass 2
*
****************************************************************
*
SPAS2	start
	using Common
	using FileCommon

	inc	pass	PASS = 2
	long	I,M
	add4	fname,#2,fp2	check for a change in the file name
	lda	[fp2]
	tay
	short M
	iny
ps2	lda	[aname],Y
	cmp	[fp2],Y
	bne	ps3
	dey
	bpl	ps2
	short I
	brl	ps4
ps3	short I
	lda	copyDepth	while COPYDEPTH > 0 do
	beq	cp3
cp1	move4 cbuff,m1l	  recover buffer handle, pointer
	ldy	#nameBuff+11
cp2	lda	[m1l],Y
	sta	work,Y
	dey
	cpy	#nameBuff
	bge	cp2
	long	I,M
	dispose cBuffHand	  release the copy buffer
	ph4	work	  release the file name buffer
	jsr	Free
	move4 work+nameBuff,cbuff	  restore the copy dependent variables
	move4 work+nameBuff+8,cBuffHand
	short I,M
	dbne	copyDepth,cp1	endwhile

cp3	long	I,M
	ph4	lastname	reopen the correct file
	jsr	Free
	add4	fname,#2,fp1
	lda	[fp1]
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	lastname
	stx	lastname+2
	sta	fp2
	stx	fp2+2
	jsr	MoveName
	move4 aname,fp1
	add4	fname,#2,fp2
	jsr	MoveName
	php
	jsr	Open
	plp
	cmpl	amlibn,mlibn	delete any new macro file names
	beq	mn1
	ph4	amlibn
	jsr	Free
mn1	cmpl	amlibn+4,mlibn+4
	beq	mn2
	ph4	amlibn+4
	jsr	Free
mn2	cmpl	amlibn+8,mlibn+8
	beq	mn3
	ph4	amlibn+8
	jsr	Free
mn3	cmpl	amlibn+12,mlibn+12
	beq	mn4
	ph4	amlibn+12
	jsr	Free
mn4	move	amlibn,mlibn,#nameBuff*4 restore the old macro names

ps4	long	I,M
	move	tempass,cmtcol,#endPass-cmtCol restore the pass dependent variables
	move4 aname,fp1
	add4	fname,#2,fp2
	jsr	MoveName
	add4	tap,srcBuff,ap	reset text pointer
	short I,M
	lda	list	print the pass 2 header
	bne	rts

	lda	progress
	beq	rts
	print2 'Pass 2: '
	ldy	#0
ps5	lda	sname+1,Y
	cout	A
	iny
	cpy	sname
	bne	ps5
	print
rts	jsr	SRLIN
	rts
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

	php
	long	I,M
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
lb3	plp
	rts

coRec	dc	i'1'
ch	ds	2

	longa	off
	longi	off
	end

****************************************************************
*
*  Stop - See if the user has flagged a stop
*
*  Outputs:
*	C - set for stop, else clear
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
Stop	start

	php
	long	I,M
	OSStop st_dcb	see if we need to quit
	lda	st_flag
	bne	lb1
	plp
	jsr	Spin
	clc
	rts

lb1	plp
	sec
	rts

	longa off
	longi off

st_dcb	dc	i'1'
st_flag	ds	2
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

	php	
	long	I,M
	lda	spinning
	beq	lb1
	stz	spinning
	lda 	#' '
	sta	ch
	OSConsoleOut coRec
	lda 	#8
	sta	ch
	OSConsoleOut coRec
lb1	plp
	rts

coRec	dc	i'1'
ch	ds	2

	longa	off
	longi	off
	end

****************************************************************
*
*  SwapNames - swap the source and macro file names
*
*  Inputs:
*	srcbuff,srcend - source file pointers
*	macbuff,macend - macro file pointers
*	fname - source file name
*	r0 - pointer to macro file name
*
*  Outputs:
*	input values are exchanged
*
*  Notes:
*	This subroutine can be called with long or short
*	registers.
*
****************************************************************
*
SwapNames private
	using Common
	using FileCommon

	php
	long	I,M	swap buffer pointers
	lda	srcbuff
	ldx	macbuff
	sta	macbuff
	stx	srcbuff
	lda	srcbuff+2
	ldx	macbuff+2
	sta	macbuff+2
	stx	srcbuff+2
	lda	srcend
	ldx	macend
	sta	macend
	stx	srcend
	lda	srcend+2
	ldx	macend+2
	sta	macend+2
	stx	srcend+2

	add4	fname,#2,fp1	move fname to a new buffer
	lda	[fp1]
	inc	A
	inc	A
	pha
	jsr	Malloc
	sta	fp2
	stx	fp2+2
	jsr	MoveName
	ph4	fp2	save the new name pointer
	move4 fp1,fp2	move the macro name to fname
	lda	(r0)
	sta	fp1
	ldy	#2
	lda	(r0),Y
	sta	fp1+2
	jsr	MoveName
	ph4	fp1	free the macro name buffer
	jsr	Free
	ldy	#2	save the file name pointer
	pla
	sta	(r0)
	pla
	sta	(r0),Y
	plp
	rts

	longa off
	longi off
	end

****************************************************************
*
*  Version - check the shell version
*
*  Outputs:
*	C - set if the shell is not present or is an old version
*
*  Notes:
*	This subroutine must be called in long mode
*
****************************************************************
*
Version	start
	longa on
	longi on

	OSVersion vrDCB
	bcs	lb1
	lda	vrNumber
	and	#$00FF
	cmp	#'2'
	blt	lb1
	clc
	rts

lb1	sec
	rts

	longa off
	longi off

vrDCB	dc	i'1'
vrNumber ds	4
	end
