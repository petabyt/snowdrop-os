;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains functionality for loading and interfacing with runtime
; libraries (RTL).
;
; It contains the consumer-side part of the RTL contract and facilities.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_RTL_
%define _COMMON_RTL_

rtlFat12FormattedName:			times 16 db 0

_RTL_LOAD_OFFSET		equ 0		; RTLs are loaded at this offset
_RTL_LOOKUP_OFFSET		equ 100h	; offset of "lookup" entry point
_RTL_INVOKE_OFFSET		equ 0		; offset of "invoke" entry point


; Loads a RTL from a file on disk
;
; input:
;	 DS:SI - pointer to 8.3 file name
; output:
;		AX - 0 when successful
;			 1 when file name is invalid
;			 2 when file not found
;			 3 when not enough memory to load RTL
;		BX - RTL handle when successful
common_rtl_load:
	push cx
	push dx
	push si
	push di
	push ds
	push es

	int 0A9h					; AX := 0 when file name is valid
	cmp ax, 0
	jne common_rtl_load__invalid_name
	
	push cs
	pop es
	mov di, rtlFat12FormattedName
	int 0A6h					; ES:DI := fat12 formatted name
	
	int 91h						; BX := new memory segment
	cmp ax, 0
	jne common_rtl_load__no_memory
	
	push cs
	pop ds
	mov si, rtlFat12FormattedName	; DS:SI := file name
	mov es, bx
	mov di, _RTL_LOAD_OFFSET	; ES:DI := destination buffer
	
	int 81h							; load RTL file
	cmp al, 0
	jne common_rtl_load__no_file	; file not found
	; RTL file loaded
	
	; here, BX = segment where RTL file was loaded
	;       (which we'll return as the RTL handle)
	
	mov ax, 0						; success
	jmp common_rtl_load_done
	
common_rtl_load__no_file:
	mov ax, 2
	jmp common_rtl_load_done
	
common_rtl_load__no_memory:
	mov ax, 3
	jmp common_rtl_load_done
	
common_rtl_load__invalid_name:
	mov ax, 1
	jmp common_rtl_load_done

common_rtl_load_done:	
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	ret


; Unloads an RTL from memory
;
; input:
;		AX - RTL handle
; output:
;		none
common_rtl_unload:
	pusha
	mov bx, ax
	int 92h			; free memory
	popa
	ret

	
; Checks whether the specified RTL contains a function
; with the specified name
;
; input:
;		AX - RTL handle
;	 DS:SI - pointer to function name
; output:
;		AX - 0 when the function does not exist, other value otherwise
common_rtl_lookup:
	; setup return address
	push cs
	push word common_rtl_lookup_return

	push ax								; invocation segment
	push word _RTL_LOOKUP_OFFSET	; invocation offset
	retf								; "call far"
common_rtl_lookup_return:
	ret
	

; Invokes a RTL function.
; Preserves no registries, to accommodate return values from invoked function.
;
; Note: since this function is expected to be called intra-segment, only
;       return offset is present on stack when it is entered
; Note: this function expects cdecl calling convention (caller cleans up stack)
; Note: behaviour is undefined if no function with the specified name exists
;       as such, consumers should ensure such a function exists prior to
;       invocation
;
; input:
;		[SS:SP+0] - return address (NOT AN INPUT)
;
;		[SS:SP+2] - RTL handle
;		[SS:SP+4] - offset of pointer to RTL function name
;		[SS:SP+6] - segment of pointer to RTL function name
;		(registers as needed by invoked function)
; output:
;		none
common_rtl_invoke:
	; setup return address
	push cs
	push word common_rtl_invoke_return
	
	; stack:
	;     [SP+0]: "back to here" offset
	;     [SP+2]: "back to here" segment
	
	; setup entry point for "invoke" for "call far"

	push bp							; save input BP

	; stack:
	;     [SP+0]: initial BP
	;     [SP+2]: "back to here" offset
	;     [SP+4]: "back to here" segment

	mov bp, sp						; need BP for addressing
									; BP := input_SP - 6
	; stack:
	;     [SP+0]: initial BP
	;     [SP+2]: "back to here" offset
	;     [SP+4]: "back to here" segment

	push word [ss:bp+8]				; segment (just use RTL handle)
	
	; stack:
	;     [SP+0]: RTL "invoke" entry point segment
	;     [SP+2]: initial BP
	;     [SP+4]: "back to here" offset
	;     [SP+6]: "back to here" segment
	
	mov bp, word [ss:bp]			; restore input BP

common_rtl_invoke_call_far:
	push word _RTL_INVOKE_OFFSET	; offset
	
	; stack:
	;     [SS:SP+0] = RTL "invoke" entry point offset
	;     [SS:SP+2] = RTL "invoke" entry point segment
	;     [SS:SP+4] = initial BP (EXPECTED TO BE REMOVED BY BOILERPLATE)
	;     [SS:SP+6] = "back to here" offset
	;     [SS:SP+8] = "back to here" segment
	;     [SS:SP+10] = "return to caller" address (offset only)
	;     [SS:SP+12] = RTL handle
	;     [SS:SP+14] = offset of pointer to RTL function name
	;     [SS:SP+16] = segment of pointer to RTL function name

	retf			; "call far"
	; we have now returned from the RTL
common_rtl_invoke_return:
	ret


%endif
