;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; This is the lower-level PS/2 mouse driver source file, containing the logic
; around communication with the hardware.
; Its highest-level routine is an IRQ12 handler which collects one byte of 
; mouse data at a time. It then notifies a software interrupt, passing in all
; data bytes it has accumulated.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lastMouseData: db 0, 0, 0		; the three bytes of last mouse IRQ, available
								; to consumers
								; this becomes populated once we finish reading
								; a batch of 3 bytes from the mouse

currentMouseData: db 0, 0, 0	; used to read mouse data from in-flight 
currentMouseDataOffset: dw 0	; interrupt requests


; Detect whether a PS/2 mouse is installed
;
; input:
;			none
; output:
;			AX - 1 when a PS/2 mouse is present, 0 otherwise
mouse_device_is_present:
	push ds
	mov ax, 40h
	mov ds, ax							; BIOS data area starts at 0040:0000h
	
	mov ax, word [ds:10h]				; AX := BIOS equipment word
	and ax, 0000000000000100b			; bit 2 = PS/2 mouse is installed
	shr ax, 2
	pop ds
	ret


; Initialize mouse
;
; input:
;			none
; output:
;			none
mouse_initialize:
	pusha
	pushf								; save flags
	
	call mouse_device_is_present		; is a PS/2 mouse installed?
	cmp ax, 0
	je mouse_initialize_exit			; NOOP when mouse not present
	
	cli									; disable interrupts
										; if we don't disable interrupts here,
										; key presses during initialization can
										; affect either keyboard or mouse
	
	mov al, 0ADh						; disable keyboard for now to cut noise
	call ps2controller_command_send		; "disable first PS/2 device(keyboard)"
	
	mov al, 0A8h
	call ps2controller_command_send		; "enable auxiliary device" (mouse)
	
	call mouse_reset
	
	mov al, 20h
	call ps2controller_command_send		; "send me the PS/2 status byte"
	call ps2controller_read_data		; AL := status byte
	
	or al, 00000010b					; set "enable IRQ12" bit
	and al, 11011111b					; clear "disable mouse clock" bit
	push ax								; save modified status byte
	
	mov al, 60h
	call ps2controller_command_send		; "store the next byte I send you"	
	pop ax								; restore modified status byte
	call ps2controller_data_send		; send modified status byte
	
	mov al, 0F4h
	call mouse_send						; "start generating packets!" 
	call ps2controller_read_data		; read ACK
	
	mov al, 0AEh						; our mouse initialization is done
	call ps2controller_command_send		; "enable first PS/2 device (keyboard)"
	
	mov cx, 10
mouse_initialize_clear_buffer:
	call ps2controller_read_data
	dec cx
	jnz mouse_initialize_clear_buffer
	
	mov byte [mouseDriverIsLoaded], 1
mouse_initialize_exit:
	popf								; restore flags
	popa
	ret


; This interrupt handler responds to IRQ12, the PS/2 mouse IRQ number.
; In "interrupt vector numbering", this is interrupt number 74h.
; Its purpose is to collect three consecutive bytes of mouse data, after which
; it calls a user interrupt routine (that is, specified by user programs
; who want to be notified of mouse events).
;
mouse_irq_handler:
	pushf
	pusha
	push ds							; save old DS
	push es							; save old ES
	
	push cs
	pop ds							; DS := CS
	push cs
	pop es							; ES := CS
	
	call ps2controller_read_data	; AL := byte read
	
	; store the newly-read mouse data byte
	mov word bx, [currentMouseDataOffset]
	mov byte [currentMouseData + bx], al	; currentMouseData[offset] := AL
	inc bx									; offset++
	cmp bx, 3									
	jne mouse_interrupt_handler_offset_computed	; if BX != 3 then do nothing
	
	; offset has reached 3, so we have finished reading in the third byte of 
	; the current in-flight batch (the third byte is the last byte of a batch)
	
	mov si, currentMouseData
	mov di, lastMouseData
	mov cx, 3			; for i := 0 to 2

	cld
	rep movsb			; 	lastMouseData[i] := currentMouseData[i]
	
	; notify raw "state changed" handler of mouse state change
	mov byte bh, [lastMouseData + 0]	; prepare arguments
	mov byte dh, [lastMouseData + 1]
	mov byte dl, [lastMouseData + 2]	
	int 8Bh								; invoke raw "state changed" handler
	
	mov bx, 0								; reset new offset to 0
mouse_interrupt_handler_offset_computed:
	; BX contains new offset
	mov word [currentMouseDataOffset], bx	; store new offset

	; send EOI (End Of Interrupt) to the PIC
	;
	; when running in Real Mode, the PIC IRQs are as follows:
	; MASTER: IRQs 0 to 7, interrupt numbers 08h to 0Fh
	; SLAVE: IRQs 8 to 15, interrupt numbers 70h to 77h
	;
	; since PS/2 is on IRQ 12, we have to send EOI to the slave PIC as well
	mov al, 20h
	out 0A0h, al					; send EOI to slave PIC
	out 20h, al						; send EOI to master PIC
	
	pop es							; restore old ES
	pop ds							; restore old DS
	popa
	popf
	ret
	
	
; Returns the last read mouse event data. Meant to be used to read the mouse
; on-demand, rather than via an interrupt handler callback.
; Note: returns raw PS/2 mouse data as output
;
; input:
;		none
; output:
;		BH - bit 7 - Y overflow
;			 bit 6 - X overflow
;			 bit 5 - Y sign bit
;			 bit 4 - X sign bit
;			 bit 3 - unused and indeterminate
;			 bit 2 - middle button
;			 bit 1 - right button
;			 bit 0 - left button
;		DH - X movement (delta X)
;		DL - Y movement (delta Y)
mouse_poll_raw:
	mov byte bh, [cs:lastMouseData + 0]	; prepare arguments
	mov byte dh, [cs:lastMouseData + 1]
	mov byte dl, [cs:lastMouseData + 2]
	ret
	

; Block waiting for data to become available on the PS/2 data port
;
ps2controller_wait_before_read:
	pusha
	mov cx, 1000							; we'll try this many times
ps2controller_wait_before_read_loop:
	dec cx
	jz ps2controller_wait_before_read_done	; if timeout expires, we're done
	
	in al, 64h
	test al, 00000001b						; bit 0 is set when output buffer
	jz ps2controller_wait_before_read_loop	; is full (data is present)
ps2controller_wait_before_read_done:
	popa
	ret
	

; Block waiting to be able to write to the PS/2 data port
;	
ps2controller_wait_before_write:
	pusha
	mov cx, 1000							; we'll try this many times
ps2controller_wait_before_write_loop:
	dec cx
	jz ps2controller_wait_before_write_done	; if timeout expires, we're done
	
	in al, 64h
	test al, 00000010b						 ; bit 1 is clear when input buffer
	jnz ps2controller_wait_before_write_loop ; is empty (can now write to it)
ps2controller_wait_before_write_done:
	popa
	ret
	

; Send a byte value to the mouse hardware
;
; input:
;		AL - byte to send
mouse_send:
	pusha
	push ax				; save byte to output

	; tell the PS/2 controller that the next byte we write is intended 
	; for the mouse
	mov al, 0D4h					; we must send D4 to select the second 
	call ps2controller_command_send	; PS/2 device, which is the mouse (keyboard
									; is the first) 
									; NOTE: writing D4 does not generate ACK
	; the PS/2 controller will now send the next byte we write to the mouse
	
	pop ax					; AL := byte to output
	call ps2controller_data_send
	
	popa
	ret
	

; Send a command or status byte to the PS/2 controller
;
; input:
;		AL - byte to send	
ps2controller_command_send:
	pusha
	push ax				; save byte to output
	
	call ps2controller_wait_before_write
	pop ax				; AL := byte to output
	out 64h, al		; output byte
	
	popa
	ret
	

; Send a data byte to the PS/2 controller
;
; input:
;		AL - byte to send	
ps2controller_data_send:
	pusha
	push ax				; save byte to output
	
	call ps2controller_wait_before_write
	pop ax				; AL := byte to output
	out 60h, al			; output byte
	
	popa
	ret
	

; Receive a byte value from the PS/2 controller.
; NOTE: We don't know whether this data byte came from the keyboard or mouse!
;
; output:
;		AL - byte read
ps2controller_read_data:
	call ps2controller_wait_before_read		; AL := status byte
	in al, 60h
	ret
	
	
; Puts the mouse in the RESET mode, initiating a self test, which ends
; with the output of 0xAA on success.
; Once the self test completes, the mouse enters STREAM mode.
;
; input:
;		none
mouse_reset:
	pusha
	
	mov al, 0FFh
	call mouse_send						; send reset command
	call ps2controller_read_data		; read ACK
	
	mov cx, 400			; our timeout value (approx. 4 seconds)
						; the reason this is so long is because I've observed
						; older computers taking 2 seconds to reset the mouse
mouse_reset_wait_for_reset_ok_response:
	dec cx
	jz mouse_reset_wait_for_reset_read_self_test_ok	; timeout is up
	
	push cx
	mov cx, 1			; 1 tick (10ms)
	int 85h				; SNOWDROP OS-SPECIFIC! "cause delay"
	pop cx
	
	call ps2controller_read_data
	cmp al, 0AAh		; mouse hardware responds with "self test ok"
						; when reset
						; it may send other bytes before "self test ok",
						; but it should always end with "self test ok"
	jne mouse_reset_wait_for_reset_ok_response
mouse_reset_wait_for_reset_read_self_test_ok:
	; following the "self test ok" byte, the mouse sends us its device ID
	; (generally, this is 00h)
	; it is recommended that we read in that value
	call ps2controller_read_data
mouse_reset_done:
	popa
	ret
	