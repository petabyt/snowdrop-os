;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The ANISPRT app.
; This app shows how to load and display an animated sprite, from a BMP image 
; file containing multiple animation frames.
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

message: db 13, 10, '  Snowdrop OS animated sprites example  '
		 db 13, 10, '320x200x256 version  (press ESC to exit)', 0
		
fat12Filename:		db "ANISPRT BMP", 0		; FAT12 format of the file name
ANIMATION_FRAMES equ 14
ANIMATION_FRAMES_DELAY equ 2
BITMAP_WIDTH equ 16

HORIZONTAL_LINE_LENGTH equ 100

start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	; load the BMP file which stores our sprite data
	mov si, fat12Filename
	mov di, fileContentsBuffer
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
	
	int 83h						; clear keyboard buffer
	
	call common_graphics_enter_graphics_mode
	call common_sprites_initialize

	call generate_background
	call generate_sprite

main_loop:
	mov ah, 1
	int 16h 					; any key pressed?
	jz main_loop_perform  		; no
	mov ah, 0					; yes
	int 16h						; read key, AH := scan code, AL := ASCII
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je done						; it is ESCAPE, so exit
	
	; it isn't Escape, so perform the main loop
main_loop_perform:
	mov cx, 3
	int 85h							; delay

	call common_sprites_animate_all	; advance animation frames for sprites
	call common_graphics_wait_vsync	; synchronize with vertical retrace
	call common_sprites_refresh		; redraw sprites right after vsync
	
	jmp main_loop					; loop again

done:
	call common_graphics_leave_graphics_mode
	int 95h							; exit


;------------------------------------------------------------------------------
; Procedures
;------------------------------------------------------------------------------	

; Draw the background.
;
; Input:
;		none
; Output:
;		none
generate_background:
	pusha
	
	; clear screen to colour
	mov bl, 197					; background colour
	call common_graphics_clear_screen_to_colour
	
	; draw horizontal line
	mov ax, COMMON_GRAPHICS_SCREEN_HEIGHT/2 + BITMAP_WIDTH/2 - 1 ; Y location
	mov bx, COMMON_GRAPHICS_SCREEN_WIDTH/2 - HORIZONTAL_LINE_LENGTH/2 ; X loc.
	call common_graphics_coordinate_to_video_offset	; AX := video memory offset
	mov di, ax					; DI := video memory offset
	mov cx, HORIZONTAL_LINE_LENGTH
	mov bl, 124					; line colour
	call common_graphics_draw_line_solid
	
	mov si, message
	call common_debug_print_string	; print message
	
	popa
	ret

; Generate our sprite. Sprite 0 will be used.
;
; Input:
;		none
; Output:
;		none
generate_sprite:
	pusha
	
	mov si, fileContentsBuffer
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)

	mov cx, COMMON_GRAPHICS_SCREEN_WIDTH/2 - BITMAP_WIDTH/2		; X location
	mov dx, COMMON_GRAPHICS_SCREEN_HEIGHT/2 - BITMAP_WIDTH/2	; Y location
	mov bl, BITMAP_WIDTH		; sprite side size (sprites are square)
	mov al, 0					; sprite 0
	call common_sprites_create
	
	mov bl, ANIMATION_FRAMES	; number of animation frames
	mov cx, ANIMATION_FRAMES_DELAY ; video frames between animation changes
	call common_sprites_set_animation_params
	call common_sprites_animate		; start animating this sprite

	popa
	ret


; configure sprites module
%ifndef _COMMON_SPRITES_LIMITS_
%define _COMMON_SPRITES_LIMITS_
COMMON_SPRITES_SPRITE_MAX_SIZE equ 16			; side length, in pixels
COMMON_SPRITES_MAX_SPRITES equ 5
%endif

%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\bmp.asm"
%include "common\vga320\graphics.asm"
%include "common\vga320\sprites.asm"
%include "common\debug.asm"

fileContentsBuffer:				; the contents of the sprite BMP image will be
								; loaded here
