;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains serial port functionality for Snowdrop OS's BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_SERIAL_
%define _COMMON_BASIC_SERIAL_


basicOldSerialInterruptHandlerSegment:	dw 0	; used to restore previous
basicOldSerialInterruptHandlerOffset:	dw 0	; interrupt handler


; Initializes serial port functionality
;
; input:
;		none
; output:
;		none
basic_serial_initialize:
	pusha
	
	call basic_serial_register_interrupt_handler
	call common_queue_clear_atomic
	
	popa
	ret


; Shuts down serial port functionality
;
; input:
;		none
; output:
;		none
basic_serial_shutdown:
	pusha
	
	call basic_serial_restore_interrupt_handler
	
	popa
	ret
	
	
; Blocks and waits for a byte to be available for reading via serial port.
; Allows user to break.
;
; input:
;		none
; output:
;		BL - value read from serial port
;	 CARRY - set when the user pressed the break combination to halt program,
;			 clear otherwise
basic_block_read_serial:
	push ax
	push cx
	push dx
	push si
	push di
	
basic_block_read_serial_loop:
	; check whether user chose to break out of this blocking read
	mov bl, COMMON_SCAN_CODE_Q
	int 0BAh							; check key state
	cmp al, 0							; is it pressed?
	jne basic_block_read_serial_aborted	; yes
	
	; check whether a byte arrived inside queue from serial port
	call common_queue_get_length_atomic	; AX := queue length
	cmp ax, 0							; is queue empty?
	je basic_block_read_serial_loop		; yes, so keep trying
	
	; queue contains a value, so a byte came in from serial port
	call common_queue_dequeue_atomic	; DL := byte from queue
	mov bl, dl							; we're returning the byte in BL
	
	clc									; clear CARRY to show user didn't break
	jmp basic_block_read_serial_done
basic_block_read_serial_aborted:
	stc									; set CARRY to show we have user break
basic_block_read_serial_done:
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	ret
	

; Registers our interrupt handler for interrupt 0AEh, Snowdrop OS serial port
; driver's "serial user interrupt".
;
; input:
;		none
; output:
;		none
basic_serial_register_interrupt_handler:
	pusha

	pushf
	cli
	mov al, 0AEh				; we're registering for interrupt 0AEh
	mov di, basic_serial_interrupt_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)
	mov word [cs:basicOldSerialInterruptHandlerOffset], bx
	mov word [cs:basicOldSerialInterruptHandlerSegment], dx
	popf
	
	popa
	ret
	
	
; Restores the previous interrupt 0AEh handler (that is, before this program
; started).
;
; input:
;		none
; output:
;		none
basic_serial_restore_interrupt_handler:
	pusha
	push es

	mov di, word [cs:basicOldSerialInterruptHandlerOffset]
	mov ax, word [cs:basicOldSerialInterruptHandlerSegment]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 0AEh				; we're registering for interrupt 0AEh
	int 0B0h					; register interrupt handler

	pop es
	popa
	ret
	

; This is our interrupt handler, which will be registered with interrupt 0AEh.
; It will be called by the serial port driver whenever it has a byte for us.
;
; input:
;		AL - byte read from serial port
; output:
;		none
basic_serial_interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	push cs
	pop ds
	
	mov dl, al					; enqueue call below expects byte in DL
	call common_queue_enqueue_atomic ; queue up the byte we got from the driver

	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control
	

%endif
