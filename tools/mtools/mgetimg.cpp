/*
 * MGETIMG  Get Logical Disk Image                   v00.20.00
 * Forever Young Software                  Benjamin David Lunt
 * 
 * This code is for WinXP only...
 * 
 * Usage:
 *   Simply answer the questions given.  Hit <enter> for the
 *    default of any question that has a default value in []'s.
 *   That's it....
 *  
 */

#include <windows.h>
#include <stdio.h>

#include "ctype.h"   // our types include
#include "mgetimg.h"     // our include

 FILE *fp;
bit8u *buffer;          // a temp buffer
 char filename[80];     // filename
 char temp[128];
 char drv_type[80];     // drive type
 char drv_letter[80];   // drive letter (A, B)
 char yesno[80];        // yes no
 char diff = ' ';
struct DISK_TYPE *disk_info;

int main(int argc, char *argv[]) {
  
  // print start string
  printf(strtstr);
  
  // Make sure we are a version of Windows that allows direct disk access.
  OSVERSIONINFO os_ver_info;
  os_ver_info.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
  GetVersionEx(&os_ver_info);
  if (os_ver_info.dwMajorVersion < 5) {
    printf("\nThis utility only works with WinXP and possibly earlier versions of WinNT");
    if (os_ver_info.dwPlatformId == VER_PLATFORM_WIN32_NT) {
      printf("\nDid not find WinXP, but did find an NT version of Windows.  Continue? (Y|N)");
      gets(temp);
      if (strcmp(temp, "Y") && strcmp(temp, "Yes") && strcmp(temp, "YES"))
        return -1;
    } else
      return -1;
  }
  
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
      // get sector count
      do {
        printf("Please enter a count of sectors to read (decimal) [201600]: ");  // default to 200 cylinders
        gets(temp);
        if (!strlen(temp)) { disk_info->total_sects = 201600; break; }
      } while (!(disk_info->total_sects = atol(temp)));
      disk_info->size = disk_info->total_sects << 9;
      disk_info->cylinders = (bit32u) (disk_info->total_sects / (63 * 16)); // assuming 16 heads, 63 sectors per track
      disk_info->num_heads = 16;
      disk_info->sec_per_track = 63;
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
  
  sprintf(drv_letter, "\\\\.\\%c:", drv_letter[0]);
  
  // TODO: make sure disk is in drive and ready (if floppy)
  //       check disk is ready (if hard drive)
  
  // print info   
  if ((disk_info->cylinders * disk_info->num_heads * disk_info->sec_per_track) != disk_info->total_sects)
    diff = '*';
  printf("\n       Creating file:  %s"
       "\n           Cylinders:  %i%c"
       "\n               Sides:  %i"
       "\n       Sectors/Track:  %i"
       "\n       Total Sectors:  %" LL64BIT "i"
       "\n                Size:  %" LL64BIT "i",
       filename, disk_info->cylinders, diff, disk_info->num_heads, disk_info->sec_per_track,
       disk_info->total_sects, disk_info->size);
  if (diff == '*')
    printf("\n*Total Sectors doesn't match cylinder boundary.");
  
  // make sure
  printf("\n  Is this correct? (Y or N) [Y]: ");
  gets(yesno);
  if (!strlen(yesno)) strcpy(yesno, "Y");
  if (strcmp(yesno, "Y")) {
    printf("\nAborting...");
    return -1;
  }
  
  // create image file
  if ((fp = fopen(filename, "w+b")) == NULL) {
    printf("\n Error creating image file");
    return -1;
  }
  
  HANDLE logical_drv = CreateFile((char *) &drv_letter, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, NULL);
  if (logical_drv == (void *) 0xFFFFFFFF) {
    printf("\n Error opening logical drive.");
    return -1;
  }
  
  // allocate mem
  if (!(buffer = (bit8u *) calloc(disk_info->sec_per_track * 512, sizeof(bit8u)))) {
    printf("\nError allocating buffer");
    return -8;
  }
  
  printf("\n");
  
  // do the read
  bit32u cnt;
  bit64u i = disk_info->total_sects;
  bit64u j = 0;
  while (i) {
    printf("\rReading sector %" LL64BIT "i (of %" LL64BIT "i)     ", j, disk_info->total_sects);
    cnt = ((i >= (bit64u) disk_info->sec_per_track) ? disk_info->sec_per_track : (bit32u) i);
    if (!read_sectors(logical_drv, buffer, j, cnt))
      break;
    if (fwrite(buffer, 512, cnt, fp) < cnt)
      break;
    i -= cnt;
    j += cnt;
  }
  if (i == 0)
    printf("\rSuccessfully read %" LL64BIT "i sectors.      ", disk_info->total_sects);
  
  // close the file
  fclose(fp);
  
  CloseHandle(logical_drv);
  
  // free buffer
  free(buffer);
  
  return 0;
}

// Read a "track" of sectors
bool read_sectors(HANDLE logical_drv, void *ptr, const bit64u lba, const bit32u cnt) {
  bit32u ntemp;
  unsigned t;  // try count (incase of floppies)
  
  for (t=0; t<3; t++) {
    ReadFile(logical_drv, ptr, (512 * cnt), (bit32u *) &ntemp, NULL);
    if (ntemp != (512 * cnt))
      printf("\n Try #%i: Error Reading from sector %" LL64BIT "i (%i)", t, lba, GetLastError());
    else
      return TRUE;
  }
  
  return FALSE;
}
