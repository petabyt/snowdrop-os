;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains logic for dealing with GUI images.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_IMAGES_
%define _COMMON_GUI_IMAGES_

IMAGE_NONE 				equ 0FFFFh ; word value which marks a slot as empty

IMAGES_ASCII_LENGTH		equ 32
IMAGES_ENTRY_SIZE_BYTES	equ 64
IMAGES_TOTAL_SIZE_BYTES equ (GUI_IMAGES_LIMIT+GUI_RESERVED_COMPONENT_COUNT)*IMAGES_ENTRY_SIZE_BYTES ; in bytes

IMAGE_FLAG_ENABLED			equ 1	; image is clickable
IMAGE_FLAG_HOVERED			equ 2	; image is hovered over by the mouse
IMAGE_FLAG_MUST_RENDER		equ 4	; image must be redrawn
IMAGE_FLAG_HELD_DOWN		equ 8	; image is clicked and held down
IMAGE_FLAG_PENDING_DELETE	equ 16	; image is pending deletion
IMAGE_FLAG_MARK_ON_HOVER	equ 32	; whether a mark is shown when hovered
IMAGE_FLAG_IGNORE_TRANSPARENCY	equ 64	; draw transparent pixels as opaque
IMAGE_FLAG_SELECTED				equ 128	; image is selected
IMAGE_FLAG_SHOW_SELECTED_MARK	equ 256	; show a mark when image is selected
IMAGE_FLAG_IS_ASCII_BASED		equ 512	; image is based on an ASCII character
IMAGE_FLAG_ASCII_SHOW_BORDER	equ 1024	; whether to show a border for ASCII images


; structure info (per array entry)
; bytes
;     0-1 id
;     2-3 position X
;     4-5 position Y
;     6-7 width
;     8-9 height
;   10-11 flags
;   12-13 flags from before last render
;   14-15 on left-click callback segment
;   16-17 on left-click callback offset
;   18-19 image data segment
;   20-21 image data offset
;   22-23 on right-click callback segment
;   24-25 on right-click callback offset
;   26-27 image data canvas width (allows use of sub-areas of larger images)
;   28-29 on selected state change callback segment
;   30-31 on selected state change callback offset
;   32-63 zero-terminated string used when image is using ASCII mode

; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
guiImagesStorage: times IMAGES_TOTAL_SIZE_BYTES db 0

guiImagesCurrentAsciiLength:	dw 0
guiImagesIncomingAsciiLength:	dw 0

guiImagesNeedRender:	db 0
				; becomes non-zero when a change which requires
				; at least one image to be redrawn took place

imagesDefaultAsciiImageString:	db '?', 0

GUI_ASCII_IMAGE_X_PADDING equ 4
GUI_ASCII_IMAGE_Y_PADDING equ 4

guiImagesRenderMode:	db	99
GUI_IMAGES_RENDER_MODE_DELETIONS		equ 0
GUI_IMAGES_RENDER_MODE_MODIFICATIONS	equ 1


; Sets the image mode to ASCII, whereby the image doesn't rely
; on a pointer to byte data, instead rendering an ASCII string.
; This function also re-calculates image size, based on the 
; rendered size of the ASCII string.
;
; NOTE: Changing the mode to ASCII of an image MUST be done immediately
;       after the image was created
;
; input:
;		AX - image handle
;	 DS:SI - pointer to string to be used when rendering image
; output:
;		none
gui_images_set_mode_ascii:
	pusha
	pushf
	push ds
	push es
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je gui_images_set_mode_ascii_done
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_IS_ASCII_BASED | IMAGE_FLAG_MUST_RENDER | IMAGE_FLAG_ASCII_SHOW_BORDER
					; we must re-render
	mov byte [cs:guiImagesNeedRender], 1	
					; mark images component for render
	
	call gui_images_set_ascii_text
gui_images_set_mode_ascii_done:
	pop es
	pop ds
	popf
	popa
	ret

	
; Sets the image's ASCII text
; This function also re-calculates image size, based on the 
; rendered size of the ASCII string.
;
; input:
;		AX - image handle
;	 DS:SI - pointer to string to be used when rendering image
; output:
;		none
gui_images_set_ascii_text:
	pusha
	pushf
	push ds
	push es
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je gui_images_set_ascii_text_done
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_MUST_RENDER
					; we must re-render
	mov byte [cs:guiImagesNeedRender], 1	
					; mark images component for render
	
	; save length of existing ASCII
	pusha
	push ds
	push cs
	pop ds
	mov si, bx
	add si, guiImagesStorage+32		; DS:SI := pointer to current ASCII string
	int 0A5h						; BX := string length
	mov word [cs:guiImagesCurrentAsciiLength], bx	; store current length
	pop ds
	popa
	
	push bx
	int 0A5h						; BX := string length
	mov ax, bx						; AX := string length
	pop bx
	cmp ax, 0						; is the passed in string non-empty?
	ja gui_images_set_ascii_text_copy_string	; yes
	; no, so copy a hardcoded placeholder
	push cs
	pop ds
	mov si, imagesDefaultAsciiImageString
	
gui_images_set_ascii_text_copy_string:
	; here, DS:SI points to the string to be copied
	; copy ASCII from DS:SI into the image's ASCII buffer
	pusha
	push ds
	
	push cs
	pop es
	mov di, guiImagesStorage		; ES:DI := pointer to storage start
	add di, bx						; ES:DI := pointer to array element
	add di, 32						; ES:DI := pointer to ASCII
	push di							; [1] save pointer to image ASCII
	mov cx, IMAGES_ASCII_LENGTH
	cld
	rep movsb						; copy as many bytes as maximum ASCII
	dec di							; ES:DI := pointer to last byte of ASCII
	mov byte [es:di], 0				; add terminator, in case passed-in ASCII
									; was too long
	pop si							; [1] restore pointer to image ASCII
	
	push cs
	pop ds							; DS:SI := pointer to image ASCII
	int 0A5h						; BX := string length
	mov word [cs:guiImagesIncomingAsciiLength], bx		; store it
	
	pop ds
	popa

	; we skip truncation/padding if this is the first assignment of ASCII str.
	cmp word [cs:guiImagesCurrentAsciiLength], 0
	je gui_images_set_ascii_text_calculate_size
	
	; now either truncate or pad, so ASCII size stays equal
	mov ax, word [cs:guiImagesIncomingAsciiLength]
	cmp ax, word [cs:guiImagesCurrentAsciiLength]
	je gui_images_set_ascii_text_calculate_size	; the incoming string
												; has the same length
	jb gui_images_set_ascii_text_incoming_is_shorter	; incoming is shorter
	; incoming is longer
gui_images_set_ascii_text_incoming_is_longer:
	pusha
	mov di, word [cs:guiImagesCurrentAsciiLength]	; terminate where current
	mov byte [cs:guiImagesStorage+bx+32+di], 0		; terminated
	popa
	jmp gui_images_set_ascii_text_calculate_size
	
gui_images_set_ascii_text_incoming_is_shorter:
	pusha
	push cs
	pop es
	mov di, guiImagesStorage+32						; ES:DI := pointer to
	add di, bx										; terminator of newly-set
	push di											; save ptr to image's str.
	add di, word [cs:guiImagesIncomingAsciiLength]	; ASCII string
	mov cx, IMAGES_ASCII_LENGTH-1
	sub cx, word [cs:guiImagesIncomingAsciiLength]
	mov al, ' '										; pad with blanks up to
	rep stosb										; end-1 (last character is
													; already a terminator)
	pop di											; ES:DI := ptr to image str
	add di, word [cs:guiImagesCurrentAsciiLength]	; point to where terminator
													; must go
	mov byte [cs:di], 0								; terminate in new spot
	popa
	jmp gui_images_set_ascii_text_calculate_size
	
gui_images_set_ascii_text_calculate_size:
	; calculate image height and width based on ASCII string
	push ds
	pusha
	push cs
	pop ds
	mov si, guiImagesStorage+32
	add si, bx									; DS:SI := image's ASCII string
	call common_graphics_text_measure_width		; AX := text width
	add ax, 2*GUI_ASCII_IMAGE_X_PADDING
	mov word [cs:guiImagesStorage+bx+6], ax		; width
	mov word [cs:guiImagesStorage+bx+8], COMMON_GRAPHICS_FONT_HEIGHT + 2*GUI_ASCII_IMAGE_Y_PADDING ; height
	popa
	pop ds
gui_images_set_ascii_text_done:
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Configures the specified ASCII image to not draw a decorative border
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_ascii_border_hide:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_ascii_border_hide_done
	
	mov dx, IMAGE_FLAG_ASCII_SHOW_BORDER
	xor dx, 0FFFFh
	and word [cs:guiImagesStorage+bx+10], dx
					; clear flag
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_MUST_RENDER
					; set flag
	mov byte [cs:guiImagesNeedRender], 1	
					; mark images component for render
common_gui_image_ascii_border_hide_done:
	popa
	ret
	
	
; Configures the specified ASCII image to draw a decorative border
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_ascii_border_show:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_ascii_border_show_done

	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_MUST_RENDER | IMAGE_FLAG_ASCII_SHOW_BORDER
					; set flag
	mov byte [cs:guiImagesNeedRender], 1	
					; mark images component for render
common_gui_image_ascii_border_show_done:
	popa
	ret
	
				
; Prepares images module before usage
;
; input:
;		none
; output:
;		none
gui_images_prepare:
	pusha
	
	call gui_images_clear_storage
	mov byte [cs:guiImagesNeedRender], 0
	
	popa
	ret


; Erases an image from the screen
;
; input:
;		BX - ID (offset) of image
; output:
;		none	
gui_images_erase:
	pusha
	
	add bx, guiImagesStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to array element
	
	mov bx, word [cs:si+2]			; X
	mov ax, word [cs:si+4]			; Y
	
	; draw a rectangle that's the same colour as the background, and large
	; enough to cover not just the image, but also its border
	mov cx, word [cs:si+6]			; width
	mov di, word [cs:si+8]			; height
	mov dl, byte [cs:guiColour1]
	call common_graphics_draw_rectangle_solid
	
	popa
	ret
	

; Draws a rectangle which signifies that the image is selected, but 
; only if applicable.
;
; input:
;		CS:SI - pointer to image
; output:
;		none	
gui_images_render_selected_rectangle:
	pusha

	mov di, si
	
	mov ax, word [cs:di+10]			; AX := flags

	and ax, IMAGE_FLAG_SELECTED | IMAGE_FLAG_SHOW_SELECTED_MARK
	cmp ax, IMAGE_FLAG_SELECTED | IMAGE_FLAG_SHOW_SELECTED_MARK
	jne gui_images_render_selected_rectangle_done	; it's not applicable
	
	; it's enabled and selected, so draw the selected mark
	call common_gui_get_colour_foreground	; CX := colour
	test word [cs:di+10], IMAGE_FLAG_ENABLED
	jnz gui_images_render_selected_rectangle_got_colour
	call common_gui_get_colour_disabled		; CX := colour

gui_images_render_selected_rectangle_got_colour:
	; here, colour is in CX
	mov dl, cl						; DL := colour
	
	mov bx, word [cs:di+2]			; X
	mov ax, word [cs:di+4]			; Y
	mov cx, word [cs:di+6]			; width
	mov si, word [cs:di+8]			; height
	call common_graphics_draw_rectangle_outline_by_coords

gui_images_render_selected_rectangle_done:
	popa
	ret
	

; Draws an image in its released (default) state
;
; input:
;		CS:SI - pointer to image
; output:
;		none
gui_images_render_draw:
	pusha
	push ds
	push es

	mov di, si						; use DI to index for now
	; decide how we will draw the image
	test word [cs:di+10], IMAGE_FLAG_IS_ASCII_BASED
	jz gui_images_render_draw_from_pixel_data	; we render from pixel data
	; we render from an ASCII string

gui_images_render_draw_from_ascii:
	push ds
	push si
	mov cl, byte [cs:guiColour0]			; enabled colour
	test word [cs:di+10], IMAGE_FLAG_ENABLED
	jnz gui_images_render_draw_from_ascii_got_colour
	mov cl, byte [cs:guiColour3]			; disabled colour
	
gui_images_render_draw_from_ascii_got_colour:
	mov bx, word [cs:di+2]			; X
	mov ax, word [cs:di+4]			; Y
	
	; render text
	add bx, GUI_ASCII_IMAGE_X_PADDING
	add ax, GUI_ASCII_IMAGE_Y_PADDING
	push cs
	pop ds
	add si, 32						; DS:SI := pointer to ASCII string
	mov dx, word [cs:guiIsBoldFont]	; options
	call common_graphics_text_print_at
	pop si
	pop ds
	
	; render a decorative border around the image, if needed
	test word [cs:di+10], IMAGE_FLAG_ASCII_SHOW_BORDER
	jz gui_images_render_draw_from_ascii_draw_border__done
	
	mov dl, byte [cs:guiColour2]			; enabled colour
	test word [cs:di+10], IMAGE_FLAG_ENABLED
	jnz gui_images_render_draw_from_ascii_draw_border
	mov dl, byte [cs:guiColour3]			; disabled colour
gui_images_render_draw_from_ascii_draw_border:
	mov bx, word [cs:di+2]			; X
	add bx, 2
	mov ax, word [cs:di+4]			; Y
	add ax, 2
	mov cx, word [cs:di+6]			; width
	sub cx, 4
	mov si, word [cs:di+8]			; height
	sub si, 4
	call common_graphics_draw_rectangle_outline_by_coords
gui_images_render_draw_from_ascii_draw_border__done:	
	jmp gui_images_render_draw_hover_mark
	
gui_images_render_draw_from_pixel_data:	
	; draw rectangle using image's pixel data
	push di							; [3] save DI
	push ds							; [2] save DS
	mov bx, word [cs:di+2]			; X
	mov ax, word [cs:di+4]			; Y
	
	mov dx, word [cs:di+26]			; global bitmap width
	mov cx, word [cs:di+6]			; width
	
	mov ds, word [cs:di+18]
	mov si, word [cs:di+20]			; DS:SI := pointer to image data
	
	test word [cs:di+10], IMAGE_FLAG_IGNORE_TRANSPARENCY	; [*] which mode?
	mov di, word [cs:di+8]			; height (MODIFIES DI!
	jz gui_images_render_draw_transparent					; [*]
	
	; draw opaque, ignoring transparent pixels
	call common_graphics_draw_rectangle_opaque
	jmp gui_images_render_draw_rectangle_done
gui_images_render_draw_transparent:
	; draw transparent
	call common_graphics_draw_rectangle_transparent

gui_images_render_draw_rectangle_done:
	pop ds							; [2] restore DS
	pop di							; [3] restore DI

gui_images_render_draw_hover_mark:	
	; draw the hover mark if applicable
	mov ax, word [cs:di+10]			; AX := flags
	and ax, IMAGE_FLAG_ENABLED | IMAGE_FLAG_HOVERED | IMAGE_FLAG_MARK_ON_HOVER
	cmp ax, IMAGE_FLAG_ENABLED | IMAGE_FLAG_HOVERED | IMAGE_FLAG_MARK_ON_HOVER
	jne gui_images_render_draw_done	; it's not enabled and hovered
	; it's enabled and hovered, so draw the hover mark
	mov bx, word [cs:di+2]			; X
	mov ax, word [cs:di+4]			; Y
	mov cx, word [cs:di+6]			; width
	mov si, word [cs:di+8]			; height
	mov dl, byte [cs:guiColour2]
	call common_graphics_draw_rectangle_outline_by_coords

gui_images_render_draw_done:
	pop es
	pop ds
	popa
	ret
	

; Draws an image on the screen
;
; input:
;		BX - ID (offset) of image
; output:
;		none
gui_images_render:
	pusha
	push ds
	
	call gui_images_erase			; first, erase image
	
	add bx, guiImagesStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to array element

	test word [cs:si+10], IMAGE_FLAG_PENDING_DELETE
	jnz gui_images_render_finish	; image was deleted

	call gui_images_render_draw
	call gui_images_render_selected_rectangle

gui_images_render_finish:
	; we're done drawing; now perform some housekeeping
	mov ax, word [cs:si+10]
	mov word [cs:si+12], ax			; old flags := flags

	; if it was pending deletion, we have erased from screen, so
	; we can clear that flag, as well
	mov ax, IMAGE_FLAG_MUST_RENDER | IMAGE_FLAG_PENDING_DELETE
	xor ax, 0FFFFh
	and word [cs:si+10], ax			; clear flags

	pop ds
	popa
	ret


; Makes the specified image disabled and no longer responding to
; interactions events
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_disable:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_disable_done
	
	mov ax, IMAGE_FLAG_ENABLED | IMAGE_FLAG_HOVERED
	xor ax, 0FFFFh
	and word [cs:guiImagesStorage+bx+10], ax	; clear flags
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_MUST_RENDER
					; we must re-render
	mov byte [cs:guiImagesNeedRender], 1	
					; mark images component for render
common_gui_image_disable_done:
	popa
	ret


; Configures the specified image to show a mark when hovered
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_hover_mark_set:
	pusha

	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_hover_mark_set_done
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_MARK_ON_HOVER ; set flag
common_gui_image_hover_mark_set_done:
	popa
	ret
	

; Configures the specified image to ignore transparent pixels,
; drawing them like normal pixels
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_ignore_transparency_set:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_ignore_transparency_set_done
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_IGNORE_TRANSPARENCY | IMAGE_FLAG_MUST_RENDER
					; set flags
	mov byte [cs:guiImagesNeedRender], 1	
					; mark images component for render
common_gui_image_ignore_transparency_set_done:
	popa
	ret

	
; Configures the specified image to count transparent pixels as transparent
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_ignore_transparency_clear:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_ignore_transparency_clear_done
	
	mov dx, IMAGE_FLAG_IGNORE_TRANSPARENCY
	xor dx, 0FFFFh
	and word [cs:guiImagesStorage+bx+10], dx
					; clear flag
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_MUST_RENDER
					; set flag
	mov byte [cs:guiImagesNeedRender], 1	
					; mark images component for render
common_gui_image_ignore_transparency_clear_done:
	popa
	ret
	

; Configures the specified image to not show a mark when hovered
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_hover_mark_clear:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_hover_mark_clear_done
	
	mov ax, IMAGE_FLAG_MARK_ON_HOVER
	xor ax, 0FFFFh
	and word [cs:guiImagesStorage+bx+10], ax	; clear flag
common_gui_image_hover_mark_clear_done:
	popa
	ret
	
	
; Enables the specified image
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_enable:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_enable_done
	
	test word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_PENDING_DELETE
	jnz common_gui_image_enable_done	
					; cannot enable an image being deleted
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_ENABLED | IMAGE_FLAG_MUST_RENDER
					; set flags
	mov byte [cs:guiImagesNeedRender], 1
							; mark images component for render
common_gui_image_enable_done:
	popa
	ret
	
	
; Deletes the specified image entirely, removing it from screen 
; and freeing up its memory
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_delete:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_delete_done

	mov word [cs:guiImagesStorage+bx+0], IMAGE_NONE	
									; free image entry
	mov word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_PENDING_DELETE | IMAGE_FLAG_MUST_RENDER
					; clear all flags except these ones
					; note, the image is also flagged as disabled, so
					; it cannot be interacted with
	mov byte [cs:guiImagesNeedRender], 1
					; mark images component for render
common_gui_image_delete_done:
	popa
	ret
	

; Clears all storage image entries
;
; input:
;		none
; output:
;		none
gui_images_clear_storage:
	pusha

	mov si, guiImagesStorage
	mov bx, 0				; offset of array slot being checked
gui_images_clear_storage_loop:
	mov word [cs:si+bx], IMAGE_NONE	; mark slot as available
	mov word [cs:si+bx+10], 0			; clear flags
gui_images_clear_storage_next:
	add bx, IMAGES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, IMAGES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_images_clear_storage_loop			; no
gui_images_clear_storage_done:
	popa
	ret


; Adds an image
;
; input:
;		AX - position X
;		BX - position Y
;		CX - width
;		DX - height
;		DI - image data canvas width (allows rectangular sub-areas of
;            a larger bitmap to be used as the image data)
;	 DS:SI - pointer to image data
; output:
;		AX - image handle
common_gui_image_add:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	push bx							; [1] save input
	
	call gui_images_find_empty_slot	; BX := offset
										; CARRY=0 when slot was found
	jc common_gui_image_add_full
	; we found a slot, so add the image
	
	push bx							; [3] save image offset
	add bx, guiImagesStorage		; BX := pointer to image

	mov word [cs:bx+0], 0			; id
	mov word [cs:bx+6], cx			; width
	mov word [cs:bx+8], dx			; height
	
	; until the consumer its own callbacks, set a NOOP callback
	mov word [cs:bx+14], cs
	mov word [cs:bx+16], gui_noop_callback
	mov word [cs:bx+22], cs
	mov word [cs:bx+24], gui_noop_callback
	mov word [cs:bx+28], cs
	mov word [cs:bx+30], gui_noop_callback
	
	push dx							; [2] save input
	mov dx, IMAGE_FLAG_ENABLED | IMAGE_FLAG_MUST_RENDER | IMAGE_FLAG_MARK_ON_HOVER | IMAGE_FLAG_SHOW_SELECTED_MARK
	mov word [cs:bx+10], dx			; flags
	mov word [cs:bx+12], dx			; old flags
	pop dx							; [2] restore input
	
	mov word [cs:bx+2], ax			; position X

	; save pointer to image data
	push ds
	pop word [cs:bx+18]				; save image data segment
	push si
	pop word [cs:bx+20]				; save image data offset
	
	mov word [cs:bx+26], di			; save image data canvas width
	
	mov byte [cs:bx+32], 0			; set ASCII string to empty string
	
	pop ax							; [3] AX := image offset
	
	mov si, bx						; SI := pointer to array element
	pop bx							; [1] restore input
	mov word [cs:si+4], bx			; position Y
	
	mov byte [cs:guiImagesNeedRender], 1 ; indicate some images changed
	jmp common_gui_image_add_done	; we're done
	
common_gui_image_add_full:
	pop bx							; remove extra value on stack
common_gui_image_add_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	

; Returns a byte offset of first empty slot in the array
;
; input:
;		none
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - byte offset (into array) of first empty slot, if one was found
gui_images_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, guiImagesStorage
	mov bx, 0				; offset of array slot being checked
gui_images_find_empty_slot_loop:
	test word [cs:si+bx+10], IMAGE_FLAG_PENDING_DELETE
	jnz gui_images_find_empty_slot_loop_next
							; skip slot if it's pending delete
							
	cmp word [cs:si+bx], IMAGE_NONE			; is this slot empty?
										; (are first two bytes IMAGE_NONE?)
	je gui_images_find_empty_slot_done	; yes

gui_images_find_empty_slot_loop_next:
	add bx, IMAGES_ENTRY_SIZE_BYTES		; next slot
	cmp bx, IMAGES_TOTAL_SIZE_BYTES		; are we past the end?
	jb gui_images_find_empty_slot_loop		; no
gui_images_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp gui_images_find_empty_slot_done
gui_images_find_empty_slot_done:
	pop si
	ret


; Iterates through all images, rendering those which need it
;
; input:
;		none
; output:
;		none
gui_images_render_all:
	mov byte [cs:guiImagesRenderMode], GUI_IMAGES_RENDER_MODE_DELETIONS
	call private_gui_images_render_all
	mov byte [cs:guiImagesRenderMode], GUI_IMAGES_RENDER_MODE_MODIFICATIONS
	call private_gui_images_render_all
	ret

	
; Iterates through those images to which the current rendering 
; mode pertains, rendering those which need it.
;
; input:
;		none
; output:
;		none
private_gui_images_render_all:
	pusha

	mov si, guiImagesStorage
	mov bx, 0				; offset of array slot being checked
gui_images_render_all_loop:
	cmp byte [cs:guiImagesRenderMode], GUI_IMAGES_RENDER_MODE_MODIFICATIONS
	je gui_images_render_all_loop_after_deleted_handling
				; we're only rendering modifications, so skip over the handling
				; of deleted ones
	test word [cs:si+bx+10], IMAGE_FLAG_PENDING_DELETE
	jnz gui_images_render_all_perform	; if it's pending delete, we have to
										; render it
										
	cmp byte [cs:guiImagesRenderMode], GUI_IMAGES_RENDER_MODE_DELETIONS
	je gui_images_render_all_next		; we're only rendering deletions, so
										; go to next
gui_images_render_all_loop_after_deleted_handling:
	cmp word [cs:si+bx], IMAGE_NONE	; is this slot empty?
										; (are first two bytes IMAGE_NONE?)
	je gui_images_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_images_render_all_perform:	
	test word [cs:si+bx+10], IMAGE_FLAG_MUST_RENDER
	jz gui_images_render_all_next		; we don't have to redraw this one
	call gui_images_render				; perform
gui_images_render_all_next:
	add bx, IMAGES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, IMAGES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_images_render_all_loop			; no
gui_images_render_all_done:
	mov byte [cs:guiImagesNeedRender], 0	; mark rendering complete
	popa
	ret
	

; Returns whether some images need to be rendered	
;
; input:
;		none
; output:
;		AL - 0 when images don't need rendering, other value otherwise
gui_images_get_need_render:
	mov al, byte [cs:guiImagesNeedRender]
	ret

	
; Invokes the "selected changed" callback of the specified image
;
; input:
;		BX - ID (offset) of image
; output:
;		none
gui_images_invoke_selected_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word gui_images_invoke_selected_callback_return
											; return address on stack
	
	; setup "call far" address
	push word [cs:guiImagesStorage+bx+28]			; callback segment
	push word [cs:guiImagesStorage+bx+30]			; callback offset

	; setup callback arguments
	mov ax, bx						; AX := image handle
	mov cx, word [cs:guiImagesStorage+bx+10]
	and cx, IMAGE_FLAG_SELECTED
	mov bx, cx						; BX := 0 when not selected

	retf							; "call far"
	; once the callback executes its own retf, execution returns below
gui_images_invoke_selected_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret
	

; Invokes the left-click callback of the specified image
;
; input:
;		BX - ID (offset) of image
; output:
;		none
gui_images_invoke_lclick_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word gui_images_invoke_lclick_callback_return	; return address on stack
	
	; setup "call far" address
	push word [cs:guiImagesStorage+bx+14]			; callback segment
	push word [cs:guiImagesStorage+bx+16]			; callback offset

	; setup callback arguments
	mov ax, bx						; AX := image handle	
	
	retf							; "call far"
	; once the callback executes its own retf, execution returns below
gui_images_invoke_lclick_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret

	
; Invokes the right-click callback of the specified image
;
; input:
;		BX - ID (offset) of image
; output:
;		none
gui_images_invoke_rclick_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word gui_images_invoke_rclick_callback_return	; return address on stack
	
	; setup "call far" address
	push word [cs:guiImagesStorage+bx+22]			; callback segment
	push word [cs:guiImagesStorage+bx+24]			; callback offset
	
	; setup callback arguments
	mov ax, bx						; AX := image handle
	
	retf							; "call far"
	; once the callback executes its own retf, execution returns below
gui_images_invoke_rclick_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret
	

; Sets the specified image's left click callback, which is invoked 
; whenever the image is left-clicked
;
; input:
;		AX - image handle
;	 DS:SI - pointer to callback function
; output:
;		none	
common_gui_image_left_click_callback_set:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_left_click_callback_set_done
	
	mov word [cs:guiImagesStorage+bx+14], ds		; callback segment
	mov word [cs:guiImagesStorage+bx+16], si		; callback offset
common_gui_image_left_click_callback_set_done:
	popa
	ret

	
; Sets the specified image's selected callback, which is invoked 
; whenever the image's selected state changes
;
; input:
;		AX - image handle
;	 DS:SI - pointer to callback function
; output:
;		none	
common_gui_image_selected_callback_set:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_selected_callback_set_done
	
	mov word [cs:guiImagesStorage+bx+28], ds		; callback segment
	mov word [cs:guiImagesStorage+bx+30], si		; callback offset
common_gui_image_selected_callback_set_done:
	popa
	ret
	
	
; Sets the specified image's right click callback, which is invoked 
; whenever the image is right-clicked
;
; input:
;		AX - image handle
;	 DS:SI - pointer to callback function
; output:
;		none	
common_gui_image_right_click_callback_set:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_right_click_callback_set_done
	
	mov word [cs:guiImagesStorage+bx+22], ds		; callback segment
	mov word [cs:guiImagesStorage+bx+24], si		; callback offset
common_gui_image_right_click_callback_set_done:
	popa
	ret
	
	
; Clears the specified image's left click callback
;
; input:
;		AX - image handle
; output:
;		none	
common_gui_image_left_click_callback_clear:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_left_click_callback_clear_done
	
	mov word [cs:guiImagesStorage+bx+14], cs		; callback segment
	mov word [cs:guiImagesStorage+bx+16], gui_noop_callback
								; NOOP callback offset
common_gui_image_left_click_callback_clear_done:
	popa
	ret


; Clears the specified image's right click callback
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_right_click_callback_clear:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_right_click_callback_clear_done
	
	mov word [cs:guiImagesStorage+bx+22], cs		; callback segment
	mov word [cs:guiImagesStorage+bx+24], gui_noop_callback
								; NOOP callback offset
common_gui_image_right_click_callback_clear_done:
	popa
	ret


; Clears the specified image's selected callback
;
; input:
;		AX - image handle
; output:
;		none
common_gui_image_selected_callback_clear:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_selected_callback_clear_done
	
	mov word [cs:guiImagesStorage+bx+28], cs		; callback segment
	mov word [cs:guiImagesStorage+bx+30], gui_noop_callback
								; NOOP callback offset
common_gui_image_selected_callback_clear_done:
	popa
	ret
	

; Sets the image data of the specified image
;
; input:
;		AX - image handle
;	 DS:SI - pointer to data
; output:
;		none	
common_gui_image_set_data:
	pusha
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_set_data_done
	
	mov word [cs:guiImagesStorage+bx+18], ds	; image data segment
	mov word [cs:guiImagesStorage+bx+20], si	; image data offset
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_MUST_RENDER
	mov byte [cs:guiImagesNeedRender], 1		; schedule for render
common_gui_image_set_data_done:
	popa
	ret
	
	
; Gets the selected state of the specified image
;
; input:
;		AX - image handle
; output:
;		BX - selected state: 0 for not selected, other value for selected
common_gui_image_get_selected:
	push ax
	
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_get_selected_done
	
	mov ax, word [cs:guiImagesStorage+bx+10]
	and ax, IMAGE_FLAG_SELECTED
	mov bx, ax				; BX := 0 when not selected, other value otherwise
common_gui_image_get_selected_done:
	pop ax
	ret
	
	
; Sets the selected state of the specified image
;
; input:
;		AX - image handle
;		BX - image state: 0 for not selected, other value for selected
; output:
;		none
common_gui_image_set_selected:
	pusha

	cmp bx, 0
	je common_gui_image_set_selected_clear
	; set selected
	mov bx, ax
	
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_set_selected_done
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_SELECTED
	jmp common_gui_image_set_selected_finish
common_gui_image_set_selected_clear:
	mov bx, ax
	
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_set_selected_done
	
	mov cx, IMAGE_FLAG_SELECTED
	xor cx, 0FFFFh
	and word [cs:guiImagesStorage+bx+10], cx		; clear flag
common_gui_image_set_selected_finish:
	or word [cs:guiImagesStorage+bx+10], CHECKBOX_FLAG_MUST_RENDER
											; schedule for render
	mov byte [cs:guiImagesNeedRender], 1	; schedule images for render
	
	; raise event
	mov si, bx
	add si, guiImagesStorage			; CS:SI := pointer to image
	call gui_images_raise_selected_changed_event
common_gui_image_set_selected_done:
	popa
	ret
	
	
; Configures whether the specified image shows a mark when selected.
;
; input:
;		AX - image handle
;		BX - 0 for no mark, other value to show a mark
; output:
;		none
common_gui_image_set_show_selected_mark:
	pusha

	cmp bx, 0
	je common_gui_image_set_show_selected_mark_clear
	
	; it becomes set
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_set_show_selected_mark_done
	
	or word [cs:guiImagesStorage+bx+10], IMAGE_FLAG_SHOW_SELECTED_MARK
	jmp common_gui_image_set_show_selected_mark_finish
common_gui_image_set_show_selected_mark_clear:
	; it becomes clear
	mov bx, ax
	cmp word [cs:guiImagesStorage+bx], IMAGE_NONE
	je common_gui_image_set_show_selected_mark_done
	
	mov cx, IMAGE_FLAG_SHOW_SELECTED_MARK
	xor cx, 0FFFFh
	and word [cs:guiImagesStorage+bx+10], cx		; clear flag
common_gui_image_set_show_selected_mark_finish:
	or word [cs:guiImagesStorage+bx+10], CHECKBOX_FLAG_MUST_RENDER
											; schedule for render
	mov byte [cs:guiImagesNeedRender], 1	; schedule images for render
common_gui_image_set_show_selected_mark_done:
	popa
	ret
	
	
; Raises a "selected changed" event
;
; input:
;		CS:SI - pointer to image
; output:
;		none
gui_images_raise_selected_changed_event:
	pusha
	
	mov al, GUI_EVENT_IMAGE_INVOKE_SELECTED_CHANGED_CALLBACK
	mov bx, si
	sub bx, guiImagesStorage	; BX := image offset
	call gui_event_enqueue_3bytes_atomic

	popa
	ret
	
	
; Considers the newly-dequeued event, and modifies image state
; for any affected images.
;
; input:
;		none
; output:
;		none
gui_images_handle_event:
	pusha
	
	call gui_images_is_event_applicable
	cmp ax, 0
	je gui_images_handle_event_done		; event is not applicable
	; event is applicable (it may modify image state)

	; some event types can be handled without iterating through all images
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_IMAGE_INVOKE_LCLICK_CALLBACK
	je gui_images_handle_event_invoke_lclick_callback
	
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_IMAGE_INVOKE_RCLICK_CALLBACK
	je gui_images_handle_event_invoke_rclick_callback
	
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_IMAGE_INVOKE_SELECTED_CHANGED_CALLBACK
	je gui_images_handle_event_invoke_selected_callback
	
	jmp gui_images_handle_event_iterate	; the event is "per-image", so
											; start iterating
gui_images_handle_event_invoke_lclick_callback:
	mov bx, word [cs:dequeueEventBytesBuffer+1]		; image offset
	call gui_images_invoke_lclick_callback
	jmp gui_images_handle_event_done
	
gui_images_handle_event_invoke_rclick_callback:
	mov bx, word [cs:dequeueEventBytesBuffer+1]		; image offset
	call gui_images_invoke_rclick_callback
	jmp gui_images_handle_event_done
	
gui_images_handle_event_invoke_selected_callback:
	mov bx, word [cs:dequeueEventBytesBuffer+1]		; image offset
	call gui_images_invoke_selected_callback
	jmp gui_images_handle_event_done

	; iterate through each image
gui_images_handle_event_iterate:
	mov si, guiImagesStorage
	mov bx, 0				; offset of array slot being checked
gui_images_handle_event_loop:
	test word [cs:si+bx+10], IMAGE_FLAG_PENDING_DELETE
	jnz gui_images_handle_event_next	; don't apply events if deleted
	
	cmp word [cs:si+bx], IMAGE_NONE	; is this slot empty?
										; (are first two bytes IMAGE_NONE?)
	je gui_images_handle_event_next	; yes
	; this array element is not empty, so perform action on it	
	call gui_images_apply_event
gui_images_handle_event_next:
	add bx, IMAGES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, IMAGES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_images_handle_event_loop			; no
gui_images_handle_event_done:
	popa
	ret

	
; Raises a "left clicked" event
;
; input:
;		CS:SI - pointer to image
; output:
;		none
gui_images_raise_left_clicked_event:
	pusha
	
	mov al, GUI_EVENT_IMAGE_INVOKE_LCLICK_CALLBACK
	mov bx, si
	sub bx, guiImagesStorage	; BX := image offset
	call gui_event_enqueue_3bytes_atomic
	
	popa
	ret
	
	
; Raises a "right clicked" event
;
; input:
;		CS:SI - pointer to image
; output:
;		none
gui_images_raise_right_clicked_event:
	pusha
	
	mov al, GUI_EVENT_IMAGE_INVOKE_RCLICK_CALLBACK
	mov bx, si
	sub bx, guiImagesStorage	; BX := image offset
	call gui_event_enqueue_3bytes_atomic
	
	popa
	ret
	

; Applies the lastly-dequeued event to the specified image
;
; input:
;		BX - ID (offset) of image
; output:
;		none
gui_images_apply_event:
	pusha
	
	add bx, guiImagesStorage	; convert offset to pointer
	mov si, bx						; SI := pointer to image
	
	test word [cs:si+10], IMAGE_FLAG_ENABLED
	jz gui_images_apply_event_done	; we're done if image is not enabled

	push bx
	push cx
	push dx
	push si
	push di
	push fs
	push gs

	mov ax, word [cs:dequeueEventBytesBuffer+1]		; mouse X
	mov cx, word [cs:dequeueEventBytesBuffer+3]		; mouse Y
	mov bx, 1										; mouse cursor width
	mov dx, 1										; mouse cursor height
	mov di, word [cs:si+6]							; image width
	push word [cs:si+8]
	pop gs											; image height
	push word [cs:si+4]
	pop fs											; image Y
	push word [cs:si+2]
	pop si											; image X
	call common_geometry_test_rectangle_overlap_by_size
											; AL := 0 when no overlap
	pop gs
	pop fs
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	
	mov bl, byte [cs:dequeueEventBytesBuffer]		; BL := event type
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je gui_images_apply_event_mouse_left_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_images_apply_event_mouse_left_up
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_images_apply_event_mouse_right_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_images_apply_event_mouse_right_up
	cmp bl, GUI_EVENT_MOUSE_MOVE
	je gui_images_apply_event_mouse_move
	jmp gui_images_apply_event_done

	; if we got here,
	; - image is enabled
	; - AL = 0 when mouse cursor doesn't overlap image
gui_images_apply_event_mouse_left_up:
	cmp al, 0
	je gui_images_apply_event_done		; releasing is NOOP when no overlap
	test word [cs:si+10], IMAGE_FLAG_HELD_DOWN
	jz gui_images_apply_event_done		; image was not held down
	; there's overlap and image was held down
	
	; image is becoming released now
	mov dx, IMAGE_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	
	xor word [cs:si+10], IMAGE_FLAG_SELECTED	; toggle "selected" flag
	or word [cs:si+10], IMAGE_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiImagesNeedRender], 1		; schedule render
	
	; raise event to invoke callback
	call gui_images_raise_left_clicked_event
	call gui_images_raise_selected_changed_event
	jmp gui_images_apply_event_done

gui_images_apply_event_mouse_right_up:
	cmp al, 0
	je gui_images_apply_event_done		; releasing is NOOP when no overlap
	test word [cs:si+10], IMAGE_FLAG_HELD_DOWN
	jz gui_images_apply_event_done		; image was not held down
	; there's overlap and image was held down
	
	; image is becoming released now
	mov dx, IMAGE_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	
	; raise event to invoke callback
	call gui_images_raise_right_clicked_event
	jmp gui_images_apply_event_done

gui_images_apply_event_mouse_left_down:
	cmp al, 0
	je gui_images_apply_event_done	; clicking does nothing when no overlap
	; there is overlap
	or word [cs:si+10], IMAGE_FLAG_HELD_DOWN	; set flag
	jmp gui_images_apply_event_done

gui_images_apply_event_mouse_right_down:
	cmp al, 0
	je gui_images_apply_event_done	; clicking does nothing when no overlap
	; there is overlap
	or word [cs:si+10], IMAGE_FLAG_HELD_DOWN	; set flag
	jmp gui_images_apply_event_done

gui_images_apply_event_mouse_move:
	cmp al, 0
	je gui_images_apply_event_mouse_move_nonoverlapping
gui_images_apply_event_mouse_move_overlapping:
	; the mouse has moved within the image
	test word [cs:si+10], IMAGE_FLAG_HOVERED
	jnz gui_images_apply_event_done	; already hovered
	; image is becoming hovered now
	or word [cs:si+10], IMAGE_FLAG_HOVERED | IMAGE_FLAG_MUST_RENDER
								; mark image as hovered and needing render
	mov byte [cs:guiImagesNeedRender], 1
								; mark images component for render
	jmp gui_images_apply_event_done

gui_images_apply_event_mouse_move_nonoverlapping:
	; the mouse has moved outside of the image
	test word [cs:si+10], IMAGE_FLAG_HOVERED
	jz gui_images_apply_event_done
					; already not hovered; now check if we need to release it
	; image is becoming non-hovered now
	mov dx, IMAGE_FLAG_HOVERED
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "hovered" flag
	or word [cs:si+10], IMAGE_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiImagesNeedRender], 1
								; mark images component for render
gui_images_apply_event_mouse_move_nonoverlapping_release:
	; check if image should become released
	test word [cs:si+10], IMAGE_FLAG_HELD_DOWN
	jz gui_images_apply_event_done			; don't need to release
	; image is becoming released now
	mov dx, IMAGE_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	jmp gui_images_apply_event_done

gui_images_apply_event_done:
	popa
	ret
	
	
; Marks all components as needing render
;
; input:
;		none
; output:
;		none
gui_images_schedule_render_all:
	pusha

	mov si, guiImagesStorage
	mov bx, 0				; offset of array slot being checked
gui_images_schedule_render_all_loop:
	cmp word [cs:si+bx], IMAGE_NONE				; is this slot empty?
	je gui_images_schedule_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_images_schedule_render_all_perform:	
	or word [cs:si+bx+10], IMAGE_FLAG_MUST_RENDER
gui_images_schedule_render_all_next:
	add bx, IMAGES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, IMAGES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_images_schedule_render_all_loop			; no
gui_images_schedule_render_all_done:
	mov byte [cs:guiImagesNeedRender], 1	; mark entire component for render
	popa
	ret
	
	
; Checks whether the lastly-dequeued event is applicable to images
;
; input:
;		none
; output:
;		AX - 0 when event is irrelevant, other value if it should be handled
gui_images_is_event_applicable:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je gui_images_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_images_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_images_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_images_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSE_MOVE
	je gui_images_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_IMAGE_INVOKE_LCLICK_CALLBACK
	je gui_images_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_IMAGE_INVOKE_RCLICK_CALLBACK
	je gui_images_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_IMAGE_INVOKE_SELECTED_CHANGED_CALLBACK
	je gui_images_is_event_applicable_yes
gui_images_is_event_applicable_no:	
	mov ax, 0
	ret
gui_images_is_event_applicable_yes:
	mov ax, 1
	ret

	
%endif
