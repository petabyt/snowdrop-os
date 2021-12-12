
// set it to 1 (align on byte)
#pragma pack (1)

char strtstr[] = "\nMTOOLS   Del From  v00.10.01     Forever Young Software 1984-2010\n";
unsigned long fatend[3] = { 0x00000FF8L, 0x0000FFF8L, 0xFFFFFFF8L };


struct BPB {
  unsigned  char jmps[2];       // The jump short instruction
  unsigned  char nop;           // nop instruction;
            char oemname[8];    // OEM name
  unsigned short nBytesPerSec;  // Bytes per sector
  unsigned  char nSecPerClust;  // Sectors per cluster
  unsigned short nSecRes;       // Sectors reserved for Boot Record
  unsigned  char nFATs;         // Number of FATs
  unsigned short nRootEnts;     // Max Root Directory Entries allowed
  unsigned short nSecs;         // Number of Logical Sectors (0B40h)
  unsigned  char mDesc;         // Medium Descriptor Byte
  unsigned short nSecPerFat;    // Sectors per FAT
  unsigned short nSecPerTrack;  // Sectors per Track
  unsigned short nHeads;        // Number of Heads
  unsigned  long nSecHidden;    // Number of Hidden Sectors
  unsigned  long nSecsExt;      // This value used when there are more
  unsigned  char DriveNum;      // Physical drive number
  unsigned  char nResByte;      // Reserved (we use for FAT type (12- 16-bit)
  unsigned  char sig;           // Signature for Extended Boot Record
  unsigned  long SerNum;        // Volume Serial Number
            char VolName[11];   // Volume Label
            char FSType[8];     // File system type
  unsigned  char filler[448];
  unsigned short boot_sig;
} bpb;

struct ROOT {
            char name[8];       // oem name
            char ext[3];        // oem name
  unsigned  char attrb;         // attribute
            char resv[10];      // reserved
  unsigned short time;          // time
  unsigned short date;          // date
  unsigned short startclust;    // starting cluster number
  unsigned  long filesize;      // file size in bytes
};
