;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The SERINTR (serial interrupt) test app.
; This app is meant to show how to register an interrupt handler to receive
; bytes read from the serial port, printing each one to the screen.
;
; Additionally, any key presses except for the "exit" key will be sent over 
; the serial port.
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop app contract:
;
; At startup, the app can assume:
;	- the app is loaded at offset 0
;	- all segment registers equal CS
;	- the stack is valid (SS, SP)
;	- BP equals SP
;	- direction flag is clear (string operations count upwards)
;
; The app must:
;	- call int 95h to exit
;	- not use the entire 64kb memory segment, as its own stack begins from 
;	  offset 0FFFFh, growing upwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16						; the CPU is assumed to function in 16-bit mode
	org 0						; apps are loaded at offset 0 by the caller
	
	jmp start


noSerialDriverMessage: 	db "No serial port driver present. Exiting...", 0
introMessage:			db "This program shows how to register an interrupt handler which receives bytes from the serial port.", 13, 10, 13, 10,
						db "Any key presses will be sent over serial.", 13, 10, 0
receivedMessage:		db "(PRESS [Q] TO EXIT) Received:", 13, 10, 0

oldInterruptHandlerSegment:	dw 0	; these are used to save and then restore
oldInterruptHandlerOffset:	dw 0	; the previous interrupt handler

lastReceivedCharacter:	db " ", 0 	; will be printed as a string

start:
	int 0ADh					; AL := serial driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_serial				; print error message and exit
	
	int 83h						; clear keyboard buffer
	
	mov si, introMessage
	int 80h
	
	mov si, receivedMessage
	int 80h
	
	call register_interrupt_handler	; register our interrupt handler
	
	; from here on, the main loop simply checks to see if the Q key was 
	; pressed, exiting when that happens
main_loop:
	mov ah, 0
	int 16h						; read key
	cmp al, 'q'
	je exit 					; lower case Q was pressed
	cmp al, 'Q'
	je exit 					; upper case Q was pressed

	int 0AFh					; all other keys are sent over serial
	
	cmp al, 13					; was the key ENTER?
	jne main_loop				; no, process next key
	mov al, 10					; yes, it was ENTER
	int 0AFh					; send an additional ASCII 10 for ENTER
	jmp main_loop				; Q key was not pressed, so loop again

no_serial:
	mov si, noSerialDriverMessage
	int 80h						; print message
	int 95h						; exit
	
exit:
	call restore_interrupt_handler	; restore old interrupt handler
	int 95h						; exit


; Registers our interrupt handler for interrupt 0AEh, Snowdrop OS serial port
; driver's "serial user interrupt".
;
register_interrupt_handler:
	pusha

	pushf
	cli
	mov al, 0AEh				; we're registering for interrupt 0AEh
	mov di, interrupt_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)
	mov word [cs:oldInterruptHandlerOffset], bx	 ; save offset of old handler
	mov word [cs:oldInterruptHandlerSegment], dx ; save segment of old handler
	popf
	
	popa
	ret
	

; Restores the previous interrupt 0AEh handler (that is, before this program
; started).
;
restore_interrupt_handler:
	pusha
	push es

	mov di, word [cs:oldInterruptHandlerOffset]
	mov ax, word [cs:oldInterruptHandlerSegment]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 0AEh				; we're registering for interrupt 0AEh
	int 0B0h					; register interrupt handler

	pop es
	popa
	ret
	

; This is our interrupt handler, which will be registered with interrupt 0AEh.
; It will be called by the serial port driver whenever it has a byte for us.
;
; input:
;		AL - byte read from serial port
;
interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	push cs
	pop ds
	
	mov byte [lastReceivedCharacter], al	; store whatever we just read
	mov si, lastReceivedCharacter
	int 80h						; print character
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control
