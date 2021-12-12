mkdir output
@del /F /Q output\*.*

cd src

@REM Assemble the kernel, putting result in the output directory
cd kernel
..\..\tools\nasm\nasm.exe -O0 kernel.asm -f bin -o ..\..\output\SNOWDROP.KRN
cd..

pause
