	mcopy gsh.mac

MAIN	START

p	equ	0
arg	equ	p+4
space	equ	arg+4

	mnote 'before subroutine',0
	subroutine (2:argc,4:argv),space
	mnote 'after subroutine',0
	nop
	return

	END
