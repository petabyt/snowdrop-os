;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MPOLLRAW (Mouse Poll Raw) test app.
; This app is meant to show how to "manually" poll raw mouse data from
; a user program.
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

noMouseDriverMessage: 	db 'No mouse driver present. Exiting...', 0
introMessage:			db 'This program shows how manually poll raw mouse data bytes.', 13, 10, 13, 10, 0
lastPolledMessage:		db 13, '(PRESS [Q] TO EXIT) Last three raw mouse data bytes: ', 0
				; printing ASCII 13 is like pressing Home key
blankSpaceMessage:		db ' ', 0
oldKeyboardDriverMode:	dw 99
	
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
	
	mov si, introMessage
	int 80h	
again:
	mov si, lastPolledMessage
	int 80h						; print message
	
	int 8Ch						; poll raw mouse data
	; The above interrupt fills in the following registers with mouse data
	;		BH - bit 7 - Y overflow
	;			 bit 6 - X overflow
	;			 bit 5 - Y sign bit
	;			 bit 4 - X sign bit
	;			 bit 3 - unused and indeterminate
	;			 bit 2 - middle button
	;			 bit 1 - right button
	;			 bit 0 - left button
	;		DH - X movement (delta X)
	;		DL - Y movement (delta Y)
	
	mov al, bh					; AL := byte 0 of mouse data
	int 8Eh						; print byte in AL to screen
	mov si, blankSpaceMessage
	int 80h						; print a blank space
	
	mov al, dh					; AL := byte 1 of mouse data
	int 8Eh						; print byte in AL to screen
	mov si, blankSpaceMessage
	int 80h						; print a blank space
	
	mov al, dl					; AL := byte 2 of mouse data
	int 8Eh						; print byte in AL to screen
	
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

%include "common\scancode.asm"
