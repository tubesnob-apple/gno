GNO 2.0.6 partial installation

This archive contains two hard drive images that contain a default extraction of the gno 2.0.6 archives. They are provided as a convenience for others to save wrangling the source disk images and performing the extraction process.

The images within this archive were created by installing gno 2.0.6 following the instructions at
http://www.gno.org/gno/refs/intro/node19.html &
http://www.gno.org/gno/refs/intro/node22.html

During the extraction process, the following files were placed into the /gno/System directory:
	/gno/System/Desk.Accs/GNOSnooperII
	/gno/System/Desk.Accs/SuspDA
	/gno/System/Desk.Accs/TMTerm
	/gno/System/Drivers/FilePort
	/gno/System/Drivers/FilePort.Data
	/gno/System/Drivers/NullPort
	/gno/System/System.Setup/GNOBug
	/gno/System/System.Setup/SIM

It is recommended that these files be copied into the relevent directories in the System folder of your boot partition. The GNOBug PIF is only required if you have GSBug installed. If you install GNOBug you should afterward sort the System.Setup directory so that GNOBug appears before GSBug (the latter of which is commonly called ``debug.init'').

After booting GS/OS from your standard boot parition, to startup GNO launch /gno/kern.
You will then see a ``login:'' prompt. Enter ``root'' as the user name; you will not yet need a password.

No custom configuration has been performed. Refer to 
http://www.gno.org/gno/refs/intro/node24.html
