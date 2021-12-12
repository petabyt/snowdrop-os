;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains token interpretation routines for Snowdrop OS's assembler.
; Essentially, this is the engine behind the ASM interpreter. Is it a state
; machine that is invoked for each token parsed out of the program text.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_INTERPRETATION_
%define _COMMON_ASM_INTERPRETATION_


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
asmInterpreter_process:
	push ds
	pusha
		
	mov word [cs:asmInterpreterParserResumePoint], si	; save continue point
	
	push cs
	pop ds
	mov si, asmCurrentToken			; DS:SI := pointer to current token
	
	cmp byte [cs:asmState], ASM_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
	je asmInterpreter_process_k_n_l

	cmp byte [cs:asmState], ASM_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	je asmInterpreter_process_id_n_frag
	
	; ERROR: invalid state
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageInvalidState
	jmp asmInterpreter_process_invalid
asmInterpreter_process_k_n_l:
	; is it a label?
	call asm_is_valid_label
	cmp ax, 0
	jne asmInterpreter_process_label		; it's a label
	; is it a keyword?
	call asm_is_valid_keyword
	cmp ax, 0
	jne asmInterpreter_process_keyword	; it's a keyword
	; is it a newline?
	call asm_is_valid_newline
	cmp ax, 0
	jne asmInterpreter_process_newline	; it's a newline
	; ERROR: token is of none of the possible types for this state
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageExpectedKeywordOrNewlineOrLabel
	jmp asmInterpreter_process_invalid
asmInterpreter_process_id_n_frag:
	; is it an instruction delimiter?
	call asm_is_valid_instruction_delimiter
	cmp ax, 0
	jne asmInterpreter_process_instruction_delimiter	; it's an inst. delim.
	; is it a newline?
	call asm_is_valid_newline
	cmp ax, 0
	jne asmInterpreter_process_newline	; it's a newline
	; treat all others are instruction fragments
	jmp asmInterpreter_process_instruction_fragment

asmInterpreter_process_label:
	call asmInterpreter_token_label
	cmp ax, 0								; was there an error?
	je asmInterpreter_process_invalid		; yes
	jmp asmInterpreter_process_valid		; no
	
asmInterpreter_process_keyword:
	call asmInterpreter_token_keyword
	jmp asmInterpreter_process_valid
	
asmInterpreter_process_newline:
	call asmInterpreter_token_newline
	cmp ax, 0								; was there an error?
	je asmInterpreter_process_invalid		; yes
	jmp asmInterpreter_process_valid		; no
	
asmInterpreter_process_instruction_delimiter:
	call asmInterpreter_token_instruction_delimiter
	cmp ax, 0								; was there an error?
	je asmInterpreter_process_invalid		; yes
	jmp asmInterpreter_process_valid		; no
	
asmInterpreter_process_instruction_fragment:
	call asmInterpreter_token_instruction_fragment
	cmp ax, 0								; was there an error?
	je asmInterpreter_process_invalid		; yes
	jmp asmInterpreter_process_valid		; no

asmInterpreter_process_valid:
	call asmEmit_is_overflowed
	cmp al, 0
	je asmInterpreter_process_valid_return_valid
	; emission would overflow, so it was halted
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageErrorBytecodeOffsetOverflow
	jmp asmInterpreter_process_invalid
	
asmInterpreter_process_valid_return_valid:
	popa
	pop ds
	mov si, word [cs:asmInterpreterParserResumePoint]	; restore resume point
	mov ax, 1							; return success
	ret
asmInterpreter_process_invalid:
	popa
	pop ds
	mov si, word [cs:asmInterpreterParserResumePoint]	; restore resume point
	mov ax, 0							; return error
	ret

	
; Processes the current token, guaranteed to be valid for the current state.
; The current token type is guaranteed to be label.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmInterpreter_token_label:
	push ds
	push si
	push bx
	push dx

	; labels must be unique
	push word [cs:asmProgramTextSeg]
	pop ds
	mov si, word [cs:asmProgramTextOff]		; DS:SI := beginning of program
	
	mov dx, cs
	mov bx, asmCurrentToken					; DX:BX := pointer to token
	call asm_is_unique_label				; AX := 0 when label is not unique
	cmp ax, 0
	je asmInterpreter_token_label_cannot_redefine	; it's invalid
	; it's valid, so we might have to save its address
	
	cmp byte [cs:asmPass], ASM_PASS_1		; we save label addresses only
	jne asmInterpreter_token_label_valid	; during pass 1
	; this is pass 1, so we save the label's address
	push cs
	pop ds
	mov si, bx								; DS:SI := pointer to token
	
	int 0A5h								; BX := string length
	mov byte [ds:si+bx-1], 0				; trim : character from the end
	
	; check whether it exists already
	call asmNumericVars_get_handle_from_storage	; CARRY - set when not found
												; NOTE: this goes directly to
												;       storage
	jnc asmInterpreter_token_label_cannot_redefine
	
	; create variable
	call asmNumericVars_allocate		; CARRY - set when a slot was not found
										; BX - variable handle	
	jc asmInterpreter_token_label_no_more_vars
	call asmDisplay_record_label
	
	; set value
	mov ax, bx										; AX := variable handle
	call asmEmit_get_current_absolute_16bit_address	; BX := label address
	call asmNumericVars_set_value
		
	jmp asmInterpreter_token_label_valid
	
asmInterpreter_token_label_no_more_vars:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageVariablesFull
	jmp asmInterpreter_token_label_invalid
	
asmInterpreter_token_label_cannot_redefine:
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageLabelNotUnique
	jmp asmInterpreter_token_label_invalid
	
asmInterpreter_token_label_valid:
	call asmList_write_label
	mov ax, 1
	jmp asmInterpreter_token_label_done
asmInterpreter_token_label_invalid:
	mov ax, 0
asmInterpreter_token_label_done:
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
asmInterpreter_token_instruction_fragment:
	; check if we reached the limit
	cmp byte [cs:asmCurrentInstTokenCount], ASM_MAX_INSTRUCTION_TOKENS
	jb asmInterpreter_token_instruction_fragment_perform	; we haven't
	; no room to store this instruction fragment
	mov word [cs:asmInterpretationEndMessagePtr], asmMessageTooManyInstructionTokens
	mov ax, 0							; "there was an error"
	ret
asmInterpreter_token_instruction_fragment_perform:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; copy current token into the corresponding instruction fragment slot
	mov bl, byte [cs:asmCurrentInstTokenCount]
	call asmInterpreter_get_instruction_token_near_ptr
									; DI := pointer to instruction token string
	mov si, asmCurrentToken
	call common_string_copy			; copy it
	
	inc byte [cs:asmCurrentInstTokenCount]	; we've added one
	
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
asmInterpreter_token_newline:
	; newlines either do nothing or complete an instruction, causing it to 
	; be executed
	mov ax, 1								; "no error"
	
	cmp byte [cs:asmState], ASM_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	jne asmInterpreter_token_newline_done
	call asmExecution_entry_point
	mov byte [cs:asmState], ASM_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
asmInterpreter_token_newline_done:	
	ret
	
	
; Processes the current token, guaranteed to be valid for the current state.
; The current token type is guaranteed to be instruction delimiter.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmInterpreter_token_instruction_delimiter:
	; instruction delimiters complete an instruction, causing it to be executed
	mov ax, 1								; "no error"
	
	call asmExecution_entry_point
	mov byte [cs:asmState], ASM_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
	ret
	

; Processes the current token, guaranteed to be valid for the current state.
; The current token type is guaranteed to be keyword.
;
; input:
;		none
; output:
;		none
asmInterpreter_token_keyword:
	pusha
	mov byte [cs:asmCurrentInstTokenCount], 0		; reset fragment count
	
	call asmInterpreter_store_current_keyword
	
	mov byte [cs:asmState], ASM_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	
	popa
	ret
	
	
; Copies the specified token range to the beginning of the instruction
; token array.
; The first token becomes the keyword.
; Variables are set in such a way that the interpreter behaves as if this
; token range was a standalone instruction.
;
; Example:
;     Instruction:  TIMES 30 - 10 DB 0, 1
;     DX = 0503h (token range: 3 to 5, inclusive)
; Becomes:
;     Instruction:  DB 0, 1
;
; input:
;		DL - first token of the subinstruction token range
;		DH - last token of the subinstruction token range
; output:
;		none
asmInterpreter_make_subinstruction_main:
	pusha
	push ds
	push es
	
	mov cx, dx							; keep a copy of DX in CX
	
	; first token ends up in the keyword
	mov bl, dl
	call asmInterpreter_get_instruction_token_near_ptr ; DI := ptr to token
	mov si, di							; DS:SI := pointer to token
	mov di, asmCurrentKeyword			; ES:DI := pointer to keyword
	call common_string_copy				; copy it

asmInterpreter_make_subinstruction_main_loop:
	inc dl								; move to next
	cmp dl, dh							; have we gone over the last
										; (inclusive) token?
	ja asmInterpreter_make_subinstruction_main_done	; yes
	; we're still within the token range, so copy this token
	
	mov bl, dl							; BL := current source token index
	call asmInterpreter_get_instruction_token_near_ptr ; DI := ptr to token
	mov si, di							; DS:SI := pointer to source token
	
	sub bl, cl
	dec bl								; BL := current destination token index
	call asmInterpreter_get_instruction_token_near_ptr ; DI := ptr to token
										; ES:DI := pointer to destination token
	call common_string_copy				; copy it
	
	jmp asmInterpreter_make_subinstruction_main_loop	; next token
asmInterpreter_make_subinstruction_main_done:
	; we've copied all tokens
	; here, CX = passed-in DX, that is, CL = first token, CH = last token
	sub ch, cl							; CH := number of tokens in range
										; (we don't add one because the first
										; token in the range ends up in the
										; keyword)
	mov byte [cs:asmCurrentInstTokenCount], ch	; store it
	
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
asmInterpreter_get_instruction_token_near_ptr:
	push ax
	push bx
	push cx
	push dx
	
	mov ax, ASM_TOKEN_MAX_LENGTH+1		; length in bytes of an entry
	mov bh, 0								; BX := index
	mul bx									; DX:AX := AX * BX
	mov di, ax								; DI := offset (since DX=0)
	add di, asmCurrentInstTokens			; convert offset to pointer
	
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
asmInterpreter_store_current_keyword:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, asmCurrentKeyword
	mov di, asmPreviousKeyword
	call common_string_copy			; save previous
	
	mov si, asmCurrentToken
	mov di, asmCurrentKeyword
	call common_string_copy			; save current
	
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
asmInterpreter_clear_current_keyword:
	mov byte [cs:asmCurrentKeyword], 0
	mov byte [cs:asmPreviousKeyword], 0
	ret


; Checks whether the interpreter is currently partway through reading
; an instruction
;
; input:
;		none
; output:
;		AX - 0 if interpreter is not within an instruction, 
;			 other value otherwise
asmInterpreter_is_within_instruction:
	mov ax, 1							; "within instruction"
	cmp byte [cs:asmState], ASM_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT
	je asmInterpreter_is_within_instruction_done
	mov ax, 0							; "not within instruction"
asmInterpreter_is_within_instruction_done:
	ret
	

; Returns the number of the current token within the current instruction
;
; input:
;		none
; output:
;		AX - current token number within the current (or just completed)
;			 instruction	
asmInterpreter_get_current_token_number:
	mov ah, 0
	mov al, byte [asmCurrentInstTokenCount]
	inc ax
	ret
	

; Prepares the interpreter proper for operation
;
; input:
;	 DS:SI - pointer to beginning of program text
; output:
;		none
asmInterpreter_initialize:
	mov word [cs:asmInterpreterParserResumePoint], si
	
	call asmInterpreter_clear_current_keyword
	mov byte [cs:asmCurrentInstTokenCount], 0
	mov byte [cs:asmState], ASM_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL
	ret


%endif
