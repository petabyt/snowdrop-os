;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains procedures for rendering an ASCII text box.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_TEXTBOX_
%define _COMMON_TEXTBOX_

ASCII_CORNER_TOP_LEFT equ 218
ASCII_CORNER_TOP_RIGHT equ 191
ASCII_CORNER_BOTTOM_LEFT equ 192
ASCII_CORNER_BOTTOM_RIGHT equ 217
ASCII_LINE_VERTICAL equ 179
ASCII_LINE_HORIZONTAL equ 196

textBoxTitleLeftDecoration: db 180, " ", 0
textBoxTitleRightDecoration: db " ", 195, 0


; Draws a box
;
; input
;		BH - row
;		BL - column
;		AH - content height, at least 1
;		AL - content width, at least 1
common_draw_box:
	pusha
	
	; top left corner
	int 9Eh						; move cursor
	mov dl, ASCII_CORNER_TOP_LEFT
	int 98h						; print character
	; draw top
	mov dl, ASCII_LINE_HORIZONTAL
	mov ch, 0
	mov cl, al					; CX := width
draw_box_top_horizontal:
	int 98h						; print character
	loop draw_box_top_horizontal
	; top right corner
	mov dl, ASCII_CORNER_TOP_RIGHT
	int 98h						; print character
	
	; verticals
draw_box_vertical:
	mov ch, 0
	mov cl, ah					; CX := height
draw_box_vertical_loop:
	push bx
	; left vertical
	add bh, cl
	int 9Eh						; move cursor
	mov dl, ASCII_LINE_VERTICAL
	int 98h						; print character
	; right vertical
	add bl, al					; move to right
	inc bl						; account for left vertical
	int 9Eh						; move cursor
	int 98h						; print character
	pop bx
	loop draw_box_vertical_loop
	
	; bottom left corner
	add bh, ah
	inc bh						; account for top border
	int 9Eh						; move cursor
	mov dl, ASCII_CORNER_BOTTOM_LEFT
	int 98h						; print character
	; draw top
	mov dl, ASCII_LINE_HORIZONTAL
	mov ch, 0
	mov cl, al					; CX := width
draw_box_bottom_horizontal:
	int 98h						; print character
	loop draw_box_bottom_horizontal
	; bottom right corner
	mov dl, ASCII_CORNER_BOTTOM_RIGHT
	int 98h						; print character
	
	popa
	ret
	
	
; Clears the inside of a box
;
; input
;		BH - row
;		BL - column
;		AH - content height, at least 1
;		AL - content width, at least 1
common_textbox_clear:
	pusha
	
	inc bl
	
	mov ch, 0
	mov cl, ah
common_textbox_clear_loop_outer:
	push cx
	
	inc bh
	int 9Eh						; move cursor
	
	mov dl, ' '
	mov ch, 0
	mov cl, al					; CX := width
common_textbox_clear_loop_inner:
	int 98h						; print character
	loop common_textbox_clear_loop_inner
	pop cx
	loop common_textbox_clear_loop_outer
	
	popa
	ret
	

; Prints a box title
;
; input
;		BH - row
;		BL - column
;		DL - attributes of text
;	 DS:SI - pointer to string
common_draw_box_title:
	pusha
	
	int 9Eh						; move cursor to BH, BL
	
	push si						; save pointer to string
	push ds
	push cs
	pop ds
	mov si, textBoxTitleLeftDecoration
	int 97h						; print left decoration
	pop ds
	pop si						; DS:SI := pointer to passed in string
	
	int 0A5h					; BX := passed in string length
	mov cx, bx					; 
	int 9Fh						; make title text coloured (CX characters)
	
	; here, DS:SI points to the passed in string again
	int 97h						; print passed in string
	
	push ds
	push cs
	pop ds
	mov si, textBoxTitleRightDecoration
	int 97h						; print right decoration
	pop ds
	
	popa
	ret

%endif
