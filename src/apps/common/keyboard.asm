;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for interacting with the keyboard.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_KEYBOARD_
%define _COMMON_KEYBOARD_

keyboardOldKeyboardDriverMode: dw 0

; Saves the current keyboard driver configuration and configures the keyboard 
; driver to no longer invoke the previous handler.
; 
; Input:
;		none
; Output:
;		none
common_keyboard_set_driver_mode_ignore_previous_handler:
	pusha
	
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:keyboardOldKeyboardDriverMode], ax	; save it
								; set keyboard driver mode to no longer
								; call the previous keyboard handler
								
	mov ax, 1					; when expecting multiple keys pressed at once,
	int 0BCh					; only Snowdrop's keyboard driver must be 
								; present, so the BIOS handler must be disabled
	popa
	ret

	
; Saves the current keyboard driver configuration and configures the keyboard 
; driver to always invoke the previous (usually BIOS) handler.
; 
; Input:
;		none
; Output:
;		none
common_keyboard_set_driver_mode_delegate_to_previous_handler:
	pusha
	
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:keyboardOldKeyboardDriverMode], ax	; save it
								; set keyboard driver mode to no longer
								; call the previous keyboard handler							
	mov ax, 0					; mode
	int 0BCh					; set keyboard driver mode
	
	popa
	ret
	

; Restores a previously saved keyboard driver mode
; 
; Input:
;		none
; Output:
;		none
common_keyboard_restore_driver_mode:
	pusha
	
	mov ax, word [cs:keyboardOldKeyboardDriverMode]
	int 0BCh					; restore keyboard driver mode
	
	popa
	ret

	
; Stores keyboard driver mode locally
; 
; Input:
;		none
; Output:
;		none
common_keyboard_save_driver_mode:
	pusha
	
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:keyboardOldKeyboardDriverMode], ax	; save it
	
	popa
	ret
	

%endif
