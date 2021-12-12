;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The APPS app.
; This app lists available apps by looking for entries in the root directory
; whose names end in the .APP extension.
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

NUM_DIRECTORY_ENTRIES equ 224
DIRECTORY_ENTRY_SIZE equ 32			; bytes
DIRECTORY_SIZE equ DIRECTORY_ENTRY_SIZE * NUM_DIRECTORY_ENTRIES
	
newlineString:	db 13, 10, 0
tabString: db "    ", 0
introMessageString:	db 13, 10, "The following apps are available:", 0

totalAppsString1:	db 13, 10, "Total ", 0
totalAppsString2:	db " apps.", 13, 10, 0
rootDirectoryEntriesCount: dw 0	; number of 32-byte entries 
								; in the root directory

largeNumberBufferString: times 16 db 0			; will hold the result of itoa
	
start:
	mov di, rootDirectory			; we're loading the root directory at ES:DI
	int 87h
	
	; AX now contains number of entries
	mov word [rootDirectoryEntriesCount], ax
	
	; the root directory 32-byte entries are now at rootDirectory

	mov si, introMessageString
	int 80h					; first, the intro message
	
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
	
	push di
	; move DI to first character of extension
	add di, 8		; skip over 8 characters of the name proper
	
	cmp byte [es:di], 'A'
	jne pop_and_next_directory_entry
	cmp byte [es:di+1], 'P'
	jne pop_and_next_directory_entry
	cmp byte [es:di+2], 'P'
	jne pop_and_next_directory_entry
	
	pop di			; restore DI to beginning of file name
	
	; this file name is an app file name, so print it
	push cx					; save app counter
	
	test cx, 00000011b
	jnz print_entry			; alternate columns
	
	mov si, newlineString
	int 80h					; first, a new line
	
print_entry:
	mov si, tabString
	int 80h					; and a tab
	
	mov si, di
	mov cx, 8	; print only 8 characters, up to the extension .
	int 88h		; dump CX characters to screen
	
	pop cx					; restore app counter
	inc cx					; app counter++
	
	jmp next_directory_entry

pop_and_next_directory_entry:
	pop di
	jmp next_directory_entry
	
all_done:
	mov si, newlineString
	int 80h

	mov dx, 0
	mov ax, cx						; DX:AX := app count
	mov si, largeNumberBufferString	; DS:SI := will store itoa string
	mov bl, 4						; option 4 - no padding, with commas
	int 0A2h
	
	mov si, totalAppsString1
	int 80h
	mov si, largeNumberBufferString
	int 80h							; print number
	mov si, totalAppsString2
	int 80h
	
	int 95h						; exit

rootDirectory:						; we'll load the root directory here
