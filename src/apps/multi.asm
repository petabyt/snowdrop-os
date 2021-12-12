;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MULTI app.
; This app is meant to test basic multi-tasking.
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

messageString:	db 'Hello from multitasking #'
				db 8							; backspace to erase #
				db 'test! ', 0

start:
	int 0A0h					; clear screen
	
	mov dx, 85					; print message this many times
main_loop:
	dec dx
	jz done
	
	mov si, messageString
	int 97h						; print string
	
	mov cx, 2					; small delay at a time
	
	int 85h						; delay
	int 94h						; yield
	
	int 85h						; delay
	int 94h						; yield
	
	int 85h						; delay
	int 94h						; yield
	
	int 85h						; delay
	int 94h						; yield
	
	; repeated delay/yield cycles make tasks more responsive
	
	jmp main_loop				; next iteration
done:
	int 95h						; exit

	
%include "common\text.asm"