;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the routines of Snowdrop's FAT12 file system driver which deal
; with the FAT (cluster table) area of a FAT12 disk.
; These routines are specific to 1.44Mb floppies.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Write FAT (cluster table proper) to disk. As with all other disk routines, 
; the disk used is the one which was current when the kernel booted.
; The buffer cannot cross 64k boundaries.
;
; input:
;		ES:BX - pointer to FAT data (must not cross 64kb boundary)
; output:
;		none (fails silently)
floppy_write_fat:
	pusha
	push es
	
	mov di, FIRST_FAT_SECTOR
	mov al, FAT_NUM_SECTORS
	call floppy_write_sectors
	
	pop es
	popa
	ret
	

; Write FAT (cluster table proper) to disk. As with all other disk routines, 
; the disk used is the one which was current when the kernel booted.
; The buffer cannot cross 64k boundaries.
; Requires the FAT to have been loaded in the disk buffer
;
; input:
;		none
; output:
;		none
floppy_write_fat_to_disk_from_disk_buffer:
	push ds
	push es
	pusha
	
	push cs
	pop ds
	push word [diskBufferSegment]
	pop es							; ES := disk buffer segment
	mov bx, 0
	call floppy_write_fat			; write FAT at ES:BX to disk
	
	popa
	pop es
	pop ds
	ret
	

; Loads the FAT (tables proper) to the specified buffer.
; The destination buffer cannot cross 64k boundaries.
;
; input:
;			ES:BX pointer to where the FAT will be loaded
;				  (must not cross 64kb boundary)
floppy_load_fat:
	pusha
	push es

	mov di, FIRST_FAT_SECTOR
	mov al, FAT_NUM_SECTORS	; we'll read this many sectors
	call floppy_read_sectors	; CARRY := set when an error occurred
	
	jnc floppy_read_fat_success	; if there were no errors (CF=0), proceed
	
	call reset_floppy					; errors happened - reset drive
	pop es								; restore all, so we can retry
	popa
	jmp floppy_load_fat					; retry

floppy_read_fat_success:
	pop es								; restore all
	popa
	ret


; Gets the value stored in a cluster in the FAT area
;
; input:
;		ES:DI - pointer to where the FAT is loaded
;		   AX - number of current cluster
; output:
;		   AX - number of next cluster (value stored in FAT 
;				for specified cluster
floppy_get_fat_cluster_value:
	push bx
	push dx
	
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
	
	mov bx, ax					; we can throw away value in BX
	mov ax, word [es:di+bx]		; AX := word in FAT for the 12-bit cluster
	
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
	jnz floppy_get_fat_cluster_value_cluster_is_even	
						; if DX is now non-zero, then it used to be zero,
						; meaning that the cluster number is even
						
						; If [cluster] is even, drop last 4 bits of word
						; with next cluster; if odd, drop first 4 bits
	
	; [EXAMPLE CONTINUES]
	; in our example, we continue here, since DX is odd

floppy_get_fat_cluster_value_cluster_is_odd:
	shr ax, 4	; for odd entries, we shift right a nibble
	
	; [EXAMPLE ENDS]
	; in our example, AX goes from 0x9AB6 to 0x09AB after the shift
	; which is exactly what cluster 3 contains (see beginning of example)
	
	jmp floppy_get_fat_cluster_value_done
floppy_get_fat_cluster_value_cluster_is_even:
	and ax, 0FFFh	; for even entries, we discard highest (left-most) nibble

floppy_get_fat_cluster_value_done:
	; AX now contains the value contained in the current cluster,
	; which is the number of the next cluster of the file
	pop dx
	pop bx
	ret
	

; Writes specified value in the specified cluster, in the FAT
;
; input:
;		ES:DI - pointer to where the FAT is loaded
;		   AX - number of cluster where we're writing
;		   CX - value to write (between 0 and 0FFFh)
; output:
;		   none
floppy_write_fat_cluster:
	push bx
	push cx
	push dx

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
	
	mov bx, ax					; we can throw away value in BX
	mov ax, word [es:di+bx]		; AX := word in FAT for the 12-bit cluster
	
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
	jnz floppy_write_fat_cluster_cluster_is_even	
						; if DX is now non-zero, then it used to be zero,
						; meaning that the cluster number is even
						
						; If [cluster] is even, drop last 4 bits of word
						; with next cluster; if odd, drop first 4 bits
	
	; [EXAMPLE CONTINUES]
	; in our example, we continue here, since DX is odd

floppy_write_fat_cluster_cluster_is_odd:
	; [EXAMPLE CONTINUES]
	; AX now contains something like 0x9AB6, where 0x9AB is the current value
	; we're overwriting
	; CX (our input value) contains something like 0x0XYZ
	; the result has to be 0xXYZ6, which we'll store back where we got it
	shl cx, 4		; CX (our input value) now contains something like 0xXYZ0

	and ax, 000Fh	; AX now contains something like 0x0006
	or ax, cx		; AX now contains something like 0xXYZ6, now holding the
					; value we wish to write to the FAT cluster entry
	mov word [es:di+bx], ax	; store new value in FAT
	jmp floppy_write_fat_cluster_done
	
floppy_write_fat_cluster_cluster_is_even:
	; [EXAMPLE CONTINUES]
	; for an even cluster number (such as 2), we'd read the following 
	; two bytes: 0x78 0xB6
	; due to little-endianness, AX = 0xB678, where 0x0678 is the current value
	; CX (our input value) contains something like 0x0XYZ
	; the result has to be 0xBXYZ, which we'll store back where we got it
	and ax, 0F000h	; AX now contains something like 0xB000
	or ax, cx		; AX now contains something like 0xBXYZ, now holding the
					; value we wish to write to the FAT cluster entry
	mov word [es:di+bx], ax	; store new value in FAT

floppy_write_fat_cluster_done:
	; AX now contains the value contained in the current cluster,
	; which is the number of the next cluster of the file
	pop dx
	pop cx
	pop bx
	ret
	
	
; Returns the number of a free (unused) cluster from the FAT table area
;
; input:
;		ES:DI - pointer to where the FAT is loaded
; output:
;		AX - number of the free (data) cluster
floppy_get_free_data_cluster:
	mov ax, FIRST_DATA_CLUSTER_NUMBER
floppy_get_free_data_cluster_loop:
	push ax									; save current cluster number

	call floppy_get_fat_cluster_value		; AX := cluster value
	cmp ax, 0								; magic value 0 means "unused"
	je floppy_get_free_data_cluster_found	; yes, current cluster is free
	; no, current cluster is taken
	pop ax									; AX := current cluster number
	inc ax									; next cluster
	
	cmp ax, LAST_DATA_CLUSTER_NUMBER		; are we past the last cluster?
	ja floppy_get_free_data_cluster_full	; yes
	jmp floppy_get_free_data_cluster_loop	; no, loop again
floppy_get_free_data_cluster_found:
	pop ax								; restore current (free) cluster number
										; so we can return it
	ret
floppy_get_free_data_cluster_full:
	pop ax								; clean stack
	push ds
	push cs
	pop ds
	mov si, floppyDataAreaFullMessage
	call debug_print_string
	pop ds
	jmp crash

	
; Returns the number of free clusters from the FAT table area
; Requires the FAT to have been loaded in memory already.
;
; input:
;		ES:DI - pointer to where the FAT is loaded
; output:
;		CX - count of free data clusters
floppy_count_free_data_clusters:
	push ax									; save user input
	
	mov cx, 0								; we'll accumulate the count in CX
	mov ax, FIRST_DATA_CLUSTER_NUMBER
floppy_count_free_data_clusters_loop:
	push ax									; save current cluster number
	call floppy_get_fat_cluster_value
	cmp ax, 0								; magic value 0 means "unused"
	jne floppy_count_free_data_clusters_next ; not free, so we don't count it
	
	inc cx									 ; yes, it's free, so count it
floppy_count_free_data_clusters_next:
	pop ax									; AX := current cluster number
	inc ax									; next cluster
	
	cmp ax, LAST_DATA_CLUSTER_NUMBER		; are we past the last cluster?
	jbe floppy_count_free_data_clusters_loop	; no, loop again

	pop ax									; restore user input
	ret
	
	
; Loads the FAT to the disk buffer segment (segment:0000)
;
; input:
;		none
; output:
;		none
floppy_load_fat_to_disk_buffer:
	pusha
	push ds
	push es
	
	push cs
	pop ds
	push word [diskBufferSegment]
	pop es					; ES := diskBufferSegment
	mov bx, 0				; we'll load the FAT to diskBufferSegment:0000
	call floppy_load_fat	; (ES = diskBufferSegment, from above)
	
	pop es
	pop ds
	popa
	ret


; Returns the number of free clusters from the FAT table area
; Requires the FAT to have been loaded in the disk buffer
;
; input:
;		none
; output:
;		CX - count of free data clusters
floppy_count_free_data_clusters_from_disk_buffer:
	push ds
	push es
	push di
	
	push cs
	pop ds
	push word [diskBufferSegment]
	pop es
	mov di, 0
	call floppy_count_free_data_clusters ; CX := number of free data clusters
	
	pop di
	pop es
	pop ds
	ret


; Returns the number of a free (unused) cluster from the FAT table area
; Requires the FAT to have been loaded in the disk buffer
;
; input:
;		none
; output:
;		AX - number of the free (data) cluster
floppy_get_free_data_cluster_from_disk_buffer:
	push ds
	push es
	push di
	
	push cs
	pop ds
	push word [diskBufferSegment]
	pop es
	mov di, 0
	call floppy_get_free_data_cluster	; AX := number of the free cluster
	
	pop di
	pop es
	pop ds
	ret
	
	
; Writes specified value in the specified cluster, in the FAT.
; Requires the FAT to have been loaded in the disk buffer.
;
; input:
;		   DX - number of cluster where we're writing (key)
;		   AX - value to write (between 0 and 0FFFh) (value)
; output:
;		   none
floppy_write_fat_cluster_from_disk_buffer:
	push ds
	push es
	pusha
	
	push cs
	pop ds
	push word [diskBufferSegment]
	pop es
	mov di, 0						; ES:DI now points to beginning of FAT
	mov cx, ax						; CX := value to write
	mov ax, dx						; AX := key (cluster where we're writing)
	call floppy_write_fat_cluster	; write value in FAT cluster
	
	popa
	pop es
	pop ds
	ret
	
