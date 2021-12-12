@set RTL=test

@set INCLUDE=-icommon\
@set OPTIMIZATION=-O0
@set FORMAT=-f bin
@set OPTIONS=%OPTIMIZATION% %INCLUDE% %FORMAT%

mkdir output
@del /F /Q output\*.*

cd src

@REM Assemble the RTL, putting result in the output directory
cd apps
..\..\tools\nasm\nasm.exe %OPTIONS% rtl\%RTL%.asm -o ..\..\output\%RTL%.RTL
cd..

cd..

pause
