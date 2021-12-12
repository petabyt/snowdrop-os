
Imginit.exe is a tool by Alexia Frounze (http://alexfru.narod.ru/) that will make
three types of disk images.

C:\>imginit -fat12 testfat.img boot12.img
  Will make a FAT12 1.44meg floppy image using boot12.img as the boot sector.
  Omit boot12.img and it will create one for you.

C:\>imginit -fat32 testfat.img
   Will make a FAT32 hard drive image.

C:\>imginit -fat1x testfat.img
   This one is the most detailed.  It will create multiple partitions, and 
   multiple extended partitions.  It will create 5 total FAT12/16 partitions
   with two extended partitions.

All partitions are formatted to FAT12/16/32 and are empty.  Use the included
tool (imgcpy) to copy files to the image.  (see .zip file)

Contents:
  imginit.c      C Source code
  imginit.exe    DOS executable compiled with DJGPP (needs DPMI)
  readme.txt     This file.
