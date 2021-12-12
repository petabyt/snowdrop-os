@echo off
rem
rem MAKEBOOT sample batch file for using MKBT
rem Created by Bart Lagerweij -- http://www.nu2.nu/mkbt
rem
if "%1" == "" goto _err1
if not exist %1\bootsect.bin goto _err2
echo.
echo Insert floppy to format in drive A:
echo * Warning! all data on floppy will be erased! *
echo.
echo Press Ctrl-C to abort
pause
echo *** Formating diskette ***
if "%os%" == "Windows_NT" goto _nt
format a: /u /autotest
if errorlevel 1 goto _abort
goto _1
:_nt
format a: /u /backup /v:
if errorlevel 1 goto _abort
:_1
echo *** Making bootable diskette from (%1) ***
mkbt %1\bootsect.bin a:
rem MS
if exist %1\io.sys copy %1\io.sys a:\
if exist %1\msdos.sys copy %1\msdos.sys a:\
rem non MS
if exist %1\ibmbio.com copy %1\ibmbio.com a:\
if exist %1\ibmdos.com copy %1\ibmdos.com a:\
copy %1\command.com a:
echo *** Label diskette ***
label a: mkbt
echo *** Flag system files to Readonly+System+Hidden ***
rem MS
if exist a:\io.sys attrib +r +s +h a:\io.sys
if exist a:\msdos.sys attrib +r +s +h a:\msdos.sys
rem non MS
if exist a:\ibmbio.com attrib +r +s +h a:\ibmbio.com
if exist a:\ibmdos.com attrib +r +s +h a:\ibmdos.com
attrib +s +h +r a:*.sys
rem
rem You can add your own custom files here...
rem
goto _end
:_err1
echo Parameter required... (see readme.txt)
goto _abort
:_err2
echo Could not find the file "%1\bootsect.bin"
goto _abort
:_abort
echo [aborted]
pause
:_end
