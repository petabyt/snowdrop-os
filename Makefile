# Basic Linux makefile for building Snowdrop OS
# http://www.sebastianmihai.com/snowdrop/
# Written by Daniel Cook, brikbusters@gmail.com

all: clean fixdir compile img
run: all emulate

clean:
	rm -rf disk temp output/* src_

# Fix up Windows only inlcude directories (backslashes)
# Will create a src_ duplicate directory to maintain compatibility with Windows
fixdir:
	-rm -rf src_
	cp -r src src_
	grep -rl '%include' src_/ | xargs sed -i 's/\\/\//g'

ASMFLAGS=-i $(PWD)/src_/apps/common -O0 -f bin

# Makefile pattern compile all apps
APPS=$(shell ls src_/apps/*.*)
APPS_O=$(subst .asm,.app,$(APPS))
%.app: %.asm
	# Compile x/x/x.asm to output/X.APP
	cd $(shell dirname $@); nasm $(ASMFLAGS) $(shell basename $<) \
		-o $(PWD)/output/$(shell basename $@)

# Compile apps first, then other things
compile: $(APPS_O)
	nasm $(ASMFLAGS) src_/loader/loader.asm -o output/SNOWDROP.LDR
	nasm $(ASMFLAGS) src_/loader/mbr.asm -o output/SNOWDROP.MBR
	cd src_/kernel/; nasm $(ASMFLAGS) kernel.asm -o $(PWD)/output/SNOWDROP.KRN
	cd src_/apps/; nasm $(ASMFLAGS) rtl/test.asm -o $(PWD)/output/TEST.RTL
	cd src_/apps/; nasm $(ASMFLAGS) rtl/basic.asm -o $(PWD)/output/BASIC.RTL
	cp -r src/static/* output/

img:
	-rm -rf disk
	-mkdir disk

	# Create 1.44mb fat12 disk
	mkfs.msdos -C disk/snowdrop.img 1440
	
	-rm -rf temp
	-mkdir temp

	# Copy all output into disk
	sudo mount disk/snowdrop.img temp
	sudo cp output/* temp/
	sleep 0.1; sudo umount temp

	# Write the bootloader in
	dd conv=notrunc if=output/SNOWDROP.LDR of=disk/snowdrop.img

emulate:
	# Maybe `sendkey` can be used for quick app loading?
	qemu-system-i386 -fda disk/snowdrop.img

addimg:
	-rm -rf temp
	-mkdir temp

	sudo mount disk/snowdrop.img temp
	sudo cp $(file) temp/
	sleep 0.1; sudo umount temp
