;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The LINKTEST app.
; This application was used to develop Snowdrop OS's linked list library.
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

%define _COMMON_MEMORY_CONFIG_			; override default chunk count value
COMMON_MEMORY_MAX_CHUNKS	equ 500

%include "common\memory.asm"
%include "common\dynamic\linklist.asm"
%include "common\text.asm"

	
AVAILABLE_DYN_MEM		equ 30000
pressToExit:			db 'Press a key to exit', 0
newLine:				db 13, 10, 0

; variables used for the first list, which holds 16bit integers
integersHeadPtr:	times COMMON_LLIST_HEAD_PTR_LENGTH db COMMON_LLIST_HEAD_PTR_INITIAL
								; by convention, consumer applications must 
								; declare and pass this address to linked 
								; list functions

integersPayload:		dw 0	; stores elements we're adding
INTEGERS_PAYLOAD_SIZE	equ 2	; each element holds this many bytes

int0ptr:	dw 0
int1ptr:	dw 0
int2ptr:	dw 0				
int3ptr:	dw 0				
int4ptr:	dw 0				; these store pointers to list elements

; variables used for the second list, which holds strings
MAX_STR_BUFFER_LENGTH	equ 200
stringsHeadPtr:		times COMMON_LLIST_HEAD_PTR_LENGTH db COMMON_LLIST_HEAD_PTR_INITIAL
								; by convention, consumer applications must 
								; declare and pass this address to linked 
								; list functions
STRINGS_PAYLOAD_SIZE	equ MAX_STR_BUFFER_LENGTH	; each element holds this many bytes

string0:	db 'string 0', 0
string1:	db 'string 1', 0
string2:	db 'string 2', 0

string0dupe:	db 'string 0', 0
string1dupe:	db 'string 1', 0
string2dupe:	db 'string 2', 0
stringNotFound:	db 'string N', 0

string0ptr:	dw 0
string1ptr:	dw 0
string2ptr:	dw 0				; these store pointers to list elements

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
	
	call strings_print_list
	call integers_print_list
	
;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;mov di, integersPayload			; ES:DI := pointer to integersPayload
;mov word [es:di], 1337			; payload
;call common_llist_add_head
	
;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;call common_llist_get_head
;int 0b4h

	mov ax, 0
	call integers_add			; DS:SI := new list element
	mov word [cs:int0ptr], si
	
;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;call integers_remove
;call integers_print_list

	mov si, string0
	call strings_add

;push cs
;pop fs
;mov bx, stringsHeadPtr
;mov cx, STRINGS_PAYLOAD_SIZE
;mov dx, 0						; offset
;push cs
;pop ds
;mov si, string0dupe				; DS:SI := string to search
;call common_llist_find_by_string
;int 0b4h
;int 97h
;mov ah, 0
;int 16h
	
	mov si, string1
	call strings_add

	mov ax, 2
	call integers_add			; DS:SI := new list element
	mov word [cs:int2ptr], si

;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;call common_llist_count
	
	mov si, string2
	call strings_add
	
	mov ax, 3
	call integers_add			; DS:SI := new list element
	mov word [cs:int3ptr], si
	
	; add after
	
	mov si, word [cs:int0ptr]	; add after this element
	mov ax, 1
	call integers_add_after		; DS:SI := new list element
	mov word [cs:int1ptr], si
	
;mov si, word [cs:int0ptr]
;mov cx, INTEGERS_PAYLOAD_SIZE
;call common_llist_get_next
;mov dx, word [ds:si]
;int 0b4h
	
	mov ax, 4
	call integers_add		; DS:SI := new list element
	mov word [cs:int4ptr], si
	
;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;mov dx, 2
;call common_llist_remove_at_index
	
;mov si, word [cs:int4ptr]
;mov cx, INTEGERS_PAYLOAD_SIZE
;call integers_remove

;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;call common_llist_clear

;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;mov di, integersPayload			; ES:DI := pointer to integersPayload
;mov word [es:di], 2337			; payload
;call common_llist_add_head

;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;mov dx, 4
;call common_llist_get_at_index
;mov cx, word [ds:si]		; payload
;int 0b4h

;mov ax, 333
;mov dx, 0
;call integers_add_at_index
	
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;push cs
;pop ds
;mov si, [cs:int4ptr]
;call common_llist_get_index
;int 0b4h

;push cs
;pop fs
;mov bx, integersHeadPtr
;mov cx, INTEGERS_PAYLOAD_SIZE
;mov si, 0
;mov dx, 4
;call common_llist_find_by_word
;mov bx, word [ds:si]
;int 0b4h
;mov ah, 0
;int 16h
	
	;call strings_print_list
	call integers_print_list
	
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

	
; Adds an integer to the strings list
;
; input:
;		SI - near pointer to string to add
; output:
;	 DS:SI - pointer to newly-added list element	
strings_add:
	push bx
	push cx
	push dx
	push di
	push es
	push fs
	
	push cs
	pop fs
	mov bx, stringsHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, STRINGS_PAYLOAD_SIZE	; payload size
	push cs
	pop es
	mov di, si						; ES:DI := pointer to payload
	call common_llist_add			; DS:SI := new list element
	
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
;	 DS:SI - pointer to element after which we're adding
; output:
;	 DS:SI - pointer to newly-added list element	
integers_add_after:
	push bx
	push cx
	push dx
	push di
	push es
	push fs

	mov cx, INTEGERS_PAYLOAD_SIZE	; integersPayload size
	push cs
	pop es
	mov di, integersPayload			; ES:DI := pointer to integersPayload
	mov word [es:di], ax			; payload
	call common_llist_add_after		; DS:SI := new list element
	
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
	call common_llist_add			; DS:SI := new list element
	
	pop fs
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	ret
	
	
; Adds an integer to the integers list, at the specified index
;
; input:
;		AX - integer to add
;		DX - index
; output:
;		AX - 0 when there was a failure, other value otherwise
;	 DS:SI - pointer to newly-added list element
integers_add_at_index:
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
	call common_llist_add_at_index	; DS:SI := new list element
	
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
;	 DS:SI - pointer to element to remove
; output:
;		none
integers_remove:
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
	call common_llist_remove		; DS:SI := new list element
	
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
	mov cx, INTEGERS_PAYLOAD_SIZE			; integersPayload size
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
strings_print_list:
	pusha
	push ds
	push es
	push fs
	
	push cs
	pop fs
	mov bx, stringsHeadPtr				; FS:BX := pointer to pointer to head
	mov cx, STRINGS_PAYLOAD_SIZE		; integersPayload size
	push cs
	pop ds
	mov si, strings_print_one_callback
	call common_llist_foreach
	
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
;		AX - 0 when traversal must stop, other value otherwise
integers_print_one_callback:
	mov dx, 0
	mov ax, word [ds:si]			; DX:AX := payload
	mov cl, 1						; formatting
	call common_text_print_number
	mov ax, 1						; keep traversing
	retf
	
	
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
strings_print_one_callback:
	int 97h							; print string
	retf
	
	
dynamicMemoryStart:
