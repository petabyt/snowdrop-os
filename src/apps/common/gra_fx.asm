;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains special graphics effects, such as fade.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GRAPHICS_EFFECTS_
%define _COMMON_GRAPHICS_EFFECTS_

COMMON_GRAPHICS_FADE_STEP equ 2				; darken by this much every step
COMMON_GRAPHICS_COLOUR_SHADES equ 64		; since VGA colours are 6-bit


; Fades the current palette
;
; input:
;		CX - delay amount between fade iterations
; output:
;		none
common_graphics_fx_fade:
	pusha
	push ds
	push es
	
	; save current palette to our temporary buffer
	push cs
	pop es
	mov di, tempPaletteBuffer			; ES:DI := destination buffer
	call common_graphics_save_current_palette_to_buffer
	
	; now perform several iterations, fading every time
	push cs
	pop ds

	mov dx, ( COMMON_GRAPHICS_COLOUR_SHADES / COMMON_GRAPHICS_FADE_STEP ) + 1
								; DX is the outer loop counter
common_graphics_fx_fade_outer:
	; now fade palette to black
	mov si, tempPaletteBuffer
	mov bx, 0
common_graphics_fx_fade_inner:
	mov al, byte [cs:si+bx]
	cmp al, COMMON_GRAPHICS_FADE_STEP
	jae fade_inner_subtract			; when greater, just subtract value
	; when lower, increase it so that the subtraction takes it to zero
	mov al, COMMON_GRAPHICS_FADE_STEP
fade_inner_subtract:
	sub al, COMMON_GRAPHICS_FADE_STEP	; shift toward black (toward zero)
	mov byte [cs:si+bx], al				; store

	inc bx
	cmp bx, COMMON_GRAPHICS_LARGEST_PALETTE_TOTAL_SIZE
	jnz common_graphics_fx_fade_inner ; next palette entry
	; end inner loop
	
	; make faded palette active
	push si
	mov si, tempPaletteBuffer		; DS:SI now points to the palette buffer
	call common_graphics_load_palette
	pop si
	
	cmp cx, 0
	je fade_after_delay				; no delay when delay amount is 0
	int 85h							; delay (amount was input in CX)
	
fade_after_delay:
	dec dx
	jnz common_graphics_fx_fade_outer					; fade again
	
common_graphics_fx_fade_done:
	pop es
	pop ds
	popa
	ret

; used for temporary palette operations, such as fading
tempPaletteBuffer: times COMMON_GRAPHICS_LARGEST_PALETTE_TOTAL_SIZE db 0	
	
%include "common\gra_base.asm"

%endif
