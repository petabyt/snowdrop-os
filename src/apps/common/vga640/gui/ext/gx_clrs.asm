;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It implements an extension for Snowdrop OS's graphical user interface 
; (GUI) framework.
;
; This extension adds a colour picker.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _GX_COLOURS_
%define _GX_COLOURS_

GX_COLOURS_LIST_HEAD_PTR_LEN		equ COMMON_LLIST_HEAD_PTR_LENGTH
GX_COLOURS_LIST_HEAD_PTR_INITIAL	equ COMMON_LLIST_HEAD_PTR_INITIAL

gxColoursRegistrationNumber:	dw 0
gxColoursNextId:				dw 0
gxColoursIsInitialized:			db 0
gxColoursNeedRendering:			db 0

gxColoursAddWidth:				dw 0
gxColoursAddHeight:				dw 0
gxColoursAddTextWidth:			dw 0
gxColoursAddTextX:				dw 0
gxColoursAddTextY:				dw 0
gxColoursAddGraphicX:			dw 0
gxColoursAddGraphicY:			dw 0
gxColoursAddGraphicHandle:		dw 0
gxColoursAddTextHandle:			dw 0
gxColoursAddFlags:				dw 0		; used when adding an icon

gxColoursMouseX:				dw 0
gxColoursMouseY:				dw 0
gxColoursEventBytesSeg:			dw 0
gxColoursEventBytesOff:			dw 0		; used when handling events

gxColoursEntityLookupIsFound:	db 0
gxColoursEntityLookupHandle:	dw 0
gxColoursEntityLookupSegment:	dw 0
gxColoursEntityLookupOffset:	dw 0				; used when looking up a group

; this list holds entities
gxColoursListHeadPtr:	times GX_COLOURS_LIST_HEAD_PTR_LEN db GX_COLOURS_LIST_HEAD_PTR_INITIAL
				; byte
				; 0 - 1        ID of entity
				; 2 - 3        unused
				; 4 - 5        unused
				; 6 - 7        X location
				; 8 - 9        Y location
				; 10 - 11      flags
				; 12 - 13      flags before last render
				; 14 - 15      computed total width, not including padding
				; 16 - 17      computed total height, not including padding
				; 18 - 19      ID of image for colour 0
				; 20 - 21      ID of image for colour 1
				; 22 - 23      ID of image for colour 2
				; 24 - 25      ID of image for colour 3
				; 26 - 27      ID of image for colour 4
				; 28 - 29      ID of image for colour 5
				; 30 - 31      ID of image for colour 6
				; 32 - 33      ID of image for colour 7
				; 34 - 35      ID of image for colour 8
				; 36 - 37      ID of image for colour 9
				; 38 - 39      ID of image for colour 10
				; 40 - 41      ID of image for colour 11
				; 42 - 43      ID of image for colour 12
				; 44 - 45      ID of image for colour 13
				; 46 - 47      ID of image for colour 14
				; 48 - 49      ID of image for colour 15
GX_COLOURS_PAYLOAD_SIZE	equ 50

GX_COLOURS_FLAG_ENABLED			equ 1	; is clickable
GX_COLOURS_FLAG_MUST_RENDER		equ 4	; must be redrawn
GX_COLOURS_FLAG_PENDING_DELETE	equ 16	; is pending deletion

GX_COLOURS_SINGLE_IMAGE_WIDTH	equ 16
GX_COLOURS_SINGLE_IMAGE_HEIGHT	equ 16
GX_COLOURS_SINGLE_IMAGE_PADDING	equ 4

GX_COLOURS_GRAPHIC_HEIGHT			equ 32
GX_COLOURS_GRAPHIC_WIDTH			equ 32

GX_COLOURS_PADDING			equ 3	; padding inside any outline we might draw

; stores data so it can be added as a new element
gxColoursPayload:		times GX_COLOURS_PAYLOAD_SIZE db 0

gxColoursRenderMode:					db	99
GX_COLOURS_RENDER_MODE_DELETIONS		equ 0
GX_COLOURS_RENDER_MODE_MODIFICATIONS	equ 1

gxBitmapColour0:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 0
gxBitmapColour1:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 1
gxBitmapColour2:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 2
gxBitmapColour3:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 3
gxBitmapColour4:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 4
gxBitmapColour5:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 5
gxBitmapColour6:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 6
gxBitmapColour7:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 7
gxBitmapColour8:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 8
gxBitmapColour9:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 9
gxBitmapColour10:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 10
gxBitmapColour11:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 11
gxBitmapColour12:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 12
gxBitmapColour13:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 13
gxBitmapColour14:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 14
gxBitmapColour15:		times GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT db 15


; Initializes this extension
;
; input:
;		none
; output:
;		none
common_gx_colours_initialize:
	pusha
	push ds
	push es
	
	cmp byte [cs:gxColoursIsInitialized], 0
	jne common_gx_colours_initialize_done
	
	call gx_register_extension	; register with the GUI extensions interface
	mov word [cs:gxColoursRegistrationNumber], ax	; store our registration number
	
	; now register our callbacks
	push cs
	pop es
	mov ax, word [cs:gxColoursRegistrationNumber]
	
	mov di, _gx_colours_prepare
	call gx_register__on_prepare
	
	mov di, _gx_colours_clear_storage
	call gx_register__on_clear_storage
	
	mov di, _gx_colours_need_render
	call gx_register__on_need_render
	
	mov di, _gx_colours_render_all
	call gx_register__on_render_all
	
	mov di, _gx_colours_schedule_render_all
	call gx_register__on_schedule_render_all
	
	mov di, _gx_colours_handle_event
	call gx_register__on_handle_event
	
	mov word [cs:gxColoursNextId], 0
	mov byte [cs:gxColoursIsInitialized], 1
common_gx_colours_initialize_done:
	pop es
	pop ds
	popa
	ret

	
; Deletes an entity
;
; input:
;		AX - entity handle
; output:
;		none
common_gx_colours_delete:
	pusha
	push ds
	
	call _gx_colours_find_entity
	cmp ax, 0
	je common_gx_colours_delete_done
	; mark as deleted
	or word [ds:si+10], GX_COLOURS_FLAG_PENDING_DELETE | GX_COLOURS_FLAG_MUST_RENDER
	
	mov byte [cs:gxColoursNeedRendering], 1
common_gx_colours_delete_done:
	pop ds
	popa
	ret


; Adds an entity
;
; input:
;		AX - position X
;		BX - position Y
; output:
;		AX - entity handle
common_gx_colours_add:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs

	; first, create the image that holds the graphic
	pusha
	push ds
	push cs
	pop ds
	
	mov si, gxBitmapColour0
	mov di, GX_COLOURS_SINGLE_IMAGE_WIDTH		; canvas size
	mov dx, GX_COLOURS_SINGLE_IMAGE_HEIGHT
	
	add ax, GX_COLOURS_PADDING
	add bx, GX_COLOURS_PADDING
	
	mov cx, 16
common_gx_colours_add__images_loop:
	push ax
	push bx										; [2]
	
	push cx										; [1]
	mov cx, GX_COLOURS_SINGLE_IMAGE_WIDTH
	call common_gui_image_add					; AX := image handle
	call common_gui_image_ignore_transparency_set
	
	push ds
	push si
	push cs
	pop ds
	mov si, _gx_image_left_clicked_callback
	call common_gui_image_left_click_callback_set
	pop si
	pop ds
	
	pop cx										; [1]
	mov bx, 16
	sub bx, cx									; BX moves from 0 to 15	
	shl bx, 1									; BX moves from 0 to 30
	mov word [cs:gxColoursPayload+18+bx], ax
	
	pop bx										; [2]
	pop ax
	add ax, GX_COLOURS_SINGLE_IMAGE_WIDTH + GX_COLOURS_SINGLE_IMAGE_PADDING
	
	; first image on second line?
	cmp cx, 9
	jne common_gx_colours_add__images_loop_next
	; yes, bring "cursor" back to left most columns, and one line down
	sub ax, 8*(GX_COLOURS_SINGLE_IMAGE_WIDTH + GX_COLOURS_SINGLE_IMAGE_PADDING)
	add bx, GX_COLOURS_SINGLE_IMAGE_HEIGHT + GX_COLOURS_SINGLE_IMAGE_PADDING
common_gx_colours_add__images_loop_next:
	add si, GX_COLOURS_SINGLE_IMAGE_WIDTH*GX_COLOURS_SINGLE_IMAGE_HEIGHT
	loop common_gx_colours_add__images_loop
	
	pop ds
	popa

	; compute flags
	mov word [cs:gxColoursAddFlags], GX_COLOURS_FLAG_ENABLED | GX_COLOURS_FLAG_MUST_RENDER
	
	push ax
	mov ax, cs
	mov es, ax
	mov fs, ax
	pop ax
	
	; add a new list element
	mov di, gxColoursPayload			; ES:DI := pointer to buffer
	
	; populate buffer
	mov word [es:di+6], ax				; X
	mov word [es:di+8], bx				; Y
	
	mov ax, word [cs:gxColoursNextId]
	mov word [es:di+0], ax				; icon handle
	
	mov ax, word [cs:gxColoursAddFlags]
	mov word [es:di+10], ax				; flags
	mov word [es:di+12], ax				; old flags	
	
	mov ax, 8*(GX_COLOURS_SINGLE_IMAGE_WIDTH + GX_COLOURS_SINGLE_IMAGE_PADDING ) - GX_COLOURS_SINGLE_IMAGE_PADDING
	mov word [es:di+14], ax				; computed total width
	mov ax, 2*(GX_COLOURS_SINGLE_IMAGE_HEIGHT + GX_COLOURS_SINGLE_IMAGE_PADDING ) - GX_COLOURS_SINGLE_IMAGE_PADDING
	mov word [es:di+16], ax				; computed total height
	
	mov bx, gxColoursListHeadPtr		; FS:BX := pointer to pointer to head
	mov cx, GX_COLOURS_PAYLOAD_SIZE
	call common_llist_add				; DS:SI := new list element
	
	mov ax, word [es:di+18]				; AX := handle of colour 0
	mov bx, 1
	call common_gui_image_set_selected	; select it
	
	inc word [cs:gxColoursNextId]
	mov byte [cs:gxColoursNeedRendering], 1
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

	
; Returns the currently-selected colour
;
; input:
;		AX - entity handle
; output:
;		AX - currently selected colour
common_gx_colours_get_colour:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	
	call _gx_colours_find_entity				; DS:SI := ptr to entity
	cmp ax, 0
	je common_gx_colours_get_colour_done
	
	add si, 18									; DS:SI := ptr to colour 0
	mov cx, 15
common_gx_colours_get_colour_loop:
	mov ax, word [ds:si]
	call common_gui_image_get_selected			; BX := 0 when not selected
	add si, 2									; next image handle
	
	cmp bx, 0
	jne common_gx_colours_get_colour_found
	loop common_gx_colours_get_colour_loop
common_gx_colours_get_colour_found:
	mov ax, 15
	sub ax, cx									; AX := colour number
common_gx_colours_get_colour_done:
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Sets the currently-selected colour
;
; input:
;		AX - entity handle
;		BX - colour to select
; output:
;		none
common_gx_colours_set_colour:
	pusha
	push ds
	
	call _gx_colours_find_entity				; DS:SI := ptr to entity
	cmp ax, 0
	je common_gx_colours_set_colour_done
	
	shl bx, 1									; 2 bytes per image handle
	mov ax, word [ds:si+18+bx]					; AX := image handle
	call _gx_select_colour
common_gx_colours_set_colour_done:
	pop ds
	popa
	ret
	

; Removes all entities
;
; input:
;		none
; output:
;		none	
_gx_colours_clear_list:
	pusha
	push ds
	push fs
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxColoursListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_COLOURS_PAYLOAD_SIZE
	
	; first, destroy any images we created
	mov si, _gx_colours_delete_referenced_images_callback
	call common_llist_foreach
	
	; then, clear OUR entities
	call common_llist_clear
	
	pop fs
	pop ds
	popa
	ret

	
; Callback for deletion of referenced images.
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
_gx_colours_delete_referenced_images_callback:
	mov ax, word [ds:si+18]
	call common_gui_image_delete
	mov ax, word [ds:si+20]
	call common_gui_image_delete
	mov ax, word [ds:si+22]
	call common_gui_image_delete
	mov ax, word [ds:si+24]
	call common_gui_image_delete
	mov ax, word [ds:si+26]
	call common_gui_image_delete
	mov ax, word [ds:si+28]
	call common_gui_image_delete
	mov ax, word [ds:si+30]
	call common_gui_image_delete
	mov ax, word [ds:si+32]
	call common_gui_image_delete
	mov ax, word [ds:si+34]
	call common_gui_image_delete
	mov ax, word [ds:si+36]
	call common_gui_image_delete
	mov ax, word [ds:si+38]
	call common_gui_image_delete
	mov ax, word [ds:si+40]
	call common_gui_image_delete
	mov ax, word [ds:si+42]
	call common_gui_image_delete
	mov ax, word [ds:si+44]
	call common_gui_image_delete
	mov ax, word [ds:si+46]
	call common_gui_image_delete
	mov ax, word [ds:si+48]
	call common_gui_image_delete

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
_gx_colours_render_single_callback:
	push cs
	pop fs
	
_gx_colours_render_single_callback__try_deletions:
	cmp byte [cs:gxColoursRenderMode], GX_COLOURS_RENDER_MODE_DELETIONS
	jne _gx_colours_render_single_callback__try_modifications
	; we're only rendering deletions
	test word [ds:si+10], GX_COLOURS_FLAG_PENDING_DELETE
	jz _gx_colours_render_single_callback_done
	test word [ds:si+10], GX_COLOURS_FLAG_MUST_RENDER
	jz _gx_colours_render_single_callback_done
	; this entity is pending delete

	call _gx_colours_erase						; erase it from screen
	call _gx_colours_remove_single_from_storage	; and from storage
	
	jmp _gx_colours_render_single_callback_done
_gx_colours_render_single_callback__try_modifications:
	cmp byte [cs:gxColoursRenderMode], GX_COLOURS_RENDER_MODE_MODIFICATIONS
	jne _gx_colours_render_single_callback_done
	; we're only rendering modifications
	test word [ds:si+10], GX_COLOURS_FLAG_MUST_RENDER
	jz _gx_colours_render_single_callback_done
	call _gx_colours_erase				; erase it from screen
	call _gx_colours_draw				; draw it anew
	
	mov ax, word [ds:si+10]
	mov word [ds:si+12], ax			; old flags := flags
	
	mov ax, GX_COLOURS_FLAG_MUST_RENDER
	xor ax, 0FFFFh
	and word [ds:si+10], ax			; clear flags
	
_gx_colours_render_single_callback_done:
	mov ax, 1						; keep traversing
	retf


; Removes the specified entity from storage, also deleting other
; entities it references
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none	
_gx_colours_remove_single_from_storage:
	pusha
	push fs
	
	mov ax, word [ds:si+18]
	call common_gui_image_delete
	mov ax, word [ds:si+20]
	call common_gui_image_delete
	mov ax, word [ds:si+22]
	call common_gui_image_delete
	mov ax, word [ds:si+24]
	call common_gui_image_delete
	mov ax, word [ds:si+26]
	call common_gui_image_delete
	mov ax, word [ds:si+28]
	call common_gui_image_delete
	mov ax, word [ds:si+30]
	call common_gui_image_delete
	mov ax, word [ds:si+32]
	call common_gui_image_delete
	mov ax, word [ds:si+34]
	call common_gui_image_delete
	mov ax, word [ds:si+36]
	call common_gui_image_delete
	mov ax, word [ds:si+38]
	call common_gui_image_delete
	mov ax, word [ds:si+40]
	call common_gui_image_delete
	mov ax, word [ds:si+42]
	call common_gui_image_delete
	mov ax, word [ds:si+44]
	call common_gui_image_delete
	mov ax, word [ds:si+46]
	call common_gui_image_delete
	mov ax, word [ds:si+48]
	call common_gui_image_delete
	
	mov ax, cs
	mov fs, ax

	mov bx, gxColoursListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_COLOURS_PAYLOAD_SIZE
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
_gx_colours_erase:
	pusha
	
	mov bx, word [ds:si+6]						; X
	mov ax, word [ds:si+8]						; Y
	call common_gui_get_colour_background		; CX := colour
	mov dx, cx
	mov cx, word [ds:si+14]						; width
	add cx, 2*GX_COLOURS_PADDING
	mov si, word [ds:si+16]						; height
	add si, 2*GX_COLOURS_PADDING
	call common_graphics_draw_rectangle_outline_by_coords
	
	popa
	ret
	
	
; Draws the specified entity to screen
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none
_gx_colours_draw:
	pusha
	
	mov bx, word [ds:si+6]						; X
	mov ax, word [ds:si+8]						; Y
	call common_gui_get_colour_decorations		; CX := colour
	mov dx, cx
	mov cx, word [ds:si+14]						; width
	add cx, 2*GX_COLOURS_PADDING
	mov si, word [ds:si+16]						; height
	add si, 2*GX_COLOURS_PADDING
	call common_graphics_draw_rectangle_outline_by_coords
	
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
_gx_colours_prepare:
	call _gx_colours_clear_list
	mov byte [cs:gxColoursNeedRendering], 0
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
_gx_colours_clear_storage:
	call _gx_colours_clear_list
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
_gx_colours_need_render:
	mov al, byte [cs:gxColoursNeedRendering]
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
_gx_colours_render_all:
	cmp byte [cs:gxColoursNeedRendering], 0
	je _gx_colours_render_all_done

	mov ax, cs
	mov fs, ax

	mov bx, gxColoursListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_COLOURS_PAYLOAD_SIZE
	mov si, _gx_colours_render_single_callback
	
	mov byte [cs:gxColoursRenderMode], GX_COLOURS_RENDER_MODE_DELETIONS
	call common_llist_foreach
	mov byte [cs:gxColoursRenderMode], GX_COLOURS_RENDER_MODE_MODIFICATIONS
	call common_llist_foreach
	
	mov byte [cs:gxColoursNeedRendering], 0
_gx_colours_render_all_done:
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
_gx_colours_schedule_render_all:
	mov byte [cs:gxColoursNeedRendering], 1
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxColoursListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_COLOURS_PAYLOAD_SIZE

	mov si, _gx_colours_schedule_render_callback
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
_gx_colours_schedule_render_callback:
	or word [ds:si+10], GX_COLOURS_FLAG_MUST_RENDER

	mov ax, 1						; keep traversing
	retf
	
	
; Finds an entity by its handle
;
; input:
;		AX - entity handle
; output:
;		AX - 0 when no such entity found, other value otherwise
;	 DS:SI - pointer to entity, when found
_gx_colours_find_entity:
	push bx
	push cx
	push dx
	push di
	push fs

	push ax								; [1]
	
	mov ax, cs
	mov fs, ax
	
	mov bx, gxColoursListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_COLOURS_PAYLOAD_SIZE
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
_gx_colours_handle_event:
	retf
	
	
; This function is invoked by the GUI framework when an image is selected.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
_gx_image_left_clicked_callback:
	call _gx_select_colour
	retf
	
	
; Gets a pointer to an entity whose image was passed in
;
; input:
;		AX - handle
; output:
;		AX - 0 when not found, other value otherwise
;	 DS:SI - pointer to entity, when found
_gx_get_entity_by_image:
	push bx
	push cx
	push dx
	push di
	push fs
	
	mov byte [cs:gxColoursEntityLookupIsFound], 0
	mov word [cs:gxColoursEntityLookupHandle], ax
	
	mov ax, cs
	mov fs, ax

	mov bx, gxColoursListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_COLOURS_PAYLOAD_SIZE
	mov si, _gx_get_entity_by_image_callback
	call common_llist_foreach
	
	mov ax, 0								; assume not found
	cmp byte [cs:gxColoursEntityLookupIsFound], 0
	je _gx_get_entity_by_image_done
	; it's found
	mov ax, 1
	mov ds, word [cs:gxColoursEntityLookupSegment]
	mov si, word [cs:gxColoursEntityLookupOffset]
	
_gx_get_entity_by_image_done:	
	pop fs
	pop di
	pop dx
	pop cx
	pop bx
	ret

	
; Callback for finding an entity by one of its images
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
_gx_get_entity_by_image_callback:
	mov cx, word [cs:gxColoursEntityLookupHandle]
	
	cmp word [ds:si+18], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+20], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+22], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+24], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+26], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+28], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+30], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+32], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+34], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+36], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+38], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+40], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+42], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+44], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+46], cx
	je _gx_get_entity_by_image_callback_found
	cmp word [ds:si+48], cx
	je _gx_get_entity_by_image_callback_found
	
_gx_get_entity_by_image_callback_not_found:
	mov ax, 1						; keep going
	retf
_gx_get_entity_by_image_callback_found:
	mov byte [cs:gxColoursEntityLookupIsFound], 1
	mov word [cs:gxColoursEntityLookupSegment], ds
	mov word [cs:gxColoursEntityLookupOffset], si
	mov ax, 0						; stop
	retf


; Selects the specified colour
;
; input:
;		AX - image handle
; output:
;		none
_gx_select_colour:
	pusha
	push ds
	
	push ax										; [1]
	
	; deselect all images from that group
	call _gx_get_entity_by_image				; DS:SI := pointer to entity
	cmp ax, 0
	je _gx_select_colour_done
	
	mov bx, 0									; "clear"
	mov ax, word [ds:si+18]
	call common_gui_image_set_selected
	mov ax, word [ds:si+20]
	call common_gui_image_set_selected
	mov ax, word [ds:si+22]
	call common_gui_image_set_selected
	mov ax, word [ds:si+24]
	call common_gui_image_set_selected
	mov ax, word [ds:si+26]
	call common_gui_image_set_selected
	mov ax, word [ds:si+28]
	call common_gui_image_set_selected
	mov ax, word [ds:si+30]
	call common_gui_image_set_selected
	mov ax, word [ds:si+32]
	call common_gui_image_set_selected
	mov ax, word [ds:si+34]
	call common_gui_image_set_selected
	mov ax, word [ds:si+36]
	call common_gui_image_set_selected
	mov ax, word [ds:si+38]
	call common_gui_image_set_selected
	mov ax, word [ds:si+40]
	call common_gui_image_set_selected
	mov ax, word [ds:si+42]
	call common_gui_image_set_selected
	mov ax, word [ds:si+44]
	call common_gui_image_set_selected
	mov ax, word [ds:si+46]
	call common_gui_image_set_selected
	mov ax, word [ds:si+48]
	call common_gui_image_set_selected
	
	; select the one that was just clicked
	pop ax										; [1]
	mov bx, 1
	call common_gui_image_set_selected
_gx_select_colour_done:
	pop ds
	popa
	ret
	

%include "common\vga640\gui\ext\gx.asm"			; must be included first

%include "common\memory.asm"
%include "common\dynamic\linklist.asm"
%include "common\vga640\gui\gui.asm"
	

%endif
