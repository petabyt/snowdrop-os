;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains instruction execution routines for Snowdrop OS's assembler.
;
; Contents of this file are x86-specific.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_X86_EXECUTION_
%define _COMMON_ASM_X86_EXECUTION_


; Executes the current instruction, LOOPNE_LOOPNZ
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_LOOPNE_LOOPNZ:
	mov al, 0E0h								; opcode byte
	call asmx86_try_emit_LOOP_family
	ret


; Executes the current instruction, LOOPE_LOOPZ
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_LOOPE_LOOPZ:
	mov al, 0E1h								; opcode byte
	call asmx86_try_emit_LOOP_family
	ret


; Executes the current instruction, LOOP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_LOOP:
	mov al, 0E2h								; opcode byte
	call asmx86_try_emit_LOOP_family
	ret


; Executes the current instruction, CWD
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CWD:
	mov al, 99h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CBW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CBW:
	mov al, 98h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, XLAT_XLATB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_XLAT_XLATB:
	mov al, 0D7h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, LEAVE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_LEAVE:
	mov al, 0C9h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, INTO
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_INTO:
	mov al, 0CEh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	cmp ax, 0
	je asmx86_INTO_done
	
	mov al, 90h								; pad NOP
	call asmEmit_emit_byte_from_number
	mov ax, 1
asmx86_INTO_done:	
	ret


; Executes the current instruction, INT3
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_INT3:
	mov al, 0CCh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	cmp ax, 0
	je asmx86_INT3_done
	
	mov al, 90h								; pad NOP
	call asmEmit_emit_byte_from_number
	mov ax, 1
asmx86_INT3_done:
	ret


; Executes the current instruction, SALC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SALC:
	mov al, 0D6h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, LAHF
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_LAHF:
	mov al, 9Fh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, SAHF
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SAHF:
	mov al, 9Eh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CMC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CMC:
	mov al, 0F5h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, NOP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_NOP:
	mov al, 90h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, HLT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_HLT:
	mov al, 0F4h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, XCHG
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_XCHG:
	push bx

	mov al, 86h				; base opcode for reg, reg
	call asmx86_try_emit_reg_reg
	
	pop bx
	ret


; Executes the current instruction, TEST
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_TEST:
	push bx

	mov al, 84h				; base opcode for reg, reg
	mov bl, 0F6h			; base opcode for reg, imm
	mov bh, 0
	call asmx86_try_emit_simple
	
	pop bx
	ret


; Executes the current instruction, REPNE_REPNZ
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_REPNE_REPNZ:
	push bx
	push cx
	push dx
	
	call asmx86_try_get_rep_suffix
	cmp ax, 0
	je asmx86_REPNE_REPNZ_error
	
	; only allow appropriate suffixes
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_MOVS
	je asmx86_REPNE_REPNZ_inappropriate_suffix
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_LODS
	je asmx86_REPNE_REPNZ_inappropriate_suffix
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_STOS
	je asmx86_REPNE_REPNZ_inappropriate_suffix
	
	; suffix is appropriate
	mov al, 0F2h					; emit prefix
	call asmEmit_emit_byte_from_number
	
	; we now make the suffix current instruction
	mov dl, 0						; DL := first token
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; DH := last token
	; make instruction from DL to DH current
	call asmInterpreter_make_subinstruction_main
	call asmExecution_core			; emit suffix
	cmp ax, 0
	je asmx86_REPNE_REPNZ_error
	jmp asmx86_REPNE_REPNZ_success
	
asmx86_REPNE_REPNZ_inappropriate_suffix:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageInappropriateSuffix
	jmp asmx86_REPNE_REPNZ_error
asmx86_REPNE_REPNZ_error:
	mov ax, 0
	jmp asmx86_REPNE_REPNZ_done
asmx86_REPNE_REPNZ_success:
	mov ax, 1
asmx86_REPNE_REPNZ_done:
	pop dx
	pop cx
	pop bx
	ret


; Executes the current instruction, REPE_REPZ
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_REPE_REPZ:
	push bx
	push cx
	push dx
	
	call asmx86_try_get_rep_suffix
	cmp ax, 0
	je asmx86_REPE_REPZ_error
	
	; only allow appropriate suffixes
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_MOVS
	je asmx86_REPE_REPZ_inappropriate_suffix
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_LODS
	je asmx86_REPE_REPZ_inappropriate_suffix
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_STOS
	je asmx86_REPE_REPZ_inappropriate_suffix
	
	; suffix is appropriate
	mov al, 0F3h					; emit prefix
	call asmEmit_emit_byte_from_number
	
	; we now make the suffix current instruction
	mov dl, 0						; DL := first token
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; DH := last token
	; make instruction from DL to DH current
	call asmInterpreter_make_subinstruction_main
	call asmExecution_core			; emit suffix
	cmp ax, 0
	je asmx86_REPE_REPZ_error
	jmp asmx86_REPE_REPZ_success
	
asmx86_REPE_REPZ_inappropriate_suffix:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageInappropriateSuffix
	jmp asmx86_REPE_REPZ_error
asmx86_REPE_REPZ_error:
	mov ax, 0
	jmp asmx86_REPE_REPZ_done
asmx86_REPE_REPZ_success:
	mov ax, 1
asmx86_REPE_REPZ_done:
	pop dx
	pop cx
	pop bx
	ret


; Executes the current instruction, REP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_REP:
	push bx
	push cx
	push dx
	
	call asmx86_try_get_rep_suffix
	cmp ax, 0
	je asmx86_REP_error
	
	; only allow appropriate suffixes
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_CMPS
	je asmx86_REP_inappropriate_suffix
	cmp cx, ASMX86_REP_SUFFIX_FAMILY_SCAS
	je asmx86_REP_inappropriate_suffix
	
	; suffix is appropriate
	mov al, 0F3h					; emit prefix
	call asmEmit_emit_byte_from_number
	
	; we now make the suffix current instruction
	mov dl, 0						; DL := first token
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; DH := last token
	; make instruction from DL to DH current
	call asmInterpreter_make_subinstruction_main
	call asmExecution_core			; emit suffix
	cmp ax, 0
	je asmx86_REP_error
	jmp asmx86_REP_success
	
asmx86_REP_inappropriate_suffix:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageInappropriateSuffix
	jmp asmx86_REP_error
asmx86_REP_error:
	mov ax, 0
	jmp asmx86_REP_done
asmx86_REP_success:
	mov ax, 1
asmx86_REP_done:
	pop dx
	pop cx
	pop bx
	ret


; Executes the current instruction, SCASW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SCASW:
	mov al, 0AFh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CMPSW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CMPSW:
	mov al, 0A7h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, STOSW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_STOSW:
	mov al, 0ABh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, LODSW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_LODSW:
	mov al, 0ADh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, MOVSW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_MOVSW:
	mov al, 0A5h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, SCASB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SCASB:
	mov al, 0AEh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CMPSB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CMPSB:
	mov al, 0A6h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, STOSB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_STOSB:
	mov al, 0AAh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, LODSB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_LODSB:
	mov al, 0ACh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, MOVSB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_MOVSB:
	mov al, 0A4h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, OUT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_OUT:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	; this opcode has a special case of mismatched register sizes, allowing
	; AL to be the source and DX the destination
	; we handle this case first
	cmp byte [cs:asmCurrentInstTokenCount], 3
	jb asmx86_OUT_tokens						; need at least three tokens
	
	mov bl, 1									; second token must be comma
	call asmx86_is_token_comma
	cmp ax, 0
	je asmx86_OUT_imm_comma_reg					; no comma
	
	mov bl, 0									; destination register
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_OUT_imm_comma_reg					; not a register
	cmp cl, ASMX86_REG_DX
	jne asmx86_OUT_imm_comma_reg				; not DX
	
	mov bl, 2									; source register
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_OUT_imm_comma_reg					; not a register
	cmp cl, ASMX86_REG_AL
	jne asmx86_OUT_AX_comma_DX					; not AL
asmx86_OUT_AL_comma_DX:
	; we're emitting OUT DX, AL
	mov al, 0EEh								; OUT DX, AL
	call asmEmit_emit_byte_from_number
	jmp asmx86_OUT_success
asmx86_OUT_AX_comma_DX:
	cmp cl, ASMX86_REG_AX
	jne asmx86_OUT_imm_comma_reg				; not AX
	; we're emitting OUT DX, AX
	mov al, 0EFh								; OUT DX, AX
	call asmEmit_emit_byte_from_number
	jmp asmx86_OUT_success
	
asmx86_OUT_imm_comma_reg:
	call asmx86_find_first_comma_token	; BL := index of first comma token
										; guaranteed to not be last
	cmp ax, 0
	je asmx86_OUT_unsupported_operands
	mov byte [cs:asmx86OutCommaIndex], bl
	; parse destination
	mov dl, 0						; we evaluate from the first token...
	mov dh, bl
	dec dh							; ...to right before comma
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_OUT_error	; there was an error
	
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_OUT_unsupported_operands
	mov word [cs:asmx86OutImm16Destination], cx
	
	; parse source
	mov bl, byte [cs:asmx86OutCommaIndex]
	inc bl										; BL := index right after comma
	mov al, byte [cs:asmCurrentInstTokenCount]	; AL := count
	dec al										; AL := index of last token
	cmp al, bl									; we must have exactly one
	jne asmx86_OUT_unsupported_operands			; token after comma
	
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_OUT_unsupported_operands
	mov cl, ch									; CL := register info
	and ch, ASMX86_REG_MASK_ENCODING
	cmp ch, ASMX86_REG_AL_AX_ENCODING
	jne asmx86_OUT_unsupported_operands
	; source is AL or AX
	test cl, ASMX86_REG_IS_16BIT
	jz asmx86_OUT_imm8_comma_reg8
asmx86_OUT_imm8_comma_reg16:
	; we're emitting OUT imm8, AX
	mov al, 0E7h								; OUT imm8, AX
	call asmEmit_emit_byte_from_number
	mov ax, word [cs:asmx86OutImm16Destination]	; imm8
	call asmEmit_emit_byte_from_number
	call asmx86_warn_if_value_larger_than_byte
	
	jmp asmx86_OUT_success
asmx86_OUT_imm8_comma_reg8:
	; we're emitting OUT imm8, AL
	mov al, 0E6h								; OUT imm8, AL
	call asmEmit_emit_byte_from_number
	mov ax, word [cs:asmx86OutImm16Destination]	; imm8
	call asmEmit_emit_byte_from_number
	call asmx86_warn_if_value_larger_than_byte
	
	jmp asmx86_OUT_success

asmx86_OUT_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_OUT_error
	
asmx86_OUT_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_OUT_error
	
asmx86_OUT_error:
	mov ax, 0							; "error"
	jmp asmx86_OUT_done
asmx86_OUT_success:
	mov ax, 1							; "success"
asmx86_OUT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction, IN
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_IN:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	; this opcode has a special case of mismatched register sizes, allowing
	; AL to be the destination and DX the source
	; we handle this case first
	cmp byte [cs:asmCurrentInstTokenCount], 3
	jb asmx86_IN_tokens							; need at least three tokens
	
	mov bl, 1									; second token must be comma
	call asmx86_is_token_comma
	cmp ax, 0
	je asmx86_IN_reg_comma_imm					; no comma
	
	mov bl, 2									; source register
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_IN_reg_comma_imm					; not a register
	cmp cl, ASMX86_REG_DX
	jne asmx86_IN_reg_comma_imm					; not DX
	
	mov bl, 0									; destination register
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_IN_reg_comma_imm					; not a register
	cmp cl, ASMX86_REG_AL
	jne asmx86_IN_AX_comma_DX					; not AL
asmx86_IN_AL_comma_DX:
	; we're emitting IN AL, DX
	mov al, 0ECh								; IN AL, DX
	call asmEmit_emit_byte_from_number
	jmp asmx86_IN_success
asmx86_IN_AX_comma_DX:
	cmp cl, ASMX86_REG_AX
	jne asmx86_IN_reg_comma_imm					; not AX
	; we're emitting IN AX, DX
	mov al, 0EDh								; IN AX, DX
	call asmEmit_emit_byte_from_number
	
	jmp asmx86_IN_success
	
asmx86_IN_reg_comma_imm:
	call asmx86_try_resolve_simple
	cmp ax, 2
	jne asmx86_IN_unsupported_operands			; it's not reg, imm
	; it's reg, imm
	cmp cl, ASMX86_REG_AL_AX_ENCODING
	jne asmx86_IN_unsupported_operands
	; it's AL, imm      or      AX, imm
	test dl, ASMX86_REG_IS_16BIT
	jz asmx86_IN_AL_comma_imm

asmx86_IN_AX_comma_imm:
	; we're emitting IN AX, imm8
	mov al, 0E5h								; IN AX, imm8
	call asmEmit_emit_byte_from_number
	mov ax, bx									; imm8
	call asmEmit_emit_byte_from_number
	call asmx86_warn_if_value_larger_than_byte
	jmp asmx86_IN_success
asmx86_IN_AL_comma_imm:
	; we're emitting IN AL, imm8
	mov al, 0E4h								; IN AL, imm8
	call asmEmit_emit_byte_from_number
	mov ax, bx									; imm8
	call asmEmit_emit_byte_from_number
	call asmx86_warn_if_value_larger_than_byte
	jmp asmx86_IN_success

asmx86_IN_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_IN_error
	
asmx86_IN_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_IN_error
	
asmx86_IN_error:
	mov ax, 0							; "error"
	jmp asmx86_IN_done
asmx86_IN_success:
	mov ax, 1							; "success"
asmx86_IN_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction, IDIV
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_IDIV:
	push bx
	
	mov al, 0F8h							; base
	mov bl, 0F7h							; opcode for reg16
	mov bh, 0F6h							; opcode for reg8
	call asmx86_try_emit_1byte_reg_from_single_operand
	
	pop bx
	ret


; Executes the current instruction, DIV
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_DIV:
	push bx
	
	mov al, 0F0h							; base
	mov bl, 0F7h							; opcode for reg16
	mov bh, 0F6h							; opcode for reg8
	call asmx86_try_emit_1byte_reg_from_single_operand
	
	pop bx
	ret


; Executes the current instruction, IMUL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_IMUL:
	push bx
	
	mov al, 0E8h							; base
	mov bl, 0F7h							; opcode for reg16
	mov bh, 0F6h							; opcode for reg8
	call asmx86_try_emit_1byte_reg_from_single_operand
	
	pop bx
	ret


; Executes the current instruction, MUL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_MUL:
	push bx
	
	mov al, 0E0h							; base
	mov bl, 0F7h							; opcode for reg16
	mov bh, 0F6h							; opcode for reg8
	call asmx86_try_emit_1byte_reg_from_single_operand
	
	pop bx
	ret


; Executes the current instruction, DEC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_DEC:
	push bx
	push cx
	push dx

	call asmx86_try_get_reg16_reg8_from_single_operand
	cmp ax, 0
	je asmx86_DEC_done						; error
	
	test ch, ASMX86_REG_IS_16BIT
	jz asmx86_DEC_reg8	
asmx86_DEC_reg16:
	; emit DEC reg16
	
	and ch, ASMX86_REG_MASK_ENCODING
	mov al, 48h
	add al, ch
	call asmEmit_emit_byte_from_number
	jmp asmx86_DEC_success
asmx86_DEC_reg8:
	; emit DEC reg8

	mov al, 0FEh
	call asmEmit_emit_byte_from_number		; opcode
	
	and ch, ASMX86_REG_MASK_ENCODING
	mov al, 0C8h							; base
	or al, ch
	call asmEmit_emit_byte_from_number		; modrm
	jmp asmx86_DEC_success
asmx86_DEC_success:	
	mov ax, 1
asmx86_DEC_done:
	pop dx
	pop cx
	pop bx
	ret


; Executes the current instruction, INC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_INC:
	push bx
	push cx
	push dx

	call asmx86_try_get_reg16_reg8_from_single_operand
	cmp ax, 0
	je asmx86_INC_done						; error
	
	test ch, ASMX86_REG_IS_16BIT
	jz asmx86_INC_reg8	
asmx86_INC_reg16:
	; emit INC reg16
	
	and ch, ASMX86_REG_MASK_ENCODING
	mov al, 40h
	add al, ch
	call asmEmit_emit_byte_from_number
	jmp asmx86_INC_success
asmx86_INC_reg8:
	; emit INC reg8

	mov al, 0FEh
	call asmEmit_emit_byte_from_number		; opcode
	
	and ch, ASMX86_REG_MASK_ENCODING
	mov al, 0C0h							; base
	or al, ch
	call asmEmit_emit_byte_from_number		; modrm
	jmp asmx86_INC_success
asmx86_INC_success:	
	mov ax, 1
asmx86_INC_done:
	pop dx
	pop cx
	pop bx
	ret


; Executes the current instruction, STD
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_STD:
	mov al, 0FDh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CLD
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CLD:
	mov al, 0FCh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, STI
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_STI:
	mov al, 0FBh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CLI
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CLI:
	mov al, 0FAh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, STC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_STC:
	mov al, 0F9h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CLC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CLC:
	mov al, 0F8h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, POPF
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_POPF:
	mov al, 9Dh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, PUSHF
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_PUSHF:
	mov al, 9Ch
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, POPA
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_POPA:
	mov al, 61h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, PUSHA
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_PUSHA:
	mov al, 60h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, POP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_POP:
	mov al, ASMX86_PUSHPOP_POP
	call asmx86_try_emit_push_pop_sreg16_reg16
	ret


; Executes the current instruction, PUSH
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_PUSH:
	mov al, ASMX86_PUSHPOP_PUSH
	call asmx86_try_emit_push_pop_sreg16_reg16
	ret


; Executes the current instruction, IRET
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_IRET:
	mov al, 0CFh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret
	

; Executes the current instruction, RETF
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_RETF:
	mov al, 0CBh
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, RET_RETN
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_RET_RETN:
	mov al, 0C3h
	call asmx86_try_emit_single_byte_opcode_no_arguments
	ret


; Executes the current instruction, CALL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CALL:
	push bx
	push cx
	push dx

	call asmx86_try_get_imm16_from_single_operand		; CX := imm16
	cmp ax, 0
	je asmx86_CALL_done									; error
	
	call asmEmit_get_current_absolute_16bit_address	; BX := address before CALL
	add bx, 3										; BX := address after CALL
	sub cx, bx		; CX := jump address relative to address right after CALL
	
	mov al, 0E8h
	call asmEmit_emit_byte_from_number
	mov ax, cx
	call asmEmit_emit_word_from_number
	
	mov ax, 1							; "success"
asmx86_CALL_done:
	pop dx
	pop cx
	pop bx
	ret


; Executes the current instruction, JCXZ
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JCXZ:
	push bx
	push cx
	push dx

	call asmx86_try_get_imm16_from_single_operand		; CX := imm16
	cmp ax, 0
	je asmx86_JCXZ_done									; error
	
	call asmEmit_get_current_absolute_16bit_address	; BX := address before JCXZ
	add bx, 2										; BX := address after JCXZ
	sub cx, bx		; CX := jump address relative to address right after JCXZ
	
	mov al, 0E3h
	call asmEmit_emit_byte_from_number
	mov ax, cx
	call asmEmit_emit_byte_from_number
	call asmx86_warn_if_value_larger_than_byte
	
	mov ax, 1							; "success"
asmx86_JCXZ_done:
	pop dx
	pop cx
	pop bx
	ret


; Executes the current instruction, JNP_JPO
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JNP_JPO:
	mov ah, 8Bh									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JP_JPE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JP_JPE:
	mov ah, 8Ah									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JG_JNLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JG_JNLE:
	mov ah, 8Fh									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JLE_JNG
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JLE_JNG:
	mov ah, 8Eh									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JGE_JNL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JGE_JNL:
	mov ah, 8Dh									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JL_JNGE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JL_JNGE:
	mov ah, 8Ch									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JA_JNBE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JA_JNBE:
	mov ah, 87h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JBE_JNA
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JBE_JNA:
	mov ah, 86h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JNB_JAE_JNC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JNB_JAE_JNC:
	mov ah, 83h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JB_JNAE_JC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JB_JNAE_JC:
	mov ah, 82h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JNE_JNZ
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JNE_JNZ:
	mov ah, 85h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JE_JZ
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JE_JZ:
	mov ah, 84h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JNS
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JNS:
	mov ah, 89h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JS
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JS:
	mov ah, 88h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JNO
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JNO:
	mov ah, 81h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, JO
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JO:
	mov ah, 80h									; second byte of opcode
	call asmx86_try_emit_Jxx_family
	ret


; Executes the current instruction, SAR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SAR:
	push bx

	mov bl, 0C0h			; base opcode for reg, imm
	mov bh, ASMX86_ROL_FAMILY_DISPLACEMENT_SAR
	call asmx86_try_emit_simple_imm8_source
	
	pop bx
	ret


; Executes the current instruction, SHR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SHR:
	push bx

	mov bl, 0C0h			; base opcode for reg, imm
	mov bh, ASMX86_ROL_FAMILY_DISPLACEMENT_SHR
	call asmx86_try_emit_simple_imm8_source
	
	pop bx
	ret


; Executes the current instruction, SHL_SAL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SHL_SAL:
	push bx

	mov bl, 0C0h			; base opcode for reg, imm
	mov bh, ASMX86_ROL_FAMILY_DISPLACEMENT_SHL_SAL
	call asmx86_try_emit_simple_imm8_source
	
	pop bx
	ret


; Executes the current instruction, RCR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_RCR:
	push bx

	mov bl, 0C0h			; base opcode for reg, imm
	mov bh, ASMX86_ROL_FAMILY_DISPLACEMENT_RCR
	call asmx86_try_emit_simple_imm8_source
	
	pop bx
	ret


; Executes the current instruction, RCL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_RCL:
	push bx

	mov bl, 0C0h			; base opcode for reg, imm
	mov bh, ASMX86_ROL_FAMILY_DISPLACEMENT_RCL
	call asmx86_try_emit_simple_imm8_source
	
	pop bx
	ret


; Executes the current instruction, ROR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_ROR:
	push bx

	mov bl, 0C0h			; base opcode for reg, imm
	mov bh, ASMX86_ROL_FAMILY_DISPLACEMENT_ROR
	call asmx86_try_emit_simple_imm8_source
	
	pop bx
	ret


; Executes the current instruction, ROL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_ROL:
	push bx

	mov bl, 0C0h			; base opcode for reg, imm
	mov bh, ASMX86_ROL_FAMILY_DISPLACEMENT_ROL
	call asmx86_try_emit_simple_imm8_source
	
	pop bx
	ret


; Executes the current instruction, CMP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_CMP:
	push bx

	mov al, 38h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_CMP
	call asmx86_try_emit_simple
	
	pop bx
	ret


; Executes the current instruction, XOR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_XOR:
	push bx

	mov al, 30h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_XOR
	call asmx86_try_emit_simple
	
	pop bx
	ret


; Executes the current instruction, SUB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SUB:
	push bx

	mov al, 28h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_SUB
	call asmx86_try_emit_simple
	
	pop bx
	ret


; Executes the current instruction, AND
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_AND:
	push bx

	mov al, 20h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_AND
	call asmx86_try_emit_simple
	
	pop bx
	ret


; Executes the current instruction, SBB
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_SBB:
	push bx

	mov al, 18h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_SBB
	call asmx86_try_emit_simple
	
	pop bx
	ret


; Executes the current instruction, ADC
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_ADC:
	push bx

	mov al, 10h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_ADC
	call asmx86_try_emit_simple
	
	pop bx
	ret


; Executes the current instruction, OR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_OR:
	push bx

	mov al, 08h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_OR
	call asmx86_try_emit_simple
	
	pop bx
	ret
	

; Executes the current instruction, ADD
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_ADD:
	push bx

	mov al, 00h			; base opcode for reg, reg
	mov bl, 80h			; base opcode for reg, imm
	mov bh, ASMX86_ADD_FAMILY_DISPLACEMENT_ADD
	call asmx86_try_emit_simple
	
	pop bx
	ret
	

; Executes the current instruction, JMP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_JMP:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:asmCurrentInstTokenCount], 0
	je asmx86_JMP_tokens
	
	mov dl, 0						; we evaluate from the first token...
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; ...to the last
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_JMP_error	; there was an error
	
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_JMP_not_a_number
	
	call asmEmit_get_current_absolute_16bit_address	; BX := address before JMP
	add bx, 3										; BX := address after JMP
	sub cx, bx		; CX := jump address relative to address right after JMP
	
	mov al, 0E9h						; JMP imm16 (relative)
	call asmEmit_emit_byte_from_number
	mov ax, cx							; imm16
	call asmEmit_emit_word_from_number
		
	jmp asmx86_JMP_success

asmx86_JMP_not_a_number:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageExpressionMustBeNumeric
	jmp asmx86_JMP_error
	
asmx86_JMP_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_JMP_error
	
asmx86_JMP_error:
	mov ax, 0							; "error"
	jmp asmx86_JMP_done
asmx86_JMP_success:
	mov ax, 1							; "success"
asmx86_JMP_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction, MOV
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_MOV:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:asmCurrentInstTokenCount], 3
	jb asmx86_MOV_tokens
	
	; check mov reg, XXXX
asmx86_MOV_check_reg_comma_XXXX:
	mov bl, 1
	call asmx86_is_token_comma
	cmp ax, 0
	je asmx86_MOV_check_mem_comma_XXXX

	mov bl, 0
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	jne asmx86_MOV_reg_comma_XXXX
	
	; check mov mem, XXXX
asmx86_MOV_check_mem_comma_XXXX:
	call asmx86_find_first_comma_token	; BL := index of first comma token
										; guaranteed to not be last
	cmp ax, 0
	je asmx86_MOV_unsupported_operands	; didn't find a comma
	cmp bl, 0							; is first token a comma?
	je asmx86_MOV_unsupported_operands	; yes, so it's malformed
	inc bl								; BL := index of first token of source
	mov bh, byte [cs:asmCurrentInstTokenCount]
	dec bh								; BH := index of last token of source
	mov word [cs:asm86xMovSrcTokenRange], bx	; save range
	
	mov bh, bl
	sub bh, 2							; BH := index of last token of dest.
	mov bl, 0
	call asmx86_try_resolve_memory_from_tokens
	cmp ax, 0
	je asmx86_MOV_unsupported_operands	; it's not a memory reference
	
	; memory reference is valid
	mov word [cs:asm86xMovDestMemoryRegInfo], cx	; save reg info
	mov word [cs:asm86xMovDestMemoryImm16], bx		; save imm16 info
	mov word [cs:asm86xMovDestMemoryType], ax		; save type
	mov byte [cs:asm86xMovDestMemorySize], dl		; save size
	;-------------------------------mov mem, XXXX------------------------------
asmx86_MOV_mem_comma_XXXX:
	; handle the mov mem, XXXX case
	; destination is guaranteed to be a valid memory reference
asmx86_MOV_mem_comma_XXXX______check_imm_source:
	mov dx, word [cs:asm86xMovSrcTokenRange]
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_MOV_mem_comma_XXXX______check_register_source
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_MOV_mem_comma_XXXX______check_register_source
	; CX contains an immediate value
	mov word [cs:asm86xMovSourceImm16], cx			; save imm16 source
	
asmx86_MOV_mem_via_reg_offset_comma_imm:
	cmp word [cs:asm86xMovDestMemoryType], 1
	jne asmx86_MOV_mem_via_imm16_offset_comma_imm

	test byte [cs:asm86xMovDestMemorySize], ASMX86_MEM_REFERENCE_SIZE_16BIT
	jz asmx86_MOV_mem8_via_reg_offset_comma_imm8
asmx86_MOV_mem16_via_reg_offset_comma_imm16:
	; we're emitting MOV word [sreg16 : reg16], imm16
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 0C7h
	call asmEmit_emit_byte_from_number		; byte 1: opcode

	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	call asmEmit_emit_byte_from_number		; byte 2: modrm
	mov ax, word [cs:asm86xMovSourceImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: imm16
	
	jmp asmx86_MOV_success
asmx86_MOV_mem8_via_reg_offset_comma_imm8:
	; we're emitting MOV byte [sreg16 : reg16], imm8
	
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 0C6h
	call asmEmit_emit_byte_from_number		; byte 1: opcode

	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	call asmEmit_emit_byte_from_number		; byte 2: modrm
	mov ax, word [cs:asm86xMovSourceImm16]
	call asmEmit_emit_byte_from_number		; byte 3: imm8
	call asmx86_warn_if_value_larger_than_byte
	
	jmp asmx86_MOV_success	
asmx86_MOV_mem_via_imm16_offset_comma_imm:
	cmp word [cs:asm86xMovDestMemoryType], 2
	jne asmx86_MOV_unsupported_operands
	test byte [cs:asm86xMovDestMemorySize], ASMX86_MEM_REFERENCE_SIZE_16BIT
	jz asmx86_MOV_mem8_via_imm16_offset_comma_imm8
asmx86_MOV_mem16_via_imm16_offset_comma_imm16:
	; we're emitting MOV word [sreg16 : imm16], imm16
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 0C7h	
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, 06h	
	call asmEmit_emit_byte_from_number		; byte 2: modrm
	mov ax, word [cs:asm86xMovDestMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset imm16
	mov ax, word [cs:asm86xMovSourceImm16]
	call asmEmit_emit_word_from_number		; bytes 5-6: imm16
	
	jmp asmx86_MOV_success	
asmx86_MOV_mem8_via_imm16_offset_comma_imm8:
	; we're emitting MOV byte [sreg16 : imm16], imm8
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 0C6h	
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, 06h	
	call asmEmit_emit_byte_from_number		; byte 2: modrm
	mov ax, word [cs:asm86xMovDestMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset imm16
	mov ax, word [cs:asm86xMovSourceImm16]
	call asmEmit_emit_byte_from_number		; bytes 5: imm8
	call asmx86_warn_if_value_larger_than_byte
	
	jmp asmx86_MOV_success
asmx86_MOV_mem_comma_XXXX______check_register_source:
	mov bx, word [cs:asm86xMovSrcTokenRange]
	cmp bh, bl
	jne asmx86_MOV_unsupported_operands		; source must be a single token
	
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_MOV_unsupported_operands
	
	mov byte [cs:asm86xMovSourceRegisterInfo], ch	; save register info
	mov cl, byte [cs:asm86xMovDestMemorySize]
	
	and ch, ASMX86_REG_IS_16BIT
	and cl, ASMX86_MEM_REFERENCE_SIZE_16BIT
	xor ch, cl									; different sizes?
	jnz asmx86_MOV_unsupported_operands			; sizes are different
	
	test byte [cs:asm86xMovSourceRegisterInfo], ASMX86_REG_IS_SEGMENT
	jz asmx86_MOV_mem_comma_reg	
asmx86_MOV_mem16_comma_sreg16:
	cmp word [cs:asm86xMovDestMemoryType], 1
	jne asmx86_MOV_mem16_via_imm16_comma_sreg16
asmx86_MOV_mem16_via_offset_register_comma_sreg16:
	; we're emitting MOV word [sreg16 : reg16], sreg16
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Ch
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	
	mov ch, byte [cs:asm86xMovSourceRegisterInfo]
	and ch, ASMX86_REG_MASK_ENCODING		; keep just destination encoding
	shl ch, 3
	or al, ch								; add in destination
	call asmEmit_emit_byte_from_number		; byte 2: offset
	
	jmp asmx86_MOV_success
asmx86_MOV_mem16_via_imm16_comma_sreg16:
	cmp word [cs:asm86xMovDestMemoryType], 2
	jne asmx86_MOV_unsupported_operands
	; we're emitting MOV word [sreg16 : imm16], sreg16
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Ch
	call asmEmit_emit_byte_from_number		; byte 1: opcode	
	
	mov al, byte [cs:asm86xMovSourceRegisterInfo]
	and al, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	shl al, 3
	or al, 00000110b
	
	call asmEmit_emit_byte_from_number		; byte 2: mod rm
	mov ax, word [cs:asm86xMovDestMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset
	
	jmp asmx86_MOV_success
asmx86_MOV_mem_comma_reg:
	test byte [cs:asm86xMovDestMemorySize], ASMX86_MEM_REFERENCE_SIZE_16BIT
	jz asmx86_MOV_mem8_comma_reg8

asmx86_MOV_mem16_comma_reg16:
	cmp word [cs:asm86xMovDestMemoryType], 1
	jne asmx86_MOV_mem16_via_imm16_comma_reg16
asmx86_MOV_mem16_via_reg16_comma_reg16:
	; we're emitting MOV word [sreg16 : reg16], reg16
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 89h
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	
	mov ch, byte [cs:asm86xMovSourceRegisterInfo]
	and ch, ASMX86_REG_MASK_ENCODING		; keep just destination encoding
	shl ch, 3
	or al, ch								; add in destination
	call asmEmit_emit_byte_from_number		; byte 2: offset
	
	jmp asmx86_MOV_success
asmx86_MOV_mem16_via_imm16_comma_reg16:
	cmp word [cs:asm86xMovDestMemoryType], 2
	jne asmx86_MOV_unsupported_operands
	; we're emitting MOV word [sreg16 : imm16], reg16
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 89h
	call asmEmit_emit_byte_from_number		; byte 1: opcode	
	
	mov al, byte [cs:asm86xMovSourceRegisterInfo]
	and al, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	shl al, 3
	or al, 00000110b
	
	call asmEmit_emit_byte_from_number		; byte 2: mod rm
	mov ax, word [cs:asm86xMovDestMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset
	
	jmp asmx86_MOV_success
asmx86_MOV_mem8_comma_reg8:
	cmp word [cs:asm86xMovDestMemoryType], 1
	jne asmx86_MOV_mem8_via_imm16_comma_reg8
asmx86_MOV_mem8_via_reg16_comma_reg8:
	; we're emitting MOV byte [sreg16 : reg16], reg8
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 88h
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	
	mov ch, byte [cs:asm86xMovSourceRegisterInfo]
	and ch, ASMX86_REG_MASK_ENCODING		; keep just destination encoding
	shl ch, 3
	or al, ch								; add in destination
	call asmEmit_emit_byte_from_number		; byte 2: offset
	
	jmp asmx86_MOV_success
asmx86_MOV_mem8_via_imm16_comma_reg8:
	cmp word [cs:asm86xMovDestMemoryType], 2
	jne asmx86_MOV_unsupported_operands
	; we're emitting MOV byte [sreg16 : imm16], reg8
	mov cx, word [cs:asm86xMovDestMemoryRegInfo]
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 88h
	call asmEmit_emit_byte_from_number		; byte 1: opcode	
	
	mov al, byte [cs:asm86xMovSourceRegisterInfo]
	and al, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	shl al, 3
	or al, 00000110b
	
	call asmEmit_emit_byte_from_number		; byte 2: mod rm
	mov ax, word [cs:asm86xMovDestMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset
	
	jmp asmx86_MOV_success
	;----------------------------end of mov mem, XXXX--------------------------
	
	;-------------------------------mov reg, XXXX------------------------------
asmx86_MOV_reg_comma_XXXX:
	; handle the mov reg, XXXX case
	; first token is guaranteed to be a register
asmx86_MOV_reg_comma_XXXX______check_imm_source:
	mov dl, 2									; evaluate expression after
	mov dh, byte [cs:asmCurrentInstTokenCount]	; comma, and up to the end
	dec dh
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_MOV_reg_comma_XXXX______check_register_source

	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_MOV_reg_comma_XXXX______check_register_source
	; CX contains an immediate value

	mov word [cs:asm86xMovImmediateSource], cx
	mov bl, 0
	call asmx86_try_resolve_register_from_token	; we know this succeeds
	test ch, ASMX86_REG_CAN_RECEIVE_IMM			; can register receive imm?
	jz asmx86_MOV_unsupported_operands

	test ch, ASMX86_REG_IS_16BIT				; is it 16bit?
	jz asmx86_MOV_reg8_comma_imm8
asmx86_MOV_reg16_comma_imm16:	
	mov al, 0B8h						; base of   mov r16, imm16
	and ch, 00000111b					; CH := encoded register
	add al, ch							; add encoded register
	call asmEmit_emit_byte_from_number	; opcode
	mov ax, word [cs:asm86xMovImmediateSource]
	call asmEmit_emit_word_from_number	; imm16
	jmp asmx86_MOV_success
asmx86_MOV_reg8_comma_imm8:
	mov al, 0B0h						; base of   mov r8, imm8:
	and ch, 00000111b					; CH := encoded register
	add al, ch							; add encoded register
	call asmEmit_emit_byte_from_number	; opcode
	mov ax, word [cs:asm86xMovImmediateSource]
	call asmEmit_emit_byte_from_number	; imm8
	call asmx86_warn_if_value_larger_than_byte
	jmp asmx86_MOV_success
	
asmx86_MOV_reg_comma_XXXX______check_register_source:
	call asmx86_find_first_comma_token	; BL := index of first comma token
										; guaranteed to not be last
	cmp ax, 0
	je asmx86_MOV_unsupported_operands	; didn't find a comma

	add bl, 2
	cmp bl, byte [cs:asmCurrentInstTokenCount]	; one more token after comma?
	jne asmx86_MOV_reg_comma_XXXX______check_memory_source	; no
	dec bl								; BL := token after comma
	mov byte [cs:asm86xMovSourceRegisterTokenIndex], bl	; save it

	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_MOV_unsupported_operands	; source token is not a register
	mov byte [cs:asm86xMovSourceRegisterInfo], ch	; save source register info

	mov bl, 0
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_MOV_reg_comma_XXXX______check_memory_source
	; see if destination register can receive a source register
	mov byte [cs:asm86xMovDestinationRegisterInfo], ch	; save register info

	test ch, ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	jz asmx86_MOV_unsupported_operands	; it can't
	; destination register can receive a source register

	mov dh, ch										; destination register info
	mov dl, byte [cs:asm86xMovSourceRegisterInfo]	; source register info

	and dh, ASMX86_REG_IS_16BIT						; keep just this bit
	and dl, ASMX86_REG_IS_16BIT						; keep just this bit
	xor dh, dl

	jnz asmx86_MOV_unsupported_operands			; register sizes are different
	; here we know:
	;     - destination and source registers are of the same size
	;     - destination register can receive register
	
asmx86_MOV_sreg16_comma_reg16:
	test byte [cs:asm86xMovDestinationRegisterInfo], ASMX86_REG_IS_SEGMENT
	jz asmx86_MOV_reg16_comma_sreg16
	test byte [cs:asm86xMovSourceRegisterInfo], ASMX86_REG_IS_ASSIGNABLE_TO_SEG
	jz asmx86_MOV_unsupported_operands
	; we're emitting MOV sreg16, reg16
	mov al, 08Eh						; base of   MOV sreg16, reg16
	call asmEmit_emit_byte_from_number	; emit opcode
	mov al, 11000000b					; prefix
	mov cl, byte [cs:asm86xMovDestinationRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	shl cl, 3
	or al, cl							; add in destination register encoding
	mov cl, byte [cs:asm86xMovSourceRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	or al, cl							; add in source register encoding
	call asmEmit_emit_byte_from_number	; emit data byte
	
	jmp asmx86_MOV_success
asmx86_MOV_reg16_comma_sreg16:
	test byte [cs:asm86xMovSourceRegisterInfo], ASMX86_REG_IS_SEGMENT
	jz asmx86_MOV_reg16_comma_reg16
	; we're emitting MOV reg16, sreg16
	mov al, 08Ch						; base of   MOV reg16, sreg16
	call asmEmit_emit_byte_from_number	; emit opcode
	mov al, 11000000b					; prefix
	mov cl, byte [cs:asm86xMovSourceRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	shl cl, 3
	or al, cl							; add in destination register encoding
	mov cl, byte [cs:asm86xMovDestinationRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	or al, cl							; add in source register encoding
	call asmEmit_emit_byte_from_number	; emit data byte
	
	jmp asmx86_MOV_success
asmx86_MOV_reg16_comma_reg16:
	; destination is NOT a segment register
	test byte [cs:asm86xMovDestinationRegisterInfo], ASMX86_REG_IS_16BIT
	jz asmx86_MOV_reg8_comma_reg8
	; we're emitting MOV reg16, reg16
	mov al, 089h						; base of   MOV reg16, reg16
	call asmEmit_emit_byte_from_number	; emit opcode
	mov al, 11000000b					; prefix
	mov cl, byte [cs:asm86xMovSourceRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	shl cl, 3
	or al, cl							; add in destination register encoding
	mov cl, byte [cs:asm86xMovDestinationRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	or al, cl							; add in source register encoding
	call asmEmit_emit_byte_from_number	; emit data byte
	
	jmp asmx86_MOV_success
asmx86_MOV_reg8_comma_reg8:
	; we're emitting MOV reg8, reg8
	mov al, 088h						; base of   MOV reg8, reg8
	call asmEmit_emit_byte_from_number	; emit opcode
	mov al, 11000000b					; prefix
	mov cl, byte [cs:asm86xMovSourceRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	shl cl, 3
	or al, cl							; add in destination register encoding
	mov cl, byte [cs:asm86xMovDestinationRegisterInfo]
	and cl, ASMX86_REG_MASK_ENCODING
	or al, cl							; add in source register encoding
	call asmEmit_emit_byte_from_number	; emit data byte
	jmp asmx86_MOV_success
asmx86_MOV_reg_comma_XXXX______check_memory_source:
	; save info of the destination register
	mov bl, 0
	call asmx86_try_resolve_register_from_token	; we know this succeeds
	test ch, ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP	; can it receive reg or mem?
	jz asmx86_MOV_unsupported_operands			; it can't
	
	mov byte [cs:asm86xMovDestinationRegisterInfo], ch		; save it
	
	; now try to resolve source memory
	call asmx86_find_first_comma_token	; BL := index of first comma token
										; guaranteed to not be last
	cmp ax, 0
	je asmx86_MOV_unsupported_operands	; didn't find a comma
	
	; get information on the memory reference in the source
	inc bl								; BL := first token after comma
	mov bh, byte [cs:asmCurrentInstTokenCount]
	dec bh								; BH := last token
	call asmx86_try_resolve_memory_from_tokens
	
	cmp ax, 0
	je asmx86_MOV_unsupported_operands	; source tokens do not represent a memory
										; reference
	; source memory is valid
	mov word [cs:asm86xMovSourceMemoryRegInfo], cx		; save reg info
	mov word [cs:asm86xMovSourceMemoryImm16], bx	; save imm16 info
	; here, DL has a bit flag indicating memory reference size
	and dl, ASMX86_MEM_REFERENCE_SIZE_16BIT	; keep just the size bit
	mov ch, byte [cs:asm86xMovDestinationRegisterInfo]
	and ch, ASMX86_REG_IS_16BIT				; keep just the size bit
	xor ch, dl
	jnz asmx86_MOV_unsupported_operands		; sizes are different

	; source memory is valid, and its size is valid WRT destination register
	cmp ax, 1							; memory reference via offset register?
	jne asmx86_MOV_reg_comma_memory_via_imm16_check
asmx86_MOV_reg_comma_memory_via_reg16_check:
	; it's of the type    mov reg, size [sreg16 : reg16]
	test byte [cs:asm86xMovDestinationRegisterInfo], ASMX86_REG_IS_16BIT
	jz asmx86_MOV_reg8_comma_memory_via_reg16
	
	test byte [cs:asm86xMovDestinationRegisterInfo], ASMX86_REG_IS_SEGMENT
	jz asmx86_MOV_reg16_comma_memory_via_reg16
asmx86_MOV_sreg16_comma_memory_via_reg16:
	; we're emitting MOV sreg16, word [sreg16 : reg16]
	
	mov cx, word [cs:asm86xMovSourceMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Eh
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	
	mov ch, byte [cs:asm86xMovDestinationRegisterInfo]
	and ch, ASMX86_REG_MASK_ENCODING		; keep just destination encoding
	shl ch, 3
	or al, ch								; add in destination
	call asmEmit_emit_byte_from_number		; byte 2: offset
	jmp asmx86_MOV_success
asmx86_MOV_reg16_comma_memory_via_reg16:
	; we're emitting MOV reg16, word [sreg16 : reg16]
	
	mov cx, word [cs:asm86xMovSourceMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Bh
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	
	mov ch, byte [cs:asm86xMovDestinationRegisterInfo]
	and ch, ASMX86_REG_MASK_ENCODING		; keep just destination encoding
	shl ch, 3
	or al, ch								; add in destination
	call asmEmit_emit_byte_from_number		; byte 2: offset
	jmp asmx86_MOV_success
asmx86_MOV_reg8_comma_memory_via_reg16:
	; we're emitting MOV reg8, byte [sreg16 : reg16]
	
	mov cx, word [cs:asm86xMovSourceMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Ah
	call asmEmit_emit_byte_from_number		; byte 1: opcode
	mov al, ch								; AL := offset register encoding
	and al, ASMX86_REG_MASK_ENCODING		; keep just offset encoding
	call asmx86_convert_reg16_offset_to_modrm	; AL := modrm representation
	
	mov ch, byte [cs:asm86xMovDestinationRegisterInfo]
	and ch, ASMX86_REG_MASK_ENCODING		; keep just destination encoding
	shl ch, 3
	or al, ch								; add in destination
	call asmEmit_emit_byte_from_number		; byte 2: offset
	jmp asmx86_MOV_success
	
asmx86_MOV_reg_comma_memory_via_imm16_check:
	cmp ax, 2							; memory reference via imm16 offset?
	jne asmx86_MOV_unsupported_operands	; no
	; it's of the type    mov reg, size [sreg16 : imm16]
	test byte [cs:asm86xMovDestinationRegisterInfo], ASMX86_REG_IS_16BIT
	jz asmx86_MOV_reg8_comma_memory_via_imm16
	
	test byte [cs:asm86xMovDestinationRegisterInfo], ASMX86_REG_IS_SEGMENT
	jz asmx86_MOV_reg16_comma_memory_via_imm16
asmx86_MOV_sreg16_comma_memory_via_imm16:
	; we're emitting MOV sreg16, word [sreg16 : imm16]
	
	mov cx, word [cs:asm86xMovSourceMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Eh
	call asmEmit_emit_byte_from_number		; byte 1: opcode	
	
	mov al, byte [cs:asm86xMovDestinationRegisterInfo]
	and al, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	shl al, 3
	or al, 00000110b
	
	call asmEmit_emit_byte_from_number		; byte 2: mod rm
	mov ax, word [cs:asm86xMovSourceMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset
	jmp asmx86_MOV_success	
asmx86_MOV_reg16_comma_memory_via_imm16:
	; we're emitting MOV reg16, word [sreg16 : imm16]
	
	mov cx, word [cs:asm86xMovSourceMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Bh
	call asmEmit_emit_byte_from_number		; byte 1: opcode	
	
	mov al, byte [cs:asm86xMovDestinationRegisterInfo]
	and al, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	shl al, 3
	or al, 00000110b
	
	call asmEmit_emit_byte_from_number		; byte 2: mod rm
	mov ax, word [cs:asm86xMovSourceMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset
	jmp asmx86_MOV_success
asmx86_MOV_reg8_comma_memory_via_imm16:
	; we're emitting MOV reg8, byte [sreg16 : imm16]
	
	mov cx, word [cs:asm86xMovSourceMemoryRegInfo]
						; CH - register encoding of offset register
						; CL - register encoding of segment register
	call asmx86_convert_sreg16_encoding_to_override_prefix
						; AL := segment override byte
	call asmEmit_emit_byte_from_number		; byte 0: segment override
	mov al, 8Ah
	call asmEmit_emit_byte_from_number		; byte 1: opcode	
	
	mov al, byte [cs:asm86xMovDestinationRegisterInfo]
	and al, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	shl al, 3
	or al, 00000110b
	
	call asmEmit_emit_byte_from_number		; byte 2: mod rm
	mov ax, word [cs:asm86xMovSourceMemoryImm16]
	call asmEmit_emit_word_from_number		; bytes 3-4: offset
	jmp asmx86_MOV_success
	
	;----------------------------end of mov reg, XXXX------------------------------

asmx86_MOV_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_MOV_error
	
asmx86_MOV_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_MOV_error
	
asmx86_MOV_error:
	mov ax, 0							; "error"
	jmp asmx86_MOV_done
asmx86_MOV_success:
	mov ax, 1							; "success"
asmx86_MOV_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction, INT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_INT:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:asmCurrentInstTokenCount], 0
	je asmx86_INT_tokens
	
	mov dl, 0						; we evaluate from the first token...
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; ...to the last
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_INT_error	; there was an error
	
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_INT_not_a_number
	
	mov al, 0CDh						; INT imm8
	call asmEmit_emit_byte_from_number
	mov ax, cx							; imm8
	call asmEmit_emit_byte_from_number
	call asmx86_warn_if_value_larger_than_byte
	
	mov al, 90h
	call asmEmit_emit_byte_from_number	; pad NOP
		
	jmp asmx86_INT_success

asmx86_INT_not_a_number:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageExpressionMustBeNumeric
	jmp asmx86_INT_error
	
asmx86_INT_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_INT_error
	
asmx86_INT_error:
	mov ax, 0							; "error"
	jmp asmx86_INT_done
asmx86_INT_success:
	mov ax, 1							; "success"
asmx86_INT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
asmx86_core:
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

asmx86_core_LOOPNZ:
	mov di, asmx86KeywordLoopnz
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LOOPNE
	call asmx86_LOOPNE_LOOPNZ
	jmp asmx86_core_done
asmx86_core_LOOPNE:
	mov di, asmx86KeywordLoopne
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LOOPZ
	call asmx86_LOOPNE_LOOPNZ
	jmp asmx86_core_done
asmx86_core_LOOPZ:
	mov di, asmx86KeywordLoopz
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LOOPE
	call asmx86_LOOPE_LOOPZ
	jmp asmx86_core_done
asmx86_core_LOOPE:
	mov di, asmx86KeywordLoope
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LOOP
	call asmx86_LOOPE_LOOPZ
	jmp asmx86_core_done
asmx86_core_LOOP:
	mov di, asmx86KeywordLoop
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_RETN
	call asmx86_LOOP
	jmp asmx86_core_done
asmx86_core_RETN:
	mov di, asmx86KeywordRetn
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CWD
	call asmx86_RET_RETN
	jmp asmx86_core_done
asmx86_core_CWD:
	mov di, asmx86KeywordCwd
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CBW
	call asmx86_CWD
	jmp asmx86_core_done
asmx86_core_CBW:
	mov di, asmx86KeywordCbw
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_XLATB
	call asmx86_CBW
	jmp asmx86_core_done
asmx86_core_XLATB:
	mov di, asmx86KeywordXlatb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_XLAT
	call asmx86_XLAT_XLATB
	jmp asmx86_core_done
asmx86_core_XLAT:
	mov di, asmx86KeywordXlat
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LEAVE
	call asmx86_XLAT_XLATB
	jmp asmx86_core_done
asmx86_core_LEAVE:
	mov di, asmx86KeywordLeave
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_INTO
	call asmx86_LEAVE
	jmp asmx86_core_done
asmx86_core_INTO:
	mov di, asmx86KeywordInto
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_INT3
	call asmx86_INTO
	jmp asmx86_core_done
asmx86_core_INT3:
	mov di, asmx86KeywordInt3
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SALC
	call asmx86_INT3
	jmp asmx86_core_done
asmx86_core_SALC:
	mov di, asmx86KeywordSalc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LAHF
	call asmx86_SALC
	jmp asmx86_core_done
asmx86_core_LAHF:
	mov di, asmx86KeywordLahf
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SAHF
	call asmx86_LAHF
	jmp asmx86_core_done
asmx86_core_SAHF:
	mov di, asmx86KeywordSahf
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CMC
	call asmx86_SAHF
	jmp asmx86_core_done
asmx86_core_CMC:
	mov di, asmx86KeywordCmc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_NOP
	call asmx86_CMC
	jmp asmx86_core_done
asmx86_core_NOP:
	mov di, asmx86KeywordNop
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_HLT
	call asmx86_NOP
	jmp asmx86_core_done
asmx86_core_HLT:
	mov di, asmx86KeywordHlt
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_XCHG
	call asmx86_HLT
	jmp asmx86_core_done
asmx86_core_XCHG:
	mov di, asmx86KeywordXchg
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_TEST
	call asmx86_XCHG
	jmp asmx86_core_done
asmx86_core_TEST:
	mov di, asmx86KeywordTest
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_REPNZ
	call asmx86_TEST
	jmp asmx86_core_done
asmx86_core_REPNZ:
	mov di, asmx86KeywordRepnz
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_REPNE
	call asmx86_REPNE_REPNZ
	jmp asmx86_core_done
asmx86_core_REPNE:
	mov di, asmx86KeywordRepne
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_REPZ
	call asmx86_REPNE_REPNZ
	jmp asmx86_core_done
asmx86_core_REPZ:
	mov di, asmx86KeywordRepz
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_REPE
	call asmx86_REPE_REPZ
	jmp asmx86_core_done
asmx86_core_REPE:
	mov di, asmx86KeywordRepe
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_REP
	call asmx86_REPE_REPZ
	jmp asmx86_core_done
asmx86_core_REP:
	mov di, asmx86KeywordRep
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SCASW
	call asmx86_REP
	jmp asmx86_core_done
asmx86_core_SCASW:
	mov di, asmx86KeywordScasw
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CMPSW
	call asmx86_SCASW
	jmp asmx86_core_done
asmx86_core_CMPSW:
	mov di, asmx86KeywordCmpsw
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_STOSW
	call asmx86_CMPSW
	jmp asmx86_core_done
asmx86_core_STOSW:
	mov di, asmx86KeywordStosw
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LODSW
	call asmx86_STOSW
	jmp asmx86_core_done
asmx86_core_LODSW:
	mov di, asmx86KeywordLodsw
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_MOVSW
	call asmx86_LODSW
	jmp asmx86_core_done
asmx86_core_MOVSW:
	mov di, asmx86KeywordMovsw
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SCASB
	call asmx86_MOVSW
	jmp asmx86_core_done
asmx86_core_SCASB:
	mov di, asmx86KeywordScasb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CMPSB
	call asmx86_SCASB
	jmp asmx86_core_done
asmx86_core_CMPSB:
	mov di, asmx86KeywordCmpsb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_STOSB
	call asmx86_CMPSB
	jmp asmx86_core_done
asmx86_core_STOSB:
	mov di, asmx86KeywordStosb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_LODSB
	call asmx86_STOSB
	jmp asmx86_core_done
asmx86_core_LODSB:
	mov di, asmx86KeywordLodsb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_MOVSB
	call asmx86_LODSB
	jmp asmx86_core_done
asmx86_core_MOVSB:
	mov di, asmx86KeywordMovsb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_OUT
	call asmx86_MOVSB
	jmp asmx86_core_done
asmx86_core_OUT:
	mov di, asmx86KeywordOut
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_IN
	call asmx86_OUT
	jmp asmx86_core_done
asmx86_core_IN:
	mov di, asmx86KeywordIn
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_IDIV
	call asmx86_IN
	jmp asmx86_core_done
asmx86_core_IDIV:
	mov di, asmx86KeywordIdiv
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_DIV
	call asmx86_IDIV
	jmp asmx86_core_done
asmx86_core_DIV:
	mov di, asmx86KeywordDiv
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_IMUL
	call asmx86_DIV
	jmp asmx86_core_done
asmx86_core_IMUL:
	mov di, asmx86KeywordImul
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_MUL
	call asmx86_IMUL
	jmp asmx86_core_done
asmx86_core_MUL:
	mov di, asmx86KeywordMul
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_DEC
	call asmx86_MUL
	jmp asmx86_core_done
asmx86_core_DEC:
	mov di, asmx86KeywordDec
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_INC
	call asmx86_DEC
	jmp asmx86_core_done
asmx86_core_INC:
	mov di, asmx86KeywordInc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_STD
	call asmx86_INC
	jmp asmx86_core_done
asmx86_core_STD:
	mov di, asmx86KeywordStd
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CLD
	call asmx86_STD
	jmp asmx86_core_done
asmx86_core_CLD:
	mov di, asmx86KeywordCld
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_STI
	call asmx86_CLD
	jmp asmx86_core_done
asmx86_core_STI:
	mov di, asmx86KeywordSti
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CLI
	call asmx86_STI
	jmp asmx86_core_done
asmx86_core_CLI:
	mov di, asmx86KeywordCli
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_STC
	call asmx86_CLI
	jmp asmx86_core_done
asmx86_core_STC:
	mov di, asmx86KeywordStc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CLC
	call asmx86_STC
	jmp asmx86_core_done
asmx86_core_CLC:
	mov di, asmx86KeywordClc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_POPF
	call asmx86_CLC
	jmp asmx86_core_done
asmx86_core_POPF:
	mov di, asmx86KeywordPopf
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_PUSHF
	call asmx86_POPF
	jmp asmx86_core_done
asmx86_core_PUSHF:
	mov di, asmx86KeywordPushf
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_POPA
	call asmx86_PUSHF
	jmp asmx86_core_done
asmx86_core_POPA:
	mov di, asmx86KeywordPopa
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_PUSHA
	call asmx86_POPA
	jmp asmx86_core_done
asmx86_core_PUSHA:
	mov di, asmx86KeywordPusha
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_POP
	call asmx86_PUSHA
	jmp asmx86_core_done
asmx86_core_POP:
	mov di, asmx86KeywordPop
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_PUSH
	call asmx86_POP
	jmp asmx86_core_done
asmx86_core_PUSH:
	mov di, asmx86KeywordPush
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_IRET
	call asmx86_PUSH
	jmp asmx86_core_done
asmx86_core_IRET:
	mov di, asmx86KeywordIret
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_RETF
	call asmx86_IRET
	jmp asmx86_core_done
asmx86_core_RETF:
	mov di, asmx86KeywordRetf
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_RET
	call asmx86_RETF
	jmp asmx86_core_done
asmx86_core_RET:
	mov di, asmx86KeywordRet
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Call
	call asmx86_RET_RETN
	jmp asmx86_core_done
asmx86_core_Call:
	mov di, asmx86KeywordCall
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jcxz
	call asmx86_CALL
	jmp asmx86_core_done
asmx86_core_Jcxz:
	mov di, asmx86KeywordJcxz
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jpo
	call asmx86_JCXZ
	jmp asmx86_core_done
asmx86_core_Jpo:
	mov di, asmx86KeywordJpo
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jnp
	call asmx86_JNP_JPO
	jmp asmx86_core_done
asmx86_core_Jnp:
	mov di, asmx86KeywordJnp
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jpe
	call asmx86_JNP_JPO
	jmp asmx86_core_done
asmx86_core_Jpe:
	mov di, asmx86KeywordJpe
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jp
	call asmx86_JP_JPE
	jmp asmx86_core_done
asmx86_core_Jp:
	mov di, asmx86KeywordJp
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jnle
	call asmx86_JP_JPE
	jmp asmx86_core_done
asmx86_core_Jnle:
	mov di, asmx86KeywordJnle
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jg
	call asmx86_JG_JNLE
	jmp asmx86_core_done
asmx86_core_Jg:
	mov di, asmx86KeywordJg
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jng
	call asmx86_JG_JNLE
	jmp asmx86_core_done
asmx86_core_Jng:
	mov di, asmx86KeywordJng
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jle
	call asmx86_JLE_JNG
	jmp asmx86_core_done
asmx86_core_Jle:
	mov di, asmx86KeywordJle
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jnl
	call asmx86_JLE_JNG
	jmp asmx86_core_done
asmx86_core_Jnl:
	mov di, asmx86KeywordJnl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jge
	call asmx86_JGE_JNL
	jmp asmx86_core_done
asmx86_core_Jge:
	mov di, asmx86KeywordJge
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_Jnge
	call asmx86_JGE_JNL
	jmp asmx86_core_done
asmx86_core_Jnge:
	mov di, asmx86KeywordJnge
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JL
	call asmx86_JL_JNGE
	jmp asmx86_core_done
asmx86_core_JL:
	mov di, asmx86KeywordJl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNBE
	call asmx86_JL_JNGE
	jmp asmx86_core_done
asmx86_core_JNBE:
	mov di, asmx86KeywordJnbe
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JA
	call asmx86_JA_JNBE
	jmp asmx86_core_done
asmx86_core_JA:
	mov di, asmx86KeywordJa
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNA
	call asmx86_JA_JNBE
	jmp asmx86_core_done
asmx86_core_JNA:
	mov di, asmx86KeywordJna
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JBE
	call asmx86_JBE_JNA
	jmp asmx86_core_done
asmx86_core_JBE:
	mov di, asmx86KeywordJbe
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNC
	call asmx86_JBE_JNA
	jmp asmx86_core_done
asmx86_core_JNC:
	mov di, asmx86KeywordJnc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JAE
	call asmx86_JNB_JAE_JNC
	jmp asmx86_core_done
asmx86_core_JAE:
	mov di, asmx86KeywordJae
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNB
	call asmx86_JNB_JAE_JNC
	jmp asmx86_core_done
asmx86_core_JNB:
	mov di, asmx86KeywordJnb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JC
	call asmx86_JNB_JAE_JNC
	jmp asmx86_core_done	
asmx86_core_JC:
	mov di, asmx86KeywordJc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNAE
	call asmx86_JB_JNAE_JC
	jmp asmx86_core_done
asmx86_core_JNAE:
	mov di, asmx86KeywordJnae
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JB
	call asmx86_JB_JNAE_JC
	jmp asmx86_core_done
asmx86_core_JB:
	mov di, asmx86KeywordJb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNZ
	call asmx86_JB_JNAE_JC
	jmp asmx86_core_done
asmx86_core_JNZ:
	mov di, asmx86KeywordJnz
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNE
	call asmx86_JNE_JNZ
	jmp asmx86_core_done
asmx86_core_JNE:
	mov di, asmx86KeywordJne
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JZ
	call asmx86_JNE_JNZ
	jmp asmx86_core_done
asmx86_core_JZ:
	mov di, asmx86KeywordJz
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JE
	call asmx86_JE_JZ
	jmp asmx86_core_done
asmx86_core_JE:
	mov di, asmx86KeywordJe
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNS
	call asmx86_JE_JZ
	jmp asmx86_core_done
asmx86_core_JNS:
	mov di, asmx86KeywordJns
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JS
	call asmx86_JNS
	jmp asmx86_core_done
asmx86_core_JS:
	mov di, asmx86KeywordJs
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JNO
	call asmx86_JS
	jmp asmx86_core_done
asmx86_core_JNO:
	mov di, asmx86KeywordJno
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JO
	call asmx86_JNO
	jmp asmx86_core_done
asmx86_core_JO:
	mov di, asmx86KeywordJo
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SAR
	call asmx86_JO
	jmp asmx86_core_done
asmx86_core_SAR:
	mov di, asmx86KeywordSar
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SHR
	call asmx86_SAR
	jmp asmx86_core_done
asmx86_core_SHR:
	mov di, asmx86KeywordShr
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SAL
	call asmx86_SHR
	jmp asmx86_core_done
asmx86_core_SAL:
	mov di, asmx86KeywordSal
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SHL
	call asmx86_SHL_SAL
	jmp asmx86_core_done
asmx86_core_SHL:
	mov di, asmx86KeywordShl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_RCR
	call asmx86_SHL_SAL
	jmp asmx86_core_done
asmx86_core_RCR:
	mov di, asmx86KeywordRcr
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_RCL
	call asmx86_RCR
	jmp asmx86_core_done
asmx86_core_RCL:
	mov di, asmx86KeywordRcl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_ROR
	call asmx86_RCL
	jmp asmx86_core_done
asmx86_core_ROR:
	mov di, asmx86KeywordRor
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_ROL
	call asmx86_ROR
	jmp asmx86_core_done
asmx86_core_ROL:
	mov di, asmx86KeywordRol
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_CMP
	call asmx86_ROL
	jmp asmx86_core_done
asmx86_core_CMP:
	mov di, asmx86KeywordCmp
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_XOR
	call asmx86_CMP
	jmp asmx86_core_done
asmx86_core_XOR:
	mov di, asmx86KeywordXor
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SUB
	call asmx86_XOR
	jmp asmx86_core_done
asmx86_core_SUB:
	mov di, asmx86KeywordSub
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_AND
	call asmx86_SUB
	jmp asmx86_core_done
asmx86_core_AND:
	mov di, asmx86KeywordAnd
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_SBB
	call asmx86_AND
	jmp asmx86_core_done
asmx86_core_SBB:
	mov di, asmx86KeywordSbb
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_ADC
	call asmx86_SBB
	jmp asmx86_core_done
asmx86_core_ADC:
	mov di, asmx86KeywordAdc
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_OR
	call asmx86_ADC
	jmp asmx86_core_done
asmx86_core_OR:
	mov di, asmx86KeywordOr
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_ADD
	call asmx86_OR
	jmp asmx86_core_done
asmx86_core_ADD:
	mov di, asmx86KeywordAdd
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_JMP
	call asmx86_ADD
	jmp asmx86_core_done
asmx86_core_JMP:
	mov di, asmx86KeywordJmp
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_MOV
	call asmx86_JMP
	jmp asmx86_core_done
asmx86_core_MOV:
	mov di, asmx86KeywordMov
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_INT
	call asmx86_MOV
	jmp asmx86_core_done
asmx86_core_INT:
	mov di, asmx86KeywordInt
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_core_UNKNOWN
	call asmx86_INT
	jmp asmx86_core_done
asmx86_core_UNKNOWN:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageCantExecuteUnknownOpcode
	mov ax, 0									; "error"
	jmp asmx86_core_done
	
asmx86_core_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret


%endif
