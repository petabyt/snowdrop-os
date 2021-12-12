;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains base functionality used by multiple graphics libraries
; (mode 13h, mode 12h, etc.)
;
; The first and at least second libraries are implemented in parallel because
; their contracts are not compatible. The first library exposed too much
; of its implementation by way of requiring a pointer into video memory as
; an argument to many of its calls.
;
; The second library rectifies this.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GRAPHICS_BASE_
%define _COMMON_GRAPHICS_BASE_

COMMON_GRAPHICS_PALETTE_ENTRY_SIZE	equ 3	; 1 byte for each: red, green, blue

; these are characteristic to Snowdrop OS's first graphics library, for mode 13h
; mode 13h, 320x200 256 colours
COMMON_GRAPHICS_MODE13H_PALETTE_ENTRY_SIZE equ COMMON_GRAPHICS_PALETTE_ENTRY_SIZE
COMMON_GRAPHICS_MODE13H_PALETTE_ENTRIES equ 256		; 256 colours in total
COMMON_GRAPHICS_MODE13H_PALETTE_TOTAL_SIZE equ COMMON_GRAPHICS_MODE13H_PALETTE_ENTRY_SIZE * COMMON_GRAPHICS_MODE13H_PALETTE_ENTRIES

; these are characteristic to the second library, for mode 12h and having
; a better-defined contract
; mode 12h, 640x480 16 colours
COMMON_GRAPHICS_MODE12H_PALETTE_ENTRY_SIZE equ COMMON_GRAPHICS_PALETTE_ENTRY_SIZE
COMMON_GRAPHICS_MODE12H_PALETTE_ENTRIES equ 16		; 16 colours in total
COMMON_GRAPHICS_MODE12H_PALETTE_TOTAL_SIZE equ COMMON_GRAPHICS_MODE12H_PALETTE_ENTRY_SIZE * COMMON_GRAPHICS_MODE12H_PALETTE_ENTRIES

; these are defined so consumers are able to allocate a palette buffer
; sufficiently large to store palettes from either graphics libraries
COMMON_GRAPHICS_LARGEST_PALETTE_TOTAL_SIZE		equ COMMON_GRAPHICS_MODE13H_PALETTE_TOTAL_SIZE
COMMON_GRAPHICS_LARGEST_NR_OF_PALETTE_ENTRIES	equ COMMON_GRAPHICS_MODE13H_PALETTE_ENTRIES


; Flips vertically a rectangle contained in its own buffer (as in, the canvas 
; is as wide as the rectangle).
;
; input:
;		DS:DI - pointer to pixel data
;		BX - height of image
;		DX - width of image
; output:
;		none	
common_graphicsbase_flip_rectangle_buffer_vertically:
	pusha
	
	mov ax, dx					; our canvas is as wide as the image itself
	call common_graphicsbase_flip_rectangle_vertically_on_canvas
	
	popa
	ret
	
	
; Flips vertically a given rectangle of pixels that's on a larger canvas 
; (such as the entire screen).
;
; NOTE: this function was written in one shot, late at night; it worked 
;       the first time...!
;
; input:
;		DS:DI - pointer to pixel data
;		BX - height of image
;		DX - width of image
;		AX - width of canvas (e.g. width of entire screen, when flipping
;			 a rectangle in the video memory)
; output:
;		none
common_graphicsbase_flip_rectangle_vertically_on_canvas:
	pusha
	
	push ax
	push bx
	push dx							; preserve input
	
	mov cx, ax						; CX := canvas width
	
	mov ax, bx						; AX := height
	dec ax							; AX := height - 1
	mov dx, cx
	mul dx							; DX:AX := (height-1)*(canvas width)
	
	mov si, di						; SI now points to bmpData[0][0]
	add si, ax						; SI now points to bmpData[height-1][0]
	
	pop dx
	pop bx
	pop ax							; restore input
	
									
	; for( i = 0; i < height / 2; i++ ) {
	;     for( j = 0; i < width; j++ ) {
	;         swap bmpData[i][j] and bmpData[height - i][j];
	;     }
	; }
	
	; here, SI points to bmpData[height-1][0] (that is, beginning of last line)
	; here, DI points to bmpData[0][0] (that is, beginning of first line)
	shr bx, 1						; BX := height / 2
	mov cx, -1
flip_vertically_outer_loop:
	inc cx							; next line down
	cmp cx, bx						; did we reach height / 2?
	je flip_vertically_done			; yes, we're done
	; process this line
	push cx							; save outer loop counter
	push bx							; save (height / 2)
	mov bx, -1
flip_vertically_inner_loop:
	inc bx
	cmp bx, dx						; did we reach width?
	je flip_vertically_inner_loop_done ; yes, we're done the inner loop
	; process this byte
	; DI points to bmpData[i][0]
	; SI points to bmpData[height-i][0]
	push ax							; [1] save canvas width
	mov al, byte [ds:di+bx]			; AL := bmpData[i][j]
	mov ah, byte [ds:si+bx]			; AH := bmpData[height-i][j]
	mov byte [ds:di+bx], ah
	mov byte [ds:si+bx], al			; swap the bytes
	pop ax							; [1] restore canvas width
	jmp flip_vertically_inner_loop	; next inner loop iteration
	
flip_vertically_inner_loop_done:
	; here, AX = canvas width, as passed in
	add di, ax						; move DI down one line
	sub si, ax						; move SI up one line
	
	pop bx							; restore (height / 2)
	pop cx							; restore outer loop counter
	jmp flip_vertically_outer_loop	; next outer loop iteration
	
flip_vertically_done:	
	popa
	ret

	
; Flips horizontally a rectangle contained in its own buffer (as in, the canvas 
; is as wide as the rectangle).
;
; input:
;		DS:DI - pointer to pixel data
;		BX - height of image
;		DX - width of image
; output:
;		none	
common_graphicsbase_flip_rectangle_buffer_horizontally:
	pusha
	
	mov ax, dx					; our canvas is as wide as the image itself
	call common_graphicsbase_flip_rectangle_horizontally_on_canvas
	
	popa
	ret
	
	
; Flips horizontally a given rectangle of pixels that's on a larger canvas 
; (such as the entire screen).
;
; input:
;		DS:DI - pointer to pixel data
;		BX - height of image
;		DX - width of image
;		AX - width of canvas (e.g. width of entire screen, when flipping
;			 a rectangle in the video memory)
; output:
;		none
common_graphicsbase_flip_rectangle_horizontally_on_canvas:
	pusha
	
	push ax
	push bx
	push dx							; preserve input
	
	mov cx, ax						; CX := canvas width
	
	mov ax, bx						; AX := height
	dec ax							; AX := height - 1
	mov dx, cx
	mul dx							; DX:AX := (height-1)*(canvas width)
	
	pop dx
	pop bx
	pop ax							; restore input
	
	; for( i = 0; i < height; i++ ) {
	;     for( j = 0; i < width / 2; j++ ) {
	;         swap bmpData[i][j] and bmpData[i][width + j - 1];
	;     }
	; }
	
	; here, DI points to bmpData[0][0] (that is, beginning of first line)
	mov cx, -1
flip_horizontally_outer_loop:
	inc cx							; next line down
	cmp cx, bx						; did we reach height?
	je flip_horizontally_done		; yes, we're done
	; process this line
	push cx							; save outer loop counter
	push bx							; save height
	
	mov bx, -1
flip_horizontally_inner_loop:
	push dx							; [2] save width
	shr dx, 1						; DX := width / 2
	
	inc bx							; next pixel to the right
	cmp bx, dx						; did we reach width / 2?
	je flip_horizontally_inner_loop_done ; yes, we're done the inner loop
	; we're not done this horizontal yet

	pop dx							; [2] restore width
	mov si, di
	add si, dx						; SI := bmpData[i][width]
	dec si							; SI := bmpData[i][width-1]
	sub si, bx						; SI := bmpData[i][width-j-1]
	
	; process this byte
	; DI points to bmpData[i][0]
	; SI points to bmpData[i][width-j-1]
	push ax							; [1] save canvas width
	mov al, byte [ds:di+bx]			; AL := bmpData[i][j]
	mov ah, byte [ds:si]			; AH := bmpData[i][width-j-1]
	mov byte [ds:di+bx], ah
	mov byte [ds:si], al			; swap the bytes
	pop ax							; [1] restore canvas width
	jmp flip_horizontally_inner_loop	; next inner loop iteration
	
flip_horizontally_inner_loop_done:
	pop dx							; [2] restore width
	; here, AX = canvas width, as passed in
	add di, ax						; move DI down one line
	
	pop bx							; restore height
	pop cx							; restore outer loop counter
	jmp flip_horizontally_outer_loop	; next outer loop iteration
	
flip_horizontally_done:	
	popa
	ret
	

%endif
