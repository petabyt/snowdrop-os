;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the routines of Snowdrop's FAT12 file system driver which deal
; with formatting a 1.44Mb floppy disk with a FAT12 file system.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NUM_FAT12_IMAGE_SECTORS equ 33	; this many sectors before the disk's data area
								; (basically, this is all we need to format a
								; FAT12 floppy disk)
NUM_BOOT_LOADER_SECTORS equ 1
BOOT_LOADER_SECTOR_LOGICAL equ 0

fat12RawImageFileName: db "SNOWDROPFAT", 0
fat12UnpartitionedLoaderFileName: db "SNOWDROPLDR", 0
fat12MbrLoaderFileName: db "SNOWDROPMBR", 0

fat12BootLoaderErrorNoLDR:	db 'Could not load SNOWDROP.LDR', 0
fat12BootLoaderErrorNoLDRMem:	db 'Could not allocate LDR buffer', 0
fat12BootLoaderErrorNoMBR:	db 'Could not load SNOWDROP.MBR', 0
fat12BootLoaderErrorNoMBRMem:	db 'Could not allocate MBR buffer', 0

BOOT_SECTOR_SIZE equ NUM_BOOT_LOADER_SECTORS * BYTES_PER_SECTOR

fat12UnpartitionedBufferSeg:	dw 0
fat12UnpartitionedBufferOff:	dw 0
fat12MbrBufferSeg:	dw 0
fat12MbrBufferOff:	dw 0

	

; Formats the current disk with the specified FAT12 image.
;
; input:
;		DS:SI - pointer to FAT12 image
; output:
;		none
floppy_format_disk_entry_point:
	pusha
	push es
	
	; write FAT12 image to disk
	push ds
	pop es
	mov bx, si						; ES:BX := beginning of FAT12 image
	mov al, NUM_FAT12_IMAGE_SECTORS	; this many sectors
	mov di, 0						; start from logical sector 0
	call floppy_write_sectors
	
	pop es
	popa
	ret


; Reads a complete floppy FAT image in preparation for a disk format operation.
;
; input:
;		ES:DI - pointer to buffer where the FAT image will be read
;				(must be able to hold at least 32kb)
;				(must not cross any 64kb boundaries)
; output:
;		AL - 0 when successful
floppy_read_fat_image_entry_point:
	push ds
	push si
	push cx
	
	push cs
	pop ds
	
	mov si, fat12RawImageFileName	; DS:SI := file name
	call floppy_load_file_entrypoint ; AL := 0 when found, CX := file size

	pop cx
	pop si
	pop ds
	ret
	

; Loads the Snowdrop OS boot loader to memory during initialization.
; This is stored so it can be written as part of a OS transfer to a new disk.
;
floppy_load_bootloader:
	pusha
	push ds
	push es
	
	mov ax, BOOT_SECTOR_SIZE
	call dynmem_allocate					; DS:SI := buffer
	cmp ax, 0
	jne floppy_load_bootloader_got_LDR_mem

	; crash
	mov si, fat12BootLoaderErrorNoLDRMem
	jmp crash_and_print
	
floppy_load_bootloader_got_LDR_mem:
	; here, DS:SI = buffer
	mov word [cs:fat12UnpartitionedBufferSeg], ds
	mov word [cs:fat12UnpartitionedBufferOff], si

	push ds
	pop es
	push si
	pop di										; ES:DI := buffer
	
	push cs
	pop ds
	mov si, fat12UnpartitionedLoaderFileName	; DS:SI := file name
	call floppy_load_file_entrypoint
	cmp al, 0
	je floppy_load_bootloader_load_MBR

	; crash
	mov si, fat12BootLoaderErrorNoLDR
	jmp crash_and_print
floppy_load_bootloader_load_MBR:
	mov ax, BOOT_SECTOR_SIZE
	call dynmem_allocate					; DS:SI := buffer
	cmp ax, 0
	jne floppy_load_bootloader_got_MBR_mem
	
	; crash
	mov si, fat12BootLoaderErrorNoMBRMem
	jmp crash_and_print
floppy_load_bootloader_got_MBR_mem:
	; here, DS:SI = buffer
	mov word [cs:fat12MbrBufferSeg], ds
	mov word [cs:fat12MbrBufferOff], si

	push ds
	pop es
	push si
	pop di										; ES:DI := buffer
	
	push cs
	pop ds
	mov si, fat12MbrLoaderFileName	; DS:SI := file name
	call floppy_load_file_entrypoint
	cmp al, 0
	je floppy_load_bootloader_success
	
	; crash
	mov si, fat12BootLoaderErrorNoMBR
	jmp crash_and_print
floppy_load_bootloader_success:
	pop es
	pop ds
	popa
	ret


; Writes the Snowdrop OS boot loader from memory to the current disk.
;
; input:
;		AX - 0=unpartitioned, 1=MBR, other value NOOP
; output:
;		none
floppy_write_bootloader_entry_point:
	pusha
	push ds
	push es
	
	push cs
	pop ds
	
	cmp ax, 0
	je floppy_write_bootloader_entry_point_unpartitioned
	cmp ax, 1
	je floppy_write_bootloader_entry_point_MBR
	jmp floppy_write_bootloader_entry_point_done
	
floppy_write_bootloader_entry_point_unpartitioned:
	; write unpartitioned loader to disk
	push word [cs:fat12UnpartitionedBufferSeg]
	pop es
	mov bx, word [cs:fat12UnpartitionedBufferOff]	; we're writing from ES:BX
	jmp floppy_write_bootloader_entry_point_perform
	
floppy_write_bootloader_entry_point_MBR:
	; write MBR loader to disk
	push word [cs:fat12MbrBufferSeg]
	pop es
	mov bx, word [cs:fat12MbrBufferOff]	; we're writing from ES:BX
	jmp floppy_write_bootloader_entry_point_perform

floppy_write_bootloader_entry_point_perform:
	mov al, NUM_BOOT_LOADER_SECTORS		; this many sectors
	mov di, BOOT_LOADER_SECTOR_LOGICAL	; write to this logical sector
	call floppy_write_sectors
	
floppy_write_bootloader_entry_point_done:
	pop es
	pop ds
	popa
	ret
