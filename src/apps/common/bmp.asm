;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains logic for loading 256-colour BMP images.
;
; This library is graphics library-agnostic in that it work with either the
; first, mode 13h 320x200 graphics library, as well as with the second,
; mode 12h 640x480 one.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BMP_
%define _COMMON_BMP_

COMMON_BMP_PALETTE_ENTRY_SIZE equ 4			; 1 byte for each: blue, green, red
											; 1 reserved byte

; Loads and initializes a 256-colour BMP image from the specified file.
;
; input:
;		DS:SI pointer to 11-byte buffer containing 
;			  file name in FAT12 format
;		ES:DI pointer to where file data will be loaded
;			  (must not cross 64kb boundary)
; output:
;		AL - status (0=success, 1=not found)
;		CX - file size in bytes
common_bmp_load:
	push si
	push di
	push ds
	
	int 81h						; load file: AL = 0 when successful
								; CX = file size in bytes

	mov si, di
	push es
	pop ds						; DS:SI := ES:DI
	call common_bmp_reverse_lines
	
	pop ds
	pop di
	pop si
	ret
	

; Modifies pixel data so that lines are not in reverse order, as is
; standard in the BMP format.
; Modifications are made in-place.
;
; input:
;		DS:SI - pointer to beginning of BMP file contents
; output:
;		none
common_bmp_reverse_lines:
	pusha
	
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	
	call common_bmp_get_dimensions	; AX:BX := height of image
									; CX:DX := width of image
	
	call common_graphicsbase_flip_rectangle_buffer_vertically
	
	popa
	ret
	
	
; Returns a pointer to the BMP image's pixel data
;
; input:
;		DS:SI - pointer to beginning of BMP file contents
; output:
;		DS:DI - pointer to beginning of image pixel data
common_bmp_get_pixel_data_pointer:
	mov di, word [ds:si+10]			; DI := low word of pixel data offset
	add di, si						; offset from beginning of file beginning
	ret
	
	
; Gets the pixel height and width of the specified BMP image
;
; input:
;		DS:SI - pointer to beginning of BMP file contents
; output:
;		AX:BX - height of image
;		CX:DX - width of image
common_bmp_get_dimensions:
	mov bx, word [ds:si+22]
	mov ax, word [ds:si+24]
	
	mov dx, word [ds:si+18]
	mov cx, word [ds:si+20]
	ret

	
; Reads the palette of the specified BMP image into the specified buffer
;
; input:
;		DS:SI - pointer to beginning of BMP file contents
;		ES:DI - pointer to buffer where palette will be stored
;				must be able to store 768 bytes
; output:
;		none
common_bmp_read_palette:
	pusha
	
	add si, 14					; advance pointer to "remaining header size"
	mov ah, 0
	mov al, byte [ds:si]		; AX := remaining header bytes
	add si, ax					; advance pointer to palette data
	
	sub si, COMMON_BMP_PALETTE_ENTRY_SIZE		; move SI to -1 position
	sub di, COMMON_GRAPHICS_PALETTE_ENTRY_SIZE	; move DI to -1 position
	mov cx, COMMON_GRAPHICS_LARGEST_NR_OF_PALETTE_ENTRIES		; this many entries
common_bmp_read_palette_loop:
	add si, COMMON_BMP_PALETTE_ENTRY_SIZE		; advance BMP palette entry
	add di, COMMON_GRAPHICS_PALETTE_ENTRY_SIZE	; advance VGA palette entry

	; note that each BMP palette entry is 24-bit (with each red, green, blue 
	; colour taking up 8 bits), while each VGA palette entry is 18-bit (with 
	; each colour taking up 6 bits)
	; this means we have to convert down
	
	mov al, byte [ds:si+0]
	shr al, 2									; convert 8-bit to 6-bit
	mov byte [es:di+2], al						; VGA[blue] := BMP[blue]
	
	mov al, byte [ds:si+1]
	shr al, 2									; convert 8-bit to 6-bit
	mov byte [es:di+1], al						; VGA[green] := BMP[green]
	
	mov al, byte [ds:si+2]
	shr al, 2									; convert 8-bit to 6-bit
	mov byte [es:di+0], al						; VGA[red] := BMP[red]
	
	loop common_bmp_read_palette_loop			; next entry
	
	popa
	ret

	
; Returns a pointer to a 256 VGA palette created from the palette
; of the specified, loaded BMP file
;
; input:
;		DS:SI - pointer to BMP file data
; output:
;		DS:SI - pointer to BMP palette converted to VGA
common_bmp_get_VGA_palette_from_bmp:
	push es
	push di
	
	push cs
	pop es
	mov di, fromBmpPaletteBuffer	; ES:DI now points to where we'll read palette
	call common_bmp_read_palette	; read BMP palette into our buffer
	
	push cs
	pop ds
	mov si, fromBmpPaletteBuffer	; DS:SI := ptr to palette
	
	pop di
	pop es
	ret
	
	
%include "gra_base.asm"

fromBmpPaletteBuffer: times COMMON_GRAPHICS_LARGEST_PALETTE_TOTAL_SIZE db 0

%endif
