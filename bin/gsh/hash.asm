**************************************************************************
*
* The GNO Shell Project
*
* Developed by:
*   Jawaid Bazyar
*   Tim Meekins
*
* $Id: hash.asm,v 1.9 1999/01/14 17:44:24 tribby Exp $
*
**************************************************************************
*
* HASH.ASM
*   By Tim Meekins & Greg Thompson
*   Modified by Dave Tribby for GNO 2.0.6
*
* Command hashing routines
*
* Note: text set up for tabs at col 16, 22, 41, 49, 57, 65
*              |     |                  |       |       |       |
*	^	^	^	^	^	^	
**************************************************************************
*
* Interfaces defined in this file:
*
* hash	jsr with params: (2:num, 4:name)
*
* dohash	subroutine (4:files)
*	return 4:table
*
* search	subroutine (4:file,4:table,4:paths)
*	return 4:fullpth
*
* dsp_tbl subroutine (4:table)
*	 return
*
* frfiles	subroutine (4:files)
*	return
* 
* dirsch	subroutine (4:dir,2:dirNum,4:files)
*	return
* 
* hashpath	jsl with no parameters
*	no returned value
*
* dsp_hash	jsr with no parameters
*	no returned value
*		                
**************************************************************************

	mcopy gsh.mac

dmyhash	start		; ends up in .root
	end


C1	gequ	11
C2	gequ	13
TAB_MULT	gequ	4

;
; Structure for filenames
;
;	struct filenode {
;		short      dirnum;
;		char       name[32];
;		filenode  *next;
;		};
fn_dnum	gequ	0
fn_name	gequ	fn_dnum+2
fn_next	gequ	fn_name+32
fn_size	gequ	fn_next+4

;
; Structure for hash table
;
;	struct tablenode {
;		short      dirnum;
;		char      *name[32];
;		};
tn_dnum	gequ	0
tn_name	gequ	tn_dnum+2
tn_size	gequ	tn_name+32

**************************************************************************
*
* Calculate hash value for a filename
*
**************************************************************************

hash	START

	using hashdata

space	equ	1
num	equ	space+2
name	equ	num+2
end	equ	name+4

* NOTE: hash should only be called after hashmtx is locked

;
; No local variables; just need to save old Dir Page pointer and set
; up new one to point to parameters.
;
	tsc
	phd
	tcd

	lda	num	If this isn't the first time
	bne	hasher	 through, reuse the value of "h".

;
; First time through for the name: calculate value for "h"
;
	stz	h
	ldy	#0
loop	lda	[name],y
	and	#$FF
	beq	hasher
	sta	addit+1	Modify "adc #$FFFF"
	lda	h	;left shift 7
	xba
	and	#$FF00
	lsr	a
addit	adc	#$FFFF	NOTE: immediate data was modified.
	phy
	UDivide (@a,t_size),(@a,@a)
	sta	h
	ply
	iny
	bra	loop

;
; "h" has been calculated; now do the rest of the hash function
;
hasher	lda	num	;num*num
	sta	tmp
	lda	#0
	ldx	#16
mulloop	asl	a
	asl	tmp
	bcc	nomul
	clc
	adc	num
nomul	dex
	bne	mulloop
		
	pha		;Acc * C2
	asl	a
	asl	a
	sec
	sbc	1,s	(Use top word on stack as temp var)
	asl	a
	asl	a
	adc	1,s
	sta	1,s

	lda	num	;num*C1 + (Acc*C2) + h
	asl	a
	adc	num
	asl	a
	asl	a
	adc	1,s
	adc	h
	sec
	sbc	num
	plx		(Remove temp var from stack)
	UDivide (@a,t_size),(@a,@y)

;
; Return the hashed value to the user
;
	lda	space
	sta	end-2
	pld
	tsc
	clc
	adc	#end-3
	tcs

	tya		Final hash value is in accumulator.
	rts

h	ds	2	NOTE: h must be a "static" variable.
tmp	ds	2

	END

**************************************************************************
*
* dohash
*
**************************************************************************

dohash	START
	
	using hashdata

h	equ	1
temp	equ	h+2
qh	equ	temp+4
table	equ	qh+2
space	equ	table+4
files	equ	space+3
end	equ	files+4

;	 subroutine (4:files),space

	tsc
	sec
	sbc	#space-1
	tcs
	phd
	tcd

	lda	hshnumex
	bne	mktsize

	stz	table
	stz	table+2
	jmp	done
;
; t_size = (TAB_MULT * numexe) - 1
;     [Shift since TAB_MULT is 4, change later if needed]
;
mktsize	asl	a
	asl	a
	dec	a
	sta	t_size
;
; table = (tablenode **)malloc(sizeof(tablenode *) * t_size);
;
	inc	a	;safety precaution
	asl	a
	asl	a
	pea	0
	pha
	~NEW
	sta	table
	stx	table+2
;
; for (i=0; i < t_size; ++i) table[i] = NULL;
;
	ldy	#0
	ldx	t_size
	tya
clrtbl	sta	[table],y
	iny
	iny
	sta	[table],y
	iny
	iny
	dex
	bne	clrtbl
;
; files = files->next
;
mainloop	ldy	#fn_next
	lda	[files],y
	tax
	ldy	#fn_next+2
	lda	[files],y
	sta	files+2
	stx	files
;
; while (files != NULL) {
;
	ora	files
	jeq	done
	stz	qh
;
; while (table[h = hash(files->name, qh))]) { ++qh; ++colls; }
;
hashloop	pei	(files+2)
	lda	files
	inc	a
	inc	a
	pha
	pei	(qh)
	jsr	hash
	asl	a
	asl	a
	sta	h
	tay
	lda	[table],y
	tax
	iny2
	ora	[table],y
	beq	gotit

; If it's the same name, skip the duplicate entry

	ldy	h	Calculate address
	clc		 of hash entry's
	lda	[table],y	  name field.
	adc	#tn_name
	tax
	iny2
	lda	[table],y
	adc	#0
	pha		High-order word of address.
	phx		Low-order word of address.
	pei	(files+2)
	lda	files
	inc	a
	inc	a
	pha
	jsr	cmpcstr
	beq	mainloop

	inc	qh
	bra	hashloop
;
; table[h] = (tablenode *)malloc(sizeof(tablenode))
;
gotit	ph4	#tn_size
	~NEW
	sta	temp
	stx	temp+2
	ldy	h
	sta	[table],y
	iny
	iny
	txa
	sta	[table],y
;
; table[h]->dirnum = files->dirNum
;
	lda	[files]
	sta	[temp]
;
; strcpy(table[h]->name, files->name);
;
	pei	(files+2)
	lda	files
	inc	a
	inc	a
	pha
	pei	(temp+2)
	lda	temp
	inc	a
	inc	a
	pha
	jsr	copycstr
	jmp	mainloop

done	anop
;	return 4:table

	ldx	table+2
	ldy	table

	lda	space
	sta	end-3
	lda	space+1
	sta	end-2
	pld
	tsc
	clc
	adc	#end-4
	tcs
	
	tya
	rtl

	END

**************************************************************************
*
* Search the hash table
*
**************************************************************************

search	START

	using	hashdata
	
ptr	equ	1
name_len	equ	ptr+4
fullpth	equ	name_len+2
qh	equ	fullpth+4
space	equ	qh+2
paths	equ	space+3
table	equ	paths+4
file	equ	table+4
end	equ	file+4

;	 subroutine (4:file,4:table,4:paths),space

	tsc
	sec
	sbc	#space-1
	tcs
	phd
	tcd

	lock	hashmtx

	stz	qh
	stz	fullpth	Set result to NULL.
	stz	fullpth+2

	lda	table	If hash table hasn't
	ora	table+2	 been allocated,
	jeq	done	  return null string.

	pei	(file+2)
	pei	(file)
	jsr	lwrCstr
mainloop	pei	(file+2)	Get hash(qh,file)
	pei	(file)
	pei	(qh)
	jsr	hash
	asl	a	Multiply by 4
	asl	a
	tay		Use as index into table.
	lda	[table],y	ptr = table[hash(qh,file)]
	sta	ptr
	tax
	iny
	iny
	ora	[table],y	If == 0,
	jeq	done	 all done.

	lda	[table],y
	sta	ptr+2

	pei	(file+2)
	pei	(file)
	pha		;ptr+2
	inx		;ptr + #2
	inx
	phx
	jsr	cmpcstr	Compare filename against entry.
	beq	found
	inc	qh
	bra	mainloop

;
; Found an entry that matches the filename. Calculate full path.
;
found	lda	[ptr]
	asl	a
	asl	a
	adc	paths	;(cf=0)
	sta	ptr
	ldx	paths+2
	stx	ptr+2

	pei	(file+2)
	pei	(file)
	jsr	cstrlen	Get length of prog name.
	sta	name_len

	ldy	#2
	lda	[ptr],y
	pha
	lda	[ptr]
	pha
	jsr	cstrlen	Get length of path.
	pha
	sec
	adc	name_len	Add name length + 1 (carry bit).
	pea	0
	pha
	~NEW		Allocate memory,
	sta	fullpth	 storing address at
	stx	fullpth+2	  functional return value.

	ldy	#2
	lda	[ptr],y
	pha
	lda	[ptr]
	pha
	pei	(fullpth+2)
	pei	(fullpth)
	jsr	copycstr	Copy pathname into buffer.

	pla		;length of path
	pei	(file+2)
	pei	(file)
	pei	(fullpth+2)
	clc
	adc	fullpth
	pha
	jsr	copycstr	Put filename at end of pathname.

done	unlock hashmtx

	ldx	fullpth+2	Load return value into Y- & X- regs
	ldy	fullpth

; Adjust stack in preparation for return
	lda	space
	sta	end-3
	lda	space+1
	sta	end-2
	pld
	tsc
	clc
	adc	#end-4
	tcs

	tya		A- & X- regs contain ptr (or NULL)

	rtl

	END

**************************************************************************
*
* Dispose the hash table
*
**************************************************************************

dsp_tbl	START

	using hashdata

ptr	equ	0
count	equ	ptr+4
space	equ	count+2

	subroutine (4:table),space

	mv4	table,ptr
	mv2	t_size,count
loop	ldy	#2
	lda	[ptr],y
	pha
	lda	[ptr]
	pha
	jsl	nullfree
	add2	ptr,#4,ptr
	dec	count
	bne	loop

	pei	(table+2)
	pei	(table)
	jsl	nullfree

	return

	END

**************************************************************************
*
* Dispose the file table
*
**************************************************************************

frfiles	START

space	equ	0

	subroutine (4:files),space

loop	ora2	files,files+2,@a
	beq	done
	ldy	#fn_next
	lda	[files],y
	tax
	ldy	#fn_next+2
	lda	[files],y
	pei	(files+2)
	pei	(files)
	stx	files
	sta	files+2
	jsl	nullfree
	bra	loop

done	return

	END

**************************************************************************
*
* Directory search
*
**************************************************************************

dirsch	START
	
	using	hashdata

temp2	equ	0
temp	equ	temp2+4
entry	equ	temp+4
numEntr	equ	entry+2
ptr	equ	numEntr+2
space	equ	ptr+4

	subroutine (4:dir,2:dirNum,4:files),space

* NOTE: dirsch is only called from hashpath (after hashmtx locked)

;
; Open directory name passed as 1st parameter
;
	ld2	3,ORec
	pei	(dir+2)	Turn "dir" c-string into
	pei	(dir)	 a GS/OS string, allocated
	jsr	c2gsstr	  via ~NEW.
	sta	ORecPath
	stx	ORecPath+2
	phx		Put GS/OS string addr on stack
	pha		 so it can be deallocated.
	Open	ORec	Open that file.
	bcc	goodopen	If there was an error,
	jsl	nullfree	 Free the GS/OS string
	jmp	exit	  and exit.

goodopen	jsl	nullfree	Free the GS/OS string.

;
; Set up parameter block for GetDirEntry
;
	mv2	ORecRef,DRecRef	Copy the file ref num from open.
	stz	DRecBase	Zero the base and
	stz	DRecDisp	 displacement.
	GetDirEntry DRec	Make DirEntry call.

	mv2	DRecEnt,numEntr	Save number of entries.
	ld2	1,(DRecBase,DRecDisp)
	stz	entry		# processed entries = 0.
;
; Process each entry in the directory
;
loop	lda	entry	If number of processed entries
	cmp	numEntr	 equals the total number,
	jge	done	  we are all done.
;
; Get directory entry's information
;
	GetDirEntry DRec

; Check for filetype $B3: GS/OS Application (S16)
	if2	DRecFT,eq,#$B3,goodfile

; Check for filetype $B5: GS/OS Shell Application (EXE)
	if2	@a,eq,#$B5,goodfile

; Check for filetype $B0, subtype $0006: Shell command file (EXEC)
	cmp	#$B0
	jne	nextfile
	lda	DRecAux
	cmp	#$06
	bne	nextfile
	lda	DRecAux+2
	bne	nextfile
;
; This directory entry points to an executable file.
; Included it in the file list.
;
goodfile	inc	hshnumex	Bump the (global) # files.

	ldx	TmpRBln	Get length word from GS/OS string
	short	a
	stz	TmpRBnm,x	 Store terminating null byte.
	long	a

	ph4	#TmpRBnm
	jsr	lwrCstr	Convert name to lower case.

	ph4	#TmpRBnm	Push src addr for copycstr.

	ldy	#fn_next	temp = files->next.
	lda	[files],y
	sta	temp
	ldy	#fn_next+2
	lda	[files],y
	sta	temp+2

	ph4	#fn_size	temp2 = new entry.
	~NEW
	sta	temp2
	stx	temp2+2

	ldy	#fn_next	files->next = temp2
	sta	[files],y
	ldy	#fn_next+2
	txa
	pha
	sta	[files],y

	lda	temp2
	clc
	adc	#fn_name
	pha
	jsr	copycstr	Copy string into entry.

	lda	dirNum	temp2->dirnum = dirNum
	sta	[temp2]

	ldy	#fn_next	temp2->next = temp
	lda	temp
	sta	[temp2],y
	ldy	#fn_next+2
	lda	temp+2
	sta	[temp2],y

nextfile	inc	entry	Bump entry number
	jmp	loop	 and stay in the loop.

;
; Done adding entries to the hash table from this directory
;
done	anop

	ld2	1,ORec	ORec.pCount = 1
	Close	ORec

exit	return


; Parameter block for GS/OS Open and Close calls
ORec	dc	i'3'	pCount (3 for Open, 1 for Close)
ORecRef	ds	2	refNum
ORecPath	ds	4	pathname (result buf)
ORecAcc	dc	i'1'	requested access = read

; Parameter block for GS/OS GetDirEntry call
DRec	dc	i'13'	pCount
DRecRef	ds	2	refNum
DRecFlag	ds	2	flags: extended/not
DRecBase	dc	i'0'	base: displacement is absolute entry #
DRecDisp	dc	i'0'	displacement: get tot # active entries
DRecName	dc	i4'TmpRBuf'	name: result buf
DRecEnt	ds	2	entryNum: entry # whose info is rtrned
DRecFT	ds	2	fileType
DRecEOF	ds	4	eof: # bytes in data fork
DRecBlk	ds	4	blockCount: # blocks in data fork
DRecCrt	ds	8	createDateTime
DRecMod	ds	8	modDateTime
DRecAcc	ds	2	access attribute
DRecAux	ds	4	auxType

; GS/OS result buffer for getting a directory entry's name
TmpRBuf	dc	i2'68'	Total length = 64 bytes + 4 for length
TmpRBln	ds	2	Value's length returned here
TmpRBnm	ds	64	Allow 64 bytes for returned name
	ds	1	Extra byte for null string termination

	END

**************************************************************************
*
* Hash the path variable
*
**************************************************************************

hashpath	START
	
	using hashdata
	using	vardata
	using global

len	equ	1
pathnum	equ	len+2
ptr	equ	pathnum+2
files	equ	ptr+4
pathptr	equ	files+4
qflag	equ	pathptr+4
qptr	equ	qflag+2
gsosbuf	equ	qptr+4
space	equ	gsosbuf+4
end	equ	space+3

;
; Allocate space on stack for direct page variables
;
	tsc
	sec
	sbc	#space-1
	tcs
	phd
	tcd

	lock	hashmtx
;
; Allocate special file node
;
	ph4	#fn_size
	~NEW
	sta	hashfls
	sta	files
	stx	hashfls+2
	stx	files+2

;
; Initialize counters and pointers
;
	lda	#0
	sta	hshnumex
	sta	pathnum
	ldy	#fn_next
	sta	[files],y
	ldy	#fn_next+2
	sta	[files],y
	ldy	#fn_name
	sta	[files],y
	sta	[files]
;
; Get value of $PATH environment variable string
;
	ph4	#pathname
	jsl	getenv
	sta	gsosbuf	Save address of allocated buffer.
	stx	gsosbuf+2
	ora	gsosbuf+2	If null,
	bne	setptr
	ldx	#^noptherr		print error message
	lda	#noptherr
	jsr	errputs
	jmp	noprint		  and exit.

setptr	clc		Add 4 bytes to
	lda	gsosbuf	 direct page pointer
	adc	#4	  to get the addr of
	sta	pathptr	   beginning of text.
	lda	gsosbuf+2
	adc	#0
	sta	pathptr+2

;
; Begin parsing $PATH
;
loop	lda	[pathptr]
	and	#$FF
	jeq	pathdone
;
; parse next pathname
;
	stz	qflag	Clear quote flag for this path

	mv4	pathptr,ptr
	ldy	#0
despace	lda	[pathptr],y
	and	#$FF
	beq	gtspc0    
	if2	@a,eq,#' ',gtspc1
	if2	@a,eq,#009,gtspc1
	if2	@a,eq,#013,gtspc1
	if2	@a,eq,#'\',gotquote
	iny
	bra	despace

; Found "\"
gotquote	anop
	iny2
	ldx	qflag	If quote flag hasn't already been set,
	bne	despace
	sty	qflag	 set it to index of first "\" + 2.
	bra	despace

; Found null byte
gtspc0	tyx			Why put Y-reg in X???
	bra	gtspc3

; Found " ", tab, or creturn
gtspc1	tyx			Why put Y-reg in X???
	short a
	lda	#0
	sta	[pathptr],y
	long	a
gtspc2	iny
	lda	[pathptr],y
	and	#$FF
	if2	@a,eq,#' ',gtspc2
	if2	@a,eq,#009,gtspc2
	if2	@a,eq,#013,gtspc2

gtspc3	anop
	clc		Bump pathptr by
	tya		 the number of bytes
	adc	pathptr	  indicated in Y-reg.
	sta	pathptr
	lda	pathptr+2
	adc	#0
	sta	pathptr+2

	lda	pathnum
	cmp	#32*4
	bcc	numok
	ldx	#^tmnyerr
	lda	#tmnyerr
	jsr	errputs
	jmp	pathdone

;
; Convert c string to GS/OS string (allocating space for it)
;
numok	pei	(ptr+2)
	pei	(ptr)
	jsr	c2gsstr
	phx		Push allocated address onto
	pha		 stack for later deallocation.
	sta	EPinPth	Save address in ExpandPath
	stx	EPinPth+2	 parameter block.
;
; If any quoted characters were included, the "\" chars must be removed
;
	ldy	qflag	Get quote flag (index to "\" char).
	beq	xpandit	If no "\", go ahead with expansion.

	sta	qptr	Save EPinPth pointer in
	stx	qptr+2	 direct page variable.
	lda	[qptr]	Store length + 2 (since we're indexing
	inc2	a	 from before length word) in qflag.
	sta	qflag
	tyx		X = index of 1st overwritten "\".
	short	a	Use 1-byte accumulator
;
; Copy characters toward front of string, removing "\" chars
;
chkloop2	lda	[qptr],y	Get next character.
	cmp	#'\'	If it's a quote,
	bne	storeit
	lda	[qptr]		Decrement length.
	dec	a
	sta	[qptr]
	iny			Skip over "\".
	lda	[qptr],y		Get character following.
storeit	phy		Push source index onto stack
	txy		 so destination index can be
	sta	[qptr],y	  used to store the character.
	ply		Restore the source index.
	inx		Bump destination and
	iny		 source index registers.
	cpy	qflag	If source index < length,
	bcc	chkloop2	 stay in copy loop.

	long	a	Restore long accumulator.

;
; Convert the input pathname into the corresponding full pathname with
; colons as separators. Use temp result buf this time, just to get length.
;
xpandit	anop
	ld4	TmpRBuf,EPoutPth
	ExpandPath EPParm
;
; Allocate memory for ExpandPath GS/OS result string
;
	lda	TmpRBln	Get length of value.
	inc2	a	Add 4 bytes for result buf len words.
	inc2	a
	sta	len	Save result buf len.
	inc	a	Add 1 more for terminator.
	pea	0
	pha
	~NEW		Request the memory.
	sta	EPoutPth	Store address in ReadVariable
	stx	EPoutPth+2	 parameter block and
	sta	ptr	  direct page pointer.
	stx	ptr+2
	ora	ptr+2	If address == NULL,
	jeq	donext	  get next entry.

	lda	len	Store result buffer length
	sta	[ptr]	 at beginning of buf.

	ExpandPath EPParm	Call again, and get the name.
	bcc	epok

	ldx	#^eperrstr	Print error message:
	lda	#eperrstr	 "Invalid pathname syntax."
	jsr	errputs
donext	jsl	nullfree	 Free GS/OS string (pushed earlier).
	jmp	next	 Get the next one.

epok	anop
	jsl	nullfree	Free source string (addr on stack)

	ldy	#2
	lda	[ptr],y	Get length of text
	sta	len
	tay
	iny4		 and add four.
	short	a
	lda	#0	Store 0 at end of text so it
	sta	[ptr],y	 can act like a C string.
	long	a
;
; Move text in GS/OS result buffer to beginning of buffer
; (overwritting the two length words).
;
	clc		Source is result
	lda	ptr	 buffer plus
	adc	#4	  four bytes.
	tay
	lda	ptr+2
	adc	#0
	pha
	phy
	pei	(ptr+2)	Destination is first
	pei	(ptr)	 byte of buffer.
	jsr	copycstr

	lda	ptr
	ldy	pathnum
	sta	hshpths,y	Store address of this
	lda	ptr+2	 path's address in the
	sta	hshpths+2,y	  hash path table.

	ldy	len
	beq	bumppnum
	dey
	lda	[ptr],y	If last character
	and	#$FF	 of path name
	cmp	#':'	  isn't ":",
	beq	bumppnum
	iny
	lda	#':'		store ":\0"
	sta	[ptr],y		 at end of string.

bumppnum	anop
	add2	pathnum,#4,pathnum	 Bump path pointer.
next	jmp	loop	Stay in loop.

;
; The $PATH entries have been created. Now we need to search each of the
; directories for executable files and add them to the "files" list.
; The earliest versions of gsh added files to the list in the order that
; directories appeared in $PATH, which put the earliest directories' files
; at the end of the list. Check for existence of $OLDPATHMODE environment
; variable to see if the user wants this, or would rather have them hashed
; in the expected order.
;
pathdone	anop
	lda	varopm
	beq	neworder

;
; Search directories and add executables to file list starting at the
; beginning of $PATH and working to the end.
;
	stz	pathnum	Start at beginning of path table.

nxtpth1	ldy	pathnum	Get offset into hash table.
	cpy	#32*4
	bcs	filsdon
	lda	hshpths,y	If address of this path
	ora	hshpths+2,y	 has not been set,
	beq	filsdon	  all done.
	lda	hshpths,y	Get address of this
	ldx	hshpths+2,y	 path's address in the
	phx		  hash path table.
	pha
	tya		Directory number =
	lsr2	a	 offset / 4
	pha
	pei	(files+2)	Pointer to file list.
	pei	(files)
	jsl	dirsch	Add executables from this directory.
	add2	pathnum,#4,pathnum	 Bump path offset.
	bra	nxtpth1

;
; Search directories and add executables to file list starting at end
; of $PATH and working back to the beginning. (Note: Loop begins at
; "neworder", but structuring the code this ways saves an instruction.)
;
nxtpth2	dey4		Decrement path offset.
	sty	pathnum
	lda	hshpths,y	Get address of this
	ldx	hshpths+2,y	 path's address in the
	phx		  hash path table.
	pha
	tya		Directory number =
	lsr2	a	 offset / 4
	pha
	pei	(files+2)	Pointer to file list.
	pei	(files)
	jsl	dirsch	Add executables from this directory.
neworder	ldy	pathnum	Get offset into hash table.
	bne	nxtpth2	When == 0, no more to do.


;
; Executable files in $PATH have been added to the list. Print
; number of files, then build the hash table.
;
filsdon	anop
	ph4	gsosbuf	Free memory allocated for
	jsl	nullfree	 $PATH string.

	lda	doneinit	If initialization isn't complete,
	beq	noprint	 don't print the # of files.

	Int2Dec (hshnumex,#hashnum,#3,#0)
	ldx	#^hashmsg
	lda	#hashmsg
	jsr	puts

noprint	anop

;
; Create the hash table from the file list.
;
	ph4	hashfls
	jsl	dohash
	sta	hshtbl
	stx	hshtbl+2

	unlock hashmtx
	
	pld
	tsc
	clc
	adc	#end-4
	tcs

	rtl

pathname	gsstr	'path'

hashmsg	dc	c'hashed '
hashnum	dc	c'000 files',h'0d00'

; Parameter block for GS/OS call ExpandPath
EPParm	dc	i'2'	pCount = 2
EPinPth	ds	4	ptr to inputPath (GS/OS string)
EPoutPth	ds	4	ptr to outputPath (Result buffer)

; GS/OS result buffer for getting the full length of expanded name
TmpRBuf	dc	i2'5'	Only five bytes total.
TmpRBln	ds	2	Value's length returned here.
	ds	1	Only 1 byte for value.

eperrstr	dc	c'rehash: Invalid pathname syntax.',h'0d00'
tmnyerr	dc	c'rehash: Too many paths specified.',h'0d00'
noptherr	dc	c'rehash: PATH string is not set.',h'0d00'

	END

**************************************************************************
*
* Dispose of hashing tables
*
**************************************************************************

dsp_hash	START

	using hashdata

	lock	hashmtx
	ora2	hshtbl,hshtbl+2,@a
	beq	done

	ldx	#32	32 different paths, maximum
	ldy	#0	Start looking at the first entry.

loop1	phx		Save path counter
	phy		 and index.
	lda	hshpths+2,y	Put address for this
	pha		 path table entry on
	lda	hshpths,y	  the stack.
	pha
	lda	#0	Zero out the table entry.
	sta	hshpths+2,y
	sta	hshpths,y
	jsl	nullfree	Free the entry's memory.
next1	ply		Restore path index
	plx		 and counter.
	iny4		Bump pointer to next address.
	dex		If more paths to process,
	bne	loop1	 stay in the loop.

	ph4	hashfls
	jsl	frfiles
	stz	hashfls
	stz	hashfls+2

	ph4	hshtbl
	jsl	dsp_tbl
	stz	hshtbl
	stz	hshtbl+2

done	unlock hashmtx
	rts

	END

**************************************************************************
*
* Hash data
*
**************************************************************************

hashdata	DATA

hashmtx	key		Mutual exclusion key

t_size	ds	2	t_size = (TAB_MULT * numexe) - 1

hshpths	dc	32i4'0'	32 paths max for now.
hashfls	dc	i4'0'
hshtbl	dc	i4'0'	Pointer to table (t_size entries)
hshnumex	dc	i2'0'	Number of hashed executables

	END
