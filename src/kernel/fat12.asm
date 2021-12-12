;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the high-level routines of Snowdrop's FAT12 file system driver,
; that is, those that are exposed to user programs as system services.
; These routines are specific to 1.44Mb floppies.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FAT12_FDD0_NUMBER			equ 0
FAT12_FDD1_NUMBER			equ 1
FAT12_HDD0_NUMBER			equ 80h
FAT12_HDD1_NUMBER			equ 81h

; specific to 1.44Mb floppy disks
FLOPPY_ROOT_ENTRIES			equ 224
FLOPPY_SECTORS_PER_TRACK	equ 18
FLOPPY_HEADS				equ 2
FLOPPY_CYLINDERS			equ 80

BYTES_PER_SECTOR equ 512
ROOT_ENTRIES_COUNT equ 224			; tightly coupled to a 1.44Mb floppy disk
BYTES_PER_ROOT_ENTRY equ 32
ROOT_DIRECTORY_NUM_SECTORS equ ( ROOT_ENTRIES_COUNT * BYTES_PER_ROOT_ENTRY ) / BYTES_PER_SECTOR
					;   224 maximum root directory entries on floppy
					;    32 bytes per root directory entry
					;   512 bytes per sector
					; 224 * 32 / 512 = 14 sectors

; | boot sector | first FAT | second FAT | root directory | data area |
;     0 - boot sector (1 sector)
;   1-9 - first FAT (9 sectors)
; 10-18 - second FAT (9 sectors)
FIRST_ROOT_DIRECTORY_SECTOR equ 19

FAT_NUM_SECTORS equ 18
FIRST_FAT_SECTOR equ 1	; first FAT starts on second logical sector

FIRST_DATA_CLUSTER_NUMBER equ 2		; data area clusters 0 and 1 are reserved
LAST_DATA_CLUSTER_NUMBER equ 2848	; last allocatable data area cluster

driveNumber: db 99		; the drive Snowdrop will use for all disk operations 
						; this initial value will be overwritten at startup
						

fat12SetCurrentDiskTarget:		db 99	; used while changing current disk
						
diskBufferSegment: 		dw 0 ; the kernel uses this segment for disk operations

diskRootEntries:		dw FLOPPY_ROOT_ENTRIES

diskSectorsPerTrack:	dw FLOPPY_SECTORS_PER_TRACK
diskHeads:				dw FLOPPY_HEADS
diskCylinders:			dw FLOPPY_CYLINDERS

floppyInitializationMessage1:	db '.FAT12 file system driver (active disk: ', 0
floppyInitializationMessage2:	db 'h)', 0

floppyDriveErrorMessage:	db 'Disk or disk drive error', 0
floppyRootDirFullMessage:	db 'Floppy root directory full', 0
floppyDataAreaFullMessage:	db 'Floppy data area full', 0

floppyFileNameBufferSegment: dw 0
floppyFileNameBufferOffset: dw 0

floppyNumSectorsToRead:		db 0	; used by single sector reads

fileName: 		db "00000000000"	; FAT12 uses spaces to pad file names 
									; to 11 characters (8 + 3), and 
									; dropping the extension dot
									; we use this buffer to simplify some of
									; the loading code

fileDataDestinationSegment:		  dw 0 ; we're loading the file to this segment
									   ; (the offset of the destination is kept
								       ; in floppyFileDataDestinationPointer 
									   ; below)
floppyFileCurrentCluster: 		  dw 0 ; number of current cluster of file
floppyFileDataDestinationPointer: dw 0 ; pointer to memory area where file
									   ; is being loaded
floppyFileDataSourcePointer:	  dw 0 ; pointer to memory from which we're
									   ; writing to disk
fileWriteFirstClusterNumber:	dw 0 ; stores the first written cluster during
									 ; a file write operation
fileReadFileSize:				dw 0 ; stores the file size during a file read
									 ; operation

fat12HddCount:			db 0
fat12FddCount:			db 0

floppyInitializationMessageDisks1:	db ' (disks: ', 0
floppyInitializationMessageDisks2:	db ')', 0
floppyInitializationMessageDisksH:	db 'h', 0
floppyInitializationMessageDisksComma:	db ', ', 0


; Initializes floppy operations
;
; input
;		AX - disk buffer segment we use for all disk operations
;		BL - disk drive number of drive we use for all disk operations
floppy_initialize:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, floppyInitializationMessage1
	call debug_print_string
	
	mov word [diskBufferSegment], ax
	mov byte [driveNumber], bl
	call floppy_load_bootloader
	
	; print drive number to screen
	mov al, byte [driveNumber]
	call debug_print_byte
	mov si, floppyInitializationMessage2
	call debug_print_string

	call fat12_find_disks
		
	mov si, floppyInitializationMessageDisks1
	call debug_print_string
	
	; print disk info
	call fat12_get_disk_info

	cmp ah, 0
	je floppy_initialize_list_drives_done
	mov al, bl										; print first drive
	call debug_print_byte
	mov si, floppyInitializationMessageDisksH
	call debug_print_string
	
	cmp ah, 1
	je floppy_initialize_list_drives_done
	mov si, floppyInitializationMessageDisksComma
	call debug_print_string
	mov al, bh										; print second drive
	call debug_print_byte
	mov si, floppyInitializationMessageDisksH
	call debug_print_string
	
	cmp ah, 2
	je floppy_initialize_list_drives_done
	mov si, floppyInitializationMessageDisksComma
	call debug_print_string
	mov al, cl										; print third drive
	call debug_print_byte
	mov si, floppyInitializationMessageDisksH
	call debug_print_string
	
	cmp ah, 3
	je floppy_initialize_list_drives_done
	mov si, floppyInitializationMessageDisksComma
	call debug_print_string
	mov al, ch										; print fourth drive
	call debug_print_byte
	mov si, floppyInitializationMessageDisksH
	call debug_print_string
	
floppy_initialize_list_drives_done:
	mov si, floppyInitializationMessageDisks2
	call debug_println_string

	pop ds
	popa
	ret

	
; Stores disk information
;
; input
;		none
fat12_find_disks:
	pusha
	push ds
	
	; store number of disks
	mov ax, 40h
	mov ds, ax							; BIOS data area starts at 0040:0000h
	mov al, byte [ds:75h]				; AL := number of hard disks
	mov byte [cs:fat12HddCount], al
	mov bl, al
	
	mov al, byte [ds:10h]				; AL := equipment descriptor byte 0
	shr al, 7							; bit 0 := floppy count - 1
	inc al								; AL := floppy count
	mov byte [cs:fat12FddCount], al

	pop ds
	popa
	ret


; Sets current disk
;
; input
;		AL - ID of disk to be made current
; output
;		AX - 0 when operation succeeded
;			 1 when operation failed because the specified disk does not exist
fat12_set_current_disk:
	pusha
	mov byte [cs:fat12SetCurrentDiskTarget], al

	call fat12_get_disk_info
fat12_set_current_disk_6:	
	cmp ah, 6
	jb fat12_set_current_disk_5
	cmp dh, byte [cs:fat12SetCurrentDiskTarget]
	jne fat12_set_current_disk_5
	mov byte [cs:driveNumber], dh						; set drive
	jmp fat12_set_current_disk_success
	
fat12_set_current_disk_5:
	cmp ah, 5
	jb fat12_set_current_disk_4
	cmp dl, byte [cs:fat12SetCurrentDiskTarget]
	jne fat12_set_current_disk_4
	mov byte [cs:driveNumber], dl						; set drive
	jmp fat12_set_current_disk_success
	
fat12_set_current_disk_4:
	cmp ah, 4
	jb fat12_set_current_disk_3
	cmp ch, byte [cs:fat12SetCurrentDiskTarget]
	jne fat12_set_current_disk_3
	mov byte [cs:driveNumber], ch						; set drive
	jmp fat12_set_current_disk_success
	
fat12_set_current_disk_3:
	cmp ah, 3
	jb fat12_set_current_disk_2
	cmp cl, byte [cs:fat12SetCurrentDiskTarget]
	jne fat12_set_current_disk_2
	mov byte [cs:driveNumber], cl						; set drive
	jmp fat12_set_current_disk_success
	
fat12_set_current_disk_2:
	cmp ah, 2
	jb fat12_set_current_disk_1
	cmp bh, byte [cs:fat12SetCurrentDiskTarget]
	jne fat12_set_current_disk_1
	mov byte [cs:driveNumber], bh						; set drive
	jmp fat12_set_current_disk_success
	
fat12_set_current_disk_1:
	cmp ah, 1
	jb fat12_set_current_disk_no_such_disk
	cmp bl, byte [cs:fat12SetCurrentDiskTarget]
	jne fat12_set_current_disk_no_such_disk
	mov byte [cs:driveNumber], bl						; set drive
	jmp fat12_set_current_disk_success
	
fat12_set_current_disk_no_such_disk:
	popa
	mov ax, 1
	jmp fat12_set_current_disk_done
fat12_set_current_disk_success:
	popa
	mov ax, 0
fat12_set_current_disk_done:
	ret
	
	
; Returns disk information
;
; input
;		none
; output
;		AL - ID of current disk
;		AH - number of drives
;		BL - ID of first disk
;		BH - ID of second disk, if one exists
;		CL - ID of third disk, if one exists
;		CH - ID of fourth disk, if one exists
;		DL - ID of fifth disk, if one exists
;		DH - ID of sixth disk, if one exists
fat12_get_disk_info:
	mov ah, 1									; assume one fdd
	mov bl, FAT12_FDD0_NUMBER					; BIOS essentially assumes
												; there's at least one fdd
	cmp byte [cs:fat12FddCount], 2
	jb fat12_get_disk_info_1fdd_check_hdd
	mov bh, FAT12_FDD1_NUMBER
	inc ah										; two fdds
fat12_get_disk_info_2fdds_check_hdd:
	; we filled BL and BH with the two fdds
	cmp byte [cs:fat12HddCount], 0
	je fat12_get_disk_info_done
	; there's at least one hdd
	mov cl, FAT12_HDD0_NUMBER
	inc ah										; two fdds, one hdd
	cmp byte [cs:fat12HddCount], 2
	jb fat12_get_disk_info_done
	; we have a second hdd
	mov ch, FAT12_HDD1_NUMBER
	inc ah										; two fdds, two hdds
	jmp fat12_get_disk_info_done
	
fat12_get_disk_info_1fdd_check_hdd:
	; we filled BL with the only fdd
	cmp byte [cs:fat12HddCount], 0
	je fat12_get_disk_info_done
	; there's at least one hdd
	mov bh, FAT12_HDD0_NUMBER
	inc ah										; one fdds, one hdd
	cmp byte [cs:fat12HddCount], 2
	jb fat12_get_disk_info_done
	; we have a second hdd
	mov cl, FAT12_HDD1_NUMBER
	inc ah										; one fdds, two hdds
	jmp fat12_get_disk_info_done

fat12_get_disk_info_done:
	mov al, byte [cs:driveNumber]				; AL := current disk
	ret
	
	
; The entry point into the "load file from floppy" workflow
; The destination buffer cannot cross 64k boundaries.
;
; input:
;			DS:SI pointer to 11-byte buffer containing 
;				  file name in FAT12 format
;			ES:DI pointer to where file data will be loaded
;				  (must not cross 64kb boundary)
; output:
;			AL - status (0=success, 1=not found)
;			CX - file size in bytes
floppy_load_file_entrypoint:
	pushf
	push ds
	push es
	push di
	push bx
	push dx
	
	push es					; save user parameter
	push di					; save user parameter
	
	push cs
	pop es					; ES := this segment
	mov di, fileName		; ES:DI now points to our file name buffer
	mov cx, 11				; we'll copy 11 bytes (8+3 file name)
							; DS:SI already points to the file name passed in
	cld
	rep movsb				; perform copy
	
	pop di					; restore user parameter
	pop es					; restore user parameter
	
	; done storing the file name
	
	push cs
	pop ds							; point DS to "this" segment
	
	mov word [fileDataDestinationSegment], es
	mov word [floppyFileDataDestinationPointer], di
	
	; Step 1: begin by loading the root directory to memory
	push word [diskBufferSegment]
	pop es
	mov di, 0	; load root directory at ES:DI, which is diskBufferSegment:0000
	call floppy_load_root_directory_entrypoint

	; Step 2: now seek the beginning of the 32-byte root directory entry which
	; 		  represents the file we need to load
	mov si, fileName	; DS:SI now points to start of file name
	mov di, 0			; ES:DI now points to start of root directory
	call floppy_find_file ; DI := pointer to start of root directory entry
						  ;       of our file
	cmp ax, 0					; did we actually find the file?
	jne floppy_load_file_not_found	; no
	; we did find the file, so continue on
	
	; here, ES:DI points to the start of the root directory entry of our file
	mov ax, word [es:di+28]		; AX := lowest two bytes of file size (4 bytes)
	mov word [fileReadFileSize], ax	; store file size so we can return it
	mov ax, word [es:di+26]		; AX := first cluster of file
								; (take it from bytes 26-27 of the entry)
	; check if the file size is zero, meaning that it uses no clusters
	cmp ax, 0				; zero-sized files have a zero as the first cluster
							; in the root directory entry
	je floppy_load_file_success	; loading zero-sized files is a NOOP
	
	; file has non-zero size, so we must actually perform the load
	mov word [floppyFileCurrentCluster], ax	; make first cluster current

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
	mov bx, 0				; we'll load the FAT to diskBufferSegment:0000
	call floppy_load_fat	; (ES = diskBufferSegment, from above)

	; FAT is now loaded and we know the number of the first cluster	
	mov ax, word [floppyFileCurrentCluster]	; AX := first cluster number
	
	; Step 4: read file data cluster by cluster, into the app segment
read_cluster_contents:
	; here, AX contains number of the cluster whose data will be read in
	push word [fileDataDestinationSegment]
	pop es							; ES := file data destination segment
	
	mov di, ax						; DI := current cluster number
	mov al, 1						; we're reading a single sector
	mov bx, [floppyFileDataDestinationPointer]	; we will read to ES:BX
	call floppy_read_data_sectors

	; now calculate the next cluster
	push word [diskBufferSegment]
	pop es									; ES := disk buffer segment
	mov di, 0								; ES:DI now points to start of FAT
	mov ax, word [floppyFileCurrentCluster]	; AX := current cluster number
	call floppy_get_fat_cluster_value			; AX := next cluster number
	mov word [floppyFileCurrentCluster], ax	; store it
	
	cmp ax, 0FF8h				 ; 0x0FF8 to 0x0FFF means "last cluster"
	jae floppy_load_file_success ; if we encounter it, we're done

	add word [floppyFileDataDestinationPointer], BYTES_PER_SECTOR ; next sector
	jmp read_cluster_contents	; AX = floppyFileCurrentCluster at this point

floppy_load_file_not_found:
	mov al, 1					; 1 means "not found"
	jmp floppy_load_file_done
floppy_load_file_success:
	mov al, 0					; 0 means "success"
	push ds
	push cs
	pop ds
	mov cx, word [fileReadFileSize]
	pop ds
floppy_load_file_done:
	pop dx
	pop bx
	pop di
	pop es
	pop ds
	popf
	ret
	
	
; The entry point into the "load root directory" workflow
; The destination buffer cannot cross 64k boundaries.
;
; input:
;			ES:DI pointer to where the root directory will be loaded
;				  (must not cross 64kb boundary)
; output:
;			number of 32-byte FAT12 root directory entries in AX
floppy_load_root_directory_entrypoint:
	push ds
	pusha

	push cs
	pop ds		; point DS at "this" segment, because 
				; floppy_logical_to_physical reads variables
floppy_load_root_directory_entrypoint_try:
	mov bx, di		; root directory will be read to ES:BX
	mov di, FIRST_ROOT_DIRECTORY_SECTOR
	mov al, ROOT_DIRECTORY_NUM_SECTORS	; AL := read 14 sectors
	call floppy_read_sectors			; CARRY := set when an error occurred

	; if no read errors (carry flag=0), we succeeded
	jnc floppy_load_root_directory_entrypoint_success
	
	call reset_floppy								; reset
	jmp floppy_load_root_directory_entrypoint_try	; retry

floppy_load_root_directory_entrypoint_success:	
	popa
	mov ax, word [diskRootEntries]	; return root directory entry count in AX
									; while we still have "this" segment in DS
	pop ds
	ret


; The entry point into the "delete file" workflow
;
; input:
;		DS:SI - pointer to 11-byte buffer containing file name in FAT12 format
; output:
;		none (fails silently)
floppy_delete_file_entry_point:
	pusha
	push es

	push ds			; save user input
	push cs
	pop ds			; DS := CS to access some variables below
	push word [diskBufferSegment]
	pop es			; ES := disk buffer
	pop ds			; restore user input
	
	; load the root directory from disk
	mov di, 0		; load root directory at diskBufferSegment:0000
	call floppy_load_root_directory_entrypoint	; load it!
	
	; find the root directory entry holding the file we're looking for
	mov di, 0		; ES:DI now points to start of root directory
	call floppy_find_file ; DI := pointer to start of root directory entry
						  ;       of our file
	cmp ax, 0					; did we actually find the file?
	jne floppy_delete_file_done	; no
	
	; ES:DI now points to the root directory entry for our file
	; first, mark the root directory entry as "deleted"
	mov byte [es:di], 0E5h	; mark root directory entry as free (deleted)
	
	mov bx, 0		; ES:BX now points to beginning of root directory
	call floppy_write_root_directory	; write root directory to disk
	
	; now we mark all clusters of the file as "free"
	mov ax, word [es:di+26]		; AX := first cluster of our file, read 
								; from root directory

	; check if the file size is zero, meaning that it uses no clusters
	cmp ax, 0				; zero-sized files have a zero as the first cluster
							; in the root directory entry
	je floppy_delete_file_done	; if we encounter it, we're done

	; load FAT
	mov bx, 0				; we'll load the FAT to diskBufferSegment:0000
	call floppy_load_fat	; (ES = diskBufferSegment, from above)
	
	; here, AX = first cluster number
	
floppy_delete_file_zero_out_cluster:
	; here, AX = current cluster number
	
	; check to see if AX actually contains a non-cluster number, but
	; rather a "last cluster" magic value
	cmp ax, 0FF8h				; 0x0FF8 to 0x0FFF means "last cluster", as in
								; "there is no further cluster"
	jae floppy_delete_file_write_fat ; if we encounter it, we're done
	
	; get next cluster number
	mov bx, ax						; BX := current cluster number
	mov di, 0
	call floppy_get_fat_cluster_value	; AX := next cluster number
	push ax							; save next cluster number
	
	; mark current cluster as "unused"
	mov ax, bx						; AX := current cluster number
	mov cx, 0						; we're writing the magic value 
									; meaning "unused"
	mov di, 0						; FAT is at ES:DI
	call floppy_write_fat_cluster	; mark current cluster as "unused"
	
	; iterate back up with next cluster as current cluster
	pop ax							; AX := next cluster number
	jmp floppy_delete_file_zero_out_cluster	; zero out next cluster

floppy_delete_file_write_fat:
	; write FAT from ES:0000
	mov bx, 0					; ES:BX points to the start of FAT
	call floppy_write_fat		; write modified FAT back to disk
	
floppy_delete_file_done:
	pop es
	popa
	ret


; Writes a file with the specified name to the disk.
; If a file with the same name is present, it will be overwritten.
; The input file contents buffer "rounded" up to the nearest 512 bytes cannot
; cross 64kb boundaries). The reason for the "round-up" is due to FAT12's
; inherent "cluster slack".
;
; input:
;		DS:SI - pointer to 11-byte buffer containing file name in FAT12 format
;		ES:DI - pointer to file contents buffer (cannot cross 64kb boundaries)
;		   CX - size of file content in bytes
; output:
;			AX - status, as such:
;				0 = success
;				1 = failure: maximum number of files reached
;				2 = failure: disk full
;
; I've written out the pseudo-code, since there's quite a bit
; happening here. I've opted for consistency of approach over performance:
;
; 10. delete any existing file with the same name (failing silently if 
;   the file does not already exist)
; 13. load root directory
; 15. if entries available = 0, then fail
; 30. if file size = 0 then set "FIRST_CLUSTER" = 0000 and go to 110
;		(skipping any FAT modifications)
; 40. load FAT
; 45. calculate number of clusters needed
; 50. if clusters available < clusters needed, then fail
; 52. get free cluster number (guaranteed to exist)
; 54. save as both "FIRST_CLUSTER" and as "previous cluster"
; 56. write cluster data to data area on disk
; 60. for each cluster needed:
;		64. write a dummy value as the value of "previous cluster" in FAT,
;			so that the "previous cluster" is not counted as free
;		70. get free cluster number (guaranteed to exist)
;		75. write it as the data of the "previous cluster" in FAT, overwriting
;			the dummy value from step 64
;		80. write cluster data to data area on disk
; 95. write data of last cluster as 0FF8h, marking it as last cluster in file
;100. write FAT to disk
;110. load root directory
;120. get free root directory entry (guaranteed to exist)
;130. write file name to root directory entry
;135. write attributes
;140. write FIRST_CLUSTER to root directory entry
;150. write root directory to disk
;160. return success
;
floppy_write_file_entry_point:
	; step 10
	pusha								; (PUSHA_10)
	call floppy_delete_file_entry_point	; delete file if it already exists
	
	; steps 13-15
	call floppy_get_free_root_directory_entries_entrypoint ; CX:= free entries
	cmp cx, 0							; see if there's space in directory
	ja floppy_write_file_root_directory_space_is_available
	; fail
	popa								; (POPA_10)
	mov ax, 1							; "max files reached" error
	ret
floppy_write_file_root_directory_space_is_available:
	; step 30
	popa								; (POPA_10)
	cmp cx, 0							; is the file size zero?
	ja floppy_write_file_nonzero_size	; no
	push ds								; yes, the file is zero-sized
	push cs
	pop ds
	mov word [fileWriteFirstClusterNumber], 0	; save FIRST_CLUSTER
	pop ds
	jmp floppy_write_file_after_fat_operations	; skip over FAT operations
floppy_write_file_nonzero_size:
	; STACK AND USER INPUT ARE CLEAN HERE
	; step 40
	call floppy_load_fat_to_disk_buffer
	; step 45
	; here, CX = file size in bytes
	pusha									; (PUSHA_45)
	call floppy_count_necessary_clusters	; AX := number of clusters needed
	; step 50
	call floppy_count_free_data_clusters_from_disk_buffer ; CX := number of
														  ; free clusters
	cmp cx, ax								; do we have enough clusters?
	jae floppy_write_file_enough_clusters_available	; yes
	popa											; no (POPA_45)
	mov ax, 2										; "disk full" error
	ret
floppy_write_file_enough_clusters_available:
	popa									; (POPA_45)
	; STACK AND USER INPUT ARE CLEAN HERE
	; file has at least one cluster
	; step 52
	pusha									; (PUSHA_52)
	call floppy_get_free_data_cluster_from_disk_buffer	; AX := first cluster
	; step 54
	push ds
	push cs
	pop ds
	mov word [fileWriteFirstClusterNumber], ax		; save as FIRST_CLUSTER
	pop ds
	; step 56
	push ax							; save previous cluster
	
	mov bx, di						; we're writing from ES:BX
	mov di, ax						; DI := first cluster number
	mov al, 1						; we're writing one cluster
	call floppy_write_data_sectors	; write first cluster to disk (data area)
	
	; here, CX = file size in bytes, as was input
	call floppy_count_necessary_clusters	; AX := number of clusters needed
	dec ax							; we've written one already, so we need
									; one less
	; steps 60 to 95
	mov cx, ax						; CX := number of clusters still needed
	pop ax							; AX := previous cluster
	add bx, BYTES_PER_SECTOR		; move source data pointer forward
									; one cluster
									; (source data pointer is now in ES:BX)

	call floppy_write_subsequent_clusters
	popa									; (POPA_52)
	; STACK AND USER INPUT ARE CLEAN HERE
	; step 100
	call floppy_write_fat_to_disk_from_disk_buffer
floppy_write_file_after_fat_operations:
	; STACK AND USER INPUT ARE CLEAN HERE
	; step 110
	call floppy_load_root_directory_to_disk_buffer
	; steps 120 to 140
	call floppy_populate_root_directory_entry_in_disk_buffer
	; step 150
	call floppy_write_root_directory_from_disk_buffer
	; STACK AND USER INPUT ARE CLEAN HERE
	mov ax, 0						; return success
	ret


;------------------------------------------------------------------------------
; The routines below are tightly coupled to the workflows above
;------------------------------------------------------------------------------

	
; Called during a file write operation, this procedure will write all clusters
; after the first to disk.
; Requires the FAT to have been loaded in the disk buffer
;
; input:
;		ES:BX - pointer to source data (must not cross 64kb boundary)
;		   AX - previously written cluster number
;		   CX - number of clusters to write
; output:
;		none
floppy_write_subsequent_clusters:
	pusha
floppy_write_subsequent_clusters_next:
	cmp cx, 0								; are we done?
	je floppy_write_subsequent_clusters_write_terminator ; yes, so now write 
														 ; cluster chain
														 ; terminator

	mov dx, ax								; DX := previous cluster number
	; step 64
	mov ax, 0137h		; we write this temporary magic value into previous
						; cluster, so that it doesn't get returned as a free
	call floppy_write_fat_cluster_from_disk_buffer	; cluster in the call 
													; immediately following 
													; this one
	; step 70
	call floppy_get_free_data_cluster_from_disk_buffer	; AX := next cluster
	; step 75
	call floppy_write_fat_cluster_from_disk_buffer	; write AX in previous 
													; (in DX) cluster's value
													; overwriting 0137h above

	; step 80
	mov di, ax								; DI := next cluster number
	mov al, 1								; write one cluster only
											; ES:BX already points to source
											; file contents data
	call floppy_write_data_sectors			; write cluster to disk (data area)
	
	dec cx									; we have one less cluster to write
	add bx, BYTES_PER_SECTOR				; move source data pointer forward
	mov ax, di								; AX := next cluster (which becomes
											; "previous" at the beginning of
											; the loop

	jmp floppy_write_subsequent_clusters_next	; loop again
floppy_write_subsequent_clusters_write_terminator:
	; step 95
	mov dx, ax								; DX := last cluster written
	mov ax, 0FF8h							; magic value: "cluster chain
											; terminator"
	call floppy_write_fat_cluster_from_disk_buffer	; write terminator

	popa
	ret

	
; Allocates and populates a root directory entry with the file information 
; for a file that was just written to the data area.
; This step essentially "registers" a cluster chain with the root directory.
; Requires the root directory to have been loaded in the disk buffer.
;
; input:
;		DS:SI - pointer to 11-byte buffer containing file name in FAT12 format
;		ES:DI - pointer to where the root directory is loaded
;		   CX - size of file content in bytes
; output:
;		none
floppy_populate_root_directory_entry_in_disk_buffer:
	pushf
	pusha
	push ds
	push es

	; step 120
	push ds							; save user input
	push cs
	pop ds							; DS := CS
	push word [diskBufferSegment]
	pop es							; ES := disk buffer segment
	pop ds							; restore user input
	mov di, 0						; ES:DI now points to start of directory
	call floppy_get_free_directory_entry ; ES:DI now points to start of entry
	push cx							; save file size
	; step 130
	mov cx, 11						; FAT12 file names are 11 characters long
	cld
	rep movsb						; copy 11 bytes from DS:SI to ES:DI,
									; STORING THE FILE NAME (bytes 0-10)
	pop cx							; restore file size
	sub di, 11						; move DI to beginning of entry
	; step 135
	mov byte [es:di+11], 0			; STORE FILE ATTRIBUTES (byte 11)
	; step 140
	
	mov ax, 1001100000000000b		; 10011 000000 00000
									;    19     00    00 (time stamp)
	mov word [es:di+14], ax			; STORE CREATION TIME (bytes 14-15)
	mov word [es:di+22], ax			; STORE LAST WRITE TIME (bytes 22-23)
	
	mov ax, 0000010010000001b		; 0000010 0100 00001
									;    1982   04    01 (date stamp)
	mov word [es:di+16], ax			; STORE CREATION DATE (bytes 16-17)
	mov word [es:di+18], ax			; STORE LAST ACCESS DATE (bytes 18-19)
	mov word [es:di+24], ax			; STORE LAST WRITE DATE (bytes 24-25)
	
	push cs
	pop ds							; DS := this segment, to access variables
	mov ax, word [fileWriteFirstClusterNumber]	; AX := first cluster of file
	mov word [es:di+26], ax			; STORE FIRST CLUSTER (bytes 26-27)
	
	mov word [es:di+28], cx			; STORE FILE SIZE (bytes 28-31)
	mov word [es:di+30], 0			; highest 2 bytes of file size are 0,
									; because our file sizes cannot exceed
									; 64kb less one (65535 bytes)
	pop es
	pop ds
	popa
	popf
	ret


; Returns the amount of available disk space, in bytes
;
; input:
;		none
; output:
;		DX:AX - amount of available disk space, in bytes
;				(least significant bytes in AX, most significant bytes in DX)
floppy_get_available_disk_space_entry_point:
	push cx
	call floppy_load_fat_to_disk_buffer
	call floppy_count_free_data_clusters_from_disk_buffer ; CX := number of
														  ; free clusters
	mov ax, BYTES_PER_SECTOR
	mul cx						; DX:AX := free clusters * bytes per cluster
	
	pop cx
	ret
