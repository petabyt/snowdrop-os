;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for viewing text on-screen, direct to video hardware.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_VIEWTEXTH_
%define _COMMON_VIEWTEXTH_

%include "common\scancode.asm"	
%include "common\screenh.asm"
%include "common\text.asm"

COMMON_VIEWTXTH_FLAG_WAIT_FOR_USER_INPUT_AT_END		equ 1

commonViewtxthFullLine:					times COMMON_SCREENH_WIDTH db ' '
										db 0
				
commonViewtxthPrintCharBuffer:			times 2 db 0
commonViewtxthViewPagedMessageOutOf:	db ' of ', 0
commonViewtxthViewPagedMessageBytes:	db ' bytes]', 0
commonViewtxthViewPagedMessageStart:	db ' [', 0
commonViewtxthMessagePressToScroll:		db '(ENTER advances line, SPACE advances page, ESC exits)', 0
commonViewtxthMessagePressToQuit:		db '(end of text - ESC exits)', 0
commonViewtxthViewPagedLastReadChar:	db 0
commonViewtxthViewPagedLimit:			dw 0
commonViewtxthViewPagedSize:			dw 0
commonViewtxthViewPagedCurrent:			dw 0
commonViewtxthViewPagedInitial:			dw 0
commonViewtxthViewOptions:				dw 0


; Clears the message area (bottom line)
;
; input:
;	 	none
; output:
;		none
_common_viewtxth_view_paged_clear_bottom_line:
	pusha
	push ds
	
	mov bh, COMMON_SCREENH_HEIGHT - 1
	mov bl, 0
	call common_screenh_move_hardware_cursor
	
	push cs
	pop ds
	mov si, commonViewtxthFullLine
	int 80h

	pop ds
	popa
	ret


; Displays a message
;
; input:
;	 	DI - near pointer to string
; output:
;		none
_common_viewtxth_view_paged_display_message:
	pusha
	push ds
	
	mov bh, COMMON_SCREENH_HEIGHT - 1
	mov bl, 0
	call common_screenh_move_hardware_cursor
	
	push cs
	pop ds
	mov si, di
	int 80h

	mov si, commonViewtxthViewPagedMessageStart
	int 80h
	
	mov cl, 4						; no leading spaces, with commas
	mov dx, 0
	mov ax, word [cs:commonViewtxthViewPagedCurrent]
	sub ax, word [cs:commonViewtxthViewPagedInitial]	; DX:AX := number
	call common_text_print_number_to_hardware_screen
	
	mov si, commonViewtxthViewPagedMessageOutOf
	int 80h
	
	mov cl, 4						; no leading spaces, with commas
	mov dx, 0
	mov ax, word [cs:commonViewtxthViewPagedSize]	; DX:AX := number
	call common_text_print_number_to_hardware_screen
	
	mov si, commonViewtxthViewPagedMessageBytes
	int 80h
	
	pop ds
	popa
	ret

	
; Displays screenfulls of text and then waits for user input to
; continue
;
; input:
;		AX - options: 
;				   bit 0 - set when viewer should wait for user input at end
;				bits 1-7 - unused
;	 DS:SI - pointer to text
;		CX - length in bytes to display
; output:
;		none
common_viewtxth_view_paged:
	pusha
	pushf
	
	mov word [cs:commonViewtxthViewOptions], ax
	mov word [cs:commonViewtxthViewPagedSize], cx
	mov word [cs:commonViewtxthViewPagedCurrent], si
	mov word [cs:commonViewtxthViewPagedInitial], si
	
	mov word [cs:commonViewtxthViewPagedLimit], si
	add word [cs:commonViewtxthViewPagedLimit], cx	; save limit
	
	cld
common_viewtxth_view_paged_loop:

	cmp si, word [cs:commonViewtxthViewPagedLimit]
	jae common_viewtxth_view_paged_done			; we reached the limit
	
	lodsb
	mov byte [cs:commonViewtxthViewPagedLastReadChar], al
		
	call common_screenh_get_cursor_position			; BH := cursor row
	cmp bh, COMMON_SCREENH_HEIGHT - 2
	jb common_viewtxth_view_paged_loop_display
	
	; cursor is on bottom row and we must still display a character
	mov di, commonViewtxthMessagePressToScroll
	call _common_viewtxth_view_paged_display_message
common_viewtxth_view_paged_loop_wait_input:
	int 83h								; clear keyboard buffer
	mov ah, 0
	int 16h								; block and read key
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je common_viewtxth_view_paged_exit
	cmp ah, COMMON_SCAN_CODE_ENTER
	je common_viewtxth_view_paged_loop_advance_line
	cmp ah, COMMON_SCAN_CODE_SPACE_BAR
	je common_viewtxth_view_paged_loop_advance_page
	jmp common_viewtxth_view_paged_loop_wait_input

common_viewtxth_view_paged_loop_advance_line:
	call _common_viewtxth_view_paged_clear_bottom_line
	call common_screenh_get_cursor_position
	sub bh, 2							; move cursor up
	call common_screenh_move_hardware_cursor
	jmp common_viewtxth_view_paged_loop_display
common_viewtxth_view_paged_loop_advance_page:
	call common_screenh_clear_hardware_screen
	; flow into display, below
common_viewtxth_view_paged_loop_display:
	inc word [cs:commonViewtxthViewPagedCurrent]

	mov dl, byte [cs:commonViewtxthViewPagedLastReadChar]
	call _common_viewtxth_print_char
	jmp common_viewtxth_view_paged_loop
	
common_viewtxth_view_paged_done:
	test word [cs:commonViewtxthViewOptions], COMMON_VIEWTXTH_FLAG_WAIT_FOR_USER_INPUT_AT_END
	jz common_viewtxth_view_paged_exit
	
	mov di, commonViewtxthMessagePressToQuit
	call _common_viewtxth_view_paged_display_message
common_viewtxth_view_paged_done_wait_key:	
	mov ah, 0
	int 16h										; wait for key
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne common_viewtxth_view_paged_done_wait_key
common_viewtxth_view_paged_exit:
	popf
	popa
	ret


; Prints a single character
;
; input:
;		DL - character to print
; output:
;		none	
_common_viewtxth_print_char:
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
