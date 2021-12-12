;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The PARAMST test app.
; This app outputs the values of the parameters it receives upon startup.
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

infoMessage:		db 'This app tests task parameter functionality', 13, 10
					db 'Usage: PARAMST [first=____] [second=____]', 0
paramFirst:			db 'first', 0
paramSecond:		db 'second', 0
valueOfFirst:		db 'Value of parameter "first":', 0
valueOfSecond:		db 'Value of parameter "second":', 0
paramValueBuffer:	times 257 db 0
newLine:			db 13, 10, 0

start:
	mov si, newLine
	int 80h
	
	mov di, paramValueBuffer
	
	; check if param "second" exists
	mov si, paramSecond
	int 0BFh					; read param value
	cmp ax, 0
	je missing_param			; not found

	; check if param "first" exists
	mov si, paramFirst
	int 0BFh					; read param value
	cmp ax, 0
	je missing_param			; not found
	; print value of param "first"
	mov si, valueOfFirst
	int 80h
	mov si, paramValueBuffer
	int 80h
	mov si, newLine
	int 80h
	
	; read and print value of param "second"
	mov si, paramSecond
	int 0BFh					; read param value
	mov si, valueOfSecond
	int 80h
	mov si, paramValueBuffer
	int 80h
	mov si, newLine
	int 80h
	
	jmp exit

missing_param:
	mov si, infoMessage
	int 80h
	mov si, newLine
	int 80h
	
exit:
	int 95h						; exit
