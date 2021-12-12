;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains screen (in 80x25 text mode) utilities.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_SCREEN_
%define _COMMON_SCREEN_

COMMON_SCREEN_HEIGHT equ 25
COMMON_SCREEN_WIDTH equ 80


; Clears screen to the specified font and background colours
;
; input:
;		DL - attributes (font and background colours)
common_clear_screen_to_colour:
	pusha
	
	int 0A0h					; clear screen

	mov bh, 0					; row
	mov bl, 0					; column
	int 9Eh						; move cursor
	
	mov cx, COMMON_SCREEN_WIDTH * COMMON_SCREEN_HEIGHT
	int 9Fh						; attributes
	
	popa
	ret

%endif
