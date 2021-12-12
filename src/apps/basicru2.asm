;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BASICRUN app.
; Version 2.
; It runs the Snowdrop OS BASIC interpreter on the specified BASIC source
; code file.
;
; This version relies on a runtime library (RTL) to invoke the interpreter,
; rather than packaging it into the executable.
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

sourceSegment:	dw 0
fat12Filename:		times 20 db 0	; input file name in FAT12 format

messageBadFileArgument:
	db 13, 10
	db 'Snowdrop OS BASIC Runner usage:   BASICRU2 [file=myprog.bas]', 13, 10
	db 0
messageCouldNotLoadFile:
	db 13, 10
	db 'Could not load specified file', 13, 10
	db 0
	
errorCouldNotAllocateDynMemSegment:	db 13, 10, 'Error: could not allocate dynamic memory segment', 13, 10, 0

dynamicMemorySegment:	dw 0	; used by BASIC

DYNAMIC_MEMORY_TOTAL_SIZE	equ 65500

rtlFilename:		db 'BASIC.RTL', 0
rtlNotFound:		db 'Runtime library BASIC.RTL was not found', 13, 10, 0
rtlNoMemory:		db 'Not enough memory to load runtime library BASIC.RTL', 13, 10, 0

rtlBasicStartFunctionName:	db 'rtl_basic_gui_entry_point', 0
rtlFunctionNotFound:	db 'Function rtl_basic_gui_entry_point not found in BASIC.RTL', 13, 10, 0

rtlMemoryFunctionName:	db 'rtl_memory_initialize', 0
rtlMemoryFunctionNotFound:	db 'Function rtl_memory_initialize not found in BASIC.RTL', 13, 10, 0

rtlHandle:			dw 0


start:
	call common_task_allocate_memory_or_exit	; BX := segment
	mov word [cs:sourceSegment], bx
	
	; fill source segment with zeroes
	mov bx, word [cs:sourceSegment]
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
	jmp exit
	
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
	push word [cs:sourceSegment]
	pop es
	mov di, 0					; load file to [sourceSegment:0]
	int 81h						; AL := 0 when successful, CX := file size
	cmp al, 0
	je start_loaded_file	; success
	
	; file could not be loaded
	mov si, messageCouldNotLoadFile
	int 80h
	jmp exit
	
start_loaded_file:
	; NOTE: since we zeroed out the entire program text segment, the program
	; text string is properly terminated

	; load BASIC runtime library (RTL)
	push cs
	pop ds
	mov si, rtlFilename
	call common_rtl_load		; BX := RTL handle
	mov word [cs:rtlHandle], bx	; save it
	cmp ax, 2
	je start_interpreter__rtl_not_found
	cmp ax, 3
	je start_interpreter__rtl_not_found
	cmp ax, 0
	je start_interpreter_rtl_loaded
	jmp exit	; unknown error
	
start_interpreter_rtl_loaded:
	; here, BX = RTL handle
	
	; lookup functions
	mov ax, word [cs:rtlHandle]	; AX := RTL handle
	mov si, rtlBasicStartFunctionName
	call common_rtl_lookup
	cmp ax, 0
	je start_interpreter__rtl_function_not_found
	
	mov ax, word [cs:rtlHandle]	; AX := RTL handle
	mov si, rtlMemoryFunctionName
	call common_rtl_lookup
	cmp ax, 0
	je start_interpreter__rtl_memory_function_not_found
	
	; RTL was loaded and functions was verified
	
	; invoke memory allocation function of RTL
	call common_task_allocate_memory_or_exit	; BX := segment
	mov word [cs:dynamicMemorySegment], bx

	; initialize RTL's dynamic memory
	
	; setup RTL function invocation
	push cs								;
	push word rtlMemoryFunctionName		; pointer to function name
	push word [cs:rtlHandle]
	
	mov ds, [cs:dynamicMemorySegment]
	mov si, 0									; DS:SI := start of dynamic mem
	mov ax, 0 + DYNAMIC_MEMORY_TOTAL_SIZE		; size
	call common_rtl_invoke		; initialize RTL memory
	add sp, 6					; remove arguments from stack
	cmp ax, 0
	je exit		; this shouldn't really happen, since
									; we've just allocated the segment
	
	; file has been loaded, so we can start interpretation
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	int 0A0h					; clear screen
	
	; setup RTL function invocation
	push cs								;
	push word rtlBasicStartFunctionName	; pointer to function name
	push word [cs:rtlHandle]
	
	; setup RTL function arguments
	mov ds, word [cs:sourceSegment]
	mov si, 0					; DS:SI := program text
	mov ax, 00000111b
	
	call common_rtl_invoke		; interpret the loaded BASIC program text
	add sp, 6					; remove arguments from stack
	jmp exit	; success
	
start_interpreter__rtl_memory_function_not_found:
	push cs
	pop ds
	mov si, rtlMemoryFunctionNotFound
	int 80h
	jmp exit
	
start_interpreter__rtl_function_not_found:
	push cs
	pop ds
	mov si, rtlFunctionNotFound
	int 80h
	jmp exit
	
start_interpreter__rtl_not_found:
	push cs
	pop ds
	mov si, rtlNotFound
	int 80h
	jmp exit
	
start_interpreter__rtl_no_memory:
	push cs
	pop ds
	mov si, rtlNoMemory
	int 80h
	jmp exit
	
failed_dyn_memory_allocation:
	push cs
	pop ds
	mov si, errorCouldNotAllocateDynMemSegment
	int 80h							
exit:
	int 95h						; exit


%include "common\args.asm"
%include "common\tasks.asm"
%include "common\rtl.asm"
%include "common\memory.asm"
