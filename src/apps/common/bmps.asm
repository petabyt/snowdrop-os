;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains logic for saving 256-colour BMP images.
;
; This library is graphics library-agnostic in that it work with either the
; first, mode 13h 320x200 graphics library, as well as with the second,
; mode 12h 640x480 one.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BMPS_
%define _COMMON_BMPS_

COMMON_BMPS_PALETTE_ENTRY_COUNT		equ 256

COMMON_BMPS_FILE_HEADER_SIZE		equ 14
COMMON_BMPS_DIB_HEADER_SIZE			equ 40
COMMON_BMPS_COLOUR_TABLE_SIZE		equ COMMON_BMP_PALETTE_ENTRY_SIZE * COMMON_BMPS_PALETTE_ENTRY_COUNT


; Saves a pixel buffer as a BMP file to disk
;
; input:
;	 DS:SI - pointer to buffer where the BMP file will be written
;		AX - bitmap width
;		BX - bitmap height
;	 ES:DI - pointer to pixel data to save into the BMP file
;	 FS:DX - pointer to FAT12 file name
; output:
;		AX - status as follows:
;			0 = success
;			1 = failure: maximum number of files reached
;			2 = failure: disk full
common_bmps_write_to_file:
	pusha
	
	call common_bmps_write_to_buffer	; CX := BMP file size
	
	push ds
	pop es
	mov di, si				; ES:DI := pointer to BMP file in memory
	
	push fs
	pop ds
	mov si, dx				; DS:SI := FAT12 file name
	
	int 9Dh					; write file
	
	popa
	ret


; Creates a BMP file into the specified buffer
;
; input:
;	 DS:SI - pointer to buffer where the BMP file will be written
;		AX - bitmap width
;		BX - bitmap height
;	 ES:DI - pointer to pixel data to save into the BMP file
; output:
;		CX - size of BMP file written to buffer
common_bmps_write_to_buffer:
	pusha
	
	call _bmps_populate_file_header
	call _bmps_populate_DIB_header
	call _bmps_populate_colour_table
	call _bmps_populate_pixel_data
	call common_bmp_reverse_lines

	popa
	mov cx, word [ds:si+2]	; CX := BMP file size
	ret
	
	
; Write the pixel data to the bitmap file in memory.
;
; input:
;	 DS:SI - pointer to beginning of BMP file contents
;		AX - bitmap width
;		BX - bitmap height
;	 ES:DI - pointer to pixel data to save
; output:
;		none	
_bmps_populate_pixel_data:
	pusha
	pushf
	push ds
	push es
	
	mul bx						; DX:AX := total number of pixels
								; (also pixel data size, since each pixel
								; takes up one byte)
								; assume DX = 0
								
	mov cx, ax					; this many bytes
	
	push ds
	push es
	pop ds
	pop es
	xchg si, di					; DS:SI := ptr to pixel data to save
								; ES:DI := ptr to beginning of BMP file
	add di, COMMON_BMPS_FILE_HEADER_SIZE + COMMON_BMPS_DIB_HEADER_SIZE + COMMON_BMPS_COLOUR_TABLE_SIZE
								; ES:DI := ptr to pixel data in BMP file
	cld
	rep movsb
	
	pop es
	pop ds
	popf
	popa
	ret

	
; Write the BMP file header to the bitmap file in memory.
; It writes the Windows-flavoured, "BM"-prefixed header.
;
; input:
;	 DS:SI - pointer to beginning of BMP file contents
;		AX - bitmap width
;		BX - bitmap height
; output:
;		none	
_bmps_populate_file_header:
	pusha
	
	mul bx						; DX:AX := total number of pixels
								; (also pixel data size, since each pixel
								; takes up one byte)
								; assume DX = 0
	
	mov byte [ds:si+0], 'B'
	mov byte [ds:si+1], 'M'		; 2 bytes for signature
	
	mov word [ds:si+2], ax
	add word [ds:si+2], COMMON_BMPS_FILE_HEADER_SIZE + COMMON_BMPS_DIB_HEADER_SIZE + COMMON_BMPS_COLOUR_TABLE_SIZE
	mov word [ds:si+4], 0		; 4 bytes for total file size
	
	mov word [ds:si+6], 0		; 2 bytes reserved for writing application
	mov word [ds:si+8], 0		; 2 bytes reserved for writing application
	
	mov word [ds:si+10], COMMON_BMPS_FILE_HEADER_SIZE + COMMON_BMPS_DIB_HEADER_SIZE + COMMON_BMPS_COLOUR_TABLE_SIZE
	mov word [ds:si+12], 0		; 4 bytes for pixel data offset within file
	
	popa
	ret
	
	
; Write the DIB header to the bitmap file in memory.
; There are multiple DIB formats, and the one this library writes
; is the Windows-flavoured BITMAPINFOHEADER.
;
; input:
;	 DS:SI - pointer to beginning of BMP file contents
;		AX - bitmap width
;		BX - bitmap height
; output:
;		none	
_bmps_populate_DIB_header:
	pusha
	
	mov dword [ds:si+14], COMMON_BMPS_DIB_HEADER_SIZE
								; 4 bytes for (this) DIB header size
								; (windows BITMAPINFOHEADER is 40 bytes long)
	
	mov word [ds:si+18], ax
	mov word [ds:si+20], 0		; 4 bytes for width
	
	mov word [ds:si+22], bx
	mov word [ds:si+24], 0		; 4 bytes for height
	
	mov word [ds:si+26], 1		; 2 bytes for colour planes count
	
	mov word [ds:si+28], 8		; 2 bytes for bits-per-pixel (bpp)
	
	mov dword [ds:si+30], 0		; 4 bytes for compression scheme
								; (0=uncompressed)
	
	mov dword [ds:si+34], 0		; 4 bytes for raw size
								; (unused for uncompressed)
								
	mov dword [ds:si+38], 0		; 4 bytes for pixel-per-metre horizontal
	
	mov dword [ds:si+42], 0		; 4 bytes for pixel-per-metre vertical
	
	mov dword [ds:si+46], 0		; 4 bytes for palette size
								; (0=use 2^bpp)
								
	mov dword [ds:si+50], 0		; 4 bytes for important colour count
	
	popa
	ret

	
; Write the colour table to the bitmap file in memory.
; It uses current VGA palette.
;
; input:
;	 DS:SI - pointer to beginning of BMP file contents
; output:
;		none
_bmps_populate_colour_table:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov es, ax
	mov di, bmpsTempPaletteBuffer
	call common_graphics_save_current_palette_to_buffer	; save current palette
	
	; prepare to iterate
	add si, 54						; DS:SI := beginning of BMP colour table
	; here, ES:DI = beginning of VGA palette
	
	sub si, COMMON_BMP_PALETTE_ENTRY_SIZE		; move SI to -1 position
	sub di, COMMON_GRAPHICS_PALETTE_ENTRY_SIZE	; move DI to -1 position
	mov cx, COMMON_BMPS_PALETTE_ENTRY_COUNT		; this many entries
_bmps_populate_colour_table_loop:
	add si, COMMON_BMP_PALETTE_ENTRY_SIZE		; advance BMP palette entry
	add di, COMMON_GRAPHICS_PALETTE_ENTRY_SIZE	; advance VGA palette entry
	
	; BMP colour table entries are in the order: blue, green, red
	;      VGA palette entries are in the order: red, green, blue
	
	; BMP entries use all 8 bits
	; VGA entries use only 6 bits
	
	mov al, byte [es:di+2]
	shl al, 2									; convert 6-bit to 8-bit
	mov byte [ds:si+0], al						; BMP[blue] := VGA[blue]
	
	mov al, byte [es:di+1]
	shl al, 2									; convert 6-bit to 8-bit
	mov byte [ds:si+1], al						; BMP[green] := VGA[green]
	
	mov al, byte [es:di+0]
	shl al, 2									; convert 6-bit to 8-bit
	mov byte [ds:si+2], al						; BMP[red] := VGA[red]
	
	loop _bmps_populate_colour_table_loop		; next entry
	
	pop es
	pop ds
	popa
	ret
	

%include "bmp.asm"	
%include "gra_base.asm"

bmpsTempPaletteBuffer: times COMMON_BMPS_PALETTE_ENTRY_COUNT * COMMON_GRAPHICS_PALETTE_ENTRY_SIZE db 0

%endif
