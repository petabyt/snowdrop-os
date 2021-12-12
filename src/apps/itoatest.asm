;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The ITOATEST app.
; This app tests the 32bit integer-to-string functionality, for all
; possible formatting options.
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

instructionsString:  db "[A]-Add 1         [S]-Add 250         [D]-Add 50,000", 0
instructionsString2: db "[Z]-Subtract 1    [X]-Subtract 250    [C]-Subtract 50,000", 0
	
option0Description: db "option 0 (no formatting).....................:            ", 0
option1Description: db "option 1 (leading blanks)....................:            ", 0
option2Description: db "option 2 (commas and leading blanks).........:            ", 0
option3Description: db "option 3 (no leading characters).............:            ", 0
option4Description: db "option 4 (commas and no leading characters)..:            ", 0

TITLE_TOP equ 17
TITLE_LEFT equ 17
titleString: db "32bit integer to string test   [ESC]-Exit", 0

largeNumberBufferString: times 16 db 0			; will hold the result of itoa

FIRST_LINE_TOP equ 3
FIRST_LINE_LEFT equ 10

HIGH_WORD_LIMIT equ 270Fh

INSTRUCTIONS_TOP equ 10
INSTRUCTIONS_LEFT equ 10


start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 0A0h					; clear screen
	
	mov bh, TITLE_TOP
	mov bl, TITLE_LEFT
	int 9Eh						; move cursor
	mov si, titleString
	int 97h
	
	mov bh, INSTRUCTIONS_TOP
	mov bl, INSTRUCTIONS_LEFT
	int 9Eh						; move cursor
	mov si, instructionsString
	int 97h
	mov bh, INSTRUCTIONS_TOP + 1
	mov bl, INSTRUCTIONS_LEFT
	int 9Eh						; move cursor
	mov si, instructionsString2
	int 97h
	
	mov ax, 0					; lowest 2 bytes of number go in AX
	mov dx, 0					; highest 2 bytes of number go in DX
	
check_input:
	call display_all
	
	push ax						; save low word of number
	
	mov ah, 0					; "block and wait for key"
	int 16h						; read key, AH := scan code, AL := ASCII
check_a:
	cmp ah, COMMON_SCAN_CODE_A
	jne check_z
	pop ax
	call increment
	jmp check_input
check_z:
	cmp ah, COMMON_SCAN_CODE_Z
	jne check_s
	pop ax
	call decrement
	jmp check_input
check_s:
	cmp ah, COMMON_SCAN_CODE_S
	jne check_x
	pop ax
	mov cx, 250
	call add_many
	jmp check_input
check_x:
	cmp ah, COMMON_SCAN_CODE_X
	jne check_d
	pop ax
	mov cx, 250
	call subtract_many
	jmp check_input
check_d:
	cmp ah, COMMON_SCAN_CODE_D
	jne check_c
	pop ax
	mov cx, 50000
	call add_many
	jmp check_input
check_c:
	cmp ah, COMMON_SCAN_CODE_C
	jne check_esc
	pop ax
	mov cx, 50000
	call subtract_many
	jmp check_input
check_esc:
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne check_done
	int 95h						; exit
check_done:
	pop ax
	jmp check_input


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Adds a specified amount to the number
;
add_many:
	push cx
add_many_loop:
	call increment
	loop add_many_loop
	pop cx
	ret


; Subtracts a specified amount from the number
;	
subtract_many:
	push cx	
subtract_many_loop:
	call decrement
	loop subtract_many_loop
	pop cx
	ret
	
	
display_all:
	pusha
	
	mov cl, 0
	mov bh, FIRST_LINE_TOP
	mov si, option0Description
	call display_number
	
	inc cl						; next formatting option
	inc bh						; next row down
	mov si, option1Description
	call display_number
	
	inc cl						; next formatting option
	inc bh						; next row down
	mov si, option2Description
	call display_number
	
	inc cl						; next formatting option
	inc bh						; next row down
	mov si, option3Description
	call display_number
	
	inc cl						; next formatting option
	inc bh						; next row down
	mov si, option4Description
	call display_number
	
	popa
	ret

; Displays a label, and the number, using the specified formatting option
;
; input:
;		DX:AX - 32bit integer to display
;		DS:SI - label to print before number
;		CL - formatting option
;		BH - screen line on which to print
;
display_number:
	pusha
	
	mov bl, FIRST_LINE_LEFT
	int 9Eh						; move cursor
	int 97h						; print label
	
	mov bl, FIRST_LINE_LEFT + 47 ; move cursor to after displayed colon
	int 9Eh						; move cursor
	
	mov si, largeNumberBufferString
	mov bl, cl					; formatting option
	int 0A2h					; convert unsigned 32bit in DX:AX to string
	int 97h						; print
	
	popa
	ret


; Increments our 32bit number, keeping it within bounds.
; Overflows wrap it around to 0.
;
increment:
	inc ax						; increment low word
	cmp ax, 0					; did we overflow?
	jne increment_done			; no
	; we overflowed the low word
	inc dx						; increment high word
	cmp dx, HIGH_WORD_LIMIT		; did we overflow?
	jbe increment_done			; no
	; we overflowed the high word
	mov dx, 0
increment_done:
	ret

	
; Increments our 32bit number, keeping it within bounds.
; Overflows wrap it around to 0.
;
decrement:
	dec ax						; decrement low word
	cmp ax, 0FFFFh				; did we underflow?
	jne decrement_done			; no
	; we underflowed the low word
	dec dx						; decrement high word
	cmp dx, 0FFFFh				; did we underflow?
	jne decrement_done			; no
	; we underflowed the high word
	mov dx, HIGH_WORD_LIMIT
decrement_done:
	ret


%include "common\scancode.asm"
