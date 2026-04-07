	mcopy gsh.mac

MAIN	START
	using	global

p	equ	0
arg	equ	p+4
space	equ	arg+4

	subroutine (2:argc,4:argv),space

intoption	ldy	#1
optloop	lda	[arg],y
	and	#$FF
	beq	nextarg
	cmp	#'f'
	beq	optf
	cmp	#'c'
	beq	parsec

showusage	ErrWriteCString #usage
	bra	done

optf	inc	FastFlag

nextopt	iny
	bra	optloop

nextarg	cpy	#1
	beq	showusage
	jmp	argloop

parsec	clc
	lda	argv
	adc	#4
	sta	argv
	dec	argc
	beq	showusage
	inc	CmdFlag
	inc	FastFlag
	mv4	argv,CmdArgV
	mv2	argc,CmdArgC

start	case	on
	jsl	shell
	case	off

done	return

str	dc	h'0d0a0a'
 dc c'Before gsh may be run, the GNO/ME system, or kernel, must be running.'
	dc	h'0d0a0a00'

usage	dc	c'Usage: gsh [-cf] [argument...]',h'0d0a00'

	END
