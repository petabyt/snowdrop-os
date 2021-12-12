;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The LCD1602 app.
; This app interfaces with a LCD1602 16-column, 2-row LCD panel connected 
; through the parallel port.
;
; All eight parallel port data pins (via port base+0) are expected to be 
; wired to the eight data pins of the LCD1602, correspondingly.
;
; This is how LCD1602 pins connect to parallel port pins (or externally):
; (corresponding base+2 (control port) bits are also shown)
; [LCD1602] pin  purpose  |  [LPT] pin  bit  purpose
;                         |               7  UNUSED
;                         |               6  UNUSED
;                         |               5  enable bi-directional (NOT WIRED)
;                         |               4  enable IRQ (NOT WIRED)
;            5    REGSEL  |         14    1  (inverted) auto linefeed
;            6    ENABLE  |          1    0  (inverted) strobe
;            1    GROUND  |  any 18-25  N/A  ground
;------------------------------------------------------------------------------
;                         |  [External connection]
;            2     +5V    |  external supply (I used a 4.5V supply)
;            4     R/W    |  wired to ground (so it's always in WRITE mode)
;            3   CONTRAST |  wired to ground for maximum contrast, or as a 
;                              voltage divider (e.g.: 10k resistor to +5V and
;                              470r resistor to ground)
;
; (LPT pin numbering, looking into female connector on PC)
; ----------------------------------------
;  \  13  12  ..................  2  1  /
;   \   25  24  ............. 15  14   /
;    ----------------------------------
;
; LCD1602 commands (abridged list, see Hitachi HD44780 documentation for 
; detailed info - this is the controller used by LCD1602 modules):

; LCD1602 complete initialization sequence:
; (power on)
; (wait more than 15ms)
; REGSEL   R/W  D7 D6 D5 D4 D3 D2 D1 D0   purpose
;    0      0    0  0  1  1  0  0  0  0   
; (wait more than 4.1ms)
;    0      0    0  0  1  1  0  0  0  0   
; (wait more than 0.1ms)
;    0      0    0  0  1  1  0  0  0  0   
;    0      0    0  0  1  1  1  0  0  0   8-bit operation, 2 lines, 5x8 dots
;    0      0    0  0  0  0  1  0  0  0   turn off display
;    0      0    0  0  0  0  0  0  0  1   clear display
;    0      0    0  0  0  0  0  1  1  0   address increment on data writes
;    0      0    0  0  0  0  1  1  1  0   turn on display, turn on cursor
; (from here on, character data can be written, causing character to display)
;    1      0    D  D  D  D  D  D  D  D   write ASCII byte
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop app contract:
;
; At startup, the app can assume:
;	- the app is loaded at offset 0
;	- all segment registers equal CS
;	- the stack is valid (SS, SP)
;	- BP equals SP
;	- direction flag is clear (string operations count upwards)
;
; The app must:
;	- call int 95h to exit
;	- not use the entire 64kb memory segment, as its own stack begins from 
;	  offset 0FFFFh, growing upwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16						; the CPU is assumed to function in 16-bit mode
	org 0						; apps are loaded at offset 0 by the caller

	jmp start

DELAY_IN_TENS_OF_MILLISECONDS equ 2
ALL_LPT_CONTROL_REG_PINS_LOW_EXCEPT_ENABLE equ 00001010b ; (some are inverted)

noParallelDriverMessage: 	db 'No parallel port driver present. Exiting...', 0
message1:					db 'Hello, World!', 0
message2:					db 'from Snowdrop OS', 0
lptBase: dw 0

start:
	int 0B7h					; AL := parallel driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_parallel				; print error message and exit
	
	mov word [cs:lptBase], dx	; save LPT port base

	call lcd1602_initialize
	
	mov si, message1
	call print_message
	
	call lcd1602_home_cursor_on_second_line
	
	mov si, message2
	call print_message

	call bring_lpt_pins_low		; save power

	int 95h						; exit
	
no_parallel:
	mov si, noParallelDriverMessage
	int 80h						; print message
	int 95h						; exit
	


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Print a string on the LCD1602	
;
; Input:
;		DS:SI - pointer to message string
; Output:
;		none
print_message:
	pusha
print_message_loop:
	lodsb
	cmp al, 0
	je print_message_done			; end of string, so we're done printing
	call lcd1602_write_character
	jmp print_message_loop			; next character
print_message_done:
	popa
	ret


; Outputs a byte to the LPT data register
; Input:
;		AL - byte to output
; Output:
;		none
output_lpt_data_bits:
	pusha
	
	mov cx, DELAY_IN_TENS_OF_MILLISECONDS
	int 85h						; delay
	
	mov dx, word [cs:lptBase]	; LPT data port
	out dx, al
	
	popa
	ret


; Outputs a byte to the LPT control register
;
; Input:
;		AL - byte to output
; Output:
;		none
output_lpt_control_bits:
	pusha
	
	mov cx, DELAY_IN_TENS_OF_MILLISECONDS
	int 85h						; delay

	mov dx, word [cs:lptBase]
	add dx, 2
	out dx, al
	
	popa
	ret


; Performs an "instruction write" operation on the LCD controller (RS pin low)
; Assumes appropriate data bits have already been output to the LPT data port
;
; Input:
;		AL - byte to output
; Output:
;		none
perform_instruction_write:
	pusha
	
	mov al, 00000010b		; select instruction register, enable high
	call output_lpt_control_bits

	mov al, 00000011b		; select instruction register, enable low
	call output_lpt_control_bits
	
	popa
	ret
	

; Performs an "data write" operation on the LCD controller (RS pin high)
; Assumes appropriate data bits have already been output to the LPT data port
;
; Input:
;		AL - byte to output
; Output:
;		none
perform_data_write:
	pusha
	
	mov al, 00000000b		; select data register, enable high
	call output_lpt_control_bits

	mov al, 00000001b		; select data register, enable low
	call output_lpt_control_bits
	
	popa
	ret


; Writes a character on the LCD1602
;
; Input:
;		AL - character to write
; Output:
;		none
lcd1602_write_character:
	pusha
	call output_lpt_data_bits		; put ASCII on parallel port data pins
	call perform_data_write			; tell LCD1602 that this character is ready
	popa
	ret
	

; Initializes LCD1602 via software. This is the most complete way to initialize
; its controller (HD44780). This is taken straight out of HD44780U's
; documentation.
;
; It works for both cases:
; - when the power supply is insufficient for the controller's
;   internal reset circuit to initialize
; - when LCD1602 has already been initialized by the hardware
;
; Input:
;		none
; Output:
;		none
lcd1602_initialize:
	pusha
	
	; (wait more than 15ms)
	mov cx, 5
	int 85h
	
	; REGSEL   R/W  D7 D6 D5 D4 D3 D2 D1 D0   purpose
	;    0      0    0  0  1  1  0  0  0  0
	mov al, 00110000b
	call output_lpt_data_bits
	call perform_instruction_write
	
	; (wait more than 4.1ms)
	mov cx, 5
	int 85h
	
	;    0      0    0  0  1  1  0  0  0  0
	mov al, 00110000b
	call output_lpt_data_bits
	call perform_instruction_write
	
	; (wait more than 0.1ms)
	mov cx, 5
	int 85h
	
	;    0      0    0  0  1  1  0  0  0  0
	mov al, 00110000b
	call output_lpt_data_bits
	call perform_instruction_write
	
	;    0      0    0  0  1  1  1  0  0  0   8-bit operation, 2 lines, 5x8dots
	mov al, 00111000b
	call output_lpt_data_bits
	call perform_instruction_write

	;    0      0    0  0  0  0  1  0  0  0   turn off display
	mov al, 00001000b
	call output_lpt_data_bits
	call perform_instruction_write
	
	;    0      0    0  0  0  0  0  0  0  1   clear display
	mov al, 00000001b
	call output_lpt_data_bits
	call perform_instruction_write
	
	;    0      0    0  0  0  0  0  1  1  0   address increment on data writes
	mov al, 00000110b
	call output_lpt_data_bits
	call perform_instruction_write
	
	;    0      0    0  0  0  0  1  1  1  0   turn on display, turn on cursor
	mov al, 00001110b
	call output_lpt_data_bits
	call perform_instruction_write

	; (from here on, character data can be written, displaying character)
	popa
	ret
	

; Brings cursor to the beginning of the second line
;
; Input:
;		none
; Output:
;		none
lcd1602_home_cursor_on_second_line:
	pusha
	mov al, 11000000b
	call output_lpt_data_bits
	call perform_instruction_write
	popa
	ret

	
; Brings most LPT pins low after our work is complete we save some power
;
; Input:
;		none
; Output:
;		none
bring_lpt_pins_low:
	pusha

	mov al, 00000000b
	call output_lpt_data_bits		; zero out all data pins

	mov al, ALL_LPT_CONTROL_REG_PINS_LOW_EXCEPT_ENABLE
	call output_lpt_control_bits	; zero out output control pins,
									; except for Enable
	
	popa
	ret
	