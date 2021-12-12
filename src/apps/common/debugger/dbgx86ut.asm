;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains various utility routines for Snowdrop OS's debugger.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DBGX86_UTILITIES_
%define _COMMON_DBGX86_UTILITIES_


dbgx86UtilHexAtoiBuffer:	times 64 db 0
dbgx86UtilHexCheckBuffer:	times 64 db 0
dbgx86UtilHexWordBuffer:	times 5 db 0

	
; Gets the numeric value represented by a hex word 
; represented as an ASCII string.
; Assumes the string contains a valid hex number.
;
; input:
;	 DS:SI - pointer to zero-terminated string
; output:
;		AX - numeric value
dbgx86Util_hex_atoi:
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
	mov di, dbgx86UtilHexAtoiBuffer	; ES:DI := pointer to buffer
	call common_string_copy			; copy into ES:DI
	push es
	pop ds
	mov si, di					; DS:SI := pointer to string copy
	int 82h						; convert to uppercase
	
	add si, bx
	dec si						; DS:SI := pointer to last digit

	mov cl, 0					; power of 2 that corresponds to last character
	mov ax, 0					; accumulates result
dbgx86Util_hex_atoi_loop:
	mov dl, byte [ds:si]
	cmp dl, '0'										; is it a number?
	jb dbgx86Util_hex_atoi_loop_letter	; no
	cmp dl, '9'
	ja dbgx86Util_hex_atoi_loop_letter
	; this digit is 0-9
	sub dl, '0'					; DL := numeric value of digit
	jmp dbgx86Util_hex_atoi_loop_accumulate
dbgx86Util_hex_atoi_loop_letter:
	; here, DL contains an uppercase letter
	sub dl, 'A'					
	add dl, 10					; DL := numeric value of digit
	
dbgx86Util_hex_atoi_loop_accumulate:
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
	jae dbgx86Util_hex_atoi_loop	; no, so keep going
	; yes, so we just ran out of characters
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret
	
	
; Checks whether the specified string contains a valid hex number
; Valid hex number strings must:
;     - be at least 1 characters long
;     - contain only characters 0-9, a-f, A-F
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid hex number string, other
;			 value otherwise	
dbgx86Util_is_hex_number_string:
	push ds
	push es
	push bx
	push si
	push di
	
	int 0A5h					; BX := string length
	cmp bx, 1					; too short
	jb dbgx86Util_is_hex_number_string_invalid

	push cs
	pop es
	mov di, dbgx86UtilHexCheckBuffer	; ES:DI := pointer to buffer
	call common_string_copy				; copy into ES:DI
	push es
	pop ds
	mov si, di					; DS:SI := pointer to string copy
	int 82h						; convert to uppercase
	
dbgx86Util_is_hex_number_string_loop:
	; first try letter
	cmp byte [ds:si], 'A'
	jb dbgx86Util_is_hex_number_string_loop_try_digit	; it's not a letter
	cmp byte [ds:si], 'F'
	ja dbgx86Util_is_hex_number_string_loop_try_digit
	jmp dbgx86Util_is_hex_number_string_loop_next		; it's a valid character

dbgx86Util_is_hex_number_string_loop_try_digit:
	cmp byte [ds:si], '0'
	jb dbgx86Util_is_hex_number_string_invalid
	cmp byte [ds:si], '9'
	ja dbgx86Util_is_hex_number_string_invalid
	
dbgx86Util_is_hex_number_string_loop_next:
	inc si
	cmp byte [ds:si], 0							; are we at the end?
	jne dbgx86Util_is_hex_number_string_loop	; no, keep going
		
	mov ax, 1					; valid
	jmp dbgx86Util_is_hex_number_string_done

dbgx86Util_is_hex_number_string_invalid:
	mov ax, 0
	
dbgx86Util_is_hex_number_string_done:
	pop di
	pop si
	pop bx
	pop es
	pop ds
	ret
	

%endif
