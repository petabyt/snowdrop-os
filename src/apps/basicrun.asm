;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BASICRUN app.
; It runs the Snowdrop OS BASIC interpreter on the specified BASIC source
; code file.
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

allocatedSegment:	dw 0
fat12Filename:		times 20 db 0	; input file name in FAT12 format

messageBadFileArgument:
	db 13, 10
	db 'Snowdrop OS BASIC Runner usage:   BASICRUN [file=myprog.bas]', 13, 10
	db 0
messageCouldNotLoadFile:
	db 13, 10
	db 'Could not load specified file', 13, 10
	db 0
	
errorCouldNotAllocateDynMemSegment:	db 13, 10, 'Error: could not allocate dynamic memory segment', 13, 10, 0

dynamicMemorySegment:	dw 0	; used by BASIC, and also by buffer T used when
								; transferring bytes:
								;   virtual display -> buffer T -> rendered seg
DYNAMIC_MEMORY_TOTAL_SIZE	equ 65500


start:
	call common_task_allocate_memory_or_exit	; BX := segment
	mov word [cs:allocatedSegment], bx

	; allocate dynamic memory segment
	int 91h						; BX := allocated segment
	cmp ax, 0
	jne message_exit_and_deallocate_first
										; we couldn't allocate third
	mov word [cs:dynamicMemorySegment], bx			; store it
	
	; initialize dynamic memory
	mov ds, bx
	mov si, 0									; DS:SI := start of dynamic mem
	mov ax, 0 + DYNAMIC_MEMORY_TOTAL_SIZE		; size
	call common_memory_initialize
	cmp ax, 0
	je exit_and_deallocate_all		; this shouldn't really happen, since
									; we've just allocated this segment
	
	; fill segment with zeroes
	mov bx, word [cs:allocatedSegment]
	mov cx, 65535
	mov di, 0
	mov es, bx

	mov al, 0
	rep stosb								; store 0 at 0 through :FFFE
	stosb									; store 0 at :FFFF

	call common_args_read_file_file_arg		; DS:SI := pointer to value of
											; "file" program argument
	cmp ax, 0					; error?
	jne start_got_file			; no
	; print error message and exit
	push cs
	pop ds
	mov si, messageBadFileArgument
	int 80h
	jmp exit_and_deallocate_all
	
start_got_file:
	; here, DS:SI contains the file name in 8.3 format
	push cs
	pop es
	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	push cs
	pop ds
	; load source file
	mov si, fat12Filename
	push word [cs:allocatedSegment]
	pop es
	mov di, 0					; load file to [allocatedSegment:0]
	int 81h						; AL := 0 when successful, CX := file size
	cmp al, 0
	je start_loaded_file	; success
	
	; file could not be loaded
	mov si, messageCouldNotLoadFile
	int 80h
	jmp exit_and_deallocate_all
	
start_loaded_file:
	; NOTE: since we zeroed out the entire program text segment, the program
	; text string is properly terminated

	; file has been loaded, so we can start interpretation
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	int 0A0h					; clear screen
	
	push word [cs:allocatedSegment]
	pop ds
	mov si, 0					; DS:SI := program text
	mov ax, BASIC_GUI_FLAG_SHOW_STATUS_ON_SUCCESS | BASIC_GUI_FLAG_SHOW_STATUS_ON_ERROR | BASIC_GUI_FLAG_WAIT_KEY_ON_STATUS
	call basic_gui_entry_point
								; interpret the loaded BASIC program text
	jmp exit_and_deallocate_all	; success
	
message_exit_and_deallocate_first:
	push cs
	pop ds
	mov si, errorCouldNotAllocateDynMemSegment
	int 80h
	jmp exit_and_deallocate_first
								
exit_and_deallocate_all:
	mov bx, word [cs:dynamicMemorySegment]
	int 92h						; free memory
exit_and_deallocate_first:
	mov bx, word [cs:allocatedSegment]
	int 92h						; free memory
	
	int 95h						; exit


%include "common\args.asm"
%include "common\tasks.asm"
%include "common\basic\basic.asm"
%include "common\memory.asm"
