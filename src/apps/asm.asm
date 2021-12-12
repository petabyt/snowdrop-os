;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The ASM app.
; This is a wrapper application of Snowdrop OS's x86 assembler.
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

fat12Filename: 		times FILE_NAME_MAX_SIZE+1 db 0
output8p3Filename:	times FILE_NAME_MAX_SIZE+1 db 0
listing8p3Filename:	times FILE_NAME_MAX_SIZE+1 db 0
listingArgument:	db 'list', 0
listingRequestedArgumentValue:		db '1', 0


; the input file
inputBufferIsAllocated:	db 0
inputSegment:	dw 0
inputOffset:	dw 0

; the output buffer
outputBufferIsAllocated:	db 0
outputSegment:		dw 0
outputOffset:		dw 0
outputSize:			dw 0

; the listing buffer
listingBufferIsAllocated:	db 0
listingSegment:		dw 0
listingOffset:		dw 0
listingSize:		dw 0

fileNotFound:	db 'Error: input file not found', 0
usageString: 	db 13, 10
				db 'Example usage:    ASM [file=example.asm]', 13, 10
				db '            or    ASM [file=example.asm] [list=1]', 13, 10
				db '                  (will write listing to example.lst)', 13, 10
				db 0

couldNotAllocateListingBuffer:	db 'Could not allocate listing buffer', 0
couldNotAllocateOutputBuffer:	db 'Could not allocate output buffer', 0
unknownError:		db 13, 10, 'Error: file writing failed for an unknown reason', 0
diskFull:			db 13, 10, 'Error: disk is full', 0
maxFilesReached:	db 13, 10, 'Error: maximum number of files on disk has already been reached', 0
writingOutputFile:	db 13, 10, 'Writing binary file ', 0
writingListingFile:	db 13, 10, 'Writing listing file ', 0

introString:	db 'Snowdrop OS x86 Assembler (written by Sebastian Mihai)', 0

	
start:
	mov si, introString
	int 80h
	
	; look for "file" argument
	call read_file_name_argument		; AX := 0 when not found or invalid
	cmp ax, 0
	je incorrect_usage
	; fat12Filename is assumed to have been filled in
	
	; allocate memory to load the file
	call common_task_allocate_memory_or_exit	; BX := allocated segment
	mov word [cs:inputSegment], bx			; store it
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
	; file has now been loaded successfully
	
	; allocate memory for the output binary
	int 91h									; BX := allocated segment
	cmp ax, 0
	jne output_segment_not_allocated
	
	mov word [cs:outputSegment], bx			; store it
	mov word [cs:outputOffset], 0
	mov byte [cs:outputBufferIsAllocated], 1
	
	; fill segment with zeroes
	push es
	mov cx, 65535
	mov di, 0
	mov es, bx
	mov al, 0
	rep stosb								; store 0 at 0 through :FFFE
	stosb									; store 0 at :FFFF
	pop es
	
	mov ax, ASM_LOG_CONFIG_DIRECT_TO_VIDEO
	call asm_configure_logging
	
	; listing
	call check_listing
	cmp ax, 0
	jne after_listing_config
	
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
	
	mov ds, word [cs:listingSegment]
	mov si, word [cs:listingOffset]
	call asm_configure_listing
	
after_listing_config:
	mov ds, word [cs:inputSegment]
	mov si, word [cs:inputOffset]			; DS:SI := input file
	
	mov es, word [cs:outputSegment]
	mov di, word [cs:outputOffset]			; ES:DI := output buffer
	call asm_run
			; AX - 0 when run was not successful, other value otherwise
			; CX - count of bytes written to output buffer, when successful
	mov word [cs:outputSize], cx
	cmp ax, 0
	je exit									; error while assembling
	
	; write output file to disk
	push cs
	pop ds
	mov si, writingOutputFile
	int 80h
	
	mov si, fat12Filename					; DS:SI := input file name
	mov byte [ds:si+8], 'A'					; rename to [input].APP
	mov byte [ds:si+9], 'P'
	mov byte [ds:si+10], 'P'
	
	push cs
	pop es
	mov di, output8p3Filename
	int 0B3h								; convert to 8.3
	push si
	mov si, output8p3Filename
	int 80h
	pop si
	
	mov es, word [cs:outputSegment]
	mov di, word [cs:outputOffset]			; ES:DI := output buffer
	mov cx, word [cs:outputSize]
	int 9Dh									; write file
	
	cmp ax, 1
	je max_files_reached
	cmp ax, 2
	je disk_full
	cmp ax, 0
	jne unknown_error
	; write succeeded

	cmp byte [cs:listingBufferIsAllocated], 0
	je done
	
	; write listing
	mov ds, word [cs:listingSegment]
	mov si, word [cs:listingOffset]
	int 0A5h								; BX := listing length
	mov word [cs:listingSize], bx
	
	push cs
	pop ds
	mov si, writingListingFile
	int 80h
	
	mov si, fat12Filename					; DS:SI := input file name
	mov byte [ds:si+8], 'L'					; rename to [input].LST
	mov byte [ds:si+9], 'S'
	mov byte [ds:si+10], 'T'
	
	push cs
	pop es
	mov di, listing8p3Filename
	int 0B3h								; convert to 8.3
	push si
	mov si, listing8p3Filename
	int 80h
	pop si
	
	mov es, word [cs:listingSegment]
	mov di, word [cs:listingOffset]			; ES:DI := listing buffer
	mov cx, word [cs:listingSize]
	int 9Dh									; write file
	
	cmp ax, 1
	je max_files_reached
	cmp ax, 2
	je disk_full
	cmp ax, 0
	jne unknown_error
	; write succeeded

done:
	jmp exit

	
unknown_error:
	push cs
	pop ds
	mov si, unknownError
	int 80h
	jmp exit

disk_full:
	push cs
	pop ds
	mov si, diskFull
	int 80h
	jmp exit
	
max_files_reached:
	push cs
	pop ds
	mov si, maxFilesReached
	int 80h
	jmp exit
	
listing_segment_not_allocated:
	push cs
	pop ds
	mov si, couldNotAllocateListingBuffer
	int 80h
	jmp exit
	
output_segment_not_allocated:
	push cs
	pop ds
	mov si, couldNotAllocateOutputBuffer
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
	
	cmp byte [cs:outputBufferIsAllocated], 0
	je deallocate_memory_after_output_dealloc
	
	mov bx, word [cs:outputSegment]
	int 92h						; deallocate
	mov byte [cs:outputBufferIsAllocated], 0
	
deallocate_memory_after_output_dealloc:

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


; Checks whether a listing file was requested
; 
; input:
;		none
; output:
;		AX - 0 when a listing file was requested, other value otherwise	
check_listing:
	push ds
	push es
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, listingArgument
	mov di, argumentBuffer
	int 0BFh

	mov si, listingRequestedArgumentValue
	int 0BDh						; compare strings
	
	pop di
	pop si
	pop es
	pop ds
	ret


%include "common\assembler\asmmain.asm"
%include "common\args.asm"
%include "common\tasks.asm"

argumentBuffer:
