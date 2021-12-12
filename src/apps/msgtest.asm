;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MSGTEST app.
; This app demonstrates the kernel's messaging functionality.
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
	
	messageType: 				db 'test-message-type', 0
	messageIncorrectType:		db 'bad-message-type', 0
	
	messageShouldBePrinted1:	db 'This should be printed (1 of 2).', 13, 10, 0
	messageShouldBePrinted1End:
	messageShouldBePrinted2:	db 'This should be printed (2 of 2).', 13, 10, 0
	messageShouldBePrinted2End:
	messageShouldNotBePrinted1:	db 'This should NOT be printed because no consumers are subscribed.', 13, 10, 0
	messageShouldNotBePrintedEnd1:
	messageShouldNotBePrinted2:	db 'This should NOT be printed it has the wrong message type.', 13, 10, 0
	messageShouldNotBePrintedEnd2:
 
start:
	; subscribe consumer
	mov ah, 0							; function 0: subscribe
	mov dx, cs
	mov bx, message_consumer
	mov si, messageType
	int 0C4h							; invoke message function

	; publish a message
	mov ah, 2							; function 2: publish message
	mov si, messageShouldBePrinted1
	mov di, messageType
	mov cx, messageShouldBePrinted1End - messageShouldBePrinted1
	int 0C4h							; invoke message function

	; unsubscribe all my consumers
	mov ah, 1							; function 1: unsubscribe all
	int 0C4h
	
	; publish a message with no consumers subscribed
	mov ah, 2							; function 2: publish message
	mov si, messageShouldNotBePrinted1
	mov di, messageType
	mov cx, messageShouldNotBePrintedEnd1 - messageShouldNotBePrinted1
	int 0C4h							; invoke message function
	
	; subscribe consumer
	mov ah, 0							; function 0: subscribe
	mov dx, cs
	mov bx, message_consumer
	mov si, messageType
	int 0C4h							; invoke message function
	
	; publish a message
	mov ah, 2							; function 2: publish message
	mov si, messageShouldBePrinted2
	mov di, messageType
	mov cx, messageShouldBePrinted2End - messageShouldBePrinted2
	int 0C4h							; invoke message function
	
	; publish a message to whose type no consumer is subscribed
	mov ah, 2							; function 2: publish message
	mov si, messageShouldNotBePrinted2
	mov di, messageIncorrectType
	mov cx, messageShouldNotBePrintedEnd2 - messageShouldNotBePrinted2
	int 0C4h							; invoke message function
	
done:
	; uncomment below lines to also test that a task with "keep memory"
	; lifetime also preserves its message consumer subscriptions
	;mov bl, COMMON_FLAG_LIFETIME_KEEP_MEMORY_ON_EXIT
	;int 0B5h					; set task lifetime params
	
	int 95h						; exit


; Message consumer contract:
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
; Consumer may not add or remove consumers.
; Consumer must use retf to return.
message_consumer:
	int 80h								; print
	retf

	
%include "common\tasks.asm"