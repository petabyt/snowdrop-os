;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for displaying hexadecimal numbers.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_HEX_
%define _COMMON_HEX_

COMMON_HEX_MAX_PRINT_CHARACTER_COUNT	equ 128

commonHexSourceBuffer:			dw 0
commonHexNumberToHexBuffer:		times 2 db 0
commonHexPrintMemoryBuffer:		times 4*COMMON_HEX_MAX_PRINT_CHARACTER_COUNT + 1 db 0
			; depending on formatting options, we might print more than
			; two ASCII characters per byte

commonHexTooLong:	db '(common hex): string too long', 0


; Prints a hex word to hardware screen, MSB first
;
; input:
;		AX - the number
; output:
;		none
common_hex_print_word_to_hardware:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, commonHexSourceBuffer
	xchg ah, al							; humans expect MSB first
	mov word [ds:si], ax
	mov bx, 2
	mov dx, 0							; non-spaced	
	call common_hex_print_memory_dump_to_hardware
	
	pop ds
	popa
	ret


; Prints a hex word to screen, MSB first
;
; input:
;		AX - the number
; output:
;		none
common_hex_print_word:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, commonHexSourceBuffer
	xchg ah, al							; humans expect MSB first
	mov word [ds:si], ax
	mov bx, 2
	mov dx, 0							; non-spaced
	call common_hex_print_memory_dump
	
	pop ds
	popa
	ret


; Dumps memory to screen as byte values.
; Example: 10 2F 38 ...
;
; input:
;	 DS:SI - pointer to starting memory location
;		BX - string length
; output:
;		none
common_hex_print_memory_dump_spaced:
	pusha
	mov dx, 2
	call common_hex_print_memory_dump
	popa
	ret
	
	
; Dumps memory to hardware screen as byte values.
; Example: 10 2F 38 ...
;
; input:
;	 DS:SI - pointer to starting memory location
;		BX - string length
;		DX - formatting options:
;			 bit 1: whether to add a space after each byte
; output:
;		none
common_hex_print_memory_dump_to_hardware:
	pusha
	push ds
	push es
	
	cmp bx, COMMON_HEX_MAX_PRINT_CHARACTER_COUNT
	ja common_hex_print_memory_dump_to_hardware_too_long
	
	or dx, 1							; zero-terminate
	
	push cs
	pop es
	mov di, commonHexPrintMemoryBuffer		; ES:DI := buffer
	call common_hex_string_to_hex
	
	push cs
	pop ds
	mov si, commonHexPrintMemoryBuffer
	int 80h
	jmp common_hex_print_memory_dump_to_hardware_done

common_hex_print_memory_dump_to_hardware_too_long:
	push cs
	pop ds
	mov si, commonHexTooLong
	int 80h
	
common_hex_print_memory_dump_to_hardware_done:	
	pop es
	pop ds
	popa
	ret
	

; Dumps memory to screen as byte values.
; Example: 10 2F 38 ...
;
; input:
;	 DS:SI - pointer to starting memory location
;		BX - string length
;		DX - formatting options:
;			 bit 1: whether to add a space after each byte
; output:
;		none
common_hex_print_memory_dump:
	pusha
	push ds
	push es
	
	cmp bx, COMMON_HEX_MAX_PRINT_CHARACTER_COUNT
	ja common_hex_print_memory_dump_too_long
	
	or dx, 1							; zero-terminate
	
	push cs
	pop es
	mov di, commonHexPrintMemoryBuffer		; ES:DI := buffer
	call common_hex_string_to_hex
	
	push cs
	pop ds
	mov si, commonHexPrintMemoryBuffer
	int 97h
	jmp common_hex_print_memory_dump_done

common_hex_print_memory_dump_too_long:
	push cs
	pop ds
	mov si, commonHexTooLong
	int 97h
	
common_hex_print_memory_dump_done:	
	pop es
	pop ds
	popa
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
common_hex_string_to_hex:
	pusha
	push ds
	push es
	
common_hex_string_to_hex_loop:
	cmp bx, 0							; done?
	je common_hex_string_to_hex_loop_done
	
	mov al, byte [ds:si]
	call common_hex_byte_to_hex				; CH := msb, CL := lsb

	mov byte [es:di], ch
	inc di
	mov byte [es:di], cl
	inc di
	
	inc si								; next source character
	dec bx
	
	test dx, 2							; add space after byte?
	jz common_hex_string_to_hex_loop			; no
	; yes
	mov byte [es:di], ' '
	inc di
	jmp common_hex_string_to_hex_loop			; next byte
	
common_hex_string_to_hex_loop_done:
	test dx, 1							; zero-terminate?
	jz common_hex_string_to_hex_done			; no
	; yes
	mov byte [es:di], 0

common_hex_string_to_hex_done:	
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
common_hex_word_to_hex:
	pusha
	push ds
	push es
	
	mov word [cs:commonHexNumberToHexBuffer], ax
	
	push cs
	pop ds
	mov si, commonHexNumberToHexBuffer
	mov bx, 2
	call common_hex_string_to_hex
	
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
common_hex_byte_to_hex:
	push ax
	push bx
	push dx
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call common_hex_hex_digit_to_char		; CL := char
	mov ch, cl
	mov al, ah
	call common_hex_hex_digit_to_char		; CL := char
	
	pop dx
	pop bx
	pop ax
	ret


; Convert a hex digit to its character representation
; Example: 10 -> 'A'
;
; input:
;		AL - hex digit
; output:
;		CL - hex digit to char
common_hex_hex_digit_to_char:
	push ax
	cmp al, 9
	jbe common_hex_hex_digit_to_char_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
common_hex_hex_digit_to_char_under9:
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
common_hex_copy_string_and_advance:
	push bx
	
	call common_string_copy
	int 0A5h									; BX := source string length
	add di, bx
	
	pop bx
	ret
	
%endif
