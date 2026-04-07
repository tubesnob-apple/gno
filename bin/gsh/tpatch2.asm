	mcopy gsh.mac

MAIN	START

p	equ	0
arg	equ	p+4
space	equ	arg+4

	subroutine (2:argc,4:argv),space

intoption	ldy	#1
	and	#$FF
	beq	nextarg
	cmp	#'f'

nextarg	cpy	#1
	beq	showusage

showusage	jsr	done
parsec	clc

start	case	on
	nop
	case	off

done	return

usage	dc	c'test',h'00'

	END
