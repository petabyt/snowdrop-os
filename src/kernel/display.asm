;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains functionality for the management of virtual displays, allowing 
; each of multiple concurrent tasks to have its own protected display.
; It relies on functionality from:
; - a hardware driver, which interacts with the CRT controller directly
; - a virtual display driver, which interacts with virtual displays
; It also defines all data structures needed by all display driver routines.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; display entry format (each entry stores the state of a virtual display):
; bytes
;	   0-1 status (0xFFFF means empty)
;		 2 cursor row (0 through 24, because there are 25 rows)
;	 	 3 cursor column (0 through 79, because there are 80 columns)
;	   4-5 segment of pointer to video buffer
;	   6-7 offset of pointer to video buffer
;          (buffer is 4000 bytes long)
;	  8-15 unused


DISPLAY_BUFFER_SIZE	equ 4000	; in bytes
DISPLAY_ENTRY_SIZE 	equ 16		; in bytes
MAX_DISPLAYS equ KERNEL_MAX_TASKS_AND_VIRTUAL_DISPLAYS
DISPLAY_TABLE_SIZE equ MAX_DISPLAYS*DISPLAY_ENTRY_SIZE	; in bytes
DISPLAY_STATUS_EMPTY equ 0FFFFh		; used to mark an unused display slot
DISPLAY_STATUS_FULL equ 0h			; used to mark an occupied display slot

displayTable: times DISPLAY_TABLE_SIZE db 0
activeDisplayOffset: dw 0			; byte offset into the table above
									; this display is visible to the user
NUM_ROWS equ 25
NUM_COLUMNS equ 80

ASCII_BLANK_SPACE equ ' '
ASCII_CARRIAGE_RETURN equ 13
ASCII_LINE_FEED equ 10
ASCII_BACKSPACE equ 8
GRAY_ON_BLACK equ 7
									
cannotAddDisplayString: db 13, 10, 'Cannot allocate new virtual display.', 0
characterOutputBuffer: db ' ', 0 ; used to display single characters as strings
displayErrorCannotAllocateBuffer:	db 13, 10, 'Cannot allocate buffer for new virtual display.', 0
displayErrorCouldNotFree:	db 13, 10, 'Cannot deallocate virtual display buffer.', 0

; Initializes the virtual display manager
;
display_initialize:
	pusha
	pushf
	push es
	
	push cs
	pop es
	
	mov cx, DISPLAY_TABLE_SIZE / 2	; we'll store a word at a time
	mov di, displayTable
	mov ax, DISPLAY_STATUS_EMPTY	; fill up the display state 
									; table with empties
	cld
	rep stosw
	
	pop es
	popf
	popa
	ret


; Allocates a new virtual display.
;
; input
;		none
; output
;		AX - ID of virtual display that was just allocated
display_allocate:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	push cs
	pop ds
	push cs
	pop es
	
	call display_find_empty_slot	; AX := byte offset of slot
	push ax							; save offset because we'll return it
	mov di, displayTable
	add di, ax						; DI now points to beginning of slot
	
	mov ax, DISPLAY_BUFFER_SIZE
	call dynmem_allocate			; DS:SI := pointer to allocated buffer
	cmp ax, 0
	jne display_allocate_got_buffer
	; we failed to allocate memory, so we're done
	
	mov si, displayErrorCannotAllocateBuffer
	jmp crash_and_print				; we're crashing
	
display_allocate_got_buffer:
	mov word [es:di], DISPLAY_STATUS_FULL	; mark slot as full
	mov byte [es:di+2], 0			; cursor starts at row 0
	mov byte [es:di+3], 0			; cursor starts at column 0
	
	mov word [es:di+4], ds			; store buffer segment
	mov word [es:di+6], si			; store buffer offset

	push word [es:di+4]
	push word [es:di+6]
	pop di
	pop es							; ES:DI now points to beginning of buffer

	; now fill up the video buffer proper
	mov cx, 2000					; we store 2000 words (4000 bytes total)
	mov al, ASCII_BLANK_SPACE		; character
	mov ah, GRAY_ON_BLACK			; attributes
	cld
	rep stosw						; store the 2000 words to ES:DI
display_allocate_done:
	pop ax							; restore offset (we call it "ID"), so 
									; we can return it in AX
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	ret
	

; output
;		AX - byte offset into virtual display state table of first empty slot
display_find_empty_slot:
	push bx
	push si
	push ds
	
	push cs
	pop ds
	
	; find first empty display state slot
	mov si, displayTable
	mov bx, 0				; offset of display state slot being checked
display_find_empty_slot_loop:
	cmp word [ds:si+bx], DISPLAY_STATUS_EMPTY ; is this slot empty?
											  ; (are first two bytes 
											  ;	DISPLAY_STATUS_EMPTY?)
	je display_find_empty_slot_found		  ; yes
	
	add bx, DISPLAY_ENTRY_SIZE			; next slot
	cmp bx, DISPLAY_TABLE_SIZE			; are we past the end?
	jb display_find_empty_slot_loop		; no
display_find_empty_slot_full:			; yes
	mov si, cannotAddDisplayString
	call debug_print_string
	jmp crash
display_find_empty_slot_found:
	mov ax, bx							; return result in AX
display_find_empty_slot_done:
	pop ds
	pop si
	pop bx
	ret


; Saves the state of the video ram (vram) to the specified virtual display
;
; input
;		AX - ID (offset) of the virtual display to which vram will be saved
display_save:
	pusha
	pushf
	push ds
	push es
	
	mov di, displayTable
	add di, ax						; DI now points to beginning of slot
	
	call display_get_hardware_cursor_position
	mov byte [cs:di+2], bh			; save cursor row
	mov byte [cs:di+3], bl			; save cursor column
	
	push word [cs:di+4]
	push word [cs:di+6]
	pop di
	pop es							; ES:DI := beginning of buffer
	
	; ES:DI now points to where we'll save the video ram
	
	push word 0B800h
	pop ds
	mov si, 0				; DS:SI now points to the beginning of video ram
	
	mov cx, 2000					; we transfer 2000 words (4000 bytes total)
	cld
	rep movsw						; perform the string copy
	
	pop es
	pop ds
	popf
	popa
	ret


; Restores a virtual display to the video ram, effectively 
; rendering it on the screen.
;
; input
;		AX - ID (offset) of the virtual display whose buffer is recalled
display_restore:
	pusha
	pushf
	push ds
	push es
	
	mov si, displayTable
	add si, ax						; SI now points to beginning of slot
	
	; now recall the cursor to where it used to be
	mov bh, byte [cs:si+2]				; cursor row
	mov bl, byte [cs:si+3]				; cursor column
	call display_move_hardware_cursor	; move hardware cursor
	
	push word [cs:si+4]
	push word [cs:si+6]
	pop si
	pop ds							; DS:SI = beginning of buffer
	
	push word 0B800h
	pop es
	mov di, 0						; point ES:DI to B800:0000
	
	mov cx, 2000					; we transfer 2000 words (4000 bytes total)
	cld
	rep movsw						; perform the string copy
	
	pop es
	pop ds
	popf
	popa
	ret
	
	
; De-allocates a virtual display
;
; input
;		AX - ID (offset) of the virtual display whose buffer will be copied
display_free:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, displayTable
	add si, ax
	mov word [ds:si+0], DISPLAY_STATUS_EMPTY
	
	push word [ds:si+4]
	push word [ds:si+6]
	pop si
	pop ds						; DS:SI := pointer to buffer
	call dynmem_deallocate
	cmp ax, 0
	jne display_free_done
	
	; deallocation failure
	push cs
	pop ds
	mov si, displayErrorCouldNotFree
	call debug_print_string
	jmp crash
	
display_free_done:
	pop ds
	popa
	ret
	

; Makes a virtual display active, meaning that writes to it will also be
; echoed to the video ram, effectively displaying on the physical screen
;
; input
;		AX - ID (offset) of the virtual display that will become active
display_activate:
	pusha
	push ds
	
	push cs
	pop ds

	push ax								; save display we're activating
	mov ax, word [activeDisplayOffset]
	call display_save					; save vram to currently active display
	
	pop ax								; restore display we're activating
	mov word [activeDisplayOffset], ax	; save its offset
	call display_restore				; copy display to video ram
	
	pop ds
	popa
	ret


; Needed during initialization, to set the initial 
; value of activeDisplayOffset
;
display_initialize_active_display:
	pusha
	push ds
	
	push cs
	pop ds

	mov word [activeDisplayOffset], ax
	
	pop ds
	popa
	ret


; Return the ID (offset) of the active virtual display
;
; output
;		AX - ID (offset) of the active virtual display
display_get_active_display_id:
	push ds
	
	push cs
	pop ds
	
	mov ax, word [activeDisplayOffset]
	
	pop ds
	ret
	

; Writes an ASCII character to the specified virtual display
; Also writes to the video ram if the specified virtual display is the 
; active virtual display.
;
; input
;		DL - ASCII character to print
;		AX - virtual display ID where we're writing the character
display_wrapper_output_character:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, characterOutputBuffer
	mov byte [ds:si], dl					; our one-character string
	call display_wrapper_output_string
	
	pop ds
	popa
	ret
	

; Writes an ASCII character directly to video ram
;
; input
;		DL - ASCII character to print
display_output_character_to_vram:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, characterOutputBuffer
	mov byte [ds:si], dl					; our one-character string
	call display_vram_output_string
	
	pop ds
	popa
	ret
	
	
; Writes a zero-terminated string to the specified virtual display
; Writes to the video ram if the specified virtual display is the 
; active virtual display.
;
; input
;		DS:SI - pointer to first character of the string
;		AX - virtual display ID where we're writing the string
display_wrapper_output_string:
	pusha
	push ds
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_output_string_virtual_only	; no
; case 1 - when display is active, we output to vram only
display_wrapper_output_string_vram_only:
	pop ds								; restore DS as passed in
	call display_vram_output_string
	popa
	ret									; we printed to vram and are now done
; case 2 - when display is not active, we output to the virtual display only
display_wrapper_output_string_virtual_only:
	pop ds								; restore DS as passed in
	call display_output_string			; write to the virtual display
	popa
	ret


; Sets the position of the cursor in the specified virtual display
; Sets it in the video ram if the specified virtual display is the 
; active virtual display.
;
; input
;		AX - ID (offset) of virtual display whose cursor we're setting
;		BH - cursor row
;		BL - cursor column
; output
;		none
display_wrapper_set_cursor_position:
	pusha
	push ds
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_set_cursor_position_virtual_only	; no
; case 1 - when display is active, we output to vram only
display_wrapper_set_cursor_position_vram_only:
	pop ds								; restore DS as passed in
	call display_move_hardware_cursor
	popa
	ret
; case 2 - when display is not active, we output to the virtual display only
display_wrapper_set_cursor_position_virtual_only:
	pop ds								; restore DS as passed in
	call display_set_cursor_position	; set virtual display cursor position
	popa
	ret


; Writes the specified attribute byte to the specified virtual display
; Writes to vram if the specified virtual display is the 
; active virtual display.
;
; input
;		AX - virtual display ID where we're writing the string
;		CX - repeat this many times
;		DL - attribute byte
; output
;		none
display_wrapper_write_attribute:
	pusha
	push ds
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_write_attribute_virtual_only	; no
; case 1 - when display is active, we output to vram only
display_wrapper_write_attribute_vram_only:
	pop ds								; restore DS as passed in
	call display_vram_write_attribute	; write to vram
	popa
	ret
; case 2 - when display is not active, we output to the virtual display only
display_wrapper_write_attribute_virtual_only:
	pop ds								; restore DS as passed in
	call display_write_attribute		; write to virtual display
	popa
	ret


; Clears the specified virtual display, moves cursor to row 0, column 0, and
; sets all attributes to light gray on black.
; Writes to vram if the specified virtual display is the 
; active virtual display.
;
; input
;		AX - ID (offset) of virtual display we're clearing
; output
;		none
display_wrapper_clear_screen:
	pusha
	push ds
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_clear_screen_virtual_only	; no
; case 1 - when display is active, we output to vram only
display_wrapper_clear_screen_vram_only:
	pop ds								; restore DS as passed in
	call display_vram_clear_screen		; write to vram
	popa
	ret
; case 2 - when display is not active, we output to the virtual display only
display_wrapper_clear_screen_virtual_only:
	pop ds								; restore DS as passed in
	call display_clear_screen			; write to virtual display
	popa
	ret

	
; Dumps the specified virtual display.
; Dumps the vram if the specified virtual display is the 
; active virtual display.
; The buffer must be able to store 4000 bytes (80 columns x 25 rows x 2 bytes).
;
; input
;		AX - ID (offset) of virtual display we're dumping
;	 ES:DI - pointer to where the virtual display will be dumped
; output
;		none
display_wrapper_dump_screen:
	pusha
	push ds
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_dump_screen_virtual_only	; no
; case 1 - when display is active, we dump vram
display_wrapper_dump_screen_vram_only:
	pop ds								; restore DS as passed in
	call display_vram_dump_screen		; dump from vram
	popa
	ret
; case 2 - when display is not active, we dump from the virtual display
display_wrapper_dump_screen_virtual_only:
	pop ds								; restore DS as passed in
	call display_dump_screen			; dump from virtual display
	popa
	ret

	
; Dumps a number of characters to the specified virtual display.
; Dumps the vram if the specified virtual display is the 
; active virtual display.
;
; input
;		AX - ID (offset) of virtual display to which we're printing
;	 DS:SI - pointer to string from which we're printing
;		CX - number of characters to print
; output
;		none
display_wrapper_print_dump:
	pusha
	push ds
	
	cmp cx, 0
	je display_wrapper_print_dump_noop	; a count of 0 means this is a NOOP
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_print_dump_virtual_only	; no
; case 1 - when display is active, we dump to vram
display_wrapper_print_dump_vram_only:
	pop ds								; restore DS as passed in
	call display_vram_print_dump		; dump to vram
	popa
	ret
; case 2 - when display is not active, we dump to the virtual display
display_wrapper_print_dump_virtual_only:
	pop ds								; restore DS as passed in
	call display_print_dump				; dump to virtual display
	popa
	ret
display_wrapper_print_dump_noop:
	pop ds
	popa
	ret
	

; Gets the cursor position in the specified virtual display.
; Gets the hardware cursor position if the specified virtual display is the 
; active virtual display.
;
; input
;		AX - ID (offset) of virtual display whose cursor position we return
; output
;		BH - row
;		BL - column
display_wrapper_get_cursor_position:
	push ds
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_get_cursor_position_virtual_only	; no
; case 1 - when display is active, we output to vram only
display_wrapper_get_cursor_position_vram_only:
	pop ds								; restore DS as passed in
	call display_get_hardware_cursor_position	; read position from hardware
	ret
; case 2 - when display is not active, we output to the virtual display only
display_wrapper_get_cursor_position_virtual_only:
	pop ds								; restore DS as passed in
	call display_get_cursor_position	; read position from virtual display
	ret

	
; Reads a character and attribute from the specified virtual display.
; Reads a character and attribute from vram if the specified virtual 
; display is the active virtual display.
;
; input:
;		AX - virtual display ID where we're writing the string
;		BH - cursor row
;		BL - cursor column
; output:
;		AH - attribute byte
;		AL - ASCII character byte
display_wrapper_read_character_attribute:
	push ds
	
	push cs								; switch DS to this segment for the
	pop ds								; dereference below
	cmp ax, word [activeDisplayOffset]	; is the specified display active?
	jne display_wrapper_read_character_attribute_virtual_only	; no
; case 1 - when display is active, we read from vram only
display_wrapper_read_character_attribute_vram_only:
	pop ds										; restore DS as passed in
	call display_vram_read_character_attribute	; read from vram
	ret
; case 2 - when display is not active, we read from the virtual display only
display_wrapper_read_character_attribute_virtual_only:
	pop ds								 ; restore DS as passed in
	call display_read_character_attribute; read from virtual display
	ret
