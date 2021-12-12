;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains functionality for dealing with serialized parameter lists.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PARAMS_ASCII_OPENER equ '['
PARAMS_ASCII_SEPARATOR equ '='
PARAMS_ASCII_CLOSER equ ']'

PARAMS_PARAM_NAME_MAX_LENGTH equ 64
PARAMS_PARAM_VALUE_MAX_LENGTH equ 256

; internal work buffers
paramsTempNameBuffer: times PARAMS_PARAM_NAME_MAX_LENGTH+1 db 0
paramsTempValueBuffer: times PARAMS_PARAM_VALUE_MAX_LENGTH+1 db 0


; Returns the value of the specified parameter, given its name.
;
; input:
;	 DS:SI - pointer to the name of the parameter to look up (zero-terminated)
;	 ES:DI - pointer to buffer into which parameter value will be read
;	 FS:DX - pointer to beginning of serialized parameter data buffer
;		CX - size of serialized parameter data
; output:
;		AX - 0 when parameter was not found, another value otherwise
params_get_parameter_value:
	push es
	push bx
	push di							; [2] save params
	
	mov bx, 0						; start from offset 0
params_get_parameter_value_loop:
	mov di, cx						; DI := serialized parameter data size
	call params_read_next_parameter
	cmp ax, 0						; did we get a parameter?
	je params_get_parameter_value_not_found	; no, there are no more parameters

	; is this the right parameter?
	push cs
	pop es
	mov di, paramsTempNameBuffer	; ES:DI := pointer to current parameter name
	int 0BDh						; compare current parameter name to the one
									; passed in DS:SI by the consumer
	cmp ax, 0						; is this the right parameter?
	jne params_get_parameter_value_loop	; no, try the next parameter
	; it's the right parameter, so copy its value into the passed-in buffer
	
	pop di
	pop bx
	pop es							; [2] restore params
	
	push ds
	push si							; [1] save passed-in parameters
	
	pusha
	pushf
	push cs
	pop ds
	mov si, paramsTempValueBuffer	; DS:SI := pointer to parameter value
	int 0A5h						; BX := length of parameter value
	mov cx, bx						; copy this many characters
	cld
	rep movsb						; copy parameter value into destination
	mov byte [es:di], 0				; add string terminator
	popf
	popa
	
	pop si
	pop ds							; [1] restore passed-in parameters
	
	mov ax, 1						; return success
	ret
params_get_parameter_value_not_found:
	mov ax, 0						; return failure
	pop di
	pop bx
	pop es							; [2] restore params
	ret


; Populates paramsTempNameBuffer and paramsTempValueBuffer with the 
; name and value of the next parameter in the serialized parameter data.
;
; input:
;	 FS:DX - pointer to beginning of serialized parameter data buffer
;		BX - offset of first character from which to start parsing
;		DI - size of serialized parameter data
; output:
;		AX - 0 when parameter was not found, another value otherwise
;		BX - offset of character immediately after the last read parameter
;			 contains an UNDEFINED value when call is not successful
params_read_next_parameter:
	pushf
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	push fs
	pop ds							; DS := data buffer segment
	push cs
	pop es							; ES := this segment
	
	mov cl, PARAMS_ASCII_OPENER		; find opener
	call params_get_next_character_offset	; BX := offset of opener
	cmp ax, 0
	je params_read_next_parameter_not_found	; no more parameters

	; opener was found!
	inc bx							; BX := offset of first character of name
	
	mov cx, bx						; CX := offset of first character of name
	
	push cx							; save offset of first character of name
	mov cl, PARAMS_ASCII_SEPARATOR	; find separator
	call params_get_next_character_offset	; BX := offset of separator
	pop cx							; restore offset of first character of name
	cmp ax, 0
	je params_read_next_parameter_not_found	; separator not found!
	; separator was found!
	pusha
	sub bx, cx						; BX := length of parameter name
	cmp bx, PARAMS_PARAM_NAME_MAX_LENGTH
	popa
	ja params_read_next_parameter_not_found	; name is too long
	
	push bx							; [1] save offset of separator
	
	mov si, dx						; SI := beginning of serialized param. data
	add si, cx						; DS:SI := pointer to first char. of name
	
	sub bx, cx						; BX := length of parameter name
	mov cx, bx						; CX := length of parameter name

	push di							; [3] save size of serialized param. data
	mov di, paramsTempNameBuffer	; ES:DI := pointer to parameter name buffer
	cld
	rep movsb						; copy parameter name to buffer
	mov byte [es:di], 0				; add string terminator
	pop di							; [3] restore size of serialized param data
	; parameter name buffer now contains the parameter name (zero-terminated)

	pop bx							; [1] restore offset of separator
	inc bx							; BX := offset of first character of value
	
	mov cx, bx						; CX := offset of first character of value
	
	push cx							; save offset of first character of value
	mov cl, PARAMS_ASCII_CLOSER		; find closer character
	call params_get_next_character_offset	; BX := offset of closer character
	pop cx							; restore offset of first character of val.
	cmp ax, 0
	je params_read_next_parameter_not_found	; closer character not found!

	; closer was found!
	pusha
	sub bx, cx						; BX := length of parameter value
	cmp bx, PARAMS_PARAM_VALUE_MAX_LENGTH
	popa
	ja params_read_next_parameter_not_found	; value is too long

	push bx							; [2] save offset of closer character
	
	mov si, dx						; SI := beginning of serialized param. data
	add si, cx						; DS:SI := pointer to first char. of value
	
	sub bx, cx						; BX := length of parameter value
	mov cx, bx						; CX := length of parameter value
	push di							; [4] save size of serialized param. data
	mov di, paramsTempValueBuffer	; ES:DI := pointer to param. value buffer
	cld
	rep movsb						; copy parameter value to buffer
	mov byte [es:di], 0				; add string terminator
	pop di							; [4] restore size of serialized param data
	; parameter value buffer now contains the parameter value (zero-terminated)
	
	pop bx							; [2] restore offset of closer character
	inc bx							; BX := offset of next char. after closer
	
	mov ax, 1						; success!
	jmp params_read_next_parameter_exit
params_read_next_parameter_not_found:
	mov ax, 0						; not found!
params_read_next_parameter_exit:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	popf
	ret


; Finds the occurrence of the next specified character in the serialized 
; parameter data, and returns its offset.
;
; Returns "not found" when character if the offset is past the end.
;
; input:
;	 FS:DX - pointer to beginning of serialized parameter data buffer
;		BX - offset from which to start searching
;		CL - ASCII value of character to find
;		DI - size of serialized parameter data
; output:
;		AX - 0 when opener was not found, another value otherwise
;		BX - offset of next occurrence of the specified character
;			 contains an UNDEFINED value when call is not successful
params_get_next_character_offset:
	push si
	
	mov si, dx
params_get_next_character_offset_loop:
	cmp bx, di										; end of file?
	jae params_get_next_character_offset_not_found	; yes, so we're done

	cmp byte [fs:si+bx], cl							; is this the character?
	je params_get_next_character_offset_loop_found	; yes
	; no, so move to the next character
	inc bx
	jmp params_get_next_character_offset_loop	; loop again

params_get_next_character_offset_not_found:
	mov ax, 0
	jmp params_get_next_character_offset_loop_exit
params_get_next_character_offset_loop_found:
	mov ax, 1
params_get_next_character_offset_loop_exit:
	pop si
	ret


; Prints all parameters in the specified serialized parameter data
;
; input:
;	 FS:DX - pointer to beginning of serialized parameter data buffer
;		DI - size of serialized parameter data
; output:
;		none
params_print_all_parameters:
	pusha
	push ds
	
	push cs
	pop ds

	mov bx, 0
params_print_all_parameters_loop:
	call params_read_next_parameter
	cmp ax, 0							; did we get a parameter?
	je params_print_all_parameters_exit	; no, there are no more parameters
	
	mov si, paramsTempNameBuffer
	call debug_print_string
	mov al, ':'
	call debug_print_char
	mov si, paramsTempValueBuffer
	call debug_print_string
	call debug_print_newline

	jmp params_print_all_parameters_loop
params_print_all_parameters_exit:
	pop ds
	popa
	ret
