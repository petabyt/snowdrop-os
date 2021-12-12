;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FVIEW app.
; This app is used to view the text contained in a file on disk.
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


FILE_NAME_MAX_SIZE	equ 12		; 8+3 plus extension dot

filenameBuffer:	times 15 db 0
fat12Filename: times FILE_NAME_MAX_SIZE+1 db 0
loadedFileSize:	dw 0

memoryIsAllocated:	db 0
addressSegment:	dw 0
addressOffset:	dw 0

fileNotFound:	db 'Error: file not found', 0
usageString: 	db 13, 10
				db 'Example usage:    FVIEW [file=sm.txt]', 13, 10
				db 0


start:	

	; look for "file" argument
	call read_file_name_argument		; AX := 0 when not found or invalid
	cmp ax, 0
	je incorrect_usage
	; fat12Filename is assumed to have been filled in
	
	; allocate memory to load the file
	call common_task_allocate_memory_or_exit	; BX := allocated segment
	mov word [cs:addressSegment], bx			; store it
	mov word [cs:addressOffset], 0
	mov byte [cs:memoryIsAllocated], 1			; indicate we have allocated

	; fill segment with zeroes
	push es
	mov cx, 65535
	mov di, 0
	mov es, bx
	mov al, 0
	rep stosb								; store 0 at 0 through :FFFE
	stosb									; store 0 at :FFFF
	pop es
	
	mov es, bx
	mov di, 0									; we're loading to ES:DI
	mov si, fat12Filename						; DS:SI := pointer to file name
	int 81h										; AL := 0 when successful
												; CX := file size in bytes
	cmp al, 0
	jne incorrect_file_name
	; file has now been loaded successfully, and address segment/offset
	; have been set
	mov word [cs:loadedFileSize], cx
	
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	mov ds, word [cs:addressSegment]
	mov si, word [cs:addressOffset]
	mov cx, word [cs:loadedFileSize]
	mov ax, COMMON_TEXT_VIEW_PAGED_FLAG_WAIT_FOR_USER_INPUT_AT_END
	call common_text_view_paged
	jmp exit

incorrect_usage:
	mov si, usageString
	int 80h
	jmp exit
	
incorrect_file_name:
	mov si, fileNotFound
	int 80h
	jmp exit
	
exit:
	call deallocate_memory
	int 95h							; exit
	
	
; Deallocates any allocated memory if needed
; 
; input:
;		none
; output:
;		none
deallocate_memory:
	pusha
	cmp byte [cs:memoryIsAllocated], 0
	je deallocate_memory_done
	
	mov bx, word [cs:addressSegment]
	int 92h						; deallocate
	mov byte [cs:memoryIsAllocated], 0
deallocate_memory_done:
	popa
	ret
	

; Attempt to read file name from parameter, and convert it
; to FAT12 format if it is found
; 
; input:
;		none
; output:
;		AX - 0 when file argument is unspecified or invalid,
;			 other value otherwise
read_file_name_argument:
	push bx
	push cx
	push dx
	push si
	push di
	pushf
	push ds
	
	; read value of argument 'file'
	call common_args_read_file_file_arg	; DS:SI := pointer to 8.3 file name
	cmp ax, 0
	jne read_file_name_argument_valid	; valid!

	; not found or invalid
	mov ax, 0
	jmp read_file_name_argument_done

read_file_name_argument_valid:
	; here, DS:SI contains the file name in 8.3 format
	push si
	int 0A5h						; BX := file name length
	mov cx, bx
	inc cx							; also copy terminator
	mov di, filenameBuffer
	cld
	rep movsb						; copy into filenameBuffer
	pop si

	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	mov ax, 1
read_file_name_argument_done:
	pop ds
	popf
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	

%include "common\scancode.asm"
%include "common\args.asm"
%include "common\tasks.asm"
%include "common\screen.asm"
%include "common\viewtext.asm"
