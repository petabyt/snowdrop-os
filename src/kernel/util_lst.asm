;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains a library for working with linked lists
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; The consumer declares a listHeadPtr as shown below. It holds exclusively
; overhead bytes, to point at the real list head, and indicate whether the
; head exists or not.
; By declaring multiple head pointers, a consumer application can
; create and operate on multiple linked lists.
; The consumer application is expected to not modify these bytes.
;
;     listHeadPtr:	times LLIST_HEAD_PTR_LENGTH db LLIST_HEAD_PTR_INITIAL
;
; Since %includes are often at the end of the file (because the initial jmp
; cannot be too long), in NASM I tend to define for example:
;     LLIST_HEAD_PTR_LENGTH_2 equ LLIST_HEAD_PTR_LENGTH
;     LLIST_HEAD_PTR_INITIAL_2 equ LLIST_HEAD_PTR_INITIAL
; to get over the "non-constant supplied to times" error.
; Then I define listHeadPtr based on those instead.
;
; Whenever linked list functions are invoked, the consumer application provides
; a pointer to a pointer to the list head like so:
; 
;     push cs
;     pop fs
;     mov bx, listHeadPtr				; FS:BX := pointer to pointer to head
;
; Also, the size (in bytes) of an element must be passed in like so:
;
;     mov cx, ELEMENT_SIZE				; size of a list element, in bytes
;										; consumers applications are expected
;										; to not access any of an element's
;										; bytes past this count
; And then:
;
;     call llist_...
;
; Internally, the list adds a few bytes after each record, for 
; management purposes:
; 
; offset past last consumer byte            what it stores
;                            0-1      next element segment
;                            2-3       next element offset
;                            4-4                     flags
;
; NOTE: the pointer to pointer to head that consumer applications must include
;       statically contains just the chunk of overhead bytes that are added
;       at the end of every linked list element


LLIST_HEAD_PTR_LENGTH	equ CLLIST_OVERHEAD_BYTES
LLIST_HEAD_PTR_INITIAL	equ 0

CLLIST_MAX_ELEMENT_SIZE		equ 20000		; in bytes

CLLIST_OVERHEAD_BYTES		equ 5			; this many bytes are added
											; to each list element
CLLIST_FLAG_HAS_NEXT		equ 1

llistNoMemory:	db 'FATAL: Must initialize dynamic memory module before using linked list functionality.'
				db 13, 10
				db 'Press a key to exit', 0

cllistCallbackReturnAx:	dw 0		; used to check callback return values
							

; Finds the first list element whose word at the specified offset has the
; specified value
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
;		DX - offset within element of word to check
;	 DS:SI - pointer to string to search
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
;		DX - index of element, when found
llist_find_by_string:
	push es
	push fs
	push bx
	push cx
	push di

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_find_by_string_fail
	
	push bx									; [1] save input
	
	int 0A5h								; BX := search string length
	inc bx									; BX := search string length
											; including terminator
	
	mov di, dx								; DI := search offset
	add di, bx								; DI := offset right after
											; search stir
	pop bx									; [1] restore input
	cmp di, cx								; would it overflow payload?
	ja llist_find_by_string_fail		; yes, so we fail
	; no, it can fit within the payload

	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_find_by_string_fail			; no, the list is empty

	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]					; ES:DI := pointer to head

	mov bx, cx								; BX := element size
	mov cx, 0								; curent index
llist_find_by_string_loop:
	; here, ES:DI = pointer to current element
	push di									; [2]
	add di, dx								; ES:DI := pointer to searched
	int 0BDh								; compare to input string
	cmp ax, 0								; match?
	pop di									; [2]
	je llist_find_by_string_success	; yes

llist_find_by_string_loop_next:
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz llist_find_by_string_fail				; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element

	inc cx								; currentIndex++
	jmp llist_find_by_string_loop	; loop again

llist_find_by_string_fail:
	mov ax, 0
	jmp llist_find_by_string_done
llist_find_by_string_success:
	push es
	pop ds
	mov si, di								; return in DS:SI
	mov dx, cx								; return index in DX
	mov ax, 1
llist_find_by_string_done:
	pop di
	pop cx
	pop bx
	pop fs
	pop es
	ret
	
	
; Finds the first list element whose word at the specified offset has the
; specified value
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
;		SI - offset within element of word to check
;		DX - word to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
;		DX - index of element, when found
llist_find_by_word:
	push es
	push fs
	push bx
	push cx
	push di

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_find_by_word_fail
	
	mov di, si									; DI := search offset
	add di, 2									; DI := offset right after word
	cmp di, cx									; would it overflow payload?
	ja llist_find_by_word_fail			; yes, so we fail
	; no, it can fit within the payload
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_find_by_word_fail			; no, the list is empty

	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]					; ES:DI := pointer to head

	mov bx, cx								; BX := element size
	mov cx, 0								; curent index
llist_find_by_word_loop:
	push di									; [1]
	add di, si								; ES:DI := pointer to searched
	cmp word [es:di], dx					; match?
	pop di									; [1]
	je llist_find_by_word_success	; yes

llist_find_by_word_loop_next:
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz llist_find_by_word_fail				; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element

	inc cx								; currentIndex++
	jmp llist_find_by_word_loop	; loop again

llist_find_by_word_fail:
	mov ax, 0
	jmp llist_find_by_word_done
llist_find_by_word_success:
	push es
	pop ds
	mov si, di								; return in DS:SI
	mov dx, cx								; return index in DX
	mov ax, 1
llist_find_by_word_done:
	pop di
	pop cx
	pop bx
	pop fs
	pop es
	ret
	

; Finds the first list element whose byte at the specified offset has the
; specified value
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
;		SI - offset within element of byte to check
;		DL - byte to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
;		DX - index of element, when found
llist_find_by_byte:
	push es
	push fs
	push bx
	push cx
	push di

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_find_by_byte_fail
	
	mov di, si									; DI := search offset
	add di, 1									; DI := offset right after byte
	cmp di, cx									; would it overflow payload?
	ja llist_find_by_byte_fail			; yes, so we fail
	; no, it can fit within the payload
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_find_by_byte_fail			; no, the list is empty

	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]					; ES:DI := pointer to head

	mov bx, cx								; BX := element size
	mov cx, 0								; curent index
llist_find_by_byte_loop:
	push di									; [1]
	add di, si								; ES:DI := pointer to searched
	cmp byte [es:di], dl					; match?
	pop di									; [1]
	je llist_find_by_byte_success	; yes

llist_find_by_byte_loop_next:
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz llist_find_by_byte_fail				; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element

	inc cx								; currentIndex++
	jmp llist_find_by_byte_loop	; loop again

llist_find_by_byte_fail:
	mov ax, 0
	jmp llist_find_by_byte_done
llist_find_by_byte_success:
	push es
	pop ds
	mov si, di								; return in DS:SI
	mov dx, cx								; return index in DX
	mov ax, 1
llist_find_by_byte_done:
	pop di
	pop cx
	pop bx
	pop fs
	pop es
	ret
	
	
; Gets the index of the specified element
;
; input:
;	 FS:BX - pointer to pointer to list head
;	 DS:SI - pointer to element
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;		DX - index, when successful
llist_get_index:
	push ds
	push es
	push fs
	push bx
	push cx
	push si
	push di
	
	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_get_index_fail
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_get_index_fail			; no, the list is empty
	
	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]				; ES:DI := pointer to head
	
	mov dx, 0							; current index
	mov bx, cx							; BX := element size

llist_get_index_loop:
	mov ax, ds
	mov cx, es
	cmp cx, ax								; match on segment?
	jne llist_get_index_loop_next	; no
	cmp si, di								; match on offset?
	je llist_get_index_success		; yes

llist_get_index_loop_next:
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz llist_get_index_fail				; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element

	inc dx								; currentIndex++
	jmp llist_get_index_loop	; loop again

llist_get_index_fail:
	mov ax, 0
	jmp llist_get_index_done
llist_get_index_success:
	mov ax, 1
llist_get_index_done:
	pop di
	pop si
	pop cx
	pop bx
	pop fs
	pop es
	pop ds
	ret
	

; Removes an element from the list, at the specified index
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
;		DX - index of element to remove
; output:
;		AX - 0 when an error occurred, other value otherwise
llist_remove_at_index:
	push ds
	push es
	push fs
	push bx
	push cx
	push dx
	push si
	push di
	
	call llist_get_at_index				; DS:SI := element at index
	cmp ax, 0
	je llist_remove_at_index_fail
	
	call llist_remove
	cmp ax, 0
	je llist_remove_at_index_fail
	
	jmp llist_remove_at_index_success
	
llist_remove_at_index_fail:
	mov ax, 0
	jmp llist_remove_at_index_done
llist_remove_at_index_success:
	mov ax, 1
llist_remove_at_index_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop fs
	pop es
	pop ds
	ret


; Adds an element at the specified index
;
; input:
;	 FS:BX - pointer to pointer to list head
;	 ES:DI - pointer to payload to add as a new element
;		CX - element length, in bytes, maximum 20,000 bytes
;		DX - index
; output:
;		AX - 0 when index is out of range, other value otherwise
;	 DS:SI - pointer to element in the list, when successful
llist_add_at_index:
	push bx
	push cx
	push dx
	push di
	push es
	push fs

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_add_at_index_fail
	
	cmp dx, 0
	jne llist_add_at_index__not_head
	
llist_add_at_index__head:
	; CASE 1: we're inserting into the head position
	call llist_add_head					; DS:SI := new element
	cmp ax, 0
	je llist_add_at_index_fail
	
	jmp llist_add_at_index_success
	
llist_add_at_index__not_head:
	; CASE 2: we're trying to insert not in the head position
	dec dx										; DX := index before insertion
	call llist_get_at_index				; DS:SI := element before
												; insertion point
	cmp ax, 0
	je llist_add_at_index_fail
	
	call llist_add_after					; insert it
	cmp ax, 0
	je llist_add_at_index_fail
	
	jmp llist_add_at_index_success
	
llist_add_at_index_fail:
	mov ax, 0
	jmp llist_add_at_index_done
llist_add_at_index_success:
	mov ax, 1
llist_add_at_index_done:
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Returns whether the list has any elements or not
;
; input:
;	 FS:BX - pointer to pointer to list head
; output:
;		AX - 0 when list
llist_has_any:
	pusha
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_has_any_no					; no, it's empty

llist_has_any_yes:
	popa
	mov ax, 1
	ret
llist_has_any_no:
	popa
	mov ax, 0
	ret
	
	
; Gets the element at the specified index
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
;		DX - index
; output:
;		AX - 0 when list does not contain that element, other value otherwise
;	 DS:SI - pointer to element in the list, when successful
llist_get_at_index:
	push bx
	push cx
	push dx
	push di
	push es
	push fs

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_get_at_index_fail
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_get_at_index_fail			; no, so we're done
	
	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]				; ES:DI := pointer to head
	
	mov bx, cx							; BX := element size

llist_get_at_index_loop:
	cmp dx, 0							; is this is the index we need?
	je llist_get_at_index_success

	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz llist_get_at_index_fail				; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element

	dec dx								; remainingIndex--
	jmp llist_get_at_index_loop	; loop again
	
llist_get_at_index_fail:
	mov ax, 0
	jmp llist_get_at_index_done
llist_get_at_index_success:
	push es
	pop ds
	mov si, di							; DS:SI := pointer to current
	mov ax, 1
llist_get_at_index_done:
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Adds a new head element to the list.
; If the list was non-empty, the existing head element becomes
; second in the list.
;
; input:
;	 FS:BX - pointer to pointer to list head
;	 ES:DI - pointer to payload to add as a new element
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to element in the list, when successful
llist_add_head:
	pushf
	push fs
	push es
	push bx
	push cx
	push dx
	push di

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_add_head_fail
	
	mov ax, cx
	add ax, CLLIST_OVERHEAD_BYTES
	call dynmem_allocate			; DS:SI := pointer to list element
	cmp ax, 0
	je llist_add_head_fail
	push cx								; [2] save input element size
	
	push ds
	push si								; [1] save pointer to new list element
	
	xchg si, di
	push ds
	push es
	pop ds								; DS:SI := pointer to input element
	pop es								; ES:DI := pointer to list element
	; here, CX = total list element size (input element size)
	cld
	rep movsb							; copy input element into list element

	pop si
	pop ds								; [1] DS:SI := new list element
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_add_head__empty			; no, the list is empty
	
llist_add_head__already_has:
	; CASE 1: already has a head
	; here, FS:BX = pointer to pointer to list head
	; here, DS:SI = new list element
	
	pop cx								; [2] CX := element size
	add si, cx							; DS:SI := overhead bytes of new head
	
	mov ax, word [fs:bx+0]
	mov word [ds:si+0], ax
	mov ax, word [fs:bx+2]
	mov word [ds:si+2], ax				; head.next := oldHead
	mov byte [ds:si+4], 0
	or byte [ds:si+4], CLLIST_FLAG_HAS_NEXT	; "new head has next"
	
	sub si, cx							; DS:SI := new head
	mov word [fs:bx+0], ds
	mov word [fs:bx+2], si				; point to new head
	
	jmp llist_add_head_success
	
llist_add_head__empty:
	; CASE 2: list is empty
	; here, FS:BX = pointer to pointer to list head
	; here, DS:SI = new list element
	
	mov word [fs:bx+0], ds
	mov word [fs:bx+2], si				; point to new head
	mov byte [fs:bx+4], 0
	or byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT		; "we have a head"
	
	pop bx								; [2] BX := element size
	
	mov al, CLLIST_FLAG_HAS_NEXT
	xor al, 0FFh
	and byte [ds:si+bx+4], al			; head.next := null
	
	jmp llist_add_head_success
	
llist_add_head_fail:
	mov ax, 0
	jmp llist_add_head_done
llist_add_head_success:
	mov ax, 1
llist_add_head_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop es
	pop fs
	popf
	ret
	
	
; Gets the number of elements in the list
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - count of elements in the list
llist_count:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs
	
	mov dx, 0							; accumulates count
	
	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_count_done
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_count_done					; no, so we're done
	
	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]				; ES:DI := pointer to head
	
	mov bx, cx							; BX := element size

llist_count_loop:
	inc dx								; accumulate

	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz llist_count_done			; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element

	jmp llist_count_loop			; loop again
	
llist_count_done:
	mov ax, dx							; return count in AX
	
	pop fs
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Removes all elements from the list
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		none
llist_clear:
	pusha
	push ds
	push es
	push fs
	
	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_clear_done

llist_clear_loop:	
	call llist_get_head				; DS:SI - pointer to head
	cmp ax, 0
	je llist_clear_done
	
	call llist_remove
	jmp llist_clear_loop
	
llist_clear_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Removes an element from the list
;
; input:
;	 FS:BX - pointer to pointer to list head
;	 DS:SI - pointer to element to remove
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
llist_remove:
	push ds
	push es
	push fs
	push bx
	push cx
	push dx
	push si
	push di

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_remove_fail
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_remove_fail			; no, the list is empty

	mov di, si
	add di, cx							; DS:DI := ptr to overhead bytes
	
	mov ax, ds
	cmp word [fs:bx+0], ax				; segment match?
	jne llist_remove__middle		; no
	cmp word [fs:bx+2], si				; offset match?
	jne llist_remove__middle		; no
llist_remove__head:
	; here, DS:SI = pointer to element to delete
	; here, DS:DI = pointer to overhead bytes of element to delete
	
	test byte [ds:di+4], CLLIST_FLAG_HAS_NEXT	; does head have a next?
	jz llist_remove__head_then_empty		; no, just get rid of it
	
llist_remove__head_then_remaining:
	; CASE 1: head removed, list will still have elements
	mov ax, word [ds:di+0]
	mov word [fs:bx+0], ax
	mov ax, word [ds:di+2]
	mov word [fs:bx+2], ax				; head := head.next
	call dynmem_deallocate		; free memory used by element
	jmp llist_remove_success

llist_remove__head_then_empty:
	; CASE 2: head removed, list becomes empty
	mov al, CLLIST_FLAG_HAS_NEXT
	xor al, 0FFh
	and byte [fs:bx+4], al				; we don't have a head anymore
	call dynmem_deallocate		; free memory used by element
	jmp llist_remove_success

llist_remove__middle:
	; here, DS:SI = pointer to element to delete
	; here, DS:DI = pointer to overhead bytes of element to delete
	; here, FS:BX = pointer to head
	push di										; [1] save ptr to overhead
												; bytes of element to delete
	call cllist_find_previous					; ES:DI := ptr to previous
	cmp ax, 0
	pop bx										; [1] DS:BX := ptr to overhead
												; bytes of element to delete
	je llist_remove_fail
	
	add di, cx									; ES:DI := ptr to overhead
												; bytes of previous
	; here, DS:SI = pointer to element to delete
	; here, DS:BX = pointer to overhead bytes of element to delete
	; here, ES:DI = pointer to overhead bytes of previous element
	; here, CX = element size
	
	test byte [ds:bx+4], CLLIST_FLAG_HAS_NEXT	; does element have a next?
	jz llist_remove__nonhead_last		; no, so it's last

llist_remove__nonhead_not_last:
	; CASE 3: inner element is deleted
	mov ax, word [ds:bx+0]
	mov word [es:di+0], ax
	mov ax, word [ds:bx+2]
	mov word [es:di+2], ax						; previous.next = toDelete.next
	call dynmem_deallocate				; free memory used by element
	
	jmp llist_remove_success
	
llist_remove__nonhead_last:
	; CASE 4: last element is deleted
	mov al, CLLIST_FLAG_HAS_NEXT
	xor al, 0FFh
	and byte [es:di+4], al						; penultimate element no 
												; longer has next
	call dynmem_deallocate				; free memory used by element
	
	jmp llist_remove_success
	
llist_remove_fail:
	mov ax, 0
	jmp llist_remove_done
llist_remove_success:
	mov ax, 1
llist_remove_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop fs
	pop es
	pop ds
	ret
	

; Gets the element after the specified element, if one exists
;
; input:
;		CX - element length, in bytes, maximum 20,000 bytes
;	 DS:SI - pointer to element before the one we're returning
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to the element after the specified one, when successful
llist_get_next:
	pushf
	push fs
	push es
	push bx
	push cx
	push dx
	push di
	
	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_get_next_fail
	
	mov bx, cx									; BX := element size
	
	test byte [ds:si+bx+4], CLLIST_FLAG_HAS_NEXT	; does it have next?
	jz llist_get_next_fail				; no
	
	push word [ds:si+bx+0]
	push word [ds:si+bx+2]
	pop si
	pop ds										; DS:SI := next element
	jmp llist_get_next_success
	
llist_get_next_fail:
	mov ax, 0
	jmp llist_get_next_done
llist_get_next_success:
	mov ax, 1
llist_get_next_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop es
	pop fs
	popf
	ret
	

; Gets the head element of the list, if one exists
;
; input:
;	 FS:BX - pointer to pointer to list head
; output:
;		AX - 0 when list is empty, other value otherwise
;	 DS:SI - pointer to head element, when successful
llist_get_head:
	pushf
	push fs
	push es
	push bx
	push cx
	push dx
	push di
	; NOTE: CX is NOT an argument
	call cllist_assert_memory
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_get_head_fail				; no
	; yes, so return it
	
	push word [fs:bx+0]
	pop ds
	mov si, word [fs:bx+2]
	jmp llist_get_head_success
	
llist_get_head_fail:
	mov ax, 0
	jmp llist_get_head_done
llist_get_head_success:
	mov ax, 1
llist_get_head_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop es
	pop fs
	popf
	ret

	
; Adds an element after the specified element (precedent)
;
; input:
;	 ES:DI - pointer to payload to add as a new element
;		CX - element length, in bytes, maximum 20,000 bytes
;	 DS:SI - pointer to element after which we're adding the new element
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to element in the list, when successful
llist_add_after:
	pushf
	push fs
	push es
	push bx
	push cx
	push dx
	push di
	
	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_add_after_fail
	
	push ds
	pop fs
	mov dx, si							; FS:DX := precedent
	
	mov ax, cx
	add ax, CLLIST_OVERHEAD_BYTES
	call dynmem_allocate			; DS:SI := pointer to list element
	cmp ax, 0
	je llist_add_after_fail
	
	push cx								; [2] save input element size
	
	push ds
	push si								; [1] save pointer to new list element
	
	xchg si, di
	push ds
	push es
	pop ds								; DS:SI := pointer to input element
	pop es								; ES:DI := pointer to list element
	; here, CX = total list element size (input element size)
	cld
	rep movsb							; copy input element into list element

	pop si
	pop ds								; [1] DS:SI := new list element
	pop bx								; [2] BX := new list element size
	; here, FS:DX = precedent
	
	push fs
	pop es
	mov di, dx							; ES:DI := precedent
	
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; does precedent have next?
	jz llist_add_after___add_at_end			; no, so we add at end
	; yes, so we add in the middle, updating new.next

llist_add_after___add_in_middle:
	; CASE 1: we must update new.next
	; here, DS:SI := new list element 
	; here, BX = new list element size
	; here, ES:DI = precedent
	
	mov ax, word [es:di+bx+0]
	mov word [ds:si+bx+0], ax
	mov ax, word [es:di+bx+2]
	mov word [ds:si+bx+2], ax			; new.next := precedent.next
	
	mov word [es:di+bx+0], ds
	mov word [es:di+bx+2], si			; precedent.next := new
	
	mov byte [ds:si+bx+4], 0
	or byte [ds:si+bx+4], CLLIST_FLAG_HAS_NEXT	; new "has next" flag
	jmp llist_add_after_success
llist_add_after___add_at_end:
	; CASE 2: we add at end
	; here, DS:SI := new list element 
	; here, BX = new list element size
	; here, ES:DI = precedent
	
	mov word [ds:si+bx+0], 0
	mov word [ds:si+bx+2], 0			; new.next := dummy
	
	mov word [es:di+bx+0], ds
	mov word [es:di+bx+2], si			; precedent.next := new
	mov byte [es:di+bx+4], 0
	or byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; precedent "has next" flag
	
	mov byte [ds:si+bx+4], 0			; new "has no next" flag
	jmp llist_add_after_success
	
llist_add_after_fail:
	mov ax, 0
	jmp llist_add_after_done
llist_add_after_success:
	mov ax, 1
llist_add_after_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop es
	pop fs
	popf
	ret
	

; Adds an element to the end of the list
;
; input:
;	 FS:BX - pointer to pointer to list head
;	 ES:DI - pointer to payload to add as a new element
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to element in the list, when successful
llist_add:
	pushf
	push fs
	push es
	push bx
	push cx
	push dx
	push di

	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_add_fail
	
	mov ax, cx
	add ax, CLLIST_OVERHEAD_BYTES
	call dynmem_allocate			; DS:SI := pointer to list element
	cmp ax, 0
	je llist_add_fail
	push cx								; [2] save input element size
	
	push ds
	push si								; [1] save pointer to new list element
	
	xchg si, di
	push ds
	push es
	pop ds								; DS:SI := pointer to input element
	pop es								; ES:DI := pointer to list element
	; here, CX = total list element size (input element size)
	cld
	rep movsb							; copy input element into list element

	pop si
	pop ds								; [1] DS:SI := new list element
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_add__empty			; no, the list is empty
	; head exists
llist_add__nonempty:
	; CASE 1: non empty list
	; find last element

	; here, DS:SI = new list element
	; here, FS:BX = pointer to pointer to head
	pop cx								; [2] CX := input element size
	call cllist_find_last				; ES:DI := pointer to last element
	
	mov bx, cx							; BX := input element size
	; populate last element
	mov word [es:di+bx+0], ds
	mov word [es:di+bx+2], si			; last.next = new
	mov byte [es:di+bx+4], 0
	or byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; store "has next" flag
												; (in new list element)
	jmp llist_add_populate_new_element
	
llist_add__empty:
	; CASE 2: empty list
	; here, DS:SI = new list element
	; here, FS:BX = pointer to pointer to head
	; here we know that the list is empty, so this is the head
		
	; fill values in pointer to pointer to head
	mov word [fs:bx+0], ds
	mov word [fs:bx+2], si				; store pointer to head (in consumer)
	mov byte [fs:bx+4], 0
	or byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; store "has head" flag 
											; (in consumer)
	pop bx								; [2] BX := input element size
	
llist_add_populate_new_element:
	; here, DS:SI = new list element
	; here, BX := input element size
	; fill values in new list element
	mov word [ds:si+bx+0], 0			; next element segment
	mov word [ds:si+bx+2], 0			; next element offset
	mov byte [ds:si+bx+4], 0			; store "has no next" flag 
										; (in list element)
	; here, DS:SI = allocated list element
	jmp llist_add_success
	
llist_add_fail:
	mov ax, 0
	jmp llist_add_done
llist_add_success:
	mov ax, 1
llist_add_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop es
	pop fs
	popf
	ret

	
; Invokes a callback function for each element of the list.
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies list structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to currently-iterated list element
;                       DX - index of currently-iterated list element
;        callback output:
;                       AX - 0 when traversal must stop, other value otherwise
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
;	 DS:SI - pointer to callback function
; output:
;		none
llist_foreach:
	pusha
	push ds
	push es
	push fs
	
	call cllist_assert_memory
	
	cmp cx, CLLIST_MAX_ELEMENT_SIZE
	ja llist_foreach_done
	
	test byte [fs:bx+4], CLLIST_FLAG_HAS_NEXT	; does head exist?
	jz llist_foreach_done				; no, so we're done
	
	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]				; ES:DI := pointer to head
	
	mov bx, cx							; BX := element size
	mov dx, 0							; current index

llist_foreach_loop:
	; here, DS:SI = pointer to callback
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; 1. setup return address
	push cs
	push word llist_callback_return	; return address on stack
	
	; 2. setup "call far" site address
	push ds			; callback segment
	push si			; callback offset
	
	; 3. setup callback arguments
	push es
	pop ds
	mov si, di		; DS:SI := pointer to list element
	; here, DX = index of current element
	
	; 4. invoke callback
	retf			; "call far"
	
	; once the callback executes its own retf, execution returns below
llist_callback_return:
	mov word [cs:cllistCallbackReturnAx], ax
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	
	cmp word [cs:cllistCallbackReturnAx], 0
	je llist_foreach_done
	
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz llist_foreach_done			; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element
	
	inc dx								; index := index + 1
	jmp llist_foreach_loop		; loop again
	
llist_foreach_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	

; Exits task and prints an error message if dynamic memory module was
; not initialized.
;
; input:
;		none
; output:
;		none
cllist_assert_memory:
	pusha
	push ds
	
	call dynmem_is_initialized
	cmp ax, 0
	jne cllist_assert_memory_success
	; not initialized
	push cs
	pop ds
	mov si, llistNoMemory
	int 80h
	mov ah, 0
	int 16h
	mov cx, 200
	int 85h							; delay
	int 95h							; exit task
cllist_assert_memory_success:
	pop ds
	popa
	ret
	
	
; Finds last element in the list.
; Assumes list not empty.
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
; output:
;	 ES:DI - pointer to last element
cllist_find_last:
	push ds
	push fs
	push ax
	push bx
	push cx
	push dx
	push si
	
	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]				; ES:DI := pointer to head
	
	mov bx, cx							; BX := element size
	
cllist_find_last_loop:
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz cllist_find_last_done			; yes, we're done
	; not last element
	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element
	jmp cllist_find_last_loop			; loop again
	
cllist_find_last_done:
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	pop fs
	pop ds
	ret
	
	
; Finds the element right before the specified element.
; Assumes list not empty.
; Assumes specified element is not the head.
;
; input:
;	 FS:BX - pointer to pointer to list head
;		CX - element length, in bytes, maximum 20,000 bytes
;	 DS:SI - pointer to element after the element for which we're searching
; output:
;		AX - 0 when element was not found, other value otherwise
;	 ES:DI - pointer to last element
cllist_find_previous:
	push ds
	push fs
	push bx
	push cx
	push dx
	push si

	push word [fs:bx+0]
	pop es
	mov di, word [fs:bx+2]				; ES:DI := pointer to head
	
	mov bx, cx							; BX := element size

cllist_find_previous_loop:
	test byte [es:di+bx+4], CLLIST_FLAG_HAS_NEXT	; last element?
	jz cllist_find_previous_fail			; yes, we're done
	; not last element

	mov ax, ds
	cmp word [es:di+bx+0], ax			; match on segment?
	jne cllist_find_previous_loop_next	; no
	cmp word [es:di+bx+2], si			; match on offset?
	jne cllist_find_previous_loop_next	; no
	
	jmp cllist_find_previous_success	; we found the previous element
	
cllist_find_previous_loop_next:	
	push word [es:di+bx+0]
	push word [es:di+bx+2]
	pop di
	pop es								; ES:DI := pointer to next element
	jmp cllist_find_previous_loop			; loop again

cllist_find_previous_fail:
	mov ax, 0
	jmp cllist_find_previous_done
cllist_find_previous_success:
	mov ax, 1
cllist_find_previous_done:
	pop si
	pop dx
	pop cx
	pop bx
	pop fs
	pop ds
	ret
