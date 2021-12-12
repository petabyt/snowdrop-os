;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains instruction execution routines for Snowdrop OS's assembler.
; Routines here are invoked once entire instructions have been parsed.
;
; Usually, there is a single routine per keyword. This means that - despite
; the large size of this file - there is very little branching complexity,
; keeping the code easy to understand.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_EXECUTION_
%define _COMMON_ASM_EXECUTION_

asmDwDbMode:	dw 0
ASM_DW_DB_MODE__DB	equ 0
ASM_DW_DB_MODE__DW	equ 1


; Executes the current instruction, ORG
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_ORG:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:asmPass], ASM_PASS_0	; we only set origin in pass 0
	jne asmExecution_ORG_success

	cmp byte [cs:asmCurrentInstTokenCount], 1
	jne asmExecution_ORG_tokens
	
	; cannot set origin when any bytes have been emitted
	call asmEmit_get_total_written_byte_count	; AX :- byte count
	cmp ax, 0
	jne asmExecution_ORG_already_emitted
	
	; get first token
	mov bl, 0
	push cs
	pop ds
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := pointer to first token
	
	; first token must be a number
	call asm_multibase_number_atoi			; AX := 0 when not a number
											; BX := the number
	cmp ax, 0
	je asmExecution_ORG_not_a_number
	
	; set origin
	mov ax, bx								; AX := the number
	call asmEmit_set_origin					; AX := 0 when origin was not set
	cmp ax, 0
	je asmExecution_ORG_cannot_set
	
	jmp asmExecution_ORG_success

asmExecution_ORG_cannot_set:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageCannotSetOriginMoreThanOnce
	jmp asmExecution_ORG_error
	
asmExecution_ORG_already_emitted:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageCannotSetOriginAfterEmittedBytes
	jmp asmExecution_ORG_error
	
asmExecution_ORG_not_a_number:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageTokenMustBeASingleNumber
	jmp asmExecution_ORG_error
	
asmExecution_ORG_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	jmp asmExecution_ORG_error
	
asmExecution_ORG_error:
	mov ax, 0							; "error"
	jmp asmExecution_ORG_done
asmExecution_ORG_success:
	mov ax, 1							; "success"
asmExecution_ORG_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction, COMMENT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_COMMENT:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:asmCurrentInstTokenCount], 1
	jne asmExecution_COMMENT_tokens
	
	; first token must be a quoted string literal
	mov bl, 0
	push cs
	pop ds
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := pointer to first token
	call asm_is_valid_quoted_string_literal	; AX := 0 when not a QSL
	cmp ax, 0
	je asmExecution_COMMENT_invalid_qsl
	jmp asmExecution_COMMENT_success

asmExecution_COMMENT_invalid_qsl:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageTokenMustBeQSL
	jmp asmExecution_COMMENT_error
	
asmExecution_COMMENT_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	jmp asmExecution_COMMENT_error
	
asmExecution_COMMENT_error:
	mov ax, 0							; "error"
	jmp asmExecution_COMMENT_done
asmExecution_COMMENT_success:
	mov ax, 1							; "success"
asmExecution_COMMENT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction, TIMES
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_TIMES:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:asmCurrentInstTokenCount], 0
	je asmExecution_TIMES_tokens
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; find first keyword token
	mov bl, 0
asmExecution_TIMES_find_keyword:
	cmp bl, byte [cs:asmCurrentInstTokenCount]
	jae asmExecution_TIMES_need_opcode
	
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di

	call asm_is_valid_keyword
	cmp ax, 0						; is this token a keyword?
	je asmExecution_TIMES_find_keyword_next
	; is this "times" again?
	mov si, asmKeywordTimes
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_TIMES_find_keyword_done	; no, so it's valid
	jmp asmExecution_TIMES_need_opcode	; yes, so it's invalid syntax
asmExecution_TIMES_find_keyword_next:
	inc bl
	jmp asmExecution_TIMES_find_keyword
asmExecution_TIMES_find_keyword_done:
	; here, BL = index of token containing first keyword (opcode)
	
	; now calculate multiplier
	mov dl, 0						; we evaluate from the first token...
	mov dh, bl
	dec dh							; ... to right before the first keyword
	call asmEval_force_read_from_var_storage_on_next_eval
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmExecution_TIMES_error		; there was an error
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmExecution_CONST_value_must_be_numeric
	; we now make the keyword current instruction
	; here, DH = token right before first keyword
	mov dl, dh
	inc dl							; DL := keyword token
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; DH := last token
	; make instruction from DL to DH current
	call asmInterpreter_make_subinstruction_main

	; delegate to subinstruction as many times as the multiplier
	; here, CX = multiplier
	cmp cx, 0
	je asmExecution_TIMES_success		; NOOP when multiplier is zero

asmExecution_TIMES_emit_loop:
	call asmExecution_core
	cmp ax, 0
	je asmExecution_TIMES_error
	loop asmExecution_TIMES_emit_loop
	
	jmp asmExecution_TIMES_success
	
asmExecution_TIMES_multiplier_must_be_numeric:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageTimesMultiplierMustBeNumeric
	jmp asmExecution_TIMES_error
	
asmExecution_TIMES_need_opcode:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageNeedOpcode
	jmp asmExecution_TIMES_error
	
asmExecution_TIMES_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	jmp asmExecution_TIMES_error
	
asmExecution_TIMES_success:
	mov ax, 1
	jmp asmExecution_TIMES_done
asmExecution_TIMES_error:
	mov ax, 0						; "error"
asmExecution_TIMES_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, either DW or DB
;
; input:
;		AX - 0 for DB, other value for DW
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_DW_DB:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	mov word [cs:asmDwDbMode], ax
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov dl, 0						; left token starts from first token
	mov dh, 0						; right token starts from first token
asmExecution_DW_loop:
	cmp dl, byte [cs:asmCurrentInstTokenCount]	; is left token PAST last?
	jae asmExecution_DW_success		; yes, so we're done
	
	mov bl, dh						
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	; ES:DI now points to right token
	mov si, asmSymbolComma
	call common_string_compare_ignore_case			; compare strings
	cmp ax, 0						; is the right token on a comma?
	je asmExecution_DW_loop_right_token_on_comma	; yes
	; it's not on a comma
	mov bl, byte [cs:asmCurrentInstTokenCount]
	dec bl
	cmp dh, bl						; is right token last token?
	je asmExecution_DW_loop_right_token_is_last	; yes
	; right token is not a comma, and not last
	inc dh							; move right token to the right
	jmp asmExecution_DW_loop		; loop again
asmExecution_DW_loop_right_token_on_comma:
	cmp dl, dh
	je asmExecution_DW_invalid_syntax	; two commas in a row, or a single
										; token of comma
	; right token is on a comma, in a valid spot
	; DL is still the index of left token
	; we can now evaluate from DL to DH-1 (since DH is on a comma)
	dec dh
	jmp asmExecution_DW_loop_evaluate

asmExecution_DW_loop_right_token_is_last:
	; right token is last token, but not a comma
	; DL is still the index of left token
	; we can now evaluate from DL to DH (since DH is last token)

asmExecution_DW_loop_evaluate:
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmExecution_DW_error		; there was an error
	cmp bx, ASM_EVAL_TYPE_NUMBER	
	je asmExecution_DW_number
asmExecution_DW_string:
	; expression evaluated to a string (in ES:DI)
	push es
	pop ds
	mov si, di
	cmp word [cs:asmDwDbMode], ASM_DW_DB_MODE__DB
	je asmExecution_DW_string_output_bytes
	call asmEmit_emit_words_from_string
	jmp asmExecution_DW_next_iteration
asmExecution_DW_string_output_bytes:
	call asmEmit_emit_bytes_from_string
	jmp asmExecution_DW_next_iteration
	
asmExecution_DW_number:
	; the expression evaluated to a number (in CX)
	mov ax, cx
	cmp word [cs:asmDwDbMode], ASM_DW_DB_MODE__DB
	je asmExecution_DW_number_output_bytes
	call asmEmit_emit_word_from_number
	jmp asmExecution_DW_next_iteration
asmExecution_DW_number_output_bytes:
	call asmEmit_emit_byte_from_number
	call asmUtil_warn_if_value_larger_than_byte
	jmp asmExecution_DW_next_iteration

asmExecution_DW_next_iteration:
	; check if right token is on last
	mov bl, byte [cs:asmCurrentInstTokenCount]
	dec bl
	cmp dh, bl						; is right token last token?
	je asmExecution_DW_success		; right token was last token, so
									; there are no more tokens
	; right token was on a comma (but we moved it one position
	; to the left, so we can evaluate)
	; NOTE: top of the loop catches the case when the last token is a comma
	add dh, 2						; move right token to the right of comma
	mov dl, dh						; also move left token on top of right
	jmp asmExecution_DW_loop		; next iteration
	
asmExecution_DW_invalid_syntax:
	mov word [cs:asmInterpretationEndMessagePtr], asmInvalidSyntax
	jmp asmExecution_DW_error
	
asmExecution_DW_success:
	mov ax, 1						; "success"
	jmp asmExecution_DW_done
asmExecution_DW_error:
	mov ax, 0						; "error"
asmExecution_DW_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, CONST
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_CONST:
	push ds
	push es
	push si
	push di
	push bx
	push cx
	push dx

	mov ax, cs
	mov ds, ax
	mov es, ax

	cmp byte [cs:asmCurrentInstTokenCount], 3
	jb asmExecution_CONST_bad_number_of_arguments	; too few arguments
	
	; first token must be a valid variable name
	mov bl, 0
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di							; DS:SI := pointer to first token
	call asm_is_valid_variable_name		; AX := 0 when invalid
	cmp ax, 0
	je asmExecution_CONST_invalid_assigned_variable
	
	; second token must be the = symbol
	mov bl, 1
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, asmSymbolEquals
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_CONST_no_equals
	
	; evaluate expression contained in tokens third to last
	mov dl, 2						; we evaluate from the third token...
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; ...to the last
	
	cmp byte [cs:asmPass], ASM_PASS_1	; during pass 1 we define constants
	jne asmExecution_CONST_eval			; only based on already defined
										; symbols
	call asmEval_force_read_from_var_storage_on_next_eval
asmExecution_CONST_eval:
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmExecution_CONST_error		; there was an error
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmExecution_CONST_value_must_be_numeric
	; here, CX = numeric result of expression to be assigned

	; get variable name
	mov bl, 0
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	push cs
	pop ds
	mov si, di							; DS:SI := pointer to variable name

	; check whether it exists already
	call asmNumericVars_get_handle_from_storage	; CARRY - set when not found
	jnc asmExecution_CONST_cannot_redefine

	; create variable
	call asmNumericVars_allocate		; CARRY - set when a slot was not found
										; BX - variable handle	
	jc asmExecution_CONST_no_more_vars
	call asmDisplay_record_const
	
	; set value
	mov ax, bx							; AX := variable handle
	mov bx, cx							; BX := expression result
	call asmNumericVars_set_value

	jmp asmExecution_CONST_success

asmExecution_CONST_cannot_redefine:
	; here, AX = handle
	; when the variable exists from a different pass, it's not redefined
	call asmNumericVars_get_definition_pass
	cmp bl, byte [cs:asmPass]
	jne asmExecution_CONST_success

	mov word [cs:asmInterpretationEndMessagePtr], asmConstantRedefined
	jmp asmExecution_CONST_error
	
asmExecution_CONST_value_must_be_numeric:
	mov word [cs:asmInterpretationEndMessagePtr], asmConstantValueMustBeNumeric
	jmp asmExecution_CONST_error
	
asmExecution_CONST_no_equals:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageMissingEqualsSign
	jmp asmExecution_CONST_error
	
asmExecution_CONST_invalid_assigned_variable:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageInvalidAssignedVariableName
	jmp asmExecution_CONST_error
	
asmExecution_CONST_bad_number_of_arguments:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	jmp asmExecution_CONST_error
	
asmExecution_CONST_no_more_vars:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageVariablesFull
	jmp asmExecution_CONST_error
	
asmExecution_CONST_error:
	cmp byte [cs:asmPass], ASM_PASS_0
	je asmExecution_CONST_success		; no errors during pass 0
	cmp byte [cs:asmPass], ASM_PASS_1
	je asmExecution_CONST_success		; no errors during pass 1
	
	mov ax, 0							; "error"
	jmp asmExecution_CONST_done
asmExecution_CONST_success:
	mov ax, 1							; "success"
asmExecution_CONST_done:
	pop dx
	pop cx
	pop bx
	pop di
	pop si
	pop es
	pop ds
	ret


; Executes the current instruction, PRINT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_PRINT:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, 1						; "no error"
	
	cmp byte [cs:asmCurrentInstTokenCount], 0
	je asmExecution_PRINT_done	; NOOP when no tokens
	
	mov dl, 0						; we evaluate from the first token...
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; ...to the last
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmExecution_PRINT_error	; there was an error

	call asm_display_ASM_tag
	
	cmp bx, ASM_EVAL_TYPE_NUMBER
	je asmExecution_PRINT_number	; expression evaluated to a number
asmExecution_PRINT_string:
	; expression evaluated to a string (in ES:DI)
	push es
	pop ds
	mov si, di						; DS:SI := pointer to result string
	jmp asmExecution_PRINT_output
asmExecution_PRINT_number:
	; the expression evaluated to a number
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov di, asmItoaBuffer			; ES:DI := pointer to buffer
	mov ax, cx						; AX := numeric result
	mov dx, 1						; option: zero-terminate									
	xchg ah, al						; humans read MSB first
	call asm_word_to_hex			; write value in AX
	mov si, asmItoaBuffer			; DS:SI := pointer to buffer
	
	jmp asmExecution_PRINT_output
asmExecution_PRINT_output:
	; now output the string representation of the expression result
	; here, DS:SI = pointer to string representation of the expression result
	
	; first, write attribute byte
	mov dl, 7
	int 0A5h						; BX := string length
	mov cx, bx
	int 9Fh							; write attribute bytes
	
	call asm_display_worker			; print string
	
	push cs
	pop ds
	mov si, asmNewline
	call asm_display_worker			; print newline
	
	mov ax, 1						; "success"
	jmp asmExecution_PRINT_done
	
asmExecution_PRINT_error:
	mov ax, 0						; "error"
asmExecution_PRINT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret

	
; Executes the current instruction
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_core:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, asmCurrentKeyword
	
	cmp byte [cs:asmPass], ASM_PASS_0		; CONST-only pass?
	jne asmExecution_core_pass_is_not_zero
	
	; during pass 0, we only execute a limited number of instructions
asmExecution_core_pass0_ORG:
	mov di, asmKeywordOrg
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_pass0_CONST
	call asmExecution_ORG
	jmp asmExecution_core_done
asmExecution_core_pass0_CONST:
	mov di, asmKeywordConst
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_done
	call asmExecution_CONST
	
	jmp asmExecution_core_done
	
	; delegate based on keyword
asmExecution_core_pass_is_not_zero:
asmExecution_core_ORG:
	mov di, asmKeywordOrg
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_COMMENT
	call asmExecution_ORG
	jmp asmExecution_core_done
asmExecution_core_COMMENT:
	mov di, asmKeywordComment
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_TIMES
	call asmExecution_COMMENT
	jmp asmExecution_core_done
asmExecution_core_TIMES:
	mov di, asmKeywordTimes
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_DB
	call asmExecution_TIMES
	jmp asmExecution_core_done
asmExecution_core_DB:
	mov di, asmKeywordDb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_DW
	mov ax, ASM_DW_DB_MODE__DB
	call asmExecution_DW_DB
	jmp asmExecution_core_done	
asmExecution_core_DW:
	mov di, asmKeywordDw
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_CONST
	mov ax, ASM_DW_DB_MODE__DW
	call asmExecution_DW_DB
	jmp asmExecution_core_done	
asmExecution_core_CONST:
	mov di, asmKeywordConst
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_PRINT
	call asmExecution_CONST
	jmp asmExecution_core_done
asmExecution_core_PRINT:
	mov di, asmKeywordPrint
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmExecution_core_try_x86_specific
	call asmExecution_PRINT
	jmp asmExecution_core_done
asmExecution_core_try_x86_specific:
	call asmx86_core
	; we use whatever was returned by this specific instruction set
asmExecution_core_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Executes the current instruction
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmExecution_entry_point:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es

	call asmDisplay_mark_instruction_beginning
	call asm_concat_last_parsed_instruction	; save a single-string version of
											; this instruction

	call asmList_mark_instruction_beginning	; make preparations to write this
											; instruction to the listing
	call asmExecution_core

	cmp ax, 0							; did the instruction cause an error?
	je asmExecution_entry_point_leave	; yes, so we're done
	; no, the execution was successful
	call asmExecution_write_listing

asmExecution_entry_point_leave:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret


; Writes the listing of the recently-assembled instruction
;
; input:
;		none
; output:
;		none
asmExecution_write_listing:
	call asmList_write_instruction
	ret
	

; Utility for: <keyword> <numeric_expression>
;
; Asserts current instruction has a numeric expression and returns
; the numeric values contained within the expressions.
; Populates error message accordingly if an assertion fails.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - numeric value
asmExecution_util_one_numeric_expression:
	push ds
	push es
	push cx
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:asmCurrentInstTokenCount], 1	; at least one tokens
	jb asmExecution_util_one_numeric_expression_tokens_count_error

	; evaluate expression
	mov dl, 0								; leftmost token to consider
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh									; rightmost token to consider
	call asmEval_do
	cmp ax, 0
	je asmExecution_util_one_numeric_expression_error
											; error in expression evaluation
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmExecution_util_one_numeric_expression_not_numeric
	mov bx, cx								; return value
	
	jmp asmExecution_util_one_numeric_expression_success

asmExecution_util_one_numeric_expression_not_numeric:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageArgumentMustBeNumeric
	jmp asmExecution_util_one_numeric_expression_error

asmExecution_util_one_numeric_expression_tokens_count_error:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	jmp asmExecution_util_one_numeric_expression_error
	
asmExecution_util_one_numeric_expression_error:
	mov ax, 0							; "error"
	jmp asmExecution_util_one_numeric_expression_done
asmExecution_util_one_numeric_expression_success:
	mov ax, 1							; "success"
asmExecution_util_one_numeric_expression_done:
	pop di
	pop si
	pop dx
	pop cx
	pop es
	pop ds
	ret
	
	
; Utility for: <keyword> <numeric_expression> , <numeric_expression>
;
; Asserts current instruction has two numeric expressions separated
; by a comma and returns the numeric values contained within the expressions.
; Populates error message accordingly if an assertion fails.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - numeric value left of comma
;		CX - numeric value right of comma
asmExecution_util_two_numeric_expressions:
	push ds
	push es
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:asmCurrentInstTokenCount], 3	; at least three tokens
	jb asmExecution_util_two_numeric_expressions_tokens_count_error
	
	; find token containing comma
	mov si, asmArgumentDelimiterToken
	call asm_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je asmExecution_util_two_numeric_expressions_no_comma		; not found
	mov byte [cs:asmExeTwoNumericExpressionsCommaTokenIndex], bl
	
	; evaluate expression (left of comma)
	mov dl, 0								; leftmost token to consider
	mov dh, bl
	dec dh									; rightmost token to consider
	call asmEval_do
	cmp ax, 0
	je asmExecution_util_two_numeric_expressions_error
											; error in expression evaluation
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmExecution_util_two_numeric_expressions_not_numeric
	mov word [cs:asmExeTwoNumericExpressionsFirstValue], cx	; save value
	
	; evaluate expression (right of comma)
	mov dl, byte [cs:asmExeTwoNumericExpressionsCommaTokenIndex]
	inc dl									; leftmost token to consider
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh									; rightmost token to consider
	call asmEval_do
	cmp ax, 0
	je asmExecution_util_two_numeric_expressions_error
											; error in expression evaluation
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmExecution_util_two_numeric_expressions_not_numeric
	
	; here, CX = numeric value of second expression
	mov bx, word [cs:asmExeTwoNumericExpressionsFirstValue]
							; BX := numeric value of first expression
	jmp asmExecution_util_two_numeric_expressions_success

asmExecution_util_two_numeric_expressions_no_comma:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageNoComma
	jmp asmExecution_util_two_numeric_expressions_error
	
asmExecution_util_two_numeric_expressions_not_numeric:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageArgumentMustBeNumeric
	jmp asmExecution_util_two_numeric_expressions_error

asmExecution_util_two_numeric_expressions_tokens_count_error:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	jmp asmExecution_util_two_numeric_expressions_error
	
asmExecution_util_two_numeric_expressions_error:
	mov ax, 0							; "error"
	jmp asmExecution_util_two_numeric_expressions_done
asmExecution_util_two_numeric_expressions_success:
	mov ax, 1							; "success"
asmExecution_util_two_numeric_expressions_done:
	pop di
	pop si
	pop dx
	pop es
	pop ds
	ret

	
; Utility for: <keyword> <numeric_expression> , <string_expression>
;
; Asserts current instruction has one numeric expressions, followed by comma,
; followed by a string expression, and returns the numeric values 
; contained within the expressions.
; Populates error message accordingly if an assertion fails.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - numeric value left of comma
;	 DS:SI - string value right of comma
asmExecution_util_int_string:
	push es
	push cx
	push dx
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:asmCurrentInstTokenCount], 3	; at least three tokens
	jb asmExecution_util_int_string_tokens_count_error
	
	; find token containing comma
	mov si, asmArgumentDelimiterToken
	call asm_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je asmExecution_util_int_string_no_comma		; not found
	mov byte [cs:asmExeIntStringCommaTokenIndex], bl
	
	; evaluate expression (left of comma)
	mov dl, 0								; leftmost token to consider
	mov dh, bl
	dec dh									; rightmost token to consider
	call asmEval_do
	cmp ax, 0
	je asmExecution_util_int_string_error
											; error in expression evaluation
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmExecution_util_int_string_first_arg_not_numeric
	mov word [cs:asmExeIntStringExpressionsFirstValue], cx	; save value
	
	; evaluate expression (right of comma)
	mov dl, byte [cs:asmExeIntStringCommaTokenIndex]
	inc dl									; leftmost token to consider
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh									; rightmost token to consider
	call asmEval_do						; ES:DI := result string
											; when applicable
	cmp ax, 0
	je asmExecution_util_int_string_error
											; error in expression evaluation
	cmp bx, ASM_EVAL_TYPE_STRING
	jne asmExecution_util_int_string_second_arg_not_string
	; here, ES:DI = string value of second expression
	push es
	pop ds
	mov si, di				; DS:SI := string value of second expression
	mov bx, word [cs:asmExeIntStringExpressionsFirstValue]
							; BX := numeric value of first expression
	jmp asmExecution_util_int_string_success

asmExecution_util_int_string_first_arg_not_numeric:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageFirstArgumentMustBeNumber
	jmp asmExecution_util_int_string_error
	
asmExecution_util_int_string_second_arg_not_string:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageSecondArgumentMustBeString
	jmp asmExecution_util_int_string_error
	
asmExecution_util_int_string_no_comma:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageNoComma
	jmp asmExecution_util_int_string_error

asmExecution_util_int_string_tokens_count_error:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	jmp asmExecution_util_int_string_error
	
asmExecution_util_int_string_error:
	mov ax, 0							; "error"
	jmp asmExecution_util_int_string_done
asmExecution_util_int_string_success:
	mov ax, 1							; "success"
asmExecution_util_int_string_done:
	pop di
	pop cx
	pop dx
	pop es
	ret


%endif
