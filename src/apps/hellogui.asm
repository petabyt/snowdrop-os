;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The HELLOGUI app.
; This app fits the "first app" stereotype for working with Snowdrop's GUI
; framework.
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

titleString:		db 'Hello Gui', 0
helloWorldString:	db 'Hello, world!', 0
hiThereString:		db 'Hi There!', 0
buttonClicked:		db 0

BUTTON_X			equ 50
BUTTON_Y			equ 75

start:
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
	
	; yield control permanently to the GUI framework
	call common_gui_start
	; the function above does not return control to the caller


; Draws a message on the screen
;
; input:
;		none
; output:
;		none	
draw_message:
	pusha
	
	cmp byte [cs:buttonClicked], 0
	je draw_message_done				; draw nothing if button
										; not yet clicked
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	; draw text next to our button
	push cs
	pop ds
	mov si, hiThereString				; DS:SI := pointer to string
	
	mov bx, BUTTON_X + 120				; position X
	mov ax, BUTTON_Y + 3				; position Y
	mov dx, 1							; bit 0 = "double horizontal width"
	mov cl, 39							; colour (red)
	call common_graphics_text_print_at	; draw text
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
draw_message_done:
	popa
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
	; create our button
	mov si, helloWorldString
	mov ax, BUTTON_X						; position X
	mov bx, BUTTON_Y						; position Y
	call common_gui_button_add_auto_scaled	; AX := button handle
	
	; specify a click callback for our button
	mov si, click_callback
	call common_gui_button_click_callback_set
	
	retf
	

; Callback for our button.
; This function is invoked by the GUI framework when our button is clicked.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - button handle
; output:
;		none
click_callback:
	call common_gui_button_disable		; disable button
	mov byte [cs:buttonClicked], 1
	call draw_message
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
	call draw_message
	retf


%include "common\vga640\gui\gui.asm"
%include "common\vga640\gra_text.asm"
