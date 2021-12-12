;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for dealing with text on-screen.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_TEXT_
%define _COMMON_TEXT_

%include "common\scancode.asm"	
%include "common\screen.asm"

commonTextItoaBufferString: times 16 db 0		; will hold the result of itoa
commonTextNewline:	db 13, 10, 0


; Prints a newline on the current virtual display
;
; Input:
;		none
; Output:
;		none
common_text_print_newline:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, commonTextNewline
	int 97h
	
	pop ds
	popa
	ret
	

; Prints text at the specified location on the current task's virtual display
;
; Input:
;		BH - screen row
;		BL - screen column
;	 DS:SI - pointer to zero-terminated string
; Output:
;		none
common_text_print_at:
	pusha
	
	int 9Eh						; move cursor
	int 97h						; print
	
	popa
	ret

	
; Prints the specified number at the specified location on the 
; current task's virtual display
;
; Input:
;		BH - screen row
;		BL - screen column
;		CL - formatting option (see int 0A2h documentation)
;	 DX:AX - 32bit number to print
; Output:
;		none
common_text_print_number_at:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, commonTextItoaBufferString
	push bx
	mov bl, cl					; BL := formatting option
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI
	pop bx
	
	call common_text_print_at
	
	pop ds
	popa
	ret
	
	
; Prints the specified number on the current task's virtual display
;
; Input:
;		CL - formatting option (see int 0A2h documentation)
;	 DX:AX - 32bit number to print
; Output:
;		none
common_text_print_number:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, commonTextItoaBufferString
	mov bl, cl					; BL := formatting option
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI

	int 97h						; print
	
	pop ds
	popa
	ret

	
; Prints the specified number directly to the hardware screen
;
; Input:
;		CL - formatting option (see int 0A2h documentation)
;	 DX:AX - 32bit number to print
; Output:
;		none
common_text_print_number_to_hardware_screen:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, commonTextItoaBufferString
	mov bl, cl					; BL := formatting option
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI

	int 80h						; print
	
	pop ds
	popa
	ret

	
%endif
