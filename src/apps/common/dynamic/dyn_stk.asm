;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains a library for working with stacks allocated via dynamic memory.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DYNAMIC_STACKS_
%define _COMMON_DYNAMIC_STACKS_

; The consumer declares a stackHeadPtr as shown below. It holds exclusively
; overhead bytes, to point at the stack head, and indicate whether the head
; exists or not.
; By declaring multiple head pointers, a consumer application can
; create and operate on multiple stacks.
; The consumer application is expected to not modify these bytes.
;
;     stackHeadPtr:	times COMMON_DYNSTACK_HEAD_PTR_LENGTH db COMMON_DYNSTACK_HEAD_PTR_INITIAL
;
; Since %includes are often at the end of the file (because the initial jmp
; cannot be too long), in NASM I tend to define for example:
;     COMMON_DYNSTACK_HEAD_PTR_LENGTH_2 equ COMMON_DYNSTACK_HEAD_PTR_LENGTH
;     COMMON_DYNSTACK_HEAD_PTR_INITIAL_2 equ COMMON_DYNSTACK_HEAD_PTR_INITIAL
; to get over the "non-constant supplied to times" error.
; Then I define stackHeadPtr based on those instead.
;
; Whenever stack functions are invoked, the consumer application provides
; a pointer to a pointer to the stack head like so:
; 
;     push cs
;     pop fs
;     mov bx, stackHeadPtr				; FS:BX := pointer to pointer to head
;
; Also, the size (in bytes) of an element must be passed in like so:
;
;     mov cx, ELEMENT_SIZE				; size of a stack element, in bytes
;										; consumers applications are expected
;										; to not access any of an element's
;										; bytes past this count
; And then:
;
;     call common_dynstack_...
;
; Stacks are implemented as linked lists where:
;     - elements can only be added to the head
;     - elements can only be removed from the head

; a dynamic stack does not need any more information than a simple linked list
COMMON_DYNSTACK_HEAD_PTR_LENGTH		equ COMMON_LLIST_HEAD_PTR_LENGTH
COMMON_DYNSTACK_HEAD_PTR_INITIAL	equ COMMON_LLIST_HEAD_PTR_INITIAL


; Gets the number of elements in the stack
;
; input:
;	 FS:BX - pointer to pointer to stack head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - count of elements in the stack
common_dynstack_get_length:
	call common_llist_count
	ret


; Removes all elements from the stack
;
; input:
;	 FS:BX - pointer to pointer to stack head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		none
common_dynstack_clear:
	call common_llist_clear
	ret


; Returns a pointer to the element at the top of the stack (that is, first
; to be popped), if one exists
;
; input:
;	 FS:BX - pointer to pointer to stack head
; output:
;		AX - 0 when stack is empty, other value otherwise
;	 DS:SI - pointer to top element in stack, when successful
common_dynstack_peek:
	call common_llist_get_head
	ret


; Adds an element to top of the stack
;
; input:
;	 FS:BX - pointer to pointer to stack head
;	 ES:DI - pointer to payload to add as a new element
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to element in the stack, when successful
common_dynstack_push:
	call common_llist_add_head
	ret

	
; Returns a pointer to a copy of the element at the top of the stack, if one
; exists, removing said element from the stack.
;
; NOTE: the consumer is expected to deallocate the returned pointer,
;       when successful
;
; input:
;	 FS:BX - pointer to pointer to stack head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when stack is empty, other value otherwise
;	 DS:SI - pointer to removed stack element, when successful
common_dynstack_pop:
	pushf
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	call common_llist_get_head				; DS:SI := first element
	cmp ax, 0								; is it empty?
	je common_dynstack_pop_fail			; yes, so we fail
	; now remove it from stack, but don't de-allocate it
	
	push ds
	push si									; [1] save pointer to head
	
	; allocate an output buffer in which we'll copy result
	mov ax, cx								; AX := element size
	call common_memory_allocate				; DS:SI := new chunk
	cmp ax, 0
	je common_dynstack_pop___clean_stack_and_fail

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
	
	; here, FS:BX = pointer to pointer to stack top
	pop cx									; [3] CX := element size
	mov dx, 0								; we're removing at index 0
	call common_llist_remove_at_index		; guaranteed to succeed
	
	pop si
	pop ds									; [2] DS:SI := ptr to output buffer
	jmp common_dynstack_pop_success
	
common_dynstack_pop___clean_stack_and_fail:
	; one pointer (seg:off) on stack
	add sp, 4
	
common_dynstack_pop_fail:
	mov ax, 0
	jmp common_dynstack_pop_done
common_dynstack_pop_success:
	mov ax, 1
common_dynstack_pop_done:
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
