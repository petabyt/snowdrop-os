;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for viewing memory (ASCII and hex) directly on
; video hardware.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_MEMVIEWH_
%define _COMMON_MEMVIEWH_


MEMVIEWH_LINES_PER_PAGE			equ 19
MEMVIEWH_BYTES_PER_LINE			equ 16

memviewhNewline:				db 13, 10, 0
memviewhPaddingBeforeAddress:	db '    ', 0
memviewhCursorPosition:			db 0
memviewhAddressSegment:			dw 0
memviewhCurrentOffset:			dw 0
memviewhSingleLineBuffer:		times 128 db 0

memviewhInstructionsString		db 'PGDN/PGUP to change pages    UP/DOWN to move line   LEFT/RIGHT to move cursor', 0
memviewhTitleString:			db 'Memory Viewer', 0
MEMVIEWH_TITLE_STRING_LENGTH equ $ - memviewhTitleString - 1		; - 1 to account for terminator


; Starts viewing the specified memory, displaying directly to
; the hardware screen
;
; input:
;	 DS:SI - pointer to beginning address
; output:
;		none
common_memviewh_start:
	pusha
	push ds
	push es
	
	mov word [cs:memviewhAddressSegment], ds
	mov word [cs:memviewhCurrentOffset], si
	
	mov ax, cs
	mov ds, ax
	mov es, ax
		
	int 83h						; clear keyboard buffer
	
common_memviewh_start_display_page:
	call common_screenh_clear_hardware_screen
	mov si, memviewhNewline
	int 80h
	int 80h
	
	push word [cs:memviewhCurrentOffset]
	mov cx, MEMVIEWH_LINES_PER_PAGE
common_memviewh_start_display_page_loop:	
	call _memviewh_write_hex_ascii_line
	mov si, memviewhPaddingBeforeAddress
	int 80h
	mov si, memviewhSingleLineBuffer
	int 80h
	mov si, memviewhNewline
	int 80h
	add word [cs:memviewhCurrentOffset], MEMVIEWH_BYTES_PER_LINE
	loop common_memviewh_start_display_page_loop
	
	pop word [cs:memviewhCurrentOffset]
	call _memviewh_draw_overlay
common_memviewh_start_wait_input:
	hlt				; do nothing until an interrupt occurs
	mov ah, 1
	int 16h 									; any key pressed?
	jz common_memviewh_start_wait_input				; no
	
	mov ah, 0
	int 16h			; block and wait for key

common_memviewh_start_wait_input_try_rightarrow:
	cmp ah, COMMON_SCAN_CODE_RIGHT_ARROW
	jne common_memviewh_start_wait_input_try_leftarrow
	cmp byte [cs:memviewhCursorPosition], MEMVIEWH_BYTES_PER_LINE - 1
	je common_memviewh_start_display_page				; already at the right
	inc byte [cs:memviewhCursorPosition]
	jmp common_memviewh_start_display_page
common_memviewh_start_wait_input_try_leftarrow:
	cmp ah, COMMON_SCAN_CODE_LEFT_ARROW
	jne common_memviewh_start_wait_input_try_uparrow
	cmp byte [cs:memviewhCursorPosition], 0
	je common_memviewh_start_display_page				; already at the left
	dec byte [cs:memviewhCursorPosition]
	jmp common_memviewh_start_display_page
common_memviewh_start_wait_input_try_uparrow:
	cmp ah, COMMON_SCAN_CODE_UP_ARROW
	jne common_memviewh_start_wait_input_try_downarrow
	sub word [cs:memviewhCurrentOffset], MEMVIEWH_BYTES_PER_LINE
	jmp common_memviewh_start_display_page
common_memviewh_start_wait_input_try_downarrow:
	cmp ah, COMMON_SCAN_CODE_DOWN_ARROW
	jne common_memviewh_start_wait_input_try_escape
	add word [cs:memviewhCurrentOffset], MEMVIEWH_BYTES_PER_LINE
	jmp common_memviewh_start_display_page
common_memviewh_start_wait_input_try_escape:	
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne common_memviewh_start_wait_input_try_pagedown
	jmp common_memviewh_start_done
common_memviewh_start_wait_input_try_pagedown:
	cmp ah, COMMON_SCAN_CODE_PAGE_DOWN
	jne common_memviewh_start_wait_input_try_pageup
	add word [cs:memviewhCurrentOffset], MEMVIEWH_LINES_PER_PAGE * MEMVIEWH_BYTES_PER_LINE
	jmp common_memviewh_start_display_page
common_memviewh_start_wait_input_try_pageup:
	cmp ah, COMMON_SCAN_CODE_PAGE_UP
	jne common_memviewh_start_wait_input_end
	sub word [cs:memviewhCurrentOffset], MEMVIEWH_LINES_PER_PAGE * MEMVIEWH_BYTES_PER_LINE
	jmp common_memviewh_start_display_page
common_memviewh_start_wait_input_end:
	jmp common_memviewh_start_wait_input
	
common_memviewh_start_done:
	pop es
	pop ds
	popa
	ret
	
	
; Draws a border and menu
;
; input:
;		none
; output:
;		none
_memviewh_draw_overlay:
	pusha
	push ds
	
	mov ax, cs
	mov ds, ax
	
	mov bx, 0					; row, col
	mov al, COMMON_SCREENH_WIDTH - 2
	mov ah, COMMON_SCREENH_HEIGHT - 3
	call common_draw_boxh
	
	mov bl, COMMON_SCREENH_WIDTH / 2 - MEMVIEWH_TITLE_STRING_LENGTH / 2 - 2
	mov si, memviewhTitleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_boxh_title
	
	call _memviewh_draw_cursor
	
	mov bh, COMMON_SCREENH_HEIGHT - 3
	mov bl, 1
	call common_screenh_move_hardware_cursor
	mov si, memviewhInstructionsString
	int 80h

	; make cursor "invisible"
	mov dl, COMMON_FONT_COLOUR_BLACK | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, 1
	call common_screenh_write_attr
	
	pop ds
	popa
	ret
	
	
; Highlights an entire column of both bytecode and ASCII to
; make it easier to follow along
; 
; input:
;		none
; output:
;		none	
_memviewh_draw_cursor:
	pusha

	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_FONT_BRIGHT
	
	mov ax, MEMVIEWH_LINES_PER_PAGE
	mov bh, 2
_memviewh_draw_cursor_loop:
	; highlight ASCII
	mov bl, byte [cs:memviewhCursorPosition]
	add bl, 59
	call common_screenh_move_hardware_cursor
	
	mov cx, 1
	call common_screenh_write_attr
	
	; highlight hex
	push ax
	
	mov al, byte [cs:memviewhCursorPosition]
	mov bl, 3
	mul bl								; three characters per hex byte
	add al, 10
	mov bl, al
	call common_screenh_move_hardware_cursor
	
	mov cx, 2
	call common_screenh_write_attr
	pop ax
	
	inc bh								; next row
	dec ax
	jnz _memviewh_draw_cursor_loop
	
	popa
	ret
	
	
; Writes a single line of hex and ASCII
;
; input:
;		none
; output:
;		none	
_memviewh_write_hex_ascii_line:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax
	mov di, memviewhSingleLineBuffer

	; write offset
	mov ax, word [cs:memviewhCurrentOffset]
	xchg ah, al									; humans read MSB first
	mov dx, 0
	call common_hex_word_to_hex
	add di, 4									; it wrote this many characters

	mov cx, 2
	call _memviewh_write_separator
	
	; write hex
	push word [cs:memviewhAddressSegment]
	pop ds
	mov si, word [cs:memviewhCurrentOffset]		; DS:SI := pointer to bytes
	mov bx, MEMVIEWH_BYTES_PER_LINE
	mov dx, 2					; options: add spacing, don't zero-terminate
	call common_hex_string_to_hex		; write
	add di, MEMVIEWH_BYTES_PER_LINE * 3			; advance ES:DI
	
	mov cx, 1
	call _memviewh_write_separator
	
	; write ASCII
	cld
	mov cx, MEMVIEWH_BYTES_PER_LINE
_memviewh_write_hex_ascii_line_loop:
	lodsb
	call _memviewh_convert_non_printable_char
	stosb
	loop _memviewh_write_hex_ascii_line_loop
	
	mov byte [es:di], 0				; terminate line	
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
_memviewh_write_separator:
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
_memviewh_convert_non_printable_char:
	cmp al, COMMON_ASCII_NULL
	je _memviewh_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BELL
	je _memviewh_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BACKSPACE
	je _memviewh_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_TAB
	je _memviewh_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_LINE_FEED
	je _memviewh_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_CARRIAGE_RETURN
	je _memviewh_convert_non_printable_char_convert
	
	ret
_memviewh_convert_non_printable_char_convert:
	mov al, '.'
	ret
	
	
%include "common\scancode.asm"
%include "common\screenh.asm"
%include "common\textboxh.asm"
%include "common\hex.asm"
%include "common\string.asm"
%include "common\ascii.asm"
%include "common\colours.asm"
	
	
%endif
