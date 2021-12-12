
// set it to 1 (align on byte)
#pragma pack (1)

char strtstr[] = "\nMTOOLS   Make Bootable CDROM Image  v00.10.10  Forever Young Software 1984-2014\n";


// Since CDROM's are "universal" to all platforms, if a value stored
//  in one of the following structures is more than a byte, the value
//  is stored twice.  The first being little_endian, the second, big_endian.
struct VOL_DATE {
            char year[4];
            char month[2];
            char day[2];
            char hour[2];
            char min[2];
            char sec[2];
            char sec100[2];
    signed  char gmt_off;
};

struct DIR_DATE {
  unsigned  char since_1900;
  unsigned  char month;
  unsigned  char day;
  unsigned  char hour;
  unsigned  char min;
  unsigned  char sec;
    signed  char gmt_off;
};

struct PATH_TAB {
  unsigned  char len_di;
  unsigned  char ext_attrib;
  unsigned  long loc;
  unsigned short parent;
  unsigned  char ident[16];
} path_tab;

struct ROOT {
  unsigned  char len;
  unsigned  char e_attrib;
  unsigned  long extent_loc;
  unsigned  long extent_loc_b;
  unsigned  long data_len;
  unsigned  long data_len_b;
  struct DIR_DATE date;
  unsigned  char flags;
  unsigned  char unit_size;
  unsigned  char gap_size;
  unsigned short sequ_num;
  unsigned short sequ_num_b;
  unsigned  char fi_len;
  unsigned  char ident;
} root_tab;

struct PVD {
  unsigned  char type;
            char ident[5];
  unsigned  char ver;
  unsigned  char resv0;
            char sys_ident[32];
            char vol_ident[32];
  unsigned  char resv1[8];
  unsigned  long num_lbas;
  unsigned  long num_lbas_b;
  unsigned  char resv2[32];
  unsigned short set_size;
  unsigned short set_size_b;
  unsigned short sequ_num;
  unsigned short sequ_num_b;
  unsigned short lba_size;
  unsigned short lba_size_b;
  unsigned  long path_table_size;
  unsigned  long path_table_size_b;
  unsigned  long PathL_loc;
  unsigned  long PathLO_loc;
  unsigned  long PathM_loc;
  unsigned  long PathMO_loc;
     struct ROOT root;  
            char set_ident[128];
            char pub_ident[128];
            char prep_ident[128];
            char app_ident[128];
            char copy_ident[37];
            char abs_ident[37];
            char bib_ident[37];
  struct VOL_DATE vol_date;
  struct VOL_DATE mod_date;
  struct VOL_DATE exp_date;
  struct VOL_DATE val_date;
  unsigned  char struct_ver;
  unsigned  char resv3;
  unsigned  char app_use[512];
  unsigned  char resv4[653];
} pvd;

struct BRVD {
  unsigned  char id;
            char ident[5];
  unsigned  char ver;
            char bsident[32];
  unsigned  char resv0[32];
  unsigned  long boot_cat;
  unsigned  char resv1[1973];
} brvd;

struct TERM {
  unsigned  char id;
            char ident[5];
  unsigned  char ver;
  unsigned  char resv1[2041];
} term;

struct BOOT_CAT {
  struct VAL_ENTRY {
    unsigned  char id;
    unsigned  char platform;
    unsigned short resv0;
              char ident[24];
    unsigned short crc;
    unsigned  char key55;
    unsigned  char keyAA;
  } val_entry;
  struct INIT_ENTRY {
    unsigned  char bootable;
    unsigned  char media;
    unsigned short load_seg;
    unsigned  char sys_type;
    unsigned  char resv0;
    unsigned short load_cnt;
    unsigned  long load_rba;
    unsigned  char resv1[20];
  } init_entry;
  struct END_ENTRY {
    unsigned  char id;
    unsigned  char platform;
    unsigned short num;
    unsigned  char resv1[28];
  } end_entry;
  unsigned  char filler[1952];
} boot_cat;
