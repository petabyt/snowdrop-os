;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The Snowdrop OS Snow Shell
; This is meant as the main shell to the Snowdrop OS kernel. It lets the user
; enter app names, and then loading and running them.
; Snow Shell is the replacement to Console and relies on the newly-implemented
; scheduler, memory manager, and virtual display driver. 
; Thus, it is able to start multiple tasks to run concurrently and to allow the
; user to switch between each task's virtual display.
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

	jmp console_start
	
SCANCODE_ALT_F1 equ 68h
SCANCODE_ALT_F9 equ 70h

newlineString:		db 13, 10, 0
consoleInitString:	db 13, 10
					db 'Snowshell loaded (with multi-task support)', 13, 10
					db 'Example of running an app:   paramst [first=hello] [second=world]', 13, 10
					db 'To begin, try entering "apps" to run the APPS app. Also try "desktop".', 13, 10
					db 0

consolePromptString:	db 13, 10, "[Snowdrop OS snowshell]: ", 0
consoleTooLongString:	db 13, 10
						db "Error: App name cannot exceed 8 characters.", 0
appLoadFailedString1:	db 13, 10, "Error: Could not load app ", 0
appLoadFailedString2:	db "; check that the file ", 0
appLoadFailedString3:	db ".APP exists.", 0
outOfMemoryString:		db 13, 10, "Error: Could not allocate memory to load app.", 0
alreadyRunningString:	db 13, 10, "Error: Snowdrop OS snowshell is already running.", 0
noSuchTaskString:		db 13, 10, "Error: Cannot switch display; task may have exited.", 0

switchDisplayString:	db "[task display - ALT+F", 0
switchDisplayString2:	db "]: ", 0

MAX_LINE_LENGTH 		equ 8 + 1 + 256			; shortest app name +
												; space +
												; longest parameter value
LINE_BUFFER_LENGTH		equ MAX_LINE_LENGTH + 1	; add terminator
currentLineBuffer: 		times LINE_BUFFER_LENGTH db 0 ; add terminator
previousLineBuffer:		times LINE_BUFFER_LENGTH db 0 ; add terminator
previousLineDi:		dw currentLineBuffer
	; value of DI when Enter was pressed on the previous line
	; it's initialized to point to the beginning of the current line,
	; indicating "empty"

appNameBuffer:		db "        APP", 0
exclusionAppName:	db "SSHELL  APP", 0		; we disallow loading this app

NO_TASK equ 0FFFFh
MAX_CHILD_TASKS 	equ 7
taskIdsList:		times ( MAX_CHILD_TASKS + 1 ) dw 0 ; +1 for this task
taskIdsListEnd:


console_start:
	cld
	
	int 9Ah						; AX := current task ID
	mov di, taskIdsList 
	mov word [es:di+0], ax		; taskIdsList[0] := this task's ID
	
	mov ax, NO_TASK
	mov cx, MAX_CHILD_TASKS
	mov di, taskIdsList
	add di, 2					; move to index 1 (word)
	rep stosw					; fill all child task slots with "empty"
	
	mov si, consoleInitString	; print greeting
	int 97h
	
	int 83h						; clear keyboard buffer
	
	; Start reading characters into a new line
console_read_new_line:
	mov si, consolePromptString
	int 97h						; show prompt
	
	call console_clear_current_line_buffer
	mov di, currentLineBuffer	; DI points to beginning of buffer
console_read_character:
	hlt							; do nothing until there's an interrupt
	
	int 94h						; yield to let other tasks run before we 
								; check whether a key has been pressed
	mov ah, 1
	int 16h 									; any key pressed?
	jnz console_read_character_key_was_pressed  ; yes
	; no key pressed, so we just yield, to let other tasks run
	jmp console_read_character	; read next character
console_read_character_key_was_pressed:
	mov ah, 0
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	
	; first try to see if we're switching to a different display
	cmp ah, SCANCODE_ALT_F9	; we only care about F1 - F9 keys
	ja console_read_character_key_not_switching_display
	cmp ah, SCANCODE_ALT_F1		; we only care about F1 - F9 keys
	jb console_read_character_key_not_switching_display
	
	call console_switch_active_display	; switch display
	cmp al, 0							; did we actually switch?
	jne console_read_new_line			; no, display prompt and read again
	jmp console_read_character			; yes, read next character
	; we're not switching to a different display, the key is meant "for us"
console_read_character_key_not_switching_display:
	cmp al, 13				; ASCII for the Enter key
	je console_process_line	; process current line
	
	cmp al, 8				; ASCII for the Backspace key
	jne console_read_character_not_enter_not_backspace
	
	; process Backspace
	cmp di, currentLineBuffer
	je console_read_character	; if buffer is empty, Backspace does nothing
	
	; handle Backspace - erase last character
	dec di					; move buffer pointer back one 
	mov byte [es:di], 0		; and clear that last location to 0
	
	call console_print_character	; show the effect of Backspace on screen
	jmp console_read_character		; and read next character
	
console_read_character_not_enter_not_backspace:
	cmp ah, COMMON_SCAN_CODE_UP_ARROW
	je console_up_arrow
	
	cmp ah, COMMON_SCAN_CODE_DOWN_ARROW
	je console_down_arrow

	; the Enter or Backspace key was not pressed if we got here
	cmp al, 0
	je console_read_character	; non-printable characters are ignored
								; (arrow keys, function keys, etc.)
	cmp al, 27
	je console_read_character	; ESCAPE is ignored
	
	mov bx, di
	sub bx, currentLineBuffer	; BX := current - beginning
	cmp bx, MAX_LINE_LENGTH
	jae console_read_character	; if we're MAX_LINE_LENGTH away from
								; beginning of the buffer, the buffer 
								; is full, so we'll do nothing
	
	; store in buffer the character which was just typed
	stosb
	
	call console_print_character
	jmp console_read_character
	
	
console_down_arrow:
	mov al, 8					; ASCII of Backspace
	sub di, currentLineBuffer	; DI := current line length
	cmp di, 0
	je console_down_arrow_loop_done	; empty - nothing to erase on screen
console_down_arrow_loop:
	call console_print_character	; erase character on screen
	dec di
	jnz console_down_arrow_loop		; erase next character
console_down_arrow_loop_done:
	mov di, currentLineBuffer	; point DI to the beginning of the buffer,
								; since it's now empty
	jmp console_read_character


console_up_arrow:
	mov al, 8					; ASCII of Backspace
	sub di, currentLineBuffer	; DI := current line length
	cmp di, 0
	je console_up_arrow_loop_done	; empty - nothing to erase on screen
console_up_arrow_loop:
	call console_print_character	; erase character on screen
	dec di
	jnz console_up_arrow_loop		; erase next character
console_up_arrow_loop_done:	
	; fill the current line buffer with the contents of the previous line
	
	mov si, previousLineBuffer
	mov di, currentLineBuffer
	mov cx, LINE_BUFFER_LENGTH
	rep movsb

	mov si, currentLineBuffer
	int 97h							; print line to screen
	
	mov di, word [previousLineDi]	; restore previous line DI
	jmp console_read_character
	

console_process_line:
	cmp di, currentLineBuffer		; is it an empty line?
	je console_process_line_after_saving_line	; don't save it
	
	mov word [cs:previousLineDi], di	; save DI
	; copy current line into previous line
	pusha
	mov si, currentLineBuffer
	mov di, previousLineBuffer
	mov cx, LINE_BUFFER_LENGTH
	rep movsb
	popa
console_process_line_after_saving_line:
	; here, DI points to the terminator of the currently-entered line (which
	; starts at currentLineBuffer)
	cmp di, currentLineBuffer		; is line empty?
	je console_read_new_line		; if line is empty, start new line
	
	; find first space or terminator
	mov si, currentLineBuffer
	mov cx, MAX_LINE_LENGTH
console_process_line_find_space_or_terminator_loop:
	cmp byte [ds:si], 0				; terminator?
	je console_process_line_no_params	; yes, so there are no parameters
	cmp byte [ds:si], ' '			; space?
	je console_process_line_space_found	; yes, so we have parameters
	inc si							; next character
	loop console_process_line_find_space_or_terminator_loop	; next char
console_process_line_space_found:	
	; SI now points to the space, which is right before the first character
	; of the parameter data
	mov byte [ds:si], 0				; convert first space into terminator
	mov di, si						; DI := pointer to terminator of app name
	inc si							; SI := pointer to parameter data
	jmp console_process_line_perform
console_process_line_no_params:
	mov di, si						; DI := pointer to terminator of app name
									; here, SI = pointer to terminator of app
									; name, so SI points to the empty string
console_process_line_perform:
	; here, DI points to the terminator of the app name on the 
	; currently-entered line (which starts at currentLineBuffer)
	; here, SI points to the first character of the parameter data
	call console_execute_app
	jmp console_read_new_line		; start new line

	
; input:
;			ASCII in AL
console_print_character:
	pusha
	
	cmp al, 8
	je console_print_character_backspace

	cmp al, 9
	je console_print_character_tab
	
	cmp al, 126		; last "type-able" ASCII code
	ja console_print_character_done
	cmp al, 32		; first "type-able" ASCII code
	jb console_print_character_done
	
	mov dl, al
	int 98h			; not a special character, so just print it
	jmp console_print_character_done
console_print_character_backspace:
	mov dl, al
	int 98h			; no longer a special character, so just print it
	jmp console_print_character_done
console_print_character_tab:
	mov dl, ' '		; in the console, tabs are printed like blank spaces
	int 98h
	jmp console_print_character_done
	
console_print_character_done:
	popa
	ret


; input:
;			none
console_clear_current_line_buffer:
	pusha
	mov di, currentLineBuffer
	mov cx, MAX_LINE_LENGTH
	mov al, 0
	rep stosb					; fill current line buffer with NULLs
	popa
	ret

; input:
;			none
console_clear_app_name_buffer:
	pusha
	mov di, appNameBuffer
	mov cx, 8
	mov al, ' '
	rep stosb					; fill app name buffer with blanks, since 
								; that's how FAT12 file names are padded
	popa
	ret
	
	
; input:
;		DS:DI - pointer to the terminator of the app name on the 
;				currently-entered line (which starts at currentLineBuffer)
;		DS:SI - pointer to the first character of the parameter data
console_execute_app:
	pusha
	
	mov cx, di
	sub cx, currentLineBuffer		; CX := length of line
	cmp cx, 8
	jbe console_execute_app_name_not_too_long	; name not too long
	
	; app name is too long, so we're done
	mov si, consoleTooLongString
	int 97h							; print error message
	popa
	ret
	
console_execute_app_name_not_too_long:
	mov dx, si					; [1] DX := pointer to parameter data
	
	call console_clear_app_name_buffer
	mov si, currentLineBuffer
	mov di, appNameBuffer
	rep movsb
	
	mov si, appNameBuffer
	int 82h						; convert app name to uppercase
	mov di, exclusionAppName
	mov cx, 11
	repe cmpsb					; compare 11 contiguous bytes
	jnz console_execute_app_perform_load ; if zero flag is not set, the last 
										 ; comparison failed, so we're not 
										 ; trying to run ourselves again
	mov si, alreadyRunningString
	int 97h							; tell user we're already running
	jmp console_execute_app_done
	
console_execute_app_perform_load:
	int 91h						; ask kernel for a memory segment in BX
	cmp ax, 0					; did we get one?
	je console_execute_app_perform_load_got_segment	; yes
	; no - we did not get the memory we asked for
	mov si, outOfMemoryString
	int 97h
	jmp console_execute_app_done	; done, but not executing
console_execute_app_perform_load_got_segment:
	push es
	
	mov es, bx					; ES := newly allocated segment
	mov di, 0
	mov si, appNameBuffer
	int 81h						; load app to ES:DI

	pop es

	cmp al, 0
	je console_execute_app_load_success

	; load failed
	int 92h							; free memory segment in BX
	
	mov si, appLoadFailedString1
	int 97h							; print error message
	mov si, currentLineBuffer
	int 82h							; convert line contents to upper case
	int 97h
	mov si, appLoadFailedString2
	int 97h
	mov si, currentLineBuffer
	int 97h
	mov si, appLoadFailedString3
	int 97h
	jmp console_execute_app_done	; we're done
	
console_execute_app_load_success:	
	; find an empty spot in our task list to store the ID of our new task
	call console_find_task_slot	; CX := offset in task list for our new task
	
	mov si, dx					; [1] SI := pointer to param data

	; here, BX = segment where we loaded the app (from above)
	int 93h						; schedule the new task at BX:0000
								; AX := task ID
	
	; store the ID of our new task (here, CX = offset of task list slot)
	mov si, taskIdsList
	add si, cx					; SI now points to task list slot
	mov word [ds:si], ax		; store task ID (from above, DS:SI points to
								; the slot in our tasks list)
	
	; inform user of the key combination to access the new task's display
	int 0AAh					; get cursor position
	push bx						; [1] save position
	
	mov bl, 0					; home cursor
	int 9Eh						; move cursor
	
	mov si, switchDisplayString
	int 97h
	
	shr cx, 1					; CX := index into array (2 bytes per)
	inc cx						; Function keys are 1-based
	add cl, '0'					; itoa (ignoring bh, due to how many slots
								; we actually have)
	mov dl, cl
	int 98h						; print character in DL
	
	mov si, switchDisplayString2
	int 97h
	
	pop bx						; [1] restore position
	int 9Eh						; move cursor
	
	; print a new line so that apps don't need to
	mov si, newlineString
	int 97h

	; yield to new task now, so that apps which write directly to the screen
	; via BIOS can do so before our prompt is displayed again.
	; NOTE: we also yield every time we unsuccessfully check whether the user 
	;       pressed any keys. (see above, near top of this file)
	int 94h
	
console_execute_app_done:
	popa
	ret


; Switches to a virtual display
;
; input:
;		AH - scan code of key
; output:
;		AL - 0 when display was switched
console_switch_active_display:
	push si
	push bx
	push dx
	
	sub ah, SCANCODE_ALT_F1		; convert to index from F1
	shl ah, 1					; convert to offset (each entry is 2 bytes)
	
	mov al, ah
	mov ah, 0					; AX := offset of task
	mov si, taskIdsList
	add si, ax					; SI now points to appropriate task ID entry
	
	mov ax, word [ds:si]		; AX := ID of task to whose display we switch
	cmp ax, NO_TASK				; if no task is there, we don't switch
	je console_switch_active_display_no_such_task ; no task
	
	mov dx, ax					; save task ID
	int 99h						; AX := task status
	cmp ax, 0FFFFh				; is task not present in the scheduler?
	je console_switch_active_display_no_such_task	; not present, so we do nothing
	
	mov ax, dx					; restore task ID
	int 96h						; activate task's display
	mov al, 0					; we did switch
	jmp console_switch_active_display_done

console_switch_active_display_no_such_task:
	mov si, noSuchTaskString
	int 97h
	mov al, 1					; we did not switch
console_switch_active_display_done:
	pop dx
	pop bx
	pop si
	ret
	

; Find a slot in the task list that either doesn't contain a task, or 
; contains a task that's no longer present in the scheduler
;
; output:
;		CX - offset of task list slot found
console_find_task_slot:
	push ax
	push bx
	push si
	
	mov si, taskIdsList
	mov bx, 0					; will store offset
console_find_task_slot_loop:
	mov ax, word [ds:si+bx]		; AX := task ID
	cmp ax, NO_TASK				; if no task is there, we found our spot
	je console_find_task_slot_done	; we found our spot

	push bx						; save BX because the call below does not preserve it
	int 99h						; AX := task status
	pop bx						; restore BX
	cmp ax, 0FFFFh				; is task not present in the scheduler?
	je console_find_task_slot_done	; we found our spot
	
	add bx, 2					; next task list slot (2 bytes per)
	jmp console_find_task_slot_loop
	
console_find_task_slot_done:
	mov cx, bx					; we return the task list offset in CX
	pop si
	pop bx
	pop ax
	ret

%include "common\scancode.asm"
