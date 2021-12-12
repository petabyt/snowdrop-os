;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The RANDTEST app.
; This test app generates sequences of random numbers, and then plots a white 
; pixel whose coordinates are given by the each random number.
; It is used to examine the characteristics of Snowdrop OS's random number 
; generator.
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

DELAY_DIVISOR equ 4095		; pause after this many random numbers

message: 	db 13, 10, '                RANDTEST                '
			db 13, 10, '     random number generator tester     '
			db 13, 10
			db 13, 10, '[SPC]-restart [OTHER]-next    [ESC]-quit'
			db 13, 10
			db 13, 10
			db 13, 10, '          Press a key to start          ', 0

	
start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 83h						; clear keyboard buffer
	call common_graphics_enter_graphics_mode

	; print message and wait for a key
	mov si, message
	call common_debug_print_string	; print message
	int 83h						; clear keyboard buffer
	mov ah, 0
	int 16h						; block and wait for key
	
	push word 0A000h
	pop es						; ES := video memory segment
	
clear_screen_before_loop:
	mov bl, 0					; clear screen to black
	call common_graphics_clear_screen_to_colour
	
screen_loop:
	mov cx, 65535				; this many random numbers
pixel_loop:
	int 86h						; AX := random number
	mov bx, ax
	mov byte [es:bx], 14		; set colour of pixel at screen[random]
	
	push cx
	and cx, DELAY_DIVISOR		; every few thousand random numbers, pause
	cmp cx, DELAY_DIVISOR
	jne delay_done
	mov cx, 25
	int 85h						; delay
delay_done:
	pop cx
	
	loop pixel_loop				; next pixel
	
	; once we've generated a sequence, wait for user input
	mov ah, 0
	int 16h						; wait for key
	cmp ah, COMMON_SCAN_CODE_SPACE_BAR
	je clear_screen_before_loop	; if SPACE key is pressed, 
								; then clear screen and generate 
								; another sequence
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne screen_loop				; if ESCAPE is not pressed, 
								; then generate another sequence (without 
								; clearing screen)
	
	; we get here when ESCAPE was pressed, so we're done
	call common_graphics_leave_graphics_mode
	int 95h						; exit


%include "common\vga320\graphics.asm"
%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\debug.asm"
