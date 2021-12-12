;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains the entry points into Snowdrop OS's x86 assembler.
;
; The assembler is made up of:
;     - a core, which can handle byte code emission, constants, addresses,
;       defining bytes and words; it is mostly processor-independent
;     - processor-specific opcode handling code
;
; The idea is that subsequent assemblers (targeting other processors) can be
; adapted easily by just keeping the core, and then adding in processor-
; specific opcodes.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_
%define _COMMON_ASM_


; Prepares the assembler for operation.
; This should be called only ONCE per program, as the overall first
; ASM call.
;
; input:
;	 DS:SI - pointer to program text, zero-terminated
;	 ES:DI - pointer to output buffer, where result will be stored
; output:
;		none
asm_prepare:
	pusha
	push ds
	push es

	mov byte [cs:asmPass], ASM_PASS_1
	call asmEmit_initialize_once
	call asmDisplay_initialize_once
	call asmList_initialize_once
	
	push ds
	pop word [cs:asmProgramTextSeg]
	push si
	pop word [cs:asmProgramTextOff]		; save pointer to program text

	push es
	pop word [cs:asmOutputBufferSeg]
	push di
	pop word [cs:asmOutputBufferOff]		; save pointer to output buffer

	call asmNumericVars_clear
	
	mov byte [cs:asmMoreTokensAvailable], 1
	mov word [cs:asmCurrentLineNumber], 1
	mov word [cs:asmCurrentInstructionNumber], 0

	mov word [cs:asmInterpretationEndMessagePtr], asmMessageEmpty
		
	pop es
	pop ds
	popa
	ret


; A wrapper which handles all initialization and execution calls
;
; input:
;	 DS:SI - pointer to program text, zero-terminated
;	 ES:DI - pointer to output buffer, where result will be stored
; output:
;		AX - 0 when run was not successful, other value otherwise
;		CX - count of bytes written to output buffer, when successful
asm_run:
	pusha	
	call asm_prepare
	
	; pass 0: resolve pure CONSTs
	mov byte [cs:asmPass], ASM_PASS_0
	call asm_interpret					; interpret program text
	
	cmp byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_ERROR
	je asm_run_error					; any errors?

	; pass 1: absolute addresses of labels are resolved
	;         during pass 1, all labels resolve to a dummy 16-bit value
	mov byte [cs:asmPass], ASM_PASS_1
	call asm_interpret					; interpret program text
	
	cmp byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_ERROR
	je asm_run_error					; any errors?
	
	; pass 2: translation of opcodes and operands to machine code
	call asmEmit_initialize
	mov byte [cs:asmPass], ASM_PASS_2
	call asm_interpret					; interpret program text
	
	cmp byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_ERROR
	je asm_run_error					; any errors during second pass?
	
asm_run_success:
	popa
	mov ax, 1
	jmp asm_run_exit
asm_run_error:
	popa
	mov ax, 0
asm_run_exit:
	call asm_display_status				; print user-friendly message
	call asmList_finalize				; finalize listing
	call asmEmit_get_written_byte_count	; CX := byte count
	ret


; The entry point into the assembler execution.
;
; input:
;		none
; output:
;		none
asm_interpret:
	pushf
	pusha
	push ds
	push es

	push word [cs:asmProgramTextSeg]
	pop ds
	push word [cs:asmProgramTextOff]
	pop si										; DS:SI := resume point
	
	cld
	push cs
	pop es
	
	call asmDisplay_initialize
	call asmInterpreter_initialize
	
	call asmDisplay_log_pass_start
	
	; pointer DS:SI advances as tokens are read
asm_interpret_next_token:
	mov byte [cs:asmMoreTokensAvailable], 1	; assume we still have tokens
	
	; read in a token from the program text
	mov di, asmCurrentToken				; here, ES = CS from above
	call asm_read_token					; current := next token
	
	cmp ax, TOKEN_PARSE_ERROR			; was there an error?
	je asm_interpret_halt_try_error		; yes
	
	mov word [cs:asmProgramTextPointerBeforeProcessing], si

	cmp ax, TOKEN_PARSE_NONE_LEFT			; any token read?
	jne asm_interpret_process				; yes, proceed normally
	; no more tokens
	mov byte [cs:asmMoreTokensAvailable], 0	; there are no further tokens..
	
	; now check whether the interpreter is in the middle of an instruction
	call asmInterpreter_is_within_instruction	; AX := 0 when not within inst.
	
	cmp ax, 0
	je asm_interpret_no_more_tokens		; not within instruction, so there
											; is nothing further to interpret
	; we are in the middle of an instruction, so insert an artificial
	; instruction delimiter to ensure that the interpreter executes it
	mov byte [cs:asmCurrentToken], ASM_CHAR_INSTRUCTION_DELIMITER
	mov byte [cs:asmCurrentToken+1], 0	; ..but we pretend we read an
											; additional token, so
											; the last instruction is
											; guaranteed to be executed
asm_interpret_process:
	; process the token we've just read
	call asmList_check_overflow		; first check listing hasn't overflowed
	call asmInterpreter_process				; this call may modify pointer 
											; DS:SI to follow a branch, etc.
	
	cmp ax, 0								; was there an error?
	je asm_interpret_halt					; yes, so we halt
	
	cmp byte [cs:asmMoreTokensAvailable], 0	; are there more tokens?
	je asm_interpret_no_more_tokens		; no, we're done
	jmp asm_interpret_next_token			; yes, so read the next one
	
asm_interpret_halt:
	; the interpretation must halt, and we determine mode below

asm_interpret_halt_try_error:
	mov byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_ERROR
	jmp asm_interpret_exit			; ((2)) we're halting due to an error

asm_interpret_halt_non_error:
	mov byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_SUCCESS
	jmp asm_interpret_exit		; ((4)) we're halting due to a non-error

asm_interpret_no_more_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageStatusOk
	cmp word [cs:asmProgramTextPointerBeforeProcessing], si
											; if current program text pointer
											; changed, it's because processing
											; the last token of program
											; has just caused a branch, so 
											; we're not at the end anymore
	jne asm_interpret_next_token			; we're no longer at the end
	
	; we have no more tokens to parse, so the interpretation is over
	mov byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_SUCCESS
	jmp asm_interpret_exit		; ((5)) we're halting due to program end
asm_interpret_exit:
	call asmDisplay_log_pass_end
	
	pop es
	pop ds
	popa
	popf
	ret


; Reads the next ASM token
;
; input:
;	 DS:SI - pointer to string, zero-terminated
;	 ES:DI - pointer to where token will be stored, zero-terminated
; output:
;	 DS:SI - pointer to immediately after token
;		AX - 0 when there were no more tokens to read
;			 1 when a token was read (success)
;			 2 when there was an error
asm_read_token:
	pushf
	push bx
	push cx
	push dx
	push di
	
	cld
	
	mov ax, TOKEN_PARSE_NONE_LEFT		; "no token found"
asm_read_token_advance_to_token_start_loop:
	cmp byte [ds:si], 0			; are we at the end of input?
	je asm_read_token_done	; yes

	call asm_check_ignored_character	; are we on an ignored character?
	jnc asm_read_token_start_found	; no, so we have found the token start
	
	inc si						; next character
	jmp asm_read_token_advance_to_token_start_loop

asm_read_token_start_found:
	; DS:SI now points to the first character of the token we're returning
	mov ax, TOKEN_PARSE_PARSED	; "token found"
	mov bx, 0					; "not a string literal"
	mov cx, 0					; token length counter
	
	cmp byte [ds:si], ASM_CHAR_STRING_DELIMITER	; is it a string literal?
	jne asm_read_token_copy	; no
	mov bx, 1					; "a string literal"
asm_read_token_copy:
	cmp cx, ASM_TOKEN_MAX_LENGTH	; have we already accumulated as many
	je asm_read_token_overflow	; characters as the max token length?
	; we have not yet filled the token buffer, so we accumulate this character
	movsb						; copy it into the output buffer
								; and advance input pointer

	inc cx						; token length counter
	
	cmp byte [ds:si-1], ASM_CHAR_LINE_ENDING	; is this token a new line?
	je asm_read_token_done	; yes
	
	cmp byte [ds:si], 0			; are we at the end of input?
	je asm_read_token_done	; yes
	
	cmp bx, 1					; is this token a string literal?
	jne asm_read_token_copy_not_string_literal	; no
	
	; we're inside a string literal
	cmp byte [ds:si-1], ASM_CHAR_STRING_DELIMITER	; did we just accumulate
													; the string delimiter?
	jne asm_read_token_copy	; no, keep accumulating
	; we just accumulated the delimiter
	; we must check if it's the opening string delimiter, or 
	; the closing string delimiter
	cmp cx, 1					; are we past the first character of the token?
	ja asm_read_token_done	; yes, so this was the closing delimiter
	jmp asm_read_token_copy	; no, so we accumulate next token character

asm_read_token_copy_not_string_literal:	
	; we're not inside a string literal
	call asm_check_ignored_character
	jc asm_read_token_done			; we stop before an ignored character
	
	cmp byte [ds:si], ASM_CHAR_LINE_ENDING
	je asm_read_token_done			; we stop before a newline
	
	call asm_check_stop_character		; are we before a stop character?
	jc asm_read_token_done			; yes
	push si
	dec si
	call asm_check_stop_character		; are we after a stop character?
	pop si
	jc asm_read_token_done			; yes
	
	cmp byte [ds:si], ASM_CHAR_STRING_DELIMITER
	je asm_read_token_done			; we stop before a string delimiter
										; (since we're not inside a 
										; string literal)
	
	jmp asm_read_token_copy			; next token character

asm_read_token_overflow:
	; the token was too long, so we should halt interpretation with an error
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageTokenTooLong
	mov ax, TOKEN_PARSE_ERROR			; "error"
	jmp asm_read_token_exit
asm_read_token_done:
	mov byte [es:di], 0					; add terminator
asm_read_token_exit:	
	pop di
	pop dx
	pop cx
	pop bx
	popf
	ret

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; includes region
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "common\ascii.asm"
%include "common\string.asm"

%include "common\assembler\asmdef.asm"
%include "common\assembler\asmvrn.asm"
%include "common\assembler\asmval.asm"
%include "common\assembler\asmint.asm"
%include "common\assembler\asmutl.asm"
%include "common\assembler\asmexe.asm"
%include "common\assembler\asmevl.asm"
%include "common\assembler\asmemit.asm"
%include "common\assembler\asmlist.asm"
%include "common\assembler\asmdisp.asm"

%include "common\assembler\asmx86ex.asm"		; processor-specific
%include "common\assembler\asmx86df.asm"		; processor-specific
%include "common\assembler\asmx86ut.asm"		; processor-specific


%endif
