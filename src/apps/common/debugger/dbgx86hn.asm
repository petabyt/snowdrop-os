;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains interrupt handler management functionality
; for Snowdrop OS's debugger.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DBGX86_HANDLERS_
%define _COMMON_DBGX86_HANDLERS_

FLAGS_TRAP_ENABLE				equ 1 << 8	; trap flag, used to enable single step
FLAGS_TRAP_DISABLE				equ 0FFFFh ^ FLAGS_TRAP_ENABLE

dbgx86OldSingleStepHandlerSeg:	dw 0	; old handler
dbgx86OldSingleStepHandlerOff:	dw 0	; (so we can restore it on shutdown)

dbgx86OldBreakpointHandlerSeg:	dw 0	; old handler
dbgx86OldBreakpointHandlerOff:	dw 0	; (so we can restore it on shutdown)

dbgx86OlTaskExitHandlerSeg:		dw 0	; old handler
dbgx86OlTaskExitHandlerOff:		dw 0	; (so we can restore it on shutdown)

; these are populated with the values that were current in the watched
; program immediately before an int1 or int3, as well as return values
dbgx86HaltReturnDS:				dw 0
dbgx86HaltReturnES:				dw 0
dbgx86HaltReturnFS:				dw 0
dbgx86HaltReturnGS:				dw 0
dbgx86HaltReturnSS:				dw 0
dbgx86HaltReturnAX:				dw 0
dbgx86HaltReturnBX:				dw 0
dbgx86HaltReturnCX:				dw 0
dbgx86HaltReturnDX:				dw 0
dbgx86HaltReturnSP:				dw 0
dbgx86HaltReturnBP:				dw 0
dbgx86HaltReturnSI:				dw 0
dbgx86HaltReturnDI:				dw 0

dbgx86HaltReturnCS:				dw 0
dbgx86HaltReturnIP:				dw 0
dbgx86HaltReturnFlagsPtrOff:	dw 0	; pointer to stack position of flags
dbgx86HaltReturnIPPtrOff:		dw 0	; pointer to stack position of IP

dbgx86TaskExitReturnCS:			dw 0
dbgx86TaskExitReturnIP:			dw 0

DBGX86_HALT_TYPE_UNKNOWN		equ 0
DBGX86_HALT_TYPE_BREAKPOINT		equ 1
DBGX86_HALT_TYPE_SINGLE_STEP	equ 2

DBGX86_USER_ACTION_UNKNOWN		equ 0
DBGX86_USER_ACTION_CONTINUE		equ 1
DBGX86_USER_ACTION_SINGLE_STEP	equ 2
DBGX86_USER_ACTION_TERMINATE	equ 3
	
dbx86LastHaltType:				db 0
dbx86LastHaltBreakpointAddr:	dw 0
dbx86LastUserAction:			db 0


; Initializes interrupt handlers in preparation for yielding to watched task
;
; input:
;		none
; output:
;		none
dbgx86Handlers_initialize:
	pusha
	
	mov byte [cs:dbx86LastHaltType], DBGX86_HALT_TYPE_UNKNOWN
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_UNKNOWN
	
	mov ax, word [cs:dbgx86BinaryOff]
	mov word [cs:dbx86LastHaltBreakpointAddr], ax
		
	popa
	ret


; Restores old handlers
;
; input:
;		none
; output:
;		none
dbgx86Handlers_restore_interrupt_handlers:
	pusha
	push es

	; restore old single step interrupt handler
	mov di, word [cs:dbgx86OldSingleStepHandlerOff]
	mov ax, word [cs:dbgx86OldSingleStepHandlerSeg]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 1					; interrupt number
	int 0B0h					; register interrupt handler
	
	; restore old breakpoint interrupt handler
	mov di, word [cs:dbgx86OldBreakpointHandlerOff]
	mov ax, word [cs:dbgx86OldBreakpointHandlerSeg]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 3					; interrupt number
	int 0B0h					; register interrupt handler
	
	; restore old "task exit" interrupt handler
	mov di, word [cs:dbgx86OlTaskExitHandlerOff]
	mov ax, word [cs:dbgx86OlTaskExitHandlerSeg]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 95h					; interrupt number
	int 0B0h					; register interrupt handler

	pop es
	popa
	ret	
	
	
; Register all of our interrupt handlers
;
; input:
;		none
; output:
;		none
dbgx86Handlers_register_interrrupt_handlers:
	pusha
	push es

	; register the single step interrupt handler
	pushf
	cli								; we don't want interrupts firing before
									; we've saved the old handler address
									
	mov al, 1						; interrupt number
	push cs
	pop es
	mov di, dbgx86Handlers_single_step_interrupt_handler
									; ES:DI := interrupt handler
	int 0B0h						; register interrupt handler
									; (returns old interrupt handler in DX:BX)
	mov word [cs:dbgx86OldSingleStepHandlerOff], bx	; save offset of old handler
	mov word [cs:dbgx86OldSingleStepHandlerSeg], dx	; save segment of old handler
	
	; register the breakpoint interrupt handler
	mov al, 3						; interrupt number
	push cs
	pop es
	mov di, dbgx86Handlers_breakpoint_interrupt_handler
									; ES:DI := interrupt handler
	int 0B0h						; register interrupt handler
									; (returns old interrupt handler in DX:BX)
	mov word [cs:dbgx86OldBreakpointHandlerOff], bx	; save offset of old handler
	mov word [cs:dbgx86OldBreakpointHandlerSeg], dx	; save segment of old handler
	
	; register the "task exit" interrupt handler
	mov al, 95h						; interrupt number
	push cs
	pop es
	mov di, dbgx86Handlers_task_exit_interrupt_handler 
									; ES:DI := interrupt handler
	int 0B0h						; register interrupt handler
									; (returns old interrupt handler in DX:BX)
	mov word [cs:dbgx86OlTaskExitHandlerOff], bx	; save offset of old handler
	mov word [cs:dbgx86OlTaskExitHandlerSeg], dx	; save segment of old handler
	
	popf

	pop es
	popa
	ret


; The purpose of this interrupt handler is to notify the debugger when
; the watched program exits	
;
; input:
;		none
; output:
;		none
dbgx86Handlers_task_exit_interrupt_handler:
	push bp
	mov bp, sp
	mov bp, word [ss:bp+2]
	mov word [cs:dbgx86TaskExitReturnIP], bp	; save
	mov bp, sp
	mov bp, word [ss:bp+4]
	mov word [cs:dbgx86TaskExitReturnCS], bp	; save
	pop bp

	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	; BEGIN actual interrupt handler work

	pusha						; the original flags and registers
	pushf						; must make it into the previous handler
	
	int 9Ah											; AX := current task ID
	cmp ax, word [cs:dbgx86WatchedProgramTaskId]	; is it the watched program
	jne dbgx86Handlers_task_exit_interrupt_handler_invoke_previous
								; some other task exited
	; the task of the watched program exited
	mov byte [cs:dbgx86MustCleanupAndExit], 1

	; this sets dbgx86ProgramExitOffset assuming the program exited normally
	; (as in, user did not choose to exit)
	mov ax, word [cs:dbgx86TaskExitReturnIP]	; this points to right after 
	sub ax, 2									; int 95h, so we bring it back
	mov word [cs:dbgx86ProgramExitOffset], ax
	
	; try to see if we should set it according to address that was highlighted
	; when user chose to exit, but ONLY IF user DID choose to exit
	cmp byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_TERMINATE
	jne dbgx86Handlers_task_exit_interrupt_handler_my_work_is_done
	
	; user did choose exit, so the exit offset must be whatever address was
	; highlighted at the time
	mov ax, word [cs:dbgx86UiHighlightedAddress]
	mov word [cs:dbgx86ProgramExitOffset], ax
	
dbgx86Handlers_task_exit_interrupt_handler_my_work_is_done:
	popf
	popa
	
	; we get here when the watched program has exited
	
	; we now invoke the previous handler as if the watched program did
	
	; NOTE: upon task exit, the scheduler looks at the "return CS"
	;       value on the stack, to know which allocated segment
	;       to free
	;       we supply the segment of the bytecode and not THIS CS
	;       so that the scheduler doesn't free the debugger's
	;       segment by accident
	; NOTE: the return address is not important as a return address per se,
	;       since we don't return from an int 95h anyway
	; push registers to simulate the behaviour of the "int" opcode
	pushf									; FLAGS
	push word [cs:dbgx86BinarySeg]			; return CS
	push word 1337h							; (dummy) return IP

	mov byte [cs:dbgx86BinarySegmentDeallocated], 1	; mark this as deallocated
	
	; invoke previous handler
	; use retf to simulate a "jmp far [oldHandlerSeg]:[oldHandlerOff]"
	push word [cs:dbgx86OlTaskExitHandlerSeg]
	push word [cs:dbgx86OlTaskExitHandlerOff]
	retf						; invoke previous handler
	
	; we do NOT get here, unless the kernel's "task exit" handler erroneously
	; returns here somehow

dbgx86Handlers_task_exit_interrupt_handler_invoke_previous:	
	; we get here when a task other than the watched program has exited
	
	; invoke previous handler normally
	
	; the idea now is to simulate calling the old handler via an "int" opcode
	; this takes two steps:
	;     1. pushing FLAGS, CS, and return IP (3 words)
	;     2. far jumping into the old handler, which takes two steps:
	;         2.1. pushing the destination segment and offset (2 words)
	;         2.2. using retf to accomplish a far jump
	
	; push registers to simulate the behaviour of the "int" opcode
	pushf													; FLAGS
	push cs													; return CS
	push word dbgx86Handlers_task_exit_interrupt_handler_old_handler_ret_addr
															; return IP

	; invoke previous handler
	; use retf to simulate a "jmp far [oldHandlerSeg]:[oldHandlerOff]"
	push word [cs:dbgx86OlTaskExitHandlerSeg]
	push word [cs:dbgx86OlTaskExitHandlerOff]
	retf						; invoke previous handler
	; old handler returns to the address immediately below	
dbgx86Handlers_task_exit_interrupt_handler_old_handler_ret_addr:

	; END actual interrupt handler work

	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control
	
	
; Our int3 handler.
; The purpose of this interrupt handler is to handle reaching a breakpoint.
;
; input:
;		none
; output:
;		none
dbgx86Handlers_breakpoint_interrupt_handler:
	mov word [cs:dbgx86HaltReturnDS], ds	; save
	mov word [cs:dbgx86HaltReturnES], es	; save
	mov word [cs:dbgx86HaltReturnFS], fs	; save
	mov word [cs:dbgx86HaltReturnGS], gs	; save
	mov word [cs:dbgx86HaltReturnSS], ss	; save
	mov word [cs:dbgx86HaltReturnAX], ax	; save
	mov word [cs:dbgx86HaltReturnBX], bx	; save
	mov word [cs:dbgx86HaltReturnCX], cx	; save
	mov word [cs:dbgx86HaltReturnDX], dx	; save
	
	mov word [cs:dbgx86HaltReturnSP], sp	; save
	add word [cs:dbgx86HaltReturnSP], 6		; 3 words on stack now (CS, IP, FL)
	
	mov word [cs:dbgx86HaltReturnBP], bp	; save
	mov word [cs:dbgx86HaltReturnSI], si	; save
	mov word [cs:dbgx86HaltReturnDI], di	; save
	
	push bp
	mov bp, sp
	add bp, 2
	mov word [cs:dbgx86HaltReturnIPPtrOff], bp	; save
	mov bp, word [ss:bp]
	mov word [cs:dbgx86HaltReturnIP], bp	; save
	
	mov bp, sp
	mov bp, word [ss:bp+4]
	mov word [cs:dbgx86HaltReturnCS], bp	; save
	
	mov bp, sp
	add bp, 6									; BP := ptr offset to flags
	mov word [cs:dbgx86HaltReturnFlagsPtrOff], bp	; save
	pop bp

	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	; BEGIN actual interrupt handler work
	
	int 9Ah											; AX := current task ID
	cmp ax, word [cs:dbgx86WatchedProgramTaskId]	; is it the watched program
	jne dbgx86Handlers_breakpoint_interrupt_handler_done
									; NOOP when some other task is active
	

	mov byte [cs:dbx86LastHaltType], DBGX86_HALT_TYPE_BREAKPOINT
	mov ax, word [cs:dbgx86HaltReturnIP]
	dec ax											; AX := int3 address
	mov word [cs:dbx86LastHaltBreakpointAddr], ax
		
	; we now modify return address to be one byte earlier, before int3
	mov bx, word [cs:dbgx86HaltReturnIPPtrOff]
							; BX := address on stack of return IP
	mov ax, word [ss:bx]
							; AX := return IP
							; (equal to address immediately after int3 )
	dec ax					; AX := address of int3
							; (equal to address of breakpoint)
	mov word [ss:bx], ax	; move return IP one back, to before int3
	
	; we now re-place the byte displaced by breakpoint's int3 back in its place
	push ax									; [1] save breakpoint offset
	call dbgx86Breakpoints_get_handle_by_address	; AX := handle
	; note that we don't check success/failure of looking up the breakpoint
	; because the breakpoint management and int3 bytes are assumed
	; to be synchronized
	call dbgx86Breakpoints_increment_seen_count
	call dbgx86Breakpoints_get_displaced_byte	; BL := displaced byte
	
	mov ds, word [cs:dbgx86BinarySeg]
	pop si									; [1] SI := breakpoint offset
	; here, DS:SI = pointer to int3 byte in program binary
	mov byte [ds:si], bl					; re-place displaced byte

	call dbgx86Handlers_show_ui_for_breakpoint
	
	cmp byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_TERMINATE
	je dbgx86Handlers_breakpoint_interrupt_handler_done

dbgx86Handlers_breakpoint_interrupt_handler__dont_terminate:
	; we now enable single step in the return flags, so it takes effect upon
	; return into watched program, and NOT here
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
							; BX := address on sack of return flags
	or word [ss:bx], FLAGS_TRAP_ENABLE

	; END actual interrupt handler work
dbgx86Handlers_breakpoint_interrupt_handler_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control
	

; Our int1 handler.
; The purpose of this interrupt handler is to handle a single step.
;
; input:
;		none
; output:
;		none
dbgx86Handlers_single_step_interrupt_handler:
	mov word [cs:dbgx86HaltReturnDS], ds	; save
	mov word [cs:dbgx86HaltReturnES], es	; save
	mov word [cs:dbgx86HaltReturnFS], fs	; save
	mov word [cs:dbgx86HaltReturnGS], gs	; save
	mov word [cs:dbgx86HaltReturnSS], ss	; save
	mov word [cs:dbgx86HaltReturnAX], ax	; save
	mov word [cs:dbgx86HaltReturnBX], bx	; save
	mov word [cs:dbgx86HaltReturnCX], cx	; save
	mov word [cs:dbgx86HaltReturnDX], dx	; save
	
	mov word [cs:dbgx86HaltReturnSP], sp	; save
	add word [cs:dbgx86HaltReturnSP], 6		; 3 words on stack now (CS, IP, FL)
	
	mov word [cs:dbgx86HaltReturnBP], bp	; save
	mov word [cs:dbgx86HaltReturnSI], si	; save
	mov word [cs:dbgx86HaltReturnDI], di	; save
	
	push bp
	mov bp, sp
	add bp, 2
	mov word [cs:dbgx86HaltReturnIPPtrOff], bp	; save
	mov bp, word [ss:bp]
	mov word [cs:dbgx86HaltReturnIP], bp	; save
	
	mov bp, sp
	mov bp, word [ss:bp+4]
	mov word [cs:dbgx86HaltReturnCS], bp	; save
	
	mov bp, sp
	add bp, 6									; BP := ptr offset to flags
	mov word [cs:dbgx86HaltReturnFlagsPtrOff], bp	; save
	pop bp

	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	; BEGIN actual interrupt handler work
	
	int 9Ah											; AX := current task ID
	cmp ax, word [cs:dbgx86WatchedProgramTaskId]	; is it the watched program
	jne dbgx86Handlers_single_step_interrupt_handler_done
									; NOOP when some other task is active
	
	cmp byte [cs:dbx86LastHaltType], DBGX86_HALT_TYPE_BREAKPOINT
	jne dbgx86Handlers_single_step_interrupt_handler__after_bk_check
	
	mov ax, word [cs:dbx86LastHaltBreakpointAddr]
	call dbgx86Breakpoints_get_handle_by_address	; AX := handle
	jc dbgx86Handlers_single_step_interrupt_handler__after_bk_check	; not found
	
	call dbgx86Breakpoints_get_type							; BL := type
	cmp bl, BK_TYPE_USER_SET
	je dbgx86Handlers_single_step_interrupt_handler__bk_is_user_set
dbgx86Handlers_single_step_interrupt_handler__bk_is_one_time:
	; delete breakpoint
	; here, AX = breakpoint handle
	; NOTE: the breakpoint handler has already re-placed the displaced byte,
	;       so we can simply delete the breakpoint here
	call dbgx86Breakpoints_delete
	
	jmp dbgx86Handlers_single_step_interrupt_handler__after_bk_check
	
dbgx86Handlers_single_step_interrupt_handler__bk_is_user_set:
	; place int3 back in at the address of the breakpoint we just saw
	; to effectively re-enable the breakpoint
	mov ds, word [cs:dbgx86BinarySeg]
	mov si, word [cs:dbx86LastHaltBreakpointAddr]
	mov byte [ds:si], 0CCh							; int3
	
dbgx86Handlers_single_step_interrupt_handler__after_bk_check:
	mov byte [cs:dbx86LastHaltType], DBGX86_HALT_TYPE_SINGLE_STEP

	cmp byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_CONTINUE
	jne dbgx86Handlers_single_step_interrupt_handler__after_last_action_continue
	; if last_user_action = continue
	
	; disable single step
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
							; BX := address on sack of return flags
	and word [ss:bx], FLAGS_TRAP_DISABLE
	; return
	jmp dbgx86Handlers_single_step_interrupt_handler_done
dbgx86Handlers_single_step_interrupt_handler__after_last_action_continue:	
	
	cmp byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_SINGLE_STEP
	jne dbgx86Handlers_single_step_interrupt_handler_done
	
	mov ax, word [cs:dbgx86HaltReturnIP]
	call dbgx86Breakpoints_get_handle_by_address	; AX := handle
	jnc dbgx86Handlers_single_step_interrupt_handler_done	; there's a breakpoint
dbgx86Handlers_single_step_interrupt_handler__after_next_instruction_is_breakpointed:

	call dbgx86Handlers_show_ui_for_single_step
	
	cmp byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_TERMINATE
	je dbgx86Handlers_single_step_interrupt_handler_done

dbgx86Handlers_single_step_interrupt_handler__dont_terminate:
	
	; END actual interrupt handler work
dbgx86Handlers_single_step_interrupt_handler_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control

	
; Shows the UI and acts according to user resume type.
; Specific to when the debugger was entered via a breakpoint.
;
; input:
;		none
; output:
;		none
dbgx86Handlers_show_ui_for_breakpoint:
	pusha
	push ds
	push es
	
	mov ax, word [cs:dbgx86HaltReturnIP]
	dec ax						; breakpoint highlights current instruction
	call dbgx86Ui_show_ui

dbgx86Handlers_show_ui_for_breakpoint___exit:
	cmp al, DBGX86_UI_USER_RESUME_TYPE_TERMINATE
	jne dbgx86Handlers_show_ui_for_breakpoint___singlestep
	; handle exit

	; insert call to int 95h at the beginning of the binary
	mov ds, word [cs:dbgx86BinarySeg]
	mov si, word [cs:dbgx86BinaryOff]
	mov byte [ds:si+0], 0CDh	; int ..
	mov byte [ds:si+1], 95h		; .. 95h
	
	; set return address to beginning of binary, so that next thing watched
	; program does is execute the int 95h we just inserted
	mov bx, word [cs:dbgx86HaltReturnIPPtrOff]
							; BX := address on stack of return IP
	mov word [ss:bx], si
	
	; disable single step to avoid possible interruptions
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
							; BX := address on stack of return flags
	and word [ss:bx], FLAGS_TRAP_DISABLE
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_TERMINATE
	
	jmp dbgx86Handlers_show_ui_for_breakpoint_done
dbgx86Handlers_show_ui_for_breakpoint___singlestep:
	cmp al, DBGX86_UI_USER_RESUME_TYPE_SINGLE_STEP
	jne dbgx86Handlers_show_ui_for_breakpoint___continue
	; handle single step
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_SINGLE_STEP
	
	jmp dbgx86Handlers_show_ui_for_breakpoint_done
dbgx86Handlers_show_ui_for_breakpoint___continue:
	cmp al, DBGX86_UI_USER_RESUME_TYPE_CONTINUE
	jne dbgx86Handlers_show_ui_for_breakpoint___stepover
	; handle continue
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_CONTINUE
	
	jmp dbgx86Handlers_show_ui_for_breakpoint_done
dbgx86Handlers_show_ui_for_breakpoint___stepover:
	; handle step over	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_SINGLE_STEP
	
	; check whether we can step over this
	mov ax, word [cs:dbx86LastHaltBreakpointAddr]
	call dbgx86Handlers_can_step_over	; BX := address after this instruction
	cmp ax, 0
	je dbgx86Handlers_show_ui_for_breakpoint_done	; can't step over this
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_CONTINUE
	
	mov ax, bx							; AX := address after this instruction
	call dbgx86Breakpoints_get_handle_by_address
	jnc dbgx86Handlers_show_ui_for_breakpoint_done	; a breakpoint is already 
													; on the step over 
													; destination so we're done
	; place a one-time breakpoint at step over destination
	mov ax, bx							; AX := address after this instruction
	call dbgx86Breakpoints_add_breakpoint_by_address	; BX := handle
	jc dbgx86Handlers_show_ui_for_breakpoint___stepover__force_single
		; couldn't place breakpoint, so we turn step over into a single step
	mov ax, bx									; AX := breakpoint handle
	call dbgx86Breakpoints_set_type_one_time	; make it one-time

	jmp dbgx86Handlers_show_ui_for_breakpoint_done
dbgx86Handlers_show_ui_for_breakpoint___stepover__force_single:
	; we couldn't place a one-time breakpoint for step over, so we single step
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_SINGLE_STEP
	jmp dbgx86Handlers_show_ui_for_breakpoint_done
	
dbgx86Handlers_show_ui_for_breakpoint_done:
	pop es
	pop ds
	popa
	ret


; Shows the UI and acts according to user resume type.
; Specific to when the debugger was entered via a single step.
;
; input:
;		none
; output:
;		none
dbgx86Handlers_show_ui_for_single_step:
	pusha
	push ds
	push es
	
	mov ax, word [cs:dbgx86HaltReturnIP]
								; single step highlights next instruction
	call dbgx86Ui_show_ui

dbgx86Handlers_show_ui_for_single_step___exit:
	cmp al, DBGX86_UI_USER_RESUME_TYPE_TERMINATE
	jne dbgx86Handlers_show_ui_for_single_step___singlestep
	; handle exit
	
	; insert call to int 95h at the beginning of the binary
	mov ds, word [cs:dbgx86BinarySeg]
	mov si, word [cs:dbgx86BinaryOff]
	mov byte [ds:si+0], 0CDh	; int ..
	mov byte [ds:si+1], 95h		; .. 95h
	
	; set return address to beginning of binary, so that next thing watched
	; program does is execute the int 95h we just inserted
	mov bx, word [cs:dbgx86HaltReturnIPPtrOff]
							; BX := address on stack of return IP
	mov word [ss:bx], si
	
	; disable single step to avoid possible interruptions
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
							; BX := address on sack of return flags
	and word [ss:bx], FLAGS_TRAP_DISABLE
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_TERMINATE
	
	jmp dbgx86Handlers_show_ui_for_single_step_done
dbgx86Handlers_show_ui_for_single_step___singlestep:
	cmp al, DBGX86_UI_USER_RESUME_TYPE_SINGLE_STEP
	jne dbgx86Handlers_show_ui_for_single_step___continue
	; handle single step
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_SINGLE_STEP
	
	jmp dbgx86Handlers_show_ui_for_single_step_done
dbgx86Handlers_show_ui_for_single_step___continue:
	cmp al, DBGX86_UI_USER_RESUME_TYPE_CONTINUE
	jne dbgx86Handlers_show_ui_for_single_step___stepover
	; handle continue
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_CONTINUE
	
	; disable single step
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
							; BX := address on sack of return flags
	and word [ss:bx], FLAGS_TRAP_DISABLE
	
	jmp dbgx86Handlers_show_ui_for_single_step_done
dbgx86Handlers_show_ui_for_single_step___stepover:
	; handle step over	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_SINGLE_STEP
	
	; check whether we can step over next instruction
	mov ax, word [cs:dbgx86HaltReturnIP]
	call dbgx86Handlers_can_step_over	; BX := address after next instruction
	cmp ax, 0
	je dbgx86Handlers_show_ui_for_single_step_done	; can't step over next
	push bx						; [1] save address after next instruction
	
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_CONTINUE
	
	; disable single step
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
							; BX := address on stack of return flags
	and word [ss:bx], FLAGS_TRAP_DISABLE
	
	pop bx							; [1] BX := address after next instruction
	mov ax, bx						; AX := address after next instruction
	call dbgx86Breakpoints_get_handle_by_address
	jnc dbgx86Handlers_show_ui_for_single_step_done	; a breakpoint is already 
													; on the step over 
													; destination so we're done
	; place a one-time breakpoint at step over destination
	mov ax, bx							; AX := address after next instruction
	call dbgx86Breakpoints_add_breakpoint_by_address	; BX := handle
	jc dbgx86Handlers_show_ui_for_single_step___stepover__force_single
		; couldn't place breakpoint, so we turn step over into a single step
	mov ax, bx									; AX := breakpoint handle
	call dbgx86Breakpoints_set_type_one_time	; make it one-time

	jmp dbgx86Handlers_show_ui_for_single_step_done
dbgx86Handlers_show_ui_for_single_step___stepover__force_single:
	; we couldn't place a one-time breakpoint for step over, so we single step
	mov byte [cs:dbx86LastUserAction], DBGX86_USER_ACTION_SINGLE_STEP
	
	; enable single stepping
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
							; BX := address on sack of return flags
	or word [ss:bx], FLAGS_TRAP_ENABLE
	
	jmp dbgx86Handlers_show_ui_for_single_step_done
	
dbgx86Handlers_show_ui_for_single_step_done:
	pop es
	pop ds
	popa
	ret
	
	
; Checks whether the debugger can step over 
;
; input:
;		AX - address of instruction over which we intend to step
; output:
;		AX - 0 when debugger cannot step over, other value otherwise
;		BX - address immediately after specified instruction, ONLY when
;			 debugger CAN step over
dbgx86Handlers_can_step_over:
	push ds
	
	mov bx, ax
	mov ax, word [cs:dbgx86BinarySeg]
	mov ds, ax								; DS:BX := pointer to instruction
	
	cmp byte [ds:bx], 0E8h					; is instruction "CALL"?
	jne dbgx86Handlers_can_step_over_no
	
	cmp bx, 0FFFDh
	jae dbgx86Handlers_can_step_over_no		; not enough room in segment 
											; for another instruction
	; here, DS:BX = pointer to instruction
	mov ax, word [cs:dbgx86BinaryOff]	; AX := first address of binary
	add ax, word [cs:dbgx86BinarySize]	; AX := first address after binary end
	add bx, 3							; DS:BX = pointer to right after CALL
	cmp bx, ax							; is DS:BX after binary end?
	jae dbgx86Handlers_can_step_over_no	; it is, so we have nothing after

dbgx86Handlers_can_step_over_yes:
	mov ax, 1
	jmp dbgx86Handlers_can_step_over_done
dbgx86Handlers_can_step_over_no:
	mov ax, 0
dbgx86Handlers_can_step_over_done:	
	pop ds
	ret
	

%endif
