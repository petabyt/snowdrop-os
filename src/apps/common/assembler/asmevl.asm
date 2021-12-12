;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains expression evaluation routines for Snowdrop OS's assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_EVAL_
%define _COMMON_ASM_EVAL_


asmEvalDoNextEvalForcedToReadVariableStorage:	db 0


; Evaluates the specified instruction fragments (tokens), resolving 
; variables as needed, and producing a single resulting value.
; Cases:
;              string --> string
;              number --> number
;     number [OPERATOR] number --> number
;
; input:
;		DL - index of first instruction token to consider
;		DH - index of last instruction token to consider
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - 0 when the result evaluated to a string
;			 1 when the result evaluated to a number
;		CX - numeric result, if applicable
;	 ES:DI - pointer to result string, if applicable
asmEval_do:
	push ds
	push fs
	push si
	push dx
	
	push dx							; [1]
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov fs, ax
	
	sub dh, dl
	cmp dh, 2
	je asmEval_do_three_tokens	; three tokens
	cmp dh, 0
	je asmEval_do_one_token		; one token
	; unsupported number of tokens
	pop dx							; [1]
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnsupportedExpressionTokenCount
	mov ax, 0						; "error"
	jmp asmEval_do_done
	
asmEval_do_three_tokens:
	pop dx							; [1]
	; we evaluate <operand> <operator> <operand>
	inc dl							; operator is the second token
	call asmEval_get_operator_type	; BX := operator
	dec dl							; restore DL to first token
	cmp ax, 0
	je asmEval_do_error
	mov word [cs:asmEvalOperatorType], bx	; save operator type

	; evaluate left operand
	mov di, asmEvalBuffer0		; ES:DI := string buffer
	call asmEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je asmEval_do_error
	mov word [cs:asmEvalLeftOperandType], bx
	mov word [cs:asmEvalLeftOperandNumericValue], cx
	
	; evaluate right operand
	add dl, 2						; right operand is third token
	mov di, asmEvalBuffer1		; ES:DI := string buffer
	call asmEval_single			; BX := token type, CX := numeric value
	sub dl, 2						; restore DL to first token
	cmp ax, 0
	je asmEval_do_error
	mov word [cs:asmEvalRightOperandType], bx
	mov word [cs:asmEvalRightOperandNumericValue], cx

asmEval_do_three_tokens_left_number_right_number:
	; number <operand> number
	call asmEval_arithmetic		; CX := numeric value
	cmp ax, 0
	je asmEval_do_error			; error	
	mov bx, ASM_EVAL_TYPE_NUMBER	; set up return values
	; CX already populated with numeric result
	jmp asmEval_do_success
	
asmEval_do_one_token:
	pop dx							; [1]
	; we evaluate a single token ( DH = DL )
	mov di, asmEvalBuffer0		; ES:DI := string buffer
	call asmEval_single
	
	; the above fills in register values in the same fashion as the
	; contract of this procedure
	jmp asmEval_do_done
	
asmEval_do_error_operator_not_supported:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageOperatorNotSupported
	jmp asmEval_do_error
	
asmEval_do_success:
	mov ax, 1						; "success"
	jmp asmEval_do_done
asmEval_do_error:
	mov ax, 0						; "error"
asmEval_do_done:
	mov byte [cs:asmEvalDoNextEvalForcedToReadVariableStorage], 0
	pop dx
	pop si
	pop fs
	pop ds
	ret
	
	
; Forces variable resolution of next asmEval_do to take place exclusively
; from variable storage
;
; input:
;		none
; output:
;		none
asmEval_force_read_from_var_storage_on_next_eval:
	mov byte [cs:asmEvalDoNextEvalForcedToReadVariableStorage], 1
	ret
	

; Evaluates the operands and operator already stored, resolving 
; variables as needed, and producing a single resulting value.
;
; NOTE: evaluates expressions of the form: ; number <operand> number
;
; input:
;		none
;		NOTE: relies on already set operand/operator variables
; output:
;		AX - 0 if there was an error, other value otherwise
;		CX - numeric result
asmEval_arithmetic:
	push ds
	push es
	push bx
	push dx
	push si
	push di
	
asmEval_arithmetic_BITSHIFTR:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_BITSHIFTR
	jne asmEval_arithmetic_BITSHIFTL
	cmp word [cs:asmEvalRightOperandNumericValue], 255
	ja asmEval_arithmetic_shift_amount_must_be_byte
	
	mov ax, word [cs:asmEvalLeftOperandNumericValue]
	mov cx, word [cs:asmEvalRightOperandNumericValue]
	shr ax, cl
	mov cx, ax
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_BITSHIFTL:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_BITSHIFTL
	jne asmEval_arithmetic_BITXOR
	cmp word [cs:asmEvalRightOperandNumericValue], 255
	ja asmEval_arithmetic_shift_amount_must_be_byte
	
	mov ax, word [cs:asmEvalLeftOperandNumericValue]
	mov cx, word [cs:asmEvalRightOperandNumericValue]
	shl ax, cl
	mov cx, ax
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_BITXOR:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_BITXOR
	jne asmEval_arithmetic_BITOR
	
	mov cx, word [cs:asmEvalLeftOperandNumericValue]
	xor cx, word [cs:asmEvalRightOperandNumericValue]
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_BITOR:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_BITOR
	jne asmEval_arithmetic_BITAND
	
	mov cx, word [cs:asmEvalLeftOperandNumericValue]
	or cx, word [cs:asmEvalRightOperandNumericValue]
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_BITAND:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_BITAND
	jne asmEval_arithmetic_addition
	
	mov cx, word [cs:asmEvalLeftOperandNumericValue]
	and cx, word [cs:asmEvalRightOperandNumericValue]
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_addition:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_PLUS
	jne asmEval_arithmetic_subtraction
	; add the two operands
	mov cx, word [cs:asmEvalLeftOperandNumericValue]
	add cx, word [cs:asmEvalRightOperandNumericValue]
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_subtraction:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_MINUS
	jne asmEval_arithmetic_multiplication
	; subtract the two operands
	mov cx, word [cs:asmEvalLeftOperandNumericValue]
	sub cx, word [cs:asmEvalRightOperandNumericValue]
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_multiplication:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_MULTIPLY
	jne asmEval_arithmetic_integer_division
	; multiply the two operands
	mov ax, word [cs:asmEvalLeftOperandNumericValue]
	mov cx, word [cs:asmEvalRightOperandNumericValue]
	imul cx										; DX:AX := AX*CX
	mov cx, ax									; return it in CX
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_integer_division:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_DIVIDE
	jne asmEval_arithmetic_modulo
	; prevent division by zero
	cmp word [cs:asmEvalRightOperandNumericValue], 0
	je asmEval_arithmetic_divide_by_zero
	; find the quotient of the two operands
	mov ax, word [cs:asmEvalLeftOperandNumericValue]	;    AX := dividend
	cwd													; DX:AX := dividend
	mov cx, word [cs:asmEvalRightOperandNumericValue]	; CX := divisor
	idiv cx										; AX := DX:AX div CX
	mov cx, ax									; return it in CX
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_modulo:
	cmp word [cs:asmEvalOperatorType], ASM_OPERATOR_MODULO
	jne asmEval_arithmetic_unsupported
	; prevent division by zero
	cmp word [cs:asmEvalRightOperandNumericValue], 0
	je asmEval_arithmetic_divide_by_zero
	; find the quotient of the two operands
	mov ax, word [cs:asmEvalLeftOperandNumericValue]	;    AX := dividend
	cwd													; DX:AX := dividend
	mov cx, word [cs:asmEvalRightOperandNumericValue]	; CX := divisor
	idiv cx										; DX := DX:AX mod CX
	mov cx, dx									; return it in CX
	jmp asmEval_arithmetic_success
	
asmEval_arithmetic_shift_amount_must_be_byte:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageShiftAmountMustBeByte
	jmp asmEval_arithmetic_error
	
asmEval_arithmetic_unsupported:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnknownOperator
	jmp asmEval_arithmetic_error
	
asmEval_arithmetic_divide_by_zero:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageIntegerDivideByZero
	jmp asmEval_arithmetic_error
	
asmEval_arithmetic_error:
	mov ax, 0							; "error"
	jmp asmEval_arithmetic_done
asmEval_arithmetic_success:
	mov ax, 1							; "success"
asmEval_arithmetic_done:
	pop di
	pop si
	pop dx
	pop bx
	pop es
	pop ds
	ret
	

; Evaluates the specified instruction fragment (token), returning the
; type of operator contained within.
;
; input:
;		DL - index of instruction token to consider
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - operator type
asmEval_get_operator_type:
	push ds
	push es
	push cx
	push dx
	push si
	push di
	
	mov bl, dl
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov ax, cs
	mov ds, ax
	mov es, ax

asmEval_get_operator_type_BITSHIFTR:
	mov bx, ASM_OPERATOR_BITSHIFTR			; return value
	mov si, asmOperatorBitShiftR
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_BITSHIFTL:
	mov bx, ASM_OPERATOR_BITSHIFTL			; return value
	mov si, asmOperatorBitShiftL
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_BITXOR:
	mov bx, ASM_OPERATOR_BITXOR				; return value
	mov si, asmOperatorBitXor
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_BITOR:
	mov bx, ASM_OPERATOR_BITOR				; return value
	mov si, asmOperatorBitOr
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_BITAND:
	mov bx, ASM_OPERATOR_BITAND				; return value
	mov si, asmOperatorBitAnd
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_plus:
	mov bx, ASM_OPERATOR_PLUS			; return value
	mov si, asmOperatorPlus
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_minus:
	mov bx, ASM_OPERATOR_MINUS		; return value
	mov si, asmOperatorMinus
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_divide:
	mov bx, ASM_OPERATOR_DIVIDE		; return value
	mov si, asmOperatorDivide
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_multiply:
	mov bx, ASM_OPERATOR_MULTIPLY		; return value
	mov si, asmOperatorMultiply
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success
asmEval_get_operator_type_modulo:
	mov bx, ASM_OPERATOR_MODULO		; return value
	mov si, asmOperatorModulo
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmEval_get_operator_type_success

asmEval_get_operator_type_error:
	; ERROR: operator not supported
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageUnknownOperator
	mov ax, 0							; "error"
	jmp asmEval_get_operator_type_done
asmEval_get_operator_type_success:
	mov ax, 1							; "success"
asmEval_get_operator_type_done:
	pop di
	pop si
	pop dx
	pop cx
	pop es
	pop ds
	ret
	

; Evaluates the specified instruction fragment (token), resolving 
; variables as needed, and producing a single resulting value.
; Cases:
;
;   single-char quoted string literal --> number (from ASCII)
;    multi-char quoted string literal --> string
;                              number --> number
;                     number variable --> number
;
; input:
;		DL - index of instruction token to consider
;	 ES:DI - pointer to buffer where string values are accumulated
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - 0 when the result evaluated to a string
;			 1 when the result evaluated to a number
;		CX - numeric result, if applicable
asmEval_single:
	push ds
	push si
	push di
	push dx

	mov bl, dl
	push di					; [1]
	call asmInterpreter_get_instruction_token_near_ptr
	mov si, di				; SI := near pointer to instruction token string
	push cs
	pop ds					; DS:SI := pointer to instruction token string
	pop di					; [1]

	; now determine its type
	
	; first try to see if it's a parameterless function
asmEval_single_quoted_string_literal:
	call asm_is_valid_quoted_string_literal	; AX := 0 when not a QSL
	cmp ax, 0
	je asmEval_single_number
	; it's a quoted string literal
	; if it's a single character, we generate a number (from character's ASCII)
	int 0A5h				; BX := QSL length
	cmp bx, 3				; is it a single character (plus 2 delimiters)?
	jne asmEval_single_quoted_string_literal_return_string	; no
	; we return a number
	mov bx, ASM_EVAL_TYPE_NUMBER			; "type is string"
	mov ch, 0
	mov cl, byte [ds:si+1]					; CX := ASCII value of character
	mov ax, 1								; "success"
	jmp asmEval_single_done
	
asmEval_single_quoted_string_literal_return_string:
	; we return a string
	call asm_get_quoted_string_literal_value	; fill in ES:DI with value
	mov bx, ASM_EVAL_TYPE_STRING				; "type is string"
	mov ax, 1									; "success"
	jmp asmEval_single_done

asmEval_single_number:
	call asm_multibase_number_atoi				; AX := 0 when not numeric
	cmp ax, 0
	je asmEval_single_number_variable_pass_0
	; it's a number
	mov cx, bx									; CX := the integer
	mov bx, ASM_EVAL_TYPE_NUMBER				; "type is numeric"
	mov ax, 1									; "success"
	jmp asmEval_single_done
	
asmEval_single_number_variable_pass_0:
	cmp byte [cs:asmPass], ASM_PASS_0			; during pass 0, we only check
	jne asmEval_single_number_variable			; variables proper
	; it's pass 0
	call asmNumericVars_get_handle_from_storage	; AX := handle
	jc asmEval_single_variable_not_found		; variable doesn't exist
	; variable exists, so get its value
	call asmNumericVars_get_value				; BX := value
	mov cx, bx									; CX := value
	jmp asmEval_single_number_variable_return
	
asmEval_single_number_variable:
	call asm_is_valid_variable_name_or_reserved_symbol
												; AX := 0 when not valid	
	cmp ax, 0
	je asmEval_single_bad_variable_name
	; is it resolvable as a reserved symbol?
	call asm_try_get_reserved_symbol_numeric_value	; AX := 0 when not
													; CX := numeric value
	cmp ax, 0
	je asmEval_single_number_variable_variable
	; it resolved as a reserved symbol, with value in CX
	jmp asmEval_single_number_variable_return
asmEval_single_number_variable_variable:
	; it's a valid variable name, so look it up

	cmp byte [cs:asmEvalDoNextEvalForcedToReadVariableStorage], 0
	je asmEval_single_number_variable_variable_use_wrapper
	
	call asmNumericVars_get_handle_from_storage	; AX := handle
	jmp asmEval_single_number_variable_variable_check_found
asmEval_single_number_variable_variable_use_wrapper:
	call asmNumericVars_get_handle_wrapper		; AX := handle
	
asmEval_single_number_variable_variable_check_found:
	jc asmEval_single_variable_not_found		; variable doesn't exist
	; variable exists, so get its value
	call asmNumericVars_get_value				; BX := value
	mov cx, bx									; CX := value
asmEval_single_number_variable_return:
	mov bx, ASM_EVAL_TYPE_NUMBER				; "type is numeric"
	mov ax, 1									; "success"
	jmp asmEval_single_done
	
asmEval_single_variable_not_found:
	; ERROR
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageVariableNotFound
	mov ax, 0						; "error"
	jmp asmEval_single_done
	
asmEval_single_bad_variable_name:
	; ERROR
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageInvalidVariableName
	mov ax, 0						; "error"
	jmp asmEval_single_done

asmEval_single_done:
	pop dx
	pop di
	pop si
	pop ds
	ret


%endif
