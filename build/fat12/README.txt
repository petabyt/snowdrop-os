This directory contains scripts to generate a blank FAT12 floppy disk image. It is used to generate the 16.5kb FAT12 image, which, in turn, is used to format FAT12 floppy disks.

The generated 1.44Mb blank floppy image is truncated, keeping only enough to format a FAT12 disk.

Finally, the file can be manually edited (offset 3) so that the 8-byte "OEM Identifier" BPB field is set to "SNOWDROP".
