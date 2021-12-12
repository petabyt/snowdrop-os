;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains routines for generation of listing files, 
; for Snowdrop OS's assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_LIST_
%define _COMMON_ASM_LIST_

ASM_LIST_SEPARATOR_CHARACTER			equ ' '
ASM_LIST_SEPARATOR_AFTER_ADDRESS_WIDTH	equ 1
ASM_LIST_SEPARATOR_AFTER_BYTECODE_WIDTH	equ 3
ASM_LIST_COLUMN_WIDTH_SEPARATORS	equ ASM_LIST_SEPARATOR_AFTER_ADDRESS_WIDTH + ASM_LIST_SEPARATOR_AFTER_BYTECODE_WIDTH

ASM_LIST_BYTECODE_COLUMN_COUNT		equ 5	; this many bytes will be listed

ASM_LIST_COLUMN_WIDTH_WHOLE_FILE	equ 79
ASM_LIST_COLUMN_WIDTH_ADDRESS		equ 4				; fits a word in hex
ASM_LIST_COLUMN_WIDTH_BYTECODE		equ ASM_LIST_BYTECODE_COLUMN_COUNT * 2
												; 2 ASCII chars per byte

ASM_LIST_COLUMN_WIDTH_INSTRUCTION	equ ASM_LIST_COLUMN_WIDTH_WHOLE_FILE - ASM_LIST_COLUMN_WIDTH_ADDRESS - ASM_LIST_COLUMN_WIDTH_BYTECODE - ASM_LIST_COLUMN_WIDTH_SEPARATORS

ASM_LIST_LABEL_OFFSET_TO_THE_LEFT	equ ASM_LIST_SEPARATOR_AFTER_BYTECODE_WIDTH - 1

ASM_LIST_PADDING_TO_INSTRUCTION		equ ASM_LIST_COLUMN_WIDTH_ADDRESS + ASM_LIST_SEPARATOR_AFTER_ADDRESS_WIDTH + ASM_LIST_COLUMN_WIDTH_BYTECODE + ASM_LIST_SEPARATOR_AFTER_BYTECODE_WIDTH

asmListingIsConfigured:		db 0
asmListingBufferSeg:		dw 0
asmListingBufferOff:		dw 0
asmListingBufferPointer:	dw 0
	
; these are used to delimit the interval (in emitted bytes) of the current
; instruction, so that listing logic 
asmListingCurrentInstructionBeginAddress:				dw 0
asmListingCurrentInstructionOutputBufferPtrSeg:			dw 0
asmListingCurrentInstructionBeginOutputBufferPtrOff:	dw 0

asmListingCurrentInstructionEndOutputBufferPtrOff:		dw 0

asmListingInstructionLines:		dw 0
asmListingBytecodeLines:		dw 0

asmListingLineNumberPerCall:	dw 0	; line number since we started
										; current call
asmListingBytecodeLeft:			dw 0	; how many more bytes of bytecode 
										; we still have to write
asmListingInstructionLeft:		dw 0	; how many more bytes of instruction
										; we still have to write

asmListCurrentBytecodePointerSeg:	dw 0
asmListCurrentBytecodePointerOff:	dw 0
asmListCurrentInstructionPointerOff:	dw 0

asmListAlreadyLoggedListingOverflow:	db 0

asmListHardcodedLargeBytecodeLabel:		db '<LARGE>', 0

asmListConstantPrologue:	db '(value=', 0
asmListConstantEpilogue:	db ')', 0
ASM_LIST_CONSTANT_BOILERPLATE_LENGTH	equ $ - asmListConstantPrologue - 2 + 4
							; value will be written in hex, so 4 characters
							; but subtract 2 terminators
							
ASMLIST_MAX_BYTECODE_CHUNK_SIZE		equ ASM_LIST_BYTECODE_COLUMN_COUNT * 3
						; chunks larger than this will be output differently


; Checks whether the listing offset has crossed FFFFh, warning the user if so
;
; input:
;		none
; output:
;		none
asmList_check_overflow:
	pusha
	push ds
	push es
	
	cmp byte [cs:asmListingIsConfigured], 0
	je asmList_check_overflow_done				; NOOP when not configured
	
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmList_check_overflow_done			; NOOP during passes other than 2
	
	cmp byte [cs:asmListAlreadyLoggedListingOverflow], 0
	jne asmList_check_overflow_done				; NOOP when already logged
		
	mov ax, word [cs:asmListingBufferPointer]	; AX := current
	cmp ax, word [cs:asmListingBufferOff]
	jae asmList_check_overflow_done				; no overflow

	; warn
	mov byte [cs:asmListAlreadyLoggedListingOverflow], 1	; mark as logged
	call asm_display_ASM_tag
	push cs
	pop ds
	mov si, asmMessageWarnListingOffsetOverflow
	call asm_display_worker
	
asmList_check_overflow_done:
	pop es
	pop ds
	popa
	ret
	

; Writes a statement containing a constant declaration to the listing buffer
;
; input:
;		none
; output:
;		none
asmList_try_write_constant:
	pusha
	push ds
	push es
	
	cmp byte [cs:asmListingIsConfigured], 0
	je asmList_try_write_constant_done			; NOOP when not configured
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmList_try_write_constant_done		; NOOP during passes other than 2
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov si, asmCurrentKeyword					; DS:SI := pointer to keyword
	mov di, asmKeywordConst
	call common_string_compare_ignore_case		; compare strings
	cmp ax, 0
	jne asmList_try_write_constant_done			; keyword is other than CONST
	
	mov bl, 0									; get pointer to first token
	call asmInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di									; DS:SI := ptr to const name
	call asmNumericVars_get_handle_from_storage	; AX := handle
												; CARRY - set when not found
	jc asmList_try_write_constant_done			; we couldn't get the handle
	call asmNumericVars_get_value				; BX := value	
	
	push word [cs:asmListingBufferSeg]			; ES:DI := current pointer into
	pop es										; listing (this is maintained
	mov di, word [cs:asmListingBufferPointer]	; throughout this procedure)	

	mov si, asmListConstantPrologue
	call asm_copy_string_and_advance			; write
	
	mov ax, bx									; AX := constant value
	xchg ah, al									; "human" word
	call asm_word_to_hex						; write value in AX
	add di, 4									; it wrote this many characters
	
	mov si, asmListConstantEpilogue
	call asm_copy_string_and_advance			; write

	; now write the potentially multi-line instruction
	push ds
	pop word [cs:asmListCurrentBytecodePointerSeg]
	push si
	pop word [cs:asmListCurrentBytecodePointerOff]
	
	; save moving pointer to start of current instruction text
	push word asmLastInstructionBuffer
	pop word [cs:asmListCurrentInstructionPointerOff]
	
	; save instruction length											
	push cs
	pop ds
	mov si, asmLastInstructionBuffer
	int 0A5h					; BX := string length
	mov word [cs:asmListingInstructionLeft], bx	; how many instruction chars
												; we still have to write
	; write first line of the constant instruction
	mov cx, ASM_LIST_PADDING_TO_INSTRUCTION
	sub cx, ASM_LIST_CONSTANT_BOILERPLATE_LENGTH
	call asmList_write_separator
	
	call asmList_write_inst_text				; advances ES:DI
	mov si, asmNewline
	call asm_copy_string_and_advance			; add new line
	
	; write subsequent lines of the constant instruction, if any are left
asmList_try_write_constant_loop:
	cmp word [cs:asmListingInstructionLeft], 0	; do we have instruction chars?
	je asmList_try_write_constant_loop_done		; no, we're done
	; yes, so perform loop
	
	mov cx, ASM_LIST_PADDING_TO_INSTRUCTION
	call asmList_write_separator
	call asmList_write_inst_text				; advances ES:DI	
asmList_try_write_constant_loop_epilogue:
	mov si, asmNewline
	call asm_copy_string_and_advance			; add new line
	jmp asmList_try_write_constant_loop
	
asmList_try_write_constant_loop_done:
	mov word [cs:asmListingBufferPointer], di	; save pointer
asmList_try_write_constant_done:
	pop es
	pop ds
	popa
	ret


; Writes a label to the listing buffer
;
; input:
;		none
; output:
;		none
asmList_write_label:
	pusha
	push ds
	push es
	
	cmp byte [cs:asmListingIsConfigured], 0
	je asmList_write_label_done			; NOOP when not configured
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmList_write_label_done		; NOOP during passes other than 2
	
	push word [cs:asmListingBufferSeg]			; ES:DI := current pointer into
	pop es										; listing (this is maintained
	mov di, word [cs:asmListingBufferPointer]	; throughout this procedure)	

	mov cx, ASM_LIST_PADDING_TO_INSTRUCTION
		; if we padded CX chars, we'd be at the beginning of 
		; the instruction test
	sub cx, ASM_LIST_LABEL_OFFSET_TO_THE_LEFT
	call asmList_write_separator
	
	push cs
	pop ds
	mov si, asmCurrentToken						; DS:SI := pointer to label
	call asm_copy_string_and_advance			; write label
	
	mov si, asmNewline
	call asm_copy_string_and_advance			; add new line
	
	mov word [cs:asmListingBufferPointer], di	; save pointer
asmList_write_label_done:
	pop es
	pop ds
	popa
	ret


; Writes a regular instruction entry to the listing buffer
; Assumption: instruction has been concatenated to a single string
;
; input:
;		none
; output:
;		none
asmList_write_instruction:
	pusha
	push ds
	push es
	
	cmp byte [cs:asmListingIsConfigured], 0
	je asmList_write_instruction_done		; NOOP when not configured
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmList_write_instruction_done		; NOOP during passes other than 2

	; asmListingBufferPointer is assumed to point to beginning of line from
	; which we start writing
	
	; column layout:
	; ADDRESS BYTECODE INSTRUCTION
	
	; main listing writer algorithm:
	;
	; write address
	; write separator
	;
	; while ( instruction has characters or bytecode has characters )
	;     if on second+ line
	;         write ASM_LIST_COLUMN_WIDTH_ADDRESS blanks
	;         write separator
	;
	;     write ASM_LIST_COLUMN_WIDTH_BYTECODE bytes (padded)
	;     if instruction has characters
	;         write separator
	;         write up to ASM_LIST_COLUMN_WIDTH_INSTRUCTION chars of 
	;         instruction
	;
	;     write 13, 10
	
	push word [cs:asmListingBufferSeg]			; ES:DI := current pointer into
	pop es										; listing (this is maintained
	mov di, word [cs:asmListingBufferPointer]	; throughout this procedure)
	
	; save pointer to start of bytecode emitted by current instruction
	call asmList_get_current_instruction_beginning_address	; BX := address
	mov ax, bx
	call asmEmit_get_ptr_to_output_buffer_by_address
			; DS:SI := pointer to beginning of bytecode of this instruction
	push ds
	pop word [cs:asmListCurrentBytecodePointerSeg]
	push si
	pop word [cs:asmListCurrentBytecodePointerOff]
	
	; save moving pointer to start of current instruction text
	push word asmLastInstructionBuffer
	pop word [cs:asmListCurrentInstructionPointerOff]

	; save bytecode length
	call asmEmit_get_current_absolute_16bit_address	; BX := current address
	mov cx, bx
	call asmList_get_current_instruction_beginning_address	; BX := address
	sub cx, bx							; CX := bytecode count
	cmp cx, 0
	je asmList_write_instruction_try_non_bytecode_emitting_statements
				; when current instruction generated no bytecode, we try to
				; write it if it's supported
	cmp cx, ASMLIST_MAX_BYTECODE_CHUNK_SIZE
	ja asmList_write_instruction_very_large_entry
				; when this chunk is too large, we treat it differently
	
	mov word [cs:asmListingBytecodeLeft], cx	; how many bytes we still have
												; to write
	; save instruction length											
	push cs
	pop ds
	mov si, asmLastInstructionBuffer
	int 0A5h					; BX := string length
	mov word [cs:asmListingInstructionLeft], bx	; how many instruction chars
												; we still have to write
	mov word [cs:asmListingLineNumberPerCall], 0	; we're on first line

	call asmList_write_address					; advances ES:DI
	call asmList_write_separator_after_address	; advances ES:DI

asmList_write_instruction_loop:
	cmp word [cs:asmListingBytecodeLeft], 0	; do we still have bytecode bytes?
	ja asmList_write_instruction_loop_do	; yes, so we still loop
	cmp word [cs:asmListingInstructionLeft], 0	; do we have instruction chars?
	je asmList_write_instruction_loop_done		; no, we're done
	; yes, so perform loop
asmList_write_instruction_loop_do:
	cmp word [cs:asmListingLineNumberPerCall], 0		; are we on first line?
	je asmList_write_instruction_loop_do_after_address	; yes
	; we're on second+ line, so we have to write blanks in the address column
	call asmList_write_blanks_for_address	; advances ES:DI
	call asmList_write_separator_after_address	; advances ES:DI
asmList_write_instruction_loop_do_after_address:
	; here, ES:DI is at the beginning of the bytecode column
	call asmList_write_bytecode_padded
	
	cmp word [cs:asmListingInstructionLeft], 0	; do we have instruction chars?
	je asmList_write_instruction_loop_epilogue	; no, so we don't write instruction
	; yes, so we have to write the instruction
	
	call asmList_write_separator_after_bytecode	; advances ES:DI
	call asmList_write_inst_text				; advances ES:DI
	
asmList_write_instruction_loop_epilogue:
	mov si, asmNewline
	call asm_copy_string_and_advance			; add new line
	inc word [cs:asmListingLineNumberPerCall]	; update counter
	jmp asmList_write_instruction_loop			; loop again
	
asmList_write_instruction_loop_done:
	mov word [cs:asmListingBufferPointer], di	; save pointer
	jmp asmList_write_instruction_done

asmList_write_instruction_try_non_bytecode_emitting_statements:
	call asmList_try_write_constant
	jmp asmList_write_instruction_done
	
asmList_write_instruction_very_large_entry:
	call asmList_write_large_chunk
	jmp asmList_write_instruction_done
	
asmList_write_instruction_done:
	pop es
	pop ds
	popa
	ret

	
; Writes instruction text.
; Updates instruction character count.
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the instruction text	
asmList_write_inst_text:
	push ds
	push ax
	push bx
	push cx
	push dx
	push si
	pushf
	
	mov bx, word [cs:asmListingInstructionLeft]	; BX := remaining chars
	cmp bx, ASM_LIST_COLUMN_WIDTH_INSTRUCTION	; does it fit in the column?
	jbe asmList_write_inst_text_write		; yes
	; it doesn't fit, so we write the maximum the column allows
	mov bx, ASM_LIST_COLUMN_WIDTH_INSTRUCTION
asmList_write_inst_text_write:
	push cs
	pop ds
	mov si, word [cs:asmListCurrentInstructionPointerOff]
											; DS:SI := pointer to instruction
	sub word [cs:asmListingInstructionLeft], bx				; update counter
	add word [cs:asmListCurrentInstructionPointerOff], bx	; update pointer
	
	mov cx, bx				; CX := how many chars we're writing on this line
	cld
	rep movsb
	; DI is now immediately after last character we wrote

	popf
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	pop ds
	ret
	

; Writes bytecode bytes, padding with blanks up to column width.
; Updates bytecode count.
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the bytecode	
asmList_write_bytecode_padded:
	push ds
	push ax
	push bx
	push cx
	push dx
	push si
	pushf
	
	mov bx, word [cs:asmListingBytecodeLeft]	; BX := remaining bytes
	shl bx, 1									; BX := remaining chars
	cmp bx, ASM_LIST_COLUMN_WIDTH_BYTECODE	; does it fit in the column?
	jbe asmList_write_bytecode_write		; yes
	; it doesn't fit, so we write the maximum the column allows
	mov bx, ASM_LIST_COLUMN_WIDTH_BYTECODE
asmList_write_bytecode_write:
	push word [cs:asmListCurrentBytecodePointerSeg]
	pop ds
	push word [cs:asmListCurrentBytecodePointerOff]
	pop si					; DS:SI := pointer to bytecode
	
	shr bx, 1									; BX := bytes we're writing
	sub word [cs:asmListingBytecodeLeft], bx	; update counter
	add word [cs:asmListCurrentBytecodePointerOff], bx	; update pointer
	
	mov dx, 0				; options: don't zero-terminate, no spacing
	call asm_string_to_hex	; write bytecode
		
	shl bx, 1								; BX := chars we've written
	add di, bx								; update pointer in listing buffer
	
	cmp bx, ASM_LIST_COLUMN_WIDTH_BYTECODE	; did we fill the column entirely?
	je asmList_write_bytecode_done			; yes, so we're done
asmList_write_bytecode_pad:
	; we didn't fully fill column, so we must pad
	mov cx, ASM_LIST_COLUMN_WIDTH_BYTECODE
	sub cx, bx								; CX := padding length
	mov al, ' '
	cld
	rep stosb
asmList_write_bytecode_done:
	popf
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	pop ds
	ret
	

; Writes blanks for the address
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the address
asmList_write_blanks_for_address:
	push ax
	push bx
	push cx
	pushf
	
	mov al, ' '
	mov cx, ASM_LIST_COLUMN_WIDTH_ADDRESS
	cld
	rep stosb
	
	popf
	pop cx
	pop bx
	pop ax
	ret
	

; Writes the address marked as the beginning of the current instruction	
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the address
asmList_write_address:
	push ax
	push bx
	push cx
	
	; write address
	call asmList_get_current_instruction_beginning_address	; BX := address

	mov ax, bx
	xchg ah, al									; "human" word
	mov dx, 0
	call asm_word_to_hex
	add di, 4									; it wrote this many characters
	
	pop cx
	pop bx
	pop ax
	ret
	
	
; Writes a separator after the address
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the separator
asmList_write_separator_after_address:
	push cx
	mov cx, ASM_LIST_SEPARATOR_AFTER_ADDRESS_WIDTH
	call asmList_write_separator
	pop cx
	ret
	
	
; Writes a separator after the bytecode
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the separator
asmList_write_separator_after_bytecode:
	push cx
	mov cx, ASM_LIST_SEPARATOR_AFTER_BYTECODE_WIDTH
	call asmList_write_separator
	pop cx
	ret
	
	
; Writes a separator of specified width
;
; input:
;	 ES:DI - pointer to listing buffer
;		CX - separator width in characters
; output:
;	 ES:DI - pointer to immediately after the separator
asmList_write_separator:
	push ax
	push cx
	pushf
	
	mov al, ASM_LIST_SEPARATOR_CHARACTER
	cld
	rep stosb
	
	popf
	pop cx
	pop ax
	ret
	

; Measures how many lines will be necessary to display the byte code
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - number of lines needed to display string
asmList_measure_bytecode:
	mov cx, ASM_LIST_COLUMN_WIDTH_BYTECODE
	call asmList_measure_string
	ret
	

; Measures how many lines will be necessary to display the instruction
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - number of lines needed to display string
asmList_measure_instruction:
	mov cx, ASM_LIST_COLUMN_WIDTH_INSTRUCTION
	call asmList_measure_string
	ret


; Measures how many lines will be necessary to display the string within a
; fixed-width column.
; Assumes string does not contain line breaks.
; Assumes string only contains printable characters.
;
; input:
;	 DS:SI - pointer to string, zero-terminated
;		CX - column width
; output:
;		AX - number of lines needed to display string
asmList_measure_string:
	push bx
	push dx
	
	int 0A5h					; BX := string length
	mov ax, bx
	mov dx, 0					; DX:AX := string length
	div cx						; AX := quotient, DX := remainder
	cmp dx, 0
	je asmList_measure_string_done	; no remainder
	; we have a remainder, so we need an additional line
	inc ax
asmList_measure_string_done:
	pop dx
	pop bx
	ret


; Resets listing variables
;
; input:
;		none
; output:
;		none
asmList_initialize_once:
	pusha
	push ds
	
	cmp byte [cs:asmListingIsConfigured], 0
	je asmList_initialize_once_done			; NOOP when not configured
	
	push word [cs:asmListingBufferOff]
	pop word [cs:asmListingBufferPointer]	; start by pointing to
											; beginning of buffer
	
	; write a newline
	; this is done to ensure that there exists a newline before the address,
	; when the listing begins with an address
	mov si, word [cs:asmListingBufferPointer]
	mov ds, word [cs:asmListingBufferSeg]
	mov byte [ds:si], 13
	mov byte [ds:si+1], 10
	add si, 2
	mov word [cs:asmListingBufferPointer], si
asmList_initialize_once_done:
	pop ds
	popa
	ret

	
; Finalizes listing, when configured
;
; input:
;		none
; output:
;		none
asmList_finalize:
	pusha
	push es
	
	cmp byte [cs:asmListingIsConfigured], 0
	je asmList_finalize_done				; NOOP when not configured

	push word [cs:asmListingBufferSeg]
	pop es
	push word [cs:asmListingBufferPointer]
	pop di
	
	mov byte [es:di], 0
	
asmList_finalize_done:
	pop es
	popa
	ret
	
	
; Returns the absolute 16bit address at the beginning of the current
; instruction
;
; input:
;		none
; output:
;		BX - resulting absolute address
asmList_get_current_instruction_beginning_address:
	mov bx, word [cs:asmListingCurrentInstructionBeginAddress]
	ret
	

; Called before an instruction begins executing, to mark the beginning
;
; input:
;		none
; output:
;		none
asmList_mark_instruction_beginning:
	push es
	push bx
	push di
	
	; save initial pointer into output buffer
	call asmEmit_get_ptr_to_current_location_in_output_buffer
						; ES:DI - pointer to current location in buffer
	push es
	pop word [cs:asmListingCurrentInstructionOutputBufferPtrSeg]
	push di
	pop word [cs:asmListingCurrentInstructionBeginOutputBufferPtrOff]
	
	; save initial address
	call asmEmit_get_current_absolute_16bit_address		; BX := address
	mov word [cs:asmListingCurrentInstructionBeginAddress], bx
	
	pop di
	pop bx
	pop es
	ret
	
	
; Writes the first line of the instruction text, truncating after that
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the instruction text	
asmList_write_truncated_inst_text:
	push ds
	push ax
	push bx
	push cx
	push dx
	push si
	pushf
	
	push di
	mov cx, ASM_LIST_COLUMN_WIDTH_INSTRUCTION
	cld
	mov al, ' '
	rep stosb
	pop di										; fill instruction with blanks
	
	push di											; [1]
	
	push cs
	pop ds
	mov si, asmLastInstructionBuffer
	int 0A5h					; BX := string length
	cmp bx, ASM_LIST_COLUMN_WIDTH_INSTRUCTION - 3	; does it fit?
	jbe asmList_write_truncated_inst_text_write		; yes
	; it doesn't fit, so we write the maximum the column allows
	mov bx, ASM_LIST_COLUMN_WIDTH_INSTRUCTION - 3
	mov byte [es:di+ASM_LIST_COLUMN_WIDTH_INSTRUCTION-1], '.'
	mov byte [es:di+ASM_LIST_COLUMN_WIDTH_INSTRUCTION-2], '.'
	mov byte [es:di+ASM_LIST_COLUMN_WIDTH_INSTRUCTION-3], '.'
asmList_write_truncated_inst_text_write:
	; here DS:SI = pointer to beginning of instruction
	mov cx, bx				; CX := how many chars we're writing on this line
	cld
	rep movsb
	
	pop di											; [1]
	add di, ASM_LIST_COLUMN_WIDTH_INSTRUCTION
			; bring ES:DI to immediately after instruction column
	popf
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	pop ds
	ret
	
	
; Writes large chunk bytecode, padding with blanks up to column width.
;
; input:
;	 ES:DI - pointer to listing buffer
; output:
;	 ES:DI - pointer to immediately after the bytecode	
asmList_write_large_chunk_bytecode:
	push ds
	push ax
	push bx
	push cx
	push dx
	push si
	pushf
	
	push cs
	pop ds
	mov si, asmListHardcodedLargeBytecodeLabel
	int 0A5h					; BX := string length
	cmp bx, ASM_LIST_COLUMN_WIDTH_BYTECODE	; does it fit in the column?
	jbe asmList_write_large_chunk_bytecode_write		; yes
	; it doesn't fit, so we write the maximum the column allows
	mov bx, ASM_LIST_COLUMN_WIDTH_BYTECODE
asmList_write_large_chunk_bytecode_write:
	mov cx, bx				; CX := how many chars we're writing on this line
	cld
	rep movsb

	cmp bx, ASM_LIST_COLUMN_WIDTH_BYTECODE	; did we fill the column entirely?
	je asmList_write_large_chunk_bytecode_done		; yes, so we're done
asmList_write_large_chunk_bytecode_pad:
	; we didn't fully fill column, so we must pad
	mov cx, ASM_LIST_COLUMN_WIDTH_BYTECODE
	sub cx, bx								; CX := padding length
	mov al, '.'
	cld
	rep stosb
asmList_write_large_chunk_bytecode_done:
	popf
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	pop ds
	ret


; Writes a large chunk to the listing buffer
; Assumption: instruction has been concatenated to a single string
;
; input:
;		none
; output:
;		none
asmList_write_large_chunk:
	pusha
	push ds
	push es
	
	cmp byte [cs:asmListingIsConfigured], 0
	je asmList_write_large_chunk_done		; NOOP when not configured
	cmp byte [cs:asmPass], ASM_PASS_2
	jne asmList_write_large_chunk_done		; NOOP during passes other than 2

	push word [cs:asmListingBufferSeg]			; ES:DI := current pointer into
	pop es										; listing (this is maintained
	mov di, word [cs:asmListingBufferPointer]	; throughout this procedure)
	
	call asmList_write_address					; advances ES:DI
	call asmList_write_separator_after_address	; advances ES:DI
	call asmList_write_large_chunk_bytecode		; advances ES:DI
	call asmList_write_separator_after_bytecode	; advances ES:DI
	call asmList_write_truncated_inst_text		; advances ES:DI
	
asmList_write_large_chunk_loop_epilogue:
	push cs
	pop ds
	mov si, asmNewline
	call asm_copy_string_and_advance			; add new line

	mov word [cs:asmListingBufferPointer], di	; save pointer
	jmp asmList_write_large_chunk_done
	
asmList_write_large_chunk_done:
	pop es
	pop ds
	popa
	ret
	

; Configures the assembler to generate a listing
;
; input:
;	 DS:SI - pointer to listing buffer, where listing will be stored
; output:
;		none
asm_configure_listing:
	mov byte [cs:asmListingIsConfigured], 1
	
	push ds
	pop word [cs:asmListingBufferSeg]
	push si
	pop word [cs:asmListingBufferOff]		; save pointer to buffer

	ret
	

%endif
