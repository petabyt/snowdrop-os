;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The HEXVIEW app.
; This app is used to view both hex and ASCII from either a specified memory
; address, or from a file on disk.
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


LINES_PER_PAGE		equ 19
BYTES_PER_LINE		equ 16
FILE_NAME_MAX_SIZE	equ 12		; 8+3 plus extension dot

instructionsString		db 'PGDN/PGUP to change pages    UP/DOWN to move line   LEFT/RIGHT to move cursor', 0
titleString:			db 'Snowdrop OS Hex Viewer', 0
TITLE_STRING_LENGTH equ $ - titleString - 1		; - 1 to account for terminator

paddingBeforeAddress:	db '    ', 0

argumentValueBuffer:	times 512 db 0
addressArgumentName:	db 'address', 0

filenameBuffer:	times 15 db 0
fat12Filename: times FILE_NAME_MAX_SIZE+1 db 0
loadedFileSize:	dw 0

addressStringSegment:	times 16 db 0
addressStringOffset:	times 16 db 0

memoryIsAllocated:	db 0
addressSegment:	dw 0
addressOffset:	dw 0

cursorPosition:		db 0

currentOffset:		dw 0
singleLineBuffer:	times 128 db 0
asmUtlNumberToHexBuffer:	times 2 db 0

newline:		db 13, 10, 0
fileNotFound:	db 'Error: file not found', 0
usageString: 	db 13, 10
				db 'Example usage:    HEXVIEW [file=sm.txt]', 13, 10
				db '            or    HEXVIEW [address=XXXX:YYYY]', 13, 10
				db '                  (where XXXX is the segment, YYYY is the offset, in hex)', 13, 10
				db 0

				
start:	
	; look for "address" argument
	call read_address_argument
	cmp ax, 0
	jne got_address						; we got an address

	; look for "file" argument
	call read_file_name_argument		; AX := 0 when not found or invalid
	cmp ax, 0
	je incorrect_usage
	; fat12Filename is assumed to have been filled in
	
	; allocate memory to load the file
	call common_task_allocate_memory_or_exit	; BX := allocated segment
	mov word [cs:addressSegment], bx			; store it
	mov word [cs:addressOffset], 0
	mov byte [cs:memoryIsAllocated], 1			; indicate we have allocated

	; fill segment with zeroes
	push es
	mov cx, 65535
	mov di, 0
	mov es, bx
	mov al, 0
	rep stosb								; store 0 at 0 through :FFFE
	stosb									; store 0 at :FFFF
	pop es
	
	mov es, bx
	mov di, 0									; we're loading to ES:DI
	mov si, fat12Filename						; DS:SI := pointer to file name
	int 81h										; AL := 0 when successful
												; CX := file size in bytes
	cmp al, 0
	jne incorrect_file_name
	; file has now been loaded successfully, and address segment/offset
	; have been set
	
	; we continue as if we're running in "address mode"	
got_address:
	mov ax, word [cs:addressSegment]
	mov bx, word [cs:addressOffset]
	
	push word [cs:addressOffset]
	pop word [cs:currentOffset]					; current := beginning

	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	int 83h						; clear keyboard buffer
	
display_page:
	int 0A0h					; clear screen
	mov si, newline
	int 97h
	int 97h
	
	push word [cs:currentOffset]
	mov cx, LINES_PER_PAGE
display_page_loop:	
	call write_hex_ascii_line
	mov si, paddingBeforeAddress
	int 97h
	mov si, singleLineBuffer
	int 97h
	mov si, newline
	int 97h
	add word [cs:currentOffset], BYTES_PER_LINE
	loop display_page_loop
	
	pop word [cs:currentOffset]
	call draw_overlay
wait_input:
	mov ah, 0
	int 16h			; block and wait for key

wait_input_try_rightarrow:
	cmp ah, COMMON_SCAN_CODE_RIGHT_ARROW
	jne wait_input_try_leftarrow
	cmp byte [cs:cursorPosition], BYTES_PER_LINE - 1
	je display_page						; already at the right
	inc byte [cs:cursorPosition]
	jmp display_page
wait_input_try_leftarrow:
	cmp ah, COMMON_SCAN_CODE_LEFT_ARROW
	jne wait_input_try_uparrow
	cmp byte [cs:cursorPosition], 0
	je display_page						; already at the left
	dec byte [cs:cursorPosition]
	jmp display_page
wait_input_try_uparrow:
	cmp ah, COMMON_SCAN_CODE_UP_ARROW
	jne wait_input_try_downarrow
	sub word [cs:currentOffset], BYTES_PER_LINE
	jmp display_page
wait_input_try_downarrow:
	cmp ah, COMMON_SCAN_CODE_DOWN_ARROW
	jne wait_input_try_escape
	add word [cs:currentOffset], BYTES_PER_LINE
	jmp display_page
wait_input_try_escape:	
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne wait_input_try_pagedown
	jmp exit
wait_input_try_pagedown:
	cmp ah, COMMON_SCAN_CODE_PAGE_DOWN
	jne wait_input_try_pageup
	add word [cs:currentOffset], LINES_PER_PAGE * BYTES_PER_LINE
	jmp display_page
wait_input_try_pageup:
	cmp ah, COMMON_SCAN_CODE_PAGE_UP
	jne wait_input_end
	sub word [cs:currentOffset], LINES_PER_PAGE * BYTES_PER_LINE
	jmp display_page
wait_input_end:
	jmp wait_input


incorrect_usage:
	mov si, usageString
	int 80h
	jmp exit
	
incorrect_file_name:
	mov si, fileNotFound
	int 80h
	jmp exit
	
exit:
	call deallocate_memory
	int 95h							; exit
	
	
; Deallocates any allocated memory if needed
; 
; input:
;		none
; output:
;		none
deallocate_memory:
	pusha
	cmp byte [cs:memoryIsAllocated], 0
	je deallocate_memory_done
	
	mov bx, word [cs:addressSegment]
	int 92h						; deallocate
	mov byte [cs:memoryIsAllocated], 0
deallocate_memory_done:
	popa
	ret
	

; Highlights an entire column of both bytecode and ASCII to
; make it easier to follow along
; 
; input:
;		none
; output:
;		none	
draw_cursor:
	pusha

	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_FONT_BRIGHT
	
	mov ax, LINES_PER_PAGE
	mov bh, 2
draw_cursor_loop:
	; highlight ASCII
	mov bl, byte [cs:cursorPosition]
	add bl, 59
	int 9Eh
	
	mov cx, 1
	int 9Fh								; write attribute
	
	; highlight hex
	push ax
	
	mov al, byte [cs:cursorPosition]
	mov bl, 3
	mul bl								; three characters per hex byte
	add al, 10
	mov bl, al
	int 9Eh
	
	mov cx, 2
	int 9Fh								; write attribute
	pop ax
	
	inc bh								; next row
	dec ax
	jnz draw_cursor_loop
	
	popa
	ret
	
	
; Draws a border and menu
;
; input:
;		none
; output:
;		none
draw_overlay:
	pusha
	push ds
	
	mov ax, cs
	mov ds, ax
	
	mov bx, 0					; row, col
	mov al, COMMON_SCREEN_WIDTH - 2
	mov ah, COMMON_SCREEN_HEIGHT - 3
	call common_draw_box
	
	mov bl, COMMON_SCREEN_WIDTH / 2 - TITLE_STRING_LENGTH / 2 - 2
	mov si, titleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title
	
	call draw_cursor
	
	mov bh, COMMON_SCREEN_HEIGHT - 3
	mov bl, 1
	int 9Eh
	mov si, instructionsString
	int 97h

	; make cursor "invisible"
	mov dl, COMMON_FONT_COLOUR_BLACK | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, 1
	int 9Fh								; write attribute
	
	pop ds
	popa
	ret
	

; Attempt to read address from program arguments
; 
; input:
;		none
; output:
;		AX - 0 when address argument is unspecified or invalid,
;			 other value otherwise
read_address_argument:
	push bx
	push cx
	push dx
	push si
	push di
	pushf
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, addressArgumentName
	mov di, argumentValueBuffer
	int 0BFh					; read param value

	cmp ax, 0
	je read_address_argument_failure
	; now validate address value
	; it has to look like this: 0000:0000
	mov si, argumentValueBuffer
	int 0A5h					; BX := string length
	cmp bx, 9
	jne read_address_argument_failure
	
	mov byte [es:addressStringSegment], '0'	; prefix with 0 for parsing
	mov di, addressStringSegment + 1
	mov cx, 4
	cld
	rep movsb					; copy segment string
	mov byte [es:di], 'h'		; add a 'h' for parsing
	mov byte [es:di+1], 0		; add terminator
	; DS:SI now points to ':'
	inc si
	mov byte [cs:addressStringOffset], '0'	; prefix with 0 for parsing
	mov di, addressStringOffset + 1
	mov cx, 4
	cld
	rep movsb					; copy offset string
	mov byte [es:di], 'h'		; add a 'h' for parsing
	mov byte [es:di+1], 0		; add terminator
	
	; now convert segment and offset strings to words
	mov si, addressStringSegment
	call is_hex_number_string			; AX := 0 when not hex
	cmp ax, 0
	je read_address_argument_failure
	call get_hex_number_string_value	; AX := number
	mov word [cs:addressSegment], ax

	mov si, addressStringOffset
	call is_hex_number_string			; AX := 0 when not hex
	cmp ax, 0
	je read_address_argument_failure
	call get_hex_number_string_value	; AX := number
	mov word [cs:addressOffset], ax
	
	mov ax, 1
	jmp read_address_argument_done
read_address_argument_failure:
	mov ax, 0
read_address_argument_done:
	pop es
	pop ds
	popf
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Attempt to read file name from parameter, and convert it
; to FAT12 format if it is found
; 
; input:
;		none
; output:
;		AX - 0 when file argument is unspecified or invalid,
;			 other value otherwise
read_file_name_argument:
	push bx
	push cx
	push dx
	push si
	push di
	pushf
	push ds
	
	; read value of argument 'file'
	call common_args_read_file_file_arg	; DS:SI := pointer to 8.3 file name
	cmp ax, 0
	jne read_file_name_argument_valid	; valid!

	; not found or invalid
	mov ax, 0
	jmp read_file_name_argument_done

read_file_name_argument_valid:
	; here, DS:SI contains the file name in 8.3 format
	push si
	int 0A5h						; BX := file name length
	mov cx, bx
	inc cx							; also copy terminator
	mov di, filenameBuffer
	cld
	rep movsb						; copy into filenameBuffer
	pop si

	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	mov ax, 1
read_file_name_argument_done:
	pop ds
	popf
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret

	
; Checks whether the specified string contains a valid hex number
; Note: modifies input string
; Valid hex number strings must:
;     - be at least 2 characters long
;     - left-most character is 0-9
;     - contain only characters 0-9, a-f, A-F, and a final h or H character
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string is not a valid hex number string, other
;			 value otherwise	
is_hex_number_string:
	push ds
	push es
	push bx
	push si
	push di
	
	int 0A5h					; BX := string length
	cmp bx, 2					; must have at least 2 characters, such as:
								; 0h, Ah
	jb is_hex_number_string_invalid

	int 82h						; convert to uppercase
	
	cmp byte [ds:si], '0'		; must start with a digit
	jb is_hex_number_string_invalid
	cmp byte [ds:si], '9'
	ja is_hex_number_string_invalid
	
	cmp byte [ds:si+bx-1], 'H'	; must end in 'H'
	jne is_hex_number_string_invalid

is_hex_number_string_loop:
	; first try letter
	cmp byte [ds:si], 'A'
	jb is_hex_number_string_loop_try_digit	; it's not a letter
	cmp byte [ds:si], 'F'
	ja is_hex_number_string_loop_try_digit
	jmp is_hex_number_string_loop_next		; it's a valid character

is_hex_number_string_loop_try_digit:
	cmp byte [ds:si], '0'
	jb is_hex_number_string_invalid
	cmp byte [ds:si], '9'
	ja is_hex_number_string_invalid
	
is_hex_number_string_loop_next:
	inc si
	cmp byte [ds:si], 'H'		; is it the 'H' at the end?
	jne is_hex_number_string_loop	; no, keep going
	
	mov ax, 1					; valid
	jmp is_hex_number_string_done

is_hex_number_string_invalid:
	mov ax, 0
	
is_hex_number_string_done:
	pop di
	pop si
	pop bx
	pop es
	pop ds
	ret

	
; Gets the numeric value represented by a hex number string
; Assumes the string contains a valid hex number
; Note: modifies input string
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - numeric value
get_hex_number_string_value:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	mov di, si				; DI := near pointer to first character
	
	int 0A5h				; BX := string length
	
	int 82h					; convert to uppercase
	
	add si, bx
	sub si, 2				; DS:SI := pointer to last digit (skips over 'H')
	
	mov cl, 0				; power of 2 that corresponds to last character
	mov ax, 0				; accumulates result
get_hex_number_string_value_loop:
	mov dl, byte [ds:si]
	cmp dl, '0'										; is it a number?
	jb get_hex_number_string_value_loop_letter	; no
	cmp dl, '9'
	ja get_hex_number_string_value_loop_letter
	; this digit is 0-9
	sub dl, '0'					; DL := numeric value of digit
	jmp get_hex_number_string_value_loop_accumulate
get_hex_number_string_value_loop_letter:
	; here, DL contains an uppercase letter
	sub dl, 'A'					
	add dl, 10					; DL := numeric value of digit
	
get_hex_number_string_value_loop_accumulate:
	mov dh, 0					; DX := numeric value of digit
	
	push cx
	shl cl, 2					; CL := position * 4
								; (since a hex digit takes up 4 bits)
	shl dx, cl					; DX := DX * 16^CL
	add ax, dx					; accumulate
	pop cx
	
	inc cl						; next higher power of 16
	dec si						; move one character to the left
	cmp si, di					; are we now to the left of leftmost character?
	jae get_hex_number_string_value_loop	; no, so keep going
	; yes, so we just ran out of characters
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret
	
	
; Converts a number to hex, two characters per input character, space-separated
;
; input:
;		AX - number to convert
;	 ES:DI - pointer to result buffer
;		DX - formatting options:
;			 bit 0: whether to zero-terminate
;			 bit 1: whether to add a space after each byte
; output:
;		none
word_to_hex:
	pusha
	push ds
	push es
	
	mov word [cs:asmUtlNumberToHexBuffer], ax
	
	push cs
	pop ds
	mov si, asmUtlNumberToHexBuffer
	mov bx, 2
	call string_to_hex
	
	pop es
	pop ds
	popa
	ret

	
; Convert a hex digit to its character representation
; Example: 10 -> 'A'
;
; input:
;		AL - hex digit
; output:
;		CL - hex digit to char
hex_digit_to_char:
	push ax
	cmp al, 9
	jbe hex_digit_to_char_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
hex_digit_to_char_under9:
	add al, '0'
	mov cl, al
	pop ax
	ret
	
	
; Renders a byte as two hex digit characters
; Example: 20 -> "1" "8"
;
; input:
;		AL - byte to render
; output:
;		CX - two characters which represent the input
byte_to_hex:
	push ax
	push bx
	push dx
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call hex_digit_to_char		; CL := char
	mov ch, cl
	mov al, ah
	call hex_digit_to_char		; CL := char
	
	pop dx
	pop bx
	pop ax
	ret
	
	
; Converts a string to hex, two characters per input character, space-separated
;
; input:
;	 DS:SI - pointer to string to convert
;	 ES:DI - pointer to result buffer
;		BX - string length
;		DX - formatting options:
;			 bit 0: whether to zero-terminate
;			 bit 1: whether to add a space after each byte
; output:
;		none
string_to_hex:
	pusha
	push ds
	push es
	
string_to_hex_loop:
	cmp bx, 0							; done?
	je string_to_hex_loop_done
	
	mov al, byte [ds:si]
	call byte_to_hex				; CH := msb, CL := lsb

	mov byte [es:di], ch
	inc di
	mov byte [es:di], cl
	inc di
	
	inc si								; next source character
	dec bx
	
	test dx, 2							; add space after byte?
	jz string_to_hex_loop			; no
	; yes
	mov byte [es:di], ' '
	inc di
	jmp string_to_hex_loop			; next byte
	
string_to_hex_loop_done:
	test dx, 1							; zero-terminate?
	jz string_to_hex_done			; no
	; yes
	mov byte [es:di], 0

string_to_hex_done:	
	pop es
	pop ds
	popa
	ret

	
; Writes a separator of specified width
;
; input:
;	 ES:DI - pointer to listing buffer
;		CX - separator width in characters
; output:
;	 ES:DI - pointer to immediately after the separator
write_separator:
	push ax
	push cx
	pushf
	
	mov al, ' '
	cld
	rep stosb
	
	popf
	pop cx
	pop ax
	ret
	
	
; Potentially converts the provided character so that it can be printed.
; Such characters include backspace, line feed, etc.
;
; input:
;		AL - character to convert to printable
; output:
;		AL - printable character
convert_non_printable_char:
	cmp al, COMMON_ASCII_NULL
	je convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BELL
	je convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BACKSPACE
	je convert_non_printable_char_convert
	cmp al, COMMON_ASCII_TAB
	je convert_non_printable_char_convert
	cmp al, COMMON_ASCII_LINE_FEED
	je convert_non_printable_char_convert
	cmp al, COMMON_ASCII_CARRIAGE_RETURN
	je convert_non_printable_char_convert
	
	ret
convert_non_printable_char_convert:
	mov al, '.'
	ret

	

; Writes a single line of hex and ASCII
;
; input:
;		none
; output:
;		none	
write_hex_ascii_line:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax
	mov di, singleLineBuffer

	; write offset
	mov ax, word [cs:currentOffset]
	xchg ah, al									; humans read MSB first
	mov dx, 0
	call word_to_hex
	add di, 4									; it wrote this many characters

	mov cx, 2
	call write_separator
	
	; write hex
	push word [cs:addressSegment]
	pop ds
	mov si, word [cs:currentOffset]		; DS:SI := pointer to bytes
	mov bx, BYTES_PER_LINE
	mov dx, 2				; options: add spacing, don't zero-terminate
	call string_to_hex		; write
	add di, BYTES_PER_LINE * 3			; advance ES:DI
	
	mov cx, 1
	call write_separator
	
	; write ASCII
	cld
	mov cx, BYTES_PER_LINE
write_hex_ascii_line_loop:
	lodsb
	call convert_non_printable_char
	stosb
	loop write_hex_ascii_line_loop
	
	mov byte [es:di], 0				; terminate line	
	pop es
	pop ds
	popa
	ret
	

%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\args.asm"
%include "common\tasks.asm"
%include "common\screen.asm"
%include "common\textbox.asm"
%include "common\colours.asm"
