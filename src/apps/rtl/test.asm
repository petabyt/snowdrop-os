;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The TEST runtime library (RTL).
; This is a test RTL.
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop runtime library (RTL) contract:
;
; The RTL can assume:
;   - it can store state - it follows that it will be loaded once for
;     each consumer application
;
; The RTL must:
;   - include the routines base code as the first statement
;   - not take FLAGS as input or return FLAGS as output, for any of its calls
;   - define __rtl_function_registry (used by base to lookup functions) as
;     follows:
;         zero-terminated function name, 2-byte function start offset
;         zero-terminated function name, 2-byte function start offset
;         etc. for each function available to consumers
;   - define __rtl_function_registry_end immediately after
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	%include "rtl\base.asm"

	; this is required by base code to lookup and invoke functions on us
	; it is how we expose functions to consumers
__rtl_function_registry:
	db 'dummyFunctionEntry', 0	; function name
	dw myFunction1				; function offset
	
	db 'myFunction1', 0		; function name
	dw myFunction1			; function offset
__rtl_function_registry_end:
		
	mismatchMessage:		db 'RTL: ERROR: input register value mismatch', 13, 10, 0
	startingMessage:		db 'RTL: entered invoked function', 13, 10, 0
	assertingMessage:		db 'RTL: asserting input from consumer', 13, 10, 0
	returningMessage:		db 'RTL: returning to consumer', 13, 10, 0	
	

; This test RTL function asserts known values passed in via
; registers and sets known output values in registers, before returning.
;
; input:
;		known input values in all registers
; output:
;		known output values in all registers
myFunction1:
	pusha
	push ds
	push cs
	pop ds
	mov si, startingMessage
	int 80h
	mov si, assertingMessage
	int 80h
	pop ds
	popa
	
	; assert register values from caller
	
	cmp ax, 0102h
	jne myFunction1_mismatch
	cmp bx, 0304h
	jne myFunction1_mismatch
	cmp cx, 0506h
	jne myFunction1_mismatch
	cmp dx, 0708h
	jne myFunction1_mismatch
	cmp si, 1337h
	jne myFunction1_mismatch
	cmp di, 2448h
	jne myFunction1_mismatch
	cmp bp, 3559h
	jne myFunction1_mismatch
	
	push ax								; [1]
	
	mov ax, ds
	cmp ax, 466Ah
	jne myFunction1_mismatch
	
	mov ax, es
	cmp ax, 577Bh
	jne myFunction1_mismatch
	
	mov ax, fs
	cmp ax, 688Ch
	jne myFunction1_mismatch
	
	mov ax, gs
	cmp ax, 799Dh
	jne myFunction1_mismatch
	
	; success
	pop ax								; [1]
	
	; these values are asserted in the test consumer application
	mov ax, 0FEDCh
	mov ds, ax
	mov ax, 0BA98h
	mov es, ax
	mov ax, 7654h
	mov fs, ax
	mov ax, 3210h
	mov gs, ax
	
	mov ax, 0F1Eh
	mov bx, 2D3Ch
	mov cx, 4B5Ah
	mov dx, 6978h
	mov si, 8796h
	mov di, 0A5B4h
	mov bp, 0C3D2h
	
	pusha
	push ds
	push cs
	pop ds
	mov si, returningMessage
	int 80h
	pop ds
	popa
	
	ret
	
myFunction1_mismatch:
	pop ax								; [1]
	
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
	