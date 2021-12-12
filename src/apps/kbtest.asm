;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The KBTEST app.
; This app shows how to interact with Snowdrop OS's keyboard driver to check 
; key status.
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

LIST_END equ 1					; tells display loop to start iterating
	
message1: db "  Snowdrop OS keyboard driver test   ", 0
message2: db "         (Press ESC to exit)         ", 0
message3: db "NOTE: Extended (multi-byte) scancodes are not supported.", 0
message4: db "      This causes some keys to not be accessible individually.", 0

; array of all labels
labelStrings:	db 'F1', 0, 'F2', 0, 'F3', 0, 'F4', 0, 'F5', 0, 'F6', 0
				db 'F7', 0, 'F8', 0, 'F9', 0, 'F10', 0
				db 'PrtScr', 0 , 'ScrLck', 0
				db 'Insert', 0, 'Delete', 0, 'Home', 0, 'End', 0 
				db 'PgUp', 0, 'PgDn', 0
				db 'DownArrow', 0, 'RightArrow', 0
				db 'LeftArrow', 0, 'UpArrow', 0
				db '`', 0, '1', 0, '2', 0, '3', 0, '4', 0, '5', 0
				db '6', 0, '7', 0, '8', 0, '9', 0, '0', 0, '-', 0
				db '=', 0, 'BackSpace', 0
				db 'Tab', 0, 'Q', 0, 'W', 0, 'E', 0, 'R', 0, 'T', 0, 'Y', 0
				db 'U', 0, 'I', 0, 'O', 0, 'P', 0, '[', 0, ']', 0, '\', 0
				db 'CapsLock', 0, 'A', 0, 'S', 0, 'D', 0, 'F', 0, 'G', 0
				db 'H', 0, 'J', 0, 'K', 0, 'L', 0, ';', 0, "'", 0, 'Enter', 0
				db 'LeftShift', 0, 'Z', 0, 'X', 0, 'C', 0, 'V', 0, 'B', 0
				db 'N', 0, 'M', 0, ',', 0, '.', 0, '/', 0, 'RightShift', 0
				db 'LeftCtrl', 0, 'LeftAlt', 0, 'SpaceBar', 0
				db 'RightCtrl', 0, 'RightAlt', 0
				db 'NumLock', 0, 'Keypad/', 0, 'Keypad*', 0, 'Keypad-', 0,
				db 'Keypad7', 0, 'Keypad8', 0, 'Keypad9', 0
				db 'Keypad4', 0, 'Keypad5', 0, 'Keypad6', 0, 'Keypad+', 0, 
				db 'Keypad1', 0, 'Keypad2', 0, 'Keypad3', 0
				db 'Keypad0', 0, 'Keypad.', 0, 'KeypadEnter', 0
				db LIST_END

; array of all scancode values
scancodeList:	db COMMON_SCAN_CODE_F1
				db COMMON_SCAN_CODE_F2
				db COMMON_SCAN_CODE_F3
				db COMMON_SCAN_CODE_F4
				db COMMON_SCAN_CODE_F5
				db COMMON_SCAN_CODE_F6
				db COMMON_SCAN_CODE_F7
				db COMMON_SCAN_CODE_F8
				db COMMON_SCAN_CODE_F9
				db COMMON_SCAN_CODE_F10
				db COMMON_SCAN_CODE_PRINT_SCREEN
				db COMMON_SCAN_CODE_SCROLL_LOCK
				
				db COMMON_SCAN_CODE_INSERT
				db COMMON_SCAN_CODE_DELETE
				db COMMON_SCAN_CODE_HOME
				db COMMON_SCAN_CODE_END
				db COMMON_SCAN_CODE_PAGE_UP
				db COMMON_SCAN_CODE_PAGE_DOWN
				
				db COMMON_SCAN_CODE_DOWN_ARROW
				db COMMON_SCAN_CODE_RIGHT_ARROW
				db COMMON_SCAN_CODE_LEFT_ARROW
				db COMMON_SCAN_CODE_UP_ARROW
				
				db COMMON_SCAN_CODE_BACKQUOTE
				db COMMON_SCAN_CODE_NUMBER_1
				db COMMON_SCAN_CODE_NUMBER_2
				db COMMON_SCAN_CODE_NUMBER_3
				db COMMON_SCAN_CODE_NUMBER_4
				db COMMON_SCAN_CODE_NUMBER_5
				db COMMON_SCAN_CODE_NUMBER_6
				db COMMON_SCAN_CODE_NUMBER_7
				db COMMON_SCAN_CODE_NUMBER_8
				db COMMON_SCAN_CODE_NUMBER_9
				db COMMON_SCAN_CODE_NUMBER_0
				db COMMON_SCAN_CODE_MINUS
				db COMMON_SCAN_CODE_EQUALS
				db COMMON_SCAN_CODE_BACKSPACE
				
				db COMMON_SCAN_CODE_TAB
				db COMMON_SCAN_CODE_Q
				db COMMON_SCAN_CODE_W
				db COMMON_SCAN_CODE_E
				db COMMON_SCAN_CODE_R
				db COMMON_SCAN_CODE_T
				db COMMON_SCAN_CODE_Y
				db COMMON_SCAN_CODE_U
				db COMMON_SCAN_CODE_I
				db COMMON_SCAN_CODE_O
				db COMMON_SCAN_CODE_P
				db COMMON_SCAN_CODE_SQR_BRACKET_L
				db COMMON_SCAN_CODE_SQR_BRACKET_R
				db COMMON_SCAN_CODE_SQR_BACKSLASH
				
				db COMMON_SCAN_CODE_CAPS_LOCK
				db COMMON_SCAN_CODE_A
				db COMMON_SCAN_CODE_S
				db COMMON_SCAN_CODE_D
				db COMMON_SCAN_CODE_F
				db COMMON_SCAN_CODE_G
				db COMMON_SCAN_CODE_H
				db COMMON_SCAN_CODE_J
				db COMMON_SCAN_CODE_K
				db COMMON_SCAN_CODE_L
				db COMMON_SCAN_CODE_SEMICOLON
				db COMMON_SCAN_CODE_QUOTE
				db COMMON_SCAN_CODE_ENTER
				
				db COMMON_SCAN_CODE_LEFT_SHIFT
				db COMMON_SCAN_CODE_Z
				db COMMON_SCAN_CODE_X
				db COMMON_SCAN_CODE_C
				db COMMON_SCAN_CODE_V
				db COMMON_SCAN_CODE_B
				db COMMON_SCAN_CODE_N
				db COMMON_SCAN_CODE_M
				db COMMON_SCAN_CODE_COMMA
				db COMMON_SCAN_CODE_PERIOD
				db COMMON_SCAN_CODE_SLASH
				db COMMON_SCAN_CODE_RIGHT_SHIFT
				
				db COMMON_SCAN_CODE_LEFT_CONTROL
				db COMMON_SCAN_CODE_LEFT_ALT
				db COMMON_SCAN_CODE_SPACE_BAR
				db COMMON_SCAN_CODE_RIGHT_ALT
				db COMMON_SCAN_CODE_RIGHT_CONTROL
				
				db COMMON_SCAN_CODE_NUMLOCK
				db COMMON_SCAN_CODE_KEYPAD_SLASH
				db COMMON_SCAN_CODE_KEYPAD_ASTRISK
				db COMMON_SCAN_CODE_KEYPAD_MINUS
				db COMMON_SCAN_CODE_KEYPAD_7
				db COMMON_SCAN_CODE_KEYPAD_8
				db COMMON_SCAN_CODE_KEYPAD_9
				db COMMON_SCAN_CODE_KEYPAD_4
				db COMMON_SCAN_CODE_KEYPAD_5
				db COMMON_SCAN_CODE_KEYPAD_6
				db COMMON_SCAN_CODE_KEYPAD_PLUS
				db COMMON_SCAN_CODE_KEYPAD_1
				db COMMON_SCAN_CODE_KEYPAD_2
				db COMMON_SCAN_CODE_KEYPAD_3
				db COMMON_SCAN_CODE_KEYPAD_0
				db COMMON_SCAN_CODE_KEYPAD_PERIOD
				db COMMON_SCAN_CODE_KEYPAD_ENTER

padding:	db '   ' ,0
notPressed: db COMMON_ASCII_LIGHTEST, COMMON_ASCII_LIGHTEST, 0
pressed: 	db COMMON_ASCII_BLOCK, COMMON_ASCII_BLOCK, 0

start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 0A0h					; clear screen
	
	; print header
	mov bh, 0
	mov bl, 20
	mov si, message1
	call common_text_print_at
	inc bh
	mov si, message2
	call common_text_print_at	
	add bh, 2
	mov bl, 10
	mov si, message3
	call common_text_print_at
	inc bh
	mov si, message4
	call common_text_print_at
	
	; when expecting multiple keys pressed at once,
	; only Snowdrop's keyboard driver must be operating
	call common_keyboard_set_driver_mode_ignore_previous_handler
	
main_loop:
	mov bh, 7
	mov bl, 0
	int 9Eh						; move cursor

	mov si, labelStrings
	mov di, scancodeList
display_loop:
	cmp byte [ds:si], LIST_END	; are we at the end of our labels list?
	je done_display_loop		; yes, so we've displayed all keys
	
	push si						; [0] save label pointer

	; now check the keyboard driver for the key state
	mov bl, byte [ds:di]
	int 0BAh					; AL := key status
	cmp al, 0					; is it "not pressed"?

	je state_not_pressed		; yes
state_pressed:
	mov si, pressed
	int 97h						; print state
	jmp done_displaying_state
state_not_pressed:
	mov si, notPressed
	int 97h						; print state

done_displaying_state:
	pop si						; [0] restore label pointer
	int 97h						; print label
	
	push si
	mov si, padding
	int 97h						; print padding
	pop si

display_loop_next_string:
	lodsb						; AL := next label character
	cmp al, 0					; was it the end of the current label?
	jne display_loop_next_string	; no
	; here, SI = pointer to beginning of next label
	inc di						; position DI to next scan code value
	
	jmp display_loop			; next key
	
done_display_loop:
	; we're done displaying all labels
	mov cx, 1
	int 85h						; delay for a bit
	
	mov bl, COMMON_SCAN_CODE_ESCAPE
	int 0BAh
	cmp al, 0					; is ESCAPE pressed?
	je main_loop				; no
	; yes, it is pressed, so exit

done:
	call common_keyboard_restore_driver_mode

	int 95h						; exit


%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\keyboard.asm"
%include "common\text.asm"
