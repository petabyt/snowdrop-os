@SET CD_IMAGE=snowdrop.iso
@SET FLOPPY_IMAGE_FILE=snowdrop.img

@rem Remove existing cd image
@del /F /Q ..\disk\%CD_IMAGE%

@IF EXIST ..\disk\%FLOPPY_IMAGE_FILE% (
..\tools\cdrtools\mkisofs.exe -pad -b ..\disk\%FLOPPY_IMAGE_FILE% -R -o ..\disk\%CD_IMAGE% ..\disk\%FLOPPY_IMAGE_FILE%
@echo ===============================================
@echo DONE CREATING CD IMAGE
@echo ===============================================
) ELSE (
@ECHO ===============================================================
@ECHO FLOPPY IMAGE NOT FOUND!! 
@ECHO Building CD image requires the floppy image to have been built.
@ECHO RUN buildFloppyImage.bat first
@ECHO ===============================================================
)
