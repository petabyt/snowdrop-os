;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The DISKCHG app.
; This application changes the current disk.
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop app contract:
;
; At startup, the app can assume:
;	- the app is loaded at offset 0
;	- all segment registers equal CS
;	- the stack is valid (SS, SP)
;	- BP equals SP
;	- direction flag is clear (string operations count upwards)
;
; The app must:
;	- call int 95h to exit
;	- not use the entire 64kb memory segment, as its own stack begins from 
;	  offset 0FFFFh, growing upwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16						; the CPU is assumed to function in 16-bit mode
	org 0						; apps are loaded at offset 0 by the caller

	jmp start

selectDiskMessage:	db 13, 10, "Press SPACE to cycle through disks", 13, 10
					db "Press ENTER to change to selected disk", 13, 10
					db "Press ESCAPE to exit", 13, 10
diskIdMessage:		db 13, "Disk ID: ", 0
notEnoughDisksMessage:	db 13, 10, "Cannot change to another disk when only one disk is available", 0
diskChangedMessage: 	db 13, 10, "Disk changed", 0
currentDiskMessage:			db "h (current)", 0
eraseCurrentDiskMessage:	db "h          ", 0

MAX_DISKS				equ 6
availableDiskIds:		times MAX_DISKS db 99		; stores up to 6 disks
availableDiskCount:		db 99
currentDiskPointer:		dw availableDiskIds		; pointer into disk ID array
initialDiskId:			db 99


start:
	; get available disk info
	int 0C2h					; get available disk information
	mov byte [cs:availableDiskIds + 0], bl
	mov byte [cs:availableDiskIds + 1], bh
	mov byte [cs:availableDiskIds + 2], cl
	mov byte [cs:availableDiskIds + 3], ch
	mov byte [cs:availableDiskIds + 4], dl
	mov byte [cs:availableDiskIds + 5], dh
	mov byte [cs:availableDiskCount], ah

	; here, AL = ID of current disk
	mov byte [cs:initialDiskId], al		; store it for later
	
	mov ch, 0
	mov cl, ah							; CX := available disk count
	mov di, availableDiskIds
	repne scasb
	dec di								; bring DI back to the match
	mov word [cs:currentDiskPointer], di	; assumes current disk exists 
										; among those disks returned above	
	cmp byte [cs:availableDiskCount], 1
	jbe not_enough_disks		; we skip disk selection if under two disks
	
	; select disk
	mov si, selectDiskMessage
	int 80h
select_disk_loop:
	; re-display disk
	mov si, diskIdMessage
	int 80h
	mov si, word [cs:currentDiskPointer]
	mov al, byte [cs:si]
	int 8Eh					; print byte to video hardware

	mov si, eraseCurrentDiskMessage
	cmp al, byte [cs:initialDiskId]		; is current disk the initial disk?
	jne select_disk_loop_wait_key		; no
	mov si, currentDiskMessage			; yes, so print a note
select_disk_loop_wait_key:
	int 80h								; prints either (current) or blanks,
										; to erase a previous (current)
	mov ah, 0
	int 16h						; wait for key
	cmp ah, COMMON_SCAN_CODE_ENTER
	je select_disk_done
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je done
	cmp ah, COMMON_SCAN_CODE_SPACE_BAR
	jne select_disk_loop
	; space was pressed
	call handle_change_disk
	
	jmp select_disk_loop		; loop again

select_disk_done:	
	mov si, word [cs:currentDiskPointer]
	mov al, byte [cs:si]
	int 0C3h							; change disk
	mov si, diskChangedMessage
	int 80h
	jmp done
		
not_enough_disks:
	mov si, notEnoughDisksMessage
	int 80h
	jmp done
	
done:
	int 95h						; exit

	
	
; Convert a hex digit to its character representation
; Example: 10 -> 'A'
;
; input:
;		AL - hex digit
; output:
;		CL - hex digit to char
hex_digit_to_char:
	push ax
	cmp al, 9
	jbe hex_digit_to_char_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
hex_digit_to_char_under9:
	add al, '0'
	mov cl, al
	pop ax
	ret
	
	
; Cycles to the next available disk
; 
handle_change_disk:
	pusha
	pushf
	push ds
	push es

	inc word [cs:currentDiskPointer]
	
	mov ax, availableDiskIds
	mov ch, 0
	mov cl, byte [cs:availableDiskCount]
	add ax, cx							; AX := just after last disk
	cmp word [cs:currentDiskPointer], ax
	jb handle_change_disk_done
	
	; we've gone past the end of available disks
	mov word [cs:currentDiskPointer], availableDiskIds	; move to first disk
	
handle_change_disk_done:	
	pop es
	pop ds
	popf
	popa
	ret
	

%include "common\scancode.asm"
