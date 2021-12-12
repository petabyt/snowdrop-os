;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for dumping text to the screen.
; These routines are unsuitable for normal text output, as they bypass virtual 
; displays, outputting via BIOS.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DEBUG_
%define _COMMON_DEBUG_

commonDebugNewLineString:			db 13, 10, 0

; input:
;		none
debug_wait_for_key_and_shutdown:
	mov ah, 0
	int 16h
	int 9Bh

; input:
;		none
common_debug_print_newline:
	pusha
	mov si, commonDebugNewLineString
	call common_debug_print_string
	popa
	ret

; input:
;		DS:SI pointer to string
common_debug_println_string:
	pusha
	call common_debug_print_string
	mov si, commonDebugNewLineString
	call common_debug_print_string
	popa
	ret
	
; input:
;		DS:SI pointer to string
common_debug_print_string:
	pusha
	mov ah, 0Eh
	mov bx, 7		; gray colour, black background
common_debug_print_string_loop:
	lodsb
	cmp al, 0		; strings are 0-terminated
	je common_debug_print_string_end
	int 10h
	jmp common_debug_print_string_loop
common_debug_print_string_end:	
	popa
	ret

; input:
;		word in AX
common_debug_print_word:
	pusha
	xchg al, ah
	call common_debug_print_byte
	xchg al, ah
	call common_debug_print_byte
	popa
	ret

; input:
;		byte in AL
common_debug_print_byte:
	pusha
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call common_debug_hex_digit_to_char
	call common_debug_print_char	; print tens digit
	
	mov al, ah
	call common_debug_hex_digit_to_char
	call common_debug_print_char	; print units digit
	
	popa
	ret


; input:
;			hex digit in AL
; output:
;			printable hex char in AL
common_debug_hex_digit_to_char:
	cmp al, 9
	jbe common_debug_hex_digit_to_char_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
common_debug_hex_digit_to_char_under9:
	add al, '0'
	ret


; input:
;		DS:SI pointer to string
;		character count in CX
common_debug_print_dump:
	pusha
common_debug_print_dump_loop:
	lodsb			; AL := byte at DS:SI
	call common_debug_convert_non_printable_char
	call common_debug_print_char
	dec cx
	jne common_debug_print_dump_loop
	
	popa
	ret


; Potentially converts the provided character so that it can be printed.
; Such characters include backspace, line feed, etc.
;
; input:
;		AL - character to convert to printable
common_debug_convert_non_printable_char:
	cmp al, COMMON_ASCII_NULL
	je common_debug_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BELL
	je common_debug_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BACKSPACE
	je common_debug_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_TAB
	je common_debug_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_LINE_FEED
	je common_debug_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_CARRIAGE_RETURN
	je common_debug_convert_non_printable_char_convert
	
	ret
common_debug_convert_non_printable_char_convert:
	mov al, '?'
	ret


common_debug_print_blank:
	pusha
	mov al, ' '
	call common_debug_print_char 
	popa
	ret


; input:
;		ASCII in AL
common_debug_print_char:
	pusha
	mov ah, 0Eh
	mov bx, 7		; gray colour, black background
	int 10h
	popa
	ret
	
	
; Convert a hex digit to its character representation
; Example: 10 -> 'A'
;
; input:
;		AL - hex digit
; output:
;		CL - hex digit to char
common_debug_hex_digit_to_char2:
	push ax
	cmp al, 9
	jbe common_debug_hex_digit_to_char2_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
common_debug_hex_digit_to_char2_under9:
	add al, '0'
	mov cl, al
	pop ax
	ret
	
	
; Renders a byte as two hex digit characters
; Example: 20 -> "1" "8"
;
; input:
;		AL - byte to render
; output:
;		CX - two characters which represent the input
common_debug_byte_to_hex:
	push ax
	push bx
	push dx
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call common_debug_hex_digit_to_char2		; CL := char
	mov ch, cl
	mov al, ah
	call common_debug_hex_digit_to_char2		; CL := char
	
	pop dx
	pop bx
	pop ax
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
common_debug_string_to_hex:
	pusha
	push ds
	push es
	
common_debug_string_to_hex_loop:
	cmp bx, 0							; done?
	je common_debug_string_to_hex_loop_done
	
	mov al, byte [ds:si]
	call common_debug_byte_to_hex		; CH := msb, CL := lsb

	mov byte [es:di], ch
	inc di
	mov byte [es:di], cl
	inc di
	
	inc si								; next source character
	dec bx
	
	test dx, 2							; add space after byte?
	jz common_debug_string_to_hex_loop			; no
	; yes
	mov byte [es:di], ' '
	inc di
	jmp common_debug_string_to_hex_loop			; next byte
	
common_debug_string_to_hex_loop_done:
	test dx, 1							; zero-terminate?
	jz common_debug_string_to_hex_done			; no
	; yes
	mov byte [es:di], 0

common_debug_string_to_hex_done:	
	pop es
	pop ds
	popa
	ret
	

%include "ascii.asm"

%endif
