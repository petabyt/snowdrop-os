;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FLIST app.
; This app is used to list files on disk.
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
	org 0						; Files are loaded at offset 0 by the caller

	jmp start

NUM_DIRECTORY_ENTRIES equ 224
DIRECTORY_ENTRY_SIZE equ 32			; bytes
DIRECTORY_SIZE equ DIRECTORY_ENTRY_SIZE * NUM_DIRECTORY_ENTRIES
	
singleBlankString:	db ' ', 0
newlineString:	db 13, 10, 0
tabString: db "    ", 0
introMessageString:	db 13, 10, 'The following files are on disk:', 0

spacesString:		db '    ', 0
largeNumberBufferString: times 16 db 0			; will hold the result of itoa
totalFilesString:	db 13, 10, "Total files count: ", 0
rootDirectoryEntriesCount: dw 0	; number of 32-byte entries 
								; in the root directory


currentStringPointer:		dw fileListString
								
start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	mov di, rootDirectory			; we're loading the root directory at ES:DI
	int 87h
	
	; AX now contains number of entries
	mov word [rootDirectoryEntriesCount], ax
	
	; the root directory 32-byte entries are now at rootDirectory

	mov si, introMessageString
	call print_zero_terminated	; first, the intro message
	
	mov cx, 0				; counts entries, to alternate print columns
	
	mov di, rootDirectory
	sub di, 32		; start one 32-byte entry before first
next_directory_entry:
	add di, 32
	mov bx, di
	shr bx, 5
	cmp bx, word [rootDirectoryEntriesCount]
	jae all_done	; if DI div 32 >= rootDirectoryEntriesCount, we're done
	
	; ES:DI now points to first of 11 characters in file name
	mov al, byte [es:di]
	cmp al, 0E5h			; if the first character equals the magic value E5
							; then this directory entry is considered free
	je next_directory_entry ; so we move on to the next directory entry
	cmp al, 0				; if the first character equals the magic value 0
							; then this directory entry is considered free
	je next_directory_entry ; so we move on to the next directory entry
	
print_entry:
	push cx					; save file counter

	mov si, newlineString
	call print_zero_terminated	; first, a new line
	
	mov si, di
	mov cx, 8	; this many characters
	call print_specified_size

	mov si, singleBlankString
	call print_zero_terminated
	
	mov si, di
	add si, 8
	mov cx, 3	; this many characters
	call print_specified_size

	; append file size
	mov si, spacesString
	call print_zero_terminated
	
	mov ax, word [es:di+28]		; lowest 2 bytes of file size go in AX
	mov dx, word [es:di+30]		; highest 2 bytes of file size go in DX
	mov si, largeNumberBufferString
	mov bl, 2					; formatting option 2 - commas + leading blanks
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI
	call print_zero_terminated
	
	pop cx					; restore file counter
	inc cx					; file counter++
	
	jmp next_directory_entry

all_done:
	mov si, newlineString
	call print_zero_terminated

	mov si, totalFilesString
	call print_zero_terminated
	
	mov dx, 0
	mov ax, cx
	mov bl, 4			; formatting option
	mov si, word [cs:currentStringPointer]
	int 0A2h			; convert number to ASCII and add terminator
	
	mov si, fileListString
	int 0A5h				; BX := string length
	mov cx, bx
	mov ax, COMMON_TEXT_VIEW_PAGED_FLAG_WAIT_FOR_USER_INPUT_AT_END
	call common_text_view_paged
	
	int 95h						; exit


; Accumulates a zero-terminated string into the large file list string
;
; input:
;	 DS:SI - pointer to text
; output:
;		none
print_zero_terminated:
	push es
	pusha
	
	int 0A5h				; BX := string length
	mov cx, bx
	
	push cs
	pop es
	mov di, word [cs:currentStringPointer]
	rep movsb
	mov word [cs:currentStringPointer], di				; save new pointer
	
	popa
	pop es
	ret
	
	
; Accumulates a string of specified size into the large file list string
;
; input:
;	 DS:SI - pointer to text
;		CX - number of bytes
; output:
;		none
print_specified_size:
	push es
	pusha
	
	push cs
	pop es
	mov di, word [cs:currentStringPointer]
	rep movsb
	mov word [cs:currentStringPointer], di				; save new pointer
	
	popa
	pop es
	ret

	
%include "common\scancode.asm"
%include "common\viewtext.asm"

rootDirectory: times DIRECTORY_SIZE db 0 ; we'll load the root directory here
fileListString:							 ; we'll build the output string here
