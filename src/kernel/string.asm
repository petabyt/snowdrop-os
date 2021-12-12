;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains string manipulation functionality.
; All strings are expected to end in an ASCII 0 terminator.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

emptyString:			db 0

stringTempBuffer: times 64 db 0				; used for formatting operations
FAT12_PAD_ASCII equ ' '


; Converts a 16-bit string representation of a decimal unsigned integer to an 
; unsigned integer.
;
; input
;		 DS:SI - pointer to string representation of integer (zero-terminated)
; output
;			AX - resulting integer
string_unsigned_16bit_atoi:
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, 0								; 0 is default for bad values
	cmp byte [ds:si], 0
	je string_unsigned_16bit_atoi_exit		; NOOP when empty string
	
	mov cx, 0								; CX will hold intermediate results
	mov bx, 1								; multiplier
	
	mov di, si
string_unsigned_16bit_atoi_go_to_units:
	cmp byte [ds:di+1], 0						; is DS:DI on the units digit?
	je string_unsigned_16bit_atoi_accumulate	; yes
	inc di										; no, move to the right
	jmp string_unsigned_16bit_atoi_go_to_units
string_unsigned_16bit_atoi_accumulate:
	; DS:DI now points to the units digit
	mov al, byte [ds:di]					; AL := ASCII of digit
	sub al, '0'								; AL := digit value
	mov ah, 0								; AX := digit value
	mul bx									; DX:AX := digit * multiplier
	; ASSUMPTION: DX=0, since the string contains a 16bit unsigned integers
	add ax, cx								; AX := intermediate result
	
	cmp si, di								; have we just accumulated the
											; most significant digit?
	je string_unsigned_16bit_atoi_exit		; yes, so we're done
	dec di									; no, move to the left
	
	mov cx, ax								; CX := intermediate result
	
	mov ax, bx								; AX := multiplier
	mov bx, 10
	mul bx									; DX:AX := multiplier * 10
	; ASSUMPTION: DX=0, since the string contains a 16bit unsigned integers
	mov bx, ax								; BX := multiplier * 10
	jmp string_unsigned_16bit_atoi_accumulate	; process this digit
string_unsigned_16bit_atoi_exit:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret


; Compares two strings ASCII-wise
;
; input
;		  DS:SI - pointer to first string
;		  ES:DI - pointer to second string
; output
;			AX - 0 when the strings are equal
;				 1 when the first string is lower (ASCII-wise)
;				 2 when the second string is lower (ASCII-wise)
string_compare:
	push si
	push di
	
string_compare_loop:
	mov al, byte [ds:si]			; AL := first string character
	cmp al, byte [es:di]			; compare to second string character
	jb string_compare_return_first	; a zero means first string is shorter
	ja string_compare_return_second	; a zero means second string is shorter
	; they're equal
	cmp al, 0
	je string_compare_return_equal	; if one is zero, both are zero
	; they're equal but non-zero
	inc si
	inc di
	jmp string_compare_loop			; next character
string_compare_return_first:
	mov ax, 1
	jmp string_compare_exit
string_compare_return_second:
	mov ax, 2
	jmp string_compare_exit
string_compare_return_equal:
	mov ax, 0
string_compare_exit:
	pop di
	pop si
	ret


; Converts string to upper case in-place 
;
; input
;			pointer to string in DS:SI
string_to_uppercase:
	pusha
	
	mov bx, -1							; begin at -1
string_to_uppercase_loop:	
	inc bx
	mov al, byte [ds:si+bx]				; AL := current character
	
	cmp al, 0							; if we're at end of string
	je string_to_uppercase_done			; then we're done
	
	cmp al, 'a'
	jb string_to_uppercase_loop ; ASCII code too low to be lowercase
	
	cmp al, 'z'
	ja string_to_uppercase_loop ; ASCII code too high to be lowercase
	
	sub al, 'a'-'A'
	mov byte [ds:si+bx], al				; subtract to bring case to upper
	
	jmp string_to_uppercase_loop ; next character
string_to_uppercase_done:	
	popa
	ret
	
	
; Converts a 32-bit unsigned integer to a decimal string.
; Adds ASCII 0 terminator at the end of the string.
; Ensures that, for a given formatting option, all numbers will be represented
; by strings that are equal in size.
; Works for numbers between 0 and 655,359,999 (270FFFFFh), inclusive, only.
;
; input
;		DX:AX - number to convert, no larger than 655,359,999 (270FFFFFh)
;		DS:SI - pointer to buffer where the result will be stored
;				(must be a minimum of 16 bytes long)
;		   BL - formatting option, as follows (for input 834104):
;				0 - no formatting, eg: "000834104"
;				1 - leading spaces, eg: "   834104"
;				2 - leading spaces and commas, eg: "   834,104"
;				3 - no leading spaces, eg: "834104"
;				4 - no leading spaces with commas, eg: "834,104"
; output
;		none
string_unsigned_32bit_itoa:
	pusha
	
	call string_unsigned_32bit_itoa_worker	; convert to string in DS:SI
	
	; select a formatting option
	cmp bl, 0
	je string_unsigned_32bit_itoa_done
	cmp bl, 1
	je string_unsigned_32bit_itoa_option_1
	cmp bl, 2
	je string_unsigned_32bit_itoa_option_2
	cmp bl, 3
	je string_unsigned_32bit_itoa_option_3
	cmp bl, 4
	je string_unsigned_32bit_itoa_option_4
	jmp string_unsigned_32bit_itoa_done
	
string_unsigned_32bit_itoa_option_1:
	call string_format_zeroes_to_blanks
	jmp string_unsigned_32bit_itoa_done

string_unsigned_32bit_itoa_option_2:
	call string_format_zeroes_to_blanks
	call string_format_add_commas
	jmp string_unsigned_32bit_itoa_done

string_unsigned_32bit_itoa_option_3:
	call string_format_zeroes_to_blanks
	call string_format_remove_leading
	jmp string_unsigned_32bit_itoa_done

string_unsigned_32bit_itoa_option_4:
	call string_format_zeroes_to_blanks
	call string_format_add_commas
	call string_format_remove_leading
	; flow into "done"
string_unsigned_32bit_itoa_done:
	popa
	ret

	
; Adds commas to a decimal string representation of a 32bit unsigned integer
; Example: "    82931" -> "82931"
;
; Assumption: string at DS:SI has blank spaces instead of leading zeroes
;
; input
;	 DS:SI - pointer to string containing a decimal number
;            assumes spaces instead of leading zeroes
string_format_remove_leading:
	pusha
	pushf
	push es
	
	cld
	
	mov di, stringTempBuffer
	push cs
	pop es						; ES:DI now points to our temp buffer

	push si						; [1] save input
	
string_format_remove_leading_copy_to_temp:
	lodsb						; AL := DS:SI++
	stosb						; ES:DI++ := AL
	cmp al, 0					; if we've just copied the terminator, we stop
	jne string_format_remove_leading_copy_to_temp	; we haven't
	
	mov di, stringTempBuffer	; ES:DI now points to our temp buffer
	pop si						; [1] restore input
	
	dec di						; start one earlier
string_format_remove_leading_skip_over_blanks:
	inc di
	cmp byte [es:di], ' '		; blank?
	je string_format_remove_leading_skip_over_blanks
	; here, DI points to the first non-blank
	
string_format_remove_leading_copy_result:
	mov al, byte [es:di]
	mov byte [ds:si], al		; move a byte from ES:DI to DS:SI
	inc di
	inc si
	cmp al, 0					; we stop after copying the terminator
	jne string_format_remove_leading_copy_result
	
	pop es
	popf
	popa
	ret
	

; Converts a 32-bit unsigned integer to a decimal string.
; Adds ASCII 0 terminator at the end of the string.
; Preserves leading zeroes, making the string 9 characters in length.
; Works for numbers between 0 and 655,359,999 (270FFFFFh), inclusive, only.
;
; The trick here is to divide DX:AX by 10,000. Since the input is no larger 
; than 655,359,999, we'll get a quotient between 0 and 65,535, and 
; a remainder of between 0 and 9,999.
; This lets us simply concatenate the 5-digit quotient and the 4-digit 
; remainder.
;
; input
;		DX:AX - number to convert, no larger than 655,359,999 (270FFFFFh)
;		DS:SI - pointer to buffer where the result will be stored
; output
;		none
string_unsigned_32bit_itoa_worker:
	pusha
	
	mov bx, 10000			; we're dividing DX:AX by 10,000
	div bx					; AX := quotient, DX := remainder
							; AX looks like XXXXX
							; DX looks like YYYY
	
	call string_unsigned_16bit_itoa_worker	; convert quotient to string
									; string now looks like "XXXXX"
	
	mov ax, dx
	call string_unsigned_16bit_itoa_worker	; covert remainder to string
									; string now looks like "XXXXXEYYYY"
									; where E is an extra digit due to the fact
									; that YYYY is actually a 4-digit number
									; with an extra leading zero
									; here, DS:SI points to right after last Y
	mov al, byte [ds:si-4]
	mov byte [ds:si-5], al			; shift the 1st Y digit left
	
	mov al, byte [ds:si-3]
	mov byte [ds:si-4], al			; shift the 2nd Y digit left
	
	mov al, byte [ds:si-2]
	mov byte [ds:si-3], al			; shift the 3rd Y digit left
	
	mov al, byte [ds:si-1]
	mov byte [ds:si-2], al			; shift the 4th Y digit left
	
	mov byte [ds:si-1], 0			; add terminator at the end
									; string now looks like "XXXXXYYYY_"
									; where _ is the terminator
	popa
	ret
	

; Adds commas to a decimal string representation of a 32bit unsigned integer
; Example: "    82931" -> "    82,931"
;
; Assumption: string at DS:SI has exactly 9 characters, and blank spaces
;             instead of leading zeroes
;
; input
;	 DS:SI - pointer to string containing a decimal number
;            assumes spaces instead of leading zeroes
string_format_add_commas:
	pushf
	pusha
	push ds
	push es
	
	mov cx, 2				; keeps track of how many blanks we need to add
							; (one for each comma not added)
	push si					; [1]
	
	push cs
	pop es
	
	push ds
	push cs
	pop ds
	mov di, stringTempBuffer	; ES:DI now points to temp buffer
	pop ds
	
	cld
	lodsb					; hundreds of millions digit
	stosb					; copy it
	
	lodsb					; tens of millions digit
	stosb					; copy it
	
	lodsb					; millions digit
	stosb					; copy it
	
	cmp al, ' '				; is there a millions digit?
	je string_format_add_commas_at_fourth_digit	; no
	
	; millions digit exists, so add a comma
	mov byte [es:di], ','	; add comma
	inc di
	dec cx					; decrement initial blanks counter
string_format_add_commas_at_fourth_digit:
	lodsb					; hundreds of thousands digit
	stosb					; copy it
	
	lodsb					; tens of thousands digit
	stosb					; copy it
	
	lodsb					; thousands digit
	stosb					; copy it
	cmp al, ' '				; is there a thousands digit?
	je string_format_add_commas_at_seventh_digit	; no
	
	; thousands digit exists, so add a comma
	mov byte [es:di], ','	; add comma
	inc di
	dec cx					; decrement initial blanks counter
string_format_add_commas_at_seventh_digit:
	push cx					; [2] save initial blanks counter
	mov cx, 3
	cld
	rep movsb				; copy hundreds, tens, and unit digits
	
	mov byte [es:di], 0		; add terminator to last position in the string
	pop cx					; [2] restore initial blanks counter
	
	; now copy string from the temp buffer to the user-specified buffer
	push ds
	pop es
	pop di					; [1] ES:DI now points to input string
	
	push cs
	pop ds
	mov si, stringTempBuffer ; DS:SI now points to the string in temp buffer
	
	; pad beginning (of ES:DI) with as many blanks as CX
	mov al, ' '				; pad beginning with a blank for each comma NOT
	cld						; added, so that small numbers generate equal
	rep stosb				; length strings as large numbers

	; now copy temp buffer into input buffer	
	cld
	mov cx, 13				; includes a few bytes of slack
	rep movsb				; copy string
	mov byte [es:di], 0		; add terminator
	
	pop es
	pop ds
	popa
	popf
	ret
	

; Converts leading zeroes to spaces
; Example: "000082931" -> "    82931"
;
; input
;	 DS:SI - pointer to string containing a decimal number
string_format_zeroes_to_blanks:
	pusha
	
string_format_zeroes_to_blanks_loop:
	cmp byte [ds:si], 0
	je string_format_zeroes_to_blanks_done	; are we at the end?
	; we're not at the end yet
	cmp byte [ds:si], '0'						; is this a zero?
	jne string_format_zeroes_to_blanks_exit	; no, we're done
	; it's a zero, so convert it to a space
	mov byte [ds:si], ' '
	
	inc si										; next digit
	jmp string_format_zeroes_to_blanks_loop	; loop again
string_format_zeroes_to_blanks_done:
	; here, DS:SI points at the terminator
	cmp byte [ds:si-1], ' '						; was the last digit ' '?
	jne string_format_zeroes_to_blanks_exit	; no, so the result is non-zero
	; yes, the last digit was ' ', meaning that our number
	; contained all zeroes
	mov byte [ds:si-1], '0'						; must have at least one digit
string_format_zeroes_to_blanks_exit:
	popa
	ret
	
	

; Helper which converts a 16-bit unsigned integer to a decimal string.
; Does NOT add ASCII 0 terminator after the number.
; Preserves leading zeroes, and prints exactly 5 digits (0-65535)
; Does NOT preserve DS:SI.
;
; input
;		   AX - number to convert
;		DS:SI - pointer to buffer where the result will be stored
; output
;		DS:SI - pointer to right after the output
string_unsigned_16bit_itoa_worker:
	push ax
	push bx
	push dx
	
	mov bx, 10000
	mov dx, 0				; we're dividing 0:AX by 10,000
	div bx					; AX := quotient, DX := remainder
							; AX is now between 0 and 6
	add al, '0'				; convert to ASCII
	mov byte [ds:si], al	; store character in string
	inc si					; next character
	
	mov ax, dx				; AX := remainder (4 digits max)
	mov bx, 1000
	mov dx, 0				; we're dividing 0:AX by 1,000
	div bx					; AX := quotient, DX := remainder
							; AX is now between 0 and 9
	add al, '0'				; convert to ASCII
	mov byte [ds:si], al	; store character in string
	inc si					; next character
	
	mov ax, dx				; AX := remainder (3 digits max)
	mov bx, 100
	mov dx, 0				; we're dividing 0:AX by 100
	div bx					; AX := quotient, DX := remainder
							; AX is now between 0 and 9
	add al, '0'				; convert to ASCII
	mov byte [ds:si], al	; store character in string
	inc si					; next character
	
	mov ax, dx				; AX := remainder (2 digits max)
	mov bx, 10
	mov dx, 0				; we're dividing 0:AX by 10
	div bx					; AX := quotient, DX := remainder
							; AX is now between 0 and 9
							; DX is now between 0 and 9
	add al, '0'				; convert to ASCII
	mov byte [ds:si], al	; store character in string
	inc si					; next character
	
	add dl, '0'				; here, DL holds the last digit
	mov byte [ds:si], dl	; store character in string
	inc si					; move to right past the last digit
	
	pop dx
	pop bx
	pop ax
	ret


; Returns the length of a ASCII 0 terminated string
;
; input
;		DS:SI - pointer to string
; output
;		   BX - string length, not including terminator
string_length:
	push ax
	
	mov bx, 0
	mov al, byte [ds:si+bx]
string_length_loop:
	cmp al, 0
	je string_length_done
	inc bx
	mov al, byte [ds:si+bx]
	jmp string_length_loop
string_length_done:
	pop ax
	ret


; Checks whether the specified 8.3 dot file name is valid:
;	Must contain one dot.
;	Must have between 1 and 8 characters before the dot.
;	Must have between 1 and 3 characters after the dot.
;
; Example: "abcd.000"
;          "abcdefgh.aaa"
;          "abc.a"
; input:
;	 DS:SI - pointer to 8.3 dot file name
; output:
;		AX - 0 when the file name is a valid 8.3 file name
string_validate_dot_filename:
	push cx
	push si
	
	mov cx, 0									; counts characters before dot
string_validate_dot_filename_first_8:
	cmp byte [ds:si], '.'						; did we find the dot?
	je string_validate_dot_filename_found_dot	; yes
	cmp byte [ds:si], 0							; did we find the terminator?
	je string_validate_dot_filename_invalid		; yes, so it's invalid
	; no, it's a regular character
	inc cx
	cmp cx, 9									; 9 characters without a dot?
	je string_validate_dot_filename_invalid		; yes, so it's invalid
	
	inc si
	jmp string_validate_dot_filename_first_8	; next character
string_validate_dot_filename_found_dot:
	; here, CX = number of characters before dot
	cmp cx, 0									; zero characters before dot?
	je string_validate_dot_filename_invalid		; yes, so it's invalid
	
	mov cx, 0									; counts characters after dot
	inc si										; point to character after dot
string_validate_dot_filename_last_3:
	cmp byte [ds:si], '.'						; did we find another dot?
	je string_validate_dot_filename_invalid		; yes, so it's invalid
	cmp byte [ds:si], 0							; did we find the terminator?
	je string_validate_dot_filename_reached_end	; yes
	
	; no, it's a regular character
	inc cx
	cmp cx, 4									; 4 chars or more after dot?
	je string_validate_dot_filename_invalid		; yes, so it's invalid
	
	inc si
	jmp string_validate_dot_filename_last_3		; next character
string_validate_dot_filename_reached_end:
	; here, CX = number of characters after dot
	cmp cx, 0									; zero characters after dot?
	je string_validate_dot_filename_invalid		; yes, so it's invalid
	
	; if we get here, the string represents a valid 8.3 file name
	pop si
	pop cx
	mov ax, 0
	ret

string_validate_dot_filename_invalid:
	pop si
	pop cx
	mov ax, 1
	ret
	

; Converts a 8.3 dot file name to a fixed-size, padded, upper-case 
; FAT12-compliant file name:
;	Must contain one dot.
;	Must have between 1 and 8 characters before the dot.
;	Must have between 1 and 3 characters after the dot.
;
; Example: "abcd.000" is converted to "ABCD    000"
;          "abcdefgh.aaa" is converted to "ABCDEFGHAAA"
;          "abc.a" is converted to "ABC       A"
; input:
;		DS:SI - pointer to 8.3 dot file name
;		ES:DI - pointer to buffer to hold the resulting FAT12 file name
; output:
;		(none, but fills buffer passed in)
string_convert_dot_filename_to_fat12:
	pushf
	pusha
	cld
	
	mov byte [es:di+11], 0		; add a terminator at the end of the output
								; buffer
	mov cx, 8
string_convert_filename_loop_first_8:
	movsb						; copy current character
	dec cx
	cmp byte [ds:si], '.'		; is next character '.' ?
	jne string_convert_filename_loop_first_8	; no

	; here, CX = padding needed for the 8-character name
	mov al, FAT12_PAD_ASCII
	rep stosb					; pad with spaces to ES:DI
	
	inc si						; move just past the '.'
	mov cx, 3
string_convert_filename_loop_last_3:
	movsb						; copy current character
	dec cx
	cmp byte [ds:si], 0			; is next character a terminator ?
	jne string_convert_filename_loop_last_3	; no
	
	; here, CX = padding needed for the 3-character extension
	mov al, FAT12_PAD_ASCII
	rep stosb					; pad with spaces to ES:DI

	popa						; restore register input values
	pusha
	
	push es
	pop ds
	push di
	pop si						; DS:SI := ES:DI
	call string_to_uppercase	; convert our result to upper case
	
	popa
	popf
	ret


; Converts a FAT12-compliant file name to a 8.3 dot file name 
;
; Example: "ABCD    000" is converted to "ABCD.000"
;          "ABCDEFGHAAA" is converted to "ABCDEFGH.AAA"
;          "ABC       A" is converted to "ABC.A"
; input:
;		DS:SI - pointer to FAT12-compliant file name
;		ES:DI - pointer to buffer to hold the resulting 8.3 dot file name
;				(must be able to hold at least 13 characters)
; output:
;		(none, but fills buffer passed in)
string_convert_fat12_to_dot_filename:
	pushf
	pusha
	
	cld
	mov cx, 8
string_convert_fat12_to_dot_filename_first_8:
	lodsb						; read char into AL
	
	cmp al, ' '					; spaces are ignored
	je string_convert_fat12_to_dot_filename_first_8_next_char
	; not a space, so copy it
	stosb
string_convert_fat12_to_dot_filename_first_8_next_char:
	loop string_convert_fat12_to_dot_filename_first_8

	mov al, '.'
	stosb						; store the dot between name and extension
	
	mov cx, 3
string_convert_fat12_to_dot_filename_last_3:
	lodsb
	
	cmp al, ' '					; spaces are ignored
	je string_convert_fat12_to_dot_filename_last_3_next_char
	; not a space, so copy it
	stosb
string_convert_fat12_to_dot_filename_last_3_next_char:
	loop string_convert_fat12_to_dot_filename_last_3
	
	mov byte [es:di], 0			; terminator
	
	popa
	popf
	ret
