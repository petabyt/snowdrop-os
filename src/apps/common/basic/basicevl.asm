;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains expression evaluation routines for Snowdrop OS's 
; BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_EVAL_
%define _COMMON_BASIC_EVAL_


; Evaluates the specified instruction fragments (tokens), resolving 
; variables as needed, and producing a single resulting value.
; Cases:
;              string --> string
;              number --> number
;     string + number --> string
;     string + string --> string
;     number + string --> string
;     number [OPERATOR] number --> number
;     string = string --> number (equality comparison)
;     function string --> string
;     function string --> number
;     function number --> string
;     function number --> number
;            function --> number
;            function --> string
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
basicEval_do:
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
	cmp dh, 5
	je basicEval_do_six_tokens		; six tokens
	cmp dh, 3
	je basicEval_do_four_tokens		; four tokens
	cmp dh, 2
	je basicEval_do_three_tokens	; three tokens
	cmp dh, 1
	je basicEval_do_two_tokens		; two tokens
	cmp dh, 0
	je basicEval_do_one_token		; one token
	; unsupported number of tokens
	pop dx							; [1]
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	mov ax, 0						; "error"
	jmp basicEval_do_done
basicEval_do_two_tokens:
	pop dx							; [1]
	; <function> <argument>
	
	; get function type
	call basicEval_get_function_type	; BX := function
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalFunctionType], bx	; save function type
	
	; evaluate argument
	inc dl							; argument is in the second token
	mov di, basicEvalBuffer0		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalRightArgumentType], bx
	mov word [cs:basicEvalRightArgumentNumericValue], cx
	
	call basicEval_func_arg
	cmp ax, 0
	je basicEval_do_error
	jmp basicEval_do_success

basicEval_do_six_tokens:
	pop dx							; [1]
	; <function> <argument>, <argument>, <argument>
	
	; get function type
	call basicEval_get_function_type	; BX := function
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalFunctionType], bx	; save function type
	
	; evaluate first argument
	inc dl							; first argument is second token
	mov di, basicEvalBuffer0		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalLeftArgumentType], bx
	mov word [cs:basicEvalLeftArgumentNumericValue], cx

	; check that second token is a comma
	inc dl							; comma must be third token
	call basic_is_token_comma		; check that it is
	cmp ax, 0
	je basicEval_do_error_expected_func_arg_arg_arg
	
	; evaluate second argument
	inc dl							; second argument is fourth token
	mov di, basicEvalBuffer1		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalRightArgumentType], bx
	mov word [cs:basicEvalRightArgumentNumericValue], cx

	; check that fourth token is a comma
	inc dl							; comma must be fifth token
	call basic_is_token_comma		; check that it is
	cmp ax, 0
	je basicEval_do_error_expected_func_arg_arg_arg
	
	; evaluate third argument
	inc dl							; third argument is sixth token
	mov di, basicEvalBuffer2		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalThirdArgumentType], bx
	mov word [cs:basicEvalThirdArgumentNumericValue], cx
	
	call basicEval_func_arg_arg_arg
	cmp ax, 0
	je basicEval_do_error
	jmp basicEval_do_success
	
basicEval_do_four_tokens:
	pop dx							; [1]
	; <function> <argument>, <argument>
	
	; get function type
	call basicEval_get_function_type	; BX := function
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalFunctionType], bx	; save function type
	
	; evaluate first argument
	inc dl							; first argument is second token
	mov di, basicEvalBuffer0		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalLeftArgumentType], bx
	mov word [cs:basicEvalLeftArgumentNumericValue], cx

	; check that second token is a comma
	inc dl							; comma must be third token
	call basic_is_token_comma		; check that it is
	cmp ax, 0
	je basicEval_do_error_expected_func_arg_arg
	
	; evaluate second argument
	inc dl							; second argument is fourth token
	mov di, basicEvalBuffer1		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalRightArgumentType], bx
	mov word [cs:basicEvalRightArgumentNumericValue], cx

	call basicEval_func_arg_arg
	cmp ax, 0
	je basicEval_do_error
	jmp basicEval_do_success
	
basicEval_do_three_tokens:
	pop dx							; [1]
	; we evaluate <operand> <operator> <operand>
	inc dl							; operator is the second token
	call basicEval_get_operator_type	; BX := operator
	dec dl							; restore DL to first token
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalOperatorType], bx	; save operator type

	; evaluate left operand
	mov di, basicEvalBuffer0		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalLeftOperandType], bx
	mov word [cs:basicEvalLeftOperandNumericValue], cx
	
	; evaluate right operand
	add dl, 2						; right operand is third token
	mov di, basicEvalBuffer1		; ES:DI := string buffer
	call basicEval_single			; BX := token type, CX := numeric value
	sub dl, 2						; restore DL to first token
	cmp ax, 0
	je basicEval_do_error
	mov word [cs:basicEvalRightOperandType], bx
	mov word [cs:basicEvalRightOperandNumericValue], cx
	
	cmp word [cs:basicEvalLeftOperandType], BASIC_EVAL_TYPE_STRING
	je basicEval_do_three_tokens_left_string
	jmp basicEval_do_three_tokens_left_number
basicEval_do_three_tokens_left_number:
	cmp word [cs:basicEvalRightOperandType], BASIC_EVAL_TYPE_STRING
	je basicEval_do_three_tokens_left_number_right_string
	jmp basicEval_do_three_tokens_left_number_right_number
basicEval_do_three_tokens_left_string:
	cmp word [cs:basicEvalRightOperandType], BASIC_EVAL_TYPE_STRING
	je basicEval_do_three_tokens_left_string_right_string_equality_check
		; we check equality only when both operands are string
		; <string> <number> and <number> <string> branches convert the number
		; to a string, and then branch to <string> <string> SKIPPING
		; the equality check
		; NOTE: the reason for this is so that 1337 <> "1337"
	jmp basicEval_do_three_tokens_left_string_right_number

basicEval_do_three_tokens_left_string_right_string_equality_check:
	; <string> = <string>
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_EQUALS
	jne basicEval_do_three_tokens_left_string_right_string_inequality_check
	
	; compare the two strings
	mov bx, BASIC_EVAL_TYPE_NUMBER		; set up return values
	mov cx, BASIC_TRUE					; assume strings are equal
	
	mov si, basicEvalBuffer0			; left string...
	mov di, basicEvalBuffer1			; ...and right string...
	int 0BDh							; compare strings
	cmp ax, 0
	je basicEval_do_success				; they're equal and we've already
										; assumed that, so just return
	mov cx, BASIC_FALSE					; they're not equal
	jmp basicEval_do_success
	
basicEval_do_three_tokens_left_string_right_string_inequality_check:
	; <string> <> <string>
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_DIFFERENT
	jne basicEval_do_three_tokens_left_string_right_string
	
	; compare the two strings
	mov bx, BASIC_EVAL_TYPE_NUMBER		; set up return values
	mov cx, BASIC_FALSE					; assume strings are equal
	
	mov si, basicEvalBuffer0			; left string...
	mov di, basicEvalBuffer1			; ...and right string...
	int 0BDh							; compare strings
	cmp ax, 0
	je basicEval_do_success				; they're equal and we've already
										; assumed that, so just return
	mov cx, BASIC_TRUE					; they're not equal
	jmp basicEval_do_success
	
basicEval_do_three_tokens_left_string_right_string:
	; string <operand> string
	; example operands: +
	
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_PLUS
	jne basicEval_do_error_operator_not_supported
	
	; concatenate the two strings
	mov si, basicEvalBuffer0			; left string...
	mov dx, basicEvalBuffer1			; ...and right string...
	mov di, basicEvalBuffer2			; ...into buffer
	call common_string_concat			; concat DS:SI and FS:DX into ES:DI

	mov bx, BASIC_EVAL_TYPE_STRING		; set up return values
	jmp basicEval_do_success

basicEval_do_three_tokens_left_string_right_number:
	; string <operand> number
	; convert number to string
	mov ax, word [cs:basicEvalRightOperandNumericValue]
	mov si, basicEvalBuffer1			; destination
	call common_string_signed_16bit_int_itoa
	; we now have strings in both left and right buffers, so we can delegate
	; to the string-string branch
	jmp basicEval_do_three_tokens_left_string_right_string

basicEval_do_three_tokens_left_number_right_string:
	; number <operand> string
	; convert number to string
	mov ax, word [cs:basicEvalLeftOperandNumericValue]
	mov si, basicEvalBuffer0			; destination
	call common_string_signed_16bit_int_itoa
	; we now have strings in both left and right buffers, so we can delegate
	; to the string-string branch
	jmp basicEval_do_three_tokens_left_string_right_string

basicEval_do_three_tokens_left_number_right_number:
	; number <operand> number
	call basicEval_arithmetic		; CX := numeric value
	cmp ax, 0
	je basicEval_do_error			; error	
	mov bx, BASIC_EVAL_TYPE_NUMBER	; set up return values
	; CX already populated with numeric result
	jmp basicEval_do_success
	
basicEval_do_one_token:
	pop dx							; [1]
	; we evaluate a single token ( DH = DL )
	mov di, basicEvalBuffer0		; ES:DI := string buffer
	call basicEval_single
	
	; the above fills in register values in the same fashion as the
	; contract of this procedure
	jmp basicEval_do_done

basicEval_do_error_expected_func_arg_arg_arg:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFuncArgArgArg
	jmp basicEval_do_error
	
basicEval_do_error_expected_func_arg_arg:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFuncArgArg
	jmp basicEval_do_error
	
basicEval_do_error_operator_not_supported:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageOperatorNotSupported
	jmp basicEval_do_error
	
basicEval_do_success:
	mov ax, 1						; "success"
	jmp basicEval_do_done
basicEval_do_error:
	mov ax, 0						; "error"
basicEval_do_done:
	pop dx
	pop si
	pop fs
	pop ds
	ret


; Evaluates the function and argument already stored, resolving 
; variables as needed, and producing a single resulting value.
;
; NOTE: evaluates expressions of the form: ; <function> <argument>
;       <argument> can be either string or numeric
;       result can be either string or numeric
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - 0 when the result evaluated to a string
;			 1 when the result evaluated to a number
;		CX - numeric result, if applicable
;	 ES:DI - pointer to result string, if applicable
basicEval_func_arg:
	push ds
	push dx
	push si

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; ASSUMPTION: the following have been populated
	;     basicEvalFunctionType
	;     basicEvalBuffer0 (when argument type is string)
	;     basicEvalRightArgumentType
	;     basicEvalRightArgumentNumericValue (when argument type is numeric)
	;
	; ASSUMPTION:
	;     basicEvalBuffer1 and basicEvalBuffer2 can be clobbered by me

basicEval_func_arg_GUIIMAGEISSELECTED:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_GUIIMAGEISSELECTED
	jne basicEval_func_arg_GUIRADIOISSELECTED
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_argument_must_be_numeric
	; argument is of correct type
	
	mov ax, word [cs:basicEvalRightArgumentNumericValue]
	call common_gui_image_get_selected		; BX := 0 when unselected,
											; other value when checked
	mov cx, bx								; we return numeric result in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_GUIRADIOISSELECTED:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_GUIRADIOISSELECTED
	jne basicEval_func_arg_GUICHECKBOXISCHECKED
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_argument_must_be_numeric
	; argument is of correct type
	
	mov ax, word [cs:basicEvalRightArgumentNumericValue]
	call common_gui_radio_get_checked		; BX := 0 when unchecked,
											; other value when checked
	mov cx, bx								; we return numeric result in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_GUICHECKBOXISCHECKED:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_GUICHECKBOXISCHECKED
	jne basicEval_func_arg_BIN
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_argument_must_be_numeric
	; argument is of correct type
	
	mov ax, word [cs:basicEvalRightArgumentNumericValue]
	call common_gui_checkbox_get_checked	; BX := 0 when unchecked,
											; other value when checked
	mov cx, bx								; we return numeric result in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_BIN:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_BIN
	jne basicEval_func_arg_VAL
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_argument_must_be_string
	; argument is of correct type
	mov si, basicEvalBuffer0

	call basic_is_binary_number_string			; AX := 0 when not binary nr.
	cmp ax, 0
	je basicEval_func_arg_argument_must_be_string_containing_binary_number
	; argument is a string containing a binary number
	
	call basic_get_binary_number_string_value	; AX := the number
	mov cx, ax								; we return numeric result in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_VAL:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_VAL
	jne basicEval_func_arg_ASCII
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_argument_must_be_string
	; argument is of correct type
	mov si, basicEvalBuffer0

	call common_string_is_numeric				; AX := 0 when not numeric
	cmp ax, 0
	je basicEval_func_arg_argument_must_be_string_containing_number
	; argument is a string containing a number
	call basic_check_numeric_literal_overflow	; AX := 0 when overflow
	cmp ax, 0
	je basicEval_func_arg_integer_out_of_range
	; argument is a string containing a number that's within range
	
	call common_string_signed_16bit_int_atoi	; AX := the integer
	mov cx, ax								; we return numeric result in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_ASCII:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_ASCII
	jne basicEval_func_arg_CHR
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_argument_must_be_string
	; argument is of correct type
	mov si, basicEvalBuffer0
	int 0A5h								; BX := string length
	cmp bx, 1								; string must have one character
	jne basicEval_func_arg_argument_must_be_a_single_character_string
	; argument is a single-character string
	mov cl, byte [cs:si]					; CL := ASCII value of first char.
	mov ch, 0								; CX := ASCII value of first char.
											; we return numeric result in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_CHR:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_CHR
	jne basicEval_func_arg_NOT
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_argument_must_be_numeric
	; argument is of correct type
	
	mov ax, word [cs:basicEvalRightArgumentNumericValue]	; argument value
	cmp ax, 255
	ja basicEval_func_arg_argument_must_be_byte
	
	mov bx, BASIC_EVAL_TYPE_STRING		; indicate result type
	mov di, basicEvalBuffer1
	mov byte [es:di], al				; ASCII value goes into first character
	mov byte [es:di+1], 0				; terminator goes into the second one
	
	jmp basicEval_func_arg_success
	
basicEval_func_arg_NOT:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_NOT
	jne basicEval_func_arg_KEY
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_argument_must_be_numeric
	; argument is of correct type
	
	mov cx, BASIC_TRUE						; CX := result (assume true)
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	
	cmp word [cs:basicEvalRightArgumentNumericValue], 0	; is it false?
	je basicEval_func_arg_success			; our assumption was correct
	
	mov cx, BASIC_FALSE
	jmp basicEval_func_arg_success
	
basicEval_func_arg_KEY:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_KEY
	jne basicEval_func_arg_RND
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_argument_must_be_numeric
	; argument is of correct type
	mov bx, word [cs:basicEvalRightArgumentNumericValue]	; BX := argument
	cmp bx, 255
	ja basicEval_func_arg_argument_must_be_byte				; negative or word
	
	; since 0 <= BX <= 255, BL contains the scan code
	int 0BAh								; AL := 0 when key not pressed
	mov ah, 0								; AX := 0 when key not pressed
	
	mov cx, ax								; CX := result
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_RND:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_RND
	jne basicEval_func_arg_LEN
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_argument_must_be_numeric
	; argument is of correct type
	mov bx, word [cs:basicEvalRightArgumentNumericValue]	; BX := argument
	cmp bx, 0
	jle basicEval_func_arg_argument_must_be_positive		; error: negative
	
	; NOTE unsigned arithmetic from here on
	int 86h									; AX := random number
	mov dx, 0								; DX:AX := AX
	div bx									; AX := DX:AX div BX
											; DX := DX:AX mod BX
											; note: UNSIGNED DIVIDE
	and dx, 0111111111111111b				; clear sign bit to force positive
	; END of unsigned arithmetic
	mov cx, dx								; CX := result
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success
	
basicEval_func_arg_LEN:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_LEN
	jne basicEval_func_arg_unsupported
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_argument_must_be_string
	; argument is of correct type
	mov si, basicEvalBuffer0
	int 0A5h								; BX := string length
	mov cx, bx								; we return numeric result in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER			; indicate result type
	jmp basicEval_func_arg_success

	
basicEval_func_arg_argument_must_be_string_containing_binary_number:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustContainBinaryNumber
	jmp basicEval_func_arg_error

basicEval_func_arg_argument_must_be_string_containing_number:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBeStringContainingNumber
	jmp basicEval_func_arg_error
	
basicEval_func_arg_integer_out_of_range:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIntegerOutOfRange
	jmp basicEval_func_arg_error
	
basicEval_func_arg_argument_must_be_byte:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBeByte
	jmp basicEval_func_arg_error
	
basicEval_func_arg_argument_must_be_positive:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBePositive
	jmp basicEval_func_arg_error
	
basicEval_func_arg_argument_must_be_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBeNumeric
	jmp basicEval_func_arg_error
	
basicEval_func_arg_argument_must_be_string:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBeString
	jmp basicEval_func_arg_error
	
basicEval_func_arg_argument_must_be_a_single_character_string:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBeSingleCharacterString
	jmp basicEval_func_arg_error
	
basicEval_func_arg_unsupported:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnknownFunction
	jmp basicEval_func_arg_error
	
basicEval_func_arg_error:
	mov ax, 0
	jmp basicEval_func_arg_done
basicEval_func_arg_success:
	mov ax, 1
basicEval_func_arg_done:
	pop si
	pop dx
	pop ds
	ret
	
	
; Evaluates the function and arguments already stored, resolving 
; variables as needed, and producing a single resulting value.
;
; NOTE: evaluates expressions of the form: ; <function> <argument>, <argument>
;       <argument> can be either string or numeric
;       result can be either string or numeric
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - 0 when the result evaluated to a string
;			 1 when the result evaluated to a number
;		CX - numeric result, if applicable
;	 ES:DI - pointer to result string, if applicable
basicEval_func_arg_arg:
	push ds
	push dx
	push si

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; ASSUMPTION: the following have been populated
	;     basicEvalFunctionType
	;
	;     basicEvalBuffer0 (when first argument type is string)
	;     basicEvalLeftArgumentType
	;     basicEvalLeftArgumentNumericValue (when second argument type is numeric)
	;
	;     basicEvalBuffer1 (when second argument type is string)
	;     basicEvalRightArgumentType
	;     basicEvalRightArgumentNumericValue (when second argument type is numeric)
	;
	; ASSUMPTION:
	;     basicEvalBuffer1 and basicEvalBuffer2 can be clobbered by me
	
basicEval_func_arg_arg_STRINGAT:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_STRINGAT
	jne basicEval_func_arg_arg_CHARAT
	cmp word [cs:basicEvalLeftArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_arg_first_argument_must_be_string
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_second_argument_must_be_number
	; arguments are of correct type
	
	mov si, basicEvalBuffer0				; DS:SI := pointer to input string
	int 0A5h								; BX := string length
	cmp word [cs:basicEvalRightArgumentNumericValue], bx
											; unsigned comparison, so negative
											; values are seen as too large also
	jae basicEval_func_arg_arg_STRINGAT_out_of_bounds	; position is too large
	; arguments are within range
	
	add si, word [cs:basicEvalRightArgumentNumericValue]
	mov al, byte [ds:si]					; AL := character at position
	
	mov di, basicEvalBuffer2
	mov byte [cs:di], al
	mov byte [cs:di+1], 0					; we return a string
	mov bx, BASIC_EVAL_TYPE_STRING			; indicate result type
	jmp basicEval_func_arg_arg_success
	
basicEval_func_arg_arg_CHARAT:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_CHARAT
	jne basicEval_func_arg_arg_unsupported
	cmp word [cs:basicEvalLeftArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_first_argument_must_be_number
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_second_argument_must_be_number
	; arguments are of correct type
	cmp word [cs:basicEvalLeftArgumentNumericValue], BASIC_TEXT_SCREEN_ROW_COUNT
											; unsigned comparison, so negative
	jae basicEval_func_arg_arg_CHARAT_row_out_of_bounds	; values are invalid also
	
	cmp word [cs:basicEvalRightArgumentNumericValue], BASIC_TEXT_SCREEN_COLUMN_COUNT
											; unsigned comparison, so negative
	jae basicEval_func_arg_arg_CHARAT_col_out_of_bounds	; values are invalid also
	; perform
	mov ax, [cs:basicEvalLeftArgumentNumericValue]
	mov bh, al								; BH := row
	mov ax, [cs:basicEvalRightArgumentNumericValue]
	mov bl, al								; BL := column
	
	int 0B2h								; AL := character at row, column
	mov di, basicEvalBuffer2
	mov byte [cs:di], al
	mov byte [cs:di+1], 0					; we return a string
	mov bx, BASIC_EVAL_TYPE_STRING			; indicate result type
	jmp basicEval_func_arg_arg_success

basicEval_func_arg_arg_STRINGAT_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageStringAtPositionOutOfBounds
	jmp basicEval_func_arg_arg_error
	
basicEval_func_arg_arg_first_argument_must_be_string:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFirstArgumentMustBeString
	jmp basicEval_func_arg_arg_error
	
basicEval_func_arg_arg_CHARAT_row_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageCharAtRowOutOfBounds
	jmp basicEval_func_arg_arg_error
	
basicEval_func_arg_arg_CHARAT_col_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageCharAtColOutOfBounds
	jmp basicEval_func_arg_arg_error
	
basicEval_func_arg_arg_first_argument_must_be_number:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFirstArgumentMustBeNumber
	jmp basicEval_func_arg_arg_error
	
basicEval_func_arg_arg_second_argument_must_be_number:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSecondArgumentMustBeNumber
	jmp basicEval_func_arg_arg_error
	
basicEval_func_arg_arg_unsupported:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnknownFunction
	jmp basicEval_func_arg_arg_error
	
basicEval_func_arg_arg_error:
	mov ax, 0
	jmp basicEval_func_arg_arg_done
basicEval_func_arg_arg_success:
	mov ax, 1
basicEval_func_arg_arg_done:
	pop si
	pop dx
	pop ds
	ret


; Evaluates the function and arguments already stored, resolving 
; variables as needed, and producing a single resulting value.
;
; NOTE: evaluates expressions of the form: 
;           <function> <argument>, <argument>, <argument>
;       <argument> can be either string or numeric
;       result can be either string or numeric
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - 0 when the result evaluated to a string
;			 1 when the result evaluated to a number
;		CX - numeric result, if applicable
;	 ES:DI - pointer to result string, if applicable
basicEval_func_arg_arg_arg:
	push ds
	push dx
	push si

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; ASSUMPTION: the following have been populated
	;     basicEvalFunctionType
	;
	;     basicEvalBuffer0 (when first argument type is string)
	;     basicEvalLeftArgumentType
	;     basicEvalLeftArgumentNumericValue (when second argument type is numeric)
	;
	;     basicEvalBuffer1 (when second argument type is string)
	;     basicEvalRightArgumentType
	;     basicEvalRightArgumentNumericValue (when second argument type is numeric)
	;
	;     basicEvalBuffer2 (when second argument type is string)
	;     basicEvalThirdArgumentType
	;     basicEvalThirdArgumentNumericValue (when third argument type is numeric)
	;
	; ASSUMPTION:
	;     basicEvalBuffer1 and basicEvalBuffer2 can be clobbered by me

basicEval_func_arg_arg_arg_GUIIMAGEASCIIADD:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_GUIIMAGEASCIIADD
	jne basicEval_func_arg_arg_arg_GUIRADIOADD
	
	cmp word [cs:basicEvalLeftArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_arg_arg_first_argument_must_be_string	; character
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_second_argument_must_be_number	; X
	cmp word [cs:basicEvalThirdArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_third_argument_must_be_number	; Y
	; arguments are of correct types

	cmp word [cs:basicEvalRightArgumentNumericValue], COMMON_GRAPHICS_SCREEN_WIDTH-1
	ja basicEval_func_arg_arg_arg_X_out_of_bounds	; unsigned, also covers x<0
	
	cmp word [cs:basicEvalThirdArgumentNumericValue], COMMON_GRAPHICS_SCREEN_HEIGHT-1
	ja basicEval_func_arg_arg_arg_Y_out_of_bounds	; unsigned, also covers y<0
	; arguments are within bounds
	
	mov ax, word [cs:basicEvalRightArgumentNumericValue]	; AX := X
	mov bx, word [cs:basicEvalThirdArgumentNumericValue]	; BX := Y
	; this image will be ASCII-based, so these can contain garbage
	mov cx, 0FFFFh		; CX := image width
	mov dx, 0FFFFh		; DX := image height
	mov di, 0FFFFh		; DI := canvas width
	; since this image will be ASCII-based, we don't bother setting DS:SI
	; to a valid value (also because we don't have such a valid value)
	call common_gui_image_add

	push cs
	pop ds
	mov si, basicEvalBuffer0					; DS:SI := character string
	int 0A5h 									; BX := string length
	call gui_images_set_mode_ascii
	
	; set up callbacks
	mov si, basic_gui_image_left_click_callback
	call common_gui_image_left_click_callback_set
	mov si, basic_gui_image_right_click_callback
	call common_gui_image_right_click_callback_set
	mov si, basic_gui_image_selected_callback
	call common_gui_image_selected_callback_set
	
	mov cx, ax									; we return handle in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER				; indicate result type
	jmp basicEval_func_arg_arg_arg_success		; success
	
basicEval_func_arg_arg_arg_GUIRADIOADD:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_GUIRADIOADD
	jne basicEval_func_arg_arg_arg_GUICHECKBOXADD
	
	cmp word [cs:basicEvalLeftArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_arg_arg_first_argument_must_be_string	; label
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_second_argument_must_be_number	; X
	cmp word [cs:basicEvalThirdArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_third_argument_must_be_number	; Y
	; arguments are of correct types
	
	cmp word [cs:basicEvalRightArgumentNumericValue], COMMON_GRAPHICS_SCREEN_WIDTH-1
	ja basicEval_func_arg_arg_arg_X_out_of_bounds	; unsigned, also covers x<0
	
	cmp word [cs:basicEvalThirdArgumentNumericValue], COMMON_GRAPHICS_SCREEN_HEIGHT-1
	ja basicEval_func_arg_arg_arg_Y_out_of_bounds	; unsigned, also covers y<0
	; arguments are within bounds

	mov ax, word [cs:basicEvalRightArgumentNumericValue]	; AX := X
	mov bx, word [cs:basicEvalThirdArgumentNumericValue]	; BX := Y
	push cs
	pop ds
	mov si, basicEvalBuffer0					; DS:SI := pointer to label
	mov di, word [cs:basicCurrentRadioGroupId]	; DI := radio group ID
	call common_gui_radio_add_auto_scaled		; AX := UI element handle
	
	mov si, basic_gui_radio_change_callback
	call common_gui_radio_change_callback_set	; set callback
	
	mov cx, ax									; we return handle in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER				; indicate result type
	jmp basicEval_func_arg_arg_arg_success		; success
	
basicEval_func_arg_arg_arg_GUICHECKBOXADD:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_GUICHECKBOXADD
	jne basicEval_func_arg_arg_arg_GUIBUTTONADD
	
	cmp word [cs:basicEvalLeftArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_arg_arg_first_argument_must_be_string	; label
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_second_argument_must_be_number	; X
	cmp word [cs:basicEvalThirdArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_third_argument_must_be_number	; Y
	; arguments are of correct types
	
	cmp word [cs:basicEvalRightArgumentNumericValue], COMMON_GRAPHICS_SCREEN_WIDTH-1
	ja basicEval_func_arg_arg_arg_X_out_of_bounds	; unsigned, also covers x<0
	
	cmp word [cs:basicEvalThirdArgumentNumericValue], COMMON_GRAPHICS_SCREEN_HEIGHT-1
	ja basicEval_func_arg_arg_arg_Y_out_of_bounds	; unsigned, also covers y<0
	; arguments are within bounds

	mov ax, word [cs:basicEvalRightArgumentNumericValue]	; AX := X
	mov bx, word [cs:basicEvalThirdArgumentNumericValue]	; BX := Y
	push cs
	pop ds
	mov si, basicEvalBuffer0					; DS:SI := pointer to label
	call common_gui_checkbox_add_auto_scaled		; AX := UI element handle
	
	mov si, basic_gui_checkbox_change_callback
	call common_gui_checkbox_change_callback_set	; set callback
	
	mov cx, ax									; we return handle in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER				; indicate result type
	jmp basicEval_func_arg_arg_arg_success		; success
	
basicEval_func_arg_arg_arg_GUIBUTTONADD:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_GUIBUTTONADD
	jne basicEval_func_arg_arg_arg_SUBSTRING
	
	cmp word [cs:basicEvalLeftArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_arg_arg_first_argument_must_be_string	; label
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_second_argument_must_be_number	; X
	cmp word [cs:basicEvalThirdArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_third_argument_must_be_number	; Y
	; arguments are of correct types
	
	cmp word [cs:basicEvalRightArgumentNumericValue], COMMON_GRAPHICS_SCREEN_WIDTH-1
	ja basicEval_func_arg_arg_arg_X_out_of_bounds	; unsigned, also covers x<0
	
	cmp word [cs:basicEvalThirdArgumentNumericValue], COMMON_GRAPHICS_SCREEN_HEIGHT-1
	ja basicEval_func_arg_arg_arg_Y_out_of_bounds	; unsigned, also covers y<0
	; arguments are within bounds

	mov ax, word [cs:basicEvalRightArgumentNumericValue]	; AX := X
	mov bx, word [cs:basicEvalThirdArgumentNumericValue]	; BX := Y
	push cs
	pop ds
	mov si, basicEvalBuffer0					; DS:SI := pointer to label
	call common_gui_button_add_auto_scaled		; AX := UI element handle
	
	mov si, basic_gui_button_click_callback
	call common_gui_button_click_callback_set	; set callback
	
	mov cx, ax									; we return handle in CX
	mov bx, BASIC_EVAL_TYPE_NUMBER				; indicate result type
	jmp basicEval_func_arg_arg_arg_success		; success
	
basicEval_func_arg_arg_arg_SUBSTRING:
	cmp word [cs:basicEvalFunctionType], BASIC_FUNCTION_SUBSTRING
	jne basicEval_func_arg_arg_arg_unsupported
	cmp word [cs:basicEvalLeftArgumentType], BASIC_EVAL_TYPE_STRING
	jne basicEval_func_arg_arg_arg_first_argument_must_be_string
	cmp word [cs:basicEvalRightArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_second_argument_must_be_number
	cmp word [cs:basicEvalThirdArgumentType], BASIC_EVAL_TYPE_NUMBER
	jne basicEval_func_arg_arg_arg_third_argument_must_be_number
	; arguments are of correct type
	cmp word [cs:basicEvalRightArgumentNumericValue], 0
	jl basicEval_func_arg_arg_arg_SUBSTRING_start_index_must_be_nonnegative
	cmp word [cs:basicEvalThirdArgumentNumericValue], 0
	jl basicEval_func_arg_arg_arg_SUBSTRING_length_must_be_nonnegative
	; start index and length are not negative
	
	mov ax, word [cs:basicEvalRightArgumentNumericValue]
	add ax, word [cs:basicEvalThirdArgumentNumericValue]
	
	mov si, basicEvalBuffer0
	int 0A5h								; BX := string length
	cmp ax, bx
	ja basicEval_func_arg_arg_arg_SUBSTRING_overrun	; we'd overrun the string

	; perform
	; here, DS:SI = pointer to input string
	mov di, basicEvalBuffer2				; ES:DI := pointer to destination
	mov bx, word [cs:basicEvalRightArgumentNumericValue]	; BX := start
	mov cx, word [cs:basicEvalThirdArgumentNumericValue]	; CX := length
	call common_string_substring
	mov bx, BASIC_EVAL_TYPE_STRING			; indicate result type
	jmp basicEval_func_arg_arg_arg_success

basicEval_func_arg_arg_arg_first_argument_must_contain_one_char:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFirstArgMustBeASingleCharString
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_X_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiXOutOfBounds
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_Y_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiYOutOfBounds
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_SUBSTRING_overrun:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSubstringOverrun
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_SUBSTRING_length_must_be_nonnegative:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSubstringLengthMustBeNonnegative
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_SUBSTRING_start_index_must_be_nonnegative:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSubstringIndexMustBeNonnegative
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_third_argument_must_be_number:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageThirdArgumentMustBeNumber
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_second_argument_must_be_number:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSecondArgumentMustBeNumber
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_first_argument_must_be_number:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFirstArgumentMustBeNumber
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_first_argument_must_be_string:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFirstArgumentMustBeString
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_unsupported:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnknownFunction
	jmp basicEval_func_arg_arg_arg_error
	
basicEval_func_arg_arg_arg_error:
	mov ax, 0
	jmp basicEval_func_arg_arg_arg_done
basicEval_func_arg_arg_arg_success:
	mov ax, 1
basicEval_func_arg_arg_arg_done:
	pop si
	pop dx
	pop ds
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
basicEval_arithmetic:
	push ds
	push es
	push bx
	push dx
	push si
	push di

basicEval_arithmetic_BITROTATER:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_BITROTATER
	jne basicEval_arithmetic_BITROTATEL
	cmp word [cs:basicEvalRightOperandNumericValue], 255
	ja basicEval_arithmetic_rotate_amount_must_be_byte
	
	mov ax, word [cs:basicEvalLeftOperandNumericValue]
	mov cx, word [cs:basicEvalRightOperandNumericValue]
	ror ax, cl
	mov cx, ax
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_BITROTATEL:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_BITROTATEL
	jne basicEval_arithmetic_BITSHIFTR
	cmp word [cs:basicEvalRightOperandNumericValue], 255
	ja basicEval_arithmetic_rotate_amount_must_be_byte
	
	mov ax, word [cs:basicEvalLeftOperandNumericValue]
	mov cx, word [cs:basicEvalRightOperandNumericValue]
	rol ax, cl
	mov cx, ax
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_BITSHIFTR:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_BITSHIFTR
	jne basicEval_arithmetic_BITSHIFTL
	cmp word [cs:basicEvalRightOperandNumericValue], 255
	ja basicEval_arithmetic_shift_amount_must_be_byte
	
	mov ax, word [cs:basicEvalLeftOperandNumericValue]
	mov cx, word [cs:basicEvalRightOperandNumericValue]
	shr ax, cl
	mov cx, ax
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_BITSHIFTL:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_BITSHIFTL
	jne basicEval_arithmetic_BITXOR
	cmp word [cs:basicEvalRightOperandNumericValue], 255
	ja basicEval_arithmetic_shift_amount_must_be_byte
	
	mov ax, word [cs:basicEvalLeftOperandNumericValue]
	mov cx, word [cs:basicEvalRightOperandNumericValue]
	shl ax, cl
	mov cx, ax
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_BITXOR:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_BITXOR
	jne basicEval_arithmetic_BITOR
	
	mov cx, word [cs:basicEvalLeftOperandNumericValue]
	xor cx, word [cs:basicEvalRightOperandNumericValue]
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_BITOR:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_BITOR
	jne basicEval_arithmetic_BITAND
	
	mov cx, word [cs:basicEvalLeftOperandNumericValue]
	or cx, word [cs:basicEvalRightOperandNumericValue]
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_BITAND:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_BITAND
	jne basicEval_arithmetic_AND
	
	mov cx, word [cs:basicEvalLeftOperandNumericValue]
	and cx, word [cs:basicEvalRightOperandNumericValue]
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_AND:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_AND
	jne basicEval_arithmetic_OR
	
	mov cx, BASIC_FALSE				; assume false
	cmp word [cs:basicEvalLeftOperandNumericValue], 0
	je basicEval_arithmetic_success	; it is false
	cmp word [cs:basicEvalRightOperandNumericValue], 0
	je basicEval_arithmetic_success	; it is false

	mov cx, BASIC_TRUE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_OR:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_OR
	jne basicEval_arithmetic_XOR
	
	mov cx, BASIC_TRUE					; assume true
	cmp word [cs:basicEvalLeftOperandNumericValue], 0
	jne basicEval_arithmetic_success	; it is true
	cmp word [cs:basicEvalRightOperandNumericValue], 0
	jne basicEval_arithmetic_success	; it is true

	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_XOR:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_XOR
	jne basicEval_arithmetic_different
	mov cx, BASIC_TRUE					; assume true
	cmp word [cs:basicEvalLeftOperandNumericValue], 0
	je basicEval_arithmetic_XOR_left_false
basicEval_arithmetic_XOR_left_true:
	cmp word [cs:basicEvalRightOperandNumericValue], 0
	je basicEval_arithmetic_success
	; both are true
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
basicEval_arithmetic_XOR_left_false:
	cmp word [cs:basicEvalRightOperandNumericValue], 0
	jne basicEval_arithmetic_success
	; both are false
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_different:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_DIFFERENT
	jne basicEval_arithmetic_less_or_equal
	; check whether left operand is different than the right operand
	mov cx, BASIC_TRUE
	mov bx, word [cs:basicEvalLeftOperandNumericValue]
	cmp bx, word [cs:basicEvalRightOperandNumericValue]
	jne basicEval_arithmetic_success
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_less_or_equal:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_LESSOREQUAL
	jne basicEval_arithmetic_greater_or_equal
	; check whether left operand is less than or equal to the right operand
	mov cx, BASIC_TRUE
	mov bx, word [cs:basicEvalLeftOperandNumericValue]
	cmp bx, word [cs:basicEvalRightOperandNumericValue]
	jle basicEval_arithmetic_success
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_greater_or_equal:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_GREATEROREQUAL
	jne basicEval_arithmetic_greater
	; check whether left operand is greater than or equal to the right operand
	mov cx, BASIC_TRUE
	mov bx, word [cs:basicEvalLeftOperandNumericValue]
	cmp bx, word [cs:basicEvalRightOperandNumericValue]
	jge basicEval_arithmetic_success
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_greater:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_GREATER
	jne basicEval_arithmetic_less
	; check whether left operand is greater than right operand
	mov cx, BASIC_TRUE
	mov bx, word [cs:basicEvalLeftOperandNumericValue]
	cmp bx, word [cs:basicEvalRightOperandNumericValue]
	jg basicEval_arithmetic_success
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_less:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_LESS
	jne basicEval_arithmetic_equality
	; check whether left operand is less than right operand
	mov cx, BASIC_TRUE
	mov bx, word [cs:basicEvalLeftOperandNumericValue]
	cmp bx, word [cs:basicEvalRightOperandNumericValue]
	jl basicEval_arithmetic_success
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_equality:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_EQUALS
	jne basicEval_arithmetic_addition
	; check equality between the two operands
	mov cx, BASIC_TRUE
	mov bx, word [cs:basicEvalLeftOperandNumericValue]
	cmp bx, word [cs:basicEvalRightOperandNumericValue]
	je basicEval_arithmetic_success
	mov cx, BASIC_FALSE
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_addition:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_PLUS
	jne basicEval_arithmetic_subtraction
	; add the two operands
	mov cx, word [cs:basicEvalLeftOperandNumericValue]
	add cx, word [cs:basicEvalRightOperandNumericValue]
	jo basicEval_arithmetic_out_of_range		; overflow
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_subtraction:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_MINUS
	jne basicEval_arithmetic_multiplication
	; subtract the two operands
	mov cx, word [cs:basicEvalLeftOperandNumericValue]
	sub cx, word [cs:basicEvalRightOperandNumericValue]
	jo basicEval_arithmetic_out_of_range		; overflow
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_multiplication:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_MULTIPLY
	jne basicEval_arithmetic_integer_division
	; multiply the two operands
	mov ax, word [cs:basicEvalLeftOperandNumericValue]
	mov cx, word [cs:basicEvalRightOperandNumericValue]
	imul cx										; DX:AX := AX*CX
	mov cx, ax									; return it in CX
	jo basicEval_arithmetic_out_of_range		; overflow
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_integer_division:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_DIVIDE
	jne basicEval_arithmetic_modulo
	; prevent division by zero
	cmp word [cs:basicEvalRightOperandNumericValue], 0
	je basicEval_arithmetic_divide_by_zero
	; find the quotient of the two operands
	mov ax, word [cs:basicEvalLeftOperandNumericValue]	;    AX := dividend
	cwd													; DX:AX := dividend
	mov cx, word [cs:basicEvalRightOperandNumericValue]	; CX := divisor
	idiv cx										; AX := DX:AX div CX
	mov cx, ax									; return it in CX
	jo basicEval_arithmetic_out_of_range		; overflow
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_modulo:
	cmp word [cs:basicEvalOperatorType], BASIC_OPERATOR_MODULO
	jne basicEval_arithmetic_unsupported
	; prevent division by zero
	cmp word [cs:basicEvalRightOperandNumericValue], 0
	je basicEval_arithmetic_divide_by_zero
	; find the quotient of the two operands
	mov ax, word [cs:basicEvalLeftOperandNumericValue]	;    AX := dividend
	cwd													; DX:AX := dividend
	mov cx, word [cs:basicEvalRightOperandNumericValue]	; CX := divisor
	idiv cx										; DX := DX:AX mod CX
	mov cx, dx									; return it in CX
	jo basicEval_arithmetic_out_of_range		; overflow
	jmp basicEval_arithmetic_success
	
basicEval_arithmetic_shift_amount_must_be_byte:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageShiftAmountMustBeByte
	jmp basicEval_arithmetic_error

basicEval_arithmetic_rotate_amount_must_be_byte:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageRotateAmountMustBeByte
	jmp basicEval_arithmetic_error
	
basicEval_arithmetic_unsupported:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnknownOperator
	jmp basicEval_arithmetic_error
	
basicEval_arithmetic_out_of_range:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIntegerOutOfRange
	jmp basicEval_arithmetic_error
	
basicEval_arithmetic_divide_by_zero:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIntegerDivideByZero
	jmp basicEval_arithmetic_error
	
basicEval_arithmetic_error:
	mov ax, 0							; "error"
	jmp basicEval_arithmetic_done
basicEval_arithmetic_success:
	mov ax, 1							; "success"
basicEval_arithmetic_done:
	pop di
	pop si
	pop dx
	pop bx
	pop es
	pop ds
	ret


; Evaluates the specified instruction fragment (token), returning the
; type of function contained within.
;
; input:
;		DL - index of instruction token to consider
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - function type
basicEval_get_function_type:
	push ds
	push es
	push cx
	push dx
	push si
	push di
	
	mov bl, dl
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov ax, cs
	mov ds, ax
	mov es, ax

basicEval_get_function_type_GUIIMAGEISSELECTED:
	mov bx, BASIC_FUNCTION_GUIIMAGEISSELECTED		; return value
	mov si, basicFunctionGuiImageIsSelected
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_GUIIMAGEASCIIADD:
	mov bx, BASIC_FUNCTION_GUIIMAGEASCIIADD		; return value
	mov si, basicFunctionGuiImageAsciiAdd
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_GUIRADIOISSELECTED:
	mov bx, BASIC_FUNCTION_GUIRADIOISSELECTED		; return value
	mov si, basicFunctionGuiRadioIsSelected
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_GUIRADIOADD:
	mov bx, BASIC_FUNCTION_GUIRADIOADD		; return value
	mov si, basicFunctionGuiRadioAdd
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_GUICHECKBOXISCHECKED:
	mov bx, BASIC_FUNCTION_GUICHECKBOXISCHECKED		; return value
	mov si, basicFunctionGuiCheckboxIsChecked
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_GUICHECKBOXADD:
	mov bx, BASIC_FUNCTION_GUICHECKBOXADD		; return value
	mov si, basicFunctionGuiCheckboxAdd
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_GUIACTIVEELEMENTID:
	mov bx, BASIC_FUNCTION_GUIACTIVEELEMENTID		; return value
	mov si, basicFunctionGuiActiveElementId
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_GUIBUTTONADD:
	mov bx, BASIC_FUNCTION_GUIBUTTONADD		; return value
	mov si, basicFunctionGuiButtonAdd
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_STRINGAT:
	mov bx, BASIC_FUNCTION_STRINGAT		; return value
	mov si, basicFunctionStringAt
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_SUBSTRING:
	mov bx, BASIC_FUNCTION_SUBSTRING		; return value
	mov si, basicFunctionSubstring
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_CHARAT:
	mov bx, BASIC_FUNCTION_CHARAT		; return value
	mov si, basicFunctionCharAt
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_SERIALDATAAVAIL:
	mov bx, BASIC_FUNCTION_SERIALDATAAVAIL		; return value
	mov si, basicFunctionSerialDataAvail
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_BIN:
	mov bx, BASIC_FUNCTION_BIN		; return value
	mov si, basicFunctionBin
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_VAL:
	mov bx, BASIC_FUNCTION_VAL		; return value
	mov si, basicFunctionVal
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_ASCII:
	mov bx, BASIC_FUNCTION_ASCII	; return value
	mov si, basicFunctionAscii
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_CHR:
	mov bx, BASIC_FUNCTION_CHR		; return value
	mov si, basicFunctionChr
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_NOT:
	mov bx, BASIC_FUNCTION_NOT		; return value
	mov si, basicFunctionNot
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_KEY:
	mov bx, BASIC_FUNCTION_KEY		; return value
	mov si, basicFunctionKey
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_RND:
	mov bx, BASIC_FUNCTION_RND		; return value
	mov si, basicFunctionRnd
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success
	
basicEval_get_function_type_LEN:
	mov bx, BASIC_FUNCTION_LEN		; return value
	mov si, basicFunctionLen
	int 0BDh
	cmp ax, 0
	je basicEval_get_function_type_success

basicEval_get_function_type_error:
	; ERROR: function not supported
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnknownFunction
	mov ax, 0							; "error"
	jmp basicEval_get_function_type_done
basicEval_get_function_type_success:
	mov ax, 1							; "success"
basicEval_get_function_type_done:
	pop di
	pop si
	pop dx
	pop cx
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
;		BX - operator type (0 for +, 1 for -, 2 for /, 3 for *, 4 for %)
basicEval_get_operator_type:
	push ds
	push es
	push cx
	push dx
	push si
	push di
	
	mov bl, dl
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov ax, cs
	mov ds, ax
	mov es, ax

basicEval_get_operator_type_BITROTATER:
	mov bx, BASIC_OPERATOR_BITROTATER			; return value
	mov si, basicOperatorBitRotateR
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_BITROTATEL:
	mov bx, BASIC_OPERATOR_BITROTATEL			; return value
	mov si, basicOperatorBitRotateL
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_BITSHIFTR:
	mov bx, BASIC_OPERATOR_BITSHIFTR			; return value
	mov si, basicOperatorBitShiftR
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_BITSHIFTL:
	mov bx, BASIC_OPERATOR_BITSHIFTL			; return value
	mov si, basicOperatorBitShiftL
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_BITXOR:
	mov bx, BASIC_OPERATOR_BITXOR				; return value
	mov si, basicOperatorBitXor
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_BITOR:
	mov bx, BASIC_OPERATOR_BITOR				; return value
	mov si, basicOperatorBitOr
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_BITAND:
	mov bx, BASIC_OPERATOR_BITAND				; return value
	mov si, basicOperatorBitAnd
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_XOR:
	mov bx, BASIC_OPERATOR_XOR				; return value
	mov si, basicOperatorXor
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_OR:
	mov bx, BASIC_OPERATOR_OR				; return value
	mov si, basicOperatorOr
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_AND:
	mov bx, BASIC_OPERATOR_AND				; return value
	mov si, basicOperatorAnd
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_different:
	mov bx, BASIC_OPERATOR_DIFFERENT		; return value
	mov si, basicOperatorDifferent
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_greaterorequal:
	mov bx, BASIC_OPERATOR_GREATEROREQUAL	; return value
	mov si, basicOperatorGreaterOrEqual
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_lessorequal:
	mov bx, BASIC_OPERATOR_LESSOREQUAL	; return value
	mov si, basicOperatorLessOrEqual
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_greater:
	mov bx, BASIC_OPERATOR_GREATER		; return value
	mov si, basicOperatorGreater
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_less:
	mov bx, BASIC_OPERATOR_LESS			; return value
	mov si, basicOperatorLess
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_equals:
	mov bx, BASIC_OPERATOR_EQUALS		; return value
	mov si, basicOperatorEquals
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_plus:
	mov bx, BASIC_OPERATOR_PLUS			; return value
	mov si, basicOperatorPlus
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_minus:
	mov bx, BASIC_OPERATOR_MINUS		; return value
	mov si, basicOperatorMinus
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_divide:
	mov bx, BASIC_OPERATOR_DIVIDE		; return value
	mov si, basicOperatorDivide
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_multiply:
	mov bx, BASIC_OPERATOR_MULTIPLY		; return value
	mov si, basicOperatorMultiply
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success
basicEval_get_operator_type_modulo:
	mov bx, BASIC_OPERATOR_MODULO		; return value
	mov si, basicOperatorModulo
	int 0BDh
	cmp ax, 0
	je basicEval_get_operator_type_success

basicEval_get_operator_type_error:
	; ERROR: operator not supported
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnknownOperator
	mov ax, 0							; "error"
	jmp basicEval_get_operator_type_done
basicEval_get_operator_type_success:
	mov ax, 1							; "success"
basicEval_get_operator_type_done:
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
;     - quoted string literal --> string
;     -       string variable --> string
;     -                number --> number
;     -       number variable --> number
;     -              function --> string
;     -              function --> number
;
; input:
;		DL - index of instruction token to consider
;	 ES:DI - pointer to buffer where string values are accumulated
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - 0 when the result evaluated to a string
;			 1 when the result evaluated to a number
;		CX - numeric result, if applicable
basicEval_single:
	push ds
	push si
	push di
	push dx

	mov bl, dl
	push di					; [1]
	call basicInterpreter_get_instruction_token_near_ptr
	mov si, di				; SI := near pointer to instruction token string
	push cs
	pop ds					; DS:SI := pointer to instruction token string
	pop di					; [1]

	; now determine its type
	
	; first try to see if it's a parameterless function
basicEval_single_parameterless_function:
	call basicEval_get_function_type	; BX := function type (using passed-in
										; instruction token index in DL)
	cmp ax, 0							; error?
	je basicEval_single_parameterless_function_end	; yes, so it's not a function
	; it's a function, so now try to see which one (of the parameterless ones)

basicEval_single_parameterless_function_GUIACTIVEELEMENTID:
	cmp bx, BASIC_FUNCTION_GUIACTIVEELEMENTID
	jne basicEval_single_parameterless_function_SERIALDATAAVAIL
	mov cx, word [cs:basicGuiActiveElementId]	; return the numeric result
	mov bx, BASIC_EVAL_TYPE_NUMBER				; "type is numeric"
	mov ax, 1									; "success"
	jmp basicEval_single_done
	
basicEval_single_parameterless_function_SERIALDATAAVAIL:
	cmp bx, BASIC_FUNCTION_SERIALDATAAVAIL
	jne basicEval_single_parameterless_function_end
	mov cx, 0							; assume no byte available
	call common_queue_get_length_atomic
	cmp ax, 0							; is the queue empty?
	je basicEval_single_parameterless_function_SERIALDATAAVAIL_done
	mov cx, 1							; byte is available
basicEval_single_parameterless_function_SERIALDATAAVAIL_done:
	mov bx, BASIC_EVAL_TYPE_NUMBER				; "type is numeric"
	mov ax, 1									; "success"
	jmp basicEval_single_done

basicEval_single_parameterless_function_end:
basicEval_single_quoted_string_literal:
	call basic_is_valid_quoted_string_literal	; AX := 0 when not a QSL
	cmp ax, 0
	je basicEval_single_number
	; it's a quoted string literal
	call basic_get_quoted_string_literal_value	; fill in ES:DI with value
	mov bx, BASIC_EVAL_TYPE_STRING				; "type is string"
	mov ax, 1									; "success"
	jmp basicEval_single_done

basicEval_single_number:
	call common_string_is_numeric				; AX := 0 when not numeric
	cmp ax, 0
	je basicEval_single_string_variable
	; it's a number
	; first check that it wouldn't overflow when atoi'd
	call basic_check_numeric_literal_overflow	; AX := 0 when would overflow
	cmp ax, 0
	je basicEval_single_numeric_literal_overflow	; error
	; it's a number that won't overflow
	call common_string_signed_16bit_int_atoi	; AX := the integer
	mov cx, ax									; CX := the integer
	mov bx, BASIC_EVAL_TYPE_NUMBER				; "type is numeric"
	mov ax, 1									; "success"
	jmp basicEval_single_done

basicEval_single_string_variable:
	call basic_is_valid_variable_name			; AX := 0 when not valid
	cmp ax, 0
	je basicEval_single_bad_variable_name
	; it's a valid variable name, so look it up
	call basicStringVars_get_handle				; AX := handle
	jc basicEval_single_number_variable			; not a string variable
												; ...try numeric
	; variable exists, so get its value
	call basicStringVars_get_value				; fill in ES:DI with value
	mov bx, BASIC_EVAL_TYPE_STRING				; "type is string"
	mov ax, 1									; "success"
	jmp basicEval_single_done
	
basicEval_single_number_variable:
	call basic_is_valid_variable_name			; AX := 0 when not valid
	cmp ax, 0
	je basicEval_single_bad_variable_name
	; it's a valid variable name, so look it up
	call basicNumericVars_get_handle			; AX := handle
	jc basicEval_single_variable_not_found		; variable doesn't exist
	; variable exists, so get its value
	call basicNumericVars_get_value				; BX := value
	mov cx, bx									; CX := value
	mov bx, BASIC_EVAL_TYPE_NUMBER				; "type is numeric"
	mov ax, 1									; "success"
	jmp basicEval_single_done

basicEval_single_numeric_literal_overflow:
	; ERROR
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIntegerOutOfRange
	mov ax, 0						; "error"
	jmp basicEval_single_done
	
basicEval_single_variable_not_found:
	; ERROR
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariableNotFound
	mov ax, 0						; "error"
	jmp basicEval_single_done
	
basicEval_single_bad_variable_name:
	; ERROR
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageInvalidVariableName
	mov ax, 0						; "error"
	jmp basicEval_single_done

basicEval_single_done:
	pop dx
	pop di
	pop si
	pop ds
	ret


%endif
