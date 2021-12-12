;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FDELETE app.
; This app deletes files from disk.
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

	bits 16
	org 0

	jmp start

fat12Filename:	times 20 db 0		; stores file name in FAT12 format

usageString: 	db 13, 10
				db 'Example usage:    FDELETE [file=notes.txt]', 13, 10, 0

start:
	; read value of argument 'file'
	call common_args_read_file_file_arg	; DS:SI := pointer to 8.3 file name
	cmp ax, 0
	jne file_name_argument_valid	; valid!

	; not found or invalid; show error message and exit
	push cs
	pop ds
	mov si, usageString
	int 80h
	int 95h							; exit program

file_name_argument_valid:
	; here, DS:SI contains the file name in 8.3 format
	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	push cs
	pop ds
	mov si, fat12Filename		; DS:SI := pointer to FAT12 format file name
	int 9Ch						; delete file
	
	int 95h						; exit


%include "common\args.asm"
