;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains routines which provide timer events, every several system ticks.
; It is interrupt-driven so ticks are still generated when callbacks are
; long-running.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_TIMER_
%define _COMMON_GUI_TIMER_


GUI_TIMER_DIVISOR	equ 10			; raise tick events after this many
									; system timer ticks

guiTimerInterruptHandlerInstalled:	db 0
guiOldTimerHandlerSeg: 		dw 0
guiOldTimerHandlerOff: 		dw 0

guiTimerCurrentValue:		dw 0

guiTimerUserCallbackSeg:	dw 0
guiTimerUserCallbackOff:	dw 0


; Initializes GUI timer functionality
;
; input:
;		none
; output:
;		none
gui_timer_prepare:
	pusha

	; set user callback to be NOOP for now
	mov word [cs:guiTimerUserCallbackSeg], cs
	mov word [cs:guiTimerUserCallbackOff], gui_noop_callback
	
	popa
	ret
	

; Initializes GUI timer functionality
;
; input:
;		none
; output:
;		none
gui_timer_initialize:
	pusha

	mov word [cs:guiTimerCurrentValue], 0
	call gui_timer_register_interrupt_handler

	popa
	ret


; Performs any destruction logic needed
;
; input:
;		none
; output:
;		none
gui_timer_shutdown:
	pusha
	
	call gui_timer_restore_old_interrupt_handler
	
	popa
	ret
	
	
; Clears the GUI timer callback
;
; input:
;		none
; output:
;		none	
common_gui_timer_callback_clear:
	pusha
	
	mov word [cs:guiTimerUserCallbackSeg], cs
	mov word [cs:guiTimerUserCallbackOff], gui_noop_callback

	popa
	ret
	
	
; Sets the GUI timer callback, invoked every several system timer ticks
;
; input:
;	 DS:SI - pointer to callback function
; output:
;		none	
common_gui_timer_callback_set:
	pusha
	
	mov word [cs:guiTimerUserCallbackSeg], ds		; callback segment
	mov word [cs:guiTimerUserCallbackOff], si		; callback offset

	popa
	ret
	
	
; Invokes the timer callback specified by the user
;
; input:
;		none
; output:
;		none
gui_timer_invoke_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word gui_timer_invoke_callback_return	; return address on stack

	; setup "call far" address
	push word [cs:guiTimerUserCallbackSeg]			; callback segment
	push word [cs:guiTimerUserCallbackOff]			; callback offset
	retf											; "call far"

	; once the callback executes its own retf, execution returns below
gui_timer_invoke_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Considers the newly-dequeued event, and acts if the event is supported
;
; input:
;		none
; output:
;		none
gui_timer_handle_event:
	pusha
	
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_TIMER_TICK
	jne gui_timer_handle_event_done				; we don't support it here
	
	; we now invoke the timer callback in response to this tick event
	call gui_timer_invoke_callback
gui_timer_handle_event_done:
	popa
	ret
	
	
; Prepares the component for a task yield
;
; input:
;		none
; output:
;		none
gui_timer_prepare_for_yield:
	call gui_timer_restore_old_interrupt_handler
	ret
	

; Restores the component after a task yield
;
; input:
;		none
; output:
;		none	
gui_timer_restore_after_yield:
	call gui_timer_register_interrupt_handler
	ret
	

; Restores previous interrupt handler
;
; input:
;		none
; output:
;		none
gui_timer_restore_old_interrupt_handler:
	pusha
	push es
	
	cmp byte [cs:guiTimerInterruptHandlerInstalled], 0	; we installed nothing,
	je gui_timer_restore_old_interrupt_handler_done		; so we restore nothing

	mov di, word [cs:guiOldTimerHandlerOff]
	mov ax, word [cs:guiOldTimerHandlerSeg]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 1Ch					; interrupt number
	int 0B0h					; register interrupt handler

	mov byte [cs:guiTimerInterruptHandlerInstalled], 0
	
gui_timer_restore_old_interrupt_handler_done:
	pop es
	popa
	ret
	

; Register our interrupt handler
;
; input:
;		none
; output:
;		none
gui_timer_register_interrupt_handler:
	pusha
	push es

	cmp byte [cs:guiTimerInterruptHandlerInstalled], 0
	jne gui_timer_register_interrupt_handler_done

	; register our interrupt handler
	pushf
	cli						; we don't want interrupts firing before we've
							; saved the old handler address
	mov al, 1Ch				; interrupt number
	push cs
	pop es
	mov di, private_gui_timer_interrupt_handler 
									; ES:DI := interrupt handler
	int 0B0h						; register interrupt handler
									; (returns old interrupt handler in DX:BX)
	mov word [cs:guiOldTimerHandlerOff], bx	; save offset of old handler
	mov word [cs:guiOldTimerHandlerSeg], dx	; save segment of old handler
	popf

	mov byte [cs:guiTimerInterruptHandlerInstalled], 1
	
gui_timer_register_interrupt_handler_done:
	pop es
	popa
	ret

	
; This interrupt handler is registered for interrupt 1Ch (timer)
;
private_gui_timer_interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	;--------------------------------------------------------------------------
	; BEGIN PAYLOAD (as in, what this handler is supposed to do)
	;--------------------------------------------------------------------------
	pushf
	cli
	inc word [cs:guiTimerCurrentValue]
	cmp word [cs:guiTimerCurrentValue], GUI_TIMER_DIVISOR
	jb private_gui_timer_interrupt_handler_done_payload
	; we have to raise an event
	mov word [cs:guiTimerCurrentValue], 0		; reset interval counter
	mov al, GUI_EVENT_TIMER_TICK
	call gui_event_enqueue_1byte_atomic			; raise event
private_gui_timer_interrupt_handler_done_payload:
	popf
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
	push word gui_timer_previous_handler_return_point		; return IP

	; invoke previous handler
	; use retf to simulate a "jmp far [oldHandlerSeg]:[oldHandlerOff]"
	push word [cs:guiOldTimerHandlerSeg]
	push word [cs:guiOldTimerHandlerOff]
	retf						; invoke previous handler
	; old handler returns to the address immediately below
gui_timer_previous_handler_return_point:		
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


%endif
