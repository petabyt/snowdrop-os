;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains the most fundamental GUI functionality, relied upon by
; higher-level GUI modules.
; It also contains general GUI framework constants.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_CORE_
%define _COMMON_GUI_CORE_


GUI_EVENT_MOUSEBUTTON_LEFT_DOWN			equ 0	; type, x (word), y (word)
GUI_EVENT_MOUSEBUTTON_LEFT_UP			equ 1	; type, x (word), y (word)
GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN		equ 2	; type, x (word), y (word)
GUI_EVENT_MOUSEBUTTON_RIGHT_UP			equ 3	; type, x (word), y (word)
GUI_EVENT_MOUSE_MOVE					equ 4	; type, x (word), y (word)
__OBSOLETE_GUI_EVENT_KEYBOARD_KEY_AVAILABLE		equ 5	; type, scan code, ASCII
GUI_EVENT_KEYBOARD_KEY_STATUS_CHANGED	equ 6	; type, scan code, released/pressed, ASCII?, ASCII
GUI_EVENT_BUTTON_INVOKE_CALLBACK		equ 7	; type, button offset (word)
GUI_EVENT_CHECKBOX_INVOKE_CALLBACK		equ 8	; type, checkbox offset (word)
GUI_EVENT_IMAGE_INVOKE_LCLICK_CALLBACK	equ 9	; type, image offset (word)
GUI_EVENT_IMAGE_INVOKE_RCLICK_CALLBACK	equ 10	; type, image offset (word)
GUI_EVENT_IMAGE_INVOKE_SELECTED_CHANGED_CALLBACK equ 11	
												; type, image offset (word)
GUI_EVENT_RADIO_INVOKE_CALLBACK			equ 12	; type, radio offset (word)
GUI_EVENT_SHUTDOWN_REQUESTED			equ 13	; type
GUI_EVENT_TIMER_TICK					equ 14	; type
GUI_EVENT_PALETTE_CHANGE				equ 15	; type, palette
GUI_EVENT_YIELD_START					equ 16	; type
GUI_EVENT_FONT_CHANGE					equ 17	; type, font type
GUI_EVENT_SCREEN_REFRESH				equ 18	; type
GUI_EVENT_OTHER_TASK_EXIT				equ 19	; type, task ID (word)
GUI_EVENT_OTHER_TASK_AWAITS_START		equ 20	; type, task ID (word)
GUI_EVENT_NOOP							equ 21	; type
GUI_EVENT_INVOKE_INITIALIZED_CALLBACK	equ 22	; type
GUI_EVENT_INITIALIZE_TIMER				equ 23	; type
; array which holds the number of bytes for each event
eventByteCounts:	db 5, 5, 5, 5, 5, 3, 5, 3, 3, 3, 3, 3, 3, 1, 1, 2, 1, 2, 1, 3, 3, 1, 1, 1

; temporary buffers which hold event bytes during event operations
; accesses MUST be atomic
MAX_EVENT_SIZE_IN_BYTES				equ 32
enqueueEventBytesBuffer: times MAX_EVENT_SIZE_IN_BYTES db 0
dequeueEventBytesBuffer: times MAX_EVENT_SIZE_IN_BYTES db 0

GUI_MOUSE_CURSOR_SIZE			equ 8
GUI_RESERVED_COMPONENT_COUNT	equ 5	; a buffer of components on top of
										; the default (in case it was
										; overridden to 0)

EVENT_QUEUE_LENGTH equ 512				; in bytes

eventQueueStorage: times EVENT_QUEUE_LENGTH db 0	; event queue storage

eventQueueHeadIndex: dw 0				; we dequeue from the index after this
eventQueueTailIndex: dw 0				; we enqueue to the index after this
eventQueueCount:	 dw 0				; count of items in the queue

guiCoreMyTaskId:		dw 0

guiCoreCallbacksAreEnabled:		db 0


; Used to prevent consumer callbacks from being invoked before everything
; has been initialized
;
; input:
;		none
; output:
;		none
gui_core_disable_callbacks:
	mov byte [cs:guiCoreCallbacksAreEnabled], 0
	ret
	
	
; Used to prevent consumer callbacks from being invoked before everything
; has been initialized
;
; input:
;		none
; output:
;		none
gui_core_enable_callbacks:
	mov byte [cs:guiCoreCallbacksAreEnabled], 1
	ret
	

; Returns my task ID
;
; input:
;		none
; output:
;		AX - my task ID
gui_get_my_task_id:
	mov ax, word [cs:guiCoreMyTaskId]
	ret


; Clears event queue atomically
;
; input:
;		none
; output:
;		none
gui_queue_clear_atomic:
	pusha
	pushf
	
	cli
	call event_queue_clear
	
	popf
	popa
	ret

	
; Cancels the last-dequeued event by replacing it with a NOOP event.
; This prevents any further processing of this event.
;
; input:
;		none
; output:
;		none
gui_cancel_event:
	pusha
	pushf

	cli
	mov byte [cs:dequeueEventBytesBuffer+0], GUI_EVENT_NOOP
	
	popf
	popa
	ret
	

; Dequeue event bytes from event queue
;
; input:
;		none
; output:
;		DS:SI - pointer to buffer where event bytes are stored
gui_dequeue_event_atomic:
	pusha
	pushf

	cli
	call event_queue_peek			; DL := first event byte (event type)
	; nothing has yet been dequeued
	mov dh, 0
	mov bx, dx						; BX := DL
	mov cl, byte [cs:eventByteCounts+bx]	; CL := event byte count
	mov di, dequeueEventBytesBuffer
gui_dequeue_event_atomic_loop:
	cmp cl, 0
	je gui_dequeue_event_atomic_done
	call event_queue_dequeue			; DL := event byte
	mov byte [cs:di], dl
	dec cl
	inc di
	jmp gui_dequeue_event_atomic_loop
gui_dequeue_event_atomic_done:
	popf
	popa
	; create result pointer
	push cs
	pop ds
	mov si, dequeueEventBytesBuffer		; DS:SI now points to result
	ret


; Enqueues an event by adding all of its bytes to the event queue.
; NOOP when queue remaining capacity is less than the number 
; of bytes in the event.
; Operation is atomic.
;
; input:
;		DS:SI - pointer to event byte values
;		   CX - event byte count
; output:
;		none
gui_event_enqueue_atomic:
	pusha
	
	pushf
	cli						; we want our event addition to be atomic
	
	call event_queue_get_remaining_capacity	; AX := remaining capacity
	cmp cx, ax					; required > capacity?
	ja gui_event_enqueue_done	; yes, so we're not adding this event
	; queue capacity is sufficient - add the event
gui_event_enqueue_perform:
	cmp cx, 0					; any more bytes to enqueue?
	je gui_event_enqueue_done	; no
	mov dl, byte [ds:si]		; DL := current byte to enqueue
	call event_queue_enqueue
	inc si						; next byte
	dec cx
	jmp gui_event_enqueue_perform
gui_event_enqueue_done:
	popf					; restore interrupt flag to previous value
	
	popa
	ret


; Helper method
; Enqueues a single-byte event
;
; input:
;		AL - byte to enqueue
; output:
;		none
gui_event_enqueue_1byte_atomic:
	pusha
	pushf
	push ds
	
	cli
	push cs
	pop ds
	mov si, enqueueEventBytesBuffer
	
	mov byte [ds:si], al		; populate event bytes
	mov cx, 1					; event has this many bytes
	call gui_event_enqueue_atomic
	
	pop ds
	popf
	popa
	ret
	

; Helper method
; Enqueues a 2-byte event
;
; input:
;		AL - first byte to enqueue
;		BL - second byte to enqueue
; output:
;		none
gui_event_enqueue_2bytes_atomic:
	pusha
	pushf
	push ds
	
	cli
	push cs
	pop ds
	mov si, enqueueEventBytesBuffer
	
	mov byte [ds:si], al		; populate event bytes
	mov byte [ds:si+1], bl
	mov cx, 2					; event has this many bytes
	call gui_event_enqueue_atomic
	
	pop ds
	popf
	popa
	ret

	
; Helper method
; Enqueues a 3-byte event
;
; input:
;		AL - first byte to enqueue
;		BL - second byte to enqueue
;		BH - third byte to enqueue
; output:
;		none
gui_event_enqueue_3bytes_atomic:
	pusha
	pushf
	push ds
	
	cli
	push cs
	pop ds
	mov si, enqueueEventBytesBuffer
	
	mov byte [ds:si], al		; populate event bytes
	mov byte [ds:si+1], bl
	mov byte [ds:si+2], bh
	mov cx, 3					; event has this many bytes
	call gui_event_enqueue_atomic
	
	pop ds
	popf
	popa
	ret
	
	
; Helper method
; Enqueues a 5-byte event
;
; input:
;		AL - first byte to enqueue
;		BL - second byte to enqueue
;		BH - third byte to enqueue
;		DL - fourth byte to enqueue
;		DH - fifth byte to enqueue
; output:
;		none
gui_event_enqueue_5bytes_atomic:
	pusha
	pushf
	push ds
	
	cli
	push cs
	pop ds
	mov si, enqueueEventBytesBuffer
	
	mov byte [ds:si], al		; populate event bytes
	mov byte [ds:si+1], bl
	mov byte [ds:si+2], bh
	mov byte [ds:si+3], dl
	mov byte [ds:si+4], dh
	mov cx, 5					; event has this many bytes
	call gui_event_enqueue_atomic
	
	pop ds
	popf
	popa
	ret
	

; A do-nothing callback which can be used by GUI components in the 
; absence of a consumer-provided callback
gui_noop_callback:
	retf


; Invokes the specified callback with no arguments
;
; input:
;	 DS:SI - pointer to callback
; output:
;		none
gui_invoke_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	cmp byte [cs:guiCoreCallbacksAreEnabled], 0
	je gui_invoke_callback_done
	
	; setup return address
	push cs
	push word gui_invoke_callback_return	; return address on stack
	
	; setup "call far" address
	push ds			; callback segment
	push si			; callback offset
	retf			; "call far"
	; once the callback executes its own retf, execution returns below
gui_invoke_callback_return:
gui_invoke_callback_done:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret

	
; Gets the number of elements in the queue
;
; input:
;		none
; output:
;		AX - queue length
event_queue_get_length:
	push ds
	
	push cs
	pop ds
	mov ax, word [eventQueueCount]
	
	pop ds
	ret


; Gets the amount of elements that can still be added to the queue
;
; input:
;		none
; output:
;		AX - queue remaining capacity
event_queue_get_remaining_capacity:
	push ds
	push bx
	
	mov bx, EVENT_QUEUE_LENGTH
	call event_queue_get_length		; AX := queue length
	sub bx, ax
	mov ax, bx							; AX := remaining capacity
	
	pop bx
	pop ds
	ret
	

; Empties the queue
;
; input:
;		none
; output:
;		none
event_queue_clear:
	push ds
	
	push cs
	pop ds
	mov word [eventQueueHeadIndex], 0
	mov word [eventQueueTailIndex], 0
	mov word [eventQueueCount], 0
	
	pop ds
	ret


; Returns the front-most item from the queue without removing it
;
; input:
;		none	
; output:
;		DL - peeked byte when queue is not empty
;		AX - 0 when queue is not empty (success)	
event_queue_peek:
	call event_queue_get_length		; at least one item?
	cmp ax, 0
	je event_queue_peek_empty		; can't dequeue when empty
	
	push ds
	push bx
	
	push cs
	pop ds								; point DS to "this" segment
	
	mov bx, word [eventQueueHeadIndex]
	inc bx								; we peek at the element right after
	cmp bx, EVENT_QUEUE_LENGTH				; did we pass the end?
	jb event_queue_peek_index_ok		; no
	; we're past the end, so wrap around
	mov bx, 0
event_queue_peek_index_ok:
	add bx, eventQueueStorage				; BX := offset into queue
	mov dl, byte [ds:bx]				; read byte
	
	pop bx
	pop ds
	mov ax, 0							; indicate success
	ret
event_queue_peek_empty:
	mov ax, 1							; indicate empty
	ret
	

; Add new item to the back of the queue if there is room
;
; input:
;		DL - byte to enqueue
; output:
;		AX - 0 when there's no overflow (success)
event_queue_enqueue:
	call event_queue_get_length		; full?
	cmp ax, EVENT_QUEUE_LENGTH
	je event_queue_enqueue_overflow	; queue already full
	
	push ds
	push cs
	pop ds
	push bx
	mov bx, word [eventQueueTailIndex]
	inc bx
	cmp bx, EVENT_QUEUE_LENGTH				; did we pass the end?
	jb event_queue_enqueue_index_ok	; no
	; we're past the end, so wrap around
	mov bx, 0
event_queue_enqueue_index_ok:
	; here, BX contains new tail index
	mov word [eventQueueTailIndex], bx		; save new tail index
	add bx, eventQueueStorage				; BX := offset into queue
	mov byte [ds:bx], dl				; store byte
	inc word [eventQueueCount]				; count++
	pop bx
	pop ds
	
	mov ax, 0							; return success
	ret
event_queue_enqueue_overflow:
	mov ax, 1							; return overflow
	ret
	

; Removes and returns the front-most item from the queue
;
; input:
;		none	
; output:
;		DL - dequeued byte when queue is not empty
;		AX - 0 when queue is not empty (success)
event_queue_dequeue:
	call event_queue_get_length		; at least one item?
	cmp ax, 0
	je event_queue_dequeue_empty		; can't dequeue when empty
	
	; not empty, so dequeue
	push ds
	push cs
	pop ds
	push bx
	mov bx, word [eventQueueHeadIndex]
	inc bx
	cmp bx, EVENT_QUEUE_LENGTH				; did we pass the end?
	jb event_queue_dequeue_index_ok	; no
	; we're past the end, so wrap around
	mov bx, 0
event_queue_dequeue_index_ok:
	; here, BX contains new head index
	mov word [eventQueueHeadIndex], bx		; save new head index
	add bx, eventQueueStorage				; BX := offset into queue
	mov dl, byte [ds:bx]				; read byte
	dec word [eventQueueCount]				; count--
	pop bx
	pop ds
	
	mov ax, 0							; indicate success
	ret
event_queue_dequeue_empty:
	mov ax, 1							; indicate empty
	ret


%endif
