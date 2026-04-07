	mcopy gsh.mac
	LONGA ON
	LONGI ON
TEST	START
; Step 1: Does AGO skip work?
	lda	#1
; Step 2: Does the @a path (cmp) work alone?
	lda	#5
	cmp	#13
	bcc	step3
step3	nop
; Step 3: Does &char1 amid work?
; (This is the LCLC+AMID pattern inside if2)
; Test with a 3-char wrapper
	lda	#7
	if2	@a,ne,#0,step4
step4	nop
	rts
	END
