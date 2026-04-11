*
*	printer.asm — GNO/ME printer port SCC serial driver
*
*	Combines port.asm.body (GNO TTY framework) and sccf.asm (SCC low-level)
*	into a single ORCA/M assembly unit for the printer port (SCC channel A,
*	Apple IIgs SCC control $E0C039 / data $E0C03B).
*
*	Linked with libsim for interrupt-vector management.
*	Output type: $BB (Device Driver), auxtype $7E01.
*
*	Build:
*	  iix assemble +T printer.asm
*	  iix chtyp -t obj printer.A
*	  iix link -P -o $(GNO_OBJ)/dev/printer printer $(GNO_OBJ)/usr/lib/libsim
*	  iix chtyp -t dvr -a 0x7e01 $(GNO_OBJ)/dev/printer
*
*	Original sources (GNO 2.0.6 CVS):
*	  kern/drivers/port.asm   (Derek Taubert, 12/15/94)
*	  kern/drivers/sccf.asm   (Derek Taubert)
*
	case	on
	mcopy	msccf_full.mac
	copy	equates
	copy	../gno/inc/tty.inc
	copy	pr.equates
	copy	portbody.asm
	copy	sccf.asm
