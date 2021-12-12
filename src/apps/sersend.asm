;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The SERSEND (serial poll) test app.
; This app sends an ASCII message to the serial port.
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
sendingMessage:		db "Sending 'Hello, serial!' over the serial port... ", 13, 10, 0
messageToSend:		db "Hello, serial!", 0

start:
	int 0ADh					; AL := serial driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_serial				; print error message and exit
	
	mov si, sendingMessage
	int 80h
	
	mov si, messageToSend
main_loop:
	mov al, byte [ds:si]		; get character from message
	int 0AFh					; send character over serial
	
	mov cx, 6
	int 85h						; delay
	
	inc si						; next character
	cmp byte [ds:si], 0			; terminator?
	je exit						; yes, so we're done
	jmp main_loop				; no, so process next character

no_serial:
	mov si, noSerialDriverMessage
	int 80h						; print message
	int 95h						; exit
	
exit:
	int 95h						; exit
