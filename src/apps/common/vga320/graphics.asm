;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains general graphics functionality.
;
; Routines here pertain to the VGA mode 13h, 320x200, 256 colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GRAPHICS_
%define _COMMON_GRAPHICS_

COMMON_GRAPHICS_PALETTE_ENTRIES equ COMMON_GRAPHICS_MODE13H_PALETTE_ENTRIES
COMMON_GRAPHICS_PALETTE_TOTAL_SIZE equ COMMON_GRAPHICS_MODE13H_PALETTE_TOTAL_SIZE

COMMON_GRAPHICS_COLOUR_TRANSPARENT equ 255

COMMON_GRAPHICS_SCREEN_WIDTH equ 320
COMMON_GRAPHICS_SCREEN_HEIGHT equ 200

initialVideoMode:	db 99	; this will store the video mode which was current
							; when we started up. we will later revert to it


; Saves the current video mode and puts the display in graphics mode
;
; Input:
;		none
; Output:
;		none
common_graphics_enter_graphics_mode:
	pusha
	
	; save initial video mode, so we can restore it when we exit
	mov ah, 0Fh					; function 0F gets current video mode
	int 10h						; get current video mode in AL
	mov byte [cs:initialVideoMode], al	; and save it
	
	mov ax, 13h 				; enter graphics mode 13h, 
	int 10h						; 320x200 pixels 8bit colour
	
	call common_graphics_save_current_palette	
					; save current palette, so we can restore it upon 
					; leaving graphics mode
	
	popa
	ret

	
; Leaves graphics mode, switching to whichever video mode was current
; before we entered graphics mode
;
; Input:
;		none
; Output:
;		none
common_graphics_leave_graphics_mode:
	pusha
	
	call common_graphics_restore_palette ; restore previously saved palette
	
	; restore video mode to what it was initially
	mov ah, 0
	mov al, byte [cs:initialVideoMode]
	int 10h
	
	popa
	ret
	

; Copies the pixel data of a rectangle from the video memory
; into the specified buffer.
;
; Input:
;		AX - height
;		DX - width
;		SI - position (offset in video memory)
;	 ES:DI - destination buffer
; Output:
;		none
common_graphics_copy_video_rectangle_to_buffer:
	pusha
	pushf
	push ds
	
	cld
	
	push word 0A000h
	pop ds					; DS now contains the video buffer segment
copy_video_rectangle_to_buffer_horizontal_line:	
	push si
	mov cx, dx
	rep movsb				; copy this horizontal line
	pop si
	
	add si, COMMON_GRAPHICS_SCREEN_WIDTH	; next horizontal line
	dec ax
	jnz copy_video_rectangle_to_buffer_horizontal_line
	
	pop ds
	popf
	popa
	ret

	
; Draw a horizontally flipped rectangle at the specified location.
; Skips transparent pixels.
;
; Input:
;		AX - height
;		DX - width
;		DI - position (offset in video memory)
;	 DS:BX - pointer to pixel colour data
;		SI - width of bitmap data (used to draw parts of the bitmap)
; Output:
;		none
common_graphics_draw_rectangle_hflipped_transparent:
	pusha
	mov cx, ax	; for each horizontal line (there are [height] of them)
draw_rectangle_hflipped_transparent_loop:	
	push cx
	mov cx, dx
	call common_graphics_draw_line_hflipped_transparent	
											; draw a BX wide horizontal line
	add di, COMMON_GRAPHICS_SCREEN_WIDTH	
								; move DI down one screen line, to 
								; the beginning of the next screen line
	add bx, si					; advance data pointer by one bitmap width
	pop cx						; restore loop counter
	loop draw_rectangle_hflipped_transparent_loop	; next horizontal line
	popa
	ret
	

; Draw a rectangle at the specified location.
; Skips transparent pixels.
;
; Input:
;		AX - height
;		DX - width
;		DI - position (offset in video memory)
;	 DS:BX - pointer to pixel colour data
;		SI - width of bitmap data (used to draw parts of the bitmap)
; Output:
;		none
common_graphics_draw_rectangle_transparent:
	pusha
	mov cx, ax	; for each horizontal line (there are [height] of them)
draw_rectangle_transparent_loop:	
	push cx
	mov cx, dx
	call common_graphics_draw_line_transparent
											; draw a BX wide horizontal line
	add di, COMMON_GRAPHICS_SCREEN_WIDTH	
								; move DI down one screen line, to 
								; the beginning of the next screen line
	add bx, si					; advance data pointer by one bitmap width
	pop cx						; restore loop counter
	loop draw_rectangle_transparent_loop	; next horizontal line
	popa
	ret

	
; Draw a rectangle at the specified location.
;
; Input:
;		AX - height
;		DX - width
;		DI - position (offset in video memory)
;	 DS:BX - pointer to pixel colour data
;		SI - width of bitmap data (used to draw parts of the bitmap)
; Output:
;		none
common_graphics_draw_rectangle_opaque:
	pusha
	mov cx, ax	; for each horizontal line (there are [height] of them)
draw_rectangle_opaque:
	push cx
	mov cx, dx
	call common_graphics_draw_line_opaque
											; draw a BX wide horizontal line
	add di, COMMON_GRAPHICS_SCREEN_WIDTH	
								; move DI down one screen line, to 
								; the beginning of the next screen line
	add bx, si					; advance data pointer by one bitmap width
	pop cx						; restore loop counter
	loop draw_rectangle_opaque	; next horizontal line
	popa
	ret


; Draw a rectangle at the specified location and using the specified colour
;
; Input:
;		AX - height
;		DX - width
;		DI - position (offset in video memory)
;		BL - colour
; Output:
;		none
common_graphics_draw_rectangle_solid:
	pusha
	mov cx, ax	; for each horizontal line (there are [height] of them)
procedure_draw_rectangle_solid_loop:
	push cx
	push di
	mov cx, dx
	call common_graphics_draw_line_solid	; draw a Bx wide horizontal line
	pop di						; restore DI to the beginning of this line	
	add di, COMMON_GRAPHICS_SCREEN_WIDTH	; move DI down one screen line, to 
								; the beginning of the next screen line
	pop cx						; restore loop counter
	loop procedure_draw_rectangle_solid_loop	
								; next horizontal line
	popa
	ret

	
; Draw a horizontal line, reading from a pixel colour buffer. 
; Skips transparent pixels.
; The line is horizontally flipped.
;
; Input: 
;		CX - line length
;		DI - position (offset in video memory)
;	 DS:BX - pointer to pixel colour data
; Output:
;		none
common_graphics_draw_line_hflipped_transparent:
	push ax
	push bx
	push cx
	push di
	push es
	
	add bx, cx	; BX now points to the byte right after the line's colour data
	dec bx		; BX now points to last colour data byte in the line
	
	mov ax, 0A000h					; video segment
	mov es, ax
common_graphics_draw_line_hflipped_transparent_loop:
	mov al, byte [ds:bx]			; load pixel colour from data buffer
	cmp al, COMMON_GRAPHICS_COLOUR_TRANSPARENT
	je common_graphics_draw_line_hflipped_transparent_next_pixel	
									; skip transparent pixels
	mov byte [es:di], al			; set A000:DI to the specified colour
common_graphics_draw_line_hflipped_transparent_next_pixel:	
	inc di							; move DI one pixel to the right
	dec bx							; data pointer--
	loop common_graphics_draw_line_hflipped_transparent_loop	; next pixel

	pop es
	pop di
	pop cx
	pop bx
	pop ax
	ret
	

; Draw a horizontal line, reading from a pixel colour buffer. 
; Skips transparent pixels.
;
; Input: 
;		CX - line length
;		DI - position (offset in video memory)
;	 DS:BX - pointer to pixel colour data
; Output:
;		none
common_graphics_draw_line_transparent:
	push ax
	push bx
	push cx
	push di
	push es
	
	mov ax, 0A000h					; video segment
	mov es, ax
common_graphics_draw_line_transparent_loop:
	mov al, byte [ds:bx]			; load pixel colour from data buffer
	cmp al, COMMON_GRAPHICS_COLOUR_TRANSPARENT
	je common_graphics_draw_line_transparent_next_pixel	
									; skip transparent pixels
	mov byte [es:di], al			; set A000:DI to the specified colour
common_graphics_draw_line_transparent_next_pixel:	
	inc di							; move DI one pixel to the right
	inc bx							; data pointer++
	loop common_graphics_draw_line_transparent_loop	; next pixel
	
	pop es
	pop di
	pop cx
	pop bx
	pop ax
	ret

	
; Draw a horizontal line, reading from a pixel colour buffer.
;
; Input: 
;		CX - line length
;		DI - position (offset in video memory)
;	 DS:BX - pointer to pixel colour data
; Output:
;		none
common_graphics_draw_line_opaque:
	push ax
	push bx
	push cx
	push di
	push es
	
	mov ax, 0A000h					; video segment
	mov es, ax
procedure_draw_line_opaque_loop:
	mov al, byte [ds:bx]			; load pixel colour from data buffer
	mov byte [es:di], al			; set A000:DI to the specified colour
	inc di							; move DI one pixel to the right
	inc bx							; data pointer++
	loop procedure_draw_line_opaque_loop ; next pixel
	
	pop es
	pop di
	pop cx
	pop bx
	pop ax
	ret


; Draw a horizontal line of a specified colour, from coordinates.
;
; Input:
;		BX - position X
;		AX - position Y
;		CX - line length
;		DL - colour
; Output:
;		none
common_graphics_draw_line_solid_by_coords:
	push ax
	push bx
	push di
	
	call common_graphics_coordinate_to_video_offset	; AX := vram offset
	mov di, ax
	mov bl, dl
	call common_graphics_draw_line_solid
	
	pop di
	pop bx
	pop ax
	ret
	
	
; Draw a horizontal line of a specified colour.
;
; Input: 
;		CX - line length
;		DI - position (offset in video memory)
;		BL - colour
; Output:
;		none
common_graphics_draw_line_solid:
	push ax
	push cx
	push di
	push es
	
	mov ax, 0A000h					; video segment
	mov es, ax
procedure_draw_line_solid_loop:
	mov byte [es:di], bl				; set A000:DI to the specified colour
	inc di								; move DI one pixel to the right
	loop procedure_draw_line_solid_loop	; next pixel
	
	pop es
	pop di
	pop cx
	pop ax
	ret

	
; Converts an (x,y) coordinate pair to an offset in video memory
; 
; Input:
;		AX - Y coordinate
;		BX - X coordinate
; Output:
;		AX - offset in video memory
common_graphics_coordinate_to_video_offset:
	push cx
	push dx
	
	mov cx, COMMON_GRAPHICS_SCREEN_WIDTH
	mul cx						; DX:AX := AX * CX
								; (assumption: DX = 0 here, because of sizes)
	add ax, bx
	
	pop dx
	pop cx
	ret

	
; Makes the specified palette active
;
; input:
;		DS:SI - pointer to palette to make active
; output:
;		none
common_graphics_load_palette:
	pusha
	pushf
	
	call common_graphics_wait_vsync		; synchronize before altering palette
	
	cli											; prevent interrupts
	mov dx, 03C8h
	mov al, 0									; we'll start writing from the
	out dx, al									; first DAC register (color 0)
	
	mov dx, 03C9h								; data port
	mov cx, COMMON_GRAPHICS_PALETTE_TOTAL_SIZE	; this many bytes	
	cld
	rep outsb									; output CX bytes to port DX
	
	popf
	popa
	ret


; Saves the current palette, using an internal buffer
;
; input:
;		none
; output:
;		none
common_graphics_save_current_palette:
	pusha
	push es

	push cs
	pop es
	mov di, previousPaletteBuffer			; ES:DI := destination buffer
	call common_graphics_save_current_palette_to_buffer
	
	pop es
	popa
	ret
	

; Saves the current palette to the specified buffer
;
; input:
;		ES:DI - pointer to buffer where the palette will be saved
; output:
;		none
common_graphics_save_current_palette_to_buffer:
	pusha
	pushf
	
	call common_graphics_wait_vsync		; synchronize before altering palette
	
	cli											; prevent interrupts
	mov dx, 03C7h
	mov al, 0									; we'll start reading from the
	out dx, al									; first DAC register (color 0)
	
	mov dx, 03C9h								; data port
	mov cx, COMMON_GRAPHICS_PALETTE_TOTAL_SIZE	; this many bytes	
	cld
	rep insb									; read in CX bytes to ES:DI
	
	popf
	popa
	ret
	

; Restores the previously saved palette
;
; input:
;		none
; output:
;		none
common_graphics_restore_palette:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, previousPaletteBuffer
	call common_graphics_load_palette
	
	pop ds
	popa
	ret
	
	
; Synchronize with the vertical retrace
; 
; Input:
;		none
; Output:
;		none
common_graphics_wait_vsync:
	pusha
	mov dx, 3DAh
vsync_wait_retrace_end:
	in al, dx
	test al, 00001000b
	jnz vsync_wait_retrace_end
vsync_wait_retrace_start:
	in al, dx
	test al, 00001000b
	jz vsync_wait_retrace_start
	popa
	ret
	

; Changes colour of all pixels to the specified colour
;
; Input:
;		BL - colour
; Output:
;		none
common_graphics_clear_screen_to_colour:
	pusha
	mov ax, COMMON_GRAPHICS_SCREEN_HEIGHT
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH
	mov di, 0
	call common_graphics_draw_rectangle_solid
	popa
	ret


; Flips entire screen horizontally
;
; input:
;		none
; output:
;		none		
common_graphics_flip_screen_horizontally:
	pusha
	push ds
	
	push word 0A000h
	pop ds
	mov di, 0								; we start from first pixel
	mov bx, COMMON_GRAPHICS_SCREEN_HEIGHT
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH
	call common_graphicsbase_flip_rectangle_horizontally_on_canvas

	pop ds
	popa
	ret
	
	
; Flips entire screen vertically
;
; input:
;		none
; output:
;		none		
common_graphics_flip_screen_vertically:
	pusha
	push ds
	
	push word 0A000h
	pop ds
	mov di, 0								; we start from first pixel
	mov bx, COMMON_GRAPHICS_SCREEN_HEIGHT
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH
	call common_graphicsbase_flip_rectangle_vertically_on_canvas

	pop ds
	popa
	ret


; Draw a horizontal line of a specified colour, from coordinates.
;
; Input:
;		BX - position X
;		AX - position Y
;		CX - line length
;		DL - colour
; Output:
;		none
common_graphics_draw_vertical_line_solid_by_coords:
	push ax
	push bx
	push di
	
	call common_graphics_coordinate_to_video_offset	; AX := vram offset
	mov di, ax
	mov bl, dl
	call common_graphics_draw_vertical_line_solid
	
	pop di
	pop bx
	pop ax
	ret

	
; Draws a vertical line of a specified colour.
;
; Input: 
;		CX - line length
;		DI - position (offset in video memory)
;		BL - colour
; Output:
;		none
common_graphics_draw_vertical_line_solid:
	push ax
	push cx
	push di
	push es
	
	mov ax, 0A000h					; video segment
	mov es, ax
draw_vertical_line_solid_loop:
	mov byte [es:di], bl					; colour pixel
	add di, COMMON_GRAPHICS_SCREEN_WIDTH	; move DI one pixel down
	loop draw_vertical_line_solid_loop		; next pixel
	
	pop es
	pop di
	pop cx
	pop ax
	ret


; Draws a rectangle outline at the specified location and using 
; the specified colour
;
; Input:
;		BX - position X
;		AX - position Y
;		CX - width
;		SI - height
;		DL - colour
; Output:
;		none	
common_graphics_draw_rectangle_outline_by_coords:
	pusha

	call common_graphics_coordinate_to_video_offset	; AX := offset in vram
	mov di, ax		; vram offset
	mov ax, si		; height
	mov bl, dl		; colour
	mov dx, cx		; width
	call common_graphics_draw_rectangle_outline
	
	popa
	ret
	

; Draws a rectangle outline at the specified location and using 
; the specified colour
;
; Input:
;		AX - height
;		DX - width
;		DI - position (offset in video memory)
;		BL - colour
; Output:
;		none
common_graphics_draw_rectangle_outline:
	pusha
	
	; left vertical
	mov cx, ax
	call common_graphics_draw_vertical_line_solid
	
	; right vertical
	push di
	add di, dx
	dec di
	call common_graphics_draw_vertical_line_solid
	pop di
	
	; top horizontal
	mov cx, dx
	call common_graphics_draw_line_solid
	
	; bottom horizontal
	push bx
	dec ax
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH
	mul bx
	add di, ax						; shift DI down AX-1 lines
	pop bx
	call common_graphics_draw_line_solid
	
	popa
	ret
	
	
; Draws a pixel from coordinates
;
; input: 
;		BX - position X
;		AX - position Y
;		DL - colour
; output:
;		none
common_graphics_draw_pixel_by_coords:
	push ax
	push bx
	push es

	call common_graphics_coordinate_to_video_offset		; AX := vram offset
	mov bx, ax
	
	mov ax, 0A000h
	mov es, ax
	mov byte [es:bx], dl
	
	pop es
	pop bx
	pop ax
	ret

%include "gra_base.asm"

; stores last active palette
previousPaletteBuffer: times COMMON_GRAPHICS_PALETTE_TOTAL_SIZE db 0

%endif
