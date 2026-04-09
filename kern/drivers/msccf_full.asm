*	msccf_full.asm — modem SCC driver (combined port + SCC source)
*
*	port.asm.body first: defines SerialData DATA + port framework before
*	sccf.asm references them.  All cross-START jsr calls use > prefix.
*	Port-specific equates from md.equates (modem channel B of the SCC).
*
	case	on
	mcopy	msccf_full.mac
	copy	equates
	copy	../gno/inc/tty.inc
	copy	md.equates
	copy	portbody.asm
	copy	sccf.asm
