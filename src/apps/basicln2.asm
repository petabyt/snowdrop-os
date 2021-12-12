;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BASICLN2 app.
; This is version 2 of the Snowdrop OS BASIC linker, used to create 
; standalone Snowdrop OS executable applications from BASIC source code.
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

	db 0E9h						; E9 = 16bit relative near jump
	dw start_linker-afterJmp	; "jmp start_linker"
								; (offset is relative to IP right after jmp)
afterJmp:

MAX_APP_FILE_SIZE	equ 64800	; leave some room for the stack
SAFETY_BUFFER_AFTER_PROGRAM_TEXT	equ 32

allocatedSegment:	dw 0
sourceFileSize:		dw 0
fat12DestinationFilename:	db '        APP', 0
eightPointThreeDestinationFilename:	times 20 db 0
fat12Filename:				times 20 db 0	; input file name in FAT12 format
rtlFilename:		db 'BASIC.RTL', 0
rtlNotFound:		db 'Runtime library BASIC.RTL was not found', 13, 10, 0
rtlNoMemory:		db 'Not enough memory to load runtime library BASIC.RTL', 13, 10, 0

rtlBasicStartFunctionName:	db 'rtl_basic_gui_entry_point', 0
rtlFunctionNotFound:	db 'Function rtl_basic_gui_entry_point not found in BASIC.RTL', 13, 10, 0

rtlMemoryFunctionName:	db 'rtl_memory_initialize', 0
rtlMemoryFunctionNotFound:	db 'Function rtl_memory_initialize not found in BASIC.RTL', 13, 10, 0

rtlHandle:			dw 0


messageSuccess1:
	db 13, 10
	db 'Read input file '
	db 0
messageSuccess2:
	db ' with size '
	db 0
messageSuccess3:
	db 13, 10
	db 'Done writing output file '
	db 0
messageBadFileArgument:
	db 13, 10
	db 'Snowdrop OS BASIC Linker', 13, 10
	db 'This application creates an executable .APP from a BASIC source code file.', 13, 10
	db 'Example usage (produces MYPROG.APP):    BASICLN2 [file=myprog.bas]', 13, 10
	db 0
messageCouldNotLoadFile:
	db 13, 10
	db 'Could not load specified file', 13, 10
	db 0
messageDiskFull:
	db 13, 10
	db 'Could not write output file: disk is full', 13, 10
	db 0
messageFileSlotsFull:
	db 13, 10
	db 'Could not write output file: maximum number of files reached', 13, 10
	db 0

dynamicMemorySegment:	dw 0	; used by BASIC, and also by buffer T used when
								; transferring bytes:
								;   virtual display -> buffer T -> rendered seg
DYNAMIC_MEMORY_TOTAL_SIZE	equ 65500
	
messageNewline:		db 13, 10, 0
messageFileTooLarge1:	db 13, 10, 'BASIC source file size cannot exceed ', 0
messageFileTooLarge2:	db ' bytes', 13, 10, 0

; this is the entry point when the app is invoked as a linker
start_linker:
	call common_task_allocate_memory_or_exit	; BX := segment
	mov word [cs:allocatedSegment], bx
	
	call common_args_read_file_file_arg		; DS:SI := pointer to value of
											; "file" program argument
	cmp ax, 0					; error?
	jne start_linker_got_file	; no
	; print error message and exit
	push cs
	pop ds
	mov si, messageBadFileArgument
	int 80h
	jmp start_linker_done
	
start_linker_got_file:
	; here, DS:SI contains the file name in 8.3 format
	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	push cs
	pop ds
	mov si, fat12Filename
	mov cx, 8
	mov di, fat12DestinationFilename
	rep movsb					; copy first 8 characters into destination
								; file name buffer
	; load source file
	mov si, fat12Filename
	push word [cs:allocatedSegment]
	pop es
	mov di, 0					; load file to [allocatedSegment:0]
	int 81h						; AL := 0 when successful, CX := file size
	mov word [cs:sourceFileSize], cx
	
	cmp al, 0
	je start_linker_loaded_file	; success
	; file could not be loaded
	mov si, messageCouldNotLoadFile
	int 80h
	jmp start_linker_done
	
start_linker_loaded_file:
	; file has been loaded
	; size of file cannot be larger than 
	; (MAX_APP_FILE_SIZE - size of THIS binary - SAFETY_BUFFER_AFTER_PROGRAM_TEXT)
	mov ax, MAX_APP_FILE_SIZE
	sub ax, endOfLinker
	sub ax, SAFETY_BUFFER_AFTER_PROGRAM_TEXT
	cmp word [cs:sourceFileSize], ax
	ja start_linker_file_too_large
	
	; source file is small enough
	; copy program source from allocated segment into this segment
	push cs
	pop es
	mov di, programText				; ES:DI := where we'll store program text
	push word [cs:allocatedSegment]
	pop ds
	mov si, 0						; DS:SI := allocatedSegment:0
	mov cx, word [cs:sourceFileSize]
	rep movsb						; copy entire program text
	
	mov al, 0						; add terminator so that program
	stosb							; text string is properly terminated
	
	push cs
	pop ds
	; here, DS = ES = CS
	
	; now modify my own initial jmp to jump into start_interpreter
	; instead of the default start_linker
	mov word [cs:1], start_interpreter-afterJmp
					; byte at offset 0 is the first byte of the jmp opcode
					; bytes at offset 1-2 are the near pointer of the jump
	mov cx, [cs:sourceFileSize]
	add cx, endOfLinker					; CX := file size
	add cx, SAFETY_BUFFER_AFTER_PROGRAM_TEXT  ; CX := file size + safety buffer
	
	mov si, fat12DestinationFilename	; DS:SI := filename
	mov di, 0							; ES:DI := CS:0 (file contents pointer)
	int 9Dh								; write file
	cmp ax, 2
	je start_linker_disk_full
	cmp ax, 1
	je start_linker_no_more_files
	; file was written
	
	mov si, fat12DestinationFilename
	mov di, eightPointThreeDestinationFilename
	int 0B3h							; covert FAT12 filename to 8.3 filename
	
	mov si, messageSuccess1
	int 80h
	call common_args_read_file_file_arg		; DS:SI := pointer to value of
											; "file" program argument
	int 80h
	mov si, messageSuccess2
	int 80h

	mov dx, 0
	mov ax, word [cs:sourceFileSize]	; DX:AX := 32bit file size
	mov cl, 4							; formatting option
	call common_text_print_number_to_hardware_screen
	
	mov si, messageSuccess3
	int 80h
	mov si, eightPointThreeDestinationFilename
	int 80h
	mov si, messageNewline
	int 80h
	jmp start_linker_done

start_linker_file_too_large:
	; here, AX = maximum size of source file
	mov si, messageFileTooLarge1
	int 80h
	
	mov dx, 0							; DX:AX := 32bit maximum source size
	mov cl, 4							; formatting option
	call common_text_print_number_to_hardware_screen
	
	mov si, messageFileTooLarge2
	int 80h
	jmp start_linker_done
	
start_linker_no_more_files:
	mov si, messageFileSlotsFull
	int 80h
	jmp start_linker_done
	
start_linker_disk_full:
	mov si, messageDiskFull
	int 80h
	jmp start_linker_done
	
start_linker_done:
	mov bx, word [cs:allocatedSegment]
	int 92h						; free memory
	
	int 95h						; exit



; this is the entry point of an app written by the linker
start_interpreter:
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
	jmp start_interpreter_exit	; unknown error
	
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
	
	mov ds, bx
	mov si, 0									; DS:SI := start of dynamic mem
	mov ax, 0 + DYNAMIC_MEMORY_TOTAL_SIZE		; size
	call common_rtl_invoke		; initialize RTL memory
	add sp, 6					; remove arguments from stack
	cmp ax, 0
	je start_interpreter_exit		; this shouldn't really happen, since
									; we've just allocated the segment
	
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	int 0A0h					; clear screen
	
	; setup RTL function invocation
	push cs								;
	push word rtlBasicStartFunctionName	; pointer to function name
	push word [cs:rtlHandle]
	
	; setup RTL function arguments
	push cs
	pop ds
	mov si, programText			; DS:SI := pointer to program
	mov ax, 00000110b
	
	call common_rtl_invoke		; interpret the inlined BASIC program text
	add sp, 6					; remove arguments from stack
	
	jmp start_interpreter_exit
	
	
start_interpreter__rtl_memory_function_not_found:
	push cs
	pop ds
	mov si, rtlMemoryFunctionNotFound
	int 80h
	jmp start_interpreter_exit
	
start_interpreter__rtl_function_not_found:
	push cs
	pop ds
	mov si, rtlFunctionNotFound
	int 80h
	jmp start_interpreter_exit
	
start_interpreter__rtl_not_found:
	push cs
	pop ds
	mov si, rtlNotFound
	int 80h
	jmp start_interpreter_exit
	
start_interpreter__rtl_no_memory:
	push cs
	pop ds
	mov si, rtlNoMemory
	int 80h
	jmp start_interpreter_exit
	
start_interpreter_exit:
	int 95h						; exit

%include "common\args.asm"
%include "common\tasks.asm"
%include "common\text.asm"
%include "common\rtl.asm"

endOfLinker:
programText:					; this is where the program text of the
								; linked BASIC program is loaded
