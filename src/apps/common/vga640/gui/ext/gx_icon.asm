;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It implements an extension for Snowdrop OS's graphical user interface 
; (GUI) framework.
;
; This extension adds clickable icons which have a graphic and a label.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _GX_ICON_
%define _GX_ICON_

GX_ICON_LIST_HEAD_PTR_LEN		equ COMMON_LLIST_HEAD_PTR_LENGTH
GX_ICON_LIST_HEAD_PTR_INITIAL	equ COMMON_LLIST_HEAD_PTR_INITIAL

gxIconRegistrationNumber:		dw 0
gxIconNextId:					dw 0
gxIconIsInitialized:			db 0
gxIconNeedRendering:			db 0

gxIconAddWidth:				dw 0
gxIconAddHeight:			dw 0
gxIconAddTextWidth:			dw 0
gxIconAddTextX:				dw 0
gxIconAddTextY:				dw 0
gxIconAddGraphicX:			dw 0
gxIconAddGraphicY:			dw 0
gxIconAddGraphicHandle:		dw 0
gxIconAddTextHandle:		dw 0
gxIconAddFlags:				dw 0		; used when adding an icon

gxIconMouseX:				dw 0
gxIconMouseY:				dw 0
gxIconEventBytesSeg:		dw 0
gxIconEventBytesOff:		dw 0		; used when handling events

; this list holds entities
gxIconListHeadPtr:	times GX_ICON_LIST_HEAD_PTR_LEN db GX_ICON_LIST_HEAD_PTR_INITIAL
				; byte
				; 0 - 1        ID of entity
				; 2 - 3        ID of decorative image (the graphic)
				; 4 - 5        ID of ASCII image (the text)
				; 6 - 7        X location
				; 8 - 9        Y location
				; 10 - 11      flags
				; 12 - 13      flags before last render
				; 14 - 15      computed total width, not including padding
				; 16 - 17      computed total height, not including padding
				; 18 - 19      on-click callback segment
				; 20 - 21      on-click callback offset
GX_ICON_PAYLOAD_SIZE	equ 22

GX_ICON_FLAG_ENABLED			equ 1	; is clickable
GX_ICON_FLAG_HOVERED			equ 2	; is hovered over by the mouse
GX_ICON_FLAG_MUST_RENDER		equ 4	; must be redrawn
GX_ICON_FLAG_SELECTED			equ 8	; is selected
GX_ICON_FLAG_PENDING_DELETE		equ 16	; is pending deletion
GX_ICON_FLAG_HELD_DOWN_LEFT		equ 32	; is held down with a left click

GX_ICON_GRAPHIC_HEIGHT			equ 32
GX_ICON_GRAPHIC_WIDTH			equ 32

GX_ICON_HORIZONTAL_PADDING_COMPENSATION		equ 6
GX_ICON_VERTICAL_PADDING_COMPENSATION		equ 6

GX_ICON_PADDING			equ 3	; padding inside any outline we might draw

; stores data so it can be added as a new element
gxIconPayload:		times GX_ICON_PAYLOAD_SIZE db 0
gxIconBitmap:
		db TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,
		db TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,GUI__COLOUR_2,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,GUI__COLOUR_2,TRN,
		db TRN,TRN,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,GUI__COLOUR_2,TRN,TRN,
		db TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,TRN,
		
gxIconRenderMode:					db	99
GX_ICON_RENDER_MODE_DELETIONS		equ 0
GX_ICON_RENDER_MODE_MODIFICATIONS	equ 1


; Initializes this extension
;
; input:
;		none
; output:
;		none
common_gx_icon_initialize:
	pusha
	push ds
	push es
	
	cmp byte [cs:gxIconIsInitialized], 0
	jne common_gx_icon_initialize_done
	
	call gx_register_extension	; register with the GUI extensions interface
	mov word [cs:gxIconRegistrationNumber], ax	; store our registration number
	
	; now register our callbacks
	push cs
	pop es
	mov ax, word [cs:gxIconRegistrationNumber]
	
	mov di, _gx_icon_prepare
	call gx_register__on_prepare
	
	mov di, _gx_icon_clear_storage
	call gx_register__on_clear_storage
	
	mov di, _gx_icon_need_render
	call gx_register__on_need_render
	
	mov di, _gx_icon_render_all
	call gx_register__on_render_all
	
	mov di, _gx_icon_schedule_render_all
	call gx_register__on_schedule_render_all
	
	mov di, _gx_icon_handle_event
	call gx_register__on_handle_event
	
	mov word [cs:gxIconNextId], 0
	mov byte [cs:gxIconIsInitialized], 1
common_gx_icon_initialize_done:
	pop es
	pop ds
	popa
	ret
	
	
; Sets the specified entity's click callback, which is invoked whenever the
; entity is clicked
;
; input:
;		AX - entity handle
;	 DS:SI - pointer to callback function
; output:
;		none
common_gx_icon_click_callback_set:
	pusha
	push ds
	
	push ds
	push si
	
	call _gx_icon_find_entity
	cmp ax, 0
	je common_gx_icon_click_callback_set_done

	pop word [ds:si+20]		; offset
	pop word [ds:si+18]		; segment
common_gx_icon_click_callback_set_done:	
	pop ds
	popa
	ret
	
	
; Clears the specified entity's click callback
;
; input:
;		AX - entity handle
; output:
;		none
common_gx_icon_click_callback_clear:
	pusha
	push ds
	
	call _gx_icon_find_entity
	cmp ax, 0
	je common_gx_icon_click_callback_clear_done
	
	mov word [ds:si+18], cs
	mov word [ds:si+20], gui_noop_callback
common_gx_icon_click_callback_clear_done:	
	pop ds
	popa
	ret
	
	
; Deletes an entity
;
; input:
;		AX - entity handle
; output:
;		none
common_gx_icon_delete:
	pusha
	push ds
	
	call _gx_icon_find_entity
	cmp ax, 0
	je common_gx_icon_delete_done
	; mark as deleted
	or word [ds:si+10], GX_ICON_FLAG_PENDING_DELETE | GX_ICON_FLAG_MUST_RENDER
	
	mov byte [cs:gxIconNeedRendering], 1
common_gx_icon_delete_done:
	pop ds
	popa
	ret


; Adds an entity
;
; input:
;		AX - position X
;		BX - position Y
;	 DS:SI - pointer to zero-terminated label string
; output:
;		AX - entity handle	
common_gx_icon_add:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs

	; this is common to both cases when text is wider and when graphic is wider
	mov word [cs:gxIconAddHeight], GX_ICON_GRAPHIC_HEIGHT + COMMON_GRAPHICS_FONT_HEIGHT + GX_ICON_VERTICAL_PADDING_COMPENSATION
	
	; calculate X positions of graphic and text
	pusha
	call common_graphics_text_measure_width		; AX := text width
	mov word [cs:gxIconAddTextWidth], ax

	cmp ax, GX_ICON_GRAPHIC_WIDTH
	popa
	ja common_gx_icon_add__text_is_wider
common_gx_icon_add__graphic_is_wider:
	mov word [cs:gxIconAddWidth], GX_ICON_GRAPHIC_WIDTH + GX_ICON_HORIZONTAL_PADDING_COMPENSATION
	
	; graphic goes to the passed-in X
	mov word [cs:gxIconAddGraphicX], ax
	mov word [cs:gxIconAddGraphicY], bx
	
	mov dx, GX_ICON_GRAPHIC_WIDTH
	sub dx, word [cs:gxIconAddTextWidth]
	sub dx, GX_ICON_HORIZONTAL_PADDING_COMPENSATION
	shr dx, 1
	
	mov word [cs:gxIconAddTextX], ax
	add word [cs:gxIconAddTextX], dx	; to the right of passed-in X
	mov word [cs:gxIconAddTextY], bx
	add word [cs:gxIconAddTextY], GX_ICON_GRAPHIC_HEIGHT ; below graphic
	
	jmp common_gx_icon_add__after_widths
common_gx_icon_add__text_is_wider:
	mov dx, word [cs:gxIconAddTextWidth]
	add dx, GX_ICON_HORIZONTAL_PADDING_COMPENSATION
	mov word [cs:gxIconAddWidth], dx
	
	; text goes to the passed-in X
	mov word [cs:gxIconAddTextX], ax
	mov word [cs:gxIconAddTextY], bx
	add word [cs:gxIconAddTextY], GX_ICON_GRAPHIC_HEIGHT ; below graphic
	
	mov dx, word [cs:gxIconAddTextWidth]
	sub dx, GX_ICON_GRAPHIC_WIDTH
	add dx, GX_ICON_HORIZONTAL_PADDING_COMPENSATION
	shr dx, 1

	mov word [cs:gxIconAddGraphicX], ax
	add word [cs:gxIconAddGraphicX], dx	; to the right of passed-in X
	mov word [cs:gxIconAddGraphicY], bx
common_gx_icon_add__after_widths:

	; first, create the image that holds the graphic
	pusha
	push ds
	
	push cs
	pop ds
	mov si, gxIconBitmap				; DS:SI := pointer to bitmap
	mov di, GX_ICON_GRAPHIC_WIDTH		; canvas size
	
	mov ax, word [cs:gxIconAddGraphicX]
	add ax, GX_ICON_PADDING
	mov bx, word [cs:gxIconAddGraphicY]
	add bx, GX_ICON_PADDING
	mov cx, GX_ICON_GRAPHIC_WIDTH
	mov dx, GX_ICON_GRAPHIC_HEIGHT
	call common_gui_image_add			; AX := image handle
	mov word [cs:gxIconAddGraphicHandle], ax
	call common_gui_image_disable
	pop ds
	popa

	; then create the image that holds the text
	pusha
	mov ax, word [cs:gxIconAddTextX]
	add ax, GX_ICON_PADDING
	mov bx, word [cs:gxIconAddTextY]
	add bx, GX_ICON_PADDING
	call common_gui_image_add			; AX := image handle
	mov word [cs:gxIconAddTextHandle], ax
	call gui_images_set_mode_ascii
	mov bx, 0
	call common_gui_image_set_show_selected_mark	; we don't want the text
													; to be selectable
	call common_gui_image_hover_mark_clear
	call common_gui_image_ascii_border_hide
	popa

	; compute flags
	mov word [cs:gxIconAddFlags], GX_ICON_FLAG_ENABLED | GX_ICON_FLAG_MUST_RENDER
	
	push ax
	mov ax, cs
	mov es, ax
	mov fs, ax
	pop ax
	
	; add a new list element
	mov di, gxIconPayload				; ES:DI := pointer to buffer
	
	; populate buffer
	mov word [es:di+6], ax				; X
	mov word [es:di+8], bx				; Y
	
	mov ax, word [cs:gxIconNextId]
	mov word [es:di+0], ax				; icon handle
	mov ax, [cs:gxIconAddGraphicHandle]
	mov word [es:di+2], ax				; graphic
	mov ax, [cs:gxIconAddTextHandle]
	mov word [es:di+4], ax				; text
	
	mov ax, word [cs:gxIconAddFlags]
	mov word [es:di+10], ax				; flags
	mov word [es:di+12], ax				; old flags	
	
	mov ax, word [cs:gxIconAddWidth]
	mov word [es:di+14], ax				; computed total width
	mov ax, word [cs:gxIconAddHeight]
	mov word [es:di+16], ax				; computed total height
	
	; until the consumer sets its own callback, set a NOOP callback
	mov word [es:di+18], cs
	mov word [es:di+20], gui_noop_callback
	
	mov bx, gxIconListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_ICON_PAYLOAD_SIZE
	call common_llist_add				; DS:SI := new list element
	
	inc word [cs:gxIconNextId]
	mov byte [cs:gxIconNeedRendering], 1
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


; Removes all entities
;
; input:
;		none
; output:
;		none	
_gx_icon_clear_list:
	pusha
	push ds
	push fs
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxIconListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_ICON_PAYLOAD_SIZE
	
	; first, destroy any images we created
	mov si, _gx_icon_delete_referenced_images_callback
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
_gx_icon_delete_referenced_images_callback:
	mov ax, word [ds:si+2]			; graphic image
	call common_gui_image_delete
	mov ax, word [ds:si+4]			; text image
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
_gx_icon_render_single_callback:
	push cs
	pop fs
	
_gx_icon_render_single_callback__try_deletions:
	cmp byte [cs:gxIconRenderMode], GX_ICON_RENDER_MODE_DELETIONS
	jne _gx_icon_render_single_callback__try_modifications
	; we're only rendering deletions
	test word [ds:si+10], GX_ICON_FLAG_PENDING_DELETE
	jz _gx_icon_render_single_callback_done
	test word [ds:si+10], GX_ICON_FLAG_MUST_RENDER
	jz _gx_icon_render_single_callback_done
	; this entity is pending delete

	call _gx_icon_erase							; erase it from screen
	call _gx_icon_remove_single_from_storage	; and from storage
	
	jmp _gx_icon_render_single_callback_done
_gx_icon_render_single_callback__try_modifications:
	cmp byte [cs:gxIconRenderMode], GX_ICON_RENDER_MODE_MODIFICATIONS
	jne _gx_icon_render_single_callback_done
	; we're only rendering modifications
	test word [ds:si+10], GX_ICON_FLAG_MUST_RENDER
	jz _gx_icon_render_single_callback_done
	call _gx_icon_erase				; erase it from screen
	call _gx_icon_draw				; draw it anew
	
	mov ax, word [ds:si+10]
	mov word [ds:si+12], ax			; old flags := flags
	
	mov ax, GX_ICON_FLAG_MUST_RENDER
	xor ax, 0FFFFh
	and word [ds:si+10], ax			; clear flags
	
_gx_icon_render_single_callback_done:
	mov ax, 1						; keep traversing
	retf


; Removes the specified entity from storage, also deleting other
; entities it references
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none	
_gx_icon_remove_single_from_storage:
	pusha
	push fs
	
	mov ax, word [ds:si+2]			; graphic image
	call common_gui_image_delete
	mov ax, word [ds:si+4]			; text image
	call common_gui_image_delete
	
	mov ax, cs
	mov fs, ax

	mov bx, gxIconListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_ICON_PAYLOAD_SIZE
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
_gx_icon_erase:
	pusha
	
	mov bx, word [ds:si+6]						; X
	mov ax, word [ds:si+8]						; Y
	call common_gui_get_colour_background		; CX := colour
	mov dx, cx
	mov cx, word [ds:si+14]						; width
	add cx, 2*GX_ICON_PADDING
	mov si, word [ds:si+16]						; height
	add si, 2*GX_ICON_PADDING
	call common_graphics_draw_rectangle_outline_by_coords
	
	popa
	ret
	
	
; Draws the specified entity to screen
;
; input:
;	 DS:SI - pointer to entity
; output:
;		none
_gx_icon_draw:
	pusha
	
	; NOTE: since we rely on other components to be drawn, the only thing
	;       left for us is to draw an outline
	
	test word [ds:si+10], GX_ICON_FLAG_HOVERED
	jz _gx_icon_draw_done
	
	mov bx, word [ds:si+6]						; X
	mov ax, word [ds:si+8]						; Y
	call common_gui_get_colour_decorations		; CX := colour
	mov dx, cx
	mov cx, word [ds:si+14]						; width
	add cx, 2*GX_ICON_PADDING
	mov si, word [ds:si+16]						; height
	add si, 2*GX_ICON_PADDING
	call common_graphics_draw_rectangle_outline_by_coords

_gx_icon_draw_done:	
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
_gx_icon_prepare:
	call _gx_icon_clear_list
	mov byte [cs:gxIconNeedRendering], 0
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
_gx_icon_clear_storage:
	call _gx_icon_clear_list
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
_gx_icon_need_render:
	mov al, byte [cs:gxIconNeedRendering]
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
_gx_icon_render_all:
	cmp byte [cs:gxIconNeedRendering], 0
	je _gx_icon_render_all_done

	mov ax, cs
	mov fs, ax

	mov bx, gxIconListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_ICON_PAYLOAD_SIZE
	mov si, _gx_icon_render_single_callback
	
	mov byte [cs:gxIconRenderMode], GX_ICON_RENDER_MODE_DELETIONS
	call common_llist_foreach
	mov byte [cs:gxIconRenderMode], GX_ICON_RENDER_MODE_MODIFICATIONS
	call common_llist_foreach
	
	mov byte [cs:gxIconNeedRendering], 0
_gx_icon_render_all_done:
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
_gx_icon_schedule_render_all:
	mov byte [cs:gxIconNeedRendering], 1
	
	mov ax, cs
	mov ds, ax
	mov fs, ax

	mov bx, gxIconListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_ICON_PAYLOAD_SIZE

	mov si, _gx_icon_schedule_render_callback
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
_gx_icon_schedule_render_callback:
	or word [ds:si+10], GX_ICON_FLAG_MUST_RENDER

	mov ax, 1						; keep traversing
	retf
	
	
; Finds an entity by its handle
;
; input:
;		AX - entity handle
; output:
;		AX - 0 when no such entity found, other value otherwise
;	 DS:SI - pointer to entity, when found
_gx_icon_find_entity:
	push bx
	push cx
	push dx
	push di
	push fs

	push ax								; [1]
	
	mov ax, cs
	mov fs, ax
	
	mov bx, gxIconListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_ICON_PAYLOAD_SIZE
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
_gx_icon_handle_event:
	push cs
	pop ds

	; save pointer to event bytes
	mov word [cs:gxIconEventBytesSeg], es
	mov word [cs:gxIconEventBytesOff], di
	
	; prepare for possible iteration through all entities
	mov ax, cs
	mov fs, ax
	mov bx, gxIconListHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_ICON_PAYLOAD_SIZE
	
	cmp byte [es:di], GUI_EVENT_MOUSE_MOVE
	je _gx_icon_handle_event__mouse_event
	cmp byte [es:di], GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je _gx_icon_handle_event__mouse_event
	cmp byte [es:di], GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je _gx_icon_handle_event__mouse_event

	jmp _gx_icon_handle_event_done
_gx_icon_handle_event__mouse_event:
	mov ax, word [es:di+1]
	mov word [cs:gxIconMouseX], ax		; mouse X
	mov ax, word [es:di+3]
	mov word [cs:gxIconMouseY], ax		; mouse Y
	mov si, _gx_icon_mouse_event_callback
	call common_llist_foreach
	
	jmp _gx_icon_handle_event_done
_gx_icon_handle_event_done:
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
_gx_icon_mouse_event_callback:
	; check overlap
	mov ax, word [cs:gxIconMouseX]		; mouse X
	mov cx, word [cs:gxIconMouseY]		; mouse Y
	mov bx, 1					; mouse cursor width
	mov dx, 1					; mouse cursor height
	
	mov di, word [ds:si+16]		; entity height
	add di, 2*GX_ICON_PADDING
	mov gs, di
	mov di, word [ds:si+14]		; entity width
	add di, 2*GX_ICON_PADDING
	mov fs, word [ds:si+8]		; entity Y
	push si
	mov si, word [ds:si+6]		; entity X
	call common_geometry_test_rectangle_overlap_by_size	; AL := 0 when no
	pop si

	; here, AL = 0 when there's no overlap
	mov es, word [cs:gxIconEventBytesSeg]
	mov di, word [cs:gxIconEventBytesOff]
	mov bl, byte [es:di+0]	; BL := event type
	
	cmp bl, GUI_EVENT_MOUSE_MOVE
	je _gx_icon_mouse_event_callback__mouse_move
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je _gx_icon_mouse_event_callback__left_click_release
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je _gx_icon_mouse_event_callback__left_click_depress
	
	jmp _gx_icon_mouse_event_callback_done
_gx_icon_mouse_event_callback__mouse_move:
	; mouse move event
	cmp al, 0
	je _gx_icon_mouse_event_callback__mouse_move_no_overlap
_gx_icon_mouse_event_callback__mouse_move_with_overlap:
	test word [ds:si+10], GX_ICON_FLAG_HOVERED
	jnz _gx_icon_mouse_event_callback_done		; NOOP when already hovering
	; entity is becoming hovered NOW
	or word [ds:si+10], GX_ICON_FLAG_HOVERED | GX_ICON_FLAG_MUST_RENDER
	mov byte [cs:gxIconNeedRendering], 1		; mark component
	
	jmp _gx_icon_mouse_event_callback_done
_gx_icon_mouse_event_callback__mouse_move_no_overlap:
	test word [ds:si+10], GX_ICON_FLAG_HOVERED
	jz _gx_icon_mouse_event_callback_done		; NOOP when already not hovered
	; entity is becoming not hovered NOW
	mov cx, GX_ICON_FLAG_HOVERED | GX_ICON_FLAG_HELD_DOWN_LEFT
	xor cx, 0FFFFh
	and word [ds:si+10], cx							; clear flags
	or word [ds:si+10], GX_ICON_FLAG_MUST_RENDER	; mark entity
	mov byte [cs:gxIconNeedRendering], 1			; mark component
	
	jmp _gx_icon_mouse_event_callback_done
	
_gx_icon_mouse_event_callback__left_click_release:
	cmp al, 0
	je _gx_icon_mouse_event_callback_done		; NOOP when released outside
_gx_icon_mouse_event_callback__left_click_release_with_overlap:
	; a left click is being released on this entity
	test word [ds:si+10], GX_ICON_FLAG_HELD_DOWN_LEFT
	jz _gx_icon_mouse_event_callback_done		; NOOP if it wasn't held down
	; a left click is being released on this entity after it was held down

	mov dx, GX_ICON_FLAG_HELD_DOWN_LEFT
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	or word [ds:si+10], GX_ICON_FLAG_MUST_RENDER	; mark entity
	mov byte [cs:gxIconNeedRendering], 1			; mark component
	
	mov ax, word [ds:si+0]		; ID to pass into callback
	mov ds, word [ds:si+18]
	mov si, word [ds:si+20]		; callback address
	call gui_invoke_callback
	jmp _gx_icon_mouse_event_callback_done
	
_gx_icon_mouse_event_callback__left_click_depress:
	cmp al, 0
	je _gx_icon_mouse_event_callback_done		; NOOP when depressed outside
_gx_icon_mouse_event_callback__left_click_depress_with_overlap:
	; a left click is depressed on this entity
	or word [cs:si+10], GX_ICON_FLAG_HELD_DOWN_LEFT | GX_ICON_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:gxIconNeedRendering], 1	; mark component
	
	jmp _gx_icon_mouse_event_callback_done
	
_gx_icon_mouse_event_callback_done:
	mov ax, 1						; keep traversing
	retf


%include "common\vga640\gui\ext\gx.asm"			; must be included first

%include "common\memory.asm"
%include "common\dynamic\linklist.asm"
%include "common\vga640\gui\gui.asm"
	

%endif
