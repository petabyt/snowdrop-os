;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MEMTEST app.
; This application tests Snowdrop OS's dynamic memory allocation module.
; It allows visualization of the available dynamic memory during a sequence
; of allocations and deallocations.
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

AVAILABLE_DYN_MEM	equ 200

INDICATOR_FRAME_COLOUR	equ 25
INDICATOR_LABEL_COLOUR	equ 25
INDICATOR_EMPTY_COLOUR	equ 16

INDICATOR_HEIGHT equ 30
INDICATOR_X equ COMMON_GRAPHICS_SCREEN_WIDTH/2 - AVAILABLE_DYN_MEM/2 - 1
											; - 1    for frame
INDICATOR_Y equ 25

TITLE_LABEL_COLOUR	equ 28

MESSAGE_TOP		equ INDICATOR_Y + 2 + INDICATOR_HEIGHT + 20
MESSAGE_LEFT	equ 5
MESSAGE_HEIGHT	equ COMMON_GRAPHICS_SCREEN_HEIGHT - MESSAGE_TOP

titleLabel:			db 'DYNAMIC MEMORY ALLOCATION TEST', 0
titleLabel2:		db '(FOR SNOWDROP OS APPLICATIONS)', 0
indicatorLabel:		db 'MEMORY MAP', 0
pressToAllocate:	db 'PRESS ANY KEY TO ALLOCATE:', 0
pressToDeallocate:	db 'PRESS ANY KEY TO DEALLOCATE:', 0
pressToReallocate:	db 'PRESS ANY KEY TO REALLOCATE:', 0
pressToFill:		db 'PRESS ANY KEY TO FILL REMAINING MEMORY', 0
pressToExit:		db 'PRESS ANY KEY TO EXIT', 0
failedReallocInSameSpotSameSize:	db 'FAILED REALLOC IN SAME SPOT/SAME SIZE', 0

reallocateColour:			db 0
reallocateNewSize:			dw 0
reallocateOriginalSegment:	dw 0
reallocateOriginalOffset:	dw 0

statFreeBytes: 		dw 0
statLargestGap:		dw 0
statFreeChunks:		dw 0

labelFreeBytes:		db '             FREE BYTES: ', 0
labelLargestGap:	db 'LARGEST AVAILABLE CHUNK: ', 0
labelFreeChunks:	db '       AVAILABLE CHUNKS: ', 0

itoaBuffer:			times 32 db 0

chunk0:		dw 0
chunk1:		dw 0
chunk2:		dw 0
chunk3:		dw 0
chunk4:		dw 0
chunk5:		dw 0
chunk6:		dw 0
chunk7:		dw 0
chunk8:		dw 0
chunk9:		dw 0
chunk10:	dw 0
chunk11:	dw 0
chunk12:	dw 0
chunk13:	dw 0
chunk14:	dw 0

start:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	call common_graphics_enter_graphics_mode
	int 83h						; clear keyboard buffer

	mov si, dynamicMemoryStart	; DS:SI := pointer to start of dynamic memory
	mov ax, AVAILABLE_DYN_MEM	; maximum allocatable bytes
	call common_memory_initialize
	cmp ax, 0
	je done

	call draw_title

	call draw_indicator_frame
	call draw_indicator_empty
	call draw_indicator_label
	
	mov dx, AVAILABLE_DYN_MEM	; size
	mov cl, 41					; colour
	call allocate_and_draw
	mov word [cs:chunk0], si
	
	mov dx, 1	; size
	mov cl, 44					; colour
	call allocate_and_draw

	mov dx, AVAILABLE_DYN_MEM	; size
	mov cl, 41					; colour
	mov si, word [cs:chunk0]
	call deallocate_and_draw
	
	mov dx, AVAILABLE_DYN_MEM + 1	; size
	mov cl, 200						; colour
	call allocate_and_draw
	
	mov dx, 1	; size
	mov cl, 44					; colour
	call allocate_and_draw
	
	mov dx, AVAILABLE_DYN_MEM	; size
	mov cl, 41					; colour
	call allocate_and_draw
	
	mov dx, 20					; size
	mov cl, 32					; colour
	call allocate_and_draw
	mov word [cs:chunk1], si
	
	mov dx, 40					; size
	mov cl, 34					; colour
	call allocate_and_draw
	mov word [cs:chunk2], si
	
	mov dx, 20					; size
	mov cl, 36					; colour
	call allocate_and_draw
	mov word [cs:chunk3], si
	
	mov dx, 20					; size
	mov cl, 40					; colour
	call allocate_and_draw
	mov word [cs:chunk4], si
	
	mov dx, 10					; size
	mov cl, 43					; colour
	call allocate_and_draw
	mov word [cs:chunk5], si

	mov dx, 10					; size
	mov cl, 43					; colour
	mov bx, 120
	call reallocate_and_draw
	mov word [cs:chunk5], si
	
	mov dx, 20					; size
	mov cl, 40					; colour
	mov si, word [cs:chunk4]
	call deallocate_and_draw
	
	mov dx, 40					; size
	mov cl, 34					; colour
	mov si, word [cs:chunk2]
	call deallocate_and_draw
		
	mov dx, 10					; size
	mov cl, 45					; colour
	call allocate_and_draw
	mov word [cs:chunk6], si
	
	mov dx, 10					; size
	mov cl, 48					; colour
	call allocate_and_draw
	mov word [cs:chunk7], si
	
	mov dx, 5					; size
	mov cl, 50					; colour
	call allocate_and_draw
	mov word [cs:chunk8], si
	
	mov dx, 60					; size
	mov cl, 53					; colour
	call allocate_and_draw
	mov word [cs:chunk9], si
	
	mov dx, 5					; size
	mov cl, 56					; colour
	call allocate_and_draw

	mov dx, 60					; size
	mov cl, 53					; colour
	mov si, word [cs:chunk9]
	call deallocate_and_draw
	
	mov dx, 10					; size
	mov cl, 59					; colour
	call allocate_and_draw
	
	mov dx, 10					; size
	mov cl, 62					; colour
	call allocate_and_draw
	
	mov dx, 10					; size
	mov cl, 65					; colour
	call allocate_and_draw
	mov word [cs:chunk10], si
	
	mov dx, 2					; size
	mov cl, 69					; colour
	call allocate_and_draw
	
	mov dx, 40					; size
	mov cl, 73					; colour
	call allocate_and_draw
	mov word [cs:chunk11], si
	
	mov dx, 40					; size
	mov cl, 77					; colour
	call allocate_and_draw

	mov dx, 2					; size
	mov cl, 84					; colour
	call allocate_and_draw
	
	mov dx, 2					; size
	mov cl, 87					; colour
	call allocate_and_draw
	mov word [cs:chunk13], si
	
	mov dx, 20					; size
	mov cl, 100					; colour
	call allocate_and_draw
	mov word [cs:chunk12], si
	
	mov dx, 3					; size
	mov cl, 110					; colour
	call allocate_and_draw
	mov word [cs:chunk14], si
	
	mov dx, 10					; size
	mov cl, 48					; colour
	mov si, word [cs:chunk7]
	call deallocate_and_draw
	
	mov dx, 10					; size
	mov cl, 65					; colour
	mov si, word [cs:chunk10]
	call deallocate_and_draw
	
	mov dx, 40					; size
	mov cl, 73					; colour
	mov si, word [cs:chunk11]
	call deallocate_and_draw
	
	mov dx, 20					; size
	mov cl, 36					; colour
	mov si, word [cs:chunk3]
	call deallocate_and_draw
	
	mov dx, 20					; size
	mov cl, 100					; colour
	mov si, word [cs:chunk12]
	call deallocate_and_draw				

	; pink
	; reallocate same size, to test moving
	mov dx, 2					; size
	mov cl, 87					; colour
	mov si, word [cs:chunk13]
	mov bx, 2					; new size
	call reallocate_and_draw
	mov word [cs:chunk13], si	; assume success
	
	mov dx, 2					; size
	mov cl, 87					; colour
	mov si, word [cs:chunk13]
	mov bx, 30					; new size
	call reallocate_and_draw
	mov word [cs:chunk13], si	; assume success
	
	mov dx, 30					; size
	mov cl, 87					; colour
	mov si, word [cs:chunk13]
	mov bx, 15					; new size
	call reallocate_and_draw
	mov word [cs:chunk13], si	; assume success
	
	;brown
	mov dx, 3					; size
	mov cl, 110					; colour
	mov si, word [cs:chunk14]
	mov bx, 25					; new size
	call reallocate_and_draw
	mov word [cs:chunk14], si	; assume success
	
	mov si, pressToFill
	mov dx, 10					; size
	mov cl, 0					; colour
	call write_message_and_wait
	
fill:
	call write_statistics
	
	mov dx, 1					; size
	mov cl, 15					; colour
	call allocate_and_draw_no_prompt
	mov cx, 4
	int 85h						; delay
	cmp ax, 0
	jne fill					; keep filling until we get an error
	
	mov dx, 25					; size
	mov cl, 110					; colour
	mov si, word [cs:chunk14]
	mov bx, 25					; new size
	call reallocate_and_draw	

	cmp ax, 0
	jne after_realloc_same_spot_same_size
	
	; failed
	mov si, failedReallocInSameSpotSameSize
	mov dx, 10					; size
	mov cl, 0					; colour
	call write_message_and_wait
after_realloc_same_spot_same_size:
	
done:
	int 83h						; clear keyboard buffer
	
	mov si, pressToExit
	mov dx, 10					; size
	mov cl, 0					; colour
	call write_message_and_wait
	
	; exit program
	call common_graphics_leave_graphics_mode
	int 95h						; exit


; Writes message and waits for key
;
; input:
;		SI - near pointer to message
;		CL - colour
;		DX - width of chunk in message area
; output:
;		none
write_message_and_wait:
	pusha
	push ds
	
	push cs
	pop ds
	
	pusha
	; erase message area
	mov ax, MESSAGE_TOP
	mov bx, MESSAGE_LEFT
	call common_graphics_coordinate_to_video_offset
	mov di, ax					; DI := video offset
	mov bl, 0					; colour
	mov ax, MESSAGE_HEIGHT		; height
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH - MESSAGE_LEFT
	call common_graphics_draw_rectangle_solid
	popa
	
	pusha
	mov dx, COMMON_TEXT_PRINT_FLAG_NORMAL
	mov bx, MESSAGE_LEFT
	mov ax, MESSAGE_TOP
	mov cl, INDICATOR_LABEL_COLOUR
	call common_graphics_text_print_at
	popa
	
	pusha
	mov ax, MESSAGE_TOP + 10
	mov bx, MESSAGE_LEFT + 30
	call common_graphics_coordinate_to_video_offset
	mov di, ax					; DI := video offset
	mov bl, cl					; colour
	mov ax, INDICATOR_HEIGHT	; height
	call common_graphics_draw_rectangle_solid
	popa
	
	call write_statistics
	call draw_marker_strings
	
	int 83h						; clear keyboard buffer
	mov ah, 0
	int 16h						; wait for key
	
	pop ds
	popa
	ret
	
	
; Prints memory statistics
;
; input:
;		none
; output:
;		none
write_statistics:
	pusha
	push ds
	
	push cs
	pop ds
	
	call common_memory_stats
	mov word [cs:statFreeBytes], bx
	mov word [cs:statLargestGap], cx
	mov word [cs:statFreeChunks], dx
	
	mov bx, MESSAGE_LEFT
	mov ax, MESSAGE_TOP + 50
	
	pusha
	; erase message area
	call common_graphics_coordinate_to_video_offset
	mov di, ax					; DI := video offset
	mov bl, 0					; colour
	mov ax, 30		; height
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH - MESSAGE_LEFT
	call common_graphics_draw_rectangle_solid
	popa
	
	mov dx, COMMON_TEXT_PRINT_FLAG_NORMAL
	mov cl, TITLE_LABEL_COLOUR
	mov si, labelFreeBytes
	call common_graphics_text_print_at
	
	mov si, itoaBuffer
	pusha
	mov dx, 0
	mov ax, word [cs:statFreeBytes]		; number in DX:AX
	mov bl, 2							; formatting
	int 0A2h
	popa
	add bx, 150
	call common_graphics_text_print_at
	
	mov bx, MESSAGE_LEFT
	add ax, 10
	mov si, labelLargestGap
	call common_graphics_text_print_at
	
	mov si, itoaBuffer
	pusha
	mov dx, 0
	mov ax, word [cs:statLargestGap]	; number in DX:AX
	mov bl, 2							; formatting
	int 0A2h
	popa
	add bx, 150
	call common_graphics_text_print_at
	
	mov bx, MESSAGE_LEFT
	add ax, 10
	mov si, labelFreeChunks
	call common_graphics_text_print_at
	
	mov si, itoaBuffer
	pusha
	mov dx, 0
	mov ax, word [cs:statFreeChunks]	; number in DX:AX
	mov bl, 2							; formatting
	int 0A2h
	popa
	add bx, 150
	call common_graphics_text_print_at
	
	pop ds
	popa
	ret
	
	
; Allocates a chunk of memory and draws a corresponding rectangle
;
; input:
;		DX - size to allocate
;		CL - colour
; output:
;	 DS:SI - allocated pointer
;		AX - 0 when allocation failed, other value otherwise
allocate_and_draw:
	push bx
	push cx
	push dx
		
	mov si, pressToAllocate
	call write_message_and_wait
	
	mov ax, dx					; allocate this many bytes
	call common_memory_allocate	; DS:SI := newly allocated pointer
	cmp ax, 0
	je allocate_and_draw_failed
	
	mov bx, si
	sub bx, dynamicMemoryStart
	; here, DX = allocated size
	call draw_chunk
	mov ax, 1					; success
	jmp allocate_and_draw_done
allocate_and_draw_failed:
	mov ax, 0
allocate_and_draw_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Allocates a chunk of memory and draws a corresponding rectangle.
; Does NOT prompt user to press a key.
;
; input:
;		DX - size to allocate
;		CL - colour
; output:
;	 DS:SI - allocated pointer
;		AX - 0 when allocation failed, other value otherwise
allocate_and_draw_no_prompt:
	push bx
	push cx
	push dx
	
	mov ax, dx					; allocate this many bytes
	call common_memory_allocate	; DS:SI := newly allocated pointer
	cmp ax, 0
	je allocate_and_draw_no_prompt_failed
	
	mov bx, si
	sub bx, dynamicMemoryStart
	; here, DX = allocated size
	call draw_chunk
	mov ax, 1					; success
	jmp allocate_and_draw_no_prompt_done
allocate_and_draw_no_prompt_failed:
	mov ax, 0
allocate_and_draw_no_prompt_done:
	pop dx
	pop cx
	pop bx
	ret

	
; Reallocates a chunk of memory and removes it from the indicator
;
; input:
;	 DS:SI - pointer to chunk
;		CL - colour
;		DX - size of chunk (used only for message)
;		BX - new size
; output:
;	 DS:SI - new pointer
;		AX - 0 when reallocation failed, other value otherwise
reallocate_and_draw:
	push bx
	push cx
	push dx

	mov word [cs:reallocateOriginalSegment], ds
	mov word [cs:reallocateOriginalOffset], si
	mov word [cs:reallocateNewSize], bx
	mov byte [cs:reallocateColour], cl
	
	push si
	mov si, pressToReallocate
	call write_message_and_wait
	pop si
	
	mov ax, word [cs:reallocateNewSize]
	call common_memory_reallocate	; DS:SI := new pointer
	cmp ax, 0
	je reallocate_and_draw_failed
	
	push ds
	push si							; save new pointer
	
	; erase
	mov ds, word [cs:reallocateOriginalSegment]
	mov si, word [cs:reallocateOriginalOffset]
	mov bx, si
	sub bx, dynamicMemoryStart
	; here, DX = size of original chunk
	mov cl, INDICATOR_EMPTY_COLOUR
	call draw_chunk
	
	; draw new
	pop si
	pop ds							; DS:SI := new pointer
	mov bx, si
	sub bx, dynamicMemoryStart
	mov dx, word [cs:reallocateNewSize]
	mov cl, byte [cs:reallocateColour]
	call draw_chunk
	
	mov ax, 1					; success
	jmp reallocate_and_draw_done
reallocate_and_draw_failed:
	mov ax, 0
reallocate_and_draw_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Deallocates a chunk of memory and removes it from the indicator
;
; input:
;	 DS:SI - pointer to chunk
;		CL - colour
;		DX - size of chunk (used only for message)
; output:
;		AX - 0 when deallocation failed, other value otherwise
deallocate_and_draw:
	push bx
	push cx
	push dx
	push ds
	push si
	
	push si
	mov si, pressToDeallocate
	call write_message_and_wait
	pop si
	
	call common_memory_deallocate	; CX := deallocated byte count
	cmp ax, 0
	je deallocate_and_draw_failed
	
	mov bx, si
	sub bx, dynamicMemoryStart
	mov dx, cx						; size
	mov cl, INDICATOR_EMPTY_COLOUR
	call draw_chunk
	mov ax, 1					; success
	jmp deallocate_and_draw_done
deallocate_and_draw_failed:
	mov ax, 0
deallocate_and_draw_done:
	pop si
	pop ds
	pop dx
	pop cx
	pop bx
	ret
	
	
; Draws a rectangle representing a chunk of memory
;
; input:
;		BX - start address
;		DX - length in bytes
;		CL - colour
; output:
;		none
draw_chunk:
	pusha
	
	add bx, INDICATOR_X + 1		; offset from left of indicator
	mov ax, INDICATOR_Y + 1		; offset from top of indicator
	call common_graphics_coordinate_to_video_offset
	mov di, ax					; DI := video offset
	
	mov bl, cl					; colour
	mov ax, INDICATOR_HEIGHT	; height
	call common_graphics_draw_rectangle_solid
	
	popa
	ret
	
	
; Draws the frame of the indicator
;
; input:
;		none
; output:
;		none
draw_indicator_frame:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov bx, INDICATOR_X
	mov ax, INDICATOR_Y
	call common_graphics_coordinate_to_video_offset
	mov di, ax					; DI := video offset
	
	mov bl, INDICATOR_FRAME_COLOUR
	mov ax, INDICATOR_HEIGHT + 2	; height (plus frame)
	mov dx, AVAILABLE_DYN_MEM + 2
	call common_graphics_draw_rectangle_solid
	
	pop ds
	popa
	ret
	
	
; Draws the frame of the indicator
;
; input:
;		none
; output:
;		none
draw_indicator_empty:
	pusha

	mov bx, 0
	mov dx, AVAILABLE_DYN_MEM
	mov cl, INDICATOR_EMPTY_COLOUR
	call draw_chunk
	
	popa
	ret
	
	
; Draws the label of the indicator
;
; input:
;		none
; output:
;		none
draw_indicator_label:
	pusha
	push ds

	push cs
	pop ds

	mov dx, COMMON_TEXT_PRINT_FLAG_CENTRE
	mov si, indicatorLabel
	mov ax, INDICATOR_Y + 2 + INDICATOR_HEIGHT + 3
	mov cl, INDICATOR_LABEL_COLOUR
	call common_graphics_text_print_at
	
	pop ds
	popa
	ret
	
	
; Draws the title
;
; input:
;		none
; output:
;		none
draw_title:
	pusha
	push ds

	push cs
	pop ds
	
	mov dx, COMMON_TEXT_PRINT_FLAG_CENTRE
	mov si, titleLabel
	mov ax, 4
	mov cl, TITLE_LABEL_COLOUR
	call common_graphics_text_print_at
	add ax, COMMON_GRAPHICS_FONT_HEIGHT + 2
	mov si, titleLabel2
	call common_graphics_text_print_at
	
	pop ds
	popa
	ret
	
	
; Draws strings to show that memory immediately before and after the dynamic
; memory area have not been corrupted by dynamic memory operations
;
; input:
;		none
; output:
;		none
draw_marker_strings:
	pusha
	push ds

	push cs
	pop ds
	
	mov dx, COMMON_TEXT_PRINT_FLAG_NORMAL
	mov bx, MESSAGE_LEFT
	mov ax, 175
	mov si, beforeMem
	mov cl, INDICATOR_FRAME_COLOUR
	call common_graphics_text_print_at
	add ax, COMMON_GRAPHICS_FONT_HEIGHT + 2
	mov si, afterMem
	call common_graphics_text_print_at
	
	pop ds
	popa
	ret
	
	
%define _COMMON_MEMORY_CONFIG_			; override default chunk count value
COMMON_MEMORY_MAX_CHUNKS	equ 105

%include "common\memory.asm"
%include "common\vga320\graphics.asm"
%include "common\vga320\gra_text.asm"

beforeMem: db 'STRING RIGHT BEFORE DYNAMIC MEMORY', 0
dynamicMemoryStart: times AVAILABLE_DYN_MEM db 'E'
afterMem: db 'STRING RIGHT AFTER DYNAMIC MEMORY', 0
