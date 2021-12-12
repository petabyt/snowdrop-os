;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains instruction execution routines for Snowdrop OS's 
; BASIC interpreter.
; Routines here are invoked once entire instructions have been parsed.
;
; Usually, there is a single routine per keyword. This means that - despite
; the large size of this file - there is very little branching complexity,
; keeping the code easy to understand.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_EXECUTION_
%define _COMMON_BASIC_EXECUTION_


; Executes the current instruction, GUICLEARALL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUICLEARALL:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	jne basicExecution_GUICLEARALL_tokens

	call common_gui_clear_all
	
	jmp basicExecution_GUICLEARALL_success

basicExecution_GUICLEARALL_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_GUICLEARALL_error
	
basicExecution_GUICLEARALL_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUICLEARALL_done
basicExecution_GUICLEARALL_success:
	mov ax, 1							; "success"
basicExecution_GUICLEARALL_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIRECTANGLEERASETO
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIRECTANGLEERASETO:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUIRECTANGLEERASETO_error				; there was an error

	cmp cx, COMMON_GRAPHICS_SCREEN_HEIGHT	; unsigned comparison, so negative
	jae basicExecution_GUIRECTANGLEERASETO_Y_out_of_bounds	; values are invalid also
	
	cmp bx, COMMON_GRAPHICS_SCREEN_WIDTH	; unsigned comparison, so negative
	jae basicExecution_GUIRECTANGLEERASETO_X_out_of_bounds	; values are invalid also
	
	; check that destination X and Y are at least origin X and Y, respectively
	cmp bx, word [cs:basicGuiCurrentX]
	jl basicExecution_GUIRECTANGLEERASETO_X_must_be_no_less_than_current_X
	cmp cx, word [cs:basicGuiCurrentY]
	jl basicExecution_GUIRECTANGLEERASETO_Y_must_be_no_less_than_current_Y
	
	; here, BX = destination X, CX = destination Y
	sub bx, word [cs:basicGuiCurrentX]	; BX := width
	sub cx, word [cs:basicGuiCurrentY]	; CX := height
	
	mov di, cx							; DI := height
	mov cx, bx							; CX := width
	mov bx, word [cs:basicGuiCurrentX]	; BX := X
	mov ax, word [cs:basicGuiCurrentY]	; AX := Y
	mov dl, GUI__COLOUR_1			; background-coloured rectangle
	
	; tell the integration layer that we need to draw on the background
	call basic_gui_request_background_change
	
	call common_graphics_draw_rectangle_solid		; draw it!
	
	jmp basicExecution_GUIRECTANGLEERASETO_success

basicExecution_GUIRECTANGLEERASETO_X_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiXOutOfBounds
	jmp basicExecution_GUIRECTANGLEERASETO_error
	
basicExecution_GUIRECTANGLEERASETO_Y_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiYOutOfBounds
	jmp basicExecution_GUIRECTANGLEERASETO_error
	
basicExecution_GUIRECTANGLEERASETO_X_must_be_no_less_than_current_X:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiXMustBeNoLessThanCurrentX
	jmp basicExecution_GUIRECTANGLEERASETO_error
	
basicExecution_GUIRECTANGLEERASETO_Y_must_be_no_less_than_current_Y:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiYMustBeNoLessThanCurrentY
	jmp basicExecution_GUIRECTANGLEERASETO_error
	
basicExecution_GUIRECTANGLEERASETO_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIRECTANGLEERASETO_done
basicExecution_GUIRECTANGLEERASETO_success:
	mov ax, 1							; "success"
basicExecution_GUIRECTANGLEERASETO_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIATDELTA
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIATDELTA:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUIATDELTA_error				; there was an error
	; here, BX = delta X, CX = delta Y
	mov dx, word [cs:basicGuiCurrentX]
	add dx, bx
	cmp dx, COMMON_GRAPHICS_SCREEN_WIDTH	; unsigned comparison, so negative
	jae basicExecution_GUIATDELTA_X_out_of_bounds	; values are invalid also

	mov si, word [cs:basicGuiCurrentY]
	add si, cx
	cmp si, COMMON_GRAPHICS_SCREEN_HEIGHT	; unsigned comparison, so negative
	jae basicExecution_GUIATDELTA_Y_out_of_bounds	; values are invalid also

	; here, DX = X, SI = Y, and they are valid
	mov word [cs:basicGuiCurrentX], dx
	mov word [cs:basicGuiCurrentY], si
	
	jmp basicExecution_GUIATDELTA_success

basicExecution_GUIATDELTA_X_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiAtDeltaXOutOfBounds
	jmp basicExecution_GUIATDELTA_error
	
basicExecution_GUIATDELTA_Y_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiAtDeltaYOutOfBounds
	jmp basicExecution_GUIATDELTA_error
	
basicExecution_GUIATDELTA_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIATDELTA_done
basicExecution_GUIATDELTA_success:
	mov ax, 1							; "success"
basicExecution_GUIATDELTA_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIAT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIAT:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUIAT_error				; there was an error

	cmp cx, COMMON_GRAPHICS_SCREEN_HEIGHT		; unsigned comparison, so negative
	jae basicExecution_GUIAT_Y_out_of_bounds	; values are invalid also
	
	cmp bx, COMMON_GRAPHICS_SCREEN_WIDTH	; unsigned comparison, so negative
	jae basicExecution_GUIAT_X_out_of_bounds	; values are invalid also

	; here, BX = X, CX = Y
	mov word [cs:basicGuiCurrentX], bx
	mov word [cs:basicGuiCurrentY], cx
	
	jmp basicExecution_GUIAT_success

basicExecution_GUIAT_X_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiXOutOfBounds
	jmp basicExecution_GUIAT_error
	
basicExecution_GUIAT_Y_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiYOutOfBounds
	jmp basicExecution_GUIAT_error
	
basicExecution_GUIAT_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIAT_done
basicExecution_GUIAT_success:
	mov ax, 1							; "success"
basicExecution_GUIAT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIPRINT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIPRINT:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, 1						; "no error"
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	je basicExecution_GUIPRINT_done	; NOOP when no tokens
	
	mov dl, 0						; we evaluate from the first token...
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh							; ...to the last
	call basicEval_do				; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je basicExecution_GUIPRINT_error	; there was an error
								
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	je basicExecution_GUIPRINT_number	; expression evaluated to a number
basicExecution_GUIPRINT_string:
	; expression evaluated to a string (in ES:DI)
	push es
	pop ds
	mov si, di						; DS:SI := pointer to result string
	jmp basicExecution_GUIPRINT_output
basicExecution_GUIPRINT_number:
	; the expression evaluated to a number
	push cs
	pop ds
	mov si, basicItoaBuffer			; DS:SI := pointer to itoa result
	mov ax, cx						; AX := numeric result
	call common_string_signed_16bit_int_itoa
	jmp basicExecution_GUIPRINT_output
basicExecution_GUIPRINT_output:
	; now output the string representation of the expression result
	; here, DS:SI = pointer to string representation of the expression result
	
	; tell the integration layer that we need to draw on the background
	call basic_gui_request_background_change
	
	call common_gui_get_colour_foreground	; CL := colour, CH := 0
	mov bx, word [cs:basicGuiCurrentX]
	mov ax, word [cs:basicGuiCurrentY]
	call common_gui_util_print_single_line_text_with_erase
	
	mov ax, 1						; "success"
	jmp basicExecution_GUIPRINT_done
	
basicExecution_GUIPRINT_error:
	mov ax, 0						; "error"
basicExecution_GUIPRINT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIIMAGESETSHOWHOVERMARK
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIIMAGESETSHOWHOVERMARK:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUIIMAGESETSHOWHOVERMARK_error	; there was an error
	
	; here, BX := first value, CX := second value
	mov ax, bx						; AX := handle
	
	cmp cx, 0
	je basicExecution_GUIIMAGESETSHOWHOVERMARK_hide	; we're hiding it
	; we're showing it
basicExecution_GUIIMAGESETSHOWHOVERMARK_show:
	call common_gui_image_hover_mark_set
	jmp basicExecution_GUIIMAGESETSHOWHOVERMARK_success
basicExecution_GUIIMAGESETSHOWHOVERMARK_hide:
	call common_gui_image_hover_mark_clear
	jmp basicExecution_GUIIMAGESETSHOWHOVERMARK_success
	
basicExecution_GUIIMAGESETSHOWHOVERMARK_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIIMAGESETSHOWHOVERMARK_done
basicExecution_GUIIMAGESETSHOWHOVERMARK_success:
	mov ax, 1							; "success"
basicExecution_GUIIMAGESETSHOWHOVERMARK_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIIMAGEDELETE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIIMAGEDELETE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIIMAGEDELETE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_image_delete
	
	jmp basicExecution_GUIIMAGEDELETE_success
	
basicExecution_GUIIMAGEDELETE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIIMAGEDELETE_done
basicExecution_GUIIMAGEDELETE_success:
	mov ax, 1							; "success"
basicExecution_GUIIMAGEDELETE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIIMAGEENABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIIMAGEENABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIIMAGEENABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_image_enable
	
	jmp basicExecution_GUIIMAGEENABLE_success
	
basicExecution_GUIIMAGEENABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIIMAGEENABLE_done
basicExecution_GUIIMAGEENABLE_success:
	mov ax, 1							; "success"
basicExecution_GUIIMAGEENABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIIMAGEDISABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIIMAGEDISABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIIMAGEDISABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_image_disable
	
	jmp basicExecution_GUIIMAGEDISABLE_success
	
basicExecution_GUIIMAGEDISABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIIMAGEDISABLE_done
basicExecution_GUIIMAGEDISABLE_success:
	mov ax, 1							; "success"
basicExecution_GUIIMAGEDISABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIIMAGESETSHOWSELECTEDMARK
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIIMAGESETSHOWSELECTEDMARK:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUIIMAGESETSHOWSELECTEDMARK_error			; there was an error
	
	; here, BX := first value, CX := second value
	
	mov ax, bx						; AX := handle
	mov bx, cx						; BX := whether image shows selected mark
	call common_gui_image_set_show_selected_mark
	
	jmp basicExecution_GUIIMAGESETSHOWSELECTEDMARK_success

basicExecution_GUIIMAGESETSHOWSELECTEDMARK_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIIMAGESETSHOWSELECTEDMARK_done
basicExecution_GUIIMAGESETSHOWSELECTEDMARK_success:
	mov ax, 1							; "success"
basicExecution_GUIIMAGESETSHOWSELECTEDMARK_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIIMAGESETISSELECTED
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIIMAGESETISSELECTED:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUIIMAGESETISSELECTED_error			; there was an error
	
	; here, BX := first value, CX := second value
	
	mov ax, bx						; AX := handle
	mov bx, cx						; BX := whether image is selected
	call common_gui_image_set_selected
	
	jmp basicExecution_GUIIMAGESETISSELECTED_success
	
basicExecution_GUIIMAGESETISSELECTED_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIIMAGESETISSELECTED_done
basicExecution_GUIIMAGESETISSELECTED_success:
	mov ax, 1							; "success"
basicExecution_GUIIMAGESETISSELECTED_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIIMAGEASCIISETTEXT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIIMAGEASCIISETTEXT:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	call basicExecution_util_int_string	; BX - numeric value left of comma
										; DS:SI - string value right of comma
	cmp ax, 0
	je basicExecution_GUIIMAGEASCIISETTEXT_error	; there was an error

	mov ax, bx										; AX := image handle
	call gui_images_set_ascii_text					; set image text
	
	jmp basicExecution_GUIIMAGEASCIISETTEXT_success

basicExecution_GUIIMAGEASCIISETTEXT_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIIMAGEASCIISETTEXT_done
basicExecution_GUIIMAGEASCIISETTEXT_success:
	mov ax, 1							; "success"
basicExecution_GUIIMAGEASCIISETTEXT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIRADIOSETISSELECTED
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIRADIOSETISSELECTED:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUIRADIOSETISSELECTED_error			; there was an error
	
	; here, BX := first value, CX := second value
	
	mov ax, bx						; AX := handle
	mov bx, cx						; BX := whether is checked
	call common_gui_radio_set_checked
	
	jmp basicExecution_GUIRADIOSETISSELECTED_success

basicExecution_GUIRADIOSETISSELECTED_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIRADIOSETISSELECTED_done
basicExecution_GUIRADIOSETISSELECTED_success:
	mov ax, 1							; "success"
basicExecution_GUIRADIOSETISSELECTED_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIRADIOENABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIRADIOENABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIRADIOENABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_radio_enable
	
	jmp basicExecution_GUIRADIOENABLE_success
	
basicExecution_GUIRADIOENABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIRADIOENABLE_done
basicExecution_GUIRADIOENABLE_success:
	mov ax, 1							; "success"
basicExecution_GUIRADIOENABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIRADIODISABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIRADIODISABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIRADIODISABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_radio_disable
	
	jmp basicExecution_GUIRADIODISABLE_success
	
basicExecution_GUIRADIODISABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIRADIODISABLE_done
basicExecution_GUIRADIODISABLE_success:
	mov ax, 1							; "success"
basicExecution_GUIRADIODISABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIRADIODELETE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIRADIODELETE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIRADIODELETE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_radio_delete
	
	jmp basicExecution_GUIRADIODELETE_success
	
basicExecution_GUIRADIODELETE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIRADIODELETE_done
basicExecution_GUIRADIODELETE_success:
	mov ax, 1							; "success"
basicExecution_GUIRADIODELETE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUISETCURRENTRADIOGROUP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUISETCURRENTRADIOGROUP:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUISETCURRENTRADIOGROUP_error	; there was an error
	mov ax, bx										; AX = group ID
	call basic_gui_set_current_radio_group_id
	
	jmp basicExecution_GUISETCURRENTRADIOGROUP_success
	
basicExecution_GUISETCURRENTRADIOGROUP_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUISETCURRENTRADIOGROUP_done
basicExecution_GUISETCURRENTRADIOGROUP_success:
	mov ax, 1							; "success"
basicExecution_GUISETCURRENTRADIOGROUP_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUICHECKBOXSETISCHECKED
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUICHECKBOXSETISCHECKED:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_GUICHECKBOXSETISCHECKED_error			; there was an error
	
	; here, BX := first value, CX := second value
	
	mov ax, bx						; AX := handle
	mov bx, cx						; BX := whether is checked
	call common_gui_checkbox_set_checked
	
	jmp basicExecution_GUICHECKBOXSETISCHECKED_success

basicExecution_GUICHECKBOXSETISCHECKED_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUICHECKBOXSETISCHECKED_done
basicExecution_GUICHECKBOXSETISCHECKED_success:
	mov ax, 1							; "success"
basicExecution_GUICHECKBOXSETISCHECKED_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUICHECKBOXDELETE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUICHECKBOXDELETE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUICHECKBOXDELETE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_checkbox_delete
	
	jmp basicExecution_GUICHECKBOXDELETE_success
	
basicExecution_GUICHECKBOXDELETE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUICHECKBOXDELETE_done
basicExecution_GUICHECKBOXDELETE_success:
	mov ax, 1							; "success"
basicExecution_GUICHECKBOXDELETE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUICHECKBOXDISABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUICHECKBOXDISABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUICHECKBOXDISABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_checkbox_disable
	
	jmp basicExecution_GUICHECKBOXDISABLE_success
	
basicExecution_GUICHECKBOXDISABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUICHECKBOXDISABLE_done
basicExecution_GUICHECKBOXDISABLE_success:
	mov ax, 1							; "success"
basicExecution_GUICHECKBOXDISABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUICHECKBOXENABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUICHECKBOXENABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUICHECKBOXENABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_checkbox_enable
	
	jmp basicExecution_GUICHECKBOXENABLE_success
	
basicExecution_GUICHECKBOXENABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUICHECKBOXENABLE_done
basicExecution_GUICHECKBOXENABLE_success:
	mov ax, 1							; "success"
basicExecution_GUICHECKBOXENABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIBUTTONENABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIBUTTONENABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIBUTTONENABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_button_enable
	
	jmp basicExecution_GUIBUTTONENABLE_success
	
basicExecution_GUIBUTTONENABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIBUTTONENABLE_done
basicExecution_GUIBUTTONENABLE_success:
	mov ax, 1							; "success"
basicExecution_GUIBUTTONENABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIBUTTONDISABLE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIBUTTONDISABLE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIBUTTONDISABLE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_button_disable
	
	jmp basicExecution_GUIBUTTONDISABLE_success
	
basicExecution_GUIBUTTONDISABLE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIBUTTONDISABLE_done
basicExecution_GUIBUTTONDISABLE_success:
	mov ax, 1							; "success"
basicExecution_GUIBUTTONDISABLE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIBUTTONDELETE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIBUTTONDELETE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_GUIBUTTONDELETE_error		; there was an error
	
	mov ax, bx							; AX := handle
	call common_gui_button_delete
	
	jmp basicExecution_GUIBUTTONDELETE_success
	
basicExecution_GUIBUTTONDELETE_error:
	mov ax, 0							; "error"
	jmp basicExecution_GUIBUTTONDELETE_done
basicExecution_GUIBUTTONDELETE_success:
	mov ax, 1							; "success"
basicExecution_GUIBUTTONDELETE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, GUIBEGIN
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GUIBEGIN:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, 1						; "no error"
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	je basicExecution_GUIBEGIN_done	; NOOP when no tokens
	
	mov dl, 0						; we evaluate from the first token...
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh							; ...to the last
	call basicEval_do				; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je basicExecution_GUIBEGIN_error	; there was an error
	
	cmp byte [cs:basicGuiStartRequested], 0
	jne basicExecution_GUIBEGIN_already_prepared	; GUI framework has already
													; been prepared
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	je basicExecution_GUIBEGIN_not_string	; expression evaluated to a number

	; expression evaluated to a string (in ES:DI)
	push es
	pop ds
	mov si, di						; DS:SI := pointer to result string

	; now output the string representation of the expression result
	; here, DS:SI = pointer to string representation of the expression result
	
	call basic_gui_GUIBEGIN
	cmp ax, 0
	je basicExecution_GUIBEGIN_prepare_failed
	
	; we now behave like YIELD
	mov byte [cs:basicHaltingDueToNonError], 1
	mov byte [cs:basicMustHaltAndYield], 1
	
	jmp basicExecution_GUIBEGIN_success

basicExecution_GUIBEGIN_prepare_failed:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageGuiPrepareFailed
	jmp basicExecution_GUIBEGIN_error
	
basicExecution_GUIBEGIN_already_prepared:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageCannotCallGuiBeginTwice
	jmp basicExecution_GUIBEGIN_error
	
basicExecution_GUIBEGIN_not_string:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_GUIBEGIN_error

basicExecution_GUIBEGIN_success:
	mov ax, 0						; not really an error, since we set
									; "not halting due to error"
	jmp basicExecution_GUIBEGIN_done
basicExecution_GUIBEGIN_error:
	mov ax, 0						; "error"
basicExecution_GUIBEGIN_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, YIELD
;
; input:
;		none
; output:
;		AX - 0 (indicating interpretation must halt)
basicExecution_YIELD:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	jne basicExecution_YIELD_tokens

	mov byte [cs:basicHaltingDueToNonError], 1
	mov byte [cs:basicMustHaltAndYield], 1
	
	jmp basicExecution_YIELD_done

basicExecution_YIELD_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	
basicExecution_YIELD_done:
	mov ax, 0				; we always halt after YIELD
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, SERIALR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_SERIALR:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; check whether serial port driver is available
	cmp byte [cs:basicSerialAvailable], 0
	je basicExecution_SERIALR_driver_not_available
	
	cmp byte [cs:basicCurrentInstTokenCount], 1
	jne basicExecution_SERIALR_tokens
	
	; SERIALR must be followed by a variable
	mov bl, 0								; get first token
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := token
	call basic_is_valid_variable_name
	cmp ax, 0
	je basicExecution_SERIALR_label_must_be_variable
	
	; if it already exists as a numeric variable, the variable must be regular
	; (ie: not a FOR loop counter, etc.)
	call basicNumericVars_get_handle			; AX := variable handle
	jc basicExecution_SERIALR_valid_variable	; variable doesn't even exist
	
	push si										; get_properties outputs to SI
	call basicNumericVars_get_properties		; BL := numeric variable type
	pop si										; restore it
	
	cmp bl, NVAR_TYPE_REGULAR
	jne basicExecution_SERIALR_label_cannot_input_into_counter
basicExecution_SERIALR_valid_variable:
	; the variable is valid
	; here, DS:SI = pointer to variable name
	call basic_delete_variable_by_name			; NOOP when var doesn't exist
	call basicNumericVars_allocate				; BX := variable handle
	jc basicExecution_SERIALR_label_cannot_allocate
	; variable has been successfully allocated

	; now block and read from serial port
	mov ax, bx									; AX := variable handle
	call basic_block_read_serial				; BX := variable value
	jc basicExecution_SERIALR_user_break		; user chose to break
	
	call basicNumericVars_set_value
	
	jmp basicExecution_SERIALR_success
	
basicExecution_SERIALR_user_break:
	mov byte [cs:basicHaltingDueToNonError], 1
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUserBreakRequest
	jmp basicExecution_SERIALR_error
	
basicExecution_SERIALR_driver_not_available:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSerialDriverNotAvailable
	jmp basicExecution_SERIALR_error
	
basicExecution_SERIALR_label_cannot_allocate:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariablesFull
	jmp basicExecution_SERIALR_error
	
basicExecution_SERIALR_label_cannot_input_into_counter:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariableCannotBeCounter
	jmp basicExecution_SERIALR_error
	
basicExecution_SERIALR_label_must_be_variable:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageMustBeAVariable
	jmp basicExecution_SERIALR_error

basicExecution_SERIALR_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_SERIALR_error
	
basicExecution_SERIALR_error:
	mov ax, 0							; "error"
	jmp basicExecution_SERIALR_done
basicExecution_SERIALR_success:
	mov ax, 1							; "success"
basicExecution_SERIALR_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, SERIALW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_SERIALW:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_SERIALW_error		; there was an error

	; we output a byte, so ensure no overflow
	cmp bx, 255
	ja basicExecution_SERIALW_value_out_of_bounds
							; unsigned so negative values are invalid as well
							
	; check whether serial port driver is available
	cmp byte [cs:basicSerialAvailable], 0
	je basicExecution_SERIALW_driver_not_available
	
	; send byte via serial port
	mov al, bl
	int 0AFh					; send character over serial
	
	jmp basicExecution_SERIALW_success

basicExecution_SERIALW_driver_not_available:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSerialDriverNotAvailable
	jmp basicExecution_SERIALW_error
	
basicExecution_SERIALW_value_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSerialValueMustBeByte
	jmp basicExecution_SERIALW_error
	
basicExecution_SERIALW_error:
	mov ax, 0							; "error"
	jmp basicExecution_SERIALW_done
basicExecution_SERIALW_success:
	mov ax, 1							; "success"
basicExecution_SERIALW_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, PARALLELW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_PARALLELW:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_PARALLELW_error			; there was an error
	
	; here, BX = parallel port register number, CX = value to write
	cmp bx, 2
	ja basicExecution_PARALLELW_register_number_out_of_bounds
							; unsigned so negative values are invalid as well
	
	; we output a byte, so ensure no overflow
	cmp cx, 255
	ja basicExecution_PARALLELW_value_out_of_bounds
							; unsigned so negative values are invalid as well
							
	; check whether parallel port driver is available
	cmp byte [cs:basicLptAvailable], 0
	je basicExecution_PARALLELW_driver_not_available
							
	; output byte to parallel port
	mov dx, word [cs:basicLptPortBaseAddress]	; DX := port base address
	add dx, bx								; DX := desired register address
	mov al, cl								; AL := value to write
	out dx, al								; write
	
	jmp basicExecution_PARALLELW_success

basicExecution_PARALLELW_driver_not_available:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageParallelDriverNotAvailable
	jmp basicExecution_PARALLELW_error
	
basicExecution_PARALLELW_register_number_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageParallelRegisterNumberOutOfBounds
	jmp basicExecution_PARALLELW_error
	
basicExecution_PARALLELW_value_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageParallelValueMustBeByte
	jmp basicExecution_PARALLELW_error
	
basicExecution_PARALLELW_error:
	mov ax, 0							; "error"
	jmp basicExecution_PARALLELW_done
basicExecution_PARALLELW_success:
	mov ax, 1							; "success"
basicExecution_PARALLELW_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, CLS
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_CLS:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	jne basicExecution_CLS_tokens
	
	mov dl, [cs:basicTextAttribute]
	call common_clear_screen_to_colour

	jmp basicExecution_CLS_success

basicExecution_CLS_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_CLS_error
	
basicExecution_CLS_error:
	mov ax, 0							; "error"
	jmp basicExecution_CLS_done
basicExecution_CLS_success:
	mov ax, 1							; "success"
basicExecution_CLS_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, BEEPW
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_BEEPW:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_BEEP		; delegate to BEEP
									; SI := duration
	cmp ax, 0
	je basicExecution_BEEPW_error	; there was an error
	
	; we now sleep for however long the sound is supposed to play
	mov cx, si						; CX := sound duration
	int 85h							; delay
	
	jmp basicExecution_BEEPW_success

basicExecution_BEEPW_error:
	mov ax, 0							; "error"
	jmp basicExecution_BEEPW_done
basicExecution_BEEPW_success:
	mov ax, 1							; "success"
basicExecution_BEEPW_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, STOP
;
; input:
;		none
; output:
;		AX - 0 (indicating interpretation must halt)
basicExecution_STOP:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	jne basicExecution_STOP_tokens

	mov byte [cs:basicHaltingDueToNonError], 1
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageStop
	
	jmp basicExecution_STOP_done

basicExecution_STOP_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	
basicExecution_STOP_done:
	mov ax, 0				; we always halt after STOP
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, BEEP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		SI - duration of the sound that was output
basicExecution_BEEP:
	push ds
	push es
	push bx
	push cx
	push dx
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_BEEP_error			; there was an error
	
	; here, BX = frequency value, CX = duration
	cmp bx, 100
	jl basicExecution_BEEP_frequency_number_out_of_bounds
	cmp bx, 30000
	ja basicExecution_BEEP_frequency_number_out_of_bounds
	
	; kernel takes in duration as a byte, so ensure no overflow
	cmp cx, 255
	ja basicExecution_BEEP_duration_out_of_bounds
											; unsigned comparison, so negative
											; values are invalid also
	mov si, cx						; we return duration in SI

	mov ch, 0						; sound mode: normal
	mov dx, 0						; no frequency delta
	mov ax, bx						; AX := frequency number
	; here, CL = duration
	int 0B9h						; play sound
											
	jmp basicExecution_BEEP_success

basicExecution_BEEP_frequency_number_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFrequencyNumberOutOfBounds
	jmp basicExecution_BEEP_error
	
basicExecution_BEEP_duration_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageDurationMustBeByte
	jmp basicExecution_BEEP_error
	
basicExecution_BEEP_error:
	mov ax, 0							; "error"
	jmp basicExecution_BEEP_done
basicExecution_BEEP_success:
	mov ax, 1							; "success"
basicExecution_BEEP_done:
	pop di
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, NOOP
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_NOOP:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	jne basicExecution_NOOP_tokens

	jmp basicExecution_NOOP_success

basicExecution_NOOP_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_NOOP_error
	
basicExecution_NOOP_error:
	mov ax, 0							; "error"
	jmp basicExecution_NOOP_done
basicExecution_NOOP_success:
	mov ax, 1							; "success"
basicExecution_NOOP_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, WAITKEY
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_WAITKEY:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:basicCurrentInstTokenCount], 1
	jne basicExecution_WAITKEY_tokens
	
	; WAITKEY must be followed by a variable
	mov bl, 0								; get first token
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := token
	call basic_is_valid_variable_name
	cmp ax, 0
	je basicExecution_WAITKEY_label_must_be_variable
	
	; if it already exists as a numeric variable, the variable must be regular
	; (ie: not a FOR loop counter, etc.)
	call basicNumericVars_get_handle			; AX := variable handle
	jc basicExecution_WAITKEY_valid_variable		; variable doesn't even exist
	call basicNumericVars_get_properties		; BL := numeric variable type
	cmp bl, NVAR_TYPE_REGULAR
	jne basicExecution_WAITKEY_label_cannot_input_into_counter
basicExecution_WAITKEY_valid_variable:
	; the variable is valid
	; here, DS:SI = pointer to variable name
	call basic_delete_variable_by_name			; NOOP when var doesn't exist
	call basicStringVars_allocate				; BX := variable handle
	jc basicExecution_WAITKEY_label_cannot_allocate
	; variable has been successfully allocated
	
	; now read input from user
	; first, set keyboard driver mode appropriately
	int 0BBh									; AX := previous keyboard
												; driver mode
	push ax
	mov ax, 0									; "use previous mode"
	int 0BCh									; set driver mode
	
	; read from user
	push bx
	mov ah, 0
	int 16h										; AH := scan code, AL := ASCII
	pop bx

	mov word [cs:basicExeWaitKeyScanAndAsciiValue], ax	; save pressed key
	
	mov byte [cs:basicExecutionStringValue0], al	; make a string of the char
	mov byte [cs:basicExecutionStringValue0+1], 0	; terminator
	
	; restore keyboard driver
	pop ax										; AX := previous keyboard
												; driver mode
	int 0BCh									; set driver mode
	
	cmp word [cs:basicExeWaitKeyScanAndAsciiValue], COMMON_SCAN_CODE_AND_ASCII_CTRL_Q
												; did user break?
	jne basicExecution_WAITKEY_not_break		; no
	; user requested break into program
	mov byte [cs:basicHaltingDueToNonError], 1
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUserBreakRequest
	jmp basicExecution_WAITKEY_error
	
basicExecution_WAITKEY_not_break:	
	; now set the variable's value to whatever the user has input
	mov ax, bx									; AX := variable handle
	mov si, basicExecutionStringValue0			; DS:SI := input buffer
	call basicStringVars_set_value
	
	jmp basicExecution_WAITKEY_success
	
basicExecution_WAITKEY_label_cannot_allocate:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariablesFull
	jmp basicExecution_WAITKEY_error
	
basicExecution_WAITKEY_label_cannot_input_into_counter:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariableCannotBeCounter
	jmp basicExecution_WAITKEY_error
	
basicExecution_WAITKEY_label_must_be_variable:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageMustBeAVariable
	jmp basicExecution_WAITKEY_error

basicExecution_WAITKEY_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_WAITKEY_error
	
basicExecution_WAITKEY_error:
	mov ax, 0							; "error"
	jmp basicExecution_WAITKEY_done
basicExecution_WAITKEY_success:
	mov ax, 1							; "success"
basicExecution_WAITKEY_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, PAUSE
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_PAUSE:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_one_numeric_expression	; BX := numeric value
	cmp ax, 0
	je basicExecution_PAUSE_error		; there was an error

	cmp bx, 0							; can't be negative
	jl basicExecution_PAUSE_error_negative
	
	mov cx, bx							; number of ticks
	int 85h								; delay
	
	jmp basicExecution_PAUSE_success

basicExecution_PAUSE_error_negative:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustNotBeNegative
	jmp basicExecution_PAUSE_error
	
basicExecution_PAUSE_error:
	mov ax, 0							; "error"
	jmp basicExecution_PAUSE_done
basicExecution_PAUSE_success:
	mov ax, 1							; "success"
basicExecution_PAUSE_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, COLOURS
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_COLOURS:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_COLOURS_error			; there was an error
	
	; here, BX = font colour, CX = background colour
	; they take only a byte, so BL = font colour, CL = background colour
	cmp bl, COMMON_FONT_COLOUR_WHITE | COMMON_FONT_BRIGHT
	ja basicExecution_COLOURS_font_colour_out_of_bounds
											; unsigned comparison, so negative
											; values are invalid also
	cmp cl, COMMON_BACKGROUND_COLOUR_WHITE >> 4
	ja basicExecution_COLOURS_bckg_colour_out_of_bounds
											; unsigned comparison, so negative
											; values are invalid also
	
	shl cl, 4
	or cl, bl
	mov byte [cs:basicTextAttribute], cl	; store it
	
	jmp basicExecution_COLOURS_success

basicExecution_COLOURS_bckg_colour_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageColoursBackgroundUnknown
	jmp basicExecution_COLOURS_error
	
basicExecution_COLOURS_font_colour_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageColoursFontUnknown
	jmp basicExecution_COLOURS_error
	
basicExecution_COLOURS_error:
	mov ax, 0							; "error"
	jmp basicExecution_COLOURS_done
basicExecution_COLOURS_success:
	mov ax, 1							; "success"
basicExecution_COLOURS_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, AT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_AT:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_util_two_numeric_expressions
									; BX := first value, CX := second value
	cmp ax, 0
	je basicExecution_AT_error				; there was an error

	cmp bx, BASIC_TEXT_SCREEN_ROW_COUNT		; unsigned comparison, so negative
	jae basicExecution_AT_row_out_of_bounds	; values are invalid also
	
	cmp cx, BASIC_TEXT_SCREEN_COLUMN_COUNT	; unsigned comparison, so negative
	jae basicExecution_AT_column_out_of_bounds	; values are invalid also

	; here, BX = row, CX = column
	mov bh, bl								; BH := (byte)BX
	mov bl, cl								; BL := (byte)column
	int 9Eh									; move cursor in current
											; virtual display
	jmp basicExecution_AT_success

basicExecution_AT_column_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageAtColumnOutOfBounds
	jmp basicExecution_AT_error
	
basicExecution_AT_row_out_of_bounds:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageAtRowOutOfBounds
	jmp basicExecution_AT_error
	
basicExecution_AT_error:
	mov ax, 0							; "error"
	jmp basicExecution_AT_done
basicExecution_AT_success:
	mov ax, 1							; "success"
basicExecution_AT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, INPUTN
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_INPUTN:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	call basicExecution_INPUTS			; read string into variable specified
										; as the first instruction token
	cmp ax, 0
	je basicExecution_INPUTN_error		; INPUTS encountered an error, so fail
	
	mov bl, 0							; get first token
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di							; DS:SI := token
	call basicStringVars_get_handle		; AX := variable handle, guaranteed to
										; exist, since INPUTS succeeded

	mov di, basicExecutionStringValue0
	call basicStringVars_get_value		; read variable value into ES:DI
	mov si, di							; DS:SI := variable value
	call common_string_is_numeric		; AX := 0 when not numeric
	cmp ax, 0
	je basicExecution_INPUTN_not_numeric
	call basic_check_numeric_literal_overflow	; AX := 0 when overflow
	cmp ax, 0
	je basicExecution_INPUTN_integer_out_of_range
	
	; string contains an integer that is within range, so we can convert it now
	call common_string_signed_16bit_int_atoi	; AX := the integer
	mov dx, ax							; [1] save it in DX for now
	
	mov bl, 0							; get first token
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di							; DS:SI := variable name
	call basic_delete_variable_by_name
	
	call basicNumericVars_allocate		; BX := handle
	jc basicExecution_INPUTN_no_more_variables
	mov ax, bx							; AX := handle
	mov bx, dx							; [1] BX := value
	call basicNumericVars_set_value
	jmp basicExecution_INPUTN_success

basicExecution_INPUTN_no_more_variables:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariablesFull
	jmp basicExecution_INPUTN_error
	
basicExecution_INPUTN_integer_out_of_range:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIntegerOutOfRange
	jmp basicExecution_INPUTN_error
	
basicExecution_INPUTN_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageInputValueNotNumeric
	jmp basicExecution_INPUTN_error
	
basicExecution_INPUTN_error:
	mov ax, 0							; "error"
	jmp basicExecution_INPUTN_done
basicExecution_INPUTN_success:
	mov ax, 1							; "success"
basicExecution_INPUTN_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, INPUTS
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_INPUTS:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:basicCurrentInstTokenCount], 1
	jne basicExecution_INPUTS_tokens
	
	; INPUTS must be followed by a variable
	mov bl, 0								; get first token
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := token
	call basic_is_valid_variable_name
	cmp ax, 0
	je basicExecution_INPUTS_label_must_be_variable
	
	; if it already exists as a numeric variable, the variable must be regular
	; (ie: not a FOR loop counter, etc.)
	call basicNumericVars_get_handle			; AX := variable handle
	jc basicExecution_INPUTS_valid_variable		; variable doesn't even exist
	
	push si										; get_properties outputs to SI
	call basicNumericVars_get_properties		; BL := numeric variable type
	pop si										; restore it
	
	cmp bl, NVAR_TYPE_REGULAR
	jne basicExecution_INPUTS_label_cannot_input_into_counter
basicExecution_INPUTS_valid_variable:
	; the variable is valid
	; here, DS:SI = pointer to variable name
	call basic_delete_variable_by_name			; NOOP when var doesn't exist
	call basicStringVars_allocate				; BX := variable handle
	jc basicExecution_INPUTS_label_cannot_allocate
	; variable has been successfully allocated

	; now read input from user
	; first, set keyboard driver mode appropriately
	int 0BBh									; AX := previous keyboard
												; driver mode
	push ax
	mov ax, 0									; "use previous mode"
	int 0BCh									; set driver mode
	
	; read from user
	mov di, basicExecutionStringValue0			; ES:DI := pointer to buffer
	mov cx, BASIC_TOKEN_MAX_LENGTH-10			; maximum characters to read
	int 0A4h									; read user input into buffer
	
	; restore keyboard driver
	pop ax										; AX := previous keyboard
												; driver mode
	int 0BCh									; set driver mode
	
	; now set the variable's value to whatever the user has input
	mov ax, bx									; AX := variable handle
	mov si, basicExecutionStringValue0			; DS:SI := input buffer
	call basicStringVars_set_value
	
	jmp basicExecution_INPUTS_success
	
basicExecution_INPUTS_label_cannot_allocate:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariablesFull
	jmp basicExecution_INPUTS_error
	
basicExecution_INPUTS_label_cannot_input_into_counter:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariableCannotBeCounter
	jmp basicExecution_INPUTS_error
	
basicExecution_INPUTS_label_must_be_variable:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageMustBeAVariable
	jmp basicExecution_INPUTS_error

basicExecution_INPUTS_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_INPUTS_error
	
basicExecution_INPUTS_error:
	mov ax, 0							; "error"
	jmp basicExecution_INPUTS_done
basicExecution_INPUTS_success:
	mov ax, 1							; "success"
basicExecution_INPUTS_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, RETURN
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_RETURN:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	jne basicExecution_RETURN_tokens

	; pop return point off stack
	call common_stack_pop							; BX := return point
	cmp ax, 0
	je basicExecution_RETURN_label_stack_underflow

	; set parser resume point to the value we've just popped
	mov word [cs:basicInterpreterParserResumePoint], bx
	jmp basicExecution_RETURN_success

basicExecution_RETURN_label_stack_underflow:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageReturnStackUnderflow
	jmp basicExecution_RETURN_error

basicExecution_RETURN_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_RETURN_error
	
basicExecution_RETURN_error:
	mov ax, 0							; "error"
	jmp basicExecution_RETURN_done
basicExecution_RETURN_success:
	mov ax, 1							; "success"
basicExecution_RETURN_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, CALL
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_CALL:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 1
	jne basicExecution_CALL_tokens
	
	; first token must be a valid label name
	mov bl, 0
	push cs
	pop ds
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov cx, di								; [1] save inst. token pointer
	mov si, di								; DS:SI := pointer to first token

	; append a label delimiter right after token
	int 0A5h								; BX := string length
	mov byte [ds:si+bx], BASIC_CHAR_LABEL_DELIMITER	; replace terminator with
													; label delimiter
	mov byte [ds:si+bx+1], 0				; add new terminator right after
	
	; now validate
	call basic_is_valid_label				; AX := 0 when invalid
	cmp ax, 0
	je basicExecution_CALL_invalid_label
	
	; push return point in the program text
	mov ax, word [cs:basicInterpreterParserResumePoint]
	call common_stack_push
	cmp ax, 0
	je basicExecution_CALL_label_stack_overflow
	
	; get near pointer to right after label token
	push word [cs:basicProgramTextSeg]
	pop ds
	mov si, word [cs:basicProgramTextOff]	; DS:SI := pointer to program text
	mov dx, cs
	
	mov bx, cx								; [1] DX:BX := ptr to label
	call basicExecution_resolve_label		; DI := near pointer to after label
	cmp ax, 0
	je basicExecution_CALL_label_not_found	; label doesn't exist in program

	; set parser resume point to right after label
	mov word [cs:basicInterpreterParserResumePoint], di	; branch to after label
	jmp basicExecution_CALL_success

basicExecution_CALL_label_stack_overflow:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageCallStackOverflow
	jmp basicExecution_CALL_error
	
basicExecution_CALL_label_not_found:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageLabelNotFound
	jmp basicExecution_CALL_error
	
basicExecution_CALL_invalid_label:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageInvalidLabelName
	jmp basicExecution_CALL_error
	
basicExecution_CALL_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_CALL_error
	
basicExecution_CALL_error:
	mov ax, 0							; "error"
	jmp basicExecution_CALL_done
basicExecution_CALL_success:
	mov ax, 1							; "success"
basicExecution_CALL_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, IF
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		DX - FFFFh when no further execution needed, otherwise:
;			DL - first token of current instruction to be executed next
;			DH - last token of current instruction to be executed next
basicExecution_IF:
	push ds
	push es
	push bx
	push cx
	push si
	push di

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov byte [cs:basicIfHasElse], 0			; assume no ELSE
	
	; assert it doesn't contain nested IFs
	mov si, basicKeywordIf
	call basic_lookup_inst_token
	cmp ax, 0
	jne basicExecution_IF_nested_IFs		; it contains nested IFs
	
	; find index of ELSE
	mov al, byte [cs:basicCurrentInstTokenCount]
	mov byte [cs:basicIfElseTokenIndex], al	; [*] initialize indexof(ELSE)
											; to be last+1
											; for easier processing later
	mov si, basicSymbolElse
	call basic_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je basicExecution_IF_searched_for_ELSE	; "ELSE" was not found
	; "ELSE" was found
	mov byte [cs:basicIfHasElse], 1			; mark it as found
	mov byte [cs:basicIfElseTokenIndex], bl	; save it for later
basicExecution_IF_searched_for_ELSE:
	
	; find index of THEN
	mov si, basicSymbolThen
	call basic_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je basicExecution_IF_no_THEN			; "THEN" was not found
	mov byte [cs:basicIfThenTokenIndex], bl	; save it for later
	
	; evaluate expression contained in tokens 0 through indexof(THEN)-1
	mov dh, bl
	dec dh									; rightmost token to consider
	mov dl, 0								; leftmost token to consider
	call basicEval_do
	cmp ax, 0
	je basicExecution_IF_error				; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_IF_error_condition_expression_not_numeric
	cmp cx, 0								; is the expression false (zero)?
	je basicExecution_IF_take_ELSE_branch	; yes, so we take the ELSE branch
	; no, so it's true - we're taking the IF branch
basicExecution_IF_take_THEN_branch:
	; the instruction on the THEN branch is between tokens (inclusive):
	;    a. indexof(THEN)+1 and last (when there's no ELSE)
	;    b. indexof(THEN)+1 and indexof(ELSE)-1 (when ELSE exists)
	;
	; due to [*], indexof(ELSE) was set to be last+1 when there's no ELSE
	mov dh, byte [cs:basicIfElseTokenIndex]
	dec dh									; DH := last OR indexof(ELSE)-1
											; depending on whether ELSE exists
	mov dl, byte [cs:basicIfThenTokenIndex]
	inc dl									; DL := indexof(THEN)+1
	jmp basicExecution_IF_execute_branch	; execute instruction in DL..DH
	
basicExecution_IF_take_ELSE_branch:
	; first, we have to check whether ELSE is specified at all
	mov dx, 0FFFFh							; assume ELSE doesn't exist
	cmp byte [cs:basicIfHasElse], 0
	je basicExecution_IF_success			; NOOP when ELSE doesn't exist
	; ELSE was specified
	; the instruction on the ELSE branch is between tokens (inclusive):
	;     indexof(ELSE)+1 and last
	mov dl, byte [cs:basicIfElseTokenIndex]
	inc dl									; DL := indexof(ELSE)+1
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh									; DH := last
	; execute instruction in DL..DH
basicExecution_IF_execute_branch:
	; here, DL = first token of branch instruction (containing keyword)
	;       DH = last token of branch instruction
	
	jmp basicExecution_IF_success

basicExecution_IF_nested_IFs:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIfNestedIfs
	jmp basicExecution_IF_error
	
basicExecution_IF_no_THEN:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIfThenNotFound
	jmp basicExecution_IF_error
	
basicExecution_IF_error_condition_expression_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageConditionExpressionNotNumeric
	jmp basicExecution_IF_error
	
basicExecution_IF_error:
	mov ax, 0							; "error"
	jmp basicExecution_IF_done
basicExecution_IF_success:
	mov ax, 1							; "success"
basicExecution_IF_done:
	pop di
	pop si
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, FOR
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_FOR:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; assert TO found at index N
	mov si, basicSymbolTo
	call basic_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je basicExecution_FOR_error_no_TO		; "TO" was not found
	mov byte [cs:basicForToTokenIndex], bl	; save it for later
	
	; assert token 0 contains a valid variable name T
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr
							; DI := pointer to instruction token string
	mov si, di				; DS:SI := ES:DI
	call basic_is_valid_variable_name
	cmp ax, 0
	je basicExecution_FOR_error_bad_counter_name
	
	; assert token 1 is "="
	mov bl, 1
	call basicInterpreter_get_instruction_token_near_ptr
							; DI := pointer to instruction token string
	mov si, basicSymbolEquals
	int 0BDh				; compare strings
	cmp ax, 0
	jne basicExecution_FOR_error_no_equals_sign
	
	; find last token of TO expression, which is either between tokens
	;     N+1 and last (when there's no STEP), or
	;     N+1 and indexof(STEP)-1 (when there's STEP)
	mov dl, byte [cs:basicCurrentInstTokenCount]	; DL := last+1
	mov byte [cs:basicForHasStep], 0
	mov byte [cs:basicForStepTokenIndex], -1
	
	mov si, basicSymbolStep
	call basic_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je basicExecution_FOR_STEP				; "STEP" was not found
	mov byte [cs:basicForHasStep], 1
	mov byte [cs:basicForStepTokenIndex], bl		; save STEP index
	mov dl, bl								; DL := indexof(STEP)
basicExecution_FOR_STEP:
	dec dl									; DL := either
											;       last, or
											;       indexof(STEP)-1
	
	; now evaluate expression immediately after TO
	mov dh, dl								; DH := rightmost token to use
	mov dl, byte [cs:basicForToTokenIndex]
	inc dl									; DL := leftmost token to use
	call basicEval_do
	cmp ax, 0
	je basicExecution_FOR_error				; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_FOR_error_TO_not_numeric
	mov word [cs:basicForToValue], cx		; save TO value
	; we have now stored the TO value
	
	; now evaluate initial value
	mov dl, 2								; leftmost token is 2
	mov dh, byte [cs:basicForToTokenIndex]
	dec dh									; rightmost token is indexof(TO)-1
	call basicEval_do
	cmp ax, 0
	je basicExecution_FOR_error				; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_FOR_error_initial_value_not_numeric
	mov word [cs:basicForInitialValue], cx	; save initial value

	; now evaluate STEP value
	; this is done either explicitly, if STEP was specified, or implicitly,
	; if STEP was not specified (implicit value is 1).
	cmp byte [cs:basicForHasStep], 0
	je basicExecution_FOR_STEP_is_implicit	; it's implicit
	; it's explicit, so we evaluate the expression right after STEP
	mov dl, byte [cs:basicForStepTokenIndex]
	inc dl									; leftmost token of STEP expression
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh									; rightmost token of STEP expr.

	call basicEval_do						; evaluate
	cmp ax, 0
	je basicExecution_FOR_error				; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_FOR_error_STEP_not_numeric
	mov word [cs:basicForStepValue], cx		; save STEP value
	jmp basicExecution_FOR_got_STEP_value
basicExecution_FOR_STEP_is_implicit:
	mov word [cs:basicForStepValue], 1		; STEP := 1
basicExecution_FOR_got_STEP_value:
	; we have now calculated this FOR loop's STEP value
	
	; now allocate a variable for the FOR counter
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr
							; DI := pointer to instruction token string
	mov si, di				; DS:SI := pointer to counter name
	; first delete existing ...
	call basic_delete_variable_by_name		; we can forcefully delete all
											; variables with this name
	; ... then allocate it
	call basicNumericVars_allocate			; BX := variable handle
	jc basicExecution_FOR_error_TO_cannot_allocate_counter
	mov word [cs:basicForCounterHandle], bx	; save it

	; now set the counter variable's properties
	mov ax, word [cs:basicForCounterHandle]	; variable handle
	call basicNumericVars_set_type_for_loop_counter	; mark it as a counter
	mov cx, word [cs:basicForToValue]		; TO value
	mov dx, word [cs:basicForStepValue]		; STEP value
	mov si, word [cs:basicInterpreterParserResumePoint]
											; SI := near pointer to instruction
											;       immediately after this FOR
	call basicNumericVars_set_for_loop_params
	mov bx, word [cs:basicForInitialValue]	; value
	call basicNumericVars_set_value

	; we must now decide whether no iterations will actually run, in which
	; case the interpreter must be told to skip execution of all subsequent
	; instructions, until NEXT T is found (where T is the counter var. name)
	; here, AX = counter variable handle
	call basic_check_for_counter_within_bounds	; BX := 0 when outside bounds
	cmp bx, 0
	jne basicExecution_FOR_success			; it's within bounds, so we're
											; iterating at least once
	; it's already out of bounds, so put interpreter in "FOR skip mode"
	call basicInterpreter_enable_FOR_skip_mode	; skip all instructions until
												; this loop's NEXT
	jmp basicExecution_FOR_success

basicExecution_FOR_error_TO_cannot_allocate_counter:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageCannotAllocateCounterVariable
	jmp basicExecution_FOR_error
	
basicExecution_FOR_error_STEP_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageForStepNotNumeric
	jmp basicExecution_FOR_error
	
basicExecution_FOR_error_initial_value_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageForInitialNotNumeric
	jmp basicExecution_FOR_error
	
basicExecution_FOR_error_TO_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageForToNotNumeric
	jmp basicExecution_FOR_error
	
basicExecution_FOR_error_no_equals_sign:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageMissingEqualsSign
	jmp basicExecution_FOR_error
	
basicExecution_FOR_error_bad_counter_name:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageCounterNotValidVariable
	jmp basicExecution_FOR_error
	
basicExecution_FOR_error_no_TO:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageMissingTo
	jmp basicExecution_FOR_error
	
basicExecution_FOR_error:
	mov ax, 0							; "error"
	jmp basicExecution_FOR_done
basicExecution_FOR_success:
	mov ax, 1							; "success"
basicExecution_FOR_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret

	
; Executes the current instruction, NEXT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_NEXT:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:basicCurrentInstTokenCount], 1
	jne basicExecution_NEXT_error_tokens
	
	; token 0 must contain a valid variable name
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr
							; DI := pointer to instruction token string
	mov si, di				; DS:SI := ES:DI
	call basic_is_valid_variable_name
	cmp ax, 0
	je basicExecution_NEXT_error_tokens

	; get variable handle
	call basicNumericVars_get_handle		; AX := counter variable handle
	jc basicExecution_NEXT_error_tokens
	
	; variable must be of type "FOR counter"
	call basicNumericVars_get_properties
	cmp bl, NVAR_TYPE_FOR_LOOP_COUNTER
	jne basicExecution_NEXT_error_tokens	; it's not of type "counter"
	
	cmp byte [cs:basicInterpreterIsInForSkipMode], 0
	je basicExecution_NEXT_begin			; not in skip mode, so we start
	
	; we're in skip mode
	; check whether my counter variable is the one for which we're skipping
	; here, AX = my counter variable handle
	cmp ax, word [cs:basicInterpreterForSkipModeCounterHandle]
	jne basicExecution_NEXT_success			; it's not, so we are NOOP
	
	; we're in skip mode and my counter variable is the 
	; one for which we're skipping
	call basicInterpreter_disable_FOR_skip_mode
	; we proceed normally from now on, to perform counter variable cleanup
basicExecution_NEXT_begin:
	; perform the main NEXT functionality

	; check if we're within bounds before incrementing the counter value
	; here, AX = my counter variable handle
	call basic_check_for_counter_within_bounds	; BX := 0 when outside bounds
	cmp bx, 0
	jne basicExecution_NEXT_within_bounds_before_step
	; is already outside of bounds, so we're finishing this FOR loop
	jmp basicExecution_NEXT_no_more_iterations
basicExecution_NEXT_within_bounds_before_step:
	; it was within bounds before step was applied
	; apply step
	call basicNumericVars_get_properties	; DX := step value
	call basicNumericVars_get_value			; BX := current value
	cmp dx, 0
	jl basicExecution_NEXT_step_negative	; step is negative
	; step is positive
	add bx, dx								; current := current + step
	jo basicExecution_NEXT_no_more_iterations	; check overflow
	jmp basicExecution_NEXT_store_new_current_value
basicExecution_NEXT_step_negative:
	neg dx									; step := |step|
	sub bx, dx								; current := current - |step|
	jo basicExecution_NEXT_no_more_iterations	; check overflow
	
basicExecution_NEXT_store_new_current_value:
	call basicNumericVars_set_value			; set new counter value
	
	; has it gone out of bounds now, after step was applied?
	call basic_check_for_counter_within_bounds	; BX := 0 when outside bounds
	cmp bx, 0
	jne basicExecution_NEXT_within_bounds_after_step
	; it's just gone out of bounds
basicExecution_NEXT_no_more_iterations:
	; we are finishing this FOR loop now
	call basicNumericVars_delete				; delete counter variable
	jmp basicExecution_NEXT_success				; we're done
basicExecution_NEXT_within_bounds_after_step:
	; jump back to immediately after the FOR instruction to iterate again
	call basicNumericVars_get_properties	; SI - near pointer into the
											; program text immediately after
											; the FOR instruction of
											; this counter variable
	mov word [cs:basicInterpreterParserResumePoint], si	; branch back to FOR
	jmp basicExecution_NEXT_success
	
basicExecution_NEXT_error_out_of_range:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageIntegerOutOfRange
	jmp basicExecution_FOR_error
	
basicExecution_NEXT_error_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageNextNeedsCounterVariable
	jmp basicExecution_FOR_error
	
basicExecution_NEXT_error:
	mov ax, 0							; "error"
	jmp basicExecution_NEXT_done
basicExecution_NEXT_success:
	mov ax, 1							; "success"
basicExecution_NEXT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret
	

; Executes the current instruction, REM
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_REM:
	push ds
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 1
	jne basicExecution_REM_tokens
	
	; first token must be a quoted string literal
	mov bl, 0
	push cs
	pop ds
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := pointer to first token
	call basic_is_valid_quoted_string_literal	; AX := 0 when not a QSL
	cmp ax, 0
	je basicExecution_REM_invalid_qsl
	jmp basicExecution_REM_success

basicExecution_REM_invalid_qsl:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageTokenMustBeQSL
	jmp basicExecution_REM_error
	
basicExecution_REM_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_REM_error
	
basicExecution_REM_error:
	mov ax, 0							; "error"
	jmp basicExecution_REM_done
basicExecution_REM_success:
	mov ax, 1							; "success"
basicExecution_REM_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ds
	ret


; Executes the current instruction, GOTO
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_GOTO:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	cmp byte [cs:basicCurrentInstTokenCount], 1
	jne basicExecution_GOTO_tokens
	
	; first token must be a valid label name
	mov bl, 0
	push cs
	pop ds
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov cx, di								; [1] save inst. token pointer
	mov si, di								; DS:SI := pointer to first token

	; append a label delimiter right after token
	int 0A5h								; BX := string length
	mov byte [ds:si+bx], BASIC_CHAR_LABEL_DELIMITER	; replace terminator with
													; label delimiter
	mov byte [ds:si+bx+1], 0				; add new terminator right after
	
	; now validate
	call basic_is_valid_label				; AX := 0 when invalid
	cmp ax, 0
	je basicExecution_GOTO_invalid_label
	
	; get near pointer to right after label token
	push word [cs:basicProgramTextSeg]
	pop ds
	mov si, word [cs:basicProgramTextOff]	; DS:SI := pointer to program text
	mov dx, cs
	
	mov bx, cx								; [1] DX:BX := ptr to label
	call basicExecution_resolve_label		; DI := near pointer to after label
	cmp ax, 0
	je basicExecution_GOTO_label_not_found	; label doesn't exist in program
	
	; set parser resume point to right after label
	mov word [cs:basicInterpreterParserResumePoint], di	; branch to after label
	jmp basicExecution_GOTO_success

basicExecution_GOTO_label_not_found:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageLabelNotFound
	jmp basicExecution_GOTO_error
	
basicExecution_GOTO_invalid_label:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageInvalidLabelName
	jmp basicExecution_GOTO_error
	
basicExecution_GOTO_tokens:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_GOTO_error
	
basicExecution_GOTO_error:
	mov ax, 0							; "error"
	jmp basicExecution_GOTO_done
basicExecution_GOTO_success:
	mov ax, 1							; "success"
basicExecution_GOTO_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret


; Executes the current instruction, LET
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_LET:
	push ds
	push es
	push si
	push di
	push bx
	push cx
	push dx
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	cmp byte [cs:basicCurrentInstTokenCount], 3
	jb basicExecution_LET_bad_number_of_arguments	; too few arguments
	
	; first token must be a valid variable name
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di								; DS:SI := pointer to first token
	call basic_is_valid_variable_name		; AX := 0 when invalid
	cmp ax, 0
	je basicExecution_LET_invalid_assigned_variable
	
	; second token must be the = symbol
	mov bl, 1
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, basicSymbolEquals
	int 0BDh						; compare strings
	cmp ax, 0
	jne basicExecution_LET_no_equals
	
	; evaluate expression contained in tokens third to last
	mov dl, 2						; we evaluate from the third token...
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh							; ...to the last
	call basicEval_do				; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string

	cmp ax, 0
	je basicExecution_LET_error		; there was an error
	; save expression result values
	mov word [cs:basicExecutionExpressionType], bx
	mov word [cs:basicExecutionNumericValue], cx

	cmp word [cs:basicExecutionExpressionType], BASIC_EVAL_TYPE_STRING
											; did evaluation return a string?
	jne basicExecution_LET_after_result_string_copied	; no
	; yes, so copy result string into temporary buffer
	push es
	pop ds
	mov si, di						; DS:SI := pointer to result string

	push cs
	pop es
	mov di, basicExecutionStringValue0	; ES:DI := temp. result string buffer
	call common_string_copy
	
basicExecution_LET_after_result_string_copied:
	; here, we know that the variable name is valid
	; delete variable if it already exists, checking both 
	; numeric and string variables
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	push cs
	pop ds
	mov si, di							; DS:SI := pointer to first token
basicExecution_LET_check_string_vars:
	; check string variables
	call basicStringVars_get_handle		; AX := handle, CARRY set=not found
	jc basicExecution_LET_check_string_vars_not_found	; not found

	; a string variable with this name was found
	cmp word [cs:basicExecutionExpressionType], BASIC_EVAL_TYPE_STRING
	jne basicExecution_LET_check_string_vars_delete	; we're setting numeric
basicExecution_LET_check_string_vars_set_value:
	; variable exists (string) and we're setting a string value
	push cs
	pop ds
	mov si, basicExecutionStringValue0
	; here, AX = variable handle, from above
	call basicStringVars_set_value			; set new value
	jmp basicExecution_LET_success
basicExecution_LET_check_string_vars_delete:
	; variable exists (string) and we're setting a numeric value
	call basicStringVars_delete
	jmp basicExecution_LET_check_numeric_vars
basicExecution_LET_check_string_vars_not_found:
	; variable doesn't exist
	cmp word [cs:basicExecutionExpressionType], BASIC_EVAL_TYPE_STRING
	jne basicExecution_LET_check_numeric_vars	; we're not setting a string
												; value anyway
	; variable doesn't exist and we're setting a string value
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di							; DS:SI := pointer to first token
	call basicStringVars_allocate		; BX := handle, CARRY=all full
	jc basicExecution_LET_no_more_vars
	mov ax, bx							; AX := handle
	push cs
	pop ds
	mov si, basicExecutionStringValue0	; DS:SI := result string
	call basicStringVars_set_value		; set its value
	jmp basicExecution_LET_check_numeric_vars
	
basicExecution_LET_check_numeric_vars:
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di							; DS:SI := pointer to first token
	
	; check numeric variables
	call basicNumericVars_get_handle		; AX := handle, CARRY set=not found
	jc basicExecution_LET_check_numeric_vars_not_found	; not found
	; a numeric variable with this name was found
	cmp word [cs:basicExecutionExpressionType], BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_LET_check_numeric_vars_delete	; we're setting string
basicExecution_LET_check_numeric_vars_set_value:
	; variable exists (numeric) and we're setting a numeric value
	; here, AX = variable handle, from above
	call basicNumericVars_get_properties	; BL := type
	cmp bl, NVAR_TYPE_FOR_LOOP_COUNTER
	je basicExecution_LET_cannot_assign_counter	; it's a counter; we can't set
	; set its value
	mov word bx, [cs:basicExecutionNumericValue]
	call basicNumericVars_set_value			; set new value
	jmp basicExecution_LET_success
basicExecution_LET_check_numeric_vars_delete:
	; variable exists (numeric) and we're setting a string value
	call basicNumericVars_get_properties	; BL := type
	cmp bl, NVAR_TYPE_FOR_LOOP_COUNTER
	je basicExecution_LET_cannot_assign_counter	; it's a counter; can't delete
	; delete it
	call basicNumericVars_delete
	jmp basicExecution_LET_check_numeric_vars
basicExecution_LET_check_numeric_vars_not_found:
	; variable doesn't exist
	cmp word [cs:basicExecutionExpressionType], BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_LET_success	; we're not setting a numeric value anyway	

	; variable doesn't exist and we're setting a numeric value
	mov bl, 0
	call basicInterpreter_get_instruction_token_near_ptr ; DI := near pointer
	mov si, di							; DS:SI := pointer to first token

	call basicNumericVars_allocate		; BX := handle, CARRY=all full	
	jc basicExecution_LET_no_more_vars
	mov ax, bx							; AX := handle
	mov word bx, [cs:basicExecutionNumericValue]
	call basicNumericVars_set_value			; set new value
	jmp basicExecution_LET_success
	
basicExecution_LET_cannot_assign_counter:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageMissingCannotAssignCounter
	jmp basicExecution_LET_error
	
basicExecution_LET_no_equals:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageMissingEqualsSign
	jmp basicExecution_LET_error
	
basicExecution_LET_invalid_assigned_variable:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageInvalidAssignedVariableName
	jmp basicExecution_LET_error
	
basicExecution_LET_bad_number_of_arguments:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_LET_error
	
basicExecution_LET_no_more_vars:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageVariablesFull
	jmp basicExecution_LET_error
	
basicExecution_LET_error:
	mov ax, 0							; "error"
	jmp basicExecution_LET_done
basicExecution_LET_success:
	mov ax, 1							; "success"
basicExecution_LET_done:
	pop dx
	pop cx
	pop bx
	pop di
	pop si
	pop es
	pop ds
	ret
	

; Executes the current instruction, PRINT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_PRINTLN:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	call basicExecution_PRINT
	mov si, basicNewline
	int 97h							; print newline
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret
	

; Executes the current instruction, PRINT
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
basicExecution_PRINT:
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di
	
	mov ax, 1						; "no error"
	
	cmp byte [cs:basicCurrentInstTokenCount], 0
	je basicExecution_PRINT_done	; NOOP when no tokens
	
	mov dl, 0						; we evaluate from the first token...
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh							; ...to the last
	call basicEval_do				; AX := 0 when there was an error
									; BX := 0 when string, 1 when number
									; CX := numeric result
									; ES:DI := pointer to result string
	cmp ax, 0
	je basicExecution_PRINT_error	; there was an error
								
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	je basicExecution_PRINT_number	; expression evaluated to a number
basicExecution_PRINT_string:
	; expression evaluated to a string (in ES:DI)
	push es
	pop ds
	mov si, di						; DS:SI := pointer to result string
	jmp basicExecution_PRINT_output
basicExecution_PRINT_number:
	; the expression evaluated to a number
	push cs
	pop ds
	mov si, basicItoaBuffer			; DS:SI := pointer to itoa result
	mov ax, cx						; AX := numeric result
	call common_string_signed_16bit_int_itoa
	jmp basicExecution_PRINT_output
basicExecution_PRINT_output:
	; now output the string representation of the expression result
	; here, DS:SI = pointer to string representation of the expression result
	
	; first, write attribute byte
	mov dl, byte [cs:basicTextAttribute]
	int 0A5h						; BX := string length
	mov cx, bx
	int 9Fh							; write attribute bytes
	
	int 97h							; print string
	mov ax, 1						; "success"
	jmp basicExecution_PRINT_done
	
basicExecution_PRINT_error:
	mov ax, 0						; "error"
basicExecution_PRINT_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	ret

	
; Executes the current instruction
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		DX - FFFFh when no further execution needed, otherwise:
;			DL - first token of current instruction to be executed next
;			DH - last token of current instruction to be executed next
basicExecution_entry_point:
	push bx
	push cx
	push si
	push di
	push ds
	push es

	mov dx, 0FFFFh				; start off with "no further execution"
								; and let specific instruction routines
								; change it
	push cs
	pop ds
	mov si, basicCurrentKeyword	
	
	; delegate based on keyword

basicExecution_entry_point_GUICLEARALL:
	mov di, basicKeywordGuiClearAll
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIRECTANGLEERASETO
	call basicExecution_GUICLEARALL
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIRECTANGLEERASETO:
	mov di, basicKeywordGuiRectangleEraseTo
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIATDELTA
	call basicExecution_GUIRECTANGLEERASETO
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIATDELTA:
	mov di, basicKeywordGuiAtDelta
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIAT
	call basicExecution_GUIATDELTA
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIAT:
	mov di, basicKeywordGuiAt
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIPRINT
	call basicExecution_GUIAT
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIPRINT:
	mov di, basicKeywordGuiPrint
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIIMAGESETSHOWHOVERMARK
	call basicExecution_GUIPRINT
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIIMAGESETSHOWHOVERMARK:
	mov di, basicKeywordGuiImageSetShowHoverMark
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIIMAGEDELETE
	call basicExecution_GUIIMAGESETSHOWHOVERMARK
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIIMAGEDELETE:
	mov di, basicKeywordGuiImageDelete
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIIMAGEDISABLE
	call basicExecution_GUIIMAGEDELETE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIIMAGEDISABLE:
	mov di, basicKeywordGuiImageDisable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIIMAGEENABLE
	call basicExecution_GUIIMAGEDISABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIIMAGEENABLE:
	mov di, basicKeywordGuiImageEnable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIIMAGESETSHOWSELECTEDMARK
	call basicExecution_GUIIMAGEENABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIIMAGESETSHOWSELECTEDMARK:
	mov di, basicKeywordGuiImageSetShowSelectedMark
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIIMAGESETISSELECTED
	call basicExecution_GUIIMAGESETSHOWSELECTEDMARK
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIIMAGESETISSELECTED:
	mov di, basicKeywordGuiImageSetIsSelected
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIIMAGEASCIISETTEXT
	call basicExecution_GUIIMAGESETISSELECTED
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIIMAGEASCIISETTEXT:
	mov di, basicKeywordGuiImageAsciiSetText
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIRADIOSETISSELECTED
	call basicExecution_GUIIMAGEASCIISETTEXT
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIRADIOSETISSELECTED:
	mov di, basicKeywordGuiRadioSetIsSelected
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIRADIOENABLE
	call basicExecution_GUIRADIOSETISSELECTED
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIRADIOENABLE:
	mov di, basicKeywordGuiRadioEnable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIRADIODISABLE
	call basicExecution_GUIRADIOENABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIRADIODISABLE:
	mov di, basicKeywordGuiRadioDisable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIRADIODELETE
	call basicExecution_GUIRADIODISABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIRADIODELETE:
	mov di, basicKeywordGuiRadioDelete
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUISETCURRENTRADIOGROUP
	call basicExecution_GUIRADIODELETE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUISETCURRENTRADIOGROUP:
	mov di, basicKeywordGuiCurrentSetRadioGroup
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUICHECKBOXSETISCHECKED
	call basicExecution_GUISETCURRENTRADIOGROUP
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUICHECKBOXSETISCHECKED:
	mov di, basicKeywordGuiCheckboxSetIsChecked
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUICHECKBOXDELETE
	call basicExecution_GUICHECKBOXSETISCHECKED
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUICHECKBOXDELETE:
	mov di, basicKeywordGuiCheckboxDelete
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUICHECKBOXDISABLE
	call basicExecution_GUICHECKBOXDELETE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUICHECKBOXDISABLE:
	mov di, basicKeywordGuiCheckboxDisable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUICHECKBOXENABLE
	call basicExecution_GUICHECKBOXDISABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUICHECKBOXENABLE:
	mov di, basicKeywordGuiCheckboxEnable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIBUTTONENABLE
	call basicExecution_GUICHECKBOXENABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIBUTTONENABLE:
	mov di, basicKeywordGuiButtonEnable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIBUTTONDISABLE
	call basicExecution_GUIBUTTONENABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIBUTTONDISABLE:
	mov di, basicKeywordGuiButtonDisable
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIBUTTONDELETE
	call basicExecution_GUIBUTTONDISABLE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIBUTTONDELETE:
	mov di, basicKeywordGuiButtonDelete
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GUIBEGIN
	call basicExecution_GUIBUTTONDELETE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GUIBEGIN:
	mov di, basicKeywordGuiBegin
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_YIELD
	call basicExecution_GUIBEGIN
	jmp basicExecution_entry_point_done
basicExecution_entry_point_YIELD:
	mov di, basicKeywordYield
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_SERIALR
	call basicExecution_YIELD
	jmp basicExecution_entry_point_done
basicExecution_entry_point_SERIALR:
	mov di, basicKeywordSerialR
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_SERIALW
	call basicExecution_SERIALR
	jmp basicExecution_entry_point_done
basicExecution_entry_point_SERIALW:
	mov di, basicKeywordSerialW
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_PARALLELW
	call basicExecution_SERIALW
	jmp basicExecution_entry_point_done
basicExecution_entry_point_PARALLELW:
	mov di, basicKeywordParallelW
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_CLS
	call basicExecution_PARALLELW
	jmp basicExecution_entry_point_done
basicExecution_entry_point_CLS:
	mov di, basicKeywordCls
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_BEEPW
	call basicExecution_CLS
	jmp basicExecution_entry_point_done
basicExecution_entry_point_BEEPW:
	mov di, basicKeywordBeepW
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_STOP
	call basicExecution_BEEPW
	jmp basicExecution_entry_point_done
basicExecution_entry_point_STOP:
	mov di, basicKeywordStop
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_BEEP
	call basicExecution_STOP
	jmp basicExecution_entry_point_done
basicExecution_entry_point_BEEP:
	mov di, basicKeywordBeep
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_NOOP
	call basicExecution_BEEP
	jmp basicExecution_entry_point_done
basicExecution_entry_point_NOOP:
	mov di, basicKeywordNoop
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_WAITKEY
	call basicExecution_NOOP
	jmp basicExecution_entry_point_done
basicExecution_entry_point_WAITKEY:
	mov di, basicKeywordWaitKey
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_PAUSE
	call basicExecution_WAITKEY
	jmp basicExecution_entry_point_done
basicExecution_entry_point_PAUSE:
	mov di, basicKeywordPause
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_COLOURS
	call basicExecution_PAUSE
	jmp basicExecution_entry_point_done
basicExecution_entry_point_COLOURS:
	mov di, basicKeywordColours
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_AT
	call basicExecution_COLOURS
	jmp basicExecution_entry_point_done
basicExecution_entry_point_AT:
	mov di, basicKeywordAt
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_INPUTN
	call basicExecution_AT
	jmp basicExecution_entry_point_done
basicExecution_entry_point_INPUTN:
	mov di, basicKeywordInputN
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_INPUTS
	call basicExecution_INPUTN
	jmp basicExecution_entry_point_done
basicExecution_entry_point_INPUTS:
	mov di, basicKeywordInputS
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_RETURN
	call basicExecution_INPUTS
	jmp basicExecution_entry_point_done
basicExecution_entry_point_RETURN:
	mov di, basicKeywordReturn
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_CALL
	call basicExecution_RETURN
	jmp basicExecution_entry_point_done
basicExecution_entry_point_CALL:
	mov di, basicKeywordCall
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_IF
	call basicExecution_CALL
	jmp basicExecution_entry_point_done
basicExecution_entry_point_IF:
	mov di, basicKeywordIf
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_NEXT
	call basicExecution_IF
	jmp basicExecution_entry_point_done
basicExecution_entry_point_NEXT:
	mov di, basicKeywordNext
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_FOR
	call basicExecution_NEXT
	jmp basicExecution_entry_point_done
basicExecution_entry_point_FOR:
	mov di, basicKeywordFor
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_REM
	call basicExecution_FOR
	jmp basicExecution_entry_point_done
basicExecution_entry_point_REM:
	mov di, basicKeywordRem
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_GOTO
	call basicExecution_REM
	jmp basicExecution_entry_point_done
basicExecution_entry_point_GOTO:
	mov di, basicKeywordGoto
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_LET
	call basicExecution_GOTO
	jmp basicExecution_entry_point_done
basicExecution_entry_point_LET:
	mov di, basicKeywordLet
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_PRINTLN
	call basicExecution_LET
	jmp basicExecution_entry_point_done
basicExecution_entry_point_PRINTLN:
	mov di, basicKeywordPrintln
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_PRINT
	call basicExecution_PRINTLN
	jmp basicExecution_entry_point_done
basicExecution_entry_point_PRINT:
	mov di, basicKeywordPrint
	int 0BDh
	cmp ax, 0
	jne basicExecution_entry_point_UNKNOWN
	call basicExecution_PRINT
	jmp basicExecution_entry_point_done
basicExecution_entry_point_UNKNOWN:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageCantExecuteUnknownKeyword
	mov ax, 0									; "error"
	jmp basicExecution_entry_point_done
	
basicExecution_entry_point_done:
	pop es
	pop ds
	pop di
	pop si
	pop cx
	pop bx
	ret

	
; Returns a near pointer to right after the first occurrence of the
; specified label, in the specified program text string
; NOTE: uses the branch cache to try to avoid an expensive lookup
;
; input:
;	 DS:SI - pointer to program text string, zero-terminated
;	 DX:BX - pointer to label name, zero-terminated
; output:
;		AX - 0 when label was not found, other value otherwise
;		DI - near pointer to right after the first occurrence of label
basicExecution_resolve_label:
	pushf
	push ds
	push es
	push si
	push bx
	push cx
	push dx
	
	; compare label name to cached label name
	push ds									; [1]
	push si
	push dx
	push bx
	
	push cs
	pop ds
	mov si, basicBranchCacheLabel			; DS:SI := cached label
	mov es, dx
	mov di, bx								; ES:DI := label name
	int 0BDh								; AX := 0 when strings are equal
	
	pop bx									; [1]
	pop dx
	pop si
	pop ds
	
	cmp ax, 0								; does cache contain this label?
	jne basicExecution_resolve_label_search	; no
	; cache contains this label, so return its near pointer
	mov di, word [cs:basicBranchCacheNearPtr]	; return near pointer in DI
	jmp basicExecution_resolve_label_success
	
basicExecution_resolve_label_search:
	; cache didn't contain this token, so search for it
	call basic_get_near_pointer_after_token	; AX := 0 when label was not found
											; contract similar to this routine
	cmp ax, 0
	je basicExecution_resolve_label_error	; not found, so we're done
	; we found it, so we add it to the cache
	mov word [cs:basicBranchCacheNearPtr], di	; cache the near pointer
	
	push di									; save near pointer
	
	push cs
	pop es
	mov di, basicBranchCacheLabel			; ES:DI := pointer to cache
	mov ds, dx
	mov si, bx								; DS:SI := pointer to label name
	call common_string_copy					; cache the label name
	
	pop di									; restore near pointer
	jmp basicExecution_resolve_label_success
basicExecution_resolve_label_error:
	mov ax, 0								; "error"
	jmp basicExecution_resolve_label_done
basicExecution_resolve_label_success:
	mov ax, 1								; "success"
basicExecution_resolve_label_done:
	pop dx
	pop cx
	pop bx
	pop si
	pop es
	pop ds
	popf
	ret


; Utility for: <keyword> <numeric_expression>
;
; Asserts current instruction has a numeric expression and returns
; the numeric values contained within the expressions.
; Populates error message accordingly if an assertion fails.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - numeric value
basicExecution_util_one_numeric_expression:
	push ds
	push es
	push cx
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:basicCurrentInstTokenCount], 1	; at least one tokens
	jb basicExecution_util_one_numeric_expression_tokens_count_error

	; evaluate expression
	mov dl, 0								; leftmost token to consider
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh									; rightmost token to consider
	call basicEval_do
	cmp ax, 0
	je basicExecution_util_one_numeric_expression_error
											; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_util_one_numeric_expression_not_numeric
	mov bx, cx								; return value
	
	jmp basicExecution_util_one_numeric_expression_success

basicExecution_util_one_numeric_expression_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBeNumeric
	jmp basicExecution_util_one_numeric_expression_error

basicExecution_util_one_numeric_expression_tokens_count_error:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_util_one_numeric_expression_error
	
basicExecution_util_one_numeric_expression_error:
	mov ax, 0							; "error"
	jmp basicExecution_util_one_numeric_expression_done
basicExecution_util_one_numeric_expression_success:
	mov ax, 1							; "success"
basicExecution_util_one_numeric_expression_done:
	pop di
	pop si
	pop dx
	pop cx
	pop es
	pop ds
	ret
	
	
; Utility for: <keyword> <numeric_expression> , <numeric_expression>
;
; Asserts current instruction has two numeric expressions separated
; by a comma and returns the numeric values contained within the expressions.
; Populates error message accordingly if an assertion fails.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - numeric value left of comma
;		CX - numeric value right of comma
basicExecution_util_two_numeric_expressions:
	push ds
	push es
	push dx
	push si
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:basicCurrentInstTokenCount], 3	; at least three tokens
	jb basicExecution_util_two_numeric_expressions_tokens_count_error
	
	; find token containing comma
	mov si, basicArgumentDelimiterToken
	call basic_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je basicExecution_util_two_numeric_expressions_no_comma		; not found
	mov byte [cs:basicExeTwoNumericExpressionsCommaTokenIndex], bl
	
	; evaluate expression (left of comma)
	mov dl, 0								; leftmost token to consider
	mov dh, bl
	dec dh									; rightmost token to consider
	call basicEval_do
	cmp ax, 0
	je basicExecution_util_two_numeric_expressions_error
											; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_util_two_numeric_expressions_not_numeric
	mov word [cs:basicExeTwoNumericExpressionsFirstValue], cx	; save value
	
	; evaluate expression (right of comma)
	mov dl, byte [cs:basicExeTwoNumericExpressionsCommaTokenIndex]
	inc dl									; leftmost token to consider
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh									; rightmost token to consider
	call basicEval_do
	cmp ax, 0
	je basicExecution_util_two_numeric_expressions_error
											; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_util_two_numeric_expressions_not_numeric
	
	; here, CX = numeric value of second expression
	mov bx, word [cs:basicExeTwoNumericExpressionsFirstValue]
							; BX := numeric value of first expression
	jmp basicExecution_util_two_numeric_expressions_success

basicExecution_util_two_numeric_expressions_no_comma:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageNoComma
	jmp basicExecution_util_two_numeric_expressions_error
	
basicExecution_util_two_numeric_expressions_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageArgumentMustBeNumeric
	jmp basicExecution_util_two_numeric_expressions_error

basicExecution_util_two_numeric_expressions_tokens_count_error:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_util_two_numeric_expressions_error
	
basicExecution_util_two_numeric_expressions_error:
	mov ax, 0							; "error"
	jmp basicExecution_util_two_numeric_expressions_done
basicExecution_util_two_numeric_expressions_success:
	mov ax, 1							; "success"
basicExecution_util_two_numeric_expressions_done:
	pop di
	pop si
	pop dx
	pop es
	pop ds
	ret

	
; Utility for: <keyword> <numeric_expression> , <string_expression>
;
; Asserts current instruction has one numeric expressions, followed by comma,
; followed by a string expression, and returns the numeric values 
; contained within the expressions.
; Populates error message accordingly if an assertion fails.
;
; input:
;		none
; output:
;		AX - 0 if there was an error, other value otherwise
;		BX - numeric value left of comma
;	 DS:SI - string value right of comma
basicExecution_util_int_string:
	push es
	push cx
	push dx
	push di
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	cmp byte [cs:basicCurrentInstTokenCount], 3	; at least three tokens
	jb basicExecution_util_int_string_tokens_count_error
	
	; find token containing comma
	mov si, basicArgumentDelimiterToken
	call basic_lookup_inst_token			; BL := index of token
	cmp ax, 0
	je basicExecution_util_int_string_no_comma		; not found
	mov byte [cs:basicExeIntStringCommaTokenIndex], bl
	
	; evaluate expression (left of comma)
	mov dl, 0								; leftmost token to consider
	mov dh, bl
	dec dh									; rightmost token to consider
	call basicEval_do
	cmp ax, 0
	je basicExecution_util_int_string_error
											; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_NUMBER
	jne basicExecution_util_int_string_first_arg_not_numeric
	mov word [cs:basicExeIntStringExpressionsFirstValue], cx	; save value
	
	; evaluate expression (right of comma)
	mov dl, byte [cs:basicExeIntStringCommaTokenIndex]
	inc dl									; leftmost token to consider
	mov dh, byte [cs:basicCurrentInstTokenCount]
	dec dh									; rightmost token to consider
	call basicEval_do						; ES:DI := result string
											; when applicable
	cmp ax, 0
	je basicExecution_util_int_string_error
											; error in expression evaluation
	cmp bx, BASIC_EVAL_TYPE_STRING
	jne basicExecution_util_int_string_second_arg_not_string
	; here, ES:DI = string value of second expression
	push es
	pop ds
	mov si, di				; DS:SI := string value of second expression
	mov bx, word [cs:basicExeIntStringExpressionsFirstValue]
							; BX := numeric value of first expression
	jmp basicExecution_util_int_string_success

basicExecution_util_int_string_first_arg_not_numeric:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageFirstArgumentMustBeNumber
	jmp basicExecution_util_int_string_error
	
basicExecution_util_int_string_second_arg_not_string:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageSecondArgumentMustBeString
	jmp basicExecution_util_int_string_error
	
basicExecution_util_int_string_no_comma:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageNoComma
	jmp basicExecution_util_int_string_error

basicExecution_util_int_string_tokens_count_error:
	mov word [cs:basicInterpretationEndMessagePtr], basicMessageUnsupportedExpressionTokenCount
	jmp basicExecution_util_int_string_error
	
basicExecution_util_int_string_error:
	mov ax, 0							; "error"
	jmp basicExecution_util_int_string_done
basicExecution_util_int_string_success:
	mov ax, 1							; "success"
basicExecution_util_int_string_done:
	pop di
	pop cx
	pop dx
	pop es
	ret
	
	
; Initializes the execution module, expected to be called ONCE per
; basic_interpret invocation.
;
; input:
;		none
; output:
;		none
basicExecution_initialize_interpretation:
	pusha
	
	mov byte [cs:basicHaltingDueToNonError], 0
	
	popa
	ret
	

; Initializes the execution module, expected to be called ONCE per program
;
; input:
;		none
; output:
;		none
basicExecution_initialize_program:
	pusha
	
	call basicExecution_initialize_interpretation
	
	call common_stack_clear
	
	mov byte [cs:basicBranchCacheLabel], 0	; set cached label to be an empty
											; string, guaranteed to be a cache
											; miss, since tokens are non-empty
	mov byte [cs:basicTextAttribute], COMMON_BACKGROUND_COLOUR_BLACK | COMMON_FONT_COLOUR_WHITE
	
	; parallel port check
	int 0B7h								; AL := 0 when driver not loaded
											; DX := port base address
	mov byte [cs:basicLptAvailable], al
	mov word [cs:basicLptPortBaseAddress], dx
	
	; serial port check
	int 0ADh								; AL := 0 when driver not loaded
	mov byte [cs:basicSerialAvailable], al
	
	popa
	ret
	

%endif
