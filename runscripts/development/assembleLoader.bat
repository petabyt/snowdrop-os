@set INCLUDE=-icommon\
@set OPTIMIZATION=-O0
@set FORMAT=-f bin
@set OPTIONS=%OPTIMIZATION% %INCLUDE% %FORMAT%

mkdir output
@del /F /Q output\*.*

cd src

@REM Assemble the loader, putting result in the output directory
cd loader
..\..\tools\nasm\nasm.exe %OPTIONS% loader.asm -o ..\..\output\loader.bin
@REM this shows the size of the loader binary, useful when developing,
@REM since it has to be kept at or under 512 bytes
dir ..\..\output\loader.bin
cd..

cd..

pause
