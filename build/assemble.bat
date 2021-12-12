@set INCLUDE=-icommon\
@set OPTIMIZATION=-O0
@set FORMAT=-f bin
@set OPTIONS=%OPTIMIZATION% %INCLUDE% %FORMAT%

mkdir ..\output
@del /F /Q ..\output\*.*

cd ..\src

@REM Assemble the boot loader, putting result in the output directory
cd loader
..\..\tools\nasm\nasm.exe -O0 loader.asm -f bin -o ..\..\output\SNOWDROP.LDR
..\..\tools\nasm\nasm.exe -O0 mbr.asm -f bin -o ..\..\output\SNOWDROP.MBR
cd..

@REM Assemble the kernel, putting result in the output directory
cd kernel
..\..\tools\nasm\nasm.exe -O0 kernel.asm -f bin -o ..\..\output\SNOWDROP.KRN
cd..

@REM Assemble the apps, putting result in the output directory
cd apps

@REM slim build, for debugging
..\..\tools\nasm\nasm.exe %OPTIONS% sshell.asm -o ..\..\output\SSHELL.APP
..\..\tools\nasm\nasm.exe %OPTIONS% apps.asm -o ..\..\output\APPS.APP
..\..\tools\nasm\nasm.exe %OPTIONS% fileman.asm -o ..\..\output\FILEMAN.APP

@rem GOTO after_apps


@REM ==========================================
@REM ======= FILE AND SYSTEM MANAGEMENT =======
@REM ==========================================
..\..\tools\nasm\nasm.exe %OPTIONS% sshell.asm -o ..\..\output\SSHELL.APP
..\..\tools\nasm\nasm.exe %OPTIONS% apps.asm -o ..\..\output\APPS.APP
..\..\tools\nasm\nasm.exe %OPTIONS% shutdown.asm -o ..\..\output\SHUTDOWN.APP
..\..\tools\nasm\nasm.exe %OPTIONS% fileman.asm -o ..\..\output\FILEMAN.APP
..\..\tools\nasm\nasm.exe %OPTIONS% hexview.asm -o ..\..\output\HEXVIEW.APP
..\..\tools\nasm\nasm.exe %OPTIONS% makeboot.asm -o ..\..\output\MAKEBOOT.APP
..\..\tools\nasm\nasm.exe %OPTIONS% flist.asm -o ..\..\output\FLIST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% fview.asm -o ..\..\output\FVIEW.APP
..\..\tools\nasm\nasm.exe %OPTIONS% fdelete.asm -o ..\..\output\FDELETE.APP
..\..\tools\nasm\nasm.exe %OPTIONS% fcopy.asm -o ..\..\output\FCOPY.APP
..\..\tools\nasm\nasm.exe %OPTIONS% frename.asm -o ..\..\output\FRENAME.APP
..\..\tools\nasm\nasm.exe %OPTIONS% format.asm -o ..\..\output\FORMAT.APP
..\..\tools\nasm\nasm.exe %OPTIONS% diskchg.asm -o ..\..\output\DISKCHG.APP
..\..\tools\nasm\nasm.exe %OPTIONS% restart.asm -o ..\..\output\RESTART.APP
..\..\tools\nasm\nasm.exe %OPTIONS% desktop.asm -o ..\..\output\DESKTOP.APP

@REM ==========================================
@REM ======= SOFTWARE DEVELOPMENT TOOLS =======
@REM ==========================================
..\..\tools\nasm\nasm.exe %OPTIONS% basiclnk.asm -o ..\..\output\BASICLNK.APP
..\..\tools\nasm\nasm.exe %OPTIONS% basicln2.asm -o ..\..\output\BASICLN2.APP
..\..\tools\nasm\nasm.exe %OPTIONS% basicrun.asm -o ..\..\output\BASICRUN.APP
..\..\tools\nasm\nasm.exe %OPTIONS% basicru2.asm -o ..\..\output\BASICRU2.APP
..\..\tools\nasm\nasm.exe %OPTIONS% textedit.asm -o ..\..\output\TEXTEDIT.APP
..\..\tools\nasm\nasm.exe %OPTIONS% asmide.asm -o ..\..\output\ASMIDE.APP
..\..\tools\nasm\nasm.exe %OPTIONS% asm.asm -o ..\..\output\ASM.APP
..\..\tools\nasm\nasm.exe %OPTIONS% dbg.asm -o ..\..\output\DBG.APP

@REM =========================
@REM ======= AMUSEMENT =======
@REM =========================
..\..\tools\nasm\nasm.exe %OPTIONS% aSMtris.asm -o ..\..\output\ASMTRIS.APP
..\..\tools\nasm\nasm.exe %OPTIONS% nosnakes.asm -o ..\..\output\NOSNAKES.APP
..\..\tools\nasm\nasm.exe %OPTIONS% storks.asm -o ..\..\output\STORKS.APP
..\..\tools\nasm\nasm.exe %OPTIONS% snowmine.asm -o ..\..\output\SNOWMINE.APP
..\..\tools\nasm\nasm.exe %OPTIONS% draw.asm -o ..\..\output\DRAW.APP
..\..\tools\nasm\nasm.exe %OPTIONS% hangman.asm -o ..\..\output\HANGMAN.APP

@REM =========================
@REM ======= UTILITIES =======
@REM =========================
..\..\tools\nasm\nasm.exe %OPTIONS% multi.asm -o ..\..\output\MULTI.APP
..\..\tools\nasm\nasm.exe %OPTIONS% present.asm -o ..\..\output\PRESENT.APP
..\..\tools\nasm\nasm.exe %OPTIONS% clock.asm -o ..\..\output\CLOCK.APP
..\..\tools\nasm\nasm.exe %OPTIONS% deflate.asm -o ..\..\output\DEFLATE.APP
..\..\tools\nasm\nasm.exe %OPTIONS% inflate.asm -o ..\..\output\INFLATE.APP

@REM =============================================
@REM ======= TEST AND EXAMPLE APPLICATIONS =======
@REM =============================================
..\..\tools\nasm\nasm.exe %OPTIONS% memtest.asm -o ..\..\output\MEMTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% guitests.asm -o ..\..\output\GUITESTS.APP
..\..\tools\nasm\nasm.exe %OPTIONS% mousegui.asm -o ..\..\output\MOUSEGUI.APP
..\..\tools\nasm\nasm.exe %OPTIONS% mpollraw.asm -o ..\..\output\MPOLLRAW.APP
..\..\tools\nasm\nasm.exe %OPTIONS% mintrraw.asm -o ..\..\output\MINTRRAW.APP
..\..\tools\nasm\nasm.exe %OPTIONS% mmanaged.asm -o ..\..\output\MMANAGED.APP
..\..\tools\nasm\nasm.exe %OPTIONS% hellogui.asm -o ..\..\output\HELLOGUI.APP
..\..\tools\nasm\nasm.exe %OPTIONS% hello.asm -o ..\..\output\HELLO.APP
..\..\tools\nasm\nasm.exe %OPTIONS% canonD.asm -o ..\..\output\CANOND.APP
..\..\tools\nasm\nasm.exe %OPTIONS% ft_large.asm -o ..\..\output\FT_LARGE.APP
..\..\tools\nasm\nasm.exe %OPTIONS% ft_many.asm -o ..\..\output\FT_MANY.APP
..\..\tools\nasm\nasm.exe %OPTIONS% itoatest.asm -o ..\..\output\ITOATEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% serintr.asm -o ..\..\output\SERINTR.APP
..\..\tools\nasm\nasm.exe %OPTIONS% sersend.asm -o ..\..\output\SERSEND.APP
..\..\tools\nasm\nasm.exe %OPTIONS% keepinst.asm -o ..\..\output\KEEPINST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% keepcall.asm -o ..\..\output\KEEPCALL.APP
..\..\tools\nasm\nasm.exe %OPTIONS% sprtest.asm -o ..\..\output\SPRTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% paratest.asm -o ..\..\output\PARATEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% bmptest.asm -o ..\..\output\BMPTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% anisprt.asm -o ..\..\output\ANISPRT.APP
..\..\tools\nasm\nasm.exe %OPTIONS% anisprt2.asm -o ..\..\output\ANISPRT2.APP
..\..\tools\nasm\nasm.exe %OPTIONS% sndtest.asm -o ..\..\output\SNDTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% kbtest.asm -o ..\..\output\KBTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% randtest.asm -o ..\..\output\RANDTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% paramst.asm -o ..\..\output\PARAMST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% lcd1602.asm -o ..\..\output\LCD1602.APP
..\..\tools\nasm\nasm.exe %OPTIONS% bear.asm -o ..\..\output\BEAR.APP
..\..\tools\nasm\nasm.exe %OPTIONS% bsttest.asm -o ..\..\output\BSTTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% msgtest.asm -o ..\..\output\MSGTEST.APP
..\..\tools\nasm\nasm.exe %OPTIONS% rtltest.asm -o ..\..\output\RTLTEST.APP

:after_apps

@REM =================================
@REM ======= RUNTIME LIBRARIES =======
@REM =================================
..\..\tools\nasm\nasm.exe %OPTIONS% rtl\test.asm -o ..\..\output\TEST.RTL
..\..\tools\nasm\nasm.exe %OPTIONS% rtl\basic.asm -o ..\..\output\BASIC.RTL

cd..

@REM Copy all static files to output directory
copy static\*.* ..\output\

cd..
cd build
