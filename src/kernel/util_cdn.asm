;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains a utility for the user to press a key during a countdown.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

backspaceMessage: db 8, 0
carriageReturnMessage: db 13, 0
promptMessage:	db ' seconds'
				times 11 db 8	; enough Backspaces to return cursor
				db 0
utilCdnItoaTempBuffer: times 16 db 0

; Displays a message, and counts down a number of seconds, re-displaying 
; the message.
; When the counter reaches 0, or if user presses a certain key, it returns.
;
; input:
;		DS:SI - pointer to message string
;		BH - ASCII code of first possible key to press
;		BL - ASCII code of second possible key to press
;		DL - number of seconds to wait
; output:
;		AL - 1 if user pressed the key, 0 otherwise
utility_countdown_user_prompt:
	push ds
	
	push cs
	pop ds
	
	call debug_print_string		; display string
	
	call keyboard_clear_bios_buffer
	mov dh, 0					; DX := DL
utility_countdown_user_prompt_main_loop:
	push dx
	
	; now display seconds count
	pusha
	mov al, dl
	mov ah, 0
	mov dx, 0					; DX:AX := 32bit integer of seconds remaining
	mov si, utilCdnItoaTempBuffer	; DS:SI := buffer to store itoa result
	mov bl, 1					; formatting option 1: "leading spaces"
	int 0A2h 					; itoa
	add si, 6					; string is padded with spaces, so advance to
								; last three characters (since the counter
								; only goes up to 255)
	call debug_print_string		; display seconds count
	popa
	
	push si
	mov si, promptMessage
	call debug_print_string		; print last word of message
	pop si
	
	mov cx, 100					; wait one second
utility_countdown_user_prompt_delay:
	push cx
	; check key press
	mov ah, 1
	int 16h 					; is any key pressed ?
	jz utility_countdown_user_prompt_delay_no_key_pressed ; no key pressed
	
	mov ah, 0					; a key is pressed!
	int 16h						; read key
	cmp al, bh					; first possible key pressed?
	je utility_countdown_user_prompt_pressed ; yes
	cmp al, bl					; first possible key pressed?
	je utility_countdown_user_prompt_pressed ; yes
	; we didn't recognize the key

utility_countdown_user_prompt_delay_no_key_pressed:	
	mov cx, 1					; we're delaying one cycle at a time
	int 85h						; calling this 100 times is about a second
	
	pop cx						; restore counter
	dec cx
	cmp cx, 0
	jne utility_countdown_user_prompt_delay	; next delay
	
	; we've waited a second - now decrement seconds counter
	pop dx
	dec dx
	cmp dx, -1					; are we done looking at second 0?
	jne utility_countdown_user_prompt_main_loop	; no
	
	pop ds
	mov al, 0					; yes, user did not press the key
	ret
	
utility_countdown_user_prompt_pressed:
	pop cx						; we had an extra value on the stack
	pop dx						; we had an extra value on the stack
	
	pop ds
	mov al, 1					; user did press the key
	ret

