;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains debugging routines (mostly output to screen) 
; mainly used by the kernel itself.
; If debugging is needed within an app, the app can simply include this file
; to gain access to the routines here.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASCII_NULL equ 0
ASCII_BELL equ 7
ASCII_TAB equ 9

newLineString:			db 13, 10, 0


; input:
;		none
debug_wait_for_key_and_shutdown:
	mov ah, 0
	int 16h
	int 9Bh


; input:
;		none
debug_print_newline:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, newLineString
	call debug_print_string
	
	pop ds
	popa
	ret

	
; input:
;		DS:SI pointer to string
debug_println_string:
	pusha
	call debug_print_string
	mov si, newLineString
	call debug_print_string
	popa
	ret
	
; input:
;		DS:SI pointer to string
debug_print_string:
	pusha
	mov ah, 0x0E
	mov bx, 0x0007	; gray colour, black background
debug_print_string_loop:
	lodsb
	cmp al, 0		; strings are 0-terminated
	je debug_print_string_end
	int 10h
	jmp debug_print_string_loop
debug_print_string_end:	
	popa
	ret

; input:
;		word in AX
debug_print_word:
	pusha
	xchg al, ah
	call debug_print_byte
	xchg al, ah
	call debug_print_byte
	popa
	ret

; input:
;		byte in AL
debug_print_byte:
	pusha
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call hex_digit_to_char
	call debug_print_char	; print tens digit
	
	mov al, ah
	call hex_digit_to_char
	call debug_print_char	; print units digit
	
	popa
	ret
	
; input:
;			hex digit in AL
; output:
;			printable hex char in AL
hex_digit_to_char:
	cmp al, 9
	jbe hex_digit_to_char_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
hex_digit_to_char_under9:
	add al, '0'
	ret
	
; input:
;		DS:SI pointer to string
;		character count in CX
debug_print_dump:
	pusha
debug_print_dump_loop:
	lodsb			; AL := byte at DS:SI
	call debug_convert_non_printable_char
	call debug_print_char
	dec cx
	jne debug_print_dump_loop
	
	popa
	ret


; Potentially converts the provided character so that it can be printed.
; Such characters include backspace, line feed, etc.
;
; input:
;		AL - character to convert to printable
debug_convert_non_printable_char:
	cmp al, ASCII_NULL
	je debug_convert_non_printable_char_convert
	cmp al, ASCII_BELL
	je debug_convert_non_printable_char_convert
	cmp al, ASCII_BACKSPACE
	je debug_convert_non_printable_char_convert
	cmp al, ASCII_TAB
	je debug_convert_non_printable_char_convert
	cmp al, ASCII_LINE_FEED
	je debug_convert_non_printable_char_convert
	cmp al, ASCII_CARRIAGE_RETURN
	je debug_convert_non_printable_char_convert
	
	ret
debug_convert_non_printable_char_convert:
	mov al, '?'
	ret
	
	
debug_print_blank:
	pusha
	mov al, ' '
	call debug_print_char 
	popa
	ret
	
; input:
;		ASCII in AL
debug_print_char:
	pusha
	mov ah, 0x0E
	mov bx, 0x0007	; gray colour, black background
	int 10h
	popa
	ret
