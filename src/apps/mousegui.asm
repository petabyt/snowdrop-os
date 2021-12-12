;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MOUSEGUI app.
; This app is meant to show how to implement a graphical mouse cursor, relying
; on the kernel-provided PS/2 mouse driver (in "managed" mode).
;
; It uses the VGA 640x480 graphics (and related) libraries.
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop app contract:
;
; At startup, the app can assume:
;	- the app is loaded at offset 0
;	- all segment registers equal CS
;	- the stack is valid (SS, SP)
;	- BP equals SP
;	- direction flag is clear (string operations count upwards)
;
; The app must:
;	- call int 95h to exit
;	- not use the entire 64kb memory segment, as its own stack begins from 
;	  offset 0FFFFh, growing upwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16						; the CPU is assumed to function in 16-bit mode
	org 0						; apps are loaded at offset 0 by the caller

	jmp start

; each entry is a byte representing the colour of one pixel in 
; our 8x8-pixel mouse cursor
mouseCursorBitmap: db  0,  0,  0,  0,  0,  0,  0, 15
				   db  0, 14, 14, 14, 14,  0, 15, 15
				   db  0, 14, 14, 14,  0, 15, 15, 15
				   db  0, 14, 14, 14, 14,  0, 15, 15
				   db  0, 14,  0, 14, 14, 14,  0, 15
				   db  0,  0, 15,  0, 14, 14, 14,  0
				   db  0, 15, 15, 15,  0, 14,  0,  0
				   db 15, 15, 15, 15, 15,  0,  0, 15

BITMAP_SIZE equ 8

noMouseDriverMessage: 	db 'No mouse driver present. Exiting...', 0
message: 			db         ' SNOWDROP OS MOUSE DRIVER GUI EXAMPLE  '
					db 13, 10, '          (PRESS Q TO EXIT)             ', 0
						
oldKeyboardDriverMode:		dw 99
rectangleX:		dw 0
rectangleY:		dw 0		; used to generate pattern on screen
RECTANGLE_WIDTH		equ 16
RECTANGLE_HEIGHT	equ 16

start:
	int 8Dh						; AL := mouse driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_mouse					; print error message and exit

	;  make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	; use Snowdrop OS's keyboard driver
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:oldKeyboardDriverMode], ax	; save it
	mov ax, 1
	int 0BCh					; change keyboard driver mode
	
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH	; width of bounding box
	mov dx, COMMON_GRAPHICS_SCREEN_HEIGHT	; height of bounding box
	int 90h						; initialize mouse manager
	
	call common_graphics_enter_graphics_mode
	call common_sprites_initialize
	call generate_rectangles
	
	mov bx, 0						; X
	mov ax, 50						; Y
	mov dl, COMMON_GRAPHICS_COLOUR_DARK_GRAY
	mov cx, 310						; width
	mov di, 20						; height
	call common_graphics_draw_rectangle_solid
	
	mov si, message
	mov cl, COMMON_GRAPHICS_COLOUR_WHITE
	mov dx, 1						; options
	call common_graphics_text_print_at
	
	int 83h						; clear keyboard buffer
	
	; poll mouse once initially
	int 8Fh						; poll mouse manager
								; BX := X coordinate
								; DX := Y coordinate

	; create sprite
	mov si, mouseCursorBitmap	; DS:SI now points to the cursor bitmap
	mov cx, bx					; CX := X
								; DX = Y, from above
	mov al, 0					; sprite #0
	mov bl, BITMAP_SIZE			; sprite side size (sprites are square)
	call common_sprites_create
	
	
main_loop:
	int 8Fh						; poll mouse manager
								; BX := X coordinate
								; DX := Y coordinate
								; AL := buttons state
	; move sprite to where the mouse is
	mov al, 0					; sprite #0
	mov cx, bx					; X
								; Y is already in DX
	call common_sprites_move
	
	call common_graphics_wait_vsync	; synchronize with vertical retrace
	call common_sprites_refresh		; redraw sprites right after vsync
	
	mov bl, COMMON_SCAN_CODE_Q
	int 0BAh
	cmp al, 0					; not pressed?
	je main_loop				; Q key was not pressed, so loop again
	jmp done					; it was pressed, so we're done
	
no_mouse:
	mov si, noMouseDriverMessage
	int 80h						; print message
	int 95h						; exit

done:
	call common_graphics_leave_graphics_mode
	mov ax, word [cs:oldKeyboardDriverMode]
	int 0BCh					; change keyboard driver mode
	int 95h						; exit

;------------------------------------------------------------------------------
; Procedures
;------------------------------------------------------------------------------

; Render a bunch of rectangles, to create a background image
;
generate_rectangles:
	mov word [cs:rectangleX], 0
	mov word [cs:rectangleY], 0
	
	mov cx, COMMON_GRAPHICS_SCREEN_HEIGHT / RECTANGLE_HEIGHT
	mov dx, 0				; colour "alternator"
generate_rectangles_loop:
	push cx

	mov cx, COMMON_GRAPHICS_SCREEN_WIDTH / RECTANGLE_WIDTH
	inc dx					; change colour
generate_rectangles_horizontal_loop:
	inc dx					; change colour
	push dx					; save colour "alternator"
	
	and dl, 00000001b		
	add dl, 1				; alternate between colours
	
	pusha
	mov bx, word [cs:rectangleX]
	mov ax, word [cs:rectangleY]
	mov di, RECTANGLE_HEIGHT
	mov cx, RECTANGLE_WIDTH
	call common_graphics_draw_rectangle_solid
	popa
	
	pop dx
	add word [cs:rectangleX], RECTANGLE_WIDTH
	dec cx
	jnz generate_rectangles_horizontal_loop

	pop cx
	add word [cs:rectangleY], RECTANGLE_HEIGHT
	mov word [cs:rectangleX], 0	; bring it back to the left edge of the screen
	
	dec cx
	jnz generate_rectangles_loop
	
	ret
	
	
; configure sprites module
%ifndef _COMMON_SPRITES_LIMITS_
%define _COMMON_SPRITES_LIMITS_
COMMON_SPRITES_SPRITE_MAX_SIZE equ 16			; side length, in pixels
COMMON_SPRITES_MAX_SPRITES equ 5
%endif
	
%include "common\vga640\gra_text.asm"
%include "common\vga640\graphics.asm"
%include "common\vga640\sprites.asm"
%include "common\debug.asm"
%include "common\scancode.asm"
