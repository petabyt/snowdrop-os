;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The SPRTEST app.
; This app exemplifies simple graphical sprites functionality, such as 
; creation and movement. It loads sprite pixel data from a 256-colour 
; BMP image.
;
; Furthermore, it synchronizes to the screen's vertical retrace to prevent 
; sprite flicker.
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

NUM_SPRITES equ 20
PRIMARY_SPRITE equ 5			; the sprite upon which user input will have
								; effect

message: db 13, 10, '       Snowdrop OS sprites example      '
		 db 13, 10, 'sprite 5: [A]-toggle horizontal flip    '
		 db 13, 10, '          [Z]-show [X]-hide   [ESC]-exit', 0
		
fat12Filename:		db "SPRTEST BMP", 0		; FAT12 format of the file name
BITMAP_SIZE equ 16

PIXELS_PER_DIRECTION equ 25		; how much sprites will move in each direction
movementDelta: dw 1							; pixels per frame
movementRemaining: dw PIXELS_PER_DIRECTION	; pixels before direction change

start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	mov si, fat12Filename
	mov di, fileContentsBuffer
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
	
	int 83h						; clear keyboard buffer
	
	call common_graphics_enter_graphics_mode
	call common_sprites_initialize
	call generate_background
	
	mov si, message
	call common_debug_print_string	; print message
	
	call generate_sprites

main_loop:
	hlt							; do nothing until an interrupt occurs
	mov ah, 1
	int 16h 					; any key pressed?
	jz main_loop_perform  		; no
	mov ah, 0					; yes
	int 16h						; read key, AH := scan code, AL := ASCII
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je done
	cmp ah, COMMON_SCAN_CODE_Z
	je show_sprite
	cmp ah, COMMON_SCAN_CODE_X
	je hide_sprite
	cmp ah, COMMON_SCAN_CODE_A
	je horizontally_flip_sprite

main_loop_perform:
	mov cx, 3
	int 85h							; delay

	call move_sprites

	call common_graphics_wait_vsync	; synchronize with vertical retrace
	call common_sprites_refresh		; redraw sprites right after vsync
	
	jmp main_loop					; loop again

show_sprite:
	mov al, PRIMARY_SPRITE
	call common_sprites_show
	jmp main_loop_perform			; finish up loop
	
hide_sprite:
	mov al, PRIMARY_SPRITE
	call common_sprites_hide
	jmp main_loop_perform			; finish up loop
	
horizontally_flip_sprite:
	mov al, PRIMARY_SPRITE
	call common_sprites_hflip_toggle
	jmp main_loop_perform			; finish up loop
	
done:
	call common_graphics_leave_graphics_mode
	int 95h							; exit


;------------------------------------------------------------------------------
; Procedures
;------------------------------------------------------------------------------

; Draw the background
;
; Input:
;		none
; Output:
;		none
generate_background:
	mov cx, 5 * COMMON_GRAPHICS_SCREEN_WIDTH
	mov bl, 112									; starting colour
	mov di, 40 * COMMON_GRAPHICS_SCREEN_WIDTH	; start location
generate_background_next_line:
	call common_graphics_draw_line_solid
	inc bl										; next colour
	
	add di, cx									; move down a few lines
	cmp di, COMMON_GRAPHICS_SCREEN_WIDTH * COMMON_GRAPHICS_SCREEN_HEIGHT
	jb generate_background_next_line
	
	; draw a few transparent lines
	mov bl, COMMON_GRAPHICS_COLOUR_TRANSPARENT
	mov di, 115 * COMMON_GRAPHICS_SCREEN_WIDTH	; start location
	mov cx, 10 * COMMON_GRAPHICS_SCREEN_WIDTH
	call common_graphics_draw_line_solid
	
	ret

; Move all sprites
;
; Input:
;		none
; Output:
;		none
move_sprites:
	pusha
	
	dec word [cs:movementRemaining]	; is it time to switch direction?
	jnz move_sprites_start			; no
	; switch direction
	neg word [cs:movementDelta]	; reverse direction
	mov word [cs:movementRemaining], PIXELS_PER_DIRECTION ; reset counter
move_sprites_start:
	mov al, 0
move_sprites_loop:
	mov bl, al
	and bl, 3							; BX := sprite number MOD 4
	
	; 4 different movements
	cmp bl, 0
	je move_sprites_0
	cmp bl, 1
	je move_sprites_1
	cmp bl, 2
	je move_sprites_2
	
	; single move, two directions
	call common_sprites_get_properties	; CX := X, DX := Y
	add cx, word [cs:movementDelta]		; move horizontally
	add dx, word [cs:movementDelta]		; move vertically
	call common_sprites_move			; perform move
	jmp move_sprites_loop_next
	
move_sprites_0:
	; two moves, one direction each
	call common_sprites_get_properties	; CX := X, DX := Y
	add cx, word [cs:movementDelta]		; move horizontally
	call common_sprites_move			; perform move
	
	call common_sprites_get_properties	; CX := X, DX := Y
	add cx, word [cs:movementDelta]		; move vertically
	call common_sprites_move			; perform move
	jmp move_sprites_loop_next
	
move_sprites_1:
	; two moves, one direction
	call common_sprites_get_properties	; CX := X, DX := Y
	add dx, word [cs:movementDelta]		; move vertically
	call common_sprites_move			; perform move
	
	call common_sprites_get_properties	; CX := X, DX := Y
	add dx, word [cs:movementDelta]		; move vertically
	call common_sprites_move			; perform move
	jmp move_sprites_loop_next
	
move_sprites_2:
	; two moves, two directions each
	call common_sprites_get_properties	; CX := X, DX := Y
	add cx, word [cs:movementDelta]		; move horizontally
	add dx, word [cs:movementDelta]		; move vertically
	call common_sprites_move			; perform move
	
	call common_sprites_get_properties	; CX := X, DX := Y
	add cx, word [cs:movementDelta]		; move horizontally
	add dx, word [cs:movementDelta]		; move vertically
	call common_sprites_move			; perform move
	jmp move_sprites_loop_next
	
move_sprites_loop_next:	
	inc al
	cmp al, NUM_SPRITES
	jne move_sprites_loop
	
	popa
	ret
	

; Generate all sprites
;
; Input:
;		none
; Output:
;		none
generate_sprites:
	pusha
	
	mov si, fileContentsBuffer
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data (8x8 pixels)
								; (calls farther down need pointer in DS:SI)
	mov al, 0
generate_sprites_loop:
	push ax						; save current sprite number
	
	int 86h						; AX := random
	and ax, 127					; AX := AX mod 128
	mov cx, ax					; CX := X
	add cx, 60					; shift it right a bit
	
	int 86h						; AX := random
	and ax, 63					; AX := AX mod 64
	mov dx, ax					; DX := Y
	add dx, 50					; shift it down a bit

	pop ax						; restore sprite number
	
	mov bl, BITMAP_SIZE			; sprite side size (sprites are square)
	call common_sprites_create

	inc al
	cmp al, NUM_SPRITES
	jne generate_sprites_loop

	popa
	ret


%include "common\bmp.asm"
%include "common\vga320\graphics.asm"
%include "common\vga320\sprites.asm"
%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\debug.asm"

fileContentsBuffer:				; the contents of the sprite BMP image will be
								; loaded here
