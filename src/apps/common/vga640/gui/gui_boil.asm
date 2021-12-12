;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains initialization and logic for boilerplate graphics common to
; all GUI framework-based apps.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_BOILERPLATE_
%define _COMMON_GUI_BOILERPLATE_

GUI_TITLE_PADDING		equ COMMON_GRAPHICS_FONT_WIDTH/2
									; pixels to the left and right of title

GUI_BORDER_OUTER_MARGIN	equ 1		; margin to edge of physical screen

GUI_TITLE_BAR_HEIGHT	equ COMMON_GRAPHICS_FONT_WIDTH + 2*GUI_BORDER_OUTER_MARGIN + 2

COMMON_GUI_MIN_X equ GUI_BORDER_OUTER_MARGIN
COMMON_GUI_MAX_X equ COMMON_GRAPHICS_SCREEN_WIDTH - GUI_BORDER_OUTER_MARGIN - 1
COMMON_GUI_MIN_Y equ GUI_TITLE_BAR_HEIGHT
COMMON_GUI_MAX_Y equ COMMON_GRAPHICS_SCREEN_HEIGHT - GUI_BORDER_OUTER_MARGIN - 1

COMMON_GUI_SCREEN_WIDTH equ COMMON_GRAPHICS_SCREEN_WIDTH - 2*GUI_BORDER_OUTER_MARGIN
COMMON_GUI_SCREEN_HEIGHT equ COMMON_GRAPHICS_SCREEN_HEIGHT - 2*GUI_BORDER_OUTER_MARGIN

GUI_GLOBAL_BUT_HORIZONTAL_PADDDING	equ 3
GUI_GLOBAL_BUT_WIDTH		equ 7
GUI_GLOBAL_BUT_HEIGHT		equ 7
guiGlobalXImageData:	db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1
						db GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1
						db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_1
						db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1
						db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_1
						db GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_0, GUI__COLOUR_1
						db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1
guiGlobalXCurrentImageData: times GUI_GLOBAL_BUT_WIDTH*GUI_GLOBAL_BUT_HEIGHT db 0
guiGlobaXImageHandle:	dw 0

guiGlobalYieldImageData:
						db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1
						db GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1
						db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1
						db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1
						db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1
						db GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1
						db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1
guiGlobalYieldCurrentImageData: times GUI_GLOBAL_BUT_WIDTH*GUI_GLOBAL_BUT_HEIGHT db 0
guiGlobalYieldImageHandle:	dw 0

guiGlobalPaletteSwapImageData:
					db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_3, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0
					db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_3, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0
					db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_3, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0
					db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_3, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0
					db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_3, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0
					db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_3, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0
					db GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_1, GUI__COLOUR_3, GUI__COLOUR_0, GUI__COLOUR_0, GUI__COLOUR_0
guiGlobalPaletteChangeImageHandle:	dw 0

guiGlobalBoldImageData:
					db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1
					db GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1
					db GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_0,GUI__COLOUR_1
					db GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_0,GUI__COLOUR_1
					db GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_0,GUI__COLOUR_1
					db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_0,GUI__COLOUR_0,GUI__COLOUR_1
					db GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1,GUI__COLOUR_1
guiGlobalBoldCurrentImageData: times GUI_GLOBAL_BUT_WIDTH*GUI_GLOBAL_BUT_HEIGHT db 0
guiGlobalBoldImageHandle:	dw 0


GUI_APP_TITLE_MAX_LENGTH	equ 32
guiDefaultApplicationTitle: db 'UNTITLED APPLICATION', 0
guiApplicationTitle:	times GUI_APP_TITLE_MAX_LENGTH+1 db 0
						; +1 for terminator


; Sets the application title, which will be displayed in the title bar
;
; input:
;		DS:SI - pointer to title
; output:
;		none
common_gui_title_set:
	pusha
	push es
	
	; copy title from DS:SI into the app title buffer
	pushf
	
	push cs
	pop es
	mov di, guiApplicationTitle		; ES:DI := pointer to title buffer
	mov cx, GUI_APP_TITLE_MAX_LENGTH
	cld
	rep movsb						; copy as many bytes as maximum title
	mov byte [es:di], 0				; add terminator, in case passed-in title
									; was too long
	popf
	
	pop es
	popa
	ret

	
; Adjusts global button graphics by copying and replacing colours.
; Assumes regular palette matches constants
; (e.g.: colour 0 equals GUI__COLOUR_0, etc.)
;
; input:
;		none
; output:
;		none
gui_boilerplate_on_palette_change:
	pusha
	push ds
	push es
	
	mov bx, cs
	mov ds, bx
	mov es, bx
	
	; swap colours of the close X button
	mov si, guiGlobalXImageData
	mov di, guiGlobalXCurrentImageData
	mov cx, GUI_GLOBAL_BUT_WIDTH*GUI_GLOBAL_BUT_HEIGHT
	call gui_boilerplate_copy_buffer_with_replace_colour
	
	; swap colours of the yield button
	mov si, guiGlobalYieldImageData
	mov di, guiGlobalYieldCurrentImageData
	mov cx, GUI_GLOBAL_BUT_WIDTH*GUI_GLOBAL_BUT_HEIGHT
	call gui_boilerplate_copy_buffer_with_replace_colour
	
	; swap colours of the bold button
	mov si, guiGlobalBoldImageData
	mov di, guiGlobalBoldCurrentImageData
	mov cx, GUI_GLOBAL_BUT_WIDTH*GUI_GLOBAL_BUT_HEIGHT
	call gui_boilerplate_copy_buffer_with_replace_colour
	
	call gui_redraw_boilerplate
	
	pop es
	pop ds
	popa
	ret


; Copies buffer and replaces colours
; Assumes regular palette matches constants
; (e.g.: colour 0 equals GUI__COLOUR_0, etc.)
;
; input:
;	 DS:SI - pointer to regular palette bitmap
;	 ES:DI - pointer to destination image bitmap
;		CX - buffer size in bytes
; output:
;		none
gui_boilerplate_copy_buffer_with_replace_colour:
	pusha
	pushf
	push ds
	push es
	
	cld
gui_boilerplate_copy_buffer_with_replace_colour_loop:
	; we're using the regular bitmap with swapped colours
	mov al, byte [ds:si]
	
gui_boilerplate_copy_buffer_with_replace_colour_try_0:
	cmp al, GUI__COLOUR_0
	jne gui_boilerplate_copy_buffer_with_replace_colour_try_1
	mov al, byte [cs:guiColour0]
	jmp gui_boilerplate_copy_buffer_with_replace_colour_next
gui_boilerplate_copy_buffer_with_replace_colour_try_1:
	cmp al, GUI__COLOUR_1
	jne gui_boilerplate_copy_buffer_with_replace_colour_try_2
	mov al, byte [cs:guiColour1]
	jmp gui_boilerplate_copy_buffer_with_replace_colour_next
gui_boilerplate_copy_buffer_with_replace_colour_try_2:
	cmp al, GUI__COLOUR_2
	jne gui_boilerplate_copy_buffer_with_replace_colour_try_3
	mov al, byte [cs:guiColour2]
	jmp gui_boilerplate_copy_buffer_with_replace_colour_next
gui_boilerplate_copy_buffer_with_replace_colour_try_3:
	cmp al, GUI__COLOUR_3
	jne gui_boilerplate_copy_buffer_with_replace_colour_next
	mov al, byte [cs:guiColour3]

gui_boilerplate_copy_buffer_with_replace_colour_next:
	mov byte [es:di], al
	inc si
	inc di
	loop gui_boilerplate_copy_buffer_with_replace_colour_loop
	
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Redraws boilerplate graphics.
; When this function is invoked, a full re-render is imminent.
;
; input:
;		none
; output:
;		none
gui_redraw_boilerplate:
	pusha
	push ds
	
	push cs
	pop ds
	
	call common_gui_draw_begin						; begin background change
	
	; clear screen
	mov dl, byte [cs:guiColour1]
	call common_graphics_clear_screen_to_colour

	; draw border and title
	push cs
	pop ds
	mov si, guiApplicationTitle
	int 0A5h										; BX := title string length
	cmp bx, 0										; is it empty?
	ja gui_redraw_boilerplate_draw_border			; no, so just draw it
	; it's empty, so use default
	mov si, guiDefaultApplicationTitle

gui_redraw_boilerplate_draw_border:
	call gui_draw_screen_border
	call common_gui_draw_end						; finish background change
	
	call gui_boilerplate_adjust_global_buttons

	call gui_raise_refresh_event					; let consumers act also

	pop ds
	popa
	ret
	

; Creates boilerplate graphics and components common to all applications
; These include the window border, title text, global X button, etc.
;
; input:
;		none
; output:
;		none
gui_create_boilerplate:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, guiGlobalXCurrentImageData
	mov cx, 1							; index
	call gui_create_global_button
	mov word [cs:guiGlobaXImageHandle], ax
	mov si, guiShutdownCallback
	call common_gui_image_left_click_callback_set

	call gui_sync_is_principal
	cmp al, 0
	je gui_create_boilerplate__is_not_principal
	
gui_create_boilerplate__is_principal:
	; we do these only if principal
	mov si, guiGlobalPaletteSwapImageData
	mov cx, 3							; index
	call gui_create_global_button
	mov word [cs:guiGlobalPaletteChangeImageHandle], ax
	mov si, guiSwitchPaletteCallback
	call common_gui_image_left_click_callback_set
	
	mov si, guiGlobalBoldCurrentImageData
	mov cx, 4							; index
	call gui_create_global_button
	mov word [cs:guiGlobalBoldImageHandle], ax
	mov si, guiBoldCallback
	call common_gui_image_left_click_callback_set

gui_create_boilerplate__is_not_principal:
	mov si, guiGlobalYieldCurrentImageData
	mov cx, 2							; index
	call gui_create_global_button
	mov word [cs:guiGlobalYieldImageHandle], ax
	mov si, guiYieldCallback
	call common_gui_image_left_click_callback_set
	
	cmp byte [cs:guiYieldDisabled], 0
	je gui_create_boilerplate__after_yield
	
	call common_gui_image_disable		; disable yield
gui_create_boilerplate__after_yield:

gui_create_boilerplate_done:
	call gui_redraw_boilerplate
	
	pop ds
	popa
	ret

	
; Synchronizes buttons with the application's state
;
; input:
;		none
; output:
;		none
gui_boilerplate_adjust_global_buttons:
	pusha
	
	call gui_sync_can_shutdown
	cmp al, 0
	je gui_boilerplate_adjust_global_buttons__X_disable
gui_boilerplate_adjust_global_buttons__X_enable:
	mov ax, word [cs:guiGlobaXImageHandle]
	call common_gui_image_enable
	jmp gui_boilerplate_adjust_global_buttons_done
gui_boilerplate_adjust_global_buttons__X_disable:
	mov ax, word [cs:guiGlobaXImageHandle]
	call common_gui_image_disable
	jmp gui_boilerplate_adjust_global_buttons_done
gui_boilerplate_adjust_global_buttons__X_after:
	
gui_boilerplate_adjust_global_buttons_done:	
	popa
	ret
	

; Creates a global button, in the title bar of the application.
; These "buttons" are actually implemented as images, so they take 
; up less space.
;
; input:
;	 DS:SI - pointer to image bytes
;		CX - index (e.g. index 0 is closest to edge, 1 is closer to middle)
;			 NOTE: index is one-based
; output:
;		AX - image handle of the newly-added "button" image
gui_create_global_button:
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, GUI_GLOBAL_BUT_WIDTH
	mul cx
	mov bx, ax							; BX := index * GUI_GLOBAL_BUT_WIDTH
	
	dec cx
	mov ax, GUI_GLOBAL_BUT_HORIZONTAL_PADDDING
	mul cx								; AX := (index-1) * GUI_GLOBAL_BUT_HORIZONTAL_PADDDING
	
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH - GUI_BORDER_OUTER_MARGIN
	sub dx, bx
	sub dx, ax
	dec dx
	
	mov bx, GUI_BORDER_OUTER_MARGIN + 1
	mov ax, dx
	mov cx, GUI_GLOBAL_BUT_WIDTH		; width
	mov dx, GUI_GLOBAL_BUT_HEIGHT		; height
	mov di, GUI_GLOBAL_BUT_WIDTH		; canvas width
	call common_gui_image_add			; AX := handle
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret


; Draws the screen border which encompasses the entire application.
; It also writes the title
;
; input:
;		DS:SI - pointer to title
; output:
;		none
gui_draw_screen_border:
	pusha
	push si
	
	; draw outer border
	mov bx, GUI_BORDER_OUTER_MARGIN
	mov ax, GUI_BORDER_OUTER_MARGIN
	mov cx, COMMON_GUI_SCREEN_WIDTH
	mov si, COMMON_GUI_SCREEN_HEIGHT
	mov dl, byte [cs:guiColour2]
	call common_graphics_draw_rectangle_outline_by_coords

	; draw horizontal lines around the title text
gui_draw_screen_border_title_loop:
	add ax, 2								; horizontal lines every few pixels
	call common_graphics_draw_line_solid
	cmp ax, GUI_BORDER_OUTER_MARGIN + COMMON_GRAPHICS_FONT_HEIGHT
	jbe gui_draw_screen_border_title_loop

	pop si								; DS:SI := pointer to title
	
	; erase border where the title will go
	call common_graphics_text_measure_width	; AX := pixel width of string
	add ax, 2*GUI_TITLE_PADDING				; AX := total title width
	mov cx, ax								; CX := total title width
	shr ax, 1								; AX := half of total title width
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH/2	; BX := middle of screen
	sub bx, ax								; BX := X of left edge of title
	
	mov ax, GUI_BORDER_OUTER_MARGIN + 1		; top Y of erasing rectangle
	
	mov di, COMMON_GRAPHICS_FONT_HEIGHT		; height of erasing rectangle
	mov dl, byte [cs:guiColour1]
	call common_graphics_draw_rectangle_solid

	; print title text
	add bx, GUI_TITLE_PADDING
	mov ax, GUI_BORDER_OUTER_MARGIN + 1
	mov cl, byte [cs:guiColour0]	; colour
	mov dx, word [cs:guiIsBoldFont]			; options
	call common_graphics_text_print_at

	popa
	ret
	
	
; Callback for the global X button
;
; input:
;		none
; output:
;		none						
guiShutdownCallback:
	call common_gui_shutdown
	retf

	
; Callback for the global palette change button
;
; input:
;		none
; output:
;		none
guiSwitchPaletteCallback:
	mov ax, word [cs:guiGlobalPaletteChangeImageHandle]
	mov bx, 0								; "not selected"
	call common_gui_image_set_selected		; the click selected the image,
											; so we unselect it automatically
	
	mov bl, byte [cs:guiIsRegularPalette]
	xor bl, 1								; swap it
	mov al, GUI_EVENT_PALETTE_CHANGE
	call gui_event_enqueue_2bytes_atomic
	retf
	
	
; Callback for the global bold text button
;
; input:
;		none
; output:
;		none
guiBoldCallback:
	mov ax, word [cs:guiGlobalBoldImageHandle]
	mov bx, 0								; "not selected"
	call common_gui_image_set_selected		; the click selected the image,
											; so we unselect it automatically
	
	mov bl, byte [cs:guiIsBoldFont]
	xor bl, 1								; swap it
	mov al, GUI_EVENT_FONT_CHANGE
	call gui_event_enqueue_2bytes_atomic
	retf
	
	
; Callback for the global yield button
;
; input:
;		none
; output:
;		none	
guiYieldCallback:
	mov ax, word [cs:guiGlobalYieldImageHandle]
	mov bx, 0								; "not selected"
	call common_gui_image_set_selected		; the click selected the image,
											; so we unselect it automatically
	call gui_yield
	retf
	

%endif
