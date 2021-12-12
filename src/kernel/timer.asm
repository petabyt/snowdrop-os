;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains timer functionality, as well as random 
; number generation routines.
; The reason random numbers are included with the timer is because they depend 
; on the current number of ticks.
;
; WARNING: These routines are needed during kernel initialization. 
;          Kernel initialization routines must NOT call these directly, and
;          rely instead on the "int" opcode.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

timerInitialized:		db 0

currentTicksCount:		dw 0	; incremented every time the system timer ticks
delayStartCount:		dw 0	; ticks count at the start of the delay routine

lastRandomNumber:		dw 0	; last random number we generated

PIT_FREQUENCY equ 1193182		; oscillation frequency (Hz) of the 8253 PIT
TIMER_FREQUENCY equ 100			; system timer frequency (Hz)
TIMER_DIVISOR equ PIT_FREQUENCY / TIMER_FREQUENCY ; used to configure the PIT


; Initializes Snowdrop OS's system timer
;
; input
;			none
; output
;			none
timer_initialize:
	pusha
	
	mov al, 36h					; PIT channel 0
	out 43h, al    				; select channel

	mov ax, TIMER_DIVISOR
	out 40h, al    ;send low byte
	mov al, ah
	out 40h, al    ;send high byte
	
	mov byte [cs:timerInitialized], 1	; mark timer as initialized
	
	popa
	ret

	
; Gets whether the timer is initialized or not
;
; input
;			none
; output
;			AL - 0 when timer is not initialized, other value when it is
timer_is_initialized:
	mov al, byte [cs:timerInitialized]
	ret
	
	
	
; Gets the system timer's frequency in Hz
;
; input
;			none
; output
;			AX - system timer frequency in Hz
timer_get_frequency:
	mov ax, TIMER_FREQUENCY
	ret
	
	
; This callback will be called every time the system timer ticks,
; which raises a hardware interrupt which occurs approximately 
; 100 times per second
;
; input
;			none
timer_callback:
	pusha
	
	inc word [cs:currentTicksCount]
	
	int 0B8h						; invoke higher-level timer interrupt

	popa
	ret
	
; Returns the current ticks count
;
; input
;			none
; output
;			current ticks count in AX
timer_get_current_ticks:
	push ds
	
	push cs
	pop ds
	
	mov ax, word [currentTicksCount]
	
	pop ds
	ret

; Wait for a number of system timer ticks. Ticks occur every 10ms.
;
; input
;			number of system timer ticks to wait in CX
timer_delay:
	pushf
	pusha
	push ds
	
	cmp cx, 0
	je timer_delay_done				; NOOP when waiting for 0 ticks
	
	push cs
	pop ds
	
	sti			; enable interrupts so the ticks count will be updated
	
timer_delay_wait_one:	
	mov bx, word [currentTicksCount]
timer_delay_wait_for_change:
	hlt							; do nothing until there's an interrupt
	cmp bx, word [currentTicksCount]
	je timer_delay_wait_for_change	; while( currentTicksCount is unchanged ){}
									; this works because currentTicksCount is 
									; updated by the system timer interrupt
									; handler
	dec cx
	cmp cx, 0
	ja timer_delay_wait_one			; wait another change if we're not done yet
	
timer_delay_done:
	pop ds
	popa
	popf		; restore the state of the interrupt flag
	ret

	
; Returns the next random number
;
; input
;			none
; output
;			next random number in AX
random_get_next:
	push ds
	push bx
	push dx
	
	push cs
	pop ds
	
	mov al, 0		; seconds registry
	out 70h, al		; select it
	in al, 71h		; read registry value
	mov dl, al		; keep it in DL for now
					; note that at this time, DH contains whatever was set by 
					; the caller, introducing further non-determinism
	
	mov ax, word [lastRandomNumber]
	mov bl, 31
	mul bl
	add ax, word [currentTicksCount]
	mov bl, 13
	mul bl
	add ax, 98
	rol ax, 3
	add ax, word [lastRandomNumber]
	add ax, word [currentTicksCount]
	add ax, dx						; based on current RTC seconds count
	rol ax, 1
	
	mov word [lastRandomNumber], ax		; store newly calculated random number
	
	pop dx
	pop bx
	pop ds
	ret
	
	
; Initializes the random number generator based on current 
; CMOS RTC (real time clock) values
;
; input
;			none
random_initialize:
	pusha
	
	mov ah, 0
	
	mov al, 0		; seconds registry
	out 70h, al		; select it
	in al, 71h		; read registry value
	mov bx, ax
	shl bx, 8
	add bx, ax
	
	mov al, 2		; minutes registry
	out 70h, al		; select it
	in al, 71h		; read registry value
	add bx, ax
	
	mov al, 4		; hours registry
	out 70h, al		; select it
	in al, 71h		; read registry value
	add bx, ax
	
	mov al, 8		; month registry
	out 70h, al		; select it
	in al, 71h		; read registry value
	add bx, ax
	
	mov al, 9		; year registry
	out 70h, al		; select it
	in al, 71h		; read registry value
	add bx, ax

	mov word [lastRandomNumber], bx	; seed the random number generator by
									; settings its initial value
	
	popa
	ret
	