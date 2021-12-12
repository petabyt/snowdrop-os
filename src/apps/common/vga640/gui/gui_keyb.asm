;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains routines dealing with keyboard events.
;
; GUI framework relies on the Snowdrop keyboard driver, which provides
; scan code and ASCII via a message whenever a key status change occurs.
;
; When the above message is received, the GUI framework raises an internal 
; event, notifying its components that a key status has changed. This design
; keeps the interrupt handling fast.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_KEYBOARD_
%define _COMMON_GUI_KEYBOARD_

oldKeyboardDriverMode:	dw 0	; used to restore previous keyboard driver
								; mode on shutdown and yield
										
; "exit" command key combination
GUI_KEYBOARD_EXIT_SCAN_CODE_KEY_1		equ COMMON_SCAN_CODE_Q
GUI_KEYBOARD_EXIT_SCAN_CODE_KEY_2		equ COMMON_SCAN_CODE_LEFT_CONTROL

; "task switch" command key combination
GUI_KEYBOARD_TASK_SWITCH_SCAN_CODE_KEY_1	equ COMMON_SCAN_CODE_TAB
GUI_KEYBOARD_TASK_SWITCH_SCAN_CODE_KEY_2	equ COMMON_SCAN_CODE_LEFT_ALT
								; for key status mode

; these are used for the second (newer) way of accessing the keyboard
; the kernel notifies consumers whenever a key status changes
guiKeyboardKeyStatusChangedMessageType:			db '_kkeyboard-status-changed', 0
GUI_KEYBOARD_KEY_STATUS_CHANGED_MESSAGE_SIZE	equ 4


; Prepares keyboard before usage
;
; input:
;		none
; output:
;		none	
gui_keyboard_prepare:
	pusha
	
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:oldKeyboardDriverMode], ax	; save it
	
	pushf
	cli
	mov ax, 1					; choose Snowdrop's keyboard driver
	int 0BCh					; change keyboard driver mode
	popf
	
	popa
	ret
	
										
; Initializes GUI keyboard functionality
;
; input:
;		none
; output:
;		none
gui_keyboard_initialize:
	pusha

	call gui_keyboard_subscribe_status_changed
	
	popa
	ret


; Performs any destruction logic needed in the case when the GUI framework
; was prepared but not started
;
; input:
;		none
; output:
;		none	
gui_keyboard_premature_shutdown:
	pusha
	
	mov ax, word [cs:oldKeyboardDriverMode]
	int 0BCh					; restore keyboard driver mode
	
	popa
	ret
	
	
; Performs any destruction logic needed
;
; input:
;		none
; output:
;		none
gui_keyboard_shutdown:
	pusha
	
	call gui_keyboard_premature_shutdown
	
	popa
	ret


; Delegates to one of the available handlers, based on current operating mode
;
; input:
;		none
; output:
;		none
gui_keyboard_handle_event:
	pusha

	call gui_keyboard_try_handle_key_status

	popa
	ret
	
	
; Considers the newly-dequeued event when keyboard is operating
; in key status mode.
;
; input:
;		none
; output:
;		none	
gui_keyboard_try_handle_key_status:
	pusha
	
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_KEYBOARD_KEY_STATUS_CHANGED
	jne gui_keyboard_try_handle_key_status_done	; unsupported event type
	; we handle the event now

	; is the "exit" key combination pressed?
	mov bl, GUI_KEYBOARD_EXIT_SCAN_CODE_KEY_1
	int 0BAh
	cmp al, 0									; not pressed?
	je gui_keyboard_try_handle_key_status__after_exit
	
	mov bl, GUI_KEYBOARD_EXIT_SCAN_CODE_KEY_2
	int 0BAh
	cmp al, 0									; not pressed?
	je gui_keyboard_try_handle_key_status__after_exit
	
	; wait for keys to no longer be pressed
gui_keyboard_try_handle_key_status__exit_wait_release:	
	mov bl, GUI_KEYBOARD_EXIT_SCAN_CODE_KEY_2
	int 0BAh
	cmp al, 0
	jne gui_keyboard_try_handle_key_status__exit_wait_release
	mov bl, GUI_KEYBOARD_EXIT_SCAN_CODE_KEY_1
	int 0BAh
	cmp al, 0
	jne gui_keyboard_try_handle_key_status__exit_wait_release
	
	
	; handle "exit" keyboard command
	call gui_cancel_event
	call common_gui_shutdown
gui_keyboard_try_handle_key_status__after_exit:
	; is the "task switch" key combination pressed?
	mov bl, GUI_KEYBOARD_TASK_SWITCH_SCAN_CODE_KEY_1
	int 0BAh
	cmp al, 0									; not pressed?
	je gui_keyboard_try_handle_key_status__after_switch_task
	
	mov bl, GUI_KEYBOARD_TASK_SWITCH_SCAN_CODE_KEY_2
	int 0BAh
	cmp al, 0									; not pressed?
	je gui_keyboard_try_handle_key_status__after_switch_task
	
	; wait for keys to no longer be pressed
gui_keyboard_try_handle_key_status__switch_task_wait_release:	
	mov bl, GUI_KEYBOARD_TASK_SWITCH_SCAN_CODE_KEY_2
	int 0BAh
	cmp al, 0
	jne gui_keyboard_try_handle_key_status__switch_task_wait_release
	mov bl, GUI_KEYBOARD_TASK_SWITCH_SCAN_CODE_KEY_1
	int 0BAh
	cmp al, 0
	jne gui_keyboard_try_handle_key_status__switch_task_wait_release
	
	; yield to another GUI task
	call gui_cancel_event
	call gui_yield
	
gui_keyboard_try_handle_key_status__after_switch_task:
	
gui_keyboard_try_handle_key_status_done:
	popa
	ret
	
	
; Prepares the component for a task yield
;
; input:
;		none
; output:
;		none
gui_keyboard_prepare_for_yield:
	pusha
	
	mov ax, word [cs:oldKeyboardDriverMode]
	int 0BCh					; restore keyboard driver mode
	
	popa
	ret
	

; Restores the component after a task yield
;
; input:
;		none
; output:
;		none	
gui_keyboard_restore_after_yield:
	pusha
	
	mov ax, 1					; choose Snowdrop's keyboard driver
	int 0BCh					; register our keyboard driver mode
	
	popa
	ret

	
; Listens to messages containing key status changes
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
gui_keyboard_key_status_changed_callback:
	cmp cx, GUI_KEYBOARD_KEY_STATUS_CHANGED_MESSAGE_SIZE
	jne gui_keyboard_key_status_changed_callback_done	; NOOP when unsupported
	
	push ax
	push bx
	call gui_get_my_task_id							; AX := my task ID
	mov bx, ax
	int 9Ah											; AX := current task
	cmp bx, ax
	pop bx
	pop ax
	jne gui_keyboard_key_status_changed_callback_done	; NOOP when I'm not active

	; raise a  "key status changed" event, to notify components 
	; of the key status change
	mov al, GUI_EVENT_KEYBOARD_KEY_STATUS_CHANGED
	mov bl, byte [ds:si+0]							; scan code
	mov bh, byte [ds:si+1]							; 0=released, 1=pressed
	mov dl, byte [ds:si+2]							; 0=no ASCII, 1=has ASCII
	mov dh, byte [ds:si+3]							; ASCII, when it has
	call gui_event_enqueue_5bytes_atomic

gui_keyboard_key_status_changed_callback_done:
	retf
	

; Subscribe to receive key status notifications
;
; input:
;		none
; output:
;		none
gui_keyboard_subscribe_status_changed:
	pusha
	push ds
	push es
	
	; subscribe to task start notifications, so we know when other
	; tasks start tasks
	mov ax, cs
	mov ds, ax	
	mov si, guiKeyboardKeyStatusChangedMessageType	; DS:SI := ptr to type
	
	mov dx, cs
	mov bx, gui_keyboard_key_status_changed_callback	; DX:BX := callback
	
	mov ah, 0										; function 0: subscribe
	int 0C4h
	
	pop es
	pop ds
	popa
	ret
	

%endif
