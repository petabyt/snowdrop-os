;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains highest-level functionality for Snowdrop OS's debugger.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DBGX86_
%define _COMMON_DBGX86_

dbgx86OriginNotFoundMessage:	db 'Origin not found', 0
dbgx86ProgramEmptyMessage:		db 'Program must be at least 3 bytes long and must call int 95h to exit', 0
dbgx86BadOffsetMessage:			db 'At this time, the debugger only supports binaries loaded at offset 0', 0
dbgx86OriginOffsetMismatchMessage:	db 'Program origin must match binary offset', 0
dbgx86ProgramExitedMessage:		db 'Watched program exited from offset ', 0
dbgx86Newline:					db 13, 10, '[DBG] ', 0

dbgx86BinarySize:		dw 0
dbgx86BinarySeg:		dw 0
dbgx86BinaryOff:		dw 0
dbgx86ListingSeg:		dw 0
dbgx86ListingOff:		dw 0

dbgx86BinarySegmentDeallocated:		db 0
dbgx86ProgramExitOffset:	dw 99h	; stores the offset of the int 95h which
									; caused the watched program to exit
									
dbgx86WatchedProgramTaskId:	dw 99	; ID of task created for watched program
dbgx86DebuggerTaskId:		dw 99	; ID of debugger task

dbgx86MustCleanupAndExit:	db 0


; Runs the debugger.
; This is the highest-level debugger routine, meant to be invoked by consumers
;
; NOTE: deallocates program binary segment upon returning
;
; input:
;	 DS:SI - pointer to program listing, zero-terminated
;	 ES:DI - pointer to program binary, zero-terminated
;            NOTE: the segment is deallocated upon returning
;		CX - program binary size
; output:
;		none
dbgx86_run:
	pusha
	push ds
	push es

	mov byte [cs:dbgx86BinarySegmentDeallocated], 0
	
	; store pointers
	mov word [cs:dbgx86BinarySeg], es
	mov word [cs:dbgx86BinaryOff], di
	mov word [cs:dbgx86ListingSeg], ds
	mov word [cs:dbgx86ListingOff], si
	
	cmp di, 0
	jne dbgx86_run_bad_offset
	
	cmp cx, 3								; need at least one int 95h
	jb dbgx86_run_program_empty
	mov word [cs:dbgx86BinarySize], cx
	
	call dbgx86Listing_get_origin			; BX := origin offset
	cmp ax, 0
	je dbgx86_run_origin_not_found
	
	cmp word [cs:dbgx86BinaryOff], bx		; enforce origin = offset
	jne dbgx86_run_origin_offset_mismatch
	
	call dbgx86_main

	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	int 0A0h					; clear screen
	
	mov si, dbgx86ProgramExitedMessage
	call dbgx86_print_builtin
	mov ax, word [cs:dbgx86ProgramExitOffset]
	call common_hex_print_word
	
	jmp dbgx86_run_done
	
dbgx86_run_origin_offset_mismatch:
	mov si, dbgx86OriginOffsetMismatchMessage
	call dbgx86_print_builtin
	jmp dbgx86_run_done
	
dbgx86_run_origin_not_found:
	mov si, dbgx86OriginNotFoundMessage
	call dbgx86_print_builtin
	jmp dbgx86_run_done
	
dbgx86_run_program_empty:
	mov si, dbgx86ProgramEmptyMessage
	call dbgx86_print_builtin
	jmp dbgx86_run_done
	
dbgx86_run_bad_offset:
	mov si, dbgx86BadOffsetMessage
	call dbgx86_print_builtin
	jmp dbgx86_run_done
	
dbgx86_run_done:
	cmp byte [cs:dbgx86BinarySegmentDeallocated], 0
	jne dbgx86_run_exit
	; the binary segment hasn't been deallocated, probably because
	; of an error
	mov bx, word [cs:dbgx86BinarySeg]
	int 92h									; deallocate

dbgx86_run_exit:	
	pop es
	pop ds
	popa
	ret

	
; Runs the debugger assuming argument validation has occurred and 
; pertinent pointers have been stored.
; Program is guaranteed to have at least one byte.
;
; input:
;		none
; output:
;		none
dbgx86_main:
	pusha
	push ds
	push es
	
	call dbgx86Breakpoints_clear
			
	int 9Ah						; AX := current task ID
	mov word [cs:dbgx86DebuggerTaskId], ax
	
	mov bx, word [cs:dbgx86BinarySeg]
	int 93h						; schedule the new task at BX:0000
								; AX := task ID
	mov word [cs:dbgx86WatchedProgramTaskId], ax
	int 96h						; make display of new task active
	
	; add a one-time breakpoint on the first instruction, to guarantee that
	; the debugger gets control at least once during execution of the watched
	; program
	mov ax, word [cs:dbgx86BinaryOff]
	call dbgx86Breakpoints_add_breakpoint_by_address	; BX := handle

	mov ax, bx													; AX := handle
	call dbgx86Breakpoints_set_type_one_time
	
	call dbgx86Watch_initialize
	call dbgx86Handlers_initialize
	call dbgx86Handlers_register_interrrupt_handlers
	
dbgx86_main_await_completion:
	; we now continue to yield until we detect that we're done
	
	; the variable that shows us whether that has happened is changed
	; by our int 95h ("terminate") handler
	int 94h											; yield

	cmp byte [cs:dbgx86MustCleanupAndExit], 0		; has watched task exited?
	je dbgx86_main_await_completion					; no, we're not done yet
	
	call dbgx86Handlers_restore_interrupt_handlers

	pop es
	pop ds
	popa
	ret

	
; Prints a built-in debugger message
;
; input:
;		SI - near pointer to message, zero-terminated
; output:
;		none
dbgx86_print_builtin:
	pusha
	push ds
	
	push cs
	pop ds
	
	push si
	mov si, dbgx86Newline
	int 97h
	pop si
	int 97h
	
	pop ds
	popa
	ret
	

%include "common\debugger\dbgx86bk.asm"
%include "common\debugger\dbgx86hn.asm"
%include "common\debugger\dbgx86ls.asm"
%include "common\debugger\dbgx86ut.asm"
%include "common\debugger\dbgx86ui.asm"
%include "common\debugger\dbgx86wa.asm"

%include "common\memviewh.asm"
%include "common\string.asm"
%include "common\screen.asm"
%include "common\scancode.asm"
%include "common\textboxh.asm"
%include "common\screenh.asm"
%include "common\colours.asm"
%include "common\hex.asm"
%include "common\viewtxth.asm"
%include "common\input.asm"

%endif
