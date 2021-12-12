;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains a utility for reading input from the user.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INPUT_ASCII_BACKSPACE 		equ 8
INPUT_ASCII_TAB_CHARACTER 	equ 9
INPUT_ASCII_ESCAPE 			equ 27

userInputBuffer:	dw 0		; pointer (offset) to buffer provided by user
maxInputLength:		dw 0		; used to store maximum length of input	


; Reads characters from the keyboard into the specified buffer.
; It reads no more than the specified limit, and adds a terminator character
; of ASCII 0 at the end, once the user presses Enter to finish inputting.
; The specified buffer must have enough room for one more character than the
; specified count.
; Echoes typed characters to the current task's virtual display.
;
; input
;		CX - maximum number of characters to read
;	 ES:DI - pointer to buffer (must fit CX+1 characters)
; output
;		none
utilities_input_read_user_line:
	pusha
	pushf
	push ds
	
	cld
	push cs
	pop ds						; need to access variables
	
	mov word [userInputBuffer], di	; save pointer to buffer
	mov word [maxInputLength], cx	; save max string length
	
	; start reading characters into the buffer
	int 83h						; clear keyboard buffer
	
	call input_read_user_line_clear_buffer
	mov di, word [userInputBuffer]	; DI points to beginning of buffer
input_read_user_line_read_character:
	mov ah, 0
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	cmp al, 13				; ASCII for the Enter key
	je input_read_user_line_done	; process current line
	
	cmp al, 8				; ASCII for the Backspace key
	jne input_read_user_line_not_enter_not_backspace
	
	; process Backspace
	cmp di, word [userInputBuffer]
	je input_read_user_line_read_character	; if buffer is empty, 
											; Backspace does nothing
	
	; handle Backspace - erase last character
	dec di					; move buffer pointer back one 
	mov byte [es:di], 0		; and clear that last location to 0
	
	call input_print_character	; show the effect of Backspace on screen
	jmp input_read_user_line_read_character		; and read next character
	
input_read_user_line_not_enter_not_backspace:
	; the Enter or Backspace key was not pressed if we got here
	cmp al, 0								; non-printable characters are
	je input_read_user_line_read_character	; ignored (arrow, function keys)

	cmp al, INPUT_ASCII_ESCAPE				; ESCAPE is ignored
	je input_read_user_line_read_character
	
	mov bx, di
	sub bx, word [userInputBuffer]	; BX := current - beginning
	cmp bx, word [maxInputLength]
	jae input_read_user_line_read_character	; do nothing when buffer is full
											; but read again, for either
											; and Enter, or Backspace
	
	; store in buffer the character which was just typed
	stosb
	
	call input_print_character
	jmp input_read_user_line_read_character
input_read_user_line_done:
	mov byte [es:di], 0			; store terminator
	
	pop ds
	popf
	popa
	ret

	
; input:
;		AL - ASCII of character to print
input_print_character:
	pusha
	
	cmp al, INPUT_ASCII_BACKSPACE
	je input_print_character_backspace

	cmp al, INPUT_ASCII_TAB_CHARACTER
	je input_print_character_tab
	
	cmp al, 126		; last "type-able" ASCII code
	ja input_print_character_done
	cmp al, 32		; first "type-able" ASCII code
	jb input_print_character_done
	
	mov dl, al
	int 98h			; not a special character, so just print it
	jmp input_print_character_done
input_print_character_backspace:
	mov dl, al
	int 98h			; no longer a special character, so just print it
	jmp input_print_character_done
input_print_character_tab:
	mov dl, ' '		; we print tabs like blank spaces
	int 98h
	; flow into "done" below	
input_print_character_done:
	popa
	ret


; input:
;		ES:DI - pointer to buffer
input_read_user_line_clear_buffer:
	pusha
	pushf
	push ds
	
	mov di, word [userInputBuffer]
	
	push cs
	pop ds
	mov cx, word [maxInputLength]
	mov al, 0
	cld
	rep stosb					; fill current line buffer with NULLs
	
	pop ds
	popf
	popa
	ret
