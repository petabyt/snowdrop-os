;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The CLOCK app.
; This app displays the current system time in the top-right corner by
; remaining in memory after it is run.
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
	
	callCounter:	dw 0
	separator:		db ':', 0
	buffer:			times 2 db 0


start:
	; register our interrupt handler
	cli							; we don't want interrupts firing before we've
								; saved the old handler address
	mov al, 1Ch					; we're registering for timer interrupt 1Ch
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
	

; The main procedure
; NOTE: preserves no registers
;
; input:
;		none
; output:
;		none
display_main:
	mov ah, 0Fh
	int 10h						; AL := video mode
	cmp al, 3					; we only support this mode
	jne display_main_done		; NOOP when unsupported video mode
	
	clc
	mov ah, 2
	int 1Ah
	jc display_main_done		; RTC error, so we do nothing
	
	call common_screenh_get_cursor_position		; BX := cursor position
	push bx						; [1] save initial cursor position
	
	mov bh, 0
	mov bl, COMMON_SCREENH_WIDTH - 8
	call common_screenh_move_hardware_cursor
	
	push cs
	pop ds
	
	mov al, ch
	call print_2bcd_digits		; hours

	mov si, separator
	int 80h

	mov al, cl
	call print_2bcd_digits		; minutes
	
	mov si, separator
	int 80h
	
	mov al, dh
	call print_2bcd_digits		; seconds

	pop bx								; [1] restore initial cursor position
	call common_screenh_move_hardware_cursor
display_main_done:
	ret
	

; Prints two BCD digits contained in a byte	
;
; input:
;		AL - contains two BCD digits (F)irst and (S)econd FFFFSSSS
; output:
;		none
print_2bcd_digits:
	push ax
	push si
	
	mov si, buffer
	
	ror al, 4
	mov byte [cs:buffer], al
	and byte [cs:buffer], 0Fh	; clear four MSBs
	add byte [cs:buffer], '0'	; convert to ASCII
	int 80h
	
	ror al, 4
	mov byte [cs:buffer], al
	and byte [cs:buffer], 0Fh	; clear four MSBs
	add byte [cs:buffer], '0'	; convert to ASCII
	int 80h
	
	pop si
	pop ax
	ret

	
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
	inc word [cs:callCounter]
	test word [cs:callCounter], 7
	jnz interrupt_handler_invoke_previous		; NOOP this time
	
	pusha
	pushf
	push ds

	call display_main
	
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

interrupt_handler_invoke_previous:	
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
%include "common\screenh.asm"
