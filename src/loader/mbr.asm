;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The Snowdrop OS MBR loader.
;
; It was introduced for BIOSes which expect a partitioned hard disk.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16
	org 7C00h

	jmp load_kernel
	times $$ + 3 - $ nop	; pad using nop up to and including the third byte

ROOT_DIR_ENTRIES			equ 224
pBlockSectorsPerTrack:		dw 18
pBlockHeads:				dw 2

; to make things cleaner, Snowdrop uses different segments
; for different purposes, rather than trying to compact everything
; into one segment
STACK_SEGMENT			equ 1000h
KERNEL_SEGMENT			equ 1000h
DISK_BUFFER_SEGMENT		equ 2000h

initialLoading:			db 13, 10, "Snowdrop OS MBR is loading:", 13, 10
						db ".dir", 13, 10, 0
floppyReadFat:			db ".FAT", 13, 10, 0
floppyReadCluster:		db ".clusters", 0

floppyKernelNotFound:	db "No kernel!", 0
floppyDriveError:		db "Disk err!", 0
floppyDriveReset:		db "rst!", 0

floppyReadClusterIncrement: db "*", 0

kernelFileName: 		db "SNOWDROPKRN" ; FAT12 uses spaces to pad file names 
										 ; to 11 characters (8 + 3), and 
										 ; dropping the extension dot
										 ; in this instance, the file is 
										 ; called SNOWDROP.KRN

kernelCurrentCluster: 	dw 0		; number of current cluster of kernel file
kernelDestinationPointer: dw 0		; pointer to memory area where kernel file
									; is being copied
bootDriveNumber: 		db 0
numSectorsToRead:		db 0	; used when reading single sectors
									
load_kernel:
	cld				; clearing the direction flag causes string (rep) 
					; operations to count upwards
	
	push cs
	pop ds							; point DS to "this" segment
	
	mov byte [bootDriveNumber], dl	; save number of the drive from 
									; which we're booting
	
	; set up the stack, which has its own segment in Snowdrop
	; starting at offset 0FFFFh
	cli						; disable interrupts while changing stack segment
	mov ax, STACK_SEGMENT
	mov ss, ax				; we disable interrupts because an interruption
							; between this instruction and the next two 
							; instructions could be disastrous
							; PUSHes first decrease SP, so our stack starts at
	xor sp, sp				; the highest possible point in the stack segment
	sti						; restore interrupts

	mov si, initialLoading
	call debug_print_string
	
	; Step 1: begin by loading the root directory to memory
load_root_directory:
	; | boot sector | first FAT | second FAT | root directory | data area |
	; where each FAT is 9 sectors
	mov di, 19	; therefore, the root directory starts at sector 19
				; DI := sector where we start reading
	
	; Snowdrop's data buffer is an entire segment
	; this segment is used by loader and kernel as working memory
	mov bx, DISK_BUFFER_SEGMENT
	mov es, bx					; root directory will be read to ES:BX
	mov fs, bx					; FS := disk buffer segment (needed for later)
	
	xor bx, bx		; we're reading into disk_buffer_segment:0000
	mov al, 14		; AL := read 14 sectors
					;	224 maximum root directory entries on floppy
					;    32 bytes per root directory entry
					;   512 bytes per sector
					; 224 * 32 / 512 = 14 sectors
	
	call read_sectors	; read the root directory to ES:BX
	
	jnc find_root_directory_entry	; if no read errors (carry flag=0), proceed
	
	call reset_floppy			; reset
	jmp load_root_directory		; retry
	
	; Step 2: now seek the beginning of the 32-byte root directory entry which
	; 		  represents Snowdrop's kernel file

find_root_directory_entry:
	xor di, di					; ES:DI points to beginning of the root directory
	mov bx, ROOT_DIR_ENTRIES	; this is the maximum number of 
								; root directory entries we'll check
find_root_directory_entry_check_file:
	push di
	
	mov si, kernelFileName	; DS:SI now points to the beginning of the string
							; containing the file name we're searching
							
	mov cx, 11				; file names are a fixed 11-byte field 
							; in each 32-byte root entry
	repe cmpsb				; compare 11 contiguous bytes
	jz find_root_directory_entry_found	; if zero flag is set, then 
										; the last comparison succeeded
										; (CX reached zero)
	dec bx
	jz find_root_directory_kernel_not_found
							; we're out of root directory entries?
	
	; try next root directory entry, 32 bytes from the beginning of this one
	pop di		; points to beginning of root directory entry being 
				; currently checked
	add di, 32	; move DI to the beginning of the next 
				; 32-byte root directory entry
	jmp find_root_directory_entry_check_file
	
find_root_directory_kernel_not_found:
					; we have an extra value on the stack, but we don't care
	mov si, floppyKernelNotFound
	call debug_print_string
	jmp halt_cpu
	
find_root_directory_entry_found:
	pop di				; DI := beginning of the kernel root directory entry
	
	mov ax, word [es:di+26]
	mov word [kernelCurrentCluster], ax	; extract first cluster of kernel
										; file from bytes 26-27 of the kernel
										; root directory entry	
	
; How root directory, FAT, and data area work together:
;
; [root directory]              [FAT]             [data area]
; [    entry     ]
;
;  bytes 26-27      --->   second cluster
; (first cluster)   --------------|-|------> actual file data in first cluster
;                                 |  \
;                                 |   -----> actual file data in second cluster
;                                 v
;                            third cluster

	; Step 3: read the FAT into memory
	
read_fat:
	mov si, floppyReadFat
	call debug_print_string
	
	mov di, 1			; first FAT starts on second logical sector
						; DI := sector to start reading from
	xor bx, bx
	mov al, 18			; we'll read all 12h (18) sectors of FAT
	call read_sectors	; read FAT into ES:BX
						; where ES points to the disk buffer segment
	
	jnc read_fat_success	; if there were no errors (carry flag=0), proceed
	
	call reset_floppy			; reset
	jmp read_fat				; retry
	
read_fat_success:	
	; FAT is now loaded at DISK_BUFFER_SEGMENT:0000
	; and we know the number of the first cluster
	
	push word KERNEL_SEGMENT	; this is where we're loading our kernel
	pop es						; ES := kernel segment
	
	mov ax, word [kernelCurrentCluster]	; AX := first cluster number
	
	; Step 4: read kernel file data cluster by cluster, into the kernel segment

	mov si, floppyReadCluster
	call debug_print_string
	
	; ASSUMPTION: AX contains number of cluster whose data will be read in
read_cluster_contents:
	add ax, 31			; offset to first data area cluster
						; note that cluster 2 is the first data area cluster
						; and we have:
						;	1 boot sector
						; 2*9 FAT sectors
						;  14 root directory sectors
						;= 33 sectors before data area
						; but since cluster 2 is the first data area cluster, 
						; we must subtract by 2, for a total offset of 31

read_cluster_contents_perform:						
	mov si, floppyReadClusterIncrement
	call debug_print_string
	
	push ax				; preserve logical sector, in case we need to retry
	
	mov di, ax			; DI := logical sector to read
	mov al, 1			; we'll read one sector (since each cluster is 
						; made up of only one sector on floppies)
	mov bx, [kernelDestinationPointer]
	call read_sectors

	jnc read_cluster_contents_success	; if no read errors (CF=0), proceed
	
	call reset_floppy					; reset
	pop ax								; restore logical sector
	jmp read_cluster_contents_perform	; retry

read_cluster_contents_success:
	pop ax				; we no longer need the logical sector
	
	; by now we have read the first cluster and must find the next one
	; FAT contains a list of all the clusters of the file
	; each cluster takes up 3 nibbles (for a total of 12 bits).
	; cluster 0: 0x012
	; cluster 1: 0x345
	; cluster 2: 0x678
	; cluster 3: 0x9AB
	; and so on...
	;
	; however, IBM PC architectures are low endian, meaning that if we
	; read a word from memory into a register, when the memory contains 
	; 0x34 0x12, for example, then the register will contain 0x1234
	;
	; due to this our example clusters are laid out like so in memory:
	; 0x12 0x50 0x34 0x78 0xB6 0x9A and so on...
	; 
calculate_next_cluster:
	mov ax, [kernelCurrentCluster]
	mov bx, 3
	mul bx			; DX:AX := 3 * cluster number
					; Note: since the floppy has only 2880 sectors,
					; this multiplication will set DX to 0
					
	dec bx			; BX := 2 (using mov would cost 2 bytes more)
	div bx			; AX := (3 * cluster number) / 2
					; DX := (3 * cluster number) % 2
	
	; [EXAMPLE BEGINS]
	; let's look at an example, using the values from above:
	; assume current cluster contained the value 3 (number of the next cluster)
	; we will now find that cluster in the FAT
	;
	; right now we have:
	; AX = (3 * cluster number) / 2 = 9 / 2 = 4
	; DX = (3 * cluster number) % 2 = 9 % 2 = 1
	
	mov si, ax					; here, FS = disk buffer segment
	mov ax, word [fs:si]		; AX := word in FAT for the 12-bit cluster
	
	; [EXAMPLE CONTINUES]
	; continuing our example, memory looks like this: 
	;  0x12    0x50    0x34    0x78    0xB6    0x9A
	; byte 0  byte 1  byte 2  byte 3  byte 4  byte 5
	;
	; we've just loaded bytes 4 and 5 (since SI = AX = 4), that is 0xB6 0x9A
	; these were loaded into AX, which now contains 0x9AB6 (low endianness)
	; also, DX is 1, since it hasn't changed from above
	
	dec dx				; at this point, DX is either 0 or 1, from receiving
						; the remainder of a division by 2, a few lines above
	jnz cluster_is_even	; if DX is now non-zero, then it used to be zero,
						; meaning that the cluster number is even
						
						; If [cluster] is even, drop last 4 bits of word
						; with next cluster; if odd, drop first 4 bits
	
	; [EXAMPLE CONTINUES]
	; in our example, we continue here, since DX is odd

cluster_is_odd:
	shr ax, 4	; for odd entries, we shift right a nibble
	
	; [EXAMPLE ENDS]
	; in our example, AX goes from 0x9AB6 to 0x09AB after the shift
	; which is exactly what cluster 3 contains (see beginning of example)
	
	jmp calculate_next_cluster_store
cluster_is_even:
	and ax, 0FFFh	; for even entries, we discard highest nibble

	; AX now contains the value contained in the current cluster,
	; which is the number of the next cluster of the file
calculate_next_cluster_store:
	mov word [kernelCurrentCluster], ax

	cmp ax, 0FF8h					; 0x0FF8 to 0x0FFF means "last cluster"
	jae transfer_control_to_kernel	; if we encounter it, we're done, and can 
									; transfer control to the kernel

	add word [kernelDestinationPointer], 512 ; next cluster will be copied 
											 ; starting 512 bytes farther out
	
	jmp read_cluster_contents		; AX = kernelCurrentCluster at this point
	
	; Step 5: execute kernel
	
transfer_control_to_kernel:
	mov al, byte [bootDriveNumber]	; Snowdrop uses no other drives than the
									; floppy disk off of which it is booted,
									; so the kernel must be told what the drive
									; number of the "main" drive is
	jmp KERNEL_SEGMENT:0000			; transfer control to kernel
									; we will not return to this boot 
									; loader again


; Convert logical sector number into physical specifications 
; (also called LBA to CHS translation, because it converts a logical block
; address to a cylinder-head-sector triplet)
; These values are returned in the proper registers, in preparation
; for an interrupt 13h call
;
; logical sector number = (C * Nheads + H) * Nsectors + (S - 1)
; 	where C = cylinder, H = head, and S = sector
;
; input:
;			logical sector number in AX
; output:
;			various registers modified in preparation to an interrupt 13h call
;				and containing values for C, H, S, and drive number
;
; PRESERVES NO REGISTERS
floppy_logical_to_physical:
	push ax				; logical sector

	xor dx, dx
	div word [pBlockSectorsPerTrack]	
			; AX := logical sector number / sectors per track
			;    which equates to logical number of track
			; DX := logical sector number % sectors per track
			;    which equates to physical sector number		

	inc dl			; physical sector numbering is 1-based
	mov cl, dl		; physical sector number belongs in CL for 
					; interrupt 13h calls
	pop ax				; AX := logical sector
	
	mov dx, 0
	div word [pBlockSectorsPerTrack] 	
			; AX := logical sector number / sectors per track
			;    which equates to logical number of track
									
	mov dx, 0
	div word [pBlockHeads]			; AX := logical number of track / heads
								; DX := logical number of track % heads
	
	mov dh, dl			; physical head number belongs in DH for 
						; interrupt 13h calls
	mov ch, al			; physical track (cylinder) number belongs 
						; in CH for interrupt 13h calls
	mov dl, byte [bootDriveNumber]	; device number belongs in DL for 
									; interrupt 13h calls
	ret

	
; Reads multiple sectors from disk, one at a time.
; NOTE: Preserves no registers
;
; input:
;			AL - count of sectors to read, must be AT LEAST 1
;			DI - first logical sector
;			ES:BX - pointer to buffer
; output:
;			CARRY - set when there was an error, clear otherwise
read_sectors:
	mov byte [cs:numSectorsToRead], al			; how many we have left
read_sectors_loop:
	pusha
	push es
	
	mov ax, di									; AX := logical sector
	call floppy_logical_to_physical				; LBA to CHS translation
	mov ah, 2									; function 2: read sectors
	mov al, 1									; we're reading one at a time
	
	; ASSUMPTION: we're reading at least one sector
	int 13h										; read single sector
	pop es
	popa
	jc read_sectors_done						; error
	add bx, 512									; advance pointer
	inc di										; advance sector
	dec byte [cs:numSectorsToRead]				; one less sector to read
	jnz read_sectors_loop
	clc											; "no error"
read_sectors_done:
	ret
	

; resets the floppy drive preceding a read retry
;
; input:
;			none
; output:
;			none
reset_floppy:
	pusha
	mov cx, 10					; we will retry the reset itself 10 times
reset_floppy_loop:
	mov si, floppyDriveReset
	call debug_print_string
	
	mov dl, byte [bootDriveNumber]
	xor ah, ah						; function 0 - reset drive
									; CARRY := 0
	int 13h							; reset drive
	jnc reset_floppy_success		; if carry flag is not set, we succeeded
	loop reset_floppy_loop

	mov si, floppyDriveError
	call debug_print_string
halt_cpu:
	jmp $
reset_floppy_success:
	popa
	ret


; input:
;		DS:SI pointer to string
; output:
;		none
debug_print_string:
	pusha
	mov ah, 0Eh
	mov bx, 0007h	; gray colour, black background
debug_print_string_loop:
	lodsb
	cmp al, 0		; strings are 0-terminated
	je debug_print_string_done
	int 10h
	jmp debug_print_string_loop
debug_print_string_done:
	popa
	ret

	times 440 - ($ - $$)  db 0		; pad to 440 bytes
	
;------------------------------------------------------------------------------
; Reserved bytes after boot loader
;------------------------------------------------------------------------------
	dw 1337h, 1337h		; disk unique identifier
	dw 0				; magic word

;------------------------------------------------------------------------------
; Partition entries
;------------------------------------------------------------------------------

	; partition 0
	db 80h						; attributes (bootable)
		
								; partition first sector
	db 0						;     CHS: head
	db 1						;     CHS: high cylinder bits and sector bits
	db 0						;     CHS: cylinder
	
	db 1						; partition type: FAT12 primary
	
								; partition last sector
	db 1						;     CHS: head
	db 18						;     CHS: high cylinder bits and sector bits
	db 79						;     CHS: cylinder
	
	dd 0						; first LBA sector
	dd 2880						; number of sectors in partition
	
	; partition 1
	db 7Fh						; attributes (invalid)
	times 15 db 0				; trash for the remainder of partition entry
	
	; partition 2
	db 7Fh						; attributes (invalid)
	times 15 db 0				; trash for the remainder of partition entry
	
	; partition 3
	db 7Fh						; attributes (invalid)
	times 15 db 0				; trash for the remainder of partition entry
 
;------------------------------------------------------------------------------
; Magic word at the end
;------------------------------------------------------------------------------	
	dw 0AA55h		; BIOS expects this signature at the end of the boot sector
