;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains token interpretation routines for Snowdrop OS's 
; BASIC interpreter.
; Essentially, this is the engine behind the BASIC interpreter. Is it a state
; machine that is invoked for each token parsed out of the program text.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_INTERPRETATION_
%define _COMMON_BASIC_INTERPRETATION_


; Processes the specified token
;
; input:
;	 DS:SI - pointer to current continue point in the program text
; output:
;		AX - 0 when interpretation must halt, other value otherwise
;	 DS:SI - pointer to new continue point in the program text
;			 NOTE: the purpose of this pointer is to allow for branching;
;				   however, most invocations will return the unmodified
;				   passed-in pointer
basicInterpreter_process:
	push ds
	pusha
	
	mov word [cs:basicInterpreterParserResumePoint], si	; save continue point
	
	push cs
	pop ds
	mov si, basicCurrentToken			; DS:SI := pointer to current token
	
	cmp byte [cs:basicState], BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
	je basicInterpreter_process_k_n_l
	
	cmp byte [cs:basicState], BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE
	je basicInterpreter_process_k_n

	cmp byte [cs:basicState], BASIC_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	je basicInterpreter_process_id_n_frag
	
	; ERROR: invalid state
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageInvalidState
	jmp basicInterpreter_process_invalid
basicInterpreter_process_k_n_l:
	; is it a label?
	call basic_is_valid_label
	cmp ax, 0
	jne basicInterpreter_process_label		; it's a label
	; is it a keyword?
	call basic_is_valid_keyword
	cmp ax, 0
	jne basicInterpreter_process_keyword	; it's a keyword
	; is it a newline?
	call basic_is_valid_newline
	cmp ax, 0
	jne basicInterpreter_process_newline	; it's a newline
	; ERROR: token is of none of the possible types for this state
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageExpectedKeywordOrNewlineOrLabel
	jmp basicInterpreter_process_invalid
basicInterpreter_process_k_n:
	; is it a keyword?
	call basic_is_valid_keyword
	cmp ax, 0
	jne basicInterpreter_process_keyword	; it's a keyword
	; is it a newline?
	call basic_is_valid_newline
	cmp ax, 0
	jne basicInterpreter_process_newline	; it's a newline
	; ERROR: token is of none of the possible types for this state
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageExpectedKeywordOrNewline
	jmp basicInterpreter_process_invalid
basicInterpreter_process_id_n_frag:
	; is it an instruction delimiter?
	call basic_is_valid_instruction_delimiter
	cmp ax, 0
	jne basicInterpreter_process_instruction_delimiter	; it's an inst. delim.
	; is it a newline?
	call basic_is_valid_newline
	cmp ax, 0
	jne basicInterpreter_process_newline	; it's a newline
	; treat all others are instruction fragments
	jmp basicInterpreter_process_instruction_fragment

basicInterpreter_process_label:
	call basicInterpreter_token_label
	cmp ax, 0								; was there an error?
	je basicInterpreter_process_invalid		; yes
	jmp basicInterpreter_process_valid		; no
	
basicInterpreter_process_keyword:
	call basicInterpreter_token_keyword
	jmp basicInterpreter_process_valid
	
basicInterpreter_process_newline:
	call basicInterpreter_token_newline
	cmp ax, 0								; was there an error?
	je basicInterpreter_process_invalid		; yes
	jmp basicInterpreter_process_valid		; no
	
basicInterpreter_process_instruction_delimiter:
	call basicInterpreter_token_instruction_delimiter
	cmp ax, 0								; was there an error?
	je basicInterpreter_process_invalid		; yes
	jmp basicInterpreter_process_valid		; no
	
basicInterpreter_process_instruction_fragment:
	call basicInterpreter_token_instruction_fragment
	cmp ax, 0								; was there an error?
	je basicInterpreter_process_invalid		; yes
	jmp basicInterpreter_process_valid		; no

basicInterpreter_process_valid:	
	popa
	pop ds
	mov si, word [cs:basicInterpreterParserResumePoint]	; restore resume point
	mov ax, 1							; return success
	ret
basicInterpreter_process_invalid:
	popa
	pop ds
	mov si, word [cs:basicInterpreterParserResumePoint]	; restore resume point
	mov ax, 0							; return error
	ret

	
; Processes the current token, guaranteed to be valid for the current state.
; The current token type is guaranteed to be label.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicInterpreter_token_label:
	push ds
	push si
	push bx
	push dx
	
	; labels must be unique
	push word [cs:basicProgramTextSeg]
	pop ds
	mov si, word [cs:basicProgramTextOff]	; DS:SI := beginning of program
	
	mov dx, cs
	mov bx, basicCurrentToken				; DX:BX := pointer to token
	call basic_is_unique_label				; AX := 0 when label is not unique
	cmp ax, 0
	jne basicInterpreter_token_label_valid	; it's unique, so it's valid
	
	; it's invalid, so set the error message
	; AX already indicates error from result above
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageLabelNotUnique
basicInterpreter_token_label_valid:
	; labels prevent an immediately subsequent label from being valid
	mov byte [cs:basicState], BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE
	
	pop dx
	pop bx
	pop si
	pop ds
	ret


; Processes the current token, guaranteed to be valid for the current state.
; The token is an instruction fragment, part of the current instruction.
;
; NOTE: whether the token is valid given the current keyword is determined
;       later, once the instruction is executed
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicInterpreter_token_instruction_fragment:
	; check if we reached the limit
	cmp byte [cs:basicCurrentInstTokenCount], BASIC_MAX_INSTRUCTION_TOKENS
	jb basicInterpreter_token_instruction_fragment_perform	; we haven't
	; no room to store this instruction fragment
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageTooManyInstructionTokens
	mov ax, 0							; "there was an error"
	ret
basicInterpreter_token_instruction_fragment_perform:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; copy current token into the corresponding instruction fragment slot
	mov bl, byte [cs:basicCurrentInstTokenCount]
	call basicInterpreter_get_instruction_token_near_ptr
									; DI := pointer to instruction token string
	mov si, basicCurrentToken
	call common_string_copy			; copy it
	
	inc byte [cs:basicCurrentInstTokenCount]	; we've added one
	
	pop es
	pop ds
	popa
	mov ax, 1							; "success"
	ret

	
; Processes the current token, guaranteed to be valid for the current state.
; The current token type is guaranteed to be newline.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicInterpreter_token_newline:
	; newlines either do nothing or complete an instruction, causing it to 
	; be executed
	mov ax, 1								; "no error"
	
	cmp byte [cs:basicState], BASIC_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	jne basicInterpreter_token_newline_done
	call basicInterpreter_execute_accumulated
	mov byte [cs:basicState], BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
basicInterpreter_token_newline_done:	
	ret
	
	
; Processes the current token, guaranteed to be valid for the current state.
; The current token type is guaranteed to be instruction delimiter.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicInterpreter_token_instruction_delimiter:
	; instruction delimiters complete an instruction, causing it to be executed
	mov ax, 1								; "no error"
	
	call basicInterpreter_execute_accumulated
	mov byte [cs:basicState], BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
	ret
	

; Processes the current token, guaranteed to be valid for the current state.
; The current token type is guaranteed to be keyword.
;
; input:
;		none
; output:
;		none
basicInterpreter_token_keyword:
	pusha
	mov byte [cs:basicCurrentInstTokenCount], 0		; reset fragment count
	
	call basicInterpreter_store_current_keyword
	
	mov byte [cs:basicState], BASIC_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	
	popa
	ret


; Attempts to perform the fully-accumulated instruction
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicInterpreter_execute_accumulated:
	pusha
	push ds
	push es
	
	; now execute it
	
	cmp byte [cs:basicInterpreterIsInForSkipMode], 0
	je basicInterpreter_execute_accumulated_perform	; not in "FOR skip mode"
	; we are in "FOR skip mode", and we execute this instruction only if
	; it's a NEXT
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov si, basicKeywordNext			; DS:SI := "NEXT"
	mov di, basicCurrentKeyword			; ES:DI := keyword
	int 0BDh							; compare
	cmp ax, 0										; it is "NEXT"?
	je basicInterpreter_execute_accumulated_perform	; yes
	; instruction is not "NEXT", so we skip it
basicInterpreter_execute_accumulated_skip:
	pop es
	pop ds
	popa
	ret
basicInterpreter_execute_accumulated_perform:
	pop es
	pop ds
	popa
	
	push dx								; [1]
	call basicExecution_entry_point		; EXECUTE!
	cmp ax, 0										; there was an error
	je basicInterpreter_execute_accumulated_error	; so no further execution
													; is performed
			; DX - FFFFh when no further execution needed, otherwise:
			;	DL - first token of current instruction to be executed next
			;	DH - last token of current instruction to be executed next
	cmp dx, 0FFFFh
	je basicInterpreter_execute_accumulated_done	; no further execution
	; further execution is needed for this instruction
	; one such example is branching into either THEN or ELSE, for IF
	call basicInterpreter_make_subinstruction_main	; re-arrange tokens such
													; that the subinstruction
													; becomes the main
													; instruction
	pop dx								; [1]
	jmp basicInterpreter_execute_accumulated		; re-enter this routine
	
basicInterpreter_execute_accumulated_error:
basicInterpreter_execute_accumulated_done:
	pop dx								; [1]
	ret
	
	
; Copies the specified token range to the beginning of the instruction
; token array.
; The first token becomes the keyword.
; Variables are set in such a way that the interpreter behaves as if this
; token range was a standalone instruction.
;
; Example:
;     Instruction:  IF a = 0 THEN LET a = a + 1
;     DX = 0904h (token range: 4 to 9, inclusive)
; Becomes:
;     Instruction:  LET a = a + 1
;
; input:
;		DL - first token of the subinstruction token range
;		DH - last token of the subinstruction token range
; output:
;		none
basicInterpreter_make_subinstruction_main:
	pusha
	push ds
	push es
	
	mov cx, dx							; keep a copy of DX in CX
	
	; first token ends up in the keyword
	mov bl, dl
	call basicInterpreter_get_instruction_token_near_ptr ; DI := ptr to token
	mov si, di							; DS:SI := pointer to token
	mov di, basicCurrentKeyword			; ES:DI := pointer to keyword
	call common_string_copy				; copy it

basicInterpreter_make_subinstruction_main_loop:
	inc dl								; move to next
	cmp dl, dh							; have we gone over the last
										; (inclusive) token?
	ja basicInterpreter_make_subinstruction_main_done	; yes
	; we're still within the token range, so copy this token
	
	mov bl, dl							; BL := current source token index
	call basicInterpreter_get_instruction_token_near_ptr ; DI := ptr to token
	mov si, di							; DS:SI := pointer to source token
	
	sub bl, cl
	dec bl								; BL := current destination token index
	call basicInterpreter_get_instruction_token_near_ptr ; DI := ptr to token
										; ES:DI := pointer to destination token
	call common_string_copy				; copy it
	
	jmp basicInterpreter_make_subinstruction_main_loop	; next token
basicInterpreter_make_subinstruction_main_done:
	; we've copied all tokens
	; here, CX = passed-in DX, that is, CL = first token, CH = last token
	sub ch, cl							; CH := number of tokens in range
										; (we don't add one because the first
										; token in the range ends up in the
										; keyword)
	mov byte [cs:basicCurrentInstTokenCount], ch	; store it
	
	pop es
	pop ds
	popa
	ret
	

; Gets a near pointer to the instruction token string at the specified index
;
; input:
;		BL - index
; output:
;		DI - near pointer to instruction token string at the specified index
basicInterpreter_get_instruction_token_near_ptr:
	push ax
	push bx
	push cx
	push dx
	
	mov ax, BASIC_TOKEN_MAX_LENGTH+1		; length in bytes of an entry
	mov bh, 0								; BX := index
	mul bx									; DX:AX := AX * BX
	mov di, ax								; DI := offset (since DX=0)
	add di, basicCurrentInstTokens			; convert offset to pointer
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
	

; Stores the current token as the current keyword
;
; input:
;		none
; output:
;		none	
basicInterpreter_store_current_keyword:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, basicCurrentToken
	mov di, basicCurrentKeyword
	call common_string_copy
	
	pop es
	pop ds
	popa
	ret


; Clears current keyword
;
; input:
;		none
; output:
;		none
basicInterpreter_clear_current_keyword:
	mov byte [cs:basicCurrentKeyword], 0
	ret


; Checks whether the interpreter is currently partway through reading
; an instruction
;
; input:
;		none
; output:
;		AX - 0 if interpreter is not within an instruction, 
;			 other value otherwise
basicInterpreter_is_within_instruction:
	mov ax, 1							; "within instruction"
	cmp byte [cs:basicState], BASIC_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	je basicInterpreter_is_within_instruction_done
	mov ax, 0							; "not within instruction"
basicInterpreter_is_within_instruction_done:
	ret
	

; Returns the number of the current token within the current instruction
;
; input:
;		none
; output:
;		AX - current token number within the current (or just completed)
;			 instruction	
basicInterpreter_get_current_token_number:
	mov ah, 0
	mov al, byte [basicCurrentInstTokenCount]
	inc ax
	ret
	
	
; Puts interpreter in "FOR skip mode" whereby instructions are ignored
; until NEXT myCounter is encountered, where myCounter is a numeric variable
; with the same handle as expected
;
; input:
;		AX - variable handle of counter variable to expect
; output:
;		none
basicInterpreter_enable_FOR_skip_mode:
	mov word [cs:basicInterpreterForSkipModeCounterHandle], ax
	mov byte [cs:basicInterpreterIsInForSkipMode], 1
	ret


; Takes interpreter out of "FOR skip mode"
;
; input:
;		none
; output:
;		none
basicInterpreter_disable_FOR_skip_mode:
	mov byte [cs:basicInterpreterIsInForSkipMode], 0
	ret
	

; Prepares the interpreter proper for operation
;
; input:
;		none
; output:
;		none
basicInterpreter_initialize:
	call basicInterpreter_clear_current_keyword
	mov byte [cs:basicInterpreterIsInForSkipMode], 0
	mov byte [cs:basicCurrentInstTokenCount], 0
	mov byte [cs:basicState], BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
	ret


%endif
