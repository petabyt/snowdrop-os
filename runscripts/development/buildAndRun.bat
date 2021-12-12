@rem Remove output and disk directories
@call clean.bat

cd build

@rem Generated binaries in output\
@call assemble.bat

@rem Create bootable floppy disk image in disk\
@call buildFloppyImage.bat

@rem Create bootable CD-ROM image in disk\
@call buildCDImage.bat

cd..

@rem Copy HDD image to disk\
@copy build\hdd_10Mb.img disk\

boot_snowdrop.bxrc
