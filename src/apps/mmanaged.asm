;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MMANAGED (Mouse Managed) test app.
; This app is meant to show how to make use of the mouse manager, which keeps
; track of mouse position and button status, and can be polled by a consumer
; program.
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

oldKeyboardDriverMode:		dw 99

noMouseDriverMessage: 	db "No mouse driver present. Exiting...", 0
introMessage:			db "This program shows how to manually poll for the mouse's location within a user-defined bounding box.", 13, 10, 13, 10, 0
sizeMessage:			db "                          Bounding box size:  ", 0
lastPolledMessage:		db 13, "(PRESS [Q] TO EXIT) Buttons: [", 0
				; printing ASCII 13 is like pressing Home key
lastPolledMessage2:		db "] Location: (", 0
commaMessage:			db ", ", 0
lastPolledMessage3:		db ")", 0 ;
xMessage:				db "o", 0
blankSpaceMessage:		db " ", 0
newLineMessage:			db 13, 10

BOX_WIDTH 				equ 320
BOX_HEIGHT 				equ 200
	
start:
	int 83h						; clear keyboard buffer
	
	int 8Dh						; AL := mouse driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_mouse					; print error message and exit
	
	; use Snowdrop OS's keyboard driver
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:oldKeyboardDriverMode], ax	; save it
	mov ax, 1
	int 0BCh					; change keyboard driver mode
	
	mov bx, BOX_WIDTH			; width of bounding box
	mov dx, BOX_HEIGHT			; height of bounding box
	int 90h						; initialize mouse manager
	
	mov si, introMessage
	int 80h
	mov si, sizeMessage
	int 80h
	mov ax, BOX_WIDTH
	call print_word
	mov si, commaMessage
	int 80h
	mov ax, BOX_HEIGHT
	call print_word
	mov si, newLineMessage
	int 80h
again:
	mov si, lastPolledMessage
	int 80h						; print message
	
	int 8Fh						; poll mouse manager (returned values below)
	;		AL - bits 3 to 7 - unused and indeterminate
	;			 bit 2 - middle button current state
	;			 bit 1 - right button current state
	;			 bit 0 - left button current state
	;		BX - X position in user coordinates
	;		DX - Y position in user coordinates

	test al, 00000001b
	jnz left_click_down
	mov si, blankSpaceMessage
	int 80h
	jmp after_left_click
left_click_down:
	mov si, xMessage
	int 80h
after_left_click:

	test al, 00000100b
	jnz middle_click_down
	mov si, blankSpaceMessage
	int 80h
	jmp after_middle_click
middle_click_down:
	mov si, xMessage
	int 80h
after_middle_click:

	test al, 00000010b
	jnz right_click_down
	mov si, blankSpaceMessage
	int 80h
	jmp after_right_click
right_click_down:
	mov si, xMessage
	int 80h
after_right_click:
	
	mov si, lastPolledMessage2
	int 80h
	
	mov ax, bx
	call print_word				; print X position
	
	mov si, commaMessage
	int 80h
	
	mov ax, dx
	call print_word				; print Y position
	
	mov si, lastPolledMessage3
	int 80h
	
	mov cx, 5					; length of delay in ticks 
	int 85h						; cause delay
	
	mov bl, COMMON_SCAN_CODE_Q
	int 0BAh
	cmp al, 0					; not pressed?
	je again					; Q key was not pressed, so loop again
	jmp exit					; it was pressed, so we're done

no_mouse:
	mov si, noMouseDriverMessage
	int 80h						; print message
exit:
	mov ax, word [cs:oldKeyboardDriverMode]
	int 0BCh					; change keyboard driver mode
	int 95h						; exit


; Prints word in AX
print_word:
	xchg ah, al
	int 8Eh			; print byte in AL
	xchg ah, al
	int 8Eh			; print byte in AL
	ret

%include "common\scancode.asm"