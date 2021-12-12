;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the low-level utilities of Snowdrop's FAT12 file system driver,
; not dealing with any specific areas of a FAT12 disk.
; These routines are specific to 1.44Mb floppies.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Reads contiguous sectors from disk. As with all other disk routines, the
; disk used is the one which was current when the kernel booted.
; The buffer cannot cross 64k boundaries.
; NOTE: Destroys registers
;
; input:
;		ES:BX - pointer to destination buffer (must not cross 64kb boundary)
;		AL - number of sectors to read
;		DI - first logical sector
; output:
;		CARRY - set when there was an error, clear otherwise
floppy_read_sectors:
	cmp al, 0
	je floppy_read_sectors_success				; reading zero sectors is NOOP
	
	mov byte [cs:floppyNumSectorsToRead], al	; how many we have left
floppy_read_sectors_loop:
	pusha
	push es
	
	mov ax, di									; AX := logical sector
	call floppy_logical_to_physical				; LBA to CHS translation
	mov ah, 2									; function 2: read sectors
	mov al, 1									; we're reading one at a time	
	int 13h										; read single sector
	
	pop es
	popa
	jc floppy_read_sectors_done					; error occurred while reading
	add bx, 512									; advance pointer
	inc di										; advance sector
	dec byte [cs:floppyNumSectorsToRead]		; one less sector to read
	jnz floppy_read_sectors_loop
floppy_read_sectors_success:
	clc											; "no error"
floppy_read_sectors_done:
	ret

	
; Write contiguous sectors to disk. As with all other disk routines, the 
; disk used is the one which was current when the kernel booted.
; The buffer cannot cross 64k boundaries.
;
; input:
;		ES:BX - pointer to data to write (must not cross 64kb boundary)
;		AL - number of sectors to write
;		DI - logical sector number of first sector to which we're writing
; output:
;		none (fails silently)
floppy_write_sectors:
	pusha
	cmp al, 0
	je floppy_write_sectors_done	; NOOP when zero sectors are to be written

floppy_write_sectors_loop:
	; input:
	;		ES:BX - pointer to data to write (must not cross 64kb boundary)
	;		DI - logical sector number of first sector to which we're writing
	; output:
	;		none (fails silently)
	call floppy_write_single_sector
	add bx, 512						; move further into buffer
	inc di							; next logical sector
	dec al							; one fewer to write
	jnz floppy_write_sectors_loop
floppy_write_sectors_done:
	popa
	ret
	

; Write a single sectors to disk. As with all other disk routines, the 
; disk used is the one which was current when the kernel booted.
; The buffer cannot cross 64k boundaries.
;
; input:
;		ES:BX - pointer to data to write (must not cross 64kb boundary)
;		DI - logical sector number of sector we're writing
; output:
;		none (fails silently)
floppy_write_single_sector:
	pusha								; save all for when we retry
	push es
	
	push bx
	push es

	; prepare arguments
	mov ax, di							; AX := first LBA sector
	call floppy_logical_to_physical		; fill in CHS values, in preparation
	
	mov ah, 3							; function 3: "write sectors to disk"
	mov al, 1							; we're writing a single sector
	pop es								; restore user input segment
	pop bx								; 	and offset
	
	; invoke BIOS disk drive function
	int 13h								; write single sector
	jnc floppy_write_single_sector_success	; if no errors (CF=0), proceed
	
	call reset_floppy					; errors happened - reset drive
	pop es								; restore all, so we can retry
	popa
	jmp floppy_write_single_sector		; retry

floppy_write_single_sector_success:	
	pop es								; restore all
	popa
	ret


; Read contiguous sectors (from the actual file data area) sectors from disk.
; As with all other disk routines, the disk used is the one which was current 
; when the kernel booted.
; The buffer cannot cross 64k boundaries.
;
; input:
;		ES:BX - pointer to where we're reading (must not cross 64kb boundary)
;		AL - number of sectors to read
;		DI - logical sector number of first sector from which we're reading
; output:
;		none (fails silently)
floppy_read_data_sectors:
	pusha								; save all for when we retry
	push es
	
	push bx
	push es

	add di, 31			; offset to first data area cluster
						; note that cluster 2 is the first data area cluster
						; and we have:
						;	1 boot sector
						; 2*9 FAT sectors
						;  14 root directory sectors
						;= 33 sectors before data area
						; but since cluster 2 is the first data area cluster, 
						; then we must subtract by 2, for a total offset of 31

	call floppy_read_sectors			; CARRY := set when an error occurred
	
	pop es								; restore user input segment
	pop bx								; 	and offset

	jnc floppy_read_data_sectors_success ; if no errors (CF=0), proceed
	
	call reset_floppy					; errors happened - reset drive
	pop es								; restore all, so we can retry
	popa
	jmp floppy_read_data_sectors		; retry

floppy_read_data_sectors_success:	
	pop es								; restore all
	popa
	ret


; Calculates how many clusters will be needed to store a file of the 
; specified size.
;
; input:
;		CX - file size in bytes
; output:
;		AX - count of data clusters needed to store file
floppy_count_necessary_clusters:
	push cx
	
	mov ax, cx
	shr ax, 9								; AX := CX div 512
	
	and cx, 511								; is there a remainder to CX / 512?
	jz floppy_count_necessary_clusters_done	; no, so we're done
	inc ax									; yes, so we need one more cluster
floppy_count_necessary_clusters_done:
	pop cx
	ret

	
; Write contiguous data (to the actual file data area) sectors from disk. 
; As with all other disk routines, the disk used is the one which was current 
; when the kernel booted.
; The buffer cannot cross 64k boundaries.
;
; input:
;		ES:BX - pointer to data (must not cross 64kb boundary)
;		   AL - number of sectors to write
;		   DI - logical sector number of first sector to which we're writing
; output:
;		none
floppy_write_data_sectors:
	pusha
	push es
	
	add di, 31			; offset to first data area cluster
						; note that cluster 2 is the first data area cluster
						; and we have:
						;	1 boot sector
						; 2*9 FAT sectors
						;  14 root directory sectors
						;= 33 sectors before data area
						; but since cluster 2 is the first data area cluster, 
						; then we must subtract by 2, for a total offset of 31
	call floppy_write_sectors
	
	pop es
	popa
	ret

	
; Resets the floppy drive preceding a retry
;
; input:
;			none
; output:
;			none
reset_floppy:
	push ds
	pusha
	
	push cs
	pop ds							; DS := this segment
	
	mov cx, 10						; we will retry the reset itself 10 times
reset_floppy_loop:
	mov ah, 0						; function 0: reset disk drive
	mov dl, byte [driveNumber]
	clc
	int 13h							; reset drive
	jnc reset_floppy_success		; if carry flag is not set, we succeeded
	
	dec cx
	jcxz reset_floppy_failure		; if we've exhausted our retries, we
									; can do nothing else, so halt the CPU
	jmp reset_floppy_loop
reset_floppy_success:	
	popa
	pop ds
	ret
reset_floppy_failure:
	mov si, floppyDriveErrorMessage
	call debug_print_string
	popa						; keep stack clean
	pop ds
	jmp crash


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
	push ds
	
	push cs
	pop ds				; DS := this segment
	
	push ax				; save logical sector

	mov dx, 0
	div word [diskSectorsPerTrack]
				; AX := logical sector number / sectors per track
				;    which equates to logical number of track
				; DX := logical sector number % sectors per track
				;    which equates to physical sector number		
	inc dl			; physical sector numbering is 1-based
	mov cl, dl		; physical sector number belongs in CL for 
					; interrupt 13h calls
	pop ax				; AX := logical sector
	
	mov dx, 0
	div word [diskSectorsPerTrack]
				; AX := logical sector number / sectors per track
				;    which equates to logical number of track
									
	mov dx, 0
	div word [diskHeads]		; AX := logical number of track / heads
								; DX := logical number of track % heads
	
	mov dh, dl			; physical head number belongs in DH for 
						; interrupt 13h calls
	mov ch, al					; physical track (cylinder) number 
								; belongs in CH for interrupt 13h calls
	mov dl, byte [driveNumber]	; device number belongs in DL for 
								; interrupt 13h calls
	pop ds
	ret
