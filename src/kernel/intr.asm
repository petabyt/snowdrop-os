;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains routines for managing interrupt handlers.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INTERRUPT_VECTOR_TABLE 		equ 0000h


; Installs the specified interrupt handler, returning a pointer to the old
; (previous) interrupt handler.
; The returned old interrupt handler pointer allows consumers to restore the 
; previous handler during their clean-up.
;
; input
;		AL - interrupt number
;		ES:DI - pointer to interrupt handler to install
; output:
;		DX:BX - pointer to old interrupt handler
;
interrupt_handler_install:
	push ax
	push si
	push ds
	push es
	
	mov ah, 0				; AX := interrupt number
	shl ax, 2				; each interrupt vector is 4 bytes long
	mov si, ax				; SI := byte offset of user-specified entry
	
	mov ax, INTERRUPT_VECTOR_TABLE
	mov ds, ax				; DS := IVT segment
	; DS:SI now points to 2-word interrupt vector
	
	mov word bx, [ds:si]	; BX := old handler offset
	mov word dx, [ds:si+2]	; DX := old handler segment
	; DX:BX now points to the old interrupt handler
	
	; now install new interrupt handler
	pushf
	cli						; ensure we don't get interrupted in-between
							; the two instructions below
	mov word [ds:si], di	; offset of new interrupt handler
	mov word [ds:si+2], es	; segment of new interrupt handler
	popf
	
	pop es
	pop ds
	pop si
	pop ax
	ret
