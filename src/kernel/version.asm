;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains values usually changed with each Snowdrop OS version.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

snowdropOsVersionGreeting:
	db 'Welcome to Snowdrop OS version 31 (written by Sebastian Mihai)'	
	db 13		; home cursor to draw attributes right after
	db 0
	
snowdropOsVersionGreetingEnd: db 10, 0


; Prints a greeting and the Snowdrop OS version
;
; input
;		none
; output
;		none
version_print:
	pusha
	push ds

	mov si, snowdropOsVersionGreeting
	call debug_print_string
	
	mov dl, 1111b							; attributes
	mov cx, NUM_COLUMNS
	call display_vram_write_attribute
	
	mov si, snowdropOsVersionGreetingEnd
	call debug_print_string
	
	pop ds
	popa
	ret