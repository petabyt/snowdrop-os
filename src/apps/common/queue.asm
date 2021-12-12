;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It allows access to a circular queue buffer where each element is a byte.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; when this %define block is declared before this file is included in a
; program, it allows the program to configure the size of the queue
%ifndef _COMMON_QUEUE_CONF_
%define _COMMON_QUEUE_CONF_

QUEUE_LENGTH equ 512						; default queue size in bytes

%endif


%ifndef _COMMON_QUEUE_
%define _COMMON_QUEUE_

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Note: ATOMIC (hardware interrupt-safe versions are found later in this file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

circularQueue: times QUEUE_LENGTH db 0	; queue storage

queueHeadIndex: dw 0				; we dequeue from the index after this
queueTailIndex: dw 0				; we enqueue to the index after this
queueCount:		dw 0				; count of items in the queue


; Gets the number of elements in the queue
;
; input:
;		none
; output:
;		AX - queue length
common_queue_get_length:
	push ds
	
	push cs
	pop ds
	mov ax, word [queueCount]
	
	pop ds
	ret


; Gets the amount of elements that can still be added to the queue
;
; input:
;		none
; output:
;		AX - queue remaining capacity
common_queue_get_remaining_capacity:
	push ds
	push bx
	
	mov bx, QUEUE_LENGTH
	call common_queue_get_length		; AX := queue length
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
common_queue_clear:
	push ds
	
	push cs
	pop ds
	mov word [queueHeadIndex], 0
	mov word [queueTailIndex], 0
	mov word [queueCount], 0
	
	pop ds
	ret


; Returns the front-most item from the queue without removing it
;
; input:
;		none	
; output:
;		DL - peeked byte when queue is not empty
;		AX - 0 when queue is not empty (success)	
common_queue_peek:
	call common_queue_get_length		; at least one item?
	cmp ax, 0
	je common_queue_peek_empty		; can't dequeue when empty
	
	push ds
	push bx
	
	push cs
	pop ds								; point DS to "this" segment
	
	mov bx, word [queueHeadIndex]
	inc bx								; we peek at the element right after
	cmp bx, QUEUE_LENGTH				; did we pass the end?
	jb common_queue_peek_index_ok		; no
	; we're past the end, so wrap around
	mov bx, 0
common_queue_peek_index_ok:
	add bx, circularQueue				; BX := offset into queue
	mov dl, byte [ds:bx]				; read byte
	
	pop bx
	pop ds
	mov ax, 0							; indicate success
	ret
common_queue_peek_empty:
	mov ax, 1							; indicate empty
	ret
	

; Add new item to the back of the queue if there is room
;
; input:
;		DL - byte to enqueue
; output:
;		AX - 0 when there's no overflow (success)
common_queue_enqueue:
	call common_queue_get_length		; full?
	cmp ax, QUEUE_LENGTH
	je common_queue_enqueue_overflow	; queue already full
	
	push ds
	push cs
	pop ds
	push bx
	mov bx, word [queueTailIndex]
	inc bx
	cmp bx, QUEUE_LENGTH				; did we pass the end?
	jb common_queue_enqueue_index_ok	; no
	; we're past the end, so wrap around
	mov bx, 0
common_queue_enqueue_index_ok:
	; here, BX contains new tail index
	mov word [queueTailIndex], bx		; save new tail index
	add bx, circularQueue				; BX := offset into queue
	mov byte [ds:bx], dl				; store byte
	inc word [queueCount]				; count++
	pop bx
	pop ds
	
	mov ax, 0							; return success
	ret
common_queue_enqueue_overflow:
	mov ax, 1							; return overflow
	ret
	

; Removes and returns the front-most item from the queue
;
; input:
;		none	
; output:
;		DL - dequeued byte when queue is not empty
;		AX - 0 when queue is not empty (success)
common_queue_dequeue:
	call common_queue_get_length		; at least one item?
	cmp ax, 0
	je common_queue_dequeue_empty		; can't dequeue when empty
	
	; not empty, so dequeue
	push ds
	push cs
	pop ds
	push bx
	mov bx, word [queueHeadIndex]
	inc bx
	cmp bx, QUEUE_LENGTH				; did we pass the end?
	jb common_queue_dequeue_index_ok	; no
	; we're past the end, so wrap around
	mov bx, 0
common_queue_dequeue_index_ok:
	; here, BX contains new head index
	mov word [queueHeadIndex], bx		; save new head index
	add bx, circularQueue				; BX := offset into queue
	mov dl, byte [ds:bx]				; read byte
	dec word [queueCount]				; count--
	pop bx
	pop ds
	
	mov ax, 0							; indicate success
	ret
common_queue_dequeue_empty:
	mov ax, 1							; indicate empty
	ret

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ATOMIC versions of each of the above calls, to be used when hardware
; interrupts can modify the queue
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	
; Removes and returns the front-most item from the queue
; Note: atomic (hardware interrupt-safe)
;
; input:
;		none	
; output:
;		DL - dequeued byte when queue is not empty
;		AX - 0 when queue is not empty (success)
common_queue_dequeue_atomic:
	pushf
	cli									; ensure we can't be interrupted
	call common_queue_dequeue
	popf
	ret

	
; Add new item to the back of the queue if there is room
; Note: atomic (hardware interrupt-safe)
;
; input:
;		DL - byte to enqueue
; output:
;		AX - 0 when there's no overflow (success)
common_queue_enqueue_atomic:
	pushf
	cli									; ensure we can't be interrupted
	call common_queue_enqueue
	popf
	ret


; Returns the front-most item from the queue without removing it
; Note: atomic (hardware interrupt-safe)
;
; input:
;		none	
; output:
;		DL - peeked byte when queue is not empty
;		AX - 0 when queue is not empty (success)	
common_queue_peek_atomic:
	pushf
	cli									; ensure we can't be interrupted
	call common_queue_peek
	popf
	ret
	
	
; Empties the queue
; Note: atomic (hardware interrupt-safe)
;
; input:
;		none
; output:
;		none
common_queue_clear_atomic:
	pushf
	cli									; ensure we can't be interrupted
	call common_queue_clear
	popf
	ret

	
; Gets the amount of elements that can still be added to the queue
; Note: atomic (hardware interrupt-safe)
;
; input:
;		none
; output:
;		AX - queue remaining capacity
common_queue_get_remaining_capacity_atomic:
	pushf
	cli									; ensure we can't be interrupted
	call common_queue_get_remaining_capacity
	popf
	ret
	

; Gets the number of elements in the queue
; Note: atomic (hardware interrupt-safe)
;
; input:
;		none
; output:
;		AX - queue length
common_queue_get_length_atomic:
	pushf
	cli									; ensure we can't be interrupted
	call common_queue_get_length
	popf
	ret
	
	
%endif
