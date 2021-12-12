;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains a library for working with queues allocated via dynamic memory.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DYNAMIC_QUEUES_
%define _COMMON_DYNAMIC_QUEUES_

; The consumer declares a queueHeadPtr as shown below. It holds exclusively
; overhead bytes, to point at the queue head, and indicate whether the
; head exists or not.
; By declaring multiple head pointers, a consumer application can
; create and operate on multiple queues.
; The consumer application is expected to not modify these bytes.
;
;     queueHeadPtr:	times COMMON_DYNQUEUE_HEAD_PTR_LENGTH db COMMON_DYNQUEUE_HEAD_PTR_INITIAL
;
; Since %includes are often at the end of the file (because the initial jmp
; cannot be too long), in NASM I tend to define for example:
;     COMMON_DYNQUEUE_HEAD_PTR_LENGTH_2 equ COMMON_DYNQUEUE_HEAD_PTR_LENGTH
;     COMMON_DYNQUEUE_HEAD_PTR_INITIAL_2 equ COMMON_DYNQUEUE_HEAD_PTR_INITIAL
; to get over the "non-constant supplied to times" error.
; Then I define queueHeadPtr based on those instead.
;
; Whenever queue functions are invoked, the consumer application provides
; a pointer to a pointer to the queue head like so:
; 
;     push cs
;     pop fs
;     mov bx, queueHeadPtr				; FS:BX := pointer to pointer to head
;
; Also, the size (in bytes) of an element must be passed in like so:
;
;     mov cx, ELEMENT_SIZE				; size of a queue element, in bytes
;										; consumers applications are expected
;										; to not access any of an element's
;										; bytes past this count
; And then:
;
;     call common_dynqueue_...
;
; Queues are implemented as linked lists where:
;     - elements can only be added at the end
;     - elements can only be removed from the head

; a dynamic queue does not need any more information than a simple linked list
COMMON_DYNQUEUE_HEAD_PTR_LENGTH		equ COMMON_LLIST_HEAD_PTR_LENGTH
COMMON_DYNQUEUE_HEAD_PTR_INITIAL	equ COMMON_LLIST_HEAD_PTR_INITIAL


; Gets the number of elements in the queue
;
; input:
;	 FS:BX - pointer to pointer to queue head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - count of elements in the queue
common_dynqueue_get_length:
	call common_llist_count
	ret


; Removes all elements from the queue
;
; input:
;	 FS:BX - pointer to pointer to queue head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		none
common_dynqueue_clear:
	call common_llist_clear
	ret


; Returns a pointer to the element at the front of the queue (that is, first
; to be dequeued), if one exists
;
; input:
;	 FS:BX - pointer to pointer to queue head
; output:
;		AX - 0 when queue is empty, other value otherwise
;	 DS:SI - pointer to first element in queue, when successful
common_dynqueue_peek:
	call common_llist_get_head
	ret


; Adds an element to the queue
;
; input:
;	 FS:BX - pointer to pointer to queue head
;	 ES:DI - pointer to payload to add as a new element
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to element in the queue, when successful
common_dynqueue_enqueue:
	call common_llist_add
	ret

	
; Returns a pointer to a copy of the element at the front of the queue, if one
; exists, removing said element from the queue.
;
; NOTE: the consumer is expected to deallocate the returned pointer,
;       when successful
;
; input:
;	 FS:BX - pointer to pointer to queue head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when queue is empty, other value otherwise
;	 DS:SI - pointer to removed queue element, when successful
common_dynqueue_dequeue:
	pushf
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	call common_llist_get_head				; DS:SI := first element
	cmp ax, 0								; is it empty?
	je common_dynqueue_dequeue_fail			; yes, so we fail
	; now remove it from queue, but don't de-allocate it
	
	push ds
	push si									; [1] save pointer to head
	
	; allocate an output buffer in which we'll copy result
	mov ax, cx								; AX := element size
	call common_memory_allocate				; DS:SI := new chunk
	cmp ax, 0
	je common_dynqueue_dequeue__clean_stack_and_fail
	
	push ds
	pop es
	mov di, si								; ES:DI := pointer to output buffer
	pop si
	pop ds									; [1] DS:SI := pointer to head
	
	push es
	push di									; [2] save pointer to output buffer
	
	; here, CX = element size (consumer)
	push cx									; [3] save element size
	cld
	rep movsb								; copy into output buffer
	
	; here, FS:BX = pointer to pointer to queue head
	pop cx									; [3] CX := element size
	mov dx, 0								; we're removing at index 0
	call common_llist_remove_at_index		; guaranteed to succeed
	
	pop si
	pop ds									; [2] DS:SI := ptr to output buffer
	jmp common_dynqueue_dequeue_success
	
common_dynqueue_dequeue__clean_stack_and_fail:
	; clean one pointer (seg:off) from stack
	add sp, 4
	
common_dynqueue_dequeue_fail:
	mov ax, 0
	jmp common_dynqueue_dequeue_done
common_dynqueue_dequeue_success:
	mov ax, 1
common_dynqueue_dequeue_done:
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	popf
	ret
	
%include "common\memory.asm"
%include "common\dynamic\linklist.asm"
	
%endif
