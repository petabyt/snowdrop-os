;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The TEXTEDIT app.
; This is the Text Editor, used to edit small text files.
; Also, it is integrated with BASIC and the GUI framework, allowing visual,
; mouse-driven BASIC applications to be developed from within.
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

CYAN_ON_BLUE equ COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLUE
RED_ON_BLUE equ COMMON_FONT_COLOUR_RED | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLUE
BLUE_ON_BLUE equ COMMON_FONT_COLOUR_BLUE | COMMON_BACKGROUND_COLOUR_BLUE

EDITOR_HEIGHT equ COMMON_SCREEN_HEIGHT - 1

VRAM_SIZE equ COMMON_SCREEN_HEIGHT * COMMON_SCREEN_WIDTH * 2
EDITABLE_VRAM_SIZE equ VRAM_SIZE - ( COMMON_SCREEN_WIDTH * 2 )	
						; bottom-most line is reserved for info
tempVramBufferSeg:	dw 0
tempVramBufferOff:	dw 0
						
EDITABLE_CHARACTER_COUNT equ EDITABLE_VRAM_SIZE / 2	; since half are attributes

FILE_BOX_TOP equ 9
FILE_BOX_LEFT equ 15
FILE_BOX_CONTENTS_HEIGHT equ 3
FILE_BOX_CONTENTS_WIDTH equ 43

FILE_NAME_MAX_SIZE equ 12		; 8+3 plus extension dot

errorCouldNotAllocateRenderedTextSegment:	db 'Error: could not allocate rendered text segment', 13, 10, 0
errorCouldNotAllocateDynMemSegment:			db 'Error: could not allocate dynamic memory segment', 13, 10, 0

usageString: 	db 'Text file can also be specified as a parameter:    TEXTEDIT [file=memo.txt]', 13, 10
				db 13, 10
				db 'Editor commands:', 13, 10
				db '    ESC - exits editor (without confirmation)', 13, 10
				db '     F2 - save file', 13, 10
				db '     F4 - run BASIC interpreter on file', 13, 10
				db '     F5 - show BASIC interpreter help', 13, 10
				db '     F6 - show BASIC GUI help', 13, 10
				db '  ENTER - inserts an empty line below the cursor location', 13, 10
				db ' CTRL-I - inserts an empty line at cursor location', 13, 10
				db ' CTRL-L - clear contents of current line', 13, 10
				db ' CTRL-D - deletes current line', 13, 10
				db ' CTRL-C - copy current line to memory', 13, 10
				db ' CTRL-V - paste line from memory onto current line', 13, 10
				db 0

filenameBuffer:	times 15 db 0
fat12Filename: times FILE_NAME_MAX_SIZE+1 db 0

initialOverlayString: db ' Snowdrop OS Text Editor', 0
preparingOverlayString: db ' Snowdrop OS Text Editor - preparing...', 0
overlayString1:	db ' File ', 0
overlayString2:	db 'Line ', 0
overlayString3:	db 'F2-Save  F4-Run BASIC  F5/F6-BASIC help  ESC-Exit', 0
textFileTitle: 			db 'Text File', 0
enterFileNameString:	db 'Enter file name: ', 0
messagePressAKey:		db 13, 10, 'Press a key to exit', 0
loadedFileTooLarge:		db 'COULD NOT LOAD FILE BECAUSE IT IS TOO LARGE', 13, 10
						db 'PRESS A KEY TO EXIT', 0

SCREEN_WIDTH equ COMMON_SCREEN_WIDTH	; Nasm particularity/bug.. can't use
										; COMMON_SCREEN_WIDTH directly with
										; times
						
tempLine:		times SCREEN_WIDTH db ' ';	; used for copy/paste
hasCopiedOnce:	db 0

loadedFileSize:	dw 0
fileNameFound:	db 0	; whether the file name was found in params, so we know
					; if we have to prompt the user
					
fileLoadSegment:	dw 0		; stores file text
FILE_LOAD_BUFFER_OFFSET	equ 0	; offset into file text segment

renderedSegment:	dw 0		; stores rendered file
RENDERED_BUFFER_OFFSET	equ 0	; offset into rendered segment

dynamicMemorySegment:	dw 0	; used by BASIC, and also by buffer T used when
								; transferring bytes:
								;   virtual display -> buffer T -> rendered seg
DYNAMIC_MEMORY_TOTAL_SIZE	equ 65500

currentCursorLine:		dw 0	; within file
renderedPageCount:		db 0
currentTopLine:			dw 0
MAX_PAGES				equ (65000 / (EDITABLE_CHARACTER_COUNT+1)) - 1
								; the +1 is there because otherwise NASM 
								; incorrectly complains about a division 
								; by zero 
MAX_TOP_LINE			equ (MAX_PAGES - 1) * EDITOR_HEIGHT


start:
	call common_task_allocate_memory_or_exit	; BX := allocated segment
	mov word [cs:fileLoadSegment], bx			; store it

	int 91h						; BX := allocated segment
	cmp ax, 0
	jne deallocate_file_load_and_exit	; we couldn't allocate second segment
	mov word [cs:renderedSegment], bx			; store it

	int 91h						; BX := allocated segment
	cmp ax, 0
	jne deallocate_file_load_and_rendered_and_exit
										; we couldn't allocate third
	mov word [cs:dynamicMemorySegment], bx			; store it

	mov ds, bx
	mov si, 0									; DS:SI := start of dynamic mem
	mov ax, 0 + DYNAMIC_MEMORY_TOTAL_SIZE		; size
	call common_memory_initialize
	cmp ax, 0
	je exit_and_deallocate_all		; this shouldn't really happen, since
									; we've just allocated this segment
	
	; allocate dynamic memory for the vram dump buffer
	mov ax, EDITABLE_VRAM_SIZE
	call common_memory_allocate
	cmp ax, 0
	je exit_and_deallocate_all		; this shouldn't really happen, since
									; dynamic memory is empty here
	mov word [cs:tempVramBufferSeg], ds
	mov word [cs:tempVramBufferOff], si				; store chunk

	; fill rendered segment with zeroes
	mov bx, word [cs:renderedSegment]
	push es
	mov cx, 65535
	mov di, 0
	mov es, bx
	mov al, 0
	rep stosb								; store 0 at 0 through :FFFE
	stosb									; store 0 at :FFFF
	pop es
	
	call read_file_name_argument	; read parameter into [fat12Filename]
	cmp byte [cs:fileNameFound], 0
	jne wait_for_active_display
	push cs
	pop ds
	mov si, usageString				; print usage when parameter not specified
	int 80h
	
wait_for_active_display:
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	cmp byte [cs:fileNameFound], 0
	jne fat12Filename_populated		; file name found in params, so we begin
	; file wasn't in the params, so we read it from the user
	call show_file_name_input_dialog	; read from user, into [fat12Filename]
	; dialog guarantees file name will be populated
fat12Filename_populated:
	call load_file
	
	mov dl, BLUE_ON_BLUE		; this makes the file rendering invisible
	call common_clear_screen_to_colour
	call draw_preparing_overlay
	
	call render_entire_file

	mov bh, 0					; row
	mov bl, 0					; column
	int 9Eh						; position cursor to top left corner
	
	call display_current_page
	
	int 83h						; clear keyboard buffer
	
	call read_user_input		; enter infinite "read user input" loop
	
	; shouldn't get here
	mov bx, word [cs:dynamicMemorySegment]
	int 92h						; deallocate
	jmp deallocate_file_load_and_rendered_and_exit_after_message
	
deallocate_file_load_and_rendered_and_exit:
	push cs
	pop ds
	mov si, errorCouldNotAllocateDynMemSegment
	int 80h
	
deallocate_file_load_and_rendered_and_exit_after_message:
	mov bx, word [cs:renderedSegment]
	int 92h						; deallocate
	jmp deallocate_file_load_and_exit_after_message
	
deallocate_file_load_and_exit:
	push cs
	pop ds
	mov si, errorCouldNotAllocateRenderedTextSegment
	int 80h
deallocate_file_load_and_exit_after_message:	
	mov bx, word [cs:fileLoadSegment]
	int 92h						; deallocate
	
	int 95h						; exit


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Recalculates and saves the line number (within file) on which
; the cursor currently is.
; Note: the value is one-based
;
; input:
;		none
; output:
;		none
save_cursor_line:
	pusha
	; save cursor line number, so draw_overlay has it
	call get_cursor_line_number			; AX := line number
	inc ax								; make it one-based
	mov word [cs:currentCursorLine], ax
	popa
	ret
	
	
; Redraws the overlay to show a change of cursor line
;
; input:
;		none
; output:
;		none
update_line_number_overlay:
	pusha
	
	int 0AAh				; BX := cursor position
	push bx					; [1] save cursor location
	call save_cursor_line
	call draw_overlay
	pop bx					; [1] restore cursor position
	int 9Eh					; move cursor
	
	popa
	ret
	

; Copies the current page from the rendered area to the video RAM
;
; input:
;		none
; output:
;		none
display_current_page:
	pusha
	push ds
	
	call save_cursor_line
	
	int 0AAh				; BX := cursor position
	push bx					; [1] save cursor location
	
	mov dl, CYAN_ON_BLUE
	call common_clear_screen_to_colour
	
	call draw_overlay
	
	call get_rendered_page_pointer

	mov bx, 0
	int 9Eh					; home cursor
	
	mov cx, EDITABLE_CHARACTER_COUNT
	int 0A8h					; dump CX characters from DS:SI to current 
								; virtual display
								
	pop bx					; [1] restore cursor position
	int 9Eh					; move cursor
	
	pop ds
	popa
	ret


; Reads the contents of file whose name is in [fat12Filename], storing 
; it in fileLoadSegment:FILE_LOAD_BUFFER_OFFSET
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
	mov si, fat12Filename
	
	push word [cs:fileLoadSegment]
	pop es
	mov di, FILE_LOAD_BUFFER_OFFSET		; ES:DI := pointer to text
	
	int 81h						; load file: AL = 0 when successful
								; CX = file size in bytes
	cmp al, 0					; was the file found?
	je load_file_store_size		; yes, store its size
	; file was not found, set size to 0
	mov cx, 0
load_file_store_size:
	mov word [cs:loadedFileSize], cx
	
	pop es
	pop ds
	popa
	ret


; Renders the entire loaded file to a format that's easily saveable/editable
;
; input:
;		none
; output:
;		none
render_entire_file:
	pusha
	push ds
	push es
	
	push word [cs:renderedSegment]
	pop es
	mov di, RENDERED_BUFFER_OFFSET	; ES:DI := pointer to rendered buffer
	
	push word [cs:fileLoadSegment]
	pop ds
	mov si, FILE_LOAD_BUFFER_OFFSET	; DS:SI := pointer to loaded file contents
	
	mov cx, word [cs:loadedFileSize]		; CX := file size
	add cx, si						; CX := address immediately after file text
	
	; we now start rendering characters in the file one by one, until the cursor
	; reaches the bottom, non-editable line
	; when this happens, we know we've crossed a page boundary, so we dump vram
	; and continue until we're past the input file end
	
	mov bx, 0
	int 9Eh					; home cursor
render_entire_file_next_page:
	inc byte [cs:renderedPageCount]

	cmp byte [cs:renderedPageCount], MAX_PAGES
	ja loaded_file_too_large
	
	cmp si, cx				; have we passed the end of the file?
	jae render_entire_file_done	; yes
	
	int 0AAh				; BL := column
	mov bh, 0				; row := 0
	int 9Eh					; move cursor
	call clear_editable_vram
	
render_entire_file_next_character:
	cmp si, cx				; have we passed the end of the file?
	jb render_entire_file_next_character_do	; no
	; we've passed the end of the file
	call dump_video_ram_to_location		; dump vram to ES:DI (last page)
	jmp render_entire_file_done
	
render_entire_file_next_character_do:
	push cx
	
render_entire_file_next_character_do_check_ASCII_zero:
	cmp byte [ds:si], COMMON_ASCII_NULL
	jne render_entire_file_next_character_do_check_tab
	; replace ASCII zero with a blank space
	mov byte [ds:si], COMMON_ASCII_BLANK
	jmp render_entire_file_next_character_do_copy_to_display
render_entire_file_next_character_do_check_tab:
	cmp byte [ds:si], COMMON_ASCII_TAB
	jne render_entire_file_next_character_do_checks_done
	; replace ASCII zero with a blank space
	mov byte [ds:si], COMMON_ASCII_BLANK
	jmp render_entire_file_next_character_do_copy_to_display
render_entire_file_next_character_do_checks_done:
	
render_entire_file_next_character_do_copy_to_display:
	mov cx, 1
	int 0A8h				; dump CX characters from DS:SI to current 
							; virtual display
	pop cx
	inc si					; next character
	
	int 0AAh				; BH := cursor row
	cmp bh, EDITOR_HEIGHT
	jb render_entire_file_next_character	; still on the same page
	; we've now crossed a page boundary
	call dump_video_ram_to_location		; dump vram to ES:DI
	add di, EDITABLE_CHARACTER_COUNT	; move ES:DI to next page
	
	jmp render_entire_file_next_page	; next page
	
render_entire_file_done:
	call clear_editable_vram
	
	pop es
	pop ds
	popa
	ret
	

; Presents error message and exits program
; REACHED VIA JMP
;
; input:
;		none
; output:
;		none
loaded_file_too_large:
	pusha
	push ds
	
	mov dl, RED_ON_BLUE
	call common_clear_screen_to_colour
	call draw_preparing_overlay
	
	mov bx, 0
	int 9Eh					; move cursor to top left corner
	
	push cs
	pop ds
	mov si, loadedFileTooLarge
	int 97h
	
	mov ah, 0
	int 16h					; wait for a key
	call handle_escape
	; SHOULD NEVER GET HERE
	pop ds
	popa
	ret
	
	
; Clears the editable video memory
;
; input:
;		none
; output:
;		none
clear_editable_vram:
	pusha

	int 0AAh				; BL := column
	push bx					; save cursor location
	
	mov bx, 0
	int 9Eh					; move cursor to top left corner
	
	mov dl, ' '
	mov ax, EDITABLE_CHARACTER_COUNT
clear_editable_vram_next:
	int 98h					; print blank
	dec ax
	jnz clear_editable_vram_next
	
	pop bx					; restore cursor location
	int 9Eh					; move cursor
	
	popa
	ret
	

; Saves the current page (which is in video ram) into the rendered buffer
;
; input:
;		none
; output:
;		none	
save_current_vram_page:
	pusha
	push ds
	push es
	
	call get_rendered_page_pointer		; DS:SI := pointer to current page
	push ds
	pop es
	mov di, si							; ES:DI := pointer to current page
	call dump_video_ram_to_location
	
	pop es
	pop ds
	popa
	ret
	
	
; Returns a pointer to the beginning of the current page in the rendered buffer
;
; input:
;		none
; output:
;		DS:SI - pointer to beginning of current page in rendered buffer
get_rendered_page_pointer:
	push ax
	push bx
	push cx
	push dx
	push di
	
	push word [cs:renderedSegment]
	pop ds
	mov si, RENDERED_BUFFER_OFFSET	; DS:SI := pointer to rendered text buffer
	
	mov ax, word [cs:currentTopLine]
	mov cx, COMMON_SCREEN_WIDTH
	mul cx							; AX := offset into rendered text buffer
									; of current page
	add si, ax				; DS:SI := pointer to beginning of current page
	
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

	
; Returns the number of the line on which the cursor is currently, zero-based
;
; input:
;		none
; output:
;		AX - 
get_cursor_line_number:
	push bx
	int 0AAh							; BH := cursor row, BL := cursor column
	xchg bl, bh
	mov bh, 0							; BX := cursor row
	add bx, word [cs:currentTopLine]
	mov ax, bx
	pop bx
	ret
	
	
; Dumps the contents (ASCII only) of the video ram into the specified buffer
;
; input:
;		ES:DI - pointer to where vram is to be dumped (ASCII only)
; output:
;		none
dump_video_ram_to_location:
	pushf
	pusha
	push ds
	push es
	
	push es
	push di						; [1] save arguments
	
	; first, dump the video ram into our buffer
	push word [cs:tempVramBufferSeg]
	pop es
	mov di, word [cs:tempVramBufferOff]	; ES:DI := dump buffer
	int 0A7h					; dump my virtual display to ES:DI
	
	; then, convert NULLs to blanks
	push word [cs:tempVramBufferSeg]
	pop ds
	mov si, word [cs:tempVramBufferOff]	; DS:SI := dump buffer
	
	mov cx, word [cs:tempVramBufferOff]	; CX := dump buffer start offset
	add cx, EDITABLE_VRAM_SIZE	; CX := offset immediately after end of buffer
								; (used as limit for the loop below)
dump_video_ram_convert_blanks:
	cmp byte [ds:si], 0			; do we need to convert this ASCII character?
	jne dump_video_ram_convert_blanks_start	; no
	; yes, we must convert it to a blank
	mov byte [ds:si], ' '
dump_video_ram_convert_blanks_start:
	add si, 2							; next ASCII character
	cmp si, cx							; are we past the end of the buffer?
	jb dump_video_ram_convert_blanks	; not yet, so loop again
	
	; then, strip all attributes, keeping only ASCII bytes
	push word [cs:tempVramBufferSeg]
	pop ds
	mov si, word [cs:tempVramBufferOff]	; DS:SI := dump buffer
	
	pop di
	pop es						; [1] restore arguments
	
	mov cx, word [cs:tempVramBufferOff]	; CX := dump buffer start offset
	add cx, EDITABLE_VRAM_SIZE	; CX := address immediately after end of buffer
								; (used as limit for the loop below)
	cld
dump_video_ram_strip:
	movsb						; copy ASCII byte
	inc si						; skip attribute byte
	cmp si, cx					; are we past the end of the buffer?
	jb dump_video_ram_strip		; not yet, so loop again
	
	pop es
	pop ds
	popa
	popf
	ret


; Draws the overlay in the "main" state
;
; input:
;		none
; output:
;		none
draw_overlay:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, overlayString1
		
	mov bh, COMMON_SCREEN_HEIGHT - 1	; row
	mov bl, 0							; column
	int 9Eh								; move cursor
	
	mov cx, COMMON_SCREEN_WIDTH
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_RED
	int 9Fh						; attributes
	
	int 97h								; print text
	
	; print file name
	mov si, filenameBuffer
	int 97h								; print text
	
	; print line number
	mov bh, COMMON_SCREEN_HEIGHT - 1	; row
	mov bl, 19							; column
	int 9Eh								; move cursor
	
	mov si, overlayString2
	int 97h								; print text
	
	mov ax, word [cs:currentCursorLine]
	mov dx, 0							; DX:AX := line number
	mov cl, 3							; formatting option
	call common_text_print_number
	mov dl, ' '
	int 98h								; print a space after, erasing
										; extra digits	
	; print commands to the right of the overlay
	mov bh, COMMON_SCREEN_HEIGHT - 1	; row
	mov bl, 30							; column
	int 9Eh								; move cursor
	mov si, overlayString3
	int 97h								; print text
	
	pop ds
	popa
	ret
	

; Draws the overlay in the "initial" state
;
; input:
;		none
; output:
;		none
draw_initial_overlay:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, initialOverlayString
	
	mov bh, COMMON_SCREEN_HEIGHT - 1	; row
	mov bl, 0							; column
	int 9Eh								; move cursor
	
	mov cx, COMMON_SCREEN_WIDTH
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_RED
	int 9Fh						; attributes
	
	int 97h
	
	pop ds
	popa
	ret
	
	
; Draws the overlay in the "preparing" state
;
; input:
;		none
; output:
;		none
draw_preparing_overlay:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, preparingOverlayString
	
	mov bh, COMMON_SCREEN_HEIGHT - 1	; row
	mov bl, 0							; column
	int 9Eh								; move cursor
	
	mov cx, COMMON_SCREEN_WIDTH
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_RED
	int 9Fh						; attributes
	
	int 97h
	
	pop ds
	popa
	ret

	
; Read file name from parameter, or show error and exit if value was invalid
; or not present.
; 
; input:
;		none
; output:
;		none
read_file_name_argument:
	pusha
	pushf
	push ds
	
	; read value of argument 'file'
	call common_args_read_file_file_arg	; DS:SI := pointer to 8.3 file name
	cmp ax, 0
	jne read_file_name_argument_valid	; valid!

	; not found or invalid; return without flagging as found
	jmp read_file_name_argument_done

read_file_name_argument_valid:
	; here, DS:SI contains the file name in 8.3 format
	push si
	int 0A5h						; BX := file name length
	mov cx, bx
	inc cx							; also copy terminator
	mov di, filenameBuffer
	cld
	rep movsb						; copy into filenameBuffer
	pop si

	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	mov byte [cs:fileNameFound], 1	; flag file name as found

read_file_name_argument_done:
	pop ds
	popf
	popa
	ret


; Prompts user for a file name and then stores it in [fat12Filename]
;
; input:
;		none
; output:
;		none
show_file_name_input_dialog:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

show_file_name_input_dialog_read_input:
	mov dl, CYAN_ON_BLUE
	call common_clear_screen_to_colour
	
	call draw_initial_overlay
	
	mov bh, FILE_BOX_TOP
	mov bl, FILE_BOX_LEFT
	mov ah, FILE_BOX_CONTENTS_HEIGHT
	mov al, FILE_BOX_CONTENTS_WIDTH
	call common_draw_box
	
	add bl, 5
	mov si, textFileTitle
	mov dl, CYAN_ON_BLUE
	call common_draw_box_title
	
	mov bh, FILE_BOX_TOP + 2	; row
	mov bl, FILE_BOX_LEFT + 25	; column
	int 9Eh						; move cursor
	mov cx, 12
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_RED
	int 9Fh						; attributes

	mov bh, FILE_BOX_TOP + 2	; row
	mov bl, FILE_BOX_LEFT + 8	; column
	int 9Eh						; move cursor
	
	mov si, enterFileNameString
	int 97h						; print prompt

	mov di, filenameBuffer		; ES:DI := pointer to buffer
	mov cx, FILE_NAME_MAX_SIZE	; character limit
	int 0A4h					; read file name from user
	
	; check whether the user entered a valid 8.3 file name
	mov si, filenameBuffer
	int 0A9h					; AX := 0 when file name is valid
	cmp ax, 0
	jne show_file_name_input_dialog_read_input	; read again if invalid
	
	; input was valid
	mov si, filenameBuffer
	mov di, fat12Filename
	int 0A6h					; convert 8.3 file name to FAT12 format
	
	pop es
	pop ds
	popa
	ret
	

; The main "user input->action" procedure
; 
; input:
;		none
; output:
;		none
read_user_input:
	pusha

read_user_input_read:
	int 83			; clear keyboard buffer

read_user_input_read__wait:	
	hlt				; do nothing until an interrupt occurs
	mov ah, 1
	int 16h 									; any key pressed?
	jz read_user_input_read__wait				; no
	
	mov ah, 0
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	
	; see if it's one of the "special" keys
	cmp ah, COMMON_SCAN_CODE_LEFT_ARROW
	je handle_left_arrow
	
	cmp ah, COMMON_SCAN_CODE_RIGHT_ARROW
	je handle_right_arrow
	
	cmp ah, COMMON_SCAN_CODE_UP_ARROW
	je handle_up_arrow
	
	cmp ah, COMMON_SCAN_CODE_DOWN_ARROW
	je handle_down_arrow
	
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je handle_escape
	
	cmp ah, COMMON_SCAN_CODE_HOME
	je handle_home
	
	cmp ah, COMMON_SCAN_CODE_END
	je handle_end
	
	cmp ah, COMMON_SCAN_CODE_ENTER
	je handle_enter
	
	cmp ah, COMMON_SCAN_CODE_DELETE
	je handle_delete
	
	cmp ah, COMMON_SCAN_CODE_TAB
	je handle_tab
	
	cmp ah, COMMON_SCAN_CODE_BACKSPACE
	je handle_backspace
	
	cmp ah, COMMON_SCAN_CODE_PAGE_UP
	je handle_page_up
	
	cmp ah, COMMON_SCAN_CODE_PAGE_DOWN
	je handle_page_down
	
	cmp ax, COMMON_SCAN_CODE_AND_ASCII_CTRL_L
	je handle_clear_line
	
	cmp ax, COMMON_SCAN_CODE_AND_ASCII_CTRL_I
	je handle_insert_line
	
	cmp ax, COMMON_SCAN_CODE_AND_ASCII_CTRL_D
	je handle_delete_line
	
	cmp ax, COMMON_SCAN_CODE_AND_ASCII_CTRL_C
	je handle_copy_line
	
	cmp ax, COMMON_SCAN_CODE_AND_ASCII_CTRL_V
	je handle_paste_line
	
	cmp ah, COMMON_SCAN_CODE_F2
	je handle_f2
	
	cmp ah, COMMON_SCAN_CODE_F4
	je handle_f4
	
	cmp ah, COMMON_SCAN_CODE_F5
	je handle_f5
	
	cmp ah, COMMON_SCAN_CODE_F6
	je handle_f6
	
	; now see if it's a printable ASCII code
	cmp al, 126					; last "type-able" ASCII code
	ja read_user_input_read		; it's past that
	cmp al, 32					; first "type-able" ASCII code
	jb read_user_input_read		; it's before that
	
	; it's a printable character, so print it
	call print_ascii_character
	
	jmp read_user_input_done_handling	; read another character

handle_left_arrow:
	call try_move_cursor_left
	jmp read_user_input_done_handling

handle_right_arrow:
	call try_move_cursor_right
	jmp read_user_input_done_handling

handle_up_arrow:
	call try_move_cursor_up
	jmp read_user_input_done_handling

handle_down_arrow:
	call try_move_cursor_down
	jmp read_user_input_done_handling

handle_backspace:
	call move_cursor_left_and_delete
	jmp read_user_input_done_handling

handle_delete:
	call delete_at_cursor
	jmp read_user_input_done_handling

handle_tab:
	call try_move_cursor_right
	call try_move_cursor_right
	call try_move_cursor_right
	call try_move_cursor_right
	jmp read_user_input_done_handling

handle_enter:
	call try_move_cursor_down
	cmp ax, 0							; did we move at all?
	je read_user_input_done_handling	; no, so we're done because we don't
										; want to clear last line of editor
	call insert_line
	call cursor_home
	jmp read_user_input_done_handling

handle_home:
	call cursor_home
	jmp read_user_input_done_handling

handle_end:
	call cursor_end
	jmp read_user_input_done_handling

handle_page_down:
	call page_down
	jmp read_user_input_done_handling
	
handle_page_up:
	call page_up
	jmp read_user_input_done_handling
	
handle_clear_line:
	call clear_line
	jmp read_user_input_done_handling
	
handle_delete_line:
	call delete_line
	call cursor_home
	jmp read_user_input_done_handling
	
handle_insert_line:
	call insert_line
	call cursor_home
	jmp read_user_input_done_handling
	
handle_copy_line:
	call copy_line
	jmp read_user_input_done_handling
	
handle_paste_line:
	call paste_line
	jmp read_user_input_done_handling
	
handle_escape:
exit_and_deallocate_all:
	mov bx, word [cs:fileLoadSegment]
	int 92h						; deallocate
	mov bx, word [cs:renderedSegment]
	int 92h						; deallocate
	mov bx, word [cs:dynamicMemorySegment]
	int 92h						; deallocate
	int 95h						; exit program
	
handle_f2:
	call save_to_file
	jmp read_user_input_done_handling
	
handle_f4:
	call run_basic
	jmp read_user_input_done_handling

handle_f5:
	call help_basic
	jmp read_user_input_done_handling
	
handle_f6:
	call help_basic_gui
	jmp read_user_input_done_handling

read_user_input_done_handling:
	call update_line_number_overlay
	jmp read_user_input_read

	popa
	ret
	
	
; Pastes from temporary memory into the line at cursor's row
;
; input:
;		none
; output:
;		none
paste_line:
	pusha
	pushf
	push ds
	push es
	
	cmp byte [cs:hasCopiedOnce], 0			; has anything been copied?
	je paste_line_done						; no
	
	call save_current_vram_page
	call save_cursor_line
	
	call get_pointer_to_start_of_current_line	; ES:DI := ptr. to line start
	
	push cs
	pop ds
	mov si, tempLine						; DS:SI := pointer to buffer
	
	mov cx, COMMON_SCREEN_WIDTH
	cld
	rep movsb								; copy temporary buffer into line
	
	call display_current_page
paste_line_done:
	pop es
	pop ds
	popf
	popa
	ret
	

; Copies line at cursor's row into temporary memory
;
; input:
;		none
; output:
;		none
copy_line:
	pusha
	pushf
	push ds
	push es
	
	call save_current_vram_page
	call save_cursor_line
	
	call get_pointer_to_start_of_current_line	; ES:DI := ptr. to line start
	push es
	pop ds
	mov si, di								; DS:SI := pointer to line start
	
	push cs
	pop es
	mov di, tempLine						; ES:DI := pointer to buffer
	
	mov cx, COMMON_SCREEN_WIDTH
	cld
	rep movsb								; copy line into temporary buffer
	
	mov byte [cs:hasCopiedOnce], 1			; indicate we've copied at all
	
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Inserts a line at cursor's row
;
; input:
;		none
; output:
;		none
insert_line:
	pusha
	pushf
	push ds
	push es
	
	call save_current_vram_page
	call save_cursor_line
	
	mov ax, word [cs:currentCursorLine]		; one-based
	dec ax									; zero-based
	mov bx, COMMON_SCREEN_WIDTH
	mul bx									; DX:AX := 32bit offset to 
											; beginning of line where we insert
											; assume DX = 0
	add ax, RENDERED_BUFFER_OFFSET			; AX := pointer to beginning of
											; line where we insert
	; now shift all bytes from the end all the way to AX
	mov bx, word [cs:renderedSegment]
	mov ds, bx
	mov es, bx
	
	mov di, RENDERED_BUFFER_OFFSET + MAX_PAGES * EDITABLE_CHARACTER_COUNT - 1
								; ES:DI := pointer to last character possible
	
	mov si, di
	sub si, COMMON_SCREEN_WIDTH	; DS:SI := pointer to char one line above ES:DI
	
	mov cx, si					; we'll repeat as many times as needed until
	sub cx, ax					; DS:SI reaches the beginning of the line
	inc cx						; where we're inserting
	std							; we're copying going backwards
	rep movsb					; shift lines down
	
	mov di, ax					; ES:DI := pointer to beginning of line where
								; we insert
	mov al, ' '
	mov cx, COMMON_SCREEN_WIDTH
	cld
	rep stosb					; clear out inserted line
	
	call display_current_page
	
	pop es
	pop ds
	popf
	popa
	ret
	

; Deletes the line at cursor's row
;
; input:
;		none
; output:
;		none
delete_line:
	pusha
	pushf
	push ds
	push es
	
	call save_current_vram_page
	call save_cursor_line
	
	mov ax, word [cs:currentCursorLine]		; one-based
	dec ax									; zero-based
	mov bx, COMMON_SCREEN_WIDTH
	mul bx									; DX:AX := 32bit offset to 
											; beginning of line where we insert
											; assume DX = 0
	add ax, RENDERED_BUFFER_OFFSET			; AX := pointer to beginning of
											; line where we insert
	; now shift all bytes until the end by [screen width] to shift lines up
	mov bx, word [cs:renderedSegment]
	mov ds, bx
	mov es, bx
	mov si, ax
	mov di, si								; first destination line
	add si, COMMON_SCREEN_WIDTH				; first source line
	
	mov cx, MAX_PAGES * EDITABLE_CHARACTER_COUNT
	sub ax, RENDERED_BUFFER_OFFSET			; convert pointer to offset
	sub cx, ax								; bytes to shift
	cld
	rep movsb								; shift lines up
	
	mov di, RENDERED_BUFFER_OFFSET + MAX_PAGES * EDITABLE_CHARACTER_COUNT - COMMON_SCREEN_WIDTH
								; ES:DI := pointer to start of last line
								; of editable area
	mov al, ' '
	mov cx, COMMON_SCREEN_WIDTH
	cld
	rep stosb								; clear out last line
	
	mov byte [ds:MAX_PAGES * EDITABLE_CHARACTER_COUNT], 0
						; add terminator immediately after work area, for BASIC
	
	call display_current_page
	
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Runs the BASIC interpreter on the current file contents
;
; input:
;		none
; output:
;		none
run_basic:
	pusha
	push ds
	push es
	
	call save_current_vram_page
	
	int 0AAh							; BH := cursor row, BL := cursor column
	push bx								; [1] save cursor position
	
	int 0A0h							; clear screen
	
	push word [cs:renderedSegment]
	pop ds
	mov si, RENDERED_BUFFER_OFFSET		; DS:SI := rendered file contents
	mov ax, BASIC_GUI_FLAG_SHOW_STATUS_ON_SUCCESS | BASIC_GUI_FLAG_SHOW_STATUS_ON_ERROR | BASIC_GUI_FLAG_WAIT_KEY_ON_STATUS
	call basic_gui_entry_point

	; bring cursor back to where it was
	pop bx						; [1] BX := cursor position
	int 9Eh						; position cursor to top left corner
	
	call display_current_page
	
	pop es
	pop ds
	popa
	ret


; Displays BASIC interpreter help
;
; input:
;		none
; output:
;		none
help_basic:
	pusha
	push ds
	push es
	
	call save_current_vram_page
	
	int 0AAh							; BH := cursor row, BL := cursor column
	push bx								; [1] save cursor position
	
	int 0A0h							; clear screen

	call basic_help
	
	push cs
	pop ds	
	mov si, messagePressAKey
	int 97h						; print
	
	mov ah, 0
	int 16h						; wait for a key
	
	; bring cursor back to where it was
	pop bx						; [1] BX := cursor position
	int 9Eh						; position cursor to top left corner
	
	call display_current_page
	
	pop es
	pop ds
	popa
	ret
	
	
; Displays BASIC GUI help
;
; input:
;		none
; output:
;		none
help_basic_gui:
	pusha
	push ds
	push es
	
	call save_current_vram_page
	
	int 0AAh							; BH := cursor row, BL := cursor column
	push bx								; [1] save cursor position
	
	int 0A0h							; clear screen

	call basic_gui_help
	
	push cs
	pop ds
	mov si, messagePressAKey
	int 97h						; print
	
	mov ah, 0
	int 16h						; wait for a key
	
	; bring cursor back to where it was
	pop bx						; [1] BX := cursor position
	int 9Eh						; position cursor to top left corner
	
	call display_current_page
	
	pop es
	pop ds
	popa
	ret
	
	
; Returns the file size as needed at save time
;
; input:
;		none
; output:
;		CX - file size for saving
get_save_file_size:
	push ax
	push bx
	push dx
	push si
	push di
	push ds
	
	mov cx, 0
	mov dx, 0							; "nothing found yet"
	
	push word [cs:renderedSegment]
	pop ds
	mov si, RENDERED_BUFFER_OFFSET		; DS:SI := rendered file contents
	mov bx, -1
get_save_file_size_loop:
	inc bx
	cmp bx, MAX_PAGES * EDITABLE_CHARACTER_COUNT
	jae get_save_file_size_found_last_typeable
	
	mov al, byte [ds:si+bx]		; AL := character
	cmp al, 126					; last "type-able" non-blank ASCII code
	ja get_save_file_size_loop	; it's past that
	cmp al, 33					; first "type-able" non-blank ASCII code
	jb get_save_file_size_loop	; it's before that
	
	; this is a "type-able" non-blank ASCII code, so save it in CX
	mov cx, bx
	mov dx, 1					; found at least one
	jmp get_save_file_size_loop
get_save_file_size_found_last_typeable:
	; here, CX contains index last "type-able" character
	cmp dx, 0
	je get_save_file_size_done	; no padding when nothing was found
	
	inc cx						; convert index to file size
	
	cmp cx, MAX_PAGES * EDITABLE_CHARACTER_COUNT - COMMON_SCREEN_WIDTH
	jbe get_save_file_size_can_pad
	; can't pad
	mov cx, MAX_PAGES * EDITABLE_CHARACTER_COUNT
	jmp get_save_file_size_pad
get_save_file_size_can_pad:
	; can pad
	add cx, COMMON_SCREEN_WIDTH
get_save_file_size_pad:
	mov bx, cx				; BX := return value
get_save_file_size_done:
	pop ds
	pop di
	pop si
	pop dx
	pop bx
	pop ax
	ret
	

; Saves the current rendered text to the file
;
; input:
;		none
; output:
;		none
save_to_file:
	pusha
	push ds
	push es
	
	call save_current_vram_page

	call get_save_file_size		; CX := file size

	push cs
	pop ds
	mov si, fat12Filename				; DS:SI := file name
	
	push word [cs:renderedSegment]
	pop es
	mov di, RENDERED_BUFFER_OFFSET		; ES:DI := rendered file contents
	int 9Dh								; write file
	
	pop es
	pop ds
	popa
	ret
	

; Clears the current line
;
; input:
;		none
; output:
;		none
clear_line:
	pusha
	call cursor_home					; bring cursor to left-most column
	
	int 0AAh					; BH := cursor row, BL := cursor column
	push bx						; save cursor position
	
	mov cx, COMMON_SCREEN_WIDTH			; write a whole line of blanks
clear_line_loop:
	mov al, ' '
	call print_ascii_character
	loop clear_line_loop
	
	pop bx						; restore cursor position
	int 9Eh						; set cursor position to BH, BL
	
	call cursor_home					; bring cursor to left-most column
										; in case we were on the last line,
										; which leaves the cursor at the end
										; of the line
	popa
	ret
	
	
; Tries to move the page down, fully or partially
;
; input:
;		none
; output:
;		none
page_down:
	pusha
	
	cmp word [cs:currentTopLine], MAX_TOP_LINE	; are we at the bottom
	je page_down_cursor_down					; of last page?
	cmp word [cs:currentTopLine], MAX_TOP_LINE - EDITOR_HEIGHT
	ja page_down_partial						; are we on last page?
	
	call save_current_vram_page
	add word [cs:currentTopLine], EDITOR_HEIGHT
	call display_current_page
	jmp page_down_done
page_down_partial:
	; we're on last page, but not at the bottom
	call save_current_vram_page
	mov word [cs:currentTopLine], MAX_TOP_LINE
	call display_current_page
	jmp page_down_done
page_down_cursor_down:
	; we're at the bottom of the last page
	int 0AAh						; BH := cursor row, BL := cursor column
	mov bh, EDITOR_HEIGHT - 1
	int 9Eh							; move cursor
page_down_done:
	popa
	ret


; Tries to move the page up, fully or partially
;
; input:
;		none
; output:
;		none
page_up:
	pusha
	
	cmp word [cs:currentTopLine], 0				; are we at the top of
	je page_up_cursor_up						; first page?
	cmp word [cs:currentTopLine], EDITOR_HEIGHT	; are we on first page?
	jb page_up_partial
	
	; we are on second page or further
	call save_current_vram_page
	sub word [cs:currentTopLine], EDITOR_HEIGHT
	call display_current_page
	jmp page_up_done
page_up_partial:
	; we're on first page, but not at the top
	call save_current_vram_page
	mov word [cs:currentTopLine], 0
	call display_current_page
	jmp page_up_done
page_up_cursor_up:
	; we're at the top of the first page
	int 0AAh						; BH := cursor row, BL := cursor column
	mov bh, 0
	int 9Eh							; move cursor
page_up_done:
	popa
	ret


; Prints a character, adjusting the cursor if necessary
;
; input:
;		AL - ASCII of character to print
; output:
;		none
print_ascii_character:
	pusha
	mov dl, al					; DL := ASCII of character to print
	int 98h						; print it!
	
	int 0AAh					; BH := cursor row, BL := cursor column
	cmp bh, EDITOR_HEIGHT		; are we on the info row?
	jne print_ascii_character_done ; no, so we don't need to adjust cursor
	; we printed from the bottom-right position, and are now too far down
	dec bh						; adjust cursor by one row upwards
	mov bl, COMMON_SCREEN_WIDTH - 1 ; and to the end of that row
	int 9Eh						; set cursor position to BH, BL
print_ascii_character_done:
	popa
	ret
	
	
; Moves the cursor left and deletes the character at its location
;
; input:
;		none
; output:
;		none
move_cursor_left_and_delete:
	pusha
	call try_move_cursor_left
	mov al, ' '
	call print_ascii_character
	call try_move_cursor_left
	popa
	ret
	

; Deletes character at cursor location
;
; input:
;		none
; output:
;		none
delete_at_cursor:
	pusha
	
	int 0AAh						; BH := cursor row, BL := cursor column
	cmp bh, EDITOR_HEIGHT - 1		; is it on bottom row?
	jne delete_at_cursor_not_at_end	; no
	cmp bl, COMMON_SCREEN_WIDTH - 1	; is it on the right-most column?
	jne delete_at_cursor_not_at_end	; no
	mov al, ' '
	call print_ascii_character
	popa
	ret
delete_at_cursor_not_at_end:
	mov al, ' '
	call print_ascii_character
	call try_move_cursor_left
	popa
	ret
	

; Move cursor down, if possible
;
; input:
;		none
; output:
;		none
cursor_cr_lf:
	pusha
	int 0AAh					; BH := cursor row, BL := cursor column
	cmp bh, EDITOR_HEIGHT - 1
	je cursor_cr_lf_done		; NOOP if cursor already on bottom row
	inc bh						; move down by one row
	mov bl, 0					; move to left-most column
	int 9Eh						; set cursor position to BH, BL
cursor_cr_lf_done:
	popa
	ret
	

; Moves the cursor to immediately before the first printable character
; of the current line
;
; input:
;		none
; output:
;		none
cursor_home:
	pusha
	push ds
	push es
	
	call save_current_vram_page
	call save_cursor_line
	
	call get_pointer_to_start_of_current_line
								; ES:DI - pointer to start of current line
								
	mov cx, 0							; assume we won't find any
	mov bx, -1
cursor_home_loop:
	inc bx
	cmp bx, COMMON_SCREEN_WIDTH
	jae cursor_home_loop_done
	
	mov al, byte [es:di+bx]		; AL := character
	cmp al, 126					; last "type-able" non-blank ASCII code
	ja cursor_home_loop	; it's past that
	cmp al, 33					; first "type-able" non-blank ASCII code
	jb cursor_home_loop	; it's before that
	
	; this is a "type-able" non-blank ASCII code, so save it in CX
	mov cx, bx
cursor_home_loop_done:
	; here, CL is the column of first non-blank character, or first column
	; if no non-blank character exists
	int 0AAh					; BH := cursor row, BL := cursor column
	cmp bl, cl					; is it already on the first character?
	je cursor_home_go_to_beginning_of_line	; yes, so put it at column 0
	; no
	mov bl, cl					; go to column
	jmp cursor_home_perform
cursor_home_go_to_beginning_of_line:
	mov bl, 0					; go to beginning of line
	
cursor_home_perform:
	int 9Eh						; set cursor position to BH, BL
	
	pop es
	pop ds
	popa
	ret


; Moves the cursor to immediately after the last printable character
; of the current line
;
; input:
;		none
; output:
;		none
cursor_end:
	pusha
	push ds
	push es
	
	call save_current_vram_page
	call save_cursor_line
	
	call get_pointer_to_start_of_current_line
								; ES:DI - pointer to start of current line
	mov cx, COMMON_SCREEN_WIDTH - 2		; assume we won't find any
	mov bx, -1
cursor_end_loop:
	inc bx
	cmp bx, COMMON_SCREEN_WIDTH - 1		; we check one fewer than whole line
	jae cursor_end_loop_done
	
	mov al, byte [es:di+bx]		; AL := character
	cmp al, 126					; last "type-able" non-blank ASCII code
	ja cursor_end_loop	; it's past that
	cmp al, 33					; first "type-able" non-blank ASCII code
	jb cursor_end_loop	; it's before that
	
	; this is a "type-able" non-blank ASCII code, so save it in CX
	mov cx, bx
	jmp cursor_end_loop
cursor_end_loop_done:
	inc cl
	int 0AAh					; BH := cursor row, BL := cursor column
	cmp bl, cl					; is it already right after last character?
	je cursor_end_go_to_end_of_line	; yes, move it to end of line
	; no
	mov bl, cl					; go to the character immediately
								; after last "type-able" non-blank ASCII one
	jmp cursor_end_perform
cursor_end_go_to_end_of_line:
	mov bl, COMMON_SCREEN_WIDTH - 1	; go to end of line
cursor_end_perform:
	int 9Eh						; set cursor position to BH, BL
	
	pop es
	pop ds
	popa
	ret
	

; Moves the cursor up, if possible
;
; input:
;		none
; output:
;		none
try_move_cursor_up:
	pusha
	int 0AAh		; BH := cursor row, BL := cursor column
	
	cmp bh, 0
	je try_move_cursor_up_top_row
	; it's not on top-most row
	dec bh
	int 9Eh							; set cursor position to BH, BL
	jmp try_move_cursor_up_done
try_move_cursor_up_top_row:
	cmp word [cs:currentTopLine], 0
	je try_move_cursor_up_done		; already at the top of first page
	; move one line up
	call save_current_vram_page
	dec word [cs:currentTopLine]
	call display_current_page
try_move_cursor_up_done:
	popa
	ret


; Moves the cursor down, if possible
;
; input:
;		none
; output:
;		AX - 0 when nothing was done, other value otherwise
try_move_cursor_down:
	pusha
	int 0AAh		; BH := cursor row, BL := cursor column

	cmp bh, EDITOR_HEIGHT - 1
	je try_move_cursor_down_bottom_row
	; it's not on bottom-most row
	inc bh							; we're moving down by one
	int 9Eh							; set cursor position to BH, BL
	jmp try_move_cursor_down_performed
try_move_cursor_down_bottom_row:
	cmp word [cs:currentTopLine], MAX_TOP_LINE
	je try_move_cursor_down_not_performed	; already at bottom of last page
	; move one line down
	call save_current_vram_page
	inc word [cs:currentTopLine]
	call display_current_page
	jmp try_move_cursor_down_performed
try_move_cursor_down_not_performed:
	popa
	mov ax, 0						; "we did nothing"
	ret
try_move_cursor_down_performed:
	popa
	mov ax, 1						; we performed something
	ret
	

; Moves the cursor left, if possible
;
; input:
;		none
; output:
;		none
try_move_cursor_left:
	pusha
	int 0AAh		; BH := cursor row, BL := cursor column
	
	; check if cursor is already in the top left corner
	mov al, 0
	add al, bh
	add al, bl		; AL := BH + BL	(can't overflow because BH < 80, BL < 80
	cmp al, 0
	je try_move_cursor_left_done	; NOOP if in the top left corner
	; move left
	dec bl							; column--
	cmp bl, COMMON_SCREEN_WIDTH
	jb try_move_cursor_left_done	; hasn't wrapped around to 255
	; it wrapped around to 255
	mov bl, COMMON_SCREEN_WIDTH - 1	; bring it to the right-most edge of screen
	dec bh							; and on the row above
try_move_cursor_left_done:
	int 9Eh							; set cursor position to BH, BL
	popa
	ret


; Moves the cursor right, if possible
;
; input:
;		none
; output:
;		none
try_move_cursor_right:
	pusha
	int 0AAh		; BH := cursor row, BL := cursor column
	
	; check if cursor is already in the bottom right corner
	cmp bh, EDITOR_HEIGHT - 1					; is it in the bottom row?
	jne try_move_cursor_right_not_bottom_row	; no, so move it
	cmp bl, COMMON_SCREEN_WIDTH - 1				; is it also in the right edge?
	je try_move_cursor_right_done				; yes, so we do nothing
												; no, so we can move it
try_move_cursor_right_not_bottom_row:
	; move right
	inc bl							; column++
	cmp bl, COMMON_SCREEN_WIDTH
	jne try_move_cursor_right_done	; hasn't gone past right edge
	; it's gone past right edge
	mov bl, 0						; bring it to the left edge
	inc bh							; and on the row below
try_move_cursor_right_done:
	int 9Eh							; set cursor position to BH, BL
	popa
	ret

	
; Gets a pointer to the start of the line at cursor row
;
; input:
;		none
; output:
;		ES:DI - pointer to start of current line
get_pointer_to_start_of_current_line:
	push ax
	push bx
	push cx
	push dx
	
	mov ax, word [cs:currentCursorLine]		; one-based
	dec ax									; zero-based
	mov bx, COMMON_SCREEN_WIDTH
	mul bx									; DX:AX := 32bit offset to 
											; beginning of line where we insert
											; assume DX = 0
	add ax, RENDERED_BUFFER_OFFSET			; AX := pointer to beginning of
											; line where we insert
	
	push word [cs:renderedSegment]
	pop es
	mov di, ax								; return in ES:DI
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret


%include "common\ascii.asm"
%include "common\args.asm"
%include "common\colours.asm"
%include "common\textbox.asm"
%include "common\screen.asm"
%include "common\scancode.asm"
%include "common\basic\basic.asm"
%include "common\basic\basichlp.asm"
%include "common\tasks.asm"
%include "common\text.asm"
%include "common\memory.asm"

;stackProtection: times 65535 - 512 - $ + $$ db 0
				; this is not actually referenced, but
				; serves as protection against included
				; files becoming too large and not
				; leaving enough room for a proper
				; stack here
				; if this happens, an assembler error
				; will be generated