;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains part of the memory manager, specifically the dynamic memory
; routines used by the kernel.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


%ifndef _DYNAMIC_MEMORY_
%define _DYNAMIC_MEMORY_


DYNMEM_NONE 			equ 0FFFFh	; word value which marks a slot as empty
									; if this value is changed, inspect
									; array clear function
DYNMEM_ARRAY_ENTRY_SIZE_BYTES	equ 12
DYNMEM_ARRAY_LENGTH 			equ 256
DYNMEM_ARRAY_TOTAL_SIZE_BYTES equ DYNMEM_ARRAY_LENGTH*DYNMEM_ARRAY_ENTRY_SIZE_BYTES ; in bytes

dynmemAllocatableSegment:		dw 0
dynmemAllocatableStartOffset:	dw 0
dynmemAllocatableSize:			dw 0
dynmemInitialized:				db 0

; structure info (per array entry)
; bytes
;     0-1 id
;     2-3 allocated address segment
;     4-5 allocated address offset
;     6-7 allocated amount in bytes
;    8-11 unused

; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
dynmemStorage: times DYNMEM_ARRAY_TOTAL_SIZE_BYTES db 0
db 0		; this simplifies certain bounds checks


; Initializes the memory module
;
; input:
;	 DS:SI - pointer to beginning of allocatable memory
;		AX - size of allocatable memory
; output:
;		AX - 0 when initialization failed, other value otherwise
dynmem_initialize:
	cmp byte [cs:dynmemInitialized], 0
	jne dynmem_initialize_fail			; can't reinitialize
	
	cmp ax, 0
	je dynmem_initialize_fail			; size must be non-zero
	
	mov word [cs:dynmemAllocatableSegment], ds
	mov word [cs:dynmemAllocatableStartOffset], si
	mov word [cs:dynmemAllocatableSize], ax
	
	add ax, si
	jc dynmem_initialize_fail			; requested size overflows 
										; segment boundary
										
	call dynmem__clear
	
	mov byte [cs:dynmemInitialized], 1
	mov ax, 1
	jmp dynmem_initialize_done
dynmem_initialize_fail:
	mov ax, 0
dynmem_initialize_done:
	ret

	
; Returns whether dynamic memory is initialized
;
; input:
;		none
; output:
;		AX - 0 when dynamic memory not initialized, other value otherwise
dynmem_is_initialized:
	mov ah, 0
	mov al, byte [cs:dynmemInitialized]
	ret
	

; Deallocates a pointer.
; NOOP when there's no match to allocated pointers.
;
; input:
;	 DS:SI - pointer to deallocate
; output:
;		AX - 0 when the entry was not found, other value otherwise
;		CX - deallocated byte count, when entry was found
dynmem_deallocate:
	pushf
	push bx
	push dx
	push si
	push di
	push ds
	push es
	
	cmp byte [cs:dynmemInitialized], 0
	je dynmem_deallocate_failed

	call dynmem__get_offset_by_address			; BX := entry offset
	cmp ax, 0
	je dynmem_deallocate_failed					; NOOP when not found
	
	mov word [cs:dynmemStorage+bx], DYNMEM_NONE	; clear entry
	mov cx, word [cs:dynmemStorage+bx+6]		; CX := byte count
	
	push cx										; [1] save byte count
	
	push word [cs:dynmemStorage+bx+2]
	pop es
	mov di, word [cs:dynmemStorage+bx+4]		; ES:DI := pointer to chunk
	mov al, 'H'									; fill chunk with bogus
	cld
	rep stosb									; fill it
	
	pop cx										; [1] restore byte count
	
	mov ax, 1									; success
	jmp dynmem_deallocate_done
	
dynmem_deallocate_failed:
	mov ax, 0
dynmem_deallocate_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop bx
	popf
	ret

	
; Allocates a chunk of memory
;
; input:
;		AX - size in bytes to allocate
; output:
;		AX - 0 when memory could not be allocated, other value otherwise
;	 DS:SI - pointer to newly allocated memory, when successful
dynmem_allocate:
	pushf
	push bx
	push cx
	push dx
	push di
	push es

	cmp byte [cs:dynmemInitialized], 0
	je dynmem_allocate_error
	
	cmp ax, 0						; NOOP when zero bytes were requested
	je dynmem_allocate_error

	mov cx, ax						; CX := requested chunk size
	
	call dynmem__find_empty_slot	; BX := offset
									; CARRY=0 when slot was found
	jc dynmem_allocate_error
	; we found a slot, now check whether a large enough chunk of memory
	; exists

	add bx, dynmemStorage			; BX := slot offset
	call dynmem__find_free_chunk	; DS:SI := pointer to suitable chunk
	cmp ax, 0
	je dynmem_allocate_error
	
	mov word [cs:bx+0], 0			; id
	mov word [cs:bx+2], ds			; chunk segment
	mov word [cs:bx+4], si			; chunk offset
	mov word [cs:bx+6], cx			; chunk size
	
	push cx							; [1] save chunk size
	push ds
	pop es
	mov di, si						; ES:DI := pointer to chunk
	mov al, 'A'						; fill chunk with bogus
	cld
	rep stosb						; fill it
	pop cx							; [1] restore chunk size
	
	mov ax, 1						; success
	jmp dynmem_allocate_done
dynmem_allocate_error:
	mov ax, 0
dynmem_allocate_done:
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	popf
	ret
	
	
; Reallocates a chunk of memory, with the possibility to grow or
; shrink the already allocated chunk.
; NOTE: when the new size is equal to the current size, the chunk is
;       forced to move
;
; input:
;	 DS:SI - pointer to memory to reallocate
;		AX - new size
; output:
;		AX - 0 when memory could not be reallocated, other value otherwise
;	 DS:SI - pointer to newly reallocated memory, when successful
dynmem_reallocate:
	push bx
	push cx
	push dx
	push di
	push es
	pushf

	cmp ax, 0
	je dynmem_reallocate_fail		; cannot reallocate to zero size
	mov dx, ax								; DX := requested size
	
	call dynmem__get_offset_by_address			; BX := entry offset
	cmp ax, 0
	je dynmem_reallocate_fail		; NOOP when not found

	cmp dx, word [cs:dynmemStorage+bx+6]		; how much was requested?
	jae dynmem_reallocate_more_or_eq	; more than is currently allocated
			; NOTE: We also attempt to move when the size doesn't change
			;       The reason for this is to allow an attempt at compacting
			;       the memory by simply calling realloc with the same size
			;       This is acceptable because there is no other reason why
			;       somebody would call realloc with the same size
	; less than what is currently allocated
dynmem_reallocate_less:
	; simply resize chunk in-place
	mov word [cs:dynmemStorage+bx+6], dx
	jmp dynmem_reallocate_success
	
dynmem_reallocate_more_or_eq:
	; we are reallocating to a larger size than current size
	; here, DS:SI = input pointer
	;       DX = requested size, guaranteed more or equal to current size
	mov cx, word [cs:dynmemStorage+bx+6]		; CX := current size
	cmp cx, dx
	je dynmem_reallocate_move_adjust_regs	; move if newsize = size
	
	push si
	add si, cx								; DS:SI := pointer to after chunk
	pushf									; save CARRY
	call dynmem__measure_gap_after				; AX := length of gap after chunk
	popf									; restore CARRY
	pop si
	jc dynmem_reallocate_fail		; we wrapped around after FFFF?

	sub dx, cx								; [1] DX := size difference
	cmp ax, dx								; is gap after chunk large enough?
	jae dynmem_reallocate_more_grow_in_place	; yes, so grow in place
	jmp dynmem_reallocate_more_move_chunk

dynmem_reallocate_move_adjust_regs:
	sub dx, cx								; [1] DX := size difference
	
dynmem_reallocate_more_move_chunk:
	; here, CX = current size
	add dx, cx								; [1] DX := requested size

	push ds
	push si									; save original chunk
	
	mov ax, dx								; AX := new size
	call dynmem_allocate				; DS:SI := new chunk

	push ds
	pop es
	mov di, si								; ES:DI := new chunk
	
	pop si
	pop ds									; DS:SI := original chunk

	cmp ax, 0								; could not allocate new chunk?
	je dynmem_reallocate_more_move_chunk_failed_alloc_check_equal
	
	push di									; [1] save new chunk near pointer
	push si									; [2] save original chunk
	cld
	rep movsb								; copy original chunk to new chunk
	pop si									; [2] DS:SI := original chunk
	call dynmem_deallocate			; deallocate original chunk

	pop si									; [1]
	push es
	pop ds									; DS:SI := pointer to new chunk
	jmp dynmem_reallocate_success	; we're done
	
dynmem_reallocate_more_move_chunk_failed_alloc_check_equal:
	cmp cx, dx								
	je dynmem_reallocate_success		; we failed alloc, but requested
											; size is equal to size, so NOOP
											; and success
	jmp dynmem_reallocate_fail		; ... otherwise fail
	
dynmem_reallocate_more_grow_in_place:
	; here, DX = size difference
	add word [cs:dynmemStorage+bx+6], dx		; grow in place
	jmp dynmem_reallocate_success
	
dynmem_reallocate_fail:
	mov ax, 0
	jmp dynmem_reallocate_done
dynmem_reallocate_success:
	mov ax, 1
dynmem_reallocate_done:
	popf
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	

; Clears array by setting all elements to "empty"
;
; input:
;		none
; output:
;		none
dynmem__clear:
	pusha
	pushf
	push es
	
	push cs
	pop es
	
	mov cx, DYNMEM_ARRAY_TOTAL_SIZE_BYTES / 2
			; can never overrun array, and since each element is at least
			; 2 bytes long, it's either event (2 bytes per element), or
			; misses third or later byte in the last element (which is
			; still marked as "empty")
										
	mov di, dynmemStorage	; ES:DI := pointer to array
	mov ax, DYNMEM_NONE				; mark each array element as "empty"
	cld
	rep stosw
	
	pop es
	popf
	popa
	ret


; Returns a byte offset of first empty slot in the array
;
; input:
;		none
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - byte offset (into array) of first empty slot, if one was found
dynmem__find_empty_slot:
	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov bx, 0				; offset of array slot being checked
dynmem__find_empty_slot_loop:
	cmp word [cs:dynmemStorage+bx], DYNMEM_NONE		; is this slot empty?
										; (are first two bytes DYNMEM_NONE?)
	je dynmem__find_empty_slot_done		; yes
	
	add bx, DYNMEM_ARRAY_ENTRY_SIZE_BYTES		; next slot
	cmp bx, DYNMEM_ARRAY_TOTAL_SIZE_BYTES		; are we past the end?
	jb dynmem__find_empty_slot_loop		; no
dynmem__find_empty_slot_full:				; yes
	stc										; set CARRY to indicate failure
	jmp dynmem__find_empty_slot_done
dynmem__find_empty_slot_done:
	ret
	
	
; Returns the offset of an entry, by its memory address
;
; input:
;	 DS:SI - pointer to memory
; output:
;		AX - 0 when not found, other value otherwise
;		BX - offset of entry, when found
dynmem__get_offset_by_address:
	push cx
	push dx
	push si
	push di

	mov ax, si		; we'll keep pointer offset in AX throughout this function
	mov cx, ds		; and pointer segment in CX
	
	mov si, dynmemStorage
	mov bx, 0				; offset of array slot being checked
dynmem__get_offset_by_address_loop:
	cmp word [cs:si+bx], DYNMEM_NONE		; is this slot empty?
										; (are first two bytes DYNMEM_NONE?)
	je dynmem__get_offset_by_address_next			; yes
	; this array element is not empty, so perform action on it
	
	;-------------- ACTION CODE GOES HERE --------------
	cmp word [cs:si+bx+2], cx				; match on entry's segment?
	jne dynmem__get_offset_by_address_next		; no
	cmp word [cs:si+bx+4], ax				; match on entry's offset?
	je dynmem__get_offset_by_address_found		; yes
	;----------------- END ACTION CODE -----------------
	
dynmem__get_offset_by_address_next:
	add bx, DYNMEM_ARRAY_ENTRY_SIZE_BYTES	; next slot
	cmp bx, DYNMEM_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb dynmem__get_offset_by_address_loop			; no
	; yes, so not found
dynmem__get_offset_by_address_not_found:
	mov ax, 0
	jmp dynmem__get_offset_by_address_done
dynmem__get_offset_by_address_found:
	mov ax, 1

dynmem__get_offset_by_address_done:
	pop di
	pop si
	pop dx
	pop cx
	ret

	
; Finds the smallest available chunk that's at least as large as the input
;
; input:
;		CX - minimum chunk size
; output:
;		AX - 0 when a suitable chunk was not found, other value otherwise
;	 DS:SI - pointer to chunk
dynmem__find_free_chunk:
	; we now search for the end of a chunk that's already allocated, such that
	; the free chunk immediately after is:
	;     - large enough to satisfy the input
	;     - smallest free chunk
	push bx
	push cx
	push dx
	push di
	push es

	mov ax, word [cs:dynmemAllocatableSegment]
	mov ds, ax
	mov si, word [cs:dynmemAllocatableStartOffset]
							; DS:SI := beginning of allocatable memory
	; check gap at beginning of allocatable memory
	mov di, 0			; "no suitable gap found yet"
	call dynmem__measure_gap_after
	cmp ax, cx								; is it suitable?
	jb dynmem__find_free_chunk_loop__start		; no
	; yes, so store it
	mov di, 1			; "we have a gap"
	mov dx, ax			; DX := size of gap at beginning of allocatable memory
	; here, DS:SI = beginning of allocatable memory
	
dynmem__find_free_chunk_loop__start:	
	; invariant through loop:
	;     DX = current smallest gap that's not smaller than input minimum size
	;  DS:SI = pointer to first byte of gap relevant to value in DX
	;     DI = 0 when no suitable gap was found yet, other value otherwise
	;     CX = requested minimum chunk size
	
	mov bx, 0				; offset of array slot being checked
dynmem__find_free_chunk_loop:
	cmp word [cs:dynmemStorage+bx], DYNMEM_NONE		; is this slot empty?
										; (are first two bytes DYNMEM_NONE?)
	je dynmem__find_free_chunk_next			; yes
	; this array element is not empty, so perform action on it
	;-------------- ACTION CODE GOES HERE --------------
	push ds
	push si								; save most suitable gap
	
	push word [cs:dynmemStorage+bx+2]
	pop ds
	mov si, word [cs:dynmemStorage+bx+4]
	add si, word [cs:dynmemStorage+bx+6]	; DS:SI := first byte after this chunk
	jc dynmem__find_free_chunk_next__pop	; we wrapped around after FFFFh
	call dynmem__measure_gap_after			; AX := gap length
	cmp ax, cx							; is it suitable?
	jb dynmem__find_free_chunk_next__pop	; no
	; it's suitable
	cmp di, 0							; is it the first suitable chunk?
	je dynmem__find_free_chunk_store		; yes, so store it
	; no, so check if it's more suitable than currently most suitable
	cmp ax, dx							; is it suitable and smaller than 
										; currently most suitable?
	jae dynmem__find_free_chunk_next__pop	; no, so we ignore it
	; yes, so store it
dynmem__find_free_chunk_store:
	mov di, 1							; "we have a gap"
	add sp, 4							; remove most suitable gap from stack
	mov dx, ax							; store new most suitable gap length
	jmp dynmem__find_free_chunk_next		; check next chunk
dynmem__find_free_chunk_next__pop:	
	pop si
	pop ds								; restore most suitable gap
	;----------------- END ACTION CODE -----------------
dynmem__find_free_chunk_next:
	add bx, DYNMEM_ARRAY_ENTRY_SIZE_BYTES	; next slot
	cmp bx, DYNMEM_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb dynmem__find_free_chunk_loop		; no
	; we're past the end
	
	mov ax, 1							; assume success
	cmp di, 0							; any suitable chunk found?
	jne dynmem__find_free_chunk_done		; yes
	mov ax, 0							; no, so it's a failure
dynmem__find_free_chunk_done:
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Measures the "gap" starting from an initial location (inclusive).
; The "gap" length represents the byte count from the initial location
; to either:
;     - the already allocated chunk that is closest to gap start
;     - end of the available allocatable memory
;
; input:
;	 DS:SI - pointer to first potential byte of gap
; output:
;		AX - 0 when a suitable gap was not found, gap length otherwise
dynmem__measure_gap_after:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es

	mov ax, ds
	cmp ax, word [cs:dynmemAllocatableSegment]
	jne dynmem__measure_gap_not_found			; limit by segment
	
	mov ax, word [cs:dynmemAllocatableStartOffset]
	add ax, word [cs:dynmemAllocatableSize]
									; AX := offset after allocatable end
	cmp si, ax
	jae dynmem__measure_gap_not_found	; gap start is past allocatable end

	; from here on, DX will contain the current minimum gap length
	; at the end of all iterations, it will contain the true gap length
	; from the specified gap start until the next allocated chunk, or 
	; allocatable end
	mov dx, ax						; DX := offset after allocatable end
	sub dx, si						; DX := gap length assuming gap runs
									;       to allocatable end
	; DX now contains the largest possible gap, so it's suitable to store
	; current minima
	
	mov bx, 0				; offset of array slot being checked
dynmem__measure_gap_after_loop:
	cmp word [cs:dynmemStorage+bx], DYNMEM_NONE		; is this slot empty?
										; (are first two bytes DYNMEM_NONE?)
	je dynmem__measure_gap_after_next			; yes
	; this array element is not empty, so perform action on it
	;-------------- ACTION CODE GOES HERE --------------
	mov ax, ds
	cmp word [cs:dynmemStorage+bx+2], ax			; match on entry's segment?
	jne dynmem__measure_gap_after_next		; no
	cmp word [cs:dynmemStorage+bx+4], si			; does this chunk start before gap?
	jb dynmem__measure_gap_after_next		; yes
	; chunk starts at gap or after
	mov ax, word [cs:dynmemStorage+bx+4]			; AX := chunk start
	sub ax, si							; AX := gap length to this chunk
	; AX can't underflow due to check above
	
	cmp ax, dx							; is this length the new minimum?
	jae dynmem__measure_gap_after_next		; no
	mov dx, ax							; yes, so we store it
	
	;----------------- END ACTION CODE -----------------
dynmem__measure_gap_after_next:
	add bx, DYNMEM_ARRAY_ENTRY_SIZE_BYTES	; next slot
	cmp bx, DYNMEM_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb dynmem__measure_gap_after_loop		; no
	; we are, so we're done
	mov ax, dx							; AX := gap length
	jmp dynmem__measure_gap_after_done
dynmem__measure_gap_not_found:
	mov ax, 0
dynmem__measure_gap_after_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	

%endif
