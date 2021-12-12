/************************************************************************ 
  MCDINFO  Get CD Image                 v00.10.10
  Forever Young Software      Benjamin David Lunt

  This utility was desinged for use with Bochs to get an
    image from a CDROM.

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
    http://www.fysnet.net/mtools.htm

  Thanks, and thanks to those who contributed to Bochs....

  ********************************************************

  Things to know:
  - This only works with WinXP
  
  ********************************************************

  Compiles as is with MS VC++ 6.x         (Win32 .EXE file)

	// ****** I am sure it will.  You just have to copy all those
	//   Windows.h files.... yeekkk.
  To compile using DJGPP:  (http://www.delorie.com/djgpp/)
     gcc -Os mkdosfs.c -o mkdosfs.exe -s  (DOS .EXE requiring DPMI)

	// ****** Requires an XP machine.  No DOS support here *****
  //Compiles as is with MS QC2.5            (TRUE DOS only)

  ********************************************************

  Usage:
    Nothing.  Just run it...

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

#include <windows.h>

#include "mgetcd.h"   // our include

#define SECT_SIZE 2048

HANDLE cdFile, imgFile;
char drive[16], drvletter;
char filename[128], temp[128];
unsigned long ntemp, ul, last_session_start;
unsigned char buf[SECT_SIZE];
char ret_val;

//// ***** WARNING.  At current, this only works on XP machines **********

int main() {

	// print start string
	printf(strtstr);

	printf("\n *** Warning.  This currently only works on WinXP machines ***");
	printf("\n   Continue (Yes or No): ");
	gets(temp);
	if (strcmp(temp, "Y") && strcmp(temp, "Yes") && strcmp(temp, "YES"))
		return 0xFF;

	printf("\n  Filename of image to create [cdrom.img]: ");
	gets(filename);
	if (!strlen(filename)) strcpy(filename, "cdrom.img");

	do {
		printf("                         Drive letter [d]: ");
		gets(temp);
		if (!strlen(temp))
			drvletter = 'd';
		else
			drvletter = tolower(temp[0]);
	} while ((drvletter < 'd') || (drvletter > 'z'));
	sprintf(drive, "\\\\.\\%c:", drvletter);

	imgFile = CreateFile(filename, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_FLAG_RANDOM_ACCESS, NULL);
	if (imgFile == INVALID_HANDLE_VALUE) {} // TODO: error

	cdFile = CreateFile(drive, GENERIC_READ, FILE_SHARE_READ|FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (cdFile == INVALID_HANDLE_VALUE) {
		printf("\n ERROR opening drive: %i", GetLastError());
		return 0;
	}

	// Lock the compact disc in the CD-ROM drive to prevent accidental removal while reading from it.
//	PREVENT_MEDIA_REMOVAL pmrLockCDROM;
//	pmrLockCDROM.PreventMediaRemoval = TRUE;
//	DeviceIoControl (cdFile, IOCTL_CDROM_MEDIA_REMOVAL,	&pmrLockCDROM, sizeof(pmrLockCDROM), NULL, 0, &ntemp, NULL);

	CDROM_READ_TOC_EX input;
	memset(&input, 0, sizeof(input));
	input.Format = CDROM_READ_TOC_EX_FORMAT_SESSION;
	input.Msf = FALSE;

	CDROM_TOC_SESSION_DATA *data = (CDROM_TOC_SESSION_DATA *) VirtualAlloc(NULL, 2048*2, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE);
	DeviceIoControl(cdFile, IOCTL_CDROM_READ_TOC_EX, &input, sizeof(input), data, sizeof(CDROM_TOC_SESSION_DATA), &ntemp, NULL);
	
	last_session_start = (data->TrackData[0].Address[0] << 24) | (data->TrackData[0].Address[1] << 16) | 
		(data->TrackData[0].Address[2] << 8) | (data->TrackData[0].Address[3] << 0);

	printf("\n Found %i session(s).", data->LastCompleteSession - data->FirstCompleteSession + 1);

	struct PVD *pvd = (struct PVD *) VirtualAlloc(NULL, 2048*2, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE);
	SetFilePointer(cdFile, ((last_session_start+16)*SECT_SIZE), NULL, SEEK_SET);
	ret_val = ReadFile(cdFile, pvd, SECT_SIZE, (unsigned long *) &ntemp, NULL);
	if (memcmp(pvd->ident, "CD001", 5) != 0) {
		printf("\n Did not file ""CD001"" signature at found session start");
		return 0xFF;
	}

	
	//////////////
	// does pvd->num_lbas include all sectors, or just the size of the actual data sectors?
	//  do we need to add the 3*16 sectors + all path sectors + all dir sectors?
	//  what other sectors are there?



	printf("\n\n");
	SetFilePointer(cdFile, 0, NULL, SEEK_SET);
	char *sector = (char *) VirtualAlloc(NULL, 2048*2, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE);
	for (ul=0; ul<pvd->num_lbas; ul++) {
		printf("\r Sector %i of %i", ul, pvd->num_lbas);
		//SetFilePointer(cdFile, (ul*SECT_SIZE), NULL, FILE_BEGIN);
		ret_val = ReadFile(cdFile, sector, SECT_SIZE, (unsigned long *) &ntemp, NULL);
		if (ret_val && (ntemp == SECT_SIZE))
			WriteFile(imgFile, sector, SECT_SIZE, (unsigned long *) &ntemp, NULL);
		else if (!ret_val && (ntemp == 0)) {
			memset(sector, 0, SECT_SIZE);
			WriteFile(imgFile, sector, SECT_SIZE, (unsigned long *) &ntemp, NULL);
		} else {
			printf("\n There was an unknown type of error");
			break;
		}
	}

	// Unlock the disc in the CD-ROM drive.
//	pmrLockCDROM.PreventMediaRemoval = FALSE;
//	DeviceIoControl(cdFile, IOCTL_CDROM_MEDIA_REMOVAL, &pmrLockCDROM, sizeof(pmrLockCDROM), NULL, 0, &ntemp, NULL);

	VirtualFree(pvd, 0, MEM_RELEASE);
	VirtualFree(data, 0, MEM_RELEASE);
	VirtualFree(sector, 0, MEM_RELEASE);

	CloseHandle(cdFile);
	CloseHandle(imgFile);
	
	return 0x00;
}
