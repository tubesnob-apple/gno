	mcopy gsh.mac
	LONGA ON
	LONGI ON

TEST	START
	lda	#10
	if2	@a,cc,#13,skip1
	lda	#0
skip1	rts
	END
