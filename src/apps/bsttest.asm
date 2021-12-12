;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BSTTEST app.
; This application tests Snowdrop OS's BST library interactively.
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

	
AVAILABLE_DYN_MEM		equ 60000

builtInTreeData:		dw 50, 25, 75, 12, 37, 62, 87, 6, 18, 30, 43, 56, 68, 80, 94, 4, 8, 2
builtInTreeData_end:

msgNewline:				db 13, 10, 0
msgBlank:				db ' ', 0
msgStatsHeight:			db '(height: ', 0
msgStatsNodes:			db '  nodes: ', 0
msgStatsMemory:			db '  memory: ', 0
msgBytes:				db ' bytes)', 0
msgEnterCommand:		db 'Enter command: ', 0
msgTitle:				db 'Snowdrop OS BST library test', 0
msgTitleEnd:
msgHorizontalLine:		db 196, 0
msgInstructions:		db 'A <nr> - add   D <nr> - delete   F <nr> - find            (numbers 0 to 99 only)'
						db 'C - clear      T - traverse      M - load built-in tree    X - exit', 0
msgTraversal:			db 'Inorder: ', 0

TITLE_STRING_LENGTH		equ msgTitleEnd - msgTitle

COMMON_DYNBST_ROOT_PTR_LENGTH_2 equ COMMON_DYNBST_ROOT_PTR_LENGTH
COMMON_DYNBST_ROOT_PTR_INITIAL_2 equ COMMON_DYNBST_ROOT_PTR_INITIAL

; our tree's root
integersRoot:	times COMMON_DYNBST_ROOT_PTR_LENGTH_2 db COMMON_DYNBST_ROOT_PTR_INITIAL_2
								; by convention, consumer applications must 
								; declare and pass this address to linked 
								; list functions

integersPayload:		dw 0	; stores elements we're adding
INTEGERS_PAYLOAD_SIZE	equ 2	; each element holds this many bytes

; this list holds ancestors of a found node (via "find" command), so they
; can be drawn in a different colour
COMMON_LLIST_HEAD_PTR_LENGTH_2	equ COMMON_LLIST_HEAD_PTR_LENGTH
COMMON_LLIST_HEAD_PTR_INITIAL_2	equ COMMON_LLIST_HEAD_PTR_INITIAL
findNodeAncestorsListHeadPtr:	times COMMON_LLIST_HEAD_PTR_LENGTH_2 db COMMON_LLIST_HEAD_PTR_INITIAL_2
PTR_SIZE						equ 4			; seg:off
findNodeTempBuffer:				times 2 dw 0	; used when finding nodes
findNodeSeg:					dw 0
findNodeOff:					dw 0
isAncestor:						dw 0
hasRoot:						db 0

MAX_INPUT			equ 4
commandBuffer:		times MAX_INPUT + 1 db 'P'

; commands
C_NONE				equ 0
C_TRAVERSE			equ 1
C_ADD				equ 2
C_DELETE			equ 3
C_CLEAR				equ 4
C_FIND				equ 5
C_DEFAULT_TREE		equ 6

treeMaxDepth:			dw 0
treeNodeCount:			dw 0

; used when drawing the tree
currentColumn:			db 0
DRAW_TREE_ROOT_ROW		equ 4
DRAW_TREE_LEFT_LIMIT	equ 3
DRAW_TREE_DELTA_X		equ 3


start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 83h						; clear keyboard buffer

	; we use a different segment for our dynamic memory to test that
	; libraries (BST and beneath) correctly preserve segment registers
	call common_task_allocate_memory_or_exit	; BX := segment
	
	mov ds, bx
	mov si, 0					; DS:SI := pointer to start of dynamic memory
	mov ax, AVAILABLE_DYN_MEM	; maximum allocatable bytes
	call common_memory_initialize
	cmp ax, 0
	je exit
	
	push cs
	pop ds							; restore it
	
	call load_default_tree
	
	mov bx, C_NONE					; default to no command initially
main_loop:
	call clear_find_node
	int 0A0h						; clear screen
	call draw_screen

main_loop_try_add:
	cmp bx, C_ADD
	jne main_loop_try_default_tree
	call integers_bst_add_word		; add node in AX
	jmp main_loop_draw_tree
	
main_loop_try_default_tree:
	cmp bx, C_DEFAULT_TREE
	jne main_loop_try_delete
	call load_default_tree
	jmp main_loop_draw_tree
	
main_loop_try_delete:
	cmp bx, C_DELETE
	jne main_loop_try_clear
	call integers_bst_remove_word	; remove node in AX
	jmp main_loop_draw_tree
	
main_loop_try_clear:
	cmp bx, C_CLEAR
	jne main_loop_draw_tree
	call integers_bst_word_clear
	jmp main_loop_draw_tree

main_loop_draw_tree:
	cmp bx, C_FIND
	jne main_loop_draw_tree_0
	call find_node					; find node in AX

main_loop_draw_tree_0:	
	call draw_tree
	
	; after tree, show traversal, if that was the command
	cmp bx, C_TRAVERSE
	jne main_loop_get_command
	call traverse_inorder
	
main_loop_get_command:	
	call get_command			; BX := command, AX := number, if applicable
	jmp main_loop
	
exit:
	; exit program
	int 95h						; exit
	

; Loads the built-in tree
;
; input:
;	 	none
; output:
;		none
load_default_tree:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call integers_bst_word_clear
	
	cld
	mov cx, (builtInTreeData_end - builtInTreeData) / 2
															; 2 bytes per word
	push cs
	pop ds
	mov si, builtInTreeData
load_default_tree_loop:
	lodsw								; AX := node data
	dec cx
	push ds
	push si
	call integers_bst_add_word
	pop si
	pop ds
	jcxz load_default_tree_done
	jmp load_default_tree_loop
	
load_default_tree_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	ret
	

; Reads a command from user
;
; input:
;	 	none
; output:
;		AX - number, if applicable
;		BX - command
get_command:
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	mov bh, COMMON_SCREEN_HEIGHT-1			; row
	mov bl, 0
	int 9Eh									; move cursor

	push cs
	pop ds
	
	mov si, msgEnterCommand
	int 97h
	
	; command box
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_BLUE | COMMON_FONT_BRIGHT
	mov cx, MAX_INPUT				; this many characters
	int 9Fh							; write attributes
	
	; hide cursor on last character
	mov bh, COMMON_SCREEN_HEIGHT-1			; row
	mov bl, 15 + MAX_INPUT
	int 9Eh									; move cursor
	mov dl, COMMON_FONT_COLOUR_BLACK | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, 1						; this many characters
	int 9Fh							; write attributes
	
	mov bh, COMMON_SCREEN_HEIGHT-1			; row
	mov bl, 30
	int 9Eh									; move cursor
	
	mov si, msgStatsHeight
	int 97h
	mov cl, 3								; formatting
	mov dx, 0
	mov ax, word [cs:treeMaxDepth]

	cmp byte [cs:hasRoot], 0
	je get_command_print_height				; no root, so height = 0
	inc ax									; height := depth + 1
get_command_print_height:
	call common_text_print_number
	
	mov si, msgStatsNodes
	int 97h
	
	mov ax, word [cs:treeNodeCount]
	call common_text_print_number
	
	mov si, msgStatsMemory
	int 97h
	
	call common_memory_stats
	mov cl, 3								; formatting
	mov ax, AVAILABLE_DYN_MEM
	sub ax, bx								; AX := in-use memory
	mov dx, 0
	call common_text_print_number
	
	mov si, msgBytes
	int 97h
	
	mov bh, COMMON_SCREEN_HEIGHT-1			; row
	mov bl, 15
	int 9Eh									; move cursor
	
	push cs
	pop es
	mov di, commandBuffer
	mov cx, MAX_INPUT
	int 0A4h					; read input from user
	
	cmp byte [cs:commandBuffer], 'A'
	je get_command_add
	cmp byte [cs:commandBuffer], 'a'
	je get_command_add
	
	cmp byte [cs:commandBuffer], 'D'
	je get_command_delete
	cmp byte [cs:commandBuffer], 'd'
	je get_command_delete
	
	cmp byte [cs:commandBuffer], 'T'
	je get_command_traverse
	cmp byte [cs:commandBuffer], 't'
	je get_command_traverse
	
	cmp byte [cs:commandBuffer], 'C'
	je get_command_clear
	cmp byte [cs:commandBuffer], 'c'
	je get_command_clear
	
	cmp byte [cs:commandBuffer], 'F'
	je get_command_find
	cmp byte [cs:commandBuffer], 'f'
	je get_command_find
	
	cmp byte [cs:commandBuffer], 'M'
	je get_command_default_tree
	cmp byte [cs:commandBuffer], 'm'
	je get_command_default_tree
	
	cmp byte [cs:commandBuffer], 'X'
	je exit
	cmp byte [cs:commandBuffer], 'x'
	je exit
	
	mov bx, C_NONE
	jmp get_command_done
	
get_command_add:
	add di, 2					; ES:DI := ptr to number
	push es
	pop ds
	mov si, di					; DS:SI := ptr to number
	
	int 0BEh					; AX := integer
	mov bx, C_ADD
	jmp get_command_done
	
get_command_default_tree:
	mov bx, C_DEFAULT_TREE
	jmp get_command_done
	
get_command_delete:
	add di, 2					; ES:DI := ptr to number
	push es
	pop ds
	mov si, di					; DS:SI := ptr to number
	
	int 0BEh					; AX := integer
	mov bx, C_DELETE
	jmp get_command_done
	
get_command_find:
	add di, 2					; ES:DI := ptr to number
	push es
	pop ds
	mov si, di					; DS:SI := ptr to number
	
	int 0BEh					; AX := integer
	mov bx, C_FIND
	jmp get_command_done
	
get_command_traverse:
	mov bx, C_TRAVERSE
	jmp get_command_done
	
get_command_clear:
	mov bx, C_CLEAR
	jmp get_command_done
	
get_command_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	ret


; Draws entire screen
;
; input:
;	 	none
; output:
;		none
draw_screen:
	pusha
	push ds
	push es
	push fs

	; draw title bar
	mov bh, 0								; row
	mov bl, 0
	int 9Eh									; move cursor
	
	push cs
	pop ds
	
	mov si, msgHorizontalLine
	mov ch, 0
	mov cl, COMMON_SCREEN_WIDTH
draw_screen_title_bar:
	int 97h
	loop draw_screen_title_bar
	
	mov si, msgTitle
	mov bh, 0								; row
	mov bl, COMMON_SCREEN_WIDTH / 2 - TITLE_STRING_LENGTH / 2 - 2
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title
	
	; draw instructions
	mov bh, 1								; row
	mov bl, 0
	int 9Eh									; move cursor
	
	mov si, msgInstructions
	int 97h
	
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Resets all setup potentially made to find a node
;
; input:
;	 	none
; output:
;		none
clear_find_node:
	pusha
	push ds
	push es
	push fs

	; clear stack which holds ancestors
	push cs
	pop fs
	mov bx, findNodeAncestorsListHeadPtr
	mov cx, PTR_SIZE
	call common_llist_clear
	
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Sets up appropriately so that when the tree is drawn, the node to find
; and all its ancestors are highlighted
;
; input:
;	 	AX - node to search
; output:
;		none
find_node:
	pusha
	push ds
	push es
	push fs

	; find it
	call integers_bst_find_word					; DS:SI := ptr to node
	cmp ax, 0									; found?
	je find_node_done							; no, so we're done
	push ds
	push si										; [1]
	
	; insert it and all its ancestors in list
	push cs
	pop es
	mov di, findNodeTempBuffer
	mov word [es:di+0], ds
	mov word [es:di+2], si						; store pointer
	push cs
	pop fs
	mov bx, findNodeAncestorsListHeadPtr
	mov cx, PTR_SIZE
	call common_llist_add						; insert found node in list
	
	pop si
	pop ds										; [1]
	mov cx, INTEGERS_PAYLOAD_SIZE
	mov di, collect_ancestors_callback
	call common_dynbintree_subtree_foreach_ancestor	; insert its ancestors
	
find_node_done:
	pop fs
	pop es
	pop ds
	popa
	ret


; Traverses in inorder and prints each node
;
; input:
;	 	none
; output:
;		none
traverse_inorder:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je traverse_inorder_done		; NOOP if no root
	
	mov bx, DRAW_TREE_ROOT_ROW		; start from this row
	mov dx, word [cs:treeMaxDepth]
	shl dx, 1
	add bx, dx						; BX := row
	xchg bh, bl						; BH := (byte)row
	mov bl, 0						; BL := column
	int 9Eh							; move cursor
	
	push cs
	pop ds
	mov si, msgNewline
	int 97h
	int 97h
	mov si, msgTraversal
	int 97h
	
	push cs
	pop fs
	mov bx, integersRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je traverse_inorder_done
	
	push cs
	pop es
	mov di, integers_print_one_callback
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_subtree_foreach_inorder
	
	int 83h							; clear keyboard buffer
	mov ah, 0
	int 16h							; wait for key
traverse_inorder_done:
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Draws the tree
;
; input:
;	 	none
; output:
;		none
draw_tree:
	pusha
	push ds
	push es
	push fs

	mov byte [cs:hasRoot], 0
	mov word [cs:treeNodeCount], 0
	mov word [cs:treeMaxDepth], 0
	
	push cs
	pop fs
	mov bx, integersRoot
	call common_dynbintree_get_root
	cmp ax, 0
	je draw_tree_done
	
	mov byte [cs:hasRoot], 1
	
	push cs
	pop es
	mov di, integers_draw_node_callback
	
	mov byte [cs:currentColumn], DRAW_TREE_LEFT_LIMIT
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	call common_dynbintree_subtree_foreach_inorder
	
draw_tree_done:
	pop fs
	pop es
	pop ds
	popa
	ret


; Adds a word to the BST	
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
	
	cmp ax, 99
	ja integers_bst_add_word_fail
	
	mov cx, INTEGERS_PAYLOAD_SIZE
	push cs
	pop fs
	mov bx, integersRoot			; FS:BX := pointer to pointer to root
	call common_dynbst_add_word		; DS:SI := new node
	cmp ax, 0
	je integers_bst_add_word_fail
	jmp integers_bst_add_word_success

integers_bst_add_word_fail:
	mov ax, 0
	je integers_bst_add_word_done
integers_bst_add_word_success:
	mov ax, 1
integers_bst_add_word_done:
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret

	
; Removes a word from the BST	
;
; input:
;		AX - integer to remove
; output:
;		AX - 0 on failure, other value on success
integers_bst_remove_word:
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
	call common_dynbst_remove_word
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	

; Removes all nodes from the BST
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


; Finds a word in the BST	
;
; input:
;		AX - integer to find
; output:
;		AX - 0 on failure, other value on success
;	 DS:SI - pointer to node
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

	
; Callback for print a list of nodes on screen
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
integers_print_one_callback:
	mov cl, 3						; formatting
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	call common_text_print_number

	push cs
	pop ds
	mov si, msgBlank
	int 97h
	
	mov ax, 1						; continue traversal
	retf
	

; Checks whether the specified node is an ancestor	
;
; input:
;		DS:SI - node to check
; output:
;		AX - 0 when node is an ancestor, other value otherwise
is_ancestor:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	mov word [cs:findNodeSeg], ds
	mov word [cs:findNodeOff], si
	mov word [cs:isAncestor], 0

	push cs
	pop fs
	mov bx, findNodeAncestorsListHeadPtr
	push cs
	pop ds
	mov si, is_ancestor_callback
	mov cx, PTR_SIZE
	call common_llist_foreach

	mov ax, word [cs:isAncestor]

	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	ret
	
	
; Callback for drawing the tree
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
integers_draw_node_callback:
	inc word [cs:treeNodeCount]
	
	cmp dx, word [cs:treeMaxDepth]
	jb integers_draw_node_callback_got_depth
	mov word [cs:treeMaxDepth], dx	; new maximum, so store it
	
integers_draw_node_callback_got_depth:
	mov bx, DRAW_TREE_ROOT_ROW		; start from this row
	shl dx, 1
	add bx, dx						; BX := row
	xchg bh, bl						; BH := (byte)row
	mov bl, byte [cs:currentColumn]	; BL := column
	int 9Eh							; move cursor
	
	mov dl, COMMON_FONT_COLOUR_MAGENTA | COMMON_BACKGROUND_COLOUR_BLACK | COMMON_FONT_BRIGHT
	call is_ancestor
	cmp ax, 0
	je integers_draw_node_callback_print
	
	; this is an ancestor of a found node, so change its colour
	mov dl, COMMON_FONT_COLOUR_GREEN | COMMON_BACKGROUND_COLOUR_BLACK | COMMON_FONT_BRIGHT
	
integers_draw_node_callback_print:	
	mov cx, DRAW_TREE_DELTA_X		; this many characters
	int 9Fh							; write attributes
	
	mov cl, 3						; formatting
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	call common_text_print_number
	
	add byte [cs:currentColumn], DRAW_TREE_DELTA_X
	
	mov ax, 1						; continue traversal
	retf
	
	

; Inserts node into list
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;
; input:
;	 DS:SI - pointer to currently-iterated node
; output:
;		none
collect_ancestors_callback:
	push cs
	pop es
	mov di, findNodeTempBuffer
	mov word [es:di+0], ds
	mov word [es:di+2], si						; store pointer
	push cs
	pop fs
	mov bx, findNodeAncestorsListHeadPtr
	mov cx, PTR_SIZE
	call common_llist_add						; insert node in list
	retf


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
;		AX - 0 when traversal must stop, other value otherwise
is_ancestor_callback:
	mov ax, word [ds:si+0]
	cmp ax, word [cs:findNodeSeg]		; match on segment?
	jne is_ancestor_callback_no
	
	mov ax, word [ds:si+2]
	cmp ax, word [cs:findNodeOff]		; match on offset?
	jne is_ancestor_callback_no

	mov word [cs:isAncestor], 1
	mov ax, 0							; we found it
	retf
is_ancestor_callback_no:
	mov ax, 1							; continue traversing
	retf


%define _COMMON_MEMORY_CONFIG_			; override default chunk count value
COMMON_MEMORY_MAX_CHUNKS	equ 300

%include "common\colours.asm"
%include "common\screen.asm"
%include "common\textbox.asm"
%include "common\tasks.asm"
%include "common\memory.asm"
%include "common\dynamic\dyn_bst.asm"
%include "common\dynamic\linklist.asm"
%include "common\text.asm"
