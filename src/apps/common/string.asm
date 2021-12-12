;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for dealing with strings.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_STRING_
%define _COMMON_STRING_

commonStringSingleCharBuffer:	db 0


; Checks whether the specified string contains only numbers and Latin
; letters
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not alphanumeric, other value otherwise
common_string_is_alphanumeric:
	push si
	
	dec si								; start at -1
common_string_is_alphanumeric_loop:
	inc si
	
	cmp byte [ds:si], 0
	je common_string_is_alphanumeric_valid		; we're at the end
	
	cmp byte [ds:si], '0'
	jb common_string_is_alphanumeric_invalid	; before '0'
	
	cmp byte [ds:si], '9'
	jbe common_string_is_alphanumeric_loop		; this character is a digit
	
	; not a digit
	
	call common_string_is_letter
	cmp ax, 0
	je common_string_is_alphanumeric_invalid
	
	jmp common_string_is_alphanumeric_loop		; next character
common_string_is_alphanumeric_invalid:
	mov ax, 0
	jmp common_string_is_alphanumeric_done
common_string_is_alphanumeric_valid:
	mov ax, 1							; "it is alphanumeric"
common_string_is_alphanumeric_done:	
	pop si
	ret
	
	
; Checks whether the specified character is an upper or lower case letter
;
; input:
;		BL - character
; output:
;		AX - 0 when character is not a letter, other value otherwise
common_string_is_letter2:
	push ds
	push si
	
	push cs
	pop ds
	mov si, commonStringSingleCharBuffer
	mov byte [ds:si], bl
	call common_string_is_letter
	
	pop si
	pop ds
	ret
	

; Checks whether the specified character is an upper or lower case letter
;
; input:
;	 DS:SI - pointer to character
; output:
;		AX - 0 when character is not a letter, other value otherwise
common_string_is_letter:
	mov ax, 0
	
	cmp byte [ds:si], 'A'
	jb common_string_is_letter_done		; too low to be an upper case letter
	cmp byte [ds:si], 'Z'
	jbe common_string_is_letter_valid	; it's an upper case letter

	cmp byte [ds:si], 'z'
	ja common_string_is_letter_done		; too high to be a lower case letter
	cmp byte [ds:si], 'a'
	jae common_string_is_letter_valid	; it's a lower case letter
	
	jmp common_string_is_letter_done
common_string_is_letter_valid:
	mov ax, 1
common_string_is_letter_done:
	ret
	

; Checks whether the specified string represents a decimal number.
; Supports prefixed sign.
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string does not represent a number, other value otherwise
common_string_is_numeric:
	push si
	
	cmp byte [ds:si], 0
	je common_string_is_numeric_no			; string is empty
	
	; see if first character is a sign
	cmp byte [ds:si], '+'
	je common_string_is_numeric_sign_read
	cmp byte [ds:si], '-'
	je common_string_is_numeric_sign_read
	
	; first character is not a sign, so start interpreting digits
	jmp common_string_is_numeric_check_digits
	
common_string_is_numeric_sign_read:
	inc si								; skip over sign
common_string_is_numeric_check_digits:
	cmp byte [ds:si], 0
	je common_string_is_numeric_no			; string has no characters after sign
	
common_string_is_numeric_loop:
	cmp byte [ds:si], 0
	je common_string_is_numeric_yes		; we reached the end
	
	cmp byte [ds:si], '0'
	jb common_string_is_numeric_no
	cmp byte [ds:si], '9'
	ja common_string_is_numeric_no
	
	inc si								; check next character
	jmp common_string_is_numeric_loop
common_string_is_numeric_yes:
	pop si
	mov ax, 1
	ret
common_string_is_numeric_no:
	pop si
	mov ax, 0
	ret

	
; Converts a signed 16bit integer to its string representation in decimal
; It works by potentially printing out a negative sign, after which it calls
; into an unsigned 32bit conversion routine (making the number positive 
; beforehand, when needed)
;
; input:
;		AX - the signed 16bit integer
;	 DS:SI - pointer to buffer where the string representation will be stored
; output:
;		none
common_string_signed_16bit_int_itoa:
	pusha
	
	cmp ax, 0				; is it a negative number?
	jge common_string_signed_16bit_int_itoa_convert	; no
	
	mov byte [ds:si], '-'	; write the - sign
	inc si					; advance character
	neg ax					; make it positive
common_string_signed_16bit_int_itoa_convert:
	mov dx, 0				; DX:AX now holds the number
	mov bl, 3				; option "no leading spaces"
	int 0A2h				; convert unsigned 32bit integer to string
	
	popa
	ret


; Parses a signed 16bit integer from its string representation in decimal
; Supports both sign prefixes
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - the signed 16bit integer
common_string_signed_16bit_int_atoi:
	push si
	
	cmp byte [ds:si], 0
	je common_string_signed_16bit_int_atoi_done	; empty string
	
	cmp byte [ds:si], '-'
	je common_string_signed_16bit_int_atoi_negative_with_sign
	
	cmp byte [ds:si], '+'
	jne common_string_signed_16bit_int_atoi_positive_without_sign
	; it's positive with sign
	inc si							; skip over sign
common_string_signed_16bit_int_atoi_positive_without_sign:
	int 0BEh						; AX := parsed integer
	jmp common_string_signed_16bit_int_atoi_done
common_string_signed_16bit_int_atoi_negative_with_sign:
	inc si							; skip over sign
	int 0BEh						; AX := parsed integer
	neg ax							; make it negative
common_string_signed_16bit_int_atoi_done:
	pop si
	ret

	
; Copies a zero-terminated string
;
; input:
;	 DS:SI - pointer to source string, zero-terminated
;	 ES:DI - pointer to destination string, zero-terminated
; output:
;		none
common_string_copy:
	pusha
	pushf
	
	cld
	int 0A5h			; BX := source string length
	mov cx, bx
	inc cx				; also copy terminator
	rep movsb			; copy characters
	
	popf
	popa
	ret


; Concatenates two strings
;
; input:
;	 DS:SI - pointer to left source string, zero-terminated
;	 FS:DX - pointer to right source string, zero-terminated
;	 ES:DI - pointer to destination string buffer
; output:
;		none
common_string_concat:
	push ds
	push es
	push fs
	pusha
	pushf
	
	call common_string_copy		; copy left string into ES:DI
	int 0A5h					; BX := left string length
	add di, bx					; move to terminator
	; now copy right string starting at the end of the left string
	push fs
	pop ds
	mov si, dx					; DS:SI := pointer to right string
	call common_string_copy		; copy right string into ES:DI
	
	popf
	popa
	pop fs
	pop es
	pop ds
	ret

	
; Creates a new string based on a subset of the specified string
;
; input:
;	 DS:SI - pointer to source string, zero-terminated
;	 ES:DI - pointer to where destination will be stored
;		BX - substring start index (inclusive)
;		CX - substring length
; output:
;		none
common_string_substring:
	pusha
	pushf
	cld
	
	add si, bx
	rep movsb
	mov byte [es:di], 0

	popf
	popa
	ret
	
	
; Compares two strings ASCII-wise, ignoring case on Latin letters
;
; input
;	 DS:SI - pointer to first string
;	 ES:DI - pointer to second string
; output
;		AX - 0 when the strings are equal
;			 1 when the first string is lower (ASCII-wise)
;			 2 when the second string is lower (ASCII-wise)
common_string_compare_ignore_case:
	push si
	push di
	
common_string_compare_ignore_case_loop:
	call common_string_compare_chars_ignore_case	; compares characters at
													; DS:SI and ES:DI
	cmp ax, 0
	je common_string_compare_ignore_case_current_chars_equal
	; they're different
	mov al, byte [ds:si]			; AL := first string character
	cmp al, byte [es:di]			; compare to second string character
	jb common_string_compare_ignore_case_return_first
									; a zero means first string is shorter
	ja common_string_compare_ignore_case_return_second
									; a zero means second string is shorter
common_string_compare_ignore_case_current_chars_equal:
	; they're equal
	cmp byte [ds:si], 0
	je common_string_compare_ignore_case_return_equal
									; if one is zero, both are zero
	; they're equal but non-zero
	inc si
	inc di
	jmp common_string_compare_ignore_case_loop			; next character
common_string_compare_ignore_case_return_first:
	mov ax, 1
	jmp common_string_compare_ignore_case_exit
common_string_compare_ignore_case_return_second:
	mov ax, 2
	jmp common_string_compare_ignore_case_exit
common_string_compare_ignore_case_return_equal:
	mov ax, 0
common_string_compare_ignore_case_exit:
	pop di
	pop si
	ret
	
	
; Compares two characters ASCII-wise, ignoring case on Latin letters
;
; input
;	 DS:SI - pointer to first character
;	 ES:DI - pointer to second character
; output
;		AX - 0 when the characters are equal, other value otherwise
common_string_compare_chars_ignore_case:
	push bx
	push cx
	
	mov cl, byte [ds:si]				; CL := first
	mov bl, byte [es:di]				; BL := second
	
	call common_string_is_letter		; considers character at DS:SI
	cmp ax, 0
	je common_string_compare_chars_ignore_case_compare_ASCII	; not letter
	
	call common_string_is_letter2		; considers character in BL
	cmp ax, 0
	je common_string_compare_chars_ignore_case_compare_ASCII	; not letter
	; both characters are letters
	or cl, 32
	or bl, 32							; convert both characters to upper case
	cmp bl, cl
	je common_string_compare_chars_ignore_case_equal
	jmp common_string_compare_chars_ignore_case_different
	
common_string_compare_chars_ignore_case_compare_ASCII:
	cmp byte [ds:si], bl
	je common_string_compare_chars_ignore_case_equal
	jmp common_string_compare_chars_ignore_case_different
common_string_compare_chars_ignore_case_equal:
	mov ax, 0
	jmp common_string_compare_chars_ignore_case_return
common_string_compare_chars_ignore_case_different:
	mov ax, 1
common_string_compare_chars_ignore_case_return:
	pop cx
	pop bx
	ret
	

; Finds first occurrence of the needle string into haystack string
;
; input
;	 DS:SI - pointer to haystack (string in which we search), zero-terminated
;	 ES:DI - pointer to needle (string we are looking for), zero-terminated
; output
;		AX - 0 when string was not found, other value otherwise	
;		BX - index at which the string was found, when found
common_string_first_indexof:
	push cx
	push dx
	push si
	push di

	mov bx, si								; BX := start of haystack
	
common_string_first_indexof__loop:
	call common_string_starts_with			; AX := 0 when doesn't start with
	cmp ax, 0
	jne common_string_first_indexof_yes		; it contains it
	
	; currently doesn't start with it
	cmp byte [ds:si], 0						; are we at the end of haystack?
	je common_string_first_indexof_no		; doesn't contain it
	
	; doesn't start with it, and we still have more to go
	inc si									; next haystack character
	jmp common_string_first_indexof__loop
	
common_string_first_indexof_yes:
	; here SI points to a character in the haystack
	; here BX points to start of haystack
	sub si, bx								; SI := index
	
	mov bx, si								; BX := index
	mov ax, 1
	jmp common_string_first_indexof_done
common_string_first_indexof_no:
	mov ax, 0
common_string_first_indexof_done:
	pop di
	pop si
	pop dx
	pop cx
	ret
	
	
; Checks whether one string begins with another string
;
; input
;	 DS:SI - pointer to haystack (string in which we search), zero-terminated
;	 ES:DI - pointer to needle (string we are looking for), zero-terminated
; output
;		AX - 0 when haystack does not begin with needle, other value otherwise
common_string_starts_with:
	push bx
	push cx
	push dx
	push si
	push di

	; we know needle is not longer
common_string_starts_with__loop:
	cmp byte [es:di], 0					; are we at the end of needle?
	je common_string_starts_with__yes	; yes, so we found it
	
	cmp byte [ds:si], 0					; are we at the end of haystack?
	je common_string_starts_with__no	; yes, so we didn't find it
	
	mov bl, byte [es:di]				; BL := current needle character
	cmp bl, byte [ds:si]				; is it equal to current haystack
										; character?
	jne common_string_starts_with__no	; no, so haystack doesn't begin
										; with needle
	inc si
	inc di								; next characters
	jmp common_string_starts_with__loop
	
common_string_starts_with__yes:
	mov ax, 1
	jmp common_string_starts_with_done
common_string_starts_with__no:
	mov ax, 0
common_string_starts_with_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret	


%endif
