**************************************************************************
*
* The GNO Shell Project
*
* Developed by:
*   Jawaid Bazyar
*   Tim Meekins
*
* $Id: alias.asm,v 1.9 1999/02/08 17:26:49 tribby Exp $
*
**************************************************************************
*
* ALIAS.ASM
*   By Tim Meekins
*   Modified by Dave Tribby for GNO 2.0.6
*
* Note: text set up for tabs at col 16, 22, 41, 49, 57, 65
*              |     |                  |       |       |       |
*	^	^	^	^	^	^	
**************************************************************************
*
* Interfaces defined in this file:
*
* alias	subroutine (4:argv,2:argc)
*	Returns with status=0 in Accumulator
*
* unalias	subroutine (4:argv,2:argc)
*	return 2:status
*			 
* initals	jsr/rts with no parameters
*
* expAlias	subroutine (4:cmd)
*	return 4:buf
*
* addalias	subroutine (4:aliasnm,4:aliasval)
*	return
*
* rmvAls	subroutine (4:aliasnm)
*	return
*		                  
* fndAlias	subroutine (4:aliasnm),space
*	return 4:value
*
* strtals	jsl/rtl with no parameters
*
* nxtals	subroutine (4:p)
*	return 2:hashvalz
*
*
**************************************************************************

	mcopy gsh.mac

dmyals	start		; ends up in root
	end


VTABSIZE	gequ	17

**************************************************************************
*
* ALIAS: builtin command
* syntax: alias [name [def]]
*
* set aliases
*
**************************************************************************

alias	START

	using	AliData

arg	equ	1
space	equ	arg+4
argc	equ	space+3
argv	equ	argc+2
end	equ	argv+4	

;	 subroutine (4:argv,2:argc),space

	tsc
	sec
	sbc	#space-1
	tcs
	phd
	tcd

	lock	AliMtx
	lda	argc	How many arguments were provided?
	dec	a
	beq	showall	None -- show all alias names.
	dec	a
	beq	showone	One -- show a single name.
	jmp	setalias	More -- set an alias.

;
; Show all aliases
;
showall	jsl	strtals
showloop	jsl	nxtals
	sta	arg
	stx	arg+2
	ora	arg+2
	beq	noshow
	ldy	#6
	lda	[arg],y
	tax
	ldy	#4
	lda	[arg],y
	jsr	puts
	lda	#':'
	jsr	putchar
	lda	#' '
	jsr	putchar
	ldy	#10
	lda	[arg],y
	tax
	ldy	#8
	lda	[arg],y
	jsr	puts
	jsr	newline
	bra	showloop	
    
noshow	jmp	exit

;
; Show a single alias
;
showone	ldy	#4+2
	lda	[argv],y
	tax
	pha		;for fndAlias
	ldy	#4	
	lda	[argv],y
	pha
	jsr	puts	Print name.
	lda	#':'	Print ": ".
	jsr	putchar
	lda	#' '
	jsr	putchar
	jsl	fndAlias
	sta	arg
	stx	arg+2
	ora	arg+2
	beq	notthere
	lda	arg
	jsr	puts	Print alias value.
	jsr	newline	Print newline.
	jmp	exit	All done.

notthere	ldx	#^noalias	Print message:
	lda	#noalias	 'Alias not defined'
	jsr	puts
	jmp	exit

;
; Set an alias name
;
setalias	ldy	#4+2	;put alias name on stack
	lda	[argv],y
	pha
	ldy	#4
	lda	[argv],y
	pha

	ph4	#2
	~NEW
	sta	arg
	stx	arg+2
	lda	#0
	sta	[arg]

	add2	argv,#8,argv

	dec2	argc

bldals	lda	argc
	beq	setit

	pei	(arg+2)
	pei	(arg)
	pei	(arg+2)
	pei	(arg)
	ldy	#2
	lda	[argv],y
	pha
	lda	[argv]
	pha
	jsr	catcstr
	stx	arg+2
	sta	arg
	jsl	nullfree

	pei	(arg+2)
	pei	(arg)
	pei	(arg+2)
	pei	(arg)
	ph4	#spacestr
	jsr	catcstr
	stx	arg+2
	sta	arg
	jsl	nullfree

	dec	argc
	add2	argv,#4,argv
	bra	bldals

setit	pei	(arg+2)
	pei	(arg)
	jsl	addalias
	pei	(arg+2)
	pei	(arg)
	jsl	nullfree

exit	unlock AliMtx
	lda	space
	sta	end-3
	lda	space+1
	sta	end-2
	pld
	tsc
	clc
	adc	#end-4
	tcs

	lda	#0	Return status always 0.

	rtl

noalias	dc	c'Alias not defined',h'0d00'
spacestr	dc	c' ',h'00'

	END

**************************************************************************
*
* UNALIAS: builtin command
* syntax: unalias [var ...]
*
* removes each alias listed
*
**************************************************************************

unalias	START

	using	AliData

status	equ	0
space	equ	status+2

	subroutine (4:argv,2:argc),space

	lock	AliMtx

	stz	status

	lda	argc
	dec	a
	bne	loop

	ldx	#^Usage
	lda	#USage
	jsr	errputs
	inc	status	Return status = 1.
	bra	done

loop	add2	argv,#4,argv
	dec	argc
	beq	done

	ldy	#2
	lda	[argv],y
	pha
	lda	[argv]
	pha
	jsl	rmvAls

	bra	loop

done	unlock AliMtx
	return 2:status

Usage	dc	c'Usage: unalias name ...',h'0d00'

	END

;=========================================================================
;
; Init alias table
;
;=========================================================================

initals	START

	using	AliData

; Set all entries in AliTbl to 0

	lda	#0
	ldy	#VTABSIZE
	tax
yahaha	sta	AliTbl,x
	inx2
	sta	AliTbl,x
	inx2
	dey	
	bne	yahaha

	rts

	END		 

;=========================================================================
;
; Expand alias
;
;=========================================================================

expAlias	START
	
outbuf	equ	0
sub	equ	outbuf+4
word	equ	sub+4
buf	equ	word+4
bufend	equ	buf+4
inquote	equ	bufend+2
bsflag	equ	inquote+2
space	equ	bsflag+2
	
	subroutine (4:cmd),space

	ph4	mxlnsz	Allocate result buffer.
	~NEW
	stx	buf+2
	sta	buf
	stx	outbuf+2	Initialize "next
	sta	outbuf	 output char" pointer.
	clc		Calculate end of buffer-1;
	adc	mxlnsz	 note: it's allocated to be in one
	dec	a	  bank, so only need low-order word.
	sta	bufend

	jsl	alcMxln	Allocate buffer for word that
	stx	word+2	 might be an alias.
	sta	word

	lda	#0
	sta	[buf]	In case we're called with empty string.
	sta	[word]
;
; Eat leading space and tabs (just in case expanding a variable added them!)
;
	bra	eatldr
bump_cmd	inc	cmd
eatldr	lda	[cmd]
	and	#$FF
	jeq	strend
	cmp	#' '
	beq	bump_cmd
	cmp	#9
	beq	bump_cmd
;
; Parse the leading word
;
	short	a
	ldy	#0
	bra	mkword1	First time, already checked 0, ' ', 9
makeword	lda	[cmd],y
	if2	@a,eq,#0,gotword
	if2	@a,eq,#' ',gotword
	if2	@a,eq,#9,gotword
mkword1	if2	@a,eq,#';',gotword
	if2	@a,eq,#'&',gotword
	if2	@a,eq,#'|',gotword
	if2	@a,eq,#'>',gotword
	if2	@a,eq,#'<',gotword
	if2	@a,eq,#13,gotword
	if2	@a,eq,#10,gotword
	sta	[word],y
	iny
	bra	makeword
;
; We have a word. See if it's an alias.
;
gotword	lda	#0
	sta	[word],y	
	long	a
	cpy	#0	Check for 0 length.
	beq	copyrest
	phy
	pei	(word+2)
	pei	(word)
	jsl	fndAlias
	sta	sub
	stx	sub+2
	ply
	ora	sub+2
	beq	copyrest
;
; Yes, this is an alias. Copy it into the output buffer.
;
	add2	@y,cmd,cmd	Add length to cmd pointer.

	pei	(sub+2)	Make sure that
	pei	(sub)	 substituted string
	jsr	cstrlen	  will fit into buffer.
	sec
	adc	outbuf
	jge	overflow
	cmp	bufend
	jge	overflow

	ldy	#0
	short	a
	lda	[sub]
putalias	sta	[outbuf]
	inc	outbuf
	iny
	lda	[sub],y
	bne	putalias
	long	a
;
; That alias is expanded. Copy until we reach the next command.
;
copyrest	stz	inquote	Clear the "in quotes" flag
	stz	bsflag	 and "backslashed" flag.

next	anop
	lda	outbuf	Check for output overflow.
	cmp	bufend
	jcs	overflow
	lda	[cmd]	Transfer the character.
	and	#$00FF
	cmp	#13	If carriage-return,
	bne	go8bits
	lda	#0	 treat like end-of-string.
go8bits	short	a
	sta	[outbuf]
	long	a
	inc	cmd	Bump pointers.
	inc	outbuf

	if2	@a,eq,#0,done
;
; If that was a backslashed character, don't check for special chars.
;
	ldx	bsflag
	beq	testq
	stz	bsflag
	bra	next

testq	if2	@a,eq,#"'",snglqtr
	if2	@a,eq,#'"',dblqtr
;
; Remaining characters aren't special if we are in a quoted string
;
	ldx	inquote
	bne	next
	if2	@a,eq,#';',nxtals
	if2	@a,eq,#'&',nxtals
	if2	@a,eq,#'|',nxtals
	if2	@a,ne,#'\',next
;
; "\" found
;
bkstab	sta	bsflag
	bra	next

;
; "'" found
;
snglqtr	bit	inquote	Check "in quotes" flag.
	bvs	next	In double quotes. Keep looking.
	lda	inquote	Toggle single quote
	eor	#$8000
	sta	inquote
	bra	next
;
; '"' found
;
dblqtr	bit	inquote	Check "in quotes" flag.
	bmi	next	In single quotes. Keep looking.
	lda	inquote	Toggle single quote
	eor	#$4000
	sta	inquote
	bra	next

;
; ";", "|", or "&" found: it's another command
;
nxtals	jmp	eatldr

;
; Terminate string and exit
;
strend	short	a
	sta	[outbuf]
	long	a
;
; All done: clean up and return to caller
;
done	ldx	word+2
	lda	word
	jsl	frmaxln

	return 4:buf


;
; Report overflow error
;
overflow	anop
	pei	(buf+2)	Free the output buffer.
	pei	(buf)
	jsl	nullfree
	stz	buf
	stz	buf+2

	ldx	#^ovferr	Report overflow error.
	lda	#ovferr
	jsr	errputs

	bra	done

ovferr	dc	c'gsh: Alias overflowed line limit',h'0d00'

	END

;=========================================================================
;
; Add alias to table
;
;=========================================================================

addalias	START
	
	using	AliData

tmp	equ	0
ptr	equ	tmp+4
hashval	equ	ptr+4
space	equ	hashval+4

	subroutine (4:aliasnm,4:aliasval),space

	pei	(aliasnm+2)
	pei	(aliasnm)
	jsl	hashals
	sta	hashval
	
	tax	
	lda	AliTbl,x
	sta	ptr
	lda	AliTbl+2,x
	sta	ptr+2

search	lda	ptr
	ora	ptr+2
	beq	notfound
	ldy	#4
	lda	[ptr],y
	tax
	ldy	#4+2
	lda	[ptr],y
	pha
	phx
	pei	(aliasnm+2)
	pei	(aliasnm)
	jsr	cmpcstr
	jeq	replace
	ldy	#2
	lda	[ptr]
	tax
	lda	[ptr],y
	sta	ptr+2
	stx	ptr
	bra	search

replace	ldy	#8+2
	lda	[ptr],y
	pha	
	ldy	#8
	lda	[ptr],y
	pha
	jsl	nullfree
	pei	(aliasval+2)
	pei	(aliasval)
	jsr	cstrlen
	inc	a
	pea	0
	pha
	~NEW
	sta	tmp
	stx	tmp+2
	ldy	#8
	sta	[ptr],y
	ldy	#8+2
	txa
	sta	[ptr],y
	pei	(aliasval+2)
	pei	(aliasval)
	pei	(tmp+2)
	pei	(tmp)
	jsr	copycstr
	jmp	done

notfound	ph4	#4*3
	~NEW
	sta	ptr
	stx	ptr+2
	ldy	#2
	ldx	hashval
	lda	AliTbl,x
	sta	[ptr]
	lda	AliTbl+2,x
	sta	[ptr],y
	pei	(aliasnm+2)
	pei	(aliasnm)
	jsr	cstrlen
	inc	a
	pea	0
	pha
	~NEW
	sta	tmp
	stx	tmp+2
	ldy	#4
	sta	[ptr],y
	ldy	#4+2
	txa
	sta	[ptr],y
	pei	(aliasnm+2)
	pei	(aliasnm)
	pei	(tmp+2)
	pei	(tmp)
	jsr	copycstr
	pei	(aliasval+2)
	pei	(aliasval)
	jsr	cstrlen
	inc	a
	pea	0
	pha
	~NEW
	sta	tmp
	stx	tmp+2
	ldy	#8
	sta	[ptr],y
	ldy	#8+2
	txa
	sta	[ptr],y
	pei	(aliasval+2)
	pei	(aliasval)
	pei	(tmp+2)
	pei	(tmp)
	jsr	copycstr
	ldx	hashval
	lda	ptr
	sta	AliTbl,x
	lda	ptr+2
	sta	AliTbl+2,x
		        
done	return

	END

;=========================================================================
;
; Remove an alias
;
;=========================================================================

rmvAls	START

	using	AliData

oldptr	equ	0
ptr	equ	oldptr+4
space	equ	ptr+4

	subroutine (4:aliasnm),space

	pei	(aliasnm+2)
	pei	(aliasnm)
	jsl	hashals
	tax
	lda	AliTbl,x
	sta	ptr
	lda	AliTbl+2,x
	sta	ptr+2
	lda	#^AliTbl
	sta	oldptr+2
	clc
	txa
	adc	#AliTbl
	sta	oldptr

srchloop	ora2	ptr,ptr+2,@a
	beq	done

	ldy	#4+2
	lda	[ptr],y
	pha
	ldy	#4
	lda	[ptr],y
	pha
	pei	(aliasnm+2)
	pei	(aliasnm)
	jsr	cmpcstr
	beq	foundit
	mv4	ptr,oldptr
	ldy	#2
	lda	[ptr],y
	tax
	lda	[ptr]
	sta	ptr
	stx	ptr+2
	bra	srchloop

foundit	ldy	#2
	lda	[ptr],y
	sta	[oldptr],y
	lda	[ptr]
	sta	[oldptr]
	ldy	#4+2
	lda	[ptr],y
	pha
	ldy	#4
	lda	[ptr],y
	pha
	jsl	nullfree
	ldy	#8+2
	lda	[ptr],y
	pha
	ldy	#8
	lda	[ptr],y
	pha
	jsl	nullfree
	pei	(ptr+2)
	pei	(ptr)
	jsl	nullfree
		        
done	return

	END

;=========================================================================
;
; Find an alias
;
;=========================================================================

fndAlias	START

	using	AliData

ptr	equ	0
value	equ	ptr+4
space	equ	value+4

	subroutine (4:aliasnm),space

	stz	value
	stz	value+2

	pei	(aliasnm+2)
	pei	(aliasnm)
	jsl	hashals
	tax
	lda	AliTbl,x
	sta	ptr
	lda	AliTbl+2,x
	sta	ptr+2

srchloop	ora2	ptr,ptr+2,@a
	beq	done

	ldy	#4+2
	lda	[ptr],y
	pha
	ldy	#4
	lda	[ptr],y
	pha
	pei	(aliasnm+2)
	pei	(aliasnm)
	jsr	cmpcstr
	beq	foundit
	ldy	#2
	lda	[ptr],y
	tax
	lda	[ptr]
	sta	ptr
	stx	ptr+2
	bra	srchloop

foundit	ldy	#8
	lda	[ptr],y
	sta	value
	ldy	#8+2
	lda	[ptr],y
	sta	value+2

done	return 4:value

	END

;=========================================================================
;
; Start alias
;
;=========================================================================

strtals	START

	using	AliData

	stz	AliasNum
	mv4	AliTbl,AliasPtr
	rtl

	END

;=========================================================================
;
; Next alias
;
;=========================================================================

nxtals	START

	using	AliData

value	equ	0
space	equ	value+4

	subroutine (0:fubar),space

	stz	value
	stz	value+2
puke	if2	AliasNum,cs,#VTABSIZE,done

	ora2	AliasPtr,AliasPtr+2,@a
	bne	flush
	inc	AliasNum
	lda	AliasNum
	asl2	a
	tax
	lda	AliTbl,x
	sta	AliasPtr
	lda	AliTbl+2,x
	sta	AliasPtr+2
	bra	puke

flush	mv4	AliasPtr,value
	ldy	#2
	lda	[value]
	sta	AliasPtr
	lda	[value],y
	sta	AliasPtr+2	

done	return 4:value

	END

;=========================================================================
;
; Hash an alias
;
;=========================================================================

hashals	PRIVATE

hashval	equ	0
space	equ	hashval+2

	subroutine (4:p),space
		               
	lda	#11
	sta	hashval

	ldy	#0
loop	asl	hashval
	lda	[p],y
	and	#$FF
	beq	done
	clc
	adc	hashval
	sta	hashval
	iny
	bra	loop
done	UDivide (hashval,#VTABSIZE),(@a,@a)

	asl2	a	;Make it an index.
	sta	hashval

	return 2:hashval

	END

;=========================================================================
;
; Alias data
;
;=========================================================================

AliData	DATA

AliasNum	dc	i2'0'
AliasPtr	dc	i4'0'
AliMtx	key

AliTbl	ds	VTABSIZE*4

	END	               
