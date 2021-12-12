;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The KEEPINST app.
; This app tests the "keep" functionality of the scheduler by installing a 
; user interrupt handler, and then exiting. The handler prints a message, 
; and then calls the previous handler.
;
; Once this app has installed its interrupt handler, the KEEPCALL app can then 
; be run to invoke the handler.
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
	
oldHandlerSeg: dw 0
oldHandlerOff: dw 0

message: db 13, 10, "Hello from user interrupt installed by KEEPINST!", 0

start:
	; register our interrupt handler
	cli							; we don't want interrupts firing before we've
								; saved the old handler address
	mov al, 0F0h				; we're registering for interrupt 0F0h
	mov di, interrupt_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)
	
	; save old handler address, so our handler can invoke it
	mov word [cs:oldHandlerOff], bx	; save offset of old handler
	mov word [cs:oldHandlerSeg], dx ; save segment of old handler
	sti							; we want interrupts to fire again
	
	; tell scheduler that we'd like to keep this task's memory after it exits
	mov bl, COMMON_FLAG_LIFETIME_KEEP_MEMORY_ON_EXIT
	int 0B5h					; set this task's lifetime to keep its memory, 
								; so that the interrupt handler we install can
								; be reached after this task exits
	
	int 95h						; exit


; We're installing this handler to interrupt 0F0h
;
; It prints a message, after which it calls the previous interrupt handler.
;
interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	;--------------------------------------------------------------------------
	; BEGIN PAYLOAD (as in, what this handler is supposed to do)
	;--------------------------------------------------------------------------
	pusha
	pushf
	push ds
	
	; print a message
	push cs
	pop ds
	mov si, message					; DS:SI now points to the message
	int 80h

	pop ds
	popf
	popa
	;--------------------------------------------------------------------------
	; END PAYLOAD
	;--------------------------------------------------------------------------
	
	; the idea now is to simulate calling the old handler via an "int" opcode
	; this takes two steps:
	;     1. pushing FLAGS, CS, and return IP (3 words)
	;     2. far jumping into the old handler, which takes two steps:
	;         2.1. pushing the destination segment and offset (2 words)
	;         2.2. using retf to accomplish a far jump
	
	; push registers to simulate the behaviour of the "int" opcode
	pushf													; FLAGS
	push cs													; return CS
	push word interrupt_handler_old_handler_return_address	; return IP

	; invoke previous handler
	; use retf to simulate a "jmp far [oldHandlerSeg]:[oldHandlerOff]"
	push word [cs:oldHandlerSeg]
	push word [cs:oldHandlerOff]
	retf						; invoke previous handler
	; old handler returns to the address immediately below
interrupt_handler_old_handler_return_address:		
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


%include "common\tasks.asm"