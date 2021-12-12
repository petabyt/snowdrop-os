;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FT_LARGE app.
; This app exercises the FAT12 driver by filling the disk with large files.
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

diskFullMessage: db "Disk full. Exiting...", 13, 10, 0
maxFilesReachedMessage: db "Max files reached. Exiting...", 13, 10, 0

NUM_FILES equ 26
fileNames:		db "TEST00  TXT"
				db "TEST01  TXT"
				db "TEST02  TXT"
				db "TEST03  TXT"
				db "TEST04  TXT"
				db "TEST05  TXT"
				db "TEST06  TXT"
				db "TEST07  TXT"
				db "TEST08  TXT"
				db "TEST09  TXT"
				db "TEST10  TXT"
				db "TEST11  TXT"
				db "TEST12  TXT"
				db "TEST13  TXT"
				db "TEST14  TXT"
				db "TEST15  TXT"
				db "TEST16  TXT"
				db "TEST17  TXT"
				db "TEST18  TXT"
				db "TEST19  TXT"
				db "TEST20  TXT"
				db "TEST21  TXT"
				db "TEST22  TXT"
				db "TEST23  TXT"
				db "TEST24  TXT"
				db "TEST25  TXT"

confirmationMessage: db 13, 10, "This test app FILLS the disk with 64kb files!"
					 db 13, 10, "Press [Y] to confirm and run.", 0
startingMessage: db 13, 10, "Starting...", 13, 10, 0
	
start:
	mov si, confirmationMessage
	int 80h						; print confirmation
	mov ah, 0
	int 83h			; clear keyboard buffer
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	cmp ah, COMMON_SCAN_CODE_Y
	jne done		; if user did not press Y, we're done

	; user pressed Y, so begin
	mov si, startingMessage
	int 80h
	
	push word 0
	pop es
	mov di, 0					; we will write from ES:DI to the file
	
	mov cx, NUM_FILES
	mov si, fileNames			; the file name is taken from DS:SI
	sub si, 11
next:
	add si, 11					; move pointer forward to next file name
	push cx
	mov cx, 65535				; CX := file size
	int 9Dh						; write file
	pop cx
	
	cmp ax, 1
	je max_files_reached
	cmp ax, 2
	je disk_full
	
	loop next
	int 95h						; exit
	
disk_full:
	mov si, diskFullMessage
	int 80h
	int 95h						; exit
max_files_reached:
	mov si, maxFilesReachedMessage
	int 80h
done:
	int 95h						; exit


%include "common\scancode.asm"
