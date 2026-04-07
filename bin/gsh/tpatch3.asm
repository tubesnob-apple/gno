	mcopy gsh.mac

stack	data	STACK
	kind	$12
	dc	128c'??'
	end

init	START
	jml	~GNO_COMMAND
	END

MAIN	START

p	equ	0
arg	equ	p+4
space	equ	arg+4

	subroutine (2:argc,4:argv),space
	nop
	return

	END
