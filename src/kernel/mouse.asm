;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; This is the highest-level source file of the mouse driver.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; these match config property values
MOUSE_DRIVER_TYPE_HARDWARE	equ 0
MOUSE_DRIVER_TYPE_PSEUDO	equ 1

MOUSE_PROMPT_CHOICE_COUNT	equ 3	; none, hardware, pseudo

mouseDriverTypePropertyName:	db 'mouse_driver_type', 0

mouseDriverType:			dw MOUSE_DRIVER_TYPE_HARDWARE
mouseDriverIsLoaded:		db 0		; also set from the low-level
										; mouse source file
mousePromptChoices:			times MOUSE_PROMPT_CHOICE_COUNT db 99
mouseCurrentChoicePtr:	dw mousePromptChoices
									; pointer into choice array
mousePromptSelect:		db 13, 10, '    press SPACE to cycle through options, ENTER to accept, ESCAPE to exit', 13, 10, 0
								; intentionally non-terminated
mousePromptSelectIdMessage:			db 13, '    mouse driver choice (0=none, 1=pseudo-mouse, 2=hardware): ', 0
							

; Highest-level mouse driver initialization routine
;
; input
;		none
; output:
;		none
mouse_general_initialize_preliminary:
	push ds
	pusha
	
	push cs
	pop ds	
	mov si, mouseDriverTypePropertyName
	call config_get_numeric_property_value
	cmp ax, 0
	je mouse_general_initialize_preliminary_after_driver_type
	call mouse_set_configured_driver_type		; set type to CX
	
mouse_general_initialize_preliminary_after_driver_type:
	popa
	pop ds
	ret
	

; Sets driver type
;
; input
;		CX - driver type
; output:
;		none	
mouse_set_configured_driver_type:
	mov word [cs:mouseDriverType], cx
	ret
	
	
; Prompts the user to override mouse settings in the config file
;
; input
;		none
; output:
;		AX - 0 when user wants no mouse
;			 1 when user wants pseudo mouse
;			 2 when user wants real mouse
;			 3 when user does nothing
mouse_prompt:
	push bx
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	push cs
	pop ds
	
	; now prompt the user, giving him a chance to cancel the initialization
	; this is to cover the case of some newer hardware on which initializing
	; the mouse driver causes the keyboard to lock up immediately
	mov si, initMouseString
	mov bh, 'y'							; can press both lower case
	mov bl, 'Y'							; and upper case
	mov dl, byte [cs:userChoiceTimeoutSeconds]	; seconds to wait
	call utility_countdown_user_prompt	; AL := 1 if user pressed Y
	cmp al, 1
	jne mouse_prompt_no_action			; user did nothing
	
	; now let the user select a choice
	call mouse_ask_user_for_choice		; DL := choice
	cmp ax, 0							; cancelled?
	je mouse_prompt_no_action			; yes
	
	mov ah, 0
	mov al, dl							; AX := choice
	jmp mouse_prompt_done
	
mouse_prompt_no_action:
	mov ax, 3
mouse_prompt_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Asks user to select a mouse driver type, or to turn it off
;
; input
;		none
; output:
;		AX - 0 when user cancelled, other value otherwise
;		DL - 0=no driver, 1=pseudo, 2=hardware
mouse_ask_user_for_choice:
	pushf
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push si
	push di
	
	; fill in choices
	mov byte [cs:mousePromptChoices + 0], 0
	mov byte [cs:mousePromptChoices + 1], 1
	mov byte [cs:mousePromptChoices + 2], 2
	
	mov word [cs:mouseCurrentChoicePtr], mousePromptChoices + 0
	
	call mouse_handle_change_choice
	
	mov si, mousePromptSelect
	call debug_print_string
mouse_ask_user_for_choice_loop:
	; re-display choice
	mov si, mousePromptSelectIdMessage
	call debug_print_string
	mov si, word [cs:mouseCurrentChoicePtr]
	mov al, byte [cs:si]
	push ax
	call hex_digit_to_char
	call debug_print_char				; print choice ID
	pop ax
	
mouse_ask_user_for_choice_loop_wait_key:
	mov ah, 0
	int 16h						; wait for key
	cmp ah, SCAN_CODE_ENTER
	je mouse_ask_user_for_choice_success
	cmp ah, SCAN_CODE_ESCAPE
	je mouse_ask_user_for_choice_fail
	cmp ah, SCAN_CODE_SPACE_BAR
	jne mouse_ask_user_for_choice_loop
	; space was pressed
	call mouse_handle_change_choice
	
	jmp mouse_ask_user_for_choice_loop		; loop again
	
mouse_ask_user_for_choice_fail:
	mov ax, 0
	jmp mouse_ask_user_for_choice_done
mouse_ask_user_for_choice_success:
	mov si, word [cs:mouseCurrentChoicePtr]
	mov dl, byte [cs:si]					; DL := choice
	
	mov ax, 1
mouse_ask_user_for_choice_done:
	pop di
	pop si
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	popf
	ret

	
; Cycles to the next available choice.
; Affects variables involved in choice selection by user.
; 
; input:
;		none
; output:
;		none
mouse_handle_change_choice:
	pusha
	pushf
	push ds
	push es
	
mouse_handle_change_choice_do:
	inc word [cs:mouseCurrentChoicePtr]
	
	mov ax, mousePromptChoices
	mov ch, 0
	mov cl, MOUSE_PROMPT_CHOICE_COUNT
	add ax, cx							; AX := just after last choice
	cmp word [cs:mouseCurrentChoicePtr], ax
	jb mouse_handle_change_choice_done
	
	; we've gone past the end of available choices
	mov word [cs:mouseCurrentChoicePtr], mousePromptChoices
										; move to first choice
mouse_handle_change_choice_done:
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Marks the mouse driver as loaded
;
; input
;		none
; output:
;		none
mouse_general_mark_driver_loaded:
	mov byte [mouseDriverIsLoaded], 1
	ret

	
; Checks the kernel configuration to see which mouse driver should be used
;
; input
;		none
; output:
;		AX - 0=hardware mouse, 1=pseudo-mouse
mouse_get_configured_driver_type:
	mov ax, word [cs:mouseDriverType]
	ret
	

; input:
;		none
; output:
;		AL = 1 when driver is loaded, 0 otherwise
mouse_get_driver_status:
	push ds
	
	push cs
	pop ds			; DS := CS
	
	mov al, byte [mouseDriverIsLoaded]
	
	pop ds
	ret
	
	