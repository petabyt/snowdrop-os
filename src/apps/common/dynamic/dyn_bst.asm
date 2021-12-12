;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains a library for working with binary search trees (BST) allocated
; via dynamic memory.
; Calls whose name includes "subtree" operate on multiple nodes.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DYNAMIC_BST_
%define _COMMON_DYNAMIC_BST_

; The consumer declares a treeRootPtr as shown below. It holds exclusively
; overhead bytes, to point at the root, and indicate whether the
; root exists or not.
; By declaring multiple root pointers, a consumer application can
; create and operate on multiple trees.
; The consumer application is expected to not modify these bytes.
;
;     treeRootPtr:	times COMMON_DYNBST_ROOT_PTR_LENGTH db COMMON_DYNBST_ROOT_PTR_INITIAL
;
; Since %includes are often at the end of the file (because the initial jmp
; cannot be too long), in NASM I tend to define for example:
;     COMMON_DYNBST_ROOT_PTR_LENGTH_2 equ COMMON_DYNBST_ROOT_PTR_LENGTH
;     COMMON_DYNBST_ROOT_PTR_INITIAL_2 equ COMMON_DYNBST_ROOT_PTR_INITIAL
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
;     call common_dynbst_...
;
; NOTE: The consumer should NOT call N-ary tree functions on BST
;       nodes, as their behaviour is undefined.

; BSTs are stored as regular binary trees

; head pointer structure is no different than for a binary tree
COMMON_DYNBST_ROOT_PTR_LENGTH		equ COMMON_DYNBINTREE_ROOT_PTR_LENGTH
COMMON_DYNBST_ROOT_PTR_INITIAL		equ COMMON_DYNBINTREE_ROOT_PTR_INITIAL

; these are used for any operations that require a comparator
cbstComparatorSeg:			dw 0
cbstComparatorOff:			dw 0

; these are used when adding a node
cbstPayloadSeg:				dw 0
cbstPayloadOff:				dw 0

; these are generally used when traversing
cbstComparatorReturnAx:		dw 0
cbstTempWordBuffer:			dw 0

; these are used for removal
cbstRemoveTargetNodeSeg:	dw 0
cbstRemoveTargetNodeOff:	dw 0
cbstRemoveMinNodeSeg:		dw 0
cbstRemoveMinNodeOff:		dw 0
cbstRemoveMinRightChildSeg:	dw 0
cbstRemoveMinRightChildOff:	dw 0
cbstRemoveLeftChildSeg:		dw 0
cbstRemoveLeftChildOff:		dw 0
cbstRemoveRightChildSeg:	dw 0
cbstRemoveRightChildOff:	dw 0


; Removes a node in the BST.
; This is the most general form of the "remove" workflow, which accepts a
; comparator callback function to use when comparing.
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to first node
;                    ES:DI - pointer to second node
;        callback output:
;                       AX - -1 when first node precedes second node
;                             0 when first node equals second node
;                             1 when first node succeeds second node
;
; input:
;	 FS:BX - pointer to pointer to root
;	 ES:DI - pointer to comparison buffer; this buffer will be passed back
;			 into the comparator for each node, therefore the consumer is 
;			 required to recognize this in the comparator. Normally, it 
;			 would look like a regular node, so comparison is easy 
;			 (would be at the same offset)
;		CX - payload length, in bytes, maximum 19,800 bytes
;	 GS:DX - pointer to comparator callback function
; output:
;		AX - 0 when not found or error, other value otherwise
common_dynbst_remove:
	pushf
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di

	mov word [cs:cbstComparatorSeg], gs
	mov word [cs:cbstComparatorOff], dx		; save pointer to comparator
	
	mov word [cs:cbstPayloadSeg], es
	mov word [cs:cbstPayloadOff], di		; save pointer to comparison buffer
	
	call common_dynbst_find					; DS:SI := ptr to node to remove
	cmp ax, 0
	je common_dynbst_remove_fail			; not found
	; here, DS:SI = pointer to node to remove

	call cbintree_is_root
	cmp ax, 0
	je common_dynbst_remove_nonroot
common_dynbst_remove_root:
	; here, DS:SI = pointer to node to remove, which is root
	call common_dynbintree_get_child_count		; AX := child count
	cmp ax, 0
	je common_dynbst_remove_root__no_children
	cmp ax, 1
	je common_dynbst_remove_root__one_child
common_dynbst_remove_root__two_children:
	; invoke helper
	call cbst_remove_node_with_two_children
	cmp ax, 0
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success
	
common_dynbst_remove_root__no_children:
	; here, DS:SI = pointer to node to remove, which is root
	; DS:SI has no children
	call common_dynbst_clear					; root with no children
	cmp ax, 0									; means one-node tree
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success
	
common_dynbst_remove_root__one_child:
	; here, DS:SI = pointer to node to remove, which is root
	; DS:SI has one child
	call common_dynbintree_has_left_child
	cmp ax, 0
	je common_dynbst_remove_root__one_child_right
common_dynbst_remove_root__one_child_left:
	push ds
	push si										; save old root
	call common_dynbintree_get_left_child		; DS:SI := left child
												; guaranteed to succeed
	call common_dynbintree_clear_parent_ptr
	cmp ax, 0
	je common_dynbst_remove_fail
	call common_dynbintree_set_root_by_ptr		; set new root
	pop si
	pop ds										; DS:SI := old root
	call common_memory_deallocate
	cmp ax, 0
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success
	
common_dynbst_remove_root__one_child_right:
	push ds
	push si										; save old root
	call common_dynbintree_get_right_child		; DS:SI := right child
												; guaranteed to succeed
	call common_dynbintree_clear_parent_ptr
	cmp ax, 0
	je common_dynbst_remove_fail
	call common_dynbintree_set_root_by_ptr		; set new root
	pop si
	pop ds										; DS:SI := old root
	call common_memory_deallocate
	cmp ax, 0
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success

common_dynbst_remove_nonroot:
	; here, DS:SI = pointer to node to remove, which is NOT root
	call common_dynbintree_get_child_count		; AX := child count
	cmp ax, 0
	je common_dynbst_remove_nonroot__no_children
	cmp ax, 1
	je common_dynbst_remove_nonroot__one_child
common_dynbst_remove_nonroot__two_children:
	; invoke helper
	call cbst_remove_node_with_two_children
	cmp ax, 0
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success

common_dynbst_remove_nonroot__no_children:
	; node to delete is a leaf, so we need do nothing other than remove it
	call common_dynbintree_remove
	cmp ax, 0
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success

common_dynbst_remove_nonroot__one_child:
	mov word [cs:cbstRemoveTargetNodeSeg], ds
	mov word [cs:cbstRemoveTargetNodeOff], si
	
	; node to delete has one child
	call common_dynbintree_has_left_child
	cmp ax, 0
	je common_dynbst_remove_nonroot__one_child_right
common_dynbst_remove_nonroot__one_child_left:
	; here, DS:SI = pointer to node to remove, which is NOT root
	; node to delete has a left child
	call common_dynbintree_get_left_child			; DS:SI := left child
													; (guaranteed to succeed)
	mov word [cs:cbstRemoveLeftChildSeg], ds
	mov word [cs:cbstRemoveLeftChildOff], si
	
	push word [cs:cbstRemoveTargetNodeSeg]
	pop es
	mov di, word [cs:cbstRemoveTargetNodeOff]		; ES:DI := node to delete
	; copy payload
	push cx
	cld
	rep movsb										; copy child payload to 
													; node to delete
	pop cx
	; copy children
	mov di, word [cs:cbstRemoveTargetNodeOff]		; ES:DI := node to delete
	mov si, word [cs:cbstRemoveLeftChildOff]		; DS:SI := left child
	call common_dynbintree_copy_children	; make children of left child
											; children of node to delete
	; make node to delete parent of left child's children
	; here, DS:SI = left child
	; here, ES:DI = node to delete
	call common_dynbintree_get_left_child	; DS:SI := left child's left child
	cmp ax, 0
	je common_dynbst_remove_nonroot__one_child_left__0
	; set parent of left child's left child to node to delete
	call common_dynbintree_change_parent_ptr
	cmp ax, 0
	je common_dynbst_remove_fail
common_dynbst_remove_nonroot__one_child_left__0:
	; check right
	; here, ES:DI = node to delete
	push word [cs:cbstRemoveLeftChildSeg]
	pop ds
	mov si, word [cs:cbstRemoveLeftChildOff]		; DS:SI := left child
	call common_dynbintree_get_right_child	; DS:SI := left child's right child
	cmp ax, 0
	je common_dynbst_remove_nonroot__one_child_left__1
	; set parent of left child's right child to node to delete
	call common_dynbintree_change_parent_ptr
	cmp ax, 0
	je common_dynbst_remove_fail
common_dynbst_remove_nonroot__one_child_left__1:
	; we can now deallocate left child, since it's been orphaned
	push word [cs:cbstRemoveLeftChildSeg]
	pop ds
	mov si, word [cs:cbstRemoveLeftChildOff]		; DS:SI := left child
	call common_memory_deallocate
	cmp ax, 0
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success

common_dynbst_remove_nonroot__one_child_right:
	; here, DS:SI = pointer to node to remove, which is NOT root
	; node to delete has a right child
	call common_dynbintree_get_right_child			; DS:SI := right child
													; (guaranteed to succeed)
	mov word [cs:cbstRemoveRightChildSeg], ds
	mov word [cs:cbstRemoveRightChildOff], si
	
	push word [cs:cbstRemoveTargetNodeSeg]
	pop es
	mov di, word [cs:cbstRemoveTargetNodeOff]		; ES:DI := node to delete
	; copy payload
	push cx
	cld
	rep movsb										; copy child payload to 
													; node to delete
	pop cx
	; copy children
	mov di, word [cs:cbstRemoveTargetNodeOff]		; ES:DI := node to delete
	mov si, word [cs:cbstRemoveRightChildOff]		; DS:SI := right child
	call common_dynbintree_copy_children	; make children of right child
											; children of node to delete
	; make node to delete parent of right child's children
	; here, DS:SI = right child
	; here, ES:DI = node to delete
	call common_dynbintree_get_left_child	; DS:SI := right child's left child
	cmp ax, 0
	je common_dynbst_remove_nonroot__one_child_right__0
	; set parent of right child's left child to node to delete
	call common_dynbintree_change_parent_ptr
	cmp ax, 0
	je common_dynbst_remove_fail
common_dynbst_remove_nonroot__one_child_right__0:
	; check right
	; here, ES:DI = node to delete
	push word [cs:cbstRemoveRightChildSeg]
	pop ds
	mov si, word [cs:cbstRemoveRightChildOff]		; DS:SI := right child
	call common_dynbintree_get_right_child
										; DS:SI := right child's right child
	cmp ax, 0
	je common_dynbst_remove_nonroot__one_child_right__1
	; set parent of right child's right child to node to delete
	call common_dynbintree_change_parent_ptr
	cmp ax, 0
	je common_dynbst_remove_fail
common_dynbst_remove_nonroot__one_child_right__1:
	; we can now deallocate right child, since it's been orphaned
	push word [cs:cbstRemoveRightChildSeg]
	pop ds
	mov si, word [cs:cbstRemoveRightChildOff]		; DS:SI := right child
	call common_memory_deallocate
	cmp ax, 0
	je common_dynbst_remove_fail
	jmp common_dynbst_remove_success
	
common_dynbst_remove_fail:
	mov ax, 0
	jmp common_dynbst_remove_done
common_dynbst_remove_success:
	mov ax, 1
common_dynbst_remove_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	popf
	ret


; Finds a node in to the BST.
; This is the most general form of the "find" workflow, which accepts a
; comparator callback function to use when comparing.
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to first node
;                    ES:DI - pointer to second node
;        callback output:
;                       AX - -1 when first node precedes second node
;                             0 when first node equals second node
;                             1 when first node succeeds second node
;
; input:
;	 FS:BX - pointer to pointer to root
;	 ES:DI - pointer to comparison buffer; this buffer will be passed back
;			 into the comparator for each node, therefore the consumer is 
;			 required to recognize this in the comparator. Normally, it 
;			 would look like a regular node, so comparison is easy 
;			 (would be at the same offset)
;		CX - payload length, in bytes, maximum 19,800 bytes
;	 GS:DX - pointer to comparator callback function
; output:
;		AX - 0 when not found, other value otherwise
;	 DS:SI - pointer to node, when found
common_dynbst_find:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	mov word [cs:cbstComparatorSeg], gs
	mov word [cs:cbstComparatorOff], dx		; save pointer to comparator
	
	mov word [cs:cbstPayloadSeg], es
	mov word [cs:cbstPayloadOff], di		; save pointer to comparison buffer
	
	call common_dynbintree_get_root			; DS:SI := root
	cmp ax, 0
	jne common_dynbst_find_got_root			; root already exists
	
	; root doesn't exist, so we fail
	cmp ax, 0
	je common_dynbst_find_fail

common_dynbst_find_got_root:
	; here, DS:SI = root
common_dynbst_find_traverse:
	; here, DS:SI = current node, guaranteed to exist	
	; invoke comparator
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; 1. setup return address
	push cs
	push word common_dynbst_find_traverse_comparator_return
										; return address on stack
	; 2. setup "call far" site address
	push word [cs:cbstComparatorSeg]			; callback segment
	push word [cs:cbstComparatorOff]			; callback offset
	
	; 3. setup callback arguments
	; here, DS:SI = pointer to current node
	push word [cs:cbstPayloadSeg]
	pop es
	mov di, word [cs:cbstPayloadOff]	; ES:DI := payload
	
	; 4. invoke callback
	retf			; "call far"
	; once the callback executes its own retf, execution returns below
common_dynbst_find_traverse_comparator_return:
	mov word [cs:cbstComparatorReturnAx], ax
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	; done invoking comparator
	
	cmp word [cs:cbstComparatorReturnAx], 0	; equal?
	je common_dynbst_find_success			; yes, so we found our node
	; this is not the right node, so we must follow a child
	
	cmp word [cs:cbstComparatorReturnAx], 1	; current node > payload?
	je common_dynbst_find_traverse_left		; yes, so we traverse left
	
	jmp common_dynbst_find_traverse_right	; current node <= payload
											; so we traverse left
	
common_dynbst_find_traverse_left:
	; here, DS:SI = current node
	push ds
	pop gs
	mov dx, si								; GS:DX := current node
	call common_dynbintree_get_left_child	; DS:SI := left child
	cmp ax, 0
	jne common_dynbst_find_traverse			; left child exists, so traverse it
	; left child doesn't exist, so we didn't find it
	jmp common_dynbst_find_fail
	
common_dynbst_find_traverse_right:
	; here, DS:SI = current node
	push ds
	pop gs
	mov dx, si								; GS:DX := current node
	call common_dynbintree_get_right_child	; DS:SI := right child
	cmp ax, 0
	jne common_dynbst_find_traverse			; right child exists, traverse it
	; right child doesn't exist, so we didn't find it
	jmp common_dynbst_find_fail
	
common_dynbst_find_fail:
	mov ax, 0
	jmp common_dynbst_find_done
common_dynbst_find_success:
	mov ax, 1
common_dynbst_find_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Adds a new node to the BST.
; This is the most general form of the "add" workflow, which accepts a
; comparator callback function to use when comparing.
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to first node
;                    ES:DI - pointer to second node
;        callback output:
;                       AX - -1 when first node precedes second node
;                             0 when first node equals second node
;                             1 when first node succeeds second node
;
; input:
;	 FS:BX - pointer to pointer to root
;	 ES:DI - pointer to payload to add as a new node
;		CX - payload length, in bytes, maximum 19,800 bytes
;	 GS:DX - pointer to comparator callback function
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dynbst_add:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	mov word [cs:cbstComparatorSeg], gs
	mov word [cs:cbstComparatorOff], dx			; save pointer to comparator
	
	mov word [cs:cbstPayloadSeg], es
	mov word [cs:cbstPayloadOff], di			; save pointer to payload
	
	call common_dynbintree_get_root				; DS:SI := root
	cmp ax, 0
	jne common_dynbst_add_got_root				; root already exists
	
	; root doesn't exist, so we add node to root
	call common_dynbintree_add_root
	cmp ax, 0
	je common_dynbst_add_fail
	jmp common_dynbst_add_success

common_dynbst_add_got_root:
	; here, DS:SI = root
common_dynbst_add_traverse:
	; here, DS:SI = current node, guaranteed to exist
	
	; invoke comparator
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; 1. setup return address
	push cs
	push word common_dynbst_add_traverse_comparator_return
										; return address on stack
	; 2. setup "call far" site address
	push word [cs:cbstComparatorSeg]			; callback segment
	push word [cs:cbstComparatorOff]			; callback offset
	
	; 3. setup callback arguments
	; here, DS:SI = pointer to current node
	push word [cs:cbstPayloadSeg]
	pop es
	mov di, word [cs:cbstPayloadOff]	; ES:DI := payload
	
	; 4. invoke callback
	retf			; "call far"
	; once the callback executes its own retf, execution returns below
common_dynbst_add_traverse_comparator_return:
	mov word [cs:cbstComparatorReturnAx], ax
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	; done invoking comparator
	
	cmp word [cs:cbstComparatorReturnAx], 1	; current node > payload?
	je common_dynbst_add_traverse_left		; yes, so we traverse left
	
	jmp common_dynbst_add_traverse_right	; current node <= payload
											; so we traverse right
	
common_dynbst_add_traverse_left:
	; here, DS:SI = current node
	push ds
	pop gs
	mov dx, si								; GS:DX := current node
	call common_dynbintree_get_left_child	; DS:SI := left child
	cmp ax, 0
	jne common_dynbst_add_traverse			; left child exists, so traverse it
	; left child doesn't exist, so add it there
	push gs
	pop ds
	mov si, dx								; DS:SI := current node
	push word [cs:cbstPayloadSeg]
	pop es
	mov di, word [cs:cbstPayloadOff]		; ES:DI := payload
	call common_dynbintree_add_left_child	; DS:SI := new node
	cmp ax, 0
	je common_dynbst_add_fail
	jmp common_dynbst_add_success
	
common_dynbst_add_traverse_right:
	; here, DS:SI = current node
	push ds
	pop gs
	mov dx, si								; GS:DX := current node
	call common_dynbintree_get_right_child	; DS:SI := right child
	cmp ax, 0
	jne common_dynbst_add_traverse			; right child exists, traverse it
	; right child doesn't exist, so add it there
	push gs
	pop ds
	mov si, dx								; DS:SI := current node
	push word [cs:cbstPayloadSeg]
	pop es
	mov di, word [cs:cbstPayloadOff]		; ES:DI := payload
	call common_dynbintree_add_right_child	; DS:SI := new node
	cmp ax, 0
	je common_dynbst_add_fail
	jmp common_dynbst_add_success
	
common_dynbst_add_fail:
	mov ax, 0
	jmp common_dynbst_add_done
common_dynbst_add_success:
	mov ax, 1
common_dynbst_add_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret
	
	
; Finds a word node in the BST.
; Uses internal word comparator to find place for new node.
; BST can ONLY contain word (2-byte) nodes.
; 
; input:
;	 FS:BX - pointer to pointer to root
;		AX - word to find
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dynbst_find_word:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push gs

	push cs
	pop es
	mov di, cbstTempWordBuffer				; ES:DI := buffer
	mov word [es:di], ax					; store value in buffer
	mov cx, 2								; byte size
	
	push cs
	pop gs
	mov dx, common_dynbst_word_comparator	; GS:DX := internal comparator
	
	call common_dynbst_find
	
	pop gs
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Finds a byte node in the BST.
; Uses internal byte comparator to find place for new node.
; BST can ONLY contain byte nodes.
; 
; input:
;	 FS:BX - pointer to pointer to root
;		AL - byte to find
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dynbst_find_byte:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push gs

	push cs
	pop es
	mov di, cbstTempWordBuffer				; ES:DI := buffer
	mov byte [es:di], al					; store value in buffer
	mov cx, 1								; byte size
	
	push cs
	pop gs
	mov dx, common_dynbst_byte_comparator	; GS:DX := internal comparator
	
	call common_dynbst_find
	
	pop gs
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret


; Adds a new word node to the BST.
; Uses internal word comparator to find place for new node.
; BST can ONLY contain word (2-byte) nodes.
; 
; input:
;	 FS:BX - pointer to pointer to root
;		AX - word to add as a new node
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dynbst_add_word:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push gs

	push cs
	pop es
	mov di, cbstTempWordBuffer				; ES:DI := buffer
	mov word [es:di], ax					; store value in buffer
	mov cx, 2								; byte size
	
	push cs
	pop gs
	mov dx, common_dynbst_word_comparator	; GS:DX := internal comparator
	
	call common_dynbst_add
	
	pop gs
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Removes a word node from the BST.
; Uses internal word comparator to find place for new node.
; BST can ONLY contain word (2-byte) nodes.
; 
; input:
;	 FS:BX - pointer to pointer to root
;		AX - word to remove
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbst_remove_word:
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
	mov di, cbstTempWordBuffer				; ES:DI := buffer
	mov word [es:di], ax					; store value in buffer
	mov cx, 2								; byte size
	
	push cs
	pop gs
	mov dx, common_dynbst_word_comparator	; GS:DX := internal comparator
	
	call common_dynbst_remove
	
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
	
	
; Removes a byte node from the BST.
; Uses internal word comparator to find place for new node.
; BST can ONLY contain byte nodes.
; 
; input:
;	 FS:BX - pointer to pointer to root
;		AL - byte to remove
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbst_remove_byte:
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
	mov di, cbstTempWordBuffer				; ES:DI := buffer
	mov byte [es:di], al					; store value in buffer
	mov cx, 1								; byte size
	
	push cs
	pop gs
	mov dx, common_dynbst_byte_comparator	; GS:DX := internal comparator
	
	call common_dynbst_remove
	
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
	
	
; Adds a new byte node to the BST.
; Uses internal byte comparator to find place for new node.
; BST can ONLY contain byte nodes.
; 
; input:
;	 FS:BX - pointer to pointer to root
;		AL - byte to add as a new node
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dynbst_add_byte:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push gs
	
	push cs
	pop es
	mov di, cbstTempWordBuffer				; ES:DI := buffer
	mov byte [es:di], al					; store value in buffer
	mov cx, 1								; byte size
	
	push cs
	pop gs
	mov dx, common_dynbst_byte_comparator	; GS:DX := internal comparator
	
	call common_dynbst_add
	pop gs
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret

	
; Clears the entire tree, removing all nodes
;
; input:
;	 FS:BX - pointer to pointer to root
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dynbst_clear:
	call common_dynbintree_clear
	ret
	
	
; A built-in comparator for unsigned words
;
; input:
;	 DS:SI - pointer to first node
;	 ES:DI - pointer to second node
; output:
;		AX - -1 when first node precedes second node
;             0 when first node equals second node
;             1 when first node succeeds second node
common_dynbst_word_comparator:
	mov ax, word [ds:si]
	cmp ax, word [es:di]
	ja common_dynbst_word_comparator_greater
	jb common_dynbst_word_comparator_less
	mov ax, 0
	jmp common_dynbst_word_comparator_done
common_dynbst_word_comparator_greater:
	mov ax, 1
	jmp common_dynbst_word_comparator_done
common_dynbst_word_comparator_less:
	mov ax, -1
	jmp common_dynbst_word_comparator_done
common_dynbst_word_comparator_done:
	retf
	
	
; A built-in comparator for unsigned bytes
;
; input:
;	 DS:SI - pointer to first node
;	 ES:DI - pointer to second node
; output:
;		AX - -1 when first node precedes second node
;             0 when first node equals second node
;             1 when first node succeeds second node
common_dynbst_byte_comparator:
	mov al, byte [ds:si]
	cmp al, byte [es:di]
	ja common_dynbst_byte_comparator_greater
	jb common_dynbst_byte_comparator_less
	mov ax, 0
	jmp common_dynbst_byte_comparator_done
common_dynbst_byte_comparator_greater:
	mov ax, 1
	jmp common_dynbst_byte_comparator_done
common_dynbst_byte_comparator_less:
	mov ax, -1
	jmp common_dynbst_byte_comparator_done
common_dynbst_byte_comparator_done:
	retf

	
; Finds the minimum node in the specified subtree
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;	 DS:SI - pointer to node with minimum value in subtree
cbst_subtree_find_min_node:
	push es
	push fs
	push gs
	push ax
	push bx
	push cx
	push dx
	push di
	
cbst_subtree_find_min_node_loop:
	call common_dynbintree_has_left_child
	cmp ax, 0
	je cbst_subtree_find_min_node_done
	call common_dynbintree_get_left_child		; DS:SI := left child
	jmp cbst_subtree_find_min_node_loop
	
cbst_subtree_find_min_node_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop gs
	pop fs
	pop es
	ret
	

; Removes in the BST a node that has two children (left and right)
;
; input:
;	 FS:BX - pointer to pointer to root
;	 DS:SI - pointer to node to remove
;		CX - payload length, in bytes, maximum 19,800 bytes
; output:
;		AX - 0 when not found or error, other value otherwise
cbst_remove_node_with_two_children:
	pushf
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	call common_dynbintree_get_child_count
	cmp ax, 2									; DS:SI must have two children
	jne cbst_remove_node_with_two_children_fail
	
	mov word [cs:cbstRemoveTargetNodeSeg], ds
	mov word [cs:cbstRemoveTargetNodeOff], si
	
	; find minimum node in right subtree
	call common_dynbintree_get_right_child		; DS:SI := right child
												; guaranteed to succeed
	call cbst_subtree_find_min_node				; DS:SI := min node in 
												; right subtree
	mov word [cs:cbstRemoveMinNodeSeg], ds
	mov word [cs:cbstRemoveMinNodeOff], si
	
	; copy payload of min node to node to be deleted
	push es
	push di
	push cx										; [1]
	; here, DS:SI = min node
	push word [cs:cbstRemoveTargetNodeSeg]
	pop es
	mov di, word [cs:cbstRemoveTargetNodeOff]	; ES:DI := ptr to node to del.
	cld
	rep movsb									; copy payload
	
	pop cx
	pop di
	pop es										; [1]
	; minimum node has now overwritten node to be deleted
	
	; at this point, min node is either a leaf or has a right child
	; (it cannot have a left child, because then it wouldn't be a minimum node)
	push word [cs:cbstRemoveMinNodeSeg]
	pop ds
	mov si, word [cs:cbstRemoveMinNodeOff]		; DS:SI := min node
	call common_dynbintree_get_right_child		; DS:SI := right child of min
	cmp ax, 0
	je cbst_remove_node_with_two_children__remove_min	; no child, so just
															; remove min node
cbst_remove_node_with_two_children__min_has_right:
	; minimum node payload has overwritten payload of node to be deleted
	; minimum node has a right child
	; minimum node itself is either a left child or a right child
	; here, DS:SI = right child of minimum node
	mov word [cs:cbstRemoveMinRightChildSeg], ds
	mov word [cs:cbstRemoveMinRightChildOff], si

	push word [cs:cbstRemoveMinNodeSeg]
	pop es
	mov di, word [cs:cbstRemoveMinNodeOff]		; ES:DI := min node

	; copy MinRightChild payload into Min
	; copy MinRightChild children into Min
	; MinRightChild.leftChild.parent := Min (if exists)
	; MinRightChild.rightChild.parent := Min (if exists)
	; common_memory_deallocate MinRightChild
	;       MinRightChild has no siblings, so nothing to adjust horizontally
	;       
	
	; copy MinRightChild payload into Min
	push cx
	cld
	rep movsb									; copy payload
	pop cx
	
	; copy MinRightChild children into Min
	push word [cs:cbstRemoveMinNodeSeg]
	pop es
	mov di, word [cs:cbstRemoveMinNodeOff]			; ES:DI := min node
	push word [cs:cbstRemoveMinRightChildSeg]
	pop ds
	mov si, word [cs:cbstRemoveMinRightChildOff]	; DS:SI := min right child

	call common_dynbintree_copy_children
	cmp ax, 0
	je cbst_remove_node_with_two_children_fail
	
	; MinRightChild.leftChild.parent := Min (if exists)
	call common_dynbintree_get_left_child		; DS:SI := MinRightChild.left
	cmp ax, 0
	je cbst_remove_node_with_two_children__min_has_right__0
	
	push word [cs:cbstRemoveMinNodeSeg]
	pop es
	mov di, word [cs:cbstRemoveMinNodeOff]		; ES:DI := min node
	call common_dynbintree_change_parent_ptr
	
cbst_remove_node_with_two_children__min_has_right__0:
	push word [cs:cbstRemoveMinRightChildSeg]
	pop ds
	mov si, word [cs:cbstRemoveMinRightChildOff]	; DS:SI := min right child
	; MinRightChild.rightChild.parent := Min (if exists)
	call common_dynbintree_get_right_child		; DS:SI := MinRightChild.right
	cmp ax, 0
	je cbst_remove_node_with_two_children__min_has_right__1
	
	push word [cs:cbstRemoveMinNodeSeg]
	pop es
	mov di, word [cs:cbstRemoveMinNodeOff]		; ES:DI := min node
	call common_dynbintree_change_parent_ptr
	
cbst_remove_node_with_two_children__min_has_right__1:
	; deallocate MinRightChild
	; (it can't have siblings, so nothing more to do)
	push word [cs:cbstRemoveMinRightChildSeg]
	pop ds
	mov si, word [cs:cbstRemoveMinRightChildOff]	; DS:SI := min right child
	call common_memory_deallocate
	cmp ax, 0
	je cbst_remove_node_with_two_children_fail
	jmp cbst_remove_node_with_two_children_success
	
cbst_remove_node_with_two_children__remove_min:
	; minimum node is a leaf
	; here, FS:BX = ptr to ptr to root
	push word [cs:cbstRemoveMinNodeSeg]
	pop ds
	mov si, word [cs:cbstRemoveMinNodeOff]	; DS:SI := min node
	call common_dynbintree_remove
	cmp ax, 0
	je cbst_remove_node_with_two_children_fail
	jmp cbst_remove_node_with_two_children_success
	
cbst_remove_node_with_two_children_fail:
	mov ax, 0
	jmp cbst_remove_node_with_two_children_done
cbst_remove_node_with_two_children_success:
	mov ax, 1
cbst_remove_node_with_two_children_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	popf
	ret
	

%include "common\memory.asm"
%include "common\dynamic\dyn_bint.asm"
	
%endif
