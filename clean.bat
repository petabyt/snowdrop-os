@echo ===============================================
@echo CLEANING UP DISK IMAGES IN disk\
@echo CLEANING UP BINARIES IN output\
@echo REMOVING DIRECTORIES disk\ AND output\
@echo ===============================================

@del /F /Q output\*.*
@del /F /Q disk\*.*
@rmdir output
@rmdir disk
