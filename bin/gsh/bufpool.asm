**************************************************************************
*
* The GNO Shell Project
*
* Developed by:
*   Jawaid Bazyar
*   Tim Meekins
*
* $Id: bufpool.asm,v 1.7 1999/02/08 17:26:50 tribby Exp $
*
**************************************************************************
*
* BUFPOOL
*   By Tim Meekins
*   Modified by Dave Tribby for GNO 2.0.6
*
* This is the buffer pool
*
* Note: text set up for tabs at col 16, 22, 41, 49, 57, 65
*              |     |                  |       |       |       |
*	^	^	^	^	^	^	
**************************************************************************
*
* Interfaces defined in this file:
*     The alloc routine is a jsl without any stack params.
*         Pointer to requested buffer is returned in X/A registers.
*   alcMxln	
*     The free routine takes the address from the X/A registers
*   frmaxln	
*
* bufpool data:
*    pmaxline		dc   i4'0'
*    pmxlnmtx	key
*		          
**************************************************************************

	mcopy gsh.mac

dmybfpl	start		; ends up in .root
	end


**************************************************************************
*
* Get a buffer of size mxlnsz
*
**************************************************************************

alcMxln	START
	
	using	bufpool

	lock	pmxlnmtx

	lda	pmaxline	If pool pointer
	ora	pmaxline+2	 isn't NULL,
	beq	allocbuf

	phd
	ph4	pmaxline		Push pool pointer on stack.
	tsc
	tcd
	lda	[1]		Replace pool pointer with
	sta	pmaxline		 the address it points to.
	ldy	#2
	lda	[1],y
	sta	pmaxline+2
	unlock pmxlnmtx
	pla
	plx
	pld
	rtl			Return to caller.

;
; No memory in free pool; must allocate a new block.
;
allocbuf	unlock pmxlnmtx
	ph4	mxlnsz
	~NEW
	rtl

;
; Constant indicating # of bytes in a maxline buffer
;
mxlnsz	entry		Make this easily seen.
	dc	i4'4096'

	END

**************************************************************************
*
* Free a buffer of size mxlnsz, putting it into the free pool
*
**************************************************************************

frmaxln	START

	using bufpool

	phd
	phx
	pha
	tsc
	tcd
	lock	pmxlnmtx
	lda	pmaxline	Move current head of pool list
	sta	[1]	 into the buffer being freed.
	ldy	#2
	lda	pmaxline+2
	sta	[1],y
	lda	1	Put address of buffer being freed
	sta	pmaxline	 into the pool list head.
	lda	3
	sta	pmaxline+2
	unlock pmxlnmtx
	pla
	plx	
	pld
	rtl		Return to caller.

	END

**************************************************************************
*
* Buffer pool data
*
**************************************************************************

bufpool	DATA

pmaxline	dc	i4'0'	Head of free pool list.

pmxlnmtx	key		Mutual exclusion when modifying list.
		         
	END
