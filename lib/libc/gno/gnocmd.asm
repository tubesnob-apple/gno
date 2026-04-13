***********************************************************************
*
* GNO command startup
* Version 1.0a
* Written by Tim Meekins
* Copyright (C) 1991-1996 by Procyon, Inc.
*
* This function emulates the startup code of a C program for assembly
* language programmers.
*
* To use it, have your first segment immediately JML to this routine.
* Then, make sure you have a segment called main() which will take argv
* and argc on the stack.
*
* $Id: gnocmd.asm,v 1.1 1997/02/28 05:12:46 gdr Exp $
*
**************************************************************************

	keep	gnocmd
	mcopy	gnocmd.mac

dummy	START		; ends up in .root file
	END

~GNO_COMMAND	START

argv	equ	0
argc	equ	4

	wdm	$40		; bisect: at very entry of ~GNO_COMMAND
	phk
	plb
	wdm	$41		; bisect: after phk/plb (DBR set up)

	sta	~USER_ID
	sty	~COMMANDLINE
	stx	~COMMANDLINE+2
	wdm	$42		; bisect: after USER_ID/COMMANDLINE saves

	jsl	~MM_INIT
	wdm	$43		; bisect: after ~MM_INIT returns

	ph4	~COMMANDLINE
	clc
	tdc
	adc	#argv
	pea	0
	pha
	wdm	$44		; bisect: about to jsl ~GNO_PARSEARG
	jsl	~GNO_PARSEARG
	wdm	$45		; bisect: after ~GNO_PARSEARG returns
	sta	argc

	cmp	#0
	beq	error
	ora2	argv,argv+2,@a
	beq	error

	pei	(argc)
	pei	(argv+2)
	pei	(argv)
	wdm	$46		; bisect: about to jsl main
	jsl	main
	wdm	$47		; bisect: after jsl main returns

	pha		;save return value

	pei	(argv+2)
	pei	(argv)
	pei	(argc)
	jsl	~GNO_FREEARG

	pla
	rtl

error	ErrWriteCString #gnoerror
	lda	#1
	rtl

gnoerror	dc	c'~GNO_COMMAND SYSTEM FAILURE!',h'0d0a00'

	END
