;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The base routines to be included in every runtime library (RTL).
; It is expected that this file be included at the beginning of each RTL.
;
; It contains the RTL-side part of the RTL contract and facilities.
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop runtime library (RTL) contract:
;	
; The RTL base must:
;   - place consumer-facing calls ("invoke", "lookup", etc.) must
;     reside at known offsets
;   - use retf to return from all of its consumer-facing calls
;   - not take FLAGS as input or return FLAGS as output, for any of its calls
;   - RTL "invoke" entry point must add 2 to SP upon entry (this adds small
;     boilerplate, with the benefit that an extra register is available to 
;     be used as input or output)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16						; the CPU is assumed to function in 16-bit mode
	org 0						; Files are loaded at offset 0 by the caller

_RTL_LOOKUP_OFFSET		equ 100h	; offset of "lookup" entry point
_RTL_INVOKE_OFFSET		equ 0		; offset of "invoke" entry point


; Invokes a RTL function.
; Preserves no registries, to accommodate return values from invoked function.
;
; Note: since this function is expected to be called inter-segment,
;       both segment and offset of return address are on stack upon entering
; Note: this function expects cdecl calling convention (caller cleans up stack)
; Note: behaviour is undefined if no function with the specified name exists
;       as such, consumers should ensure such a function exists prior to
;       invocation
;
; Must start at offset _RTL_INVOKE_OFFSET
;
; input:
;		(assumes stack adjustment boilerplate has been executed)
;		[SS:SP+0] = return address offset (NOT AN INPUT)
;		[SS:SP+2] = return address segment (NOT AN INPUT)
;		[SS:SP+4] = DO NOT USE (NOT AN INPUT)
;		[SS:SP+6] = DO NOT USE (NOT AN INPUT)
;
;		[SS:SP+8] = offset of pointer to RTL function name
;		[SS:SP+10] = segment of pointer to RTL function name
;		(registers as needed by invoked function)
; output:
;		none
rtl_invoke:
	; ------- IMPORTANT - RTL "invoke" entry point must do this first ---------
	add sp, 2					; tightly coupled with RTL interface
	; -------------------------------------------------------------------------
	
	push si
	
	push ax
	push ds						; save input
	
	push bp
	mov bp, sp
	add bp, 8					; move to where SP used to be
	mov ds, word [ss:bp+10]
	mov si, word [ss:bp+8]		; DS:SI := pointer to RTL function name
	pop bp

	call _rtl_lookup_by_name	; lookup function by name
								; SI := function offset
	cmp ax, 0					; [1] did we find the function?
	
	pop ds
	pop ax						; restore input
	
	; stack:
	;     [SP+0]: input SI
	
	je rtl_invoke_done			; [1] NOOP when function not found
	
	; stack:
	;     [SP+0]: input SI

	push word rtl_invoke_return_address
	push si
	
	; stack:
	;     [SP+0]: function offset
	;     [SP+2]: "back to here" offset
	;     [SP+4]: input SI
	
	push bp
	
	; stack:
	;     [SP+0]: input BP
	;     [SP+2]: function offset
	;     [SP+4]: "back to here" offset
	;     [SP+6]: input SI
	
	mov bp, sp
	mov si, word [ss:bp+6]		; restore input
	pop bp
	
	; stack:
	;     [SP+0]: function offset
	;     [SP+2]: "back to here" offset
	;     [SP+4]: input SI
	
	ret							; "call" function
	
rtl_invoke_return_address:
	; stack:
	;     [SP+0]: input SI

rtl_invoke_done:
	add sp, 2					; clear stack
	retf


times $$ + _RTL_LOOKUP_OFFSET - $ db 'A'
								; pad to "lookup" entry point


; Checks whether this RTL contains a function
; with the specified name
;
; Must start at offset _RTL_LOOKUP_OFFSET
;
; input:
;	 DS:SI - pointer to function name
; output:
;		AX - 0 when the function does not exist, other value otherwise
rtl_lookup:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	push bp
	
	call _rtl_lookup_by_name	; AX := 0 when not found
								; SI := offset of function start
	pop bp
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	retf

	
; Looks up the offset of a function via its name
;
; input:
;	 DS:SI - pointer to function name
; output:
;		AX - 0 when function was not found, other value otherwise
;		SI - function start offset
_rtl_lookup_by_name:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	push bp
	
	push ds
	pop es
	mov di, si			; ES:DI := pointer to function name to look up
	
	push cs
	pop ds
	mov si, __rtl_function_registry
	
	cmp si, __rtl_function_registry_end
	jae _rtl_lookup_by_name_not_found		; empty registry or
											; starts after it ends
	; here, DS:SI points to first function name in registry
_rtl_lookup_by_name_loop:
	; here, DS:SI points to next function name in registry
	; here, ES:DI points to function name to check
	
	int 0BDh						; compare strings
	cmp ax, 0
	je _rtl_lookup_by_name_found
	
	int 0A5h						; BX := string length
	add si, bx						; move SI to terminator
	add si, 3						; move SI to beginning of next
									; function name
									
	cmp si, __rtl_function_registry_end
	jb _rtl_lookup_by_name_loop		; we still have functions to check
	; we're out of functions in the registry
_rtl_lookup_by_name_not_found:
	mov ax, 0						; failure
	jmp _rtl_lookup_by_name_done
	
_rtl_lookup_by_name_found:
	; here, DS:SI points to start of matched function name in registry
	int 0A5h						; BX := string length
	mov si, word [ds:si+bx+1]		; function offset is immediately after
									; string terminator
	mov ax, 1						; success
_rtl_lookup_by_name_done:
	pop bp
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	ret

db	'registry:'