;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains Snowdrop OS's BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_
%define _COMMON_BASIC_


; Prepares the BASIC interpreter for operation.
; This should be called only ONCE per program, as the overall first
; BASIC call.
;
; NOTE: Requires dynamic memory to have been initialized
;
; input:
;	 DS:SI - pointer to program text, zero-terminated
; output:
;		AX - 0 when an error occurred, other value otherwise
basic_prepare:
	pusha
	push ds
	push es
	
	call common_memory_stats
	cmp ax, 0
	je basic_prepare_no_dynamic_memory

	mov byte [cs:basicInterpreterState], BASIC_STATE_RESUMABLE
									; initial state is resumable by default
	push ds
	pop word [cs:basicProgramTextSeg]
	push si
	pop word [cs:basicProgramTextOff]		; save pointer to program text
	
	call private_basic_prelookup_gui_labels		; cache GUI labels
	
	mov word [cs:basicResumeNearPointer], si	; we're resuming from beginning
	
	mov byte [cs:basicGuiStartRequested], 0
	mov word [cs:basicCurrentRadioGroupId], 0	; default radio group ID
	
	call basicNumericVars_clear
	call basicStringVars_clear
	
	call basicExecution_initialize_program
	
	mov byte [cs:basicMoreTokensAvailable], 1
	mov word [cs:basicCurrentLineNumber], 1
	mov word [cs:basicCurrentInstructionNumber], 0

	mov word [cs:basicInterpretationEndMessagePtr], basicMessageEmpty
	
	int 0C1h					; clear any sounds
	
	call basic_serial_initialize
	
	int 0BBh					; AX := keyboard driver mode
	mov word [cs:basicOldKeyboardDriverMode], ax	; save it
	call basic_set_keyboard_mode_non_blocking
						; BASIC only switches to blocking mode when executing
						; an instruction which specifically blocks waiting
						; for user input
	
basic_prepare_success:
	pop es
	pop ds
	popa
	mov ax, 1
	ret
	
basic_prepare_no_dynamic_memory:
	push cs
	pop ds
	mov si, basicFatalPrepareErrorNoMem
	int 80h
	mov ah, 0
	int 16h
basic_prepare_fail:
	pop es
	pop ds
	popa
	mov ax, 0
	ret


; Returns the current interpreter state.
; Meant to be called after basic_interpret returns.
;
; input:
;		none
; output:
;		AL - interpreter state
basic_get_interpreter_state:
	mov al, byte [cs:basicInterpreterState]
	ret


; Notifies the BASIC interpreter that it will soon have to shutdown because
; the GUI framework has been shut down.
;
; input:
;		none
; output:
;		none
basic_preshutdown_due_to_gui_exit:
	pusha
	
	; did the GUI exit because of an error in BASIC
	cmp byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_ERROR
	je basic_preshutdown_due_to_gui_exit_return	; there was an error, so
												; line info and message
												; have already been populated
basic_preshutdown_due_to_gui_exit_no_error:	
	; we exited from outside the BASIC program, so line and instruction
	; values are undefined
	mov word [cs:basicCurrentLineNumber], 0
	mov word [cs:basicCurrentInstructionNumber], 0
	
	; since GUI exited from within, the last BASIC state is
	; resumable-success, so we indicate that we've actually completed
	; successfully
	mov byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_SUCCESS
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiExited
	
basic_preshutdown_due_to_gui_exit_return:
	popa
	ret


; Looks up all GUI callback labels and stores lookup result pointers.
; This is done to considerably speed up label lookup.
;
; input:
;	 DS:SI - pointer to program text string, zero-terminated
; output:
;		none
private_basic_prelookup_gui_labels:
	pusha
	push ds
	push es
	
	; look up labels one by one
	mov dx, cs
	
	mov bx, basicCallbackLabelButtonClick		; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelButtonClick_found], ax
	mov word [cs:basicGuiCallbackLabelButtonClick_ptr], di
	
	mov bx, basicCallbackLabelCheckboxChange	; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelCheckboxChange_found], ax
	mov word [cs:basicGuiCallbackLabelCheckboxChange_ptr], di
	
	mov bx, basicCallbackLabelRadioChange		; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelRadioChange_found], ax
	mov word [cs:basicGuiCallbackLabelRadioChange_ptr], di
	
	mov bx, basicCallbackLabelImageLeftClick	; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelImageLeftClick_found], ax
	mov word [cs:basicGuiCallbackLabelImageLeftClick_ptr], di
	
	mov bx, basicCallbackLabelImageRightClick	; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelImageRightClick_found], ax
	mov word [cs:basicGuiCallbackLabelImageRightClick_ptr], di
	
	mov bx, basicCallbackLabelImageSelectedChange	; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelImageSelectedChange_found], ax
	mov word [cs:basicGuiCallbackLabelImageSelectedChange_ptr], di
	
	mov bx, basicCallbackLabelTimerTick	; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelTimerTick_found], ax
	mov word [cs:basicGuiCallbackLabelTimerTick_ptr], di

	mov bx, basicCallbackLabelOnRefresh	; DX:BX := pointer to label
	call basicExecution_resolve_label	; AX := 0 when not found, DI := pointer
	mov word [cs:basicGuiCallbackLabelOnRefresh_found], ax
	mov word [cs:basicGuiCallbackLabelOnRefresh_ptr], di

	pop es
	pop ds
	popa
	ret
	
	
; Sets the resume point (to be used during next interpretation start)
; to immediately after the specified label
;
; input:
;	 DX:BX - pointer to label name, zero-terminated
; output:
;		AX - 0 when label was not found, other value otherwise
basic_set_resume_label:
	pusha
	push ds
	
	push word [cs:basicProgramTextSeg]
	pop ds
	mov si, word [cs:basicProgramTextOff]	; DS:SI := pointer to program text
	
	call basicExecution_resolve_label	; AX := 0 when label was not found
										; DI := near pointer to right after the
										;       first occurrence of label
	cmp ax, 0
	je basic_set_resume_label_not_found	; error
	
	call basic_set_resume_pointer
basic_set_resume_label_success:
	pop ds
	popa
	mov ax, 1
	ret
basic_set_resume_label_not_found:
	pop ds
	popa
	mov ax, 0
	ret

	
; Sets the resume point (to be used during next interpretation start)
; to the specified near pointer
;
; input:
;		DI - near pointer to resume point in the program text
; output:
;		none
basic_set_resume_pointer:
	mov word [cs:basicResumeNearPointer], di
	ret
	

; Prepares the BASIC interpreter for a single interpretation "session".
; This should be called every time a new interpretation starts.
;
; input:
;		none
; output:
;		none
basic_init_per_interpretation:
	pusha
	
	mov byte [cs:basicMustHaltAndYield], 0		; we don't yet need to yield
	call basicInterpreter_initialize
	call basicExecution_initialize_interpretation
	
	popa
	ret
	

; Called when BASIC has finished the current interpretation.
; Note that the program may not have yet finished.
;
; input:
;		none
; output:
;		none
basic_shutdown_per_interpretation:
	pusha
	
	popa
	ret	


; The entry point into the BASIC interpreter execution.
; Consumers invoke this to begin or resume interpretation, AFTER
; the interpreter has been prepared.
;
; input:
;		none
; output:
;		none
basic_interpret:
	cmp byte [cs:basicInterpreterState], BASIC_STATE_RESUMABLE
	je basic_interpret_begin
	ret						; we're not in a resumable state, so we do nothing
basic_interpret_begin:	
	pushf
	pusha
	push ds
	push es

	push word [cs:basicProgramTextSeg]
	pop ds
	push word [cs:basicResumeNearPointer]
	pop si										; DS:SI := resume point
	
	cld
	push cs
	pop es
	
	call basic_init_per_interpretation
	
	; pointer DS:SI advances as tokens are read
basic_interpret_next_token:
	; has the user requested a break?
	call basic_is_break_requested			; AX := 0 when no break requested
	cmp ax, 0
	jne basic_interpret_break				; user requested break
	
	; user did not request a break
	mov byte [cs:basicMoreTokensAvailable], 1	; assume we still have tokens
	
	; read in a token from the program text
	mov di, basicCurrentToken				; here, ES = CS from above
	call basic_read_token					; current := next token
	
	cmp ax, TOKEN_PARSE_ERROR				; was there an error?
	je basic_interpret_halt_try_error		; yes
	
	mov word [cs:basicProgramTextPointerBeforeProcessing], si

	cmp ax, TOKEN_PARSE_NONE_LEFT			; any token read?
	jne basic_interpret_process				; yes, proceed normally
	; no more tokens
	mov byte [cs:basicMoreTokensAvailable], 0	; there are no further tokens..
	
	; now check whether the interpreter is in the middle of an instruction
	call basicInterpreter_is_within_instruction	; AX := 0 when not within inst.
	
	cmp ax, 0
	je basic_interpret_no_more_tokens		; not within instruction, so there
											; is nothing further to interpret
	; we are in the middle of an instruction, so insert an artificial
	; instruction delimiter to ensure that the interpreter executes it
	mov byte [cs:basicCurrentToken], BASIC_CHAR_INSTRUCTION_DELIMITER
	mov byte [cs:basicCurrentToken+1], 0	; ..but we pretend we read an
											; additional token, so
											; the last instruction is
											; guaranteed to be executed
basic_interpret_process:
	; process the token we've just read
	call basicInterpreter_process			; this call may modify pointer 
											; DS:SI to follow a branch, etc.
	
	cmp ax, 0								; was there an error?
	je basic_interpret_halt					; yes, so we halt
	
	cmp byte [cs:basicMoreTokensAvailable], 0	; are there more tokens?
	je basic_interpret_no_more_tokens		; no, we're done
	jmp basic_interpret_next_token			; yes, so read the next one
basic_interpret_break:
	; user aborted interpretation
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUserBreakRequest
	call basic_set_line_and_instruction_number
	mov byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_SUCCESS
	jmp basic_interpret_exit		; ((1)) we're halting due to user break req
	
basic_interpret_halt:
	; the interpretation must halt, and we determine mode below
	call basic_set_line_and_instruction_number

basic_interpret_halt_try_error:	
	cmp byte [cs:basicHaltingDueToNonError], 0
	jne basic_interpret_halt_try_yield
	; it's an error
	mov byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_ERROR
	jmp basic_interpret_exit			; ((2)) we're halting due to an error

basic_interpret_halt_try_yield:
	cmp byte [cs:basicMustHaltAndYield], 0
	je basic_interpret_halt_non_error
	mov byte [cs:basicInterpreterState], BASIC_STATE_RESUMABLE
	mov word [cs:basicResumeNearPointer], si	; save resume point
	jmp basic_interpret_exit		; ((3)) we're halting due to yield

basic_interpret_halt_non_error:
	mov byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_SUCCESS
	jmp basic_interpret_exit		; ((4)) we're halting due to a non-error

basic_interpret_no_more_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageStatusOk
	cmp word [cs:basicProgramTextPointerBeforeProcessing], si
											; if current program text pointer
											; changed, it's because processing
											; the last token of program
											; has just caused a branch, so 
											; we're not at the end anymore
	jne basic_interpret_next_token			; we're no longer at the end
	
	; we have no more tokens to parse, so the interpretation is over
	call basic_set_line_and_instruction_number
	mov byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_SUCCESS
	jmp basic_interpret_exit		; ((5)) we're halting due to program end
basic_interpret_exit:
	call basic_shutdown_per_interpretation

	pop es
	pop ds
	popa
	popf
	ret


; Shuts down the interpreter.
; Meant to be called once program execution can no longer continue, because:
; - the interpreter has reached a non-resumable state, or
; - the invoking application has simply chosen to terminate execution
;
; input:
;		none
; output:
;		none	
basic_shutdown:
	pusha
	
	call basic_serial_shutdown
	call basicStringVars_shutdown
	int 0C1h					; clear any sounds
	
	mov ax, word [cs:basicOldKeyboardDriverMode]
	int 0BCh					; restore keyboard driver mode
	
	popa
	ret
	
	
; Displays a tag that precedes BASIC interpreter messages
;
; input:
;		none
; output:
;		none
basic_display_BASIC_tag:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, basicMessagePrefix1
	int 97h
	
	mov dx, 0
	mov ax, word [cs:basicCurrentLineNumber]
	mov si, basicItoaBuffer
	mov bl, 3						; formatting option
	int 0A2h
	int 97h
	
	mov si, basicMessagePrefix2
	int 97h
	
	mov dx, 0
	mov ax, word [cs:basicCurrentInstructionNumber]
	mov si, basicItoaBuffer
	mov bl, 3						; formatting option
	int 0A2h
	int 97h	
	
	mov si, basicMessagePrefix3
	int 97h

	pop ds
	popa
	ret
	

; Called by consumer usually after the interpreter returns and is 
; in a non-resumable state.
; Must be called BEFORE basic_shutdown
; Displays a message for the user at the end of interpretation.
; It alerts the user if there was an error.
;
; input:
;		none
; output:
;		none	
basic_display_status:
	pusha
	push ds
	
	cmp byte [cs:basicInterpreterState], BASIC_STATE_RESUMABLE
	je basic_display_status_done

	push cs
	pop ds
	mov si, basicMessageNewline
	int 97h

	call basic_display_BASIC_tag
	
	; was there an error?
	cmp byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_ERROR
	jne basic_display_status_status	; no
	
	mov si, basicMessageStatusError	; yes
	int 97h
basic_display_status_status:
	
	mov si, word [cs:basicInterpretationEndMessagePtr]
	int 97h

	; display details pertaining to the error, if applicable
	; was there an error?
	cmp byte [cs:basicInterpreterState], BASIC_STATE_NONRESUMABLE_ERROR
	jne basic_display_status_after_error_details	; no
	; there was an error, so we show error details
	
	; display last seen token
	mov si, basicMessageNewline
	int 97h
	call basic_display_BASIC_tag
	mov si, basicDebugMsgLastTokenMessage
	int 97h
	mov si, basicDebugMsgTokenQuote
	int 97h
	mov si, basicCurrentToken
	int 97h
	mov si, basicDebugMsgTokenQuote
	int 97h
	
	; display last seen instruction
	mov si, basicMessageNewline
	int 97h
	call basic_display_BASIC_tag
	mov si, basicDebugMsgLastInstructionMessage
	int 97h
	call basic_display_last_parsed_instruction
	
basic_display_status_after_error_details:
basic_display_status_done:
	pop ds
	popa
	ret
	

; Configures driver for blocking key reads, to support instructions which
; block waiting for the user to press keys and input strings
;
; input:
;		none
; output:
;		none	
basic_set_keyboard_mode_blocking:
	pusha
	mov ax, 0					; mode
	int 0BCh					; set keyboard driver mode
	popa
	ret


; Configures driver for non-blocking key reads, to support instructions
; which allow non-blocking checking of key status
;
; input:
;		none
; output:
;		none	
basic_set_keyboard_mode_non_blocking:
	pusha
	mov ax, 1					; driver mode
	int 0BCh					; set it
	popa
	ret
	

; Reads the next BASIC token
;
; input:
;	 DS:SI - pointer to string, zero-terminated
;	 ES:DI - pointer to where token will be stored, zero-terminated
; output:
;	 DS:SI - pointer to immediately after token
;		AX - 0 when there were no more tokens to read
;			 1 when a token was read (success)
;			 2 when there was an error
basic_read_token:
	pushf
	push bx
	push cx
	push dx
	push di
	
	cld
	
	mov ax, TOKEN_PARSE_NONE_LEFT		; "no token found"
basic_read_token_advance_to_token_start_loop:
	cmp byte [ds:si], 0			; are we at the end of input?
	je basic_read_token_done	; yes

	call basic_check_ignored_character	; are we on an ignored character?
	jnc basic_read_token_start_found	; no, so we have found the token start
	
	inc si						; next character
	jmp basic_read_token_advance_to_token_start_loop

basic_read_token_start_found:
	; DS:SI now points to the first character of the token we're returning
	mov ax, TOKEN_PARSE_PARSED	; "token found"
	mov bx, 0					; "not a string literal"
	mov cx, 0					; token length counter
	
	cmp byte [ds:si], BASIC_CHAR_STRING_DELIMITER	; is it a string literal?
	jne basic_read_token_copy	; no
	mov bx, 1					; "a string literal"
basic_read_token_copy:
	cmp cx, BASIC_TOKEN_MAX_LENGTH	; have we already accumulated as many
	je basic_read_token_overflow	; characters as the max token length?
	; we have not yet filled the token buffer, so we accumulate this character
	movsb						; copy it into the output buffer
								; and advance input pointer

	inc cx						; token length counter
	
	cmp byte [ds:si-1], BASIC_CHAR_LINE_ENDING	; is this token a new line?
	je basic_read_token_done	; yes
	
	cmp byte [ds:si], 0			; are we at the end of input?
	je basic_read_token_done	; yes
	
	cmp bx, 1					; is this token a string literal?
	jne basic_read_token_copy_not_string_literal	; no
	
	; we're inside a string literal
	cmp byte [ds:si-1], BASIC_CHAR_STRING_DELIMITER	; did we just accumulate
													; the string delimiter?
	jne basic_read_token_copy	; no, keep accumulating
	; we just accumulated the delimiter
	; we must check if it's the opening string delimiter, or 
	; the closing string delimiter
	cmp cx, 1					; are we past the first character of the token?
	ja basic_read_token_done	; yes, so this was the closing delimiter
	jmp basic_read_token_copy	; no, so we accumulate next token character

basic_read_token_copy_not_string_literal:	
	; we're not inside a string literal
	call basic_check_ignored_character
	jc basic_read_token_done			; we stop before an ignored character
	
	cmp byte [ds:si], BASIC_CHAR_LINE_ENDING
	je basic_read_token_done			; we stop before a newline
	
	call basic_check_stop_character		; are we before a stop character?
	jc basic_read_token_done			; yes
	push si
	dec si
	call basic_check_stop_character		; are we after a stop character?
	pop si
	jc basic_read_token_done			; yes
	
	cmp byte [ds:si], BASIC_CHAR_STRING_DELIMITER
	je basic_read_token_done			; we stop before a string delimiter
										; (since we're not inside a 
										; string literal)
	
	jmp basic_read_token_copy			; next token character

basic_read_token_overflow:
	; the token was too long, so we should halt interpretation with an error
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageTokenTooLong
	mov ax, TOKEN_PARSE_ERROR			; "error"
	jmp basic_read_token_exit
basic_read_token_done:
	mov byte [es:di], 0					; add terminator
basic_read_token_exit:	
	pop di
	pop dx
	pop cx
	pop bx
	popf
	ret


; Checks whether the user has requested a break in the program
;
; input:
;		none
; output:
;		AX - 0 when user did not request break, other value otherwise
basic_is_break_requested:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	mov bl, COMMON_SCAN_CODE_Q
	int 0BAh
	cmp al, 0						; is it pressed?
	je basic_is_break_requested_no	; no
	
	mov bl, COMMON_SCAN_CODE_LEFT_CONTROL
	int 0BAh
	cmp al, 0						; is it pressed?
	je basic_is_break_requested_no	; no
	
	; it is, so user requested a break
basic_is_break_requested_yes:
	mov ax, 1
	jmp basic_is_break_requested_done
basic_is_break_requested_no:
	mov ax, 0
basic_is_break_requested_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret
	
	
; Populates line number and instruction number variables
;
; input:
;	 	SI - near pointer to current position within program
; output:
;		none
basic_set_line_and_instruction_number:
	pusha
	push ds
	
	mov bx, si								; BX := near pointer to position
	
	push word [cs:basicProgramTextSeg]
	pop ds
	mov si, word [cs:basicProgramTextOff]	; DS:SI := pointer to program text
	
	call basic_get_position					; CX := line number
											; DX := instruction number
											
	mov word [cs:basicCurrentLineNumber], cx
	mov word [cs:basicCurrentInstructionNumber], dx
	
	pop ds
	popa
	ret


; Prints the tokens of the last parsed instruction
;
; input:
;	 	none
; output:
;		none	
basic_display_last_parsed_instruction:
	pusha
	push ds
	
	push cs
	pop ds

	mov si, basicDebugMsgTokenQuote
	int 97h
	mov si, basicCurrentKeyword
	int 97h
	mov si, basicDebugMsgTokenQuote
	int 97h
	
	mov si, basicDebugMsgBlank
	int 97h
	; iterate over all instruction fragments
	mov bl, 0								; instruction fragment index
basic_display_last_parsed_instruction_fragments:
	cmp bl, byte [cs:basicCurrentInstTokenCount]
	jae basic_display_last_parsed_instruction_fragments_done

	mov si, basicDebugMsgTokenQuote
	int 97h
	
	call basicInterpreter_get_instruction_token_near_ptr
	mov si, di				; DI := pointer to instruction token string								
	int 97h
	
	mov si, basicDebugMsgTokenQuote
	int 97h
	
	mov si, basicDebugMsgBlank
	int 97h
	
	inc bl					; next instruction fragment
	jmp basic_display_last_parsed_instruction_fragments
basic_display_last_parsed_instruction_fragments_done:
	pop ds
	popa
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; includes region
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
; configure CALL stack
%ifndef _COMMON_STACK_CONF_
%define _COMMON_STACK_CONF_
STACK_LENGTH equ 64						; size in words
%endif
%include "common\stack.asm"

%ifndef _COMMON_SPRITES_LIMITS_
%define _COMMON_SPRITES_LIMITS_
COMMON_SPRITES_SPRITE_MAX_SIZE equ 8	; override sprite library defaults
COMMON_SPRITES_MAX_SPRITES equ 1		; to values more suitable for me
%endif
%ifndef _COMMON_GUI_CONF_COMPONENT_LIMITS_
%define _COMMON_GUI_CONF_COMPONENT_LIMITS_
GUI_RADIO_LIMIT 		equ 12	; maximum number of radio available
GUI_IMAGES_LIMIT 		equ 12	; maximum number of images available
GUI_CHECKBOXES_LIMIT 	equ 12	; maximum number of checkboxes available
GUI_BUTTONS_LIMIT 		equ 12	; maximum number of buttons available
%endif
%include "common\vga640\gui\gui.asm"

%include "common\text.asm"
%include "common\colours.asm"
%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\string.asm"
%include "common\screen.asm"
%include "common\queue.asm"
%include "common\memory.asm"

%include "common\basic\basicgui.asm"
%include "common\basic\basicdef.asm"
%include "common\basic\basicvrn.asm"
%include "common\basic\basicvrs.asm"
%include "common\basic\basicval.asm"
%include "common\basic\basicint.asm"
%include "common\basic\basicutl.asm"
%include "common\basic\basicexe.asm"
%include "common\basic\basicevl.asm"
%include "common\basic\basicsrl.asm"


%endif
