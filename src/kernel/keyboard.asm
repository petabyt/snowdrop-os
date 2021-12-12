;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the Snowdrop OS keyboard driver, which is meant to supplement 
; BIOS's int 16h ("keyboard services")
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

oldKeyboardHandlerSeg: dw 0
oldKeyboardHandlerOff: dw 0

KEY_RELEASED_EVENT_FLAG equ 80h	; when this bit is set, the key was released

KEY_STATE_NOT_PRESSED	equ 0
KEY_STATE_PRESSED 		equ 1
keyStateTable:	times 256 db KEY_STATE_NOT_PRESSED	; stores "pressed" or "not
													; pressed" for each key
keyStateTableAfterEnd:

; driver modes
MODE_PASS_THROUGH	equ 0	; off - delegate everything to previous handler
MODE_LOCAL_ONLY		equ 1	; on - ignore previous handler

keyboardDriverMode: dw MODE_PASS_THROUGH

; used to publish messages to notify subscribers of key status changes
KEYBOARD_KEY_STATUS_CHANGED_MESSAGE_SIZE	equ 4
	; byte 0 - 0     scan code
	;      1 - 1     status 0=released, 1=pressed
	;      2 - 2     0 when ASCII not available
	;      3 - 3     ASCII when available
keyboardKeyStatusChangedMessageBuffer:		times KEYBOARD_KEY_STATUS_CHANGED_MESSAGE_SIZE db 0
keyboardKeyStatusChangedMessageType:		db '_kkeyboard-status-changed', 0

; scan code to ASCII translation table
; format:
;     base scan code (1 byte)        base ASCII (1 byte)       shifted ASCII (1 byte)
keyboardScanCodeTranslationTable:
	; alphabet
	db SCAN_CODE_A, 'a', 'A'
	db SCAN_CODE_B, 'b', 'B'
	db SCAN_CODE_C, 'c', 'C'
	db SCAN_CODE_D, 'd', 'D'
	db SCAN_CODE_E, 'e', 'E'
	db SCAN_CODE_F, 'f', 'F'
	db SCAN_CODE_G, 'g', 'G'
	db SCAN_CODE_H, 'h', 'H'
	db SCAN_CODE_I, 'i', 'I'
	db SCAN_CODE_J, 'j', 'J'
	db SCAN_CODE_K, 'k', 'K'
	db SCAN_CODE_L, 'l', 'L'
	db SCAN_CODE_M, 'm', 'M'
	db SCAN_CODE_N, 'n', 'N'
	db SCAN_CODE_O, 'o', 'O'
	db SCAN_CODE_P, 'p', 'P'
	db SCAN_CODE_Q, 'q', 'Q'
	db SCAN_CODE_R, 'r', 'R'
	db SCAN_CODE_S, 's', 'S'
	db SCAN_CODE_T, 't', 'T'
	db SCAN_CODE_U, 'u', 'U'
	db SCAN_CODE_V, 'v', 'V'
	db SCAN_CODE_W, 'w', 'W'
	db SCAN_CODE_X, 'x', 'X'
	db SCAN_CODE_Y, 'y', 'Y'
	db SCAN_CODE_Z, 'z', 'Z'
	
	; first row
	db SCAN_CODE_BACKQUOTE, '`', '~'
	db SCAN_CODE_NUMBER_1, '1', '!'
	db SCAN_CODE_NUMBER_2, '2', '@'
	db SCAN_CODE_NUMBER_3, '3', '#'
	db SCAN_CODE_NUMBER_4, '4', '$'
	db SCAN_CODE_NUMBER_5, '5', '%'
	db SCAN_CODE_NUMBER_6, '6', '^'
	db SCAN_CODE_NUMBER_7, '7', '&'
	db SCAN_CODE_NUMBER_8, '8', '*'
	db SCAN_CODE_NUMBER_9, '9', '('
	db SCAN_CODE_NUMBER_0, '0', ')'
	db SCAN_CODE_MINUS, '-', '_'
	db SCAN_CODE_EQUALS, '=', '+'
	
	; second row
	db SCAN_CODE_SQR_BRACKET_L, '[', '{'
	db SCAN_CODE_SQR_BRACKET_R, ']', '}'
	db SCAN_CODE_BACKSPACE, 8, 8
	
	; third row
	db SCAN_CODE_SEMICOLON, ';', ':'
	db SCAN_CODE_QUOTE, "'", '"'
	
	; fourth row
	db SCAN_CODE_COMMA, ',', '<'
	db SCAN_CODE_PERIOD, '.', '>'
	db SCAN_CODE_SLASH, '/', '?'
	
	; fifth row
	db SCAN_CODE_SPACE_BAR, ' ', ' '
keyboardScanCodeTranslationTableEnd:
KEYBOARD_SCAN_CODE_TRANSLATION_TABLE_ENTRY_SIZE	equ 3		; in bytes


; Returns the current status (pressed or not pressed) of the specified key
;
; Input:
;		BL - scan code
; Output:
;		AL - pressed/not pressed status, as such:
;				0 - not pressed
;				otherwise pressed
;
keyboard_get_key_status:
	push bx
	mov bh, 0							; BX := BL
	
	mov al, byte [cs:keyStateTable+bx]	; AL := keyStateTable[BX]
	
	pop bx
	ret

	
; Changes the way the keyboard driver functions
;
; Input:
;		AX - driver mode, as follows:
;			0 - off; delegate everything to previous handler (BIOS usually)
;			1 - on; ignore previous handler
; Output:
;		none
;
keyboard_set_driver_mode:
	pusha

	; wait for all keys to be released
	pushf
	sti							; need hardware interrupts to still fire
keyboard_set_driver_mode_wait:
	call keyboard_clear_bios_buffer
	
	mov si, keyStateTable					; start from first key
keyboard_set_driver_mode_wait_loop:
	cmp byte [cs:si], KEY_STATE_PRESSED		; if we found a pressed key
	je keyboard_set_driver_mode_wait		; restart loop
	
	inc si									; next key
	cmp si, keyStateTableAfterEnd			; are we at the end?
	jb keyboard_set_driver_mode_wait_loop	; no, move to next key
	; we're past the end and no keys were pressed, so we're done
keyboard_set_driver_mode_wait_done:
	popf						; restore interrupt state
	
	mov word [cs:keyboardDriverMode], ax	; store mode

	popa
	ret
	
	
; Returns the current keyboard driver mode
;
; Input:
;		none
; Output:
;		AX - driver mode, as follows:
;			0 - off; delegate everything to previous handler (BIOS usually)
;			1 - on; ignore previous handler
;
keyboard_get_driver_mode:
	mov ax, word [cs:keyboardDriverMode]
	
	ret
	
	
; Initializes the keyboard driver by setting up data and installing the 
; keyboard driver's interrupt handler
;
; Input:
;		none
; Output:
;		none
;
keyboard_initialize:
	pusha
	push es
	
	; configure keyboard to be most responsive
	mov ax, 0305h				; function 03, sub-function 05: set typematic
								; rate
	mov bx, 0h					; most responsive
	int 16h						; set keyboard typematic rate
	
	; register our interrupt handler
	pushf
	cli							; we don't want interrupts firing before we've
								; saved the old handler address
	mov al, 9h					; we're registering for interrupt 9h
	push cs
	pop es
	mov di, keyboard_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)

	mov word [cs:keyboardDriverMode], MODE_PASS_THROUGH
	
	; save old handler address, so our handler can invoke it
	mov word [cs:oldKeyboardHandlerOff], bx	; save offset of old handler
	mov word [cs:oldKeyboardHandlerSeg], dx ; save segment of old handler
	popf						; restore interrupts state
	
	pop es
	popa
	ret
	
	
; We're installing this handler to interrupt 9. It will intercept and process 
; scan codes from the keyboard, followed by an invocation to the old handler.
;
keyboard_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	;--------------------------------------------------------------------------
	; BEGIN PAYLOAD (as in, what this handler is supposed to do)
	;--------------------------------------------------------------------------
	cmp word [cs:keyboardDriverMode], MODE_PASS_THROUGH	; do we perform at all?
	je keyboard_handler_invoke_previous					; no
	
	in al, 60h						; AL := scan code from keyboard controller

	mov dl, KEY_STATE_PRESSED			; DL := "this is a key press"
	
	test al, KEY_RELEASED_EVENT_FLAG	; is it a released key?
	jz keyboard_handler_store			; no, so store the press (AL=scan code)
	mov dl, KEY_STATE_NOT_PRESSED		; yes, so DL := "this is a key release"
	xor al, KEY_RELEASED_EVENT_FLAG		; clear pressed/release bit to set
										; AL to the scan code of the key
keyboard_handler_store:
	; here, AL = scan code of the key
	; here, DL = new state of the key
	mov bh, 0
	mov bl, al							; BX := AL
	mov byte [cs:keyStateTable+bx], dl	; keyStateTable[BX] := new state
	
	; notify consumers
	call keyboard_notify_key_status_changed
	
	; send EOI (End Of Interrupt) to the PIC, acknowledging that the 
	; hardware interrupt request has been handled
	;
	; when running in Real Mode, the PIC IRQs are as follows:
	; MASTER: IRQs 0 to 7, interrupt numbers 08h to 0Fh
	; SLAVE: IRQs 8 to 15, interrupt numbers 70h to 77h
	;
	mov al, 20h
	out 20h, al						; send EOI to master PIC
	
	jmp keyboard_handler_done		; we're done
	;--------------------------------------------------------------------------
	; END PAYLOAD
	;--------------------------------------------------------------------------

keyboard_handler_invoke_previous:
	; the idea is to simulate calling the old handler via an "int" opcode
	; this takes two steps:
	;     1. pushing FLAGS, CS, and return IP (3 words)
	;     2. far jumping into the old handler, which takes two steps:
	;         2.1. pushing the destination segment and offset (2 words)
	;         2.2. using retf to accomplish a far jump
	
	; push registers to simulate the behaviour of the "int" opcode

	pushf													; FLAGS
	push cs													; return CS
	push word keyboard_handler_old_handler_return_address	; return IP

	; invoke previous handler
	; use retf to simulate a 
	;     "jmp far [oldKeyboardHandlerSeg]:[oldKeyboardHandlerOff]"
	push word [cs:oldKeyboardHandlerSeg]
	push word [cs:oldKeyboardHandlerOff]
	retf						; invoke previous handler
	
	; old handler returns to the address immediately below
keyboard_handler_old_handler_return_address:
keyboard_handler_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Clear keyboard buffer 
;
; Input:
;		none
; Output:
;		none
;
keyboard_clear_bios_buffer:
	pusha
	; wait for shift, ALT, CTRL keys to be released
keyboard_clear_bios_buffer_special:
	mov ah, 2
	int 16h				; AL := shift flags
	test al, 00001111b	; are any shifts, CTRL, or ALT pressed?
	jnz keyboard_clear_bios_buffer_special	; yes, so keep waiting
	; wait for regular keypresses to be flushed out of the buffer
keyboard_clear_buffer_loop:
	mov ah, 1
	int 16h 		; any keys still in the buffer?
	jz keyboard_clear_buffer_done ; no, the buffer is now clear
	
	mov ah, 0
	int 16h			; read the key, clearing it from the buffer
	
	jmp keyboard_clear_buffer_loop	; see if there are more 
									; keys in the buffer
keyboard_clear_buffer_done:
	popa
	ret
	
	
; Notifies consumers that the status of a key has changed
;
; Input:
;		AL - scan code of key, with status flag cleared
;		DL - status: 0=released, 1=pressed
; Output:
;		none
;
keyboard_notify_key_status_changed:
	pusha
	push ds
	push es
	
	mov cx, cs
	mov ds, cx
	mov es, cx

	mov byte [cs:keyboardKeyStatusChangedMessageBuffer+0], al	; scan code
	mov byte [cs:keyboardKeyStatusChangedMessageBuffer+1], dl	; released/pressed
	
	call keyboard_translate_scan_code			; AH := ASCII
												; AL := 0 when unsuccessful
	mov byte [cs:keyboardKeyStatusChangedMessageBuffer+2], 0	; assume not translatable
	cmp al, 0
	je keyboard_notify_key_status_changed__publish
	mov byte [cs:keyboardKeyStatusChangedMessageBuffer+2], 1	; it's translatable
	mov byte [cs:keyboardKeyStatusChangedMessageBuffer+3], ah	; ASCII

keyboard_notify_key_status_changed__publish:
	mov cx, KEYBOARD_KEY_STATUS_CHANGED_MESSAGE_SIZE
	mov si, keyboardKeyStatusChangedMessageBuffer	; DS:SI := ptr to contents
	mov di, keyboardKeyStatusChangedMessageType	; ES:DI := ptr to type
	mov ah, 2									; function 2: publish
	int 0C4h									; publish message
	
	pop es
	pop ds
	popa
	ret
	

; Translates a scan code to ASCII, if possible.
; Takes current modifier keys into account (e.g. shift).
; Not all keys have an ASCII correspondent.
;
; Input:
;		AL - scan code of key, with status flag cleared
; Output:
;		AL - 0 when scan code is not translatable, other value otherwise
;			 (maybe because it's not yet supported)
;		AH - ASCII, when scan code is translatable
;	
keyboard_translate_scan_code:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	mov si, keyboardScanCodeTranslationTable - KEYBOARD_SCAN_CODE_TRANSLATION_TABLE_ENTRY_SIZE
			; SI := "-1"
keyboard_translate_scan_code_loop:
	cmp si, keyboardScanCodeTranslationTableEnd
	jae keyboard_translate_scan_code__not_found				; it's past end
	
	add si, KEYBOARD_SCAN_CODE_TRANSLATION_TABLE_ENTRY_SIZE	; next table entry
	cmp byte [cs:si+0], al
	jne keyboard_translate_scan_code_loop
	; this is a match
keyboard_translate_scan_code__found:
	; is it shifted?
	mov bl, SCAN_CODE_LEFT_SHIFT
	call keyboard_get_key_status				; AL := 0 when not pressed
	cmp al, 0
	jne keyboard_translate_scan_code__found__shifted
	
	mov bl, SCAN_CODE_RIGHT_SHIFT
	call keyboard_get_key_status				; AL := 0 when not pressed
	cmp al, 0
	jne keyboard_translate_scan_code__found__shifted

keyboard_translate_scan_code__found__not_shifted:
	mov ah, byte [cs:si+1]
	mov al, 1
	jmp keyboard_translate_scan_code__done
keyboard_translate_scan_code__found__shifted:
	mov ah, byte [cs:si+2]
	mov al, 1
	jmp keyboard_translate_scan_code__done
	
keyboard_translate_scan_code__not_found:
	mov al, 0										; "not found"
	
keyboard_translate_scan_code__done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	ret
