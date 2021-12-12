
// set it to 1 (align on byte)
#pragma pack (1)

char strtstr[] = "\nMTOOLS   Get CDROM Image  v00.10.00    Forever Young Software 1984-2003\n";


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
  unsigned short PathL_loc;    // little endian path location
  unsigned short PathL_loc_b;
  unsigned short PathLO_loc;
  unsigned short PathLO_loc_b;
  unsigned short PathM_loc;    // big endian path location
  unsigned short PathM_loc_b;
  unsigned short PathMO_loc;
  unsigned short PathMO_loc_b;
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
  } root;
            char set_ident[128];
			char pub_ident[128];
			char prep_ident[128];
			char app_ident[128];
			char copy_ident[37];
			char abs_ident[37];
			char bib_ident[37];
  struct VOL_DATE vol_date;
  unsigned  char date_resv[10];
            char mod_date[17];
			char exp_date[17];
			char val_date[17];
  unsigned  char struct_ver;
  unsigned  char resv3;
  unsigned  char app_use[512];
  unsigned  char resv4[653];
};


struct TOC_01 {
	char   toc_len[2];
	char   first_sess;
	char   last_sess;
	char   resv0;
	char   addr_control;
	char   first_trk_num;
	char   resv1;
	union {
		struct MSF {
			char  resv;
			char  min;
			char  sec;
			char  frame;
		} msf;
		char   lba[4];
	} abs_lba;
	char  resv2[804-12];
};


// READ_TOC_EX structure(s) and #defines

#define CDROM_READ_TOC_EX_FORMAT_TOC      0x00
#define CDROM_READ_TOC_EX_FORMAT_SESSION  0x01
#define CDROM_READ_TOC_EX_FORMAT_FULL_TOC 0x02
#define CDROM_READ_TOC_EX_FORMAT_PMA      0x03
#define CDROM_READ_TOC_EX_FORMAT_ATIP     0x04
#define CDROM_READ_TOC_EX_FORMAT_CDTEXT   0x05

#define IOCTL_CDROM_BASE              FILE_DEVICE_CD_ROM
#define IOCTL_CDROM_READ_TOC_EX       CTL_CODE(IOCTL_CDROM_BASE, 0x0015, METHOD_BUFFERED, FILE_READ_ACCESS)

typedef struct _CDROM_READ_TOC_EX {
    UCHAR Format    : 4;
    UCHAR Reserved1 : 3; // future expansion
    UCHAR Msf       : 1;
    UCHAR SessionTrack;
    UCHAR Reserved2;     // future expansion
    UCHAR Reserved3;     // future expansion
} CDROM_READ_TOC_EX, *PCDROM_READ_TOC_EX;

typedef struct _TRACK_DATA {
    UCHAR Reserved;
    UCHAR Control : 4;
    UCHAR Adr : 4;
    UCHAR TrackNumber;
    UCHAR Reserved1;
    UCHAR Address[4];
} TRACK_DATA, *PTRACK_DATA;

typedef struct _CDROM_TOC_SESSION_DATA {
    // Header
    UCHAR Length[2];  // add two bytes for this field
    UCHAR FirstCompleteSession;
    UCHAR LastCompleteSession;
    // One track, representing the first track
    // of the last finished session
    TRACK_DATA TrackData[1];
} CDROM_TOC_SESSION_DATA, *PCDROM_TOC_SESSION_DATA;

// End READ_TOC_EX structure(s) and #defines


