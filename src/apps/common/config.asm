;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for dealing with configuraton properties in a buffer.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_CONFIG_
%define _COMMON_CONFIG_

CONFIG_ASCII_OPENER equ '['
CONFIG_ASCII_SEPARATOR equ '='
CONFIG_ASCII_CLOSER equ ']'

CONFIG_PARAM_NAME_MAX_LENGTH equ 64
CONFIG_PARAM_VALUE_MAX_LENGTH equ 256

; internal work buffers
configTempNameBuffer: times CONFIG_PARAM_NAME_MAX_LENGTH+1 db 0
configTempValueBuffer: times CONFIG_PARAM_VALUE_MAX_LENGTH+1 db 0

CONFIG_TOKEN_PARSE_NONE_LEFT		equ 0
CONFIG_TOKEN_PARSE_PARSED			equ 1
CONFIG_TOKEN_PARSE_ERROR			equ 2

CONFIG_CHAR_STRING_DELIMITER		equ COMMON_ASCII_DOUBLEQUOTE
CONFIG_CHAR_LINE_ENDING				equ COMMON_ASCII_LINE_FEED


configStopTokenChars:			; the tokenizer stops on these characters
	db ','
configStopTokenCharsCount equ $ - configStopTokenChars


; Returns the value of the specified parameter, given its name.
;
; input:
;	 DS:SI - pointer to the name of the parameter to look up (zero-terminated)
;	 ES:DI - pointer to buffer into which parameter value will be read
;	 FS:DX - pointer to beginning of serialized parameter data buffer
;		CX - size of serialized parameter data
; output:
;		AX - 0 when parameter was not found, another value otherwise
common_config_get_parameter_value:
	push es
	push bx
	push di							; [2] save params
	
	mov bx, 0						; start from offset 0
common_config_get_parameter_value_loop:
	mov di, cx						; DI := serialized parameter data size
	call _config_read_next_parameter
	cmp ax, 0						; did we get a parameter?
	je common_config_get_parameter_value_not_found	; no, there are no more parameters

	; is this the right parameter?
	push cs
	pop es
	mov di, configTempNameBuffer	; ES:DI := pointer to current parameter name
	int 0BDh						; compare current parameter name to the one
									; passed in DS:SI by the consumer
	cmp ax, 0						; is this the right parameter?
	jne common_config_get_parameter_value_loop	; no, try the next parameter
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
	mov si, configTempValueBuffer	; DS:SI := pointer to parameter value
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
common_config_get_parameter_value_not_found:
	mov ax, 0						; return failure
	pop di
	pop bx
	pop es							; [2] restore params
	ret


; Populates configTempNameBuffer and configTempValueBuffer with the 
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
_config_read_next_parameter:
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
	
	mov cl, CONFIG_ASCII_OPENER		; find opener
	call _config_get_next_character_offset	; BX := offset of opener
	cmp ax, 0
	je _config_read_next_parameter_not_found	; no more parameters

	; opener was found!
	inc bx							; BX := offset of first character of name
	
	mov cx, bx						; CX := offset of first character of name
	
	push cx							; save offset of first character of name
	mov cl, CONFIG_ASCII_SEPARATOR	; find separator
	call _config_get_next_character_offset	; BX := offset of separator
	pop cx							; restore offset of first character of name
	cmp ax, 0
	je _config_read_next_parameter_not_found	; separator not found!
	; separator was found!
	pusha
	sub bx, cx						; BX := length of parameter name
	cmp bx, CONFIG_PARAM_NAME_MAX_LENGTH
	popa
	ja _config_read_next_parameter_not_found	; name is too long
	
	push bx							; [1] save offset of separator
	
	mov si, dx						; SI := beginning of serialized param. data
	add si, cx						; DS:SI := pointer to first char. of name
	
	sub bx, cx						; BX := length of parameter name
	mov cx, bx						; CX := length of parameter name

	push di							; [3] save size of serialized param. data
	mov di, configTempNameBuffer	; ES:DI := pointer to parameter name buffer
	cld
	rep movsb						; copy parameter name to buffer
	mov byte [es:di], 0				; add string terminator
	pop di							; [3] restore size of serialized param data
	; parameter name buffer now contains the parameter name (zero-terminated)

	pop bx							; [1] restore offset of separator
	inc bx							; BX := offset of first character of value
	
	mov cx, bx						; CX := offset of first character of value
	
	push cx							; save offset of first character of value
	mov cl, CONFIG_ASCII_CLOSER		; find closer character
	call _config_get_next_character_offset	; BX := offset of closer character
	pop cx							; restore offset of first character of val.
	cmp ax, 0
	je _config_read_next_parameter_not_found	; closer character not found!

	; closer was found!
	pusha
	sub bx, cx						; BX := length of parameter value
	cmp bx, CONFIG_PARAM_VALUE_MAX_LENGTH
	popa
	ja _config_read_next_parameter_not_found	; value is too long

	push bx							; [2] save offset of closer character
	
	mov si, dx						; SI := beginning of serialized param. data
	add si, cx						; DS:SI := pointer to first char. of value
	
	sub bx, cx						; BX := length of parameter value
	mov cx, bx						; CX := length of parameter value
	push di							; [4] save size of serialized param. data
	mov di, configTempValueBuffer	; ES:DI := pointer to param. value buffer
	cld
	rep movsb						; copy parameter value to buffer
	mov byte [es:di], 0				; add string terminator
	pop di							; [4] restore size of serialized param data
	; parameter value buffer now contains the parameter value (zero-terminated)
	
	pop bx							; [2] restore offset of closer character
	inc bx							; BX := offset of next char. after closer
	
	mov ax, 1						; success!
	jmp _config_read_next_parameter_exit
_config_read_next_parameter_not_found:
	mov ax, 0						; not found!
_config_read_next_parameter_exit:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	popf
	ret


; Reads the next token
;
; input:
;	 DS:SI - pointer to string, zero-terminated
;	 ES:DI - pointer to where token will be stored, zero-terminated
; output:
;	 DS:SI - pointer to immediately after token
;		AX - 0 when there were no more tokens to read
;			 1 when a token was read (success)
;			 2 when there was an error
common_config_read_token:
	pushf
	push bx
	push cx
	push dx
	push di
	
	cld
	
	mov ax, CONFIG_TOKEN_PARSE_NONE_LEFT		; "no token found"
common_config_read_token_advance_to_token_start_loop:
	cmp byte [ds:si], 0			; are we at the end of input?
	je common_config_read_token_done	; yes

	call _common_config_is_ignored_character	; are we on an ignored character?
	jnc common_config_read_token_start_found	; no, so we have found the token start
	
	inc si						; next character
	jmp common_config_read_token_advance_to_token_start_loop

common_config_read_token_start_found:
	; DS:SI now points to the first character of the token we're returning
	mov ax, CONFIG_TOKEN_PARSE_PARSED	; "token found"
	mov bx, 0					; "not a string literal"
	mov cx, 0					; token length counter
	
	cmp byte [ds:si], CONFIG_CHAR_STRING_DELIMITER	; is it a string literal?
	jne common_config_read_token_copy	; no
	mov bx, 1					; "a string literal"
common_config_read_token_copy:
	cmp cx, CONFIG_PARAM_VALUE_MAX_LENGTH	; have we already accumulated as many
	je common_config_read_token_overflow	; characters as the max token length?
	; we have not yet filled the token buffer, so we accumulate this character
	movsb						; copy it into the output buffer
								; and advance input pointer

	inc cx						; token length counter
	
	cmp byte [ds:si-1], CONFIG_CHAR_LINE_ENDING	; is this token a new line?
	je common_config_read_token_done	; yes
	
	cmp byte [ds:si], 0			; are we at the end of input?
	je common_config_read_token_done	; yes
	
	cmp bx, 1					; is this token a string literal?
	jne common_config_read_token_copy_not_string_literal	; no
	
	; we're inside a string literal
	cmp byte [ds:si-1], CONFIG_CHAR_STRING_DELIMITER	; did we just accumulate
													; the string delimiter?
	jne common_config_read_token_copy	; no, keep accumulating
	; we just accumulated the delimiter
	; we must check if it's the opening string delimiter, or 
	; the closing string delimiter
	cmp cx, 1					; are we past the first character of the token?
	ja common_config_read_token_done	; yes, so this was the closing delimiter
	jmp common_config_read_token_copy	; no, so we accumulate next token character

common_config_read_token_copy_not_string_literal:	
	; we're not inside a string literal
	call _common_config_is_ignored_character
	jc common_config_read_token_done			; we stop before an ignored character
	
	cmp byte [ds:si], CONFIG_CHAR_LINE_ENDING
	je common_config_read_token_done			; we stop before a newline
	
	call _common_config_is_stop_character		; are we before a stop character?
	jc common_config_read_token_done			; yes
	push si
	dec si
	call _common_config_is_stop_character		; are we after a stop character?
	pop si
	jc common_config_read_token_done			; yes
	
	cmp byte [ds:si], CONFIG_CHAR_STRING_DELIMITER
	je common_config_read_token_done			; we stop before a string delimiter
										; (since we're not inside a 
										; string literal)
	
	jmp common_config_read_token_copy			; next token character

common_config_read_token_overflow:
	; the token was too long, so we should halt interpretation with an error
	mov ax, CONFIG_TOKEN_PARSE_ERROR			; "error"
	jmp common_config_read_token_exit
common_config_read_token_done:
	mov byte [es:di], 0					; add terminator
common_config_read_token_exit:	
	pop di
	pop dx
	pop cx
	pop bx
	popf
	ret
	
	
; Checks whether the specified character is a tokenizer stop character
;
; input:
;	 DS:SI - pointer to character
; output:
;	 CARRY - set if it is a stop character, clear otherwise
_common_config_is_stop_character:
	pusha

	mov al, byte [ds:si]
	; is it a stop character?
	mov si, configStopTokenChars
	mov cx, configStopTokenCharsCount
_common_config_is_stop_character_loop:
	cmp al, byte [cs:si]					; is it a stop character?
	je _common_config_is_stop_character_yes		; yes, so we're done
	inc si									; next character to check
	loop _common_config_is_stop_character_loop

_common_config_is_stop_character_no:
	clc										; not a stop character
	popa
	ret
_common_config_is_stop_character_yes:
	stc
	popa
	ret
	
	
; Checks whether the specified character is an ignored character
;
; input:
;	 DS:SI - pointer to character
; output:
;	 CARRY - set if it is an ignored character, clear otherwise
_common_config_is_ignored_character:
	clc
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
_config_get_next_character_offset:
	push si
	
	mov si, dx
_config_get_next_character_offset_loop:
	cmp bx, di										; end of file?
	jae _config_get_next_character_offset_not_found	; yes, so we're done

	cmp byte [fs:si+bx], cl							; is this the character?
	je _config_get_next_character_offset_loop_found	; yes
	; no, so move to the next character
	inc bx
	jmp _config_get_next_character_offset_loop	; loop again

_config_get_next_character_offset_not_found:
	mov ax, 0
	jmp _config_get_next_character_offset_loop_exit
_config_get_next_character_offset_loop_found:
	mov ax, 1
_config_get_next_character_offset_loop_exit:
	pop si
	ret


%endif
