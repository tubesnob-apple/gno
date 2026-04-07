**************************************************************************
*
* The GNO Shell Project
*
* Developed by:
*   Jawaid Bazyar
*   Tim Meekins
*
* $Id: expand.asm,v 1.8 1999/02/08 17:26:50 tribby Exp $
*
**************************************************************************
*
* EXPAND.ASM
*   By Tim Meekins
*   Modified by Dave Tribby for GNO 2.0.6
*
* Command line expansion routines for wildcards and env vars
*
* Note: text set up for tabs at col 16, 22, 41, 49, 57, 65
*              |     |                  |       |       |       |
*	^	^	^	^	^	^	
**************************************************************************

	mcopy gsh.mac

dmyexp	start		; ends up in .root
	end


**************************************************************************
*
* glob the command line and expand filename wildcard characters
*
**************************************************************************

glob	START
	
	using	vardata

count	equ	0
gname	equ	count+2
sepptr	equ	gname+4
eptr	equ	sepptr+4
exppath	equ	eptr+4
filesep	equ	exppath+4
shlwglb	equ	filesep+2
wordbuf	equ	shlwglb+2
index	equ	wordbuf+4
buf	equ	index+2
globflag	equ	buf+4
overflag	equ	globflag+2
space	equ	overflag+2

	subroutine (4:cmd),space

; Allocate buffer to hold result
	jsl	alcMxln
	sta	buf
	stx	buf+2

; Check for noglob variable and exit if it's set to something.
	ldy	varnogl
	beq	doglob

; Allocate a buffer, copy the command line into it, and return.
	pei	(cmd+2)
	pei	(cmd)
	pei	(buf+2)
	pei	(buf)
	jsr	copycstr
	jmp	bye

;
; noglob isn't set, so we can start globbing.
;
doglob	lda	#$FFFF	Start output index at -1.
	sta	index

	jsl	alcMxln	Create a word buffer.
	sta	wordbuf
	stx	wordbuf+2

	jsl	alcMxln	Alloc buffer for wildcard pattern.
	sta	exppath
	stx	exppath+2

	ph4	#65	Allocate memory for
	~NEW		expanded name.
	sta	gname	Store in direct
	stx	gname+2	 page pointer

	stz	globflag	globflag = no globbing done (yet).
	stz	overflag	Clear output buffer overflow flag.

;
; Find the beginning of the next word
;
findword	jsr	ggtbyte	Get character from command line.
	jeq	alldone
	if2	@a,eq,#' ',passthru
	if2	@a,eq,#009,passthru
	if2	@a,eq,#013,passthru
	if2	@a,eq,#010,passthru
	if2	@a,eq,#';',passthru
	if2	@a,eq,#'&',passthru
	if2	@a,eq,#'|',passthru
	if2	@a,eq,#'>',passthru
	if2	@a,eq,#'<',passthru

; It's not a simple pass-through character. See what needs to happen.

	stz	shlwglb
	ldy	#0
	bra	grbbwrd

; For pass-through characters, just copy to output buffer.

passthru	jsr	gptbyte
	bra	findword

;
; single out the next word [y is initialized above]
;
grabword	jsr	ggtbyte
grbbwrd	if2	@a,eq,#"'",grabsngl
	if2	@a,eq,#'"',grabdbl
	if2	@a,eq,#'\',grabslsh
	if2	@a,eq,#' ',procword
	if2	@a,eq,#009,procword
	if2	@a,eq,#013,procword
	if2	@a,eq,#010,procword
	if2	@a,eq,#000,procword
	if2	@a,eq,#';',procword
	if2	@a,eq,#'&',procword
	if2	@a,eq,#'|',procword
	if2	@a,eq,#'>',procword
	if2	@a,eq,#'<',procword
	if2	@a,eq,#'[',grabglob  
	if2	@a,eq,#']',grabglob
	if2	@a,eq,#'*',grabglob
	if2	@a,eq,#'?',grabglob

; Default action (also completion of some of the other special cases)
grabnext	sta	[wordbuf],y	Save character in word buffer
	iny		 and bump its index.
	bra	grabword	Get next character of word.

; "[", "]", "*", "?"
grabglob	ldx	#1	Set "shlwglb"
	stx	shlwglb	 flag.
	bra	grabnext	Store char in word buf & get next.

; "\"
grabslsh	sta	[wordbuf],y	Save "\" in word buffer
	iny		 and bump its index.
	jsr	ggtbyte	Get next character in cmd line.
	beq	procword	If null byte, word is terminated.
	bra	grabnext	Store char in word buf & get next.

; '"'
grabsngl	sta	[wordbuf],y	Save char in word buffer
	iny		 and bump its index.
	jsr	ggtbyte	Get next character in cmd line.
	beq	procword	If null byte, word is terminated.
	if2	@a,eq,#"'",grabnext If "'", store and grab next char.
	bra	grabsngl	Save new char and stay in this loop.

; "'"
grabdbl	sta	[wordbuf],y	Save char in word buffer
	iny		 and bump its index.
	jsr	ggtbyte	Get next character in cmd line.
	beq	procword	If null byte, word is terminated.
	if2	@a,eq,#'"',grabnext If '"', store and grab next char.
	bra	grabdbl	Save new char and stay in this loop.


;
; The complete word is in the buffer. Time to process it.
;
procword	dec	cmd	Decrement cmd line pointer.
	lda	#0	Terminate word buffer with
	sta	[wordbuf],y	 a null byte.

;
; Shall we glob? Shall we scream? What happened, to our postwar dream?
;
	lda	[wordbuf]
	and	#$FF
	if2	@a,eq,#'-',skpdglb	;This allows '-?' option.
	lda	shlwglb
	bne	globword
;
; we didn't glob this word, so copy the word buffer to the output buffer
;
skpdglb	ldy	#0
flshlp	lda	[wordbuf],y
	and	#$FF
	beq	dnflush
	jsr	gptbyte
	iny
	bra	flshlp
dnflush	anop
	lda	overflag	If buffer overflowed,
	jne	errexit	 clean up and return null pointer.
	jmp	findword

;
; Hello, boys and goils, velcome to Tim's Magik Shoppe
;
; Ok, here's the plan:
;  1. We give InitWildcardGS a PATHNAME.
;  2. NextWildcardGS returns a FILENAME.
;  3. We need to expand to the command-line the full pathname.
;  4. Therefore, we must put aside the prefix, and cat each file returned
;     from NextWildcardGS to the saved prefix, but, we must still pass
;     the entire path to InitWildcardGS.
;  5. This solves our problem with quoting. Expand the quotes before
;     passing along to InitWildcardGS, BUT the saved prefix we saved to cat
;     to will still have the quotes in it, so that the tokenizer can deal
;     with it. Whew!
;
; Well, here goes nuthin'....  [Ya know, and I'm reading Levy's book 
; 'Hackers' right now...]
;
;
;
; Expand out the quoted stuff, and keep an eye out for that ubiquitous last
; filename separator... then we can isolate him!
;
globword	stz	filesep	

	lda	exppath	Get addr of wildcard
	ldx	exppath+2	 pattern buffer.
	incaxa	Leave room for length word
	incaxa
	sta	eptr
	stx	eptr+2
	sta	sepptr
	stx	sepptr+2
		
	ldy	#0
exploop	lda	[wordbuf],y
	and	#$FF
	beq	endexp
	iny
	if2	@a,eq,#'\',expslash
	if2	@a,eq,#"'",expsngl
	if2	@a,eq,#'"',expdbl
	if2	@a,eq,#'/',expsep
	if2	@a,eq,#':',expsep
expput	sta	[eptr]
	incad	eptr
	bra	exploop
expsep	sty	filesep
	sta	[eptr]
	incad	eptr
	mv4	eptr,sepptr
	bra	exploop
expslash	lda	[wordbuf],y
	iny
	and	#$FF
	beq	endexp
	bra	expput
expsngl	lda	[wordbuf],y
	iny
	and	#$FF
	beq	endexp
	if2	@a,eq,#"'",exploop
	sta	[eptr]
	incad	eptr
	bra	expsngl
expdbl	lda	[wordbuf],y
	iny
	and	#$FF
	beq	endexp
	if2	@a,eq,#'"',exploop
	sta	[eptr]
	incad	eptr
	bra	expdbl
;
; We really didn't mean to expand the filename, so, copy it back again..
;
endexp	ldy	filesep
copyback	lda	[wordbuf],y
	iny
	and	#$FF
	sta	[sepptr]
	incad	sepptr
	cmp	#0
	bne	copyback
;
; Calculate length by subtracting sepptr from starting address
;
	sub2	sepptr,exppath,@a
	dec2	a	Don't count length word or \0
	dec	a
	sta	[exppath]
;
; We now have enough to call InitWildCardGS!!!
; [ let's mutex the rest so we don't have to fix InitWC and NextWC ;-) ]
;
	lock	glbmtx
;
; Call shell routine InitWildcardGS to initialize the filename pattern
;
	stz	count
	mv4	exppath,IniWCPth
	InitWildcardGS InitWCP

	lda	gname	Store expanded
	ldx	gname+2	 name addr
	sta	nWCname	  in NextWildcardGS
	stx	nWCname+2	   parameter block.
	lda	#65	Store maximum length at
	sta	[gname]	 beginning of result buf.
;
; Call shell routine NextWildcardGS to get the next name that matches.
;
WCloop	anop
	lda	overflag	If buffer overflowed,
	bne	nomore	 quit expanding.
	NextWildcardGS nWCparm
	ldy	#2
	lda	[gname],y
	beq	nomore
;
; Keep count of how many paths are expanded
;
	inc	count

;
; Copy the original path (up to file separator) to output buffer
;
	ldy	#0
outhere	if2	@y,eq,filesep,globout
	lda	[wordbuf],y
	jsr	gptspec
	iny
	bra	outhere
;
; Copy the expanded filename to output buffer
;
globout	ldy	#2	Get returned length
	lda	[gname],y	 from GS/OS buffer.
	tax
	ldy	#4
glbout	lda	[gname],y	Copy next character
	jsr	gptspec	 into buffer.
	iny
	dex
	bne	glbout
;
; Place blank as separator after name and see if more are expanded.
;
	lda	#' '
	jsr	gptbyte
	bra	WCloop

;
; All of the names (if any) from this pattern have been expanded.
;
nomore	anop

	unlock glbmtx

	lda	overflag	If buffer overflowed,
	bne	errexit	 clean up and return null pointer.

	lda	count	If something was expanded,
	beq	nthnfnd

	lda	globflag	Set "globbed, something found"
	ora	#$8000	 bit in globflag.
	sta	globflag
	jmp	findword	  Go find the next word.

; Nothing was expanded from the wildcard.  If we wanted to act like
; ksh, we could pass the original text by doing a "jmp skpdglb".

nthnfnd	anop
	lda	globflag	Set "globbed, nothing found"
	ora	#$4000	 bit in globflag.
	sta	globflag

	jmp	findword	Go find the next word.

;
; Goodbye, cruel world, I'm leaving you today, Goodbye, goodbye.
;
alldone	anop
	jsr	gptbyte	Store null byte at end of string.
	lda	overflag	If buffer overflowed,
	bne	errexit	 clean up and return null ptr.
;
; Check globflag for no valid matches found in any pattern
;
	lda	globflag
	cmp	#$4000
	bne	alldone2

	ldx	#^nomatch
	lda	#nomatch
	jsr	errputs

errexit	ldx	buf+2
	lda	buf
	jsl	frmaxln

	stz	buf+2	Return NULL
	stz	buf	 value from routine.

alldone2	ldx	wordbuf+2
	lda	wordbuf
	jsl	frmaxln

	pei	(gname+2)
	pei	(gname)
	jsl	nullfree

	ldx	exppath+2
	lda	exppath
	jsl	frmaxln

bye	return 4:buf


;
; Subroutine of glob: get a byte from the original command-line
;
ggtbyte	lda	[cmd]
	incad	cmd
	and	#$FF
	rts

;
; Subroutine of glob: put special characters. Same as gptbyte, but
; if it is a special shell character then quote it.
;
gptspec	and	#$7F
	if2	@a,eq,#' ',special
;	if2	@a,eq,#'.',special	>> NOTE: '.' isn't special!
	if2	@a,eq,#013,special
	if2	@a,eq,#009,special
	if2	@a,eq,#';',special
	if2	@a,eq,#'&',special
	if2	@a,eq,#'<',special
	if2	@a,eq,#'>',special
	if2	@a,eq,#'|',special
	bra	gptbyte
special	pha
	lda	#'\'
	jsr	gptbyte
	pla		; fall through to gptbyte...
;
; Subroutine of glob: store a byte into the new command-line
;
gptbyte	anop
	phx		Hold X-reg on stack.
	inc	index	Bump the buffer index.
	ldx	index
	cpx	mxlnsz
	bcc	novflow	If more chars than will fit in buffer:
	lda	overflag		If already reported,
	bne	ovflret		  return to caller.
	inc	overflag		Set overflow flag.
	ldx	#^ovferr		Report overflow error.
	lda	#ovferr
	jsr	errputs
	bra	ovflret		Return to caller.
novflow	phy		Hold Y-reg on stack.
	txy
	short	a
	sta	[buf],y	Store character in output buffer.
	long	a
	ply		Restore Y-reg.
ovflret	plx		Restore X-reg.
	rts

ovferr	dc	c'gsh: Globbing overflowed line limit',h'0d00'

glbmtx	key

;
; Parameter block for shell InitWildcardGS call (p 414 in ORCA/M manual)
;
InitWCP	dc	i2'2'	pCount
IniWCPth	ds	4	Path name, with wildcard
	dc	i2'%00000001'	Flags (this bit not documented!!!)

;
; Parameter block for shell NextWildcardGS call (p 414 in ORCA/M manual)
;
nWCparm	dc	i2'1'	pCount
nWCname	ds	4	Pointer to returned path name

nomatch	dc	c'No match',h'0d00'

	END

**************************************************************************
*
* Expand $variables and tildes not in single quotes
*
**************************************************************************

expVars	START

; Maximum number of characters in an environment variable or $<
MAXVAL	equ	512


index	equ	1
buf	equ	index+2
dflag	equ	buf+4
overflag	equ	dflag+2
space	equ	overflag+2
cmd	equ	space+3
end	equ	cmd+4

;	 subroutine (4:cmd),space

	tsc
	sec
	sbc	#space-1
	tcs
	phd
	tcd

	stz	dflag	Delimiter flag = FALSE.
	stz	overflag	Clear output buffer overflow flag.
	lda	#$FFFF	Start output index at -1.
	sta	index

	jsl	alcMxln
	sta	buf
	stx	buf+2

loop	jsr	egtbyte
	jeq	done
	if2	@a,eq,#"'",quote
	if2	@a,eq,#'$',expand
	if2	@a,eq,#'~',tilde
	if2	@a,eq,#'\',slasher
	jsr	eptbyte
	bra	loop

slasher	jsr	eptbyte
	jsr	egtbyte
	jsr	eptbyte
	bra	loop

quote	jsr	eptbyte
	jsr	egtbyte
	jeq	done
	if2	@a,ne,#"'",quote
	jsr	eptbyte
	bra	loop

;
; Tilde expansion: use the contents of $home, but make sure the
; path delimiter(s) match what the user wants (either "/" or ":")
;
tilde	anop
	lock	expmtx

	lda	#"oh"	Strangely enough,
	sta	name	 this spells "home"!
	lda	#"em"
	sta	name+2
	sta	dflag	Delimiter flag = TRUE.
	ldx	#4
	jmp	getval

;
; Expand an environment variable since a '$' was encountered.
;
expand	anop
	lock	expmtx

	lda	#0
	sta	name
	lda	[cmd]
	and	#$FF
	if2	@a,eq,#'{',brcexp
	if2	@a,eq,#'<',stdinex
	ldx	#0
nameloop	lda	[cmd]
	and	#$FF
	beq	getval
	if2	@a,cc,#'0',getval
	if2	@a,cc,#'9'+1,inname
	if2	@a,cc,#'A',getval
	if2	@a,cc,#'Z'+1,inname
	if2	@a,eq,#'_',inname
	if2	@a,cc,#'a',getval
	if2	@a,cc,#'z'+1,inname
	bra	getval
inname	jsr	egtbyte
	cpx	#255	Only the first 255 characters
	beq	nameloop	 are significant.
	sta	name,x
	inx
	bra	nameloop

;
; expand in braces {}
;
brcexp	jsr	egtbyte
	ldx	#0
brcloop	lda	[cmd]
	and	#$FF
	beq	getval
	jsr	egtbyte
	if2	@a,eq,#'}',getval
	cpx	#255	Only the first 255 characters
	beq	brcloop	 are significant.
	sta	name,x
	inx
	bra	brcloop

;
; get text from standard input
;
stdinex	jsr	egtbyte
	ReadLine (#value,#MAXVAL,#13,#0),@a
	sta	valueln
	bra	chklen

;
; Get a value for this variable
;
getval	stx	nameln	Save length of name.
	ReadVariableGS RdVarPB	Read its value.

	lda	valueln	Get value length.
	cmp	#MAXVAL+1	If > maximum allowed length,
	bcs	expanded	 we didn't get anything.
	cmp	#0
chklen	anop
	beq	expanded	If 0, nothing to do
	tax		Save length in X-reg.
	lda	dflag	If delimiter flag isn't set,
	beq	storeval	 go store the variable value

; Check to see if delimiters in the variable need to be switched
	lda	valueln	Set up length in
	tax		  X-reg and get
	lda	[cmd]	    next command line
	and	#$FF	      character.
	cmp	#"/"	If it's a slash, see if
	beq	chkvrsl	 variable needs to convert to slash.
	cmp	#":"	If it's not a colon,
	bne	storeval	 no need to convert.
	lda	value	Get first character of value.
	and	#$FF
	cmp	#"/"	If it's not a slash,
	bne	storeval	 no need to convert.

; Convert variable from "/" to ":" delimiter
	short m
chk_s	lda	value-1,x
	cmp	#"/"
	bne	bump_s
	lda	#":"
	sta	value-1,x
bump_s	dex
	bpl	chk_s
	long	m
	bra	storeval

chkvrsl	anop
	lda	value	Get first character of value.
	and	#$FF
	cmp	#":"	If it's not a colon,
	bne	storeval	 no need to convert.

; Convert variable from ":" to "/" delimiter
	short m
chk_c	lda	value-1,x
	cmp	#":"
	bne	bump_c
	lda	#"/"
	sta	value-1,x
bump_c	dex
	bpl	chk_c
	long	m

;
; Store the variable's value in the out buffer
;
storeval	anop
	lda	valueln	Get length.
	tay		Save length in Y-reg.
	ldx	#0	Use X-reg in index value.
putval	lda	value,x
	jsr	eptbyte
	inx
	dey	
	bne	putval

expanded	unlock expmtx
	stz	dflag	Delimiter flag = FALSE.
	lda	overflag	If no buffer overflow,
	jeq	loop	 stay in loop.

done	jsr	eptbyte	Store terminating null char.
	ldx	buf+2	Set return value
	ldy	buf	 to buffer pointer.
	lda	overflag	If buffer overflowed,
	beq	return
	tya
	jsl	frmaxln		Free the output buffer
	ldx	#0		 and set return pointer
	ldy	#0		  to NULL.

return	lda	space
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

;
; expVars internal subroutines to get and put bytes in buffers
;

egtbyte	lda	[cmd]
	incad	cmd
	and	#$FF
	rts

eptbyte	anop
	phx		Hold X-reg on stack.
	inc	index	Bump the buffer index.
	ldx	index
	cpx	mxlnsz
	bcc	novflow	If more chars than will fit in buffer:
	lda	overflag		If already reported,
	bne	ovflret		  return to caller.
	inc	overflag		Set overflow flag.
	ldx	#^ovferr		Report overflow error.
	lda	#ovferr
	jsr	errputs
	bra	ovflret		Return to caller.
novflow	phy		Hold Y-reg on stack.
	txy
	short	a
	sta	[buf],y	Store character in output buffer.
	long	a
	ply		Restore Y-reg.
ovflret	plx		Restore X-reg.
	rts

ovferr	dc	c'gsh: Variable expansion overflowed line limit',h'0d00'

expmtx	key


; GS/OS string to hold variable name
namestr	anop
nameln	ds	2	Length of name
name	ds	256	Room for 255 chars + 0.


; GS/OS result buffer to hold up to MAXVAL bytes of value
valres	anop
	dc	i2'MAXVAL+4'	Length of result buffer
valueln	ds	2	Length of value
value	ds	MAXVAL	Room for MAXVAL chars


; Parameter block for shell ReadVariableGS calls
RdVarPB	anop
	dc	i2'3'	pCount
RVname	dc	a4'namestr'	Name (pointer to GS/OS string)
RVvalue	dc	a4'valres'	Value (ptr to result buf or string)
RVexport	ds	2	Export flag

	END
