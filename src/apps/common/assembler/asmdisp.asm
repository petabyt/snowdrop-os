;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains routines for displaying messages, for Snowdrop OS's assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_DISPLAY_
%define _COMMON_ASM_DISPLAY_


ASM_LOG_CONFIG_TO_VIRTUAL_DISPLAY		equ 0
ASM_LOG_CONFIG_DIRECT_TO_VIDEO			equ 1
asmLoggingConfiguration:		dw ASM_LOG_CONFIG_TO_VIRTUAL_DISPLAY

asmDisplayInstructionHasBeenRendered:	db 0
asmDisplayUserFriendlyNewline:	db '<NEW LINE>', 0

asmDisplayTab:					db '  ', 0
asmDisplayOrigin:				db 'origin is at ', 0
asmDisplayBytesWritten:			db ' bytes written', 13, 10, 0
asmDisplayLabelCountMsg:		db ' label addresses resolved', 13, 10, 0
asmDisplayConstantCount:		db ' constants processed', 13, 10, 0
asmDisplayPassStart:			db 'Starting pass ', 0
asmDisplayByteToStringBuffer:	db ' ', 0

asmDisplayConstCountPass0:		dw 0
asmDisplayConstCountPass1:		dw 0
asmDisplayConstCountPass2:		dw 0

asmDisplayLabelCount:			dw 0

asmDisplay16BitNumberBuffer:	times 10 db 0
asmDisplayOffsetBeforeCurrentInstruction:	dw 0


; Performs the necessary housekeeping before an instruction is executed
;
; input:
;		none
; output:
;		none
asmDisplay_mark_instruction_beginning:
	push bx
	call asmEmit_get_current_absolute_16bit_address
	mov word [cs:asmDisplayOffsetBeforeCurrentInstruction], bx
	pop bx
	ret


; Displays a user-readable message using whichever method was configured
;
; input:
;	 DS:SI - pointer to message, zero-terminated
; output:
;		none
asm_display_worker:
asm_display_worker_virtual:
	cmp word [cs:asmLoggingConfiguration], ASM_LOG_CONFIG_TO_VIRTUAL_DISPLAY
	jne asm_display_worker_direct_to_video
	int 97h									; print on virtual display
	jmp asm_display_worker_done
asm_display_worker_direct_to_video:
	int 80h									; print directly to video
asm_display_worker_done:
	ret
	

; Configures assembler's logging
;
; input:
;		AX - logging method
; output:
;		none
asm_configure_logging:
	mov word [cs:asmLoggingConfiguration], ax
	ret


; Initializes the display module once per assembly session
;
; input:
;	 	none
; output:
;		none
asmDisplay_initialize_once:
	push ds
	pusha
	
	mov word [cs:asmDisplayConstCountPass0], 0
	mov word [cs:asmDisplayConstCountPass1], 0
	mov word [cs:asmDisplayConstCountPass2], 0
	mov word [cs:asmDisplayLabelCount], 0
	
	popa
	pop ds
	ret


; Initializes the display module
;
; input:
;	 	none
; output:
;		none
asmDisplay_initialize:
	mov byte [cs:asmDisplayInstructionHasBeenRendered], 0
	ret

	
; Keeps counts of labels stored
;
; input:
;	 	none
; output:
;		none
asmDisplay_record_label:
	inc word [cs:asmDisplayLabelCount]
	ret
	
	
; Keeps counts of constants stored during each pass
;
; input:
;	 	none
; output:
;		none
asmDisplay_record_const:
asmDisplay_record_const_pass0:	
	cmp byte [cs:asmPass], ASM_PASS_0
	jne asmDisplay_record_const_pass1
	inc word [cs:asmDisplayConstCountPass0]
	jmp asmDisplay_record_const_done
asmDisplay_record_const_pass1:
	cmp byte [cs:asmPass], ASM_PASS_1
	jne asmDisplay_record_const_pass2
	inc word [cs:asmDisplayConstCountPass1]
	jmp asmDisplay_record_const_done
asmDisplay_record_const_pass2:
	inc word [cs:asmDisplayConstCountPass2]
asmDisplay_record_const_done:
	ret
	

; Prints messages at the end of a pass
;
; input:
;	 	none
; output:
;		none
asmDisplay_log_pass_end:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax
asmDisplay_log_pass_end_pass0:	
	cmp byte [cs:asmPass], ASM_PASS_0
	jne asmDisplay_log_pass_end_pass1
	
	; log origin
	mov si, asmDisplayTab
	call asm_display_worker
	mov si, asmDisplayOrigin
	call asm_display_worker
	
	call asmEmit_get_origin						; CX := origin
	mov ax, cx
	xchg ah, al									; humans read MSB first
	mov di, asmDisplay16BitNumberBuffer
	mov dx, 1
	call asm_word_to_hex
	mov si, asmDisplay16BitNumberBuffer
	call asm_display_worker
	mov si, asmNewline
	call asm_display_worker
	
	mov ax, word [cs:asmDisplayConstCountPass0]
	jmp asmDisplay_log_pass_end_write_constant
asmDisplay_log_pass_end_pass1:
	cmp byte [cs:asmPass], ASM_PASS_1
	jne asmDisplay_log_pass_end_pass2
	
	; write label count
	mov si, asmDisplayTab
	call asm_display_worker
	
	mov ax, word [cs:asmDisplayLabelCount]
	xchg ah, al									; humans read MSB first
	mov di, asmDisplay16BitNumberBuffer
	mov dx, 1
	call asm_word_to_hex
	mov si, asmDisplay16BitNumberBuffer
	call asm_display_worker
	
	mov si, asmDisplayLabelCountMsg
	call asm_display_worker
		
	mov ax, word [cs:asmDisplayConstCountPass1]
	jmp asmDisplay_log_pass_end_write_constant
asmDisplay_log_pass_end_pass2:

	mov ax, word [cs:asmDisplayConstCountPass2]
asmDisplay_log_pass_end_write_constant:
	mov si, asmDisplayTab
	call asm_display_worker
	
	; here, AX = constant count
	; write constant count
	xchg ah, al									; humans read MSB first
	mov di, asmDisplay16BitNumberBuffer
	mov dx, 1
	call asm_word_to_hex
	mov si, asmDisplay16BitNumberBuffer
	call asm_display_worker
	
	mov si, asmDisplayConstantCount
	call asm_display_worker
	
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmDisplay_log_pass_end_done
	; from here on we write at the end
	
	; write bytecode length
	mov si, asmDisplayTab
	call asm_display_worker
	
	call asmEmit_get_written_byte_count			; CX := written bytes
	mov ax, cx
	xchg ah, al									; humans read MSB first
	mov di, asmDisplay16BitNumberBuffer
	mov dx, 1
	call asm_word_to_hex
	mov si, asmDisplay16BitNumberBuffer
	call asm_display_worker
	
	mov si, asmDisplayBytesWritten
	call asm_display_worker
	
asmDisplay_log_pass_end_done:
	pop es
	pop ds
	popa
	ret
	
	
; Prints messages at the start of a pass
;
; input:
;	 	none
; output:
;		none
asmDisplay_log_pass_start:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, asmDisplayPassStart
	call asm_display_worker
	
	mov al, byte [cs:asmPass]
	call asm_byte_to_hex				; CX := ASCII
	mov byte [cs:asmDisplayByteToStringBuffer], cl	; it's a single char
	mov si, asmDisplayByteToStringBuffer
	call asm_display_worker
	mov si, asmNewline
	call asm_display_worker
	
	pop ds
	popa
	ret
	
	
; Concatenates all tokens of the last parsed instruction
;
; input:
;	 	none
; output:
;		none	
asm_concat_last_parsed_instruction:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov di, asmLastInstructionBuffer
	
	mov si, asmCurrentKeyword
	call asm_copy_string_and_advance	
	
	mov si, asmDebugMsgBlank
	call asm_copy_string_and_advance
	; iterate over all instruction fragments
	mov bl, 0								; instruction fragment index
asm_concat_last_parsed_instruction_fragments:
	cmp bl, byte [cs:asmCurrentInstTokenCount]
	jae asm_concat_last_parsed_instruction_fragments_done
	
	push di
	call asmInterpreter_get_instruction_token_near_ptr
	mov si, di				; SI := pointer to instruction token string		
	pop di
	call asm_copy_string_and_advance
	
	mov si, asmDebugMsgBlank
	call asm_copy_string_and_advance
	
	inc bl					; next instruction fragment
	jmp asm_concat_last_parsed_instruction_fragments
asm_concat_last_parsed_instruction_fragments_done:
	mov byte [cs:asmDisplayInstructionHasBeenRendered], 1
	pop es
	pop ds
	popa
	ret


; Displays a message for the user at the end of interpretation.
; It alerts the user if there was an error.
;
; input:
;		none
; output:
;		none	
asm_display_status:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, asmMessageNewline
	call asm_display_worker

	call asm_display_ASM_tag
	
	; was there an error?
	cmp byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_ERROR
	jne asm_display_status_status	; no
	
	mov si, asmMessageStatusError	; yes
	call asm_display_worker
asm_display_status_status:
	mov si, word [cs:asmInterpretationEndMessagePtr]
	call asm_display_worker

	; display details pertaining to the error, if applicable
	; was there an error?
	cmp byte [cs:asmInterpreterState], ASM_STATE_NONRESUMABLE_ERROR
	jne asm_display_status_after_error_details	; no
	; there was an error, so we show error details
	
	; display last seen token
	mov si, asmMessageNewline
	call asm_display_worker
	call asm_display_ASM_tag
	mov si, asmDebugMsgLastTokenMessage
	call asm_display_worker
	
	; see if we should display <NEW LINE>
	mov si, asmCurrentToken
	mov di, asmNewlineToken
	call common_string_compare_ignore_case
	cmp ax, 0
	jne asm_display_status_last_token_verbatim	; we're displaying the token
	; we're displaying <NEW LINE>
	mov si, asmDisplayUserFriendlyNewline
	call asm_display_worker
	jmp asm_display_status_after_last_token

asm_display_status_last_token_verbatim:	
	; display the actual last token
	mov si, asmDebugMsgTokenQuote
	call asm_display_worker
	mov si, asmCurrentToken
	call asm_display_worker
	mov si, asmDebugMsgTokenQuote
	call asm_display_worker
	
asm_display_status_after_last_token:
	cmp byte [cs:asmDisplayInstructionHasBeenRendered], 0
	je asm_display_status_after_error_details	; we don't print instruction
												; when it hasn't been rendered
	; display last seen instruction
	mov si, asmMessageNewline
	call asm_display_worker
	call asm_display_ASM_tag
	mov si, asmDebugMsgLastInstructionMessage
	call asm_display_worker
	mov si, asmLastInstructionBuffer
	call asm_display_worker
	
asm_display_status_after_error_details:
asm_display_status_done:
	pop es
	pop ds
	popa
	ret	


; Populates line number and instruction number variables
;
; input:
;		none
; output:
;		none
asm_display_set_line_and_instruction_number:
	pusha
	push ds
	
	mov bx, word [cs:asmInterpreterParserResumePoint]
											; BX := near pointer to position
	push word [cs:asmProgramTextSeg]
	pop ds
	mov si, word [cs:asmProgramTextOff]		; DS:SI := pointer to program text
	
	call asm_get_position					; CX := line number
											; DX := instruction number
	mov word [cs:asmCurrentLineNumber], cx
	mov word [cs:asmCurrentInstructionNumber], dx

	pop ds
	popa
	ret


; Displays a tag that precedes assembler messages
;
; input:
;		none
; output:
;		none
asm_display_ASM_tag:
	pusha
	push ds
	push es
	
	call asm_display_set_line_and_instruction_number
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, asmMessagePrefix1
	call asm_display_worker
	
	mov dx, 0
	mov ax, word [cs:asmCurrentLineNumber]
	mov si, asmItoaBuffer
	mov bl, 3						; formatting option
	int 0A2h
	call asm_display_worker
	
	mov si, asmMessagePrefix2
	call asm_display_worker
	
	mov dx, 0
	mov ax, word [cs:asmCurrentInstructionNumber]
	mov si, asmItoaBuffer
	mov bl, 3						; formatting option
	int 0A2h
	call asm_display_worker	
	
	cmp byte [cs:asmPass], ASM_PASS_0		; offset is not available
	je asm_display_ASM_tag___after_offset	; during pass 0
	
	mov si, asmMessagePrefix3
	call asm_display_worker

	mov ax, word [cs:asmDisplayOffsetBeforeCurrentInstruction]
	xchg ah, al									; humans read MSB first
	mov di, asmDisplay16BitNumberBuffer
	mov dx, 1
	call asm_word_to_hex
	mov si, asmDisplay16BitNumberBuffer
	call asm_display_worker
	
asm_display_ASM_tag___after_offset:	
	mov si, asmMessagePrefix4
	call asm_display_worker

	pop es
	pop ds
	popa
	ret

	
%endif
