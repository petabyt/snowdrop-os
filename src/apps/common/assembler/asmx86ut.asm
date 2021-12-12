;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for Snowdrop OS's assembler.
;
; Contents of this file are x86-specific.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_X86_UTILITIES_
%define _COMMON_ASM_X86_UTILITIES_

	
; Checks whether the input string represents a register
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 if token does not contain a register, other value otherwise
asmx86_is_reserved_word:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	call asmx86_try_resolve_register
	cmp ax, 0
	jne asmx86_is_reserved_word_yes
	
	; check IP
	mov ax, cs
	mov es, ax
	mov di, asmx86RegIp
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_is_reserved_word_no
	
	; check "word" and "byte"
	mov di, asmx86ReservedWord
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_is_reserved_word_no
	mov di, asmx86ReservedByte
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_is_reserved_word_no

asmx86_is_reserved_word_yes:
	mov ax, 1
	jmp asmx86_is_reserved_word_done
asmx86_is_reserved_word_no:
	mov ax, 0
asmx86_is_reserved_word_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	

; Tries to resolve a register from a token
;
; input:
;		BL - token index
; output:
;		AX - 0 if token does not contain a register, other value otherwise	
;		CL - register
;		CH - bits 0-2 - encoded register value
;			 bit    3 - set when register can receive immediate value via MOV
;			 bit    4 - set when register is 16bit, clear when 8bit
;			 bit    5 - set when register can receive register via MOV
;			 bit    6 - set when register is a segment register
;			 bit    7 - set when register is assignable to a segment register
;		DL - bit    0 - set when register can be used as an offset in a mem ref
;			 bits 1-7 - unused
asmx86_try_resolve_register_from_token:
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	call asmInterpreter_get_instruction_token_near_ptr
	mov si, di						; DS:SI := pointer to token
	
	call asmx86_try_resolve_register
	
	pop es
	pop ds
	ret
	

; Tries to resolve a register from a string
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 if token does not contain a register, other value otherwise	
;		CL - register
;		CH - bits 0-2 - encoded register value
;			 bit    3 - set when register can receive immediate value via MOV
;			 bit    4 - set when register is 16bit, clear when 8bit
;			 bit    5 - set when register can receive register via MOV
;			 bit    6 - set when register is a segment register
;			 bit    7 - set when register is assignable to a segment register
;		DL - bit    0 - set when register can be used as an offset in a mem ref
;			 bits 1-7 - unused
asmx86_try_resolve_register:
	push ds
	push es
	push si
	push di
	push bx
	
	mov ax, cs
	mov es, ax
	
asmx86_try_resolve_register_GS:
	mov di, asmx86RegGs
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_FS
	; it's this register
	mov cl, ASMX86_REG_GS
	mov ch, 101b							; encoding
	or ch, ASMX86_REG_IS_16BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP | ASMX86_REG_IS_SEGMENT
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_FS:
	mov di, asmx86RegFs
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_DS
	; it's this register
	mov cl, ASMX86_REG_FS
	mov ch, 100b							; encoding
	or ch, ASMX86_REG_IS_16BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP | ASMX86_REG_IS_SEGMENT
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_DS:
	mov di, asmx86RegDs
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_SS
	; it's this register
	mov cl, ASMX86_REG_DS
	mov ch, 011b							; encoding
	or ch, ASMX86_REG_IS_16BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP | ASMX86_REG_IS_SEGMENT
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_SS:
	mov di, asmx86RegSs
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_ES
	; it's this register
	mov cl, ASMX86_REG_SS
	mov ch, 010b							; encoding
	or ch, ASMX86_REG_IS_16BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP | ASMX86_REG_IS_SEGMENT
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_ES:
	mov di, asmx86RegEs
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_CS
	; it's this register
	mov cl, ASMX86_REG_ES
	mov ch, 000b							; encoding
	or ch, ASMX86_REG_IS_16BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP | ASMX86_REG_IS_SEGMENT
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_CS:
	mov di, asmx86RegCs
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_DH
	; it's this register
	mov cl, ASMX86_REG_CS
	mov ch, 001b							; encoding
	or ch, ASMX86_REG_IS_16BIT | ASMX86_REG_IS_SEGMENT
	mov dl, 0
	jmp asmx86_try_resolve_register_valid

asmx86_try_resolve_register_DH:
	mov di, asmx86RegDh
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_DL
	; it's this register
	mov cl, ASMX86_REG_DH
	mov ch, 110b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_DL:
	mov di, asmx86RegDl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_CH
	; it's this register
	mov cl, ASMX86_REG_DL
	mov ch, 010b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_CH:
	mov di, asmx86RegCh
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_CL
	; it's this register
	mov cl, ASMX86_REG_CH
	mov ch, 101b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_CL:
	mov di, asmx86RegCl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_BH
	; it's this register
	mov cl, ASMX86_REG_CL
	mov ch, 001b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_BH:
	mov di, asmx86RegBh
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_BL
	; it's this register
	mov cl, ASMX86_REG_BH
	mov ch, 111b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_BL:
	mov di, asmx86RegBl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_AH
	; it's this register
	mov cl, ASMX86_REG_BL
	mov ch, 011b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_AH:
	mov di, asmx86RegAh
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_AL
	; it's this register
	mov cl, ASMX86_REG_AH
	mov ch, 100b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_AL:
	mov di, asmx86RegAl
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_BP
	; it's this register
	mov cl, ASMX86_REG_AL
	mov ch, 000b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_8BIT | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_BP:
	mov di, asmx86RegBp
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_SP
	; it's this register
	mov cl, ASMX86_REG_BP
	mov ch, 101b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_SP:
	mov di, asmx86RegSp
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_DI
	; it's this register
	mov cl, ASMX86_REG_SP
	mov ch, 100b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_DI:
	mov di, asmx86RegDi
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_SI
	; it's this register
	mov cl, ASMX86_REG_DI
	mov ch, 111b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	or dl, ASMX86_REG_IS_VALID_OFFSET
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_SI:
	mov di, asmx86RegSi
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_DX
	; it's this register
	mov cl, ASMX86_REG_SI
	mov ch, 110b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	or dl, ASMX86_REG_IS_VALID_OFFSET
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_DX:
	mov di, asmx86RegDx
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_CX
	; it's this register
	mov cl, ASMX86_REG_DX
	mov ch, 010b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_CX:
	mov di, asmx86RegCx
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_BX
	; it's this register
	mov cl, ASMX86_REG_CX
	mov ch, 001b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_BX:
	mov di, asmx86RegBx
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_AX
	; it's this register
	mov cl, ASMX86_REG_BX
	mov ch, 011b							; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	or dl, ASMX86_REG_IS_VALID_OFFSET
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_AX:
	mov di, asmx86RegAx
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_register_invalid
	; it's this register
	mov cl, ASMX86_REG_AX
	mov ch, 0								; encoding
	or ch, ASMX86_REG_CAN_RECEIVE_IMM | ASMX86_REG_IS_16BIT | ASMX86_REG_IS_ASSIGNABLE_TO_SEG | ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP
	mov dl, 0
	jmp asmx86_try_resolve_register_valid
	
asmx86_try_resolve_register_invalid:
	mov ax, 0
	jmp asmx86_try_resolve_register_done
asmx86_try_resolve_register_valid:
	mov ax, 1
asmx86_try_resolve_register_done:
	pop bx
	pop di
	pop si
	pop es
	pop ds
	ret
	
	
; Checks whether the specified token is a comma
;
; input:
;		BL - token number
; output:
;		AX - 0 if token is not a comma, other value otherwise
asmx86_is_token_comma:
	push ds
	push es
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	call asmInterpreter_get_instruction_token_near_ptr
	mov si, asmArgumentDelimiterToken
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_is_token_comma_no
	
asmx86_is_token_comma_yes:
	mov ax, 1
	jmp asmx86_is_token_comma_done
asmx86_is_token_comma_no:
	mov ax, 0
asmx86_is_token_comma_done:	
	pop di
	pop si
	pop es
	pop ds
	ret
	
	
; Warns user whether the specified number requires 2 bytes to be represented
;
; input:
;		AX - number
; output:
;		none
asmx86_warn_if_value_larger_than_byte:
	call asmUtil_warn_if_value_larger_than_byte
	ret

	
; Warns user whether the specified signed number requires 2 bytes 
; to be represented
;
; input:
;		AX - number
; output:
;		none
asmx86_warn_if_signed_value_larger_than_byte:
	push si
	push ds
	
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmx86_warn_if_signed_value_larger_than_byte_done	; we warn only in pass 2
	
	cmp ax, -128
	jl asmx86_warn_if_signed_value_larger_than_byte_warn
	cmp ax, 127
	jg asmx86_warn_if_signed_value_larger_than_byte_warn
	
	jmp asmx86_warn_if_signed_value_larger_than_byte_done
		
asmx86_warn_if_signed_value_larger_than_byte_warn:
	; warn
	call asm_display_ASM_tag
	push cs
	pop ds
	mov si, asmMessageWarnSingleByteOverflow
	call asm_display_worker
asmx86_warn_if_signed_value_larger_than_byte_done:
	pop ds
	pop si
	ret
	
	
; Finds the index of the comma token in the current instruction tokens
; if and only if:
;     - a comma token exists
;     - comma token is not last token of the instruction
;
; input:
;		none
; output:
;		AX - 0 when a comma token was not found, other value otherwise
;		BL - index of first comma token, when one was found
asmx86_find_first_comma_token:
	push cx
	push dx
	
	cmp byte [cs:asmCurrentInstTokenCount], 2
	jb asmx86_find_first_comma_token_fail		; need at least two tokens
	
	mov bh, byte [cs:asmCurrentInstTokenCount]
	sub bh, 2									; BH := last candidate index
	
	mov bl, 0									; start at first token
asmx86_find_first_comma_token_loop:
	cmp bl, bh
	ja asmx86_find_first_comma_token_fail		; we're past last candidate
	
	call asmx86_is_token_comma
	cmp ax, 0
	jne asmx86_find_first_comma_success			; we found a comma token
	
	inc bl
	jmp asmx86_find_first_comma_token_loop		; next token
	
asmx86_find_first_comma_token_fail:
	mov ax, 0
	jmp asmx86_find_first_comma_done
asmx86_find_first_comma_success:
	mov ax, 1
asmx86_find_first_comma_done:
	pop dx
	pop cx
	ret

	
; Converts the encoding of a segment register to its modrm byte.
;
; input:	
;		AL - encoding of register
; output:
;		AL - modrm byte for memory reference
asmx86_convert_reg16_offset_to_modrm:
asmx86_convert_reg16_offset_to_modrm_SI:
	cmp al, 110b
	jne asmx86_convert_reg16_offset_to_modrm_DI
	mov al, 100b
	jmp asmx86_convert_reg16_offset_to_modrm_done
asmx86_convert_reg16_offset_to_modrm_DI:
	cmp al, 111b
	jne asmx86_convert_reg16_offset_to_modrm_BX
	mov al, 101b
	jmp asmx86_convert_reg16_offset_to_modrm_done
asmx86_convert_reg16_offset_to_modrm_BX:
	mov al, 111b
	
asmx86_convert_reg16_offset_to_modrm_done:
	ret
	
	
; Converts the encoding of a segment register to its segment override
; prefix byte.
; This is used in memory referencing, where a segment register is specified.
;
; input:	
;		CL - register encoding of segment register
; output:
;		AL - segment override prefix
asmx86_convert_sreg16_encoding_to_override_prefix:
asmx86_convert_sreg16_encoding_to_override_prefix_ES:
	cmp cl, 000b
	jne asmx86_convert_sreg16_encoding_to_override_prefix_CS
	mov al, 26h
	jmp asmx86_convert_sreg16_encoding_to_override_prefix_done
asmx86_convert_sreg16_encoding_to_override_prefix_CS:
	cmp cl, 001b
	jne asmx86_convert_sreg16_encoding_to_override_prefix_SS
	mov al, 2Eh
	jmp asmx86_convert_sreg16_encoding_to_override_prefix_done
asmx86_convert_sreg16_encoding_to_override_prefix_SS:
	cmp cl, 010b
	jne asmx86_convert_sreg16_encoding_to_override_prefix_DS
	mov al, 36h
	jmp asmx86_convert_sreg16_encoding_to_override_prefix_done
asmx86_convert_sreg16_encoding_to_override_prefix_DS:
	cmp cl, 011b
	jne asmx86_convert_sreg16_encoding_to_override_prefix_FS
	mov al, 3Eh
	jmp asmx86_convert_sreg16_encoding_to_override_prefix_done
asmx86_convert_sreg16_encoding_to_override_prefix_FS:
	cmp cl, 100b
	jne asmx86_convert_sreg16_encoding_to_override_prefix_GS
	mov al, 64h
	jmp asmx86_convert_sreg16_encoding_to_override_prefix_done
asmx86_convert_sreg16_encoding_to_override_prefix_GS:
	mov al, 65h
	
asmx86_convert_sreg16_encoding_to_override_prefix_done:
	ret
	
	
; Tries to resolve a memory reference from a range of tokens.
; The following forms are supported:
;		word [sreg16 : reg16]
;		byte [sreg16 : reg16]
;		word [sreg16 : imm16]
;		byte [sreg16 : imm16]
;
; input:
;		BL - first token to be considered
;		BH - last token to be considered
; output:
;		AX - 0 if tokens do not contain a memory reference
;			 1 if tokens contain a memory reference via offset register
;			 2 if tokens contain a memory reference via imm16 offset
;		DL - bits 0-3 - unused
;			 bit    4 - set when memory reference is 16bit, clear when 8bit
;			 bits 5-7 - unused
;
;		(when memory reference is via an offset register)
;		CH - register encoding of offset register
;		CL - register encoding of segment register
;
;		(when memory reference is via an imm16 offset)
;		CL - register encoding of segment register
;		BX - imm16 offset
asmx86_try_resolve_memory_from_tokens:
	push ds
	push es
	push si
	push di
	
	mov byte [cs:asmx86TryResolveMemResultSize], 0
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov ch, bh
	sub ch, bl
	inc ch									; CH := token count
	cmp ch, 6
	jb asmx86_try_resolve_memory_from_tokens_no	; not enough tokens

asmx86_try_resolve_memory_from_tokens_try16bit:
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := ptr to first token
	mov di, asmx86ReservedWord
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_memory_from_tokens_try8bit
	or byte [cs:asmx86TryResolveMemResultSize], ASMX86_MEM_REFERENCE_SIZE_16BIT
	jmp asmx86_try_resolve_memory_from_tokens_got_size
asmx86_try_resolve_memory_from_tokens_try8bit:
	mov di, asmx86ReservedByte
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_memory_from_tokens_no	; token isn't a bracket
	or byte [cs:asmx86TryResolveMemResultSize], ASMX86_MEM_REFERENCE_SIZE_8BIT
	
asmx86_try_resolve_memory_from_tokens_got_size:
	inc bl									; BL := second token
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := ptr to second token
	mov di, asmx86OpenPointerBracket
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_memory_from_tokens_no	; token isn't a bracket
	
	xchg bh, bl								; BL := last token, BH := second
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := ptr to last token
	mov di, asmx86ClosedPointerBracket
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_memory_from_tokens_no	; token isn't a bracket
	xchg bh, bl								; BL := second token, BH := last
	
	; here, we know size of memory reference (16bit or 8bit), and that we
	; have brackets in the corrects spots
	inc bl									; BL := first token inside [
	dec bh									; BH := last token inside ]
	mov word [cs:asmx86TryResolveMemFirstAndLastIndicesInsideBrackets], bx
	
	inc bl									; BL := second token inside [
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := ptr to last token
	mov di, asmx86SegmentOffsetSeparatorToken
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asmx86_try_resolve_memory_from_tokens_no	; it's not a :

	dec bl									; BL := first token inside [
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_try_resolve_memory_from_tokens_no
	test ch, ASMX86_REG_IS_SEGMENT			; must be a segment register
	jz asmx86_try_resolve_memory_from_tokens_no
	mov cl, ch								; CL := encoding
	and cl, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	mov byte [cs:asmx86TryResolveMemSegmentRegisterEncoding], cl	; save it
	
	mov word bx, [cs:asmx86TryResolveMemFirstAndLastIndicesInsideBrackets]
												; BL := first token inside [
												; BH := last token inside ]
	add bl, 2			; BL := first token of offset
	mov word [cs:asmx86TryResolveMemFirstAndLastIndicesOfOffset], bx	; save
	cmp bh, bl			; offset is made up of a single token?
	ja asmx86_try_resolve_memory_from_tokens____check_imm16_offset	; no
asmx86_try_resolve_memory_from_tokens____check_reg16_offset:	
	; offset is made up of a single token, which could be a register
	
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_try_resolve_memory_from_tokens____check_imm16_offset
	; the single token of the offset is a register
	test dl, ASMX86_REG_IS_VALID_OFFSET
	jz asmx86_try_resolve_memory_from_tokens_no
	; the single token of the offset is a valid register
	; so we return
	and ch, ASMX86_REG_MASK_ENCODING		; get rid of unwanted bits
	mov cl, byte [cs:asmx86TryResolveMemSegmentRegisterEncoding]
	mov ax, 1								; "offset via register"
	mov dl, 0
	or dl, byte [cs:asmx86TryResolveMemResultSize]
	jmp asmx86_try_resolve_memory_from_tokens_done
	
asmx86_try_resolve_memory_from_tokens____check_imm16_offset:
	mov dx, word [cs:asmx86TryResolveMemFirstAndLastIndicesOfOffset]
									; DL := first token of offset
									; DH := last token of offset
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_try_resolve_memory_from_tokens_no	; there was an error

	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_try_resolve_memory_from_tokens_no
	; the offset was resolved to an imm16
	; so we return
	mov bx, cx						; we return imm16 offset in BX
	mov cl, byte [cs:asmx86TryResolveMemSegmentRegisterEncoding]
	mov dl, 0
	or dl, byte [cs:asmx86TryResolveMemResultSize]
	mov ax, 2 								; "offset via imm16"
	jmp asmx86_try_resolve_memory_from_tokens_done
	
asmx86_try_resolve_memory_from_tokens_no:
	mov ax, 0
	jmp asmx86_try_resolve_memory_from_tokens_done
asmx86_try_resolve_memory_from_tokens_done:
	pop di
	pop si
	pop es
	pop ds
	ret

	
; Tries to resolve a simple combination of destination and source
; from the entirety of the current instruction.
; Performs size match checking when destination and source are both registers.
; Segment registers are not supported.
;
; Simple combinations are:
;		reg16, reg16
;		reg16, imm16
;		reg8, reg8
;		reg8, imm16
;
; input:
;		none
; output:
;		AX - 0 if instruction does not contain a simple combination
;			 1 if combination is reg, reg
;			 2 if combination is reg, imm16
;		CL - register encoding of destination register
;		CH - like CL but for source register, when one is present
;		DL - bits 0-3 - unused
;			 bit    4 - set when operand sizes are 16bit, clear when 8bit
;			 bits 5-7 - unused
;		BX - imm16, when one is present
asmx86_try_resolve_simple:
	push si
	push di
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:asmCurrentInstTokenCount], 3
	jb asmx86_try_resolve_simple_invalid	; need at least three tokens
	
	mov bl, 1								; second token must be comma
	call asmx86_is_token_comma
	cmp ax, 0
	je asmx86_try_resolve_simple_invalid
asmx86_try_resolve_simple_destination:	
	mov bl, 0
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_try_resolve_simple_invalid
	mov byte [cs:asmx86TryResolveSimpleDestinationRegInfo], ch	; save it
	
	test ch, ASMX86_REG_IS_SEGMENT
	jnz asmx86_try_resolve_simple_invalid
	
	; destination is a register
	
asmx86_try_resolve_simple_source:
	cmp byte [cs:asmCurrentInstTokenCount], 3	; if it has more than 3 tokens
	ja asmx86_try_resolve_simple_source_imm16	; it can't be reg, reg
	
	mov bl, 2
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_try_resolve_simple_source_imm16
	; source is a register
	test ch, ASMX86_REG_IS_SEGMENT
	jnz asmx86_try_resolve_simple_invalid
	
	mov dh, ch													; source 
	mov dl, byte [cs:asmx86TryResolveSimpleDestinationRegInfo]	; destination
	and dh, ASMX86_REG_IS_16BIT
	and dl, ASMX86_REG_IS_16BIT
	xor dh, dl
	jnz asmx86_try_resolve_simple_invalid						; sizes differ
	; sizes match
	; here, DL contains size bit
	; here, CH = source register info
	and ch, ASMX86_REG_MASK_ENCODING			; keep just the encoding
	mov cl, byte [cs:asmx86TryResolveSimpleDestinationRegInfo]
	and cl, ASMX86_REG_MASK_ENCODING			; keep just the encoding
	mov ax, 1									; reg, reg
	jmp asmx86_try_resolve_simple_done
	
asmx86_try_resolve_simple_source_imm16:
	mov dl, 2						; DL := first token of source
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; DH := last token of source
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_try_resolve_simple_invalid
	
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_try_resolve_simple_invalid
	mov bx, cx						; BX := imm16
	mov cl, byte [cs:asmx86TryResolveSimpleDestinationRegInfo]
	and cl, ASMX86_REG_MASK_ENCODING			; keep just the encoding
	mov dl, byte [cs:asmx86TryResolveSimpleDestinationRegInfo]
	and dl, ASMX86_REG_IS_16BIT		; size
	mov ax, 2						; reg, imm16
	jmp asmx86_try_resolve_simple_done
	
asmx86_try_resolve_simple_invalid:
	mov ax, 0
asmx86_try_resolve_simple_done:
	pop es
	pop ds
	pop di
	pop si
	ret
	
	
; Tries to resolve modrm byte plus information from the current instruction.
; Only succeeds when the current instruction has a simple combination of 
; operands.
;
; Simple combinations are:
;		reg16, reg16
;		reg16, imm16
;		reg8, reg8
;		reg8, imm16
;
; input:
;		none
; output:
;		AX - 0 if unsuccessful
;			 1 if combination is reg, reg
;			 2 if combination is reg, imm
;		DL - modrm byte:
;			 bits 0-1 - addressing mode
;			 bits 2-4 - zero when destination is immediate,
;						register encoding otherwise
;			 bits 5-7 - register encoding
;		DH - opcode byte size modifier:
;			 bit    0 - set when operand sizes are 16bit, clear when 8bit
;			 bit    1 - set when destination is a register
;			 bits 2-7 - zero
;		BX - imm16 source, if one is present
asmx86_try_resolve_modrm_simple:
	push cx

	call asmx86_try_resolve_simple
	cmp ax, 0
	je asmx86_try_resolve_modrm_simple_invalid

	cmp ax, 1
	jne asmx86_try_resolve_modrm_simple_reg_imm16
asmx86_try_resolve_modrm_simple_reg_reg:
	test dl, ASMX86_REG_IS_16BIT
	jz asmx86_try_resolve_modrm_simple_reg8_reg8
asmx86_try_resolve_modrm_simple_reg16_reg16:
	; we're handling XXX reg16, reg16
	mov dl, 11000000b					; "register addressing mode"
	shl ch, 3
	or dl, ch							; source
	or dl, cl							; destination
	mov dh, ASMX86_OPCODE_FLAG_16BIT
	mov ax, 1
	jmp asmx86_try_resolve_modrm_simple_done
asmx86_try_resolve_modrm_simple_reg8_reg8:
	; we're handling XXX reg8, reg8
	mov dl, 11000000b					; "register addressing mode"
	shl ch, 3
	or dl, ch							; source
	or dl, cl							; destination
	mov dh, 0
	mov ax, 1
	jmp asmx86_try_resolve_modrm_simple_done
asmx86_try_resolve_modrm_simple_reg_imm16:
	cmp ax, 2
	jne asmx86_try_resolve_modrm_simple_invalid
	test dl, ASMX86_REG_IS_16BIT
	jz asmx86_try_resolve_modrm_simple_reg8_imm16
asmx86_try_resolve_modrm_simple_reg16_imm16:
	; we're handling XXX reg16, imm16
	mov dl, 11000000b					; "register addressing mode"
	or dl, cl							; destination
	mov dh, ASMX86_OPCODE_FLAG_16BIT
	mov ax, 2
	jmp asmx86_try_resolve_modrm_simple_done
asmx86_try_resolve_modrm_simple_reg8_imm16:
	; we're handling XXX reg8, imm16
	mov dl, 11000000b					; "register addressing mode"
	or dl, cl							; destination
	mov dh, 0
	mov ax, 2
	jmp asmx86_try_resolve_modrm_simple_done
asmx86_try_resolve_modrm_simple_invalid:
	mov ax, 0	
asmx86_try_resolve_modrm_simple_done:
	pop cx
	ret

	
; Tries to emit an instruction based on a simple combination of operands.
; Restricted to cases where the source is imm8.
;
; Simple combinations are:
;		reg16, imm8
;		reg8, imm8
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		BL - base opcode for XXX reg, imm
;		BH - opcode extension for XXX reg, imm:
;			 bits 0-2 - opcode extension
;			 bits 3-7 - zero
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_simple_imm8_source:
	push bx
	push cx
	push dx

	mov byte [cs:asmx86EmitSimpleImm8SourceOpcodeRegImm], bl
	shl bh, 3
	mov byte [cs:asmx86EmitSimpleImm8SourceModrmExtensionRegImm], bh
	
	call asmx86_try_resolve_modrm_simple
			; AX - 0 if unsuccessful
			;      1 if combination is reg, reg
			;      2 if combination is reg, imm
			; DL - modrm byte:
			;      bits 0-1 - addressing mode
			;      bits 2-4 - zero when destination is immediate,
			;                 register encoding otherwise
			;      bits 5-7 - register encoding
			; DH - opcode byte size modifier:
			;      bit    0 - set when operand sizes are 16bit, clear when 8bit
			;      bit    1 - set when destination is a register
			;      bits 2-7 - zero
			; BX - imm16 source, if one is present
	cmp ax, 0
	je asmx86_try_emit_simple_imm8_source_invalid
	
	cmp ax, 1
	je asmx86_try_emit_simple_imm8_source_invalid
	
asmx86_try_emit_simple_imm8_source_reg_imm:
	cmp ax, 2
	jne asmx86_try_emit_simple_imm8_source_invalid
	test dh, 00000001b
	jz asmx86_try_emit_simple_imm8_source_reg_imm8
asmx86_try_emit_simple_imm8_source_reg_imm16:
	; reg, imm16
	mov al, byte [cs:asmx86EmitSimpleImm8SourceOpcodeRegImm]
	or al, dh									; add in size and direction
	call asmEmit_emit_byte_from_number			; emit opcode
	mov al, dl
	or al, byte [cs:asmx86EmitSimpleImm8SourceModrmExtensionRegImm]
	call asmEmit_emit_byte_from_number			; emit modrm
	mov ax, bx
	call asmEmit_emit_byte_from_number			; emit imm8
	call asmx86_warn_if_value_larger_than_byte
	jmp asmx86_try_emit_simple_imm8_source_valid
	
asmx86_try_emit_simple_imm8_source_reg_imm8:
	; reg, imm8
	mov al, byte [cs:asmx86EmitSimpleImm8SourceOpcodeRegImm]
	or al, dh									; add in size and direction
	call asmEmit_emit_byte_from_number			; emit opcode
	mov al, dl
	or al, byte [cs:asmx86EmitSimpleImm8SourceModrmExtensionRegImm]
	call asmEmit_emit_byte_from_number			; emit modrm
	mov ax, bx
	call asmEmit_emit_byte_from_number			; emit imm8
	call asmx86_warn_if_value_larger_than_byte
	jmp asmx86_try_emit_simple_imm8_source_valid
	
asmx86_try_emit_simple_imm8_source_invalid:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	mov ax, 0
	jmp asmx86_try_emit_simple_imm8_source_done
asmx86_try_emit_simple_imm8_source_valid:
	mov ax, 1
asmx86_try_emit_simple_imm8_source_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Tries to emit an instruction based on a simple combination of operands.
;
; Simple combinations are:
;		reg16, reg16
;		reg16, imm16
;		reg8, reg8
;		reg8, imm8
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - base opcode for XXX reg, reg
;		BL - base opcode for XXX reg, imm
;		BH - opcode extension for XXX reg, imm:
;			 bits 0-2 - opcode extension
;			 bits 3-7 - zero
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_simple:
	push bx
	push cx
	push dx

	mov byte [cs:asmx86EmitSimpleOpcodeRegReg], al
	mov byte [cs:asmx86EmitSimpleOpcodeRegImm], bl
	shl bh, 3
	mov byte [cs:asmx86EmitSimpleModrmExtensionRegImm], bh
	
	call asmx86_try_resolve_modrm_simple
			; AX - 0 if unsuccessful
			;      1 if combination is reg, reg
			;      2 if combination is reg, imm
			; DL - modrm byte:
			;      bits 0-1 - addressing mode
			;      bits 2-4 - zero when destination is immediate,
			;                 register encoding otherwise
			;      bits 5-7 - register encoding
			; DH - opcode byte size modifier:
			;      bit    0 - set when operand sizes are 16bit, clear when 8bit
			;      bit    1 - set when destination is a register
			;      bits 2-7 - zero
			; BX - imm16 source, if one is present
	cmp ax, 0
	je asmx86_try_emit_simple_invalid
	
	cmp ax, 1
	jne asmx86_try_emit_simple_reg_imm
asmx86_try_emit_simple_reg_reg:	
	; reg, reg
	mov al, byte [cs:asmx86EmitSimpleOpcodeRegReg]
	or al, dh									; add in size and direction
	call asmEmit_emit_byte_from_number			; emit opcode
	mov al, dl
	call asmEmit_emit_byte_from_number			; emit modrm
	jmp asmx86_try_emit_simple_valid
	
asmx86_try_emit_simple_reg_imm:
	cmp ax, 2
	jne asmx86_try_emit_simple_invalid
	test dh, 00000001b
	jz asmx86_try_emit_simple_reg_imm8
asmx86_try_emit_simple_reg_imm16:
	; reg, imm16
	mov al, byte [cs:asmx86EmitSimpleOpcodeRegImm]
	or al, dh									; add in size and direction
	call asmEmit_emit_byte_from_number			; emit opcode
	mov al, dl
	or al, byte [cs:asmx86EmitSimpleModrmExtensionRegImm]
	call asmEmit_emit_byte_from_number			; emit modrm
	mov ax, bx
	call asmEmit_emit_word_from_number			; emit imm16
	jmp asmx86_try_emit_simple_valid
	
asmx86_try_emit_simple_reg_imm8:
	; reg, imm8
	mov al, byte [cs:asmx86EmitSimpleOpcodeRegImm]
	or al, dh									; add in size and direction
	call asmEmit_emit_byte_from_number			; emit opcode
	mov al, dl
	or al, byte [cs:asmx86EmitSimpleModrmExtensionRegImm]
	call asmEmit_emit_byte_from_number			; emit modrm
	mov ax, bx
	call asmEmit_emit_byte_from_number			; emit imm8
	call asmx86_warn_if_value_larger_than_byte
	jmp asmx86_try_emit_simple_valid
	
asmx86_try_emit_simple_invalid:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	mov ax, 0
	jmp asmx86_try_emit_simple_done
asmx86_try_emit_simple_valid:
	mov ax, 1
asmx86_try_emit_simple_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Tries to resolve the single (checked) operand of a statement to an imm16
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		none
; output:
;		AX - 0 if unsuccessful, other value otherwise
;		CX - the imm16 when successful
asmx86_try_get_imm16_from_single_operand:
	push bx
	push dx
	
	cmp byte [cs:asmCurrentInstTokenCount], 0
	je asmx86_try_get_imm16_from_single_operand_tokens
	
	mov dl, 0						; we evaluate from the first token...
	mov dh, byte [cs:asmCurrentInstTokenCount]
	dec dh							; ...to the last
	call asmEval_do					; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je asmx86_try_get_imm16_from_single_operand_unsupported_operands
									; there was an error
	cmp bx, ASM_EVAL_TYPE_NUMBER
	jne asmx86_try_get_imm16_from_single_operand_unsupported_operands

	jmp asmx86_try_get_imm16_from_single_operand_success
	
asmx86_try_get_imm16_from_single_operand_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_try_get_imm16_from_single_operand_failure
	
asmx86_try_get_imm16_from_single_operand_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_try_get_imm16_from_single_operand_failure
	
asmx86_try_get_imm16_from_single_operand_failure:
	mov ax, 0
	jmp asmx86_try_get_imm16_from_single_operand_done
asmx86_try_get_imm16_from_single_operand_success:
	mov ax, 1
asmx86_try_get_imm16_from_single_operand_done:
	pop dx
	pop bx
	ret

	
; Tries to emit an instruction based on a 2-byte opcode and a single imm16
; operand
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - first byte of opcode
;		AH - second byte of opcode
;		BX - value to displace imm16 by (additive)
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_2byte_opcode_imm16:
	push bx
	push cx
	push dx

	mov byte [cs:asmx86Emit2ByteOpcodeImm16Byte0], al
	mov byte [cs:asmx86Emit2ByteOpcodeImm16Byte1], ah
	mov word [cs:asmx86Emit2ByteOpcodeImm16Displacement], bx
	
	call asmx86_try_get_imm16_from_single_operand		; CX := imm16
	cmp ax, 0
	je asmx86_try_emit_2byte_opcode_imm16_invalid

	mov al, byte [cs:asmx86Emit2ByteOpcodeImm16Byte0]
	call asmEmit_emit_byte_from_number
	mov al, byte [cs:asmx86Emit2ByteOpcodeImm16Byte1]
	call asmEmit_emit_byte_from_number
	mov ax, cx
	add ax, word [cs:asmx86Emit2ByteOpcodeImm16Displacement]
	call asmEmit_emit_word_from_number					; imm16
	
	jmp asmx86_try_emit_2byte_opcode_imm16_valid
asmx86_try_emit_2byte_opcode_imm16_invalid:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	mov ax, 0
	jmp asmx86_try_emit_2byte_opcode_imm16_done
asmx86_try_emit_2byte_opcode_imm16_valid:
	mov ax, 1
asmx86_try_emit_2byte_opcode_imm16_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Tries to emit a conditional jump instruction
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AH - second byte of opcode
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_Jxx_family:
	push bx
	
	call asmEmit_get_current_absolute_16bit_address	; BX := address before Jxx
	add bx, 4										; BX := address after Jxx
	neg bx										; BX := additive displacement
	mov al, 0Fh									; Jxx opcode first byte
	call asmx86_try_emit_2byte_opcode_imm16
	
	pop bx
	ret
	
	
; Tries to emit a single-byte opcode that takes no arguments
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - byte of opcode
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_single_byte_opcode_no_arguments:
	cmp byte [cs:asmCurrentInstTokenCount], 0
	jne asmx86_try_emit_single_byte_opcode_no_arguments_arguments
	
	call asmEmit_emit_byte_from_number
	mov ax, 1
	ret
asmx86_try_emit_single_byte_opcode_no_arguments_arguments:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageExpectedNoArguments
	mov ax, 0
	ret
	
	
; Tries to resolve the single (checked) operand of a statement to a 
; 16 bit register.
; Supports both reg16 and sreg16.
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		none
; output:
;		AX - 0 if unsuccessful, other value otherwise
;		CL - register
;		CH - bits 0-2 - encoded register value
;			 bit    3 - set when register can receive immediate value via MOV
;			 bit    4 - set when register is 16bit, clear when 8bit
;			 bit    5 - set when register can receive register via MOV
;			 bit    6 - set when register is a segment register
;			 bit    7 - set when register is assignable to a segment register
;		DL - bit    0 - set when register can be used as an offset in a mem ref
;			 bits 1-7 - unused
asmx86_try_get_reg16_from_single_operand:
	push bx
	push dx
	
	cmp byte [cs:asmCurrentInstTokenCount], 1
	jne asmx86_try_get_reg16_from_single_operand_tokens
	
	mov bl, 0
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_try_get_reg16_from_single_operand_unsupported_operands
	
	test ch, ASMX86_REG_IS_16BIT
	jz asmx86_try_get_reg16_from_single_operand_unsupported_operands

	jmp asmx86_try_get_reg16_from_single_operand_success
	
asmx86_try_get_reg16_from_single_operand_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_try_get_reg16_from_single_operand_failure
	
asmx86_try_get_reg16_from_single_operand_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_try_get_reg16_from_single_operand_failure
	
asmx86_try_get_reg16_from_single_operand_failure:
	mov ax, 0
	jmp asmx86_try_get_reg16_from_single_operand_done
asmx86_try_get_reg16_from_single_operand_success:
	mov ax, 1
asmx86_try_get_reg16_from_single_operand_done:
	pop dx
	pop bx
	ret

	
; Tries to emit either a PUSH or POP
; Supports:
;     PUSH reg16
;     PUSH sreg16
;     POP reg16
;     POP sreg16
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - PUSH/POP selector
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_push_pop_sreg16_reg16:
	push bx
	push cx
	push dx
	
	mov byte [cs:asmx86TryEmitPushPopSelector], al
	call asmx86_try_get_reg16_from_single_operand
	cmp ax, 0
	je asmx86_try_emit_push_pop_sreg16_reg16_fail
	
	test ch, ASMX86_REG_IS_SEGMENT
	jnz asmx86_try_emit_push_pop_sreg16_reg16____sreg16
asmx86_try_emit_push_pop_sreg16_reg16____reg16:
	cmp byte [cs:asmx86TryEmitPushPopSelector], ASMX86_PUSHPOP_PUSH
	jne asmx86_try_emit_push_pop_sreg16_reg16____reg16_POP
asmx86_try_emit_push_pop_sreg16_reg16____reg16_PUSH:
	; emit PUSH reg16
	
	and ch, ASMX86_REG_MASK_ENCODING
	mov al, 50h								; base opcode
	add al, ch								; add in register
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success
asmx86_try_emit_push_pop_sreg16_reg16____reg16_POP:
	; emit POP reg16
	
	and ch, ASMX86_REG_MASK_ENCODING
	mov al, 58h								; base opcode
	add al, ch								; add in register
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success	
asmx86_try_emit_push_pop_sreg16_reg16____sreg16:
	cmp byte [cs:asmx86TryEmitPushPopSelector], ASMX86_PUSHPOP_PUSH
	jne asmx86_try_emit_push_pop_sreg16_reg16____sreg16_POP
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_PUSH:

	cmp cl, ASMX86_REG_FS
	jne asmx86_try_emit_push_pop_sreg16_reg16____sreg16_PUSH_GS
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_PUSH_FS:
	; emit PUSH FS
	
	mov al, 0Fh
	call asmEmit_emit_byte_from_number
	mov al, 0A0h
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_PUSH_GS:
	cmp cl, ASMX86_REG_GS
	jne asmx86_try_emit_push_pop_sreg16_reg16____sreg16_PUSH_misc
	; emit PUSH GS
	
	mov al, 0Fh
	call asmEmit_emit_byte_from_number
	mov al, 0A8h
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_PUSH_misc:
	; emit PUSH sreg16
	
	and ch, ASMX86_REG_MASK_ENCODING
	shl ch, 3
	mov al, 06h								; base opcode
	or al, ch								; add in register
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_POP:
	test ch, ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP	; not all registers can
	jz asmx86_try_emit_push_pop_sreg16_reg16_unsupported_operands	; be popped
	
	cmp cl, ASMX86_REG_FS
	jne asmx86_try_emit_push_pop_sreg16_reg16____sreg16_POP_GS
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_POP_FS:
	; emit POP FS

	mov al, 0Fh
	call asmEmit_emit_byte_from_number
	mov al, 0A1h
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_POP_GS:
	cmp cl, ASMX86_REG_GS
	jne asmx86_try_emit_push_pop_sreg16_reg16____sreg16_POP_misc
	; emit POP GS

	mov al, 0Fh
	call asmEmit_emit_byte_from_number
	mov al, 0A9h
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success
asmx86_try_emit_push_pop_sreg16_reg16____sreg16_POP_misc:
	; emit POP sreg16
	
	and ch, ASMX86_REG_MASK_ENCODING
	shl ch, 3
	mov al, 07h								; base opcode
	or al, ch								; add in register
	call asmEmit_emit_byte_from_number
	jmp asmx86_try_emit_push_pop_sreg16_reg16_success
	
asmx86_try_emit_push_pop_sreg16_reg16_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_try_emit_push_pop_sreg16_reg16_fail
	
asmx86_try_emit_push_pop_sreg16_reg16_fail:
	mov ax, 0
	jmp asmx86_try_emit_push_pop_sreg16_reg16_done
asmx86_try_emit_push_pop_sreg16_reg16_success:
	mov ax, 1	
asmx86_try_emit_push_pop_sreg16_reg16_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Tries to resolve the single (checked) operand of a statement to a register.
; Supports reg16 and reg8.
; Does NOT support sreg16.
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		none
; output:
;		AX - 0 if unsuccessful, other value otherwise
;		CL - register
;		CH - bits 0-2 - encoded register value
;			 bit    3 - set when register can receive immediate value via MOV
;			 bit    4 - set when register is 16bit, clear when 8bit
;			 bit    5 - set when register can receive register via MOV
;			 bit    6 - set when register is a segment register
;			 bit    7 - set when register is assignable to a segment register
;		DL - bit    0 - set when register can be used as an offset in a mem ref
;			 bits 1-7 - unused
asmx86_try_get_reg16_reg8_from_single_operand:
	push bx
	
	cmp byte [cs:asmCurrentInstTokenCount], 1
	jne asmx86_try_get_reg16_reg8_from_single_operand_tokens
	
	mov bl, 0
	call asmx86_try_resolve_register_from_token
	cmp ax, 0
	je asmx86_try_get_reg16_reg8_from_single_operand_unsupported_operands

	test ch, ASMX86_REG_IS_SEGMENT
	jnz asmx86_try_get_reg16_reg8_from_single_operand_unsupported_operands

	jmp asmx86_try_get_reg16_reg8_from_single_operand_success
	
asmx86_try_get_reg16_reg8_from_single_operand_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_try_get_reg16_reg8_from_single_operand_failure
	
asmx86_try_get_reg16_reg8_from_single_operand_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_try_get_reg16_reg8_from_single_operand_failure
	
asmx86_try_get_reg16_reg8_from_single_operand_failure:
	mov ax, 0
	jmp asmx86_try_get_reg16_reg8_from_single_operand_done
asmx86_try_get_reg16_reg8_from_single_operand_success:
	mov ax, 1
asmx86_try_get_reg16_reg8_from_single_operand_done:
	pop bx
	ret

	
asmx86TryEmit1ByteRegOpcodeForReg16:		db 0
asmx86TryEmit1ByteRegOpcodeForReg8:			db 0
asmx86TryEmit1ByteRegOpcodeForRegBase:		db 0

; Tries to emit an instruction with a 1-byte opcode and a single,
; register operand
;
; Supported operands:
;		reg16
;		reg8
; NOTE: sreg16 is not supported
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - base of second byte
;		BL - opcode for reg16
;		BH - opcode for reg8
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_1byte_reg_from_single_operand:
	push bx
	push cx
	push dx
	
	mov byte [cs:asmx86TryEmit1ByteRegOpcodeForReg16], bl
	mov byte [cs:asmx86TryEmit1ByteRegOpcodeForReg8], bh
	mov byte [cs:asmx86TryEmit1ByteRegOpcodeForRegBase], al
	
	call asmx86_try_get_reg16_reg8_from_single_operand
	cmp ax, 0
	je asmx86_try_emit_1byte_reg_from_single_operand_done
	
	test ch, ASMX86_REG_IS_16BIT
	jz asmx86_try_emit_1byte_reg_from_single_operand___reg8
asmx86_try_emit_1byte_reg_from_single_operand___reg16:
	; emit reg16
	mov al, byte [cs:asmx86TryEmit1ByteRegOpcodeForReg16]
	call asmEmit_emit_byte_from_number
	mov al, byte [cs:asmx86TryEmit1ByteRegOpcodeForRegBase]
	and ch, ASMX86_REG_MASK_ENCODING
	or al, ch
	call asmEmit_emit_byte_from_number
	
	jmp asmx86_try_emit_1byte_reg_from_single_operand_success
asmx86_try_emit_1byte_reg_from_single_operand___reg8:
	; emit reg8
	mov al, byte [cs:asmx86TryEmit1ByteRegOpcodeForReg8]
	call asmEmit_emit_byte_from_number
	mov al, byte [cs:asmx86TryEmit1ByteRegOpcodeForRegBase]
	and ch, ASMX86_REG_MASK_ENCODING
	or al, ch
	call asmEmit_emit_byte_from_number
	
	jmp asmx86_try_emit_1byte_reg_from_single_operand_success
asmx86_try_emit_1byte_reg_from_single_operand_success:
	mov ax, 1
asmx86_try_emit_1byte_reg_from_single_operand_done:
	pop dx
	pop cx
	pop bx
	ret

	
; Tries to resolve the single (checked) suffix of a repXX-prefixed instruction
;
; NOTE: Does not validate allowed whether suffix is valid with 
;       respect to prefix.
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		none
; output:
;		AX - 0 if unsuccessful, other value otherwise
;		CX - suffix family
asmx86_try_get_rep_suffix:
	push bx
	push dx
	push si
	push di
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:asmCurrentInstTokenCount], 1
	jne asmx86_try_get_rep_suffix_tokens		; must have exactly one token
	
	mov bl, 0									; BL := first token
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer

	mov si, asmx86KeywordMovsb
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_MOVS
	mov si, asmx86KeywordMovsw
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_MOVS
	
	mov si, asmx86KeywordLodsb
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_LODS
	mov si, asmx86KeywordLodsw
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_LODS
	
	mov si, asmx86KeywordStosb
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_STOS
	mov si, asmx86KeywordStosw
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_STOS
	
	mov si, asmx86KeywordCmpsb
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_CMPS
	mov si, asmx86KeywordCmpsw
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_CMPS
	
	mov si, asmx86KeywordScasb
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_SCAS
	mov si, asmx86KeywordScasw
	call common_string_compare_ignore_case
	cmp ax, 0
	je asmx86_try_get_rep_suffix_SCAS
	
	jmp asmx86_try_get_rep_suffix_unsupported_operands

asmx86_try_get_rep_suffix_MOVS:
	mov cx, ASMX86_REP_SUFFIX_FAMILY_MOVS
	jmp asmx86_try_get_rep_suffix_success
asmx86_try_get_rep_suffix_LODS:
	mov cx, ASMX86_REP_SUFFIX_FAMILY_LODS
	jmp asmx86_try_get_rep_suffix_success
asmx86_try_get_rep_suffix_STOS:
	mov cx, ASMX86_REP_SUFFIX_FAMILY_STOS
	jmp asmx86_try_get_rep_suffix_success
asmx86_try_get_rep_suffix_CMPS:
	mov cx, ASMX86_REP_SUFFIX_FAMILY_CMPS
	jmp asmx86_try_get_rep_suffix_success
asmx86_try_get_rep_suffix_SCAS:
	mov cx, ASMX86_REP_SUFFIX_FAMILY_SCAS
	jmp asmx86_try_get_rep_suffix_success
		
asmx86_try_get_rep_suffix_unsupported_operands:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	jmp asmx86_try_get_rep_suffix_failure
	
asmx86_try_get_rep_suffix_tokens:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedExpressionTokenCount
	jmp asmx86_try_get_rep_suffix_failure
	
asmx86_try_get_rep_suffix_failure:
	mov ax, 0
	jmp asmx86_try_get_rep_suffix_done
asmx86_try_get_rep_suffix_success:
	mov ax, 1
asmx86_try_get_rep_suffix_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop bx
	ret
	
	
; Tries to emit an instruction based on a simple combination of operands.
; Only general purpose registers are supported.
;
; Simple combinations are:
;		reg16, reg16
;		reg8, reg8
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - base opcode for XXX reg, reg
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_reg_reg:
	push bx
	push cx
	push dx

	mov byte [cs:asmx86EmitSimpleRegRegOpcodeRegReg], al
	
	call asmx86_try_resolve_modrm_simple
			; AX - 0 if unsuccessful
			;      1 if combination is reg, reg
			;      2 if combination is reg, imm
			; DL - modrm byte:
			;      bits 0-1 - addressing mode
			;      bits 2-4 - zero when destination is immediate,
			;                 register encoding otherwise
			;      bits 5-7 - register encoding
			; DH - opcode byte size modifier:
			;      bit    0 - set when operand sizes are 16bit, clear when 8bit
			;      bit    1 - set when destination is a register
			;      bits 2-7 - zero
			; BX - imm16 source, if one is present
	cmp ax, 0
	je asmx86_try_emit_reg_reg_invalid	
	cmp ax, 2
	je asmx86_try_emit_reg_reg_invalid
	
	; reg, reg
	mov al, byte [cs:asmx86EmitSimpleRegRegOpcodeRegReg]
	or al, dh									; add in size and direction
	call asmEmit_emit_byte_from_number			; emit opcode
	mov al, dl
	call asmEmit_emit_byte_from_number			; emit modrm
	jmp asmx86_try_emit_reg_reg_valid
	
asmx86_try_emit_reg_reg_invalid:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	mov ax, 0
	jmp asmx86_try_emit_reg_reg_done
asmx86_try_emit_reg_reg_valid:
	mov ax, 1
asmx86_try_emit_reg_reg_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Tries to emit an instruction based on a 1-byte opcode and a single imm8
; operand
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - first byte of opcode
;		BX - value to displace imm8 by (additive)
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_1byte_opcode_imm8:
	push bx
	push cx
	push dx

	mov byte [cs:asmx86Emit1ByteOpcodeImm8Byte0], al
	mov word [cs:asmx86Emit1ByteOpcodeImm8Displacement], bx
	
	call asmx86_try_get_imm16_from_single_operand		; CX := imm16
	cmp ax, 0
	je asmx86_try_emit_1byte_opcode_imm8_invalid

	mov al, byte [cs:asmx86Emit1ByteOpcodeImm8Byte0]
	call asmEmit_emit_byte_from_number
	mov ax, cx
	add ax, word [cs:asmx86Emit1ByteOpcodeImm8Displacement]
	call asmEmit_emit_byte_from_number					; imm8
	call asmx86_warn_if_signed_value_larger_than_byte
	
	jmp asmx86_try_emit_1byte_opcode_imm8_valid
asmx86_try_emit_1byte_opcode_imm8_invalid:
	mov word [cs:asmInterpretationEndMessagePtr], asmx86MessageUnsupportedOperands
	mov ax, 0
	jmp asmx86_try_emit_1byte_opcode_imm8_done
asmx86_try_emit_1byte_opcode_imm8_valid:
	mov ax, 1
asmx86_try_emit_1byte_opcode_imm8_done:
	pop dx
	pop cx
	pop bx
	ret
	
	
; Tries to emit a conditional jump instruction
;
; NOTE: Sets an error message if unsuccessful.
;
; input:
;		AL - opcode byte
; output:
;		AX - 0 if unsuccessful, other value otherwise
asmx86_try_emit_LOOP_family:
	push bx
	
	call asmEmit_get_current_absolute_16bit_address	; BX := address before LOOP
	add bx, 2										; BX := address after LOOP
	neg bx										; BX := additive displacement
	call asmx86_try_emit_1byte_opcode_imm8
	
	pop bx
	ret
	
	
%endif
