;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains validation functionality for Snowdrop OS's BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_VALIDATION_
%define _COMMON_BASIC_VALIDATION_


; Checks whether the specified numeric literal (as a zero-terminated string)
; represents an integer outside of bounds.
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when numeric literal would overflow, other value otherwise
basic_check_numeric_literal_overflow:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	call common_string_signed_16bit_int_atoi	; AX := the input integer
	push ds
	pop es
	mov di, si									; ES:DI := ptr to input string
	
	push cs
	pop ds
	mov si, basicItoaBuffer						; DS:SI := itoa storage
	call common_string_signed_16bit_int_itoa
	; we've converted <numeric literal> --> number --> <numeric literal>
	; if the two numeric literals are equal, then there was no overflow
	
	; ... but first, skip over a possible prefixed + sign in the input
	cmp byte [es:di], '+'
	jne basic_check_numeric_literal_overflow_compare
	inc di										; skip over +
basic_check_numeric_literal_overflow_compare:	
	int 0BDh									; compare strings
	cmp ax, 0
	je basic_check_numeric_literal_overflow_no_overflow
	; we overflowed
basic_check_numeric_literal_overflow_overflow:
	mov ax, 0
	jmp basic_check_numeric_literal_overflow_done
basic_check_numeric_literal_overflow_no_overflow:
	mov ax, 1
basic_check_numeric_literal_overflow_done:
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
;     - have at least one character
;     - be alphanumeric
;     - start with a letter
;     - be no longer than the maximum variable name length
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid variable name, other value otherwise
basic_is_valid_variable_name:
	push bx

	mov ax, 0								; "not valid"

	int 0A5h								; BX := string length
	cmp bx, BASIC_VAR_NAME_MAX_LENGTH
	jae basic_is_valid_variable_name_done	; it's too long
	
	cmp byte [ds:si], 0
	je basic_is_valid_variable_name_done	; it's empty
	
	call common_string_is_letter
	cmp ax, 0
	je basic_is_valid_variable_name_done
	
	call common_string_is_alphanumeric		; AX := 0 when not alphanumeric
											; AX := 1 when alphanumeric
basic_is_valid_variable_name_done:
	pop bx
	ret

	
; Checks whether the specified string contains a valid binary number
; Valid binary number strings must:
;     - be at least 1 character long
;     - be at most 16 characters long
;     - contain no other characters than '0' and '1'
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid binary number string, other
;			 value otherwise	
basic_is_binary_number_string:
	push bx
	push si
	
	mov ax, 0					; assume invalid
	
	int 0A5h					; BX := string length
	cmp bx, 1
	jb basic_is_binary_number_string_done
	cmp bx, 16
	ja basic_is_binary_number_string_done
basic_is_binary_number_string_loop:
	cmp byte [ds:si], '0'
	jb basic_is_binary_number_string_done
	cmp byte [ds:si], '1'
	ja basic_is_binary_number_string_done
	
	inc si
	cmp byte [ds:si], 0			; terminator?
	jne basic_is_binary_number_string_loop	; no, keep going
	
	mov ax, 1					; valid
basic_is_binary_number_string_done:
	pop si
	pop bx
	ret
	

; Checks whether the specified string contains a valid label
; Valid labels must:
;     - have at least one character
;     - be alphanumeric (except for the last character, which must be ':' )
;     - start with a letter
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid label, other value otherwise	
basic_is_valid_label:
	push bx
	push si
	
	mov ax, 0					; "not a valid label"
	
	int 0A5h					; BX := string length
	cmp bx, 2					; must be at least a letter and ':'
	jb basic_is_valid_label_no	; too short
	
	cmp byte [ds:si+bx-1], BASIC_CHAR_LABEL_DELIMITER	; check last character
	jne basic_is_valid_label_no	; labels must end in ':'
	
	mov byte [ds:si+bx-1], 0	; terminate string just before ':', so
								; we can perform our "inner" check
								; (we'll restore the ':' before returning)
	call basic_is_valid_variable_name	; AX := 0 when invalid, other value
										; otherwise
										; (same contract as this procedure)
	mov byte [ds:si+bx-1], BASIC_CHAR_LABEL_DELIMITER	; restore delimiter
basic_is_valid_label_no:
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
basic_is_valid_quoted_string_literal:
	push bx
	mov ax, 0					; "not a valid quoted string literal"
	
	int 0A5h					; BX := string length
	cmp bx, 2					; is it too short?
	jb basic_is_valid_quoted_string_literal_done
	
	cmp byte [ds:si], BASIC_CHAR_STRING_DELIMITER	; begins with delimiter?
	jne basic_is_valid_quoted_string_literal_done	; no
	
	cmp byte [ds:si+bx-1], BASIC_CHAR_STRING_DELIMITER	; ends with delimiter?
	jne basic_is_valid_quoted_string_literal_done	; no
	
	mov ax, 1					; "it is a valid quoted string literal"
basic_is_valid_quoted_string_literal_done:
	pop bx
	ret

	
; Checks whether the specified string contains a 
; valid Snowdrop OS BASIC keyword.
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid keyword, other value otherwise
basic_is_valid_keyword:
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
	mov si, basicKeywordStart		; DS:SI := pointer to first keyword
basic_is_valid_keyword_loop:
	int 0BDh						; compare strings
	cmp ax, 0						; do we have a keyword match?
	je basic_is_valid_keyword_success
	; no match, so move to next keyword
	int 0A5h						; BX := length of current keyword
	add si, bx						; move pointer to terminator
	inc si							; move pointer to first character of
									; next keyword
	cmp si, basicKeywordEnd			; are we past the end?
	jae basic_is_valid_keyword_error
	; here, DS:SI points to the first character of next keyword
	jmp basic_is_valid_keyword_loop
basic_is_valid_keyword_success:
	mov ax, 1						; "success"
	jmp basic_is_valid_keyword_done
basic_is_valid_keyword_error:
	mov ax, 0						; "error"
	jmp basic_is_valid_keyword_done
	
basic_is_valid_keyword_done:
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
basic_check_ignored_character:
	pusha

	mov al, byte [ds:si]
	; is it an ignored character?
	mov si, basicIgnoredTokenChars
	mov cx, basicIgnoredTokenCharsCount
basic_check_ignored_character_loop:
	cmp al, byte [cs:si]						; is it an ignored character?
	je basic_check_ignored_character_yes		; yes, so we're done
	inc si										; next character to check
	loop basic_check_ignored_character_loop

basic_check_ignored_character_no:
	clc											; not an ignored character
	popa
	ret
basic_check_ignored_character_yes:
	stc
	popa
	ret

	
; Checks whether the specified character is a tokenizer stop character
;
; input:
;	 DS:SI - pointer to character
; output:
;	 CARRY - set if it is a stop character, clear otherwise
basic_check_stop_character:
	pusha

	mov al, byte [ds:si]
	; is it a stop character?
	mov si, basicStopTokenChars
	mov cx, basicStopTokenCharsCount
basic_check_stop_character_loop:
	cmp al, byte [cs:si]					; is it a stop character?
	je basic_check_stop_character_yes		; yes, so we're done
	inc si									; next character to check
	loop basic_check_stop_character_loop

basic_check_stop_character_no:
	clc										; not a stop character
	popa
	ret
basic_check_stop_character_yes:
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
basic_is_valid_single_character_token:
	mov ax, 0								; "no"
	cmp byte [ds:si], dl					; first the character ...
	jne basic_is_valid_single_character_token_done
	cmp byte [ds:si+1], 0					; ... then the terminator
	jne basic_is_valid_single_character_token_done
	mov ax, 1								; "yes"
basic_is_valid_single_character_token_done:
	ret
	
	
; Checks whether the specified string contains a newline token
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a newline, other value otherwise
basic_is_valid_newline:
	push dx
	mov dl, BASIC_CHAR_LINE_ENDING
	call basic_is_valid_single_character_token
	pop dx
	ret
	
	
; Checks whether the specified string contains an instruction delimiter
; token
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not an inst. delimiter, other value otherwise
basic_is_valid_instruction_delimiter:
	push dx
	mov dl, BASIC_CHAR_INSTRUCTION_DELIMITER
	call basic_is_valid_single_character_token
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
basic_is_unique_label:
	push ds
	push es
	push si
	push di
	push bx
	push cx
	push dx
	
	push cs
	pop es
	mov di, basicPrivateOnlyBuffer0		; ES:DI := token storage buffer
	
	mov cx, 0							; occurrence counter
	; start reading tokens from the beginning
basic_is_unique_label_next_token:
	call basic_read_token				; read token into ES:DI
										; DS:SI := position right after token
	
	cmp ax, 0							; any token read?
	je basic_is_unique_label_no_more	; no, so we're done
	
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
	jne basic_is_unique_label_next_token	; no, so just loop again
	; it's an occurrence
	inc cx									; increment occurrence counter
	jmp basic_is_unique_label_next_token	; loop again
basic_is_unique_label_no_more:
	mov ax, 1							; "it's unique"
	
	cmp cx, 1
	je basic_is_unique_label_done		; one occurrence, so it's unique
	mov ax, 0							; "it's not unique"
basic_is_unique_label_done:
	pop dx
	pop cx
	pop bx
	pop di
	pop si
	pop es
	pop ds
	ret


%endif
