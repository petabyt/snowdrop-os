;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The DRAW app.
; This app lets the user draw on a canvas.
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

MAX_STACK			equ 1000

titleString:		db 'Draw', 0

buttonClear:		db 'Clear', 0
labelInkColour:		db 'Ink Colour', 0
labelPaperColour:	db 'Paper Colour', 0

stepInitial:		db 'Starting DRAW', 13, 10, 0
stepInitDynMem:		db 'Initialized dynamic memory', 13, 10, 0
errorNoMemory:		db 'Failed to initialize dynamic memory, or not enough memory available', 13, 10, 0
errorPressAKey:		db 'Press a key to exit', 13, 10, 0

memoryNotAllocated:			db 'No memory for canvas or file buffer', 0
fileNotFound:				db 'File not found', 0
fileUnsupportedDimensions:	db 'Unsupported dimensions', 0
fileSaveErrorNoMoreFiles:	db 'Save failed: no more files', 0
fileSaveErrorDiskFull:		db 'Save failed: disk full', 0

colourPickerHandle:	dw 0
backgroundColourPickerHandle:	dw 0
allSegmentsAreAllocated:	db 0
canvasSegment:		dw 0
fileSegment:		dw 0
mouseLeftDown:		db 0

CANVAS_WIDTH		equ 320
CANVAS_HEIGHT		equ 200
CANVAS_X			equ 250
CANVAS_Y			equ 180
CANVAS_CLEAR_COLOUR	equ 15

COLOUR_PICKER_X		equ CANVAS_X - 190

CLEAR_BUTTON_X		equ 560
CLEAR_BUTTON_Y		equ CANVAS_Y + CANVAS_HEIGHT + 25

labelBrushSize:		db 'Brush Size', 0
labelBrushSmall:	db 'Small', 0
labelBrushMedium:	db 'Medium', 0
labelBrushLarge:	db 'Large', 0
labelBrushHuge:		db 'Huge', 0
BRUSH_SIZE_RADIO_GROUP	equ 0
brushSmallHandle:	dw 0
brushMediumHandle:	dw 0
brushLargeHandle:	dw 0
brushHugeHandle:	dw 0
brushSize:			dw 0

BRUSH_SIZE_SMALL	equ 1		; keep these odd, so mouse is always
BRUSH_SIZE_MEDIUM	equ 5		; in the centre of the stroke
BRUSH_SIZE_LARGE	equ 9
BRUSH_SIZE_HUGE		equ 21

FILE_BOX_X			equ 230
FILE_BOX_Y			equ 50
FILE_BOX_MAX_CHARS	equ 12
filenameBoxHandle:	dw 0
labelFilename:		db 'File name (name.ext):', 0
labelExample:		db '(example file:  draw.bmp)', 0

FILE_NAME_MAX_SIZE	equ 12		; 8+3 plus extension dot
fat12Filename: 		times FILE_NAME_MAX_SIZE+1 db 0

fileLoading:			db 'Loading image', 0
fileSaving:				db 'Saving image', 0
loadFileButton:			db 'Load', 0
loadFileButtonHandle:	dw 0
saveFileButton:			db 'Save', 0
saveFileButtonHandle:	dw 0


start:
	mov si, stepInitial
	int 80h
	
	; initialize dynamic memory - this is required by GUI extensions
	mov si, allocatableMemoryStart
	mov ax, 65535 - MAX_STACK
	sub ax, allocatableMemoryStart
	call common_memory_initialize
	cmp ax, 0
	je no_memory
	mov si, stepInitDynMem
	int 80h
	
	; request a memory segment - it's where we'll store the canvas bitmap
	int 91h						; ask kernel for a memory segment in BX
	cmp ax, 0					; did we get one?
	jne after_segment_allocation	; no
	; yes
	mov word [cs:canvasSegment], bx
	
	; and one for file load/save
	int 91h						; ask kernel for a memory segment in BX
	cmp ax, 0					; did we get one?
	jne after_segment_allocation	; no
	; yes
	mov word [cs:fileSegment], bx
	
	mov byte [cs:allSegmentsAreAllocated], 1

after_segment_allocation:	

	; initialize GUI framework extensions interface
	; this is required before any extensions can initialize
	call common_gx_initialize
	
	; initialize GUI framework extensions which we'll use here
	; they must be initialized before the GUI framework is prepared
	call common_gx_colours_initialize
	call common_gx_text_initialize

	call common_gui_prepare					; must call this before any
											; other GUI framework functions
	
	; any long application initialization (e.g.: loading from disk, etc.)
	; should happen here, since the GUI framework has shown a "loading..."
	; notice
	
	; set application title
	mov si, titleString						; DS:SI := pointer to title string
	call common_gui_title_set										
	
	; set up the initialized callback, which is invoked by the GUI framework
	; right after it has initialized itself
	mov si, initialized_callback
	call common_gui_initialized_callback_set
	
	mov si, on_refresh_callback
	call common_gui_on_refresh_callback_set	; we need to know when the GUI
											; framework refreshes the screen
											; so we draw our custom things
											
	mov si, on_mouse_event_callback
	call common_gui_mouse_event_callback_set	; we need to know when the
												; mouse does something
	; yield control permanently to the GUI framework
	call common_gui_start
	; the function above does not return control to the caller

no_memory:
	push cs
	pop ds
	mov si, errorNoMemory
	jmp print_error_and_exit
	
print_error_and_exit:
	int 80h
	mov si, errorPressAKey
	int 80h
	mov ah, 0
	int 16h
	int 95h						; exit


; Draws a message on the screen
;
; input:
;		none
; output:
;		none	
draw_text:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	
	mov bx, COLOUR_PICKER_X
	mov ax, CANVAS_Y + 45
	mov si, labelInkColour
	call common_gui_util_print_single_line_text_with_erase
	
	add ax, 145
	mov si, labelPaperColour
	call common_gui_util_print_single_line_text_with_erase
	
	mov bx, COLOUR_PICKER_X
	mov ax, CANVAS_Y+70
	mov si, labelBrushSize
	call common_gui_util_print_single_line_text_with_erase
	
	mov bx, FILE_BOX_X - 170
	mov ax, FILE_BOX_Y + 6
	mov si, labelFilename
	call common_gui_util_print_single_line_text_with_erase
	
	add ax, 2*COMMON_GRAPHICS_FONT_HEIGHT
	add bx, 170
	mov si, labelExample
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
draw_text_done:
	pop ds
	popa
	ret
	
	
; Draws the canvas from memory, onto screen
;
; input:
;		none
; output:
;		none
draw_canvas:
	pusha
	push ds
	push es
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	; draw canvas
	mov bx, CANVAS_X
	mov ax, CANVAS_Y
	mov cx, CANVAS_WIDTH
	mov di, CANVAS_HEIGHT
	
	mov ds, word [cs:canvasSegment]
	mov si, 0
	
	mov dx, CANVAS_WIDTH
	call common_graphics_draw_rectangle_opaque

	; outline
	call common_gui_get_colour_foreground			; CX := colour
	mov dl, cl	
	dec bx
	dec ax
	mov cx, CANVAS_WIDTH + 2
	mov si, CANVAS_HEIGHT + 2
	call common_graphics_draw_rectangle_outline_by_coords
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing							
	pop es
	pop ds
	popa
	ret
	

; Clears the canvas storage
;
; input:
;		none
; output:
;		none	
clear_canvas:
	pushf
	pusha
	push es
	
	mov ax, word [cs:backgroundColourPickerHandle]
	call common_gx_colours_get_colour			; AX := colour
	
	mov es, word [cs:canvasSegment]
	mov di, 0
	mov cx, CANVAS_WIDTH * CANVAS_HEIGHT
	
	cld
	rep stosb
	
	pop es
	popa
	popf
	ret
	

; Paints a single stroke at the specified location
;
; input:
;		BX - mouse X
;		CX - mouse Y
;		DL - colour
; output:
;		none
paint_one:
	pusha
	
	cmp bx, CANVAS_X
	jb paint_one_done
	cmp bx, CANVAS_X + CANVAS_WIDTH
	jae paint_one_done
	cmp cx, CANVAS_Y
	jb paint_one_done
	cmp cx, CANVAS_Y + CANVAS_HEIGHT
	jae paint_one_done
	
	call draw_rectangle_within_bounds	
paint_one_done:
	popa
	ret
	
	
; Paints a single stroke at the specified location
;
; input:
;		BX - mouse X
;		CX - mouse Y
;		DL - colour
; output:
;		none
draw_rectangle_within_bounds:
	pusha
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	
	mov ax, cx							; AX := Y
	; here, BX = X
	; here, DL = colour
	; now center on mouse position
	push dx
	mov dx, word [cs:brushSize]
	shr dx, 1
	sub bx, dx							; offset X
	sub ax, dx							; offset Y
	pop dx
	mov si, bx							; [1] save X
	
	mov cx, word [cs:brushSize]
draw_rectangle_within_bounds__outer:
	mov bx, si							; [1] restore X
	push cx
	mov cx, word [cs:brushSize]
draw_rectangle_within_bounds__inner:
	; check whether this pixel will fall inside canvas
	cmp bx, CANVAS_X
	jb draw_rectangle_within_bounds__inner_next
	cmp bx, CANVAS_X + CANVAS_WIDTH
	jae draw_rectangle_within_bounds__inner_next
	cmp ax, CANVAS_Y
	jb draw_rectangle_within_bounds__inner_next
	cmp ax, CANVAS_Y + CANVAS_HEIGHT
	jae draw_rectangle_within_bounds__inner_next
	; it's inside, so draw this pixel
	call common_graphics_draw_pixel_by_coords
	call draw_pixel_to_canvas_memory
draw_rectangle_within_bounds__inner_next:
	inc bx								; X++
	loop draw_rectangle_within_bounds__inner
	pop cx
	
	inc ax								; Y++
	loop draw_rectangle_within_bounds__outer
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	popa
	ret
	
	
; Zeroes out file segment
;
; input:
;		none
; output:
;		none
clear_file_segment:
	pusha
	pushf
	push es
	
	mov cx, 8000h
	mov ax, 0
	mov es, word [cs:fileSegment]
	mov di, 0
	cld
	rep stosw
	
	pop es
	popf
	popa
	ret
	
	
; Draws a pixel from coordinates, to the canvas memory
;
; input: 
;		BX - position X
;		AX - position Y
;		DL - colour
; output:
;		none
draw_pixel_to_canvas_memory:
	push ds
	pusha
	
	sub bx, CANVAS_X
	sub ax, CANVAS_Y				; canvas is not at 0, 0
	mov cx, CANVAS_WIDTH
	push dx							; [1]
	mul cx
	pop dx							; [1]
	add ax, bx
	xchg ax, bx						; BX := offset of pixel in canvas memory
	mov ds, word [cs:canvasSegment]
	mov byte [ds:bx], dl

	popa
	pop ds
	ret
	

;==============================================================================
; Callbacks
;==============================================================================

; Called by the GUI framework after it has initialized itself
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
initialized_callback:
	cmp byte [cs:allSegmentsAreAllocated], 0
	je initialized_callback_done
	
	push cs
	pop ds
	
	; "clear" button
	mov si, buttonClear
	mov ax, CLEAR_BUTTON_X
	mov bx, CLEAR_BUTTON_Y
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov si, clear_click_callback
	call common_gui_button_click_callback_set

	; "load" button
	mov si, loadFileButton
	mov ax, FILE_BOX_X + 120
	mov bx, FILE_BOX_Y + 2
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov word [cs:loadFileButtonHandle], ax
	mov si, load_click_callback
	call common_gui_button_click_callback_set
	call common_gui_button_disable
	
	; "save" button
	mov si, saveFileButton
	mov ax, FILE_BOX_X + 170
	mov bx, FILE_BOX_Y + 2
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov word [cs:saveFileButtonHandle], ax
	mov si, save_click_callback
	call common_gui_button_click_callback_set
	call common_gui_button_disable
	
	; ink colour picker
	mov ax, COLOUR_PICKER_X
	mov bx, CANVAS_Y
	call common_gx_colours_add
	mov word [cs:colourPickerHandle], ax
	mov bx, COMMON_GRAPHICS_COLOUR_BLACK
	call common_gx_colours_set_colour
	
	; paper colour picker
	mov ax, COLOUR_PICKER_X
	mov bx, CANVAS_Y+145
	call common_gx_colours_add
	mov word [cs:backgroundColourPickerHandle], ax
	mov bx, COMMON_GRAPHICS_COLOUR_WHITE
	call common_gx_colours_set_colour
	
	; brush size selectors
	mov ax, COLOUR_PICKER_X
	mov bx, CANVAS_Y+80
	mov di, BRUSH_SIZE_RADIO_GROUP
	mov si, labelBrushSmall
	call common_gui_radio_add_auto_scaled
	mov word [cs:brushSmallHandle], ax
	mov si, brush_size_changed_callback
	call common_gui_radio_change_callback_set
	
	mov ax, COLOUR_PICKER_X
	add bx, 10
	mov si, labelBrushMedium
	call common_gui_radio_add_auto_scaled
	mov word [cs:brushMediumHandle], ax
	mov si, brush_size_changed_callback
	call common_gui_radio_change_callback_set
	
	mov ax, COLOUR_PICKER_X
	add bx, 10
	mov si, labelBrushLarge
	call common_gui_radio_add_auto_scaled
	mov word [cs:brushLargeHandle], ax
	mov si, brush_size_changed_callback
	call common_gui_radio_change_callback_set
	
	mov ax, COLOUR_PICKER_X
	add bx, 10
	mov si, labelBrushHuge
	call common_gui_radio_add_auto_scaled
	mov word [cs:brushHugeHandle], ax
	mov si, brush_size_changed_callback
	call common_gui_radio_change_callback_set
	
	mov ax, word [cs:brushMediumHandle]
	mov bx, 1
	call common_gui_radio_set_checked
	
	mov ax, FILE_BOX_X
	mov bx, FILE_BOX_Y
	mov cx, FILE_BOX_MAX_CHARS
	call common_gx_text_add
	mov word [cs:filenameBoxHandle], ax
	mov si, filename_changed_callback
	call common_gx_text_changed_callback_set
	call common_gx_text_select
	
	call clear_canvas
	call draw_canvas
initialized_callback_done:
	retf


; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
;		BX - 0 when not selected
; output:
;		none	
brush_size_changed_callback:
brush_size_changed_callback__small:
	cmp ax, word [cs:brushSmallHandle]
	jne brush_size_changed_callback__medium
	mov word [cs:brushSize], BRUSH_SIZE_SMALL
	jmp brush_size_changed_callback_done
brush_size_changed_callback__medium:
	cmp ax, word [cs:brushMediumHandle]
	jne brush_size_changed_callback__large
	mov word [cs:brushSize], BRUSH_SIZE_MEDIUM
	jmp brush_size_changed_callback_done
brush_size_changed_callback__large:
	cmp ax, word [cs:brushLargeHandle]
	jne brush_size_changed_callback__huge
	mov word [cs:brushSize], BRUSH_SIZE_LARGE
	jmp brush_size_changed_callback_done
brush_size_changed_callback__huge:
	mov word [cs:brushSize], BRUSH_SIZE_HUGE
brush_size_changed_callback_done:	
	retf
	
	
; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
clear_click_callback:
	call clear_canvas
	call draw_canvas
	retf
	
	
; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
save_click_callback:	
	; convert to FAT12 name
	mov ax, word [cs:filenameBoxHandle]
	call common_gx_text_contents_get		; DS:SI := ptr to 8.3 file name
	
	push cs
	pop es
	mov di, fat12Filename
	int 0A6h								; fill in FAT12 name
	
	; show a notice
	push cs
	pop ds
	mov si, fileSaving
	call common_gui_util_show_notice
	
	call clear_file_segment

	; write BMP file from canvas memory
	push cs
	pop fs
	mov dx, fat12Filename					; FS:DX := FAT12 file name
	
	mov ds, word [cs:fileSegment]
	mov si, 0								; DS:SI := ptr to work buffer
	
	mov es, word [cs:canvasSegment]
	mov di, 0								; ES:DI := ptr to canvas memory
	
	mov ax, CANVAS_WIDTH
	mov bx, CANVAS_HEIGHT
	call common_bmps_write_to_file

	cmp ax, 1
	je save_click_callback__no_more_files
	cmp ax, 2
	je save_click_callback__disk_full
	
	call common_gui_redraw_screen
	jmp save_click_callback_done
	
save_click_callback__no_more_files:
	push cs
	pop ds
	mov si, fileSaveErrorNoMoreFiles
	call common_gui_util_show_notice
	mov cx, 100
	int 85h
	call common_gui_redraw_screen
	jmp save_click_callback_done
	
save_click_callback__disk_full:
	push cs
	pop ds
	mov si, fileSaveErrorDiskFull
	call common_gui_util_show_notice
	mov cx, 100
	int 85h
	call common_gui_redraw_screen
	jmp save_click_callback_done
	
save_click_callback_done:
	retf
	
	
; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
load_click_callback:
	; convert to FAT12 name
	mov ax, word [cs:filenameBoxHandle]
	call common_gx_text_contents_get		; DS:SI := ptr to 8.3 file name
	
	push cs
	pop es
	mov di, fat12Filename
	int 0A6h								; fill in FAT12 name
	
	; show a notice
	push cs
	pop ds
	mov si, fileLoading
	call common_gui_util_show_notice
	
	; load file
	mov si, fat12Filename		; DS:SI := ptr to file name
	
	mov es, word [cs:fileSegment]
	mov di, 0					; ES:DI now points to where we'll load file
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes	
	cmp al, 0
	jne load_click_callback__file_not_found
	; file was loaded successfully

	mov ds, word [cs:fileSegment]
	mov si, 0					; DS:SI now points to file data
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	call common_bmp_get_dimensions	; AX:BX - height of image
									; CX:DX - width of image
	
	cmp bx, 0
	je load_click_callback__unsupported_dimensions
	cmp dx, 0
	je load_click_callback__unsupported_dimensions
	cmp bx, CANVAS_HEIGHT
	ja load_click_callback__unsupported_dimensions
	cmp dx, CANVAS_WIDTH
	ja load_click_callback__unsupported_dimensions
	
	mov si, di						; DS:SI := ptr to pixel data
	
	mov es, word [cs:canvasSegment]
	mov di, 0						; ES:DI := ptr to canvas memory
	cld
	
	call clear_canvas
	; write line by line from bitmap to canvas memory
load_click_callback__line_loop:
	push di						; [1] save ptr to start of canvas line
	
	mov cx, dx					; CX := width
	rep movsb					; copy line from bitmap to canvas memory
	
	pop di						; [1] restore ptr to start of canvas line
	add di, CANVAS_WIDTH		; next canvas line
	dec bx						; next bitmap line
	jnz load_click_callback__line_loop
	
	call common_gui_redraw_screen
	jmp load_click_callback_done
	
load_click_callback__unsupported_dimensions:
	push cs
	pop ds
	mov si, fileUnsupportedDimensions
	call common_gui_util_show_notice
	mov cx, 100
	int 85h
	call common_gui_redraw_screen
	jmp load_click_callback_done
	
load_click_callback__file_not_found:
	push cs
	pop ds
	mov si, fileNotFound
	call common_gui_util_show_notice
	mov cx, 100
	int 85h
	call common_gui_redraw_screen
	
load_click_callback_done:
	retf
	
	
; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
filename_changed_callback:
	call common_gx_text_contents_get		; DS:SI := ptr to text
	int 0A9h								; AX := 0 when valid 8.3 filename
	cmp ax, 0
	jne filename_changed_callback_invalid
	
	; it contains a valid file name
	mov ax, word [cs:loadFileButtonHandle]
	call common_gui_button_enable
	mov ax, word [cs:saveFileButtonHandle]
	call common_gui_button_enable
	retf
filename_changed_callback_invalid:
	; it contains an invalid file name
	mov ax, word [cs:loadFileButtonHandle]
	call common_gui_button_disable
	mov ax, word [cs:saveFileButtonHandle]
	call common_gui_button_disable
	retf

	
; Callback for GUI framework's "on refresh". This will redraw anything custom
; we have to draw.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none	
on_refresh_callback:
	cmp byte [cs:allSegmentsAreAllocated], 0
	jne on_refresh_callback_perform
	
	push cs
	pop ds
	mov si, memoryNotAllocated
	call common_gui_util_show_notice
	
	jmp on_refresh_callback_done

on_refresh_callback_perform:
	call draw_text
	
	cmp byte [cs:allSegmentsAreAllocated], 0
	je on_refresh_callback_done
	
	call draw_canvas
on_refresh_callback_done:
	retf


; Invoked by the GUI framework on mouse move	
;
; Callbacks MUST use retf upon returning
; Callbacks are not expected to preserve any registers
; input:
;		AX - 0 for left mouse button down
;			 1 for left mouse button up
;			 2 for right mouse button down
;			 3 for right mouse button up
;			 4 for mouse move
;		BX - mouse X
;		CX - mouse Y
; output:
;		none
on_mouse_event_callback:
	cmp byte [cs:allSegmentsAreAllocated], 0
	je on_mouse_event_callback_done
	
	cmp ax, 0
	je on_mouse_event_callback__left_down
	cmp ax, 1
	je on_mouse_event_callback__left_up
	cmp ax, 2
	je on_mouse_event_callback__right_down
	cmp ax, 3
	je on_mouse_event_callback__right_up
	cmp ax, 4
	je on_mouse_event_callback__mouse_move
	
	jmp on_mouse_event_callback_done
	
on_mouse_event_callback__left_down:
	mov byte [cs:mouseLeftDown], 1
	mov ax, word [cs:colourPickerHandle]
	call common_gx_colours_get_colour
	mov dl, al
	call paint_one
	jmp on_mouse_event_callback_done
	
on_mouse_event_callback__left_up:
	mov byte [cs:mouseLeftDown], 0
	jmp on_mouse_event_callback_done
	
on_mouse_event_callback__right_down:
	jmp on_mouse_event_callback_done
	
on_mouse_event_callback__right_up:
	jmp on_mouse_event_callback_done
	
on_mouse_event_callback__mouse_move:
	cmp byte [cs:mouseLeftDown], 0
	je on_mouse_event_callback_done
	mov ax, word [cs:colourPickerHandle]
	call common_gx_colours_get_colour
	mov dl, al
	call paint_one
	jmp on_mouse_event_callback_done
	
on_mouse_event_callback_done:
	retf
	

%include "common\vga640\gui\ext\gx.asm"				; must be included first

%include "common\vga640\gui\ext\gx_clrs.asm"
%include "common\vga640\gui\ext\gx_text.asm"
%include "common\vga640\gui\gui.asm"
%include "common\memory.asm"
%include "common\bmp.asm"
%include "common\bmps.asm"


allocatableMemoryStart:
