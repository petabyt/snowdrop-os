;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file contains a template meant to be customized via simple, text 
; find-and-replace.
;
; Once customized (renamed), it can be copied verbatim to be incorporated in
; a program. Through multiple renames, multiple copies of this template can 
; be incorporated in the same program.
;
; It provides storage and access to an array of multi-byte values. As such, it
; is best suited as a "struct array".
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;------------------------- TEMPLATE TEXT REPLACEMENTS -------------------------
;-     replace strings prefixed with t_ or T_ to "instantiate" the object     -
;-     and then copy it in your program.
;------------------------------------------------------------------------------
;
; t_arrayName 				(replace with something like objectArray, etc.)
T_NONE 						equ 0FFFFh ; word value which marks a slot as empty
									   ; if this value is changed, inspect
									   ; array clear function
T_ARRAY_ENTRY_SIZE_BYTES	equ 64
T_ARRAY_LENGTH 				equ 8
T_ARRAY_TOTAL_SIZE_BYTES equ T_ARRAY_LENGTH*T_ARRAY_ENTRY_SIZE_BYTES ; in bytes
;
;----------------------- END TEMPLATE TEXT REPLACEMENTS -----------------------


; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
t_arrayNameStorage: times T_ARRAY_TOTAL_SIZE_BYTES db 0


; Clears array by setting all elements to "empty"
;
; input:
;		none
; output:
;		none
t_arrayName_clear:
	pusha
	pushf
	push es
	
	push cs
	pop es
	
	mov cx, T_ARRAY_TOTAL_SIZE_BYTES / 2
			; can never overrun array, and since each element is at least
			; 2 bytes long, it's either event (2 bytes per element), or
			; misses third or later byte in the last element (which is
			; still marked as "empty")
										
	mov di, t_arrayNameStorage	; ES:DI := pointer to array
	mov ax, T_NONE				; mark each array element as "empty"
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
t_arrayName_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, t_arrayNameStorage
	mov bx, 0				; offset of array slot being checked
t_arrayName_find_empty_slot_loop:
	cmp word [cs:si+bx], T_NONE			; is this slot empty?
										; (are first two bytes T_NONE?)
	je t_arrayName_find_empty_slot_done	; yes
	
	add bx, T_ARRAY_ENTRY_SIZE_BYTES		; next slot
	cmp bx, T_ARRAY_TOTAL_SIZE_BYTES		; are we past the end?
	jb t_arrayName_find_empty_slot_loop		; no
t_arrayName_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp t_arrayName_find_empty_slot_done
t_arrayName_find_empty_slot_done:
	pop si
	ret


; Performs an action on all (non-empty) elements of the array
; This function is meant to be customized to whatever action is required
;
; input:
;		none
; output:
;		none
t_arrayName_perform:
	pusha

	mov si, t_arrayNameStorage
	mov bx, 0				; offset of array slot being checked
t_arrayName_perform_loop:
	cmp word [cs:si+bx], T_NONE			; is this slot empty?
										; (are first two bytes T_NONE?)
	je t_arrayName_perform_next			; yes
	; this array element is not empty, so perform action on it
	push bx
	push si
	;-------------- ACTION CODE GOES HERE --------------
	
	;----------------- END ACTION CODE -----------------
	pop si
	pop bx
t_arrayName_perform_next:
	add bx, T_ARRAY_ENTRY_SIZE_BYTES	; next slot
	cmp bx, T_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb t_arrayName_perform_loop			; no
t_arrayName_perform_done:
	popa
	ret
