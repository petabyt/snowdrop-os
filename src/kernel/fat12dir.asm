;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the routines of Snowdrop's FAT12 file system driver which deal
; with the root directory area of a FAT12 disk.
; These routines are specific to 1.44Mb floppies.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Write root directory to disk. As with all other disk routines, the 
; disk used is the one which was current when the kernel booted.
; The buffer cannot cross 64k boundaries.
;
; input:
;		ES:BX - pointer to root directory data (must not cross 64kb boundary)
; output:
;		none (fails silently)
floppy_write_root_directory:
	pusha
	push es
	
	mov di, FIRST_ROOT_DIRECTORY_SECTOR
	mov al, ROOT_DIRECTORY_NUM_SECTORS
	call floppy_write_sectors
	
	pop es
	popa
	ret


; Write root directory to disk. As with all other disk routines, the 
; disk used is the one which was current when the kernel booted.
; Requires the root directory to have been loaded in the disk buffer
;
; input:
;		none
; output:
;		none (fails silently)
floppy_write_root_directory_from_disk_buffer:
	push ds
	push es
	pusha
	
	push cs
	pop ds
	push word [diskBufferSegment]
	pop es							; ES := disk buffer segment
	mov bx, 0
	call floppy_write_root_directory	; write root directory at ES:BX to disk
	
	popa
	pop es
	pop ds
	ret
	

; Locates the root directory entry of the file with the specified name
;
; input:
;		DS:SI - pointer to 11-byte buffer containing file name in FAT12 format
;		ES:DI - pointer to start of root directory
; output:
;		ES:DI - pointer to root directory entry of file whose name was provided
;		   AX - 0 when file was found
floppy_find_file:
	pushf
	push bx
	push cx
	push dx
	
	sub di, 32		; start one 32-byte entry before first
floppy_find_file_next_directory_entry:
	add di, 32		; next root directory entry
	mov bx, di
	shr bx, 5		; BX := index of current entry
	cmp bx, ROOT_ENTRIES_COUNT
	jae floppy_find_file_not_found	; if DI div 32 >= rootDirectoryEntriesCount
									; we're past the end, so file doesn't exist
	
	; ES:DI now points to first of 11 characters in file name in the entry
	mov al, byte [es:di]
	cmp al, 0E5h			; if the first character equals the magic value E5
							; then this directory entry is considered free
	je floppy_find_file_next_directory_entry 
							; so we move on to the next directory entry
	cmp al, 0				; if the first character equals the magic value 0
							; then this directory entry is considered free
	je floppy_find_file_next_directory_entry 
							; so we move on to the next directory entry
	
	; compare file name to input string
	push di			; save pointer to beginning of root directory entry
	push si			; save user input
	
	mov cx, 11				; FAT12 file names are always 11 characters
	cld
	repe cmpsb				; compare 11 contiguous bytes
	jnz floppy_find_file_wrong_file		; if zero flag is not set, the last 
										; comparison failed, meaning that
										; this is not the file we want
	; we found it!
	pop si			; restore user input
	pop di			; restore DI to beginning of current root directory entry
					; (also used as a return value)
	mov ax, 0		; indicate success when returning
	jmp floppy_find_file_done
	
floppy_find_file_wrong_file:
	pop si			; restore user input
	pop di			; restore DI to beginning of current root directory entry
	jmp floppy_find_file_next_directory_entry

floppy_find_file_not_found:
	mov ax, 1
	; flow into the "done" part below
floppy_find_file_done:
	pop dx
	pop cx
	pop bx
	popf
	ret
	
	
; Returns the number of a free (unused) entry from the root directory
;
; input:
;		ES:DI - pointer to where the root directory is loaded
; output:
;		ES:DI - pointer to the beginning of a free root directory entry
floppy_get_free_directory_entry:
	push ax
	push bx
	
	sub di, 32		; start one 32-byte entry before first
floppy_get_free_directory_entry_next:
	add di, 32		; next root directory entry
	mov bx, di
	shr bx, 5		; BX := index of current entry
	cmp bx, ROOT_ENTRIES_COUNT
	jae floppy_get_free_directory_entry_not_found
									; if DI div 32 >= rootDirectoryEntriesCount
									; we're past the end, so directory is full
	
	; ES:DI now points to first of 11 characters in file name in the entry
	mov al, byte [es:di]
	cmp al, 0E5h			; if the first character is the magic value E5
							; then this directory entry is considered free
	je floppy_get_free_directory_entry_found
							
	cmp al, 0				; if the first character is the magic value 0
							; then this directory entry is considered free
	je floppy_get_free_directory_entry_found
	
	jmp floppy_get_free_directory_entry_next	; next root directory entry
floppy_get_free_directory_entry_found:	
	; this entry is free, so we return it, leaving DI as it is
	pop bx
	pop ax
	ret
floppy_get_free_directory_entry_not_found:
	pop bx								; clean stack
	pop ax								; clean stack
	push ds
	push cs
	pop ds
	mov si, floppyRootDirFullMessage
	call debug_print_string
	pop ds
	jmp crash
	
	
; Returns the number of a free (unused) entry from the root directory.
; Requires that root directory to have been loaded in memory already.
;
; input:
;		ES:DI - pointer to where the root directory is loaded
; output:
;		CX - count of free root directory entries
floppy_count_free_directory_entries:
	push ax
	push bx
	push di
	
	mov cx, 0		; we'll accumulate in CX the count of free entries
	sub di, 32		; start one 32-byte entry before first
floppy_count_free_directory_entries_next:
	add di, 32		; next root directory entry
	mov bx, di
	shr bx, 5		; BX := index of current entry
	cmp bx, ROOT_ENTRIES_COUNT
	jae floppy_count_free_directory_entries_done
									; if DI div 32 >= rootDirectoryEntriesCount
									; we're past the end, so directory is full
	
	; ES:DI now points to first of 11 characters in file name in the entry
	mov al, byte [es:di]
	cmp al, 0E5h			; if the first character is the magic value E5
							; then this directory entry is considered free
	je floppy_count_free_directory_entries_found
							
	cmp al, 0				; if the first character is the magic value 0
							; then this directory entry is considered free
	je floppy_count_free_directory_entries_found
	
	jmp floppy_count_free_directory_entries_next	; next root directory entry
floppy_count_free_directory_entries_found:
	inc cx					; the current entry is free, so we count it
	jmp floppy_count_free_directory_entries_next	; next root directory entry
floppy_count_free_directory_entries_done:
	pop di
	pop bx
	pop ax
	ret
	

; Loads the root directory and returns the number of free root directory 
; entries
;
; input:
;		none
; output:
;		CX - number of free root directory entries
floppy_get_free_root_directory_entries_entrypoint:
	push ds
	push es

	push cs
	pop ds								; DS := CS
	push word [diskBufferSegment]
	pop es								; ES := disk buffer segment
	
	mov di, 0	; load root directory at ES:DI, which is diskBufferSegment:0000
	call floppy_load_root_directory_entrypoint
	
	mov di, 0							; need ES:0000 for the call below
	call floppy_count_free_directory_entries
	
	pop es
	pop ds
	ret
	

; Loads the root directory into the disk buffer segment
;
; input:
;		none
; output:
;		none
floppy_load_root_directory_to_disk_buffer:
	push ds
	push es
	pusha
	
	push cs
	pop ds
	push word [diskBufferSegment]
	pop es							; ES := disk buffer segment
	mov di, 0
	call floppy_load_root_directory_entrypoint	; load root directory to ES:DI
	
	popa
	pop es
	pop ds
	ret
	
