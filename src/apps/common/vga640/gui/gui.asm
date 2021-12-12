;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains highest-level GUI functionality, being in charge of:
; 
; 1. Waiting for events in the event queue and delegating them to each GUI
;    component type
; 2. Deciding if the GUI should render, by asking each component type
; 3. Handling initialization and re-initialization of the GUI framework
; 4. Handling GUI framework shutdown
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_
%define _COMMON_GUI_

guiLoadingMessage:				db 'Loading...', 0

guiShutdownCallbackSegment:		dw 0
guiShutdownCallbackOffset:		dw 0

guiMouseEventCallbackSegment:	dw 0
guiMouseEventCallbackOffset:	dw 0

guiInitializedCallbackSegment:	dw 0
guiInitializedCallbackOffset:	dw 0

guiOnRefreshCallbackSegment:	dw 0
guiOnRefreshCallbackOffset:		dw 0

guiTerminateTaskOnShutdown:			db 1
guiTerminateTaskOnNoMouseDriver:	db 1

guiIsRegularPalette:	db 1
guiColour0:	db GUI__COLOUR_0
guiColour1:	db GUI__COLOUR_1
guiColour2:	db GUI__COLOUR_2
guiColour3:	db GUI__COLOUR_3

guiIsBoldFont:		db 0
					db 0 ; so value can be assigned to 16bit registers easily
					
guiYieldDisabled:	db 0


; Prevents the GUI framework from shutting down when no mouse
; driver is present
;
; input:
;		none
; output:
;		none
common_gui_dont_shutdown_on_no_mouse_driver:
	mov byte [cs:guiTerminateTaskOnNoMouseDriver], 0
	ret
	
	
; Prepares the GUI framework to accept requests (to add UI components, etc.).
; It is meant to be called before any other interactions 
; with the GUI framework.
;
; input:
;		none
; output:
;		AX - 0 when preparation failed, other value otherwise
common_gui_prepare:
	pusha
	push ds
	
	mov byte [cs:guiTerminateTaskOnShutdown], 1
	call gui_core_disable_callbacks
	
	int 9Ah									; AX := my task ID
	mov word [cs:guiCoreMyTaskId], ax
	call gui_mouse_installation_check
	cmp ax, 0
	je common_gui_prepare_failure	; driver not loaded
	
	call gui_queue_clear_atomic		; clear event queue
	
	; initialize callbacks to NOOPs
	call common_gui_shutdown_callback_clear
	call common_gui_mouse_event_callback_clear
	call common_gui_initialized_callback_clear
	call common_gui_on_refresh_callback_clear
	
	call gui_timer_prepare
	call gui_keyboard_prepare
	call gui_buttons_prepare
	call gui_checkboxes_prepare
	call gui_images_prepare
	call gui_radio_prepare
	call gui_clock_prepare
	call gx_prepare
	
	; make consumer's own virtual display active
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	call common_graphics_enter_graphics_mode
	
	call gui_use_regular_palette
	call gui_use_regular_font
	
	; clear screen
	mov dl, byte [cs:guiColour1]
	call common_graphics_clear_screen_to_colour
	
	; show loading message
	mov si, guiLoadingMessage
	call common_gui_util_show_notice
common_gui_prepare_success:
	pop ds
	popa
	mov ax, 1
	ret
common_gui_prepare_failure:
	pop ds
	popa
	mov ax, 0
	ret


; Yields control to the GUI framework.
; Used by consumer applications after they have set up 
; desired components, callbacks, etc.
;
; input:
;		none
; output:
;		none
common_gui_start:
	pusha
	
	int 83h						; clear keyboard buffer
	
	mov al, 1					; indicate we're trying to become principal
	call gui_sync_initialize

	call gui_create_boilerplate
	
	; initialize and configure sprites
	call common_sprites_initialize
	mov ax, COMMON_SPRITES_CONFIG_ANIMATE_ON_REFRESH
		; we don't enable "wait for VSYNC on update" because it slows things
		; down, and because GUI apps won't move too many sprites around
	call common_sprites_set_config

	call gui_keyboard_initialize
	call gui_mouse_initialize
	call gui_render					; render initially
	
	mov al, GUI_EVENT_INVOKE_INITIALIZED_CALLBACK
	call gui_event_enqueue_1byte_atomic
	
	mov al, GUI_EVENT_SCREEN_REFRESH
	call gui_event_enqueue_1byte_atomic
	
	mov al, GUI_EVENT_INITIALIZE_TIMER	; timer is initialized late since
	call gui_event_enqueue_1byte_atomic	; "initialized" callbacks can run long
	
	; the GUI framework now enters its main loop, where it waits for events
	; to appear on its event queue (from interrupt handlers, etc.)
	call enter_gui_event_loop
	popa
	ret
	

; Runs the main event loop
;
; input:
;		none
; output:
;		none
enter_gui_event_loop:
	pusha
gui_event_queue_loop:
	hlt								; sleep until an interrupt occurs
									; this includes the periodic system ticks	
gui_event_queue_loop_after_halt:
	call gui_render					; this can be called repeatedly here
									; for two reasons:
									; 1. it is extremely fast in the case that
									;    no components actually need to render
									; 2. upon deletion, components need a 
									;    subsequent render to be cleaned up
									;    from the screen
	
	pushf
	cli								; peeking and dequeueing must be atomic
	call event_queue_peek			; DL := peeked byte, AX:=0 when successful
	cmp ax, 0						; was anything in the queue?
	je gui_event_queue_loop_dequeue	; yes
	popf							; no, so wait some more
	jmp gui_event_queue_loop		; loop again
gui_event_queue_loop_dequeue:
	; queue contains an event
	call gui_dequeue_event_atomic	; DS:SI := pointer to event bytes
	popf							; we can re-enable interrupts

	call gui_process_event
	cmp ax, 0						; do we have to return to caller?
	jne gui_event_queue_loop_after_halt	; no, so try to see if there's another
										; event in the queue
	; we must now return to caller	
	
	;
	; NOTE: this function does not normally return, terminating 
	;       the current task upon shutdown
	; However, the GUI framework can be configured to not terminate task, 
	; instead returning normally
	;
gui_event_queue_loop_done:
	popa
	ret


; Removes all GUI components
;
; input:
;		none
; output:
;		none
common_gui_clear_all:
	pusha
	pushf
	
	cli								; no further events for now
	
	; delete any pending events
	;call gui_queue_clear_atomic
	
	; clear storages of all components
	call gui_buttons_clear_storage
	call gui_checkboxes_clear_storage
	call gui_images_clear_storage
	call gui_radio_clear_storage
	call gui_clock_clear_storage
	call gx_clear_storage
	
	; clear background
	call common_sprites_background_change_prepare
	mov dl, byte [cs:guiColour1]
	call common_graphics_clear_screen_to_colour
	call common_sprites_background_change_finish
	
	call gui_create_boilerplate
	
	; redraw any affected sprites
	call common_sprites_refresh
	
	popf							; allow events once again
	popa
	ret
	
	
; Processes a newly-dequeued event by delegating to all component types
;
; input:
;		none
; output:
;		AX - 0 when shutdown was performed and the GUI framework must 
;			 return to caller, other value otherwise
gui_process_event:
	pusha

	call gui_clock_handle_event
	call gui_buttons_handle_event
	call gui_checkboxes_handle_event
	call gui_images_handle_event
	call gui_radio_handle_event
	call gui_mouse_handle_event
	call gui_keyboard_handle_event
	call gui_timer_handle_event
	call gx_handle_event
	
	call gui_handle_event			; since this ultimately invokes consumer's
									; "on refresh" callback, it MUST be called
									; AFTER all GUI framework components
									; (including extensions) have had a chance
									; to act on an event

	; the shutdown event is not handled in gui_handle_event call above
	; because it can affect the return value of THIS function
gui_process_event__check_shutdown:
	; handle shutdown event
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_SHUTDOWN_REQUESTED
	jne gui_process_event_done
	; shutdown was requested, so handle it
	call gui_handle_shutdown_event
	
	; did we actually shut down?
	call gui_sync_can_shutdown
	cmp al, 0
	je gui_process_event_done			; no
	
	; if we got here, it means that we skipped task termination, so we 
	; return to caller
	popa
	mov ax, 0							; "shutdown - return to caller"
	ret
gui_process_event_done:
	popa
	mov ax, 1							; "normal flow"
	ret
	
	
; Renders GUI components when needed
;
; input:
;		none
; output:
;		none
gui_render:
	pusha
	
	; first, determine if any components need to be rendered
	; by accumulating in DH whether each component type needs to be rendered
	mov dh, 0					; accumulates whether anyone needs to render
	
	call gui_buttons_get_need_render	; AL := 0 when render is not needed
	or dh, al							; accumulate
	call gui_checkboxes_get_need_render	; AL := 0 when render is not needed
	or dh, al							; accumulate
	call gui_images_get_need_render		; AL := 0 when render is not needed
	or dh, al							; accumulate
	call gui_radio_get_need_render		; AL := 0 when render is not needed
	or dh, al							; accumulate
	call gui_mouse_get_need_render		; AL := 0 when render is not needed
	or dh, al							; accumulate
	call gui_clock_get_need_render		; AL := 0 when render is not needed
	or dh, al							; accumulate
	call gx_get_need_render				; AL := 0 when render is not needed
	or dh, al							; accumulate
	
	cmp dh, 0
	je gui_render_done					; no components need to be rendered
	
	; some of the components need to be rendered
	
	; rendering prologue
	call common_sprites_background_change_prepare	; begin background change

	; rendering of components
gui_render_check_buttons:
	call gui_buttons_get_need_render
	cmp al, 0
	je gui_render_check_images			; buttons don't need it; check next
	; buttons need to be rendered
	call gui_buttons_render_all
gui_render_check_images:
	call gui_images_get_need_render
	cmp al, 0
	je gui_render_check_radio			; images don't need it; check next
	; images need to be rendered
	call gui_images_render_all
gui_render_check_radio:
	call gui_radio_get_need_render
	cmp al, 0
	je gui_render_check_checkboxes		; radio don't need it; check next
	; radio need to be rendered
	call gui_radio_render_all
gui_render_check_checkboxes:
	call gui_checkboxes_get_need_render
	cmp al, 0
	je gui_render_check_clock			; checkboxes don't need it; check next
	; checkboxes need to be rendered
	call gui_checkboxes_render_all	
gui_render_check_clock:
	call gui_clock_get_need_render
	cmp al, 0
	je gui_render_check_mouse			; clock doesn't need it; check next
	; clock needs to be rendered
	call gui_clock_render_all	
gui_render_check_mouse:
	call gui_mouse_get_need_render
	cmp al, 0
	je gui_render_check_extensions		; mouse doesn't need it
	; mouse needs to be rendered
	call gui_mouse_render_all
gui_render_check_extensions:
	call gx_get_need_render
	cmp al, 0
	je gui_render_epilogue				; extensions don't need it
	; extensions needs to be rendered
	call gx_render_all

gui_render_epilogue:
	; rendering epilogue
	call common_sprites_background_change_finish	; finish background change
	call common_sprites_refresh		; redraw sprites

gui_render_done:
	popa
	ret

	
; Considers the newly-dequeued event, and acts as needed
;
; input:
;		none
; output:
;		none
gui_handle_event:
	pusha

gui_handle_event__mouse_delegation:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je gui_handle_event__mouse_delegation__left_down
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_handle_event__mouse_delegation__left_up
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_handle_event__mouse_delegation__right_down
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_handle_event__mouse_delegation__right_up
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSE_MOVE
	je gui_handle_event__mouse_delegation__move
	; not a mouse event
	jmp gui_handle_event__palette
gui_handle_event__mouse_delegation__left_down:
	mov ax, 0
	jmp gui_handle_event__mouse_delegation__invoke
gui_handle_event__mouse_delegation__left_up:
	mov ax, 1
	jmp gui_handle_event__mouse_delegation__invoke
gui_handle_event__mouse_delegation__right_down:
	mov ax, 2
	jmp gui_handle_event__mouse_delegation__invoke
gui_handle_event__mouse_delegation__right_up:
	mov ax, 3
	jmp gui_handle_event__mouse_delegation__invoke
gui_handle_event__mouse_delegation__move:
	mov ax, 4
	jmp gui_handle_event__mouse_delegation__invoke
gui_handle_event__mouse_delegation__invoke:
	mov bx, word [cs:dequeueEventBytesBuffer+1]
	mov cx, word [cs:dequeueEventBytesBuffer+3]

	push word [cs:guiMouseEventCallbackSegment]
	pop ds
	mov si, word [cs:guiMouseEventCallbackOffset]
	call gui_invoke_callback
	jmp gui_handle_event_done
	
gui_handle_event__palette:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_PALETTE_CHANGE
	jne gui_handle_event__font
	mov al, byte [ds:dequeueEventBytesBuffer+1]		; AL := palette
	call gui_handle_palette_changed_event
	jmp gui_handle_event_done
gui_handle_event__font:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_FONT_CHANGE	
	jne gui_handle_event__screen_refresh
	mov al, byte [ds:dequeueEventBytesBuffer+1]		; AL := font
	call gui_handle_font_changed_event
	jmp gui_handle_event_done
gui_handle_event__screen_refresh:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_SCREEN_REFRESH	
	jne gui_handle_event__other_task_exiting
	call gui_handle_screen_refresh_event
	jmp gui_handle_event_done
gui_handle_event__other_task_exiting:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_OTHER_TASK_EXIT
	jne gui_handle_event__yield
	call gui_handle_other_task_exit_event
	jmp gui_handle_event_done
gui_handle_event__yield:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_YIELD_START
	jne gui_handle_event__invoke_initialized_callback
	call gui_yield_perform
	jmp gui_handle_event_done
gui_handle_event__invoke_initialized_callback:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_INVOKE_INITIALIZED_CALLBACK
	jne gui_handle_event__initialize_timer
	call gui_invoke_initialized_callback
	jmp gui_handle_event_done
gui_handle_event__initialize_timer:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_INITIALIZE_TIMER
	jne gui_handle_event_done
	call gui_initialize_timer
	jmp gui_handle_event_done
gui_handle_event_done:
	popa
	ret
	
	
; Handles the "other task exit" event
;
; input:
;		none
; output:
;		none
gui_handle_other_task_exit_event:
	pusha
	push ds
	
	call gui_sync_decrement_task_counter_atomic
	call gui_boilerplate_adjust_global_buttons
gui_handle_other_task_exit_event_done:
	pop ds
	popa
	ret

	
; Handles the "screen refresh" event
;
; input:
;		none
; output:
;		none
gui_handle_screen_refresh_event:
	pusha
	push ds
	
	push word [cs:guiOnRefreshCallbackSegment]
	pop ds
	mov si, word [cs:guiOnRefreshCallbackOffset]
	call gui_invoke_callback

	pop ds
	popa
	ret
	

; Returns the foreground colour
;
; input:
;		none
; output:
;		CH - 0
;		CL - foreground colour	
common_gui_get_colour_foreground:
	mov ch, 0
	mov cl, byte [cs:guiColour0]
	ret
	
	
; Returns the background colour
;
; input:
;		none
; output:
;		CH - 0
;		CL - background colour	
common_gui_get_colour_background:
	mov ch, 0
	mov cl, byte [cs:guiColour1]
	ret
	
	
; Returns the decorations colour
;
; input:
;		none
; output:
;		CH - 0
;		CL - decorations colour	
common_gui_get_colour_decorations:
	mov ch, 0
	mov cl, byte [cs:guiColour2]
	ret
	
	
; Returns the disabled colour
;
; input:
;		none
; output:
;		CH - 0
;		CL - disabled colour	
common_gui_get_colour_disabled:
	mov ch, 0
	mov cl, byte [cs:guiColour3]
	ret
	
	
; Returns current text formatting options
;
; input:
;		none
; output:
;		DX - current text formatting options
common_gui_get_text_formatting:
	mov dx, word [cs:guiIsBoldFont]
	ret
	

; Changes palette
;
; input:
;		AL - palette: 1=regular, 0=inverted
; output:
;		none	
gui_handle_palette_changed_event:
	pusha
	cmp al, byte [cs:guiIsRegularPalette]		; is it already current?
	je gui_handle_palette_changed_event_done	; yes, so NOOP
	call gui_swap_palette
gui_handle_palette_changed_event_done:
	popa
	ret
	
	
; Changes font
;
; input:
;		AL - font: 1=regular, 0=bold
; output:
;		none	
gui_handle_font_changed_event:
	pusha
	cmp al, byte [cs:guiIsBoldFont]			; is it already current?
	je gui_handle_font_changed_event_done		; yes, so NOOP
	call gui_swap_font
gui_handle_font_changed_event_done:
	popa
	ret
	
	
; Used by consumers to instruct the GUI framework to not allow the user
; to exit the application
;
; input:
;		none
; output:
;		none
common_gui_disallow_exit:
	call gui_sync_disable_shutdown_explicit
	ret
	
	
; Used by consumers to instruct the GUI framework that the consumer is 
; about to draw something to the screen
;
; input:
;		none
; output:
;		none
common_gui_draw_begin:
	pusha
	
	call common_sprites_background_change_prepare	; begin background change
	
	popa
	ret
	
	
; Used by consumers to instruct the GUI framework that the consumer has
; finished drawing to the screen.
;
; input:
;		none
; output:
;		none
common_gui_draw_end:
	pusha
	
	call common_sprites_background_change_finish	; finish background change
	call common_sprites_refresh		; redraw sprites
	
	popa
	ret
	

; Raises an event which will cause the refresh callback to be invoked, giving
; consumers a chance to re-draw custom graphics, text, etc. - that is, 
; outside of GUI framework components
;
; input:
;		none
; output:
;		none
gui_raise_refresh_event:
	pusha

	mov al, GUI_EVENT_SCREEN_REFRESH
	call gui_event_enqueue_1byte_atomic
	
	popa
	ret
	

; Clears GUI framework's "on shutdown" callback
;
; input:
;		none
; output:
;		none
common_gui_shutdown_callback_clear:
	pusha
	
	mov word [cs:guiShutdownCallbackSegment], cs
	mov word [cs:guiShutdownCallbackOffset], gui_noop_callback
	
	popa
	ret
	
	
; Sets GUI framework's "on shutdown" callback
;
; input:
;	 DS:SI - pointer to callback
; output:
;		none	
common_gui_shutdown_callback_set:
	pusha
	
	mov word [cs:guiShutdownCallbackSegment], ds
	mov word [cs:guiShutdownCallbackOffset], si
	
	popa
	ret
	
	
; Clears GUI framework's "mouse event" callback
;
; input:
;		none
; output:
;		none
common_gui_mouse_event_callback_clear:
	pusha
	
	mov word [cs:guiMouseEventCallbackSegment], cs
	mov word [cs:guiMouseEventCallbackOffset], gui_noop_callback
	
	popa
	ret
	
	
; Sets GUI framework's "mouse event" callback
;
; input:
;	 DS:SI - pointer to callback
; output:
;		none	
common_gui_mouse_event_callback_set:
	pusha
	
	mov word [cs:guiMouseEventCallbackSegment], ds
	mov word [cs:guiMouseEventCallbackOffset], si
	
	popa
	ret
	

; Clears GUI framework's "on initialized" callback
;
; input:
;		none
; output:
;		none	
common_gui_initialized_callback_clear:
	pusha
	
	mov word [cs:guiInitializedCallbackSegment], cs
	mov word [cs:guiInitializedCallbackOffset], gui_noop_callback
	
	popa
	ret
	
	
; Sets GUI framework's "on initialized" callback
;
; input:
;	 DS:SI - pointer to callback
;			 contract:
;				Callbacks MUST use retf upon returning
;				Callbacks are not expected to preserve any registers
;				input:
;						AX - 0 for left mouse button down
;							 1 for left mouse button up
;							 2 for right mouse button down
;							 3 for right mouse button up
;							 4 for mouse move
;						BX - mouse X
;						CX - mouse Y
;				output:
;						none
; output:
;		none
common_gui_initialized_callback_set:
	pusha
	
	mov word [cs:guiInitializedCallbackSegment], ds
	mov word [cs:guiInitializedCallbackOffset], si
	
	popa
	ret
	

; Initiate a GUI framework shutdown via raising the proper events
;
; input:
;		none
; output:
;		none
common_gui_shutdown:
	pusha

	; we're raising an event indicating
	; the shutdown, to allow the GUI framework to return to caller
	call gui_queue_clear_atomic			; ignore all previously queued events
	mov al, GUI_EVENT_SHUTDOWN_REQUESTED
	call gui_event_enqueue_1byte_atomic	; enqueue the shutdown event

common_gui_shutdown_done:
	popa
	ret
	

; Also an entry point for when the GUI framework must be shut down after 
; it was prepared, but before it started.
;
; input:
;		none
; output:
;		none
common_gui_premature_shutdown:
	pusha
	
	call gui_keyboard_premature_shutdown
	call common_graphics_leave_graphics_mode
	
	popa
	ret
	
	
; Configures the GUI framework to not allow yielding to other GUI applications
;
; input:
;		none
; output:
;		none
common_gui_disable_yield:
	pusha
	
	mov byte [cs:guiYieldDisabled], 1
	
	popa
	ret
	

; Performs any destruction logic needed.
;
; input:
;		none
; output:
;		none
gui_handle_shutdown_event:
	pusha
	push ds

	call gui_sync_can_shutdown
	cmp al, 0
	je gui_handle_shutdown_event_done	; NOOP if we can't
	
	mov byte [cs:guiYieldDisabled], 0	; clean this up here, since we can't
										; do it during preparation
	
	; invoke "on shutdown" callback
	push word [cs:guiShutdownCallbackSegment]
	pop ds
	mov si, word [cs:guiShutdownCallbackOffset]
	call gui_invoke_callback

	call common_sprites_shutdown
	call gui_timer_shutdown
	call gui_mouse_shutdown
	call gui_keyboard_shutdown
	call gui_sync_shutdown
	
	call common_graphics_leave_graphics_mode
	
	; see if we're also terminating the task
	cmp byte [cs:guiTerminateTaskOnShutdown], 0
	je gui_handle_shutdown_event_dont_terminate
	int 95h						; exit current task
	
gui_handle_shutdown_event_dont_terminate:
	; we're not terminating the task
gui_handle_shutdown_event_done:
	pop ds
	popa
	ret
	
	
; Configures the GUI framework to return to caller on shutdown
;
; input:
;		none
; output:
;		none
common_gui_set_return_on_shutdown:
	mov byte [cs:guiTerminateTaskOnShutdown], 0
	ret
	
	
; Swaps the current font
;
; input:
;		none
; output:
;		none
gui_swap_font:
	pusha
	
	cmp byte [cs:guiIsBoldFont], 1
	je gui_swap_font__use_regular

gui_swap_font__use_bold:	
	call gui_use_bold_font
	jmp gui_swap_font_done
gui_swap_font__use_regular:
	call gui_use_regular_font
gui_swap_font_done:
	popa
	ret
	
	
; Makes regular font current
;
; input:
;		none
; output:
;		none
gui_use_regular_font:
	pusha
	
	mov byte [cs:guiIsBoldFont], 0
	
	call gui_redraw_boilerplate
	call gui_schedule_all_for_render
	popa
	ret
	
	
; Makes bold font current
;
; input:
;		none
; output:
;		none
gui_use_bold_font:
	pusha
	
	mov byte [cs:guiIsBoldFont], 1
	
	call gui_redraw_boilerplate
	call gui_schedule_all_for_render
	popa
	ret
	
	
; Swaps the current palette
;
; input:
;		none
; output:
;		none
gui_swap_palette:
	pusha
	
	cmp byte [cs:guiIsRegularPalette], 0
	je gui_swap_palette__use_regular

gui_swap_palette__use_inverted:	
	call gui_use_inverted_palette
	jmp gui_swap_palette_done
gui_swap_palette__use_regular:
	call gui_use_regular_palette
gui_swap_palette_done:
	popa
	ret


; Makes regular palette current
;
; input:
;		none
; output:
;		none
gui_use_regular_palette:
	pusha
	
	mov byte [cs:guiColour0], GUI__COLOUR_0
	mov byte [cs:guiColour1], GUI__COLOUR_1
	mov byte [cs:guiColour2], GUI__COLOUR_2
	mov byte [cs:guiColour3], GUI__COLOUR_3
	mov byte [cs:guiIsRegularPalette], 1
	
	call gui_boilerplate_on_palette_change
	
	call gui_schedule_all_for_render
	popa
	ret

	
; Makes inverted palette current
;
; input:
;		none
; output:
;		none
gui_use_inverted_palette:
	pusha
	
	mov byte [cs:guiColour0], GUI__COLOUR_1
	mov byte [cs:guiColour1], GUI__COLOUR_0
	mov byte [cs:guiColour2], GUI__COLOUR_3
	mov byte [cs:guiColour3], GUI__COLOUR_2
	mov byte [cs:guiIsRegularPalette], 0
	
	call gui_boilerplate_on_palette_change
	
	call gui_schedule_all_for_render
	popa
	ret
	

; Marks all UI components as needing rendering
;
; input:
;		none
; output:
;		none
gui_schedule_all_for_render:
	call gui_buttons_schedule_render_all
	call gui_checkboxes_schedule_render_all
	call gui_images_schedule_render_all
	call gui_radio_schedule_render_all
	call gui_clock_schedule_render_all
	call gx_schedule_render_all
	ret

	
; Raise an appropriate event to begin yielding to another GUI application
;
; input:
;		none
; output:
;		none
gui_yield:
	pusha
	
	cmp byte [cs:guiYieldDisabled], 0
	jne gui_yield_done				; NOOP when yield is disabled
	
	mov al, GUI_EVENT_YIELD_START
	call gui_event_enqueue_1byte_atomic
	
gui_yield_done:
	popa
	ret

	
; Clears GUI framework's "on refresh" callback
;
; input:
;		none
; output:
;		none	
common_gui_on_refresh_callback_clear:
	pusha
	
	mov word [cs:guiOnRefreshCallbackSegment], cs
	mov word [cs:guiOnRefreshCallbackOffset], gui_noop_callback
	
	popa
	ret
	
	
; Sets GUI framework's "on initialized" callback.
; This is invoked whenever the GUI framework has to refresh the 
; whole screen.
;
; input:
;	 DS:SI - pointer to callback
; output:
;		none
common_gui_on_refresh_callback_set:
	pusha
	
	mov word [cs:guiOnRefreshCallbackSegment], ds
	mov word [cs:guiOnRefreshCallbackOffset], si
	
	popa
	ret


; Starts a task, given a memory segment where the application was loaded.
; It also yields to this newly-created task, switching to it immediately.
;
; input:
;		BX - segment
;	 DS:SI - task arguments
; output:
;		none
common_gui_start_new_task:
	int 93h							; AX := task ID
	
	call gui_sync_increment_task_counter_atomic
	call gui_sync_publish_task_started
	
	mov bx, ax						; BX := task ID
	mov ah, 0						; function 0: set next task
	int 0C6h						; scheduler functions
	call gui_yield
	ret


; Invokes the initialized callback
;
; input:
;		none
; output:
;		none	
gui_invoke_initialized_callback:
	pusha
	push ds
	
	; we do not invoke consumer callbacks before "initialized"
	call gui_core_enable_callbacks
	
	; invoke "on initialized" callback
	push word [cs:guiInitializedCallbackSegment]
	pop ds
	mov si, word [cs:guiInitializedCallbackOffset]
	call gui_invoke_callback
	
	pop ds
	popa
	ret
	
	
; Initializes the timer
;
; input:
;		none
; output:
;		none	
gui_initialize_timer:
	pusha
	push ds
	
	call gui_timer_initialize
	
	pop ds
	popa
	ret
	
	

; Yields to the next task.
; Cleans up any hookups which may function while it is not active.
;
; input:
;		none
; output:
;		none
gui_yield_perform:
	pusha
	pushf
	
	call gui_keyboard_prepare_for_yield
	call gui_timer_prepare_for_yield
	call gui_mouse_prepare_for_yield
	
	call gui_sync_publish_all_changes
	
	; now yield to next task

	int 94h						; yield

	; we have now been yielded to, so we restore ourselves
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	call gui_redraw_boilerplate
	call gui_mouse_restore_after_yield
	call gui_timer_restore_after_yield
	call gui_keyboard_restore_after_yield
	
	call gui_schedule_all_for_render
	
	popf
	popa
	ret
	

; Redraws everything on the screen
;
; input:
;		none
; output:
;		none	
common_gui_redraw_screen:
	pusha
	call gui_redraw_boilerplate
	call gui_schedule_all_for_render
	popa
	ret


%include "common\vga640\gui\gui_ext.asm"	
%include "common\vga640\gui\gui_conf.asm"
%include "common\vga640\gui\gui_core.asm"
%include "common\vga640\gui\gui_sync.asm"
%include "common\vga640\gui\gui_mous.asm"
%include "common\vga640\gui\gui_keyb.asm"
%include "common\vga640\gui\gui_boil.asm"
%include "common\vga640\gui\gui_util.asm"
%include "common\vga640\gui\gui_time.asm"

%include "common\vga640\gui\gui_clck.asm"
%include "common\vga640\gui\gui_bttn.asm"
%include "common\vga640\gui\gui_chkb.asm"
%include "common\vga640\gui\gui_imge.asm"
%include "common\vga640\gui\gui_rdio.asm"

%include "common\vga640\graphics.asm"
%include "common\vga640\gra_text.asm"
%include "common\vga640\sprites.asm"

%include "common\scancode.asm"

%endif
