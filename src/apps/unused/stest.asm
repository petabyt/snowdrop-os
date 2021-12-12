;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The QTEST app.
; This application was used to develop Snowdrop OS's stack library.
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

	
AVAILABLE_DYN_MEM		equ 30000
pressToExit:			db 'Press a key to exit', 0
newLine:				db 13, 10, 0

COMMON_DYNSTACK_HEAD_PTR_LENGTH_2 equ COMMON_DYNSTACK_HEAD_PTR_LENGTH
COMMON_DYNSTACK_HEAD_PTR_INITIAL_2 equ COMMON_DYNSTACK_HEAD_PTR_INITIAL

; variables used for the first list, which holds 16bit integers
integersHeadPtr:	times COMMON_DYNSTACK_HEAD_PTR_LENGTH_2 db COMMON_DYNSTACK_HEAD_PTR_INITIAL_2
integersHeadPtr2:	times COMMON_DYNSTACK_HEAD_PTR_LENGTH_2 db COMMON_DYNSTACK_HEAD_PTR_INITIAL_2
								; by convention, consumer applications must 
								; declare and pass this address to linked 
								; list functions

integersPayload:		dw 0	; stores elements we're adding
INTEGERS_PAYLOAD_SIZE	equ 2	; each element holds this many bytes
INTEGERS_PAYLOAD_SIZE2	equ 200	; each element holds this many bytes

int0ptr:	dw 0
int1ptr:	dw 0
int2ptr:	dw 0				
int3ptr:	dw 0				
int4ptr:	dw 0				; these store pointers to list elements

start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 83h						; clear keyboard buffer

	mov si, dynamicMemoryStart	; DS:SI := pointer to start of dynamic memory
	mov ax, AVAILABLE_DYN_MEM	; maximum allocatable bytes
	call common_memory_initialize
	cmp ax, 0
	je done
	
	; main program
	
	call integers_print_list
	
	mov ax, 0
	call integers_add			; DS:SI := new list element
	mov word [cs:int0ptr], si
	
	mov ax, 1
	call integers_add		; DS:SI := new list element
	mov word [cs:int1ptr], si
	
push cs
pop fs
mov bx, integersHeadPtr
mov cx, INTEGERS_PAYLOAD_SIZE
call common_dynstack_pop
mov bx, word [ds:si]
;int 0b4h
call common_memory_deallocate

push cs
pop fs
mov bx, integersHeadPtr
mov cx, INTEGERS_PAYLOAD_SIZE
call common_dynstack_pop
mov bx, word [ds:si]
;int 0b4h
call common_memory_deallocate

	
	mov ax, 2
	call integers_add			; DS:SI := new list element
	mov word [cs:int2ptr], si

	mov ax, 3
	call integers_add			; DS:SI := new list element
	mov word [cs:int3ptr], si
	
	mov ax, 4
	call integers_add		; DS:SI := new list element
	mov word [cs:int4ptr], si
	
	
push cs
pop fs
mov bx, integersHeadPtr
mov cx, INTEGERS_PAYLOAD_SIZE
call common_dynstack_get_length
;int 0b4h
	
push cs
pop fs
mov bx, integersHeadPtr
mov cx, INTEGERS_PAYLOAD_SIZE
call common_dynstack_peek
mov bx, word [ds:si]
;int 0b4h



mov ax, 100
call integers2_add		; DS:SI := new list element
mov ax, 100
call integers2_add		; DS:SI := new list element

mov ax, 200
call integers2_add		; DS:SI := new list element
mov ax, 300
call integers2_add		; DS:SI := new list element

	
	call integers_print_list
	call integers_print_list2
	
done:
	int 83h						; clear keyboard buffer
	
	push cs
	pop ds
	mov si, pressToExit
	int 97h
	mov ah, 0
	int 16h
	
	; exit program
	int 95h						; exit

	

; Adds an integer to the integers list
;
; input:
;		AX - integer to add
; output:
;	 DS:SI - pointer to newly-added list element	
integers_add:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, INTEGERS_PAYLOAD_SIZE	; integersPayload size
	push cs
	pop es
	mov di, integersPayload			; ES:DI := pointer to integersPayload
	mov word [es:di], ax			; payload
	call common_dynstack_push		; DS:SI := new list element
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Adds an integer to the integers list
;
; input:
;		AX - integer to add
; output:
;	 DS:SI - pointer to newly-added list element	
integers2_add:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersHeadPtr2		; FS:BX := pointer to pointer to head
	mov cx, INTEGERS_PAYLOAD_SIZE2	; integersPayload size
	push cs
	pop es
	mov di, integersPayload			; ES:DI := pointer to integersPayload
	mov word [es:di], ax			; payload
	call common_dynstack_push		; DS:SI := new list element
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Prints payload of all elements in the list
;
; input:
;		none
; output:
;		none
integers_print_list:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersHeadPtr				; FS:BX := pointer to pointer to head
	mov cx, INTEGERS_PAYLOAD_SIZE		; integersPayload size
	push cs
	pop ds
	mov si, integers_print_one_callback
	call common_llist_foreach
	
	mov si, newLine
	int 97h
	
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Prints payload of all elements in the list
;
; input:
;		none
; output:
;		none
integers_print_list2:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, integersHeadPtr2			; FS:BX := pointer to pointer to head
	mov cx, INTEGERS_PAYLOAD_SIZE2		; integersPayload size
	push cs
	pop ds
	mov si, integers_print_one_callback
	call common_llist_foreach
	
	mov si, newLine
	int 97h
	
	pop fs
	pop es
	pop ds
	popa
	ret
	
	
; Callback for iteration through the list via foreach
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		none
integers_print_one_callback:
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	mov cl, 1						; formatting
	call common_text_print_number
	retf
	

%define _COMMON_MEMORY_CONFIG_			; override default chunk count value
COMMON_MEMORY_MAX_CHUNKS	equ 500

%include "common\memory.asm"
%include "common\dyn_stk.asm"
%include "common\dyn_que.asm"
%include "common\text.asm"
	
	
dynamicMemoryStart:
