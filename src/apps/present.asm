;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The PRESENT app.
; This app serves as a simple slide show presentation application.
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

	bits 16
	org 0

	jmp start


TEXT_AREA_ATTRIBUTES equ COMMON_FONT_COLOUR_BROWN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLUE

VRAM_SIZE equ COMMON_SCREEN_HEIGHT * COMMON_SCREEN_WIDTH * 2
EDITABLE_VRAM_SIZE equ VRAM_SIZE - ( COMMON_SCREEN_WIDTH * 2 )	
						; bottom-most line is reserved for info

fat12Filename: db "        TXT", 0			; stores slide file name

overlayString1: db " Snowdrop OS Presenter    (Slide: ", 0
overlayString2:	db ")   [LEFT/RIGHT]-Previous/Next  [ESC]-Exit", 0

fileSize: dw 0
slideNumber: db 0
largeNumberBufferString: times 16 db 0			; will hold the result of itoa

filenameLength: db 0

noSlidesFoundTitle: db "Press [ESC] to exit", 0
slideNotFound1: db "Unable to find first slide. File '", 0
slideNotFound2: db "' was not found.", 13, 10, 0
toDotFilename: times 12 db 0

paramSlide: db 'slideName', 0
paramValueBuffer: times 257 db 0
usageString: 	db 13, 10
				db 'Example usage:    PRESENT [slideName=slide]', 13, 10
				db 'This will expect slide files called SLIDE000.TXT, SLIDE001.TXT, etc.', 13, 10
				db 'Value of slideName must be between 1 and 5 characters.', 13, 10, 0

start:
	call read_file_name_argument	; read from user, into [fat12Filename]
	
	mov al, byte [slideNumber]
	call convert_slide_number_to_file_name

	call load_file
	cmp al, 0					; does first slide exist?
	jne start_no_slides			; no
	
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	; here, first slide has been loaded successfully
	call display_file_contents

	int 83h						; clear keyboard buffer
	
	call read_user_input		; enter infinite "read user input" loop

start_no_slides:
	mov si, fat12Filename
	mov di, toDotFilename
	int 0B3h					; convert FAT12 file name to 8.3 file name
	
	mov si, slideNotFound1
	int 80h						; print error
	mov si, toDotFilename
	int 80h						; print file name
	mov si, slideNotFound2
	int 80h						; print error
	int 95h						; exit


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	
; Read file name from parameter, or show error and exit if value was invalid
; or not present.
;
read_file_name_argument:
	pusha
	pushf
	push ds
	
	mov si, paramSlide
	mov di, paramValueBuffer
	int 0BFh					; read param value
	cmp ax, 0
	je read_file_name_argument_exit			; not found

	mov si, paramValueBuffer
	int 0A5h					; BX := string length
	cmp bx, 5
	ja read_file_name_argument_exit
	cmp bx, 0
	je read_file_name_argument_exit
	
	; it's valid!
	mov si, paramValueBuffer
	mov byte [filenameLength], bl ; BX = BL, since BH is 0
	
	int 82h						; convert input to upper case
	mov di, fat12Filename
	mov cx, bx					; CX := input length
	cld
	rep movsb					; copy upper case input to FAT12 file name

	pop ds
	popf
	popa
	ret

read_file_name_argument_exit:
	; not found or invalid; show error message and exit
	mov si, usageString
	int 80h
	int 95h							; exit program


; Converts number in AL to a slide file name, storing it in [fat12Filename]
;
; input:
;		AL - slide number
convert_slide_number_to_file_name:
	pusha
	
	mov ah, 0			
	mov dx, 0					; DX:AX := slide number
	mov si, largeNumberBufferString
	mov bl, 0					; formatting option 0 - leading zeroes
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI
	add si, 6					; we got a 9-digit string, so we move to
								; last 3 digits

	mov di, fat12Filename
	mov ch, 0
	mov cl, byte [filenameLength]
	add di, cx					; DI now points to right after slide prefix
	
	cld
	movsb
	movsb
	movsb						; copy 3 digits into file name string
								
	popa
	ret


; Renders the text in [fileContentsBuffer] to the display
;
display_file_contents:
	pusha
	
	mov dl, TEXT_AREA_ATTRIBUTES
	call common_clear_screen_to_colour
	
	call draw_overlay
	
	mov bh, 0					; row
	mov bl, 0					; column
	int 9Eh						; move cursor
	mov si, fileContentsBuffer
	mov cx, word [fileSize]
	int 0A8h					; dump CX characters from DS:SI to current 
								; virtual display								
	call hide_video_cursor
	
	popa
	ret
	

; Reads the contents of file whose name is in [fat12Filename], storing 
; it in [fileContentsBuffer]
;
; output:
;		AL - 0 when file is found
;
load_file:
	push si
	push di
	push cx
	
	mov si, fat12Filename
	mov di, fileContentsBuffer
	int 81h						; load file: AL = 0 when successful
								; CX = file size in bytes
	cmp al, 0					; was the file found?
	je load_file_store_size		; yes, store its size
	; file was not found, set size to 0
	mov cx, 0
load_file_store_size:
	mov word [fileSize], cx
	
	pop cx
	pop di
	pop si
	ret


; Draws informational text at the bottom of the screen
;
draw_overlay:
	pusha
	
	mov bh, COMMON_SCREEN_HEIGHT - 1	; row
	mov bl, 0							; column
	int 9Eh								; move cursor
	
	mov cx, COMMON_SCREEN_WIDTH
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_RED
	int 9Fh						; attributes

	mov si, overlayString1
	int 97h
	mov si, largeNumberBufferString
	add si, 6
	int 97h
	mov si, overlayString2
	int 97h
	
	popa
	ret


; The main "user input->action" procedure
;
read_user_input:
	pusha

read_user_input_read:
	mov ah, 0
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	
	cmp ah, COMMON_SCAN_CODE_LEFT_ARROW
	je handle_left_arrow
	
	cmp ah, COMMON_SCAN_CODE_RIGHT_ARROW
	je handle_right_arrow
	
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je handle_escape
	
	jmp read_user_input_read	; read another character

handle_left_arrow:
	call previous_slide
	jmp read_user_input_done_handling

handle_right_arrow:
	call next_slide
	jmp read_user_input_done_handling
	
handle_escape:
	int 95h							; exit program

read_user_input_done_handling:
	jmp read_user_input

	popa
	ret


; Attempt to load and display a previous slide
;
previous_slide:
	pusha

	cmp byte [slideNumber], 0
	je previous_slide_done				; NOOP when on first slide
	
	dec byte [slideNumber]
	mov al, byte [slideNumber]
	call convert_slide_number_to_file_name
	call load_file						; previous slide is guaranteed to exist
										; so we don't need to check for success
	call display_file_contents
previous_slide_done:
	popa
	ret


; Attempt to load and display a next slide
;
next_slide:
	pusha
	
	mov al, byte [slideNumber]
	inc al
	call convert_slide_number_to_file_name

	call load_file
	cmp al, 0					; does next slide exist?
	jne next_slide_done			; no, so NOOP
	; yes
	call display_file_contents
	inc byte [slideNumber]		; update slide number
next_slide_done:
	popa
	ret

	
; Hide video cursor by moving it to the bottom of the screen, and making that
; character red ink on red background
;
hide_video_cursor:
	pusha
	
	mov bh, COMMON_SCREEN_HEIGHT - 1
	mov bl, 0
	int 9Eh						; move cursor
	
	mov dl, COMMON_FONT_COLOUR_RED | COMMON_BACKGROUND_COLOUR_RED
	mov cx, 1					; set attributes on this many characters
	int 9Fh						; attributes (passed in DL)
	
	popa
	ret


fileContentsBuffer: times EDITABLE_VRAM_SIZE db 0 ; this is where we're loading
												  ; file contents
%include "common\colours.asm"
%include "common\screen.asm"
%include "common\scancode.asm"
%include "common\textbox.asm"
