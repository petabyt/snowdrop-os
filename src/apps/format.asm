;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FORMAT app.
; This app formats a disk with a FAT12 file system.
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

confirmationMessage: 
 db 13, 10
 db 13, 10, "=========================== WARNING ==========================="
 db 13, 10, "The disk is about to be formatted, DESTROYING ALL EXISTING DATA"
 db 13, 10, "Insert desired disk to format and press [Y] to run.", 13, 10, 0
startingMessage: db 13, 10, "Starting...", 13, 10, 0
notFoundMessage: db 13, 10, "Could not read FAT12 image!", 13, 10, 0
selectDiskMessage:	db 13, 10, "Press SPACE to cycle through disks", 13, 10
					db "Press ENTER to accept disk", 13, 10
					db "Press ESCAPE to exit", 13, 10
diskIdMessage:		db 13, "Disk ID: ", 0
currentDiskMessage:			db "h (current)", 0
eraseCurrentDiskMessage:	db "h          ", 0

MAX_DISKS				equ 6
availableDiskIds:		times MAX_DISKS db 99		; stores up to 6 disks
availableDiskCount:		db 99
currentDiskPointer:		dw availableDiskIds		; pointer into disk ID array
initialDiskId:			db 99


start:
	; read FAT12 image
	mov di, fatImageBuffer		; ES:DI now points to beginning of buffer
	int 0B1h					; read FAT12 image into ES:DI
	cmp al, 0					; success?
	jne fat_image_not_found		; failure (not found)
	
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
	jbe select_disk_done		; we skip disk selection if under two disks
	
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
	; wait for user confirmation
	mov si, confirmationMessage
	int 80h						; print confirmation
	mov ah, 0
	int 83h						; clear keyboard buffer
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_Y
	jne done					; if user did not press Y, we're done

	; perform format
	mov si, startingMessage
	int 80h						; print "starting..."
	
	mov si, fatImageBuffer		; DS:SI now points to beginning of FAT image
	int 0ABh					; format FAT12 disk using image in DS:SI
	jmp done
	
fat_image_not_found:
	mov si, notFoundMessage
	int 80h						; print
	
done:
	mov al, byte [cs:initialDiskId]
	int 0C3h							; restore disk
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
	
	
; Renders a byte as two hex digit characters
; Example: 20 -> "1" "8"
;
; input:
;		AL - byte to render
; output:
;		CX - two characters which represent the input
byte_to_hex:
	push ax
	push bx
	push dx
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call hex_digit_to_char		; CL := char
	mov ch, cl
	mov al, ah
	call hex_digit_to_char		; CL := char
	
	pop dx
	pop bx
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
	mov si, word [cs:currentDiskPointer]
	mov al, byte [cs:si]
	int 0C3h							; change disk
	
	pop es
	pop ds
	popf
	popa
	ret
	

%include "common\scancode.asm"

fatImageBuffer: 	; the FAT12 image will be loaded here

