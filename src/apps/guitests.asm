;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The GUITESTS app.
; This app tests many of the components supported by Snowdrop's GUI framework.
;
; Since this is a "many-in-one" program, constants and variables are 
; defined in each specific test suite's area, near the suite's procedures.
;
; This version relies on the VGA mode 12h, 640x480, 16 colours.
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
	
titleString:				db 'Snowdrop OS GUI Tests', 0
subtitleString:				db 'Select a test suite', 0
goodbyeString:				db 'Good Bye', 0

start:
	call common_gui_prepare					; must call this before any
											; other GUI framework functions

	; any long application initialization (e.g.: loading from disk, etc.)
	; should happen here, since the GUI framework has shown a "loading..."
	; notice
	call images_test_load_image_file		; load BMP file
	
	; set application title
	mov si, titleString						; DS:SI := pointer to title string
	call common_gui_title_set										
	
	; set up the shutdown callback, which is invoked by the GUI framework
	; as it is shutting down
	mov si, shutdown_callback
	call common_gui_shutdown_callback_set
	
	; set up the initialized callback, which is invoked by the GUI framework
	; right after it has initialized itself
	mov si, setup_main_menu_callback
	call common_gui_initialized_callback_set

	call common_gui_start
	; control has now been yielded permanently to the GUI framework


;------------------------------------------------------------------------------
;
;
;
; Shared functionality
;
;
;
;------------------------------------------------------------------------------
SHARED_BACK_BUTTON_X			equ 4
SHARED_BACK_BUTTON_Y			equ 14
sharedBackButtonLabel:			db 'Back', 0
itoaBuffer:						times 20 db 0


; Creates a "back" button which returns the user to the main menu
;
; input:
;		none
; output:
;		none	
shared_back_button_add:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov si, sharedBackButtonLabel
	mov ax, SHARED_BACK_BUTTON_X
	mov bx, SHARED_BACK_BUTTON_Y
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov si, setup_main_menu_callback
	call common_gui_button_click_callback_set
	
	pop ds
	popa
	ret
	

shutdown_callback:
	push cs
	pop ds
	mov si, goodbyeString
	call common_gui_util_show_notice
										
	mov cx, 100
	int 85h								; pause
	
	retf


;------------------------------------------------------------------------------
;
;
;
; Main menu
;
;
;
;------------------------------------------------------------------------------
MAIN_MENU_BUTTON_WIDTH			equ 150
MAIN_MENU_BUTTON_X				equ COMMON_GRAPHICS_SCREEN_WIDTH/2 - MAIN_MENU_BUTTON_WIDTH/2
MAIN_MENU_BUTTON_FIRST_Y		equ 54
MAIN_MENU_BUTTON_Y_GAP			equ COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE + 10
mainMenuButtonsLabel:			db 'Buttons Test', 0
mainMenuCheckboxesLabel:		db 'Checkboxes Test', 0
mainMenuRadioLabel:				db 'Radio Test', 0
mainMenuImagesLabel:			db 'Images Test', 0


; Initialized the "main menu" mode
;
; input:
;		none
; output:
;		none
setup_main_menu:
	pusha
	push ds
	
	push cs
	pop ds
	
	; "buttons test" button
	mov si, mainMenuButtonsLabel
	mov ax, MAIN_MENU_BUTTON_X						; position X
	mov bx, MAIN_MENU_BUTTON_FIRST_Y				; position Y
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, MAIN_MENU_BUTTON_WIDTH
	call common_gui_button_add						; AX := button handle
	mov si, setup_buttons_test_callback
	call common_gui_button_click_callback_set
	
	; "checkboxes test" button
	mov si, mainMenuCheckboxesLabel
	mov ax, MAIN_MENU_BUTTON_X						; position X
	add bx, MAIN_MENU_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, setup_checkboxes_test_callback
	call common_gui_button_click_callback_set
	
	; "radio test" button
	mov si, mainMenuRadioLabel
	mov ax, MAIN_MENU_BUTTON_X						; position X
	add bx, MAIN_MENU_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, setup_radio_test_callback
	call common_gui_button_click_callback_set
	
	; "images test" button
	mov si, mainMenuImagesLabel
	mov ax, MAIN_MENU_BUTTON_X						; position X
	add bx, MAIN_MENU_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, setup_images_test_callback
	call common_gui_button_click_callback_set
	
	pop ds
	popa
	ret


; Writes instructions
;
; input:
;		none
; output:
;		none	
main_menu_write_subtitle:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	mov si, subtitleString

	call common_graphics_text_measure_width ; AX := width
	shr ax, 1
	neg ax
	add ax, COMMON_GRAPHICS_SCREEN_WIDTH/2
	mov bx, ax							; BX := X position (centre text)
	
	mov ax, 24							; AX := Y position
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	pop ds
	popa
	ret
	
	
;------------------------------------------------------------------------------
;
; Main menu callbacks
;
;------------------------------------------------------------------------------

setup_main_menu_callback:
	; set on refresh callback before common_gui_clear_all below
	push cs
	pop ds
	mov si, main_menu_on_refresh
	call common_gui_on_refresh_callback_set
	
	call common_gui_clear_all
	call setup_main_menu
	retf

	
main_menu_on_refresh:
	call main_menu_write_subtitle
	retf
	

;------------------------------------------------------------------------------
;
;
;
; Button tests
;
;
;
;------------------------------------------------------------------------------
BUTTONS_TEST_TARGET_CLICKED_NOTICE_X	equ 50
BUTTONS_TEST_TARGET_CLICKED_NOTICE_Y	equ 180

BUTTONS_TEST_TARGET_WIDTH			equ 80
BUTTONS_TEST_BUTTON_WIDTH			equ 180
BUTTONS_TEST_BUTTON_X				equ 20
BUTTONS_TEST_BUTTON_FIRST_Y			equ 40
BUTTONS_TEST_BUTTON_Y_GAP			equ COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE + 7
buttonsTestTargetClicked:			db ' total clicks on target', 0

buttonsTestDisableLabel:			db 'Disable', 0
buttonsTestEnableLabel:				db 'Enable', 0
buttonsTestDeleteLabel:				db 'Delete', 0
buttonsTestTargetLabel:				db 'Target', 0
buttonsTestCreateLabel:				db 'Create', 0
buttonsTestRemoveCallbackLabel:		db 'Clear click callback', 0
buttonsTestSetCallbackLabel:		db 'Set click callback', 0

buttonsTestTargetHandle:			dw 0
buttonsTestTargetExists:			db 0
buttonsTestTargetClickCount:		dw 0



; Initialized the "button test" mode
;
; input:
;		none
; output:
;		none
setup_buttons_test:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov word [cs:buttonsTestTargetClickCount], 0
	
	mov si, buttons_test_on_refresh_callback
	call common_gui_on_refresh_callback_set
	
	call common_gui_clear_all
	
	call shared_back_button_add
	call buttons_test_create_target_button
	
	; "disable" button
	mov si, buttonsTestDisableLabel
	mov ax, BUTTONS_TEST_BUTTON_X					; position X
	mov bx, BUTTONS_TEST_BUTTON_FIRST_Y				; position Y
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, BUTTONS_TEST_BUTTON_WIDTH
	call common_gui_button_add						; AX := button handle
	mov si, buttons_test_disable
	call common_gui_button_click_callback_set
	
	; "enable" button
	mov si, buttonsTestEnableLabel
	mov ax, BUTTONS_TEST_BUTTON_X						; position X
	add bx, BUTTONS_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, buttons_test_enable
	call common_gui_button_click_callback_set
	
	; "delete" button
	mov si, buttonsTestDeleteLabel
	mov ax, BUTTONS_TEST_BUTTON_X						; position X
	add bx, BUTTONS_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, buttons_test_delete
	call common_gui_button_click_callback_set
	
	; "create" button
	mov si, buttonsTestCreateLabel
	mov ax, BUTTONS_TEST_BUTTON_X						; position X
	add bx, BUTTONS_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, buttons_test_create
	call common_gui_button_click_callback_set
	
	; "remove callback" button
	mov si, buttonsTestRemoveCallbackLabel
	mov ax, BUTTONS_TEST_BUTTON_X						; position X
	add bx, BUTTONS_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, buttons_test_remove_callback
	call common_gui_button_click_callback_set
	
	; "set callback" button
	mov si, buttonsTestSetCallbackLabel
	mov ax, BUTTONS_TEST_BUTTON_X						; position X
	add bx, BUTTONS_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, buttons_test_set_callback
	call common_gui_button_click_callback_set
	
	pop ds
	popa
	ret

	
; Writes text to inform user of how many times the target button was clicked
;
; input:
;		none
; output:
;		none
buttons_test_write_notice:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	
	; itoa
	pusha
	mov dx, 0
	mov ax, word [cs:buttonsTestTargetClickCount]	; DX:AX := number
	mov si, itoaBuffer
	mov bl, 1							; formatting option
	int 0A2h							; convert to string
	popa
	
	; write the number
	mov bx, BUTTONS_TEST_TARGET_CLICKED_NOTICE_X
	mov ax, BUTTONS_TEST_TARGET_CLICKED_NOTICE_Y
	mov si, itoaBuffer
	call common_gui_util_print_single_line_text_with_erase
	
	; write the suffix
	mov si, buttonsTestTargetClicked
	add bx, 74
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	pop ds
	popa
	ret
	

; Creates the target button
;
; input:
;		none
; output:
;		none
buttons_test_create_target_button:
	pusha
	push ds
	
	push cs
	pop ds
	
	; button under test
	mov si, buttonsTestTargetLabel
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH - BUTTONS_TEST_BUTTON_X - BUTTONS_TEST_TARGET_WIDTH
	mov bx, BUTTONS_TEST_BUTTON_FIRST_Y				; position Y
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, BUTTONS_TEST_TARGET_WIDTH				; width
	call common_gui_button_add						; AX := button handle
	mov si, buttons_test_target_clicked
	call common_gui_button_click_callback_set
	mov word [cs:buttonsTestTargetHandle], ax
	mov byte [cs:buttonsTestTargetExists], 1
	
	pop ds
	popa
	ret

	
;------------------------------------------------------------------------------
;
; Button tests callbacks
;
;------------------------------------------------------------------------------

; Callback for GUI framework's "on refresh". This will redraw anything custom
; we have to draw.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none	
buttons_test_on_refresh_callback:
	call buttons_test_write_notice
	retf
	
; Callback for the target button
; This function is invoked by the GUI framework when our button is clicked.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - button handle
; output:
;		none
buttons_test_target_clicked:
	inc word [cs:buttonsTestTargetClickCount]
	call buttons_test_write_notice
	retf
	

buttons_test_set_callback:
	mov ax, word [cs:buttonsTestTargetHandle]
	mov si, buttons_test_target_clicked
	call common_gui_button_click_callback_set
	retf	
	
buttons_test_remove_callback:
	mov ax, word [cs:buttonsTestTargetHandle]
	call common_gui_button_click_callback_clear
	retf
	
buttons_test_disable:
	mov ax, word [cs:buttonsTestTargetHandle]
	call common_gui_button_disable
	retf
	
buttons_test_enable:
	mov ax, word [cs:buttonsTestTargetHandle]
	call common_gui_button_enable
	retf
	
buttons_test_delete:
	mov ax, word [cs:buttonsTestTargetHandle]
	call common_gui_button_delete
	mov byte [cs:buttonsTestTargetExists], 0
	retf

buttons_test_create:
	cmp byte [cs:buttonsTestTargetExists], 0
	jne buttons_test_create_done				; already exists
	call buttons_test_create_target_button
buttons_test_create_done:
	retf


setup_buttons_test_callback:
	call setup_buttons_test
	retf
	
	
;------------------------------------------------------------------------------
;
;
;
; Checkboxes tests
;
;
;
;------------------------------------------------------------------------------
CHECKBOXES_TEST_TARGET_CLICKED_NOTICE_X	equ 122
CHECKBOXES_TEST_TARGET_CLICKED_NOTICE_Y	equ 185

CHECKBOXES_TEST_TARGET_X		equ COMMON_GRAPHICS_SCREEN_WIDTH - 80
CHECKBOXES_TEST_TARGET_WIDTH	equ 80
CHECKBOXES_TEST_BUTTON_WIDTH	equ 180
CHECKBOXES_TEST_BUTTON_X		equ 20
CHECKBOXES_TEST_BUTTON_FIRST_Y	equ 40
CHECKBOXES_TEST_Y_GAP	equ COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE + 3
checkboxesTestTargetChecked:	db '    target is checked', 0
checkboxesTestTargetNotChecked:	db 'target is not checked', 0

checkboxesTestDisableLabel:			db 'Disable', 0
checkboxesTestEnableLabel:			db 'Enable', 0
checkboxesTestDeleteLabel:			db 'Delete', 0
checkboxesTestTargetLabel:			db 'Target', 0
checkboxesTestCreateLabel:			db 'Create', 0
checkboxesTestRemoveCallbackLabel:	db 'Clear changed callback', 0
checkboxesTestSetCallbackLabel:		db 'Set changed callback', 0
checkboxesTestCheckLabel:			db 'Check', 0
checkboxesTestUncheckLabel:			db 'Uncheck', 0
checkboxesTestDummyLabel:			db 'Dummy', 0

checkboxesTestTargetHandle:			dw 0
checkboxesTestTargetExists:			db 0
checkboxesTestTargetClickCount:		dw 0


; Initialized the "checkboxes test" mode
;
; input:
;		none
; output:
;		none
setup_checkboxes_test:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov word [cs:checkboxesTestTargetClickCount], 0
	
	mov si, checkboxes_test_on_refresh_callback
	call common_gui_on_refresh_callback_set	; we need to know when the GUI
											; framework refreshes the screen
											; so we draw our custom things
	
	call common_gui_clear_all
	
	call shared_back_button_add
	call checkboxes_test_create_target
	call checkboxes_test_create_dummies
	
	; "disable" button
	mov si, checkboxesTestDisableLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	mov bx, CHECKBOXES_TEST_BUTTON_FIRST_Y			; position Y
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, CHECKBOXES_TEST_BUTTON_WIDTH
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_disable
	call common_gui_button_click_callback_set
	
	; "enable" button
	mov si, checkboxesTestEnableLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	add bx, CHECKBOXES_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_enable
	call common_gui_button_click_callback_set
	
	; "delete" button
	mov si, checkboxesTestDeleteLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	add bx, CHECKBOXES_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_delete
	call common_gui_button_click_callback_set
	
	; "create" button
	mov si, checkboxesTestCreateLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	add bx, CHECKBOXES_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_create
	call common_gui_button_click_callback_set
	
	; "remove callback" button
	mov si, checkboxesTestRemoveCallbackLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	add bx, CHECKBOXES_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_remove_callback
	call common_gui_button_click_callback_set
	
	; "set callback" button
	mov si, checkboxesTestSetCallbackLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	add bx, CHECKBOXES_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_set_callback
	call common_gui_button_click_callback_set
	
	; "uncheck" button
	mov si, checkboxesTestUncheckLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	add bx, CHECKBOXES_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_uncheck_callback
	call common_gui_button_click_callback_set
	
	; "check" button
	mov si, checkboxesTestCheckLabel
	mov ax, CHECKBOXES_TEST_BUTTON_X				; position X
	add bx, CHECKBOXES_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, checkboxes_test_check_callback
	call common_gui_button_click_callback_set
	
	pop ds
	popa
	ret

	
; Writes the current state of the checkbox
;
; input:
;		none
; output:
;		none
checkboxes_test_write_notice:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	
	push cs
	pop ds
	
	mov ax, word [cs:checkboxesTestTargetHandle]
	call common_gui_checkbox_get_checked		; BX := checked status
	mov dx, bx									; DX := checked status

	; write the number
	mov bx, CHECKBOXES_TEST_TARGET_CLICKED_NOTICE_X
	mov ax, CHECKBOXES_TEST_TARGET_CLICKED_NOTICE_Y
	; write the suffix
	mov si, checkboxesTestTargetChecked
	cmp dx, 0
	jne checkboxes_test_write_notice_perform	; it's checked
	mov si, checkboxesTestTargetNotChecked		; it's not checked
checkboxes_test_write_notice_perform:
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	
	pop ds
	popa
	ret
	

; Creates dummy checkboxes
;
; input:
;		none
; output:
;		none	
checkboxes_test_create_dummies:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov bx, CHECKBOXES_TEST_BUTTON_FIRST_Y				; position Y
	
	; dummy checkboxes
	mov si, checkboxesTestDummyLabel
	mov ax, CHECKBOXES_TEST_TARGET_X
	add bx, CHECKBOXES_TEST_Y_GAP						; position Y
	call common_gui_checkbox_add_auto_scaled			; AX := handle
	
	mov ax, CHECKBOXES_TEST_TARGET_X
	add bx, CHECKBOXES_TEST_Y_GAP						; position Y
	call common_gui_checkbox_add_auto_scaled			; AX := handle
	
	mov ax, CHECKBOXES_TEST_TARGET_X
	add bx, CHECKBOXES_TEST_Y_GAP						; position Y
	call common_gui_checkbox_add_auto_scaled			; AX := handle
	
	pop ds
	popa
	ret
	

; Creates the target
;
; input:
;		none
; output:
;		none
checkboxes_test_create_target:
	pusha
	push ds
	
	push cs
	pop ds
	
	; checkbox under test
	mov si, checkboxesTestTargetLabel
	mov ax, CHECKBOXES_TEST_TARGET_X
	mov bx, CHECKBOXES_TEST_BUTTON_FIRST_Y				; position Y
	call common_gui_checkbox_add_auto_scaled			; AX := handle
	mov si, checkboxes_test_target_changed
	call common_gui_checkbox_change_callback_set
	
	mov word [cs:checkboxesTestTargetHandle], ax
	mov byte [cs:checkboxesTestTargetExists], 1

	call checkboxes_test_write_notice
	
	pop ds
	popa
	ret


;------------------------------------------------------------------------------
;
; Checkboxes tests callbacks
;
;------------------------------------------------------------------------------

; Callback for GUI framework's "on refresh". This will redraw anything custom
; we have to draw.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
checkboxes_test_on_refresh_callback:
	call checkboxes_test_write_notice
	retf
	
; Callback for the target checkbox
; This function is invoked by the GUI framework when checkbox changes
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - checkbox handle
;		BX - checked state: 0 when not checked, other value when checked
; output:
;		none
checkboxes_test_target_changed:
	call checkboxes_test_write_notice
	retf

	
checkboxes_test_uncheck_callback:
	mov ax, word [cs:checkboxesTestTargetHandle]
	mov bx, 0
	call common_gui_checkbox_set_checked
	retf

checkboxes_test_check_callback:
	mov ax, word [cs:checkboxesTestTargetHandle]
	mov bx, 1
	call common_gui_checkbox_set_checked
	retf

checkboxes_test_set_callback:
	mov ax, word [cs:checkboxesTestTargetHandle]
	mov si, checkboxes_test_target_changed
	call common_gui_checkbox_change_callback_set
	retf
	
checkboxes_test_remove_callback:
	mov ax, word [cs:checkboxesTestTargetHandle]
	call common_gui_checkbox_change_callback_clear
	retf
	
checkboxes_test_disable:
	mov ax, word [cs:checkboxesTestTargetHandle]
	call common_gui_checkbox_disable
	retf
	
checkboxes_test_enable:
	mov ax, word [cs:checkboxesTestTargetHandle]
	call common_gui_checkbox_enable
	retf
	
checkboxes_test_delete:
	mov ax, word [cs:checkboxesTestTargetHandle]
	call common_gui_checkbox_delete
	mov byte [cs:checkboxesTestTargetExists], 0
	retf

checkboxes_test_create:
	cmp byte [cs:checkboxesTestTargetExists], 0
	jne checkboxes_test_create_done				; already exists
	call checkboxes_test_create_target
checkboxes_test_create_done:
	retf


setup_checkboxes_test_callback:
	call setup_checkboxes_test
	retf
	
	
;------------------------------------------------------------------------------
;
;
;
; Radio tests
;
;
;
;------------------------------------------------------------------------------
RADIO_TEST_TARGET_GROUP				equ 0	; used to group target radio

RADIO_TEST_TARGET_CLICKED_NOTICE_X	equ 122
RADIO_TEST_TARGET_CLICKED_NOTICE_Y	equ 185

RADIO_TEST_TARGET_X			equ COMMON_GRAPHICS_SCREEN_WIDTH - 80
RADIO_TEST_TARGET_WIDTH		equ 80
RADIO_TEST_BUTTON_WIDTH		equ 180
RADIO_TEST_BUTTON_X			equ 20
RADIO_TEST_BUTTON_FIRST_Y	equ 40
RADIO_TEST_Y_GAP			equ COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE + 3
radioTestTargetChecked:			db '    target is checked', 0
radioTestTargetNotChecked:		db 'target is not checked', 0

radioTestDisableLabel:			db 'Disable', 0
radioTestEnableLabel:			db 'Enable', 0
radioTestDeleteLabel:			db 'Delete', 0
radioTestTargetLabel:			db 'Target', 0
radioTestCreateLabel:			db 'Create', 0
radioTestRemoveCallbackLabel:	db 'Clear changed callback', 0
radioTestSetCallbackLabel:		db 'Set changed callback', 0
radioTestCheckLabel:			db 'Check', 0
radioTestUncheckLabel:			db 'Uncheck', 0
radioTestDummyLabel:			db 'Dummy', 0

radioTestTargetHandle:			dw 0
radioTestTargetExists:			db 0
radioTestTargetClickCount:		dw 0


; Initialized the "radio test" mode
;
; input:
;		none
; output:
;		none
setup_radio_test:
	mov word [cs:radioTestTargetClickCount], 0
	
	push cs
	pop ds
	mov si, radio_test_on_refresh_callback
	call common_gui_on_refresh_callback_set	; we need to know when the GUI
											; framework refreshes the screen
											; so we draw our custom things

	call common_gui_clear_all
	
	call shared_back_button_add
	call radio_test_create_target
	call radio_test_create_dummies
	
	; "disable" button
	mov si, radioTestDisableLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	mov bx, RADIO_TEST_BUTTON_FIRST_Y			; position Y
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, RADIO_TEST_BUTTON_WIDTH
	call common_gui_button_add						; AX := handle
	mov si, radio_test_disable
	call common_gui_button_click_callback_set
	
	; "enable" button
	mov si, radioTestEnableLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	add bx, RADIO_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, radio_test_enable
	call common_gui_button_click_callback_set
	
	; "delete" button
	mov si, radioTestDeleteLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	add bx, RADIO_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, radio_test_delete
	call common_gui_button_click_callback_set
	
	; "create" button
	mov si, radioTestCreateLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	add bx, RADIO_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, radio_test_create
	call common_gui_button_click_callback_set
	
	; "remove callback" button
	mov si, radioTestRemoveCallbackLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	add bx, RADIO_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, radio_test_remove_callback
	call common_gui_button_click_callback_set
	
	; "set callback" button
	mov si, radioTestSetCallbackLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	add bx, RADIO_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, radio_test_set_callback
	call common_gui_button_click_callback_set
	
	; "uncheck" button
	mov si, radioTestUncheckLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	add bx, RADIO_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, radio_test_uncheck_callback
	call common_gui_button_click_callback_set
	
	; "check" button
	mov si, radioTestCheckLabel
	mov ax, RADIO_TEST_BUTTON_X				; position X
	add bx, RADIO_TEST_Y_GAP			; position Y
	call common_gui_button_add						; AX := handle
	mov si, radio_test_check_callback
	call common_gui_button_click_callback_set
	
	ret

	
; Writes the current state of the radio
;
; input:
;		none
; output:
;		none
radio_test_write_notice:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen	
	push cs
	pop ds
	
	mov ax, word [cs:radioTestTargetHandle]
	call common_gui_radio_get_checked		; BX := checked status
	mov dx, bx									; DX := checked status

	; write the number
	mov bx, RADIO_TEST_TARGET_CLICKED_NOTICE_X
	mov ax, RADIO_TEST_TARGET_CLICKED_NOTICE_Y
	; write the suffix
	mov si, radioTestTargetChecked
	cmp dx, 0
	jne radio_test_write_notice_perform	; it's checked
	mov si, radioTestTargetNotChecked		; it's not checked
radio_test_write_notice_perform:
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	pop ds
	popa
	ret


; Creates the dummy radios
;
; input:
;		none
; output:
;		none
radio_test_create_dummies:
	pusha
	push ds
	
	push cs
	pop ds
	
	; dummy radio in the same group as target
	mov di, RADIO_TEST_TARGET_GROUP					; group
	mov si, radioTestDummyLabel
	mov ax, RADIO_TEST_TARGET_X
	mov bx, RADIO_TEST_BUTTON_FIRST_Y				; position Y
	call common_gui_radio_add_auto_scaled			; AX := handle
	
	; skip over the target
	add bx, RADIO_TEST_Y_GAP						; position Y
	
	; dummy radio in the same group as target
	mov di, RADIO_TEST_TARGET_GROUP					; group
	mov si, radioTestDummyLabel
	mov ax, RADIO_TEST_TARGET_X
	add bx, RADIO_TEST_Y_GAP						; position Y
	call common_gui_radio_add_auto_scaled			; AX := handle
	
	; gap
	add bx, RADIO_TEST_Y_GAP						; position Y
	
	; dummy radios in different group
	mov di, RADIO_TEST_TARGET_GROUP+1				; group
	mov ax, RADIO_TEST_TARGET_X
	add bx, RADIO_TEST_Y_GAP						; position Y
	call common_gui_radio_add_auto_scaled			; AX := handle
	
	mov di, RADIO_TEST_TARGET_GROUP+1				; group
	mov ax, RADIO_TEST_TARGET_X
	add bx, RADIO_TEST_Y_GAP						; position Y
	call common_gui_radio_add_auto_scaled			; AX := handle
	
	mov di, RADIO_TEST_TARGET_GROUP+1				; group
	mov ax, RADIO_TEST_TARGET_X
	add bx, RADIO_TEST_Y_GAP						; position Y
	call common_gui_radio_add_auto_scaled			; AX := handle
	
	pop ds
	popa
	ret
	

; Creates the target
;
; input:
;		none
; output:
;		none
radio_test_create_target:
	pusha
	push ds

	push cs
	pop ds
	
	mov bx, RADIO_TEST_BUTTON_FIRST_Y				; position Y
	
	; radio under test
	mov di, RADIO_TEST_TARGET_GROUP					; group
	mov si, radioTestTargetLabel
	mov ax, RADIO_TEST_TARGET_X
	add bx, RADIO_TEST_Y_GAP						; position Y
	call common_gui_radio_add_auto_scaled			; AX := handle
	mov si, radio_test_target_changed
	call common_gui_radio_change_callback_set
	
	mov word [cs:radioTestTargetHandle], ax
	mov byte [cs:radioTestTargetExists], 1
	
	call radio_test_write_notice
	
	pop ds
	popa
	ret


;------------------------------------------------------------------------------
;
; Radio tests callbacks
;
;------------------------------------------------------------------------------

; Callback for GUI framework's "on refresh". This will redraw anything custom
; we have to draw.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
radio_test_on_refresh_callback:
	call radio_test_write_notice
	retf


; Callback for the target radio
; This function is invoked by the GUI framework when radio changes
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
;		BX - checked state: 0 when not checked, other value when checked
; output:
;		none
radio_test_target_changed:
	call radio_test_write_notice
	retf

	
radio_test_uncheck_callback:
	mov ax, word [cs:radioTestTargetHandle]
	mov bx, 0
	call common_gui_radio_set_checked
	retf

radio_test_check_callback:
	mov ax, word [cs:radioTestTargetHandle]
	mov bx, 1
	call common_gui_radio_set_checked
	retf

radio_test_set_callback:
	mov ax, word [cs:radioTestTargetHandle]
	mov si, radio_test_target_changed
	call common_gui_radio_change_callback_set
	retf
	
radio_test_remove_callback:
	mov ax, word [cs:radioTestTargetHandle]
	call common_gui_radio_change_callback_clear
	retf
	
radio_test_disable:
	mov ax, word [cs:radioTestTargetHandle]
	call common_gui_radio_disable
	retf
	
radio_test_enable:
	mov ax, word [cs:radioTestTargetHandle]
	call common_gui_radio_enable
	retf
	
radio_test_delete:
	mov ax, word [cs:radioTestTargetHandle]
	call common_gui_radio_delete
	mov byte [cs:radioTestTargetExists], 0
	retf

radio_test_create:
	cmp byte [cs:radioTestTargetExists], 0
	jne radio_test_create_done				; already exists
	call radio_test_create_target
radio_test_create_done:
	retf


setup_radio_test_callback:
	call setup_radio_test
	retf
	
	
;------------------------------------------------------------------------------
;
;
;
; Image tests
;
;
;
;------------------------------------------------------------------------------
imagesTestImageFileName:			db 'GUITESTSBMP', 0

IMAGES_TEST_IMAGE_WIDTH				equ 64
IMAGES_TEST_IMAGE_HEIGHT			equ 64

IMAGES_TEST_RIGHT_PADDING			equ 32

IMAGES_TEST_TARGET_CLICKED_NOTICE_X	equ 10
IMAGES_TEST_TARGET_CLICKED_NOTICE_Y	equ 180

IMAGES_TEST_HALF_WIDTH_BUTTON_MARGIN	equ 3
IMAGES_TEST_BUTTON_WIDTH			equ 180
IMAGES_TEST_BUTTON_X				equ 10
IMAGES_TEST_BUTTON_FIRST_Y			equ 32
IMAGES_TEST_BUTTON_Y_GAP			equ COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE + 3
imagesTestTargetClicked:			db ' total left clicks on target', 0
imagesTestTargetRClicked:			db ' total right clicks on target', 0

imagesTestSelectedLabel:		db 'Selected', 0
imagesTestDeselectedLabel:		db 'Deselected', 0

imagesTestSelectLabel:			db 'Select', 0
imagesTestDeselectLabel:		db 'Deselect', 0

imagesTestFlipLabel:			db 'Flip', 0
imagesTestDisableLabel:			db 'Disable', 0
imagesTestEnableLabel:			db 'Enable', 0
imagesTestDeleteLabel:			db 'Delete', 0
imagesTestTargetLabel:			db 'Target', 0
imagesTestCreateLabel:			db 'Create', 0
imagesTestRemoveCallbackLabel:	db 'Clear lclick callback', 0
imagesTestSetCallbackLabel:		db 'Set lclick callback', 0
imagesTestRemoveRCallbackLabel:	db 'Clear rclick callback', 0
imagesTestSetRCallbackLabel:	db 'Set rclick callback', 0
imagesTestRemoveSelectedCallbackLabel:	db 'Clr selected callback', 0
imagesTestSetSelectedCallbackLabel:		db 'Set selected callback', 0

imagesTestTargetHandle:				dw 0
imagesTestTargetExists:				db 0
imagesTestTargetClickCount:			dw 0
imagesTestTargetRightClickCount:	dw 0

imagesTestSelectedRadioHandle:		dw 0
imagesTestDeselectedRadioHandle:	dw 0

; Initialized the "image test" mode
;
; input:
;		none
; output:
;		none
setup_images_test:
	pusha
	push ds
	
	mov word [cs:imagesTestTargetClickCount], 0
	mov word [cs:imagesTestTargetRightClickCount], 0
	
	push cs
	pop ds
	
	mov si, images_test_on_refresh_callback
	call common_gui_on_refresh_callback_set	; we need to know when the GUI
											; framework refreshes the screen
											; so we draw our custom things
	
	call common_gui_clear_all
	
	call shared_back_button_add
	
	; "disable" button
	mov si, imagesTestDisableLabel
	mov ax, IMAGES_TEST_BUTTON_X					; position X
	mov bx, IMAGES_TEST_BUTTON_FIRST_Y				; position Y
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, IMAGES_TEST_BUTTON_WIDTH/2 - IMAGES_TEST_HALF_WIDTH_BUTTON_MARGIN
	call common_gui_button_add						; AX := button handle
	mov si, images_test_disable
	call common_gui_button_click_callback_set
	
	; "deselect" button
	mov si, imagesTestDeselectLabel
	mov ax, IMAGES_TEST_BUTTON_X + IMAGES_TEST_BUTTON_WIDTH/2	; position X
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, IMAGES_TEST_BUTTON_WIDTH/2
	call common_gui_button_add						; AX := button handle
	mov si, images_test_deselect
	call common_gui_button_click_callback_set
	
	; "enable" button
	mov si, imagesTestEnableLabel
	mov ax, IMAGES_TEST_BUTTON_X						; position X
	add bx, IMAGES_TEST_BUTTON_Y_GAP					; position Y
	mov cx, IMAGES_TEST_BUTTON_WIDTH/2 - IMAGES_TEST_HALF_WIDTH_BUTTON_MARGIN
	call common_gui_button_add						; AX := button handle
	mov si, images_test_enable
	call common_gui_button_click_callback_set
	
	; "select" button
	mov si, imagesTestSelectLabel
	mov ax, IMAGES_TEST_BUTTON_X + IMAGES_TEST_BUTTON_WIDTH/2	; position X
	mov cx, IMAGES_TEST_BUTTON_WIDTH/2
	call common_gui_button_add						; AX := button handle
	mov si, images_test_select
	call common_gui_button_click_callback_set

	; "remove selected callback" button
	mov si, imagesTestRemoveSelectedCallbackLabel
	mov ax, IMAGES_TEST_BUTTON_X						; position X
	add bx, IMAGES_TEST_BUTTON_Y_GAP					; position Y
	mov cx, IMAGES_TEST_BUTTON_WIDTH
	call common_gui_button_add						; AX := button handle
	mov si, images_test_remove_selected_callback
	call common_gui_button_click_callback_set

	; "set selected callback" button
	mov si, imagesTestSetSelectedCallbackLabel
	mov ax, IMAGES_TEST_BUTTON_X						; position X
	add bx, IMAGES_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, images_test_set_selected_callback
	call common_gui_button_click_callback_set
	
	; "remove callback" button
	mov si, imagesTestRemoveCallbackLabel
	mov ax, IMAGES_TEST_BUTTON_X						; position X
	add bx, IMAGES_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, images_test_remove_callback
	call common_gui_button_click_callback_set
	
	; "set callback" button
	mov si, imagesTestSetCallbackLabel
	mov ax, IMAGES_TEST_BUTTON_X						; position X
	add bx, IMAGES_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, images_test_set_callback
	call common_gui_button_click_callback_set
	
	; "remove right click callback" button
	mov si, imagesTestRemoveRCallbackLabel
	mov ax, IMAGES_TEST_BUTTON_X						; position X
	add bx, IMAGES_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, images_test_remove_right_click_callback
	call common_gui_button_click_callback_set
	
	; "set right click callback" button
	mov si, imagesTestSetRCallbackLabel
	mov ax, IMAGES_TEST_BUTTON_X						; position X
	add bx, IMAGES_TEST_BUTTON_Y_GAP					; position Y
	call common_gui_button_add						; AX := button handle
	mov si, images_test_set_right_click_callback
	call common_gui_button_click_callback_set
	
	
	; indicator radios
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH - IMAGES_TEST_IMAGE_WIDTH - IMAGES_TEST_RIGHT_PADDING
	mov bx, IMAGES_TEST_BUTTON_FIRST_Y + IMAGES_TEST_IMAGE_HEIGHT + 3
	mov di, 0										; group
	mov si, imagesTestDeselectedLabel
	call common_gui_radio_add_auto_scaled			; AX := handle
	call common_gui_radio_disable
	mov word [cs:imagesTestDeselectedRadioHandle], ax
	; here, BX != 0, which means "checked" for the call immediately below
	call common_gui_radio_set_checked			; this radio is checked because
												; image starts out deselected

	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH - IMAGES_TEST_IMAGE_WIDTH - IMAGES_TEST_RIGHT_PADDING
	add bx, COMMON_GUI_RADIO_HEIGHT_SINGLE_LINE	+ 3
	mov di, 0										; group
	mov si, imagesTestSelectedLabel
	call common_gui_radio_add_auto_scaled			; AX := handle
	call common_gui_radio_disable
	mov word [cs:imagesTestSelectedRadioHandle], ax
	
	; "delete" button
	mov si, imagesTestDeleteLabel
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH - IMAGES_TEST_IMAGE_WIDTH - IMAGES_TEST_RIGHT_PADDING
	add bx, COMMON_GUI_RADIO_HEIGHT_SINGLE_LINE	+ 2	; position Y
	mov cx, IMAGES_TEST_BUTTON_WIDTH/2
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	call common_gui_button_add						; AX := button handle
	mov si, images_test_delete
	call common_gui_button_click_callback_set

	; "create" button
	mov si, imagesTestCreateLabel
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH - IMAGES_TEST_IMAGE_WIDTH - IMAGES_TEST_RIGHT_PADDING
	add bx, IMAGES_TEST_BUTTON_Y_GAP				; position Y
	mov cx, IMAGES_TEST_BUTTON_WIDTH/2
	call common_gui_button_add						; AX := button handle
	mov si, images_test_create
	call common_gui_button_click_callback_set
	
	; "flip" button
	mov si, imagesTestFlipLabel
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH - IMAGES_TEST_IMAGE_WIDTH - IMAGES_TEST_RIGHT_PADDING
	add bx, IMAGES_TEST_BUTTON_Y_GAP				; position Y
	mov cx, IMAGES_TEST_BUTTON_WIDTH/2
	call common_gui_button_add						; AX := button handle
	mov si, images_test_flip
	call common_gui_button_click_callback_set
	
	call images_test_create_target_image
	
	pop ds
	popa
	ret

	
; Writes text to inform user of how many times the 
; target image was left clicked
;
; input:
;		none
; output:
;		none
images_test_write_notice:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	
	; itoa
	pusha
	mov dx, 0
	mov ax, word [cs:imagesTestTargetClickCount]	; DX:AX := number
	mov si, itoaBuffer
	mov bl, 1							; formatting option
	int 0A2h							; convert to string
	popa
	
	; write the number
	mov bx, IMAGES_TEST_TARGET_CLICKED_NOTICE_X
	mov ax, IMAGES_TEST_TARGET_CLICKED_NOTICE_Y
	mov si, itoaBuffer
	call common_gui_util_print_single_line_text_with_erase
	
	; write the suffix
	mov si, imagesTestTargetClicked
	add bx, 74
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	pop ds
	popa
	ret
	
	
; Writes text to inform user of how many times the 
; target image was right clicked
;
; input:
;		none
; output:
;		none
images_test_write_right_click_notice:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	
	; itoa
	pusha
	mov dx, 0
	mov ax, word [cs:imagesTestTargetRightClickCount]	; DX:AX := number
	mov si, itoaBuffer
	mov bl, 1							; formatting option
	int 0A2h							; convert to string
	popa
	
	; write the number
	mov bx, IMAGES_TEST_TARGET_CLICKED_NOTICE_X
	mov ax, IMAGES_TEST_TARGET_CLICKED_NOTICE_Y + COMMON_GRAPHICS_FONT_HEIGHT
	mov si, itoaBuffer
	call common_gui_util_print_single_line_text_with_erase
	
	; write the suffix
	mov si, imagesTestTargetRClicked
	add bx, 74
	call common_gui_util_print_single_line_text_with_erase
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	pop ds
	popa
	ret
	

; Creates the target image
;
; input:
;		none
; output:
;		none
images_test_create_target_image:
	pusha
	push ds
	
	push cs
	pop ds
	
	; image under test
	mov si, imagesTestImageDataBuffer		; DS:SI := pointer to BMP
	call common_bmp_get_pixel_data_pointer	; DS:DI := pointer to pixel data
	mov si, di								; DS:SI := pointer to pixel data
	
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH - IMAGES_TEST_IMAGE_WIDTH - IMAGES_TEST_RIGHT_PADDING
	mov bx, IMAGES_TEST_BUTTON_FIRST_Y				; position Y
	mov dx, IMAGES_TEST_IMAGE_HEIGHT
	mov cx, IMAGES_TEST_IMAGE_WIDTH
	mov di, IMAGES_TEST_IMAGE_WIDTH					; canvas width
	call common_gui_image_add						; AX := handle
	mov si, images_test_target_clicked
	call common_gui_image_left_click_callback_set
	mov si, images_test_target_right_clicked
	call common_gui_image_right_click_callback_set
	mov si, images_test_image_selected_changed
	call common_gui_image_selected_callback_set
	
	mov word [cs:imagesTestTargetHandle], ax
	mov byte [cs:imagesTestTargetExists], 1

	; check the "deselected" indicator radio, since the image is not
	; selected when it is created
	mov ax, word [cs:imagesTestDeselectedRadioHandle]
	mov bx, 1								; check it
	call common_gui_radio_set_checked
	
	pop ds
	popa
	ret

	
; Loads the bitmap file into memory
;
; input:
;		none
; output:
;		none
images_test_load_image_file:
	pusha
	push ds
	push es
	
	push cs
	pop ds
	mov si, imagesTestImageFileName		; DS:SI now points to file name
	push cs
	pop es
	mov di, imagesTestImageDataBuffer	; ES:DI now points to where we'll load file
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
								
	pop es
	pop ds
	popa
	ret
	
	
;------------------------------------------------------------------------------
;
; Image tests callbacks
;
;------------------------------------------------------------------------------
	
; Callback for GUI framework's "on refresh". This will redraw anything custom
; we have to draw.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
images_test_on_refresh_callback:
	call images_test_write_notice
	call images_test_write_right_click_notice
	retf

	
; Callback for the target image
; This function is invoked by the GUI framework when our image is left clicked.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
images_test_target_clicked:
	inc word [cs:imagesTestTargetClickCount]
	call images_test_write_notice
	retf
	
	
; Callback for the target image
; This function is invoked by the GUI framework when our image 
; is right clicked.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - button handle
; output:
;		none
images_test_target_right_clicked:
	inc word [cs:imagesTestTargetRightClickCount]
	call images_test_write_right_click_notice
	retf
	

images_test_set_callback:
	mov ax, word [cs:imagesTestTargetHandle]
	mov si, images_test_target_clicked
	call common_gui_image_left_click_callback_set
	retf	
	
images_test_remove_callback:
	mov ax, word [cs:imagesTestTargetHandle]
	call common_gui_image_left_click_callback_clear
	retf
	
images_test_set_right_click_callback:
	mov ax, word [cs:imagesTestTargetHandle]
	mov si, images_test_target_right_clicked
	call common_gui_image_right_click_callback_set
	retf	
	
images_test_remove_right_click_callback:
	mov ax, word [cs:imagesTestTargetHandle]
	call common_gui_image_right_click_callback_clear
	retf
	
images_test_remove_selected_callback:
	mov ax, word [cs:imagesTestTargetHandle]
	call common_gui_image_selected_callback_clear
	retf
	
images_test_set_selected_callback:
	mov ax, word [cs:imagesTestTargetHandle]
	mov si, images_test_image_selected_changed
	call common_gui_image_selected_callback_set
	retf

images_test_select:
	mov ax, word [cs:imagesTestTargetHandle]
	mov bx, 1
	call common_gui_image_set_selected
	retf
	
images_test_deselect:
	mov ax, word [cs:imagesTestTargetHandle]
	mov bx, 0
	call common_gui_image_set_selected
	retf
	
images_test_disable:
	mov ax, word [cs:imagesTestTargetHandle]
	call common_gui_image_disable
	retf
	
images_test_enable:
	mov ax, word [cs:imagesTestTargetHandle]
	call common_gui_image_enable
	retf

images_test_flip:
	mov ax, word [cs:imagesTestTargetHandle]
	push cs
	pop ds
	
	; get a pointer to the BMP pixel data
	mov si, imagesTestImageDataBuffer		; DS:SI := pointer to BMP
	call common_bmp_get_pixel_data_pointer	; DS:DI := pointer to pixel data
	
	; flip it horizontally and set target image data
	mov si, di								; DS:SI := pointer to pixel data
	mov bx, IMAGES_TEST_IMAGE_HEIGHT
	mov dx, IMAGES_TEST_IMAGE_WIDTH
	call common_graphicsbase_flip_rectangle_buffer_horizontally
	call common_gui_image_set_data			; setting image data forces an
											; image render
	retf
	
images_test_delete:
	mov ax, word [cs:imagesTestTargetHandle]
	call common_gui_image_delete
	mov byte [cs:imagesTestTargetExists], 0
	retf

images_test_create:
	cmp byte [cs:imagesTestTargetExists], 0
	jne images_test_create_done				; already exists
	call images_test_create_target_image
images_test_create_done:
	retf

images_test_image_selected_changed:
	mov ax, word [cs:imagesTestDeselectedRadioHandle]
	cmp bx, 0								; deselected?
	je images_test_image_selected_changed_done
	mov ax, word [cs:imagesTestSelectedRadioHandle]
images_test_image_selected_changed_done:
	; here, AX = handle of radio to become checked
	mov bx, 1								; check it
	call common_gui_radio_set_checked
	retf

setup_images_test_callback:
	call setup_images_test
	retf


%include "common\vga640\gui\gui.asm"
%include "common\vga640\gra_text.asm"
%include "common\bmp.asm"

imagesTestImageDataBuffer:			; filled in from the BMP file
