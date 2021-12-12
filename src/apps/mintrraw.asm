;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MINTRRAW (Mouse Interrupt Raw) test app.
; This app is meant to show how to register an interrupt handler to receive raw
; mouse data.
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

noMouseDriverMessage: 	db "No mouse driver present. Exiting...", 0
introMessage:			db "This program shows how to register an interrupt handler which receives raw mouse data bytes.", 13, 10, 13, 10, 0
lastPolledMessage:		db 13, "(PRESS [Q] TO EXIT) Last three raw mouse data bytes: ", 0
				; printing ASCII 13 is like pressing Home key
blankSpaceMessage:		db " ", 0

oldInterruptHandlerSegment:	dw 0	; these are used to save and then restore
oldInterruptHandlerOffset:	dw 0	; the previous interrupt handler

oldKeyboardDriverMode:		dw 99


start:
	int 83h						; clear keyboard buffer
	
	int 8Dh						; AL := mouse driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_mouse					; print error message and exit
	
	mov si, introMessage
	int 80h
	
	mov si, lastPolledMessage
	int 80h						; print message a first time, before the mouse
								; sends any events
	
	call register_interrupt_handler	; register our interrupt handler
	
	; use Snowdrop OS's keyboard driver
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:oldKeyboardDriverMode], ax	; save it
	mov ax, 1
	int 0BCh					; change keyboard driver mode
	
	; from here on, the main loop simply checks to see if the Q key was 
	; pressed, exiting when that happens
main_loop:
	mov bl, COMMON_SCAN_CODE_Q
	int 0BAh
	cmp al, 0					; not pressed?
	je main_loop				; Q key was not pressed, so loop again
	jmp exit					; it was pressed, so we're done
	
no_mouse:
	mov si, noMouseDriverMessage
	int 80h						; print message
	int 95h						; exit

exit:
	call restore_interrupt_handler	; restore old interrupt handler
	mov ax, word [cs:oldKeyboardDriverMode]
	int 0BCh					; change keyboard driver mode
	int 95h						; exit


	

	
; Restores the previous interrupt 8Bh handler (that is, before this program
; started).
;	
restore_interrupt_handler:
	pusha
	push es

	mov di, word [cs:oldInterruptHandlerOffset]
	mov ax, word [cs:oldInterruptHandlerSegment]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 8Bh					; we're registering for interrupt 8Bhh
	int 0B0h					; register interrupt handler

	pop es
	popa
	ret
	

; Registers our interrupt handler for interrupt 8Bh, Snowdrop OS mouse
; driver's "raw mouse data interrupt".
;
register_interrupt_handler:
	pusha

	pushf
	cli
	mov al, 8Bh					; we're registering for interrupt 8Bhh
	mov di, interrupt_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)
	mov word [cs:oldInterruptHandlerOffset], bx	 ; save offset of old handler
	mov word [cs:oldInterruptHandlerSegment], dx ; save segment of old handler
	popf
	
	popa
	ret
	

; This is our interrupt handler, which will be registered with interrupt 8Bh.
; It will be called by the PS/2 mouse driver every time there's a mouse event,
; being given the 3 bytes which describe what the mouse did.
; 
; WARNING: By registering this handler, we're overriding the mouse driver's 
;          handler. This effectively disables downstream consumers, such as
;          "managed" mouse mode interrupts otherwise made available by the 
;          kernel.
;
; input:
;		BH - bit 7 - Y overflow
;			 bit 6 - X overflow
;			 bit 5 - Y sign bit
;			 bit 4 - X sign bit
;			 bit 3 - unused and indeterminate
;			 bit 2 - middle button
;			 bit 1 - right button
;			 bit 0 - left button
;		DH - X movement (delta X)
;		DL - Y movement (delta Y)
interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	; BEGIN actual interrupt handler work
	; the int 80h calls below take pointers via DS:SI, so we must set DS
	; correctly, to the current code segment
	push cs
	pop ds						; DS := CS
	
	mov si, lastPolledMessage
	int 80h						; print message
	
	mov al, bh					; AL := byte 0 of mouse data
	int 8Eh						; print byte in AL to screen
	mov si, blankSpaceMessage
	int 80h						; print a blank space
	
	mov al, dh					; AL := byte 1 of mouse data
	int 8Eh						; print byte in AL to screen
	mov si, blankSpaceMessage
	int 80h						; print a blank space
	
	mov al, dl					; AL := byte 2 of mouse data
	int 8Eh						; print byte in AL to screen
	; END actual interrupt handler work
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control

%include "common\scancode.asm"