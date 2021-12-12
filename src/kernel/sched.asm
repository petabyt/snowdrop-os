;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains the scheduler, whose job is to manage running tasks, by accepting
; add, exit, and yield requests.
; It is based on a nonpreemptive round robin implementation.
; Additionally, it allows access to task parameters (program arguments).
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; task state format:
; bytes
;     0-1 CS 
;     2-3 IP 
;     4-5 FLAGS 
;     6-7 BP
;     8-9 GS
;   10-11 FS
;   12-13 ES
;   14-15 DS
;   16-17 DI
;   18-19 SI
;   20-21 DX
;   22-23 CX
;   24-25 BX
;   26-27 AX
;   28-29 SP
;   30-31 SS
;   32-33 virtual display ID
;   34-35 parent task ID
;   36-36 task lifetime
;   37-40 unused
;   41-42 segment of pointer to parameters buffer
;   43-44 offset of pointer to parameters buffer
TASK_STATE_PARAMETER_DATA_SIZE equ 512
TASK_STATE_ENTRY_SIZE equ 45	; in bytes

MAX_TASKS equ KERNEL_MAX_TASKS_AND_VIRTUAL_DISPLAYS
TASK_STATE_TABLE_SIZE equ MAX_TASKS*TASK_STATE_ENTRY_SIZE	; in bytes
NO_TASK equ 0FFFFh				; used to mark an unused task slot

FLAG_LIFETIME_FREE_ON_EXIT equ 0	; the default lifetime: free all resources
									; on task exit
FLAG_LIFETIME_KEEP_MEMORY_ON_EXIT equ 1	; keep allocated memory on task exit

TASK_INITIAL_SP equ 0000h		; value of SP register for newly-started tasks
TASK_INITIAL_IP equ 0000h		; value of IP register for newly-started tasks
initialFlags: dw 0FFh			; flags value for newly-started tasks

currentFlags: dw 0				; used when saving flags
schedulerHasStarted: dw 0		; whether the scheduler is active

taskStateTable: times TASK_STATE_TABLE_SIZE db 0
currentTaskOffset: dw 0			; byte offset into the table above

initialVideoMode: db 99	; this will store the video mode which was current
						; when we started; we switch back to this video mode
						; before locking up the CPU, so we can print an error
						; message

noTasksString: db 13, 10, 'The scheduler has run out of tasks. ', 0
cannotAddTaskString: db 13, 10, 'Cannot add new task.', 0
schedulerNoMemoryForParams:	db 13, 10, 'Cannot allocate memory for task parameters buffer', 0

schedulerHasExplicitNextTask:		db 0
schedulerExplicitNextTask:			dw 0

; Initializes the scheduler
;
; input
;		AX - initial value of the FLAGS register when starting a task
; output
;		none
scheduler_initialize:
	pushf
	pusha
	push ds
	push es
	
	push cs
	pop es
	push cs
	pop ds
	
	mov word [initialFlags], ax		; save initial FLAGS value
	
	; save current video mode
	mov ah, 0Fh						; function 0F gets current video mode
	int 10h							; get current video mode in AL
	mov byte [initialVideoMode], al	; and save it
	
	; clear out the tasks table
	mov cx, TASK_STATE_TABLE_SIZE / 2 ; we'll store a word at a time
	mov di, taskStateTable
	mov ax, NO_TASK				; fill up the task state table with empties
	cld
	rep stosw
	
	mov byte [cs:schedulerHasExplicitNextTask], 0
	
	pop es
	pop ds
	popa
	popf
	ret


; Sets task taht will be the target on next yield
;
; input
;		AX - task ID of task to which we will yield next
; output
;		none	
scheduler_set_next_task:
	pusha
	
	mov byte [cs:schedulerHasExplicitNextTask], 1
	mov word [cs:schedulerExplicitNextTask], ax
	
	popa
	ret
	

; Returns whether the scheduler has started
;
; input
;		none
; output
;		AX - 0 when the scheduler has not yet started; other value otherwise
scheduler_has_started:
	mov ax, word [cs:schedulerHasStarted]
	ret
	

; Starts the scheduler
;
; NOTE: at least one task must have been added beforehand
; NOTE: this is reached via jmp, and NOT call, as it is not meant to return
;
scheduler_start:
	push cs
	pop ds
	
	mov word [cs:schedulerHasStarted], 1
	
	call scheduler_find_next_task		; AX := offset of first task
	jc scheduler_start_starved			; if carry is set, we found no tasks
	
	mov word [currentTaskOffset], ax	; first task becomes the active task
	jmp scheduler_run_current_task


; This is reached when a task is searched for, but not found, indicating
; that the scheduler task list is empty
; 
scheduler_start_starved:
	push cs
	pop ds
	
	mov ah, 0Fh				; function 0F gets current video mode
	int 10h					; get current video mode in AL
	
	cmp al, byte [initialVideoMode]
	je scheduler_start_starved_print ; video mode hasn't changed
	
	mov ah, 0						 ; revert video mode to initial
	mov al, byte [initialVideoMode]
	int 10h
scheduler_start_starved_print:	
	mov si, noTasksString
	call debug_print_string
	jmp crash


; Invoked when the current task wishes to yield to another task
; NOTE: this is reached via jmp, and NOT call, as it is not meant to return
;       the idea is that we don't return to the saved return address, instead
;       saving it in the current task's state, and "returning" to the next
;       task in the list
; NOTE: expects the stack to contain register values from the 
;       current task, having been pushed like so by the int instruction:
;			pushf
;			push cs
;			push ip
;
scheduler_task_yield:
	; we first save the yielding task's state
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	push fs
	push gs
	push bp
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, word [currentTaskOffset]	; SI now points to beginning of slot
	
	pop word [ds:si+6]				; BP
	pop word [ds:si+8]				; GS
	pop word [ds:si+10]				; FS
	pop word [ds:si+12]				; ES
	pop word [ds:si+14]				; DS
	pop word [ds:si+16]				; DI
	pop word [ds:si+18]				; SI
	pop word [ds:si+20]				; DX
	pop word [ds:si+22]				; CX
	pop word [ds:si+24]				; BX
	pop word [ds:si+26]				; AX
	
	pop word [ds:si+2]				; IP
	pop word [ds:si+0]				; CS
	pop word [ds:si+4]				; FLAGS
	
	; after all the pops, SP has returned to what it was right before the task
	; called this interrupt
	mov word [ds:si+28], sp				; SP
	mov word [ds:si+30], ss				; SS
	
	; we finished saving the yielding task's state
	; we can now resume next available task
	call scheduler_find_next_task		; AX := offset of first task
	jc scheduler_start_starved			; if carry is set, we found no tasks
	mov word [currentTaskOffset], ax	; save new current task
	jmp scheduler_run_current_task		; run current task
	

; Adds a new task from the specified a memory segment, which contains
; a program ready to be run by the scheduler
;
; input
;		BX - segment containing the app that must be run as a task
;		DX - virtual display ID for the task
;	 DS:SI - pointer to string containing serialized parameter data for the 
;			 task being created (maximum 256 bytes)
; output
;		AX - task ID (offset)
scheduler_add_task:
	pushf
	push bx
	push cx
	push si
	push di
	push ds
	push es
	
	push ds
	pop es
	mov di, si						; ES:DI := DS:SI
	
	push cs
	pop ds
	
	call scheduler_find_empty_slot	; AX := byte offset of slot
	push ax							; [1] save task ID (offset)
	mov si, taskStateTable
	add si, ax						; SI now points to beginning of slot
	
	mov word [ds:si+0], bx			; CS (input in BX)
	mov word [ds:si+2], TASK_INITIAL_IP		; IP
	
	mov ax, word [initialFlags]
	mov word [ds:si+4], ax			; FLAGS
		
	mov word [ds:si+6], TASK_INITIAL_SP		; BP
	mov word [ds:si+8], bx			; GS
	mov word [ds:si+10], bx			; FS
	mov word [ds:si+12], bx			; ES
	mov word [ds:si+14], bx			; DS
	mov word [ds:si+16], 0			; DI
	mov word [ds:si+18], 0			; SI
	mov word [ds:si+20], 0			; DX
	mov word [ds:si+22], 0			; CX
	mov word [ds:si+24], 0			; BX
	mov word [ds:si+26], 0			; AX
	
	mov word [ds:si+28], TASK_INITIAL_SP	; SP
	mov word [ds:si+30], bx			; SS
	
	mov word [ds:si+32], dx			; virtual display ID
	
	mov ax, word [currentTaskOffset]
	mov word [ds:si+34], ax			; parent task ID (current task is parent)
	
	mov byte [ds:si+36], FLAG_LIFETIME_FREE_ON_EXIT	; lifetime
	
	push es
	push di									; [2] save pointer passed-in arg
	
	; allocate
	push ds
	push si									; [3] save pointer to task slot
	
	mov ax, TASK_STATE_PARAMETER_DATA_SIZE
	call dynmem_allocate					; DS:SI := buffer
	cmp ax, 0
	jne scheduler_add_task_got_mem
	mov si, schedulerNoMemoryForParams
	jmp crash_and_print						; crash - don't care about [2]
	
scheduler_add_task_got_mem:
	push ds
	pop es
	mov di, si								; ES:DI := pointer to param buffer

	pop si
	pop ds									; [3] DS:SI := pointer to task slot

	mov word [ds:si+41], es
	mov word [ds:si+43], di					; store pointer to param buffer
	
	push es
	pop ds
	mov si, di								; DS:SI := pointer to param buffer

	; zero out parameter data
	mov cx, TASK_STATE_PARAMETER_DATA_SIZE
	mov al, 0
	cld
	rep stosb								; zero-out task parameter data
	
	pop di
	pop es									; [2] ES:DI := ptr to param source

	; now add serialized parameter data, up to the limit, or a zero terminator
	; here, ES:DI points to string containing serialized parameter data
	mov bx, 0								; index into input string
scheduler_add_task_parameters_loop:
	mov al, byte [es:di+bx]
	cmp al, 0								; string terminator?
	je scheduler_add_task_done				; yes, so we're done
	mov byte [ds:si+bx], al					; copy this character
	
	inc bx									; next character
	cmp bx, TASK_STATE_PARAMETER_DATA_SIZE	; are we past the limit?
	jb scheduler_add_task_parameters_loop	; no, keep going

scheduler_add_task_done:
	pop ax							; [1] restore task ID (offset) to return

	pop es
	pop ds
	pop di
	pop si
	pop cx
	pop bx
	popf
	ret

	
; Yields to the task whose offset is in currentTaskOffset
; NOTE: this is reached via jmp, and NOT call, as it is not meant to return
;
scheduler_run_current_task:
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, word [currentTaskOffset]	; SI now points to beginning of slot

	; change to the stack of the task we're switching to
	pushf
	pop ax
	mov word [currentFlags], ax	; save old flags
	
	cli						; changing to task's own stack must be atomic
	mov ax, word [ds:si+28]
	mov sp, ax
	mov ax, word [ds:si+30]
	mov ss, ax				; we're done the atomic part

	mov ax, word [currentFlags]
	push ax
	popf					; restore flags
	
	; these will be popped automatically via iret
	push word [ds:si+4]		; FLAGS
	push word [ds:si+0]		; CS
	push word [ds:si+2]		; IP
	; these will be popped one by one (some will destroy DS and SI)
	push word [ds:si+26]
	push word [ds:si+24]
	push word [ds:si+22]
	push word [ds:si+20]
	push word [ds:si+18]
	push word [ds:si+16]
	push word [ds:si+14]
	push word [ds:si+12]
	push word [ds:si+10]
	push word [ds:si+8]
	push word [ds:si+6]
	; restore registries in preparation for running a task
	pop bp					; BP
	pop gs					; GS
	pop fs					; FS
	pop es					; ES
	pop ds					; DS
	pop di					; DI
	pop si					; SI
	pop dx					; DX
	pop cx					; CX
	pop bx					; BX
	pop ax					; AX

	iret					; pop FLAGS, IP, CS, essentially simulating a 
							; return from an interrupt, and into the task
							; being made current


; Called by the current task when it wishes to exit
;
; NOTE: this is reached via jmp, and NOT call, as it is not meant to return
; NOTE: expects the stack to contain register values from the 
;       current task, having been pushed like so by the int instruction:
;			pushf
;			push cs
;			push ip
scheduler_task_exit:
	; first, clear stack of what the int instruction pushed on it
	; (since we're not using them to return to the exiting task)
	pop ax				; IP
	pop bx				; CS (will be used further down to free task's memory)
	pop ax				; FLAGS
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, word [currentTaskOffset]	; SI now points to beginning of slot

	mov word [ds:si], NO_TASK			; mark exiting task's slot as empty
	
	mov ax, word [ds:si+32]
	call display_free					; also free its virtual display

	push word [ds:si+41]
	push word [ds:si+43]
	pop si
	pop ds								; DS:SI := pointer to param buffer
	call dynmem_deallocate				; also free its param buffer

	call scheduler_find_next_task		; AX := offset of next task
	jc scheduler_start_starved			; if carry is set, we found no tasks
	mov word [cs:currentTaskOffset], ax	; set task as current
	jmp scheduler_run_current_task		; pass control to it

	
; Returns the lifetime mode of the current task
;
; input:
;		none
; output:
;		AX - lifetime mode of current task:
;			 0 - "keep memory"
;			 1 - "deallocate memory on exit"
scheduler_get_current_task_lifetime:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, word [currentTaskOffset]	; SI now points to beginning of slot
	
	test byte [ds:si+36], FLAG_LIFETIME_KEEP_MEMORY_ON_EXIT	; do we have to keep memory?
	jnz scheduler_get_current_task_lifetime_keep
	
	mov ax, 1
	jmp scheduler_get_current_task_lifetime_done
scheduler_get_current_task_lifetime_keep:
	mov ax, 0							; "keep memory" mode
scheduler_get_current_task_lifetime_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret

	
; output
;		AX - byte offset into task state table of first empty slot
scheduler_find_empty_slot:
	push bx
	push si
	push ds
	
	push cs
	pop ds
	
	; find first empty task state slot
	mov si, taskStateTable
	mov bx, 0				; offset of task state slot being checked
scheduler_find_empty_slot_loop:
	cmp word [ds:si+bx], NO_TASK			; is this slot empty?
											; (are first two bytes NO_TASK?)
	je scheduler_find_empty_slot_found		; yes
	
	add bx, TASK_STATE_ENTRY_SIZE			; next slot
	cmp bx, TASK_STATE_TABLE_SIZE			; are we past the end?
	jb scheduler_find_empty_slot_loop		; no
scheduler_find_empty_slot_full:				; yes
	mov si, cannotAddTaskString
	call debug_print_string
	jmp crash
scheduler_find_empty_slot_found:
	mov ax, bx								; return result in AX
scheduler_find_empty_slot_done:
	pop ds
	pop si
	pop bx
	ret


; Return the offset of the next task. Assumes at least one task exists
;
; output
;		AX - byte offset into task state table of next task
;		Carry - set when no tasks are queued, clear otherwise
scheduler_find_next_task:
	push bx
	push si
	push ds
	
	cmp byte [cs:schedulerHasExplicitNextTask], 0
	je scheduler_find_next_task__next_in_line
	; we have been told to switch to a specific task
	
	mov byte [cs:schedulerHasExplicitNextTask], 0
	mov bx, [cs:schedulerExplicitNextTask]
	jmp scheduler_find_next_task_found
	
scheduler_find_next_task__next_in_line:
	push cs
	pop ds
	
	mov si, taskStateTable
	mov bx, word [currentTaskOffset]		; we start at the task right after
	add bx, TASK_STATE_ENTRY_SIZE			; the current one
	cmp bx, TASK_STATE_TABLE_SIZE			; are we past the end?
	jb scheduler_find_next_task_loop		; no, so we can start immediately
	mov bx, 0								; yes, so cycle back to beginning	
scheduler_find_next_task_loop:
	cmp word [ds:si+bx], NO_TASK			; does this slot contain a task?
	jne scheduler_find_next_task_found		; yes
	
	cmp bx, word [currentTaskOffset]		; if we're back to the current task
	je scheduler_find_next_task_starved		; it means that none are available
	
	add bx, TASK_STATE_ENTRY_SIZE			; no, next slot
	cmp bx, TASK_STATE_TABLE_SIZE			; are we past the end?
	jb scheduler_find_next_task_loop		; no
scheduler_find_next_task_cycle_back:		; yes
	mov bx, 0								; go back to the beginning 
											; of task state table
	jmp scheduler_find_next_task_loop		; and try again
scheduler_find_next_task_starved:
	stc										; set carry to indicate failure
	jmp scheduler_find_next_task_done
scheduler_find_next_task_found:
	mov ax, bx								; return result in AX
	clc										; clear carry to indicate success
scheduler_find_next_task_done:
	pop ds
	pop si
	pop bx
	ret


; Return the virtual display ID of the specified task
;
; input
;		AX - ID (offset) of task
; output
;		AX - virtual display ID of the specified task
scheduler_get_display_id_for_task:
	push ds
	push si
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, ax
	mov ax, word [ds:si+32]				; AX := virtual display ID
	
	pop si
	pop ds
	ret


; Return the ID (offset) of the current task
;
; output
;		AX - ID (offset) of the current task
scheduler_get_current_task_id:
	push ds
	
	push cs
	pop ds
	
	mov ax, word [currentTaskOffset]
	
	pop ds
	ret

	
; Return the memory segment in which the current task resides
;
; input
;		none
; output
;		BX - segment
scheduler_get_current_task_segment:
	push ds
	push ax
	push cx
	push dx
	push si
	push di
	
	mov ax, word [cs:currentTaskOffset]
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, ax
	mov bx, word [ds:si+0]				; BX := segment
	
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	pop ds
	ret
	

; Get parent task ID (offset) of specified task
;
; input
;		AX - task ID (offset)
; output
;		AX - parent task ID (offset)
scheduler_get_parent_task_id:
	push ds
	push si
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, ax
	mov ax, word [ds:si+34]				; AX := parent task ID
	
	pop si
	pop ds
	ret


; Get status of specified task
;
; input
;		AX - task ID (offset)
; output
;		AX - status:
;			0FFFFh - not present
;			otherwise - present
scheduler_get_task_status:
	push ds
	push si
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, ax
	mov ax, word [ds:si+0]				; AX := status
	
	pop si
	pop ds
	ret


; Sets the lifetime of the specified task
; 
; input
;		AX - task ID (offset)
;		BL - lifetime
;			bit 0 - when set, keep memory after task exit
;           bit 1-7 - unused
; output
;		none
scheduler_set_task_lifetime:
	push ds
	push si
	
	push cs
	pop ds
	
	mov si, taskStateTable
	add si, ax
	mov byte [ds:si+36], bl				; set lifetime
	
	pop si
	pop ds
	ret

	
; Gets the parameter with the specified name, of the specified task
; 
; input
;		AX - task ID (offset)
;	 DS:SI - pointer to the name of the parameter to look up (zero-terminated)
;	 ES:DI - pointer to buffer into which parameter value will be read
; output
;		AX - 0 when parameter was not found, another value otherwise
scheduler_get_task_parameter:
	push fs
	push bx
	push cx
	push dx
	push si
	push di
	
	push si								; [1]
	
	mov si, taskStateTable
	add si, ax							; CS:SI := pointer to task entry
	
	push word [cs:si+41]
	pop fs
	mov dx, word [cs:si+43]				; FS:DX := pointer to param buffer
	
	pop si								; [1]
	
	mov cx, TASK_STATE_PARAMETER_DATA_SIZE	; CX := parameter data size
	call params_get_parameter_value			; AX := 0 when parameter not found

	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop fs
	ret

	
; Dumps to screen the parameter data of specified task
;
; input
;		AX - task ID (offset)
; output
;		none
scheduler_print_task_params:
	pusha
	push ds

	push cs
	pop ds
	call debug_print_newline
	
	push ax
	mov al, 178
	call debug_print_char
	pop ax

	mov si, taskStateTable
	add si, ax						; SI now points to beginning of slot
	
	push word [cs:si+41]
	pop ds
	mov si, word [cs:si+43]			; DS:SI := pointer to param buffer
	
	mov cx, TASK_STATE_PARAMETER_DATA_SIZE
	call debug_print_dump
	
	push cs
	pop ds
	
	mov al, 178
	call debug_print_char
	call debug_print_newline
	
	pop ds
	popa
	ret
