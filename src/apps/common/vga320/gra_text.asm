;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains functions for outputting text in graphics mode.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GRAPHICS_TEXT_
%define _COMMON_GRAPHICS_TEXT_

; This font is not complete. It is based on the font I created for my 
; ZX Spectrum game development library, libzx.

; Size: 8x8 pixels
;     - zeroes are considered transparent and are not rendered
;     - ones are rendered as opaque

COMMON_TEXT_PRINT_FLAG_NORMAL 		equ 0
COMMON_TEXT_PRINT_FLAG_DOUBLE_WIDTH	equ 1
COMMON_TEXT_PRINT_FLAG_CENTRE 		equ 2

COMMON_GRAPHICS_PIXELS_PER_CHARACTER equ COMMON_GRAPHICS_FONT_BYTES_PER_CHARACTER
CHARACTERS_PER_LINE equ COMMON_GRAPHICS_SCREEN_WIDTH / COMMON_GRAPHICS_FONT_WIDTH

; used to store the character being printed on screen, during the colour 
; replacement step
graphicsTextTempCharacter: times COMMON_GRAPHICS_PIXELS_PER_CHARACTER db 0


; Renders the specified string in the given colour.
; Can also centre the text horizontally at the specified Y location.
;
; Input:
;		CL - colour
;		BX - X position (not used when text is centred)
;		AX - Y position
;	 DS:SI - pointer to zero-terminated string to print
;		DX - options:
;		   bit 0 - double horizontal thickness
;		   bit 1 - centre text (ignores X position value in BX)
;		bit 2-15 - unused
; Output:
;		none	
common_graphics_text_print_at:
	pusha
	
	push dx									; [2] save options
	
	; do we have to centre the text?
	test dx, COMMON_TEXT_PRINT_FLAG_CENTRE		; do we centre it?
	jz print_centered_calculate_video_offset	; no, so go ahead and calculate
												; using passed-in X and Y
	; we are centring the text
	; calculate string length
	int 0A5h				; BX := string length
	cmp bx, CHARACTERS_PER_LINE				; is it too wide?
	ja print_centered_calculate_too_wide	; yes
	; no, it's not too wide
	; now calculate a suitable X position for it
	push ax									; [1] save passed-in Y position
	mov al, COMMON_GRAPHICS_FONT_WIDTH
	mul bl									; AX := pixel length of string
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH
	sub bx, ax
	shr bx, 1								; BX := X position
	pop ax									; [1] restore passed-in Y position
	jmp print_centered_calculate_video_offset
print_centered_calculate_too_wide:
	; string is longer than a screen width, so start at the left edge
	mov bx, 0								; X position
print_centered_calculate_video_offset:
	; calculate initial video offset in DI, using Y = AX and X = BX
	call common_graphics_coordinate_to_video_offset	; AX := starting offset
	mov di, ax				; DI := starting video offset

	pop dx									; [2] restore options
common_graphics_text_print_at_loop:
	mov al, byte [ds:si]					; AL := ASCII to print
	cmp al, 0								; did we reach end of string?
	je common_graphics_text_print_at_done	; yes
	cmp al, COMMON_ASCII_CARRIAGE_RETURN
	je common_graphics_text_print_at_cr
	cmp al, COMMON_ASCII_LINE_FEED
	je common_graphics_text_print_at_lf
	jmp common_graphics_text_print_at_normal_ascii

common_graphics_text_print_at_lf:
	; line feed character sends the cursor directly one line down
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH
	mov bx, COMMON_GRAPHICS_FONT_HEIGHT
	mul bx								; DX:AX := screen width * font height
	add di, ax							; (DX = 0, since DX:AX < 64000)
	
	inc si								; advance string pointer
	jmp common_graphics_text_print_at_loop	; next character

common_graphics_text_print_at_cr:
	; carriage return character sends the cursor to the start of the line
	mov dx, 0
	mov ax, di							; DX:AX := current offset
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH
	div bx								; AX := current offset DIV screen width
	mul bx								; DX:AX := beginning of current line
	mov di, ax							; (DX = 0, since DX:AX < 64000)
	
	inc si								; advance string pointer
	jmp common_graphics_text_print_at_loop	; next character
	
common_graphics_text_print_at_normal_ascii:
	; print normal ASCII character
	sub al, COMMON_GRAPHICS_FIRST_CHARACTER	; AL := ASCII - first char
	
	mov bl, COMMON_GRAPHICS_PIXELS_PER_CHARACTER/8
	mul bl						; AX := offset into font array
	
	mov bx, ax					; BX := offset into font array
	add bx, commonGraphicsFont	; convert to pointer

	call graphics_text_load_temp_character
	mov bl, cl					; BL := font colour to render
	call graphics_text_replace_colour_in_temp_character
	call graphics_text_render_temp_character
	
	test dx, COMMON_TEXT_PRINT_FLAG_DOUBLE_WIDTH	; double width option?
	jz text_print_at_next_character			; no
	; yes, so render it again, to achieve double width
text_print_at_double_width:
	push di
	inc di
	call graphics_text_render_temp_character
	pop di

text_print_at_next_character:
	inc si									; advance character pointer
	add di, COMMON_GRAPHICS_FONT_WIDTH		; advance video offset
	jmp common_graphics_text_print_at_loop	; next character
	
common_graphics_text_print_at_done:
	popa
	ret
	

; Renders the temporary character to video memory
;
; Input:
;	 	DI - video memory offset
; Output:
;		none
graphics_text_render_temp_character:
	pusha
	push ds
	
	push cs
	pop ds
	mov bx, graphicsTextTempCharacter	; DS:BX now points to temp character
	
	; here, DI = video memory offset as passed in
	mov si, COMMON_GRAPHICS_FONT_WIDTH	; canvas is as wide as the character
	mov ax, COMMON_GRAPHICS_FONT_HEIGHT	; character height
	mov dx, COMMON_GRAPHICS_FONT_WIDTH	; character width
	call common_graphics_draw_rectangle_transparent	; render it
	
	pop ds
	popa
	ret
	

; Replaces all non-zero bytes of the font data in the temporary character
; with the specified colour.
; Also replaces all zero bytes with the transparent colour
;
; Input:
;	 	BL - colour to "paint" all pixels of the temporary character
; Output:
;		none
graphics_text_replace_colour_in_temp_character:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, graphicsTextTempCharacter	; DS:SI now points to temp. character
	
	mov cx, COMMON_GRAPHICS_PIXELS_PER_CHARACTER
graphics_text_replace_colour_loop:
	mov al, byte [ds:si]
	cmp al, 0
	je graphics_text_replace_colour_zero
graphics_text_replace_colour_nonzero:
	; replace with provided colour
	mov byte [ds:si], bl
	jmp graphics_text_replace_colour_next
graphics_text_replace_colour_zero:
	; replace with the transparent colour
	mov byte [ds:si], COMMON_GRAPHICS_COLOUR_TRANSPARENT
graphics_text_replace_colour_next:
	inc si
	loop graphics_text_replace_colour_loop	; next

	pop ds
	popa
	ret
	

; Loads a character's worth of bytes into the temporary character
; storage area.
;
; Input:
;		BX - pointer to font entry for a character (OFFSET ONLY)
; Output:
;		none
graphics_text_load_temp_character:
	pusha
	push es
	
	push cs
	pop es
	mov di, graphicsTextTempCharacter
	
	; expand each byte of the font to 8 bytes
	; such that a 0 bit makes a 0 byte and a 1 bit makes a 1 byte
	
	mov cx, COMMON_GRAPHICS_PIXELS_PER_CHARACTER/8
graphics_text_load_temp_character_loop:
	mov al, byte [cs:bx]
	
	mov dl, al
	and dl, 10000000b
	shr dl, 7
	mov byte [es:di+0], dl
	
	mov dl, al
	and dl, 01000000b
	shr dl, 6
	mov byte [es:di+1], dl
	
	mov dl, al
	and dl, 00100000b
	shr dl, 5
	mov byte [es:di+2], dl
	
	mov dl, al
	and dl, 00010000b
	shr dl, 4
	mov byte [es:di+3], dl
	
	mov dl, al
	and dl, 00001000b
	shr dl, 3
	mov byte [es:di+4], dl
	
	mov dl, al
	and dl, 00000100b
	shr dl, 2
	mov byte [es:di+5], dl
	
	mov dl, al
	and dl, 00000010b
	shr dl, 1
	mov byte [es:di+6], dl
	
	mov dl, al
	and dl, 00000001b
	shr dl, 0
	mov byte [es:di+7], dl
	
	inc bx						; next source byte
	add di, 8					; next chunk of 8 destination bytes
	loop graphics_text_load_temp_character_loop
	
	pop es
	popa
	ret


; Measures the width in pixels of a string, assuming it will all be printed
; on a single line.
;
; Input:
;	 DS:SI - pointer to zero-terminated string to print
; Output:
;		AX - printed string width in pixels
common_graphics_text_measure_width:
	push bx
	int 0A5h 				; BX := string length
	mov ax, COMMON_GRAPHICS_FONT_WIDTH
	mul bx					; DX:AX := pixel width of string
	pop bx
	ret
	

%include "common\ascii.asm"	
%include "common\vga320\graphics.asm"
%include "common\gra_font.asm"

%endif
