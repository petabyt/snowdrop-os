/************************************************************************ 
  MDEL    DEL a file from a DOS FAT image     v00.10.01
  Forever Young Software            Benjamin David Lunt

  This utility was desinged for use with Bochs to delete a file 
   from a DOS FAT 12, 16, or 32 disk image.

  Bochs is located at:
    http://bochs.sourceforge.net

  I designed this program to be used for testing my own OS,
   though you are welcome to use it any way you wish.

  Please note that I release it and it's code for others to
   use and do with as they want.  You may copy it, modify it,
   do what ever you want with it as long as you release the
   source code and display this entire comment block in your
   source or documentation file.
   (you may add to this comment block if you so desire)

  Please use at your own risk.  I do not specify that this
   code is correct and unharmful.  No warranty of any kind
   is given for its release.

  I take no blame for what may or may not happen by using
   this code with your purposes.

  'nuff of that!  You may modify this to your liking and if you
   see that it will help others with their use of Bochs, please
   send the revised code to fys@fysnet.net.  I will then
   release it as I have this one.

  You may get the latest and greatest at:
    http://www.fysnet.net/fysos.htm

  Thanks, and thanks to those who contributed to Bochs....

  ********************************************************

  Things to know:
  - I have not checked or put a lot of effort into any FAT size,
    other than FAT12.  I am only using FAT12 at the time.  If you
    see that the other two FAT sizes are incorrectly coded, please
    let me know.  Maybe you could fix it and send it in :)

  - I have not added LFN support yet.
  ********************************************************

  To compile using DJGPP:  (http://www.delorie.com/djgpp/)
     gcc -Os mdel.c -o mdel.exe -s   (DOS .EXE requiring DPMI)

  Compiles as is with MS VC++ 6.x    (Win32 .EXE file)

  Compiles as is with MS QC2.5       (TRUE DOS only)

  ********************************************************

  Usage:
    MDEL image_file_name.img file_to_delete

  It deletes 'file_to_delete' from the 'image_file_name.img'
   file.

  file_to_delete is case sensitive and since (non LFN) FAT
   uses uppercase, you must type it in as uppercase.

************************************************************************/

// don't know which ones are needed or not needed.  I just copied them
//  across from another project. :)
#include <ctype.h>
#include <conio.h>
#include <stdio.h>
#include <errno.h>
#include <memory.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <limits.h>
#include <math.h>
#include <time.h>

#include "mdel.h"   // our include

#define TRUE    1
#define FALSE   0

#define FAT12  0
#define FAT16  1
#define FAT32  2

FILE *fimg;

struct ROOT *root;           // buffer to hold the root
unsigned char *fat;          // buffer to hold the fat

unsigned  char buffer[512];  // a temp buffer
          char filename[32]; // another
		  char *f;

void read_sectors(FILE *fp, void *ptr, unsigned short cnt, unsigned long pos);
void write_sectors(FILE *fp, void *ptr, unsigned short cnt, unsigned long pos);
unsigned long del_fat_entry(unsigned long start, unsigned char type);


int main(int argc, char *argv[]) {

	int i, j;
	unsigned  long usl;
	unsigned  char fattype;
	          char Fnd = FALSE;
	
	// print start string
	printf(strtstr);

  if (argc < 2) {
    printf("\n Usage: mdel <image_file> <file_to_delete>"
           "\n"
           "\n Where <image_file> is the image to delete from and"
           "\n  <file_to_delete> is the filename with extention to delete."
           "\n (the file to delete must be case sensitive.  Use UPPER CASE."
           "\n");
    return -1;
  }

	// open image file
	if ((fimg = fopen(argv[1], "r+b")) == NULL) {
		printf("\n Error opening image file");
    return -2;
	}

	// read in BPB
	read_sectors(fimg, &bpb, 512, 0x00000000);

	// Figure what type of FAT it is:
	i = (((bpb.nRootEnts * sizeof(struct ROOT)) + (bpb.nBytesPerSec - 1)) / bpb.nBytesPerSec);
	j = (bpb.nSecs - (bpb.nSecRes + (bpb.nFATs * bpb.nSecPerFat) + i));
	if ((unsigned short)(j / bpb.nSecPerClust) < 4085) {
		fattype = FAT12;
	} else if ((unsigned short)(j / bpb.nSecPerClust) < 65525) {
		fattype = FAT16;
	} else {
		fattype = FAT32;
	}

	// allocate the fat and read it
	if (!(fat = (unsigned char *) calloc(bpb.nSecPerFat * bpb.nBytesPerSec, sizeof(unsigned char)))) {
		printf("\nError allocating FAT buffer");
    return 8;
	}
	read_sectors(fimg, fat, (bpb.nSecPerFat * bpb.nBytesPerSec), (unsigned long) (bpb.nSecRes * bpb.nBytesPerSec));

	// allocate the root and read it
	if (!(root = (struct ROOT *) calloc(bpb.nRootEnts, sizeof(struct ROOT)))) {
		printf("\nError allocating ROOT buffer");
    return 8;
	}
	read_sectors(fimg, root, (bpb.nRootEnts * sizeof(struct ROOT)),
		(unsigned long) ((bpb.nSecRes + (bpb.nFATs * bpb.nSecPerFat)) * bpb.nBytesPerSec));

	// find argv[2]
	Fnd = FALSE;
	for (i=0; i<bpb.nRootEnts; i++) {
		f = filename;
		if (((unsigned char) root[i].name[0] != 0xE5) && root[i].name[0]) {
			for (j=0; j<8; j++) {
				*f = root[i].name[j];
				if (*f == ' ') break;
				f++;
			}
			*f++ = '.';
			for (j=0; j<3; j++) {
				*f = root[i].ext[j];
				if (*f == ' ') break;
				f++;
			}
			*f = 0x00;
			if (!strcmp(filename, argv[2])) {
				// delete FAT chain
				usl = root[i].startclust;
				while (usl = del_fat_entry(usl, fattype)) {};
				// clear ROOT entry
				root[i].name[0] = '\xE5';
				// write the FAT(s)				
				fseek(fimg, (unsigned long) (bpb.nSecRes * bpb.nBytesPerSec), SEEK_SET);
				for (i=0; i<bpb.nFATs; i++)
					write_sectors(fimg, fat, (bpb.nSecPerFat * bpb.nBytesPerSec), 0xFFFFFFFF);
				// write the ROOT
				write_sectors(fimg, root, (bpb.nRootEnts * sizeof(struct ROOT)),
					(unsigned long) ((bpb.nSecRes + (bpb.nFATs * bpb.nSecPerFat)) * bpb.nBytesPerSec));
				Fnd = TRUE;
				break;
			}
		}
	}
	if (!Fnd) printf("\n File Not Found");

	// close the file
	fclose(fimg);

  return 0;

}

// Read sector(s)
void read_sectors(FILE *fp, void *ptr, unsigned short cnt, unsigned long pos) {
	if (pos < 0xFFFFFFFF) fseek(fp, pos, SEEK_SET);
	if (fread(ptr, 1, cnt, fp) < cnt) {
		printf("\n **** Error reading from file ****");
		exit(0xFF);
	}
}

// Write sector(s)
void write_sectors(FILE *fp, void *ptr, unsigned short cnt, unsigned long pos) {
	if (pos < 0xFFFFFFFF) fseek(fp, pos, SEEK_SET);
	if (fwrite(ptr, 1, cnt, fp) < cnt) {
		printf("\n **** Error writing to file ****");
		exit(0xFF);
	}
}

// Delete FAT entry
unsigned long del_fat_entry(unsigned long start, unsigned char type) {

	unsigned  long usl;
	unsigned short ush, ush1;

	switch (type) {
		case FAT12:
			usl = (start >> 1) + start;
			ush = (*((unsigned short *)(fat+usl)));
			if (start & 1) {  // if odd, clear high 12 bits
				ush1 = (*((unsigned short *)(fat+usl))) >> 4;
				(*((unsigned short *)(fat+usl))) = (ush & 0x000F);
			} else {        // if even, clear low 12 bits
				ush1 = (*((unsigned short *)(fat+usl))) & 0x0FFF;
				(*((unsigned short *)(fat+usl))) = (ush & 0xF000);
			}
			usl = ush1;
			break;
		case FAT16:
			ush = fat[start];
			fat[start] = 0;
			usl = ush;
			break;
		case FAT32:
			usl = (*((unsigned long *)(fat+(start<<2))));
			(*((unsigned long *)(fat+(start<<2)))) = 0;
	}
	if ((usl & 0x00000FFF) < 0xFF8) 
		return usl;
	else
		return FALSE;
}
