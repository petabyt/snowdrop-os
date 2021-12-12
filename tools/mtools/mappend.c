
/************************************************************************ 
	MAPPEND  Append Sectors to Disk Image      v00.10.05
  Forever Young Software      Benjamin David Lunt

  This utility was desinged for use with Bochs to add sectors
    to the end of a disk image to make it an even number of
    cylinders with 16 heads and 63 spt.

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

  Thanks, and thanks to those who contribute(d) to Bochs....

  ********************************************************

  Things to know:
  - nothing right now

  ********************************************************

  To compile using DJGPP:  (http://www.delorie.com/djgpp/)
     gcc -Os mappend.c -o mappend.exe -s  (DOS .EXE requiring DPMI)
  Must of libsupp 6.2a +
    (ftp://ftp.delorie.com/pub/djgpp/beta/v2tk/lsupp62a.zip)
    (http://groups.google.com/group/comp.os.msdos.djgpp/browse_thread/thread/e54107629ccb962a/46ebdc1db3d78a8f#46ebdc1db3d78a8f)

  Compiles as is with MS VC++ 6.x         (Win .EXE file)
  
  ********************************************************
  
  Usage:
    Simply give the filename on the command line and answer one question
     
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
#include <dos.h>

#if defined(DJGPP)
#include <libsupp.h>

// Even #including the libsupp above, it still doesn't work unless we
//  include these things...
#define offset_t long long

long long libsupp_lfilelength(int _fhandle);
#define lfilelength  libsupp_lfilelength

offset_t  libsupp_llseek(int _handle, offset_t _offset, int _whence);
#define llseek libsupp_llseek

#elif defined(_MSC_VER)
#include <windows.h>
#endif

#include "mappend.h"   // our include

#if defined(DJGPP)
  #define TRUE    1
  #define FALSE   0
  #define bool char
#endif

int main(int argc, char *argv[]) {

	unsigned int cyls;
  long long file_size;
  unsigned long long sectors;
  unsigned char buffer[512];
  
	// print start string
	printf(strtstr);
  
  // if no filename on command line, error and exit
  if (argc != 2) {
    printf("\n Usage:"
           "\n   MAppend filename.img\n");
    return -1;
  }
  
#if defined(DJGPP)
  FILE *fp;
  if ((fp = fopen(argv[1], "r+b")) == NULL) {
    printf("\n Could not open file: %s", argv[1]);
    return -2;
  }
  
  file_size = lfilelength(fileno(fp));
  if (file_size < 0) {
    printf("\n Could not get the files size");
    return -3;
  }
#elif defined(_MSC_VER)
  // Open file for reading
  HANDLE hFile = ::CreateFile(argv[1], (GENERIC_READ | GENERIC_WRITE), 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if (hFile == INVALID_HANDLE_VALUE) {
    printf("\n Could not open file: %s", argv[1]);
    return -2;
  }
  
  // Get file size
  if (!::GetFileSizeEx(hFile, (PLARGE_INTEGER) &file_size)) {
    printf("\n Could not get the files size");
    return -3;
  }
#endif  
  
  // we don't assume that the file is sector aligned
  sectors = (unsigned long long) (((unsigned long long) file_size + 511) >> 9);  // convert to sectors
  cyls = (unsigned int) ((sectors + ((unsigned long long) ((16*63)-1))) / (unsigned long long) (16*63));
  
  if ((sectors % (16*63)) == 0) {
    printf("\n No need to append any sectors.\n File already at even cylinder (%i) * 16 heads * 63 spt.", cyls);
    return 0;
  }
  
  unsigned int add = (unsigned int) ((cyls * (16*63)) - sectors);
  
  // seek to end of file
#if defined(DJGPP)
  llseek(fileno(fp), 0, SEEK_END);
#elif defined(_MSC_VER)
  LARGE_INTEGER offset;
  offset.QuadPart = 0;
  ::SetFilePointerEx(hFile, offset, NULL, FILE_END);
#endif  
  
  printf("\n Adding %i sectors", add);
  
  memset(buffer, 0, 512);
  
  // write the sectors
  while (add--) {
#if defined(DJGPP)
    fwrite(buffer, 1, 512, fp);
#elif defined(_MSC_VER)
    DWORD written = 0;
    if (::WriteFile(hFile, buffer, 512, &written, NULL) == 0) {
      printf("\n error on writefile: %i", GetLastError());
      break;
    }
#endif
  }
  
  // Close file before quitting
#if defined(DJGPP)
  fclose(fp);
#elif defined(_MSC_VER)
  ::CloseHandle(hFile);
#endif  
  
  printf("\n New disk geometry is:  Cyl = %i, heads = 16, spt = 63", cyls);
  
	return 0x00;
}

