
/************************************************************************ 
	MGETIMG  Get Logical Disk Image      v00.15.10
  Forever Young Software      Benjamin David Lunt

  This utility was desinged for use with Bochs to get a
    logical disk image.

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

  Thanks, and thanks to those who contribute(d) to Bochs....

  ********************************************************

  Things to know:
  - Currently, this app only allows the floppy disk sizes
    specified in the main menu upon execution.  If you would
    like me to add another format or size, please let me know.
    (address below)
	- However, this app does allow you to read a logical
	  partition on a hard drive.  Please note that this 'partition'
		must have 63 sectors_per_track and 16 heads.
  - This app reads full tracks at a time to make it quicker.

  ********************************************************

  (not yet) To compile using DJGPP:  (http://www.delorie.com/djgpp/)
            gcc -Os mgetimg.c -o mgetimg.exe -s  (DOS .EXE requiring DPMI)

  Compiles as is with MS VC++ 6.x         (WinNT .EXE file)
	 **** Requires WinNT machine ***

  ********************************************************

  Usage:
    Simply answer the questions given.  Hit <enter> for the
     default of any question that has a default value in []'s.
    That's it....

************************************************************************/


//#define WINNT    // to compile for WINNT
//#define WIN95    // to compile for WIN95
// To compile with DJGPP for DOS (and DPMI) don't define anything here


#if defined(WINNT) && (defined(WIN95) || defined(DJGPP))
	#error Must not define multiple targets 1
#elif defined(WIN95) && (defined(WINNT) || defined(DJGPP))
	#error Must not define multiple targets 2
#elif defined(DJGPP) && (defined(WINNT) || defined(WIN95))
	#error Must not define multiple targets 3
#endif

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
#include <dos.h>

#include "mgetimg.h"   // our include

#if defined(WINNT) | defined(WIN95)
  #include <windows.h>
	HANDLE logical_drv;
#elif defined(DJGPP)
  #include <dpmi.h>
  #include <go32.h>
  #define TRUE    1
  #define FALSE   0
  #define bool char
	unsigned  char *fbuffer;
#else
	#error Must define a target platform
#endif

FILE *fp;

unsigned  char *buffer;          // a temp buffer
					char filename[80];     // filename
					char temp[128];
		  char drv_type[80];         // drive type
		  char drv_letter[80];       // drive letter (A, B)
		  char yesno[80];            // yes no

struct DISK_TYPE *disk_info;

#if defined(WINNT) | defined(WIN95)
	bool read_track(char *drv_letter, unsigned long cyl, unsigned long side, unsigned char *ptr, unsigned long spt);
#else
	bool read_track(char drv_letter, unsigned long cyl, unsigned long side, unsigned char *ptr, unsigned long spt);
#endif	
void write_sectors(FILE *fp, unsigned char *ptr, unsigned long cnt);

int main() {

	unsigned i, j;

	// print start string
	printf(strtstr);

#if defined(WINNT)
  // Make sure we are a version of Windows that allows direct disk access.
  OSVERSIONINFO os_ver_info;
  os_ver_info.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
  GetVersionEx(&os_ver_info);
  if (os_ver_info.dwMajorVersion < 5) {
    printf("\nThis utility only works with WinXP and possibly earlier vesrions of WinNT");
    if (os_ver_info.dwPlatformId == VER_PLATFORM_WIN32_NT) {
      printf("\nDid not find WinXP, but did find an NT version of Windows.  Continue? (Y|N)");
      gets(temp);
      if (strcmp(temp, "Y") && strcmp(temp, "Yes") && strcmp(temp, "YES"))
        return 0xFF;
    } else
      return 0xFF;
  }
#elif defined(WIN95)
	printf("\n *** Warning.  This currently only works on Win95 machines ***");
	printf("\n ***           If you are using a WinNT machine, recompile. ***");
	printf("\n   Continue (Yes or No): ");
	gets(temp);
	if (strcmp(temp, "Y") && strcmp(temp, "Yes") && strcmp(temp, "YES"))
		return 0xFF;
#endif

	// print menu string
	printf(menustr);

	// get menu item
	do {
		printf("\n            Please choose a number (0-F) [7]: ");
		gets(drv_type);
		if (!strlen(drv_type)) { strcpy(drv_type, "7"); break; }
	} while (!isxdigit(drv_type[0]));

	// get target file name
	printf("               As filename [logical_drv.img]: ");
	gets(filename);
	if (!strlen(filename)) strcpy(filename, "logical_drv.img");

	switch (toupper(drv_type[0])) {
		case '0':
			disk_info = &disk160;
			break;
		case '1':
			disk_info = &disk180;
			break;
		case '2':
			disk_info = &disk320;
			break;
		case '3':
			disk_info = &disk360;
			break;
		case '4':
		case '5':
			disk_info = &disk720;
			break;
		case '6':
			disk_info = &disk1220;
			break;
		case '7':
			disk_info = &disk1440;
			break;
		case '8':
			disk_info = &disk1720;
			break;
		case '9':
			disk_info = &disk2880;
			break;
		case 'A':
			disk_info = &harddisk;
			// get cylinder count
			do {
				printf("Please enter cylinder count (decimal) [1000]: ");
				gets(temp);
				if (!strlen(temp)) { disk_info->cylinders = 1000; break; }
			} while (!(disk_info->cylinders = atol(temp)));
			disk_info->total_sects = (unsigned long long) disk_info->cylinders * disk_info->sec_per_track * disk_info->num_heads;
			disk_info->size = disk_info->total_sects << 9;
			break;
		case 'B':
		case 'C':
		case 'D':
		case 'E':
		case 'F':
			return 0x00;
	}

	// get drive letter
	do {
		printf("Please choose a drive letter (A, B, C, D, ...) [A]: ");
		gets(drv_letter);
		if (!strlen(drv_letter)) { strcpy(drv_letter, "A"); break; }
		drv_letter[0] = toupper(drv_letter[0]);
	} while ((drv_letter[0] < 'A') || (drv_letter[0] > 'Z'));

#if defined(WINNT)
	sprintf(drv_letter, "\\\\.\\%c:", toupper(drv_letter[0]));
#else
	drv_letter[0] = toupper(drv_letter[0]) - 'A';
#endif

  // TODO: make sure disk is in drive and ready (if floppy)
	//       check disk is ready (if hard drive)

	// print info   
	printf("\n       Creating file:  %s"
		   "\n           Cylinders:  %i"
		   "\n               Sides:  %i"
		   "\n       Sectors/Track:  %i"
#if defined(WINNT) | defined(WIN95)
			 "\n       Total Sectors:  %I64i"
			 "\n                Size:  %I64i",
#else
       "\n       Total Sectors:  %lli"
       "\n                Size:  %lli",
#endif
		   filename, disk_info->cylinders, disk_info->num_heads, disk_info->sec_per_track,
		   disk_info->total_sects, disk_info->size);

	// make sure
	printf("\n  Is this correct? (Y or N) [Y]: ");
	gets(yesno);
	if (!strlen(yesno)) strcpy(yesno, "Y");
	if (strcmp(yesno, "Y")) {
		printf("\nAborting...");
		return 0xFF;
	}

	// create image file
	if ((fp = fopen(filename, "w+b")) == NULL) {
		printf("\n Error creating image file");
		return 0x01;
	}

#if defined(WINNT)
	logical_drv = CreateFile((char *)&drv_letter, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, NULL);
	if (logical_drv == (void *)0xFFFFFFFF) {} // TODO: error
#elif defined(WIN95)
	logical_drv = CreateFile("\\\\.\\vwin32", 0, 0, NULL, 0, FILE_FLAG_DELETE_ON_CLOSE, NULL);
	if (logical_drv == (void *)0xFFFFFFFF) {} // TODO: error
#endif

	// allocate mem
	if (!(buffer = (unsigned char *) calloc(disk_info->sec_per_track * 512, sizeof(unsigned char)))) {
		printf("\nError allocating buffer");
		return 0x08;
	}

	printf("\n");

	// do it
	for (i=0; i<disk_info->cylinders; i++) {
		for (j=0; j<disk_info->num_heads; j++) {
			printf("\rReading cyl %i (of %i), side %02i", i, disk_info->cylinders-1, j);
#if defined(WINNT) | defined(WIN95)
      if (!read_track((char *)&drv_letter, i, j, buffer, disk_info->sec_per_track)) {
        i=disk_info->cylinders;
        break;
      }
#else
      if (!read_track(drv_letter[0], i, j, buffer, disk_info->sec_per_track)) {
        i=disk_info->cylinders;
        break;
      }
#endif
			write_sectors(fp, buffer, disk_info->sec_per_track);
		}
	}

	// close the file
	fclose(fp);

#if defined(WINNT) | defined(WIN95)
	CloseHandle(logical_drv);
#endif

	// free buffer
	free(buffer);

	return 0x00;
}

// Read a track
#if defined(WINNT) | defined(WIN95)
	bool read_track(char *drv_letter, unsigned long cyl, unsigned long side, unsigned char *ptr, unsigned long spt) {
#else
	bool read_track(char drv_letter, unsigned long cyl, unsigned long side, unsigned char *ptr, unsigned long spt) {
#endif	

	unsigned short status;
	unsigned t;

#if defined(WINNT)
	unsigned long ntemp;
#elif defined(WIN95)
	DIOC_REGISTERS reg;
	unsigned long cb;
	static unsigned long win95_start = 0;
#else
	__dpmi_regs regs;
#endif

	for (t=0; t<3; t++) {
#if defined(WINNT)
		ReadFile(logical_drv, (void *) ptr, (512 * spt), (unsigned long *) &ntemp, NULL);
    if (ntemp == 0) {
      printf("\n Error: %i", GetLastError());
      break;
    } else
			status = FALSE;
#elif defined(WIN95)
		reg.reg_ECX = spt;
		reg.reg_EDX = win95_start;
		reg.reg_EBX = (unsigned long) ptr;
		reg.reg_EAX = drv_letter[0];
		reg.reg_Flags = 0x0001;     // assume error (carry flag is set) 
		status = (DeviceIoControl(logical_drv, VWIN32_DIOC_DOS_INT25, 
       &reg, sizeof(reg), &reg, sizeof(reg), &cb, NULL) == 0);
		//if (!status & (reg.reg_Flags & 0x0001)) status = TRUE;
		win95_start += spt;
#else
    int ret_sel;
    int seg = __dpmi_allocate_dos_memory(((512*spt)+15)>>4, &ret_sel);
    
		regs.h.ah = 0x02;
		regs.h.al = spt;
		regs.h.ch = cyl;
		regs.h.cl = 1;
		regs.h.dh = side;
		regs.h.dl = drv_letter;
		regs.x.bx = 0x0000;
		regs.x.es = seg;
    __dpmi_int(0x13, &regs);
		status = regs.x.flags;
    
    dosmemget(seg << 4, (512*spt), ptr);
    __dpmi_free_dos_memory(ret_sel);
    
#endif
		if (!(status & 0x01)) return TRUE;
	}
	printf("\nError reading from drive.  Continue? [N]\n");
	gets(yesno);
	if (!strlen(yesno)) strcpy(yesno, "N");
	if (strcmp(yesno, "N") == 0) 
    return FALSE;
  else
    return TRUE;
}

// Write sector(s)
void write_sectors(FILE *fp, unsigned char *ptr, unsigned long cnt) {
	if (fwrite(ptr, 512, cnt, fp) < cnt) {
		printf("\n **** Error writing to file ****");
		exit(0xFF);
	}
}
