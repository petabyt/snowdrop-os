
// set it to 1 (align on byte)
#pragma pack (1)

char strtstr[] = "\nMTOOLS   CDROM Info  v00.10.20    Forever Young Software 1984-2011\n";

#define ENDIAN_16U(x)   ((((x) & 0xFF) << 8) | (((x) & 0xFF00) >> 8))
#define ENDIAN_32U(x)   ((((x) & 0xFF) << 24) | (((x) & 0xFF00) << 8) | (((x) & 0xFF0000) >> 8) | (((x) & 0xFF000000) >> 24))


char *sprinf_date_time(struct DATE_TIME *);
void debug(unsigned char *, unsigned long);

// Since CDROM's are "universal" to all platforms, if a value stored
//  in one of the following structures is more than a byte, the value
//  is stored twice.  The first being little_endian, the second, big_endian.
struct VOL_DATE {
  unsigned  char since_1900;
  unsigned  char month;
  unsigned  char day;
  unsigned  char hour;
  unsigned  char min;
  unsigned  char sec;
    signed  char gmt_off;
};

struct DATE_TIME {
            char year[4];
            char month[2];
            char day[2];
            char hour[2];
            char min[2];
            char sec[2];
            char jiffies[2];
    signed  char gmt_off;
};

struct ROOT {
  unsigned  char len;
	unsigned  char e_attrib;
	unsigned  long  extent_loc;
	unsigned  long  extent_loc_b;
	unsigned  long  data_len;
	unsigned  long  data_len_b;
	struct VOL_DATE date;
	unsigned  char flags;
	unsigned  char unit_size;
	unsigned  char gap_size;
	unsigned short sequ_num;
	unsigned short sequ_num_b;
	unsigned  char fi_len;
	unsigned  char ident;
};

struct PVD {
  unsigned  char type;
            char ident[5];
  unsigned  char ver;
  union {
    unsigned  char resv0;   // pvd: type 1
    unsigned  char vflags;  // pvd: type 2
  };
            char sys_ident[32];
						char vol_ident[32];
  unsigned  char resv1[8];
  unsigned  long num_lbas;
  unsigned  long num_lbas_b;
  union {
    unsigned  char resv2[32];
    unsigned  char escape_sequ[32];
  };
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
  struct DATE_TIME vol_date;
  struct DATE_TIME mod_date;
	struct DATE_TIME exp_date;
	struct DATE_TIME val_date;
  unsigned  char struct_ver;
  unsigned  char resv3;
  unsigned  char app_use[512];
  unsigned  char resv4[653];
} pvd;

struct PVD3 {
  unsigned  char type;
            char ident[5];
  unsigned  char ver;
  unsigned  char resv0;   // pvd: type 1
            char sys_ident[32];
						char part_ident[32];
	unsigned  long part_location;
	unsigned  long part_location_b;
	unsigned  long part_size;
	unsigned  long part_size_b;
  unsigned  char app_use[1960];
};

