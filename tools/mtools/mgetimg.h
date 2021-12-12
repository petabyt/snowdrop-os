
// set it to 1 (align on byte)
#pragma pack (1)

char strtstr[] = "\nMTOOLS   Get Image  v00.20.00    Forever Young Software 1984-2014\n";

char menustr[] = "\n   0)   5.25   160k 1-sided"
         "\n   1)   5.25   180k 1-sided"
         "\n   2)   5.25   320k 2-sided"
         "\n   3)   5.25   360k 2-sided"
         "\n   4)   5.25   720k 2-sided"
         "\n   5)   3.5    720k 2-sided"
         "\n   6)   5.25  1220k 2-sided"
         "\n   7)   3.5   1440k 2-sided"
         "\n   8)   3.5   1720k 2-sided (DMF)"
         "\n   9)   3.5   2880k 2-sided"
         "\n   A)   logical hard disk image"
         "\n   B)   "
         "\n   C)   "
         "\n   D)   "
         "\n   E)   "
         "\n   F)   Exit.";

struct DISK_TYPE {
  bit64u total_sects;
  bit32u cylinders;
  bit32u sec_per_track;
  bit32u num_heads;
  bit64u size;
};

struct DISK_TYPE disk160  = {  320, 40,  8, 1,  160};
struct DISK_TYPE disk180  = {  360, 40,  9, 1,  180};
struct DISK_TYPE disk320  = {  640, 40,  8, 2,  320};
struct DISK_TYPE disk360  = {  720, 40,  9, 2,  360};
struct DISK_TYPE disk1220 = { 2400, 80, 15, 2, 2400};
struct DISK_TYPE disk720  = { 1440, 80,  9, 2,  720};
struct DISK_TYPE disk1440 = { 2880, 80, 18, 2, 1440};
struct DISK_TYPE disk1720 = { 3360, 80, 21, 2, 1720};
struct DISK_TYPE disk2880 = { 5760, 80, 36, 2, 2880};
struct DISK_TYPE harddisk = {    0,  0, 63, 16,   0};



bool read_sectors(HANDLE, void *, bit64u, bit32u);

