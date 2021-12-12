;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The SNDTEST app.
; This app shows how to interact with Snowdrop OS's sound driver, in order
; to play sounds on the IBM PC internal speaker.
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

message1: db "  Snowdrop OS sound driver test   ", 0
message2: db "       (Press ESC to exit)        ", 0
instructions:	db "Press:    ", 13, 10, 13, 10
				db "         [Z]-clear sound queue                                         ", 13, 10, 13, 10
				db "         [A]-NORMAL mode sound                              [flat tone]", 13, 10, 13, 10
				db "         [S]-IMMEDIATE mode sound (plays immediately)       [flat tone]", 13, 10, 13, 10
				db "         [D]-EXCLUSIVE mode sound (removes all queued sounds,", 13, 10
				db "             plays immediately, and prevents other sounds from ", 13, 10
				db "             being queued while it plays)           [frequency shifted]", 0

start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 0A0h					; clear screen
	
	int 83h						; clear keyboard buffer

	; display text
	mov bh, 2
	mov bl, 22
	mov si, message1
	call common_text_print_at
	mov bh, 3
	mov bl, 22
	mov si, message2
	call common_text_print_at
	mov bh, 6
	mov bl, 6
	mov si, instructions
	call common_text_print_at
	
main_loop:
	; read keyboard
	hlt							; do nothing until an interrupt occurs
	mov ah, 1
	int 16h 					; any key pressed?
	jz main_loop  				; no
	mov ah, 0					; yes
	int 16h						; read key, AH := scan code, AL := ASCII
	
	; handle key presses
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je done						; it is ESCAPE, so exit
	cmp ah, COMMON_SCAN_CODE_Z
	je clear_queue				; clear queue
	cmp ah, COMMON_SCAN_CODE_A
	je add_sound_normal_mode	; add a sound if "A" is pressed
	cmp ah, COMMON_SCAN_CODE_S
	je add_sound_immediate_mode	; add another sound if "S" is pressed
	cmp ah, COMMON_SCAN_CODE_D
	je add_sound_exclusive_mode ; add another sound if "D" is pressed
	
	jmp main_loop				; unrecognized key - nothing to handle
	
add_sound_normal_mode:
	mov ch, COMMON_SOUND_MODE_NORMAL	; sound mode
	mov cl, 10					; duration in ticks
	mov dx, 0					; no per-frame frequency shift
	mov ax, 4063				; frequency (see int 89h documentation)
	int 0B9h
	jmp main_loop
	
add_sound_immediate_mode:
	mov ch, COMMON_SOUND_MODE_IMMEDIATE	; sound mode
	mov cl, 20					; duration in ticks
	mov dx, 0					; no per-frame frequency shift
	mov ax, 7239				; frequency (see int 89h documentation)
	int 0B9h
	jmp main_loop
	
add_sound_exclusive_mode:
	mov ch, COMMON_SOUND_MODE_EXCLUSIVE	; sound mode
	mov cl, 50					; duration in ticks
	mov dx, -40					; per-tick frequency shift, for a nice effect
	mov ax, 4063				; frequency (see int 89h documentation)
	int 0B9h
	jmp main_loop
	
clear_queue:
	int 0C1h					; clear any sounds
	jmp main_loop

done:
	int 95h							; exit


%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\debug.asm"
%include "common\text.asm"
%include "common\sound.asm"
