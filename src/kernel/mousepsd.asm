;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; This is the pseudo-mouse driver, containing the 
; logic which allows the keyboard to simulate PS/2 controller data, feeding
; into the higher level mouse routines.
; Essentially, this allows the user to move the mouse using the keyboard.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MOUSE_PSEUDO_DELTA_X	equ 1	; amount to move when left or right is pressed
MOUSE_PSEUDO_DELTA_Y	equ 1	; amount to move when up or down is pressed

MOUSE_PSEUDO_KEY_UP		equ SCAN_CODE_UP_ARROW
MOUSE_PSEUDO_KEY_DOWN	equ SCAN_CODE_DOWN_ARROW
MOUSE_PSEUDO_KEY_LEFT	equ SCAN_CODE_LEFT_ARROW
MOUSE_PSEUDO_KEY_RIGHT	equ SCAN_CODE_RIGHT_ARROW
MOUSE_PSEUDO_KEY_LCLICK	equ SCAN_CODE_HOME
MOUSE_PSEUDO_KEY_RCLICK	equ SCAN_CODE_END

mousePseudoOldHandlerSeg: dw 0
mousePseudoOldHandlerOff: dw 0

mousePseudoLastTimeHadActivity:	db 0
mousePseudoHasActivity:			db 0
mousePseudoData: db 0, 0, 0	; the three bytes of last pseudo mouse event,
							; available to consumers
							; they look like whatever the PS/2 controller
							; would send from a real mouse, but instead are
							; generated from certain key presses


; Initializes all components needed by the pseudo-mouse driver
;
; input
;		none
; output
;		none
mouse_pseudo_initialize:
	push ds
	push es
	pusha
	
	pushf
	; register our interrupt handler
	cli							; we don't want interrupts firing before we've
								; saved the old handler address
	mov al, 0B8h				; we're registering for interrupt 0B8h
	push cs
	pop es
	mov di, mouse_pseudo_timer_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)
	
	; save old handler address, so our handler can invoke it
	mov word [cs:mousePseudoOldHandlerOff], bx	; save offset of old handler
	mov word [cs:mousePseudoOldHandlerSeg], dx ; save segment of old handler
	popf						; we want interrupts to fire again
	
	popa
	pop es
	pop ds
	ret


; Returns last raw data set
;
; input:
;		none
; output:
;		BH - bit 7 - Y overflow
;			 bit 6 - X overflow
;			 bit 5 - Y sign bit
;			 bit 4 - X sign bit
;			 bit 3 - always 1
;			 bit 2 - middle button
;			 bit 1 - right button
;			 bit 0 - left button
;		DH - X movement (delta X)
;		DL - Y movement (delta Y)
mouse_pseudo_poll_raw:
	mov byte bh, [cs:mousePseudoData + 0]	; prepare arguments
	mov byte dh, [cs:mousePseudoData + 1]
	mov byte dl, [cs:mousePseudoData + 2]
	ret

	
; This interrupt handler is called every system timer tick and simulates
; PS/2 mouse data
;
; input
;		none
; output
;		none
mouse_pseudo_timer_handler:
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

	call mouse_get_configured_driver_type
	cmp ax, MOUSE_DRIVER_TYPE_PSEUDO
	jne mouse_pseudo_timer_handler_done_payload		; NOOP if wrong mode

	call mouse_get_driver_status
	cmp al, 1
	jne mouse_pseudo_timer_handler_done_payload		; should be initialized

	int 0BBh
	cmp ax, 0										; NOOP when keyboard driver
	je mouse_pseudo_timer_handler_done_payload		; is off

	call mouse_pseudo_generate_data
	cmp ax, 0
	je mouse_pseudo_timer_handler_done_payload		; nothing happened

	; we get here ONLY if some keys were actually pressed

	; notify raw "state changed" handler of mouse state change
	mov byte bh, [cs:mousePseudoData + 0]	; prepare arguments
	mov byte dh, [cs:mousePseudoData + 1]
	mov byte dl, [cs:mousePseudoData + 2]	
	int 8Bh								; invoke raw "state changed" handler
	
mouse_pseudo_timer_handler_done_payload:
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
	push word mouse_pseudo_timer_handler_old_handler_return_address	; return IP

	; invoke previous handler
	; use retf to simulate a "jmp far [mousePseudoOldHandlerSeg]:[mousePseudoOldHandlerOff]"
	push word [cs:mousePseudoOldHandlerSeg]
	push word [cs:mousePseudoOldHandlerOff]
	retf						; invoke previous handler
	; old handler returns to the address immediately below
mouse_pseudo_timer_handler_old_handler_return_address:		
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Fills in the three data bytes based on keyboard status.
; Essentially it converts key presses into PS/2 data.
;
; input
;		none
; output
;		AX - 0 when nothing has happened, other value otherwise
mouse_pseudo_generate_data:
	pusha
	
	mov al, byte [cs:mousePseudoHasActivity]
	mov byte [cs:mousePseudoLastTimeHadActivity], al	; last := this
	
	mov byte [cs:mousePseudoHasActivity], 0
	
	; initialize bytes
	mov byte [cs:mousePseudoData + 0], 8
	mov byte [cs:mousePseudoData + 1], 0
	mov byte [cs:mousePseudoData + 2], 0
		
	; left button
	mov bl, MOUSE_PSEUDO_KEY_LCLICK
	int 0BAh
	cmp al, 0
	je mouse_pseudo_generate_data_after_left_button

	or byte [cs:mousePseudoData + 0], 1
	mov byte [cs:mousePseudoHasActivity], 1
mouse_pseudo_generate_data_after_left_button:
	
	; right button
	mov bl, MOUSE_PSEUDO_KEY_RCLICK
	int 0BAh
	cmp al, 0
	je mouse_pseudo_generate_data_after_right_button
	or byte [cs:mousePseudoData + 0], 2
	mov byte [cs:mousePseudoHasActivity], 1
mouse_pseudo_generate_data_after_right_button:

	; mouse moves left
	mov bl, MOUSE_PSEUDO_KEY_LEFT
	int 0BAh
	cmp al, 0
	je mouse_pseudo_generate_data_after_move_left
	or byte [cs:mousePseudoData + 0], 10h
	mov byte [cs:mousePseudoData + 1], -MOUSE_PSEUDO_DELTA_X
	mov byte [cs:mousePseudoHasActivity], 1
mouse_pseudo_generate_data_after_move_left:

	; mouse moves right
	mov bl, MOUSE_PSEUDO_KEY_RIGHT
	int 0BAh
	cmp al, 0
	je mouse_pseudo_generate_data_after_move_right
	mov al, 0FFh
	xor al, 10h
	and byte [cs:mousePseudoData + 0], al
	mov byte [cs:mousePseudoData + 1], MOUSE_PSEUDO_DELTA_X
	mov byte [cs:mousePseudoHasActivity], 1
mouse_pseudo_generate_data_after_move_right:

	; mouse moves up
	mov bl, MOUSE_PSEUDO_KEY_UP
	int 0BAh	
	cmp al, 0
	je mouse_pseudo_generate_data_after_move_up
	mov al, 0FFh
	xor al, 20h
	and byte [cs:mousePseudoData + 0], al
	mov byte [cs:mousePseudoData + 2], MOUSE_PSEUDO_DELTA_Y
	mov byte [cs:mousePseudoHasActivity], 1
mouse_pseudo_generate_data_after_move_up:

	; mouse moves down
	mov bl, MOUSE_PSEUDO_KEY_DOWN
	int 0BAh
	cmp al, 0
	je mouse_pseudo_generate_data_after_move_down
	or byte [cs:mousePseudoData + 0], 20h
	mov byte [cs:mousePseudoData + 2], -MOUSE_PSEUDO_DELTA_Y
	mov byte [cs:mousePseudoHasActivity], 1
mouse_pseudo_generate_data_after_move_down:

	; if last time we had activity, we always act this time, so that
	; things like held down buttons can become released again
	cmp byte [cs:mousePseudoLastTimeHadActivity], 0
	jne mouse_pseudo_generate_data_has_activity

	cmp byte [cs:mousePseudoHasActivity], 0
	je mouse_pseudo_generate_data_no_activity
mouse_pseudo_generate_data_has_activity:
	popa
	mov ax, 1
	ret
mouse_pseudo_generate_data_no_activity:
	popa
	mov ax, 0
	ret
