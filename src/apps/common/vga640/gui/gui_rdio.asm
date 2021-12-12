;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains logic for dealing with GUI radio buttons.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_RADIO_
%define _COMMON_GUI_RADIO_

RADIO_NONE 				equ 0FFFFh ; word value which marks a slot as empty

RADIO_ENTRY_SIZE_BYTES	equ 64
RADIO_TOTAL_SIZE_BYTES equ (GUI_RADIO_LIMIT+GUI_RESERVED_COMPONENT_COUNT)*RADIO_ENTRY_SIZE_BYTES ; in bytes

RADIO_FLAG_ENABLED			equ 1	; radio is clickable
RADIO_FLAG_HOVERED			equ 2	; radio is hovered over by the mouse
RADIO_FLAG_MUST_RENDER		equ 4	; radio must be redrawn
RADIO_FLAG_CHECKED			equ 8	; radio is checked
RADIO_FLAG_PENDING_DELETE	equ 16	; radio is pending deletion
RADIO_FLAG_HELD_DOWN		equ 32	; radio is being held down via a click

RADIO_LABEL_LENGTH		equ 32

RADIO_SQUARE_SIZE		equ COMMON_GRAPHICS_FONT_WIDTH	; size of the box

RADIO_LABEL_PADDING_X	equ RADIO_SQUARE_SIZE + RADIO_DEPTH
				; in pixels, from the overall X position
RADIO_DEPTH				equ 1	; in pixels

RADIO_HOVER_MARK_SIZE_PIXELS		equ 2

COMMON_GUI_RADIO_HEIGHT_SINGLE_LINE equ COMMON_GRAPHICS_FONT_HEIGHT + RADIO_DEPTH
		; height of a radio containing a single line of text as the label

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
;   18-19 group id (used to group together multiple radio buttons)
;   20-31 unused
;   32-63 zero-terminated label string

; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
guiRadioStorage: times RADIO_TOTAL_SIZE_BYTES db 0

guiRadioNeedRender:	db 0
				; becomes non-zero when a change which requires
				; at least one radio to be redrawn took place

guiRadioRenderMode:	db	99
GUI_RADIO_RENDER_MODE_DELETIONS		equ 0
GUI_RADIO_RENDER_MODE_MODIFICATIONS	equ 1

; Prepares radio module before usage
;
; input:
;		none
; output:
;		none
gui_radio_prepare:
	pusha
	
	call gui_radio_clear_storage
	mov byte [cs:guiRadioNeedRender], 0
	
	popa
	ret


; Erases a radio from the screen
;
; input:
;		BX - ID (offset) of radio
; output:
;		none	
gui_radio_erase:
	pusha
	
	add bx, guiRadioStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to array element
	
	mov bx, word [cs:si+2]			; X
	mov ax, word [cs:si+4]			; Y
	
	; draw a rectangle that's the same colour as the background, and large
	; enough to cover not just the radio, but also its depth
	mov cx, word [cs:si+6]			; width
	mov di, word [cs:si+8]			; height
	mov dl, byte [cs:guiColour1]
	call common_graphics_draw_rectangle_solid
	
	popa
	ret
	

; Draws a checkmark (if needed), inside the specified radio
;
; input:
;		CS:SI - pointer to radio
; output:
;		none	
gui_radio_render_checkmark:
	pusha
	test word [cs:si+10], RADIO_FLAG_CHECKED
	jz gui_radio_render_checkmark_done
	
	test word [cs:si+10], RADIO_FLAG_ENABLED
	jz gui_radio_render_checkmark_disabled
	
gui_radio_render_checkmark_enabled:
	mov dl, byte [cs:guiColour0]
	jmp gui_radio_render_checkmark_perform
gui_radio_render_checkmark_disabled:
	mov dl, byte [cs:guiColour3]
	
gui_radio_render_checkmark_perform:
	; render it
	mov bx, word [cs:si+2]			; X
	add bx, 3
	mov ax, word [cs:si+4]			; Y
	add ax, 3
	mov di, RADIO_SQUARE_SIZE - 6	; height
	mov cx, RADIO_SQUARE_SIZE - 6	; width
	call common_graphics_draw_rectangle_solid
	
gui_radio_render_checkmark_done:
	popa
	ret
	

; Draws a radio in its released (default) state
;
; input:
;		CS:SI - pointer to radio
; output:
;		none
gui_radio_render_released:
	pusha

	; draw rectangle
	mov di, si						; use DI to index for now
	
	mov bx, word [cs:di+2]			; X
	mov ax, word [cs:di+4]			; Y
	mov cx, RADIO_SQUARE_SIZE	; width
	mov si, RADIO_SQUARE_SIZE	; height
	
	test word [cs:di+10], RADIO_FLAG_ENABLED	; determine rectangle colour
	jz gui_radio_render_released_rectangle_disabled
gui_radio_render_released_rectangle_enabled:
	mov dl, byte [cs:guiColour0]
	jmp gui_radio_render_released_rectangle_draw
gui_radio_render_released_rectangle_disabled:
	mov dl, byte [cs:guiColour3]
	jmp gui_radio_render_released_rectangle_draw
gui_radio_render_released_rectangle_draw:
	call common_graphics_draw_rectangle_outline_by_coords
	
	mov dl, byte [cs:guiColour1]
	call common_graphics_draw_pixel_by_coords	; "cut out" top left corner
	add bx, RADIO_SQUARE_SIZE
	dec bx
	call common_graphics_draw_pixel_by_coords	; "cut out" top right corner
	add ax, RADIO_SQUARE_SIZE
	dec ax
	sub bx, RADIO_SQUARE_SIZE
	inc bx
	call common_graphics_draw_pixel_by_coords	; "cut out" bottom left corner
	
	mov si, di						; use SI to index again
	; draw box depth
	mov bx, word [cs:si+2]			; X
	add bx, 2
	
	mov ax, word [cs:si+4]			; Y
	add ax, RADIO_SQUARE_SIZE	; add height
	
	; we push the computed depth colour so we can re-use it later on
	test word [cs:si+10], RADIO_FLAG_ENABLED	; determine label colour
	jz gui_radio_render_released_depth_disabled
gui_radio_render_released_depth_enabled:
	mov dl, byte [cs:guiColour2]
	jmp gui_radio_render_released_depth_draw
gui_radio_render_released_depth_disabled:
	mov dl, byte [cs:guiColour3]
	jmp gui_radio_render_released_depth_draw
gui_radio_render_released_depth_draw:
	mov cx, RADIO_SQUARE_SIZE	; width (equal to height)
	sub cx, 2
	call common_graphics_draw_line_solid
	
	mov bx, word [cs:si+2]			; X
	add bx, RADIO_SQUARE_SIZE	; add width (equal to height)
	mov ax, word [cs:si+4]			; Y
	add ax, 2
	mov cx, RADIO_SQUARE_SIZE	; height
	sub cx, 2
	call common_graphics_draw_vertical_line_solid_by_coords
	
	; depth in bottom-right corner
	mov dx, bx								; DL := colour
	mov bx, word [cs:si+2]			; X
	mov ax, word [cs:si+4]			; Y
	add bx, RADIO_SQUARE_SIZE
	dec bx
	add ax, RADIO_SQUARE_SIZE
	dec ax
	call common_graphics_draw_pixel_by_coords
	
	; render the checkmark, if needed
	call gui_radio_render_checkmark
	
	push si									; [2] save pointer to radio
	; render the radio's label
	test word [cs:si+10], RADIO_FLAG_ENABLED	; determine label colour
	jz gui_radio_render_released_label_disabled
gui_radio_render_released_label_enabled:
	mov cl, byte [cs:guiColour0]
	jmp gui_radio_render_released_label_draw
gui_radio_render_released_label_disabled:
	mov cl, byte [cs:guiColour3]
	jmp gui_radio_render_released_label_draw
gui_radio_render_released_label_draw:
	mov bx, word [cs:si+2]			; X
	add bx, RADIO_LABEL_PADDING_X
	mov ax, word [cs:si+4]			; Y
	push cs
	pop ds
	add si, 32						; DS:SI := pointer to radio label
	mov dx, word [cs:guiIsBoldFont]
	call common_graphics_text_print_at
	
	pop si									; [2] restore pointer to radio
	; render the "hover" mark when hovering over an enabled radio
	; NOTE: the mark is drawn on the top left corner, since it's the place
	;       least likely to be covered by the bulk of the mouse cursor
	mov ax, word [cs:si+10]
	and ax, RADIO_FLAG_ENABLED | RADIO_FLAG_HOVERED
	cmp ax, RADIO_FLAG_ENABLED | RADIO_FLAG_HOVERED
	jne gui_radio_render_released_done
	; it's enabled and hovered, so draw the mark
	mov ax, word [cs:si+4]			; Y
	add ax, 2						; move inside rectangle
	mov bx, word [cs:si+2]			; X
	add bx, 2						; move inside rectangle
	mov cx, RADIO_HOVER_MARK_SIZE_PIXELS		; line length
	mov dl, byte [cs:guiColour2]			; colour
	call common_graphics_draw_line_solid	; line to the right
	call common_graphics_draw_vertical_line_solid_by_coords	; line downward
	
gui_radio_render_released_done:	
	popa
	ret
	

; Draws a radio on the screen
;
; input:
;		BX - ID (offset) of radio
; output:
;		none
gui_radio_render:
	pusha
	push ds
	
	call gui_radio_erase			; first, erase radio
	
	add bx, guiRadioStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to array element

	test word [cs:si+10], RADIO_FLAG_PENDING_DELETE
	jnz gui_radio_render_finish	; radio was deleted

	call gui_radio_render_released

gui_radio_render_finish:
	; we're done drawing; now perform some housekeeping
	mov ax, word [cs:si+10]
	mov word [cs:si+12], ax			; old flags := flags

	; if it was pending deletion, we have erased from screen, so
	; we can clear that flag, as well
	mov ax, RADIO_FLAG_MUST_RENDER | RADIO_FLAG_PENDING_DELETE
	xor ax, 0FFFFh
	and word [cs:si+10], ax			; clear flags

	pop ds
	popa
	ret
	
	
; Measures the width in pixels of a radio which will have the 
; specified, single-line label string
;
; Input:
;	 DS:SI - pointer to zero-terminated string 
; Output:
;		CX - radio width
common_gui_radio_measure_single_line:
	push ax
	call common_graphics_text_measure_width	; AX := pixel width of string
	add ax, RADIO_LABEL_PADDING_X ; string is offset this much from the left
	mov cx, ax
	pop ax
	ret


; Makes the specified radio disabled and no longer responding to
; interactions events
;
; input:
;		AX - radio handle
; output:
;		none
common_gui_radio_disable:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_disable_done
	
	mov ax, RADIO_FLAG_ENABLED | RADIO_FLAG_HOVERED
	xor ax, 0FFFFh
	and word [cs:guiRadioStorage+bx+10], ax	; clear "enabled" flag
	or word [cs:guiRadioStorage+bx+10], RADIO_FLAG_MUST_RENDER
					; we must re-render
	mov byte [cs:guiRadioNeedRender], 1	
					; mark radio component for render
common_gui_radio_disable_done:
	popa
	ret


; Gets the checked state of the specified radio
;
; input:
;		AX - radio handle
; output:
;		BX - checked state: 0 for unchecked, other value for checked
common_gui_radio_get_checked:
	push ax
	
	mov bx, ax
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_get_checked_done
	
	mov ax, word [cs:guiRadioStorage+bx+10]
	and ax, RADIO_FLAG_CHECKED
	mov bx, ax				; BX := 0 when unchecked, other value otherwise
common_gui_radio_get_checked_done:
	pop ax
	ret
	

; Sets the checked state of the specified radio
;
; input:
;		AX - radio handle
;		BX - checked state: 0 for unchecked, other value for checked
; output:
;		none
common_gui_radio_set_checked:
	pusha

	cmp bx, 0
	je common_gui_radio_set_checked_clear
	; set checked
	mov bx, ax
	
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_set_checked_done
	
	; it's becoming checked
	or word [cs:guiRadioStorage+bx+10], RADIO_FLAG_CHECKED

	; uncheck all other radios in the same group
	mov di, guiRadioStorage
	add di, bx							; CS:DI := pointer to this button
	call gui_radio_uncheck_all_except
	
	jmp common_gui_radio_set_checked_finish
common_gui_radio_set_checked_clear:
	mov bx, ax
	
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_set_checked_done
	
	mov cx, RADIO_FLAG_CHECKED
	xor cx, 0FFFFh
	and word [cs:guiRadioStorage+bx+10], cx		; clear flag
common_gui_radio_set_checked_finish:
	or word [cs:guiRadioStorage+bx+10], RADIO_FLAG_MUST_RENDER
											; schedule for render
	mov byte [cs:guiRadioNeedRender], 1	
					; mark radio component for render
	
	; raise event
	mov si, bx
	add si, guiRadioStorage			; CS:SI := pointer to radio
	call gui_radio_raise_checked_set_event
	
common_gui_radio_set_checked_done:
	popa
	ret
	
	
; Enables the specified radio
;
; input:
;		AX - radio handle
; output:
;		none
common_gui_radio_enable:
	pusha
	
	mov bx, ax
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_enable_done
	
	test word [cs:guiRadioStorage+bx+10], RADIO_FLAG_PENDING_DELETE
	jnz common_gui_radio_enable_done	
					; cannot enable a radio being deleted
	
	or word [cs:guiRadioStorage+bx+10], RADIO_FLAG_ENABLED | RADIO_FLAG_MUST_RENDER
					; set flags
	mov byte [cs:guiRadioNeedRender], 1
							; mark radio component for render
common_gui_radio_enable_done:
	popa
	ret
	
	
; Deletes the specified radio entirely, removing it from screen 
; and freeing up its memory
;
; input:
;		AX - radio handle
; output:
;		none
common_gui_radio_delete:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_delete_done
	
	mov word [cs:guiRadioStorage+bx+0], RADIO_NONE
									; free radio entry
	mov word [cs:guiRadioStorage+bx+10], RADIO_FLAG_PENDING_DELETE | RADIO_FLAG_MUST_RENDER
					; clear all flags except these ones
					; note, the radio is also flagged as disabled, so
					; it cannot be interacted with
	mov byte [cs:guiRadioNeedRender], 1
					; mark radio component for render
common_gui_radio_delete_done:
	popa
	ret
	

; Clears all storage radio entries
;
; input:
;		none
; output:
;		none
gui_radio_clear_storage:
	pusha

	mov si, guiRadioStorage
	mov bx, 0				; offset of array slot being checked
gui_radio_clear_storage_loop:
	mov word [cs:si+bx], RADIO_NONE	; mark slot as available
	mov word [cs:si+bx+10], 0			; clear flags
gui_radio_clear_storage_next:
	add bx, RADIO_ENTRY_SIZE_BYTES	; next slot
	cmp bx, RADIO_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_radio_clear_storage_loop			; no
gui_radio_clear_storage_done:
	popa
	ret
	

; Adds a radio whose size is auto scaled to fit the radio's label.
; Assumes label only takes up a single line
;
; input:
;		AX - position X
;		BX - position Y
;		DI - group id (used to group together multiple radio buttons)
;	 DS:SI - pointer to zero-terminated label string
; output:
;		AX - radio handle
common_gui_radio_add_auto_scaled:
	call common_gui_radio_measure_single_line		; CX := width
	mov dx, COMMON_GUI_RADIO_HEIGHT_SINGLE_LINE	; height
	call common_gui_radio_add		; AX := radio handle
	ret
	
	
; Adds a radio
;
; input:
;		AX - position X
;		BX - position Y
;		CX - width
;		DX - height
;		DI - group id (used to group together multiple radio buttons)
;	 DS:SI - pointer to zero-terminated label string
; output:
;		AX - radio handle
common_gui_radio_add:
	push di
	push bx
	push cx
	push dx
	push si
	push ds
	push es
	
	push bx							; [1] save input
	
	call gui_radio_find_empty_slot	; BX := offset
										; CARRY=0 when slot was found
	jc common_gui_radio_add_full
	; we found a slot, so add the radio
	
	push bx							; [3] save radio offset
	add bx, guiRadioStorage			; BX := pointer to radio

	mov word [cs:bx+0], 0			; id
	mov word [cs:bx+6], cx			; width
	mov word [cs:bx+8], dx			; height
	
	; until the consumer its own callback, set a NOOP callback
	mov word [cs:bx+14], cs
	mov word [cs:bx+16], gui_noop_callback
	
	mov word [cs:bx+18], di			; store group id
	
	push dx							; [2] save input
	mov dx, RADIO_FLAG_ENABLED | RADIO_FLAG_MUST_RENDER
	mov word [cs:bx+10], dx			; flags
	mov word [cs:bx+12], dx			; old flags
	pop dx							; [2] restore input
	
	mov word [cs:bx+2], ax			; position X
	
	; copy label from DS:SI into the radio's label buffer
	pushf
	push cs
	pop es
	mov di, bx						; ES:DI := pointer to array element
	add di, 32						; ES:DI := pointer to label
	mov cx, RADIO_LABEL_LENGTH
	cld
	rep movsb						; copy as many bytes as maximum label
	dec di							; ES:DI := pointer to last byte of label
	mov byte [es:di], 0				; add terminator, in case passed-in label
									; was too long
	popf

	pop ax							; [3] AX := radio offset
	
	mov si, bx						; SI := pointer to array element
	pop bx							; [1] restore input
	mov word [cs:si+4], bx			; position Y
	
	mov byte [cs:guiRadioNeedRender], 1 ; indicate some radio changed
	jmp common_gui_radio_add_done	; we're done

common_gui_radio_add_full:
	pop bx							; remove extra value on stack
common_gui_radio_add_done:
	pop es
	pop ds
	pop si
	pop dx
	pop cx
	pop bx
	pop di
	ret
	

; Returns a byte offset of first empty slot in the array
;
; input:
;		none
; output:
;	 CARRY - set when a slot was not found, clear otherwise
;		BX - byte offset (into array) of first empty slot, if one was found
gui_radio_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, guiRadioStorage
	mov bx, 0				; offset of array slot being checked
gui_radio_find_empty_slot_loop:
	test word [cs:si+bx+10], RADIO_FLAG_PENDING_DELETE
	jnz gui_radio_find_empty_slot_loop_next
							; skip slot if it's pending delete
	
	cmp word [cs:si+bx], RADIO_NONE			; is this slot empty?
										; (are first two bytes RADIO_NONE?)
	je gui_radio_find_empty_slot_done	; yes

gui_radio_find_empty_slot_loop_next:
	add bx, RADIO_ENTRY_SIZE_BYTES		; next slot
	cmp bx, RADIO_TOTAL_SIZE_BYTES		; are we past the end?
	jb gui_radio_find_empty_slot_loop		; no
gui_radio_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp gui_radio_find_empty_slot_done
gui_radio_find_empty_slot_done:
	pop si
	ret

	
; Iterates through all radios, rendering those which need it
;
; input:
;		none
; output:
;		none
gui_radio_render_all:
	mov byte [cs:guiRadioRenderMode], GUI_RADIO_RENDER_MODE_DELETIONS
	call private_gui_radio_render_all
	mov byte [cs:guiRadioRenderMode], GUI_RADIO_RENDER_MODE_MODIFICATIONS
	call private_gui_radio_render_all
	ret
	
	
; Iterates through those radios to which the current rendering 
; mode pertains, rendering those which need it.
;
; input:
;		none
; output:
;		none
private_gui_radio_render_all:
	pusha

	mov si, guiRadioStorage
	mov bx, 0				; offset of array slot being checked
gui_radio_render_all_loop:
	cmp byte [cs:guiRadioRenderMode], GUI_RADIO_RENDER_MODE_MODIFICATIONS
	je gui_radio_render_all_loop_after_deleted_handling
				; we're only rendering modifications, so skip over the handling
				; of deleted ones
	test word [cs:si+bx+10], RADIO_FLAG_PENDING_DELETE
	jnz gui_radio_render_all_perform	; if it's pending delete, we have to
										; render it
										
	cmp byte [cs:guiRadioRenderMode], GUI_RADIO_RENDER_MODE_DELETIONS
	je gui_radio_render_all_next		; we're only rendering deletions, so
										; go to next
gui_radio_render_all_loop_after_deleted_handling:
	cmp word [cs:si+bx], RADIO_NONE	; is this slot empty?
										; (are first two bytes RADIO_NONE?)
	je gui_radio_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_radio_render_all_perform:	
	test word [cs:si+bx+10], RADIO_FLAG_MUST_RENDER
	jz gui_radio_render_all_next		; we don't have to redraw this one
	call gui_radio_render				; perform
gui_radio_render_all_next:
	add bx, RADIO_ENTRY_SIZE_BYTES	; next slot
	cmp bx, RADIO_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_radio_render_all_loop			; no
gui_radio_render_all_done:
	mov byte [cs:guiRadioNeedRender], 0	; mark rendering complete
	popa
	ret
	

; Returns whether some radio need to be rendered	
;
; input:
;		none
; output:
;		AL - 0 when radio don't need rendering, other value otherwise
gui_radio_get_need_render:
	mov al, byte [cs:guiRadioNeedRender]
	ret


; Invokes the callback of the specified radio
;
; input:
;		BX - ID (offset) of radio
; output:
;		none
gui_radio_invoke_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word gui_radio_invoke_callback_return	; return address on stack
	
	; setup "call far" address
	push word [cs:guiRadioStorage+bx+14]			; callback segment
	push word [cs:guiRadioStorage+bx+16]			; callback offset
	
	; setup callback arguments
	mov ax, bx						; AX := radio handle
	mov cx, word [cs:guiRadioStorage+bx+10]
	and cx, RADIO_FLAG_CHECKED
	mov bx, cx						; BX := 0 when not checked
	
	retf							; "call far"
	; once the callback executes its own retf, execution returns below
gui_radio_invoke_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret


; Sets the specified radio's change callback, which is invoked whenever the
; radio is changed
;
; input:
;		AX - radio handle
;	 DS:SI - pointer to callback function
; output:
;		none	
common_gui_radio_change_callback_set:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_change_callback_set_done
	
	mov word [cs:guiRadioStorage+bx+14], ds		; callback segment
	mov word [cs:guiRadioStorage+bx+16], si		; callback offset
common_gui_radio_change_callback_set_done:
	popa
	ret
	
	
; Clears the specified radio's change callback
;
; input:
;		AX - radio handle
; output:
;		none	
common_gui_radio_change_callback_clear:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiRadioStorage+bx], RADIO_NONE
	je common_gui_radio_change_callback_clear_done
	
	mov word [cs:guiRadioStorage+bx+14], cs		; callback segment
	mov word [cs:guiRadioStorage+bx+16], gui_noop_callback
								; NOOP callback offset
common_gui_radio_change_callback_clear_done:
	popa
	ret
	
	
; Considers the newly-dequeued event, and modifies radio state
; for any affected radios.
;
; input:
;		none
; output:
;		none
gui_radio_handle_event:
	pusha
	
	call gui_radio_is_event_applicable
	cmp ax, 0
	je gui_radio_handle_event_done		; event is not applicable
	; event is applicable (it may modify radio state)

	; some event types can be handled without iterating through all radios
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_RADIO_INVOKE_CALLBACK
	je gui_radio_handle_event_invoke_callback
	
	jmp gui_radio_handle_event_iterate	; the event is "per-radio", so
											; start iterating
gui_radio_handle_event_invoke_callback:
	mov bx, word [cs:dequeueEventBytesBuffer+1]		; radio offset
	call gui_radio_invoke_callback
	jmp gui_radio_handle_event_done

	; iterate through each radio
gui_radio_handle_event_iterate:
	mov si, guiRadioStorage
	mov bx, 0				; offset of array slot being checked
gui_radio_handle_event_loop:
	test word [cs:si+bx+10], RADIO_FLAG_PENDING_DELETE
	jnz gui_radio_handle_event_next	; don't apply events if deleted
	
	cmp word [cs:si+bx], RADIO_NONE	; is this slot empty?
										; (are first two bytes RADIO_NONE?)
	je gui_radio_handle_event_next	; yes
	; this array element is not empty, so perform action on it	
	call gui_radio_apply_event
gui_radio_handle_event_next:
	add bx, RADIO_ENTRY_SIZE_BYTES	; next slot
	cmp bx, RADIO_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_radio_handle_event_loop			; no
gui_radio_handle_event_done:
	popa
	ret

	
; Raises a "checked set" event
;
; input:
;		CS:SI - pointer to radio
; output:
;		none
gui_radio_raise_checked_set_event:
	pusha
	
	mov al, GUI_EVENT_RADIO_INVOKE_CALLBACK
	mov bx, si
	sub bx, guiRadioStorage	; BX := radio offset
	call gui_event_enqueue_3bytes_atomic
	
	popa
	ret
	

; Unchecks all radios except the specified one.
; Only radio buttons in the same group as the specified one are 
; considered.
;
; input:
;		CS:DI - pointer to radio
; output:
;		none
gui_radio_uncheck_all_except:
	pusha
	
	; iterate through each radio
gui_radio_uncheck_all_except_iterate:
	mov si, guiRadioStorage
	mov bx, 0				; offset of array slot being checked
gui_radio_uncheck_all_except_loop:
	test word [cs:si+bx+10], RADIO_FLAG_PENDING_DELETE
	jnz gui_radio_uncheck_all_except_next	; not applicable if deleted

	cmp word [cs:si+bx], RADIO_NONE	; is this slot empty?
										; (are first two bytes RADIO_NONE?)
	je gui_radio_uncheck_all_except_next	; yes
	; this array element is not empty, so perform action on it	
	mov ax, word [cs:si+bx+18]		; AX := current radio group id
	cmp ax, word [cs:di+18]			; is it equal to the exception group id?
	jne gui_radio_uncheck_all_except_next	; no
	; the current radio is in the same group as the passed-in radio
	push di
	sub di, si						; DI := offset of exception radio
	cmp di, bx						; is current radio the exception radio?
	pop di
	je gui_radio_uncheck_all_except_next	; yes, so skip unchecking it
	
	push bx
	mov ax, bx						; AX := current radio handle
	mov bx, 0						; BX := "uncheck"
	call common_gui_radio_set_checked
	pop bx
gui_radio_uncheck_all_except_next:
	add bx, RADIO_ENTRY_SIZE_BYTES	; next slot
	cmp bx, RADIO_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_radio_uncheck_all_except_loop			; no
gui_radio_uncheck_all_except_done:
	popa
	ret
	

; Applies the lastly-dequeued event to the specified radio
;
; input:
;		BX - ID (offset) of radio
; output:
;		none
gui_radio_apply_event:
	pusha
	
	add bx, guiRadioStorage	; convert offset to pointer
	mov si, bx						; SI := pointer to radio
	
	test word [cs:si+10], RADIO_FLAG_ENABLED
	jz gui_radio_apply_event_done	; we're done if radio is not enabled

	push bx
	push cx
	push dx
	push si
	push di
	push fs
	push gs

	mov ax, word [cs:dequeueEventBytesBuffer+1]		; mouse X
	mov cx, word [cs:dequeueEventBytesBuffer+3]		; mouse Y
	; use a smaller rectangle than the cursor, so that the mouse cursor
	; "tail" doesn't count as a collision
	mov bx, 1										; mouse cursor width
	mov dx, 1										; mouse cursor height
	mov di, word [cs:si+6]							; radio width
	push word [cs:si+8]
	pop gs											; radio height
	push word [cs:si+4]
	pop fs											; radio Y
	push word [cs:si+2]
	pop si											; radio X
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
	je gui_radio_apply_event_mouse_left_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_radio_apply_event_mouse_left_up
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_radio_apply_event_mouse_right_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_radio_apply_event_mouse_right_up
	cmp bl, GUI_EVENT_MOUSE_MOVE
	je gui_radio_apply_event_mouse_move
	jmp gui_radio_apply_event_done

	; if we got here,
	; - radio is enabled
	; - AL = 0 when mouse cursor doesn't overlap radio
gui_radio_apply_event_mouse_left_up:
	cmp al, 0
	je gui_radio_apply_event_done		; releasing is NOOP when no overlap
	test word [cs:si+10], RADIO_FLAG_HELD_DOWN
	jz gui_radio_apply_event_done		; radio was not held down
	; there's overlap and radio was held down
	
	; radio is becoming released now
	mov dx, RADIO_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	
	or word [cs:si+10], RADIO_FLAG_CHECKED		; set "checked" flag
	or word [cs:si+10], RADIO_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiRadioNeedRender], 1
									; mark radio component for render
	push di
	mov di, si						; CS:DI := pointer to radio just checked
	call gui_radio_uncheck_all_except
	pop di
									
	; raise event to invoke callback
	call gui_radio_raise_checked_set_event
	jmp gui_radio_apply_event_done

gui_radio_apply_event_mouse_right_up:
	; NOOP - radio don't respond to right click events
	jmp gui_radio_apply_event_done

gui_radio_apply_event_mouse_left_down:
	cmp al, 0
	je gui_radio_apply_event_done	; clicking does nothing when no overlap
	; there is overlap
	or word [cs:si+10], RADIO_FLAG_HELD_DOWN	; set flag
	jmp gui_radio_apply_event_done

gui_radio_apply_event_mouse_right_down:
	; NOOP - radio don't respond to right click events
	jmp gui_radio_apply_event_done

gui_radio_apply_event_mouse_move:
	cmp al, 0
	je gui_radio_apply_event_mouse_move_nonoverlapping
gui_radio_apply_event_mouse_move_overlapping:
	; the mouse has moved within the radio
	test word [cs:si+10], RADIO_FLAG_HOVERED
	jnz gui_radio_apply_event_done	; already hovered
	; radio is becoming hovered now
	or word [cs:si+10], RADIO_FLAG_HOVERED | RADIO_FLAG_MUST_RENDER
								; mark radio as hovered and needing render
	mov byte [cs:guiRadioNeedRender], 1
								; mark radio component for render
	jmp gui_radio_apply_event_done

gui_radio_apply_event_mouse_move_nonoverlapping:
	; the mouse has moved outside of the radio
	test word [cs:si+10], RADIO_FLAG_HOVERED
	jz gui_radio_apply_event_done
					; already not hovered; now check if we need to release it
	; radio is becoming non-hovered now
	mov dx, RADIO_FLAG_HOVERED
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "hovered" flag
	or word [cs:si+10], RADIO_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiRadioNeedRender], 1
								; mark radio component for render
gui_radio_apply_event_mouse_move_nonoverlapping_release:
	; check if radio should become released
	test word [cs:si+10], RADIO_FLAG_HELD_DOWN
	jz gui_radio_apply_event_done			; don't need to release
	; radio is becoming released now
	mov dx, RADIO_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	jmp gui_radio_apply_event_done

gui_radio_apply_event_done:
	popa
	ret
	
	
; Marks all components as needing render
;
; input:
;		none
; output:
;		none
gui_radio_schedule_render_all:
	pusha

	mov si, guiRadioStorage
	mov bx, 0				; offset of array slot being checked
gui_radio_schedule_render_all_loop:
	cmp word [cs:si+bx], RADIO_NONE				; is this slot empty?
	je gui_radio_schedule_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_radio_schedule_render_all_perform:	
	or word [cs:si+bx+10], RADIO_FLAG_MUST_RENDER
gui_radio_schedule_render_all_next:
	add bx, RADIO_ENTRY_SIZE_BYTES	; next slot
	cmp bx, RADIO_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_radio_schedule_render_all_loop			; no
gui_radio_schedule_render_all_done:
	mov byte [cs:guiRadioNeedRender], 1	; mark entire component for render
	popa
	ret
	
	
; Checks whether the lastly-dequeued event is applicable to radios
;
; input:
;		none
; output:
;		AX - 0 when event is irrelevant, other value if it should be handled
gui_radio_is_event_applicable:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je gui_radio_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_radio_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_radio_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_radio_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSE_MOVE
	je gui_radio_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_RADIO_INVOKE_CALLBACK
	je gui_radio_is_event_applicable_yes
gui_radio_is_event_applicable_no:	
	mov ax, 0
	ret
gui_radio_is_event_applicable_yes:
	mov ax, 1
	ret

	
%endif
