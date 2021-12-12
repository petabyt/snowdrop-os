@echo ================================================================
@echo THIS SCRIPT WILL UNFORMAT THE FLOPPY DISK IN DRIVE B:
@echo IF YOUR DRIVE B: IS ANYTHING BUT THE FLOPPY DRIVE INTENDED TO 
@echo BE UNFORMATTED, THIS WILL DESTROY IT. 
@echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
@echo BE VERY SURE OF WHAT YOU'RE DOING BEFORE PROCEEDING.
@echo - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
@echo IF YOU'RE NOT 100%% SURE RIGHT NOW, PRESS CONTROL-C TO ABORT.
@echo ================================================================

pause

rem Uncomment the line below after you've understood the risks of raw-writing to drive B
rem ..\..\tools\dd\dd.exe --progress if=_blank.img of=\\.\b:

pause
