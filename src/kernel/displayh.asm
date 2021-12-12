;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains a text-mode CRT driver, interacting directly with the hardware.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vramCharacterOutputBuffer: db ' ', 0 ; used to display single characters 
									 ; as strings, directly to vram

; Reads the current hardware cursor position from the 6845 CRT controller
;
; output
;		BH - row
;		BL - column
display_get_hardware_cursor_position:
	push ax
	push dx
	
	mov al, 0Eh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Eh "cursor position MSB register"
	
	mov dx, 3D5h
	in al, dx			; read high byte from "cursor position MSB register"
	
	xchg ah, al			; AH := high byte of cursor position
	
	mov al, 0Fh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Fh "cursor position LSB register"

	mov dx, 3D5h
	in al, dx			; read low byte of "cursor position LSB register"
						; AL := low byte of cursor position
	; AX now contains the cursor position (offset)					
	
	mov bl, NUM_COLUMNS
	div bl				; AL := AX / NUM_COLUMNS
						; AH := AX % NUM_COLUMNS
	
	mov bh, al			; row (to return)
	mov bl, ah			; column (to return)
	
	pop dx
	pop ax
	ret


; Re-positions the hardware cursor by writing to the 6845 CRT controller
;
; input
;		BH - row
;		BL - column
display_move_hardware_cursor:
	pusha
	
	mov al, NUM_COLUMNS
	mul bh				; AX := NUM_COLUMNS * cursor row
	mov bh, 0			; BX := cursor column
	add bx, ax			; BX := (NUM_COLUMNS * cursor row) + cursor column
	
	mov al, 0Fh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Fh "cursor position LSB register"

	mov al, bl			; low byte of (NUM_COLUMNS * cursor row)+cursor column
	mov dx, 3D5h
	out dx, al			; write low byte to "cursor position LSB register"
	
	mov al, 0Eh
	mov dx, 3D4h
	out dx, al			; write to index register 3D4h to 
						; select register 0Eh "cursor position MSB register"
	
	mov al, bh			; high byte of (NUM_COLUMNS * cursor row)+cursor column
	mov dx, 3D5h
	out dx, al			; write high byte to "cursor position MSB register"
	
	popa
	ret
	
	
; Writes a zero-terminated string to the video ram
;
; input
;		DS:SI - pointer to first character of the string
display_vram_output_string:
	pusha
	push es
	
	push word 0B800h
	pop es

	call display_get_hardware_cursor_position ; BH - cursor row
											  ; BL - cursor column
	push bx					; save cursor position
	mov al, NUM_COLUMNS
	mul bh				; AX := NUM_COLUMNS * cursor row
	mov bh, 0			; BX := cursor column
	add ax, bx			; AX := (NUM_COLUMNS * cursor row) + cursor column
	shl ax, 1			; multiply by 2 due to 2 bytes per character
	; AX now contains the offset in the video buffer where we're putting
	; the string we have to print
	pop bx					; restore cursor position
	
	mov di, ax				; ES:DI now points to where we must put the string
	
display_vram_output_string_loop:
	mov al, byte [ds:si]	; read one character from input string
	inc si					; next character from input string
	cmp al, 0				; is it the terminator?
	je display_vram_output_string_done	; yes
	
display_vram_output_string_try_CR:
	cmp al, ASCII_CARRIAGE_RETURN	 ; is it CR?
	jne display_vram_output_string_try_BS ; no
									 ; yes, move cursor to beginning of line
	shl bl, 1						 ; each cursor position is 2 bytes
	mov ah, 0
	mov al, bl						 ; AX := 2*cursor column
	sub di, ax						 ; move buffer pointer to beginning of line
	mov bl, 0						 ; move cursor to beginning of line
	jmp display_vram_output_string_loop	 ; done, so display next character

display_vram_output_string_try_BS:
	cmp al, ASCII_BACKSPACE					; is it BS?
	jne display_vram_output_string_try_LF	; no
	; it is BS
	cmp bl, 0								; are we on the left-most column?
	je display_vram_output_string_loop		; yes
	
	sub di, 2								; move one position (2-byte) left
	mov al, ASCII_BLANK_SPACE				; "erase" existing character there
	mov byte [es:di], al					; store character
	
	dec bl									; move cursor left
	
	jmp display_vram_output_string_loop	 	; done, so display next character
	
display_vram_output_string_try_LF:
	cmp al, ASCII_LINE_FEED						; is it LF?
	jne display_vram_output_string_plain_character	; no
	inc bh										; yes, move cursor down
	add di, NUM_COLUMNS*2					; move buffer pointer down one line
											; (2 bytes per character)
	jmp display_vram_output_string_loop_check_scroll ; we may have scrolled

display_vram_output_string_plain_character:
	; now "print" the character to vram
	mov byte [es:di], al	; store character
	add di, 2				; next character from display buffer
							; (skipping over one attribute byte)
	inc bl					; advance cursor one position to the right
	cmp bl, NUM_COLUMNS		; are we past the right-hand edge of the screen?
	jne display_vram_output_string_loop	; no, so just display next character
	mov bl, 0				; yes, so move it to beginning of line
	inc bh					; and move it to the next line
	; flow into the part where we see if we have to scroll the screen
display_vram_output_string_loop_check_scroll:
	cmp bh, NUM_ROWS		; are we past the bottom-most line?
	jne display_vram_output_string_loop	; no, so just display next character
									; yes, so scroll screen
	
	push di							; save current DI
	mov di, 0						; move DI to beginning of buffer
	call display_scroll_buffer
	pop di							; restore current DI
	dec bh							; and put cursor on last line
	
	sub di, NUM_COLUMNS*2			; move buffer pointer up one line
									; (2 bytes per character)
	
	jmp display_vram_output_string_loop	; display next character
display_vram_output_string_done:
	; here, BH = cursor row after string was written
	;       BL = cursor column after string was written
	call display_move_hardware_cursor	; move hardware cursor

display_vram_output_string_return:	
	pop es
	popa
	ret


; Moves all lines of text in a virtual display up by one line.
; Fills bottom-most line with blank spaces.
;
; input
;		ES:DI - pointer to beginning of buffer to be scrolled
display_scroll_buffer:
	pusha
	push ds

	push cs
	pop ds
	
	mov cx, (NUM_ROWS-1)*NUM_COLUMNS	; we'll copy NUM_ROWS-1 lines upwards
display_scroll_buffer_loop:
	mov ax, word [es:di+NUM_COLUMNS*2]	; replace each character/attribute with
	mov word [es:di], ax				; the one underneath it (2 bytes per)
	add di, 2							; next character
	loop display_scroll_buffer_loop
	
	; DI now points to the beginning of the last line
	mov cx, NUM_COLUMNS
display_scroll_buffer_fill_bottom_line:
	mov byte [es:di], ASCII_BLANK_SPACE	; character
	mov byte [es:di+1], GRAY_ON_BLACK	; attribute
	add di, 2
	loop display_scroll_buffer_fill_bottom_line
	
	pop ds
	popa
	ret

	
; Writes an ASCII character to the vram
;
; input
;		AL - ASCII character to print
display_vram_output_character:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, vramCharacterOutputBuffer
	mov byte [ds:si], al					; our one-character string
	call display_vram_output_string
	
	pop ds
	popa
	ret
	

; input:
;		AL - byte to print
display_vram_print_byte:
	pusha
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call hex_digit_to_char
	call display_vram_output_character	; print tens digit
	
	mov al, ah
	call hex_digit_to_char
	call display_vram_output_character	; print units digit
	
	popa
	ret
	

; Prints a specified number of characters from a string	to vram
;
; input:
;		DS:SI -  pointer to string
;		CX - number of characters to print
display_vram_print_dump:
	pusha
	pushf
	
	cmp cx, 0							; if the character count is 0
	je display_vram_print_dump_done		; then this is a NOOP
	
	cld
display_vram_print_dump_loop:
	lodsb			; AL := byte at DS:SI
	call display_vram_output_character
	loop display_vram_print_dump_loop
display_vram_print_dump_done:
	popf
	popa
	ret


; Reads a character and attribute pair from vram
;
; input:
;		BH - cursor row
;		BL - cursor column
; output:
;		AH - attribute byte
;		AL - ASCII character byte
display_vram_read_character_attribute:
	push bx
	push cx
	push dx
	push si
	push ds
	
	push word 0B800h
	pop ds
	
	mov al, NUM_COLUMNS
	mul bh				; AX := NUM_COLUMNS * cursor row
	mov bh, 0			; BX := cursor column
	add ax, bx			; AX := (NUM_COLUMNS * cursor row) + cursor column
	shl ax, 1			; multiply by 2 due to 2 bytes per character
	; AX now contains the offset in the video buffer from where we're reading	
	mov si, ax
	mov ax, word [ds:si]	; return value (attributes and ASCII character)
	
	pop ds
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Writes an attribute byte to the video ram, repeating as specified
;
; input
;		CX - repeat this many times
;		DL - attribute byte
; output
;		none
display_vram_write_attribute:
	pusha
	push es
	
	push word 0B800h
	pop es

	call display_get_hardware_cursor_position ; BH - cursor row
											  ; BL - cursor column
	mov al, NUM_COLUMNS
	mul bh				; AX := NUM_COLUMNS * cursor row
	mov bh, 0			; BX := cursor column
	add ax, bx			; AX := (NUM_COLUMNS * cursor row) + cursor column
	shl ax, 1			; multiply by 2 due to 2 bytes per character
	; AX now contains the offset in the video buffer from where we're starting
	
	mov di, ax				; ES:DI now points to the beginning of the location
							; where we're painting
	inc di					; point ES:DI at the high (attribute) byte

	cmp cx, 0							; handle the 0-count case
	je display_vram_write_attribute_done	
display_vram_write_attribute_loop:
	; now write the attribute byte
	mov byte [es:di], dl	; store attribute byte
	add di, 2				; next character from display buffer
							; (skipping over one character byte)
	loop display_vram_write_attribute_loop	; next location

display_vram_write_attribute_done:
	pop es
	popa
	ret

	
; Clears the screen and positions the cursor on row 0, column 0
; Sets all attributes to light gray on black.
;
; input
;		none
; output
;		none
display_vram_clear_screen:
	pushf
	pusha
	push es
	
	push word 0B800h
	pop es
	mov di, 0							; ES:DI points at beginning of vram
	mov ah, GRAY_ON_BLACK				; attribute byte
	mov al, 0							; ASCII character byte
	mov cx, NUM_ROWS * NUM_COLUMNS		; this many words
	cld
	rep stosw
	
	mov bx, 0
	call display_move_hardware_cursor	; move cursor to (0, 0)
	
	pop es
	popa
	popf
	ret


; Dumps the vram to the specified buffer.
; The buffer must be able to store 4000 bytes (80 columns x 25 rows x 2 bytes).
;
; input
;	 ES:DI - pointer to where the vram will be dumped
; output
;		none
display_vram_dump_screen:
	pusha
	pushf
	push ds
	
	push word 0B800h
	pop ds
	mov si, 0					; we copy from B800:0000 to ES:DI
	mov cx, 4000				; this many bytes
	cld
	rep movsb					; perform the copy
	
	pop ds
	popf
	popa
	ret
