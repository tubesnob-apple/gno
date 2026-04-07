	mcopy gsh.mac
	LONGA ON
	LONGI ON
TEST	START
	lda	#5
	if2	@a,cc,#13,skip1
	nop
skip1	rts
	END
