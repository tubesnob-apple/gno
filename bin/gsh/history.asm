**************************************************************************
*
* The GNO Shell Project
*
* Developed by:
*   Jawaid Bazyar
*   Tim Meekins
*
* $Id: history.asm,v 1.8 1999/02/08 17:26:50 tribby Exp $
*
**************************************************************************
*
* HISTORY.ASM
*   By Tim Meekins
*   Modified by Dave Tribby for GNO 2.0.6
*
* Routines for dealing with history buffers.
*
* History Data Structures:
*
*        HistoryPtr -> historyRec   [HistoryPtr is the most recent history]
*
* Where historyRec is:
*
*   [+0] NextHist: pointer to historyRec
*   [+4] HistoryCmd:	 string of characters
*
* Note: text set up for tabs at col 16, 22, 41, 49, 57, 65
*              |     |                  |       |       |       |
*	^	^	^	^	^	^	
**************************************************************************
*
* Interfaces defined in this file:
*
* InsrtHst 	
*
* PrevHist	
*
* NextHist	
*
* SaveHist	
*
* ReadHist	
*
* InitHist	
*
* PrntHist	
*
**************************************************************************

	mcopy gsh.mac

dmyhist	start		; ends up in .root
	end


histNext	gequ	0
histCmd	gequ	4

cmdbflen	gequ	1024

;=========================================================================
;
; Add a C string to the head of the history buffer.
;
;=========================================================================

InsrtHst	START
	
	using HistData
	using global

ptr2	equ	0
ptr	equ	ptr2+4
len	equ	ptr+4
histvptr	equ	len+2
space	equ	histvptr+4

	subroutine (4:cmd),space

	pei	(cmd+2)
	pei	(cmd)
	jsr	cstrlen
	sta	len	 
	pea	0
	clc
	adc	#4+1
	pha
	~NEW
	sta	ptr
	stx	ptr+2
	ora	ptr+2
	beq	putdone

	inc	lasthist
	inc	numhist

	lda	histptr	;Set up linked list pointers
	sta	[ptr]
	ldy	#histNext+2
	lda	histptr+2
	sta	[ptr],y
	mv4	ptr,histptr

	pei	(cmd+2)
	pei	(cmd)
	pei	(ptr+2)
	clc
	lda	ptr
	adc	#4
	pha
	jsr	copycstr
;
; Now, find out what the maximum history is and prune to that value
;
putdone	anop

;
; Get value of $HISTORY environment variable
;
	ph4	#histStr
	jsl	getenv
	sta	histvptr	Save pointer to GS/OS result buffer.
	stx	histvptr+2
	ora	histvptr+2	If buffer wasn't allocated,
	jeq	goback	 all done.
;
; Call Dec2Int to convert value of string into an integer
;
	pha		Reserve room on stack for result.
	lda	histvptr	Get pointer to $HISTORY value.
	ldx	histvptr+2
	clc		Add 4 to address to skip
	adc	#4	 over length words.
	bcc	pushaddr
	inx
pushaddr	phx		Push address onto stack.
	pha
	ldy	#2
	lda	[histvptr],y
	pha		Push length.
	pea	0	Push signedFlag = 0 (unsigned)
	Tool	$280b	Dec2Int.
	pla		Get result.
	sta	size
	beq	alldone
;
; Follow linked list until we reach size histories
;
	mv4	histptr,ptr
	ldy	#histNext+2
follow	lda	[ptr]
	tax
	ora	[ptr],y
	beq	alldone	;not enough
	dec	size
	beq	prune
	lda	[ptr],y
	sta	ptr+2
	stx	ptr
	bra	follow
;
; we have enough, start pruning
;
prune	lda	[ptr]
	sta	ptr2
	lda	[ptr],y
	sta	ptr2+2
	lda	#0
	sta	[ptr]
	sta	[ptr],y	  ;terminate last history
;
; Dispose remaining
;
dispose	lda	ptr2
	ora	ptr2+2
	beq	alldone
	dec	numhist
	lda	[ptr2]
	sta	ptr
	lda	[ptr2],y
	sta	ptr+2
	pei	(ptr2+2)
	pei	(ptr2)
	jsl	nullfree
	lda	ptr
	sta	ptr2
	lda	ptr+2
	sta	ptr2+2
	ldy	#histNext+2
	bra	dispose

alldone	pei	(histvptr+2)
	pei	(histvptr)
	jsl	nullfree

goback	return

size	ds	2

	END

;=========================================================================
;
; Places the previous history into the command buffer, called when pressing
; UP-ARROW.
;
;=========================================================================

PrevHist	START

	using HistData
	using global
	using	termdata

	ora2	histptr,histptr+2,@a	 ;If no history, then skip
	jeq	ctl5a

	ldx	cmdloc	;Move cursor to beginning of line
	jsr	moveleft

	lda	cdcap
	ora	cdcap
	beq	ctl5b0
	tputs (cdcap,#0,#outc)
	bra	ctl5g

ctl5b0	ldx	cmdlen	;clear line
ctl5b	dex
	bmi	ctl5c
	phx
	lda	#' '
	jsr	putchar
	plx
	bra	ctl5b
ctl5c	ldx	cmdlen
	jsr	moveleft

ctl5g	ora2	curhist,curhist+2,@a
	bne	ctl5i	;If not set up for current hist then
	lda	histptr+2	;Set up at start.
	ldx	histptr
	ldy	#2
	bra	ctl5j

ctl5i	mv4	curhist,0	;Otherwise move to previous history
	stz	cmdlen
	stz	cmdloc
	ldy	#HistNext+2
	lda	[0]
	tax
	lda	[0],y

ctl5j	sta	0+2	;Save some pointers
	stx	0
	sta	curhist+2
	stx	curhist
	ora	0	;If ptr is 0 then at end, quit
	beq	ctl5a

	ldx	#0	;Display and store command
	iny2
ctl5h	lda	[0],y
	and	#$FF
	sta	cmdline,x
	beq	ctl5ha
	inx
	iny
	bra	ctl5h
ctl5ha	stx	cmdlen
	stx	cmdloc

	ldx	#^cmdline
	lda	#cmdline
	jsr	puts

ctl5a	rts

	END

;=========================================================================
;
; Places the next history into the command buffer, called when pressing
; DOWN-ARROW.
;
;=========================================================================

NextHist	START

	using HistData
	using global
	using	termdata

	ora2	histptr,histptr+2,@a	 ;No hist, then skip
	jeq	ctl6a

	stz	4          ;Walk through linked list searching
	stz	4+2        ; for hist prior to last hist.
	mv4	histptr,0
ctl6i	if2	0,ne,curhist,ctl6j
	if2	0+2,eq,curhist+2,ctl6k
ctl6j	mv4	0,4
	ldy	#HistNext+2
	lda	[0]
	tax
	lda	[0],y
	sta	0+2
	stx	0
	bra	ctl6i

ctl6k	ldx	cmdloc	;Move cursor to left
	jsr	moveleft

	lda	cdcap
	ora	cdcap
	beq	ctl6b0
	tputs (cdcap,#0,#outc)
	bra	ctl6g

ctl6b0	ldx	cmdlen	;clear line
ctl6b	dex
	bmi	ctl6c
	phx
	lda	#' '
	jsr	putchar
	plx
	bra	ctl6b
ctl6c	ldx	cmdlen
	jsr	moveleft

ctl6g	stz	cmdlen	;Get hist info.
	stz	cmdloc
	mv4	4,curhist
	ora2	4,4+2,@a
	beq	ctl6a	;Whoops, back to end, quit

	ldx	#0	;Output the new command
	ldy	#4
ctl6h	lda	[4],y
	and	#$ff
	sta	cmdline,x
	beq	ctl6ha
	iny
	inx
	bra	ctl6h
ctl6ha	stx	cmdlen
	stx	cmdloc

	ldx	#^cmdline
	lda	#cmdline
	jsr	puts

ctl6a	rts

	END

;=========================================================================
;
; Save History if variable set
;
;=========================================================================

SaveHist	START

	using HistData
	using global

svhvptr	equ	0
space	equ	svhvptr+4

	subroutine ,space

	lda	histFN
	sta	DstParm+2
	sta	CrtParm+2
	sta	OpenParm+4
	lda	histFN+2
	sta	DstParm+4
	sta	CrtParm+4
	sta	OpenParm+6
;
; Get value of $SAVEHISTORY environment variable
;
	ph4	#svhstStr
	jsl	getenv
	sta	svhvptr	Save pointer to GS/OS result buffer.
	stx	svhvptr+2
	ora	svhvptr+2	If buffer wasn't allocated,
	jeq	goback	 all done.
;
; Call Dec2Int to convert value of string into an integer
;
	pha		Reserve room on stack for result.
	lda	svhvptr	Get pointer to $HISTORY value.
	ldx	svhvptr+2
	clc		Add 4 to address to skip
	adc	#4	 over length words.
	bcc	pushaddr
	inx
pushaddr	phx		Push address onto stack.
	pha
	ldy	#2
	lda	[svhvptr],y
	pha		Push length.
	pea	0	Push signedFlag = 0 (unsigned)
	Tool	$280b	Dec2Int
	pla		Get result.
	sta	size
	jeq	done
;
; Create and write history to file
;
	Destroy DstParm
	Create CrtParm
	jcs	done
	Open	OpenParm
	bcs	done
	mv2	OpenRef,(WriteRef,WrtCRRf,CloseRef)

loop1	mv4	histptr,0
	mv2	size,count
	ldy	#histNext+2
loop2	lda	0
	ora	0+2
	beq	next
	lda	[0]
	tax
	dec	count
	beq	write
	lda	[0],y
	sta	0+2
	stx	0
	bra	loop2
write	clc
	lda	0
	adc	#4
	tax
	sta	WriteBuf
	lda	0+2
	adc	#0
	sta	WriteBuf+2
	pha
	phx
	jsr	cstrlen
	sta	WriteReq
	Write WrtParm
	bcs	donclos
	Write WriteCR
	bcs	donclos
next	dec	size
	bne	loop1

donclos	Close ClsParm

done	pei	(svhvptr+2)	Free $SAVEHISTORY value buffer
	pei	(svhvptr)
	jsl	nullfree

goback	return


DstParm	dc	i2'1'
	dc	a4'histFN'

CrtParm	dc	i2'3'
	dc	a4'histFN'
	dc	i2'$C3'
	dc	i2'0'

OpenParm	dc	i2'2'
OpenRef	ds	2
	dc	a4'histFN'

WrtParm	dc	i2'4'
WriteRef	ds	2
WriteBuf	dc	a4'cmdline'
WriteReq	ds	4
	ds	4

WriteCR	dc	i2'4'
WrtCRRf	ds	2
	dc	a4'CRBuf'
	dc	i4'1'
	ds	4
CRBuf	dc	i1'13'

ClsParm	dc	i2'1'
CloseRef	ds	2

size	ds	2
count	ds	2

	END

;=========================================================================
;
; Read History file
;
;=========================================================================

ReadHist	START

	using HistData
	using global

	lda	histFN
	sta	OpenParm+4
	lda	histFN+2
	sta	OpenParm+6

	lda	#0
	sta	histptr
	sta	histptr+2

	Open	OpenParm
	bcs	done
	mv2	OpenRef,(ReadRef,NLRef,CloseRef)
	NewLine NLParm
	bcs	donclos

loop	anop
	Read	ReadParm
	bcs	donclos
	ldy	RdTrans
	beq	donclos
	dey
	lda	#0
	sta	cmdline,y
	ph4	#cmdline
	jsl	InsrtHst
	bra	loop

donclos	Close ClsParm

done	rts

OpenParm	dc	i2'2'
OpenRef	ds	2
	dc	a4'histFN'

NLParm	dc	i2'4'
NLRef	ds	2
	dc	i2'$7F'
	dc	i2'1'
	dc	a4'NLTable'
NLTable	dc	i1'13'

ReadParm	dc	i2'4'
ReadRef	ds	2
	dc	a4'cmdline'
	dc	i4'cmdbflen'
RdTrans	ds	4

ClsParm	dc	i2'1'
CloseRef	ds	2

size	ds	2

	END

;=========================================================================
;
; Init History
;
;=========================================================================
InitHist	START
	using	HistData

	ph4	#histName	Create string
	jsl	AppHome	 $HOME/history
	stx	histFN+2	Store pointer to it
	sta	histFN	 in histFN
	rts
	END

;=========================================================================
;
; Print History (this is the history command)
;
;=========================================================================

PrntHist	START

	using HistData
	using global

ptr	equ	0
status	equ	ptr+4
space	equ	status+2

	subroutine (4:argv,2:argc),space

	stz	status

	lda	argc
	dec	a
	beq	chkptr

	ldx	#^usage
	lda	#usage
	jsr	errputs
	inc	status	Return status = 1.
	bra	done

chkptr	lda	histptr
	ora	histptr+2
	beq	done

	lda	numhist
	sta	num
loop1	mv4	histptr,ptr
	lda	num
	bmi	done
	sta	count
loop2	lda	count
	beq	print
	ldy	#histNext+2
	lda	[ptr]
	tax
	lda	[ptr],y
	sta	ptr+2
	stx	ptr
	ora	ptr
	beq	next
	dec	count
	bra	loop2

print	sub2	lasthist,num,@a
	Int2Dec (@a,#numbstr,#4,#0)
	ldx	#^numbstr
	lda	#numbstr
	jsr	puts
	clc
	ldx	ptr+2
	lda	ptr
	adc	#4
ok	jsr	puts
	jsr	newline

next	dec	num
	bra	loop1

done	return 2:status

numbstr	dc	c'0000:  ',h'00'
num	ds	2
count	ds	2

usage	dc	c'Usage: history',h'0d00'

	END

;=========================================================================
;
; History Data
;
;=========================================================================

HistData	DATA

lasthist	dc	i2'0'
numhist	dc	i2'0'
curhist	ds	4
histptr	dc	i4'0'
histStr	gsstr	'HISTORY'
svhstStr	gsstr	'SAVEHIST'
histName	dc	c'/history',i1'0'
histFN	ds	4

	END
