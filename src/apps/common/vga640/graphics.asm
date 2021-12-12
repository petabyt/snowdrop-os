;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains general graphics functionality.
;
; This is the second graphics library written for Snowdrop OS.
; Routines here pertain to the VGA mode 12h, 640x480, 16 colours.
;
; The first and at least second libraries are implemented in parallel because
; their contracts are not compatible. The first library exposed too much
; of its implementation by way of requiring a pointer into video memory as
; an argument to many of its calls.
;
; This (second) library rectifies this.
; Additionally, its lower-level routines (e.g. line drawing) inline 
; pixel-level operations. This allows for far greater speed by requiring fewer
; memory accesses for register preservation.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GRAPHICS_
%define _COMMON_GRAPHICS_

COMMON_GRAPHICS_PALETTE_ENTRIES equ COMMON_GRAPHICS_MODE12H_PALETTE_ENTRIES
COMMON_GRAPHICS_PALETTE_TOTAL_SIZE equ COMMON_GRAPHICS_MODE12H_PALETTE_TOTAL_SIZE

COMMON_GRAPHICS_SCREEN_WIDTH	equ 640
COMMON_GRAPHICS_SCREEN_HEIGHT	equ 480

COMMON_GRAPHICS_MODE			equ 12h

initialVideoMode:	db 99	; this will store the video mode which was current
							; when we started up. we will later revert to it

COMMON_GRAPHICS_COLOUR_BLACK		equ 0
COMMON_GRAPHICS_COLOUR_BLUE			equ 1
COMMON_GRAPHICS_COLOUR_GREEN		equ 2
COMMON_GRAPHICS_COLOUR_CYAN			equ 3
COMMON_GRAPHICS_COLOUR_RED			equ 4
COMMON_GRAPHICS_COLOUR_WHITE		equ 5
COMMON_GRAPHICS_COLOUR_BROWN		equ 6
COMMON_GRAPHICS_COLOUR_LIGHT_GRAY	equ 7
COMMON_GRAPHICS_COLOUR_DARK_GRAY	equ 8
COMMON_GRAPHICS_COLOUR_MEDIUM_BLUE	equ 9
COMMON_GRAPHICS_COLOUR_LIGHT_GREEN	equ 10
COMMON_GRAPHICS_COLOUR_LIGHT_BLUE	equ 11
COMMON_GRAPHICS_COLOUR_ORANGE		equ 12
COMMON_GRAPHICS_COLOUR_PINK			equ 13
COMMON_GRAPHICS_COLOUR_YELLOW		equ 14
COMMON_GRAPHICS_COLOUR_PURPLE		equ 15	; when drawn opaquely
											; (ignoring transparency)

COMMON_GRAPHICS_COLOUR_TRANSPARENT	equ 15

commonGraphicsIHaveInitialized:		db 1	; assume I will do initialization


; Saves the current video mode and puts the display in graphics mode
;
; Input:
;		none
; Output:
;		none
common_graphics_enter_graphics_mode:
	pusha
	push ds
	
	mov ah, 0Fh							; function 0F is "get video mode" in AL
	int 10h
	cmp al, COMMON_GRAPHICS_MODE		; is it the right one?
	jne common_graphics_enter_graphics_mode_begin	; no, so we must proceed
	mov byte [cs:commonGraphicsIHaveInitialized], 0
	jmp common_graphics_enter_graphics_mode_done
	
common_graphics_enter_graphics_mode_begin:
	; save initial video mode, so we can restore it when we exit
	mov ah, 0Fh					; function 0F gets current video mode
	int 10h						; get current video mode in AL
	mov byte [cs:initialVideoMode], al	; and save it
	
	mov ax, COMMON_GRAPHICS_MODE	; enter graphics mode 12h, 
	int 10h							; 640x480, 16 colours
	
	call common_graphics_save_current_palette	
					; save current palette, so we can restore it upon 
					; leaving graphics mode
	; in 16 colour mode, colour 15 (last) is considered transparent
	;
	; since VGA adapters' colour 15 is usually pure white (which is used
	; frequently), we discard default colour 5 (dark magenta), and 
	; replace it with pure white
	
	; replace colour 5 with colour 15
	mov bl, byte [cs:previousPaletteBuffer+5*3+0]
	mov bh, byte [cs:previousPaletteBuffer+5*3+1]
	mov cl, byte [cs:previousPaletteBuffer+5*3+2]	; save old colour 5
	
	mov byte [cs:previousPaletteBuffer+5*3+0], 63
	mov byte [cs:previousPaletteBuffer+5*3+1], 63
	mov byte [cs:previousPaletteBuffer+5*3+2], 63	; make colour 5 white

	push cs
	pop ds
	mov si, previousPaletteBuffer
	call common_graphics_load_palette				; write palette to video
	
	mov byte [cs:previousPaletteBuffer+5*3+0], bl
	mov byte [cs:previousPaletteBuffer+5*3+1], bh
	mov byte [cs:previousPaletteBuffer+5*3+2], cl	; restore colour 5
	
common_graphics_enter_graphics_mode_done:
	pop ds
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

	cmp byte [cs:commonGraphicsIHaveInitialized], 0
	je common_graphics_leave_graphics_mode_done	; I haven't initialized
												; (maybe video mode was already
												; set by someone else)
	
	call common_graphics_restore_palette ; restore previously saved palette
	
	; restore video mode to what it was initially
	mov ah, 0
	mov al, byte [cs:initialVideoMode]
	int 10h
	
common_graphics_leave_graphics_mode_done:
	popa
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
	

; Draw a rectangle at the specified location and using the specified colour
;
; input: 
;		BX - position X
;		AX - position Y
;		DL - colour
;		CX - width
;		DI - height
; output:
;		none
common_graphics_draw_rectangle_solid:
	pusha
	
procedure_draw_rectangle_solid_loop:
	call common_graphics_draw_line_solid
	inc ax										; next line down
	dec di
	jnz procedure_draw_rectangle_solid_loop
	
	popa
	ret


; Draw a horizontal line of a specified colour.
; This function is optimized such that it will:
;     render single pixels up until an 8-pixel boundary
;     render all remaining whole 8-pixel groups in one shot
;     render remaining single pixels
;
; input: 
;		BX - position X
;		AX - position Y
;		DL - colour
;		CX - width
; output:
;		none
common_graphics_draw_line_solid:
	pusha
	push es
	push fs
	push gs

	mov gs, dx					; use GS to store passed-in colour
	
	mov dx, 0A000h
	mov es, dx
	
	mov di, cx					; use DI as the length counter
common_graphics_draw_line_solid_loop:
	; write pixel
	; inlined pixel drawing
	mov bp, ax					; [1] save Y
	mov fs, bx					; [2] save X

	; first, compute pointer to byte representing the 8-byte group 
	; we will affect by writing our pixel
	
	mov cx, COMMON_GRAPHICS_SCREEN_WIDTH/8
	mul cx						; AX := Y * resolution/8

	mov cl, bl					; CL := low X coordinate byte, used
								; to generate the bit mask
	shr bx, 3					; BX := X / 8
	add bx, ax					; ES:BX := ptr to 8-pixel group
								; (where offset ix X/8 + Y*SCREENWIDTH/8)

	; since we know all pixels we're drawing are of the same colour, we 
	; can attempt to draw 8 at a time, if we have at least 8 more to draw
	; 
	; BUT, we also have to be on an 8-pixel boundary
	mov dx, bx					; (save) DX := offset to 8-pixel group
	mov bx, fs					; BX := X
	test bx, 7					; X mod 8
	mov bx, dx					; (restore) ES:BX := ptr to 8-pixel group
	jnz common_graphics_draw_line_solid_loop__draw_one	; not on an 
														; 8-pixel boundary
	cmp di, 8
	jb common_graphics_draw_line_solid_loop__draw_one	; not enough pixels
common_graphics_draw_line_solid_loop__draw_eight:
	; we can draw a group of 8 at a time
	
	; build bit mask and write it to VGA controller
	mov ah, 0FFh				; all pixels of the group
	mov al, 8					; AL := index byte 8: "Bit Mask"

	mov dx, 3CEh
	out dx, ax					; write AH and AL to VGA controller
								; (AL to 3CEh, AH to 3CFh)

	; select read/write mode from VGA controller
	mov ax, 205h				; AL := index byte 5: "Graphics Mode Register"
								; AH := 2 ("read mode 0, write mode 2")
	out dx, ax					; select read mode 0, "OR" write mode
	
	mov ax, gs					; AL := pixel colour

	; we know there are at least 8 pixels ahead, but there could be more
	; so we must see how many groups of 8 we can write all at once
	; NOTE: the PUSHes here are O(1), since a single line has at most ONE
	;       contiguous run of 8-pixel groups
	push di						; [3] save remaining length
	mov cx, di
	shr cx, 3					; CX := (remaining length) div 8
								; we're writing this many groups at once
	mov dx, cx					; [4] save

	mov di, bx					; ES:DI := ptr to first 8-pixel group
	pushf
	cld
	rep stosb					; write this many 8-pixel groups
	popf	
	
	mov bx, fs					; [2] restore X
	mov ax, bp					; [1] restore Y
	
	mov cx, dx					; [4] (restore) CX := how many groups we wrote
	shl cx, 3					; CX := how many pixels we wrote
	add bx, cx					; X++
	
	pop di						; [3] DI := remaining length
	sub di, cx					; remaining length--
	jnz common_graphics_draw_line_solid_loop	; we still have pixels left
	
	jmp common_graphics_draw_line_solid_done
common_graphics_draw_line_solid_loop__draw_one:
	; build bit mask and write it to VGA controller
	and cl, 7					; CL := location of pixel within 8-pixel group
	xor cl, 7
	mov ah, 1
	shl ah, cl					; AH now represents the bit mask of the pixel
								; we're drawing, within its 8-pixel group
	mov al, 8					; AL := index byte 8: "Bit Mask"

	mov dx, 3CEh
	out dx, ax					; write AH and AL to VGA controller
								; (AL to 3CEh, AH to 3CFh)

	; select read/write mode from VGA controller
	mov ax, 205h				; AL := index byte 5: "Graphics Mode Register"
								; AH := 2 ("read mode 0, write mode 2")
	out dx, ax					; select read mode 0, "OR" write mode
	
	mov al, byte [es:bx]		; latch VGA register, to cause controller to 
								; refresh from RAM
	mov ax, gs					; AL := pixel colour
	mov byte [es:bx], al		; write colour to memory
	
	mov bx, fs					; [2] restore X
	mov ax, bp					; [1] restore Y
	
	inc bx						; X++
	
	dec di						; remaining length--
	jnz common_graphics_draw_line_solid_loop

common_graphics_draw_line_solid_done:
	pop gs
	pop fs
	pop es
	popa
	ret

	
; Draw a rectangle at the specified location.
;
; Input: 
;		BX - position X
;		AX - position Y
;		CX - width
;		DI - height
;	 DS:SI - pointer to pixel colour data
;		DX - width of bitmap data (used to draw parts of the bitmap)
; Output:
;		none
common_graphics_draw_rectangle_opaque:
	cmp di, 0
	je common_graphics_draw_rectangle_opaque_return
	
	pusha
draw_rectangle_opaque_loop:
	call common_graphics_draw_line_opaque
	inc ax							; move down one line on screen
	add si, dx						; advance through bitmap to next line
	dec di
	jnz draw_rectangle_opaque_loop
	popa
common_graphics_draw_rectangle_opaque_return:
	ret


; Draw a horizontal line, reading from a pixel colour buffer.
;
; Input: 
;		BX - position X
;		AX - position Y
;		CX - line length
;	 DS:SI - pointer to pixel colour data
; Output:
;		none
common_graphics_draw_line_opaque:
	pusha
	push es
	push fs
	
	mov dx, 0A000h
	mov es, dx
	
	mov di, cx					; use DI as the length counter
common_graphics_draw_line_opaque_loop:
	; write pixel
	; inlined pixel drawing
	mov bp, ax					; [1] save Y
	mov fs, bx					; [2] save X

	; first, compute pointer to byte representing the 8-byte group 
	; we will affect by writing our pixel
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH/8
	mul dx						; AX := Y * resolution/8

	mov cl, bl					; CL := low X coordinate byte, used
								; to generate the bit mask
	shr bx, 3					; BX := X / 8
	add bx, ax					; ES:BX := ptr to 8-pixel group

	; now build bit mask and write it to VGA controller
	and cl, 7					; CL := location of pixel within 8-pixel group
	xor cl, 7
	mov ah, 1
	shl ah, cl					; AH now represents the bit mask of the pixel
								; we're drawing, within its 8-pixel group
	mov al, 8					; AL := index byte 8: "Bit Mask"

	mov dx, 3CEh
	out dx, ax					; write AH and AL to VGA controller
								; (AL to 3CEh, AH to 3CFh)

	; select read/write mode from VGA controller
	mov ax, 205h				; AL := index byte 5: "Graphics Mode Register"
								; AH := 2 ("read mode 0, write mode 2")
	out dx, ax					; select read mode 0, "OR" write mode

	; output data
	mov al, byte [es:bx]		; latch VGA register, to cause controller to 
								; refresh from RAM
	mov al, byte [ds:si]		; AL := pixel colour
	mov byte [es:bx], al		; write colour to memory
	
	mov bx, fs					; [2] restore X
	mov ax, bp					; [1] restore Y
	
	inc bx						; next pixel to the right
	inc si						; move pointer
	
	dec di						; remaining length--
	jnz common_graphics_draw_line_opaque_loop

	pop fs
	pop es
	popa
	ret

	
; Copies the pixel data of a rectangle from the video memory
; into the specified buffer.
;
; Input:
;		BX - position X
;		AX - position Y
;		CX - width
;		SI - height
;	 ES:DI - destination buffer
; Output:
;		none
common_graphics_copy_video_rectangle_to_buffer:
	pusha
	push ds

	mov bp, bx						; save X
copy_video_rectangle_to_buffer_outer:
	push cx							; [2] save width
copy_video_rectangle_to_buffer_horizontal_line:
	; inlined pixel reading
	pusha
	
	mov cx, bx					; X
	mov dx, ax					; Y
	mov ah, 0Dh
	mov bh, 0					; page
	int 10h						; read pixel colour into AL

	mov byte [es:di], al	
	popa
	
	inc di							; move pointer in buffer
	inc bx							; X++
	loop copy_video_rectangle_to_buffer_horizontal_line
	
	pop cx							; [2] restore width
	mov bx, bp						; restore X
	inc ax							; next line down
	dec si							; height--
	jnz copy_video_rectangle_to_buffer_outer
	
	pop ds
	popa
	ret


; Draw a rectangle at the specified location.
; Skips transparent pixels.
;
; Input: 
;		BX - position X
;		AX - position Y
;		CX - width
;		DI - height
;	 DS:SI - pointer to pixel colour data
;		DX - width of bitmap data (used to draw parts of the bitmap)
; Output:
;		none
common_graphics_draw_rectangle_transparent:
	cmp di, 0
	je common_graphics_draw_rectangle_transparent_return
	
	pusha
draw_rectangle_transparent_loop:
	call common_graphics_draw_line_transparent
	inc ax							; move down one line on screen
	add si, dx						; advance through bitmap to next line
	dec di
	jnz draw_rectangle_transparent_loop
	popa
common_graphics_draw_rectangle_transparent_return:
	ret
	

; Draw a horizontal line, reading from a pixel colour buffer. 
; Skips transparent pixels.
;
; Input: 
;		BX - position X
;		AX - position Y
;		CX - line length
;	 DS:SI - pointer to pixel colour data
; Output:
;		none
common_graphics_draw_line_transparent:
	pusha
	push es
	push fs
	
	mov dx, 0A000h
	mov es, dx
	
	mov di, cx					; use DI as loop counter to reduce
								; memory accesses for register preservation
common_graphics_draw_line_transparent_loop:
	cmp byte [ds:si], COMMON_GRAPHICS_COLOUR_TRANSPARENT
	je common_graphics_draw_line_transparent_next_pixel	
	; write pixel
	
	; inlined pixel drawing
	mov bp, ax					; [1] save Y
	mov fs, bx					; [2] save X

	; first, compute pointer to byte representing the 8-byte group 
	; we will affect by writing our pixel
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH/8
	mul dx						; AX := Y * resolution/8

	mov cl, bl					; CL := low X coordinate byte, used
								; to generate the bit mask
	shr bx, 3					; BX := X / 8
	add bx, ax					; ES:BX := ptr to 8-pixel group

	; now build bit mask and write it to VGA controller
	and cl, 7					; CL := location of pixel within 8-pixel group
	xor cl, 7
	mov ah, 1
	shl ah, cl					; AH now represents the bit mask of the pixel
								; we're drawing, within its 8-pixel group
	mov al, 8					; AL := index byte 8: "Bit Mask"

	mov dx, 3CEh
	out dx, ax					; write AH and AL to VGA controller
								; (AL to 3CEh, AH to 3CFh)

	; select read/write mode from VGA controller
	mov ax, 205h				; AL := index byte 5: "Graphics Mode Register"
								; AH := 2 ("read mode 0, write mode 2")
	out dx, ax					; select read mode 0, "OR" write mode

	; output data
	mov al, byte [es:bx]		; latch VGA register, to cause controller to 
								; refresh from RAM
	mov al, byte [ds:si]		; AL := pixel colour
	mov byte [es:bx], al		; write colour to memory
	
	mov bx, fs					; [2] restore X
	mov ax, bp					; [1] restore Y
common_graphics_draw_line_transparent_next_pixel:
	inc bx						; next pixel to the right
	inc si						; move pointer
	
	dec di						; length remaining--
	jne common_graphics_draw_line_transparent_loop

	pop fs
	pop es
	popa
	ret


; Draw a horizontally flipped rectangle at the specified location.
; Skips transparent pixels.
;
; Input: 
;		BX - position X
;		AX - position Y
;		CX - width
;		DI - height
;	 DS:SI - pointer to pixel colour data
;		DX - width of bitmap data (used to draw parts of the bitmap)
; Output:
;		none
common_graphics_draw_rectangle_hflipped_transparent:
	cmp di, 0
	je common_graphics_draw_rectangle_hflipped_transparent_return
	
	pusha
draw_rectangle_hflipped_transparent_loop:
	call common_graphics_draw_line_hflipped_transparent
	inc ax							; move down one line on screen
	add si, dx						; advance through bitmap to next line
	dec di
	jnz draw_rectangle_hflipped_transparent_loop
	popa
common_graphics_draw_rectangle_hflipped_transparent_return:
	ret

	
; Draw a horizontal line, reading from a pixel colour buffer. 
; Skips transparent pixels.
; The line is horizontally flipped.
;
; Input: 
;		BX - position X
;		AX - position Y
;		CX - line length
;	 DS:SI - pointer to pixel colour data
; Output:
;		none
common_graphics_draw_line_hflipped_transparent:
	pusha
	
	add si, cx
	dec si							; start from last pixel
common_graphics_draw_line_hflipped_transparent_loop:
	mov dl, byte [ds:si]
	cmp dl, COMMON_GRAPHICS_COLOUR_TRANSPARENT
	je common_graphics_draw_line_hflipped_transparent_next_pixel	
	; write pixel
	call common_graphics_draw_pixel_by_coords
common_graphics_draw_line_hflipped_transparent_next_pixel:
	inc bx							; next pixel to the right
	dec si							; move pointer
	loop common_graphics_draw_line_hflipped_transparent_loop

	popa
	ret
	
	
; Draws a rectangle outline at the specified location and using 
; the specified colour
; The height and width include borders.
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

	push ax
	
	; top horizontal
	call common_graphics_draw_line_solid
	; bottom horizontal
	add ax, si
	dec ax
	call common_graphics_draw_line_solid
	pop ax
	
	; left vertical
	push cx
	
	mov cx, si
	call common_graphics_draw_vertical_line_solid_by_coords
	; right vertical
	pop cx
	add bx, cx
	dec bx
	mov cx, si
	call common_graphics_draw_vertical_line_solid_by_coords
	
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
	push cx
	push ax
	
common_graphics_draw_vertical_line_solid_by_coords_loop:
	call common_graphics_draw_pixel_by_coords
	inc ax
	loop common_graphics_draw_vertical_line_solid_by_coords_loop
	
	pop ax
	pop cx
	ret
	
	
; Changes colour of all pixels to the specified colour
;
; Input:
;		DL - colour
; Output:
;		none
common_graphics_clear_screen_to_colour:
	pusha
	pushf
	push es
	
	push dx						; [1]
	
	mov ah, 0FFh				; all pixels of this pixel group
	mov al, 8					; AL := index byte 8: "Bit Mask"

	mov dx, 3CEh
	out dx, ax					; write AH and AL to VGA controller
								; (AL to 3CEh, AH to 3CFh)

	; select read/write mode from VGA controller
	mov ax, 205h				; AL := index byte 5: "Graphics Mode Register"
								; AH := 2 ("read mode 0, write mode 2")
	out dx, ax					; select read mode 0, "OR" write mode
	
	; output data
	mov ax, 0A000h
	mov es, ax
	mov di, 0
	mov cx, COMMON_GRAPHICS_SCREEN_WIDTH * COMMON_GRAPHICS_SCREEN_HEIGHT / 16
								; although pixels are in groups of 8, we will
								; write a word at a time, to go even faster
	pop ax						; [1] AL := colour
	mov ah, al					;     AH := colour
	cld
	rep stosw
	
	pop es
	popf
	popa
	ret
	

; Returns the colour of the specified pixel
;
; input: 
;		BX - position X
;		AX - position Y
; output:
;		DL - pixel colour
common_graphics_read_pixel_by_coords:
	push ds
	pusha
	
	mov cx, bx					; X
	mov dx, ax					; Y
	mov ah, 0Dh
	mov bh, 0					; page
	int 10h						; read pixel colour into AL
	mov ds, ax					; move it in here temporarily,
								; so we can rely on pusha/popa
	popa
	mov dx, ds
	pop ds
	ret
	
	
; Draws a pixel from coordinates
; Preserves no registers
;
; input: 
;		BX - position X
;		AX - position Y
;		DL - colour
; output:
;		none
common_graphics_draw_pixel_by_coords:
	pusha
	push es

	push dx						; [1] save colour
	
	mov dx, 0A000h
	mov es, dx
	
	; first, compute pointer to byte representing the 8-byte group 
	; we will affect by writing our pixel
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH/8
	mul dx						; AX := Y * resolution/8

	mov cl, bl					; CL := low X coordinate byte, used
								; to generate the bit mask
	shr bx, 3					; BX := X / 8
	add bx, ax					; ES:BX := ptr to 8-pixel group

	; now build bit mask and write it to VGA controller
	and cl, 7					; CL := location of pixel within 8-pixel group
	xor cl, 7
	mov ah, 1
	shl ah, cl					; AH now represents the bit mask of the pixel
								; we're drawing, within its 8-pixel group
	mov al, 8					; AL := index byte 8: "Bit Mask"

	mov dx, 3CEh
	out dx, ax					; write AH and AL to VGA controller
								; (AL to 3CEh, AH to 3CFh)

	; select read/write mode from VGA controller
	mov ax, 205h				; AL := index byte 5: "Graphics Mode Register"
								; AH := 2 ("read mode 0, write mode 2")
	out dx, ax					; select read mode 0, "OR" write mode

	; output data
	mov al, byte [es:bx]		; latch VGA register, to cause controller to 
								; refresh from RAM
	pop ax						; [1] AL := colour
	mov byte [es:bx], al		; write colour to memory
	
	pop es
	popa
	ret
	
	
%include "common\gra_base.asm"

; stores last active palette
previousPaletteBuffer: times COMMON_GRAPHICS_PALETTE_TOTAL_SIZE db 0

%endif
