;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BMPTEST app.
; This app demonstrates how to load BMP image files and display them on screen.
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

fat12Filename:		db "BMPTEST BMP", 0
allocatedSegment: 	dw 0			; we'll load the image file here

start:
	call common_task_allocate_memory_or_exit	; BX := allocated segment
	mov word [cs:allocatedSegment], bx			; store allocated memory
	
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 83h						; clear keyboard buffer
	call common_graphics_enter_graphics_mode
	; done initialization

	call load_file
	call load_palette
	call draw_bitmap
	
	mov ah, 0
	int 16h							; wait for key to exit
	
	mov cx, 3						; fade delay
	call common_graphics_fx_fade	; fade screen to black
	
	call common_graphics_leave_graphics_mode
	mov bx, word [cs:allocatedSegment]
	int 92h							; deallocate memory
	int 95h							; exit

;------------------------------------------------------------------------------
; Procedures
;------------------------------------------------------------------------------

; Draws the bitmap that has been loaded into memory
;
; input:
;		none
; output:
;		none
draw_bitmap:
	pusha
	push ds
	push es
	
	push word [cs:allocatedSegment]
	pop ds
	mov si, 0					; DS:SI now points to file data
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	call common_bmp_get_dimensions	; AX:BX - height of image
									; CX:DX - width of image
	
	mov ax, bx						; AX := low word of image height
									; DX = low word of image width (from above)

	push word [cs:allocatedSegment]
	pop ds
	mov bx, di						; DS:BX := pointer to pixel data
	mov si, dx						; SI := low word of bitmap width
	mov di, 0						; offset in video memory
	call common_graphics_draw_rectangle_opaque
	
	pop es
	pop ds
	popa
	ret
	
	
; Makes active the palette of the bitmap that has been 
; loaded into memory
;
; input:
;		none
; output:
;		none
load_palette:
	pusha
	push ds
	
	push word [cs:allocatedSegment]
	pop ds
	mov si, 0					; DS:SI now points to file data
	call common_bmp_get_VGA_palette_from_bmp	; DS:SI := ptr to palette
	call common_graphics_load_palette
	
	pop ds
	popa
	ret
	
	
; Loads the bitmap file into memory
;
; input:
;		none
; output:
;		none
load_file:
	pusha
	push ds
	push es
	
	push cs
	pop ds
	mov si, fat12Filename		; DS:SI now points to file name
	push word [cs:allocatedSegment]
	pop es
	mov di, 0					; ES:DI now points to where we'll load file
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
	pop es
	pop ds
	popa
	ret
	

%include "common\bmp.asm"
%include "common\tasks.asm"
%include "common\vga320\graphics.asm"
%include "common\gra_fx.asm"

bmpPaletteBuffer: times COMMON_GRAPHICS_PALETTE_TOTAL_SIZE db 0
