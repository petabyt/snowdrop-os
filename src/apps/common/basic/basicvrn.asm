;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains numeric variable management functionality 
; for Snowdrop OS's BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_VARS_NUMERIC_
%define _COMMON_BASIC_VARS_NUMERIC_

NVAR_NONE 					equ 0FFFFh ; word value which marks a slot as empty
									   ; if this value is changed, inspect
									   ; array clear function
NVAR_IN_USE 				equ 0	; indicates a slot is in use

NVAR_ENTRY_SIZE_BYTES	equ 50
NVAR_COUNT	 			equ 40
NVAR_TOTAL_SIZE_BYTES equ NVAR_COUNT*NVAR_ENTRY_SIZE_BYTES ; in bytes

NVAR_TYPE_REGULAR			equ 0
NVAR_TYPE_FOR_LOOP_COUNTER	equ 1

; format of a numeric variable table entry:
; bytes
;     0-1 whether this variable slot is available
;    2-34 name (zero-terminated)
;   35-36 value
;   37-37 type (0- regular, 1- for-loop counter)
;   38-39 (for-loop counter) near pointer into program text to immediately
;         after the FOR instruction which uses it as a counter
;   40-41 (for-loop counter) step value
;   42-43 (for-loop counter) inclusive end value
;   44-49 unused


; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
basicNumericVarsStorage: times NVAR_TOTAL_SIZE_BYTES db 0
basicNumericVarsStorageEnd:


; Allocates a new numeric variable
;
; input:
;	 DS:SI - pointer to name string, zero-terminated
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - variable handle
basicNumericVars_allocate:
	call basicNumericVars_find_empty_slot
	jc basicNumericVars_allocate_return		; none found, so just return
	
	pushf
	push es
	push di
	push cx
	push si
	mov word [cs:basicNumericVarsStorage+bx], NVAR_IN_USE	; mark slot
	
	mov word [cs:basicNumericVarsStorage+bx+35], 0	; initialize value to 0
	mov byte [cs:basicNumericVarsStorage+bx+37], NVAR_TYPE_REGULAR
	
	cld
	mov cx, BASIC_VAR_NAME_MAX_LENGTH
	push cs
	pop es
	mov di, basicNumericVarsStorage
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
basicNumericVars_allocate_return:
	ret

	
; Deletes a string variable
;
; input:
;		AX - byte offset of variable
; output:
;		none	
basicNumericVars_delete:
	push bx
	mov bx, ax
	mov word [cs:basicNumericVarsStorage+bx], NVAR_NONE
	pop bx
	ret
	
	
; Sets the value of a numeric variable
;
; input:
;		AX - byte offset of variable
;		BX - value to set
; output:
;		none
basicNumericVars_set_value:
	pusha
	
	mov si, basicNumericVarsStorage
	add si, ax							; SI := pointer to variable
	add si, 35							; SI := pointer to variable value
	mov word [cs:si], bx
	
	popa
	ret


; Sets type of the specified variable as "regular"	
;
; input:
;		AX - byte offset of variable
; output:
;		none
basicNumericVars_set_type_regular:
	pusha
	mov bx, ax							; BX := variable byte offset
	mov byte [cs:basicNumericVarsStorage+bx+37], NVAR_TYPE_REGULAR
	popa
	ret
	
	
; Sets type of the specified variable as "for-loop counter"
;
; input:
;		AX - byte offset of variable
; output:
;		none
basicNumericVars_set_type_for_loop_counter:
	pusha
	mov bx, ax							; BX := variable byte offset
	mov byte [cs:basicNumericVarsStorage+bx+37], NVAR_TYPE_FOR_LOOP_COUNTER
	popa
	ret
	
	
; Sets the for-loop parameters for the specified variable, which is meant
; to be used as a for-loop counter
;
; input:
;		AX - byte offset of variable
;		CX - for-loop inclusive end value
;		DX - for-loop step value
;		SI - near pointer into the program text to be used as the beginning
;			 of the for-loop iteration
; output:
;		none
basicNumericVars_set_for_loop_params:
	pusha
	
	mov bx, ax							; BX := variable byte offset
	
	mov word [cs:basicNumericVarsStorage+bx+38], si
	mov word [cs:basicNumericVarsStorage+bx+40], dx
	mov word [cs:basicNumericVarsStorage+bx+42], cx
	
	popa
	ret


; Gets the properties for the specified variable
;
; input:
;		AX - byte offset of variable
; output:
;		CX - for-loop inclusive end value
;		DX - for-loop step value
;		SI - near pointer into the program text to be used as the beginning
;			 of the for-loop iteration
;		BL - type
basicNumericVars_get_properties:
	push di
	
	mov di, basicNumericVarsStorage
	add di, ax							; CS:DI := pointer to variable
	
	mov bl, byte [cs:di+37]
	mov si, word [cs:di+38]
	mov dx, word [cs:di+40]
	mov cx, word [cs:di+42]
	
	pop di
	ret
	
	
; Gets the value of a numeric variable
;
; input:
;		AX - byte offset of variable
; output:
;		BX - variable value
basicNumericVars_get_value:
	push si
	
	mov si, basicNumericVarsStorage
	add si, ax							; SI := pointer to variable
	add si, 35							; SI := pointer to variable value
	mov bx, word [cs:si]
	
	pop si
	ret
	
	
; Gets the handle of a numeric variable by name
;
; input:
;	 DS:SI - pointer to name string, zero-terminated
; output:
;	 CARRY - set when variable was not found, clear otherwise
;		AX - handle (byte offset into array), if found
basicNumericVars_get_handle:
	push es
	push bx
	push di
	
	push cs
	pop es
	
	mov bx, basicNumericVarsStorage
basicNumericVars_get_handle_loop:
	cmp bx, basicNumericVarsStorageEnd			; are we past the end?
	jae basicNumericVars_get_handle_not_found	; yes, so it's not found

	cmp word [cs:bx], NVAR_NONE					; is this slot empty?
	je basicNumericVars_get_handle_loop_next	; yes, so skip it
	; slot is full, compare names
	
	mov di, bx					; ES:DI := pointer to variable slot
	add di, 2					; ES:DI := pointer to variable name
	int 0BDh					; compare strings
	cmp ax, 0					; equal?
	je basicNumericVars_get_handle_found	; yes, this is the variable
	
basicNumericVars_get_handle_loop_next:
	add bx, NVAR_ENTRY_SIZE_BYTES
	jmp basicNumericVars_get_handle_loop

basicNumericVars_get_handle_found:
	mov ax, bx
	sub ax, basicNumericVarsStorage		; AX := handle (byte offset)
	clc
	jmp basicNumericVars_get_handle_done
basicNumericVars_get_handle_not_found:
	stc
basicNumericVars_get_handle_done:
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
basicNumericVars_clear:
	pusha
	pushf
	push es
	
	push cs
	pop es
	
	mov cx, NVAR_TOTAL_SIZE_BYTES / 2
			; can never overrun array, and since each element is at least
			; 2 bytes long, it's either event (2 bytes per element), or
			; misses third or later byte in the last element (which is
			; still marked as "empty")
										
	mov di, basicNumericVarsStorage	; ES:DI := pointer to array
	mov ax, NVAR_NONE				; mark each array element as "empty"
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
basicNumericVars_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, basicNumericVarsStorage
	mov bx, 0				; offset of array slot being checked
basicNumericVars_find_empty_slot_loop:
	cmp word [cs:si+bx], NVAR_NONE			; is this slot empty?
										; (are first two bytes NVAR_NONE?)
	je basicNumericVars_find_empty_slot_done	; yes
	
	add bx, NVAR_ENTRY_SIZE_BYTES		; next slot
	cmp bx, NVAR_TOTAL_SIZE_BYTES		; are we past the end?
	jb basicNumericVars_find_empty_slot_loop		; no
basicNumericVars_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp basicNumericVars_find_empty_slot_done
basicNumericVars_find_empty_slot_done:
	pop si
	ret


%endif
