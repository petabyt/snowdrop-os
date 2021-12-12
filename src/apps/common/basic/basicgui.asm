;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains the higher-level integration layer, which brings together
; BASIC and the GUI framework, allowing BASIC programs to create UI elements
; and the GUI framework to invoke BASIC code as callbacks.
;
; This module governs the interactions between the BASIC interpreter and the
; GUI framework.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_GUI_INTEGRATION_
%define _COMMON_BASIC_GUI_INTEGRATION_


basicGuiStartRequested:			db 0
basicGuiActiveElementId:		dw 0FFFFh	; the GUI element ID of the last
											; element to cause the invocation
											; of a callback

basicGuiCurrentX:		dw 0	; these contain the position which
basicGuiCurrentY:		dw 0	; GUI drawing routines will use as origin

basicGuiBackgroundChangeRequested:	db 0	; used to indicate BASIC has drawn
											
; these are BASIC labels that serve as entry points into "callbacks" into
; the BASIC program
; whenever the GUI framework invokes a callback (due to the user clicking
; a button for example), the BASIC program interpretation is resumed from
; the respective label
basicCallbackLabelButtonClick:				db 'buttonClickEvent:', 0
basicCallbackLabelCheckboxChange:			db 'checkboxChangeEvent:', 0
basicCallbackLabelRadioChange:				db 'radioChangeEvent:', 0
basicCallbackLabelImageLeftClick:			db 'imageLeftClickedEvent:', 0
basicCallbackLabelImageRightClick:			db 'imageRightClickedEvent:', 0
basicCallbackLabelImageSelectedChange:		db 'imageSelectedChangeEvent:', 0
basicCallbackLabelTimerTick:				db 'timerTickEvent:', 0
basicCallbackLabelOnRefresh:				db 'guiRefreshEvent:', 0

basicGuiMessagePressAKey:	db 13, 10, 'Press a key to exit', 0

; these are used to pre-lookup GUI labels to speed up execution
basicGuiCallbackLabelButtonClick_found:			dw 0
basicGuiCallbackLabelButtonClick_ptr:			dw 0
basicGuiCallbackLabelCheckboxChange_found:		dw 0
basicGuiCallbackLabelCheckboxChange_ptr:		dw 0
basicGuiCallbackLabelRadioChange_found:			dw 0
basicGuiCallbackLabelRadioChange_ptr:			dw 0
basicGuiCallbackLabelImageLeftClick_found:		dw 0
basicGuiCallbackLabelImageLeftClick_ptr:		dw 0
basicGuiCallbackLabelImageRightClick_found:		dw 0
basicGuiCallbackLabelImageRightClick_ptr:		dw 0
basicGuiCallbackLabelImageSelectedChange_found:	dw 0
basicGuiCallbackLabelImageSelectedChange_ptr:	dw 0
basicGuiCallbackLabelTimerTick_found:			dw 0
basicGuiCallbackLabelTimerTick_ptr:				dw 0
basicGuiCallbackLabelOnRefresh_found:			dw 0
basicGuiCallbackLabelOnRefresh_ptr:				dw 0

; used by operations on radio buttons
basicCurrentRadioGroupId:		dw 0

basicGuiSettingsFlags			dw 0

BASIC_GUI_FLAG_SHOW_STATUS_ON_SUCCESS	equ 1
	; whether BASIC end of execution status is shown 
	; after program ends in success
BASIC_GUI_FLAG_SHOW_STATUS_ON_ERROR		equ 2
	; whether BASIC end of execution status is shown 
	; after program ends in error
BASIC_GUI_FLAG_WAIT_KEY_ON_STATUS		equ 4
	; whether BASIC will block waiting for a key from the user 
	; while displaying end of execution status


; The second-level entry point into BASIC+GUI framework.
; This has replaced previous BASIC entry point, from before it was
; integrated with the GUI framework
;
; NOTE: Requires dynamic memory to have been initialized
; IMPORTANT: there is a runtime library (RTL) which wraps this
;            function; if this contract is modified, then the 
;            RTL's must be modified as well
;
; input:
;	 DS:SI - pointer to program text, zero-terminated
;		AX - settings (see BASIC_GUI_FLAG_* above)
; output:
;		AX - 0 when an error occurred, other value otherwise
basic_gui_entry_point:
	pusha
	push ds
	
	mov word [cs:basicGuiSettingsFlags], ax	; save settings
	
	mov word [cs:basicGuiCurrentX], COMMON_GUI_MIN_X
	mov word [cs:basicGuiCurrentY], COMMON_GUI_MIN_Y
	
	call basic_prepare						; prepare interpreter for
											; a new program
	cmp ax, 0
	je basic_gui_entry_point_fail
	
basic_gui_entry_point_loop:
	call basic_interpret					; run interpreter
	
	; check if we're done with this program
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?

	jne basic_gui_entry_point_nonresumable	; no, so we're done
	
	; we're in a resumable state
	; check whether BASIC requested the GUI framework to start
	cmp byte [cs:basicGuiStartRequested], 0
	je basic_gui_entry_point_loop			; no, so keep interpreting
	
	; BASIC has just requested the GUI framework to start
	call common_gui_start					; start the GUI framework

	; when we reach this point, 
	; the GUI has shut down from within, so we do nothing more to it
	
	; tell BASIC that the GUI framework has shut down
	call basic_preshutdown_due_to_gui_exit
	
	jmp basic_gui_entry_point_after_gui_shutdown
	
basic_gui_entry_point_nonresumable:

	; we reach this point when either:
	;     1. there was an error in BASIC, or
	;     2. user requested break, or
	;     3. the program finished normally, either by a statement such
	;        as STOP, or by simply reaching the end of the program text
	
	; here, the GUI framework has not started, but may have been prepared
	
	cmp byte [cs:basicGuiStartRequested], 0		; has the GUI been prepared?
	je basic_gui_entry_point_after_gui_shutdown	; no, so there's nothing more
												; to do to the GUI framework
	
	; GUI framework has been prepared, but not yet started
	; this indicates a BASIC error right after GUIBEGIN, but before the 
	; GUI framework has actually started

	; shutdown GUI framework
	call common_gui_premature_shutdown

	; and now shut down BASIC
basic_gui_entry_point_after_gui_shutdown:
	call basic_get_interpreter_state			; AL := state
	cmp al, BASIC_STATE_NONRESUMABLE_SUCCESS	; success?
	jne basic_gui_entry_point_execution_was_error	; no

basic_gui_entry_point_execution_was_successful:
	test word [cs:basicGuiSettingsFlags], BASIC_GUI_FLAG_SHOW_STATUS_ON_SUCCESS
	jz basic_gui_entry_point_BASIC_shutdown		; we're configured to not show message
	; we're configured to show message
	call basic_display_status			; print user-friendly message
	jmp basic_gui_entry_point_wait_key

basic_gui_entry_point_execution_was_error:
	test word [cs:basicGuiSettingsFlags], BASIC_GUI_FLAG_SHOW_STATUS_ON_ERROR
	jz basic_gui_entry_point_BASIC_shutdown		; we're configured to not show message
	; we're configured to show message
	call basic_display_status			; print user-friendly message
	jmp basic_gui_entry_point_wait_key
	
basic_gui_entry_point_wait_key:
	test word [cs:basicGuiSettingsFlags], BASIC_GUI_FLAG_WAIT_KEY_ON_STATUS
	jz basic_gui_entry_point_BASIC_shutdown		; we're configured to not wait for key
	; we're configured to wait for a key
	call basic_shutdown		; this must be called before waiting for a key
							; in case current keyboard driver mode doesn't
							; support blocking
	push cs
	pop ds
	mov si, basicGuiMessagePressAKey
	int 97h					; print
	
	int 83h					; clear keyboard buffer
	mov ah, 0
	int 16h					; wait for a key
	jmp basic_gui_entry_point_success
	
basic_gui_entry_point_BASIC_shutdown:
	call basic_shutdown
	
basic_gui_entry_point_success:
	pop ds
	popa
	mov ax, 1
	ret
basic_gui_entry_point_fail:
	pop ds
	popa
	mov ax, 0
	ret


; Readies the GUI framework to interface with a BASIC program
;
; input:
;	 DS:SI - pointer to application title string, zero-terminated
; output:
;		AX - 0 when execution failed, other value otherwise
basic_gui_GUIBEGIN:
	pusha
	push ds

	call common_gui_dont_shutdown_on_no_mouse_driver
	call common_gui_disable_yield
	call common_gui_prepare
	cmp ax, 0
	je basic_gui_GUIBEGIN_failure
	
	mov byte [cs:basicGuiStartRequested], 1
	
	call common_gui_title_set		; set GUI application title to DS:SI
	
	push cs
	pop ds
	mov si, basic_gui_gui_initialized_callback	; DS:SI := pointer to callback
	call common_gui_initialized_callback_set
	
	; also install on refresh callback
	mov si, basic_gui_on_refresh_callback
	call common_gui_on_refresh_callback_set
	
	; and shutdown callback
	mov si, basic_gui_gui_shutdown_callback
	call common_gui_shutdown_callback_set
	
	call common_gui_set_return_on_shutdown	; configure GUI framework to return
											; instead of terminating task
basic_gui_GUIBEGIN_success:
	pop ds
	popa
	mov ax, 1
	ret
basic_gui_GUIBEGIN_failure:
	pop ds
	popa
	mov ax, 0
	ret

	
; Callback for all buttons created from the BASIC program.
; This function is invoked by the GUI framework when a button is clicked.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - button handle
; output:
;		none
basic_gui_button_click_callback:
	pusha
	
	mov word [cs:basicGuiActiveElementId], ax	; save active element ID
	
	; set BASIC interpreter's resume point to the button click callback label
	cmp word [cs:basicGuiCallbackLabelButtonClick_found], 0
	je basic_gui_button_click_callback_done	; label doesn't exist, so NOOP
	mov di, word [cs:basicGuiCallbackLabelButtonClick_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_button_click_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return
basic_gui_button_click_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf


; Callback for all checkboxes created from the BASIC program.
; This function is invoked by the GUI framework when a checkbox value changes.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - checkbox handle
;		BX - checked state: 0 when not checked, other value when checked
; output:
;		none
basic_gui_checkbox_change_callback:
	pusha

	mov word [cs:basicGuiActiveElementId], ax	; save active element ID
	
	; set BASIC interpreter's resume point to the callback label
	cmp word [cs:basicGuiCallbackLabelCheckboxChange_found], 0
	je basic_gui_checkbox_change_callback_done	; label doesn't exist, so NOOP
	mov di, word [cs:basicGuiCallbackLabelCheckboxChange_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_checkbox_change_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return	
basic_gui_checkbox_change_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf


; Callback for all radio boxes created from the BASIC program.
; This function is invoked by the GUI framework when a radio value changes.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - radio handle
;		BX - checked state: 0 when not checked, other value when checked
; output:
;		none	
basic_gui_radio_change_callback:
	pusha

	mov word [cs:basicGuiActiveElementId], ax	; save active element ID
	
	; set BASIC interpreter's resume point to the callback label
	cmp word [cs:basicGuiCallbackLabelRadioChange_found], 0
	je basic_gui_radio_change_callback_done	; label doesn't exist, so NOOP
	mov di, word [cs:basicGuiCallbackLabelRadioChange_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_radio_change_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return	
basic_gui_radio_change_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf
	
	
; This function is invoked by the GUI framework after it redraws the screen.
; Its intention is to redraw anything that was not based on a GUI framework
; component. Examples: text, custom graphics.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
basic_gui_on_refresh_callback:
	pusha

	; set BASIC interpreter's resume point to the button click callback label
	cmp word [cs:basicGuiCallbackLabelOnRefresh_found], 0
	je basic_gui_on_refresh_callback_done	; label doesn't exist, so NOOP
	
	mov di, word [cs:basicGuiCallbackLabelOnRefresh_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_on_refresh_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return	
basic_gui_on_refresh_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf
	
	
; This function is invoked by the GUI framework when the GUI timer ticks
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
basic_gui_timer_tick_callback:
	pusha

	; set BASIC interpreter's resume point to the button click callback label
	cmp word [cs:basicGuiCallbackLabelTimerTick_found], 0
	je basic_gui_timer_tick_callback_done	; label doesn't exist, so NOOP
	mov di, word [cs:basicGuiCallbackLabelTimerTick_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_timer_tick_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return	
basic_gui_timer_tick_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf
	
	
; Called by the GUI framework after it has initialized itself
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
basic_gui_gui_initialized_callback:
	pusha
	push ds
	
	; we can now resume the BASIC interpreter to continue with the
	; initialization of the application, such as adding buttons, etc.
	call basic_interpret
	
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_gui_initialized_callback_success
							; yes, so we simply return, letting the GUI
							; framework continue until a callback must
							; be invoked (perhaps because the user clicked
							; a button), which passes control back to BASIC
							; which eventually YIELDS back to the GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call 
								; to return
	jmp basic_gui_gui_initialized_callback_done

basic_gui_gui_initialized_callback_success:
	; install timer callback once all initial GUI elements have been created
	push cs
	pop ds
	mov si, basic_gui_timer_tick_callback
	call common_gui_timer_callback_set
basic_gui_gui_initialized_callback_done:
	call basic_gui_end_of_callback_housekeeping
	pop ds
	popa
	retf
	
	
; Called by the GUI framework immediately before shutting itself down
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
basic_gui_gui_shutdown_callback:
	pusha

	call basic_gui_end_of_callback_housekeeping
	popa
	retf


; Sets the current group ID to be used by operations which
; work on GUI radio boxes
;
; input:
;		AX - ID of group to be made current
; output:
;		none
basic_gui_set_current_radio_group_id:
	pusha
	mov word [cs:basicCurrentRadioGroupId], ax
	popa
	ret


; Callback for all images created from the BASIC program.
; This function is invoked by the GUI framework when an image is left clicked.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
basic_gui_image_left_click_callback:
	pusha

	mov word [cs:basicGuiActiveElementId], ax	; save active element ID
	
	; set BASIC interpreter's resume point to the callback label
	cmp word [cs:basicGuiCallbackLabelImageLeftClick_found], 0
	je basic_gui_image_left_click_callback_done	; label doesn't exist, so NOOP
	mov di, word [cs:basicGuiCallbackLabelImageLeftClick_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_image_left_click_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return	
basic_gui_image_left_click_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf
	

; Callback for all images created from the BASIC program.
; This function is invoked by the GUI framework when an image is right clicked.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
basic_gui_image_right_click_callback:
	pusha

	mov word [cs:basicGuiActiveElementId], ax	; save active element ID
	
	; set BASIC interpreter's resume point to the callback label
	cmp word [cs:basicGuiCallbackLabelImageRightClick_found], 0
	je basic_gui_image_right_click_callback_done	; label doesn't exist, so NOOP
	mov di, word [cs:basicGuiCallbackLabelImageRightClick_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_image_right_click_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return	
basic_gui_image_right_click_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf
	
	
; Callback for all images created from the BASIC program.
; This function is invoked by the GUI framework when an image is selected.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
basic_gui_image_selected_callback:
	pusha

	mov word [cs:basicGuiActiveElementId], ax	; save active element ID
	
	; set BASIC interpreter's resume point to the callback label
	cmp word [cs:basicGuiCallbackLabelImageSelectedChange_found], 0
	je basic_gui_image_selected_callback_done	; label doesn't exist, so NOOP
	mov di, word [cs:basicGuiCallbackLabelImageSelectedChange_ptr]
	call basic_set_resume_pointer

	call basic_interpret					; resume BASIC at callback label
	; we're done and must shut down if the BASIC program is in a
	; non-resumable state
	call basic_get_interpreter_state		; AL := state
	cmp al, BASIC_STATE_RESUMABLE			; is it resumable?
	je basic_gui_image_selected_callback_done	; return to GUI framework
	
	; BASIC interpreter is not in a resumable state, so tell GUI framework to
	; shut down as well
	call common_gui_shutdown	; this causes the initial common_gui_start call
								; to return	
basic_gui_image_selected_callback_done:
	call basic_gui_end_of_callback_housekeeping
	popa
	retf


; Informs the GUI framework that BASIC is about to change the background
;
; input:
;		none
; output:
;		none	
basic_gui_request_background_change:
	pusha
	
	cmp byte [cs:basicGuiBackgroundChangeRequested], 0
	jne basic_gui_request_background_change_done ; NOOP when already requested
	
	mov byte [cs:basicGuiBackgroundChangeRequested], 1	; set flag
	call common_gui_draw_begin

basic_gui_request_background_change_done:	
	popa
	ret
	

; Performs housekeeping right before returning control to the GUI
; framework from a callback
;
; input:
;		none
; output:
;		none	
basic_gui_end_of_callback_housekeeping:
	pusha
	
	; has BASIC performed any drawing on the background?
	cmp byte [cs:basicGuiBackgroundChangeRequested], 0
	je basic_gui_end_of_callback_housekeeping_done ; NOOP when not requested
	; inform the GUI framework that BASIC has finished changing the background
	mov byte [cs:basicGuiBackgroundChangeRequested], 0	; clear flag
	call common_gui_draw_end

basic_gui_end_of_callback_housekeeping_done:	
	popa
	ret
	

%endif
