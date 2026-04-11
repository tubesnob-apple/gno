*
*	modem.asm — GNO/ME modem port SCC serial driver
*
*	Combines port.asm.body (GNO TTY framework) and sccf.asm (SCC low-level)
*	into a single ORCA/M assembly unit for the modem port (SCC channel B,
*	Apple IIgs SCC control $E0C038 / data $E0C03A).
*
*	Linked with libsim for interrupt-vector management.
*	Output type: $BB (Device Driver), auxtype $7E01.
*
*	Build:
*	  iix assemble +T modem.asm
*	  iix chtyp -t obj modem.A
*	  iix link -P -o $(GNO_OBJ)/dev/modem modem $(GNO_OBJ)/usr/lib/libsim
*	  iix chtyp -t dvr -a 0x7e01 $(GNO_OBJ)/dev/modem
*
*	Original sources (GNO 2.0.6 CVS):
*	  kern/drivers/port.asm   (Derek Taubert, 12/15/94)
*	  kern/drivers/sccf.asm   (Derek Taubert)
*
	case	on
	mcopy	msccf_full.mac
	copy	equates
	copy	../gno/inc/tty.inc
	copy	md.equates
	copy	portbody.asm
	copy	sccf.asm
