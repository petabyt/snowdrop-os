;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains various utility routines for Snowdrop OS's assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_UTIL_
%define _COMMON_ASM_UTIL_

asmUtlNumberToHexBuffer:	times 2 db 0


; Parses a number in all supported bases, from a string.
; Treats decimal numbers as signed (can be prefixed with a -)
; Examples:
;            0, 10, -25, 40000
;            100b, 11B
;            34h, 0AAH
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string does not represent a number, other
;			 value otherwise
;		BX - the 16bit integer, when valid
asm_multibase_number_atoi:
	call asm_is_valid_multibase_number			; AX := 0 when invalid,
												; BX := format
	cmp ax, 0
	je asm_multibase_number_atoi_done			; it's invalid
	; number is valid

asm_multibase_number_atoi_try_binary:
	cmp bx, ASM_NUMBER_FORMAT_BINARY
	jne asm_multibase_number_atoi_try_hex
	; it's binary
	call asm_get_binary_number_string_value		; AX := number
	mov bx, ax									; BX := number
	jmp asm_multibase_number_atoi_success
	
asm_multibase_number_atoi_try_hex:
	cmp bx, ASM_NUMBER_FORMAT_HEX
	jne asm_multibase_number_atoi_try_decimal
	; it's hexadecimal
	call asm_get_hex_number_string_value		; AX := number
	mov bx, ax									; BX := number
	jmp asm_multibase_number_atoi_success

asm_multibase_number_atoi_try_decimal:
	cmp bx, ASM_NUMBER_FORMAT_DECIMAL
	jne asm_multibase_number_atoi_done
	; it's decimal
	call common_string_signed_16bit_int_atoi	; AX := number
	mov bx, ax									; BX := number
	jmp asm_multibase_number_atoi_success

asm_multibase_number_atoi_success:	
	mov ax, 1
asm_multibase_number_atoi_done:
	ret


; Extracts the proper value of a quoted string literal
;
; input:
;	 DS:SI - pointer to string, zero-terminated
;	 ES:DI - pointer to buffer where the return value will be filled in
; output:
;		none
asm_get_quoted_string_literal_value:
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
asm_get_binary_number_string_value:
	push bx
	push cx
	push dx
	push si
	push di

	mov di, si					; DI := near pointer to first character
	
	int 0A5h					; BX := string length
	add si, bx
	sub si, 2					; DS:SI := pointer to last digit (skips over 'b')
	
	mov cl, 0					; power of 2 that corresponds to last character
	mov ax, 0					; accumulates result
asm_get_binary_number_string_value_loop:
	mov dl, byte [ds:si]
	sub dl, '0'					; DL := 0 or 1
	mov dh, 0					; DX := 0 or 1
	shl dx, cl					; DX := DX * 2^CL
	add ax, dx					; accumulate
	
	inc cl						; next higher power of 2
	dec si						; move one character to the left
	cmp si, di					; are we now to the left of leftmost character?
	jae asm_get_binary_number_string_value_loop	; no, so keep going
	; yes, so we just ran out of characters
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Gets the numeric value represented by a hex number string
; Assumes the string contains a valid hex number
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - numeric value
asm_get_hex_number_string_value:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	mov di, si					; DI := near pointer to first character
	
	int 0A5h					; BX := string length
	
	push cs
	pop es
	mov di, asmPrivateOnlyBuffer0	; ES:DI := pointer to buffer
	call common_string_copy			; copy into ES:DI
	push es
	pop ds
	mov si, di					; DS:SI := pointer to string copy
	int 82h						; convert to uppercase
	
	add si, bx
	sub si, 2					; DS:SI := pointer to last digit (skips over 'H')
	
	mov cl, 0					; power of 2 that corresponds to last character
	mov ax, 0					; accumulates result
asm_get_hex_number_string_value_loop:
	mov dl, byte [ds:si]
	cmp dl, '0'										; is it a number?
	jb asm_get_hex_number_string_value_loop_letter	; no
	cmp dl, '9'
	ja asm_get_hex_number_string_value_loop_letter
	; this digit is 0-9
	sub dl, '0'					; DL := numeric value of digit
	jmp asm_get_hex_number_string_value_loop_accumulate
asm_get_hex_number_string_value_loop_letter:
	; here, DL contains an uppercase letter
	sub dl, 'A'					
	add dl, 10					; DL := numeric value of digit
	
asm_get_hex_number_string_value_loop_accumulate:
	mov dh, 0					; DX := numeric value of digit
	
	push cx
	shl cl, 2					; CL := position * 4
								; (since a hex digit takes up 4 bits)
	shl dx, cl					; DX := DX * 16^CL
	add ax, dx					; accumulate
	pop cx
	
	inc cl						; next higher power of 16
	dec si						; move one character to the left
	cmp si, di					; are we now to the left of leftmost character?
	jae asm_get_hex_number_string_value_loop	; no, so keep going
	; yes, so we just ran out of characters
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
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
asm_get_near_pointer_after_token:
	push ds
	push es
	push si
	push bx
	push cx
	push dx
	
	push cs
	pop es
	mov di, asmPrivateOnlyBuffer0		; ES:DI := token storage buffer

	; start reading tokens from the beginning
asm_get_near_pointer_after_token_next_token:
	call asm_read_token				; read token into ES:DI
										; DS:SI := position right after token
	
	cmp ax, 0							; any token read?
	je asm_get_near_pointer_after_token_not_found	; no, so we're done
	
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
	jne asm_get_near_pointer_after_token_next_token	; no, so just loop again
	; it's an occurrence
	mov di, si							; near pointer to return
	jmp asm_get_near_pointer_after_token_success	
asm_get_near_pointer_after_token_not_found:
	mov ax, 0							; "error"
	jmp asm_get_near_pointer_after_token_done
asm_get_near_pointer_after_token_success:
	mov ax, 1							; "success"
asm_get_near_pointer_after_token_done:
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
asm_get_position:
	push ds
	push es
	push si
	push di
	push ax
	push bx
	
	mov ax, cs
	mov es, ax
	
	mov di, asmPrivateOnlyBuffer0		; ES:DI := token storage buffer
	
	mov cx, 1							; line counter
	mov dx, 1							; instruction counter
	; start reading tokens from the beginning
asm_get_position_next_token:
	call asm_read_token					; read token into ES:DI
										; DS:SI := position right after token
	
	cmp ax, 0							; any token read?
	je asm_get_position_done			; no, so we're done
	
	cmp si, bx							; past the current position pointer?
	jae asm_get_position_done_check	; yes, so we're done
	
	; check whether it's a newline
	push ds
	push si								; [1]
	
	push cs
	pop ds
	mov si, asmNewlineToken			; DS:SI := newline token
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	cmp ax, 0							; is it a newline?
	je asm_get_position_newline		; yes
	
	; check whether it's an instruction delimiter
	push ds
	push si								; [1]
	
	push cs
	pop ds
	mov si, asmInstructionDelimiterToken	; DS:SI := newline token
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	cmp ax, 0							; is it an instruction delimiter
	je asm_get_position_inst_delim	; yes
	
	jmp asm_get_position_next_token	; next token
	
asm_get_position_newline:
	; it's a newline
	inc cx								; increment line counter
	mov dx, 1							; initialize instruction counter
	jmp asm_get_position_next_token	; loop again
	
asm_get_position_inst_delim:
	; it's an instruction delimiter
	inc dx								; increment instruction counter
	jmp asm_get_position_next_token	; loop again
	
asm_get_position_done_check:
	; normally we don't consider the last read token
	; the only exception is a newline
	push ds
	push si								; [1]

	push cs
	pop ds
	mov si, asmNewlineToken			; DS:SI := newline token
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	
	cmp ax, 0							; is it a newline?
	jne asm_get_position_done			; no
	; it's a newline which must be considered
	inc cx								; increment line counter
	mov dx, 1							; initialize instruction counter
asm_get_position_done:
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
asm_lookup_inst_token:
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
asm_lookup_inst_token_fragments:
	cmp bl, byte [cs:asmCurrentInstTokenCount]
	jae asm_lookup_inst_token_fragments_not_found

	call asmInterpreter_get_instruction_token_near_ptr
							; DI := pointer to instruction token string
							; here, ES = CS

	int 0BDh				; compare passed-in string with this token
	cmp ax, 0				; equal?
	je asm_lookup_inst_token_fragments_found	; yes, return BL
	
	inc bl					; next instruction fragment
	jmp asm_lookup_inst_token_fragments

asm_lookup_inst_token_fragments_not_found:
	mov ax, 0						; "not found"
	jmp asm_lookup_inst_token_fragments_done
asm_lookup_inst_token_fragments_found:
	mov ax, 1						; "found"
asm_lookup_inst_token_fragments_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	ret

	
; Checks whether the specified token is a comma token
;
; input:
;		DL - token index
; output:
;		AX - 0 when token is not a comma, other value otherwise
asm_is_token_comma:
	push bx
	push di
	mov bl, dl
	call asmInterpreter_get_instruction_token_near_ptr	; DI := near ptr
	mov ax, 0					; assume false
	cmp byte [cs:di], ASM_CHAR_ARGUMENT_DELIMITER
	jne asm_is_token_comma_done
	cmp byte [cs:di+1], 0
	jne asm_is_token_comma_done
	mov ax, 1					; success
asm_is_token_comma_done:
	pop di
	pop bx
	ret
	
	
; Converts a string to hex, two characters per input character, space-separated
;
; input:
;	 DS:SI - pointer to string to convert
;	 ES:DI - pointer to result buffer
;		BX - string length
;		DX - formatting options:
;			 bit 0: whether to zero-terminate
;			 bit 1: whether to add a space after each byte
; output:
;		none
asm_string_to_hex:
	pusha
	push ds
	push es
	
asm_string_to_hex_loop:
	cmp bx, 0							; done?
	je asm_string_to_hex_loop_done
	
	mov al, byte [ds:si]
	call asm_byte_to_hex				; CH := msb, CL := lsb

	mov byte [es:di], ch
	inc di
	mov byte [es:di], cl
	inc di
	
	inc si								; next source character
	dec bx
	
	test dx, 2							; add space after byte?
	jz asm_string_to_hex_loop			; no
	; yes
	mov byte [es:di], ' '
	inc di
	jmp asm_string_to_hex_loop			; next byte
	
asm_string_to_hex_loop_done:
	test dx, 1							; zero-terminate?
	jz asm_string_to_hex_done			; no
	; yes
	mov byte [es:di], 0

asm_string_to_hex_done:	
	pop es
	pop ds
	popa
	ret

	
; Converts a number to hex, two characters per input character, space-separated
;
; input:
;		AX - number to convert
;	 ES:DI - pointer to result buffer
;		DX - formatting options:
;			 bit 0: whether to zero-terminate
;			 bit 1: whether to add a space after each byte
; output:
;		none
asm_word_to_hex:
	pusha
	push ds
	push es
	
	mov word [cs:asmUtlNumberToHexBuffer], ax
	
	push cs
	pop ds
	mov si, asmUtlNumberToHexBuffer
	mov bx, 2
	call asm_string_to_hex
	
	pop es
	pop ds
	popa
	ret
	

; Renders a byte as two hex digit characters
; Example: 20 -> "1" "8"
;
; input:
;		AL - byte to render
; output:
;		CX - two characters which represent the input
asm_byte_to_hex:
	push ax
	push bx
	push dx
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call asm_hex_digit_to_char		; CL := char
	mov ch, cl
	mov al, ah
	call asm_hex_digit_to_char		; CL := char
	
	pop dx
	pop bx
	pop ax
	ret


; When the passed-in string is a reserved symbol, it returns its value
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when input string is not a reserved symbol,
;			 other value otherwise
;		CX - numeric value when input string is a reserved symbol
asm_try_get_reserved_symbol_numeric_value:
	push ds
	push es
	push bx
	push dx
	push si
	push di
	
	push cs
	pop es
	
asm_try_get_reserved_symbol_numeric_value_DOLLAR:
	mov di, asmReservedSymbolDollar
	call common_string_compare_ignore_case	; compare strings
	cmp ax, 0						; do we have a match?
	jne asm_try_get_reserved_symbol_numeric_value_DOLLAR_DOLLAR
	call asmList_get_current_instruction_beginning_address	; BX := address
	mov cx, bx						; return it in CX
	jmp asm_try_get_reserved_symbol_numeric_value_yes
	
asm_try_get_reserved_symbol_numeric_value_DOLLAR_DOLLAR:
	mov di, asmReservedSymbolDollarDollar
	call common_string_compare_ignore_case	; compare strings
	cmp ax, 0						; do we have a match?
	jne asm_try_get_reserved_symbol_numeric_value_no
	call asmEmit_get_origin			; CX := origin
	jmp asm_try_get_reserved_symbol_numeric_value_yes

asm_try_get_reserved_symbol_numeric_value_no:
	mov ax, 0
	jmp asm_try_get_reserved_symbol_numeric_value_done
asm_try_get_reserved_symbol_numeric_value_yes:
	mov ax, 1
asm_try_get_reserved_symbol_numeric_value_done:	
	pop di
	pop si
	pop dx
	pop bx
	pop es
	pop ds
	ret
	

; Convert a hex digit to its character representation
; Example: 10 -> 'A'
;
; input:
;		AL - hex digit
; output:
;		CL - hex digit to char
asm_hex_digit_to_char:
	push ax
	cmp al, 9
	jbe asm_hex_digit_to_char_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
asm_hex_digit_to_char_under9:
	add al, '0'
	mov cl, al
	pop ax
	ret
	
	
; Copies a zero-terminated string, advancing destination pointer to 
; the newly-written terminator.
; It is meant to be used when multiple strings are concatenated together.
;
; input:
;	 DS:SI - pointer to source string, zero-terminated
;	 ES:DI - pointer to destination string, zero-terminated
; output:
;	 ES:DI - pointer to terminator of newly-written string
asm_copy_string_and_advance:
	push bx
	
	call common_string_copy
	int 0A5h									; BX := source string length
	add di, bx
	
	pop bx
	ret
	
	
; Warns user whether the specified number requires 2 bytes to be represented
;
; input:
;		AX - number
; output:
;		none
asmUtil_warn_if_value_larger_than_byte:
	push si
	push ds
	
	cmp ax, 255
	jbe asmUtil_warn_if_value_larger_than_byte_done
	
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmUtil_warn_if_value_larger_than_byte_done	; we warn only in pass 2
	
	; warn
	call asm_display_ASM_tag
	push cs
	pop ds
	mov si, asmMessageWarnSingleByteOverflow
	call asm_display_worker
asmUtil_warn_if_value_larger_than_byte_done:
	pop ds
	pop si
	ret
	

%endif
