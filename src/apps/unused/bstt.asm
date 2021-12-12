;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BSTT app.
; This application was used to develop Snowdrop OS's BST library.
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
pressToExit:			db 13, 10, 'Press a key to exit', 0
newLine:				db 13, 10, 0

COMMON_DYNBST_ROOT_PTR_LENGTH_2 equ COMMON_DYNBST_ROOT_PTR_LENGTH
COMMON_DYNBST_ROOT_PTR_INITIAL_2 equ COMMON_DYNBST_ROOT_PTR_INITIAL

; variables used for the first list, which holds 16bit integers
integersRoot:	times COMMON_DYNBST_ROOT_PTR_LENGTH_2 db COMMON_DYNBST_ROOT_PTR_INITIAL_2
								; by convention, consumer applications must 
								; declare and pass this address to linked 
								; list functions

integersPayload:		dw 0	; stores elements we're adding
INTEGERS_PAYLOAD_SIZE	equ 2	; each element holds this many bytes


; variables used for the first list, which holds 16bit integers
stringsRoot:	times COMMON_DYNBST_ROOT_PTR_LENGTH_2 db COMMON_DYNBST_ROOT_PTR_INITIAL_2
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

msgParent1:			db ' (parent:', 0
msgParent2: 		db ')', 0
msgRoot:			db ' (root)', 0
printNodeSeg:		dw 0
printNodeOff:		dw 0
msgNewline:			db 13, 10, 0
msgLeft:			db ' left:', 0
msgRight:			db ' right:', 0

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

	mov ax, 20
	call integers_bst_add_word
	mov word [cs:node6ptr], si

	mov ax, 10
	call integers_bst_add_word
	
	mov ax, 5
	call integers_bst_add_word
	
	mov ax, 3
	call integers_bst_add_word
	
	mov ax, 7
	call integers_bst_add_word
	
	mov ax, 30
	call integers_bst_add_word
	
	mov ax, 25
	call integers_bst_add_word 
	
	mov ax, 27
	call integers_bst_add_word 
	
	mov ax, 28
	call integers_bst_add_word 
	
	mov ax, 26
	call integers_bst_add_word 
	
	mov ax, 31
	call integers_bst_add_word 

    ;               20
	;	10                     30
	; 5	                 25          31
	;3 7				    27
	;					  26  28					

	;push cs
	;pop fs
	;mov bx, integersRoot
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov ax, 20
	;call common_dynbst_remove_word
	;				25
	;	10                     30
	; 5					 27          31
	;3 7			   26  28
	
	
	
	;mov ax, 40
	;call integers_bst_add_word
	;mov ax, 35
	;call integers_bst_add_word
	;mov ax, 45
	;call integers_bst_add_word
	;               20
	;	10                     30
	; 5	                 25          31
	;3 7				    27           40
	;					  26  28	   35  45
	;push cs
	;pop fs
	;mov bx, integersRoot
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov ax, 20
	;call common_dynbst_remove_word
	;               25
	;	10                     30
	; 5	                 27          31
	;3 7			   26  28           40
	;					        	  35  45
	
	
	
	
	;push cs
	;pop fs
	;mov bx, integersRoot
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov ax, 10
	;call common_dynbst_remove_word
	;               20
	;	 5                     30
	;   3 7              25          31
	;  	 		      27
	;			    26  28					

	
	mov ax, 25
	;call common_dynbst_remove_word
	mov ax, 27
	;call common_dynbst_remove_word
	mov ax, 28
	;call common_dynbst_remove_word
	
	mov ax, 30
	;call common_dynbst_remove_word
	mov ax, 31
	;call common_dynbst_remove_word
	mov ax, 10
	;call common_dynbst_remove_word
	
	;call common_dynbintree_subtree_statistics
	;mov bx, word [ds:si]
	;int 0b4h
	
	;mov si, word [cs:node8ptr]			; SI only is OK!
	;call integers_subtree_remove

	;push cs
	;pop fs
	;mov bx, integersRoot
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dynbintree_clear
	
do_strings:
	mov si, string3
	call strings_bst_add
	
	mov si, string1
	call strings_bst_add
	
	mov si, string2
	call strings_bst_add
	
	mov si, string5
	call strings_bst_add
	
	mov si, string3
	call strings_bst_remove
	
	mov si, string4
	call strings_bst_add
	
	mov si, string5
int 0b4h
	call strings_bst_find
int 0b4h
	int 97h
	
print:
call common_memory_stats
;int 0b4h
	mov si, word [cs:node6ptr]			; SI only is OK!
	;call integers_print_subtree_postorder
	;call integers_print_subtree_preorder
	;call integers_print_subtree_inorder
	
	;call integers_print_whole_tree_inorder
	;call integers_print_bst_inorder
	;call integers_print_bst_inorder_byte
	;call strings_print_whole_tree_inorder
	;call strings_print_whole_tree_preorder
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
	;call common_dynbintree_subtree_find_by_byte
	;mov dx, 5
	;call common_dynbintree_subtree_find_by_word
	;mov bx, word [ds:si]
	;int 0b4h
	
	;push cs
	;pop es
	;mov di, integers_print_ancestor_callback
	;push cs
	;pop ds
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov si, word [cs:node6ptr]
	;call common_dynbintree_subtree_foreach_ancestor
	
	;mov si, word [cs:node6ptr]
	;call common_dynbintree_subtree_statistics	; AX := height, BX := node count
	;int 0b4h

	;mov si, word [cs:node5ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dynbintree_get_next_sibling
	;mov bx, word [ds:si]
	;int 0b4h
	
	;mov si, word [cs:node6ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dynbintree_get_first_child			; DS:SI := ptr
	;mov bx, word [ds:si]
	;int 0b4h
	
	;mov si, word [cs:node6ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dynbintree_get_child_count
	;int 0b4h
	
	;mov si, word [cs:node4ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;mov dx, 0
	;call common_dynbintree_get_child_at_index
	;mov bx, word [ds:si]
	;int 0b4h
	
	;mov si, word [cs:node6ptr]
	;mov cx, INTEGERS_PAYLOAD_SIZE
	;call common_dynbintree_get_parent
	;mov bx, word [ds:si]
	;int 0b4h
	
	
	; ============= strings ==============
	;mov cx, STRINGS_PAYLOAD_SIZE
	;mov di, string2									; DI only is OK
	;call common_dynbintree_add_left_child
	;mov word [cs:string2ptr], si
	
	;mov di, string3									; DI only is OK
	;call common_dynbintree_add_right_child
	;mov word [cs:string3ptr], si

	;                           string1
	;             string2
	;                    string3

	;push cs
	;pop ds
	;mov si, word [cs:string2ptr]
	;push cs
	;pop es
	;mov di, string1								; string to search
	;mov dx, 0									; offset
	;mov cx, STRINGS_PAYLOAD_SIZE
	;call common_dynbintree_subtree_find_by_string
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
	call common_dynbintree_subtree_foreach_preorder
	
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
	call common_dynbintree_subtree_foreach_preorder
	
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
	call common_dynbintree_subtree_foreach_postorder
	
	pop es
	pop ds
	popa
	ret
	
	
;
; input:
;	 CS:SI - pointer to node
; output:
;		none
integers_print_subtree_inorder:
	pusha
	push ds
	push es
	
	push cs
	pop es
	mov di, integers_print_one_subtree_callback
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_subtree_foreach_inorder
	
	pop es
	pop ds
	popa
	ret

;
; input:
;	 CS:SI - pointer to node
; output:
;		none
strings_print_whole_tree_inorder:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, stringsRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je strings_print_whole_tree_inorder_done
	
	push cs
	pop es
	mov di, strings_print_one_subtree_callback
	
	mov cx, STRINGS_PAYLOAD_SIZE
	call common_dynbintree_subtree_foreach_inorder
	
strings_print_whole_tree_inorder_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
	;
; input:
;	 CS:SI - pointer to node
; output:
;		none
strings_print_whole_tree_preorder:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, stringsRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je strings_print_whole_tree_preorder_done
	
	push cs
	pop es
	mov di, strings_print_one_subtree_callback
	
	mov cx, STRINGS_PAYLOAD_SIZE
	call common_dynbintree_subtree_foreach_preorder
	
strings_print_whole_tree_preorder_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
;
; input:
;	 CS:SI - pointer to node
; output:
;		none
integers_print_whole_tree_inorder:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je integers_print_whole_tree_inorder_done
	
	push cs
	pop es
	mov di, integers_print_one_subtree_callback
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_subtree_foreach_inorder
	
integers_print_whole_tree_inorder_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
;
; input:
;		none
; output:
;		none
integers_print_bst_inorder:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je integers_print_bst_inorder_done
	
	push cs
	pop es
	mov di, integers_print_one_subtree_callback
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_subtree_foreach_inorder
integers_print_bst_inorder_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
;
; input:
;		none
; output:
;		none
integers_print_bst_inorder_byte:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je integers_print_bst_inorder_byte_done
	
	push cs
	pop es
	mov di, integers_print_one_subtree_callback_byte
	
	mov cx, 1
	call common_dynbintree_subtree_foreach_inorder
integers_print_bst_inorder_byte_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
;
; input:
;		AX - integer to add
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to new node
integers_bst_add_word:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_add_word		; DS:SI := new node
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;		SI - near pointer to string to add
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to new node
strings_bst_add:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push gs
	
	push cs
	pop es						
	mov di, si					; DS:SI := string to add
	
	push cs
	pop gs
	mov dx, string_comparator
	
	mov cx, STRINGS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, stringsRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_add		; DS:SI := new node
	
	pop gs
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;		SI - near pointer to string to look up
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to node
strings_bst_find:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push gs
	
	push cs
	pop es						
	mov di, si					; DS:SI := string to add
	
	push cs
	pop gs
	mov dx, string_comparator
	
	mov cx, STRINGS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, stringsRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_find		; DS:SI := new node
	
	pop gs
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;		SI - near pointer to string to remove
; output:
;		AX - 0 on failure, other value on success
strings_bst_remove:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs
	push gs
	
	push cs
	pop es						
	mov di, si					; DS:SI := string to remove
	
	push cs
	pop gs
	mov dx, string_comparator
	
	mov cx, STRINGS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, stringsRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_remove		; DS:SI := 
	
	pop gs
	pop fs
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
;
; input:
;		none
; output:
;		none
integers_bst_word_clear:
	pusha
	push ds
	push es
	push fs
	push gs
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_clear
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; input:
;		none
; output:
;		none
integers_bst_byte_clear:
	pusha
	push ds
	push es
	push fs
	push gs
	
	mov cx, 1
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_clear
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
;
; input:
;		AX - integer to find
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to new node
integers_bst_find_word:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_find_word		; DS:SI := new node
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;		AX - integer to find
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to new node
integers_bst_find_byte:
	push bx
	push cx
	push dx
	push di
	push es
	push fs

	mov cx, INTEGERS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_find_byte		; DS:SI := new node
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
;
; input:
;		AL - integer to add
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to new node
integers_bst_add_byte:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_add_byte		; DS:SI := new node
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
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
;		AX - 0 when traversal must stop, other value otherwise
integers_print_one_subtree_callback:
	mov word [cs:printNodeSeg], ds
	mov word [cs:printNodeOff], si

	mov cl, 1						; formatting
	mov ax, dx
	mov dx, 0
	call common_text_print_number	; print depth
	
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	call common_text_print_number

	; print parent?
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_get_parent
	cmp ax, 0
	jne integers_print_one_subtree_callback_print_parent
	
	push cs
	pop ds
	mov si, msgRoot
	int 97h
	jmp integers_print_one_subtree_callback_print_children
integers_print_one_subtree_callback_print_parent:
	mov cl, 1						; formatting
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := parent word

	push cs
	pop ds
	mov si, msgParent1
	int 97h
	call common_text_print_number	; print parent word
	mov si, msgParent2
	int 97h
integers_print_one_subtree_callback_print_children:	
	
	push cs
	pop ds
	mov si, msgLeft
	int 97h
	
	push word [cs:printNodeSeg]
	pop ds
	mov si, word [cs:printNodeOff]
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_get_left_child
	cmp ax, 0
	je integers_print_one_subtree_callback_print_children_right
	
	mov cl, 1
	mov dx, 0
	mov ax, word [ds:si]
	call common_text_print_number
integers_print_one_subtree_callback_print_children_right:
	push cs
	pop ds
	mov si, msgRight
	int 97h
	
	push word [cs:printNodeSeg]
	pop ds
	mov si, word [cs:printNodeOff]	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_get_right_child
	cmp ax, 0
	je integers_print_one_subtree_callback_print_children_done
	
	mov cl, 1
	mov dx, 0
	mov ax, word [ds:si]
	call common_text_print_number
integers_print_one_subtree_callback_print_children_done:
	push cs
	pop ds
	mov si, msgNewline
	int 97h
	mov ax, 1						; continue traversal
	retf

	
; just for bytes
;
;
integers_print_one_subtree_callback_byte:
	mov cl, 1						; formatting
	
	mov ax, dx
	mov dx, 0
	;call common_text_print_number	; print depth
	
	mov dx, 0
	mov al, byte [ds:si]			; DX:AX := payload
	mov ah, 0
	call common_text_print_number
	
	mov ax, 1						; success
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
;		AX - 0 when traversal must stop, other value otherwise
strings_print_one_subtree_callback:
	mov cl, 1						; formatting
	
	mov ax, dx
	mov dx, 0
	;call common_text_print_number	; print depth
	int 97h							; print string
	mov ax, 1						; continue traversal
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
	
	
; A built-in comparator for unsigned words
;
; input:
;	 DS:SI - pointer to first node
;	 ES:DI - pointer to second node
; output:
;		AX - -1 when first node precedes second node
;             0 when first node equals second node
;             1 when first node succeeds second node
string_comparator:
	int 0BDh					; AX := 0 (equal), 1 (first < second), else 2
	cmp ax, 1
	je string_comparator_less
	cmp ax, 2
	je string_comparator_greater 
	mov ax, 0
	jmp string_comparator_done
string_comparator_greater:
	mov ax, 1
	jmp string_comparator_done
string_comparator_less:
	mov ax, -1
	jmp string_comparator_done
string_comparator_done:
	retf
	

%define _COMMON_MEMORY_CONFIG_			; override default chunk count value
COMMON_MEMORY_MAX_CHUNKS	equ 1000

%include "common\memory.asm"
%include "common\dynamic\dyn_bst.asm"
%include "common\text.asm"
	
	
dynamicMemoryStart:
