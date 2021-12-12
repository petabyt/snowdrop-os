;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains routines for dealing with unrecoverable errors.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

crashBeginMessage:	db 13, 10, 'An unrecoverable error has occurred.'
					db 13, 10, 'Snowdrop OS kernel is halting the CPU:'
					db 13, 10
					db 176, 176, 176, 176, 176
					db 0
					
crashDotProgress:	db 178, 0
crashCursorHome:	db 13, 0

; input:
;		SI - near pointer to message
crash_and_print:
	push cs
	pop ds
	call debug_print_string

crash:
	cmp byte [cs:interruptsInitialized], 0
	je crash_after_register_dump	; if interrupts not initialized, don't dump
	int 0B4h						; dump registers and stack

crash_after_register_dump:	
	push cs
	pop ds
	mov si, crashBeginMessage
	call debug_print_string

	cmp byte [cs:interruptsInitialized], 0
	je crash_halt	; if interrupts not initialized, don't wait
	
	mov si, crashCursorHome
	int 80h
crash_halt_prepare:
	push cs
	pop ds
	; delay to allow things like floppy drive motors to stop spinning
	mov cx, 100
	mov si, crashDotProgress
	int 80h
	
	int 85h
	int 80h
	int 85h
	int 80h
	int 85h
	int 80h
	int 85h
	int 80h
	int 85h

crash_halt:
	cli
	hlt
	jmp crash_halt
