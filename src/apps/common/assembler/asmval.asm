;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains validation functionality for Snowdrop OS's assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_VALIDATION_
%define _COMMON_ASM_VALIDATION_


; Tests whether a string represents a number in all supported bases,
; returning a format designator when so
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string does not represent a number, other
;			 value otherwise
;		BX - format designator when string represents a number
asm_is_valid_multibase_number:
	call asm_is_binary_number_string			; AX := 0 when not binary
	cmp ax, 0
	je asm_is_valid_multibase_number_check_hex
	; it's a binary number
	mov bx, ASM_NUMBER_FORMAT_BINARY
	jmp asm_is_valid_multibase_number_done
	
asm_is_valid_multibase_number_check_hex:
	call asm_is_hex_number_string				; AX := 0 when not hex
	cmp ax, 0
	je asm_is_valid_multibase_number_check_decimal
	; it's a hexadecimal
	mov bx, ASM_NUMBER_FORMAT_HEX
	jmp asm_is_valid_multibase_number_done
	
asm_is_valid_multibase_number_check_decimal:
	call common_string_is_numeric				; AX := 0 when not decimal
	cmp ax, 0
	je asm_is_valid_multibase_number_done
	; it's a decimal number
	mov bx, ASM_NUMBER_FORMAT_DECIMAL
	jmp asm_is_valid_multibase_number_done
	
asm_is_valid_multibase_number_done:
	ret

	
; Checks whether the specified string contains a reserved symbol (such as $)
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a reserved symbol, other value otherwise
asm_is_reserved_symbol:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	pop es
	mov di, si						; ES:DI := pointer to input string
	
	push cs
	pop ds
	mov si, asmReservedSymbolsStart	; DS:SI := pointer to first keyword
asm_is_reserved_symbol_loop:
	int 0BDh						; compare strings
	cmp ax, 0						; do we have a match?
	je asm_is_reserved_symbol_yes
	; no match, so move to next
	int 0A5h						; BX := length of current keyword
	add si, bx						; move pointer to terminator
	inc si							; move pointer to first character of
									; next keyword
	cmp si, asmReservedSymbolsEnd	; are we past the end?
	jae asm_is_reserved_symbol_no
	; here, DS:SI points to the first character of next keyword
	jmp asm_is_reserved_symbol_loop
asm_is_reserved_symbol_no:
	mov ax, 0
	jmp asm_is_reserved_symbol_done
asm_is_reserved_symbol_yes:
	mov ax, 1
asm_is_reserved_symbol_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret
	

; Checks whether the specified string contains a valid variable name
; or is a reserved symbol (such as $)
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is neither a valid variable name or a reserved
;			 symbol, other value otherwise
asm_is_valid_variable_name_or_reserved_symbol:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call asm_is_valid_variable_name			; first check variable name
	cmp ax, 0
	jne asm_is_valid_variable_name_or_reserved_symbol_yes
	; now check reserved symbols
	
	call asm_is_reserved_symbol				; then check reserved symbol
	jmp asm_is_valid_variable_name_or_reserved_symbol_done
asm_is_valid_variable_name_or_reserved_symbol_no:
	mov ax, 0
	jmp asm_is_valid_variable_name_or_reserved_symbol_done
asm_is_valid_variable_name_or_reserved_symbol_yes:
	mov ax, 1
asm_is_valid_variable_name_or_reserved_symbol_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret
	

; Checks whether the specified string contains a valid variable name
; Valid variable names must:
;     - not be empty
;     - start with a letter
;     - be made up of no other characters than digits, letters, underscore
;     - be no longer than the maximum variable name length
;     - not be a reserved symbol or keyword
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid variable name, other value otherwise
asm_is_valid_variable_name:
	push bx
	push si

	call asmx86_is_reserved_word
	cmp ax, 0
	jne asm_is_valid_variable_name_invalid	; it's a CPU-specific reserved word
	
	call asm_is_reserved_symbol
	cmp ax, 0
	jne asm_is_valid_variable_name_invalid	; it's a reserved symbol
	
	call asm_is_valid_keyword
	cmp ax, 0
	jne asm_is_valid_variable_name_invalid	; it's a keyword
	
	int 0A5h								; BX := string length
	cmp bx, ASM_VAR_NAME_MAX_LENGTH
	jae asm_is_valid_variable_name_invalid	; it's too long
	
	cmp byte [ds:si], 0
	je asm_is_valid_variable_name_invalid	; it's empty
	
	call common_string_is_letter
	cmp ax, 0
	je asm_is_valid_variable_name_invalid	; not a letter
	
	dec si								; start at -1
asm_is_valid_variable_name_loop:
	inc si
	
	cmp byte [ds:si], 0
	je asm_is_valid_variable_name_valid		; we're at the end
	
	cmp byte [ds:si], '_'
	je asm_is_valid_variable_name_loop		; this character is allowed

	cmp byte [ds:si], '0'
	jb asm_is_valid_variable_name_invalid	; before '0'
											; (can't be a letter, either)
	cmp byte [ds:si], '9'
	jbe asm_is_valid_variable_name_loop		; this character is a digit
	
	; not a digit, but can still be a letter
	
	call common_string_is_letter
	cmp ax, 0
	je asm_is_valid_variable_name_invalid	; not a letter
	
	jmp asm_is_valid_variable_name_loop		; next character
	
asm_is_valid_variable_name_invalid:
	mov ax, 0								; "not valid"
	jmp asm_is_valid_variable_name_done
asm_is_valid_variable_name_valid:
	mov ax, 1								; "valid"
asm_is_valid_variable_name_done:
	pop si
	pop bx
	ret

	
; Checks whether the specified string contains a valid hex number
; Valid hex number strings must:
;     - be at least 2 characters long
;     - left-most character is 0-9
;     - contain only characters 0-9, a-f, A-F, and a final h or H character
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid hex number string, other
;			 value otherwise	
asm_is_hex_number_string:
	push ds
	push es
	push bx
	push si
	push di
	
	int 0A5h					; BX := string length
	cmp bx, 2					; must have at least 2 characters, such as:
								; 0h, Ah
	jb asm_is_hex_number_string_invalid

	push cs
	pop es
	mov di, asmPrivateOnlyBuffer0	; ES:DI := pointer to buffer
	call common_string_copy			; copy into ES:DI
	push es
	pop ds
	mov si, di					; DS:SI := pointer to string copy
	int 82h						; convert to uppercase
	
	cmp byte [ds:si], '0'		; must start with a digit
	jb asm_is_hex_number_string_invalid
	cmp byte [ds:si], '9'
	ja asm_is_hex_number_string_invalid
	
	cmp byte [ds:si+bx-1], 'H'	; must end in 'H'
	jne asm_is_hex_number_string_invalid

asm_is_hex_number_string_loop:
	; first try letter
	cmp byte [ds:si], 'A'
	jb asm_is_hex_number_string_loop_try_digit	; it's not a letter
	cmp byte [ds:si], 'F'
	ja asm_is_hex_number_string_loop_try_digit
	jmp asm_is_hex_number_string_loop_next		; it's a valid character

asm_is_hex_number_string_loop_try_digit:
	cmp byte [ds:si], '0'
	jb asm_is_hex_number_string_invalid
	cmp byte [ds:si], '9'
	ja asm_is_hex_number_string_invalid
	
asm_is_hex_number_string_loop_next:
	inc si
	cmp byte [ds:si], 'H'		; is it the 'H' at the end?
	jne asm_is_hex_number_string_loop	; no, keep going
	
	mov ax, 1					; valid
	jmp asm_is_hex_number_string_done

asm_is_hex_number_string_invalid:
	mov ax, 0
	
asm_is_hex_number_string_done:
	pop di
	pop si
	pop bx
	pop es
	pop ds
	ret

	
	
; Checks whether the specified string contains a valid binary number
; Valid binary number strings must:
;     - be at least 2 characters long
;     - contain no other characters than '0' and '1', except ending
;       with 'b' or 'B'
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid binary number string, other
;			 value otherwise	
asm_is_binary_number_string:
	push bx
	push si
	
	mov ax, 0					; assume invalid
	
	int 0A5h					; BX := string length
	cmp bx, 2					; must have at least 2 characters, such as:
								; 0b, 1b
	jb asm_is_binary_number_string_done
	
	cmp byte [ds:si+bx-1], 'b'	; must end in 'b'
	je asm_is_binary_number_string_loop
	cmp byte [ds:si+bx-1], 'B'	; ... or 'B'
	je asm_is_binary_number_string_loop
	
	jmp asm_is_binary_number_string_done	; invalid

asm_is_binary_number_string_loop:
	cmp byte [ds:si], '0'
	jb asm_is_binary_number_string_done
	cmp byte [ds:si], '1'
	ja asm_is_binary_number_string_done
	
	inc si
	cmp byte [ds:si], 'b'		; is it the 'b' at the end?
	je asm_is_binary_number_string_loop_over	; yes, we're done
	cmp byte [ds:si], 'B'		; ... or the 'B'?
	je asm_is_binary_number_string_loop_over	; yes, we're done
	
	jmp asm_is_binary_number_string_loop		; no, continue looping
asm_is_binary_number_string_loop_over:	
	mov ax, 1					; valid
asm_is_binary_number_string_done:
	pop si
	pop bx
	ret
	

; Checks whether the specified string contains a valid label
; Valid labels must:
;     - follow the same rules as variable names, except
;       for the last character, which must be ':'
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid label, other value otherwise	
asm_is_valid_label:
	push bx
	push si
	
	mov ax, 0					; "not a valid label"
	
	int 0A5h					; BX := string length
	cmp bx, 2					; must be at least a letter and ':'
	jb asm_is_valid_label_no	; too short
	
	cmp byte [ds:si+bx-1], ASM_CHAR_LABEL_DELIMITER	; check last character
	jne asm_is_valid_label_no	; labels must end in ':'
	
	mov byte [ds:si+bx-1], 0	; terminate string just before ':', so
								; we can perform our "inner" check
								; (we'll restore the ':' before returning)
	call asm_is_valid_variable_name	; AX := 0 when invalid, other value
										; otherwise
										; (same contract as this procedure)
	mov byte [ds:si+bx-1], ASM_CHAR_LABEL_DELIMITER	; restore delimiter
asm_is_valid_label_no:
	pop si
	pop bx
	ret


; Checks whether the specified string contains a quoted string literal.
; Valid string literals must:
;     - be at least two characters long
;     - begin and end with the string delimiter character
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid quoted string literal, 
;			   other value otherwise
asm_is_valid_quoted_string_literal:
	push bx
	mov ax, 0					; "not a valid quoted string literal"
	
	int 0A5h					; BX := string length
	cmp bx, 2					; is it too short?
	jb asm_is_valid_quoted_string_literal_done
	
	cmp byte [ds:si], ASM_CHAR_STRING_DELIMITER	; begins with delimiter?
	jne asm_is_valid_quoted_string_literal_done	; no
	
	cmp byte [ds:si+bx-1], ASM_CHAR_STRING_DELIMITER	; ends with delimiter?
	jne asm_is_valid_quoted_string_literal_done	; no
	
	mov ax, 1					; "it is a valid quoted string literal"
asm_is_valid_quoted_string_literal_done:
	pop bx
	ret

	
; Checks whether the specified string contains a 
; valid Snowdrop OS ASM keyword.
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid keyword, other value otherwise
asm_is_valid_keyword:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	push cs
	pop es
	mov di, asmPrivateOnlyBuffer0	; ES:DI := pointer to buffer
	call common_string_copy			; copy input string into buffer
		
	push cs
	pop ds
	mov si, asmKeywordStart			; DS:SI := pointer to first keyword
asm_is_valid_keyword_loop:
	call common_string_compare_ignore_case		; compare strings
	cmp ax, 0						; do we have a keyword match?
	je asm_is_valid_keyword_success
	; no match, so move to next keyword
	int 0A5h						; BX := length of current keyword
	add si, bx						; move pointer to terminator
	inc si							; move pointer to first character of
									; next keyword
	cmp si, asmKeywordEnd			; are we past the end?
	jae asm_is_valid_keyword_error
	; here, DS:SI points to the first character of next keyword
	jmp asm_is_valid_keyword_loop
asm_is_valid_keyword_success:
	mov ax, 1						; "success"
	jmp asm_is_valid_keyword_done
asm_is_valid_keyword_error:
	mov ax, 0						; "error"
	jmp asm_is_valid_keyword_done
	
asm_is_valid_keyword_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret

	
; Checks whether the specified character is an ignored character
;
; input:
;	 DS:SI - pointer to character
; output:
;	 CARRY - set if it is an ignored character, clear otherwise
asm_check_ignored_character:
	pusha

	mov al, byte [ds:si]
	; is it an ignored character?
	mov si, asmIgnoredTokenChars
	mov cx, asmIgnoredTokenCharsCount
asm_check_ignored_character_loop:
	cmp al, byte [cs:si]						; is it an ignored character?
	je asm_check_ignored_character_yes		; yes, so we're done
	inc si										; next character to check
	loop asm_check_ignored_character_loop

asm_check_ignored_character_no:
	clc											; not an ignored character
	popa
	ret
asm_check_ignored_character_yes:
	stc
	popa
	ret

	
; Checks whether the specified character is a tokenizer stop character
;
; input:
;	 DS:SI - pointer to character
; output:
;	 CARRY - set if it is a stop character, clear otherwise
asm_check_stop_character:
	pusha

	mov al, byte [ds:si]
	; is it a stop character?
	mov si, asmStopTokenChars
	mov cx, asmStopTokenCharsCount
asm_check_stop_character_loop:
	cmp al, byte [cs:si]					; is it a stop character?
	je asm_check_stop_character_yes		; yes, so we're done
	inc si									; next character to check
	loop asm_check_stop_character_loop

asm_check_stop_character_no:
	clc										; not a stop character
	popa
	ret
asm_check_stop_character_yes:
	stc
	popa
	ret
	
	
; Checks whether the specified string contains a token with the specified
; character.
;
; input:
;	 DS:SI - pointer to string, zero-terminated
;		DL - character to check
; output:
;		AX - 0 when string does not contain the token of the specified
;			 character, other value otherwise	
asm_is_valid_single_character_token:
	mov ax, 0								; "no"
	cmp byte [ds:si], dl					; first the character ...
	jne asm_is_valid_single_character_token_done
	cmp byte [ds:si+1], 0					; ... then the terminator
	jne asm_is_valid_single_character_token_done
	mov ax, 1								; "yes"
asm_is_valid_single_character_token_done:
	ret
	
	
; Checks whether the specified string contains a newline token
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a newline, other value otherwise
asm_is_valid_newline:
	push dx
	mov dl, ASM_CHAR_LINE_ENDING
	call asm_is_valid_single_character_token
	pop dx
	ret
	
	
; Checks whether the specified string contains an instruction delimiter
; token
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not an inst. delimiter, other value otherwise
asm_is_valid_instruction_delimiter:
	push dx
	mov dl, ASM_CHAR_INSTRUCTION_DELIMITER
	call asm_is_valid_single_character_token
	pop dx
	ret


; Checks whether the specified string contains a label that's unique 
; (as in, appears only once) within the specified program text
;
; input:
;	 DS:SI - pointer to program text string, zero-terminated
;	 DX:BX - pointer to label string, zero-terminated
; output:
;		AX - 0 when label is not unique, other value otherwise	
asm_is_unique_label:
	push ds
	push es
	push si
	push di
	push bx
	push cx
	push dx
	
	push cs
	pop es
	mov di, asmPrivateOnlyBuffer0		; ES:DI := token storage buffer
	
	mov cx, 0							; occurrence counter
	; start reading tokens from the beginning
asm_is_unique_label_next_token:
	call asm_read_token				; read token into ES:DI
										; DS:SI := position right after token
	
	cmp ax, 0							; any token read?
	je asm_is_unique_label_no_more	; no, so we're done
	
	; compare token to passed-in label
	push ds
	push si								; [1]
	
	push dx
	pop ds
	mov si, bx							; DS:SI := DX:BX
										; ES:DI = current token
	int 0BDh							; AX := 0 when strings are equal
	pop si								; [1]
	pop ds
	cmp ax, 0							; is it an occurrence?
	jne asm_is_unique_label_next_token	; no, so just loop again
	; it's an occurrence
	inc cx									; increment occurrence counter
	jmp asm_is_unique_label_next_token	; loop again
asm_is_unique_label_no_more:
	mov ax, 1							; "it's unique"
	
	cmp cx, 1
	je asm_is_unique_label_done		; one occurrence, so it's unique
	mov ax, 0							; "it's not unique"
asm_is_unique_label_done:
	pop dx
	pop cx
	pop bx
	pop di
	pop si
	pop es
	pop ds
	ret


%endif
