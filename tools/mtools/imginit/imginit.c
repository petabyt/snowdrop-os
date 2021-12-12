//
// This is very low quality code, which isn't intended to be
// flexible or maintainable. The main thing about it is that
// it serves for its small and very specific purpose - to
// create an HDD image with FAT1x or FAT32 partitions in it
// or an FDD image for 3.5" floppy with FAT12.
// The image will be used in the test of the FAT FS module.
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include "FAT.h"

typedef struct tExtendedPartition
{
  uint32                        AbsLBA;
  tPartitionSector              MBR;
  tFATBootSector                BootSector;
  struct tExtendedPartition*    pNext;
} tExtendedPartition;

typedef struct
{
  int                   IsFloppy;
  uint32                CylinderCnt;
  uint32                HeadCnt;
  uint32                SectorCnt;
  tPartitionSector      MBR;
  tFATBootSector        aBootSectors[4];
  tExtendedPartition*   pExtendedPartition;
} tImageDescriptor;

tImageDescriptor ImgFdd =
{
  1,                            // IsFloppy
  80,                           // CylinderCnt
  2,                            // HeadCnt
  18,                           // SectorCnt
  {                             // MBR
    {                           // aBootCode[]
      0
    }
  },
  {                             // aBootSectors[]
    {                           // aBootSectors[0]
      {                         //   aJump[]
        0xEB, 0x3C, 0x90
      },
      "FAT-TEST",               //   OEMName[]
      {                         //   BPB
        {                       //     BPB1
          512,                  //       BytesPerSector
          1,              //    //       SectorsPerCluster
          1,                    //       ReservedSectorsCount
          2,                    //       NumberOfFATs
          224,                  //       RootEntriesCount
          2880,           //    //       TotalSectorsCount16
          0xF0,                 //       MediaType
          9,              //    //       SectorsPerFAT1x
          18,                   //       SectorsPerTrack
          2,                    //       HeadsPerCylinder
          0,              //    //       HiddenSectorsCount
          0               //    //       TotalSectorsCount32
        },
        {                       //     BPB2
          .FAT1x =
          {                     //       FAT1x
            0x00,               //         DriveNumber
            0,                  //         reserved1
            0x29,               //         ExtendedBootSignature
            0x00000000UL, //    //         VolumeSerialNumber
            "NO NAME    ",      //         VolumeLabel[]
            "FAT12   ",   //    //         FileSystemName[]
            {                   //         aBootCode1x[]
              0
            }
          }
        }
      },
      {                         //   aBootCode32[]
        0
      },
      0xAA55                    //   Signature0xAA55
    }
  },
  NULL
};

//
// Sample test HDD partition layout:
//
// Active  Type             Size  Cluster Size  Letter Layout
//         FAT12 CHS       ~4 MB          1 KB  F:     1 boot, 32 root, 4084 clusters => 2*12 FATs, 8168 data = 8225
//      x  FAT16 CHS < 31  ~4 MB          1 KB  C:     1 boot, 32 root, 4085 clusters => 2*16 FATs, 8170 data = 8235
//         Ext CHS                                     1+65689+32932=98622
//           FAT16 CHS    ~32 MB          2 KB  D:     1 boot, 32 root, 16382 clusters => 2*64 FATs, 65528 data = 65689
//           Ext CHS                                   1+32931=32932
//             FAT16 CHS  ~16 MB          1 KB  E:     1 boot, 32 root, 16384 clusters => 2*65 FATs, 32768 data = 32931
//         FAT16 LBA     ~128 MB          2 KB  G:     1 boot, 32 root, 65524 clusters => 2*256 FATs, 262096 data = 262641
//                                                     1+8225+8235+98622+262641=377724 ~184 MB

extern tExtendedPartition DiskD;
extern tExtendedPartition DiskE;

tImageDescriptor ImgHdd =
{
  0,                            // IsFloppy
  24,//1024,                         // CylinderCnt
  256,                          // HeadCnt
  63,                           // SectorCnt
  {                             // MBR
    {                           // aBootCode[]
      0
    },
    {                           // aPartitions[]
      {                         //   aPartitions[0]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_FAT12_PARTITION,     //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[1]
        ps_ACTIVE_PARTITION,    //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_FAT16_UNDER_32MB_PARTITION, //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[2]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_EXTENDED_PARTITION,   //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[3]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_FAT16_OVER_32MB_LBA_PARTITION, //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      }
    },
    0xAA55                      // Signature0xAA55
  },
  {                             // aBootSectors[]
    {                           // aBootSectors[0]
      {                         //   aJump[]
        0xEB, 0x3C, 0x90
      },
      "FAT-TEST",               //   OEMName[]
      {                         //   BPB
        {                       //     BPB1
          512,                  //       BytesPerSector
          2,              //    //       SectorsPerCluster
          1,                    //       ReservedSectorsCount
          2,                    //       NumberOfFATs
          512,                  //       RootEntriesCount
          8225,           //    //       TotalSectorsCount16
          0xF8,                 //       MediaType
          12,             //    //       SectorsPerFAT1x
          63,                   //       SectorsPerTrack
          256,                  //       HeadsPerCylinder
          0,              //    //       HiddenSectorsCount
          0               //    //       TotalSectorsCount32
        },
        {                       //     BPB2
          .FAT1x =
          {                     //       FAT1x
            0x80,               //         DriveNumber
            0,                  //         reserved1
            0x29,               //         ExtendedBootSignature
            0x80800000UL, //    //         VolumeSerialNumber
            "NO NAME    ",      //         VolumeLabel[]
            "FAT12   ",   //    //         FileSystemName[]
            {                   //         aBootCode1x[]
              0
            }
          }
        }
      },
      {                         //   aBootCode32[]
        0
      },
      0xAA55                    //   Signature0xAA55
    },
    {                           // aBootSectors[1]
      {                         //   aJump[]
        0xEB, 0x3C, 0x90
      },
      "FAT-TEST",               //   OEMName[]
      {                         //   BPB
        {                       //     BPB1
          512,                  //       BytesPerSector
          2,              //    //       SectorsPerCluster
          1,                    //       ReservedSectorsCount
          2,                    //       NumberOfFATs
          512,                  //       RootEntriesCount
          8235,           //    //       TotalSectorsCount16
          0xF8,                 //       MediaType
          16,             //    //       SectorsPerFAT1x
          63,                   //       SectorsPerTrack
          256,                  //       HeadsPerCylinder
          0,              //    //       HiddenSectorsCount
          0               //    //       TotalSectorsCount32
        },
        {                       //     BPB2
          .FAT1x =
          {                     //       FAT1x
            0x80,               //         DriveNumber
            0,                  //         reserved1
            0x29,               //         ExtendedBootSignature
            0x80800001UL, //    //         VolumeSerialNumber
            "NO NAME    ",      //         VolumeLabel[]
            "FAT16   ",   //    //         FileSystemName[]
            {                   //         aBootCode1x[]
              0
            }
          }
        }
      },
      {                         //   aBootCode32[]
        0
      },
      0xAA55                    //   Signature0xAA55
    },
    {                           // aBootSectors[2]
      {                         //   aJump[]
        0
      }
    },
    {                           // aBootSectors[3]
      {                         //   aJump[]
        0xEB, 0x3C, 0x90
      },
      "FAT-TEST",               //   OEMName[]
      {                         //   BPB
        {                       //     BPB1
          512,                  //       BytesPerSector
          4,              //    //       SectorsPerCluster
          1,                    //       ReservedSectorsCount
          2,                    //       NumberOfFATs
          512,                  //       RootEntriesCount
          0,              //    //       TotalSectorsCount16
          0xF8,                 //       MediaType
          256,            //    //       SectorsPerFAT1x
          63,                   //       SectorsPerTrack
          256,                  //       HeadsPerCylinder
          0,              //    //       HiddenSectorsCount
          262641UL        //    //       TotalSectorsCount32
        },
        {                       //     BPB2
          .FAT1x =
          {                     //       FAT1x
            0x80,               //         DriveNumber
            0,                  //         reserved1
            0x29,               //         ExtendedBootSignature
            0x80800002UL, //    //         VolumeSerialNumber
            "NO NAME    ",      //         VolumeLabel[]
            "FAT16   ",   //    //         FileSystemName[]
            {                   //         aBootCode1x[]
              0
            }
          }
        }
      },
      {                         //   aBootCode32[]
        0
      },
      0xAA55                    //   Signature0xAA55
    }
  },
  &DiskD                        // pExtendedPartition
};

tExtendedPartition DiskD =
{
  0,                            // AbsLBA
  {                             // MBR
    {                           // aBootCode[]
      0
    },
    {                           // aPartitions[]
      {                         //   aPartitions[0]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_FAT16_OVER_32MB_PARTITION, //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[1]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_EXTENDED_PARTITION,  //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[2]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION,   //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[3]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION,   //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      }
    },
    0xAA55                      // Signature0xAA55
  },
  {                           // BootSector
    {                         //   aJump[]
      0xEB, 0x3C, 0x90
    },
    "FAT-TEST",               //   OEMName[]
    {                         //   BPB
      {                       //     BPB1
        512,                  //       BytesPerSector
        4,              //    //       SectorsPerCluster
        1,                    //       ReservedSectorsCount
        2,                    //       NumberOfFATs
        512,                  //       RootEntriesCount
        0,              //    //       TotalSectorsCount16
        0xF8,                 //       MediaType
        64,             //    //       SectorsPerFAT1x
        63,                   //       SectorsPerTrack
        256,                  //       HeadsPerCylinder
        0,              //    //       HiddenSectorsCount
        65689UL         //    //       TotalSectorsCount32
      },
      {                       //     BPB2
        .FAT1x =
        {                     //       FAT1x
          0x80,               //         DriveNumber
          0,                  //         reserved1
          0x29,               //         ExtendedBootSignature
          0x80800003UL, //    //         VolumeSerialNumber
          "NO NAME    ",      //         VolumeLabel[]
          "FAT16   ",   //    //         FileSystemName[]
          {                   //         aBootCode1x[]
            0
          }
        }
      }
    },
    {                         //   aBootCode32[]
      0
    },
    0xAA55                    //   Signature0xAA55
  },
  &DiskE                        // pExtendedPartition
};

tExtendedPartition DiskE =
{
  0,                            // AbsLBA
  {                             // MBR
    {                           // aBootCode[]
      0
    },
    {                           // aPartitions[]
      {                         //   aPartitions[0]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_FAT16_OVER_32MB_PARTITION, //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[1]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION,   //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[2]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION,   //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[3]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION,   //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      }
    },
    0xAA55                      // Signature0xAA55
  },
  {                           // BootSector
    {                         //   aJump[]
      0xEB, 0x3C, 0x90
    },
    "FAT-TEST",               //   OEMName[]
    {                         //   BPB
      {                       //     BPB1
        512,                  //       BytesPerSector
        2,              //    //       SectorsPerCluster
        1,                    //       ReservedSectorsCount
        2,                    //       NumberOfFATs
        512,                  //       RootEntriesCount
        0,              //    //       TotalSectorsCount16
        0xF8,                 //       MediaType
        65,             //    //       SectorsPerFAT1x
        63,                   //       SectorsPerTrack
        256,                  //       HeadsPerCylinder
        0,              //    //       HiddenSectorsCount
        32931UL         //    //       TotalSectorsCount32
      },
      {                       //     BPB2
        .FAT1x =
        {                     //       FAT1x
          0x80,               //         DriveNumber
          0,                  //         reserved1
          0x29,               //         ExtendedBootSignature
          0x80800004UL, //    //         VolumeSerialNumber
          "NO NAME    ",      //         VolumeLabel[]
          "FAT16   ",   //    //         FileSystemName[]
          {                   //         aBootCode1x[]
            0
          }
        }
      }
    },
    {                         //   aBootCode32[]
      0
    },
    0xAA55                    //   Signature0xAA55
  },
  NULL                          // pExtendedPartition
};

//
// Active  Type             Size  Cluster Size  Letter Layout
//      x  FAT32 LBA     ~256 MB          4 KB  C:     2*6=12 boot, 65525 clusters => 2*512 FATs, 524200 data = 525236
//                                                     1+525236=525237
//
tImageDescriptor ImgHdd2 =
{
  0,                            // IsFloppy
  33,//1024,                    // CylinderCnt
  256,                          // HeadCnt
  63,                           // SectorCnt
  {                             // MBR
    {
      0
    },                          // aBootCode[]
    {                           // aPartitions[]
      {                         //   aPartitions[0]
        ps_ACTIVE_PARTITION,    //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_FAT32_LBA_PARTITION, //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        1,                      //     StartSectorLBA
        525236UL                //     SectorsCount
      },
      {                         //   aPartitions[1]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION, //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[2]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION,   //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      },
      {                         //   aPartitions[3]
        ps_INACTIVE_PARTITION,  //     PartitionStatus
        {                       //     StartSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        pt_UNKNOWN_PARTITION, //     PartitionType
        {                       //     EndSectorCHS
          0,                    //       Head
          0                     //       PackedCylSec
        },
        0,                      //     StartSectorLBA
        0                       //     SectorsCount
      }
    },
    0xAA55                      // Signature0xAA55
  },
  {                             // aBootSectors[]
    {                           // aBootSectors[0]
      {                         //   aJump[]
        0xEB, 0x3C, 0x90
      },
      "FAT-TEST",               //   OEMName[]
      {                         //   BPB
        {                       //     BPB1
          512,                  //       BytesPerSector
          8,              //    //       SectorsPerCluster
          12,             //    //       ReservedSectorsCount
          2,                    //       NumberOfFATs
          0,              //    //       RootEntriesCount
          0,              //    //       TotalSectorsCount16
          0xF8,                 //       MediaType
          0,              //    //       SectorsPerFAT1x
          63,                   //       SectorsPerTrack
          256,                  //       HeadsPerCylinder
          0,              //    //       HiddenSectorsCount
          525236UL        //    //       TotalSectorsCount32
        },
        {                       //     BPB2
          .FAT32 =
          {                     //       FAT32
            512,          //    //         SectorsPerFAT32
            0,            //??? //         ExtendedFlags
            0x0000,             //         FSVersion
            2,                  //         RootDirectoryClusterNo
            1,                  //         FSInfoSectorNo
            6,                  //         BackupBootSectorNo
            {                   //         reserved[]
              0
            },
            0x81,               //         DriveNumber
            0,                  //         reserved1
            0x29,               //         ExtendedBootSignature
            0x81810000UL, //    //         VolumeSerialNumber
            "NO NAME    ",      //         VolumeLabel[]
            "FAT32   "    //    //         FileSystemName[]
          }
        }
      },
      {                         //   aBootCode32[]
        0
      },
      0xAA55                    //   Signature0xAA55
    },
    {                           // aBootSectors[1]
      {                         //   aJump[]
        0
      }
    },
    {                           // aBootSectors[2]
      {                         //   aJump[]
        0
      }
    },
    {                           // aBootSectors[3]
      {                         //   aJump[]
        0
      }
    }
  },
  NULL                          // pExtendedPartition
};

tFAT32FSInfoSector FAT32FSInfoSector =
{
  0x41615252,                   // LeadingSignature0x41615252
  {                             // reserved1[]
    0
  },
  0x61417272,                   // StrucSignature0x61417272
  0xFFFFFFFFUL,                 // LastKnownFreeClusterCount
  0xFFFFFFFFUL,                 // FirstClusterToCheckIfFree
  {                             // reserved2[]
    0
  },
  0xAA550000                    // TrailingSignature0xAA550000
};

long fsize (FILE *f)
{
  long len, cur;
  if (f == NULL)
    return -1;
  cur = ftell (f);
  if (cur < 0)
    return -1;
  if (fseek (f, 0, SEEK_END))
    return -1;
  len = ftell (f);
  if (len < 0)
    return -1;
  if (fseek (f, cur, SEEK_SET))
    return -1;
  return len;
}

FILE* fcreate (const char* filename, long size)
{
  FILE* f;

  if ((f = fopen(filename, "wb")) == NULL)
  {
    printf ("can't create file \'%s\'.\n", filename);
    goto lend;
  }

  if (fseek (f, size-1, SEEK_SET))
  {
lwerr:
    printf ("failed to create file \'%s\' of size %ld\n", filename, size);
    fclose (f);
    f = NULL;
    remove (filename);
    goto lend;
  }

  if (fwrite ("\0", 1, 1, f) != 1)
  {
    goto lwerr;
  }

lend:
  return f;
}

int WriteMBR (tPartitionSector* pMBR, uint32 LBA, FILE* f)
{
  printf ("MBR @ %lu\n", LBA);

  if (fseek (f, LBA * 512, SEEK_SET))
  {
    printf ("failed to seek\n");
    return -1;
  }

  if (fwrite (pMBR, 1, sizeof(*pMBR), f) != sizeof(*pMBR))
  {
    printf ("failed to write\n");
    return -1;
  }

  return 0;
}

int InitFAT (tFATBootSector* pBootSector, uint32 LBA, FILE* f)
{
  uint8 aSector[512];
  uint32 NumOfSectorsToZero;
  uint i;

  printf ("FAT1x @ %lu\n", LBA);

  // write out boot sector
  if (fseek (f, LBA * 512, SEEK_SET))
  {
    printf ("failed to seek\n");
    return -1;
  }

  if (fwrite (pBootSector, 1, sizeof(*pBootSector), f) != sizeof(*pBootSector))
  {
    printf ("failed to write\n");
    return -1;
  }

  // zero out the FAT sectors and the root directory
  if (fseek (f,
             (LBA + pBootSector->BPB.BPB1.ReservedSectorsCount) * 512,
             SEEK_SET))
  {
    printf ("failed to seek\n");
    return -1;
  }

  NumOfSectorsToZero =
    (uint32)pBootSector->BPB.BPB1.NumberOfFATs *
      pBootSector->BPB.BPB1.SectorsPerFAT1x +
    (uint32)pBootSector->BPB.BPB1.RootEntriesCount *
      sizeof(tFATDirectoryEntry) / 512;

  memset (aSector, 0, sizeof(aSector));

  while (NumOfSectorsToZero--)
  {
    if (fwrite (aSector, 1, sizeof(aSector), f) != sizeof(aSector))
    {
      printf ("failed to write\n");
      return -1;
    }
  }

  switch (GetFATType (&pBootSector->BPB))
  {
    case ft_FAT16:
      // initialize FAT16's first entry's low byte with media type
      aSector[0*2+0] = pBootSector->BPB.BPB1.MediaType;
      aSector[0*2+1] = 0xFF;

      // initialize FAT16's second entry to the last cluster mark value:
      aSector[1*2+0] = 0xFF;
      aSector[1*2+1] = 0xFF; // clean shutdown=1, hardware errors=1=no errors
      break;
    case ft_FAT12:
      // initialize FAT12's first entry's low byte with media type
      // initialize FAT12's second entry to the last cluster mark value:
      aSector[0] = pBootSector->BPB.BPB1.MediaType;
      aSector[1] = 0xFF;
      aSector[2] = 0xFF;
      break;
    default:
      printf ("wrong FAT type\n");
      return -1;
  }

  for (i = 0; i < pBootSector->BPB.BPB1.NumberOfFATs; i++)
  {
    if (fseek (f,
               (LBA + pBootSector->BPB.BPB1.ReservedSectorsCount +
                 (uint32)i * pBootSector->BPB.BPB1.SectorsPerFAT1x) * 512,
               SEEK_SET))
    {
      printf ("failed to seek\n");
      return -1;
    }

    if (fwrite (aSector, 1, sizeof(aSector), f) != sizeof(aSector))
    {
      printf ("failed to write\n");
      return -1;
    }
  }

  return 0;
}

int InitFAT32 (tFATBootSector* pBootSector, uint32 LBA, FILE* f)
{
  uint8 aSector[512];
  uint32 NumOfSectorsToZero;
  uint i;

  printf ("FAT32 @ %lu\n", LBA);

  memset (aSector, 0, sizeof(aSector));
  aSector[510] = 0x55;
  aSector[511] = 0xAA;

  // write out boot sector
  for (i = 0; i < 2; i++)
  {
    // boot sector
    if (fseek (f,
               (LBA + i * pBootSector->BPB.BPB2.FAT32.BackupBootSectorNo) * 512,
               SEEK_SET))
    {
      printf ("failed to seek\n");
      return -1;
    }

    if (fwrite (pBootSector, 1, sizeof(*pBootSector), f) != sizeof(*pBootSector))
    {
      printf ("failed to write\n");
      return -1;
    }

    // fs info sector
    if (fseek (f,
               (LBA + i * pBootSector->BPB.BPB2.FAT32.BackupBootSectorNo +
                pBootSector->BPB.BPB2.FAT32.FSInfoSectorNo) * 512,
               SEEK_SET))
    {
      printf ("failed to seek\n");
      return -1;
    }

    if (fwrite (&FAT32FSInfoSector, 1, sizeof(FAT32FSInfoSector), f) != sizeof(FAT32FSInfoSector))
    {
      printf ("failed to write\n");
      return -1;
    }

    // last sector of the 3 sectors making up the FAT32 boot sector
    if (fwrite (aSector, 1, sizeof(aSector), f) != sizeof(aSector))
    {
      printf ("failed to write\n");
      return -1;
    }
  }

  // zero out the FAT sectors and the root directory
  if (fseek (f,
             (LBA + pBootSector->BPB.BPB1.ReservedSectorsCount) * 512,
             SEEK_SET))
  {
    printf ("failed to seek\n");
    return -1;
  }

  NumOfSectorsToZero =
    (uint32)pBootSector->BPB.BPB1.NumberOfFATs *
      pBootSector->BPB.BPB2.FAT32.SectorsPerFAT32 +
    pBootSector->BPB.BPB1.SectorsPerCluster;

  memset (aSector, 0, sizeof(aSector));

  while (NumOfSectorsToZero--)
  {
    if (fwrite (aSector, 1, sizeof(aSector), f) != sizeof(aSector))
    {
      printf ("failed to write\n");
      return -1;
    }
  }

  // initialize FAT's first entry with media type and all ones:
  aSector[0*4+0] = pBootSector->BPB.BPB1.MediaType;
  aSector[0*4+1] = 0xFF;
  aSector[0*4+2] = 0xFF;
  aSector[0*4+3] = 0x0F;

  // initialize FAT's second entry to the last cluster mark value:
  aSector[1*4+0] = 0xFF;
  aSector[1*4+1] = 0xFF;
  aSector[1*4+2] = 0xFF;
  aSector[1*4+3] = 0x0F; // clean shutdown=1, hardware errors=1=no errors

  // initialize FAT's entry for the root directory, cluster 2:
  aSector[2*4+0] = 0xFF;
  aSector[2*4+1] = 0xFF;
  aSector[2*4+2] = 0xFF;
  aSector[2*4+3] = 0x0F;

  for (i = 0; i < pBootSector->BPB.BPB1.NumberOfFATs; i++)
  {
    if (fseek (f,
               (LBA + pBootSector->BPB.BPB1.ReservedSectorsCount +
                 (uint32)i * pBootSector->BPB.BPB2.FAT32.SectorsPerFAT32) * 512,
               SEEK_SET))
    {
      printf ("failed to seek\n");
      return -1;
    }

    if (fwrite (aSector, 1, sizeof(aSector), f) != sizeof(aSector))
    {
      printf ("failed to write\n");
      return -1;
    }
  }

  return 0;
}

void PreparePartitionInfo (int IsFat32, uint32* pSectorsCountInDiskImage)
{
  uint32 LBA;
  uint32 TotalHddSectorsCnt;
  uint i, ExtendedPartitionIndex;

  if (!IsFat32)
  {
    // Assign LBAs to the partitions
    TotalHddSectorsCnt = LBA = 1;

    // 1st pass: assign LBAs to primary partitions and ignore the extended one;
    // partitions that follow the extended partition in the MBR
    // will not yet receive their final LBAs...
    for (i = 0; i < 4; i++)
    {
      switch (ImgHdd.MBR.aPartitions[i].PartitionType)
      {
        case pt_UNKNOWN_PARTITION:
          ImgHdd.MBR.aPartitions[i].StartSectorLBA = 0;
          ImgHdd.MBR.aPartitions[i].SectorsCount = 0;
          break;

        case pt_EXTENDED_PARTITION:
        case pt_EXTENDED_LBA_PARTITION:
          ImgHdd.MBR.aPartitions[i].StartSectorLBA = LBA;
          ImgHdd.MBR.aPartitions[i].SectorsCount = 0;
          break;

        default:
        {
          uint32 VolumeTotalSectorsCount =
            ImgHdd.aBootSectors[i].BPB.BPB1.TotalSectorsCount16;
          if (!VolumeTotalSectorsCount)
            VolumeTotalSectorsCount =
              ImgHdd.aBootSectors[i].BPB.BPB1.TotalSectorsCount32;

          ImgHdd.MBR.aPartitions[i].SectorsCount = VolumeTotalSectorsCount;
          ImgHdd.MBR.aPartitions[i].StartSectorLBA = LBA;

          LBA += VolumeTotalSectorsCount;
          TotalHddSectorsCnt += VolumeTotalSectorsCount;
          break;
        }
      }
    }

    // 2nd pass: assign LBAs to the nested partitions in the
    // extended partition
    for (ExtendedPartitionIndex = 4, i = 0; i < 4; i++)
    {
      switch (ImgHdd.MBR.aPartitions[i].PartitionType)
      {
        case pt_EXTENDED_PARTITION:
        case pt_EXTENDED_LBA_PARTITION:
        {
          tExtendedPartition* pExtendedPartition;
          uint32 VolumeTotalSectorsCount = 0;

          ExtendedPartitionIndex = i;

          // calculate the total size of the extended partition and
          // update the sizes and LBAs of the nested primary partitions in it
          for (pExtendedPartition = ImgHdd.pExtendedPartition;
               pExtendedPartition != NULL;
               pExtendedPartition = pExtendedPartition->pNext)
          {
            uint32 s;
            if (pExtendedPartition->BootSector.BPB.BPB1.TotalSectorsCount16)
              s = pExtendedPartition->BootSector.BPB.BPB1.TotalSectorsCount16;
            else
              s = pExtendedPartition->BootSector.BPB.BPB1.TotalSectorsCount32;

            pExtendedPartition->MBR.aPartitions[0].SectorsCount = s;

            VolumeTotalSectorsCount += s + 1; // count MBR as well

            pExtendedPartition->MBR.aPartitions[0].StartSectorLBA = 1;
          }

          // update the total sizes and LBAs of the extended partition in the MBR
          ImgHdd.MBR.aPartitions[i].SectorsCount = VolumeTotalSectorsCount;
          TotalHddSectorsCnt += VolumeTotalSectorsCount;

          // update the sizes and LBAs of the nested extended partitions
          for (pExtendedPartition = ImgHdd.pExtendedPartition;
               pExtendedPartition != NULL;
               pExtendedPartition = pExtendedPartition->pNext)
          {
            uint32 s = VolumeTotalSectorsCount -
              pExtendedPartition->MBR.aPartitions[0].SectorsCount - 1;

            if (s)
            {
              pExtendedPartition->MBR.aPartitions[1].SectorsCount = s;

              pExtendedPartition->MBR.aPartitions[1].StartSectorLBA =
                ImgHdd.MBR.aPartitions[i].SectorsCount - s;
            }

            VolumeTotalSectorsCount = s;
          }

          // calculate absolute LBAs of the nested MBRs inside the extended
          // partition
          LBA = ImgHdd.MBR.aPartitions[i].StartSectorLBA;
          for (pExtendedPartition = ImgHdd.pExtendedPartition;
               pExtendedPartition != NULL;
               pExtendedPartition = pExtendedPartition->pNext)
          {
            pExtendedPartition->AbsLBA = LBA;
            LBA += 1 + pExtendedPartition->MBR.aPartitions[0].SectorsCount;
          }

          break;
        }
      }
    }

    // 3rd pass: adjust the LBAs of the primary
    // partitions (if any) following the extended partition
    for (i = ExtendedPartitionIndex + 1; i < 4; i++)
    {
      switch (ImgHdd.MBR.aPartitions[i].PartitionType)
      {
        case pt_UNKNOWN_PARTITION:
        case pt_EXTENDED_PARTITION:
        case pt_EXTENDED_LBA_PARTITION:
          break;

        default:
          ImgHdd.MBR.aPartitions[i].StartSectorLBA +=
            ImgHdd.MBR.aPartitions[ExtendedPartitionIndex].SectorsCount;
          break;
      }
    }

    // 4th pass: assign LBAs of primary partitions to their boot sector's
    // HiddenSectorsCount
    for (i = 0; i < 4; i++)
    {
      switch (ImgHdd.MBR.aPartitions[i].PartitionType)
      {
        case pt_UNKNOWN_PARTITION:
        case pt_EXTENDED_PARTITION:
        case pt_EXTENDED_LBA_PARTITION:
          break;

        default:
          ImgHdd.aBootSectors[i].BPB.BPB1.HiddenSectorsCount =
            ImgHdd.MBR.aPartitions[i].StartSectorLBA;
          break;
      }
    }
  }
  else // elseof if (!IsFat32)
  {
    TotalHddSectorsCnt = 1 + ImgHdd2.MBR.aPartitions[0].SectorsCount;
  }

  *pSectorsCountInDiskImage = TotalHddSectorsCnt;
}

int WriteImage (FILE* f, int IsFat32)
{
  int res = -1;
  uint i;

  if (!IsFat32)
  {
    // Write out all MBRs
    if (WriteMBR (&ImgHdd.MBR, 0, f))
    {
      goto lend;
    }

    if (ImgHdd.pExtendedPartition != NULL)
    {
      tExtendedPartition* pExtendedPartition;

      for (pExtendedPartition = ImgHdd.pExtendedPartition;
           pExtendedPartition != NULL;
           pExtendedPartition = pExtendedPartition->pNext)
      if (WriteMBR (&pExtendedPartition->MBR,
                    pExtendedPartition->AbsLBA,
                    f))
      {
        goto lend;
      }
    }

    // Write out all boot sectors and init all FATs
    for (i = 0; i < 4; i++)
    {
      switch (ImgHdd.MBR.aPartitions[i].PartitionType)
      {
        case pt_UNKNOWN_PARTITION:
          break;

        default:
          if (InitFAT (&ImgHdd.aBootSectors[i],
                       ImgHdd.MBR.aPartitions[i].StartSectorLBA,
                       f))
          {
            goto lend;
          }
          break;

        case pt_EXTENDED_PARTITION:
        case pt_EXTENDED_LBA_PARTITION:
        {
          tExtendedPartition* pExtendedPartition;

          for (pExtendedPartition = ImgHdd.pExtendedPartition;
               pExtendedPartition != NULL;
               pExtendedPartition = pExtendedPartition->pNext)
          if (InitFAT (&pExtendedPartition->BootSector,
                       pExtendedPartition->AbsLBA + 1,
                       f))
          {
            goto lend;
          }
          break;
        }
      }
    }
  }
  else // elseof if (!IsFat32)
  {
    // Write out all MBRs
    if (WriteMBR (&ImgHdd2.MBR, 0, f))
    {
      goto lend;
    }

    // Write out all boot sectors and init all FATs
    if (InitFAT32 (&ImgHdd2.aBootSectors[0],
                   ImgHdd2.MBR.aPartitions[0].StartSectorLBA,
                   f))
    {
      goto lend;
    }
  }

  res = 0;

lend:

  return res;
}

int main (int argc, char* argv[])
{
  FILE*   f = NULL;
  int     IsFat32;
  enum {IMG_UNDEFINED, IMG_FDD12, IMG_HDD1x, IMG_HDD32} ImageType = IMG_UNDEFINED;
  uint32  SectorsCountInDiskImage;
  long    fsz;
  int     res = 1;

  srand((unsigned)time(NULL));

  if (argc < 3)
  {
linfo:
    printf ("Usage:\n  %s\n"
            "    <-fat[12|1x|32]> <disk image file> [fat12 boot sector file]\n\n", argv[0]);
    printf ("  -fat12 creates 3.5\" 1.44MB FAT12 floppy image, optionally\n"
            "    writing boot code from fat12 boot sector file (if given)\n"
            "  -fat1x creates FAT12+FAT16 hard drive image\n"
            "  -fat32 creates FAT32 hard drive image\n");
    printf ("\nIf the image file doesn't exist, it will be created and formatted.\n"
            "If the image file does exist, it will be quick-formatted.\n");
    goto lend;
  }

  if (!strcmp(argv[1], "-fat1x") || !strcmp(argv[1], "-FAT1X"))
    ImageType = IMG_HDD1x;
  else if (!strcmp(argv[1], "-fat32") || !strcmp(argv[1], "-FAT32"))
    ImageType = IMG_HDD32;
  else if (!strcmp(argv[1], "-fat12") || !strcmp(argv[1], "-FAT12"))
    ImageType = IMG_FDD12;
  else
    goto linfo;

  IsFat32 = ImageType == IMG_HDD32;

  if (ImageType == IMG_FDD12)
  {
    SectorsCountInDiskImage =
      ImgFdd.aBootSectors[0].BPB.BPB1.TotalSectorsCount16;
  }
  else
  {
    PreparePartitionInfo (IsFat32, &SectorsCountInDiskImage);

    // let's make it a multiple of 256*63 sectors, full cylinder
    SectorsCountInDiskImage += 256*63 - 1;
    SectorsCountInDiskImage /= 256*63;
    SectorsCountInDiskImage *= 256*63;
  }

  if ((f = fopen (argv[2], "rb")) == NULL)
  {
    printf ("can't open file \'%s\', creating...\n", argv[2]);
    if ((f = fcreate (argv[2], SectorsCountInDiskImage * 512UL)) == NULL)
    {
      printf ("can't create \'%s\' of size %lu...\n", argv[2], SectorsCountInDiskImage);
      goto lend;
    }
  }
  else
  {
    fclose (f);
    printf ("quick formatting \'%s\'...\n", argv[2]);
    if ((f = fopen (argv[2], "rb+")) == NULL)
    {
      printf ("can't open \'%s\' for writing...\n", argv[2]);
      goto lend;
    }
  }

  if (((fsz = fsize (f)) < 0) || (fsz < SectorsCountInDiskImage))
  {
    printf ("file \'%s\' size is %ld bytes, needed %lu bytes or more\n",
            argv[2],
            fsz,
            SectorsCountInDiskImage);
    goto lend;
  }

  if (ImageType == IMG_FDD12)
  {
    tFATBootSector BootSector;
    FILE* fboot = NULL;
    // make the floppy image bootable if asked using specified file
    if (argc == 4)
    {
      if ((fboot = fopen(argv[3], "rb")) == NULL)
      {
        printf ("can't open file \'%s\' with boot sector code\n",
                argv[3]);
        goto lend;
      }
      else
      {
        if (fread (&BootSector, 1, sizeof(BootSector), fboot) != sizeof(BootSector))
        {
          printf ("can't read boot sector code from file \'%s\'\n",
                  argv[3]);
          fclose (fboot);
          goto lend;
        }
        memcpy (ImgFdd.aBootSectors[0].aJump,
                BootSector.aJump,
                sizeof(BootSector.aJump));
        memcpy (ImgFdd.aBootSectors[0].BPB.BPB2.FAT1x.aBootCode1x,
                BootSector.BPB.BPB2.FAT1x.aBootCode1x,
                sizeof(BootSector.BPB.BPB2.FAT1x.aBootCode1x));
        memcpy (ImgFdd.aBootSectors[0].aBootCode32,
                BootSector.aBootCode32,
                sizeof(BootSector.aBootCode32));
        fclose (fboot);
      }
    }
    // Randomize floppy's serial number -- the floppy change
    // logic needs unique serial numbers to detect disk changes
    // when the floppy controller can't detect the change
    ImgFdd.aBootSectors[0].BPB.BPB2.FAT1x.VolumeSerialNumber =
      (((uint32)rand()) << 16) | (rand() & 0xFFFFU);
    if (InitFAT (&ImgFdd.aBootSectors[0],
                 0,
                 f))
    {
      goto lend;
    }
  }
  else
  {
    if (WriteImage (f, IsFat32))
    {
      goto lend;
    }
  }

  if (fclose (f))
  {
    printf ("failed to close file \'%s\'\n", argv[2]);
    goto lend;
  }

  f = NULL;

  printf ("Total image sectors: %lu\n", SectorsCountInDiskImage);

  res = 0;

lend:

  if (f != NULL)
    fclose (f);

  return res;
}
