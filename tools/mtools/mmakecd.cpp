/************************************************************************ 
  MMAKECD  Make 9660 CD image           v00.10.00
  Forever Young Software      Benjamin David Lunt

  This utility was desinged for use with Bochs to make a 
	  CD-ROM disk image from a directory of files.

  Bochs is located at:
    http://bochs.sourceforge.net

  This code was originally written by Philip J. Erdelsky.
   I simply modified it for my own code style and for use
   with my own utilities.  I have included the original
   comment he gave in the bottom of the header file.
  
  I designed this program to be used for testing my own OS,
   though you are welcome to use it any way you wish as long
   as it does not conflict with any licensing that the
   original authoer, Philip J. Erdelsky, may have.
  
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
  - This currently only works within a Windows DOS box due
    to the findfirst() and findnext() routines.
	TODO:
	- Code the findfirst() and findnext() routines for DOS
  
  ********************************************************

  To compile using DJGPP:  (http://www.delorie.com/djgpp/)
     gcc -Os mmakecd.c -o mmakecd.exe -s  (DOS .EXE requiring DPMI)

  Compiles as is with MS VC++ 6.x         (Win32 .EXE file)

  ********************************************************

  Usage:
     see help_str[] below

************************************************************************/

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#define TRUE    1
#define FALSE   0
#define NULL    0

#include "mmakecd.h"   // our include

// make sure that this stays this length, or you will have to modify the code below
#define APPSTR "MTOOLS   Make 9660 CDROM Image  v00.10.00  Forever Young Software 1984-2011"

char strgstr[128] = "\n" APPSTR "\n\n";

char help_str[] =
  "CDMAKE  [-q] [-v] [-p] [-s N]  source  volume  image\n"
  "\n"
  "  source      specifications of base directory containing all files to\n"
  "              be written to CD-ROM image\n"
  "\n"
  "  volume      volume label\n"
  "\n"
  "  image       image file or device\n"
  "\n"
  "  -q          quiet mode - display nothing but error messages\n"
  "\n"
  "  -v          verbose mode - display file information as files are\n"
  "              scanned and written - overrides -p option\n"
  "\n"
  "  -p          show progress while writing\n"
  "\n"
  "  -s N        abort operation before beginning write if image will be\n"
  "              larger than N megabytes (i.e. 1024*1024*N bytes)\n"
  "\n"
  "  -m          accept punctuation marks other than underscores in\n"
  "              names and extensions\n";

struct CD_IMAGE cd;

char  volume_label[32];
struct DIRECTORY_RECORD root;
char  source[512];
char  *end_source;
enum  { QUIET, NORMAL, VERBOSE } verbosity;
bool  show_progress;
bit32u size_limit;
bool  accept_punctuation_marks;

bit32u total_sectors;
bit32u path_table_size;
bit32u little_endian_path_table_sector;
bit32u big_endian_path_table_sector;
bit32u number_of_files;
bit32u bytes_in_files;
bit32u unused_bytes_at_ends_of_files;
bit32u number_of_directories;
bit32u bytes_in_directories;

/* This function edits a 32-bit unsigned number into a comma-delimited form, such
 * as 4,294,967,295 for the largest possible number, and returns a pointer to a
 * static buffer containing the result. It suppresses leading zeros and commas,
 * but optionally pads the result with blanks at the left so the result is always
 * exactly 13 characters long (excluding the terminating zero).
 *
 * CAUTION: A statement containing more than one call on this function, such as
 * printf("%s, %s", edit_with_commas(), edit_with_commas()), will produce
 * incorrect results because all calls use the same static bufffer.
 */
char *edit_with_commas(bit32u x, const bool pad) {
  static char s[14];
  unsigned i = 13;
  
  do {
    if ((i % 4) == 2)
      s[--i] = ',';
    s[--i] = (char) ((x % 10) + '0');
  } while ((x/=10) != 0);
  
  if (pad)
    while (i > 0)
      s[--i] = ' ';
  
  return s + i;
}

/*
 * This function releases all allocated memory blocks.
 */
void release_memory() {
  while (root.next_in_memory != NULL) {
    struct DIRECTORY_RECORD *next = root.next_in_memory->next_in_memory;
    free(root.next_in_memory);
    root.next_in_memory = next;
  }
  
  if (cd.buffer != NULL) {
    free(cd.buffer);
    cd.buffer = NULL;
  }
}

/*
 * This function edits and displays an error message and then exits.
 */
void error_exit(const char *format, ...) {
  vfprintf(stderr, format, (va_list) &format + 1);
  fprintf(stderr, "\n");
  if (cd.handle != NULL)
    fclose(cd.handle);
  release_memory();
  exit(-1);
}

/*
 * This function, which is called only on the second pass, and only when the
 * buffer is not empty, flushes the buffer to the CD-ROM image.
 */
void flush_buffer() {
  if (fwrite(cd.buffer, 1, cd.count, cd.handle) < cd.count)
    error_exit("File write error");
  cd.count = 0;
  if (show_progress)
    printf("\r%s ", edit_with_commas(((total_sectors - cd.sector) * SECTOR_SIZE), TRUE));
}

/*
 * This function writes a single byte to the CD-ROM image. On the first pass (in
 * which cd.handle == NULL), it does not actually write anything but merely updates
 * the file pointer as though the byte had been written.
 */
void write_byte(bit8u x) {
  if (cd.handle != NULL) {
    cd.buffer[cd.count] = x;
    if (++cd.count == BUFFER_SIZE)
      flush_buffer();
  }
  if (++cd.offset == SECTOR_SIZE) {
    cd.sector++;
    cd.offset = 0;
  }
}

/*
 * These functions write a word or double word to the CD-ROM image with the
 * specified endianity.
 */
void write_little_endian16(bit16u x) {
  write_byte((bit8u) x);
  write_byte((bit8u) (x >> 8));
}

void write_big_endian16(bit16u x) {
  write_byte((bit8u) (x >> 8));
  write_byte((bit8u) x);
}

void write_both_endian16(bit16u x) {
  write_little_endian16(x);
  write_big_endian16(x);
}

void write_little_endian32(bit32u x) {
  write_byte((bit8u) x);
  write_byte((bit8u) (x >> 8));
  write_byte((bit8u) (x >> 16));
  write_byte((bit8u) (x >> 24));
}

void write_big_endian32(bit32u x) {
  write_byte((bit8u) (x >> 24));
  write_byte((bit8u) (x >> 16));
  write_byte((bit8u) (x >> 8));
  write_byte((bit8u) (x));
}

void write_both_endian32(bit32u x) {
  write_little_endian32(x);
  write_big_endian32(x);
}

/*
 * This function writes enough zeros to fill out the end of a sector, and leaves
 * the file pointer at the beginning of the next sector. If the file pointer is
 * already at the beginning of a sector, it writes nothing.
 */
void fill_sector(void) {
  while (cd.offset != 0)
    write_byte(0);
}

/*
 * This function writes a string to the CD-ROM image. The terminating \0 is not
 * written.
 */
void write_string(char *s) {
  while (*s)
    write_byte(*s++);
}

/*
 * This function writes a block of identical bytes to the CD-ROM image.
 */
void write_block(unsigned count, bit8u value) {
  while (count) {
    write_byte(value);
    count--;
  }
}

/*
 * This function writes a directory record to the CD_ROM image.
 */
void write_directory_record(struct DIRECTORY_RECORD *d, enum directory_record_type type) {
  unsigned identifier_size;
  
  switch (type) {
    case DOT_RECORD:
    case DOT_DOT_RECORD:
      identifier_size = 1;
      break;
    case SUBDIRECTORY_RECORD:
      identifier_size = strlen(d->name);
      break;
    case FILE_RECORD:
      identifier_size = strlen(d->name) + 2;
      if (d->extension[0] != 0)
        identifier_size += 1 + strlen(d->extension);
      break;
  }
  
  unsigned record_size = 33 + identifier_size;
  if ((identifier_size & 1) == 0)
    record_size++;
  if (cd.offset + record_size > SECTOR_SIZE)
    fill_sector();
  write_byte(record_size);             // length of dir record
  write_byte(0);                       // number of sectors in extended attribute record
  write_both_endian32(d->sector);      // location of extent
  write_both_endian32(d->size);        // data length
  write_byte(d->date_and_time.year - 1900); // year
  write_byte(d->date_and_time.month);  // month
  write_byte(d->date_and_time.day);    // day
  write_byte(d->date_and_time.hour);   // hour
  write_byte(d->date_and_time.minute); // minute
  write_byte(d->date_and_time.second); // second
  write_byte(0);                       // GMT offset
  write_byte(d->flags);                // flags
  write_byte(0);                       // file unit size for an interleaved file
  write_byte(0);                       // interleave gap size for an interleaved file
  write_both_endian16(1);              // volume sequence number
  write_byte(identifier_size);         // length of file identifier (filename)
  
  switch (type) {
    case DOT_RECORD:                   // '.'
      write_byte(0);
      break;
    case DOT_DOT_RECORD:               // '..'
      write_byte(1);
      break;
    case SUBDIRECTORY_RECORD:          // sub directory name
      write_string(d->name);
      break;
    case FILE_RECORD:                  // file name
      write_string(d->name);
      if (d->extension[0] != 0) {
        write_byte('.');
        write_string(d->extension);
      }
      write_string(";1");
      break;
  }
  if ((identifier_size & 1) == 0)
    write_byte(0);
}

/*
 * This function converts the date and time words from an ffblk structure and
 * puts them into a date_and_time structure.
 */
void convert_date_and_time(struct DATE_AND_TIME *dt, FILETIME last_accessed) {
  
  bit16u date, time;
  FileTimeToDosDateTime(&last_accessed, &date, &time);
  
  dt->second = 2 * (time & 0x1F);
  dt->minute = time >> 5 & 0x3F;
  dt->hour = time >> 11 & 0x1F;
  dt->day = date & 0x1F;
  dt->month = date >> 5 & 0xF;
  dt->year = (date >> 9 & 0x7F) + 1980;
}

/*
 * This function converts the current date and time into a 16 byte string
 */
char *make_data_string() {
  
  static char date_str[16+1] = "0000000000000000";
  
  SYSTEMTIME lt;
  GetLocalTime(&lt);
  
  sprintf(date_str, "%04i%02i%02i%02i%02i%02i%02i", lt.wYear, lt.wMonth, lt.wDay, lt.wHour, lt.wMinute, lt.wSecond, lt.wMilliseconds / 10);
  
  return date_str;
}


/*
 * This function checks the specified character, if necessary, and
 * generates an error if it is a punctuation mark other than an underscore.
 * It also converts small letters to capital letters and returns the
 * result.
 */
int check_for_punctuation(int c, char *name) {
  c = toupper(c & 0xFF);
  if (!accept_punctuation_marks && !isalnum(c) && (c != '_'))
    error_exit("Punctuation mark in %s", name);
  return c;
}

/*
 * This function creates a new directory record with the information from the
 * specified ffblk. It links it into the beginning of the directory list
 * for the specified parent and returns a pointer to the new record.
 */
struct DIRECTORY_RECORD *new_directory_record(WIN32_FIND_DATA *f, struct DIRECTORY_RECORD *parent) {
  struct DIRECTORY_RECORD *d = (struct DIRECTORY_RECORD *) malloc(sizeof(struct DIRECTORY_RECORD));
  
  if (d == NULL)
    error_exit("Insufficient memory");
  
  d->next_in_memory = root.next_in_memory;
  root.next_in_memory = d;
  
  char *s = f->cFileName;
  char *t = d->name;
  while (*s != 0) {
    if (*s == '.') {
      s++;
      break;
    }
    *t++ = check_for_punctuation(*s++, f->cFileName);
  }
  *t = 0;
  t = d->extension;
  while (*s != 0)
    *t++ = check_for_punctuation(*s++, f->cFileName);
  *t = 0;
  
  convert_date_and_time(&d->date_and_time, f->ftLastAccessTime);
  if (f->dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
    if (d->extension[0] != 0)
      error_exit("Directory with extension %s", f->cFileName);
    d->flags = DIRECTORY_FLAG;
  } else
    d->flags = (f->dwFileAttributes & FILE_ATTRIBUTE_HIDDEN) ? HIDDEN_FLAG : 0;
  
  d->size = f->nFileSizeLow;
  d->next_in_directory = parent->first_record;
  parent->first_record = d;
  d->parent = parent;

  return d;
}

/*
 * This function compares two directory records according to the ISO9660 rules
 * for directory sorting and returns a negative value if p is before q, or a
 * positive value if p is after q.
 */
int compare_directory_order(struct DIRECTORY_RECORD *p, struct DIRECTORY_RECORD *q) {
  int n = strcmp(p->name, q->name);
  if (n == 0)
    n = strcmp(p->extension, q->extension);
  return n;
}

/*
 * This function compares two directory records (which must represent
 * directories) according to the ISO9660 rules for path table sorting and returns
 * a negative value if p is before q, or a positive vlaue if p is after q.
 */
int compare_path_table_order(struct DIRECTORY_RECORD *p, struct DIRECTORY_RECORD *q) {
  if (p == q)
    return 0;
  int n = p->level - q->level;
  if (n == 0) {
    n = compare_path_table_order(p->parent, q->parent);
    if (n == 0)
      n = compare_directory_order(p, q);
  }
  return n;
}

/*
 * This function appends the specified string to the buffer source[].
 */
void append_string_to_source(char *s) {
  while (*s != 0)
    *end_source++ = *s++;
}

/*
 * This function scans all files from the current source[] (which must end in \,
 * and represents a directory already in the database as d),
 * and puts the appropriate directory records into the database in memory, with
 * the specified root. It calls itself recursively to scan all subdirectories.
 */
void make_directory_records(struct DIRECTORY_RECORD *d) {
  WIN32_FIND_DATA f;
  HANDLE hFind;
  
  d->first_record = NULL;
  strcpy(end_source, "*.*");
  hFind = findfirst(source, &f, FILE_ATTRIBUTE_HIDDEN);
  if (hFind != NULL) {
    do {
      if (verbosity == VERBOSE) {
        char *old_end_source = end_source;
        strcpy(end_source, f.cFileName);
        printf("%d: file %s\n", d->level, source);
        end_source = old_end_source;
      }
      convert_date_and_time(&d->date_and_time, f.ftLastAccessTime);
      new_directory_record(&f, d);
    } while (findnext(hFind, &f, FILE_ATTRIBUTE_HIDDEN));
    FindClose(hFind);
  }
  
  strcpy(end_source, "*.*");
  hFind = findfirst(source, &f, FILE_ATTRIBUTE_DIRECTORY);
  if (hFind != NULL) {
    do {
      if ((f.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) && (f.cFileName[0] != '.')) {
        char *old_end_source = end_source;
        append_string_to_source(f.cFileName);
        *end_source++ = '\\';
        if (verbosity == VERBOSE) {
          *end_source = 0;
          printf("%d: directory %s\n", d->level + 1, source);
        }
        if (d->level < MAX_LEVEL) {
          struct DIRECTORY_RECORD *new_d = new_directory_record(&f, d);
          new_d->next_in_path_table = root.next_in_path_table;
          root.next_in_path_table = new_d;
          new_d->level = d->level + 1;
          make_directory_records(new_d);
        } else
          error_exit("Directory is nested too deep");
        end_source = old_end_source;
      }
    } while (findnext(hFind, &f, FILE_ATTRIBUTE_DIRECTORY));
    FindClose(hFind);
  }
  
  // sort directory
  d->first_record = (struct DIRECTORY_RECORD *) sort_linked_list(d->first_record, 0, (int (__cdecl *)(void *, void *)) compare_directory_order);
}

/*
 * This function loads the file specifications for the file or directory
 * corresponding to the specified directory record into the source[] buffer. It
 * is recursive.
 */
void get_file_specifications(struct DIRECTORY_RECORD *d) {
  if (d != &root) {
    get_file_specifications(d->parent);
    append_string_to_source(d->name);
    if ((d->flags & DIRECTORY_FLAG) == 0 && d->extension[0] != 0) {
      *end_source++ = '.';
      append_string_to_source(d->extension);
    }
    if (d->flags & DIRECTORY_FLAG)
      *end_source++ = '\\';
  }
}

void pass() {
  
  // first 16 sectors are zeros
  write_block(16 * SECTOR_SIZE, 0);

  // Primary Volume Descriptor
  write_byte(1);                       // pvd type
  write_string("CD001");               // standard identifier
  write_byte(1);                       // descript version
  write_byte(0);                       // type 1: unused, type 2: flags
  write_block(32, ' ');                // system identifier
  
  char *t = volume_label;
  for (unsigned i = 0; i < 32; i++)
    write_byte((*t != 0) ? toupper(*t++) : ' ');
  
  write_block(8, 0);                   // unused
  write_both_endian32(total_sectors);  // total sectors in volume
  write_block(32, 0);                  // type 1: usused, type 2: escape sequences
  write_both_endian16(1);              // volume set size
  write_both_endian16(1);              // volume sequence number
  write_both_endian16(2048);           // sector size
  write_both_endian32(path_table_size); // path table size
  write_little_endian32(little_endian_path_table_sector); // Little Endian Path table lba
  write_little_endian32(0);                               // second little endian path table
  write_big_endian32(big_endian_path_table_sector);       // Big Endian Path table lba
  write_big_endian32(0);                                  // second big endian path table
  write_directory_record(&root, DOT_RECORD); // directory record for root directory
  write_block(128, ' ');               // volume set identifier
  write_block(128, ' ');               // publisher identifier
  write_block(128, ' ');               // data preparer identifier
  write_string(APPSTR "                                                     "); // application identifier (make sure it is 128 bytes)
  write_block(37, ' ');                // copyright file identifier
  write_block(37, ' ');                // abstract file identifier
  write_block(37, ' ');                // bibliographic file identifier
  t = make_data_string();              // create date_time string
  write_string(t);                     // volume creation
  write_byte(0);                       // GMT offset
  write_string(t);                     // most recent modification
  write_byte(0);                       // GMT offset
  write_string("0000000000000000");    // volume expires
  write_byte(0);                       // GMT offset
  write_string(t);                     // volume is effective
  write_byte(0);                       // GMT offset
  write_byte(1);                       // file structure version
  write_byte(0);                       // unused
  fill_sector();                       // application use / unused
  
  // Volume Descriptor Set Terminator
  write_byte(255);                     // pvd type
  write_string("CD001");               // standard identifier
  write_byte(1);                       // descript version
  fill_sector();
  
  // Little Endian Path Table
  little_endian_path_table_sector = cd.sector;
  write_byte(1);                       // 
  write_byte(0);                       // number of sectors in extended attribute record
  write_little_endian32(root.sector);  // 
  write_little_endian16(1);
  write_byte(0);
  write_byte(0);
  
  struct DIRECTORY_RECORD *d;
  unsigned index = 1;
  root.path_table_index = 1;
  for (d = root.next_in_path_table; d != NULL; d = d->next_in_path_table) {
    unsigned name_length = strlen(d->name);
    write_byte(name_length);
    write_byte(0);  // number of sectors in extended attribute record
    write_little_endian32(d->sector);
    write_little_endian16(d->parent->path_table_index);
    write_string(d->name);
    if (name_length & 1)
      write_byte(0);
    d->path_table_index = ++index;
  }
  path_table_size = (cd.sector - little_endian_path_table_sector) *  SECTOR_SIZE + cd.offset;
  fill_sector();
  
  // Big Endian Path Table
  big_endian_path_table_sector = cd.sector;
  write_byte(1);
  write_byte(0);  // number of sectors in extended attribute record
  write_big_endian32(root.sector);
  write_big_endian16(1);
  write_byte(0);
  write_byte(0);
  
  for (d = root.next_in_path_table; d != NULL; d = d->next_in_path_table) {
    unsigned name_length = strlen(d->name);
    write_byte(name_length);
    write_byte(0);  // number of sectors in extended attribute record
    write_big_endian32(d->sector);
    write_big_endian16(d->parent->path_table_index);
    write_string(d->name);
    if (name_length & 1)
      write_byte(0);
  }
  fill_sector();

  // directories and files
  for (d = &root; d != NULL; d = d->next_in_path_table) {
    struct DIRECTORY_RECORD *q;
    
    // write directory
    d->sector = cd.sector;
    write_directory_record(d, DOT_RECORD);
    write_directory_record(d == &root ? d : d->parent, DOT_DOT_RECORD);
    for (q = d->first_record; q != NULL; q = q->next_in_directory)
      write_directory_record(q, q->flags & DIRECTORY_FLAG ? SUBDIRECTORY_RECORD : FILE_RECORD);
    fill_sector();
    d->size = (cd.sector - d->sector) * SECTOR_SIZE;
    number_of_directories++;
    bytes_in_directories += d->size;
    
    // write file data
    for (q = d->first_record; q != NULL; q = q->next_in_directory) {
      if ((q->flags & DIRECTORY_FLAG) == 0) {
        q->sector = cd.sector;
        bit32u size = q->size;
        if (cd.handle == NULL) {
          bit32u number_of_sectors = (size + SECTOR_SIZE - 1) / SECTOR_SIZE;
          cd.sector += number_of_sectors;
          number_of_files++;
          bytes_in_files += size;
          unused_bytes_at_ends_of_files += number_of_sectors * SECTOR_SIZE - size;
        } else {
          char *old_end_source = end_source;
          get_file_specifications(q);
          *end_source = 0;
          if (verbosity == VERBOSE)
            printf("Writing %s\n", source);
          FILE *h = fopen(source, "rb");
          if (h != NULL) {
            while (size > 0) {
              bit32u n = BUFFER_SIZE - cd.count;
              if (n > size)
                n = size;
              if (fread(cd.buffer + cd.count, 1, n, h) != n) {
                fclose(h);
                error_exit("Read error in file %s\n", source);
              }
              cd.count += n;
              if (cd.count == BUFFER_SIZE)
                flush_buffer();
              cd.sector += n / SECTOR_SIZE;
              cd.offset += n % SECTOR_SIZE;
              size -= n;
            }
            fclose(h);
          } else
            error_exit("Can't open %s\n", source);
          end_source = old_end_source;
          fill_sector();
        }
      }
    }
  }
  
  total_sectors = cd.sector;
}

/*
 * Program execution starts here.
 */
int main(int argc, char **argv) {
  
  // print start string
  printf(strgstr);
  
  if (argc < 2) {
    puts(help_str);
    return 1;
  }
  
  // initialize root directory
  cd.buffer = (bit8u *) malloc(BUFFER_SIZE);
  if (cd.buffer == NULL)
    error_exit("Insufficient memory");
  
  memset(&root, 0, sizeof(root));
  root.level = 1;
  root.flags = DIRECTORY_FLAG;
  
  // initialize CD-ROM write buffer
  cd.handle = NULL;
  cd.filespecs[0] = 0;
  
  // initialize parameters
  verbosity = NORMAL;
  size_limit = 0;
  show_progress = FALSE;
  accept_punctuation_marks = FALSE;
  source[0] = 0;
  volume_label[0] = 0;
  
  // scan command line arguments
  bool q_option = FALSE;
  bool v_option = FALSE;
  for (int i = 1; i < argc; i++) {
    if (memcmp(argv[i], "-s", 2) == 0) {
      char *t = argv[i] + 2;
      if (*t == 0) {
        if (++i < argc)
          t = argv[i];
        else
          error_exit("Missing size limit parameter");
      }
      while (isdigit(*t))
        size_limit = size_limit * 10 + *t++ - '0';
      if (size_limit < 1 || size_limit > 800)
        error_exit("Invalid size limit");
      size_limit <<= 9;  // convert megabyte to sector count
    } else if (strcmp(argv[i], "-q") == 0)
      q_option = TRUE;
    else if (strcmp(argv[i], "-v") == 0)
      v_option = TRUE;
    else if (strcmp(argv[i], "-p") == 0)
      show_progress = TRUE;
    else if (strcmp(argv[i], "-m") == 0)
      accept_punctuation_marks = TRUE;
    else if (i + 2 < argc) {
      strcpy(source, argv[i++]);
      strncpy(volume_label, argv[i++], sizeof(volume_label) - 1);
      strcpy(cd.filespecs, argv[i]);
    } else
      error_exit("Missing command line argument");
  }
  
  if (v_option) {
    show_progress = FALSE;
    verbosity = VERBOSE;
  } else if (q_option) {
    verbosity = QUIET;
    show_progress = FALSE;
  }
  
  if (source[0] == 0)
    error_exit("Missing source directory");
  if (volume_label[0] == 0)
    error_exit("Missing volume label");
  if (cd.filespecs[0] == 0)
    error_exit("Missing image file specifications");
  
  // set source[] and end_source to source directory, with a terminating '\'
  end_source = source + strlen(source);
  if (end_source[-1] == ':')
    *end_source++ = '.';
  if (end_source[-1] != '\\')
    *end_source++ = '\\';
  
  // scan all files and create directory structure in memory
  make_directory_records(&root);
  
  // sort path table entries
  root.next_in_path_table = (struct DIRECTORY_RECORD *) sort_linked_list(root.next_in_path_table, 1, (int (__cdecl *)(void *, void *)) compare_path_table_order);
  
  // initialize CD-ROM write buffer
  cd.handle = NULL;
  cd.sector = 0;
  cd.offset = 0;
  cd.count = 0;
  
  // make non-writing pass over directory structure to obtain the proper
  // sector numbers and offsets and to determine the size of the image
  number_of_files = 
  bytes_in_files = 
  number_of_directories =
  bytes_in_directories = 
  unused_bytes_at_ends_of_files = 0;
  
  pass();
  
  if (verbosity >= NORMAL) {
    printf("%s bytes ", edit_with_commas(bytes_in_files, TRUE));
    printf("in %s files\n", edit_with_commas(number_of_files, FALSE));
    printf("%s unused bytes at ends of files\n", edit_with_commas(unused_bytes_at_ends_of_files, TRUE));
    printf("%s bytes ", edit_with_commas(bytes_in_directories, TRUE));
    printf("in %s directories\n", edit_with_commas(number_of_directories, FALSE));
    printf("%s other bytes\n", edit_with_commas(root.sector * SECTOR_SIZE, TRUE));
    puts("-------------");
    printf("%s total bytes\n", edit_with_commas(total_sectors * SECTOR_SIZE, TRUE));
    puts("=============");
  }
  
  if (size_limit != 0 && total_sectors > size_limit)
    error_exit("Size limit exceeded");
  
  // re-initialize CD-ROM write buffer
  cd.handle = fopen(cd.filespecs, "wb");
  if (cd.handle == NULL)
    error_exit("Can't open image file %s", cd.filespecs);
  cd.sector = 0;
  cd.offset = 0;
  cd.count = 0;
  
  // make writing pass over directory structure
  pass();
  
  if (cd.count > 0)
    flush_buffer();
  if (show_progress)
    printf("\r             \n");
  if (fclose(cd.handle) != 0) {
    cd.handle = NULL;
    error_exit("File write error in image file %s", cd.filespecs);
  }
  
  if (verbosity >= NORMAL)
    puts("CD-ROM image made successfully");
  
  release_memory();
  return 0;
}

HANDLE findfirst(const char *pathname, WIN32_FIND_DATA *f, int attrib) {
  HANDLE hFind;
  int iFnd;
  
  attrib |= (FILE_ATTRIBUTE_ARCHIVE | FILE_ATTRIBUTE_NORMAL | FILE_ATTRIBUTE_READONLY);
  
  hFind = FindFirstFile(pathname, f);
  if (hFind != INVALID_HANDLE_VALUE) {
    do {
      if (f->dwFileAttributes & attrib)
        return hFind;
      else
        iFnd = FindNextFile(hFind, f);
    } while (iFnd != 0);
  }
  
  return NULL;
}

int	findnext(HANDLE hFind, WIN32_FIND_DATA *f, int attrib) {
  
  attrib |= (FILE_ATTRIBUTE_ARCHIVE | FILE_ATTRIBUTE_NORMAL | FILE_ATTRIBUTE_READONLY);
  int iFnd = FindNextFile(hFind, f);
  while (iFnd) {
    if (f->dwFileAttributes & attrib)
      return 1;
    iFnd = FindNextFile(hFind, f);
  }
  
  return 0;
}

/* A Linked-List Memory Sort
 *  by Philip J. Erdelsky
 *  pje@acm.org
 *  http://www.alumni.caltech.edu/~pje/
 */
void *sort_linked_list(void *p, unsigned index, int (*compare)(void *, void *)) {
  unsigned base;
  unsigned long block_size;

  struct RECORD {
    struct RECORD *next[1];
    // other members not directly accessed by this function
  };
  
  struct TAPE {
    struct RECORD *first, *last;
    unsigned long count;
  } tape[4];
  
  // Distribute the records alternately to tape[0] and tape[1].
  tape[0].count = tape[1].count = 0;
  tape[0].first = NULL;
  base = 0;
  
  while (p != NULL) {
    struct RECORD *next = ((struct RECORD *)p)->next[index];
    ((struct RECORD *)p)->next[index] = tape[base].first;
    tape[base].first = ((struct RECORD *)p);
    tape[base].count++;
    p = next;
    base ^= 1;
  }
  
  // If the list is empty or contains only a single record, then
  // tape[1].count == 0L and this part is vacuous.
  for (base = 0, block_size = 1; tape[base+1].count != 0; base ^= 2, block_size <<= 1) {
    int dest;
    struct TAPE *tape0, *tape1;
    tape0 = tape + base;
    tape1 = tape + base + 1;
    dest = base ^ 2;
    tape[dest].count = tape[dest+1].count = 0;
    for (; tape0->count != 0; dest ^= 1) {
      unsigned long n0, n1;
      struct TAPE *output_tape = tape + dest;
      n0 = n1 = block_size;
      while (1) {
        struct RECORD *chosen_record;
        struct TAPE *chosen_tape;
        if (n0 == 0 || tape0->count == 0) {
          if (n1 == 0 || tape1->count == 0)
            break;
          chosen_tape = tape1;
          n1--;
        } else if (n1 == 0 || tape1->count == 0) {
          chosen_tape = tape0;
          n0--;
        } else if ((*compare)(tape0->first, tape1->first) > 0) {
          chosen_tape = tape1;
          n1--;
        } else {
          chosen_tape = tape0;
          n0--;
        }
        chosen_tape->count--;
        chosen_record = chosen_tape->first;
        chosen_tape->first = chosen_record->next[index];
        if (output_tape->count == 0)
          output_tape->first = chosen_record;
        else
          output_tape->last->next[index] = chosen_record;
        output_tape->last = chosen_record;
        output_tape->count++;
      }
    }
  }
  
  if (tape[base].count > 1)
    tape[base].last->next[index] = NULL;
  
  return tape[base].first;
}

