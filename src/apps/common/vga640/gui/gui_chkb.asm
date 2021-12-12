;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains logic for dealing with GUI checkboxes.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_CHECKBOXES_
%define _COMMON_GUI_CHECKBOXES_

CHECKBOX_NONE 				equ 0FFFFh ; word value which marks a slot as empty

CHECKBOXES_ENTRY_SIZE_BYTES	equ 64
CHECKBOXES_TOTAL_SIZE_BYTES equ (GUI_CHECKBOXES_LIMIT+GUI_RESERVED_COMPONENT_COUNT)*CHECKBOXES_ENTRY_SIZE_BYTES ; in bytes

CHECKBOX_FLAG_ENABLED			equ 1	; checkbox is clickable
CHECKBOX_FLAG_HOVERED			equ 2	; checkbox is hovered over by the mouse
CHECKBOX_FLAG_MUST_RENDER		equ 4	; checkbox must be redrawn
CHECKBOX_FLAG_CHECKED			equ 8	; checkbox is checked
CHECKBOX_FLAG_PENDING_DELETE	equ 16	; checkbox is pending deletion
CHECKBOX_FLAG_HELD_DOWN			equ 32	; checkbox is being held down via a click

CHECKBOXES_LABEL_LENGTH		equ 32

CHECKBOX_SQUARE_SIZE		equ COMMON_GRAPHICS_FONT_WIDTH	; size of the box
CHECKBOX_LABEL_PADDING_X	equ CHECKBOX_SQUARE_SIZE + CHECKBOX_DEPTH
				; in pixels, from the overall X position
CHECKBOX_DEPTH				equ 1	; in pixels

CHECKBOX_HOVER_MARK_SIZE_PIXELS		equ 2

COMMON_GUI_CHECKBOX_HEIGHT_SINGLE_LINE equ COMMON_GRAPHICS_FONT_HEIGHT + CHECKBOX_DEPTH
		; height of a checkbox containing a single line of text as the label

; structure info (per array entry)
; bytes
;     0-1 id
;     2-3 position X
;     4-5 position Y
;     6-7 width
;     8-9 height
;   10-11 flags
;   12-13 flags from before last render
;   14-15 on-change callback segment
;   16-17 on-change callback offset
;   18-31 unused
;   32-63 zero-terminated label string

; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
guiCheckboxesStorage: times CHECKBOXES_TOTAL_SIZE_BYTES db 0

guiCheckboxesNeedRender:	db 0
				; becomes non-zero when a change which requires
				; at least one checkbox to be redrawn took place

guiCheckboxesRenderMode:	db	99
GUI_CHECKBOXES_RENDER_MODE_DELETIONS		equ 0
GUI_CHECKBOXES_RENDER_MODE_MODIFICATIONS	equ 1

; Prepares checkboxes module before usage
;
; input:
;		none
; output:
;		none
gui_checkboxes_prepare:
	pusha
	
	call gui_checkboxes_clear_storage
	mov byte [cs:guiCheckboxesNeedRender], 0
	
	popa
	ret


; Erases a checkbox from the screen
;
; input:
;		BX - ID (offset) of checkbox
; output:
;		none	
gui_checkboxes_erase:
	pusha
	
	add bx, guiCheckboxesStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to array element
	
	mov bx, word [cs:si+2]			; X
	mov ax, word [cs:si+4]			; Y
	
	; draw a rectangle that's the same colour as the background, and large
	; enough to cover not just the checkbox, but also its depth
	mov cx, word [cs:si+6]			; width
	mov di, word [cs:si+8]			; height
	mov dl, byte [cs:guiColour1]
	call common_graphics_draw_rectangle_solid
	
	popa
	ret
	

; Draws a checkmark (if needed), inside the specified checkbox
;
; input:
;		CS:SI - pointer to checkbox
; output:
;		none	
gui_checkboxes_render_checkmark:
	pusha
	test word [cs:si+10], CHECKBOX_FLAG_CHECKED
	jz gui_checkboxes_render_checkmark_done
	
	test word [cs:si+10], CHECKBOX_FLAG_ENABLED
	jz gui_checkboxes_render_checkmark_disabled
	
gui_checkboxes_render_checkmark_enabled:
	mov dl, byte [cs:guiColour0]
	jmp gui_checkboxes_render_checkmark_perform
gui_checkboxes_render_checkmark_disabled:
	mov dl, byte [cs:guiColour3]
	
gui_checkboxes_render_checkmark_perform:
	; render it
	mov bx, word [cs:si+2]			; X
	inc bx
	mov ax, word [cs:si+4]			; Y
	add ax, CHECKBOX_SQUARE_SIZE
	dec ax
	dec ax
	dec ax
	call common_graphics_draw_pixel_by_coords
	push ax
	dec ax
	call common_graphics_draw_pixel_by_coords	; draw pixel towards top-right
	pop ax
	inc ax
	inc bx
	call common_graphics_draw_pixel_by_coords
	push ax
	dec ax
	call common_graphics_draw_pixel_by_coords	; draw pixel towards top-right
	pop ax
	
	mov cx, word [cs:si+2]
	add cx, CHECKBOX_SQUARE_SIZE
	dec cx								; CX := X of right vertical of box
	dec cx				; CX := X immediately to the left of right vertical
gui_checkboxes_render_checkmark_loop:
	dec ax
	inc bx
	call common_graphics_draw_pixel_by_coords	; draw pixel towards top-right
	push ax
	dec ax
	call common_graphics_draw_pixel_by_coords	; draw pixel towards top-right
	pop ax
	
	cmp bx, cx
	jb gui_checkboxes_render_checkmark_loop
					; we're done when we reach right vertical of box
	
gui_checkboxes_render_checkmark_done:
	popa
	ret
	

; Draws a checkbox in its released (default) state
;
; input:
;		CS:SI - pointer to checkbox
; output:
;		none
gui_checkboxes_render_released:
	pusha

	; draw rectangle
	mov di, si						; use DI to index for now
	
	mov bx, word [cs:di+2]			; X
	mov ax, word [cs:di+4]			; Y
	mov cx, CHECKBOX_SQUARE_SIZE	; width
	mov si, CHECKBOX_SQUARE_SIZE	; height
	
	test word [cs:di+10], CHECKBOX_FLAG_ENABLED	; determine rectangle colour
	jz gui_checkboxes_render_released_rectangle_disabled
gui_checkboxes_render_released_rectangle_enabled:
	mov dl, byte [cs:guiColour0]
	jmp gui_checkboxes_render_released_rectangle_draw
gui_checkboxes_render_released_rectangle_disabled:
	mov dl, byte [cs:guiColour3]
	jmp gui_checkboxes_render_released_rectangle_draw
gui_checkboxes_render_released_rectangle_draw:
	call common_graphics_draw_rectangle_outline_by_coords
	
	mov si, di						; use SI to index again
	; draw box depth
	mov bx, word [cs:si+2]			; X
	inc bx
	
	mov ax, word [cs:si+4]			; Y
	add ax, CHECKBOX_SQUARE_SIZE	; add height
	
	; we push the computed depth colour so we can re-use it later on
	test word [cs:si+10], CHECKBOX_FLAG_ENABLED	; determine label colour
	jz gui_checkboxes_render_released_depth_disabled
gui_checkboxes_render_released_depth_enabled:
	mov dl, byte [cs:guiColour2]
	push dx									; [1] (1st branch) - save colour
	jmp gui_checkboxes_render_released_depth_draw
gui_checkboxes_render_released_depth_disabled:
	mov dl, byte [cs:guiColour3]
	push dx									; [1] (2nd branch) - save colour
	jmp gui_checkboxes_render_released_depth_draw
gui_checkboxes_render_released_depth_draw:
	mov cx, CHECKBOX_SQUARE_SIZE	; width (equal to height)
	call common_graphics_draw_line_solid
	
	mov bx, word [cs:si+2]			; X
	add bx, CHECKBOX_SQUARE_SIZE	; add width (equal to height)
	mov ax, word [cs:si+4]			; Y
	inc ax
	pop dx									; [1] restore colour
	mov cx, CHECKBOX_SQUARE_SIZE	; height
	call common_graphics_draw_vertical_line_solid_by_coords
	
	; render the checkmark, if needed
	call gui_checkboxes_render_checkmark
	
	push si									; [2] save pointer to checkbox
	; render the checkbox's label
	test word [cs:si+10], CHECKBOX_FLAG_ENABLED	; determine label colour
	jz gui_checkboxes_render_released_label_disabled
gui_checkboxes_render_released_label_enabled:
	mov cl, byte [cs:guiColour0]
	jmp gui_checkboxes_render_released_label_draw
gui_checkboxes_render_released_label_disabled:
	mov cl, byte [cs:guiColour3]
	jmp gui_checkboxes_render_released_label_draw
gui_checkboxes_render_released_label_draw:
	mov bx, word [cs:si+2]			; X
	add bx, CHECKBOX_LABEL_PADDING_X
	mov ax, word [cs:si+4]			; Y
	push cs
	pop ds
	add si, 32						; DS:SI := pointer to checkbox label
	mov dx, word [cs:guiIsBoldFont]
	call common_graphics_text_print_at
	
	pop si									; [2] restore pointer to checkbox
	; render the "hover" mark when hovering over an enabled checkbox
	; NOTE: the mark is drawn on the top left corner, since it's the place
	;       least likely to be covered by the bulk of the mouse cursor
	mov ax, word [cs:si+10]
	and ax, CHECKBOX_FLAG_ENABLED | CHECKBOX_FLAG_HOVERED
	cmp ax, CHECKBOX_FLAG_ENABLED | CHECKBOX_FLAG_HOVERED
	jne gui_checkboxes_render_released_done
	; it's enabled and hovered, so draw the mark
	mov ax, word [cs:si+4]			; Y
	add ax, 2						; move inside rectangle
	mov bx, word [cs:si+2]			; X
	add bx, 2						; move inside rectangle
	mov cx, CHECKBOX_HOVER_MARK_SIZE_PIXELS		; line length
	mov dl, byte [cs:guiColour2]			; colour
	call common_graphics_draw_line_solid	; line to the right
	call common_graphics_draw_vertical_line_solid_by_coords	; line downward
	
gui_checkboxes_render_released_done:	
	popa
	ret
	

; Draws a checkbox on the screen
;
; input:
;		BX - ID (offset) of checkbox
; output:
;		none
gui_checkboxes_render:
	pusha
	push ds
	
	call gui_checkboxes_erase			; first, erase checkbox
	
	add bx, guiCheckboxesStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to array element

	test word [cs:si+10], CHECKBOX_FLAG_PENDING_DELETE
	jnz gui_checkboxes_render_finish	; checkbox was deleted

	call gui_checkboxes_render_released

gui_checkboxes_render_finish:
	; we're done drawing; now perform some housekeeping
	mov ax, word [cs:si+10]
	mov word [cs:si+12], ax			; old flags := flags

	; if it was pending deletion, we have erased from screen, so
	; we can clear that flag, as well
	mov ax, CHECKBOX_FLAG_MUST_RENDER | CHECKBOX_FLAG_PENDING_DELETE
	xor ax, 0FFFFh
	and word [cs:si+10], ax			; clear flags

	pop ds
	popa
	ret
	
	
; Measures the width in pixels of a checkbox which will have the 
; specified, single-line label string
;
; Input:
;	 DS:SI - pointer to zero-terminated string 
; Output:
;		CX - checkbox width
common_gui_checkbox_measure_single_line:
	push ax
	call common_graphics_text_measure_width	; AX := pixel width of string
	add ax, CHECKBOX_LABEL_PADDING_X ; string is offset this much from the left
	mov cx, ax
	pop ax
	ret


; Makes the specified checkbox disabled and no longer responding to
; interactions events
;
; input:
;		AX - checkbox handle
; output:
;		none
common_gui_checkbox_disable:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_disable_done
	
	mov ax, CHECKBOX_FLAG_ENABLED | CHECKBOX_FLAG_HOVERED
	xor ax, 0FFFFh
	and word [cs:guiCheckboxesStorage+bx+10], ax	; clear "enabled" flag
	or word [cs:guiCheckboxesStorage+bx+10], CHECKBOX_FLAG_MUST_RENDER
					; we must re-render
	mov byte [cs:guiCheckboxesNeedRender], 1	
					; mark checkboxes component for render
common_gui_checkbox_disable_done:
	popa
	ret


; Gets the checked state of the specified checkbox
;
; input:
;		AX - checkbox handle
; output:
;		BX - checked state: 0 for unchecked, other value for checked
common_gui_checkbox_get_checked:
	push ax
	
	mov bx, ax
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_get_checked_done
	
	mov ax, word [cs:guiCheckboxesStorage+bx+10]
	and ax, CHECKBOX_FLAG_CHECKED
	mov bx, ax				; BX := 0 when unchecked, other value otherwise
common_gui_checkbox_get_checked_done:
	pop ax
	ret
	

; Sets the checked state of the specified checkbox
;
; input:
;		AX - checkbox handle
;		BX - checked state: 0 for unchecked, other value for checked
; output:
;		none
common_gui_checkbox_set_checked:
	pusha

	cmp bx, 0
	je common_gui_checkbox_set_checked_clear
	; set checked
	mov bx, ax
	
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_set_checked_done
	
	or word [cs:guiCheckboxesStorage+bx+10], CHECKBOX_FLAG_CHECKED
	jmp common_gui_checkbox_set_checked_finish
common_gui_checkbox_set_checked_clear:
	mov bx, ax
	
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_set_checked_done
	
	mov cx, CHECKBOX_FLAG_CHECKED
	xor cx, 0FFFFh
	and word [cs:guiCheckboxesStorage+bx+10], cx		; clear flag
common_gui_checkbox_set_checked_finish:
	or word [cs:guiCheckboxesStorage+bx+10], CHECKBOX_FLAG_MUST_RENDER
											; schedule for render
	mov byte [cs:guiCheckboxesNeedRender], 1	
					; mark checkboxes component for render
	
	; raise event
	mov si, bx
	add si, guiCheckboxesStorage			; CS:SI := pointer to checkbox
	call gui_checkboxes_raise_checked_set_event
	
common_gui_checkbox_set_checked_done:
	popa
	ret
	
	
; Enables the specified checkbox
;
; input:
;		AX - checkbox handle
; output:
;		none
common_gui_checkbox_enable:
	pusha
	
	mov bx, ax
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_enable_done
	
	test word [cs:guiCheckboxesStorage+bx+10], CHECKBOX_FLAG_PENDING_DELETE
	jnz common_gui_checkbox_enable_done	
					; cannot enable a checkbox being deleted
	
	or word [cs:guiCheckboxesStorage+bx+10], CHECKBOX_FLAG_ENABLED | CHECKBOX_FLAG_MUST_RENDER
					; set flags
	mov byte [cs:guiCheckboxesNeedRender], 1
							; mark checkboxes component for render
common_gui_checkbox_enable_done:
	popa
	ret
	
	
; Deletes the specified checkbox entirely, removing it from screen 
; and freeing up its memory
;
; input:
;		AX - checkbox handle
; output:
;		none
common_gui_checkbox_delete:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_delete_done
	
	mov word [cs:guiCheckboxesStorage+bx+0], CHECKBOX_NONE
									; free checkbox entry
	mov word [cs:guiCheckboxesStorage+bx+10], CHECKBOX_FLAG_PENDING_DELETE | CHECKBOX_FLAG_MUST_RENDER
					; clear all flags except these ones
					; note, the checkbox is also flagged as disabled, so
					; it cannot be interacted with
	mov byte [cs:guiCheckboxesNeedRender], 1
					; mark checkboxes component for render
common_gui_checkbox_delete_done:
	popa
	ret
	

; Clears all storage checkbox entries
;
; input:
;		none
; output:
;		none
gui_checkboxes_clear_storage:
	pusha

	mov si, guiCheckboxesStorage
	mov bx, 0				; offset of array slot being checked
gui_checkboxes_clear_storage_loop:
	mov word [cs:si+bx], CHECKBOX_NONE	; mark slot as available
	mov word [cs:si+bx+10], 0			; clear flags
gui_checkboxes_clear_storage_next:
	add bx, CHECKBOXES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, CHECKBOXES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_checkboxes_clear_storage_loop			; no
gui_checkboxes_clear_storage_done:
	popa
	ret
	

; Adds a checkbox whose size is auto scaled to fit the checkbox's label.
; Assumes label only takes up a single line
;
; input:
;		AX - position X
;		BX - position Y
;	 DS:SI - pointer to zero-terminated label string
; output:
;		AX - checkbox handle
common_gui_checkbox_add_auto_scaled:
	call common_gui_checkbox_measure_single_line		; CX := width
	mov dx, COMMON_GUI_CHECKBOX_HEIGHT_SINGLE_LINE	; height
	call common_gui_checkbox_add		; AX := checkbox handle
	ret
	
	
; Adds a checkbox
;
; input:
;		AX - position X
;		BX - position Y
;		CX - width
;		DX - height
;	 DS:SI - pointer to zero-terminated label string
; output:
;		AX - checkbox handle
common_gui_checkbox_add:
	push bx
	push cx
	push dx
	push si
	push ds
	push es
	
	push bx							; [1] save input
	
	call gui_checkboxes_find_empty_slot	; BX := offset
										; CARRY=0 when slot was found
	jc common_gui_checkbox_add_full
	; we found a slot, so add the checkbox
	
	push bx							; [3] save checkbox offset
	add bx, guiCheckboxesStorage		; BX := pointer to checkbox

	mov word [cs:bx+0], 0			; id
	mov word [cs:bx+6], cx			; width
	mov word [cs:bx+8], dx			; height
	
	; until the consumer its own callback, set a NOOP callback
	mov word [cs:bx+14], cs
	mov word [cs:bx+16], gui_noop_callback
	
	push dx							; [2] save input
	mov dx, CHECKBOX_FLAG_ENABLED | CHECKBOX_FLAG_MUST_RENDER
	mov word [cs:bx+10], dx			; flags
	mov word [cs:bx+12], dx			; old flags
	pop dx							; [2] restore input
	
	mov word [cs:bx+2], ax			; position X
	
	; copy label from DS:SI into the checkbox's label buffer
	pushf
	push cs
	pop es
	mov di, bx						; ES:DI := pointer to array element
	add di, 32						; ES:DI := pointer to label
	mov cx, CHECKBOXES_LABEL_LENGTH
	cld
	rep movsb						; copy as many bytes as maximum label
	dec di							; ES:DI := pointer to last byte of label
	mov byte [es:di], 0				; add terminator, in case passed-in label
									; was too long
	popf

	pop ax							; [3] AX := checkbox offset
	
	mov si, bx						; SI := pointer to array element
	pop bx							; [1] restore input
	mov word [cs:si+4], bx			; position Y
	
	mov byte [cs:guiCheckboxesNeedRender], 1 ; indicate some checkboxes changed
	jmp common_gui_checkbox_add_done	; we're done
	
common_gui_checkbox_add_full:
	pop bx							; remove extra value on stack
common_gui_checkbox_add_done:
	pop es
	pop ds
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
gui_checkboxes_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, guiCheckboxesStorage
	mov bx, 0				; offset of array slot being checked
gui_checkboxes_find_empty_slot_loop:
	test word [cs:si+bx+10], CHECKBOX_FLAG_PENDING_DELETE
	jnz gui_checkboxes_find_empty_slot_loop_next
							; skip slot if it's pending delete
	
	cmp word [cs:si+bx], CHECKBOX_NONE			; is this slot empty?
										; (are first two bytes CHECKBOX_NONE?)
	je gui_checkboxes_find_empty_slot_done	; yes

gui_checkboxes_find_empty_slot_loop_next:
	add bx, CHECKBOXES_ENTRY_SIZE_BYTES		; next slot
	cmp bx, CHECKBOXES_TOTAL_SIZE_BYTES		; are we past the end?
	jb gui_checkboxes_find_empty_slot_loop		; no
gui_checkboxes_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp gui_checkboxes_find_empty_slot_done
gui_checkboxes_find_empty_slot_done:
	pop si
	ret

	
; Iterates through all checkboxes, rendering those which need it
;
; input:
;		none
; output:
;		none
gui_checkboxes_render_all:
	mov byte [cs:guiCheckboxesRenderMode], GUI_CHECKBOXES_RENDER_MODE_DELETIONS
	call private_gui_checkboxes_render_all
	mov byte [cs:guiCheckboxesRenderMode], GUI_CHECKBOXES_RENDER_MODE_MODIFICATIONS
	call private_gui_checkboxes_render_all
	ret
	
	
; Iterates through those checkboxes to which the current rendering 
; mode pertains, rendering those which need it.
;
; input:
;		none
; output:
;		none
private_gui_checkboxes_render_all:
	pusha

	mov si, guiCheckboxesStorage
	mov bx, 0				; offset of array slot being checked
gui_checkboxes_render_all_loop:
	cmp byte [cs:guiCheckboxesRenderMode], GUI_CHECKBOXES_RENDER_MODE_MODIFICATIONS
	je gui_checkboxes_render_all_loop_after_deleted_handling
				; we're only rendering modifications, so skip over the handling
				; of deleted ones
	test word [cs:si+bx+10], CHECKBOX_FLAG_PENDING_DELETE
	jnz gui_checkboxes_render_all_perform	; if it's pending delete, we have to
										; render it
										
	cmp byte [cs:guiCheckboxesRenderMode], GUI_CHECKBOXES_RENDER_MODE_DELETIONS
	je gui_checkboxes_render_all_next		; we're only rendering deletions, so
										; go to next
gui_checkboxes_render_all_loop_after_deleted_handling:
	cmp word [cs:si+bx], CHECKBOX_NONE	; is this slot empty?
										; (are first two bytes CHECKBOX_NONE?)
	je gui_checkboxes_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_checkboxes_render_all_perform:	
	test word [cs:si+bx+10], CHECKBOX_FLAG_MUST_RENDER
	jz gui_checkboxes_render_all_next		; we don't have to redraw this one
	call gui_checkboxes_render				; perform
gui_checkboxes_render_all_next:
	add bx, CHECKBOXES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, CHECKBOXES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_checkboxes_render_all_loop			; no
gui_checkboxes_render_all_done:
	mov byte [cs:guiCheckboxesNeedRender], 0	; mark rendering complete
	popa
	ret
	

; Returns whether some checkboxes need to be rendered
;
; input:
;		none
; output:
;		AL - 0 when checkboxes don't need rendering, other value otherwise
gui_checkboxes_get_need_render:
	mov al, byte [cs:guiCheckboxesNeedRender]
	ret


; Invokes the callback of the specified checkbox
;
; input:
;		BX - ID (offset) of checkbox
; output:
;		none
gui_checkboxes_invoke_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word gui_checkboxes_invoke_callback_return	; return address on stack
	
	; setup "call far" address
	push word [cs:guiCheckboxesStorage+bx+14]			; callback segment
	push word [cs:guiCheckboxesStorage+bx+16]			; callback offset
	
	; setup callback arguments
	mov ax, bx						; AX := checkbox handle
	mov cx, word [cs:guiCheckboxesStorage+bx+10]
	and cx, CHECKBOX_FLAG_CHECKED
	mov bx, cx						; BX := 0 when not checked
	
	retf							; "call far"
	; once the callback executes its own retf, execution returns below
gui_checkboxes_invoke_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret


; Sets the specified checkbox's change callback, which is invoked whenever the
; checkbox is changed
;
; input:
;		AX - checkbox handle
;	 DS:SI - pointer to callback function
; output:
;		none	
common_gui_checkbox_change_callback_set:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_change_callback_set_done
	
	mov word [cs:guiCheckboxesStorage+bx+14], ds		; callback segment
	mov word [cs:guiCheckboxesStorage+bx+16], si		; callback offset
common_gui_checkbox_change_callback_set_done:
	popa
	ret
	
	
; Clears the specified checkbox's change callback
;
; input:
;		AX - checkbox handle
; output:
;		none	
common_gui_checkbox_change_callback_clear:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiCheckboxesStorage+bx], CHECKBOX_NONE
	je common_gui_checkbox_change_callback_clear_done
	
	mov word [cs:guiCheckboxesStorage+bx+14], cs		; callback segment
	mov word [cs:guiCheckboxesStorage+bx+16], gui_noop_callback
								; NOOP callback offset
common_gui_checkbox_change_callback_clear_done:
	popa
	ret
	
	
; Considers the newly-dequeued event, and modifies checkbox state
; for any affected checkboxes.
;
; input:
;		none
; output:
;		none
gui_checkboxes_handle_event:
	pusha
	
	call gui_checkboxes_is_event_applicable
	cmp ax, 0
	je gui_checkboxes_handle_event_done		; event is not applicable
	; event is applicable (it may modify checkbox state)

	; some event types can be handled without iterating through all checkboxes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_CHECKBOX_INVOKE_CALLBACK
	je gui_checkboxes_handle_event_invoke_callback
	
	jmp gui_checkboxes_handle_event_iterate	; the event is "per-checkbox", so
											; start iterating
gui_checkboxes_handle_event_invoke_callback:
	mov bx, word [cs:dequeueEventBytesBuffer+1]		; checkbox offset
	call gui_checkboxes_invoke_callback
	jmp gui_checkboxes_handle_event_done

	; iterate through each checkbox
gui_checkboxes_handle_event_iterate:
	mov si, guiCheckboxesStorage
	mov bx, 0				; offset of array slot being checked
gui_checkboxes_handle_event_loop:
	test word [cs:si+bx+10], CHECKBOX_FLAG_PENDING_DELETE
	jnz gui_checkboxes_handle_event_next	; don't apply events if deleted
	
	cmp word [cs:si+bx], CHECKBOX_NONE	; is this slot empty?
										; (are first two bytes CHECKBOX_NONE?)
	je gui_checkboxes_handle_event_next	; yes
	; this array element is not empty, so perform action on it	
	call gui_checkboxes_apply_event
gui_checkboxes_handle_event_next:
	add bx, CHECKBOXES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, CHECKBOXES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_checkboxes_handle_event_loop			; no
gui_checkboxes_handle_event_done:
	popa
	ret

	
; Raises a "checked set" event
;
; input:
;		CS:SI - pointer to checkbox
; output:
;		none
gui_checkboxes_raise_checked_set_event:
	pusha
	
	mov al, GUI_EVENT_CHECKBOX_INVOKE_CALLBACK
	mov bx, si
	sub bx, guiCheckboxesStorage	; BX := checkbox offset
	call gui_event_enqueue_3bytes_atomic
	
	popa
	ret
	

; Applies the lastly-dequeued event to the specified checkbox
;
; input:
;		BX - ID (offset) of checkbox
; output:
;		none
gui_checkboxes_apply_event:
	pusha
	
	add bx, guiCheckboxesStorage	; convert offset to pointer
	mov si, bx						; SI := pointer to checkbox
	
	test word [cs:si+10], CHECKBOX_FLAG_ENABLED
	jz gui_checkboxes_apply_event_done	; we're done if checkbox is not enabled

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
	mov di, word [cs:si+6]							; checkbox width
	push word [cs:si+8]
	pop gs											; checkbox height
	push word [cs:si+4]
	pop fs											; checkbox Y
	push word [cs:si+2]
	pop si											; checkbox X
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
	je gui_checkboxes_apply_event_mouse_left_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_checkboxes_apply_event_mouse_left_up
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_checkboxes_apply_event_mouse_right_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_checkboxes_apply_event_mouse_right_up
	cmp bl, GUI_EVENT_MOUSE_MOVE
	je gui_checkboxes_apply_event_mouse_move
	jmp gui_checkboxes_apply_event_done

	; if we got here,
	; - checkbox is enabled
	; - AL = 0 when mouse cursor doesn't overlap checkbox
gui_checkboxes_apply_event_mouse_left_up:
	cmp al, 0
	je gui_checkboxes_apply_event_done		; releasing is NOOP when no overlap
	test word [cs:si+10], CHECKBOX_FLAG_HELD_DOWN
	jz gui_checkboxes_apply_event_done		; checkbox was not held down
	; there's overlap and checkbox was held down
	
	; checkbox is becoming released now
	mov dx, CHECKBOX_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	
	xor word [cs:si+10], CHECKBOX_FLAG_CHECKED		; toggle "checked" flag
	or word [cs:si+10], CHECKBOX_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiCheckboxesNeedRender], 1
									; mark checkboxes component for render
	; raise event to invoke callback
	call gui_checkboxes_raise_checked_set_event
	jmp gui_checkboxes_apply_event_done

gui_checkboxes_apply_event_mouse_right_up:
	; NOOP - checkboxes don't respond to right click events
	jmp gui_checkboxes_apply_event_done

gui_checkboxes_apply_event_mouse_left_down:
	cmp al, 0
	je gui_checkboxes_apply_event_done	; clicking does nothing when no overlap
	; there is overlap
	or word [cs:si+10], CHECKBOX_FLAG_HELD_DOWN	; set flag
	jmp gui_checkboxes_apply_event_done

gui_checkboxes_apply_event_mouse_right_down:
	; NOOP - checkboxes don't respond to right click events
	jmp gui_checkboxes_apply_event_done

gui_checkboxes_apply_event_mouse_move:
	cmp al, 0
	je gui_checkboxes_apply_event_mouse_move_nonoverlapping
gui_checkboxes_apply_event_mouse_move_overlapping:
	; the mouse has moved within the checkbox
	test word [cs:si+10], CHECKBOX_FLAG_HOVERED
	jnz gui_checkboxes_apply_event_done	; already hovered
	; checkbox is becoming hovered now
	or word [cs:si+10], CHECKBOX_FLAG_HOVERED | CHECKBOX_FLAG_MUST_RENDER
								; mark checkbox as hovered and needing render
	mov byte [cs:guiCheckboxesNeedRender], 1
								; mark checkboxes component for render
	jmp gui_checkboxes_apply_event_done

gui_checkboxes_apply_event_mouse_move_nonoverlapping:
	; the mouse has moved outside of the checkbox
	test word [cs:si+10], CHECKBOX_FLAG_HOVERED
	jz gui_checkboxes_apply_event_done
					; already not hovered; now check if we need to release it
	; checkbox is becoming non-hovered now
	mov dx, CHECKBOX_FLAG_HOVERED
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "hovered" flag
	or word [cs:si+10], CHECKBOX_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiCheckboxesNeedRender], 1
								; mark checkboxes component for render
gui_checkboxes_apply_event_mouse_move_nonoverlapping_release:
	; check if checkbox should become released
	test word [cs:si+10], CHECKBOX_FLAG_HELD_DOWN
	jz gui_checkboxes_apply_event_done			; don't need to release
	; checkbox is becoming released now
	mov dx, CHECKBOX_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	jmp gui_checkboxes_apply_event_done

gui_checkboxes_apply_event_done:
	popa
	ret
	
	
; Marks all components as needing render
;
; input:
;		none
; output:
;		none
gui_checkboxes_schedule_render_all:
	pusha

	mov si, guiCheckboxesStorage
	mov bx, 0				; offset of array slot being checked
gui_checkboxes_schedule_render_all_loop:
	cmp word [cs:si+bx], CHECKBOX_NONE	; is this slot empty?
										; (are first two bytes CHECKBOX_NONE?)
	je gui_checkboxes_schedule_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_checkboxes_schedule_render_all_perform:	
	or word [cs:si+bx+10], CHECKBOX_FLAG_MUST_RENDER
gui_checkboxes_schedule_render_all_next:
	add bx, CHECKBOXES_ENTRY_SIZE_BYTES	; next slot
	cmp bx, CHECKBOXES_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_checkboxes_schedule_render_all_loop			; no
gui_checkboxes_schedule_render_all_done:
	mov byte [cs:guiCheckboxesNeedRender], 1	; mark entire component for render
	popa
	ret
	
	
; Checks whether the lastly-dequeued event is applicable to checkboxes
;
; input:
;		none
; output:
;		AX - 0 when event is irrelevant, other value if it should be handled
gui_checkboxes_is_event_applicable:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je gui_checkboxes_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_checkboxes_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_checkboxes_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_checkboxes_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSE_MOVE
	je gui_checkboxes_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_CHECKBOX_INVOKE_CALLBACK
	je gui_checkboxes_is_event_applicable_yes
gui_checkboxes_is_event_applicable_no:	
	mov ax, 0
	ret
gui_checkboxes_is_event_applicable_yes:
	mov ax, 1
	ret

	
%endif
