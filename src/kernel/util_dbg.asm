;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains debug utilities, such as a way to dump the values of all 
; registers to the video memory.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
registerAX: db "AX:", 0
registerBX: db "BX:", 0
registerCX: db "CX:", 0
registerDX: db "DX:", 0

registerDS: db "    DS:", 0
registerES: db "    ES:", 0
registerFS: db "    FS:", 0
registerGS: db "    GS:", 0

registerSI: db "  SI:", 0
registerDI: db "  DI:", 0

registerCS: db "    CS:", 0
registerIP: db "  IP:", 0

registerSS: db "    SS:", 0
registerSP: db "  SP:", 0

registerBP: 	db "                      BP:", 0
registerFLAGS:	db "                   FLAGS:", 0

stackTopPlusZero: 	db "       stack: [SS:", 0
stackTopPlusOne: 	db "              [SS:", 0
stackTopPlusTwo: 	db "              [SS:", 0
stackTopPlusThree: 	db "              [SS:", 0
stackEnding:		db "]:", 0

dsSiContents:	db "[DS:SI]: ", 0
esdiContents:	db "[ES:DI]: ", 0


; Dump register values to video ram, as they were right before 
; the "int XX" call which reaches this function
;
; NOTE: the int opcode which took us here has pushed values on the stack
;       as follows:
;			pushf
;			push cs
;			push ip
;
; input
;		none
; output
;		none
kernel_interrupt_dump_registers:
	pusha						; pushes: AX, CX, DX, BX, SP, BP, SI, DI
	push ds
	push es
	push fs
	push gs
	
	; all pushes so far: 
	; FLAGS CS, IP, AX, CX, DX, BX, SP, BP, SI, DI, DS, ES, FS, GS
	; offsets with respect to SP
	;    28 26  24  22  20  18  16  14  12  10   8   6   4   2   0
	
	mov bp, sp					; we'll use BP and the above offsets to 
								; reference register values on stack
	
	push cs
	pop ds						; DS := this segment
	
	
	call debug_print_newline
	
	mov si, registerAX
	call debug_print_string
	mov ax, word [ss:bp+22]
	call debug_print_word
	
	mov si, registerDS
	call debug_print_string
	mov ax, word [ss:bp+6]
	call debug_print_word
	
	mov si, registerSI
	call debug_print_string
	mov ax, word [ss:bp+10]
	call debug_print_word
	
	mov si, registerCS
	call debug_print_string
	mov ax, word [ss:bp+26]
	call debug_print_word
	
	mov si, registerIP
	call debug_print_string
	mov ax, word [ss:bp+24]
	sub ax, 2					; "int" opcode takes 2 bytes, so subtract 2
								; to get the address right before the "int"
								; call
	call debug_print_word
	
	mov bx, bp
	cmp bx, 0FFFFh - 30
	ja kernel_interrupt_dump_registers_after_stack_0
	add bx, 30
	mov si, stackTopPlusZero
	call debug_print_string
	mov ax, bx
	call debug_print_word
	mov si, stackEnding
	call debug_print_string
	mov al, byte [ss:bx]
	call debug_print_byte
kernel_interrupt_dump_registers_after_stack_0:
	
	call debug_print_newline
	
	mov si, registerBX
	call debug_print_string
	mov ax, word [ss:bp+16]
	call debug_print_word
	
	mov si, registerES
	call debug_print_string
	mov ax, word [ss:bp+4]
	call debug_print_word
	
	mov si, registerDI
	call debug_print_string
	mov ax, word [ss:bp+8]
	call debug_print_word
	
	mov si, registerSS
	call debug_print_string
	mov ax, ss
	call debug_print_word
	
	mov si, registerSP
	call debug_print_string
	mov ax, sp
	add ax, 30					; last entry is at SP+28, so SP was at
								; SP+30 right before the "int" call
	call debug_print_word
	
	mov bx, bp
	cmp bx, 0FFFFh - 31
	ja kernel_interrupt_dump_registers_after_stack_1
	add bx, 31
	mov si, stackTopPlusOne
	call debug_print_string
	mov ax, bx
	call debug_print_word
	mov si, stackEnding
	call debug_print_string
	mov al, byte [ss:bx]
	call debug_print_byte
kernel_interrupt_dump_registers_after_stack_1:
	
	call debug_print_newline
	
	
	mov si, registerCX
	call debug_print_string
	mov ax, word [ss:bp+20]
	call debug_print_word
	
	mov si, registerFS
	call debug_print_string
	mov ax, word [ss:bp+2]
	call debug_print_word
	
	mov si, registerBP
	call debug_print_string
	mov ax, word [ss:bp+12]
	call debug_print_word
	
	mov bx, bp
	cmp bx, 0FFFFh - 32
	ja kernel_interrupt_dump_registers_after_stack_2
	add bx, 32
	mov si, stackTopPlusTwo
	call debug_print_string
	mov ax, bx
	call debug_print_word
	mov si, stackEnding
	call debug_print_string
	mov al, byte [ss:bx]
	call debug_print_byte
kernel_interrupt_dump_registers_after_stack_2:
	
	call debug_print_newline
	
	
	mov si, registerDX
	call debug_print_string
	mov ax, word [ss:bp+18]
	call debug_print_word
	
	mov si, registerGS
	call debug_print_string
	mov ax, word [ss:bp+0]
	call debug_print_word
	
	mov si, registerFLAGS
	call debug_print_string
	mov ax, word [ss:bp+28]
	call debug_print_word
	
	mov bx, bp
	cmp bx, 0FFFFh - 33
	ja kernel_interrupt_dump_registers_after_stack_3
	add bx, 33
	mov si, stackTopPlusThree
	call debug_print_string
	mov ax, bx
	call debug_print_word
	mov si, stackEnding
	call debug_print_string
	mov al, byte [ss:bx]
	call debug_print_byte
kernel_interrupt_dump_registers_after_stack_3:
	
	call debug_print_newline
	
	; print first few bytes at DS:SI
	push ds
	pusha
	mov si, dsSiContents
	call debug_print_string
	
	mov ds, word [ss:bp+6]
	mov si, word [ss:bp+10]
	mov cx, 32
kernel_interrupt_dump_registers__dssi_loop:
	mov al, byte [ds:si]
	call debug_print_byte
	call debug_print_blank
	inc si
	loop kernel_interrupt_dump_registers__dssi_loop
	popa
	pop ds
	
	call debug_print_newline
	
	; print first few bytes at ES:DI
	push es
	pusha
	mov si, esdiContents
	call debug_print_string
	
	mov es, word [ss:bp+4]
	mov di, word [ss:bp+8]
	mov cx, 32
kernel_interrupt_dump_registers__esdi_loop:
	mov al, byte [es:di]
	call debug_print_byte
	call debug_print_blank
	inc di
	loop kernel_interrupt_dump_registers__esdi_loop
	popa
	pop es
	
	call debug_print_newline
	pop gs
	pop fs
	pop es
	pop ds
	popa
	iret
