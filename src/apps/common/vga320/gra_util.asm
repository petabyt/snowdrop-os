;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains graphics-oriented utilities.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GRAPHICS_UTILITIES_
%define _COMMON_GRAPHICS_UTILITIES_


; Draws a progress bar for the specified current value.
; The bar is assumed to track values between 0 and maximum value, inclusive.
;
; input:
;		DX - current value
;		CX - maximum value
;		DI - video memory offset of top left corner of indicator
;		BL - frame colour
;		BH - bar colour
;		AX - height
; output:
;		none
common_graphics_utils_draw_prograss_indicator:
	pusha
	
	cmp dx, cx
	jbe draw_prograss_indicator_begin	; current value is in range

	mov dx, cx							; limit current value to max value
draw_prograss_indicator_begin:
	push dx
	push ax
	add ax, 2					; height
	
	mov dx, cx
	add dx, 2					; width
	; BL already contains outline colour
	; AX already contains height
	call common_graphics_draw_rectangle_solid
	pop ax
	pop dx
	
	cmp dx, 0
	je draw_prograss_indicator_done			; nothing to fill when 0
	
	add di, COMMON_GRAPHICS_SCREEN_WIDTH	; shift DI to top-left corner
	inc di									; of the interior
	
	; DX already contains width
	; AX already contains height
	mov bl, bh					; BL := bar colour
	call common_graphics_draw_rectangle_solid
	
draw_prograss_indicator_done:	
	popa
	ret


%include "common\vga320\graphics.asm"

%endif
