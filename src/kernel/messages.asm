;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the messaging system, which allows communication between tasks
; and between tasks and kernel, via a provider-consumer notification model.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


messagesNoDynMemory:	db ' FATAL: messaging requires dynamic memory', 0
messagesDebugConsumersHeading:
	db 'MESSAGE TYPE     SEG  OFF  OWNER  FLAGS', 0

messagesTypeKernelWarning:	db '_kwarn', 0
messagesWarnCannotAddConsumer:	db 'Message consumer could not be added', 0
messagesWarnCannotRemoveConsumer:	db 'Message consumer could not be removed', 0

messagesIsInitialized:	db 0

; list of consumers
MESSAGE_HEAD_PTR_LENGTH equ LLIST_HEAD_PTR_LENGTH
MESSAGE_HEAD_PTR_INITIAL equ LLIST_HEAD_PTR_INITIAL
msgConsumersListHeadPtr:	times MESSAGE_HEAD_PTR_LENGTH db MESSAGE_HEAD_PTR_INITIAL

MESSAGE_MAX_TYPE_LENGTH		equ 32	; in characters, not including terminator
MESSAGE_CONSUMER_ENTRY_LENGTH	equ 40
	; bytes 0 - 32    message type, zero terminated
	;      33 - 34    consumer segment
	;      35 - 36    consumer offset
	;      37 - 38    owner ID (e.g.: task ID if applicable)
	;      39 - 39    flags:
	;                 bits 0 - 1    owner type (0=kernel, 1=task)
	;                      2 - 7    unused

messageNewConsumerBuffer:	times MESSAGE_CONSUMER_ENTRY_LENGTH db 0
messageConsumerListIsLocked:	db 0

	
; Initializes the messaging system
;
; input
;		none
; output
;		none
messages_initialize:
	pusha
	push ds
	
	push cs
	pop ds
	
	call dynmem_is_initialized
	cmp ax, 0
	jne messages_initialize_done
	
	; we fail, because dynamic memory is not available for some reason
	mov si, messagesNoDynMemory
	jmp crash_and_print
	
messages_initialize_done:	
	mov byte [cs:messagesIsInitialized], 1
	mov byte [cs:messageConsumerListIsLocked], 0
	pop ds
	popa
	ret


; Publishes the specified message
;
; input
;	 DS:SI - pointer to message contents
;	 ES:DI - message type
;		CX - length of message contents
; output
;		none
messages_publish:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	push cx
	push ds
	push si								; [1] save input
	mov bp, sp							; SS:BP := ptr to ptr to message
										; SS:BP+4 := ptr to length
	cli
	
	cmp byte [cs:messagesIsInitialized], 0
	je messages_publish_done
	
	push cs
	pop fs
	mov bx, msgConsumersListHeadPtr		; FS:BX := pointer to head
	call llist_get_head					; DS:SI := head
	cmp ax, 0
	je messages_publish_done			; no consumers

	mov cx, MESSAGE_CONSUMER_ENTRY_LENGTH
messages_publish_loop:
	; here, DS:SI = start of current consumer entry
	; (which starts with the type string)
	; here, ES:DI points to type to search (passed in)
	int 0BDh							; compare strings
	cmp ax, 0
	jne messages_publish_loop_next		; no match on type
	; this consumer is subscribed to this message's type
	; tell consumer about this message
	
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word messages_publish_after_invoke	; return address on stack
	
	; setup "call far" address
	push word [ds:si+33]			; callback segment
	push word [ds:si+35]			; callback offset
	
	; setup callback arguments
	push ds
	pop es
	mov di, si						; ES:DI := ptr to message type
	mov si, word [ss:bp]
	mov ds, word [ss:bp+2]			; DS:SI := ptr to message bytes
	mov cx, word [ss:bp+4]			; CX := length of message
	
	retf							; "call far"
	; once the callback executes its own retf, execution returns below
messages_publish_after_invoke:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
messages_publish_loop_next:
	call llist_get_next					; DS:SI := next consumer
	cmp ax, 0
	jne messages_publish_loop			; got one
	; we're out of consumers
messages_publish_done:
	add sp, 6							; [1] clean stack
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	ret
	
	
; Subscribes the specified consumer to the specified message type, for
; the current task
;
; input
;	 DS:SI - pointer to message type string, no longer than 32 characters
;	 DX:BX - pointer to consumer function; consumer contract:
;			 input:
;				 DS:SI - pointer to message bytes
;				 ES:DI - pointer to message type
;					CX - message bytes length
;                   AX - (reserved for future functionality)
;                   BX - (reserved for future functionality)
;                   DX - (reserved for future functionality)
;			 output:
;					none
;			 Consumer may not add or remove consumers.
; output
;		none
messages_subscribe_task:
	pusha
	pushf
	
	cli
	
	cmp byte [cs:messagesIsInitialized], 0
	je messages_subscribe_task_done
	
	cmp byte [cs:messageConsumerListIsLocked], 0
	jne messages_subscribe_task_done
	
	mov byte [cs:messageConsumerListIsLocked], 1
	int 9Ah								; AX := current task ID
	mov cl, 1							; flags
	call _messages_subscribe			; invoke worker
messages_subscribe_task_done:
	mov byte [cs:messageConsumerListIsLocked], 0
	popf
	popa
	ret
	
	
; Subscribes the specified consumer to the specified message type
; NOTE: for kernel usage only; not exposed outward
;
; input
;	 DS:SI - pointer to message type string, no longer than 32 characters
;	 DX:BX - pointer to consumer function; consumer contract:
;			 input:
;				 DS:SI - pointer to message bytes
;				 ES:DI - pointer to message type
;					CX - message bytes length
;			 output:
;					none
;			 Consumer may not add or remove consumers.
; output
;		none
messages_subscribe_kernel:
	pusha
	pushf
	
	cli
	
	cmp byte [cs:messagesIsInitialized], 0
	je messages_subscribe_kernel_done
	
	cmp byte [cs:messageConsumerListIsLocked], 0
	jne messages_subscribe_kernel_done
	
	mov byte [cs:messageConsumerListIsLocked], 1
	mov cl, 0							; flags
	call _messages_subscribe			; invoke worker
messages_subscribe_kernel_done:
	mov byte [cs:messageConsumerListIsLocked], 0
	popf
	popa
	ret
	

; Worker. Does NOT perform initialization checks.
; Subscribes the specified consumer to the specified message type.
;
; input
;		AX - owner ID or undefined
;		CL - flags
;	 DS:SI - pointer to message type string, no longer than 32 characters
;	 DX:BX - pointer to consumer function; consumer contract:
;			 input:
;				 DS:SI - pointer to message bytes
;					CX - message bytes length
;			 output:
;					none
;			 Consumer may not add or remove consumers.
; output
;		none
_messages_subscribe:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs

	push bx
	int 0A5h							; BX := string length
	cmp bx, MESSAGE_MAX_TYPE_LENGTH
	pop bx
	ja _messages_subscribe_done
	
	; begin by populating the buffer, before addition
	push ax								; save owner
	push dx
	push bx								; save consumer
	push cx								; save flags

	push cs
	pop es
	mov di, messageNewConsumerBuffer	; ES:DI := buffer
	mov cx, MESSAGE_MAX_TYPE_LENGTH
	cld
	rep movsb							; copy message type
	mov byte [es:di], 0					; terminator
	mov di, messageNewConsumerBuffer	; ES:DI := buffer
	
	pop cx								; restore flags
	mov byte [es:di+39], cl				; write flags
	
	pop bx
	pop dx								; restore consumer
	mov word [es:di+33], dx
	mov word [es:di+35], bx				; write consumer
	
	pop ax								; restore owner
	mov word [es:di+37], ax				; write owner
	; here, ES:DI = pointer to buffer
	
	push cs
	pop fs
	mov bx, msgConsumersListHeadPtr		; FS:BX := pointer to head
	mov cx, MESSAGE_CONSUMER_ENTRY_LENGTH
	call llist_add						; add consumer
	cmp ax, 0
	jne _messages_subscribe_done		; no errors
	; consumer was not added
	call _messages_log_unable_to_add_consumer
_messages_subscribe_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	ret
	
	
; Unsubscribe all consumers subscribed by the specified task
;
; input
;		DX - task ID
; output
;		none
messages_unsubscribe_all_by_task:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	cli
	
	cmp byte [cs:messagesIsInitialized], 0
	je messages_unsubscribe_all_by_task_done
	
	cmp byte [cs:messageConsumerListIsLocked], 0
	jne messages_unsubscribe_all_by_task_done
	
	mov byte [cs:messageConsumerListIsLocked], 1
	
	push cs
	pop fs
	mov bx, msgConsumersListHeadPtr		; FS:BX := pointer to head
	mov cx, MESSAGE_CONSUMER_ENTRY_LENGTH
	; here, DX = task ID to search
	push dx								; [1] save task ID to search
	mov bp, sp							; SS:BP := ptr to task ID
messages_unsubscribe_all_by_task_loop:
	mov si, 37							; offset of owner in entry
	mov dx, word [ss:bp]				; [1] DX := task ID to search
	
	call llist_find_by_word				; DS:SI := ptr to element
										; DX := index of element
	cmp ax, 0
	je messages_unsubscribe_all_by_task_done	; nothing found
	
	mov al, byte [ds:si+39]
	and al, 3							; AL := owner type (from flags)
	cmp al, 1							; is it task-owned?
	jne messages_unsubscribe_all_by_task_loop	; no, next iteration
	; matched on owner ID and owner is task, so we unsubscribe
	call llist_remove_at_index			; remove at index DX
	cmp ax, 0
	jne messages_unsubscribe_all_by_task_loop
	; removal failed... fail completely now, to avoid an infinite loop
	call _messages_log_unable_to_remove_consumer
messages_unsubscribe_all_by_task_done:
	add sp, 2							; [1] clean up stack
	
	mov byte [cs:messageConsumerListIsLocked], 0
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret


; Used when a message consumer could not be added
;
; input
;		none
; output
;		none
_messages_log_unable_to_add_consumer:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, messagesWarnCannotAddConsumer
	call messages_publish_kernel_warning
	
	pop ds
	popa
	ret
	

; Writes a warning to the kernel log messages
;
; input
;	 DS:SI - string to write as a message
; output
;		none
messages_publish_kernel_warning:
	pusha
	push es
	
	mov ax, cs
	mov es, ax
	
	int 0A5h							; BX := string length
	inc bx								; include terminator
	mov cx, bx							; CX := message length
	mov di, messagesTypeKernelWarning
	call messages_publish
	
	pop es
	popa
	ret


; Used when a message consumer could not be unsubscribed
;
; input
;		none
; output
;		none
_messages_log_unable_to_remove_consumer:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, messagesWarnCannotRemoveConsumer
	call messages_publish_kernel_warning
	
	pop ds
	popa
	ret


; Prints a list of all consumers to the screen
;
; input
;		none
; output
;		none
_messages_debug_print_consumers:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	cmp byte [cs:messagesIsInitialized], 0
	je _messages_debug_print_consumers_done
	
	call debug_print_newline
	push cs
	pop ds
	mov si, messagesDebugConsumersHeading
	call debug_println_string
	
	push cs
	pop fs
	mov bx, msgConsumersListHeadPtr		; FS:BX := pointer to head
	call llist_get_head					; DS:SI := head
	cmp ax, 0
	je _messages_debug_print_consumers_done			; no consumers

	mov cx, MESSAGE_CONSUMER_ENTRY_LENGTH
_messages_debug_print_consumers_loop:
	; here, DS:SI = start of current consumer entry
	call debug_print_string						; print message type
	call debug_print_blank
	mov ax, word [ds:si+33]
	call debug_print_word
	call debug_print_blank
	mov ax, word [ds:si+35]
	call debug_print_word
	call debug_print_blank
	mov ax, word [ds:si+37]
	call debug_print_word
	call debug_print_blank
	mov al, byte [ds:si+39]
	call debug_print_byte
	call debug_print_blank
	
	call debug_print_newline
_messages_debug_print_consumers_loop_next:
	call llist_get_next					; DS:SI := next consumer
	cmp ax, 0
	jne _messages_debug_print_consumers_loop			; got one
	; we're out of consumers
_messages_debug_print_consumers_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	ret
