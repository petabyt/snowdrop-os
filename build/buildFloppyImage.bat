@SET IMAGE_FILE=snowdrop.img

@echo ===============================================
@echo GENERATING SNOWDROP OS FLOPPY DISK IMAGE
@echo ===============================================

mkdir ..\disk
del /F /Q ..\disk\%IMAGE_FILE%

@echo Creating the floppy image
..\tools\mtools\imginit\imginit.exe -fat12 ..\disk\%IMAGE_FILE%

@echo Copying the contents of the output directory to the floppy image
cd ..\output
for %%i in (*.*) do ..\tools\mtools\imgcpy\imgcpy.exe %%i ..\disk\%IMAGE_FILE%=a:\%%i
cd..

cd build

@echo Removing boot loader file from floppy image (was included by previous step)
@rem (no longer needed)    ..\tools\mtools\mdel.exe ..\disk\%IMAGE_FILE% LOADER.BIN

@echo Copying boot loader to boot sector inside the floppy image
..\tools\mkbt\mkbt.exe ..\output\SNOWDROP.LDR ..\disk\%IMAGE_FILE%

@echo ===============================================
@echo DONE CREATING FLOPPY IMAGE
@echo ===============================================
