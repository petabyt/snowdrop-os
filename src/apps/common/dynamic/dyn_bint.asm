;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains a library for working with binary trees allocated via 
; dynamic memory.
; Calls whose name includes "subtree" operate on multiple nodes.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DYNAMIC_BINARY_TREES_
%define _COMMON_DYNAMIC_BINARY_TREES_

; The consumer declares a treeRootPtr as shown below. It holds exclusively
; overhead bytes, to point at the root, and indicate whether the
; root exists or not.
; By declaring multiple root pointers, a consumer application can
; create and operate on multiple trees.
; The consumer application is expected to not modify these bytes.
;
;     treeRootPtr:	times COMMON_DYNBINTREE_ROOT_PTR_LENGTH db COMMON_DYNBINTREE_ROOT_PTR_INITIAL
;
; Since %includes are often at the end of the file (because the initial jmp
; cannot be too long), in NASM I tend to define for example:
;     COMMON_DYNBINTREE_ROOT_PTR_LENGTH_2 equ COMMON_DYNBINTREE_ROOT_PTR_LENGTH
;     COMMON_DYNBINTREE_ROOT_PTR_INITIAL_2 equ COMMON_DYNBINTREE_ROOT_PTR_INITIAL
; to get over the "non-constant supplied to times" error.
; Then I define treeRootPtr based on those instead.
;
; Whenever tree functions are invoked, the consumer application provides
; a pointer to a pointer to the root like so:
; 
;     push cs
;     pop fs
;     mov bx, treeRootPtr				; FS:BX := pointer to pointer to head
;
; Also, the size (in bytes) of a node must be passed in like so:
;
;     mov cx, NODE_SIZE					; size of a node, in bytes
;										; consumers applications are expected
;										; to not access any of an node's
;										; bytes past this count
; And then:
;
;     call common_dynbintree_...
;
; NOTE: The consumer should NOT call N-ary tree functions on binary tree
;       nodes, as their behaviour is undefined.

; A tree node contains the consumer payload as the first X bytes (where X is
; the size of a node, as far as the consumer is concerned).
; Following that, there are overhead bytes used to organize the tree.
; 
; offset past last consumer byte                                what it stores
;                          0 - 0                        binary tree node flags

; head pointer structure is no different than for an N-ary tree
COMMON_DYNBINTREE_ROOT_PTR_LENGTH		equ COMMON_DYNTREE_ROOT_PTR_LENGTH
COMMON_DYNBINTREE_ROOT_PTR_INITIAL		equ COMMON_DYNTREE_ROOT_PTR_INITIAL

CBINTREE_MAX_NODE_SIZE			equ 19800	; in bytes

CBINTREE_OVERHEAD_BYTES			equ 1	; overhead used by the binary trees
										; library on each node
CBINTREE_FLAG_IS_LEFT_CHILD		equ 1	; whether the node is the left child
										; no meaning when node is root

commonBinTreeNoMemory:	db 'FATAL: Must initialize dynamic memory module before using binary tree functionality.'
					db 13, 10
					db 'Press a key to exit', 0

CBINTREE_DYNSTACK_HEAD_PTR_LENGTH	equ COMMON_DYNSTACK_HEAD_PTR_LENGTH

; this represents an entry on the stack(s) used for traversals
; it contains information that is passed on to callbacks:
;       offset                              details
;          0-1           segment of pointer to node
;          2-3            offset of pointer to node
;          4-5                           node depth
CBINTREE_NODE_PTR_SIZE				equ 6

cbintreePtrTempStorage:	times CBINTREE_NODE_PTR_SIZE db 0
cbintreeStackHeadPtr:	times CBINTREE_DYNSTACK_HEAD_PTR_LENGTH db COMMON_DYNSTACK_HEAD_PTR_INITIAL

cbintreeCallbackReturnAx:	dw 0		; used to check callback return values


; Copies the children of a node to another node
;
; input:
;	 DS:SI - pointer to source node
;	 ES:DI - pointer to destination node
;		CX - element length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbintree_copy_children:
	push cx

	call cbintree_assert_memory
	
	mov ax, 0
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dynbintree_copy_children_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_copy_children
common_dynbintree_copy_children_done:
	pop cx
	ret


; Invokes a callback function for each node that is the specified node,
; or a descendant of the specified node.
; The tree is traversed in inorder (left then node then right).
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to currently-iterated node
;                       DX - depth relative to specified node
;        callback output:
;                       AX - 0 when traversal must stop, other value otherwise
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,900 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dynbintree_subtree_foreach_inorder:
	pusha
	push ds
	push es
	push fs
	push gs
	
	call cbintree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_foreach_inorder_done
	
	; inorder traversal algorithm:
	;
	; NODE := root
	; do
	;     if NODE is not null
	;         stack.push NODE
	;         while NODE.left is not null
	;             NODE := NODE.left
	;             stack.push NODE
	;
	;     NODE := stack.pop
	;     (act on NODE)
	;     NODE := NODE.right
	; while (stack not empty) OR (NODE is not null)
	
	; invariant: DS:SI is the current node
	mov dx, -1									; specified node is at depth 0
common_dynbintree_subtree_foreach_inorder_outer:
	inc dx										; depth++
	; node is not null
	
	call cbintree_stack_push					; push node
	cmp ax, 0
	je common_dynbintree_subtree_foreach_inorder_done
	
common_dynbintree_subtree_foreach_inorder_inner:
	call common_dynbintree_get_left_child		; DS:SI := ptr to left child
	cmp ax, 0
	je common_dynbintree_subtree_foreach_inorder_inner_end
	inc dx										; depth++

	call cbintree_stack_push					; push node
	cmp ax, 0
	je common_dynbintree_subtree_foreach_inorder_done
	
	jmp common_dynbintree_subtree_foreach_inorder_inner	; next left

common_dynbintree_subtree_foreach_inorder_inner_end:
	call cbintree_stack_pop						; DS:SI := node
												; DX := depth
	cmp ax, 0
	je common_dynbintree_subtree_foreach_inorder_done
	
	; BEGIN WORK ON NODE

	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; 1. setup return address
	push cs
	push word common_dynbintree_subtree_foreach_inorder_callback_return
												; return address on stack
	; 2. setup "call far" site address
	push es			; callback segment
	push di			; callback offset
	
	; 3. setup callback arguments
	; here, DS:SI = pointer to node
	; here, DX = node depth
	
	; 4. invoke callback
	retf			; "call far"
	; once the callback executes its own retf, execution returns below
common_dynbintree_subtree_foreach_inorder_callback_return:
	mov word [cs:cbintreeCallbackReturnAx], ax
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	
	; END WORK ON NODE
	
	cmp word [cs:cbintreeCallbackReturnAx], 0
	je common_dynbintree_subtree_foreach_inorder_done	; callback said "stop"
	
	call common_dynbintree_get_right_child		; DS:SI := ptr to right child
	cmp ax, 0
	jne common_dynbintree_subtree_foreach_inorder_outer	; we have a right child
														; so we iterate outer
														; again
	; no right child, so we check if stack still has nodes
	call cbintree_stack_has_any
	cmp ax, 0
	jne common_dynbintree_subtree_foreach_inorder_inner_end
	
common_dynbintree_subtree_foreach_inorder_done:
	call cbintree_stack_clear
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret


; Adds the payload as a new node, becoming left child of the specified node
;
; input:
;	 ES:DI - pointer to payload to add as a new node
;		CX - payload length, in bytes, maximum 19,800 bytes
;	 DS:SI - pointer to node that will be the parent of new node
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dynbintree_add_left_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_add_left_child_fail
	
	call common_dynbintree_has_left_child
	cmp ax, 0
	jne common_dynbintree_add_left_child_fail		; already has
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_add_child
	cmp ax, 0
	je common_dynbintree_add_left_child_fail
	
	sub cx, CBINTREE_OVERHEAD_BYTES					; CX := payload length
	mov bx, cx
	
	or byte [ds:si+bx+0], CBINTREE_FLAG_IS_LEFT_CHILD
	
	jmp common_dynbintree_add_left_child_success
	
common_dynbintree_add_left_child_fail:
	mov ax, 0
	jmp common_dynbintree_add_left_child_done
common_dynbintree_add_left_child_success:
	mov ax, 1
common_dynbintree_add_left_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Adds the payload as a new node, becoming right child of the specified node
;
; input:
;	 ES:DI - pointer to payload to add as a new node
;		CX - payload length, in bytes, maximum 19,800 bytes
;	 DS:SI - pointer to node that will be the parent of new node
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dynbintree_add_right_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_add_right_child_fail
	
	call common_dynbintree_has_right_child
	cmp ax, 0
	jne common_dynbintree_add_right_child_fail		; already has
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_add_child
	cmp ax, 0
	je common_dynbintree_add_right_child_fail
	
	sub cx, CBINTREE_OVERHEAD_BYTES					; CX := payload length
	mov bx, cx
	
	mov al, CBINTREE_FLAG_IS_LEFT_CHILD
	xor al, 0FFh
	and byte [ds:si+bx+0], al
	
	jmp common_dynbintree_add_right_child_success
	
common_dynbintree_add_right_child_fail:
	mov ax, 0
	jmp common_dynbintree_add_right_child_done
common_dynbintree_add_right_child_success:
	mov ax, 1
common_dynbintree_add_right_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Changes the parent of the specified node, making the specified node
; the new parent's left child
;
; input:
;	 DS:SI - pointer to node to move
;	 ES:DI - pointer to node to become the new parent
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to moved node, when successful
common_dynbintree_change_parent_as_left_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_change_parent_as_left_child_fail
	
	call cbintree_is_root
	cmp ax, 0
	jne common_dynbintree_change_parent_as_left_child_fail	; can't move root
	
	push ds
	push si											; [1] save node to move
	
	push es
	pop ds
	mov si, di										; DS:SI := destination
	call common_dynbintree_has_left_child			; [*]
	
	pop si
	pop ds											; [1] DS:SI := node to move
	cmp ax, 0										; [*]
	jne common_dynbintree_change_parent_as_left_child_fail	; already has left
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_change_parent				; DS:SI := moved node
	cmp ax, 0
	je common_dynbintree_change_parent_as_left_child_fail
	
	; we successfully moved node, so now mark it as left child
	sub cx, CBINTREE_OVERHEAD_BYTES					; CX := payload length
	mov bx, cx
	
	or byte [ds:si+bx+0], CBINTREE_FLAG_IS_LEFT_CHILD
	jmp common_dynbintree_change_parent_as_left_child_success
	
common_dynbintree_change_parent_as_left_child_fail:
	mov ax, 0
	jmp common_dynbintree_change_parent_as_left_child_done
common_dynbintree_change_parent_as_left_child_success:
	mov ax, 1
common_dynbintree_change_parent_as_left_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Changes the parent of the specified node, making the specified node
; the new parent's right child
;
; input:
;	 DS:SI - pointer to node to move
;	 ES:DI - pointer to node to become the new parent
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to moved node, when successful
common_dynbintree_change_parent_as_right_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_change_parent_as_right_child_fail
	
	call cbintree_is_root
	cmp ax, 0
	jne common_dynbintree_change_parent_as_right_child_fail	; can't move root
	
	push ds
	push si											; [1] save node to move
	
	push es
	pop ds
	mov si, di										; DS:SI := destination
	call common_dynbintree_has_right_child			; [*]
	
	pop si
	pop ds											; [1] DS:SI := node to move
	cmp ax, 0										; [*]
	jne common_dynbintree_change_parent_as_right_child_fail	; already has right
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_change_parent				; DS:SI := moved node
	cmp ax, 0
	je common_dynbintree_change_parent_as_right_child_fail
	
	; we successfully moved node, so now mark it as right child
	sub cx, CBINTREE_OVERHEAD_BYTES					; CX := payload length
	mov bx, cx
	
	mov al, CBINTREE_FLAG_IS_LEFT_CHILD
	xor al, 0FFh
	and byte [ds:si+bx+0], al
	jmp common_dynbintree_change_parent_as_right_child_success
	
common_dynbintree_change_parent_as_right_child_fail:
	mov ax, 0
	jmp common_dynbintree_change_parent_as_right_child_done
common_dynbintree_change_parent_as_right_child_success:
	mov ax, 1
common_dynbintree_change_parent_as_right_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Checks whether the specified node has a right child
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when node doesn't have a right child, other value otherwise
common_dynbintree_has_right_child:
	push ds
	push si
	call common_dynbintree_get_right_child
	pop si
	pop ds
	ret
	
	
; Checks whether the specified node has a left child
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when node doesn't have a left child, other value otherwise
common_dynbintree_has_left_child:
	push ds
	push si
	call common_dynbintree_get_left_child
	pop si
	pop ds
	ret
	
	
; Sets the root via pointer.
;
; NOTE: old root, if existing, is orphaned
;
; input:
;	 FS:BX - pointer to pointer to root
;	 DS:SI - pointer to new root
; output:
;		none
common_dynbintree_set_root_by_ptr:
	call common_dyntree_set_root_by_ptr
	ret
	

; Swaps the children of the specified node so:
;     - the right child (if exists) becomes the left child
;     - the left child (if exists) becomes the right child
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbintree_swap_children:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_swap_children_fail
	
	push ds
	push si									; [1] save node
	
	call common_dynbintree_get_left_child	; DS:SI := left child
	mov dx, ax								; [*] DX := left child exists?
	push ds
	pop es
	mov di, si								; ES:DI := left child
	
	pop si
	pop ds									; [1] DS:SI := node
	call common_dynbintree_get_right_child	; DS:SI := right child
	cmp ax, 0								; does right child exist?
	je common_dynbintree_swap_children__modify_left	; no, so process left
common_dynbintree_swap_children__modify_right:
	; right child exists, so swap it
	add si, cx								; DS:SI := ptr to binary overhead
	or byte [ds:si+0], CBINTREE_FLAG_IS_LEFT_CHILD
	; flow into left
common_dynbintree_swap_children__modify_left:
	cmp dx, 0								; [*] did it have a left child?
	je common_dynbintree_swap_children_success	; no, so we're done
	; left child exists, so swap it
	add di, cx								; ES:DI := ptr to binary overhead
	mov al, CBINTREE_FLAG_IS_LEFT_CHILD
	xor al, 0FFh
	and byte [es:di+0], al
	jmp common_dynbintree_swap_children_success
common_dynbintree_swap_children_fail:
	mov ax, 0
	jmp common_dynbintree_swap_children_done
common_dynbintree_swap_children_success:
	mov ax, 1
common_dynbintree_swap_children_done:
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


; Returns a pointer to root's left child node.
; This call is useful after root is replaced via common_dynbintree_add_root,
; for the consumer to get a pointer to the reallocated old root node.
;
; input:
;	 FS:BX - pointer to pointer to root
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to root's left child node, if any
common_dynbintree_get_roots_left_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_get_roots_left_child_fail
	
	call common_dynbintree_get_root				; DS:SI := ptr to root
	cmp ax, 0
	je common_dynbintree_get_roots_left_child_fail
	
	call common_dynbintree_get_left_child		; DS:SI := ptr to left child
	cmp ax, 0
	je common_dynbintree_get_roots_left_child_fail
	
	jmp common_dynbintree_get_roots_left_child_success
	
common_dynbintree_get_roots_left_child_fail:
	mov ax, 0
	jmp common_dynbintree_get_roots_left_child_done
common_dynbintree_get_roots_left_child_success:
	mov ax, 1
common_dynbintree_get_roots_left_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Searches the specified subtree for a string, looking in the payload
; at the specified offset
;
; input:
;	 DS:SI - pointer to root node of subtree
;		CX - element length, in bytes, maximum 19,800 bytes
;	 ES:DI - string to find
;		DX - offset within payload, of string to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
common_dynbintree_subtree_find_by_string:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_find_by_string_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_find_by_string
common_dynbintree_subtree_find_by_string_done:
	pop cx
	ret


; Searches the specified subtree for a word, looking in the payload
; at the specified offset
;
; input:
;	 DS:SI - pointer to root node of subtree
;		CX - element length, in bytes, maximum 19,800 bytes
;		DX - word to find
;		DI - offset within payload, of word to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
common_dynbintree_subtree_find_by_word:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_find_by_word_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_find_by_word
common_dynbintree_subtree_find_by_word_done:
	pop cx
	ret


; Searches the specified subtree for a byte, looking in the payload
; at the specified offset
;
; input:
;	 DS:SI - pointer to root node of subtree
;		CX - element length, in bytes, maximum 19,800 bytes
;		DL - byte to find
;		DI - offset within payload, of byte to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
common_dynbintree_subtree_find_by_byte:	
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_find_by_byte_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_find_by_byte
common_dynbintree_subtree_find_by_byte_done:
	pop cx
	ret


; Returns the number of children of the specified node
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - child count
common_dynbintree_get_child_count:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_get_child_count_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_get_child_count
common_dynbintree_get_child_count_done:
	pop cx
	ret



; Returns statistics of the subtree rooted at the specified node
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,800 bytes
; output:
;		AX - height
;		BX - number of nodes
;		CX - number of nodes (placeholder for further statistic)
;		DX - number of nodes (placeholder for further statistic)
common_dynbintree_subtree_statistics:
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_statistics_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_statistics
common_dynbintree_subtree_statistics_done:
	ret


; Clears the entire tree, removing all nodes
;
; input:
;	 FS:BX - pointer to pointer to root
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbintree_clear:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_clear_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_clear
common_dynbintree_clear_done:
	pop cx
	ret


; Checks whether the specified node has any children
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when node has no children, other value otherwise
common_dynbintree_has_children:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_has_children_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_has_children
common_dynbintree_has_children_done:
	pop cx
	ret


; Invokes a callback function for each node that is an ancestor of the
; specified node.
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to currently-iterated node
;        callback output:
;                       none
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,800 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dynbintree_subtree_foreach_ancestor:
	push cx
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_foreach_ancestor_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_foreach_ancestor
common_dynbintree_subtree_foreach_ancestor_done:
	pop cx
	ret

	
; Changes the parent pointer of a node
;
; input:
;	 DS:SI - pointer to node
;	 ES:DI - pointer to new parent node
;		CX - element length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbintree_change_parent_ptr:
	push cx
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_change_parent_ptr_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_change_parent_ptr
common_dynbintree_change_parent_ptr_done:
	pop cx
	ret
	
	
; Marks the specified node as having no parent
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbintree_clear_parent_ptr:
	push cx
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_clear_parent_ptr_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_clear_parent_ptr
common_dynbintree_clear_parent_ptr_done:
	pop cx
	ret
	

; Returns a pointer to the parent node of the specified node,
; if one exists
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to parent node, if it exists
common_dynbintree_get_parent:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_get_parent_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_get_parent
common_dynbintree_get_parent_done:
	pop cx
	ret


; Returns a pointer to specified node's right child node
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to right child node, if any
common_dynbintree_get_right_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_get_right_child_fail
	
	mov bx, cx									; BX := payload length

	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_get_first_child			; DS:SI := first child
	cmp ax, 0
	je common_dynbintree_get_right_child_fail	; no children

	test byte [ds:si+bx+0], CBINTREE_FLAG_IS_LEFT_CHILD	; is it right child?
	jz common_dynbintree_get_right_child_success		; yes, so return it
	; it's not right child
	
	call common_dyntree_get_next_sibling
	cmp ax, 0
	je common_dynbintree_get_right_child_fail			; no second child
	; if first child wasn't right child, second one is guaranteed to be
	jmp common_dynbintree_get_right_child_success
	
common_dynbintree_get_right_child_fail:
	mov ax, 0
	jmp common_dynbintree_get_right_child_done
common_dynbintree_get_right_child_success:
	mov ax, 1
common_dynbintree_get_right_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Returns a pointer to specified node's left child node
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to left child node, if any
common_dynbintree_get_left_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_get_left_child_fail
	
	mov bx, cx									; BX := payload length

	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_get_first_child			; DS:SI := first child
	cmp ax, 0
	je common_dynbintree_get_left_child_fail	; no children
	
	test byte [ds:si+bx+0], CBINTREE_FLAG_IS_LEFT_CHILD	; is it left child?
	jnz common_dynbintree_get_left_child_success		; yes, so return it
	; it's not left child
	
	call common_dyntree_get_next_sibling
	cmp ax, 0
	je common_dynbintree_get_left_child_fail			; no second child
	; if first child wasn't left child, second one is guaranteed to be
	jmp common_dynbintree_get_left_child_success
	
common_dynbintree_get_left_child_fail:
	mov ax, 0
	jmp common_dynbintree_get_left_child_done
common_dynbintree_get_left_child_success:
	mov ax, 1
common_dynbintree_get_left_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Gets the root node
;
; input:
;	 FS:BX - pointer to pointer to root
; output:
;		AX - 0 when an error occurred or no root, other value otherwise
;	 DS:SI - pointer to root, when successful
common_dynbintree_get_root:
	call cbintree_assert_memory
	; no need to add CX
	call common_dyntree_get_root
common_dynbintree_get_root_done:
	ret


; Removes a subtree rooted in the specified node.
; The specified node and all its descendants are removed.
;
; input:
;	 FS:BX - pointer to pointer to root
;	 DS:SI - pointer to root node of the subtree to remove
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbintree_subtree_remove:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_remove_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_remove
common_dynbintree_subtree_remove_done:
	pop cx
	ret


; Invokes a callback function for each node that is the specified node,
; or a descendant of the specified node.
; The tree is traversed in preorder (node then children).
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to currently-iterated node
;                       DX - depth relative to specified node
;        callback output:
;                       AX - 0 when traversal must stop, other value otherwise
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,800 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dynbintree_subtree_foreach_preorder:
	push cx
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_foreach_preorder_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_foreach_preorder
common_dynbintree_subtree_foreach_preorder_done:
	pop cx
	ret


; Invokes a callback function for each node that is the specified node,
; or a descendant of the specified node.
; The tree is traversed in postorder (children then node).
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to currently-iterated node
;                       DX - depth relative to specified node
;        callback output:
;                       AX - 0 when traversal must stop, other value otherwise
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,800 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dynbintree_subtree_foreach_postorder:
	push cx
	
	call cbintree_assert_memory
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_subtree_foreach_postorder_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_subtree_foreach_postorder
common_dynbintree_subtree_foreach_postorder_done:
	pop cx
	ret


; Removes a leaf node - that is, which has no child nodes
;
; input:
;	 FS:BX - pointer to pointer to root
;	 DS:SI - pointer to node to remove
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbintree_remove:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_remove_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_remove
common_dynbintree_remove_done:
	pop cx
	ret

	
; Checks whether the specified node is a left child.
; Behaviour is undefined for root nodes.
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when node is not a left child, other value otherwise
common_dynbintree_is_left_child:
	push si
	
	add si, cx										; DS:SI := ptr to overhead
	test byte [ds:si], CBINTREE_FLAG_IS_LEFT_CHILD
	jnz common_dynbintree_is_left_child_yes			; it is
	; it's not
common_dynbintree_is_left_child_no:
	mov ax, 0
	jmp common_dynbintree_is_left_child_done
common_dynbintree_is_left_child_yes:
	mov ax, 1
common_dynbintree_is_left_child_done:
	pop si
	ret
	

; Adds a root node.
; If existing, the old root becomes the new root's left child
;
; NOTE: old root, if existing, is reallocated, invalidating existing
;       pointers to it held by the consumer application
;
; input:
;	 FS:BX - pointer to pointer to root
;	 ES:DI - pointer to payload to add as a new root
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new root, when successful
common_dynbintree_add_root:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja common_dynbintree_add_root_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call common_dyntree_add_root
	cmp ax, 0
	je common_dynbintree_add_root_done
	
	sub cx, CBINTREE_OVERHEAD_BYTES				; CX := payload size
	push bx
	mov bx, cx
	or byte [ds:si+bx+0], CBINTREE_FLAG_IS_LEFT_CHILD
	pop bx
common_dynbintree_add_root_done:
	pop cx
	ret

	
; Exits task and prints an error message if dynamic memory module was
; not initialized.
;
; input:
;		none
; output:
;		none
cbintree_assert_memory:
	pusha
	push ds
	
	call common_memory_is_initialized
	cmp ax, 0
	jne cbintree_assert_memory_success
	; not initialized
	push cs
	pop ds
	mov si, commonBinTreeNoMemory
	int 80h
	mov ah, 0
	int 16h
	mov cx, 200
	int 85h							; delay
	int 95h							; exit task
cbintree_assert_memory_success:
	pop ds
	popa
	ret
	
	
; Returns whether the specified node is root or not
;
; input:
;	 DS:SI - pointer to node to check
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when node is not root, other value otherwise
cbintree_is_root:
	push cx
	
	call cbintree_assert_memory
	mov ax, 0									; assume error
	cmp cx, CBINTREE_MAX_NODE_SIZE
	ja cbintree_is_root_done
	
	add cx, CBINTREE_OVERHEAD_BYTES
	call ctree_is_root
cbintree_is_root_done:
	pop cx
	ret
	
	
; Pushes a pointer on the stack
;
; input:
;	 DS:SI - pointer
;		DX - depth
; output:
;		AX - 0 when an error occurred, other value otherwise
cbintree_stack_push:
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
	mov di, cbintreePtrTempStorage		; ES:DI := temp storage for pointers
	mov word [es:di+0], ds
	mov word [es:di+2], si
	mov word [es:di+4], dx				; depth
	
	push cs
	pop fs
	mov bx, cbintreeStackHeadPtr	; FS:BX := ptr to ptr to stack top
	
	mov cx, CBINTREE_NODE_PTR_SIZE
	call common_dynstack_push
	cmp ax, 0
	je cbintree_stack_push_fail
	jmp cbintree_stack_push_success
	
cbintree_stack_push_fail:
	mov ax, 0
	jmp cbintree_stack_push_done
cbintree_stack_push_success:
	mov ax, 1
cbintree_stack_push_done:
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
	
	
; Pops a pointer from stack
;
; input:
;		none
; output:
;		AX - 0 when stack is empty, other value otherwise
;	 DS:SI - pointer to popped element
;		DX - depth
cbintree_stack_pop:
	push es
	push fs
	push gs
	push bx
	push cx
	push di

	push cs
	pop fs
	mov bx, cbintreeStackHeadPtr		; FS:BX := ptr to ptr to stack top
	
	mov cx, CBINTREE_NODE_PTR_SIZE
	call common_dynstack_pop			; DS:SI := pointer to popped node
	cmp ax, 0
	je cbintree_stack_pop_fail
	
	push word [ds:si+0]
	push word [ds:si+2]					; save payload (which is a pointer)
	mov dx, word [ds:si+4]				; DX := depth
	
	call common_memory_deallocate		; consumer must deallocate pointer
	pop si
	pop ds								; DS:SI := payload
	cmp ax, 0
	je cbintree_stack_pop_fail
	
	mov ax, 1
	jmp cbintree_stack_pop_done
	
cbintree_stack_pop_fail:
	mov ax, 0
cbintree_stack_pop_done:
	pop di
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret
	
	
; Clears stack used by traversals.
; This is an easy way to not leak memory if stack operations fail during
; traversals.
;
; input:
;		none
; output:
;		none
cbintree_stack_clear:
	pusha
	push ds
	push es
	push fs
	push gs

	push cs
	pop fs
	mov bx, cbintreeStackHeadPtr
	mov cx, CBINTREE_NODE_PTR_SIZE
	call common_dynstack_clear
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Checks whether the stack has any elements
;
; input:
;		none
; output:
;		AX - 0 when stack has no elements, other value otherwise
cbintree_stack_has_any:
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
	pop fs
	mov bx, cbintreeStackHeadPtr
	mov cx, CBINTREE_NODE_PTR_SIZE
	call common_dynstack_peek
	
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
	

%include "common\memory.asm"
%include "common\dynamic\dyn_tree.asm"
%include "common\dynamic\dyn_stk.asm"
	
%endif
