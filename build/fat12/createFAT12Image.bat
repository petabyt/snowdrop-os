SET BLANK_FLOPPY_IMAGE=blank.img
SET FAT12_IMAGE=SNOWDROP.FAT
SET TRUNCATE_AMOUNT_TO_KEEP=16896

@del /F /Q %BLANK_FLOPPY_IMAGE%
@del /F /Q %FAT12_IMAGE%

@echo Creating a blank FAT12 floppy image
..\..\tools\mtools\imginit\imginit.exe -fat12 %BLANK_FLOPPY_IMAGE%

@echo Truncating blank floppy image, keeping only what is needed for a FAT12 format
..\..\tools\dd\dd.exe if=%BLANK_FLOPPY_IMAGE% of=%FAT12_IMAGE% bs=1 count=%TRUNCATE_AMOUNT_TO_KEEP% --progress

@rem Remove blank floppy image
@del /F /Q %BLANK_FLOPPY_IMAGE%

@echo =================================================
@echo Optionally, manually replace "FAT-TEST" with 
@echo "SNOWDROP" inside %FAT12_IMAGE% (OEM Identifier)
@echo =================================================

pause
