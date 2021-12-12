;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains routines dealing with mouse events, rendering, etc.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_MOUSE_
%define _COMMON_GUI_MOUSE_

TRN equ COMMON_GRAPHICS_COLOUR_TRANSPARENT

oldMouseStateButton:	db 0		; holds previous state
oldMouseStateX:			dw 0
oldMouseStateY:			dw 0
mouseStateButton:		db 0		; holds current state
mouseStateX:			dw 0
mouseStateY:			dw 0

oldMouseStateHandlerSeg:	dw 0	; old mouse manager state changed handler
oldMouseStateHandlerOff:	dw 0	; (so we can restore it on shutdown)

noMouseDriverMessage: 	db "No mouse driver present. Exiting...", 0

guiMouseSpriteCreated:	db 0
guiMouseNeedRender:		db 0
				; becomes non-zero when a change which requires
				; the mouse cursor to be redrawn took place

; each entry is a byte representing the colour of one pixel of our mouse cursor
guiCursor:			db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, TRN
					db GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_1, TRN, TRN
					db GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_1, TRN, TRN, TRN
					db GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_1, TRN, TRN
					db GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_1, TRN
					db GUI__COLOUR_1, GUI__COLOUR_1, TRN, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_1
					db GUI__COLOUR_1, TRN, TRN, TRN, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, TRN
					db TRN, TRN, TRN, TRN, TRN, GUI__COLOUR_1, TRN, TRN

SPRITE_MOUSE equ COMMON_SPRITES_MAX_SPRITES - 1
					; mouse sprite number (highest priority sprite is used)


; Exits task when mouse driver is not present
;
; input:
;		none
; output:
;		AX - 0 when no driver was found, other value otherwise
gui_mouse_installation_check:
	pusha
	
	; initialize mouse (driver is required to have been loaded)
	int 8Dh						; AL := mouse driver status
	cmp al, 0					; 0 means "driver not loaded"
	jne gui_mouse_installation_check_success
	; mouse driver not loaded
	
	cmp byte [cs:guiTerminateTaskOnNoMouseDriver], 0
	je gui_mouse_installation_check_no_driver		; we won't terminate
	; we are terminating the task
	mov si, noMouseDriverMessage
	int 80h						; print message
	int 95h						; exit
gui_mouse_installation_check_no_driver:
	popa
	mov ax, 0
	ret
gui_mouse_installation_check_success:
	popa
	mov ax, 1
	ret


; Initializes GUI mouse functionality
;
; input:
;		none
; output:
;		none
gui_mouse_initialize:
	pusha
	push ds
	
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH
	mov dx, COMMON_GRAPHICS_SCREEN_HEIGHT
	int 90h						; initialize mouse manager

	; poll mouse once initially, to determine mouse cursor's initial position
	int 8Fh						; poll mouse manager, AL := button state
								; BX := X coordinate
								; DX := Y coordinate

	; save initial mouse state
	mov byte [cs:mouseStateButton], al
	mov word [cs:mouseStateX], bx
	mov word [cs:mouseStateY], dx
	mov byte [cs:oldMouseStateButton], al
	mov word [cs:oldMouseStateX], bx
	mov word [cs:oldMouseStateY], dx
	
	push cs
	pop ds
	mov si, guiCursor			; DS:SI := pointer to cursor bitmap
	mov cx, bx					; CX := X
								; DX = Y, from above
	mov al, SPRITE_MOUSE		; sprite number
	mov bl, GUI_MOUSE_CURSOR_SIZE	; sprite side size (sprites are square)
	call common_sprites_create
	
	call gui_mouse_register_interrupt_handler
	mov byte [cs:guiMouseNeedRender], 1	; schedule an initial rendering

	mov byte [cs:guiMouseSpriteCreated], 1
	
	pop ds
	popa
	ret

	
; Returns whether mouse needs to be rendered
;
; input:
;		none
; output:
;		AL - 0 when mouse doesn't need rendering, other value otherwise
gui_mouse_get_need_render:
	mov al, byte [cs:guiMouseNeedRender]
	ret


; Returns whether mouse needs to be rendered
;
; input:
;		none
; output:
;		AX - mouse Y
;		BX - mouse X
gui_mouse_get_position:
	mov ax, word [cs:mouseStateY]
	mov bx, word [cs:mouseStateX]
	ret
	

; Considers the newly-dequeued event, and modifies mouse state
; as needed
;
; input:
;		none
; output:
;		none
gui_mouse_handle_event:
	pusha
	
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSE_MOVE
	jne gui_mouse_handle_event_handled		; did mouse move?
	
	; mouse did move
	mov cx, word [ds:dequeueEventBytesBuffer+1]
	mov dx, word [ds:dequeueEventBytesBuffer+3]
	mov al, SPRITE_MOUSE	; sprite #
	call common_sprites_move

gui_mouse_handle_event_handled:
	mov byte [cs:guiMouseNeedRender], 1	; schedule for rendering
	
gui_mouse_handle_event_done:	
	popa
	ret

	
; Renders any applicable mouse graphics
;
; input:
;		none
; output:
;		none
gui_mouse_render_all:
	pusha
	
	; sprites library handles the rendering, so just flag mouse as rendered
	mov byte [cs:guiMouseNeedRender], 0
	
	popa
	ret
	

; Performs any destruction logic needed
;
; input:
;		none
; output:
;		none
gui_mouse_shutdown:
	pusha
	
	call gui_mouse_restore_interrupt_handler
	
	popa
	ret
	
	
; Prepares the component for a task yield
;
; input:
;		none
; output:
;		none
gui_mouse_prepare_for_yield:
	pusha
	
	call gui_mouse_restore_interrupt_handler
	
	popa
	ret
	

; Restores the component after a task yield
;
; input:
;		none
; output:
;		none	
gui_mouse_restore_after_yield:
	pusha
	
	; move cursor to where the last task left it
	int 8Fh										; BX := mouse X, DX := mouse Y
	call gui_mouse_event_enqueue_mouse_movement
	
	call gui_mouse_register_interrupt_handler
	
	; behave as if buttons just became released, in case user switched tasks
	; while holding down a mouse button
	call gui_mouse_event_enqueue_mousebutton_up_left
	call gui_mouse_event_enqueue_mousebutton_up_right
	
	popa
	ret
	

; Restores old mouse manager state handler
;
; input:
;		none
; output:
;		none
gui_mouse_restore_interrupt_handler:
	pusha
	push es

	mov di, word [cs:oldMouseStateHandlerOff]
	mov ax, word [cs:oldMouseStateHandlerSeg]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 0C0h				; interrupt number
	int 0B0h					; register interrupt handler

	pop es
	popa
	ret
	

; Register our mouse manager state handler
;
; input:
;		none
; output:
;		none
gui_mouse_register_interrupt_handler:
	pusha
	push es

	; register our interrupt handler
	pushf
	cli							; we don't want interrupts firing before we've
								; saved the old handler address
	mov al, 0C0h					; interrupt number
	push cs
	pop es
	mov di, gui_mouse_state_changed_interrupt_handler 
									; ES:DI := interrupt handler
	int 0B0h						; register interrupt handler
									; (returns old interrupt handler in DX:BX)
	mov word [cs:oldMouseStateHandlerOff], bx	; save offset of old handler
	mov word [cs:oldMouseStateHandlerSeg], dx	; save segment of old handler
	popf

	pop es
	popa
	ret


; This interrupt handler is invoked every time the mouse's state changes.
;
; input:
;		AL - bits 3 to 7 - unused and indeterminate
;			 bit 2 - middle button current state
;			 bit 1 - right button current state
;			 bit 0 - left button current state
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
; output:
;		none
gui_mouse_state_changed_interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	; BEGIN actual interrupt handler work
	; preserve previous state
	mov cl, byte [cs:mouseStateButton]
	mov byte [cs:oldMouseStateButton], cl
	mov si, word [cs:mouseStateX]
	mov word [cs:oldMouseStateX], si
	mov di, word [cs:mouseStateY]
	mov word [cs:oldMouseStateY], di
	
	; save mouse state
	mov byte [cs:mouseStateButton], al
	mov word [cs:mouseStateX], bx
	mov word [cs:mouseStateY], dx

	; here CL = old mouse button state
	;      SI = old mouse X state
	;      DI = old mouse Y state
	
	; see if we need to raise any events
	call gui_mouse_check_buttons
	call gui_mouse_check_movement
	
	; END actual interrupt handler work

	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control
	
	
; Enqueues a "mouse down left button" event
;
; input:
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
; output:
;		none
gui_mouse_event_enqueue_mousebutton_down_left:
	pusha
	mov al, GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	call gui_event_enqueue_5bytes_atomic
	popa
	ret
	
; Enqueues a "mouse up left button" event
;
; input:
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
; output:
;		none
gui_mouse_event_enqueue_mousebutton_up_left:
	pusha
	mov al, GUI_EVENT_MOUSEBUTTON_LEFT_UP
	call gui_event_enqueue_5bytes_atomic
	popa
	ret

; Enqueues a "mouse down right button" event
;
; input:
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
; output:
;		none
gui_mouse_event_enqueue_mousebutton_down_right:
	pusha
	mov al, GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	call gui_event_enqueue_5bytes_atomic
	popa
	ret

; Enqueues a "mouse up right button" event
;
; input:
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
; output:
;		none
gui_mouse_event_enqueue_mousebutton_up_right:
	pusha
	mov al, GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	call gui_event_enqueue_5bytes_atomic
	popa
	ret


; Enqueues a "mouse movement" event
;
; input:
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
; output:
;		none
gui_mouse_event_enqueue_mouse_movement:
	pusha
	mov al, GUI_EVENT_MOUSE_MOVE
	call gui_event_enqueue_5bytes_atomic
	popa
	ret
	

; Tries to create mouse movement events, if any are mandated
;
; input:
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
;		SI = old mouse X state
;		DI = old mouse Y state
gui_mouse_check_movement:
	pusha

	; raise event if either X or Y has changed
	cmp bx, si
	jne gui_mouse_check_movement_raise_event
	cmp dx, di
	jne gui_mouse_check_movement_raise_event
	; mouse hasn't moved, so we just return
	popa
	ret
gui_mouse_check_movement_raise_event:
	; here, BX = X position, DX = Y position
	call gui_mouse_event_enqueue_mouse_movement
	popa
	ret

	
; Tries to create mouse button events, if any are mandated
;
; input:
;		AL - bits 3 to 7 - unused and indeterminate
;			 bit 2 - middle button current state
;			 bit 1 - right button current state
;			 bit 0 - left button current state
;		CL - like AL, but for previous state
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
; output:
;		none	
gui_mouse_check_buttons:
	pusha

gui_mouse_check_buttons_try_down_left:
	test al, 00000001b
	jz gui_mouse_check_buttons_try_down_right	; button is not down
	test cl, 00000001b
	jnz gui_mouse_check_buttons_try_down_right	; button was already down
	call gui_mouse_event_enqueue_mousebutton_down_left

gui_mouse_check_buttons_try_down_right:
	test al, 00000010b
	jz gui_mouse_check_buttons_try_up_left		; button is not down
	test cl, 00000010b
	jnz gui_mouse_check_buttons_try_up_left		; button was already down
	call gui_mouse_event_enqueue_mousebutton_down_right

gui_mouse_check_buttons_try_up_left:
	test al, 00000001b
	jnz gui_mouse_check_buttons_try_up_right	; button is not up
	test cl, 00000001b
	jz gui_mouse_check_buttons_try_up_right		; button was already up
	call gui_mouse_event_enqueue_mousebutton_up_left
	
gui_mouse_check_buttons_try_up_right:
	test al, 00000010b
	jnz gui_mouse_check_buttons_done			; button is not up
	test cl, 00000010b
	jz gui_mouse_check_buttons_done				; button was already up
	call gui_mouse_event_enqueue_mousebutton_up_right

gui_mouse_check_buttons_done:	
	popa
	ret


%endif
