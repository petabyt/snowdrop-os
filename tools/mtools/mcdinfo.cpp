/************************************************************************ 
  MCDINFO  Get CD Information              v00.10.20
  Forever Young Software      Benjamin David Lunt

  This utility was desinged for use with Bochs to get the
    info from a CDROM.

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
  - 
  
  ********************************************************

  Compiles as is with MS VC++ 6.x         (Win32 .EXE file)

	// ****** I am sure it will.  You just have to copy all those
	//   Windows.h files.... yeekkk.
  To compile using DJGPP:  (http://www.delorie.com/djgpp/)
     gcc -Os mkdosfs.c -o mkdosfs.exe -s  (DOS .EXE requiring DPMI)

	// ****** Requires an NT machine.  No DOS support here *****
  //Compiles as is with MS QC2.5            (TRUE DOS only)


  ********************************************************

  Usage:
    When reading a physical CD, just run the file
    When reading an ISO image, give image name on command line

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

#include "mcdinfo.h"   // our include

#define CD_FRAMESIZE 2048

HANDLE hFile;
char drive[128], temp[128], drvletter;
unsigned long ntemp, pos, n;
unsigned char *pathtable;
int i, j;

char months[12][4] = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

//// ***** WARNING.  At current, this only works on NT machines **********
//                    When reading actual CD's

int main(int argc, char *argv[]) {
  
  char temp_str[256];
  
	// print start string
	fprintf(stderr, strtstr);

  if (argc == 2) {
    strcpy(drive, argv[1]);
  } else {
	  fprintf(stderr, "\n *** Warning.  This currently only works on WinNT machines ***");
	  fprintf(stderr, "\n   Continue (Yes or No): ");
	  gets(temp);
	  if (strcmp(temp, "Y") && strcmp(temp, "Yes") && strcmp(temp, "YES"))
		  return 0xFF;

	  do {
		  fprintf(stderr, "\n                         Drive letter [d]: ");
		  gets(temp);
		  if (!strlen(temp))
			  drvletter = 'd';
		  else
			  drvletter = tolower(temp[0]);
	  } while ((drvletter < 'd') || (drvletter > 'z'));
	  sprintf(drive, "\\\\.\\%c:", drvletter);
  }

	hFile = CreateFile((char *)&drive, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, NULL); 
	if (hFile == INVALID_HANDLE_VALUE) {
    printf("\n Error opening file/drive.");
    return -2;
  }
  
	pos = SetFilePointer(hFile, (16*CD_FRAMESIZE), NULL, SEEK_SET);
	ReadFile(hFile, (void *) &pvd, CD_FRAMESIZE, (unsigned long *) &ntemp, NULL);
	if (ntemp != CD_FRAMESIZE) {
    printf("\n Did not read all of the pvd");
    return -3;
  }
	
	memset(temp, 0, sizeof(temp));
  printf("\n                Label:  value  <normal>"
         "\n -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
	printf("\n                 Type:  %i      <1-3>", pvd.type);
  if ((pvd.type < 1) || (pvd.type > 3)) {
    printf("\n **** We only know about type 1, 2, or type 3.");
    exit(1);
  }
  
  if ((pvd.type >= 1) && (pvd.type <= 2)) {
	  memcpy(temp, pvd.ident, 5);
	  printf("\n  Standard Identifier:  %5s  <CD001>"
		       "\n   Descriptor Version:  %i      <1>", temp, pvd.ver);
    if (pvd.type == 1)
      printf("\n         Unused Field:  %02X     <00>", pvd.resv0);
    else
      printf("\n         Volume Flags:  %02X     <00>", pvd.vflags);
    memcpy(temp_str, pvd.sys_ident, 32);
    temp_str[32] = 0;
    printf("\n    System Identifier:  [%s]", temp_str);
    memcpy(temp_str, pvd.vol_ident, 32);
    temp_str[32] = 0;
    printf("\n    Volume Identifier:  [%s]", temp_str);
    printf("\n         Unused Field:  %02X %02X %02X %02X %02X %02X %02X %02X  <zeros>",
      pvd.resv1[0], pvd.resv1[1], pvd.resv1[2], pvd.resv1[3], pvd.resv1[4], pvd.resv1[5], pvd.resv1[6], pvd.resv1[7]);
    printf("\n    Sectors in Volume:  %i {%i} (%3.2f meg)", pvd.num_lbas, ENDIAN_32U(pvd.num_lbas_b), (double) ((double) pvd.num_lbas / 512));
  
    if (pvd.type == 1) {
      printf("\n         Unused Field:  %02X %02X %02X %02X %02X %02X %02X %02X  <zeros>",
        pvd.resv2[0], pvd.resv2[1], pvd.resv2[2], pvd.resv2[3], pvd.resv2[4], pvd.resv2[5], pvd.resv2[6], pvd.resv2[7]);
      printf("\n                        %02X %02X %02X %02X %02X %02X %02X %02X  <zeros>",
        pvd.resv2[8], pvd.resv2[9], pvd.resv2[10], pvd.resv2[11], pvd.resv2[12], pvd.resv2[13], pvd.resv2[14], pvd.resv2[15]);
      printf("\n                        %02X %02X %02X %02X %02X %02X %02X %02X  <zeros>",
        pvd.resv2[16], pvd.resv2[17], pvd.resv2[18], pvd.resv2[19], pvd.resv2[20], pvd.resv2[21], pvd.resv2[22], pvd.resv2[23]);
      printf("\n                        %02X %02X %02X %02X %02X %02X %02X %02X  <zeros>",
        pvd.resv2[24], pvd.resv2[25], pvd.resv2[26], pvd.resv2[27], pvd.resv2[28], pvd.resv2[29], pvd.resv2[30], pvd.resv2[31]);
    } else if (pvd.type == 2) {
      printf("\n     Escape Sequences:");
      debug(pvd.escape_sequ, 32);
    } 
  
    printf("\n      Volume Set Size:  %i {%i}", pvd.set_size, ENDIAN_16U(pvd.set_size_b));
    printf("\n  Volume Sequence num:  %i {%i}", pvd.sequ_num, ENDIAN_16U(pvd.sequ_num_b));
    printf("\n   Logical Block Size:  %i {%i} <2048>", pvd.lba_size, ENDIAN_16U(pvd.lba_size_b));
		     
    ntemp = (pvd.path_table_size / CD_FRAMESIZE) + (pvd.path_table_size % CD_FRAMESIZE ? 1 : 0); 
    printf("\n      Path Table Size:  %i {%i} (%i sectors)", pvd.path_table_size, ENDIAN_32U(pvd.path_table_size_b), ntemp);
  
	  printf("\n  Path Table Location:  %i", pvd.PathL_loc);
	  printf("\n OPath Table Location:  %i", pvd.PathLO_loc);
	  printf("\n MPath Table Location:  %i (big-endian)", ENDIAN_32U(pvd.PathM_loc));
	  printf("\nMOPath Table Location:  %i (big-endian)", ENDIAN_32U(pvd.PathMO_loc));
    
    printf("\n  *** Root  ***"
           "\n         Entry Length:  %i <34>", pvd.root.len);
    printf("\n      Extended Attrib:  %i <2>", pvd.root.e_attrib);
    printf("\n      Extent Location:  %i {%i}", pvd.root.extent_loc, ENDIAN_32U(pvd.root.extent_loc_b));
    printf("\n          Data Length:  %i {%i}  (%i sectors)", pvd.root.data_len, ENDIAN_32U(pvd.root.data_len_b),
      ((pvd.root.data_len / CD_FRAMESIZE) + (pvd.root.data_len % CD_FRAMESIZE ? 1 : 0)));
    printf("\n        Date and Time:  %02i%s%4i %02i:%02i:%02i%c (GMT %i)", 
      pvd.root.date.day, months[pvd.root.date.month-1], pvd.root.date.since_1900 + 1900,
      (pvd.root.date.hour <= 12) ? pvd.root.date.hour : pvd.root.date.hour - 12, pvd.root.date.min, pvd.root.date.sec, 
      (pvd.root.date.hour <= 12) ? 'a' : 'p', pvd.root.date.gmt_off);
  
    printf("\n                Flags:  %i", pvd.root.flags);
    printf("\n            Unit Size:  %i", pvd.root.unit_size);
    printf("\n  Interleave Gap Size:  %i", pvd.root.gap_size);
    printf("\n  Volume Sequence Num:  %i {%i}", pvd.root.sequ_num, ENDIAN_16U(pvd.root.sequ_num_b));
    printf("\n    File Ident Length:  %i <1>", pvd.root.fi_len);
    printf("\n           Identifier:  %i <0>", pvd.root.ident);
  
    memcpy(temp_str, pvd.set_ident, 127);
    temp_str[127] = 0;
    printf("\nVolume Set Identifier: [%s]", temp_str);
    
    memcpy(temp_str, pvd.pub_ident, 127);
    printf("\n Publisher Identifier: [%s]", temp_str);
    
    memcpy(temp_str, pvd.prep_ident, 127);
    printf("\n  Preparer Identifier: [%s]", temp_str);
    
    memcpy(temp_str, pvd.app_ident, 127);
    printf("\n       App Identifier: [%s]", temp_str);
    
    memcpy(temp_str, pvd.copy_ident, 37);
    temp_str[37] = 0;
    printf("\n Copyright Identifier: [%s]", temp_str);
    
    memcpy(temp_str, pvd.abs_ident, 37);
    printf("\n  Abstract Identifier: [%s]", temp_str);
    
    memcpy(temp_str, pvd.bib_ident, 37);
    printf("\n    Biblio Identifier: [%s]", temp_str);
    
    printf("\n Volume Date and Time:  %s", sprinf_date_time(&pvd.vol_date));
    printf("\n        Last Modified:  %s", sprinf_date_time(&pvd.mod_date));
    printf("\n    Volume Expiration:  %s", sprinf_date_time(&pvd.exp_date));
    printf("\n     Volume Effective:  %s", sprinf_date_time(&pvd.val_date));
  
    printf("\n   File Structure Ver:  %i", pvd.struct_ver);

    printf("\n         Unused Field:  %02X", pvd.resv3);
  
    printf("\n\nApplication Use:");
    debug(pvd.app_use, 512);
  
    printf("\n\nUnused Field:");
    debug(pvd.resv4, 653);
  
    printf("\n\n PATH TABLE ENTRIES:");
	  
    pathtable = (unsigned char *) calloc(CD_FRAMESIZE*ntemp, sizeof(unsigned char));
	  if (pathtable == NULL) {} // TODO: error
	  pos = SetFilePointer(hFile, (pvd.PathL_loc*CD_FRAMESIZE), NULL, SEEK_SET);
	  ReadFile(hFile, (void *) pathtable, CD_FRAMESIZE*ntemp, (unsigned long *) &ntemp, NULL);
	  if (ntemp == 0) {} // TODO: error
	  j = 0;
	  ntemp = 0;
	  do {
		  memset(temp, 0, 128);
		  for (i=0; i<(unsigned char) *pathtable; i++)
			  temp[i] = (char) *(pathtable+8+i);
		  printf("\n Path Table Entry %i"
			     "\n   Logical Block: %i"
			     "\n          Parent: %i"
			     "\n      Identifier: %s"
			     "\n",
			     j++, (unsigned short) *(pathtable+2),
			     (unsigned short) *(pathtable+6), temp
			     );
		  i = 8;
		  i += (unsigned char) *pathtable;
		  i += (unsigned char) *pathtable & 1;
		  pathtable += i;
		  ntemp += i;
	  } while (ntemp < pvd.path_table_size);
  } else if (pvd.type == 3) {
    struct PVD3 *pvd3 = (struct PVD3 *) &pvd;
	  memcpy(temp, pvd3->ident, 5);
	  printf("\n  Standard Identifier:  %5s  <CD001>", temp);
    printf("\n         Unused Field:  %02X     <00>", pvd3->resv0);
    memcpy(temp_str, pvd3->sys_ident, 32);
    temp_str[32] = 0;
    printf("\n    System Identifier:  [%s]", temp_str);
    memcpy(temp_str, pvd3->part_ident, 32);
    temp_str[32] = 0;
    printf("\n Partition Identifier:  [%s]", temp_str);
    printf("\n   Partition Location:  %i {%i}", pvd3->part_location, ENDIAN_32U(pvd3->part_location_b));
    printf("\n       Partition Size:  %i {%i}", pvd3->part_size, ENDIAN_32U(pvd3->part_size_b));
    printf("\n\nApplication Use:");
    debug(pvd3->app_use, 1960);
  }
  
  printf("\n Legend:"
         "\n  []:   Strings are enclosed in [] so to see all characters."
         "\n  {}:   Big Endian values are converted to Little Endian and shown in {}."
         "\n  <>:   These are values that this item should be.  The normal value."
         "\n  ():   More information for the item shown.\n\n");

	CloseHandle(hFile);
	
	return 0x00;
}

//                                             0         1         2         3
//                                             012345678901234567890123456789012
// return a string with the following format:  DD/MM/YYYY  HH:MM:SS.jj (xxx GMT)
char date_string[128];

char *sprinf_date_time(struct DATE_TIME *date) {
  
  strcpy(date_string, "DD/MM/YYYY  HH:MM:SS.jj           ");
  
  memcpy(&date_string[0], date->day, 2);
  memcpy(&date_string[3], date->month, 2);
  memcpy(&date_string[6], date->year, 4);
  
  memcpy(&date_string[12], date->hour, 2);
  memcpy(&date_string[15], date->min, 2);
  memcpy(&date_string[18], date->sec, 2);
  memcpy(&date_string[21], date->jiffies, 2);
  
  sprintf(&date_string[24], "(%i GMT)", date->gmt_off);
  
  date_string[33] = 0;
  
  return date_string;
}

void debug(unsigned char *data, unsigned long size) {

  unsigned long offset = 0;
  unsigned char *temp_buf;
  unsigned i;
  
  while (size) {
    printf("\n   ");
    offset += 16;
    temp_buf = data;
    for (i=0; (i<16) && (i<size); i++)
      printf("%02X%c", *temp_buf++, (i==7) ? ((size>8) ? '-' : ' ') : ' ');
    for (; i<16; i++)
      printf("   ");
    printf("   ");
    for (i=0; (i<16) && (i<size); i++) {
      putch(isprint(*data) ? *data : '.');
      data++;
    }
    size -= i;
  }
}
