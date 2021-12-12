/************************************************************************ 
  MDIREX   Dir extended       v00.10.01
  Forever Young Software      Benjamin David Lunt

  This utility was desinged for use with Bochs to read the
   directory and fat structure of a FAT 12, 16, or 32 disk
   image.

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

  ********************************************************

  To compile using DJGPP:  (http://www.delorie.com/djgpp/)
     gcc -Os mcopyf.c -o mcopyf.exe -s  (DOS .EXE requiring DPMI)

  Compiles as is with MS VC++ 6.x       (Win32 .EXE file)

  Compiles as is with MS QC2.5          (TRUE DOS only)

  ********************************************************

  Usage:
    MDIREX image_file_name.img

************************************************************************/

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

#include "mdirex.h"   // our include

#define TRUE    1
#define FALSE   0

#define FAT12  0
#define FAT16  1
#define FAT32  2

FILE *fp;

          char buffer[256]; // a temp buffer

unsigned  char *sector;     // buffer to hold a single sector of data
unsigned  char *fat;        // buffer to hold the fat
struct ROOT *root;          // buffer to hold the root


          char *bits(unsigned long ulong, int size);
          char read_sectors(FILE *fp, void *ptr, unsigned short cnt);
unsigned  long get_fat_entry(unsigned long start, unsigned char type);

int main(int argc, char *argv[]) {

	int i, j;
	unsigned  long usl;
	unsigned  char fattype;

	// print title to strerr (not redirectable)
	fprintf(stderr, strtstr);
//	if (stderr != stdout)  // if output redirected, print to redirection too.
//		printf(strtstr);

  if (argc < 2) {
    printf("\n Usage: mdirex <image_file>"
           "\n"
           "\n Where <image_file> is the image to view."
           "\n");
    return -1;
  }

	if ((fp = fopen(argv[1], "rb")) == NULL) {
		printf("\nError opening source file.");
    return -2;
	}

	// allocate sector buffer
	if (!(sector = (unsigned char *) calloc(512, sizeof(unsigned char)))) {
		printf("\nError allocating sector buffer");
    return -8;
	}

	// read the BOOT Block
	printf("\nReading BOOT sector of %s", argv[1]);
	if (!read_sectors(fp, sector, 1)) {
		printf("\nError reading from file");
    return -3;
	}

	if (((unsigned short *) sector)[255] != 0xAA55) {
		printf("\n BOOT signature does not equal 0xAA55:  %04Xh", ((unsigned short *) sector)[255]);
    return -4;
	}

	// extract the BPB
	memcpy(&bpb, sector+3, sizeof(bpb));

	//print the BPB
	printf("\n   BIOS Parameter Block:"
		   "\n               OEM Name:  %c%c%c%c%c%c%c%c"
		   "\n       Bytes per sector:  %i"
		   "\n    Sectors per cluster:  %i"
		   "\n       Reserved Sectors:  %i"
		   "\n                   FATs:  %i"
		   "\n   Maximum ROOT entries:  %i  (%i sectors)",
		   bpb.oemname[0], bpb.oemname[1], bpb.oemname[2], bpb.oemname[3], bpb.oemname[4],
		   bpb.oemname[5], bpb.oemname[6], bpb.oemname[7],
		   bpb.nBytesPerSec,
		   bpb.nSecPerClust,
		   bpb.nSecRes,
		   bpb.nFATs,
       bpb.nRootEnts, ((bpb.nRootEnts * sizeof(struct ROOT)) / bpb.nBytesPerSec));
	printf("\n          Total Sectors:  %i"
		   "\n             Media Byte:  %02Xh"
		   "\n        Sectors per FAT:  %i"
		   "\n      Sectors per Track:  %i"
		   "\n                  Heads:  %i"
		   "\n         Hidden Sectors:  %i"
		   "\n          Reserved byte:  %02X (FYSOS uses for FAT type)",
           bpb.nSecs,
		   bpb.mDesc,
		   bpb.nSecPerFat,
		   bpb.nSecPerTrack,
		   bpb.nHeads,
		   bpb.nSecHidden,
		   bpb.nResByte);
	printf("\n               Sig Byte:  %02X"
		   "\n          Serial Number:  %04X-%04X"
		   "\n            Volume Name:  %c%c%c%c%c%c%c%c%c%c%c"
		   "\n                FS Type:  %c%c%c%c%c%c%c%c",
		   bpb.sig,
		   bpb.SerNum >> 16, bpb.SerNum & 0xFFFFL,
		   bpb.VolName[0], bpb.VolName[1], bpb.VolName[2], bpb.VolName[3], bpb.VolName[4],
		   bpb.VolName[5], bpb.VolName[6], bpb.VolName[7], bpb.VolName[8], bpb.VolName[9],
		   bpb.VolName[10],
		   bpb.FSType[0], bpb.FSType[1], bpb.FSType[2], bpb.FSType[3], bpb.FSType[4],
		   bpb.FSType[5], bpb.FSType[6], bpb.FSType[7]);


	// Figure what type of FAT it is:
  i = (((bpb.nRootEnts * sizeof(struct ROOT)) + (bpb.nBytesPerSec - 1)) / bpb.nBytesPerSec);
	j = (bpb.nSecs - (bpb.nSecRes + (bpb.nFATs * bpb.nSecPerFat) + i));
	if ((unsigned short)(j / bpb.nSecPerClust) < 4085) {
		printf("\n Calculated FAT12");
		if (memcmp(&bpb.FSType, "FAT12   ", 8)) {
			printf(" FS type in BPB not 'FAT 12  '");
      return -5;
		}
		fattype = FAT12;
	} else if ((unsigned short)(j / bpb.nSecPerClust) < 65525) {
		printf("\n Calculated FAT16");
		if (memcmp(&bpb.FSType, "FAT16   ", 8)) {
			printf(" FS type in BPB not 'FAT 16  '");
      return -6;
		}
		fattype = FAT16;
	} else {
		printf("\n Calculated FAT32");
		if (memcmp(&bpb.FSType, "FAT32   ", 8)) {
			printf(" FS type in BPB not 'FAT 32  '");
      return -7;
		}
		fattype = FAT32;
	}

	// Skip to FAT if bpb.nSecRes > 1
	for (i=1; i<bpb.nSecRes; i++) {
		if (!read_sectors(fp, sector, 1)) {
			printf("\nError reading from file");
      return -9;
		}
	}
	
	// allocate FAT buffer
	if (!(fat = (unsigned char *) calloc((512*bpb.nSecPerFat), sizeof(unsigned char)))) {
		printf("\nError allocating FAT buffer");
    return -8;
	}
	// Now read in the FAT
	if (!read_sectors(fp, fat, bpb.nSecPerFat)) {
		printf("\nError reading from file");
    return -10;
	}

	// Skip any extra FATs
	for (i=0; i<(bpb.nSecPerFat*(bpb.nFATs-1)); i++) {
		if (!read_sectors(fp, sector, 1)) {
			printf("\nError reading from file");
      return -11;
		}
	}

	// allocate ROOT buffer
  if (!(root = (struct ROOT *) calloc(bpb.nRootEnts, sizeof(struct ROOT)))) {
		printf("\nError allocating ROOT buffer");
    return -8;
	}
	// Now read in the ROOT
  if (!read_sectors(fp, root, ((bpb.nRootEnts * sizeof(struct ROOT)) / bpb.nBytesPerSec))) {
		printf("\nError reading from file");
    return -12;
	}

	// Print info about all file entrys
	for (i=0; i<bpb.nRootEnts; i++) {
		// if root[i].name[0] == '\0', we can quit looking per DOS 2.x's specs of a FAT
		if (root[i].name[0] && ((unsigned char) root[i].name[0] != 0xE5)) {
			if (root[i].attrb == 0x0F) { // is LFN entry
				printf("\n Is LFN slot entry");
			} else {
				printf("\n\n  Root entry at slot % 4i:"
					   "\n                     Name:  %c%c%c%c%c%c%c%c.%c%c%c"
					   "\n                Attribute:  %s"
					   "\n                     Time:  %02i:%02i:%02i"
					   "\n                     Date:  %04i %s %02i"
					   "\n                File Size:  %i"
  					   "\n         Starting Cluster:  %06X"
					   "\n                FAT Chain:",
					   i,
					   root[i].name[0], root[i].name[1], root[i].name[2], root[i].name[3],
					   root[i].name[4], root[i].name[5], root[i].name[6], root[i].name[7],
					   root[i].ext[0], root[i].ext[1], root[i].ext[2],
                       bits((unsigned long) root[i].attrb, sizeof(root[i].attrb)*8),
					   (root[i].time >> 11), ((root[i].time & 0x07E0) >> 5), (root[i].time & 0x001F),
					   ((root[i].date >> 9)+1980), month[((root[i].date & 0x01E0) >> 5)-1], (root[i].date & 0x001F),
					   root[i].filesize,
					   root[i].startclust);
				j=0;
				usl = root[i].startclust;
				while ((usl = get_fat_entry(usl, fattype)) < fatend[fattype]) {
					printf("  %06X", usl);
					if (j++ > 3) { printf("\n                          "); j=0; }
				}
			}
		}
	}

	// close the file
	fclose(fp);

	// free memory
	free(sector);
	free(fat);
	free(root);
	
	// return to DOS
	return 0x00;
}

// display bit rep
char *bits(unsigned long ulong, int size) {

	int i;
	char *p = buffer;
	unsigned long bitrep = 0x80000000L;

	bitrep >>= (32-size);
	for(i=0; i<size; i++) {
		if (ulong & bitrep)
			*p = '1';
		else
			*p = '0';
		p++;
		bitrep >>= 1;
	}
	*p = '\0';

	return buffer;
}


// Read sector(s) from a file handle
char read_sectors(FILE *fp, void *ptr, unsigned short cnt) {

	if (fread(ptr, 512, cnt, fp) < cnt) return FALSE;
	return TRUE;
}

// Get FAT entry
unsigned  long get_fat_entry(unsigned  long start, unsigned char type) {

	unsigned  long usl;

	switch (type) {
		case FAT12:
			usl = (start >> 1) + start;
			if (start & 1) {  // if odd, get high 12 bits
				return (*((unsigned short *)(fat+usl))) >> 4;
			} else {        // if even, get low 12 bits
				return (*((unsigned short *)(fat+usl))) & 0x0FFF;
			}
		case FAT16:
			return fat[start];
		case FAT32:
			return (*((unsigned long *)(fat+(start<<2))));
		default:
			return 0x00;
	}
}

