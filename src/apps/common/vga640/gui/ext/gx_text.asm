;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It implements an extension for Snowdrop OS's graphical user interface 
; (GUI) framework.
;
; This extension adds a text box.
; It currently only supports keyboard mode "typewriter".
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _GX_TEXT_
%define _GX_TEXT_

GX_TEXT_LIST_HEAD_PTR_LEN		equ COMMON_LLIST_HEAD_PTR_LENGTH
GX_TEXT_LIST_HEAD_PTR_INITIAL	equ COMMON_LLIST_HEAD_PTR_INITIAL

gxTextRegistrationNumber:	dw 0
gxTextNextId:				dw 0
gxTextIsInitialized:		db 0
gxTextNeedRendering:		db 0

gxTextMouseX:				dw 0
gxTextMouseY:				dw 0
gxTextEventBytesSeg:		dw 0
gxTextEventBytesOff:		dw 0		; used when handling events

; this list holds entities
gxTextListHeadPtr:	times GX_TEXT_LIST_HEAD_PTR_LEN db GX_TEXT_LIST_HEAD_PTR_INITIAL
				; byte
				; 0 - 1        ID of entity
				; 2 - 3        segment of pointer to text buffer
				; 4 - 5        offset of pointer to text buffer
				; 6 - 7        X location
				; 8 - 9        Y location
				; 10 - 11      flags
				; 12 - 13      flags before last render
				; 14 - 15      computed total width
				; 16 - 17      computed total height
				; 18 - 19      maximum text length in characters
				; 20 - 21      segment of text changed callback
				; 22 - 23      offset of text changed callback

GX_TEXT_PAYLOAD_SIZE	equ 24

GX_TEXT_FLAG_ENABLED			equ 1	; is clickable
GX_TEXT_FLAG_HOVERED			equ 2	; is hovered over by the mouse
GX_TEXT_FLAG_MUST_RENDER		equ 4	; must be redrawn
GX_TEXT_FLAG_PENDING_DELETE		equ 16	; is pending deletion
GX_TEXT_FLAG_HELD_DOWN_LEFT		equ 32	; is held down with a left click
GX_TEXT_FLAG_SELECTED			equ 128	; is selected

GX_TEXT_SINGLE_IMAGE_WIDTH		equ 16
GX_TEXT_SINGLE_IMAGE_HEIGHT		equ 16
GX_TEXT_SINGLE_IMAGE_PADDING	equ 4

GX_TEXT_GRAPHIC_HEIGHT			equ 32
GX_TEXT_GRAPHIC_WIDTH			equ 32

GX_TEXT_PADDING					equ 5	; between box edge and text

; stores data so it can be added as a new element
gxTextPayload:		times GX_TEXT_PAYLOAD_SIZE db 0

gxTextRenderMode:					db	99
GX_TEXT_RENDER_MODE_DELETIONS		equ 0
GX_TEXT_RENDER_MODE_MODIFICATIONS	equ 1
gxTextSelectedFound					db 0
gxTextSelectedSegment				dw 0
gxTextSelectedOffset				dw 0


; Initializes this extension
;
; input:
;		none
; output:
;		none
common_gx_text_initialize:
	pusha
	push ds
	push es
	
	cmp byte [cs:gxTextIsInitialized], 0
	jne common_gx_text_initialize_done
	
	call gx_register_extension	; register with the GUI extensions interface
	mov word [cs:gxTextRegistrationNumber], ax	; store our registration number
	
	; now register our callbacks
	push cs
	pop es
	mov ax, word [cs:gxTextRegistrationNumber]
	
	mov di, _gx_text_prepare
	call gx_register__on_prepare
	
	mov di, _gx_text_clear_storage
	call gx_register__on_clear_storage
	
	mov di, _gx_text_need_render
	call gx_register__on_need_render
	
	mov di, _gx_text_render_all
	call gx_register__on_render_all
	
	mov di, _gx_text_schedule_render_all
	call gx_register__on_schedule_render_all
	
	mov di, _gx_text_handle_event
	call gx_register__on_handle_event
	
	mov word [cs:gxTextNextId], 0
	mov byte [cs:gxTextIsInitialized], 1
common_gx_text_initialize_done:
	pop es
	pop ds
	popa
	ret

	
; Gets contents
;
; input:
;		AX - entity handle
; output:
;	 DS:SI - pointer to text contents
common_gx_text_contents_get:
	push ax
	push bx
	push cx
	push dx
	push di
	
	call _gx_text_find_entity
	cmp ax, 0
	je common_gx_text_contents_set_done
	
	push word [ds:si+2]
	push word [ds:si+4]
	pop si
	pop ds	
common_gx_text_contents_get_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

	
; Sets contents
;
; input:
;		AX - entity handle
;	 ES:DI - pointer to contents to set
; output:
;		none
common_gx_text_contents_set:
	pusha
	pushf
	push ds
	push es
	
	call _gx_text_find_entity
	cmp ax, 0
	je common_gx_text_contents_set_done
	
	push ds
	push si							; [1]
	
	or word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER
	
	mov cx, word [ds:si+18]			; CX := maximum length
	inc cx							; plus terminator
	
	push word [ds:si+2]
	push word [ds:si+4]
	mov si, di
	mov ax, es
	mov ds, ax						; DS:SI := ptr to source
	
	pop di
	pop es							; ES:DI := ptr to destination
	cld
	rep movsb
	
	mov byte [es:di-1], 0			; terminator, in case passed-in string
									; was too long
	mov byte [cs:gxTextNeedRendering], 1
	
	pop si
	pop ds							; [1]
	
	; invoke changed callback
	mov ax, word [ds:si+0]			; handle
	mov ds, word [ds:si+20]
	mov si, word [ds:si+22]
	call gui_invoke_callback
common_gx_text_contents_set_done:
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Selects an entity
;
; input:
;		AX - entity handle
; output:
;		none
common_gx_text_select:
	pusha
	push ds
	
	call _gx_text_find_entity
	cmp ax, 0
	je common_gx_text_select_done
	
	call _gx_select
common_gx_text_select_done:
	pop ds
	popa
	ret
	
	
; Deletes an entity
;
; input:
;		AX - entity handle
; output:
;		none
common_gx_text_delete:
	pusha
	push ds
	
	call _gx_text_find_entity
	cmp ax, 0
	je common_gx_text_delete_done
	; mark as deleted
	or word [ds:si+10], GX_TEXT_FLAG_PENDING_DELETE | GX_TEXT_FLAG_MUST_RENDER
	
	mov byte [cs:gxTextNeedRendering], 1
common_gx_text_delete_done:
	pop ds
	popa
	ret


; Adds an entity
;
; input:
;		AX - position X
;		BX - position Y
;		CX - maximum input length
; output:
;		AX - entity handle
common_gx_text_add:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs

	push ax
	mov ax, cs
	mov es, ax
	mov fs, ax
	pop ax
	
	; add a new list element
	mov di, gxTextPayload			; ES:DI := pointer to buffer
	
	; populate buffer
	mov word [es:di+6], ax				; X
	mov word [es:di+8], bx				; Y
	
	mov word [es:di+18], cx				; maximum text length
	
	mov ax, cx
	inc ax								; we allocate length+1 (for terminator)
	call common_memory_allocate			; DS:SI := allocated pointer
	mov byte [ds:si], 0					; start off with an empty string
	
	mov word [es:di+2], ds				; segment
	mov word [es:di+4], si				; offset
	
	call _gx_text_compute_box_dimensions	; AX := width, BX := height
	mov word [es:di+14], ax				; width
	mov word [es:di+16], bx				; height
	
	mov ax, word [cs:gxTextNextId]
	mov word [es:di+0], ax				; entity handle
	
	mov word [es:di+20], cs
	mov word [es:di+22], gui_noop_callback
	
	mov word [es:di+10], GX_TEXT_FLAG_ENABLED | GX_TEXT_FLAG_MUST_RENDER	; flags
	mov word [es:di+12], GX_TEXT_FLAG_ENABLED | GX_TEXT_FLAG_MUST_RENDER	; old flags	

	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	call common_llist_add				; DS:SI := new list element
	
	inc word [cs:gxTextNextId]
	mov byte [cs:gxTextNeedRendering], 1
	mov ax, word [ds:si+0]				; return handle in AX
	
	pop fs
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Sets the specified entity's changed callback, which is invoked whenever the
; entity is changed
;
; input:
;		AX - entity handle
;	 DS:SI - pointer to callback function
;			 callback contract:
;				input:
;					AX - entity handle
;				output:
;					none
;			 MUST return via retf
;			 not required to preserve any registers
; output:
;		none
common_gx_text_changed_callback_set:
	pusha
	push ds
	
	push ds
	push si
	
	call _gx_text_find_entity
	cmp ax, 0
	je common_gx_text_changed_callback_set_done

	pop word [ds:si+22]		; offset
	pop word [ds:si+20]		; segment
common_gx_text_changed_callback_set_done:	
	pop ds
	popa
	ret
	
	
; Clears the specified entity's changed callback
;
; input:
;		AX - entity handle
; output:
;		none
common_gx_text_changed_callback_clear:
	pusha
	push ds
	
	call _gx_text_find_entity
	cmp ax, 0
	je common_gx_text_changed_callback_clear_done
	
	mov word [ds:si+20], cs
	mov word [ds:si+22], gui_noop_callback
common_gx_text_changed_callback_clear_done:	
	pop ds
	popa
	ret
	

; Returns the size of the box large enough to contain the specified
; length of text
;
; input:
;		CX - text length
; output:
;		AX - width
;		BX - height
_gx_text_compute_box_dimensions:
	call common_graphics_text_measure_width_by_count	; AX := text width
	add ax, 2*GX_TEXT_PADDING
	add ax, 2											; box around text
	
	mov bx, COMMON_GRAPHICS_FONT_HEIGHT
	add bx, 2*GX_TEXT_PADDING
	add bx, 2											; box around text
	ret
	

; Removes all entities
;
; input:
;		none
; output:
;		none	
_gx_text_clear_list:
	pusha
	push ds
	push fs
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	
	; first, deallocate any resources we created
	mov si, _gx_text_deallocate_references_callback
	call common_llist_foreach
	
	; then, clear OUR entities
	call common_llist_clear
	
	pop fs
	pop ds
	popa
	ret
	
	
; Callback for deallocation of referenced data
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
_gx_text_deallocate_references_callback:
	; deallocate text buffer
	push word [ds:si+2]
	push word [ds:si+4]
	pop si
	pop ds
	call common_memory_deallocate

	mov ax, 1						; keep traversing
	retf


; Callback for rendering icons.
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
_gx_text_render_single_callback:
	push cs
	pop fs
	
_gx_text_render_single_callback__try_deletions:
	cmp byte [cs:gxTextRenderMode], GX_TEXT_RENDER_MODE_DELETIONS
	jne _gx_text_render_single_callback__try_modifications
	; we're only rendering deletions
	test word [ds:si+10], GX_TEXT_FLAG_PENDING_DELETE
	jz _gx_text_render_single_callback_done
	test word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER
	jz _gx_text_render_single_callback_done
	; this entity is pending delete

	call _gx_text_erase						; erase it from screen
	call _gx_text_remove_single_from_storage	; and from storage
	
	jmp _gx_text_render_single_callback_done
_gx_text_render_single_callback__try_modifications:
	cmp byte [cs:gxTextRenderMode], GX_TEXT_RENDER_MODE_MODIFICATIONS
	jne _gx_text_render_single_callback_done
	; we're only rendering modifications
	test word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER
	jz _gx_text_render_single_callback_done
	call _gx_text_erase				; erase it from screen
	call _gx_text_draw				; draw it anew
	
	mov ax, word [ds:si+10]
	mov word [ds:si+12], ax			; old flags := flags
	
	mov ax, GX_TEXT_FLAG_MUST_RENDER
	xor ax, 0FFFFh
	and word [ds:si+10], ax			; clear flags
	
_gx_text_render_single_callback_done:
	mov ax, 1						; keep traversing
	retf


; Removes the specified entity from storage, also deleting other
; entities it references
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none	
_gx_text_remove_single_from_storage:
	pusha
	push fs

	; deallocate text buffer
	push word [ds:si+2]
	push word [ds:si+4]
	pop si
	pop ds
	call common_memory_deallocate
	
	mov ax, cs
	mov fs, ax

	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	call common_llist_remove
	
	pop fs
	popa
	ret
	

; Erases the specified entity from the screen
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none
_gx_text_erase:
	pusha
	
	mov bx, word [ds:si+6]						; X
	mov ax, word [ds:si+8]						; Y
	call common_gui_get_colour_background		; CX := colour
	mov dx, cx
	mov cx, word [ds:si+14]						; width
	mov di, word [ds:si+16]						; height
	call common_graphics_draw_rectangle_solid
	
	popa
	ret
	
	
; Draws the specified entity to screen
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none
_gx_text_draw:
	pusha
	push ds

	; draw box
	push ds
	push si
	
	mov bx, word [ds:si+6]						; X
	mov ax, word [ds:si+8]						; Y
	call common_gui_get_colour_decorations		; CX := colour
	mov dx, cx
	mov cx, word [ds:si+14]						; width
	mov si, word [ds:si+16]						; height
	call common_graphics_draw_rectangle_outline_by_coords
	
	pop si
	pop ds
_gx_text_draw__after_box:
	test word [ds:si+10], GX_TEXT_FLAG_SELECTED
	jz _gx_text_draw__after_selected
	
	; draw cursor
	push ds
	push si

	push word [ds:si+6]							; [4] X
	push word [ds:si+8]							; [3] Y
	
	push word [ds:si+2]
	push word [ds:si+4]
	pop si
	pop ds										; DS:SI := ptr to text buffer
	call common_graphics_text_measure_width		; AX := width
	mov dx, ax
	
	pop ax										; [3] Y
	add ax, GX_TEXT_PADDING-1
	
	pop bx										; [4] X
	add bx, dx
	add bx, GX_TEXT_PADDING						; move to after text
	inc bx
	
	call common_gui_get_colour_decorations
	mov dx, cx
	mov cx, COMMON_GRAPHICS_FONT_HEIGHT + 4
	call common_graphics_draw_vertical_line_solid_by_coords
	inc bx
	call common_graphics_draw_vertical_line_solid_by_coords
	
	pop si
	pop ds	
_gx_text_draw__after_selected:
	test word [ds:si+10], GX_TEXT_FLAG_HOVERED
	jz _gx_text_draw__after_hovered
	
	; draw hover mark
	push ds
	push si
	
	call common_gui_get_colour_decorations		; CX := colour
	mov dx, cx
	
	mov bx, word [ds:si+6]						; X
	add bx, 2
	mov ax, word [ds:si+8]						; Y
	add ax, 2
	call common_graphics_draw_pixel_by_coords
	inc bx
	call common_graphics_draw_pixel_by_coords
	dec bx
	inc ax
	call common_graphics_draw_pixel_by_coords
	
	pop si
	pop ds
_gx_text_draw__after_hovered:
	; write text
	push ds
	push si
	
	mov bx, word [ds:si+6]						; X
	mov ax, word [ds:si+8]						; Y
	add bx, GX_TEXT_PADDING
	add ax, GX_TEXT_PADDING
	call common_gui_get_text_formatting			; DX := format
	call common_gui_get_colour_foreground		; CX := colour
	
	push word [ds:si+2]
	push word [ds:si+4]
	pop si
	pop ds										; DS:SI := ptr to text buffer

	call common_graphics_text_print_at
	
	pop si
	pop ds

	pop ds
	popa
	ret
	

; Prepares before usage
;
; MUST return via retf
; Not required to preserve any registers
;
; input:
;		none
; output:
;		none
_gx_text_prepare:
	call _gx_text_clear_list
	mov byte [cs:gxTextNeedRendering], 0
	retf
	

; Clears all entities
;
; MUST return via retf
; Not required to preserve any registers
;
; input:
;		none
; output:
;		none	
_gx_text_clear_storage:
	call _gx_text_clear_list
	retf
	

; Returns whether some entities need to be rendered
;
; MUST return via retf
; Not required to preserve any registers
;
; input:
;		none
; output:
;		AL - 0 when no entities need rendering, other value otherwise
_gx_text_need_render:
	mov al, byte [cs:gxTextNeedRendering]
	retf


; Iterates through all entities, rendering those which need it
;
; MUST return via retf
; Not required to preserve any registers
;
; input:
;		none
; output:
;		none
_gx_text_render_all:
	cmp byte [cs:gxTextNeedRendering], 0
	je _gx_text_render_all_done

	mov ax, cs
	mov fs, ax

	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	mov si, _gx_text_render_single_callback
	
	mov byte [cs:gxTextRenderMode], GX_TEXT_RENDER_MODE_DELETIONS
	call common_llist_foreach
	mov byte [cs:gxTextRenderMode], GX_TEXT_RENDER_MODE_MODIFICATIONS
	call common_llist_foreach
	
	mov byte [cs:gxTextNeedRendering], 0
_gx_text_render_all_done:
	retf
	

; Marks all entities as needing render
;
; MUST return via retf
; Not required to preserve any registers
;
; input:
;		none
; output:
;		none	
_gx_text_schedule_render_all:
	mov byte [cs:gxTextNeedRendering], 1
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE

	mov si, _gx_text_schedule_render_callback
	call common_llist_foreach
	
	retf
	
	
; Callback for scheduling entities for render.
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
_gx_text_schedule_render_callback:
	or word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER

	mov ax, 1						; keep traversing
	retf
	
	
; Finds an entity by its handle
;
; input:
;		AX - entity handle
; output:
;		AX - 0 when no such entity found, other value otherwise
;	 DS:SI - pointer to entity, when found
_gx_text_find_entity:
	push bx
	push cx
	push dx
	push di
	push fs

	push ax								; [1]
	
	mov ax, cs
	mov fs, ax
	
	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	mov si, 0							; handle is at offset 0
	pop dx								; [1] handle value
	call common_llist_find_by_word		; DS:SI := element
										; AX := 0 when not found
	pop fs
	pop di
	pop dx
	pop cx
	pop bx
	ret
	

; Considers the newly-dequeued event, and modifies entities' state
; for any affected entities.
;
; MUST return via retf
; Not required to preserve any registers
;
; input:
;	 ES:DI - pointer to event bytes
; output:
;		none
_gx_text_handle_event:
	push cs
	pop ds

	; save pointer to event bytes
	mov word [cs:gxTextEventBytesSeg], es
	mov word [cs:gxTextEventBytesOff], di
	
	; prepare for possible iteration through all entities
	mov ax, cs
	mov fs, ax
	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	
	cmp byte [es:di], GUI_EVENT_MOUSE_MOVE
	je _gx_text_handle_event__mouse_event
	cmp byte [es:di], GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je _gx_text_handle_event__mouse_event
	cmp byte [es:di], GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je _gx_text_handle_event__mouse_event
	
	cmp byte [es:di], GUI_EVENT_KEYBOARD_KEY_STATUS_CHANGED
	je _gx_text_handle_event__keyboard_status_event

	jmp _gx_text_handle_event_done
_gx_text_handle_event__mouse_event:
	mov ax, word [es:di+1]
	mov word [cs:gxTextMouseX], ax		; mouse X
	mov ax, word [es:di+3]
	mov word [cs:gxTextMouseY], ax		; mouse Y
	mov si, _gx_text_mouse_event_callback
	call common_llist_foreach
	
	jmp _gx_text_handle_event_done
	
_gx_text_handle_event__keyboard_status_event:
	call _gx_handle_keyboard_status_event
	
	jmp _gx_text_handle_event_done
	
_gx_text_handle_event_done:
	retf
	
	
; Callback for applying a mouse event to a single entity
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
_gx_text_mouse_event_callback:
	; check overlap
	mov ax, word [cs:gxTextMouseX]		; mouse X
	mov cx, word [cs:gxTextMouseY]		; mouse Y
	mov bx, 1					; mouse cursor width
	mov dx, 1					; mouse cursor height
	
	mov di, word [ds:si+16]		; entity height
	add di, 2*GX_TEXT_PADDING
	mov gs, di
	mov di, word [ds:si+14]		; entity width
	add di, 2*GX_TEXT_PADDING
	mov fs, word [ds:si+8]		; entity Y
	push si
	mov si, word [ds:si+6]		; entity X
	call common_geometry_test_rectangle_overlap_by_size	; AL := 0 when no
	pop si

	; here, AL = 0 when there's no overlap
	mov es, word [cs:gxTextEventBytesSeg]
	mov di, word [cs:gxTextEventBytesOff]
	mov bl, byte [es:di+0]	; BL := event type
	
	cmp bl, GUI_EVENT_MOUSE_MOVE
	je _gx_text_mouse_event_callback__mouse_move
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je _gx_text_mouse_event_callback__left_click_release
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je _gx_text_mouse_event_callback__left_click_depress
	
	jmp _gx_text_mouse_event_callback_done
_gx_text_mouse_event_callback__mouse_move:
	; mouse move event
	cmp al, 0
	je _gx_text_mouse_event_callback__mouse_move_no_overlap
_gx_text_mouse_event_callback__mouse_move_with_overlap:
	test word [ds:si+10], GX_TEXT_FLAG_HOVERED
	jnz _gx_text_mouse_event_callback_done		; NOOP when already hovering
	; entity is becoming hovered NOW
	or word [ds:si+10], GX_TEXT_FLAG_HOVERED | GX_TEXT_FLAG_MUST_RENDER
	mov byte [cs:gxTextNeedRendering], 1		; mark component
	
	jmp _gx_text_mouse_event_callback_done
_gx_text_mouse_event_callback__mouse_move_no_overlap:
	test word [ds:si+10], GX_TEXT_FLAG_HOVERED
	jz _gx_text_mouse_event_callback_done		; NOOP when already not hovered
	; entity is becoming not hovered NOW
	mov cx, GX_TEXT_FLAG_HOVERED | GX_TEXT_FLAG_HELD_DOWN_LEFT
	xor cx, 0FFFFh
	and word [ds:si+10], cx							; clear flags
	or word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER	; mark entity
	mov byte [cs:gxTextNeedRendering], 1			; mark component
	
	jmp _gx_text_mouse_event_callback_done
	
_gx_text_mouse_event_callback__left_click_release:
	cmp al, 0
	je _gx_text_mouse_event_callback_done		; NOOP when released outside
_gx_text_mouse_event_callback__left_click_release_with_overlap:
	; a left click is being released on this entity
	test word [ds:si+10], GX_TEXT_FLAG_HELD_DOWN_LEFT
	jz _gx_text_mouse_event_callback_done		; NOOP if it wasn't held down
	; a left click is being released on this entity after it was held down

	mov dx, GX_TEXT_FLAG_HELD_DOWN_LEFT
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	or word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER	; mark entity
	mov byte [cs:gxTextNeedRendering], 1			; mark component
	call _gx_select
	jmp _gx_text_mouse_event_callback_done
	
_gx_text_mouse_event_callback__left_click_depress:
	cmp al, 0
	je _gx_text_mouse_event_callback_done		; NOOP when depressed outside
_gx_text_mouse_event_callback__left_click_depress_with_overlap:
	; a left click is depressed on this entity
	or word [cs:si+10], GX_TEXT_FLAG_HELD_DOWN_LEFT | GX_TEXT_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:gxTextNeedRendering], 1	; mark component
	
	jmp _gx_text_mouse_event_callback_done
	
_gx_text_mouse_event_callback_done:
	mov ax, 1						; keep traversing
	retf

	
; Selects the specified entity
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none
_gx_select:
	pusha
	
	call _gx_text_deselect_all		; deselect everything first
	
	or word [cs:si+10], GX_TEXT_FLAG_SELECTED | GX_TEXT_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:gxTextNeedRendering], 1	; mark component
	
	popa
	ret
	

; Deselect all entities
;
; input:
;		none
; output:
;		none
_gx_text_deselect_all:
	pusha
	push ds
	push fs
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	mov si, _gx_text_deselect_all_callback
	call common_llist_foreach
	
	pop fs
	pop ds
	popa
	ret

	
; Callback
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
_gx_text_deselect_all_callback:
	mov ax, GX_TEXT_FLAG_SELECTED
	xor ax, 0FFFFh
	and word [ds:si+10], ax			; clear flags
	
	or word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER
	mov byte [cs:gxTextNeedRendering], 1
	
	mov ax, 1						; keep traversing
	retf

	
; Returns the selected entity, if one exists
;
; input:
;		none
; output:
;		AX - 0 if no entities are selected, other value otherwise
;	 DS:SI - pointer to selected entity, if found
_gx_text_get_selected:
	push bx
	push cx
	push dx
	push di
	push fs
	
	mov byte [cs:gxTextSelectedFound], 0
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxTextListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_TEXT_PAYLOAD_SIZE
	mov si, _gx_text_get_selected_callback
	call common_llist_foreach
	
	mov ah, 0
	mov al, byte [cs:gxTextSelectedFound]
	mov ds, word [cs:gxTextSelectedSegment]
	mov si, word [cs:gxTextSelectedOffset]
	
	pop fs
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Callback
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
_gx_text_get_selected_callback:
	test word [ds:si+10], GX_TEXT_FLAG_PENDING_DELETE
	jnz _gx_text_get_selected_callback_done

	test word [ds:si+10], GX_TEXT_FLAG_SELECTED
	jz _gx_text_get_selected_callback_done
	
	; this entity is selected
	mov byte [cs:gxTextSelectedFound], 1
	mov word [cs:gxTextSelectedSegment], ds
	mov word [cs:gxTextSelectedOffset], si
	mov ax, 0						; stop traversing
	retf
_gx_text_get_selected_callback_done:	
	mov ax, 1						; keep traversing
	retf
	
	
; Apply a keyboard event.
; This is used for when the GUI framework keyboard mode is "key status".
;
; input:
;	 ES:DI - pointer to event bytes
; output:
;		none
_gx_handle_keyboard_status_event:
	pusha
	push ds
	push es
	
	cmp byte [es:di+2], 0			; released?
	je _gx_handle_keyboard_status_event_done	; yes, so NOOP
	
	cmp byte [es:di+3], 0			; has ASCII?
	je _gx_handle_keyboard_status_event_done	; no, so NOOP
	
	; key has just been pressed, and it does have an ASCII correspondent
	
	call _gx_text_get_selected		; DS:SI := ptr to selected entity
	cmp ax, 0
	je _gx_handle_keyboard_status_event_done
	
	or word [ds:si+10], GX_TEXT_FLAG_MUST_RENDER
	mov byte [cs:gxTextNeedRendering], 1

	; setup arguments to handle key press
	mov al, byte [es:di+4]			; AL := ASCII
	mov ah, byte [es:di+1]			; AH := scan code
	
	mov cx, word [ds:si+18]			; CX := max text length
	
	push ds
	pop es
	mov di, si						; ES:DI := ptr to entity

	push word [ds:si+2]
	push word [ds:si+4]
	pop si
	pop ds							; DS:SI := ptr to text
	
	int 0A5h						; BX := text length
	call _gx_handle_keypress
	
_gx_handle_keyboard_status_event_done:
	pop es
	pop ds
	popa
	ret
	
	
; Apply a keypress to the specified entity
;
; input:
;		AL - ASCII of pressed key
;		AH - scan code of pressed key
;	 DS:SI - pointer to text
;		BX - current text length
;		CX - maximum text length
;	 ES:DI - pointer to entity
; output:
;		none
_gx_handle_keypress:
	pusha
	pushf
	push ds
	push es

	cmp al, COMMON_ASCII_BACKSPACE
	je _gx_handle_keypress__remove
	jmp _gx_handle_keypress__add
	
_gx_handle_keypress__remove:
	cmp bx, 0
	je _gx_handle_keypress_done
	; we have at least one character in text buffer
	mov byte [ds:si+bx-1], 0		; replace last character with terminator
	jmp _gx_handle_keypress__invoke_callback_and_done
	
_gx_handle_keypress__add:
	cmp bx, cx						; is it full?
	jae _gx_handle_keypress_done	; yes
	; we can add one more character to the text
	call common_ascii_is_printable
	jnc _gx_handle_keypress_done	; not printable
	
	mov byte [ds:si+bx], al			; insert character over old terminator
	mov byte [ds:si+bx+1], 0		; new terminator
	jmp _gx_handle_keypress__invoke_callback_and_done
	
_gx_handle_keypress__invoke_callback_and_done:
	; invoke changed callback
	mov ax, word [es:di+0]			; handle
	mov ds, word [es:di+20]
	mov si, word [es:di+22]
	call gui_invoke_callback
	
_gx_handle_keypress_done:
	pop es
	pop ds
	popf
	popa
	ret
	

%include "common\vga640\gui\ext\gx.asm"			; must be included first

%include "common\memory.asm"
%include "common\ascii.asm"
%include "common\dynamic\linklist.asm"
%include "common\vga640\gui\gui.asm"
	

%endif
