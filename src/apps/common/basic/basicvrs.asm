;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains string variable management functionality 
; for Snowdrop OS's BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_VARS_STRING_
%define _COMMON_BASIC_VARS_STRING_

SVAR_NONE 					equ 0FFFFh ; word value which marks a slot as empty
									   ; if this value is changed, inspect
									   ; array clear function
SVAR_IN_USE 				equ 0	; indicates a slot is in use

SVAR_ENTRY_SIZE_BYTES	equ 41
SVAR_COUNT 				equ 40
SVAR_TOTAL_SIZE_BYTES 	equ SVAR_COUNT*SVAR_ENTRY_SIZE_BYTES ; in bytes

SVAR_VALUE_MAX_LENGTH	equ 156


; format of a string variable table entry:
; bytes
;     0-1 whether this variable slot is available
;    2-34 name (zero-terminated)
;   35-36 segment of pointer to value buffer
;   37-38 offset of pointer to value buffer
;   39-40 unused


; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
basicStringVarsStorage: times SVAR_TOTAL_SIZE_BYTES db 0
basicStringVarsStorageEnd:


; Allocates a new string variable
;
; input:
;	 DS:SI - pointer to name string, zero-terminated
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - variable handle
basicStringVars_allocate:
	pushf
	push es
	push di
	push cx
	push si
	
	call basicStringVars_find_empty_slot
	jc basicStringVars_allocate_fail		; none found, so just return
	
	push ds
	pop es
	mov di, si								; ES:DI := variable name
	
	mov ax, SVAR_VALUE_MAX_LENGTH
	call common_memory_allocate				; DS:SI := new chunk
	cmp ax, 0
	je basicStringVars_allocate_fail
	mov byte [ds:si], 0						; empty string initially
	
	mov word [cs:basicStringVarsStorage+bx], SVAR_IN_USE	; mark slot
	
	mov word [cs:basicStringVarsStorage+bx+35], ds
	mov word [cs:basicStringVarsStorage+bx+37], si	; store pointer to chunk

	; save variable name
	push es
	pop ds
	mov si, di								; DS:SI := variable name
	
	cld
	mov cx, BASIC_VAR_NAME_MAX_LENGTH
	push cs
	pop es
	mov di, basicStringVarsStorage
	add di, bx						; ES:DI := pointer to variable slot
	add di, 2						; ES:DI := pointer to variable name
	rep movsb						; copy name
	mov byte [es:di], 0				; terminator
	
	pop si
	pop cx
	pop di
	pop es
	popf
	clc								; success
	ret
basicStringVars_allocate_fail:
	pop si
	pop cx
	pop di
	pop es
	popf
	stc								; failure
	ret


; Deletes a string variable
;
; input:
;		AX - byte offset of variable
; output:
;		none	
basicStringVars_delete:
	push bx
	mov bx, ax
	mov word [cs:basicStringVarsStorage+bx], SVAR_NONE
	pop bx
	ret
	
	
; Sets the value of a string variable
;
; input:
;		AX - byte offset of variable
;	 DS:SI - pointer to string value
; output:
;		none
basicStringVars_set_value:
	pusha
	pushf
	
	mov di, basicStringVarsStorage
	add di, ax						; ES:DI := pointer to variable
	
	push word [cs:di+35]
	pop es
	mov di, word [cs:di+37]			; ES:DI := pointer to value buffer
	
	cld
	mov cx, SVAR_VALUE_MAX_LENGTH
	rep movsb						; copy value
	mov byte [es:di], 0				; terminator
	
	popf
	popa
	ret


; Gets the value of a string variable
;
; input:
;		AX - byte offset of variable
;	 ES:DI - pointer to buffer where variable value will be output
; output:
;		none
basicStringVars_get_value:
	pusha
	pushf
	push ds
	
	cld
	
	mov si, basicStringVarsStorage
	add si, ax							; DS:SI := pointer to variable
	cmp word [cs:si], SVAR_NONE			; is this slot in use?
	je basicStringVars_get_value_done	; no, so we're done
	
	push word [cs:si+35]
	pop ds
	mov si, word [cs:si+37]				; DS:SI := pointer to value buffer
	
	int 0A5h							; BX := string length
	mov cx, bx
	rep movsb							; copy value into buffer

basicStringVars_get_value_done:
	mov byte [es:di], 0					; add terminator
	
	pop ds
	popf
	popa
	ret
	
	
; Gets the handle of a string variable by name
;
; input:
;	 DS:SI - pointer to name string, zero-terminated
; output:
;	 CARRY - set when variable was not found, clear otherwise
;		AX - handle (byte offset into array), if found
basicStringVars_get_handle:
	push es
	push bx
	push di
	
	push cs
	pop es
	
	mov bx, basicStringVarsStorage
basicStringVars_get_handle_loop:
	cmp bx, basicStringVarsStorageEnd			; are we past the end?
	jae basicStringVars_get_handle_not_found	; yes, so it's not found

	cmp word [cs:bx], SVAR_NONE					; is this slot empty?
	je basicStringVars_get_handle_loop_next	; yes, so skip it
	; slot is full, compare names
	
	mov di, bx					; ES:DI := pointer to variable slot
	add di, 2					; ES:DI := pointer to variable name
	int 0BDh					; compare strings
	cmp ax, 0					; equal?
	je basicStringVars_get_handle_found	; yes, this is the variable
	
basicStringVars_get_handle_loop_next:
	add bx, SVAR_ENTRY_SIZE_BYTES
	jmp basicStringVars_get_handle_loop

basicStringVars_get_handle_found:
	mov ax, bx
	sub ax, basicStringVarsStorage		; AX := handle (byte offset)
	clc
	jmp basicStringVars_get_handle_done
basicStringVars_get_handle_not_found:
	stc
basicStringVars_get_handle_done:
	pop di
	pop bx
	pop es
	ret
	
	
; Clears array by setting all elements to "empty"
;
; input:
;		none
; output:
;		none
basicStringVars_clear:
	pusha
	pushf
	push es
	
	push cs
	pop es
	
	mov cx, SVAR_TOTAL_SIZE_BYTES / 2
			; can never overrun array, and since each element is at least
			; 2 bytes long, it's either event (2 bytes per element), or
			; misses third or later byte in the last element (which is
			; still marked as "empty")
										
	mov di, basicStringVarsStorage	; ES:DI := pointer to array
	mov ax, SVAR_NONE				; mark each array element as "empty"
	cld
	rep stosw
	
	pop es
	popf
	popa
	ret


; Returns a byte offset of first empty slot in the array
;
; input:
;		none
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - byte offset (into array) of first empty slot, if one was found
basicStringVars_find_empty_slot:
	push si
	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, basicStringVarsStorage
	mov bx, 0				; offset of array slot being checked
basicStringVars_find_empty_slot_loop:
	cmp word [cs:si+bx], SVAR_NONE			; is this slot empty?
										; (are first two bytes SVAR_NONE?)
	je basicStringVars_find_empty_slot_done	; yes
	
	add bx, SVAR_ENTRY_SIZE_BYTES		; next slot
	cmp bx, SVAR_TOTAL_SIZE_BYTES		; are we past the end?
	jb basicStringVars_find_empty_slot_loop		; no
basicStringVars_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp basicStringVars_find_empty_slot_done
basicStringVars_find_empty_slot_done:
	pop si
	ret
	
	
; Shuts down the string variables module, performing clean-up as needed
;
; input:
;		none
; output:
;		none
basicStringVars_shutdown:
	call basicStringVars_deallocate_buffers
	ret

	
; Deallocates all buffers allocated by string variables
;
; input:
;		none
; output:
;		none
basicStringVars_deallocate_buffers:
	pusha
	push ds
	
	mov bx, basicStringVarsStorage
basicStringVars_deallocate_buffers_loop:
	cmp bx, basicStringVarsStorageEnd			; are we past the end?
	jae basicStringVars_deallocate_buffers_done	; yes, so it's not found

	cmp word [cs:bx], SVAR_NONE					; is this slot empty?
	je basicStringVars_deallocate_buffers_loop_next	; yes, so skip it
	; slot is full
	
	push word [cs:bx+35]
	pop ds
	mov si, word [cs:bx+37]						; DS:SI := value buffer
	call common_memory_deallocate

basicStringVars_deallocate_buffers_loop_next:
	add bx, SVAR_ENTRY_SIZE_BYTES
	jmp basicStringVars_deallocate_buffers_loop

basicStringVars_deallocate_buffers_done:
	pop ds
	popa
	ret
	

%endif
