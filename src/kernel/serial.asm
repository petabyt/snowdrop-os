;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; This is Snowdrop's serial port communications driver, exposing sending and 
; receiving functionality to consumers.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


com1BaseAddress: dw 0			; COM1 operations are all based on this address


; Blocks until the serial port is ready to send.
; Once that happens, it sends the specified byte.
;
; input:
;		AL - byte to send
; output:
;		none
serial_blocking_send:
	pusha
	
	push ax			; save byte to send
	call serial_get_driver_status
	jz serial_blocking_send_exit		; driver not loaded
	pop ax			; restore byte to send
	
	push ax			; save byte to send
serial_blocking_send_wait:
	mov dx, word [cs:com1BaseAddress]
	add dx, 5		; DX := base address + 5
	in al, dx
	test al, 00100000b	; bit 5 of Line Status Register 
						; "Empty Transmitter Holding Register"
	jz serial_blocking_send_wait	; while ( transmitter not empty ) {}
	
	pop ax			; restore byte to send
	mov dx, word [cs:com1BaseAddress]	; DX := base address + 0
	out dx, al
serial_blocking_send_exit:
	popa
	ret

	
; Returns the base I/O address of the serial port (COM1)
;
; input
;		none
; output
;		AX - base I/O address of the serial port (COM1)
serial_get_base_address:
	mov ax, word [cs:com1BaseAddress]
	ret
	

; Initialize serial port driver, if a port exists
;
; input:
;		none
; output:
;		none
serial_initialize:
	pusha
	push ds
	
	mov ax, 40h
	mov ds, ax					; BIOS data area starts at 0040:0000h
	
	mov ax, word [ds:10h]		; AX := BIOS equipment word
	test ax, 0000111000000000b	; bytes 9-11 hold number of serial ports
	jz serial_initialize_exit	; 0 means no ports
	
	mov bx, word [ds:00h]		; COM1 base I/O address is at offset 00h
	mov word [cs:com1BaseAddress], bx	; store COM1 base I/O address
	cmp bx, 0
	je serial_initialize_exit	; 0 means no port
	
	; here, BX = COM1 base I/O address
serial_initialize_port_found:
	push cs
	pop ds
	
	mov al, 0
	mov dx, bx
	inc dx			; base address + 1
	out dx, al		; disable interrupts

	mov dx, bx
	add dx, 3		; base address + 3
	mov al, 10000000b	
	out dx, al		; enable DLAB (most significant bit), so we can
					; start setting baud rate divisor
					; (destroying all other bits is ok for now)
					;
					; bits 7-7 : DLAB enable
					; bits 6-6 : transmit break while 1
					; bits 3-5 : parity (0=none)
					; bits 2-2 : stop bit count (0=1 stop bit)
					; bits 0-1 : char length (5 to 8)

	mov al, 12
	mov dx, bx		; base address + 0
	out dx, al		; least significant byte of divisor
	mov al, 0
	
	mov dx, bx
	add dx, 1		; base address + 1
	out dx, al		; most significant byte of divisor
					; this yields a rate of 115200 / 12 = 9600

	mov al, 00000011b
	mov dx, bx
	add dx, 3		; base address + 3
	out dx, al		; disable DLAB, and set:
					;	- 8 bit character length
					;	- no parity
					;	- 1 stop bit
					;
					; bits 7-7 : DLAB enable
					; bits 6-6 : transmit break while 1
					; bits 3-5 : parity (0=none)
					; bits 2-2 : stop bit count (0=1 stop bit)
					; bits 0-1 : char length (5 to 8)

	mov al, 11000111b
	mov dx, bx
	add dx, 2		; base address + 2
	out dx, al		; 14-byte interrupt trigger level, enable FIFOs
					; clear receive FIFO, clear transmit FIFO
					;
					; bits 7-6 : interrupt trigger level
					; bits 5-5 : enable 64-byte FIFO
					; bits 4-4 : reserved
					; bits 3-3 : DMA mode select
					; bits 2-2 : clear transmit FIFO
					; bits 1-1 : clear receive FIFO
					; bits 0-0 : enable FIFOs
	
	mov al, 00001011b
	mov dx, bx
	add dx, 4		; base address + 4
	out dx, al		; enable auxiliary output 2 (usually wired as "enable IRQ")
					; and RTS, DTR
					;
					; bits 7-6 - reserved
					; bits 5-5 - autoflow control enabled
					; bits 4-4 - loopback mode
					; bits 3-3 - auxiliary output 2 (usually wired
					;            as "enable IRQ")
					; bits 2-2 - auxiliary output 1
					; bits 1-1 - request to send (RTS)
					; bits 0-0 - data terminal ready (DTR)
	
	in al, 21h			; read IRQ mask bits from Master PIC
	and al, 11101111b	; unmask (enable) IRQ4, keeping all others unchanged
	out 21h, al			; write back IRQ mask bits to Master PIC
	
	mov al, 1
	mov dx, bx
	add dx, 1			; base address + 1
	out dx, al			; enable interrupts

serial_initialize_exit:
	pop ds
	popa
	ret

	
; input:
;		none
; output:
;		AL = 1 when driver is loaded, 0 otherwise
serial_get_driver_status:
	cmp word [cs:com1BaseAddress], 0
	jne serial_get_driver_status_loaded
	mov al, 0
	ret
serial_get_driver_status_loaded:
	mov al, 1
	ret
	

; This is the serial port IRQ handler, called whenever the hardware has data
; available for us.
; It reads all available data on the serial port, calling a user interrupt
; for each byte that it read.
; The default user interrupt handler is NOOP.
;
; For non-blocking (interrupt-driven) serial port reading, consumers are 
; expected to replace the user interrupt handler with their own.
;
; input:
;		none
; output:
;		none
serial_irq_handler:
	pusha
	
	call serial_get_driver_status
	jz serial_irq_handler_done			; 0 means driver not loaded
	
serial_irq_handler_read_and_emit:
	mov dx, word [cs:com1BaseAddress]	; DX := base address
	add dx, 5					; DX := base address + 5
	in al, dx
	test al, 00000001b			; bit 0 of Line Status Register "Data Ready"
	jz serial_irq_handler_done	; unexpectedly no data was available 
	
	mov dx, word [cs:com1BaseAddress]	; DX := base address + 0
	in al, dx					; AL := byte from serial port
	
	int 0AEh					; call user serial interrupt handler
	jmp serial_irq_handler_read_and_emit	; if we don't check multiple times
											; whether we have a byte to read, 
											; we run the risk of filling up 
											; UART's FIFO
serial_irq_handler_done:	
	; send EOI (End Of Interrupt) to the Master PIC
	mov al, 20h
	out 20h, al					; send EOI to master PIC

	popa
	ret
