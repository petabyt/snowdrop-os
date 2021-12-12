;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FT_MANY app.
; This app exercises the FAT12 driver by filling the disk with many files.
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

NUM_FILES equ 300
; advancing one character at a time yields a new file name
fileNames:		db "EKLJ98UHEU2NEDOINEDKMPDIO1DCWDHEIFFRHNF937HNF938RHFN39RUHFN39RFN309JVFLJNS09JELMVLJNALSKDMFALSKPLRRMIEPOIMSCNV22OIN4FLKM4F4UWHOIWEOFIWOECIMWEPO09497HF48J09K2EFJ02GH7Y7YHF8IJF09JRFO2NNXBWTYRHNEINEIEIFEEFNOIZPKRPLPLMIQAUH3D6G4FIUNVKJGR98H35GKJBWSDCKMN23QAZAQZ1WS1WSRVGRVTBHY5YJ6N87I6O79P8P675H4TH4TGHV3RG34CF34F34VG45YBY6H67NJ867OSOSOOSLSWJQWIUWIS7S7QGQQBO8IHFWEJHN24F98HSDLF"
	
confirmationMessage: db 13, 10, "This test app FILLS the disk with many small"
					         db " files."
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
	
	mov cx, NUM_FILES
	mov di, 0					; we will write from ES:DI to the file
	mov si, fileNames			; the file name is taken from DS:SI
	dec si
next:
	inc si						; move pointer forward to next file name
	push cx
	mov cx, 10					; CX := file size
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
