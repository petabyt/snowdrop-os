Snowdrop OS - a small-scale 16-bit real mode operating system written in x86 assembly language
by Sebastian Mihai, http://sebastianmihai.com

This package contains everything needed to assemble the source code and build bootable Snowdrop OS images.

This package expects a 32bit Windows operating system. Windows XP is known to work.

Run make.bat to assemble Snowdrop OS source code and create disk images. The build scripts produce a CD-ROM image and a floppy disk image, both bootable - find them inside disk\
To create a bootable USB key, take a look inside the tools\rufus\ directory.

See the docs\ directory for more detailed information on:
	- building Snowdrop OS
	- extending Snowdrop OS with your own kernel services and apps
	- a list of the service interrupts provided by the kernel to apps
	- my daily development log, kept as I developed Snowdrop OS
	- a useful listing of keyboard scan codes
	- BASIC documentation
	- x86 assembler documentation
	- version information
	- development log


Snowdrop OS was born of my childhood curiosity around what happens when a PC is turned on, the mysteries of bootable disks, and the hidden aspects of operating systems. 

I chose to use exclusively assembly language because of two reasons:
	- it keeps the process of creating binaries extremely simple, only requiring the assembly step
	- I consider software that's close to the hardware to be more "real"

I hope that Snowdrop can serve other programmers who are looking to get a basic understanding of operating system functions. Like my other projects, the source code is fully available, without any restrictions on its usage and modification.

Additionally, I've made sure to comment my source code well, focusing on the more algorithmically-complex pieces. Other than the boot loader, where I was strapped for space, I kept the code on the verbose side, as opposed to the efficient/minimalistic side. If you run across a confusing piece of code, send me an email using the address on my website above.

Finally, I've kept a day-by-day (or rather, evening-by-evening) development log describing various issues I ran into. It doesn't have much technical value, but could be an interesting read.

Regarding the tools I've used (Nasm, cdrtools, etc.), I've used an online meta virus scanner to scan the Snowdrop OS package for possible viruses in the tools I downloaded, of the 55 scanners, one lesser-known scanner reported a possible threat. Given that industry-recognized ones like Bitdefender, AVG, Symantec, Kaspersky, etc. detected nothing, I believe that the threat report is a false positive. Regardless, I suggest you always work in a virtual machine when you work with tools whose origin is hard to verify.

