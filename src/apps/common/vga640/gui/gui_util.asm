;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains various utility functionality.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.;

; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_UTIL_
%define _COMMON_GUI_UTIL_

NOTICE_RECTANGLE_WIDTH	equ 400
NOTICE_RECTANGLE_HEIGHT	equ 80


; Renders a single line of text, first erasing the background behind it.
; Useful for when a dynamic line of text must be written to the screen.
;
; input:
;	 DS:SI - pointer to string
;		AX - position Y
;		BX - position X
; output:
;		none
common_gui_util_print_single_line_text_with_erase:
	pusha
	
	push ax
	
	; erase previous text
	call common_graphics_text_measure_width			; AX := text width
	mov cx, ax										; CX := text width
	add cx, 2										; padding in case text is bold
	mov di, COMMON_GRAPHICS_FONT_HEIGHT				; DI := text height
	mov dl, byte [cs:guiColour1]					; background
	pop ax
	call common_graphics_draw_rectangle_solid
	
	; write text
	inc bx								; padding in case text is bold
	mov dx, word [cs:guiIsBoldFont]		; options
	mov cl, byte [cs:guiColour0]		; colour
	call common_graphics_text_print_at	; draw text
	
	popa
	ret


; Renders a notice rectangle containing the specified message
;
; input:
;	 DS:SI - pointer to string
; output:
;		none
common_gui_util_show_notice:
	pusha
	push si								; [1]
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH/2 - NOTICE_RECTANGLE_WIDTH/2
	mov ax, COMMON_GRAPHICS_SCREEN_HEIGHT/2 - NOTICE_RECTANGLE_HEIGHT/2
	
	; draw a solid rectangle that's the same colour as the background
	mov cx, NOTICE_RECTANGLE_WIDTH	; width
	mov di, NOTICE_RECTANGLE_HEIGHT	; height
	mov dl, byte [cs:guiColour1]
	call common_graphics_draw_rectangle_solid
	; now draw its outline
	mov dl, byte [cs:guiColour2]
	mov si, NOTICE_RECTANGLE_HEIGHT
	call common_graphics_draw_rectangle_outline_by_coords
					
	pop si								; [1]
	call common_graphics_text_measure_width	; AX := width
	shr ax, 1							; AX := width/2
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH/2
	sub bx, ax							; BX := X position
	mov ax, COMMON_GRAPHICS_SCREEN_HEIGHT/2 - COMMON_GRAPHICS_FONT_HEIGHT/2
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	popa
	ret

	
; Prints two BCD digits contained in a byte	
;
; input:
;		AL - contains two BCD digits (F)irst and (S)econd FFFFSSSS
; output:
;		AH - numeric value of most significant digit
;		AL - numeric value of least significant digit
gui_util_decode_BCD:
	push bx
	
	ror al, 4
	mov bh, al
	and bh, 0Fh
	
	ror al, 4
	mov bl, al
	and bl, 0Fh
	
	mov ax, bx
	pop bx
	ret
	

%endif
