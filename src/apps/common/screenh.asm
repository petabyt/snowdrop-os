;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains screen (in 80x25 text mode) utilities, focused on video
; hardware.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_SCREEN_HARDWARE_
%define _COMMON_SCREEN_HARDWARE_

COMMON_SCREENH_HEIGHT equ 25
COMMON_SCREENH_WIDTH equ 80

COMMON_SCREENH_GRAY_ON_BLACK equ 7


; Clears the screen and positions the cursor on row 0, column 0
; Sets all attributes to light gray on black.
;
; input
;		none
; output
;		none
common_screenh_clear_hardware_screen:
	pushf
	pusha
	push es
	
	push word 0B800h
	pop es
	mov di, 0							; ES:DI points at beginning of vram
	mov ah, COMMON_SCREENH_GRAY_ON_BLACK		; attribute byte
	mov al, 0									; ASCII character byte
	mov cx, COMMON_SCREENH_HEIGHT * COMMON_SCREENH_WIDTH	; this many words
	cld
	rep stosw
	
	mov bx, 0
	call common_screenh_move_hardware_cursor	; move cursor to (0, 0)
	
	pop es
	popa
	popf
	ret


; Re-positions the hardware cursor by writing to the 6845 CRT controller
;
; input
;		BH - row
;		BL - column	
common_screenh_move_hardware_cursor:
	pusha
	
	mov al, COMMON_SCREENH_WIDTH
	mul bh				; AX := COMMON_SCREEN_WIDTH * cursor row
	mov bh, 0			; BX := cursor column
	add bx, ax			; BX := (COMMON_SCREEN_WIDTH * cursor row) + cursor column
	
	mov al, 0Fh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Fh "cursor position LSB register"

	mov al, bl			; low byte of (COMMON_SCREEN_WIDTH * cursor row)+cursor column
	mov dx, 3D5h
	out dx, al			; write low byte to "cursor position LSB register"
	
	mov al, 0Eh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Eh "cursor position MSB register"
	
	mov al, bh			; high byte of (COMMON_SCREEN_WIDTH * cursor row)+cursor column
	mov dx, 3D5h
	out dx, al			; write high byte to "cursor position MSB register"
	
	popa
	ret

	
; Writes an attribute byte to the video ram, repeating as specified
;
; input
;		CX - repeat this many times
;		DL - attribute byte
; output
;		none
common_screenh_write_attr:
	pusha
	push es
	
	push word 0B800h
	pop es

	call common_screenh_get_cursor_position	; BH - cursor row
											; BL - cursor column
	mov al, COMMON_SCREENH_WIDTH
	mul bh				; AX := NUM_COLUMNS * cursor row
	mov bh, 0			; BX := cursor column
	add ax, bx			; AX := (NUM_COLUMNS * cursor row) + cursor column
	shl ax, 1			; multiply by 2 due to 2 bytes per character
	; AX now contains the offset in the video buffer from where we're starting
	
	mov di, ax				; ES:DI now points to the beginning of the location
							; where we're painting
	inc di					; point ES:DI at the high (attribute) byte

	cmp cx, 0							; handle the 0-count case
	je common_screenh_write_attr_done	
common_screenh_write_attr_loop:
	; now write the attribute byte
	mov byte [es:di], dl	; store attribute byte
	add di, 2				; next character from display buffer
							; (skipping over one character byte)
	loop common_screenh_write_attr_loop	; next location

common_screenh_write_attr_done:
	pop es
	popa
	ret

	
; Reads the current hardware cursor position from the 6845 CRT controller
;
; output
;		BH - row
;		BL - column
common_screenh_get_cursor_position:
	push ax
	push dx
	
	mov al, 0Eh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Eh "cursor position MSB register"
	
	mov dx, 3D5h
	in al, dx			; read high byte from "cursor position MSB register"
	
	xchg ah, al			; AH := high byte of cursor position
	
	mov al, 0Fh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Fh "cursor position LSB register"

	mov dx, 3D5h
	in al, dx			; read low byte of "cursor position LSB register"
						; AL := low byte of cursor position
	; AX now contains the cursor position (offset)					
	
	mov bl, COMMON_SCREENH_WIDTH
	div bl				; AL := AX / NUM_COLUMNS
						; AH := AX % NUM_COLUMNS
	
	mov bh, al			; row (to return)
	mov bl, ah			; column (to return)
	
	pop dx
	pop ax
	ret

	

%endif
