;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains logic for dealing with GUI buttons.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_BUTTONS_
%define _COMMON_GUI_BUTTONS_

BUTTONS_NONE 				equ 0FFFFh ; word value which marks a slot as empty

BUTTONS_ENTRY_SIZE_BYTES	equ 64
BUTTONS_TOTAL_SIZE_BYTES equ (GUI_BUTTONS_LIMIT+GUI_RESERVED_COMPONENT_COUNT)*BUTTONS_ENTRY_SIZE_BYTES ; in bytes

BUTTON_FLAG_ENABLED			equ 1	; button is clickable
BUTTON_FLAG_HOVERED			equ 2	; button is hovered over by the mouse
BUTTON_FLAG_MUST_RENDER		equ 4	; button must be redrawn
BUTTON_FLAG_HELD_DOWN		equ 8	; button is being held down via a click
BUTTON_FLAG_PENDING_DELETE	equ 16	; button is pending deletion

BUTTONS_LABEL_LENGTH		equ 32
BUTTON_LABEL_PADDING_X		equ 4	; in pixels
BUTTON_LABEL_PADDING_Y		equ 3	; in pixels
BUTTON_DEPTH				equ 2	; in pixels

BUTTON_HOVER_MARK_SIZE_PIXELS		equ 2

COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE equ COMMON_GRAPHICS_FONT_HEIGHT + 1 + 2*BUTTON_LABEL_PADDING_Y
		; height of a button containing a single line of text as the label, such that
		; the label is centered vertically
		; (the +1 accounts for the top pixel row of each character being empty)

; structure info (per array entry)
; bytes
;     0-1 id
;     2-3 position X
;     4-5 position Y
;     6-7 width
;     8-9 height
;   10-11 flags
;   12-13 flags from before last render
;   14-15 on-click callback segment
;   16-17 on-click callback offset
;   18-18 label position X (used for ease of rendering labels)
;   19-31 unused
;   32-63 zero-terminated label string

; the first two bytes in each element in the array are used to flag whether
; that array element is "empty"
; non-empty elements can use those two bytes for any purpose (such as element 
; ID, etc.)
guiButtonsStorage: times BUTTONS_TOTAL_SIZE_BYTES db 0

guiButtonsNeedRender:	db 0	; becomes non-zero when a change which requires
								; at least one button to be redrawn took place

guiButtonsRenderMode:	db	99
GUI_BUTTONS_RENDER_MODE_DELETIONS		equ 0
GUI_BUTTONS_RENDER_MODE_MODIFICATIONS	equ 1

; Prepares buttons module before usage
;
; input:
;		none
; output:
;		none
gui_buttons_prepare:
	pusha
	
	call gui_buttons_clear_storage
	mov byte [cs:guiButtonsNeedRender], 0
	
	popa
	ret


; Erases a button from the screen
;
; input:
;		BX - ID (offset) of button
; output:
;		none	
gui_buttons_erase:
	pusha
	
	add bx, guiButtonsStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to array element
	
	mov bx, word [cs:si+2]			; X
	mov ax, word [cs:si+4]			; Y
	
	; draw a rectangle that's the same colour as the background, and large
	; enough to cover not just the button, but also its depth
	mov cx, word [cs:si+6]			; width
	add cx, BUTTON_DEPTH
	mov di, word [cs:si+8]			; height
	add di, BUTTON_DEPTH
	mov dl, byte [cs:guiColour1]
	call common_graphics_draw_rectangle_solid
	
	popa
	ret
	

; Draws a button in its released (default) state
;
; input:
;		CS:SI - pointer to button
; output:
;		none	
gui_buttons_render_released:
	pusha

	; draw rectangle
	mov di, si						; use DI to index for now
	
	mov bx, word [cs:di+2]			; X
	mov ax, word [cs:di+4]			; Y
	mov cx, word [cs:di+6]			; width
	mov si, word [cs:di+8]			; height
	
	test word [cs:di+10], BUTTON_FLAG_ENABLED	; determine rectangle colour
	jz gui_buttons_render_released_rectangle_disabled
gui_buttons_render_released_rectangle_enabled:
	mov dl, byte [cs:guiColour0]
	jmp gui_buttons_render_released_rectangle_draw
gui_buttons_render_released_rectangle_disabled:
	mov dl, byte [cs:guiColour3]
	jmp gui_buttons_render_released_rectangle_draw
gui_buttons_render_released_rectangle_draw:
	call common_graphics_draw_rectangle_outline_by_coords
	
	mov si, di						; use SI to index again
	; draw button depth
	mov bx, word [cs:si+2]			; X
	inc bx
	mov ax, word [cs:si+4]			; Y
	add ax, word [cs:si+8]			; add height
	
	; we push the computed depth colour so we can re-use it later on
	test word [cs:si+10], BUTTON_FLAG_ENABLED	; determine label colour
	jz gui_buttons_render_released_depth_disabled
gui_buttons_render_released_depth_enabled:
	mov dl, byte [cs:guiColour2]
	jmp gui_buttons_render_released_depth_draw
gui_buttons_render_released_depth_disabled:
	mov dl, byte [cs:guiColour3]
	jmp gui_buttons_render_released_depth_draw
gui_buttons_render_released_depth_draw:
	; draw depth pixel at the bottom-left
	call common_graphics_draw_pixel_by_coords

	; draw horizontal depth line
	mov cx, word [cs:si+6]			; width
	inc bx
	inc ax
	call common_graphics_draw_line_solid
	
	; draw depth pixel at the top-right
	mov bx, word [cs:si+2]			; X
	add bx, word [cs:si+6]			; add width
	mov ax, word [cs:si+4]			; Y
	inc ax
	call common_graphics_draw_pixel_by_coords

	; draw vertical depth line
	mov cx, word [cs:si+8]			; height
	inc bx
	inc ax
	call common_graphics_draw_vertical_line_solid_by_coords
	
	push si									; [2] save pointer to button
	; render the button's label
	test word [cs:si+10], BUTTON_FLAG_ENABLED	; determine label colour
	jz gui_buttons_render_released_label_disabled
gui_buttons_render_released_label_enabled:
	mov cl, byte [cs:guiColour0]
	jmp gui_buttons_render_released_label_draw
gui_buttons_render_released_label_disabled:
	mov cl, byte [cs:guiColour3]
	jmp gui_buttons_render_released_label_draw
gui_buttons_render_released_label_draw:
	mov bx, word [cs:si+18]			; X
	mov ax, word [cs:si+4]			; Y
	add ax, BUTTON_LABEL_PADDING_Y
	push cs
	pop ds
	add si, 32						; DS:SI := pointer to button label
	mov dx, word [cs:guiIsBoldFont]
	call common_graphics_text_print_at
	
	pop si									; [2] restore pointer to button
	; render the "hover" mark when hovering over an enabled button
	; NOTE: the mark is drawn on the top left corner, since it's the place
	;       least likely to be covered by the bulk of the mouse cursor
	mov ax, word [cs:si+10]
	and ax, BUTTON_FLAG_ENABLED | BUTTON_FLAG_HOVERED
	cmp ax, BUTTON_FLAG_ENABLED | BUTTON_FLAG_HOVERED
	jne gui_buttons_render_released_done
	; it's enabled and hovered, so draw the mark
	mov ax, word [cs:si+4]			; Y
	add ax, 2						; move inside rectangle
	mov bx, word [cs:si+2]			; X
	add bx, 2						; move inside rectangle
	mov cx, BUTTON_HOVER_MARK_SIZE_PIXELS		; line length
	mov dl, byte [cs:guiColour2]			; colour
	call common_graphics_draw_line_solid	; line to the right
	call common_graphics_draw_vertical_line_solid_by_coords	; line downward

gui_buttons_render_released_done:
	popa
	ret

	
; Draws a button in its clicked (depressed) state
;
; input:
;		CS:SI - pointer to button
; output:
;		none	
gui_buttons_render_clicked:
	pusha
	
	; draw rectangle
	mov bx, word [cs:si+2]			; X
	add bx, BUTTON_DEPTH			; offset
	mov ax, word [cs:si+4]			; Y
	add ax, BUTTON_DEPTH			; offset
	mov cx, word [cs:si+6]			; width
	mov dx, word [cs:si+8]			; height
	push si
	mov si, dx						; height
	mov dl, byte [cs:guiColour0]			; colour
	call common_graphics_draw_rectangle_outline_by_coords
	pop si
	
	push si							; [2] save pointer to button
	; render the button's label
	mov bx, word [cs:si+18]			; X
	add bx, BUTTON_DEPTH			; offset
	mov ax, word [cs:si+4]			; Y
	add ax, BUTTON_DEPTH			; offset
	add ax, BUTTON_LABEL_PADDING_Y
	push cs
	pop ds
	add si, 32						; DS:SI := pointer to button label
	mov cl, byte [cs:guiColour0]
	mov dx, word [cs:guiIsBoldFont]
	call common_graphics_text_print_at
	
	pop si									; [2] restore pointer to button
	; render the hovered mark
	mov ax, word [cs:si+4]			; Y
	add ax, BUTTON_DEPTH			; offset
	add ax, 2						; move inside rectangle
	mov bx, word [cs:si+2]			; X
	add bx, BUTTON_DEPTH			; offset
	add bx, 2						; move inside rectangle
	mov cx, BUTTON_HOVER_MARK_SIZE_PIXELS		; line length
	mov dl, byte [cs:guiColour2]			; colour
	call common_graphics_draw_line_solid	; line to the right
	call common_graphics_draw_vertical_line_solid_by_coords	; line downward
	
	popa
	ret
	

; Draws a button on the screen
;
; input:
;		BX - ID (offset) of button
; output:
;		none
gui_buttons_render:
	pusha
	push ds

	mov si, bx						; SI := pointer to array element
	add si, guiButtonsStorage		; convert offset to pointer

	call gui_buttons_erase			; first, erase button
	
gui_buttons_render_after_erasing:
	test word [cs:si+10], BUTTON_FLAG_PENDING_DELETE
	jnz gui_buttons_render_finish	; button was deleted

	test word [cs:si+10], BUTTON_FLAG_HELD_DOWN
	jnz gui_buttons_render_depressed
gui_buttons_render_default:
	call gui_buttons_render_released
	jmp gui_buttons_render_finish
gui_buttons_render_depressed:
	call gui_buttons_render_clicked
	jmp gui_buttons_render_finish

gui_buttons_render_finish:
	; we're done drawing; now perform some housekeeping
	mov ax, word [cs:si+10]
	mov word [cs:si+12], ax			; old flags := flags

	; if it was pending deletion, we have erased from screen, so
	; we can clear that flag, as well
	mov ax, BUTTON_FLAG_MUST_RENDER | BUTTON_FLAG_PENDING_DELETE
	xor ax, 0FFFFh
	and word [cs:si+10], ax			; clear flags

	pop ds
	popa
	ret
	
	
; Measures the width in pixels of a button which will have the 
; specified, single-line label string
;
; Input:
;	 DS:SI - pointer to zero-terminated string 
; Output:
;		CX - button width
common_gui_button_measure_single_line:
	push ax
	call common_graphics_text_measure_width	; AX := pixel width of string
	add ax, 2*BUTTON_LABEL_PADDING_X
	mov cx, ax
	pop ax
	ret


; Makes the specified button disabled and no longer responding to
; interactions events
;
; input:
;		AX - button handle
; output:
;		none
common_gui_button_disable:
	pusha
	
	mov bx, ax
	cmp word [cs:guiButtonsStorage+bx], BUTTONS_NONE
	je common_gui_button_disable_done
	
	mov word [cs:guiButtonsStorage+bx+10], BUTTON_FLAG_MUST_RENDER
					; clear all flags except this one
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render

common_gui_button_disable_done:	
	popa
	ret
	
	
; Enables the specified button
;
; input:
;		AX - button handle
; output:
;		none
common_gui_button_enable:
	pusha
	
	mov bx, ax
	cmp word [cs:guiButtonsStorage+bx], BUTTONS_NONE
	je common_gui_button_enable_done
	
	test word [cs:guiButtonsStorage+bx+10], BUTTON_FLAG_PENDING_DELETE
	jnz common_gui_button_enable_done	; cannot enable a button being deleted
	
	mov word [cs:guiButtonsStorage+bx+10], BUTTON_FLAG_ENABLED | BUTTON_FLAG_MUST_RENDER
					; clear all flags except these one
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render
common_gui_button_enable_done:
	popa
	ret
	
	
; Deletes the specified button entirely, removing it from screen 
; and freeing up its memory
;
; input:
;		AX - button handle
; output:
;		none
common_gui_button_delete:
	pusha
	
	mov bx, ax
	cmp word [cs:guiButtonsStorage+bx], BUTTONS_NONE
	je common_gui_button_delete_exit
	
	mov word [cs:guiButtonsStorage+bx+0], BUTTONS_NONE	; free button entry
	mov word [cs:guiButtonsStorage+bx+10], BUTTON_FLAG_PENDING_DELETE | BUTTON_FLAG_MUST_RENDER
					; clear all flags except these ones
					; note, the button is also flagged as disabled, so
					; it cannot be interacted with
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render

common_gui_button_delete_exit:
	popa
	ret
	

; Clears all storage button entries
;
; input:
;		none
; output:
;		none
gui_buttons_clear_storage:
	pusha

	mov si, guiButtonsStorage
	mov bx, 0				; offset of array slot being checked
gui_buttons_clear_storage_loop:
	mov word [cs:si+bx], BUTTONS_NONE	; mark slot as available
	mov word [cs:si+bx+10], 0			; clear flags
gui_buttons_clear_storage_next:
	add bx, BUTTONS_ENTRY_SIZE_BYTES	; next slot
	cmp bx, BUTTONS_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_buttons_clear_storage_loop			; no
gui_buttons_clear_storage_done:
	popa
	ret
	

; Adds a button whose size is auto scaled to fit the button's label.
; Assumes label only takes up a single line
;
; input:
;		AX - position X
;		BX - position Y
;	 DS:SI - pointer to zero-terminated label string
; output:
;		AX - button handle
common_gui_button_add_auto_scaled:
	push cx
	push dx
	
	call common_gui_button_measure_single_line		; CX := width
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	call common_gui_button_add		; AX := button handle
	
	pop dx
	pop cx
	ret
	
	
; Adds a button
;
; input:
;		AX - position X
;		BX - position Y
;		CX - width
;		DX - height
;	 DS:SI - pointer to zero-terminated label string
; output:
;		AX - button handle
common_gui_button_add:
	push bx
	push cx
	push dx
	push si
	push ds
	push es
	
	push bx							; [1] save input
	
	call gui_buttons_find_empty_slot	; BX := offset
										; CARRY=0 when slot was found
	jc common_gui_button_add_full
	; we found a slot, so add the button
	
	push bx							; [3] save button offset
	add bx, guiButtonsStorage		; BX := pointer to button

	mov word [cs:bx+0], 0			; id
	mov word [cs:bx+6], cx			; width
	mov word [cs:bx+8], dx			; height
	
	; until the consumer its own callback, set a NOOP callback
	mov word [cs:bx+14], cs
	mov word [cs:bx+16], gui_noop_callback
	
	push dx							; [2] save input
	mov dx, BUTTON_FLAG_ENABLED | BUTTON_FLAG_MUST_RENDER
	mov word [cs:bx+10], dx			; flags
	mov word [cs:bx+12], dx			; old flags
	pop dx							; [2] restore input
	
	mov word [cs:bx+2], ax			; position X
	
	; calculate label position X to simplify rendering code
	pusha
	shr cx, 1						; CX := half width
	add cx, ax						; CX := middle of button
	call common_graphics_text_measure_width	; AX := pixel width of label
	shr ax, 1						; AX := half label width
	sub cx, ax						; CX := label position X
	mov word [cs:bx+18], cx			; store label position X
	popa

	; copy label from DS:SI into the button's label buffer
	pushf
	push cs
	pop es
	mov di, bx						; ES:DI := pointer to array element
	add di, 32						; ES:DI := pointer to label
	mov cx, BUTTONS_LABEL_LENGTH
	cld
	rep movsb						; copy as many bytes as maximum label
	dec di							; ES:DI := pointer to last byte of label
	mov byte [es:di], 0				; add terminator, in case passed-in label
									; was too long
	popf

	pop ax							; [3] AX := button offset
	
	mov si, bx						; SI := pointer to array element
	pop bx							; [1] restore input
	mov word [cs:si+4], bx			; position Y
	
	mov byte [cs:guiButtonsNeedRender], 1	; indicate some buttons changed
	jmp common_gui_button_add_done	; we're done
	
common_gui_button_add_full:
	pop bx							; remove extra value on stack
common_gui_button_add_done:
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
gui_buttons_find_empty_slot:
	push si

	clc									; a clear CARRY indicates success
	
	; find first empty array slot
	mov si, guiButtonsStorage
	mov bx, 0				; offset of array slot being checked
gui_buttons_find_empty_slot_loop:
	test word [cs:si+bx+10], BUTTON_FLAG_PENDING_DELETE
	jnz gui_buttons_find_empty_slot_loop_next	; skip slot if it's pending delete

	cmp word [cs:si+bx], BUTTONS_NONE			; is this slot empty?
										; (are first two bytes BUTTONS_NONE?)
	je gui_buttons_find_empty_slot_done	; yes

gui_buttons_find_empty_slot_loop_next:
	add bx, BUTTONS_ENTRY_SIZE_BYTES		; next slot
	cmp bx, BUTTONS_TOTAL_SIZE_BYTES		; are we past the end?
	jb gui_buttons_find_empty_slot_loop		; no
gui_buttons_find_empty_slot_full:			; yes
	stc										; set CARRY to indicate failure
	jmp gui_buttons_find_empty_slot_done
gui_buttons_find_empty_slot_done:
	pop si
	ret

	
; Iterates through all buttons, rendering those which need it
;
; input:
;		none
; output:
;		none
gui_buttons_render_all:
	mov byte [cs:guiButtonsRenderMode], GUI_BUTTONS_RENDER_MODE_DELETIONS
	call private_gui_buttons_render_all
	mov byte [cs:guiButtonsRenderMode], GUI_BUTTONS_RENDER_MODE_MODIFICATIONS
	call private_gui_buttons_render_all
	ret
	
	
; Iterates through those buttons to which the current rendering 
; mode pertains, rendering those which need it.
;
; input:
;		none
; output:
;		none
private_gui_buttons_render_all:
	pusha

	mov si, guiButtonsStorage
	mov bx, 0				; offset of array slot being checked
gui_buttons_render_all_loop:
	cmp byte [cs:guiButtonsRenderMode], GUI_BUTTONS_RENDER_MODE_MODIFICATIONS
	je gui_buttons_render_all_loop_after_deleted_handling
				; we're only rendering modifications, so skip over the handling
				; of deleted ones
	test word [cs:si+bx+10], BUTTON_FLAG_PENDING_DELETE
	jnz gui_buttons_render_all_perform	; if it's pending delete, we have to
										; render it
	
	cmp byte [cs:guiButtonsRenderMode], GUI_BUTTONS_RENDER_MODE_DELETIONS
	je gui_buttons_render_all_next		; we're only rendering deletions, so
										; go to next
gui_buttons_render_all_loop_after_deleted_handling:
	cmp word [cs:si+bx], BUTTONS_NONE	; is this slot empty?
										; (are first two bytes BUTTONS_NONE?)
	je gui_buttons_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_buttons_render_all_perform:	
	test word [cs:si+bx+10], BUTTON_FLAG_MUST_RENDER
	jz gui_buttons_render_all_next		; we don't have to redraw this one
	call gui_buttons_render				; perform
gui_buttons_render_all_next:
	add bx, BUTTONS_ENTRY_SIZE_BYTES	; next slot
	cmp bx, BUTTONS_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_buttons_render_all_loop			; no
gui_buttons_render_all_done:
	mov byte [cs:guiButtonsNeedRender], 0	; mark rendering complete
	popa
	ret
	
	
; Marks all components as needing render
;
; input:
;		none
; output:
;		none
gui_buttons_schedule_render_all:
	pusha

	mov si, guiButtonsStorage
	mov bx, 0				; offset of array slot being checked
gui_buttons_schedule_render_all_loop:
	cmp word [cs:si+bx], BUTTONS_NONE	; is this slot empty?
										; (are first two bytes BUTTONS_NONE?)
	je gui_buttons_schedule_render_all_next		; yes
	; this array element is not empty, so perform action on it
gui_buttons_schedule_render_all_perform:	
	or word [cs:si+bx+10], BUTTON_FLAG_MUST_RENDER
gui_buttons_schedule_render_all_next:
	add bx, BUTTONS_ENTRY_SIZE_BYTES	; next slot
	cmp bx, BUTTONS_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_buttons_schedule_render_all_loop			; no
gui_buttons_schedule_render_all_done:
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render
	popa
	ret
	

; Returns whether some buttons need to be rendered	
;
; input:
;		none
; output:
;		AL - 0 when buttons don't need rendering, other value otherwise
gui_buttons_get_need_render:
	mov al, byte [cs:guiButtonsNeedRender]
	ret


; Invokes the callback of the specified button
;
; input:
;		BX - ID (offset) of button
; output:
;		none
gui_buttons_invoke_callback:
	pusha
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word gui_buttons_invoke_callback_return	; return address on stack
	
	; setup "call far" address
	push word [cs:guiButtonsStorage+bx+14]			; callback segment
	push word [cs:guiButtonsStorage+bx+16]			; callback offset
	
	; setup callback arguments
	mov ax, bx										; AX := button handle
	
	retf											; "call far"
	; once the callback executes its own retf, execution returns below
gui_buttons_invoke_callback_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	popa
	ret


; Sets the specified button's click callback, which is invoked whenever the
; button is clicked
;
; input:
;		AX - button handle
;	 DS:SI - pointer to callback function
; output:
;		none	
common_gui_button_click_callback_set:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiButtonsStorage+bx], BUTTONS_NONE
	je common_gui_button_click_callback_set_done
	
	mov word [cs:guiButtonsStorage+bx+14], ds		; callback segment
	mov word [cs:guiButtonsStorage+bx+16], si		; callback offset

common_gui_button_click_callback_set_done:	
	popa
	ret
	
	
; Clears the specified button's click callback
;
; input:
;		AX - button handle
; output:
;		none	
common_gui_button_click_callback_clear:
	pusha
	
	mov bx, ax
	
	cmp word [cs:guiButtonsStorage+bx], BUTTONS_NONE
	je common_gui_button_click_callback_clear_done
	
	mov word [cs:guiButtonsStorage+bx+14], cs		; callback segment
	mov word [cs:guiButtonsStorage+bx+16], gui_noop_callback
								; NOOP callback offset
common_gui_button_click_callback_clear_done:
	popa
	ret
	
	
; Considers the newly-dequeued event, and modifies button state
; for any affected buttons.
;
; input:
;		none
; output:
;		none
gui_buttons_handle_event:
	pusha
	
	call gui_buttons_is_event_applicable
	cmp ax, 0
	je gui_buttons_handle_event_done		; event is not applicable
	; event is applicable (it may modify button state)

	; some event types can be handled without iterating through all buttons
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_BUTTON_INVOKE_CALLBACK
	je gui_buttons_handle_event_invoke_callback
	
	jmp gui_buttons_handle_event_iterate	; the event is "per-button", so
											; start iterating
gui_buttons_handle_event_invoke_callback:
	mov bx, word [cs:dequeueEventBytesBuffer+1]		; button offset
	call gui_buttons_invoke_callback
	jmp gui_buttons_handle_event_done

	; iterate through each button
gui_buttons_handle_event_iterate:
	mov si, guiButtonsStorage
	mov bx, 0				; offset of array slot being checked
gui_buttons_handle_event_loop:
	test word [cs:si+bx+10], BUTTON_FLAG_PENDING_DELETE
	jnz gui_buttons_handle_event_next	; don't apply events if deleted
	
	cmp word [cs:si+bx], BUTTONS_NONE	; is this slot empty?
										; (are first two bytes BUTTONS_NONE?)
	je gui_buttons_handle_event_next	; yes
	; this array element is not empty, so perform action on it	
	call gui_buttons_apply_event
gui_buttons_handle_event_next:
	add bx, BUTTONS_ENTRY_SIZE_BYTES	; next slot
	cmp bx, BUTTONS_TOTAL_SIZE_BYTES	; are we past the end?
	jb gui_buttons_handle_event_loop			; no
gui_buttons_handle_event_done:
	popa
	ret


; Applies the lastly-dequeued event to the specified button
;
; input:
;		BX - ID (offset) of button
; output:
;		none
gui_buttons_apply_event:
	pusha
	
	add bx, guiButtonsStorage		; convert offset to pointer
	mov si, bx						; SI := pointer to button
	
	test word [cs:si+10], BUTTON_FLAG_ENABLED
	jz gui_buttons_apply_event_done	; we're done if button is not enabled

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
	mov di, word [cs:si+6]							; button width
	push word [cs:si+8]
	pop gs											; button height
	push word [cs:si+4]
	pop fs											; button Y
	push word [cs:si+2]
	pop si											; button X
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
	je gui_buttons_apply_event_mouse_left_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_buttons_apply_event_mouse_left_up
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_buttons_apply_event_mouse_right_down
	cmp bl, GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_buttons_apply_event_mouse_right_up
	cmp bl, GUI_EVENT_MOUSE_MOVE
	je gui_buttons_apply_event_mouse_move
	jmp gui_buttons_apply_event_done

	; if we got here,
	; - button is enabled
	; - AL = 0 when mouse cursor doesn't overlap button
gui_buttons_apply_event_mouse_left_up:
	cmp al, 0
	je gui_buttons_apply_event_done		; releasing is NOOP when no overlap
	test word [cs:si+10], BUTTON_FLAG_HELD_DOWN
	jz gui_buttons_apply_event_done		; button was not held down
	; there's overlap and button was held down
	
	; button is becoming released now
	mov dx, BUTTON_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	or word [cs:si+10], BUTTON_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render
	; raise event to invoke callback
	mov al, GUI_EVENT_BUTTON_INVOKE_CALLBACK
	mov bx, si
	sub bx, guiButtonsStorage	; BX := button offset
	call gui_event_enqueue_3bytes_atomic
	jmp gui_buttons_apply_event_done

gui_buttons_apply_event_mouse_right_up:
	; NOOP - buttons don't respond to right click events
	jmp gui_buttons_apply_event_done

gui_buttons_apply_event_mouse_left_down:
	cmp al, 0
	je gui_buttons_apply_event_done		; clicking does nothing when no overlap
	test word [cs:si+10], BUTTON_FLAG_HELD_DOWN
	jnz gui_buttons_apply_event_done	; button was already held down
	; button is becoming held down now
	or word [cs:si+10], BUTTON_FLAG_HELD_DOWN | BUTTON_FLAG_MUST_RENDER
								; mark button as held down and needing render
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render
	jmp gui_buttons_apply_event_done

gui_buttons_apply_event_mouse_right_down:
	; NOOP - buttons don't respond to right click events
	jmp gui_buttons_apply_event_done

gui_buttons_apply_event_mouse_move:
	cmp al, 0
	je gui_buttons_apply_event_mouse_move_nonoverlapping
gui_buttons_apply_event_mouse_move_overlapping:
	; the mouse has moved within the button
	test word [cs:si+10], BUTTON_FLAG_HOVERED
	jnz gui_buttons_apply_event_done	; already hovered

	; button is becoming hovered now
	or word [cs:si+10], BUTTON_FLAG_HOVERED | BUTTON_FLAG_MUST_RENDER
								; mark button as hovered and needing render
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render
	jmp gui_buttons_apply_event_done

gui_buttons_apply_event_mouse_move_nonoverlapping:
	; the mouse has moved outside of the button
	test word [cs:si+10], BUTTON_FLAG_HOVERED
	jz gui_buttons_apply_event_mouse_move_nonoverlapping_release
					; already not hovered; now check if we need to release it
	; button is becoming non-hovered now
	mov dx, BUTTON_FLAG_HOVERED
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "hovered" flag
	or word [cs:si+10], BUTTON_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render
gui_buttons_apply_event_mouse_move_nonoverlapping_release:
	; check if button should become released
	test word [cs:si+10], BUTTON_FLAG_HELD_DOWN
	jz gui_buttons_apply_event_done			; don't need to release
	; button is becoming released now
	mov dx, BUTTON_FLAG_HELD_DOWN
	xor dx, 0FFFFh
	and word [cs:si+10], dx				; clear "held down" flag
	or word [cs:si+10], BUTTON_FLAG_MUST_RENDER	; mark as needing render
	mov byte [cs:guiButtonsNeedRender], 1	; mark buttons component for render
	jmp gui_buttons_apply_event_done

gui_buttons_apply_event_done:
	popa
	ret
	
	
; Checks whether the lastly-dequeued event is applicable to buttons
;
; input:
;		none
; output:
;		AX - 0 when event is irrelevant, other value if it should be handled
gui_buttons_is_event_applicable:
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_DOWN
	je gui_buttons_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_LEFT_UP
	je gui_buttons_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_DOWN
	je gui_buttons_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSEBUTTON_RIGHT_UP
	je gui_buttons_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_MOUSE_MOVE
	je gui_buttons_is_event_applicable_yes
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_BUTTON_INVOKE_CALLBACK
	je gui_buttons_is_event_applicable_yes
gui_buttons_is_event_applicable_no:	
	mov ax, 0
	ret
gui_buttons_is_event_applicable_yes:
	mov ax, 1
	ret

	
%endif
