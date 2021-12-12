;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains breakpoint management functionality 
; for Snowdrop OS's debugger.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DBGX86_BREAKPOINTS_
%define _COMMON_DBGX86_BREAKPOINTS_

BK_NONE 				equ 0FFFFh ; word value which marks a slot as empty
									   ; if this value is changed, inspect
									   ; array clear function
BK_IN_USE 				equ 0	; indicates a slot is in use

BK_ENTRY_SIZE_BYTES		equ 10
BK_COUNT	 			equ 128
BK_TOTAL_SIZE_BYTES		equ BK_COUNT*BK_ENTRY_SIZE_BYTES ; in bytes

BK_TYPE_USER_SET		equ 0
BK_TYPE_ONE_TIME		equ 1

; format of a breakpoint table entry:
; bytes
;     0-1 whether this slot is available
;     2-3 breakpoint address
;     4-4 displaced byte
;     5-5 type
;     6-7 seen count
;     8-9 unused

; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
dbgx86BreakpointsStorage: times BK_TOTAL_SIZE_BYTES db 0
dbgx86BreakpointsStorageEnd:


; Deletes a breakpoint
;
; input:
;		AX - byte offset of breakpoint
; output:
;		none
dbgx86Breakpoints_delete:
	push bx
	mov bx, ax
	mov word [cs:dbgx86BreakpointsStorage+bx], BK_NONE
	pop bx
	ret
	

; Allocates a new user-set breakpoint
;
; input:
;		AX - breakpoint address
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - breakpoint handle
dbgx86Breakpoints_allocate:
	call dbgx86Breakpoints_find_empty_slot		; BX := slot offset
	jc dbgx86Breakpoints_allocate_return		; none found, so just return

	pushf
	push ax
	push dx
	push es
	push di
	push cx
	push si
	
	mov word [cs:dbgx86BreakpointsStorage+bx], BK_IN_USE	; mark slot in-use
	mov word [cs:dbgx86BreakpointsStorage+bx+2], ax			; address
	mov byte [cs:dbgx86BreakpointsStorage+bx+5], BK_TYPE_USER_SET
	mov word [cs:dbgx86BreakpointsStorage+bx+6], 0			; seen count

	pop si
	pop cx
	pop di
	pop es
	pop dx
	pop ax
	popf

	clc								; success
dbgx86Breakpoints_allocate_return:
	ret
	
	
; Gets the displaced byte of a breakpoint
;
; input:
;		AX - byte offset of breakpoint
; output:
;		BL - displaced byte
dbgx86Breakpoints_get_displaced_byte:
	push si
	
	mov si, dbgx86BreakpointsStorage
	add si, ax							; SI := pointer to breakpoint
	mov bl, byte [cs:si+4]
	
	pop si
	ret
	
	
; Sets the displaced byte of a breakpoint
;
; input:
;		AX - byte offset of breakpoint
;		BL - displaced byte to set
; output:
;		none
dbgx86Breakpoints_set_displaced_byte:
	pusha
	
	mov si, dbgx86BreakpointsStorage
	add si, ax							; SI := pointer to breakpoint
	add si, 4							; SI := pointer to displaced byte
	mov byte [cs:si], bl
	
	popa
	ret
	
	
; Increments the seen count of a breakpoint
;
; input:
;		AX - byte offset of breakpoint
; output:
;		none
dbgx86Breakpoints_increment_seen_count:
	pusha
	
	mov si, dbgx86BreakpointsStorage
	add si, ax							; SI := pointer to breakpoint
	add si, 6							; SI := pointer to seen count
	inc word [cs:si]
	
	popa
	ret
	
	
; Sets breakpoint type to "one time"
;
; input:
;		AX - byte offset of breakpoint
; output:
;		none
dbgx86Breakpoints_set_type_one_time:
	pusha
	
	mov si, dbgx86BreakpointsStorage
	add si, ax							; SI := pointer to breakpoint
	add si, 5							; SI := pointer to type
	mov byte [cs:si], BK_TYPE_ONE_TIME
	
	popa
	ret


; Sets breakpoint type to "user-set"
;
; input:
;		AX - byte offset of breakpoint
; output:
;		none
dbgx86Breakpoints_set_type_user_set:
	pusha
	
	mov si, dbgx86BreakpointsStorage
	add si, ax							; SI := pointer to breakpoint
	add si, 5							; SI := pointer to type
	mov byte [cs:si], BK_TYPE_USER_SET
	
	popa
	ret
	
	
; Gets the type of a breakpoint
;
; input:
;		AX - byte offset of breakpoint
; output:
;		BL - type
dbgx86Breakpoints_get_type:
	push si
	mov si, dbgx86BreakpointsStorage
	add si, ax							; SI := pointer to breakpoint	
	add si, 5							; SI := pointer to breakpoint address
	mov bl, byte [cs:si]
	pop si
	ret
	
	
; Gets the address of a breakpoint
;
; input:
;		AX - byte offset of breakpoint
; output:
;		BX - breakpoint address
dbgx86Breakpoints_get_address:
	push si
	mov si, dbgx86BreakpointsStorage
	add si, ax							; SI := pointer to breakpoint	
	add si, 2							; SI := pointer to breakpoint address
	mov bx, word [cs:si]
	pop si
	ret

	
; Gets the handle of a breakpoint by address
;
; input:
;	 	AX - address
; output:
;	 CARRY - set when breakpoint was not found, clear otherwise
;		AX - handle (byte offset into array), if found
dbgx86Breakpoints_get_handle_by_address:
	push bx
	push cx
	push dx
	
	mov bx, dbgx86BreakpointsStorage
dbgx86Breakpoints_get_handle_loop:
	cmp bx, dbgx86BreakpointsStorageEnd			; are we past the end?
	jae dbgx86Breakpoints_get_handle_not_found	; yes, so it's not found

	cmp word [cs:bx], BK_NONE					; is this slot empty?
	je dbgx86Breakpoints_get_handle_loop_next	; yes, so skip it
	; slot is full, compare addresses
	
	mov cx, word [cs:bx+2]		; CX := address of this breakpoint
	cmp ax, cx					; equal?
	je dbgx86Breakpoints_get_handle_found	; yes, this is the breakpoint
	
dbgx86Breakpoints_get_handle_loop_next:
	add bx, BK_ENTRY_SIZE_BYTES
	jmp dbgx86Breakpoints_get_handle_loop

dbgx86Breakpoints_get_handle_found:
	mov ax, bx
	sub ax, dbgx86BreakpointsStorage		; AX := handle (byte offset)
	clc
	jmp dbgx86Breakpoints_get_handle_done
dbgx86Breakpoints_get_handle_not_found:
	stc
dbgx86Breakpoints_get_handle_done:
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
dbgx86Breakpoints_clear:
	pusha
	pushf
	push es
	
	push cs
	pop es
	
	mov cx, BK_TOTAL_SIZE_BYTES / 2
			; can never overrun array, and since each element is at least
			; 2 bytes long, it's either even (2 bytes per element), or
			; misses third or later byte in the last element (which is
			; still marked as "empty")
										
	mov di, dbgx86BreakpointsStorage	; ES:DI := pointer to array
	mov ax, BK_NONE				; mark each array element as "empty"
	cld
	rep stosw
	
	pop es
	popf
	popa
	ret
	
	
; Allocates a new user-set breakpoint and modifies program binary by
; inserting an int3.
;
; input:
;		AX - breakpoint address
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - breakpoint handle
dbgx86Breakpoints_add_breakpoint_by_address:
	push ds
	push ax
	push si
	
	call dbgx86Breakpoints_allocate					; BX := handle

	jc dbgx86Breakpoints_add_breakpoint_by_address_done
	; it was successful
	mov ds, word [cs:dbgx86BinarySeg]
	mov si, ax				; DS:SI := pointer to breakpoint address
	
	push ax
	push bx
	mov ax, bx										; AX := handle
	mov bl, byte [ds:si]							; BL := displaced byte
	call dbgx86Breakpoints_set_displaced_byte
	pop bx
	pop ax
	
	; insert int3 into program
	mov byte [ds:si], 0CCh							; int3
dbgx86Breakpoints_add_breakpoint_by_address_done:
	pop si
	pop ax
	pop ds
	ret
	

; Returns a byte offset of first empty slot in the array
;
; input:
;		none
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - byte offset (into array) of first empty slot, if one was found
dbgx86Breakpoints_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, dbgx86BreakpointsStorage
	mov bx, 0				; offset of array slot being checked
dbgx86Breakpoints_find_empty_slot_loop:
	cmp word [cs:si+bx], BK_NONE		; is this slot empty?
										; (are first two bytes BK_NONE?)
	je dbgx86Breakpoints_find_empty_slot_done	; yes
	
	add bx, BK_ENTRY_SIZE_BYTES		; next slot
	cmp bx, BK_TOTAL_SIZE_BYTES		; are we past the end?
	jb dbgx86Breakpoints_find_empty_slot_loop		; no
dbgx86Breakpoints_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp dbgx86Breakpoints_find_empty_slot_done
dbgx86Breakpoints_find_empty_slot_done:
	pop si
	ret

	
; Prints all breakpoints to the screen, in a list
;
; input:
;		none
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - byte offset (into array) of first empty slot, if one was found
dbgx86Breakpoints_print_list:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov bh, DBGX86_BK_LIST_BOX_FIRST_TOP
	mov bl, DBGX86_BK_LIST_BOX_FIRST_LEFT
	call common_screenh_move_hardware_cursor
	
	; find first empty array slot
	mov si, dbgx86BreakpointsStorage
	mov bx, 0				; offset of array slot being checked
dbgx86Breakpoints_print_list_loop:
	cmp word [cs:si+bx], BK_NONE		; is this slot empty?
										; (are first two bytes BK_NONE?)
	je dbgx86Breakpoints_print_list_loop_next	; yes
	; this entry contains a breakpoint
	
	cmp byte [cs:si+bx+5], BK_TYPE_ONE_TIME
	je dbgx86Breakpoints_print_list_loop_next	; we don't print one-time
												; breakpoints
	mov ax, word [cs:si+bx+2]					; AX := address
	call common_hex_print_word_to_hardware		; print address
	
	; move cursor right to print the seen count
	mov cx, bx									; save
	call common_screenh_get_cursor_position
	add bl, 8
	call common_screenh_move_hardware_cursor
	mov bx, cx
	mov ax, word [cs:si+bx+6]					; AX := seen count
	call common_hex_print_word_to_hardware		; print address
	
	; move cursor down
	mov cx, bx									; save
	call common_screenh_get_cursor_position
	inc bh
	mov bl, DBGX86_BK_LIST_BOX_FIRST_LEFT
	call common_screenh_move_hardware_cursor
	cmp bh, DBGX86_BK_LIST_BOX_LAST_TOP
	ja dbgx86Breakpoints_print_list_done
	mov bx, cx									; restore

dbgx86Breakpoints_print_list_loop_next:
	add bx, BK_ENTRY_SIZE_BYTES					; next slot
	cmp bx, BK_TOTAL_SIZE_BYTES					; are we past the end?
	jb dbgx86Breakpoints_print_list_loop		; no

dbgx86Breakpoints_print_list_done:
	pop es
	pop ds
	popa
	ret


; Counts all user-set breakpoints
;
; input:
;		none
; output:
;		CX - number of user-set breakpoints
dbgx86Breakpoints_count_user_set:
	push ax
	push bx
	push dx
	push si
	push di
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov cx, 0

	mov si, dbgx86BreakpointsStorage
	mov bx, 0				; offset of array slot being checked
dbgx86Breakpoints_count_user_set_loop:
	cmp word [cs:si+bx], BK_NONE		; is this slot empty?
										; (are first two bytes BK_NONE?)
	je dbgx86Breakpoints_count_user_set_loop_next	; yes
	; this entry contains a breakpoint
	
	cmp byte [cs:si+bx+5], BK_TYPE_ONE_TIME
	je dbgx86Breakpoints_count_user_set_loop_next	; we don't count one-time
													; breakpoints
	inc cx								; accumulate
dbgx86Breakpoints_count_user_set_loop_next:
	add bx, BK_ENTRY_SIZE_BYTES					; next slot
	cmp bx, BK_TOTAL_SIZE_BYTES					; are we past the end?
	jb dbgx86Breakpoints_count_user_set_loop		; no

dbgx86Breakpoints_count_user_set_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop bx
	pop ax
	ret


%endif
