;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains procedures for rendering an ASCII text box directly to 
; video hardware
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_TEXTBOX_HARDWARE_
%define _COMMON_TEXTBOX_HARDWARE_

TH_ASCII_CORNER_TOP_LEFT_s db 218, 0
TH_ASCII_CORNER_TOP_RIGHT_s db 191, 0
TH_ASCII_CORNER_BOTTOM_LEFT_s db 192, 0
TH_ASCII_CORNER_BOTTOM_RIGHT_s db 217, 0
TH_ASCII_LINE_VERTICAL_s db 179, 0
TH_ASCII_LINE_HORIZONTAL_s db 196, 0

textBoxHTitleLeftDecoration: db 180, " ", 0
textBoxHTitleRightDecoration: db " ", 195, 0


; Draws a box
;
; input
;		BH - row
;		BL - column
;		AH - content height, at least 1
;		AL - content width, at least 1
common_draw_boxh:
	pusha
	push ds
	
	push cs
	pop ds
	
	; top left corner
	call common_screenh_move_hardware_cursor
	mov si, TH_ASCII_CORNER_TOP_LEFT_s
	int 80h
	; draw top
	mov cl, al					; CX := width
	mov si, TH_ASCII_LINE_HORIZONTAL_s
	mov ch, 0
draw_boxh_top_horizontal:
	int 80h
	loop draw_boxh_top_horizontal
	; top right corner
	mov si, TH_ASCII_CORNER_TOP_RIGHT_s
	int 80h
	; verticals
draw_boxh_vertical:
	mov ch, 0
	mov cl, ah					; CX := height
draw_boxh_vertical_loop:
	push bx
	; left vertical
	add bh, cl
	call common_screenh_move_hardware_cursor
	mov si, TH_ASCII_LINE_VERTICAL_s
	int 80h
	; right vertical
	add bl, al					; move to right
	inc bl						; account for left vertical
	call common_screenh_move_hardware_cursor
	mov si, TH_ASCII_LINE_VERTICAL_s
	int 80h
	pop bx
	loop draw_boxh_vertical_loop
	
	; bottom left corner
	add bh, ah
	inc bh						; account for top border
	call common_screenh_move_hardware_cursor
	mov si, TH_ASCII_CORNER_BOTTOM_LEFT_s
	int 80h
	; draw top
	mov cl, al					; CX := width
	
	mov si, TH_ASCII_LINE_HORIZONTAL_s
	mov ch, 0
draw_boxh_bottom_horizontal:
	int 80h
	loop draw_boxh_bottom_horizontal
	; bottom right corner
	mov si, TH_ASCII_CORNER_BOTTOM_RIGHT_s
	int 80h
	
	pop ds
	popa
	ret
	

; Prints a box title
;
; input
;		BH - row
;		BL - column
;		DL - attributes of text
;	 DS:SI - pointer to string
common_draw_boxh_title:
	pusha
	
	call common_screenh_move_hardware_cursor
	
	push si						; save pointer to string
	push ds
	push cs
	pop ds
	mov si, textBoxHTitleLeftDecoration
	int 80h						; print left decoration
	pop ds
	pop si						; DS:SI := pointer to passed in string
	
	int 0A5h					; BX := passed in string length
	mov cx, bx					; 
	call common_screenh_write_attr	; make title text coloured (CX characters)
	
	; here, DS:SI points to the passed in string again
	int 80h						; print passed in string
	
	push ds
	push cs
	pop ds
	mov si, textBoxHTitleRightDecoration
	int 80h						; print right decoration
	pop ds
	
	popa
	ret

	
; input:
;		ASCII in AL
textboxh_print_char:
	pusha
	mov ah, 0Eh
	mov bx, 7		; gray colour, black background
	int 10h
	popa
	ret
	

%include "common\screenh.asm"
	
%endif
