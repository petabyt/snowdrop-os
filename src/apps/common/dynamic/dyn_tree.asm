;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains a library for working with trees allocated via dynamic memory.
; It can represent N-ary trees, that is, no restrictions on number
; of child nodes.
; Calls whose name includes "subtree" operate on multiple nodes.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DYNAMIC_TREES_
%define _COMMON_DYNAMIC_TREES_

; The consumer declares a treeRootPtr as shown below. It holds exclusively
; overhead bytes, to point at the root, and indicate whether the
; root exists or not.
; By declaring multiple root pointers, a consumer application can
; create and operate on multiple trees.
; The consumer application is expected to not modify these bytes.
;
;     treeRootPtr:	times COMMON_DYNTREE_ROOT_PTR_LENGTH db COMMON_DYNTREE_ROOT_PTR_INITIAL
;
; Since %includes are often at the end of the file (because the initial jmp
; cannot be too long), in NASM I tend to define for example:
;     COMMON_DYNTREE_ROOT_PTR_LENGTH_2 equ COMMON_DYNTREE_ROOT_PTR_LENGTH
;     COMMON_DYNTREE_ROOT_PTR_INITIAL_2 equ COMMON_DYNTREE_ROOT_PTR_INITIAL
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
;     call common_dyntree_...
;

; A tree node contains the consumer payload as the first X bytes (where X is
; the size of a node, as far as the consumer is concerned).
; Following that, there are overhead bytes used to organize the tree.
; 
; offset past last consumer byte                                what it stores
;                          0 - 1                        parent pointer segment
;                                             (root pointer in root structure)
;                          2 - 3                         parent pointer offset
;                                             (root pointer in root structure)
;                          4 - 4                                         flags
;                        5 - Y+4     ptr to ptr to head of list of child nodes
;                                           (this is a linked lists-specific
;                                            structure, used as a list
;                                            beginning marker, of size Y,
;                                            where Y is defined internally by
;                                            the linked lists library)


COMMON_DYNTREE_ROOT_PTR_LENGTH		equ 5
COMMON_DYNTREE_ROOT_PTR_INITIAL		equ 0

CTREE_MAX_NODE_SIZE		equ 19900			; in bytes

CTREE_SPECIFIC_OVERHEAD_BYTES	equ 5
CTREE_OVERHEAD_BYTES			equ CTREE_SPECIFIC_OVERHEAD_BYTES + COMMON_LLIST_HEAD_PTR_LENGTH
					; this many bytes are added to each node as overhead
					; child nodes are stored in a linked lists whose head
					; is part of the overhead bytes of the parent node
					; (this is the Y quantity in the table above)
CTREE_FLAG_HAS_PARENT		equ 1	
CTREE_FLAG_HAS_ROOT			equ CTREE_FLAG_HAS_PARENT
					; also means "has root" when in the tree's 
					; pointer to pointer to head structure

commonTreeNoMemory:	db 'FATAL: Must initialize dynamic memory module before using tree functionality.'
					db 13, 10
					db 'Press a key to exit', 0

CTREE_DYNSTACK_HEAD_PTR_LENGTH	equ COMMON_DYNSTACK_HEAD_PTR_LENGTH

; this represents an entry on the stack(s) used for traversals
; it contains information that is passed on to callbacks:
;       offset                              details
;          0-1           segment of pointer to node
;          2-3            offset of pointer to node
;          4-5                           node depth
CTREE_NODE_PTR_SIZE				equ 6

ctreePtrTempStorage:		times CTREE_NODE_PTR_SIZE db 0

; these stacks are used for traversals
ctreeWorkStackHeadPtr:		times CTREE_DYNSTACK_HEAD_PTR_LENGTH db COMMON_DYNSTACK_HEAD_PTR_INITIAL
ctreeResultStackHeadPtr:	times CTREE_DYNSTACK_HEAD_PTR_LENGTH db COMMON_DYNSTACK_HEAD_PTR_INITIAL

; these are used to accumulate statistics during a traversal
ctreeStatsMaxDepth:		dw 0
ctreeStatsNodeCount:	dw 0

; these are used to pass values to the "remove leaf" callback during a 
; subtree deletion
; an external consumer would have ready access to these values, so the
; callback contract is kept simple, and these are passed via variables
ctreeSubtreeRemove_rootSeg:			dw 0
ctreeSubtreeRemove_rootOff:			dw 0
ctreeSubtreeRemove_payloadLength:	dw 0

; these are used when searching for a byte
ctreeSubtreeFindByteByteToFind:		db 0
ctreeSubtreeFindByteOffsetToSearch:	dw 0
ctreeSubtreeFindByteWasFound:		db 0
ctreeSubtreeFindByteFoundSegment:	dw 0
ctreeSubtreeFindByteFoundOffset:	dw 0

; these are used when searching for a word
ctreeSubtreeFindWordWordToFind:		dw 0
ctreeSubtreeFindWordOffsetToSearch:	dw 0
ctreeSubtreeFindWordWasFound:		db 0
ctreeSubtreeFindWordFoundSegment:	dw 0
ctreeSubtreeFindWordFoundOffset:	dw 0

; these are used when searching for a string
ctreeSubtreeFindStringStringToFindSegment:	dw 0
ctreeSubtreeFindStringStringToFindOffset:	dw 0
ctreeSubtreeFindStringOffsetToSearch:		dw 0
ctreeSubtreeFindStringWasFound:				db 0
ctreeSubtreeFindStringFoundSegment:			dw 0
ctreeSubtreeFindStringFoundOffset:			dw 0

ctreeCallbackReturnAx:	dw 0		; used to check callback return values


; Marks the specified node as having no parent
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dyntree_clear_parent_ptr:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_clear_parent_ptr_fail

	add si, cx			; DS:SI := ptr to overhead bytes
	
	mov al, CTREE_FLAG_HAS_PARENT
	xor al, 0FFh
	and byte [ds:si+4], al
	
	jmp common_dyntree_clear_parent_ptr_success
common_dyntree_clear_parent_ptr_fail:
	mov ax, 0
	jmp common_dyntree_clear_parent_ptr_done
common_dyntree_clear_parent_ptr_success:
	mov ax, 1
common_dyntree_clear_parent_ptr_done:
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


; Changes the parent pointer of a node
;
; input:
;	 DS:SI - pointer to node
;	 ES:DI - pointer to new parent node
;		CX - element length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dyntree_change_parent_ptr:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_change_parent_ptr_fail

	add si, cx			; DS:SI := ptr to overhead bytes
	mov word [ds:si+0], es
	mov word [ds:si+2], di					; store parent
	
	jmp common_dyntree_change_parent_ptr_success
common_dyntree_change_parent_ptr_fail:
	mov ax, 0
	jmp common_dyntree_change_parent_ptr_done
common_dyntree_change_parent_ptr_success:
	mov ax, 1
common_dyntree_change_parent_ptr_done:
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


; Copies the children of a node to another node
;
; input:
;	 DS:SI - pointer to source node
;	 ES:DI - pointer to destination node
;		CX - element length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dyntree_copy_children:
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
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_copy_children_fail
	
	add cx, CTREE_SPECIFIC_OVERHEAD_BYTES
	add si, cx			; DS:SI := ptr to child list head of source node
	add di, cx			; ES:DI := ptr to child list head of destination node
	mov cx, COMMON_LLIST_HEAD_PTR_LENGTH
	cld
	rep movsb							; replace child list head
	jmp common_dyntree_copy_children_success
	
common_dyntree_copy_children_fail:
	mov ax, 0
	jmp common_dyntree_copy_children_done
common_dyntree_copy_children_success:
	mov ax, 1
common_dyntree_copy_children_done:
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


; Searches the specified subtree for a string, looking in the payload
; at the specified offset
;
; input:
;	 DS:SI - pointer to root node of subtree
;		CX - element length, in bytes, maximum 19,900 bytes
;	 ES:DI - string to find
;		DX - offset within payload, of string to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
common_dyntree_subtree_find_by_string:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_subtree_find_by_string_fail
	
	; check for overflow
	push ds
	push si									; [1] save input node
	
	push es
	pop ds
	mov si, di								; DS:SI := string to search
	int 0A5h								; BX := search string length
	inc bx									; BX := search string length
											; including terminator
	add bx, dx								; BX := offset right after
											; search string
	pop si
	pop ds									; [1] restore input node
	
	cmp bx, cx								; would it overflow payload?
	ja common_dyntree_subtree_find_by_string_fail		; yes, so we fail

	mov word [cs:ctreeSubtreeFindStringStringToFindSegment], es
	mov word [cs:ctreeSubtreeFindStringStringToFindOffset], di
	mov word [cs:ctreeSubtreeFindStringOffsetToSearch], dx
	mov byte [cs:ctreeSubtreeFindStringWasFound], 0

	; here, DS:SI = pointer to input node
	push cs
	pop es
	mov di, ctree_find_string_callback
	call common_dyntree_subtree_foreach_postorder
	
	cmp byte [cs:ctreeSubtreeFindStringWasFound], 0
	je common_dyntree_subtree_find_by_string_fail			; not found
	; found
	mov ax, word [cs:ctreeSubtreeFindStringFoundSegment]
	mov ds, ax
	mov si, word [cs:ctreeSubtreeFindStringFoundOffset]	; DS:SI := found node
	jmp common_dyntree_subtree_find_by_string_success
	
common_dyntree_subtree_find_by_string_fail:
	mov ax, 0
	jmp common_dyntree_subtree_find_by_string_done
common_dyntree_subtree_find_by_string_success:
	mov ax, 1
common_dyntree_subtree_find_by_string_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Searches the specified subtree for a word, looking in the payload
; at the specified offset
;
; input:
;	 DS:SI - pointer to root node of subtree
;		CX - element length, in bytes, maximum 19,900 bytes
;		DX - word to find
;		DI - offset within payload, of word to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
common_dyntree_subtree_find_by_word:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_subtree_find_by_word_fail
	
	add di, 2									; DI := offset right after word
	cmp di, cx									; would it overflow payload?
	ja common_dyntree_subtree_find_by_word_fail	; yes, so we fail
	; no, it can fit within the payload
	
	sub di, 2									; restore offset
	mov word [cs:ctreeSubtreeFindWordWordToFind], dx
	mov word [cs:ctreeSubtreeFindWordOffsetToSearch], di
	mov byte [cs:ctreeSubtreeFindWordWasFound], 0

	; here, DS:SI = pointer to input node
	push cs
	pop es
	mov di, ctree_find_word_callback
	call common_dyntree_subtree_foreach_postorder
	
	cmp byte [cs:ctreeSubtreeFindWordWasFound], 0
	je common_dyntree_subtree_find_by_word_fail			; not found
	; found
	mov ax, word [cs:ctreeSubtreeFindWordFoundSegment]
	mov ds, ax
	mov si, word [cs:ctreeSubtreeFindWordFoundOffset]	; DS:SI := found node
	jmp common_dyntree_subtree_find_by_word_success
	
common_dyntree_subtree_find_by_word_fail:
	mov ax, 0
	jmp common_dyntree_subtree_find_by_word_done
common_dyntree_subtree_find_by_word_success:
	mov ax, 1
common_dyntree_subtree_find_by_word_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Searches the specified subtree for a byte, looking in the payload
; at the specified offset
;
; input:
;	 DS:SI - pointer to root node of subtree
;		CX - element length, in bytes, maximum 19,900 bytes
;		DL - byte to find
;		DI - offset within payload, of byte to check
; output:
;		AX - 0 when no such element found, other value otherwise
;	 DS:SI - pointer to element, when found
common_dyntree_subtree_find_by_byte:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_subtree_find_by_byte_fail
	
	add di, 1									; DI := offset right after byte
	cmp di, cx									; would it overflow payload?
	ja common_dyntree_subtree_find_by_byte_fail	; yes, so we fail
	; no, it can fit within the payload
	
	sub di, 1									; restore offset
	mov byte [cs:ctreeSubtreeFindByteByteToFind], dl
	mov word [cs:ctreeSubtreeFindByteOffsetToSearch], di
	mov byte [cs:ctreeSubtreeFindByteWasFound], 0

	; here, DS:SI = pointer to input node
	push cs
	pop es
	mov di, ctree_find_byte_callback
	call common_dyntree_subtree_foreach_postorder
	
	cmp byte [cs:ctreeSubtreeFindByteWasFound], 0
	je common_dyntree_subtree_find_by_byte_fail			; not found
	; found
	mov ax, word [cs:ctreeSubtreeFindByteFoundSegment]
	mov ds, ax
	mov si, word [cs:ctreeSubtreeFindByteFoundOffset]	; DS:SI := found node
	jmp common_dyntree_subtree_find_by_byte_success
	
common_dyntree_subtree_find_by_byte_fail:
	mov ax, 0
	jmp common_dyntree_subtree_find_by_byte_done
common_dyntree_subtree_find_by_byte_success:
	mov ax, 1
common_dyntree_subtree_find_by_byte_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Clears the entire tree, removing all nodes
;
; input:
;	 FS:BX - pointer to pointer to root
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dyntree_clear:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_clear_fail
	
	call common_dyntree_get_root			; DS:SI := pointer to root
	cmp ax, 0
	je common_dyntree_clear_fail
	
	call common_dyntree_subtree_remove		; remove subtree rooted at DS:SI
	cmp ax, 0
	je common_dyntree_clear_fail
	
	jmp common_dyntree_clear_success

common_dyntree_clear_fail:
	mov ax, 0
	jmp common_dyntree_clear_done
common_dyntree_clear_success:
	mov ax, 1
common_dyntree_clear_done:
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


; Removes a subtree rooted in the specified node.
; The specified node and all its descendants are removed.
;
; input:
;	 FS:BX - pointer to pointer to root
;	 DS:SI - pointer to root node of the subtree to remove
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dyntree_subtree_remove:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_subtree_remove_fail
	
	; these will be used by the callback
	mov word [cs:ctreeSubtreeRemove_rootSeg], fs
	mov word [cs:ctreeSubtreeRemove_rootOff], bx
	mov word [cs:ctreeSubtreeRemove_payloadLength], cx
	
	; here, DS:SI = pointer to input node
	push cs
	pop es
	mov di, ctree_remove_leaf_callback
	call common_dyntree_subtree_foreach_postorder
	; postorder is suitable because it traverses children first, guaranteeing
	; traversal of leaves before inner nodes
	jmp common_dyntree_subtree_remove_success
	
common_dyntree_subtree_remove_fail:
	mov ax, 0
	jmp common_dyntree_subtree_remove_done
common_dyntree_subtree_remove_success:
	mov ax, 1
common_dyntree_subtree_remove_done:
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
;		CX - element length, in bytes, maximum 19,900 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dyntree_subtree_foreach_ancestor:
	pusha
	push ds
	push es
	push fs
	push gs
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_subtree_foreach_ancestor_done
	
common_dyntree_subtree_foreach_ancestor_loop:
	; here, DS:SI = pointer to node
	call common_dyntree_get_parent				; DS:SI := pointer to parent
	cmp ax, 0
	je common_dyntree_subtree_foreach_ancestor_done
	; we got the parent
	
	; BEGIN WORK ON NODE
	
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; 1. setup return address
	push cs
	push word common_dyntree_subtree_foreach_ancestor_callback_return
												; return address on stack
	; 2. setup "call far" site address
	push es			; callback segment
	push di			; callback offset
	
	; 3. setup callback arguments
	; here, DS:SI = pointer to node
	
	; 4. invoke callback
	retf			; "call far"
	; once the callback executes its own retf, execution returns below
common_dyntree_subtree_foreach_ancestor_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	
	; END WORK ON NODE
	jmp common_dyntree_subtree_foreach_ancestor_loop		; next ancestor
	
common_dyntree_subtree_foreach_ancestor_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
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
;		CX - element length, in bytes, maximum 19,900 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dyntree_subtree_foreach_preorder:
	pusha
	push ds
	push es
	push fs
	push gs
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_subtree_foreach_preorder_done
	
	; preorder traversal algorithm:
	;
	; workStack.push ROOT	
	; while workStack not empty
	;     NODE := workStack.pop
	;     (act on NODE)
	;
	;     foreach child in NODE.children:
	;         resultStack.push child
	;     while resultStack not empty
	;         child := resultStack.pop
	;         workStack.push child
	
	mov dx, 0									; specified node is at depth 0
	call ctree_work_stack_push					; push node
common_dyntree_subtree_foreach_preorder_loop:
	call ctree_work_stack_pop					; DS:SI := node
												; DX := depth
	cmp ax, 0									; was stack empty?
	je common_dyntree_subtree_foreach_preorder_done	; yes
	; no, we actually popped something

	; BEGIN WORK ON NODE
	
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; 1. setup return address
	push cs
	push word common_dyntree_subtree_foreach_preorder_callback_return
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
common_dyntree_subtree_foreach_preorder_callback_return:
	mov word [cs:ctreeCallbackReturnAx], ax
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	
	; END WORK ON NODE
	
	cmp word [cs:ctreeCallbackReturnAx], 0
	je common_dyntree_subtree_foreach_preorder_done	; callback said "stop"
	
	; we're now about to put this node's children on the stack,
	; so we're one level deeper
	inc dx										; next depth level
	call common_dyntree_get_first_child			; DS:SI := first child
common_dyntree_subtree_foreach_preorder_children:
	; push all children onto result stack
	
	; here, DS:SI = potential child
	cmp ax, 0									; is this a child?
	je common_dyntree_subtree_foreach_preorder_back_on_work	; no
	; this is a child
	call ctree_result_stack_push				; push child
	call common_dyntree_get_next_sibling		; DS:SI := next child
	jmp common_dyntree_subtree_foreach_preorder_children
	
common_dyntree_subtree_foreach_preorder_back_on_work:
	; move children from result stack to work stack, reversing their order
	call ctree_result_stack_pop					; DS:SI := node
												; DX := depth
	cmp ax, 0
	je common_dyntree_subtree_foreach_preorder_loop	; result stack is empty
	call ctree_work_stack_push					; move this child to work stack
	jmp common_dyntree_subtree_foreach_preorder_back_on_work
	
common_dyntree_subtree_foreach_preorder_done:
	call ctree_stacks_clear
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret


; Returns statistics of the subtree rooted at the specified node
;
; input:
;	 DS:SI - pointer to node
;		CX - element length, in bytes, maximum 19,900 bytes
; output:
;		AX - height
;		BX - number of nodes
;		CX - number of nodes (placeholder for further statistic)
;		DX - number of nodes (placeholder for further statistic)
common_dyntree_subtree_statistics:
	push ds
	push es
	push fs
	push gs
	push si
	push di
	
	mov word [cs:ctreeStatsMaxDepth], 0
	mov word [cs:ctreeStatsNodeCount], 0
	
	push cs
	pop es
	mov di, ctree_statistics_callback		; ES:DI := ptr to callback
	call common_dyntree_subtree_foreach_postorder	; traverse
	
	mov ax, word [cs:ctreeStatsMaxDepth]
	mov bx, word [cs:ctreeStatsNodeCount]
	mov cx, bx
	mov dx, bx
	
	cmp bx, 0
	je common_dyntree_subtree_statistics_done	; no nodes, so height = 0
	; we had nodes, so height := max depth + 1
	inc ax
common_dyntree_subtree_statistics_done:
	pop di
	pop si
	pop gs
	pop fs
	pop es
	pop ds
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
;		CX - element length, in bytes, maximum 19,900 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dyntree_subtree_foreach_postorder:
	pusha
	push ds
	push es
	push fs
	push gs
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_subtree_foreach_postorder_done
	
	; postorder traversal algorithm:
	;
	; workStack.push ROOT	
	; while workStack not empty
	;     NODE := workStack.pop
	;     resultStack.push NODE
	;     foreach child in NODE.children:
	;         workStack.push child
	;
	; while resultStack not empty
	;     NODE := resultStack.pop
	;     (act on NODE)
	
	mov dx, 0									; specified node is at depth 0
	call ctree_work_stack_push					; push node
	
common_dyntree_subtree_foreach_postorder_fill_results:
	call ctree_work_stack_pop					; DS:SI := node
												; DX := depth
	cmp ax, 0									; was stack empty?
	je common_dyntree_subtree_foreach_postorder_process_results	; yes
	; no, we actually popped something
	call ctree_result_stack_push				; push node on result stack
	; we're now about to put this node's children on the stack,
	; so we're one level deeper
	inc dx										; next depth level
	call common_dyntree_get_first_child			; DS:SI := first child
common_dyntree_subtree_foreach_postorder_fill_results_children:
	; here, DS:SI = potential child
	cmp ax, 0									; is this a child?
	je common_dyntree_subtree_foreach_postorder_fill_results	; no
	; this is a child
	call ctree_work_stack_push					; push child
	call common_dyntree_get_next_sibling		; DS:SI := next child
	jmp common_dyntree_subtree_foreach_postorder_fill_results_children

common_dyntree_subtree_foreach_postorder_process_results:
	call ctree_result_stack_pop					; DS:SI := node
												; DX := depth
	; here, DS:SI = potential node to act on
	cmp ax, 0									; did we pop something?
	je common_dyntree_subtree_foreach_postorder_done	; no, we're done
	; BEGIN WORK ON NODE
	
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; 1. setup return address
	push cs
	push word common_dyntree_subtree_foreach_postorder_callback_return
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
common_dyntree_subtree_foreach_postorder_callback_return:
	mov word [cs:ctreeCallbackReturnAx], ax
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	
	; END WORK ON NODE
	cmp word [cs:ctreeCallbackReturnAx], 0
	je common_dyntree_subtree_foreach_postorder_done	; callback said "stop"
	
	jmp common_dyntree_subtree_foreach_postorder_process_results
	
common_dyntree_subtree_foreach_postorder_done:
	call ctree_stacks_clear
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret
	

; Returns a pointer to the next sibling of the specified node
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to next sibling, if any
common_dyntree_get_next_sibling:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_get_next_sibling_fail
	
	call ctree_is_root
	cmp ax, 0
	jne common_dyntree_get_next_sibling_fail	; fail if node is root
	
	call ctree_get_children_list_head_ptr
											; FS:BX := ptr to ptr to list head
	cmp ax, 0
	je common_dyntree_get_next_sibling_fail
	
	add cx, CTREE_OVERHEAD_BYTES				; CX := tree node size
	call common_llist_get_next					; DS:SI := ptr to next sibling
	cmp ax, 0
	je common_dyntree_get_next_sibling_fail

	jmp common_dyntree_get_next_sibling_success
	
common_dyntree_get_next_sibling_fail:
	mov ax, 0
	jmp common_dyntree_get_next_sibling_done
common_dyntree_get_next_sibling_success:
	mov ax, 1
common_dyntree_get_next_sibling_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret



; Returns a pointer to the child of the specified node that is
; at the specified index
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
;		DX - index
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to child at specified index, if any
common_dyntree_get_child_at_index:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_get_child_at_index_fail
	
	call ctree_get_children_list_head_ptr
											; FS:BX := ptr to ptr to list head
	cmp ax, 0
	je common_dyntree_get_child_at_index_fail
	
	add cx, CTREE_OVERHEAD_BYTES				; CX := tree node size
	call common_llist_get_at_index				; DS:SI := ptr to child
	cmp ax, 0
	je common_dyntree_get_child_at_index_fail

	jmp common_dyntree_get_child_at_index_success
	
common_dyntree_get_child_at_index_fail:
	mov ax, 0
	jmp common_dyntree_get_child_at_index_done
common_dyntree_get_child_at_index_success:
	mov ax, 1
common_dyntree_get_child_at_index_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Returns the number of children of the specified node
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - child count
common_dyntree_get_child_count:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_get_child_count_zero
	
	call ctree_get_children_list_head_ptr
											; FS:BX := ptr to ptr to list head
	cmp ax, 0
	je common_dyntree_get_child_count_zero
	
	add cx, CTREE_OVERHEAD_BYTES			; CX := tree node size
	call common_llist_count					; AX := count
	jmp common_dyntree_get_child_count_done
	
common_dyntree_get_child_count_zero:
	mov ax, 0
common_dyntree_get_child_count_done:
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


; Checks whether the specified node has any children
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when node has no children, other value otherwise
common_dyntree_has_children:
	pusha
	push ds

	call common_dyntree_get_first_child
	cmp ax, 0
	je common_dyntree_has_children_no
	
common_dyntree_has_children_yes:
	pop ds
	popa
	mov ax, 1
	ret	
common_dyntree_has_children_no:
	pop ds
	popa
	mov ax, 0
	ret


; Returns a pointer to specified node's first child node, if specified node
; exists and has at least one child
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to node's first child node, if any
common_dyntree_get_first_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_get_first_child_fail
	
	call ctree_get_children_list_head_ptr
											; FS:BX := ptr to ptr to list head
	cmp ax, 0
	je common_dyntree_get_first_child_fail
	
	call common_llist_get_head					; DS:SI := ptr to first child
	cmp ax, 0
	je common_dyntree_get_first_child_fail

	jmp common_dyntree_get_first_child_success
	
common_dyntree_get_first_child_fail:
	mov ax, 0
	jmp common_dyntree_get_first_child_done
common_dyntree_get_first_child_success:
	mov ax, 1
common_dyntree_get_first_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret

; Returns a pointer to root's first child node, if root exists and
; has at least one child.
; This call is useful after root is replaced via common_dyntree_add_root,
; for the consumer to get a pointer to the reallocated old root node.
;
; input:
;	 FS:BX - pointer to pointer to root
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to root's first child node, if any
common_dyntree_get_roots_first_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_get_roots_first_child_fail
	
	call common_dyntree_get_root					; DS:SI := ptr to root
	cmp ax, 0
	je common_dyntree_get_roots_first_child_fail	; no root

	call common_dyntree_get_first_child
	cmp ax, 0
	je common_dyntree_get_roots_first_child_fail	; no children
	
	jmp common_dyntree_get_roots_first_child_success
	
common_dyntree_get_roots_first_child_fail:
	mov ax, 0
	jmp common_dyntree_get_roots_first_child_done
common_dyntree_get_roots_first_child_success:
	mov ax, 1
common_dyntree_get_roots_first_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Removes a leaf node - that is, which has no child nodes
;
; input:
;	 FS:BX - pointer to pointer to root
;	 DS:SI - pointer to node to remove
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
common_dyntree_remove:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs
	push gs
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_remove_fail
	
	push fs
	push bx									; [1]
	
	call ctree_get_children_list_head_ptr
											; FS:BX := ptr to children list
	call common_llist_has_any
	cmp ax, 0
	pop bx
	pop fs									; [1] FS:BX := ptr to tree struct
	jne common_dyntree_remove_fail			; node has children, so we fail
	; node has no children, so we can delete it
	
	test byte [fs:bx+4], CTREE_FLAG_HAS_ROOT	; does root exist?
	jz common_dyntree_remove_fail				; no
	
	; is the root the node we're removing?
	mov ax, ds
	cmp word [fs:bx+0], ax					; match on segment?
	jne common_dyntree_remove__nonroot		; no
	cmp word [fs:bx+2], si					; match on offset?
	jne common_dyntree_remove__nonroot		; no
	
common_dyntree_remove__root:
	; we're removing the root, so mark pointer to pointer to root as having
	; no root
	mov al, CTREE_FLAG_HAS_ROOT
	xor al, 0FFh
	and byte [fs:bx+4], al					; we no longer have a root
	; and now remove the node
	call common_memory_deallocate
	cmp ax, 0
	je common_dyntree_remove_fail
	jmp common_dyntree_remove_success
	
common_dyntree_remove__nonroot:
	; here, DS:SI = node to remove
	mov bx, cx								; BX := consumer payload length
	push word [ds:si+bx+0]
	push word [ds:si+bx+2]
	pop bx
	pop fs									; FS:BX := pointer to parent node
	
	add bx, cx								; FS:BX := ptr to parent node ovrhd
	add bx, CTREE_SPECIFIC_OVERHEAD_BYTES	; FS:BX := ptr to parent node
											; child list
	add cx, CTREE_OVERHEAD_BYTES
	call common_llist_remove
	cmp ax, 0
	je common_dyntree_remove_fail
	
	jmp common_dyntree_remove_success
	
common_dyntree_remove_fail:
	mov ax, 0
	jmp common_dyntree_remove_done
common_dyntree_remove_success:
	mov ax, 1
common_dyntree_remove_done:
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


; Changes the parent of the specified node
;
; input:
;	 DS:SI - pointer to node to move
;	 ES:DI - pointer to node to become the new parent
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to moved node, when successful
common_dyntree_change_parent:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_change_parent_fail
		
	call ctree_is_root							; AX := 0 when not root
	cmp ax, 0
	jne common_dyntree_change_parent_fail		; can't change parent of root

	; check whether we're moving the node to itself
	mov ax, ds
	mov dx, es
	cmp ax, dx									; match on segment?
	jne common_dyntree_change_parent_valid		; no
	cmp si, di									; match on offset?
	je common_dyntree_change_parent_fail		; yes, so we're trying to add
												; the node to itself
	; destination parent and node are different
common_dyntree_change_parent_valid:
	
	mov bx, cx									; BX := payload size
	
	; check whether the destination parent is equal to current parent
	mov ax, es
	mov dx, word [ds:si+bx+0]
	cmp ax, dx									; match on segment?
	jne common_dyntree_change_parent_valid2		; no, so it's valid
	cmp di, word [ds:si+bx+2]					; match on offset?
	je common_dyntree_change_parent_success		; yes, so destination parent
												; is equal to current parent
	
common_dyntree_change_parent_valid2:
	; change parent reference of node to move
	push word [ds:si+bx+0]
	push word [ds:si+bx+2]						; [1] save ptr to old parent
	push ds
	push si										; [2] save ptr to node to move
	
	mov word [ds:si+bx+0], es
	mov word [ds:si+bx+2], di					; set new parent
	
	; add node as child to new parent
	push es
	pop ds
	mov si, di									; DS:SI := new parent
	
	pop di
	pop es										; [2] ES:DI := node to move
	
	push es
	push di										; [3] save ptr to node to move
	call common_dyntree_add_child				; DS:SI := ptr to moved node
	cmp ax, 0
	je common_dyntree_change_parent___clean_stack_and_fail
	
	; now remove node from old parent's child list
	push ds
	pop es
	mov di, si									; ES:DI := ptr to moved node
	
	pop si
	pop ds										; [3] DS:SI := node to move
	
	; here, CX = consumer payload size
	pop bx
	pop fs										; [1] FS:BX := old parent
	add bx, cx									; FS:BX := ptr to tree overhead
	add bx, CTREE_SPECIFIC_OVERHEAD_BYTES		; FS:BX := ptr to child node
												; list structure of old parent
	add cx, CTREE_OVERHEAD_BYTES				; CX := node size
	call common_llist_remove
	cmp ax, 0
	je common_dyntree_change_parent_fail

	push es
	pop ds
	mov si, di									; DS:SI := moved node
	jmp common_dyntree_change_parent_success
	
common_dyntree_change_parent___clean_stack_and_fail:
	; there are 2 pointers on the stack, seg:off
	; 2 * 4 = 8 bytes
	add sp, 8
	; fail
common_dyntree_change_parent_fail:
	mov ax, 0
	jmp common_dyntree_change_parent_done
common_dyntree_change_parent_success:
	mov ax, 1
common_dyntree_change_parent_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret
	ret
	

; Adds the payload as a new node, becoming a child of the specified node
;
; input:
;	 ES:DI - pointer to payload to add as a new node
;		CX - payload length, in bytes, maximum 19,900 bytes
;	 DS:SI - pointer to node that will be the parent of new node
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new node, when successful
common_dyntree_add_child:
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push di

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_add_child_fail
	
	push ds
	push si											; [1] save parent
	
	call ctree_allocate_node						; DS:SI := new node data
	cmp ax, 0										; [*]

	push ds
	pop es
	mov di, si										; ES:DI := new node data
	
	pop si
	pop ds											; [1] DS:SI := parent
	
	je common_dyntree_add_child_fail				; [*]
	
	push ds
	pop gs
	mov dx, si										; GS:DX := parent

	call ctree_get_children_list_head_ptr
											; FS:BX := child list of parent
	cmp ax, 0
	je common_dyntree_add_child___deallocate_and_fail
	
	add cx, CTREE_OVERHEAD_BYTES

	; here, ES:DI = new node data
	; here, CX = tree node payload size
	; here, FS:BX = child list or parent
	call common_llist_add							; DS:SI := new child
	cmp ax, 0
	je common_dyntree_add_child___deallocate_and_fail
	
	; set reference to parent in new node
	sub cx, CTREE_OVERHEAD_BYTES				; CX := consumer payload size
	add si, cx									; DS:SI := ptr to tree overhead
	mov word [ds:si+0], gs
	mov word [ds:si+2], dx						; store pointer to parent
	or byte [ds:si+4], CTREE_FLAG_HAS_PARENT
	
	sub si, cx									; DS:SI := new child
	
	push ds
	push si										; [2] save ptr to new child
	
	; deallocate node data
	push es
	pop ds
	mov si, di									; DS:SI := node data
	call common_memory_deallocate
	pop si
	pop ds										; [2] DS:SI := new child
	cmp ax, 0
	je common_dyntree_add_child_fail
	jmp common_dyntree_add_child_success
	
common_dyntree_add_child___deallocate_and_fail:
	; here, ES:DI = new node we must deallocate
	push es
	pop ds
	mov si, di
	call common_memory_deallocate
	
common_dyntree_add_child_fail:
	mov ax, 0
	jmp common_dyntree_add_child_done
common_dyntree_add_child_success:
	mov ax, 1
common_dyntree_add_child_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret


; Returns a pointer to the parent node of the specified node,
; if one exists
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to parent node, if it exists
common_dyntree_get_parent:

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_get_parent_fail
	
	add si, cx							; DS:SI := ptr to tree overhead bytes

	test byte [ds:si+4], CTREE_FLAG_HAS_PARENT
	jz common_dyntree_get_parent_fail
	
	push word [ds:si+0]
	push word [ds:si+2]
	pop si
	pop ds								; DS:SI := ptr to parent
	jmp common_dyntree_get_parent_success
	
common_dyntree_get_parent_fail:
	mov ax, 0
	jmp common_dyntree_get_parent_done
common_dyntree_get_parent_success:
	mov ax, 1
common_dyntree_get_parent_done:
	ret


; Invokes a callback function for each child of the specified node
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree
;        callback is NOT required to preserve any registers
;        callback input:
;                    DS:SI - pointer to currently-iterated child
;                       DX - index of currently-iterated child
;        callback output:
;                       none
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
;	 ES:DI - pointer to callback function
; output:
;		none
common_dyntree_children_foreach:
	pusha
	push ds
	push es
	push fs

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_children_foreach_done
	
	call ctree_get_children_list_head_ptr	; FS:BX := ptr to children
	cmp ax, 0
	je common_dyntree_children_foreach_done
	
	; now call foreach on the linked list representing the node's children
	push es
	pop ds
	mov si, di										; DS:SI := callback
	add cx, CTREE_OVERHEAD_BYTES
	call common_llist_foreach
	
common_dyntree_children_foreach_done:
	pop fs
	pop es
	pop ds
	popa
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
common_dyntree_set_root_by_ptr:
	pusha
	
	mov word [fs:bx+0], ds
	mov word [fs:bx+2], si					; store pointer to new node
	or byte [fs:bx+4], CTREE_FLAG_HAS_ROOT	; indicate that root exists
	
	popa
	ret
	

; Adds a root node.
; If existing, the old root becomes the new root's only child.
;
; NOTE: old root, if existing, is reallocated, invalidating existing
;       pointers to it held by the consumer application
;
; input:
;	 FS:BX - pointer to pointer to root
;	 ES:DI - pointer to payload to add as a new root
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to new root, when successful
common_dyntree_add_root:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	push gs

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja common_dyntree_add_root_fail
	
	call ctree_allocate_node			; DS:SI := pointer to new node
	cmp ax, 0
	je common_dyntree_add_root_fail
	
	push ds
	pop es
	mov di, si							; ES:DI := pointer to new node
	
	; reference new node from the pointer to pointer to root structure
	call common_dyntree_get_root		; [*] DS:SI := pointer to existing root
	
	mov word [fs:bx+0], es
	mov word [fs:bx+2], di					; store pointer to new node
	or byte [fs:bx+4], CTREE_FLAG_HAS_ROOT	; indicate that root exists
	
	cmp ax, 0							; [*]
	jne common_dyntree_add_root__already_has	; already has root

common_dyntree_add_root__doesnt_already_have:
	; here, DS:SI = undefined
	; here, ES:DI = pointer to new root
	push es
	pop ds
	mov si, di								; DS:SI := pointer to new root
	jmp common_dyntree_add_root_success
	
common_dyntree_add_root__already_has:
	; here, FS:BX = pointer to pointer to root
	; here, DS:SI = pointer to old root
	; here, ES:DI = pointer to new root
	; here, CX = payload length

	; add old root as a child of the new root
	push ds
	push es
	pop ds
	pop es							; DS:SI := pointer to new root
	xchg si, di						; ES:DI := pointer to old root
	
	push fs
	push bx							; [2] save pointer to pointer to root

	push ds
	pop fs
	mov bx, si						; FS:BX := pointer to new root
	add bx, cx						; FS:BX := pointer to new root overhead
	add bx, CTREE_SPECIFIC_OVERHEAD_BYTES
									; FS:BX := ptr to new root list overhead
									; (which is the ptr to child list head)
	add cx, CTREE_OVERHEAD_BYTES	; also include tree node overhead in the
									; amount to add to list node
	push ds
	push si							; [1] save pointer to new root

	; here, ES:DI = pointer to old root, old memory
	call common_llist_add			; add old root as a child of new root
									; DS:SI := pointer to old root, new memory
	push ds
	pop gs
	mov dx, si						; GS:DX := pointer to old root, new memory
								
	pop si
	pop ds							; [1] DS:SI := new root
	
	pop bx
	pop fs							; [2] FS:BX := pointer to pointer to root
									
	cmp ax, 0
	je common_dyntree_add_root__already_has__reference_failed

	; since llist_add copies memory, deallocate old root
	; here, ES:DI = pointer to old root, old memory
	push ds
	push si							; [3] save new root
	
	push es
	pop ds
	mov si, di						; DS:SI := ptr to old root, old memory
	call common_memory_deallocate
	pop si
	pop ds							; [3] DS:SI := new root
	cmp ax, 0
	je common_dyntree_add_root_fail
	
	; save pointer to parent (new root) in old root, new memory
	; here, GS:DX = pointer to old root, new memory
	sub cx, CTREE_OVERHEAD_BYTES	; CX := payload length
	add dx, cx						; GS:DX := pointer to tree overhead bytes
									; (in old root, new memory)
	mov bx, dx						; GS:BX := pointer to tree overhead bytes

	mov word [gs:bx+0], ds
	mov word [gs:bx+2], si
	or byte [gs:bx+4], CTREE_FLAG_HAS_PARENT	; store parent reference
	
	jmp common_dyntree_add_root_success
	
common_dyntree_add_root__already_has__reference_failed:
	; we failed to add a reference from new root to old root
	; because we couldn't allocate [old root, new memmory]
	
	; here, ES:DI = pointer to old root
	; here, DS:SI = pointer to new root
	; here, FS:BX = pointer to pointer to root
	
	; point root structure at the old root
	mov word [fs:bx+0], es
	mov word [fs:bx+2], di					; store ptr to old root, old memory
	or byte [fs:bx+4], CTREE_FLAG_HAS_ROOT	; indicate that root exists
	
	; deallocate new root
	call common_memory_deallocate			; deallocate new root
	jmp common_dyntree_add_root_fail
	
common_dyntree_add_root_fail:
	mov ax, 0
	jmp common_dyntree_add_root_done
common_dyntree_add_root_success:
	mov ax, 1
common_dyntree_add_root_done:
	pop gs
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret

	
; Gets the root node
;
; input:
;	 FS:BX - pointer to pointer to root
; output:
;		AX - 0 when an error occurred or no root, other value otherwise
;	 DS:SI - pointer to root, when successful
common_dyntree_get_root:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	call ctree_assert_memory
	
	test byte [fs:bx+4], CTREE_FLAG_HAS_ROOT	; does root exist?
	jz common_dyntree_get_root_fail				; no
	; yes, so return it
	
	push word [fs:bx+0]
	pop ds
	mov si, word [fs:bx+2]						; DS:SI := root
	jmp common_dyntree_get_root_success
	
common_dyntree_get_root_fail:
	mov ax, 0
	jmp common_dyntree_get_root_done
common_dyntree_get_root_success:
	mov ax, 1
common_dyntree_get_root_done:
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret


; Allocates a new tree node based on a temporary buffer provided by
; the consumer.
; The temporary buffer holds the consumer payload and is copied into
; the newly-allocated node.
; The node's pointer to pointer to head of list structure is initialized.
; The node is marked as having no parent.
;
; input:
;	 ES:DI - pointer to payload to add as a new node
;		CX - node payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 DS:SI - pointer to newly allocated node, when successful
ctree_allocate_node:
	pushf
	push bx
	push cx
	push dx
	push di
	push es
	push fs

	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja ctree_allocate_node_fail
	
	mov ax, cx
	add ax, CTREE_OVERHEAD_BYTES
	call common_memory_allocate			; DS:SI := pointer to new node
	cmp ax, 0
	je ctree_allocate_node_fail
	
	push ds
	push si								; [1] save pointer to new node
	
	xchg si, di
	push ds
	push es
	pop ds								; DS:SI := pointer to input buffer
	pop es								; ES:DI := pointer to new node
	
	push cx								; [2] save payload size
	push di								; [3] save pointer to new node
	
	; here, CX = payload size
	cld
	rep movsb							; copy input buffer into new node

	pop di								; [3] ES:DI := pointer to new node
	pop cx								; [2] CX := payload size
	
	; populate tree-specific overhead
	add di, cx							; ES:DI := pointer to overhead bytes
	mov byte [es:di+4], 0				; flags: no parent
	
	; populate list's head pointer
	add di, CTREE_SPECIFIC_OVERHEAD_BYTES	; ES:DI := pointer to linked list 
											; pointer to pointer to head
	mov al, COMMON_LLIST_HEAD_PTR_INITIAL
	mov cx, COMMON_LLIST_HEAD_PTR_LENGTH
	rep stosb							; populate pointer to pointer to
										; list head
	pop si
	pop ds								; [1] DS:SI := new node

	jmp ctree_allocate_node_success
	
ctree_allocate_node_fail:
	mov ax, 0
ctree_allocate_node_success:
	mov ax, 1
ctree_allocate_node_done:
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	popf
	ret

	
; Exits task and prints an error message if dynamic memory module was
; not initialized.
;
; input:
;		none
; output:
;		none
ctree_assert_memory:
	pusha
	push ds
	
	call common_memory_is_initialized
	cmp ax, 0
	jne ctree_assert_memory_success
	; not initialized
	push cs
	pop ds
	mov si, commonTreeNoMemory
	int 80h
	mov ah, 0
	int 16h
	mov cx, 200
	int 85h							; delay
	int 95h							; exit task
ctree_assert_memory_success:
	pop ds
	popa
	ret
	
	
; Returns whether the specified node is root or not
;
; input:
;	 DS:SI - pointer to node to check
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when node is not root, other value otherwise
ctree_is_root:
	push si
	
	mov ax, 0						; assume not root
	
	add si, cx						; DS:SI := pointer to tree overhead bytes
	test byte [ds:si+4], CTREE_FLAG_HAS_PARENT
	jnz ctree_is_root_done			; parent, so it's not root
	
	mov ax, 1						; "it is root"
ctree_is_root_done:
	pop si
	ret

	
; Pushes a pointer on the work stack
;
; input:
;	 DS:SI - pointer
;		DX - depth
; output:
;		AX - 0 when an error occurred, other value otherwise
ctree_work_stack_push:
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
	mov di, ctreePtrTempStorage			; ES:DI := temp storage for pointers
	mov word [es:di+0], ds
	mov word [es:di+2], si
	mov word [es:di+4], dx				; depth
	
	push cs
	pop fs
	mov bx, ctreeWorkStackHeadPtr		; FS:BX := ptr to ptr to stack top
	
	mov cx, CTREE_NODE_PTR_SIZE
	call common_dynstack_push
	cmp ax, 0
	je ctree_work_stack_push_fail
	jmp ctree_work_stack_push_success
	
ctree_work_stack_push_fail:
	mov ax, 0
	jmp ctree_work_stack_push_done
ctree_work_stack_push_success:
	mov ax, 1
ctree_work_stack_push_done:
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
	
	
; Pushes a pointer on the result stack
;
; input:
;	 DS:SI - pointer
;		DX - depth
; output:
;		AX - 0 when an error occurred, other value otherwise
ctree_result_stack_push:
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
	mov di, ctreePtrTempStorage			; ES:DI := temp storage for pointers
	mov word [es:di+0], ds
	mov word [es:di+2], si
	mov word [es:di+4], dx				; depth
	
	push cs
	pop fs
	mov bx, ctreeResultStackHeadPtr		; FS:BX := ptr to ptr to stack top
	
	mov cx, CTREE_NODE_PTR_SIZE
	call common_dynstack_push
	cmp ax, 0
	je ctree_result_stack_push_fail
	jmp ctree_result_stack_push_success
	
ctree_result_stack_push_fail:
	mov ax, 0
	jmp ctree_result_stack_push_done
ctree_result_stack_push_success:
	mov ax, 1
ctree_result_stack_push_done:
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
	
	
; Pops a pointer from work stack
;
; input:
;		none
; output:
;		AX - 0 when stack is empty, other value otherwise
;	 DS:SI - pointer to popped element
;		DX - depth
ctree_work_stack_pop:
	push es
	push fs
	push gs
	push bx
	push cx
	push di

	push cs
	pop fs
	mov bx, ctreeWorkStackHeadPtr		; FS:BX := ptr to ptr to stack top
	
	mov cx, CTREE_NODE_PTR_SIZE
	call common_dynstack_pop			; DS:SI := pointer to popped node
	cmp ax, 0
	je ctree_work_stack_pop_fail
	
	push word [ds:si+0]
	push word [ds:si+2]					; save payload (which is a pointer)
	mov dx, word [ds:si+4]				; DX := depth
	
	call common_memory_deallocate		; consumer must deallocate pointer
	pop si
	pop ds								; DS:SI := payload
	cmp ax, 0
	je ctree_work_stack_pop_fail
	
	mov ax, 1
	jmp ctree_work_stack_pop_done
	
ctree_work_stack_pop_fail:
	mov ax, 0
ctree_work_stack_pop_done:
	pop di
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret
	
	
; Pops a pointer from result stack
;
; input:
;		none
; output:
;		AX - 0 when stack is empty, other value otherwise
;	 DS:SI - pointer to popped element
;		DX - depth
ctree_result_stack_pop:
	push es
	push fs
	push gs
	push bx
	push cx
	push di

	push cs
	pop fs
	mov bx, ctreeResultStackHeadPtr		; FS:BX := ptr to ptr to stack top
	
	mov cx, CTREE_NODE_PTR_SIZE
	call common_dynstack_pop			; DS:SI := pointer to popped node
	cmp ax, 0
	je ctree_result_stack_pop_fail
	
	push word [ds:si+0]
	push word [ds:si+2]					; save payload (which is a pointer)
	mov dx, word [ds:si+4]				; DX := depth
	
	call common_memory_deallocate		; consumer must deallocate pointer
	pop si
	pop ds								; DS:SI := payload
	cmp ax, 0
	je ctree_result_stack_pop_fail
	
	mov ax, 1
	jmp ctree_result_stack_pop_done
	
ctree_result_stack_pop_fail:
	mov ax, 0
ctree_result_stack_pop_done:
	pop di
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	ret
	
	
; Clears all stacks used by traversals.
; This is an easy way to not leak memory if stack operations fail during
; traversals.
;
; input:
;		none
; output:
;		none
ctree_stacks_clear:
	pusha
	push ds
	push es
	push fs
	push gs

	push cs
	pop fs
	mov bx, ctreeResultStackHeadPtr
	mov cx, CTREE_NODE_PTR_SIZE
	call common_dynstack_clear

	mov bx, ctreeWorkStackHeadPtr
	call common_dynstack_clear
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Callback for gathering statistics
;
; NOTES: callback MUST use retf to return
;        behaviour is undefined if callback modifies tree structure
;        callback is NOT required to preserve any registers
;
; input:
;	 DS:SI - pointer to currently-traversed node
;		DX - depth relative to root of traversed subtree
; output:
;		AX - 0 when traversal must stop, other value otherwise
ctree_statistics_callback:
	inc word [cs:ctreeStatsNodeCount]
	
	cmp word [cs:ctreeStatsMaxDepth], dx
	jae ctree_statistics_callback_done
	mov word [cs:ctreeStatsMaxDepth], dx
ctree_statistics_callback_done:
	mov ax, 1						; continue traversal
	retf
	
	
; Callback for removal of subtrees.
; It removes a single leaf node from the tree.
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
ctree_remove_leaf_callback:
	push word [cs:ctreeSubtreeRemove_rootSeg]
	pop fs
	mov bx, word [cs:ctreeSubtreeRemove_rootOff]	; FS:BX := ptr to root
	mov cx, word [cs:ctreeSubtreeRemove_payloadLength]
											; CX := consumer paylaod length
	call common_dyntree_remove
	mov ax, 1						; continue traversal
	retf
	
	
; Callback for finding a byte.
; Assumes offset at which to search is low enough that there
; would be no overflow.
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
ctree_find_byte_callback:
	cmp byte [cs:ctreeSubtreeFindByteWasFound], 0
	jne ctree_find_byte_callback_done				; NOOP when already found

	mov bx, word [cs:ctreeSubtreeFindByteOffsetToSearch]
	mov dl, byte [cs:ctreeSubtreeFindByteByteToFind]
	cmp byte [ds:si+bx], dl							; match?
	jne ctree_find_byte_callback_done				; no
	; yes, this was a match

	mov word [cs:ctreeSubtreeFindByteFoundSegment], ds
	mov word [cs:ctreeSubtreeFindByteFoundOffset], si	; save found node
	mov byte [cs:ctreeSubtreeFindByteWasFound], 1
ctree_find_byte_callback_done:
	mov ax, 1						; continue traversal
	retf
	
	
; Callback for finding a word.
; Assumes offset at which to search is low enough that there
; would be no overflow.
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
ctree_find_word_callback:
	cmp byte [cs:ctreeSubtreeFindWordWasFound], 0
	jne ctree_find_word_callback_done				; NOOP when already found

	mov bx, word [cs:ctreeSubtreeFindWordOffsetToSearch]
	mov dx, word [cs:ctreeSubtreeFindWordWordToFind]
	cmp word [ds:si+bx], dx							; match?
	jne ctree_find_word_callback_done				; no
	; yes, this was a match

	mov word [cs:ctreeSubtreeFindWordFoundSegment], ds
	mov word [cs:ctreeSubtreeFindWordFoundOffset], si	; save found node
	mov byte [cs:ctreeSubtreeFindWordWasFound], 1
ctree_find_word_callback_done:
	mov ax, 1						; continue traversal
	retf


; Callback for finding a string.
; Assumes offset at which to search is low enough that there
; would be no overflow.
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
ctree_find_string_callback:
	cmp byte [cs:ctreeSubtreeFindStringWasFound], 0
	jne ctree_find_string_callback_done				; NOOP when already found

	push word [cs:ctreeSubtreeFindStringStringToFindSegment]
	pop es
	mov di, word [cs:ctreeSubtreeFindStringStringToFindOffset]
													; ES:DI := string
	push si											; [1] save node pointer
	add si, word [cs:ctreeSubtreeFindStringOffsetToSearch]
													; DS:SI := search location
	int 0BDh										; compare strings
	
	pop si											; [1] restore node pointer
	cmp ax, 0										; match?
	jne ctree_find_string_callback_done				; no
	; yes, this was a match

	mov word [cs:ctreeSubtreeFindStringFoundSegment], ds
	mov word [cs:ctreeSubtreeFindStringFoundOffset], si	; save found node
	mov byte [cs:ctreeSubtreeFindStringWasFound], 1
ctree_find_string_callback_done:
	mov ax, 1						; continue traversal
	retf
	
	

; Returns the pointer to pointer to head of the list containing
; the children of the specified node
;
; input:
;	 DS:SI - pointer to node
;		CX - payload length, in bytes, maximum 19,900 bytes
; output:
;		AX - 0 when an error occurred, other value otherwise
;	 FS:BX - pointer to pointer to head of children list, when successful
ctree_get_children_list_head_ptr:
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	call ctree_assert_memory
	
	cmp cx, CTREE_MAX_NODE_SIZE
	ja ctree_get_children_list_head_ptr_fail
	
	mov bx, si
	add bx, cx
	add bx, CTREE_SPECIFIC_OVERHEAD_BYTES
	push ds
	pop fs							; FS:BX := ptr to ptr to head of list
	
	jmp ctree_get_children_list_head_ptr_success
	
ctree_get_children_list_head_ptr_fail:
	mov ax, 0
	jmp ctree_get_children_list_head_ptr_done
ctree_get_children_list_head_ptr_success:
	mov ax, 1
ctree_get_children_list_head_ptr_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	ret
	

%include "common\memory.asm"
%include "common\dynamic\linklist.asm"
%include "common\dynamic\dyn_stk.asm"
	
%endif
