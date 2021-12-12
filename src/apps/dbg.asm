;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The DBG app.
; This is a wrapper application of Snowdrop OS's x86 debugger.
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

fat12Filename: 			times FILE_NAME_MAX_SIZE+1 db 0
fat12ListingFilename:	times 8 db 0		; the name part
						db 'LST', 0			; the extension part

; the input file
inputBufferIsAllocated:	db 0
inputSegment:	dw 0
inputOffset:	dw 0
binaryByteSize:	dw 0

; the listing buffer
listingBufferIsAllocated:	db 0
listingSegment:		dw 0
listingOffset:		dw 0
listingSize:		dw 0

fileNotFound:			db 13, 10, 'Error: input file not found', 0
listingFileNotFound:	db 13, 10, 'Error: listing file not found', 0
introString:	db 'Snowdrop OS x86 Debugger (written by Sebastian Mihai)', 0
usageString: 	db 13, 10
				db 'Example usage:    DBG [file=example.app]', 13, 10
				db '    (expects files EXAMPLE.APP and EXAMPLE.LST to be present)', 13, 10
				db 0

couldNotAllocateListingBuffer:	db 'Could not allocate listing buffer', 0

	
start:
	mov si, introString
	int 80h
	
	; look for "file" argument
	call read_file_name_argument		; AX := 0 when not found or invalid
	cmp ax, 0
	je incorrect_usage
	; fat12Filename is assumed to have been filled in
	; fat12ListingFilename is assumed to have been filled in
	
	; allocate memory to load the file
	call common_task_allocate_memory_or_exit	; BX := allocated segment
	mov word [cs:inputSegment], bx				; store it
	mov word [cs:inputOffset], 0
	mov byte [cs:inputBufferIsAllocated], 1			; indicate we have allocated

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
	; binary file has now been loaded successfully
	mov word [cs:binaryByteSize], cx
	
	; allocate memory for the listing
	int 91h									; BX := allocated segment
	cmp ax, 0
	jne listing_segment_not_allocated
	
	mov word [cs:listingSegment], bx			; store it
	mov word [cs:listingOffset], 0
	mov byte [cs:listingBufferIsAllocated], 1
	
	; fill segment with zeroes
	push es
	mov cx, 65535
	mov di, 0
	mov es, bx
	mov al, 0
	rep stosb								; store 0 at 0 through :FFFE
	stosb									; store 0 at :FFFF
	pop es
	
	mov es, word [cs:listingSegment]
	mov di, word [cs:listingOffset]			; ES:DI := listing buffer
	push cs
	pop ds
	mov si, fat12ListingFilename			; DS:SI := pointer to file name
	int 81h									; AL := 0 when successful
											; CX := file size in bytes
	cmp al, 0
	jne listing_not_found
	
	; now run the debugger
	mov ds, word [cs:listingSegment]
	mov si, word [cs:listingOffset]			; DS:SI := listing buffer
	mov es, word [cs:inputSegment]
	mov di, word [cs:inputOffset]			; ES:DI := binary buffer
	mov cx, word [cs:binaryByteSize]
	call dbgx86_run

	mov ah, 0
	int 16h									; wait for key
	jmp exit
	
listing_segment_not_allocated:
	push cs
	pop ds
	mov si, couldNotAllocateListingBuffer
	int 80h
	jmp exit
	
incorrect_usage:
	push cs
	pop ds
	mov si, usageString
	int 80h
	jmp exit
	
incorrect_file_name:
	push cs
	pop ds
	mov si, fileNotFound
	int 80h
	jmp exit

listing_not_found:
	push cs
	pop ds
	mov si, listingFileNotFound
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
	cmp byte [cs:inputBufferIsAllocated], 0
	je deallocate_memory_after_input_dealloc
	
	mov bx, word [cs:inputSegment]
	int 92h						; deallocate
	mov byte [cs:inputBufferIsAllocated], 0
deallocate_memory_after_input_dealloc:
	
	cmp byte [cs:listingBufferIsAllocated], 0
	je deallocate_memory_after_listing_dealloc

	mov bx, word [cs:listingSegment]
	int 92h						; deallocate
	mov byte [cs:listingBufferIsAllocated], 0

deallocate_memory_after_listing_dealloc:
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
	push es
	
	; read value of argument 'file'
	call common_args_read_file_file_arg	; DS:SI := pointer to 8.3 file name
	cmp ax, 0
	jne read_file_name_argument_valid	; valid!

	; not found or invalid
	mov ax, 0
	jmp read_file_name_argument_done

read_file_name_argument_valid:
	; here, DS:SI contains the file name in 8.3 format
	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, fat12Filename
	mov di, fat12ListingFilename
	mov cx, 8							; we're just copying the name part
	cld
	rep movsb
	
	mov ax, 1
read_file_name_argument_done:
	pop es
	pop ds
	popf
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret


%include "common\args.asm"
%include "common\tasks.asm"
%include "common\debugger\dbgx86.asm"
