;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains various utility routines for Snowdrop OS's BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_UTIL_
%define _COMMON_BASIC_UTIL_


; Extracts the proper value of a quoted string literal
;
; input:
;	 DS:SI - pointer to string, zero-terminated
;	 ES:DI - pointer to buffer where the return value will be filled in
; output:
;		none
basic_get_quoted_string_literal_value:
	pusha

	inc si						; skip over opening string delimiter	
	call common_string_copy		; copy from second character to end
	
	int 0A5h					; BX := string length
	mov byte [es:di+bx-1], 0	; replace closing string delimiter 
								; with terminator
	popa
	ret

	
; Gets the numeric value represented by a binary number string
; Assumes the string contains a valid binary number
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - numeric value
basic_get_binary_number_string_value:
	push bx
	push cx
	push dx
	push si
	push di

	mov di, si					; DI := near pointer to first character
	
	int 0A5h					; BX := string length
	add si, bx
	dec si						; DS:SI := pointer to last character
	
	mov cl, 0					; power of 2 that corresponds to last character
	mov ax, 0					; accumulates result
basic_get_binary_number_string_value_loop:
	mov dl, byte [ds:si]
	sub dl, '0'					; DL := 0 or 1
	mov dh, 0					; DX := 0 or 1
	shl dx, cl					; DX := DX * 2^CL
	add ax, dx					; accumulate
	
	inc cl						; next higher power of 2
	dec si						; move one character to the left
	cmp si, di					; are we now to the left of leftmost character?
	jae basic_get_binary_number_string_value_loop	; no, so keep going
	; yes, so we just ran out of characters
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	

; Returns a near pointer to right after the first occurrence of the
; specified token, in the specified program text string
;
; input:
;	 DS:SI - pointer to program text string, zero-terminated
;	 DX:BX - pointer to token string, zero-terminated
; output:
;		AX - 0 when token was not found, other value otherwise
;		DI - near pointer to right after the first occurrence of token
basic_get_near_pointer_after_token:
	push ds
	push es
	push si
	push bx
	push cx
	push dx
	
	push cs
	pop es
	mov di, basicPrivateOnlyBuffer0		; ES:DI := token storage buffer

	; start reading tokens from the beginning
basic_get_near_pointer_after_token_next_token:
	call basic_read_token				; read token into ES:DI
										; DS:SI := position right after token
	
	cmp ax, 0							; any token read?
	je basic_get_near_pointer_after_token_not_found	; no, so we're done
	
	; compare token to passed-in token
	push ds
	push si								; [1] save position right after token
	
	push dx
	pop ds
	mov si, bx							; DS:SI := DX:BX
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	cmp ax, 0							; is it an occurrence?
	jne basic_get_near_pointer_after_token_next_token	; no, so just loop again
	; it's an occurrence
	mov di, si							; near pointer to return
	jmp basic_get_near_pointer_after_token_success	
basic_get_near_pointer_after_token_not_found:
	mov ax, 0							; "error"
	jmp basic_get_near_pointer_after_token_done
basic_get_near_pointer_after_token_success:
	mov ax, 1							; "success"
basic_get_near_pointer_after_token_done:
	pop dx
	pop cx
	pop bx
	pop si
	pop es
	pop ds
	ret
	
	
; Returns the current position (line number and instruction number)
; in the program
;
; input:
;	 DS:SI - pointer to program text string, zero-terminated
;		BX - near pointer to current position
; output:
;		CX - line number
;		DX - instruction number (within line)
basic_get_position:
	push ds
	push es
	push si
	push di
	push ax
	push bx
	
	mov ax, cs
	mov es, ax
	
	mov di, basicPrivateOnlyBuffer0		; ES:DI := token storage buffer
	
	mov cx, 1							; line counter
	mov dx, 1							; instruction counter
	; start reading tokens from the beginning
basic_get_position_next_token:
	call basic_read_token				; read token into ES:DI
										; DS:SI := position right after token
	
	cmp ax, 0							; any token read?
	je basic_get_position_done			; no, so we're done
	
	cmp si, bx							; past the current position pointer?
	jae basic_get_position_done_check	; yes, so we're done
	
	; check whether it's a newline
	push ds
	push si								; [1]
	
	push cs
	pop ds
	mov si, basicNewlineToken			; DS:SI := newline token
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	cmp ax, 0							; is it a newline?
	je basic_get_position_newline		; yes
	
	; check whether it's an instruction delimiter
	push ds
	push si								; [1]
	
	push cs
	pop ds
	mov si, basicInstructionDelimiterToken	; DS:SI := newline token
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	cmp ax, 0							; is it an instruction delimiter
	je basic_get_position_inst_delim	; yes
	
	jmp basic_get_position_next_token	; next token
	
basic_get_position_newline:
	; it's a newline
	inc cx								; increment line counter
	mov dx, 1							; initialize instruction counter
	jmp basic_get_position_next_token	; loop again
	
basic_get_position_inst_delim:
	; it's an instruction delimiter
	inc dx								; increment instruction counter
	jmp basic_get_position_next_token	; loop again
	
basic_get_position_done_check:
	; normally we don't consider the last read token
	; the only exception is a newline
	push ds
	push si								; [1]

	push cs
	pop ds
	mov si, basicNewlineToken			; DS:SI := newline token
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	
	cmp ax, 0							; is it a newline?
	jne basic_get_position_done			; no
	; it's a newline which must be considered
	inc cx								; increment line counter
	mov dx, 1							; initialize instruction counter
basic_get_position_done:
	pop bx
	pop ax
	pop di
	pop si
	pop es
	pop ds
	ret


; Returns the index of the instruction token which equals the 
; specified string
;
; input:
;	 DS:SI - pointer to string to look up, zero-terminated
; output:
;		AX - 0 when not found, other value otherwise
;		BL - index of instruction token, when found
basic_lookup_inst_token:
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	push cs
	pop es
		
	; iterate over all instruction fragments
	mov bl, 0								; instruction fragment index
basic_lookup_inst_token_fragments:
	cmp bl, byte [cs:basicCurrentInstTokenCount]
	jae basic_lookup_inst_token_fragments_not_found

	call basicInterpreter_get_instruction_token_near_ptr
							; DI := pointer to instruction token string
							; here, ES = CS

	int 0BDh				; compare passed-in string with this token
	cmp ax, 0				; equal?
	je basic_lookup_inst_token_fragments_found	; yes, return BL
	
	inc bl					; next instruction fragment
	jmp basic_lookup_inst_token_fragments

basic_lookup_inst_token_fragments_not_found:
	mov ax, 0						; "not found"
	jmp basic_lookup_inst_token_fragments_done
basic_lookup_inst_token_fragments_found:
	mov ax, 1						; "found"
basic_lookup_inst_token_fragments_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	ret
	
	
; Deletes a variable from both string variables and numeric variables.
; NOOP when variable does not exist.
;
; input:
;	 DS:SI - pointer to variable name, zero-terminated
; output:
;		none
basic_delete_variable_by_name:
	pusha
	
	; string variables first
	call basicStringVars_get_handle				; AX := handle
	jc basic_delete_variable_from_numeric		; not found
	call basicStringVars_delete					; delete

basic_delete_variable_from_numeric:
	call basicNumericVars_get_handle			; AX := handle
	jc basic_delete_variable_done				; not found
	call basicNumericVars_delete				; delete

basic_delete_variable_done:
	popa
	ret

	
; Checks whether the specified FOR loop counter variable is still within its
; loop boundaries
; Assumes variable exists, is numeric, and is a FOR-loop counter
;
; input:
;		AX - byte offset of variable
; output:
;		BX - 0 when stopping condition was not met, other value otherwise
basic_check_for_counter_within_bounds:
	pusha

	call basicNumericVars_get_properties	; CX := inclusive end value
											; DX := step value
	call basicNumericVars_get_value			; BX := current value
	cmp dx, 0
	jl basic_check_for_counter_within_bounds_negative_step
basic_check_for_counter_within_bounds_positive_step:
	cmp bx, cx
	jle basic_check_for_counter_within_bounds_yes		; value <= limit
	jmp basic_check_for_counter_within_bounds_no
basic_check_for_counter_within_bounds_negative_step:
	cmp bx, cx
	jge basic_check_for_counter_within_bounds_yes		; value >= limit
	jmp basic_check_for_counter_within_bounds_no
basic_check_for_counter_within_bounds_no:
	popa
	mov bx, 0
	ret
basic_check_for_counter_within_bounds_yes:
	popa
	mov bx, 1
	ret

	
; Checks whether the specified token is a comma token
;
; input:
;		DL - token index
; output:
;		AX - 0 when token is not a comma, other value otherwise
basic_is_token_comma:
	push bx
	push di
	mov bl, dl
	call basicInterpreter_get_instruction_token_near_ptr	; DI := near ptr
	mov ax, 0					; assume false
	cmp byte [cs:di], BASIC_CHAR_ARGUMENT_DELIMITER
	jne basic_is_token_comma_done
	cmp byte [cs:di+1], 0
	jne basic_is_token_comma_done
	mov ax, 1					; success
basic_is_token_comma_done:
	pop di
	pop bx
	ret
	

%endif
