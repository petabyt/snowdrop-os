;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for reading user input.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_INPUT_
%define _COMMON_INPUT_


COMMON_INPUT_ASCII_BACKSPACE 		equ 8
COMMON_INPUT_ASCII_TAB_CHARACTER 	equ 9
COMMON_INPUT_ASCII_ESCAPE 			equ 27

commonInputUserInputBufferOffset:	dw 0
					; pointer (offset) to buffer provided by user
commonInputMaxInputLength:		dw 0
					; used to store maximum length of input	

commonInputPrintCharBuffer:			times 2 db 0


; Reads characters from the keyboard into the specified buffer.
; It reads no more than the specified limit, and adds a terminator character
; of ASCII 0 at the end, once the user presses Enter to finish inputting.
; The specified buffer must have enough room for one more character than the
; specified count.
; Echoes typed characters to the hardware screen.
;
; input
;		CX - maximum number of characters to read
;	 ES:DI - pointer to buffer (must fit CX+1 characters)
; output
;		none
common_input_read_user_line_h:
	pusha
	pushf
	push ds
	
	cld
	push cs
	pop ds						; need to access variables
	
	mov word [commonInputUserInputBufferOffset], di	; save pointer to buffer
	mov word [commonInputMaxInputLength], cx	; save max string length
	
	; start reading characters into the buffer
	int 83h						; clear keyboard buffer
	
	call common_input_read_user_line_clear_buffer
	mov di, word [commonInputUserInputBufferOffset]	
										; DI points to beginning of buffer
common_input_read_user_line_read_character:
	hlt				; do nothing until an interrupt occurs
	mov ah, 1
	int 16h 									; any key pressed?
	jz common_input_read_user_line_read_character				; no
	
	mov ah, 0
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	cmp al, 13				; ASCII for the Enter key
	je common_input_read_user_line_done	; process current line
	
	cmp al, 8				; ASCII for the Backspace key
	jne common_input_read_user_line_not_enter_not_backspace
	
	; process Backspace
	cmp di, word [commonInputUserInputBufferOffset]
	je common_input_read_user_line_read_character	; if buffer is empty, 
											; Backspace does nothing
	
	; handle Backspace - erase last character
	dec di					; move buffer pointer back one 
	mov byte [es:di], 0		; and clear that last location to 0
	
	call common_input_print_character	; show the effect of Backspace on screen
	jmp common_input_read_user_line_read_character	; and read next character
	
common_input_read_user_line_not_enter_not_backspace:
	; the Enter or Backspace key was not pressed if we got here
	cmp al, 0								; non-printable characters are
	je common_input_read_user_line_read_character	; ignored

	cmp al, COMMON_INPUT_ASCII_ESCAPE				; ESCAPE is ignored
	je common_input_read_user_line_read_character
	
	mov bx, di
	sub bx, word [commonInputUserInputBufferOffset]	; BX := current - beginning
	cmp bx, word [commonInputMaxInputLength]
	jae common_input_read_user_line_read_character
											; do nothing when buffer is full
											; but read again, for either
											; and Enter, or Backspace
	
	; store in buffer the character which was just typed
	stosb
	
	call common_input_print_character
	jmp common_input_read_user_line_read_character
common_input_read_user_line_done:
	mov byte [es:di], 0			; store terminator
	
	pop ds
	popf
	popa
	ret

	
; input:
;		AL - ASCII of character to print
common_input_print_character:
	pusha
	
	cmp al, COMMON_INPUT_ASCII_BACKSPACE
	je common_input_print_character_backspace

	cmp al, COMMON_INPUT_ASCII_TAB_CHARACTER
	je common_input_print_character_tab
	
	cmp al, 126		; last "type-able" ASCII code
	ja common_input_print_character_done
	cmp al, 32		; first "type-able" ASCII code
	jb common_input_print_character_done
	
	mov dl, al
	call _common_input_print_char	; not a special character, so just print it
	jmp common_input_print_character_done
common_input_print_character_backspace:
	mov dl, al
	call _common_input_print_char
						; no longer a special character, so just print it
	jmp common_input_print_character_done
common_input_print_character_tab:
	mov dl, ' '		; we print tabs like blank spaces
	call _common_input_print_char
	; flow into "done" below	
common_input_print_character_done:
	popa
	ret


; input:
;		ES:DI - pointer to buffer
common_input_read_user_line_clear_buffer:
	pusha
	pushf
	push ds
	
	mov di, word [commonInputUserInputBufferOffset]
	
	push cs
	pop ds
	mov cx, word [commonInputMaxInputLength]
	mov al, 0
	cld
	rep stosb					; fill current line buffer with NULLs
	
	pop ds
	popf
	popa
	ret

	
; Prints a single character
;
; input:
;		DL - character to print
; output:
;		none	
_common_input_print_char:
	push ds
	push si
	push cs
	pop ds
	mov si, commonViewtxthPrintCharBuffer
	mov byte [ds:si], dl
	int 80h
	pop si
	pop ds
	ret
	
	
%endif
