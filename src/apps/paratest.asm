;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The PARATEST app.
; This app tests the "send data" functionality of the parallel port driver.
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

noParallelDriverMessage: 	db "No parallel port driver present. Exiting...", 0

titleString: db "Snowdrop OS Parallel Port Driver Test", 0
TITLE_TOP equ 2
TITLE_LEFT equ 22

descriptionString1: db "Outputting byte ", 0
descriptionString2: db " to the parallel port..", 0
DESCRIPTION_TOP equ 14
DESCRIPTION_LEFT equ 13

binaryString: db "Binary:    ", 0
binaryZeroString: db COMMON_ASCII_LIGHTEST, COMMON_ASCII_LIGHTEST, "   ", 0
binaryOneString: db COMMON_ASCII_BLOCK, COMMON_ASCII_BLOCK, "   ", 0
BINARY_STRING_TOP equ 16
BINARY_STRING_LEFT equ 13

instructionsString:  db "[A]-Increment  [Z]-Decrement  [S]-Rotate left  [X]-Rotate right     [ESC]-Exit", 0
INSTRUCTIONS_TOP equ 5
INSTRUCTIONS_LEFT equ 1

currentNumber:	db 0
largeNumberBufferString: times 16 db 0			; will hold the result of itoa


start:
	int 0B7h					; AL := parallel driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_parallel				; print error message and exit
	
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 0A0h					; clear screen
	
	mov bh, INSTRUCTIONS_TOP
	mov bl, INSTRUCTIONS_LEFT
	int 9Eh						; move cursor
	mov si, instructionsString
	int 97h
	
check_input:
	int 83h						; clear keyboard buffer
	
	mov al, byte [cs:currentNumber]
	int 0B6h					; send byte to parallel port
	
	call display_number			; refresh screen
	
	mov cx, 4					; wait this many ticks
	int 85h						; delay
	
	mov ah, 1
	int 16h 					; any key pressed?
	jz check_input  			; no
	
	; yes, so read it
	mov ah, 0					; "block and wait for key"
	int 16h						; read key, AH := scan code, AL := ASCII
check_a:
	cmp ah, COMMON_SCAN_CODE_A
	jne check_z
	inc byte [cs:currentNumber]
	jmp check_input
check_z:
	cmp ah, COMMON_SCAN_CODE_Z
	jne check_s
	dec byte [cs:currentNumber]
	jmp check_input
check_s:
	cmp ah, COMMON_SCAN_CODE_S
	jne check_x
	rol byte [cs:currentNumber], 1
	jmp check_input
check_x:
	cmp ah, COMMON_SCAN_CODE_X
	jne check_esc
	ror byte [cs:currentNumber], 1
	jmp check_input
check_esc:
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne check_input
	; when equal, flow into exit
	int 95h						; exit
	
no_parallel:
	mov si, noParallelDriverMessage
	int 80h						; print message
	int 95h						; exit
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Displays a label, and the number, using the specified formatting option
;
; input:
;		DX:AX - 32bit integer to display
display_number:
	pusha
	
	mov si, titleString
	mov bh, TITLE_TOP
	mov bl, TITLE_LEFT
	int 9Eh						; move cursor
	int 97h						; print label
	
	mov si, descriptionString1
	mov bh, DESCRIPTION_TOP
	mov bl, DESCRIPTION_LEFT
	int 9Eh						; move cursor
	int 97h						; print label
	
	mov dx, 0
	mov ah, 0
	mov al, byte [cs:currentNumber]	; DX:AX := current number
	mov si, largeNumberBufferString
	mov bl, 1					; formatting option 1: leading spaces
	int 0A2h					; convert unsigned 32bit in DX:AX to string
	int 97h						; print number
	
	mov si, descriptionString2
	int 97h						; print label
	
	mov si, binaryString
	mov bh, BINARY_STRING_TOP
	mov bl, BINARY_STRING_LEFT
	int 9Eh						; move cursor
	int 97h						; print label

	; now display the digit indicators
	mov cx, 8
	mov al, byte [cs:currentNumber]
display_number_binary_loop:
	test al, 10000000b			; get left most digit
	jnz display_number_one_digit
display_number_zero_digit:
	mov si, binaryZeroString
	jmp display_number_binary_print
display_number_one_digit:
	mov si, binaryOneString
display_number_binary_print:
	int 97h						; print digit
	rol al, 1
	loop display_number_binary_loop
	
	mov bx, 0
	int 9Eh						; move cursor to top left
	
	popa
	ret


%include "common\scancode.asm"
%include "common\ascii.asm"