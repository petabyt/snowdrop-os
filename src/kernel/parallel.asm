;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains Snowdrop OS's parallel port driver.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lpt1BaseAddress dw 0			; LPT1 operations are all based on this address


; Initializes the parallel port driver, if a port exists
;
; input
;		none
; output
;		none
parallel_initialize:
	pusha
	push ds
	
	mov ax, 40h
	mov ds, ax				; BIOS data area starts at 0040:0000h
	
	mov ax, word [ds:10h]		; AX := BIOS equipment word
	test ax, 1100000000000000b	; bytes 14-15 hold number of parallel ports
	jz parallel_initialize_exit	; 0 means no ports
	
	mov ax, word [ds:08h]		; LPT1 base I/O address is at offset 08h
	mov word [cs:lpt1BaseAddress], ax	; store LPT1 base address for later
	
parallel_initialize_exit:
	pop ds
	popa
	ret
	

; Returns the base I/O address of the parallel port (LPT1)
;
; input
;		none
; output
;		AX - base I/O address of the parallel port (LPT1)
parallel_get_base_address:
	mov ax, word [cs:lpt1BaseAddress]
	ret


; input
;		none
; output
;		AL = 1 when driver is loaded, 0 otherwise
;		DX = port base address (only if driver is loaded)
parallel_get_driver_status:
	call parallel_get_base_address			; AX := base address
	cmp ax, 0
	jnz parallel_get_driver_status_driver_is_loaded

	mov al, 0			; AL := driver not loaded
	ret
parallel_get_driver_status_driver_is_loaded:
	mov dx, ax			; DX := base address
	mov al, 1			; AL := driver loaded
	ret
	

; Send a byte to the parallel port (LPT1)
;
; input
;		AL - byte to send
; output
;		none
parallel_send:
	pusha
	push ax				; save passed-in byte in AL
	
	call parallel_get_driver_status	; AL := 1 when driver is loaded
	cmp al, 1
	je parallel_send_perform		; all good, so perform the operation
	
	; driver not loaded, so this is a NOOP
	pop ax
	popa
	ret
parallel_send_perform:
	; reset port via control register (base+2)
	mov dx, word [cs:lpt1BaseAddress]
	add dx, 2			; base+2 is the control register
	in al, dx
	mov al, 00001100b	; bit 2 - reset
						; bit 3 - select printer
						; bit 5 - enable bi-directional port
	out dx, al			; output "reset"
	
	; send byte to port via data register (base+0)
	pop ax				; restore passed-in byte in AL
	mov dx, word [cs:lpt1BaseAddress]	; base+0 is the data register
	out dx, al			; output data byte
	
	; send strobe via control register (base+2), signalling that 
	; data is available
	mov dx, word [cs:lpt1BaseAddress]
	add dx, 2
	mov al, 1			; bit 0 - strobe
	out dx, al			; output strobe
	
	popa
	ret
