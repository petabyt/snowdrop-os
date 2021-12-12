;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains a text-mode virtual display driver, interacting with virtual
; displays.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

virtualDisplayCharacterOutputBuffer: db ' ', 0 
									; used to display single characters as
									; strings, to a specified virtual display

; Return the cursor position in a virtual display
;
; input
;		AX - ID (offset) of virtual display whose cursor we're polling
; output
;		BH - cursor row
;		BL - cursor column
display_get_cursor_position:
	push si
	push ds
	
	push cs
	pop ds
	
	mov si, displayTable
	add si, ax
	mov bh, byte [ds:si+2]
	mov bl, byte [ds:si+3]
	
	pop ds
	pop si
	ret


; Set the cursor position in a virtual display
;
; input
;		AX - ID (offset) of virtual display whose cursor we're setting
; output
;		BH - cursor row
;		BL - cursor column
display_set_cursor_position:
	push si
	push ds
	
	push cs
	pop ds
	
	mov si, displayTable
	add si, ax
	mov byte [ds:si+2], bh
	mov byte [ds:si+3], bl
	
	pop ds
	pop si
	ret
	

; Writes a zero-terminated string to the specified virtual display
;
; input
;		DS:SI - pointer to first character of the string
;		AX - virtual display ID where we're writing the string
display_output_string:
	pusha
	push es
	
	push cs
	pop es
	
	mov di, displayTable
	add di, ax				; DI now points to the beginning of 
							; current task's display slot
							
	push di					; save pointer to beginning of display slot
							
	mov al, NUM_COLUMNS
	mul byte [es:di+2]		; AX := NUM_COLUMNS * cursor row
	mov bh, 0
	mov bl, byte [es:di+3]	; BX := cursor column
	add ax, bx				; AX := (NUM_COLUMNS * cursor row) + cursor column
	
	shl ax, 1				; multiply by 2 due to 2 bytes per character
	
	; AX now contains the offset in the video buffer where we're putting
	; the string we have to print
	
	mov bh, byte [es:di+2]	; BH := cursor row
							; BL = cursor column (from above)
	
	; ES:DI points to the beginning of display slot
	push word [es:di+4]
	push word [es:di+6]
	pop di
	pop es					; ES:DI now points to beginning of buffer
	add di, ax				; ES:DI now points to where we must put the string
	
display_output_string_loop:
	mov al, byte [ds:si]	; read one character from input string
	inc si					; next character from input string
	cmp al, 0				; is it the terminator?
	je display_output_string_done	; yes
	
display_output_string_try_CR:
	cmp al, ASCII_CARRIAGE_RETURN	 ; is it CR?
	jne display_output_string_try_BS ; no
									 ; yes, move cursor to beginning of line
	shl bl, 1						 ; each cursor position is 2 bytes
	mov ah, 0
	mov al, bl						 ; AX := 2*cursor column
	sub di, ax						 ; move buffer pointer to beginning of line
	mov bl, 0						 ; move cursor to beginning of line
	jmp display_output_string_loop	 ; done, so display next character

display_output_string_try_BS:
	cmp al, ASCII_BACKSPACE					; is it BS?
	jne display_output_string_try_LF		; no
	; it is BS
	cmp bl, 0								; are we on the left-most column?
	je display_output_string_loop 			; yes, so skip this character
	
	sub di, 2								; move one position (2-byte) left
	mov al, ASCII_BLANK_SPACE				; "erase" existing character there
	mov byte [es:di], al					; store character
	
	dec bl									; move cursor left
	
	jmp display_output_string_loop	 ; done, so display next character
	
display_output_string_try_LF:
	cmp al, ASCII_LINE_FEED						; is it LF?
	jne display_output_string_plain_character	; no
	inc bh										; yes, move cursor down
	add di, NUM_COLUMNS*2					; move buffer pointer down one line
											; (2 bytes per character)
	jmp display_output_string_loop_check_scroll ; we may have scrolled

display_output_string_plain_character:
	; now "print" the character to the virtual display buffer
	mov byte [es:di], al	; store character
	add di, 2				; next character from display buffer
							; (skipping over one attribute byte)
	inc bl					; advance cursor one position to the right
	cmp bl, NUM_COLUMNS		; are we past the right-hand edge of the screen?
	jne display_output_string_loop	; no, so just display next character
	mov bl, 0				; yes, so move it to beginning of line
	inc bh					; and move it to the next line
	; flow into the part where we see if we have to scroll the screen
display_output_string_loop_check_scroll:
	cmp bh, NUM_ROWS		; are we past the bottom-most line?
	jne display_output_string_loop	; no, so just display next character
									; yes, so scroll screen
	
	; here, ES:CX = pointer to current location into buffer
	mov cx, di						; [3] save current buffer DI in CX
	
	pop di							; DI := beginning of display slot
	push di							; put beginning of display slot back
	
	push word [cs:di+6]				; buffer offset
	pop di							; ES:DI := beginning of buffer
	call display_scroll_buffer

	mov di, cx						; [3] restore current buffer DI from CX
	; here, ES:DI = pointer to current location into buffer
	
	dec bh							; and put cursor on last line
	
	sub di, NUM_COLUMNS*2			; move buffer pointer up one line
									; (2 bytes per character)
	
	jmp display_output_string_loop	; display next character
display_output_string_done:
	; here, BH = cursor row after string was written
	;       BL = cursor column after string was written
	
	; save cursor position into the virtual display slot
	pop di					; restore pointer to beginning of display slot
	
	mov byte [cs:di+2], bh	; store new cursor row
	mov byte [cs:di+3], bl	; store new cursor column

	pop es
	popa
	ret

	
; Reads a character and attribute pair from the specified virtual display
;
; input:
;		AX - virtual display ID where we're writing the string
;		BH - cursor row
;		BL - cursor column
; output:
;		AH - attribute byte
;		AL - ASCII character byte
display_read_character_attribute:
	push bx
	push cx
	push dx
	push si
	push ds
	
	push cs
	pop ds
	
	mov si, displayTable
	add si, ax				; SI now points to the beginning of 
							; the display slot

	mov al, NUM_COLUMNS
	mul bh				; AX := NUM_COLUMNS * cursor row
	mov bh, 0			; BX := cursor column
	add ax, bx			; AX := (NUM_COLUMNS * cursor row) + cursor column
	shl ax, 1			; multiply by 2 due to 2 bytes per character
	; AX now contains the offset in the video buffer from where we're reading	
	
	; here, DS:SI points to the beginning of the display slot
	push word [ds:si+4]
	push word [ds:si+6]
	pop si
	pop ds				; DS:SI now points to beginning of buffer
	
	add si, ax				; DS:SI now points to the position we're reading
	mov ax, word [ds:si]	; return value (attributes and ASCII character)
	
	pop ds
	pop si
	pop dx
	pop cx
	pop bx
	ret
	

; Writes an attribute byte to the specified virtual display, 
; repeating as specified
;
; input
;		AX - virtual display ID where we're writing the string
;		CX - repeat this many times
;		DL - attribute byte
; output
;		none
display_write_attribute:
	pusha
	push es
	
	push cs
	pop es
	
	mov di, displayTable
	add di, ax				; DI now points to the beginning of 
							; the display slot

	mov al, NUM_COLUMNS
	mul byte [es:di+2]		; AX := NUM_COLUMNS * cursor row
	mov bh, 0
	mov bl, byte [es:di+3]	; BX := cursor column
	add ax, bx				; AX := (NUM_COLUMNS * cursor row) + cursor column
	
	shl ax, 1				; multiply by 2 due to 2 bytes per character
	; AX now contains the offset in the video buffer from where we're starting
	
	; here, ES:DI points to the beginning of the display slot
	push word [es:di+4]
	push word [es:di+6]
	pop di					
	pop es					; ES:DI now points to beginning of buffer proper
	
	add di, ax				; ES:DI now points to where we must put the string
	inc di					; point ES:DI at the high (attribute) byte

	cmp cx, 0							; handle the 0-count case
	je display_write_attribute_done	
display_write_attribute_loop:
	; now write the attribute byte
	mov byte [es:di], dl	; store attribute byte
	add di, 2				; next character from display buffer
							; (skipping over one character byte)
	loop display_write_attribute_loop	; next location

display_write_attribute_done:
	pop es
	popa
	ret

	
; Clears the screen and positions the cursor on row 0, column 0
; Sets all attributes to light gray on black.
;
; input
;		AX - ID (offset) of virtual display we're clearing
; output
;		none
display_clear_screen:
	pushf
	pusha
	push es
	
	push cs
	pop es
	
	push ax					; save virtual display ID
	
	mov di, displayTable
	add di, ax				; DI now points to the beginning of 
							; the display slot
	push word [es:di+4]
	push word [es:di+6]
	pop di
	pop es					; ES:DI now points to beginning of buffer proper
	
	mov ah, GRAY_ON_BLACK				; attribute byte
	mov al, 0							; ASCII character byte
	mov cx, NUM_ROWS * NUM_COLUMNS		; this many words
	cld
	rep stosw
	
	pop ax					; restore virtual display ID
	mov bx, 0
	call display_set_cursor_position	; move cursor to (0, 0)
	
	pop es
	popa
	popf
	ret

	
; Dumps the specified virtual display to the specified buffer.
; The buffer must be able to store 4000 bytes (80 columns x 25 rows x 2 bytes).
;
; input
;		AX - ID (offset) of virtual display we're dumping
;	 ES:DI - pointer to where the virtual display will be dumped
; output
;		none
display_dump_screen:
	pusha
	pushf
	push ds
	
	push cs
	pop ds	
	mov si, displayTable
	add si, ax
	
	push word [ds:si+4]
	push word [ds:si+6]
	pop si
	pop ds					; DS:SI now points to beginning of buffer proper
	
	mov cx, 4000			; this many bytes
	cld
	rep movsb				; perform the copy
	
	pop ds
	popf
	popa
	ret


; Writes an ASCII character to the specified virtual display
;
; input
;		AX - ID (offset) of virtual display to which we're printing
;		BL - ASCII character to print
display_output_character:
	pusha
	push ds
	
	push cs
	pop ds

	mov si, virtualDisplayCharacterOutputBuffer
	mov byte [ds:si], bl					; our one-character string
	call display_output_string
	
	pop ds
	popa
	ret	

	
; Prints a specified number of characters from a string	to the
; specified virtual display
;
; input:
;		AX - ID (offset) of virtual display to which we're printing
;		DS:SI - pointer to string
;		CX - number of characters to print
display_print_dump:
	pusha
display_print_dump_loop:
	mov bl, byte [ds:si]				; BL := byte at DS:SI
	inc si								; next character
	call display_output_character		; print character in BL
	loop display_print_dump_loop
	
	popa
	ret
