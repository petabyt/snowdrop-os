;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the memory manager, used to allocate memory.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

firstAllocatableSegment:	dw 0
LAST_ALLOCATABLE_SEGMENT:	equ 7000h ; 7FFFF (7000:FFFF) is the last address
									  ; guaranteed to be available in IBM PC
									  ; conventional memory

numAllocatableSegments:		dw 0	; word for convenience

kernelDynMemoryStartOffset:	dw KERNEL_DYN_MEMORY_START_OFFSET
kernelDynMemoryLength:		dw KERNEL_DYN_MEMORY_LENGTH

memoryInitializedMsg1:		db ' (', 0
memoryInitializedMsg2:		db 'h segs, ', 0
memoryInitializedMsg2p5:	db ':', 0
memoryInitializedMsg3:		db 'h dyn start, ', 0
memoryInitializedMsg4:		db 'h dyn length)', 13, 10, 0

memoryCannotCreateSegmentList:		db 'Fatal: cannot create segment list', 0
memoryCannotDeallocateSegment:		db 'Fatal: cannot deallocate - segment not found', 0
memoryCannotSetTaskOwner:			db 'Fatal: cannot set task owner on segment', 0

; list of available segments
LLIST_HEAD_PTR_LENGTH_2 equ LLIST_HEAD_PTR_LENGTH
LLIST_HEAD_PTR_INITIAL_2 equ LLIST_HEAD_PTR_INITIAL
segmentListHeadPtr:		times LLIST_HEAD_PTR_LENGTH_2 db LLIST_HEAD_PTR_INITIAL_2

; offset            what it stores
;    0-1            segment number
;    2-3             owner task ID
;    4-4                     flags
SEGMENT_ELEMENT_SIZE:		equ 5

SEGMENT_FLAGS_INITIAL_VALUE	equ 0

SEGMENT_FLAG_IN_USE			equ 1	; whether segment is currently allocated
SEGMENT_FLAG_HAS_OWNER_TASK	equ 2	; segments allocated before scheduler
									; starts are not owned by a task

segmentAddBuffer:			times SEGMENT_ELEMENT_SIZE db 0

; used when searching for segments
memorySegmentFound:					db 0
memorySegmentFoundPtrSeg:			dw 0
memorySegmentFoundPtrOff:			dw 0

memoryFreeByOwnerTaskId:			dw 0		; used when freeing
memoryMarkUnownedByOwnerTaskId:		dw 0		; used when marking unowned


; Lifetime of a memory segment
;
; There are a few cases that are handled by a combination of scheduler and
; memory manager:
;     1. Task allocates segment for own use. Segment is not needed after exit.
;     2. Task allocates segment and starts other task
;     3. Service ("keep memory" task) exits
;
; The above cases are handled via the following:
;
;   upon "add task", scheduler sets task as owner of segment in which it lives
;   upon "task exit", if task is not service
;                     then
;                     free all segments whose owner is the exiting task
;     
;   if scheduler has started
;   then
;        upon "allocate segment", memory manager sets current task as owner
;   else
;        do nothing (before scheduler starts it's the kernel allocating memory)
;

;
; A special case is when kernel allocates memory and then adds tasks. This
; is the case for the startup app, or services. In these cases, the scheduler
; has not yet started, so "add task" will not set the owner of the segments.
;
; 
;
; To ensure those are correctly deallocated, scheduler_task_exit will continue
; to deallocate the segment where the task lived.
; This is despite a "deallocation by owner" of all segments owned by an
; exiting task


; Initializes the memory manager
;
; input
;		AX - first allocatable segment
; output
;		none
memory_initialize:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov word [cs:firstAllocatableSegment], ax

	mov ax, LAST_ALLOCATABLE_SEGMENT
	sub ax, word [cs:firstAllocatableSegment]
	shr ax, 12							 ; AX := Zh (assuming max is < 16)
	inc ax								 ; first is actually usable
	mov word [cs:numAllocatableSegments], ax	; store it
	
	; initialize dynamic memory
	push word [cs:kernelWorkspaceSegment]
	pop ds
	mov si, word [cs:kernelDynMemoryStartOffset]	; DS:SI := start of memory
	mov ax, word [cs:kernelDynMemoryLength]
	call dynmem_initialize
	cmp ax, 0
	je crash
	
	push cs
	pop ds
	
	mov si, memoryInitializedMsg1
	call debug_print_string
	
	mov ax, word [cs:numAllocatableSegments]
	call debug_print_word
	mov si, memoryInitializedMsg2
	call debug_print_string
	
	mov ax, word [cs:kernelWorkspaceSegment]
	call debug_print_word
	mov si, memoryInitializedMsg2p5
	call debug_print_string
	mov ax, word [cs:kernelDynMemoryStartOffset]
	call debug_print_word
	mov si, memoryInitializedMsg3
	call debug_print_string
	
	mov ax, word [cs:kernelDynMemoryLength]
	call debug_print_word
	mov si, memoryInitializedMsg4
	call debug_print_string
	
	mov dx, word [cs:firstAllocatableSegment]
	call memory_create_segment_list
	
	pop ds
	popa
	ret
	
	
; Creates the list of segments used to manage segments
;
; input
;		DX - first allocatable segment
; output
;		none
memory_create_segment_list:
	pusha
	push ds
	push es
	push fs
	
	mov ax, cs

	mov fs, ax
	mov bx, segmentListHeadPtr			; FS:BX := ptr to ptr to head
	
	mov es, ax
	mov di, segmentAddBuffer			; ES:DI := ptr to buffer

	mov cx, SEGMENT_ELEMENT_SIZE		; element size
	
	; prepare buffer
	mov byte [cs:segmentAddBuffer+4], SEGMENT_FLAGS_INITIAL_VALUE
	
memory_create_segment_list_loop:
	; invariant: DX = current segment to add to list
	;            ES:DI = ptr to buffer used when adding segments to list
	cmp dx, LAST_ALLOCATABLE_SEGMENT
	ja memory_create_segment_list_done	; we're done

	mov word [es:di+0], dx				; store segment number in buffer
	call llist_add						; add buffer as new element
	cmp ax, 0

	mov si, memoryCannotCreateSegmentList	; in case we crash
	je crash_and_print
	
	add dx, 1000h						; next segment
	jmp memory_create_segment_list_loop
memory_create_segment_list_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	

; Sets the task owner of a segment
;
; input
;		BX - segment
;		AX - task ID
; output
;		none
memory_set_task_owner:
	pusha
	push ds
	
	mov dx, ax								; DX := task ID
	
	call memory_find_segment				; DS:SI := ptr to segment element
	cmp ax, 0
	jne memory_set_task_owner_found
	
	mov si, memoryCannotSetTaskOwner
	jmp crash_and_print
memory_set_task_owner_found:
	or byte [ds:si+4], SEGMENT_FLAG_HAS_OWNER_TASK
	mov word [ds:si+2], dx					; store owner
	
	pop ds
	popa
	ret
	
	
; Frees all segments owned by the specified task
;
; input
;		AX - task whose segments we are deallocating
; output
;		none
memory_free_by_owner:
	pusha
	push ds
	push es
	push fs

	mov word [cs:memoryFreeByOwnerTaskId], ax
	
	push cs
	pop ds
	mov si, memory_free_by_owner_callback		; DS:SI := ptr to callback
	mov cx, SEGMENT_ELEMENT_SIZE
	push cs
	pop fs
	mov bx, segmentListHeadPtr					; FS:BX := ptr to ptr to head
	call llist_foreach

	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Marks all segments owned by a task as unowned.
; Typically called to support the "keep memory" workflow, where a task
; wishes to keep its memory unaltered after it exits. (services, or anything
; that hooks an interrupt handler before exiting)
; This is to prevent their accidental deallocation when a task with the
; same ID is created and then exits.
;
; NOTE: As of version 25, there is no way for a segment - that is in use and
;       has become unowned via this function - to become free again
;
; input
;		AX - task whose segments we are deallocating
; output
;		none
memory_mark_unowned_by_owner:
	pusha
	push ds
	push es
	push fs

	mov word [cs:memoryMarkUnownedByOwnerTaskId], ax
	
	push cs
	pop ds
	mov si, memory_mark_unowned_by_owner_callback	; DS:SI := ptr to callback
	mov cx, SEGMENT_ELEMENT_SIZE
	push cs
	pop fs
	mov bx, segmentListHeadPtr					; FS:BX := ptr to ptr to head
	call llist_foreach

	pop fs
	pop es
	pop ds
	popa
	ret
	

; Allocates a 64kb memory segment for consumer to use
;
; input
;		none
; output
;		AX - 0 when allocation succeeded
;		BX - segment number of the newly allocated segment, when successful	
memory_allocate_segment:
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs
	
	mov byte [cs:memorySegmentFound], 0			; not yet found
	
	push cs
	pop ds
	mov si, memory_find_available_segment_callback	; DS:SI := ptr to callback
	mov cx, SEGMENT_ELEMENT_SIZE
	push cs
	pop fs
	mov bx, segmentListHeadPtr					; FS:BX := ptr to ptr to head
	call llist_foreach

	cmp byte [cs:memorySegmentFound], 0
	je memory_allocate_segment_fail
	jmp memory_allocate_segment_success
	
memory_allocate_segment_fail:
	mov ax, 1
	jmp memory_allocate_segment_return
memory_allocate_segment_success:
	mov ax, 0
	
	push word [cs:memorySegmentFoundPtrSeg]
	pop ds
	mov si, word [cs:memorySegmentFoundPtrOff]	; DS:SI := element of segment
	or byte [ds:si+4], SEGMENT_FLAG_IN_USE		; mark segment "in use"
	
	mov bx, word [ds:si+0]						; BX := segment
memory_allocate_segment_return:
	pop fs
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	ret

	
; Deallocates a segment
;
; NOTE: If this is ever changed to affect segment list structure
;       (e.g. deletion or addition of elements), callback used to
;       free many segments by owner has to change
;
; input
;		BX - segment to deallocate
; output
;		none
memory_free_segment:
	pusha
	push ds
	push es
	push fs

	call memory_find_segment				; DS:SI := ptr to segment element
	cmp ax, 0
	jne memory_free_segment_found
	
	mov si, memoryCannotDeallocateSegment
	jmp crash_and_print
memory_free_segment_found:
	; we found it
	; here, DS:SI = ptr to segment element to deallocate
	
	mov byte [ds:si+4], SEGMENT_FLAGS_INITIAL_VALUE	; reset flags to initial
	
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Returns a pointer to the segment list element representing the
; specified segment
;
; input
;		BX - segment number to search
; output
;		AX - 0 when element not found, other value otherwise
;	 DS:SI - pointer to segment element, when found
memory_find_segment:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	mov dx, bx							; DX := segment number to find
	
	mov ax, cs

	mov fs, ax
	mov bx, segmentListHeadPtr			; FS:BX := ptr to ptr to head

	mov cx, SEGMENT_ELEMENT_SIZE		; element size
	mov si, 0							; segment number is at offset 0
										; in each list element
	call llist_find_by_word				; DS:SI := ptr to element
	cmp ax, 0
	je memory_find_segment_fail
	jmp memory_find_segment_success
	
memory_find_segment_fail:
	mov ax, 0
	jmp memory_find_segment_done
memory_find_segment_success:
	mov ax, 1
memory_find_segment_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret
	
	
; Callback for finding an available segment
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
memory_find_available_segment_callback:
	test byte [ds:si+4], SEGMENT_FLAG_IN_USE
	jnz memory_find_available_segment_callback_done		; this one is in use
	; this one is not in use
	
	mov byte [cs:memorySegmentFound], 1
	mov word [cs:memorySegmentFoundPtrSeg], ds
	mov word [cs:memorySegmentFoundPtrOff], si			; store found segment
	mov ax, 0						; stop traversing
	retf
memory_find_available_segment_callback_done:	
	mov ax, 1						; keep traversing
	retf
	
	
; Callback for deallocating all segments owned by a task
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
memory_free_by_owner_callback:
	test byte [ds:si+4], SEGMENT_FLAG_IN_USE
	jz memory_free_by_owner_callback_done		; this one is not in use
	; this one is in use
	
	test byte [ds:si+4], SEGMENT_FLAG_HAS_OWNER_TASK
	jz memory_free_by_owner_callback_done		; not owned by task
	; it is owned by a task
	
	mov ax, word [cs:memoryFreeByOwnerTaskId]	; AX := owner ID
	cmp ax, word [ds:si+2]						; match?
	jne memory_free_by_owner_callback_done		; no
	
	; match, so free it
	mov bx, word [ds:si+0]						; BX := segment
	call memory_free_segment
	
memory_free_by_owner_callback_done:	
	mov ax, 1						; keep traversing
	retf
	

; Callback for marking all segments owned by a task as unowned
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
memory_mark_unowned_by_owner_callback:
	test byte [ds:si+4], SEGMENT_FLAG_IN_USE
	jz memory_mark_unowned_by_owner_callback_done		; this one is not in use
	; this one is in use
	
	test byte [ds:si+4], SEGMENT_FLAG_HAS_OWNER_TASK
	jz memory_mark_unowned_by_owner_callback_done		; not owned by task
	; it is owned by a task
	
	mov ax, word [cs:memoryMarkUnownedByOwnerTaskId]	; AX := owner ID
	cmp ax, word [ds:si+2]								; match?
	jne memory_mark_unowned_by_owner_callback_done		; no
	
	; match, so mark it unowned
	mov al, SEGMENT_FLAG_HAS_OWNER_TASK
	xor al, 0FFh
	and byte [ds:si+4], al
	
memory_mark_unowned_by_owner_callback_done:	
	mov ax, 1						; keep traversing
	retf
	