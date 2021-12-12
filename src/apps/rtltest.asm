;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The RTLTEST app.
; This app shows how to interface with runtime libraries (RTL) by loading
; a test RTL and invoking one of its functions.
;
; It also serves as a regression test, as both consumer and RTL assert
; output and input register values, respectively.
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

	functionArgName:		db 'function', 0
	functionArgValueBuffer:	times 257 db 0

	loadedRtlMessage:		db 'consumer: loaded runtime library (RTL) into memory', 13, 10, 0
	invokingRtlMessage:		db 'consumer: invoking RTL function', 13, 10, 0
	assertingOutputMessage:	db 'consumer: asserting output of RTL function', 13, 10, 0
	returnedMessage:		db 'consumer: returned from RTL function', 13, 10, 0
	okMessage:				db 'consumer: success', 13, 10, 0
	lookupMessage:			db 'consumer: looking up function (expects myFunction1)', 13, 10, 0
	lookedUpMessage:		db 'consumer: successfully looked up function', 13, 10, 0
	
	usageMessage:			db 'consumer: ERROR: usage:    RTLTEST [file=somertl.rtl] [function=somefunc]', 13, 10, 0
	mismatchMessage:		db 'consumer: ERROR: output register value mismatch', 13, 10, 0
	invalidFilenameMessage:	db 'consumer: ERROR: invalid 8.3 filename', 13, 10, 0
	fileNotFoundMessage:	db 'consumer: ERROR: RTL file not found (expects TEST.RTL)', 13, 10, 0
	noMemoryMessage:		db 'consumer: ERROR: insufficient memory to load RTL file', 13, 10, 0
	unknownErrorMessage:	db 'consumer: ERROR: unknown error occurred', 13, 10, 0
	unloadFailedMessage:	db 'consumer: ERROR: load-unload-load did not use the same segment', 13, 10, 0
	functionNotFoundMessage:	db 'consumer: ERROR: function not found in RTL', 13, 10, 0


start:
	; start with a load-unload-load test, asserting that the second load
	; loads into the same segment, demonstrating that unload worked
	
	call common_args_read_file_file_arg
	cmp ax, 0
	jne got_file_arg
	
	push cs
	pop ds
	mov si, usageMessage
	int 80h
	int 95h						; exit
	
got_file_arg:
	; here DS:SI = pointer to RTL file name
	call common_rtl_load		; BX := RTL handle
	cmp ax, 0
	je loaded
	; RTL not loaded successfully
	push cs
	pop ds						; restore DS
	
	cmp ax, 1
	je _invalid_filename
	cmp ax, 2
	je _file_not_found
	cmp ax, 3
	je _no_memory
	
	mov si, unknownErrorMessage
	int 80h
	int 95h						; exit
	
loaded:
	; unload it and assert that next time it loads, it has the same handle
	mov dx, bx					; DX := RTL handle
	mov ax, bx					; AX := RTL handle
	call common_rtl_unload

	call common_rtl_load		; BX := RTL handle
	
	push cs
	pop ds						; restore DS
	
	cmp ax, 0
	je loaded2
	; RTL not loaded successfully
	
	cmp ax, 1
	je _invalid_filename
	cmp ax, 2
	je _file_not_found
	cmp ax, 3
	je _no_memory
	
	mov si, unknownErrorMessage
	int 80h
	int 95h						; exit

loaded2:
	; here, DX = first RTL handle (it has been unloaded)
	; here, BX = second RTL handle
	cmp bx, dx
	je loaded_and_verified		; after unload, second RTL should
								; have been loaded where first used to be
	; it isn't
	mov si, unloadFailedMessage
	int 80h
	int 95h						; exit
	
loaded_and_verified:
	mov si, loadedRtlMessage
	int 80h
	
	mov si, lookupMessage
	int 80h
	
	mov si, functionArgName		; DS:SI := arg name
	mov di, functionArgValueBuffer	; ES:DI := arg value buffer
	int 0BFh					; read argument value
	cmp ax, 0
	jne got_function_argument	; found
	; not found
	
	push cs
	pop ds
	mov si, usageMessage
	int 80h
	int 95h						; exit
	
got_function_argument:
	mov ax, bx					; AX := RTL handle
	mov si, functionArgValueBuffer
	call common_rtl_lookup
	cmp ax, 0
	jne looked_up
	
	; function was not found
	
	push cs
	pop ds						; restore DS
	mov si, functionNotFoundMessage
	int 80h
	int 95h						; exit
	
looked_up:	
	mov si, lookedUpMessage
	int 80h
	mov si, invokingRtlMessage
	int 80h
	
	push cs								;
	push word functionArgValueBuffer	; pointer to function name
	push bx						; RTL handle
	
	; these values are asserted in the test RTL
	mov ax, 466Ah
	mov ds, ax
	mov ax, 577Bh
	mov es, ax
	mov ax, 688Ch
	mov fs, ax
	mov ax, 799Dh
	mov gs, ax
	
	mov ax, 0102h
	mov bx, 0304h
	mov cx, 0506h
	mov dx, 0708h
	mov si, 1337h
	mov di, 2448h
	mov bp, 3559h
	
	call common_rtl_invoke
	add sp, 6					; remove arguments from stack
	
	; assert register values returned by RTL function
	
	pusha
	push ds
	push cs
	pop ds
	mov si, returnedMessage
	int 80h
	mov si, assertingOutputMessage
	int 80h
	pop ds
	popa
	
	cmp ax, 0F1Eh
	jne _output_register_mismatch
	cmp bx, 2D3Ch
	jne _output_register_mismatch
	cmp cx, 4B5Ah
	jne _output_register_mismatch
	cmp dx, 6978h
	jne _output_register_mismatch
	cmp si, 8796h
	jne _output_register_mismatch
	cmp di, 0A5B4h
	jne _output_register_mismatch
	cmp bp, 0C3D2h
	jne _output_register_mismatch
	
	push ax								; [1]
	
	mov ax, ds
	cmp ax, 0FEDCh
	jne _output_register_mismatch
	
	mov ax, es
	cmp ax, 0BA98h
	jne _output_register_mismatch
	
	mov ax, fs
	cmp ax, 7654h
	jne _output_register_mismatch
	
	mov ax, gs
	cmp ax, 3210h
	jne _output_register_mismatch
	
	push cs
	pop ds
	mov si, okMessage
	int 80h
	int 95h						; exit
	
_invalid_filename:
	mov si, invalidFilenameMessage
	int 80h
	int 95h						; exit
	
_file_not_found:
	mov si, fileNotFoundMessage
	int 80h
	int 95h						; exit
	
_no_memory:
	mov si, noMemoryMessage
	int 80h
	int 95h						; exit	
	
_output_register_mismatch:
	pop ax						; [1]
	
	pusha
	push ds
	push cs
	pop ds
	mov si, mismatchMessage
	int 80h
	pop ds
	popa
	int 0B4h
	jmp $					; lock up on register mismatch

%include "common\rtl.asm"
%include "common\args.asm"
