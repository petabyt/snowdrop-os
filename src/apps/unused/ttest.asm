;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The TTEST app.
; This application was used to develop Snowdrop OS's trees library.
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop app contract:
;
; At startup, the app can assume:
;	- the app is loaded at offset 0
;	- all segment registers equal CS
;	- the stack is valid (SS, SP)
;	- BP equals SP
;	- direction flag is clear (string operations count upwards)
;
; The app must:
;	- call int 95h to exit
;	- not use the entire 64kb memory segment, as its own stack begins from 
;	  offset 0FFFFh, growing upwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16						; the CPU is assumed to function in 16-bit mode
	org 0						; apps are loaded at offset 0 by the caller

	jmp start

	
AVAILABLE_DYN_MEM		equ 30000
pressToExit:			db 'Press a key to exit', 0
newLine:				db 13, 10, 0

COMMON_DYNTREE_ROOT_PTR_LENGTH_2 equ COMMON_DYNTREE_ROOT_PTR_LENGTH
COMMON_DYNTREE_ROOT_PTR_INITIAL_2 equ COMMON_DYNTREE_ROOT_PTR_INITIAL

; variables used for the first list, which holds 16bit integers
integersRoot:	times COMMON_DYNTREE_ROOT_PTR_LENGTH_2 db COMMON_DYNTREE_ROOT_PTR_INITIAL_2
								; by convention, consumer applications must 
								; declare and pass this address to linked 
								; list functions

integersPayload:		dw 0	; stores elements we're adding
INTEGERS_PAYLOAD_SIZE	equ 2	; each element holds this many bytes


; variables used for the first list, which holds 16bit integers
stringsRoot:	times COMMON_DYNTREE_ROOT_PTR_LENGTH_2 db COMMON_DYNTREE_ROOT_PTR_INITIAL_2
								; by convention, consumer applications must 
								; declare and pass this address to linked 
								; list functions
STRINGS_PAYLOAD_SIZE	equ 9	; each element holds this many bytes

string1:	db 'string 1', 0
string2:	db 'string 2', 0
string3:	db 'string 3', 0
string4:	db 'string 4', 0
string5:	db 'string 5', 0

string1ptr:	dw 0
string2ptr:	dw 0
string3ptr:	dw 0
string4ptr:	dw 0
string5ptr:	dw 0

; these store pointers to list elements
node4ptr:	dw 0
node5ptr:	dw 0
node6ptr:	dw 0
node8ptr:	dw 0				
node7ptr:	dw 0		
node9ptr:	dw 0

start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 83h						; clear keyboard buffer

	mov si, dynamicMemoryStart	; DS:SI := pointer to start of dynamic memory
	mov ax, AVAILABLE_DYN_MEM	; maximum allocatable bytes
	call common_memory_initialize
	cmp ax, 0
	je done
	
	; main program
	
call common_memory_stats
;int 0b4h

	mov ax, 5
	call integers_add_root
	mov word [cs:node5ptr], si
	mov bx, word [ds:si]
	
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dyntree_get_parent
	;int 0b4h
	
	mov ax, 6
	call integers_add_root
	mov word [cs:node6ptr], si
	mov bx, word [ds:si]
	;int 0b4h

	push cs
	pop fs
	mov bx, integersRoot
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_get_roots_first_child	; DS:SI := ptr
	mov word [cs:node5ptr], si
	
	mov ax, 7
	mov si, word [cs:node6ptr]
	call integers_add_child
	mov word [cs:node7ptr], si

	mov ax, 8
	mov si, word [cs:node6ptr]
	call integers_add_child
	mov word [cs:node8ptr], si
	
	mov ax, 9
	mov si, word [cs:node6ptr]
	call integers_add_child
	mov word [cs:node9ptr], si

	mov si, word [cs:node9ptr]
	mov di, word [cs:node8ptr]					; target
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_change_parent
	mov word [cs:node9ptr], si
	;int 0b4h
	
	mov si, word [cs:node7ptr]
	mov di, word [cs:node8ptr]					; target
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_change_parent
	mov word [cs:node7ptr], si
	;int 0b4h
	
	;            6
	;     5             8
	;                9     7
	
	mov si, word [cs:node8ptr]
	mov di, word [cs:node6ptr]					; target
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_change_parent
	mov word [cs:node8ptr], si
	;int 0b4h
	
	;            6
	;     5             8
	;                9     7
	
	;mov si, pressToExit
	;int 80h
	
	mov si, word [cs:node5ptr]
	mov di, word [cs:node8ptr]					; target
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_change_parent
	mov word [cs:node5ptr], si
	;int 0b4h
	
	;            6
	;                   8
	;                9  7  5

	mov si, word [cs:node7ptr]
	mov di, word [cs:node6ptr]					; target
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_change_parent
	mov word [cs:node7ptr], si
	
	;            6
	;      7            8
	;                 9   5
	
	mov ax, 4
	mov si, word [cs:node8ptr]
	call integers_add_child
	mov word [cs:node4ptr], si
	
	;            6
	;      7            8
	;                9  5  4

	mov si, word [cs:node9ptr]
	call integers_remove_leaf
	;int 0b4h
	
	mov si, word [cs:node5ptr]
	call integers_remove_leaf
	
	mov si, word [cs:node4ptr]
	call integers_remove_leaf
	
	;            6
	;      7            8
	;
	
	mov ax, 9
	mov si, word [cs:node8ptr]
	call integers_add_child
	mov word [cs:node9ptr], si
	
	mov ax, 4
	mov si, word [cs:node8ptr]
	call integers_add_child
	mov word [cs:node4ptr], si
	
	mov ax, 5
	mov si, word [cs:node8ptr]
	call integers_add_child
	mov word [cs:node5ptr], si
	
	; node 8 was before 7 for a while - previous drawings show them in the wrong order
	;
	;            6
	;      8            7
	;   9  4  5
	;
	; postorder: 9 4 5 8 7 6
	;  preorder: 6 8 9 4 5 7
	
	;mov si, word [cs:node8ptr]			; SI only is OK!
	;call integers_subtree_remove

	;push cs
	;pop fs
	;mov bx, integersRoot
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dyntree_clear
	
call common_memory_stats
;int 0b4h
	mov si, word [cs:node6ptr]			; SI only is OK!
	;call integers_print_subtree_postorder
	;call integers_print_subtree_preorder
call common_memory_stats
;int 0b4h
	
	;mov si, word [cs:node5ptr]
	;int 0b4h
	;push cs
	;pop ds
	;mov si, word [cs:node6ptr]
	;mov di, 0									; offset
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov dl, 5									; to find
	;call common_dyntree_subtree_find_by_byte
	;mov dx, 5
	;call common_dyntree_subtree_find_by_word
	;mov bx, word [ds:si]
	;int 0b4h
	
	;push cs
	;pop es
	;mov di, integers_print_ancestor_callback
	;push cs
	;pop ds
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov si, word [cs:node6ptr]
	;call common_dyntree_subtree_foreach_ancestor
	
	;mov si, word [cs:node6ptr]
	;call common_dyntree_subtree_statistics	; AX := height, BX := node count
	;int 0b4h

	;mov si, word [cs:node5ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dyntree_get_next_sibling
	;mov bx, word [ds:si]
	;int 0b4h
	
	;mov si, word [cs:node6ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dyntree_get_first_child			; DS:SI := ptr
	;mov bx, word [ds:si]
	;int 0b4h
	
	;mov si, word [cs:node6ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dyntree_get_child_count
	;int 0b4h
	
	;mov si, word [cs:node4ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov dx, 0
	;call common_dyntree_get_child_at_index
	;mov bx, word [ds:si]
	;int 0b4h
	
	;mov si, word [cs:node6ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dyntree_get_parent
	;mov bx, word [ds:si]
	;int 0b4h
	
	
	; ============= strings ==============
	mov di, string1									; DI only is OK
	call strings_add_root
	mov word [cs:string1ptr], si

	mov si, word [cs:string1ptr]
	mov di, string2
	call strings_add_child
	mov word [cs:string2ptr], si

	mov si, word [cs:string1ptr]
	mov di, string3
	call strings_add_child
	mov word [cs:string3ptr], si

	mov si, word [cs:string2ptr]
	mov di, string4
	call strings_add_child
	mov word [cs:string4ptr], si

	mov si, word [cs:string2ptr]
	mov di, string5
	call strings_add_child
	mov word [cs:string5ptr], si

	;                           string1
	;             string2                    string3
	;     string4         string5

	mov si, word [cs:string1ptr]
	;call strings_print_subtree_preorder
	
	;mov si, word [cs:string4ptr]
	;int 0b4h
	;push cs
	;pop ds
	;mov si, word [cs:string1ptr]
	;push cs
	;pop es
	;mov di, string4								; string to search
	;mov dx, 0									; offset
	;mov cx, STRINGS_PAYLOAD_SIZE
	;call common_dyntree_subtree_find_by_string
	;mov bx, word [ds:si]
	;int 0b4h
	;int 97h
	
done:
	int 83h						; clear keyboard buffer
	
	push cs
	pop ds
	mov si, pressToExit
	int 97h
	mov ah, 0
	int 16h
	
	; exit program
	int 95h						; exit


;
; input:
;	 CS:SI - pointer to node
; output:
;		none
integers_print_subtree_preorder:
	pusha
	push ds
	push es
	
	push cs
	pop es
	mov di, integers_print_one_subtree_callback
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_subtree_foreach_preorder
	
	pop es
	pop ds
	popa
	ret
	
	
;
; input:
;	 CS:SI - pointer to node
; output:
;		none
strings_print_subtree_preorder:
	pusha
	push ds
	push es
	
	push cs
	pop es
	mov di, strings_print_one_subtree_callback
	
	mov cx, STRINGS_PAYLOAD_SIZE
	call common_dyntree_subtree_foreach_preorder
	
	pop es
	pop ds
	popa
	ret
	

;
; input:
;	 CS:SI - pointer to node
; output:
;		none
integers_print_subtree_postorder:
	pusha
	push ds
	push es
	
	push cs
	pop es
	mov di, integers_print_one_subtree_callback
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dyntree_subtree_foreach_postorder
	
	pop es
	pop ds
	popa
	ret

	
;
; input:
;	 CS:SI - pointer to node to remove
; output:
;		AX - 0 on failure, other value on success
integers_remove_leaf:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push ds
	push si
	
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	mov cx, INTEGERS_PAYLOAD_SIZE	; integersPayload size
	push cs
	pop ds
	call common_dyntree_remove
	
	pop si
	pop ds
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;		AX - integer to add
; output:
;	 DS:SI - pointer to new root
;		AX - 0 on failure, other value on success
integers_add_root:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	mov cx, INTEGERS_PAYLOAD_SIZE	; integersPayload size
	push cs
	pop es
	mov di, integersPayload			; ES:DI := pointer to integersPayload
	mov word [es:di], ax			; payload
	call common_dyntree_add_root	; DS:SI := new root
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;	 CS:DI - pointer to string to add
; output:
;	 DS:SI - pointer to new root
;		AX - 0 on failure, other value on success
strings_add_root:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	push cs
	pop fs
	mov bx, stringsRoot			; FS:BX := pointer to pointer to root
	mov cx, STRINGS_PAYLOAD_SIZE	; integersPayload size
	push cs
	pop es							; ES:DI := string
	call common_dyntree_add_root	; DS:SI := new root
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;		AX - integer to add
;	 DS:SI - pointer to parent node
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to new node
integers_add_child:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	mov cx, INTEGERS_PAYLOAD_SIZE	; integersPayload size
	push cs
	pop es
	mov di, integersPayload			; ES:DI := pointer to integersPayload
	mov word [es:di], ax			; payload
	call common_dyntree_add_child	; DS:SI := new node
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;	 CS:DI - pointer to string to add
;	 DS:SI - pointer to parent node
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to new node
strings_add_child:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	mov cx, STRINGS_PAYLOAD_SIZE	; integersPayload size
	push cs
	pop es							; ES:DI := pointer to string to add
	call common_dyntree_add_child	; DS:SI := new node
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;	 CS:SI - pointer to root of subtree to remove
; output:
;		none
integers_subtree_remove:
	pusha
	push ds
	push es
	push fs

	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	mov cx, INTEGERS_PAYLOAD_SIZE

	push cs
	pop ds										; DS:SI := node

	call common_dyntree_subtree_remove
	
	mov si, newLine
	int 97h
	
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Prints children of the specified node
;
; input:
;	 CS:SI - pointer to node
; output:
;		none
integers_print_children:
	pusha
	push ds
	push es
	push fs

	mov cx, INTEGERS_PAYLOAD_SIZE

	push cs
	pop ds										; DS:SI := node
	
	push cs
	pop es
	mov di, integers_print_one_callback			; ES:DI := callback

	call common_dyntree_children_foreach
	
	mov si, newLine
	int 97h
	
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Callback for iteration through the list via foreach
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		none
integers_print_one_callback:
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	mov cl, 1						; formatting
	call common_text_print_number
	retf
	
	
; Callback for iteration through a subtree
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;
; input:
;	 DS:SI - pointer to currently-iterated node
;		DX - depth relative to specified node
; output:
;		none
integers_print_one_subtree_callback:
	mov cl, 1						; formatting
	
	mov ax, dx
	mov dx, 0
	;call common_text_print_number	; print depth
	
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	call common_text_print_number
	retf
	
	
; Callback for iteration through a subtree
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;
; input:
;	 DS:SI - pointer to currently-iterated node
;		DX - depth relative to specified node
; output:
;		none
strings_print_one_subtree_callback:
	mov cl, 1						; formatting
	
	mov ax, dx
	mov dx, 0
	call common_text_print_number	; print depth
	int 97h							; print string
	retf
	
	
; Callback for iteration through the ancestors of a node
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;
; input:
;	 DS:SI - pointer to currently-iterated node
; output:
;		none
integers_print_ancestor_callback:
	mov cl, 1						; formatting
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	call common_text_print_number
	retf
	

%define _COMMON_MEMORY_CONFIG_			; override default chunk count value
COMMON_MEMORY_MAX_CHUNKS	equ 1000

%include "common\memory.asm"
%include "common\dyn_tree.asm"
%include "common\text.asm"
	
	
dynamicMemoryStart:
