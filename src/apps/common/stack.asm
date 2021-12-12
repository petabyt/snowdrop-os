;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It allows access to a stack of 16bit words.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; when this %define block is declared before this file is included in a
; program, it allows the program to configure the size of the stack
%ifndef _COMMON_STACK_CONF_
%define _COMMON_STACK_CONF_
STACK_LENGTH equ 256						; default size in words
%endif


%ifndef _COMMON_STACK_
%define _COMMON_STACK_

commonStackStorage: times STACK_LENGTH dw 0	; storage
commonStackStorageEnd:

commonStackPointer: dw commonStackStorage	; stack pointer


; Clears the stack
;
; input:
;		none
; output:
;		none
common_stack_clear:
	mov word [cs:commonStackPointer], commonStackStorage
	ret


; Pushes the specified value onto the stack
;
; input:
;		AX - value to push
; output:
;		AX - 0 when there was an overflow, other value otherwise
common_stack_push:
	pusha
	cmp word [cs:commonStackPointer], commonStackStorageEnd
	jae common_stack_push_overflow
	
	mov bx, word [cs:commonStackPointer]	; BX := pointer to element
	mov word [cs:bx], ax					; store it
	add word [cs:commonStackPointer], 2		; move pointer
	popa
	mov ax, 1
	ret
common_stack_push_overflow:
	popa
	mov ax, 0
	ret


; Pops a value off the stack
;
; input:
;		none
; output:
;		AX - 0 when there was an underflow, other value otherwise
;		BX - popped value, when no underflow
common_stack_pop:
	cmp word [cs:commonStackPointer], commonStackStorage
	jbe common_stack_pop_underflow
	
	sub word [cs:commonStackPointer], 2		; move pointer
	mov bx, word [cs:commonStackPointer]	; BX := pointer to element
	mov bx, word [cs:bx]					; return it
	mov ax, 1
	ret
common_stack_pop_underflow:
	mov ax, 0
	ret


%endif
