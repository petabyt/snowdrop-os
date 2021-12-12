@set APP=storks

@set INCLUDE=-icommon\
@set OPTIMIZATION=-O0
@set FORMAT=-f bin
@set OPTIONS=%OPTIMIZATION% %INCLUDE% %FORMAT%

mkdir output
@del /F /Q output\*.*

cd src

@REM Assemble the app, putting result in the output directory
cd apps
..\..\tools\nasm\nasm.exe %OPTIONS% %APP%.asm -o ..\..\output\%APP%.APP
cd..

cd..

pause
