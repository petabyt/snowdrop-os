;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains logic for emission of binary (machine code) for Snowdrop OS's 
; assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_EMIT_
%define _COMMON_ASM_EMIT_


asmEmitGlobalOrigin:				dw 0
asmEmitTotalWrittenBytes:			dw 0

asmEmitGlobalOriginSetExplicitly:	db 0
asmEmitAlreadyLoggedOverflow:		db 0


; Initializes this component
;
; input:
;		none
; output:
;		none
asmEmit_initialize:
	mov word [cs:asmEmitTotalWrittenBytes], 0
	mov byte [cs:asmEmitGlobalOriginSetExplicitly], 0
	ret
	
	
; Initializes this component once per assembly
;
; input:
;		none
; output:
;		none
asmEmit_initialize_once:
	mov byte [cs:asmEmitGlobalOriginSetExplicitly], 0
	mov byte [cs:asmEmitAlreadyLoggedOverflow], 0
	call asmEmit_initialize
	ret
	

; Checks whether emission was stopped because it would overflow
;
; input:
;		none
; output:
;		AX - 0 when there is no overflow, other value otherwise	
asmEmit_is_overflowed:
	mov ah, 0
	mov al, byte [cs:asmEmitAlreadyLoggedOverflow]
	ret
	
	
; Checks whether the bytecode output offset would cross FFFFh, 
; warning the user if so
;
; input:
;		CX - number of bytes about to be written
; output:
;		none
asmEmit_check_overflow:
	cmp byte [cs:asmPass], ASM_PASS_1
	jne asmEmit_check_overflow_done			; NOOP during passes other than 1

	cmp byte [cs:asmEmitAlreadyLoggedOverflow], 0
	jne asmEmit_check_overflow_done					; NOOP when already logged
	
	pusha
	push ds
	push es
	
	call asmEmit_get_ptr_to_current_location_in_output_buffer
			; ES:DI - pointer to current location in the output buffer
	mov ax, 65535
	sub ax, di
	cmp ax, cx										; do we have enough room
	jae asmEmit_check_overflow_pop_and_done			; to write CX bytes?

	; we would overflow
	mov byte [cs:asmEmitAlreadyLoggedOverflow], 1	; mark as logged
asmEmit_check_overflow_pop_and_done:
	pop es
	pop ds
	popa
asmEmit_check_overflow_done:
	ret
	
	
; Sets origin value
;
; input:
;		AX - origin value
; output:
;		AX - 0 when origin was not set, other value otherwise
asmEmit_set_origin:
	cmp byte [cs:asmEmitGlobalOriginSetExplicitly], 0
	jne asmEmit_set_origin_failure

	mov word [cs:asmEmitGlobalOrigin], ax
	mov byte [cs:asmEmitGlobalOriginSetExplicitly], 1
	mov ax, 1
	jmp asmEmit_set_origin_done
asmEmit_set_origin_failure:	
	mov ax, 0
asmEmit_set_origin_done:
	ret
	

; Gets how many bytes have been written so far
;
; input:
;		none
; output:
;		CX - byte count
asmEmit_get_written_byte_count:
	mov cx, word [cs:asmEmitTotalWrittenBytes]
	ret

	
; Returns the current absolute 16bit address, offset by origin
;
; input:
;		none
; output:
;		BX - resulting absolute address
asmEmit_get_current_absolute_16bit_address:
	mov bx, word [cs:asmEmitTotalWrittenBytes]		; current offset
	add bx, word [cs:asmEmitGlobalOrigin]
	ret


; Returns the address origin
;
; input:
;		none
; output:
;		CX - origin
asmEmit_get_origin:
	mov cx, word [cs:asmEmitGlobalOrigin]
	ret
	
	
; Emits a byte
;
; input:
;		AL - byte to emit
; output:
;		none
asmEmit_emit_byte_from_number:
	pusha
	push ds
	push es
	
	mov cx, 1									; we want to emit this many
	call asmEmit_check_overflow
	cmp byte [cs:asmEmitAlreadyLoggedOverflow], 0
	jne asmEmit_emit_byte_from_number_done		; NOOP when overflowed
	
	call asmEmit_get_ptr_to_current_location_in_output_buffer
					; ES:DI := pointer to current location in output buffer
	mov byte [es:di], al
	inc word [cs:asmEmitTotalWrittenBytes]		; save new byte count
asmEmit_emit_byte_from_number_done:
	pop es
	pop ds
	popa
	ret
	
	
; Emits a word in little endian order
;
; input:
;		AX - word to emit
; output:
;		none
asmEmit_emit_word_from_number:
	pusha
	push ds
	push es
	
	mov cx, 2									; we want to emit this many
	call asmEmit_check_overflow
	cmp byte [cs:asmEmitAlreadyLoggedOverflow], 0
	jne asmEmit_emit_word_from_number_done		; NOOP when overflowed

	call asmEmit_get_ptr_to_current_location_in_output_buffer
					; ES:DI := pointer to current location in output buffer
	mov word [es:di], ax
	add word [cs:asmEmitTotalWrittenBytes], 2	; save new byte count
asmEmit_emit_word_from_number_done:
	pop es
	pop ds
	popa
	ret
	

; Emits words based on the provided string.
; Each character is written out as a byte. When the string has an odd number 
; of characters, a zero byte is emitted at the end 
; (essentially casting the last character to a word)
;
; input:
;	 DS:SI - pointer to string
; output:
;		none
asmEmit_emit_words_from_string:
	pusha
	push ds
	push es

	call asmEmit_emit_bytes_from_string
	
	; now emit a zero byte for odd number of character strings
	int 0A5h								; BX := string length
	test bx, 1
	jz asmEmit_emit_words_from_string_done	; it's even
	; it's odd
	call asmEmit_get_ptr_to_current_location_in_output_buffer
					; ES:DI := pointer to current location in output buffer
					
	mov al, 0								; make it even by emitting a zero
	call asmEmit_emit_byte_from_number
	
asmEmit_emit_words_from_string_done:
	pop es
	pop ds
	popa
	ret
	

; Emits bytes based on the provided string
;
; input:
;	 DS:SI - pointer to string
; output:
;		none
asmEmit_emit_bytes_from_string:
	pushf
	pusha
	push ds
	push es

	int 0A5h							; BX := string length
	mov cx, bx							; CX := string length
	
	call asmEmit_check_overflow
	cmp byte [cs:asmEmitAlreadyLoggedOverflow], 0
	jne asmEmit_emit_bytes_from_string_done		; NOOP when overflowed
	
	call asmEmit_get_ptr_to_current_location_in_output_buffer
					; ES:DI := pointer to current location in output buffer
	cld
	rep movsb
	
	add word [cs:asmEmitTotalWrittenBytes], bx	; save new byte count
asmEmit_emit_bytes_from_string_done:	
	pop es
	pop ds
	popa
	popf
	ret
	
	
; Return a pointer to the current location in the output buffer
;
; input:
;		none
; output:
;	 ES:DI - pointer to current location in the output buffer
asmEmit_get_ptr_to_current_location_in_output_buffer:
	push word [cs:asmOutputBufferSeg]
	pop es
	mov di, word [cs:asmOutputBufferOff]
	add di, word [cs:asmEmitTotalWrittenBytes]
	ret

	
; Return a pointer to the specified address in the output buffer
;
; input:
;		AX - address
; output:
;	 DS:SI - pointer to location in the output buffer for address
asmEmit_get_ptr_to_output_buffer_by_address:
	push ax
	
	push word [cs:asmOutputBufferSeg]
	pop ds
	mov si, word [cs:asmOutputBufferOff]
	
	sub ax, word [cs:asmEmitGlobalOrigin]
	add si, ax
	
	pop ax
	ret
	

; Returns the number of bytes written so far
;
; input:
;		none
; output:
;		AX - total written bytes so far
asmEmit_get_total_written_byte_count:
	mov ax, word [cs:asmEmitTotalWrittenBytes]
	ret
	

%endif
