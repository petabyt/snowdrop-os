;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains numeric variable management functionality 
; for Snowdrop OS's assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_VARS_NUMERIC_
%define _COMMON_ASM_VARS_NUMERIC_

NVAR_NONE 					equ 0FFFFh ; word value which marks a slot as empty
									   ; if this value is changed, inspect
									   ; array clear function
NVAR_IN_USE 				equ 0	; indicates a slot is in use

NVAR_ENTRY_SIZE_BYTES	equ 40
NVAR_COUNT	 			equ 128
NVAR_TOTAL_SIZE_BYTES equ NVAR_COUNT*NVAR_ENTRY_SIZE_BYTES ; in bytes

NVAR_TYPE_REGULAR			equ 0
NVAR_TYPE_FOR_LOOP_COUNTER	equ 1

; format of a numeric variable table entry:
; bytes
;     0-1 whether this variable slot is available
;    2-34 name (zero-terminated)
;   35-36 value
;   37-37 pass number during which this variable was defined
;   38-39 unused

; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
asmNumericVarsStorage: times NVAR_TOTAL_SIZE_BYTES db 0
asmNumericVarsStorageEnd:


; Deletes a string variable
;
; input:
;		AX - byte offset of variable
; output:
;		none	
asmNumericVars_delete:
	push bx
	mov bx, ax
	mov word [cs:asmNumericVarsStorage+bx], NVAR_NONE
	pop bx
	ret
	

; Allocates a new numeric variable
;
; input:
;	 DS:SI - pointer to name string, zero-terminated
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - variable handle
asmNumericVars_allocate:
	call asmNumericVars_find_empty_slot
	jc asmNumericVars_allocate_return		; none found, so just return
	
	pushf
	push es
	push di
	push cx
	push si
	mov word [cs:asmNumericVarsStorage+bx], NVAR_IN_USE	; mark slot
	
	mov word [cs:asmNumericVarsStorage+bx+35], 0	; initialize value to 0
	mov cl, byte [cs:asmPass]
	mov byte [cs:asmNumericVarsStorage+bx+37], cl	; set pass
	
	cld
	mov cx, ASM_VAR_NAME_MAX_LENGTH
	push cs
	pop es
	mov di, asmNumericVarsStorage
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
asmNumericVars_allocate_return:
	ret
	
	
; Gets the pass during which the numeric variable was defined
;
; input:
;		AX - byte offset of variable
; output:
;		BL - pass
asmNumericVars_get_definition_pass:
	push si
	
	mov si, asmNumericVarsStorage
	add si, ax							; SI := pointer to variable
	mov bl, byte [cs:si+37]
	
	pop si
	ret
	
	
; Sets the value of a numeric variable
;
; input:
;		AX - byte offset of variable
;		BX - value to set
; output:
;		none
asmNumericVars_set_value:
	pusha
	
	mov si, asmNumericVarsStorage
	add si, ax							; SI := pointer to variable
	add si, 35							; SI := pointer to variable value
	mov word [cs:si], bx
	
	popa
	ret
	
	
; Gets the value of a numeric variable
;
; input:
;		AX - byte offset of variable
; output:
;		BX - variable value
asmNumericVars_get_value:
	push si
	mov si, asmNumericVarsStorage
	add si, ax							; SI := pointer to variable
	cmp word [cs:si+0], NVAR_NONE
	je asmNumericVars_return_dummy
	
	add si, 35							; SI := pointer to variable value
	mov bx, word [cs:si]
	jmp asmNumericVars_done
asmNumericVars_return_dummy:
	mov bx, ASM_PASS_1_DUMMY_ADDRESS
asmNumericVars_done:
	pop si
	ret


; Gets the handle of a numeric variable by name
; NOTE: returns dummy values during first pass, or from
;       storage otherwise
;
; input:
;	 DS:SI - pointer to name string, zero-terminated
; output:
;	 CARRY - set when variable was not found, clear otherwise
;		AX - handle (byte offset into array), if found
asmNumericVars_get_handle_wrapper:
	cmp byte [cs:asmPass], ASM_PASS_1			; we return a dummy handle
	jne asmNumericVars_get_handle_wrapper_from_storage	; during first pass
	mov ax, 0									; dummy handle
	clc
	ret
asmNumericVars_get_handle_wrapper_from_storage:
	call asmNumericVars_get_handle_from_storage
	ret
	
	
	
; Gets the handle of a numeric variable by name
; NOTE: looks in storage exclusively
;
; input:
;	 DS:SI - pointer to name string, zero-terminated
; output:
;	 CARRY - set when variable was not found, clear otherwise
;		AX - handle (byte offset into array), if found
asmNumericVars_get_handle_from_storage:
	push es
	push bx
	push di
	
	push cs
	pop es
	
	mov bx, asmNumericVarsStorage
asmNumericVars_get_handle_loop:
	cmp bx, asmNumericVarsStorageEnd			; are we past the end?
	jae asmNumericVars_get_handle_not_found	; yes, so it's not found

	cmp word [cs:bx], NVAR_NONE					; is this slot empty?
	je asmNumericVars_get_handle_loop_next	; yes, so skip it
	; slot is full, compare names
	
	mov di, bx					; ES:DI := pointer to variable slot
	add di, 2					; ES:DI := pointer to variable name
	int 0BDh					; compare strings
	cmp ax, 0					; equal?
	je asmNumericVars_get_handle_found	; yes, this is the variable
	
asmNumericVars_get_handle_loop_next:
	add bx, NVAR_ENTRY_SIZE_BYTES
	jmp asmNumericVars_get_handle_loop

asmNumericVars_get_handle_found:
	mov ax, bx
	sub ax, asmNumericVarsStorage		; AX := handle (byte offset)
	clc
	jmp asmNumericVars_get_handle_done
asmNumericVars_get_handle_not_found:
	stc
asmNumericVars_get_handle_done:
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
asmNumericVars_clear:
	pusha
	pushf
	push es
	
	push cs
	pop es
	
	mov cx, NVAR_TOTAL_SIZE_BYTES / 2
			; can never overrun array, and since each element is at least
			; 2 bytes long, it's either even (2 bytes per element), or
			; misses third or later byte in the last element (which is
			; still marked as "empty")
										
	mov di, asmNumericVarsStorage	; ES:DI := pointer to array
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
asmNumericVars_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, asmNumericVarsStorage
	mov bx, 0				; offset of array slot being checked
asmNumericVars_find_empty_slot_loop:
	cmp word [cs:si+bx], NVAR_NONE			; is this slot empty?
										; (are first two bytes NVAR_NONE?)
	je asmNumericVars_find_empty_slot_done	; yes
	
	add bx, NVAR_ENTRY_SIZE_BYTES		; next slot
	cmp bx, NVAR_TOTAL_SIZE_BYTES		; are we past the end?
	jb asmNumericVars_find_empty_slot_loop		; no
asmNumericVars_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp asmNumericVars_find_empty_slot_done
asmNumericVars_find_empty_slot_done:
	pop si
	ret


%endif
