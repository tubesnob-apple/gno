*	psccf_full.asm — printer SCC driver (combined port + SCC source)
*
*	Assembles port.asm and sccf.asm together into a single object so
*	all cross-module JSR references resolve within one assembly unit.
*	Port-specific equates from pr.equates (printer channel A of the SCC).
*
	case	on
	case	on
	mcopy	msccf_full.mac
	copy	equates
	copy	../gno/inc/tty.inc
	copy	pr.equates
	copy	portbody.asm
	copy	sccf.asm
