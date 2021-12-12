;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains task-related routines.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_TASKS_
%define _COMMON_TASKS_

; task lifetime flags
COMMON_FLAG_LIFETIME_FREE_ON_EXIT equ 0	; the default lifetime: free all 
										; resources on task exit
COMMON_FLAG_LIFETIME_KEEP_MEMORY_ON_EXIT equ 1 ; keep allocated memory on task exit


tasksNoMemoryString: db "Failed to allocate memory. Exiting...", 0

; Let other tasks run until our display is made active
; The purpose of this is to serve as a stopgap until all input/output resources
; are virtualized.
;
common_yield_until_my_display_is_made_active:
	pusha
common_yield_until_my_display_is_made_active_loop:
	int 94h						; yield
	int 9Ah						; get current (my) task ID
	int 99h						; get task status by ID
								; BX := 1 when task's display is active
	cmp bx, 1
	jne common_yield_until_my_display_is_made_active_loop
	
	popa
	ret

	
; Allocate a segment of memory.
; On failure, print an error message and cause the current task to exit.
;
; This is meant to be used at the beginning of a consumer app, when that app 
; cannot function without the memory it is requesting.
; 
; Input:
;		none
; Output:
;		BX - segment that was allocated
common_task_allocate_memory_or_exit:
	push ax
	; allocate a memory segment to hold any files we read (for copying)
	int 91h							; BX := allocated segment, AX:=0 on success
	cmp ax, 0						; if AX != 0, memory was not allocated
	jne common_task_allocate_memory_or_exit_no_memory
	; return allocated segment in BX
	pop ax
	ret
common_task_allocate_memory_or_exit_no_memory:
	; we not print an error message and exit the current task
	; since we're exiting, there's no need to preserve the stack
	push cs
	pop ds
	mov si, tasksNoMemoryString		; DS:SI := pointer to error message
	int 80h							; print error message
	int 95h							; exit
	
	
%endif
