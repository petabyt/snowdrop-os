;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for viewing text on-screen.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_VIEWTEXT_
%define _COMMON_VIEWTEXT_

%include "common\scancode.asm"	
%include "common\screen.asm"
%include "common\text.asm"

COMMON_TEXT_VIEW_PAGED_FLAG_WAIT_FOR_USER_INPUT_AT_END		equ 1

commonTextFullLine:					times COMMON_SCREEN_WIDTH db ' '
									db 0
									
commonTextViewPagedMessageOutOf:	db ' of ', 0
commonTextViewPagedMessageBytes:	db ' bytes]', 0
commonTextViewPagedMessageStart:	db ' [', 0
commonTextMessagePressToScroll:		db '(ENTER advances line, SPACE advances page, ESC exits)', 0
commonTextMessagePressToQuit:		db '(end of text - ESC exits)', 0
commonTextViewPagedLastReadChar:	db 0
commonTextViewPagedLimit:			dw 0
commonTextViewPagedSize:			dw 0
commonTextViewPagedCurrent:			dw 0
commonTextViewPagedInitial:			dw 0
commonTextViewOptions:				dw 0


; Clears the message area (bottom line)
;
; input:
;	 	none
; output:
;		none
_common_text_view_paged_clear_bottom_line:
	pusha
	push ds
	
	mov bh, COMMON_SCREEN_HEIGHT - 1
	mov bl, 0
	int 9Eh								; move cursor
	
	push cs
	pop ds
	mov si, commonTextFullLine
	int 97h

	pop ds
	popa
	ret


; Displays a message
;
; input:
;	 	DI - near pointer to string
; output:
;		none
_common_text_view_paged_display_message:
	pusha
	push ds
	
	mov bh, COMMON_SCREEN_HEIGHT - 1
	mov bl, 0
	int 9Eh								; move cursor
	
	push cs
	pop ds
	mov si, di
	int 97h

	mov si, commonTextViewPagedMessageStart
	int 97h
	
	mov cl, 4						; no leading spaces, with commas
	mov dx, 0
	mov ax, word [cs:commonTextViewPagedCurrent]
	sub ax, word [cs:commonTextViewPagedInitial]	; DX:AX := number
	call common_text_print_number
	
	mov si, commonTextViewPagedMessageOutOf
	int 97h
	
	mov cl, 4						; no leading spaces, with commas
	mov dx, 0
	mov ax, word [cs:commonTextViewPagedSize]	; DX:AX := number
	call common_text_print_number
	
	mov si, commonTextViewPagedMessageBytes
	int 97h
	
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
common_text_view_paged:
	pusha
	pushf
	
	mov word [cs:commonTextViewOptions], ax
	mov word [cs:commonTextViewPagedSize], cx
	mov word [cs:commonTextViewPagedCurrent], si
	mov word [cs:commonTextViewPagedInitial], si
	
	mov word [cs:commonTextViewPagedLimit], si
	add word [cs:commonTextViewPagedLimit], cx	; save limit
	
	cld
common_text_view_paged_loop:

	cmp si, word [cs:commonTextViewPagedLimit]
	jae common_text_view_paged_done			; we reached the limit
	
	lodsb
	mov byte [cs:commonTextViewPagedLastReadChar], al
		
	int 0AAh					; BH := cursor row
	cmp bh, COMMON_SCREEN_HEIGHT - 2
	jb common_text_view_paged_loop_display
	
	; cursor is on bottom row and we must still display a character
	mov di, commonTextMessagePressToScroll
	call _common_text_view_paged_display_message
common_text_view_paged_loop_wait_input:
	int 83h								; clear keyboard buffer
	mov ah, 0
	int 16h								; block and read key
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je common_text_view_paged_exit
	cmp ah, COMMON_SCAN_CODE_ENTER
	je common_text_view_paged_loop_advance_line
	cmp ah, COMMON_SCAN_CODE_SPACE_BAR
	je common_text_view_paged_loop_advance_page
	jmp common_text_view_paged_loop_wait_input

common_text_view_paged_loop_advance_line:
	call _common_text_view_paged_clear_bottom_line
	int 0AAh
	sub bh, 2							; move cursor up
	int 9Eh
	jmp common_text_view_paged_loop_display
common_text_view_paged_loop_advance_page:
	int 0A0h							; clear screen
	; flow into display, below
common_text_view_paged_loop_display:
	inc word [cs:commonTextViewPagedCurrent]

	mov dl, byte [cs:commonTextViewPagedLastReadChar]
	int 98h										; print character
	jmp common_text_view_paged_loop
	
common_text_view_paged_done:
	test word [cs:commonTextViewOptions], COMMON_TEXT_VIEW_PAGED_FLAG_WAIT_FOR_USER_INPUT_AT_END
	jz common_text_view_paged_exit
	
	mov di, commonTextMessagePressToQuit
	call _common_text_view_paged_display_message
common_text_view_paged_done_wait_key:	
	mov ah, 0
	int 16h										; wait for key
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne common_text_view_paged_done_wait_key
common_text_view_paged_exit:
	popf
	popa
	ret

	
%endif
