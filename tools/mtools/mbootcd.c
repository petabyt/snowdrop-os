

// TODO:
//   allow user to set bootcat sector and image sector


/************************************************************************ 
  MKISOFS  Make Bootable CD image       v00.10.10
  Forever Young Software      Benjamin David Lunt

  v00.10.01 - fix root size in bytes instead of a fixed 2048
  v00.10.03 - update to ISO 9660:1999 and fix a small error
  v00.10.05 - added the effective date to the pvd
              (some hardware won't boot if not valid effective date)
  v00.10.10 - corrected the ending boot entry
            - added the required Terminator Volume Record
            - fixed a few other things
  
  This utility was desinged for use with Bochs to make a 
    bootable CD-ROM disk image.

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

  P.S.  Please don't laugh at my code :)  I didn't spend but
   a few minutes on this.  BXimage just wasn't working for my
   needs, so here it is.

  You may get the latest and greatest at:
    http://www.fysnet.net/mtools.htm

  Thanks, and thanks to those who contributed to Bochs....

  ********************************************************

  Things to know:
  - the boot image must be the correct size for the type
      of image.  If it is not, this should still work, filling
      nulls to the rest of the image position in the CD.
  TODO:
  - We could easily ask for filenames to add to the CD
     by asking until ENTER only.  We have already set up
     most of the code, a few changes and the UI part, and
     we could have it add as many files as we wanted.
  - I don't calculate the GMT offset
  
  ********************************************************

  To compile using DJGPP:  (http://www.delorie.com/djgpp/)
     gcc -Os mkdosfs.c -o mkdosfs.exe -s  (DOS .EXE requiring DPMI)

  Compiles as is with MS VC++ 6.x         (Win32 .EXE file)

  Compiles as is with MS QC2.5            (TRUE DOS only)

  ********************************************************

  Usage:
    Simply answer the questions given.  Hit <enter> for the
     default of any question that has a default value in []'s.
    That's it....

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

#define TRUE    1
#define FALSE   0


#define PVD_SECT         16  // 
#define BVD_SECT         17  // 
#define TVD_SECT         18  // Terminator Descriptor is at 18
#define BOOT_CAT_SECT    19  // our boot catalog sector is at 19
#define BOOT_IMG_SECT    20  // our boot image is at 20
#define PATH_SECT_SIZE    1  // path size in sectors
#define ROOT_SECT_SIZE    1  // root size in sectors

#define SECT_SIZE      0x800 // sector size

#define START_SEG      0x0000 // bios boot start seg for 0x07C0 when this is zero

#include "mbootcd.h"   // our include

FILE *cdimg, *bimg;
char filename[128];
char bootimg[128];
char strbuf[128];
unsigned char buf[SECT_SIZE], *bptr;
unsigned long i, img_size, cd_size;
int type = 0;


unsigned long bigendian(unsigned long num, int size);
void fill_date(struct DIR_DATE *date);
void fill_e_date(struct VOL_DATE *date);

int main() {

  // print start string
  printf(strtstr);

  printf("\n              Image type:   0 = no boot image, standard image only"
         "\n                            1 = 1.22m"
         "\n                            2 = 1.44m"
         "\n                            3 = 2.88m"
         "\n                            4 = hard drive");
  do {
    printf("\n          Boot image type  [2]: ");
    gets(strbuf);
    if (!strlen(strbuf))
      type = 2;
    else
      type = atoi(strbuf);
  } while ((type < 0) || (type > 4));

  printf("  Filename of image to create [bootcd.iso]: ");
  gets(filename);
  if (!strlen(filename)) strcpy(filename, "bootcd.iso");

  if (type) {
    printf("        Filename of bootable image [a.img]: ");
    gets(bootimg);
    if (!strlen(bootimg)) strcpy(bootimg, "a.img");
  }

  do {
    printf("    Size of CD in 2048 byte sectors [2048]: ");
    gets(strbuf);
    if (!strlen(strbuf))
      cd_size = 2048;
    else
      cd_size = atoi(strbuf);
  } while ((cd_size < 1024) && (cd_size > 8192));

  switch (type) {
    case 0:
      img_size = 0;
      break;
    case 1:
      img_size = 2400/4;
      break;
    case 2:
      img_size = 2880/4;
      break;
    case 3:
      img_size = 5760/4;
      break;
    case 4:
      do {
        printf("            Size of hard drive image:  ");
        gets(strbuf);
        img_size = atoi(strbuf)/4;
      } while (!img_size);
      break;
    default:
      printf("\n ERROR: shouldn't have gotten here");
      break;
  }

  if ((cdimg = fopen(filename, "wb")) == NULL) {
    printf("\nError creating file [%s]", filename);
    return 0x01;
  }

  if (type) {
    if ((bimg = fopen(bootimg, "r+b")) == NULL) {
      printf("\nError opening file [%s]", bootimg);
      fclose(cdimg);
      return 0x02;
    }
  }

  // first 16 sectors are zero'd
  memset(buf, 0, SECT_SIZE);
  for (i=0; i<16; i++)
    fwrite(buf, SECT_SIZE, 1, cdimg);
  
  // initialize pvd
  memset(&pvd, 0, SECT_SIZE);
  pvd.type = 1;
  memcpy(pvd.ident, "CD001", 5);
  pvd.ver = 1;
  memcpy(pvd.sys_ident, "WINXP                           ", 32);
  memcpy(pvd.vol_ident, "Forever Young Software 1984-2014", 32);
  pvd.num_lbas = cd_size;
  pvd.num_lbas_b = (unsigned long) bigendian(cd_size, 4);
  pvd.set_size = 0x0001;
  pvd.set_size_b = 0x0100;
  pvd.sequ_num = 0x0001;
  pvd.sequ_num_b = 0x0100;
  pvd.lba_size = SECT_SIZE;
  pvd.lba_size_b = (unsigned short) bigendian(SECT_SIZE, 2);
  pvd.path_table_size = PATH_SECT_SIZE*SECT_SIZE;
  pvd.path_table_size_b = (unsigned long) bigendian(PATH_SECT_SIZE*SECT_SIZE, 4);
  pvd.PathL_loc = (unsigned long) (img_size + BOOT_IMG_SECT);
  pvd.PathLO_loc = 0;
  pvd.PathM_loc = (unsigned long) bigendian((img_size + BOOT_IMG_SECT), 4);
  pvd.PathMO_loc = 0;
  pvd.root.len = 34;
  pvd.root.e_attrib = 0;
  pvd.root.extent_loc = (img_size + BOOT_IMG_SECT + PATH_SECT_SIZE);
  pvd.root.extent_loc_b = (unsigned long) bigendian((img_size + BOOT_IMG_SECT + PATH_SECT_SIZE), 4);
  pvd.root.data_len = ROOT_SECT_SIZE*SECT_SIZE;
  pvd.root.data_len_b = (unsigned long) bigendian(ROOT_SECT_SIZE*SECT_SIZE, 4);
  fill_date(&pvd.root.date);
  pvd.root.flags = 0x02;  // directory
  pvd.root.unit_size = 0;
  pvd.root.gap_size = 0;
  pvd.root.sequ_num = 0x0001;
  pvd.root.sequ_num_b = 0x0100;
  pvd.root.fi_len = 1;
  pvd.root.ident = 0;
  memset(pvd.set_ident, 0x20, 128);
  memset(pvd.pub_ident, 0x20, 128);
  memset(pvd.prep_ident, 0x20, 128);
  memset(pvd.app_ident, 0x20, 128);
  strcpy(pvd.app_ident, "Forever Young Software  MBOOTCD.EXE  v00.10.05");
  memset(pvd.copy_ident, 0x20, 37);
  memset(pvd.abs_ident, 0x20, 37);
  memset(pvd.bib_ident, 0x20, 37);
  fill_e_date(&pvd.vol_date);
  fill_e_date(&pvd.mod_date);
  memset(&pvd.exp_date, 0, 17);
  fill_e_date(&pvd.val_date);
  pvd.struct_ver = 1;
  fwrite(&pvd, SECT_SIZE, 1, cdimg);  // sector 16

  if (type) {
    // initialize Boot Primary Volume Descriptor
    memset(&brvd, 0, SECT_SIZE);
    memcpy(brvd.ident, "CD001", 5);
    brvd.ver = 1;
    memcpy(brvd.bsident, "EL TORITO SPECIFICATION", 23);
    brvd.boot_cat = BOOT_CAT_SECT;
    fwrite(&brvd, SECT_SIZE, 1, cdimg);  // sector 17
    
    // advance to sector TVD_SECT and
    // write Term Volume Descriptor sector
    fseek(cdimg, TVD_SECT * SECT_SIZE, SEEK_SET);
    memset(&term, 0, SECT_SIZE);
    term.id = 255;
    memcpy(term.ident, "CD001", 5);
    term.ver = 1;
    fwrite(&term, SECT_SIZE, 1, cdimg);
    
    // advance to sector BOOT_CAT_SECT and
    // write Boot Catalog sector
    fseek(cdimg, BOOT_CAT_SECT * SECT_SIZE, SEEK_SET);
    memset(&boot_cat, 0, SECT_SIZE);
    boot_cat.val_entry.id = 1;
    boot_cat.val_entry.platform = 0;
    boot_cat.val_entry.key55 = 0x55;
    boot_cat.val_entry.keyAA = 0xAA;
    unsigned short crc = 0, *crc_p = (unsigned short *) &boot_cat.val_entry.id;
    for (i=0; i<16; i++)
      crc += crc_p[i];
    boot_cat.val_entry.crc = -crc;
    boot_cat.init_entry.bootable = 0x88;
    boot_cat.init_entry.media = (unsigned char) type;
    boot_cat.init_entry.load_seg = START_SEG;
    boot_cat.init_entry.sys_type = 0;
    boot_cat.init_entry.load_cnt = 1;  // load one sector for boot
    boot_cat.init_entry.load_rba = BOOT_IMG_SECT;
    boot_cat.end_entry.id = 0x90;  // no more entries follow
    fwrite(&boot_cat, SECT_SIZE, 1, cdimg);
    
    cd_size -= ((ftell(cdimg) / SECT_SIZE) + img_size + PATH_SECT_SIZE + ROOT_SECT_SIZE + 1);
    
    // advance to sector BOOT_IMG_SECT
    // and copy boot image
    fseek(cdimg, BOOT_IMG_SECT * SECT_SIZE, SEEK_SET);
    for (i=0; i<img_size; i++) {
      fread(buf, SECT_SIZE, 1, bimg);
      fwrite(buf, SECT_SIZE, 1, cdimg);
    }
  } else {
    memset(buf, 0, SECT_SIZE);
    fwrite(buf, SECT_SIZE, 1, cdimg);  // dummy boot descriptor
    fwrite(buf, SECT_SIZE, 1, cdimg);  // dummy term descriptor ?
    fwrite(buf, SECT_SIZE, 1, cdimg);  // dummy boot catalog
    cd_size -= ((ftell(cdimg) / SECT_SIZE) + PATH_SECT_SIZE + ROOT_SECT_SIZE + 1);
  }
  
  // path table
  memset(buf, 0, SECT_SIZE);
  // only one directory.  The ROOT.
  path_tab.len_di = 1;
  path_tab.ext_attrib = 0;
  path_tab.loc = (img_size + BOOT_IMG_SECT + PATH_SECT_SIZE);
  path_tab.parent = 1;
  memset(path_tab.ident, 0, 2);
  // copy to the path table sector
  memcpy(buf, &path_tab, 8+2);
  fwrite(buf, SECT_SIZE, 1, cdimg);
  
  // root table
  bptr = buf;
  memset(bptr, 0, SECT_SIZE);
  // two directory entrys.  One dir, one file (required?)
  root_tab.len = 34;
  root_tab.e_attrib = 0;
  root_tab.extent_loc = (img_size + BOOT_IMG_SECT + PATH_SECT_SIZE);
  root_tab.extent_loc_b = (unsigned long) bigendian((img_size + BOOT_IMG_SECT + PATH_SECT_SIZE), 4);
  root_tab.data_len = SECT_SIZE;
  root_tab.data_len_b = (unsigned long) bigendian(SECT_SIZE, 4);
  fill_date(&root_tab.date);
  root_tab.flags = 0x02;
  root_tab.unit_size = 0;
  root_tab.gap_size = 0;
  root_tab.sequ_num = 0;
  root_tab.sequ_num_b = 0;
  root_tab.fi_len = 1;
  root_tab.ident = 0;
  // copy to the root table sector
  memcpy(bptr, &root_tab, sizeof(root_tab));
  bptr += sizeof(root_tab);
  // second entry only requires a difference of a 1 as the ident
  root_tab.ident = 1;
  memcpy(bptr, &root_tab, sizeof(root_tab));
  bptr += sizeof(root_tab);

  // A temp file for good measure
  root_tab.len = sizeof(root_tab) - 1 + 12;
  root_tab.e_attrib = 0;
  root_tab.extent_loc = (img_size + BOOT_IMG_SECT + PATH_SECT_SIZE+1);
  root_tab.extent_loc_b = (unsigned long) bigendian((img_size + BOOT_IMG_SECT + PATH_SECT_SIZE+1), 4);
  root_tab.data_len = 46;
  root_tab.data_len_b = (unsigned long) bigendian(SECT_SIZE, 4);
  fill_date(&root_tab.date);
  root_tab.flags = 0;
  root_tab.unit_size = 0;
  root_tab.gap_size = 0;
  root_tab.sequ_num = 0;
  root_tab.sequ_num_b = 0;
  root_tab.fi_len = 12;
  memcpy(bptr, &root_tab, sizeof(root_tab)-1);
  bptr += (sizeof(root_tab)-1);
  memcpy(bptr, "README.TXT;1", 12);
  //bptr += 12;  // for next file if we add one
  fwrite(buf, SECT_SIZE, 1, cdimg);
  // make sure to update  pvd.root.data_len  above to match length of data actually stored.

  // create a file and place after ROOT_SECT
  memset(buf, 0, SECT_SIZE);
  memcpy(buf, "This is a temp file for testing purposes..\015\012\015\012", 46);
  fwrite(buf, SECT_SIZE, 1, cdimg);

  // fill in rest of image with zero's
  memset(buf,0,SECT_SIZE);
  for (i=0; i<cd_size; i++)
    fwrite(buf, SECT_SIZE, 1, cdimg);

  // close the files
  fclose(cdimg);
  if (type) fclose(bimg);
  
  return 0x00;
}

// convert little endian to big endian
unsigned long bigendian(unsigned long num, int size) {

  unsigned long temp = 0;
  int i;
  
  for (i=0; i<size; i++) {
    temp <<= 8;
    temp |= (num & 0xFF);
    num  >>= 8;
  }

  return temp;
}

void fill_date(struct DIR_DATE *date) {

  struct tm *tmptr;
  time_t lt;

  lt = time(NULL);
  tmptr = localtime(&lt);

  date->since_1900 = tmptr->tm_year;
  date->month      = tmptr->tm_mon;
  date->day        = tmptr->tm_mday;
  date->hour       = tmptr->tm_hour;
  date->min        = tmptr->tm_min;
  date->sec        = tmptr->tm_sec;
  date->gmt_off    = (signed char) 0x00;
  
  return;
}

void fill_e_date(struct VOL_DATE *date) {
  
  struct tm *tmptr;
  time_t lt;
  
  lt = time(NULL);
  tmptr = localtime(&lt);
  
  sprintf(date->year, "%04i", tmptr->tm_year + 1900);
  sprintf(date->month, "%02i", tmptr->tm_mon + 1);
  sprintf(date->day, "%02i", tmptr->tm_mday);
  sprintf(date->hour, "%02i", tmptr->tm_hour);
  sprintf(date->min, "%02i", tmptr->tm_min);
  sprintf(date->sec, "%02i", tmptr->tm_sec);
  sprintf(date->sec100, "%02i", 0);
  date->gmt_off = 0;
}
