This directory contains scripts I used to run Snowdrop OS during development. They will likely not match your own Bochs paths, if you have Bochs intalled at all.

However, I've moved the lines you need to change to run Snowdrop via Bochs to the top, so they're easy to find if you have Bochs installed and want to easily run Snowdrop yourself.

boot_snowdrop.bxrc - used to start Bochs and boot from the Snowdrop floppy image
boot_HDD.bxrc - used to boot from hard disk image
DOS_with_snowdrop.bxrc - used to start Bochs and boot Dos 6.22, with Snowdrop as floppy drive B: . The purpose of this is to test the validity of the boot loader as a first sector on the floppy drive.

copyImageToFloppy.bat - doesn't directly run Snowdrop OS, but copies it to a real floppy disk to try it on real hardware. Since this script performs a potentially dangerous raw-write, the actual write step is commented out. You'll have to edit the batch file and uncomment the write step.

ripFloppy.bat - creates an image file from a real floppy disk

development\ - scripts that I have found useful during development, but are not mandatory otherwise

serial\ - scripts used when debugging serial port communications, connecting to Bochs

parallel\ - scripts used to start Bochs in a way that makes it output anything written to the parallel port out to a file

unformat\ - scripts used to make a floppy "unformatted", destroying its file system; used for testing Snowdrop OS's disk formatting functionality

ripping\ - scripts for ripping floppy disk images

debug\ - scripts for starting Bochs in debugging mode
