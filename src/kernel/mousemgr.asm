;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; This is the higher-level PS/2 mouse driver source file, containing the logic
; which translates deltas from the mouse hardware to a (x, y) mouse pointer 
; location, within a user-specified system of coordinates.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

mouseManagerIsInitialized: db 0
boundingBoxWidth: dw 0
boundingBoxHeight: dw 0

mouseX:	dw 0
mouseY:	dw 0
mouseButtons: db 0	; bits 3 to 7 - unused and indeterminate
					; bit 2 - middle button current state
					; bit 1 - right button current state
					; bit 0 - left button current state
lastMouseButtons: db 0	; like above

mouseToBoxFactor: dd 0	; we multiply the mouse delta by this
mouseToBoxFactorAccelerated: dd 0	; like above, but for accelerated values
; these are used since the FPU considers all numbers it loads signed
longestBoundingBoxDimension: dd 0 ; temporary unsigned dword, used to
								  ; calculate mouse-to-box factor
ratioDenominator: dw 1000		; mouse deltas from the hardware will be
								; divided by this number to slow pointer down
ratioDenominatorAccelerated: dw 400	; like above, but for accelerated values
								
deltaX: dw 0			; unsigned, 0-255
deltaXUserCoords: dd 0	; unsigned
deltaY: dw 0			; unsigned, 0-255
deltaYUserCoords: dd 0	; unsigned

ACCELERATION_THRESHOLD equ 32	; delta values above this will be accelerated

; This interrupt handler calculates and updates the mouse position within the
; system of coordinates specified by the user, so that the user can ultimately
; poll to get the new mouse location.
; User programs who wish to use the mouse in a more advanced way can choose 
; to register their own interrupt handler.
; Note: takes raw PS/2 mouse data as input
; Note: if this is overridden, the behaviour of the "managed poll" interrupt 
;       becomes undefined
;
; input:
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
mouse_state_changed_raw_handler:
	pusha
	push ds
	
	push cs
	pop ds							; DS := CS
	
	mov al, byte [mouseManagerIsInitialized]
	cmp al, 0
	je mouse_state_changed_raw_handler_done	; if not initialized, do nothing
	
	call compute_new_mouseX
	call compute_new_mouseY
		
	and bh, 00000111b				; BH := current buttons states only
	mov byte [mouseButtons], bh		; store new value (which we just computed)
	
	; invoke mouse manager state changed handler
	mov bx, word [mouseX]
	mov dx, word [mouseY]
	mov al, byte [mouseButtons]
	int 0C0h

mouse_state_changed_raw_handler_done:
	pop ds
	popa
	ret
	

; Compute and store new mouse X value in user coordinates.
;
; input:
;		BH - bit 4 - X sign bit
;		DH - X movement (delta X)
compute_new_mouseX:
	pusha
	
	cmp dh, 0
	je compute_new_mouseX_done	; if no horizontal movement, we're done
	
	mov cl, bh				; save sign bit in CL
	test cl, 00010000b		; when bit 4 is clear, delta is positive
	jz compute_new_mouseX_positive
	neg dh					; delta := |delta|
compute_new_mouseX_positive:	
	mov ah, 0
	mov al, dh				; AX := DH
	mov word [deltaX], ax	; store to memory in preparation to FPU calls
	
	fild word [deltaX]				; st0 := deltaX
	
	cmp ax, ACCELERATION_THRESHOLD
	jb compute_new_mouseX_under_threshold	; are we under the acc. threshold?
	fld dword [mouseToBoxFactorAccelerated]	; st1 := deltaX
											; st0 :=mouseToBoxFactorAccelerated
	jmp compute_new_mouseX_multiply
compute_new_mouseX_under_threshold:
	fld dword [mouseToBoxFactor]	; st1 := deltaX
									; st0 := mouseToBoxFactor
compute_new_mouseX_multiply:
	fmulp st1, st0					; st0 := st1 * st0
	fistp dword [deltaXUserCoords]	; deltaXUserCoords := st0
	; while deltaXUserCoords is a dword, its value will never 
	; be above 65535, which means that it can be safely cast to a word
	; (since the bytes are LSB-to-MSB, due to IBM PC's little endianness)
	mov ax, word [deltaXUserCoords]
	cmp ax, 0
	jne compute_new_mouseX_non_zero		
						; if deltaXUserCoords = 0, then deltaXUserCoords := 1
	mov ax, 1			; so that mouse movement always ends in a delta
compute_new_mouseX_non_zero:
	; AX = movement delta in user coordinates
	test cl, 00010000b	; when bit 4 is clear, it's positive
	jz calculate_mouseX_move_right
calculate_mouseX_move_left:
	clc					; clear carry flag
	mov bx, [mouseX]
	sub bx, ax			; BX := mouseX - deltaXUserCoords
	jnc calculate_mouseX_move_left_no_overflow
	; we overflowed, so we constrain to 0
	mov bx, 0
calculate_mouseX_move_left_no_overflow:
	mov word [mouseX], bx
	jmp compute_new_mouseX_done	; and we're done
	
calculate_mouseX_move_right:
	clc					; clear carry flag
	mov bx, [mouseX]
	add bx, ax			; BX := mouseX + deltaXUserCoords
	jnc calculate_mouseX_move_right_no_overflow
	; we overflowed, so reduce value to limit
	mov bx, 0FFh
calculate_mouseX_move_right_no_overflow:
	cmp bx, word [boundingBoxWidth]
	jb calculate_mouseX_move_right_within_bounds
	mov bx, word [boundingBoxWidth]	; if BX >= boundingBoxWidth
	dec bx							;     then BX := boundingBoxWidth - 1
calculate_mouseX_move_right_within_bounds:
	mov word [mouseX], bx			; store final value
	
compute_new_mouseX_done:
	popa
	ret
	
	
; Compute and store new mouse Y value in user coordinates.
;
; input:
;		BH - bit 5 - Y sign bit
;		DL - Y movement (delta Y)
compute_new_mouseY:
	pusha
	
	cmp dl, 0
	je compute_new_mouseY_done	; if no vertical movement, we're done
	
	mov cl, bh				; save sign bit in CL
	test cl, 00100000b		; when bit 5 is clear, delta is positive
	jz compute_new_mouseY_positive
	neg dl					; delta := |delta|
compute_new_mouseY_positive:	
	mov ah, 0
	mov al, dl				; AX := DL
	mov word [deltaY], ax	; store to memory in preparation to FPU calls
	
	fild word [deltaY]				; st0 := deltaY
	
	cmp ax, ACCELERATION_THRESHOLD
	jb compute_new_mouseY_under_threshold	; are we under the acc. threshold?
	fld dword [mouseToBoxFactorAccelerated]	; st1 := deltaY
											; st0 :=mouseToBoxFactorAccelerated
	jmp compute_new_mouseY_multiply
compute_new_mouseY_under_threshold:
	fld dword [mouseToBoxFactor]	; st1 := deltaY
									; st0 := mouseToBoxFactor
compute_new_mouseY_multiply:
	fmulp st1, st0					; st0 := st1 * st0
	fistp dword [deltaYUserCoords]	; deltaYUserCoords := st0
	; while deltaYUserCoords is a dword, its value will never 
	; be above 65535, which means that it can be safely cast to a word
	; (since the bytes are LSB-to-MSB, due to IBM PC's little endianness)
	mov ax, word [deltaYUserCoords]
	cmp ax, 0
	jne compute_new_mouseY_non_zero		
						; if deltaYUserCoords = 0, then deltaYUserCoords := 1
	mov ax, 1			; so that mouse movement always ends in a delta
compute_new_mouseY_non_zero:
	; AX = movement delta in user coordinates
	test cl, 00100000b	; when bit 5 is clear, mouse moved up
	jnz calculate_mouseY_move_down	; BUT, we want it the other way around!
calculate_mouseY_move_up:
	clc					; clear carry flag
	mov bx, [mouseY]
	sub bx, ax			; BX := mouseY - deltaYUserCoords
	jnc calculate_mouseY_move_up_no_overflow
	; we overflowed, so we constrain to 0
	mov bx, 0
calculate_mouseY_move_up_no_overflow:
	mov word [mouseY], bx
	jmp compute_new_mouseY_done	; and we're done
	
calculate_mouseY_move_down:
	clc					; clear carry flag
	mov bx, [mouseY]
	add bx, ax			; BX := mouseY + deltaYUserCoords
	jnc calculate_mouseY_move_down_no_overflow
	; we overflowed, so reduce value to limit
	mov bx, 0FFh
calculate_mouseY_move_down_no_overflow:
	cmp bx, word [boundingBoxHeight]
	jb calculate_mouseY_move_down_within_bounds
	mov bx, word [boundingBoxHeight]	; if BX >= boundingBoxHeight
	dec bx							;     then BX := boundingBoxHeight - 1
calculate_mouseY_move_down_within_bounds:
	mov word [mouseY], bx			; store final value
	
compute_new_mouseY_done:
	popa
	ret
	
	
; Returns the current mouse location (in user coordinates), and buttons state.
;
; output:
;		AL - bits 3 to 7 - unused and indeterminate
;			 bit 2 - middle button current state
;			 bit 1 - right button current state
;			 bit 0 - left button current state
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
mouse_manager_poll:
	push ds
	
	push cs
	pop ds							; DS := CS
	
	mov al, byte [mouseButtons]
	mov bx, word [mouseX]
	mov dx, word [mouseY]
	
	pop ds
	ret


; Sets mouse velocity divisor
;
; input:
;		AX - mouse velocity divisor value
mouse_manager_set_divisor:
	mov word [cs:ratioDenominator], ax
	ret


; Sets mouse velocity divisor when under acceleration
;
; input:
;		AX - mouse velocity divisor value (under acceleration)
mouse_manager_set_divisor_accelerated:
	mov word [cs:ratioDenominatorAccelerated], ax
	ret
	

; Move mouse to specified location
; 
; input:
;		DX - Y coordinate
;		BX - X coordinate
; output:
;		none	
mouse_manager_move_to:
	pusha

	cmp byte [cs:mouseManagerIsInitialized], 0
	je mouse_manager_move_to_done
	
	cmp bx, word [cs:boundingBoxWidth]
	jae mouse_manager_move_to_done
	cmp dx, word [cs:boundingBoxHeight]
	jae mouse_manager_move_to_done
	
	mov word [cs:mouseX], bx
	mov word [cs:mouseY], dx
	
mouse_manager_move_to_done:
	popa
	ret
	
	
	
; Initializes the mouse manager, which allows for polling by consumer programs.
; Also puts the mouse cursor at the centre of the bounding box.
;
; input:
;		BX - width of the bounding box within which the mouse cursor will move
;		DX - height of the bounding box within which the mouse cursor will move
; output:
;		none
mouse_manager_initialize:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov byte [mouseManagerIsInitialized], 1	; we're initialized
	
	mov byte [mouseButtons], 0			; clear mouse buttons state
	
	mov ax, bx							; assume width is longer than height
	cmp bx, dx
	jae mouse_manager_initialize_got_dimension	; width is longer - do nothing
	mov ax, dx							; height is actually longer than width
mouse_manager_initialize_got_dimension:
	; here, AX = longest dimension
	; store longest dimension as a dword
	mov byte [longestBoundingBoxDimension], bl	 ; low endian word->dword cast
	mov byte [longestBoundingBoxDimension+1], bh ; so that the FPU doesn't 
	mov byte [longestBoundingBoxDimension+2], 0	 ; interpret large word
	mov byte [longestBoundingBoxDimension+3], 0	 ; values as negative
	
	mov word [boundingBoxWidth], bx		; store width as a word
	shr bx, 1
	mov word [mouseX], bx				; initially, mouseX := boxWidth / 2
	
	mov word [boundingBoxHeight], dx	; store height
	shr dx, 1
	mov word [mouseY], dx				; initially, mouseY := boxHeight / 2
	
	fninit								; initialize FPU
	
	; calculate mouse-to-box factor
	fild dword [longestBoundingBoxDimension] ; st0 := longest box dimension
	fild word [ratioDenominator]			 ; st1 := longest box dimension
											 ; st0 := ratioDenominator
	fdivp st1, st0							 ; st0 := st1 / st0
	fstp dword [mouseToBoxFactor]	 		 ; mouseToBoxFactor := st0
	
	; calculate mouse-to-box factor for accelerated values
	fild dword [longestBoundingBoxDimension] ; st0 := longest box dimension
	fild word [ratioDenominatorAccelerated]	 ; st1 := longest box dimension
											 ; st0 := ratioDenominator
	fdivp st1, st0							 ; st0 := st1 / st0
	fstp dword [mouseToBoxFactorAccelerated] ; mouseToBoxFactor := st0
	
	pop ds
	popa
	ret
	