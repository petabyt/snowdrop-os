;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains routines needed for the user interface of
; Snowdrop OS's debugger.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DBGX86_UI_
%define _COMMON_DBGX86_UI_


DBGX86_UI_USER_RESUME_TYPE_UNKNOWN		equ 0
DBGX86_UI_USER_RESUME_TYPE_CONTINUE		equ 1
DBGX86_UI_USER_RESUME_TYPE_SINGLE_STEP	equ 2
DBGX86_UI_USER_RESUME_TYPE_STEP_OVER	equ 3
DBGX86_UI_USER_RESUME_TYPE_TERMINATE	equ 4

dbgx86UiHighlightedAddress:		dw 0
dbgx86UiUserResumeType:		db DBGX86_UI_USER_RESUME_TYPE_UNKNOWN

dbgx86UiCurrentVirtualDisplayTaskId:	dw 0
DBGX86_SCR_WIDTH			equ COMMON_SCREENH_WIDTH
dbgx86UiLineCopyBuffer:		times DBGX86_SCR_WIDTH + 10 db 'A'

dbgx86TitleString:			db 'Snowdrop OS Debugger', 0
dbgx86TitleStringEnd:

dbgx86BreakpointsString:	db 'Breakpoints', 0
dbgx86BreakpointsStringEnd:

dbgx86UiBlankSpace:			db ' ', 0
dbgx86UiRegistersBoxTitle:	db 'Registers', 0
dbgx86UiStackBoxTitle:		db 'Stack', 0
dbgx86UiFlagsBoxTitle:		db 'Flags', 0
dbgx86UiDssiBoxTitle:		db 'DS:SI', 0
dbgx86UiBreakpointListBoxTitle:		db 'Address', 0
dbgx86UiBreakpointListBoxSeenTitle:	db 'Count', 0
dbgx86UiBreakpointAddBoxTitle:		db 'Add breakpoint', 0
dbgx86UiBreakpointRemoveBoxTitle:	db 'Delete breakpoint', 0
dbgx86UiWatchAddBoxTitle:
dbgx86UiWatchShowEmptyBoxTitle:			db 'Watched address', 0
dbgx86UiWatchShowPopulatedBoxTitle:					db 'Watching address '	; intentionally unterminated
dbgx86UiWatchShowPopulatedBoxTitleInsertionPoint:	db '    ', 0
dbgx86UiWatchNoneSet:		db ' None set yet', 0
dbgx86UiMessageUiInstructions:	db 'F10-over F9-step F8-cont F4-screens F1-stop B-breakpts L-list M-memory W-watch', 0

dbgx86UiBreakpointsUiPrompt:			db 'A-add D-delete L-listing M-memory ESC-back', 0
dbgx86UiBreakpointsUiPromptNoAdd:		db 'D-delete L-listing M-memory ESC-back', 0
dbgx86UiBreakpointsUiPromptNoRemove:	db 'A-add L-listing M-memory ESC-back', 0

DBGX86_REG_BOX_LEFT		equ 0
DBGX86_REG_BOX_TOP		equ 14
DBGX86_REG_BOX_WIDTH	equ 17
DBGX86_REG_BOX_HEIGHT	equ 8

DBGX86_REG_BOX_FIRST_REG_LEFT	equ DBGX86_REG_BOX_LEFT + 2
DBGX86_REG_BOX_FIRST_REG_TOP	equ DBGX86_REG_BOX_TOP + 1

dbgx86UiAx:		db 'AX:', 0
dbgx86UiBx:		db ' BX:', 0
dbgx86UiCx:		db 'CX:', 0
dbgx86UiDx:		db ' DX:', 0
dbgx86UiDs:		db 'DS:', 0
dbgx86UiSi:		db ' SI:', 0
dbgx86UiEs:		db 'ES:', 0
dbgx86UiDi:		db ' DI:', 0
dbgx86UiSs:		db 'SS:', 0
dbgx86UiSp:		db ' SP:', 0
dbgx86UiCs:		db 'CS:', 0
dbgx86UiIp:		db ' IP:', 0
dbgx86UiBp:		db 'BP:', 0
dbgx86UiFl:		db ' FL:', 0
dbgx86UiFs:		db 'FS:', 0
dbgx86UiGs:		db ' GS:', 0

DBGX86_STACK_BOX_LEFT		equ 31
DBGX86_STACK_BOX_TOP		equ 14
DBGX86_STACK_BOX_WIDTH		equ 13
DBGX86_STACK_BOX_HEIGHT		equ 8

DBGX86_STACK_BOX_FIRST_LEFT		equ DBGX86_STACK_BOX_LEFT + 1
DBGX86_STACK_BOX_FIRST_TOP	equ DBGX86_STACK_BOX_TOP + DBGX86_STACK_BOX_HEIGHT
dbgx86UiStackBoxEmptyEntry: times DBGX86_STACK_BOX_WIDTH db ' '
							db 0			; terminator
dbgx86UiStackBoxSegment:		db ' [', 0
dbgx86UiStackBoxCloseBracket:	db '] ', 0							
dbgx86UiStackBoxStackTopMarker:	db '>', 0

DBGX86_FLAGS_BOX_LEFT		equ 19
DBGX86_FLAGS_BOX_TOP		equ 14
DBGX86_FLAGS_BOX_WIDTH		equ 10
DBGX86_FLAGS_BOX_HEIGHT		equ 8

DBGX86_FLAGS_BOX_FIRST_REG_LEFT	equ DBGX86_FLAGS_BOX_LEFT + 2
DBGX86_FLAGS_BOX_FIRST_REG_TOP	equ DBGX86_FLAGS_BOX_TOP + 1

dbgx86UiFlagCarry:		db 'carry: ', 0
dbgx86UiFlagParity:		db 'prity: ', 0
dbgx86UiFlagAdjust:		db 'adjst: ', 0
dbgx86UiFlagZero:		db 'zero:  ', 0
dbgx86UiFlagSign:		db 'sign:  ', 0
dbgx86UiFlagDirection:	db 'direc: ', 0
dbgx86UiFlagOverflow:	db 'ovrfl: ', 0
dbgx86UiFlagInterrupt:	db 'intrp: ', 0

DBGX86_FLAG_MASK_CARRY		equ 1 << 0
DBGX86_FLAG_MASK_PARITY		equ 1 << 2
DBGX86_FLAG_MASK_ADJUST		equ 1 << 4
DBGX86_FLAG_MASK_ZERO		equ 1 << 6
DBGX86_FLAG_MASK_SIGN		equ 1 << 7
DBGX86_FLAG_MASK_DIRECTION	equ 1 << 10
DBGX86_FLAG_MASK_OVERFLOW	equ 1 << 11
DBGX86_FLAG_MASK_INTERRUPT	equ 1 << 9

dbgx86UiFlagOffString:		db '0', 0
dbgx86UiFlagOnString:		db '1', 0

DBGX86_DSSI_BOX_LEFT	equ 46
DBGX86_DSSI_BOX_TOP		equ 19
DBGX86_DSSI_BOX_WIDTH	equ 32
DBGX86_DSSI_BOX_HEIGHT	equ 3

DBGX86_DSSI_BOX_FIRST_REG_LEFT	equ DBGX86_DSSI_BOX_LEFT + 1
DBGX86_DSSI_BOX_FIRST_REG_TOP	equ DBGX86_DSSI_BOX_TOP + 1

dbgx86SingleLineBuffer:	times 128 db 0
DBGX86_DSSI_BYTES_PER_LINE		equ 8

DBGX86UI_SOURCE_AREA_HEIGHT		equ 13
dbgx86UiListingDoesntContainAddress:	db 'Current address not found in listing', 0

DBGX86_BK_LIST_BOX_TOP		equ 1
DBGX86_BK_LIST_BOX_LEFT		equ 1
DBGX86_BK_LIST_BOX_HEIGHT	equ 21
DBGX86_BK_LIST_BOX_WIDTH	equ 21

DBGX86_BK_LIST_BOX_FIRST_LEFT	equ DBGX86_BK_LIST_BOX_LEFT + 2
DBGX86_BK_LIST_BOX_FIRST_TOP	equ DBGX86_BK_LIST_BOX_TOP + 1
DBGX86_BK_MAX_COUNT				equ DBGX86_BK_LIST_BOX_TOP + DBGX86_BK_LIST_BOX_HEIGHT - DBGX86_BK_LIST_BOX_FIRST_TOP + 1
DBGX86_BK_LIST_BOX_LAST_TOP		equ DBGX86_BK_LIST_BOX_FIRST_TOP + DBGX86_BK_MAX_COUNT - 1

DBGX86_BK_ADD_BOX_TOP		equ 20
DBGX86_BK_ADD_BOX_LEFT		equ 25
DBGX86_BK_ADD_BOX_HEIGHT	equ 1
DBGX86_BK_ADD_BOX_WIDTH		equ 33

DBGX86_BK_ADD_BOX_FIRST_LEFT	equ DBGX86_BK_ADD_BOX_LEFT + 2
DBGX86_BK_ADD_BOX_FIRST_TOP		equ DBGX86_BK_ADD_BOX_TOP + 1

DBGX86_BK_REMOVE_BOX_TOP		equ DBGX86_BK_ADD_BOX_TOP
DBGX86_BK_REMOVE_BOX_LEFT		equ DBGX86_BK_ADD_BOX_LEFT
DBGX86_BK_REMOVE_BOX_HEIGHT		equ DBGX86_BK_ADD_BOX_HEIGHT
DBGX86_BK_REMOVE_BOX_WIDTH		equ DBGX86_BK_ADD_BOX_WIDTH

DBGX86_BK_REMOVE_BOX_FIRST_LEFT	equ DBGX86_BK_REMOVE_BOX_LEFT + 2
DBGX86_BK_REMOVE_BOX_FIRST_TOP	equ DBGX86_BK_REMOVE_BOX_TOP + 1

DBGX86_WATCH_ADD_BOX_TOP		equ 14
DBGX86_WATCH_ADD_BOX_LEFT		equ 46
DBGX86_WATCH_ADD_BOX_HEIGHT		equ 1
DBGX86_WATCH_ADD_BOX_WIDTH		equ 32

DBGX86_WATCH_ADD_BOX_FIRST_LEFT		equ DBGX86_WATCH_ADD_BOX_LEFT + 2
DBGX86_WATCH_ADD_BOX_FIRST_TOP		equ DBGX86_WATCH_ADD_BOX_TOP + 1

DBGX86_WATCH_SHOW_BOX_TOP		equ DBGX86_WATCH_ADD_BOX_TOP
DBGX86_WATCH_SHOW_BOX_LEFT		equ DBGX86_WATCH_ADD_BOX_LEFT
DBGX86_WATCH_SHOW_BOX_HEIGHT	equ 3
DBGX86_WATCH_SHOW_BOX_WIDTH		equ DBGX86_WATCH_ADD_BOX_WIDTH

DBGX86_WATCH_SHOW_BOX_FIRST_LEFT	equ DBGX86_WATCH_SHOW_BOX_LEFT + 1
DBGX86_WATCH_SHOW_BOX_FIRST_TOP		equ DBGX86_WATCH_ADD_BOX_FIRST_TOP
DBGX86_WATCH_SHOW_BYTES_PER_LINE	equ 8

dbgx86UiWatchAddErase:				times DBGX86_WATCH_ADD_BOX_WIDTH db ' '
									db 0
dbgx86UiWatchAddInstructions:
dbgx86UiBreakpointRemoveInstructions:
dbgx86UiBreakpointAddInstructions:	db 'Enter address (e.g. F23B): ', 0
dbgx86UiUserEnteredAddressBuffer:	times 5 db 0

dbgx86UiAddressCheckBuffer:			times 5 db 0


; Shows the main debugger UI, where the user can inspect the program,
; set breakpoints, etc.
; This procedure exits when the user chooses a resume type, such as
; continue, single step, etc.
;
; input:
;		AX - address whose instruction we will highlight
; output:
;		AL - user resume type (continue, single step, etc.)
dbgx86Ui_show_ui:
	pusha
	pushf
	push ds
	push es
	
	mov word [cs:dbgx86UiHighlightedAddress], ax		; save
	
	sti
	
	mov ax, word [cs:dbgx86DebuggerTaskId]
	mov word [cs:dbgx86UiCurrentVirtualDisplayTaskId], ax
	int 96h						; make virtual display of debugger active

	call dbgx86Ui_draw_ui
	
	int 83h										; clear keyboard buffer
dbgx86Ui_show_ui_main_loop:
	hlt
	mov ah, 1
	int 16h 									; any key pressed?
	jz dbgx86Ui_show_ui_main_loop 			 	; no
	
	mov ah, 0
	int 16h										; AH := scan code

	cmp ah, COMMON_SCAN_CODE_F4
	je dbgx86Ui_show_ui_handle_swap_displays

	mov dx, word [cs:dbgx86UiCurrentVirtualDisplayTaskId]
	cmp dx, word [cs:dbgx86DebuggerTaskId]
	jne dbgx86Ui_show_ui_main_loop_after_key_checks
	; we don't check any more keys when we're looking at the watched 
	; program's display
	
	; the workflows below work only when the active display is that of
	; the debugger
	cmp ah, COMMON_SCAN_CODE_F8
	je dbgx86Ui_show_ui_handle_continue
	
	cmp ah, COMMON_SCAN_CODE_F10
	je dbgx86Ui_show_ui_handle_step_over
	
	cmp ah, COMMON_SCAN_CODE_F9
	je dbgx86Ui_show_ui_handle_single_step
	
	cmp ah, COMMON_SCAN_CODE_F1
	je dbgx86Ui_show_ui_handle_exit
	
	cmp ah, COMMON_SCAN_CODE_L
	je dbgx86Ui_show_ui_handle_show_listing
	
	cmp ah, COMMON_SCAN_CODE_B
	je dbgx86Ui_show_ui_handle_show_breakpoints
	
	cmp ah, COMMON_SCAN_CODE_M
	je dbgx86Ui_show_ui_handle_show_memory
	
	cmp ah, COMMON_SCAN_CODE_W
	je dbgx86Ui_show_ui_handle_add_watch

dbgx86Ui_show_ui_main_loop_after_key_checks:	
	jmp dbgx86Ui_show_ui_main_loop
	
dbgx86Ui_show_ui_handle_exit:
	mov byte [cs:dbgx86UiUserResumeType], DBGX86_UI_USER_RESUME_TYPE_TERMINATE
	jmp dbgx86Ui_show_ui_done
	
dbgx86Ui_show_ui_handle_continue:
	mov byte [cs:dbgx86UiUserResumeType], DBGX86_UI_USER_RESUME_TYPE_CONTINUE
	jmp dbgx86Ui_show_ui_done
	
dbgx86Ui_show_ui_handle_single_step:
	mov byte [cs:dbgx86UiUserResumeType], DBGX86_UI_USER_RESUME_TYPE_SINGLE_STEP
	jmp dbgx86Ui_show_ui_done
	
dbgx86Ui_show_ui_handle_step_over:
	mov byte [cs:dbgx86UiUserResumeType], DBGX86_UI_USER_RESUME_TYPE_STEP_OVER
	jmp dbgx86Ui_show_ui_done
	
dbgx86Ui_show_ui_handle_swap_displays:
	call dbgx86Ui_swap_virtual_displays
	jmp dbgx86Ui_show_ui_main_loop
	
dbgx86Ui_show_ui_handle_show_listing:
	call common_screenh_clear_hardware_screen
	call dbgx86Ui_show_listing
	call dbgx86Ui_draw_ui
	jmp dbgx86Ui_show_ui_main_loop

dbgx86Ui_show_ui_handle_show_breakpoints:
	call common_screenh_clear_hardware_screen
	call dbgx86Ui_show_breakpoints
	call dbgx86Ui_draw_ui
	jmp dbgx86Ui_show_ui_main_loop
	
dbgx86Ui_show_ui_handle_add_watch:
	call dbgx86Ui_watch_add
	call dbgx86Ui_draw_ui
	jmp dbgx86Ui_show_ui_main_loop
	
dbgx86Ui_show_ui_handle_show_memory:
	push ds
	push si
	mov si, word [cs:dbgx86UiHighlightedAddress]
	mov ds, word [cs:dbgx86BinarySeg]
	call common_memviewh_start
	pop si
	pop ds
	call dbgx86Ui_draw_ui
	jmp dbgx86Ui_show_ui_main_loop	
	
dbgx86Ui_show_ui_done:
	mov ax, word [cs:dbgx86WatchedProgramTaskId]
	mov word [cs:dbgx86UiCurrentVirtualDisplayTaskId], ax
	int 96h					; make virtual display of watched program active

dbgx86Ui_show_ui_after_display_restoration:
	pop es
	pop ds
	popf
	popa
	mov al, byte [cs:dbgx86UiUserResumeType]
	ret

	
; Draws the UI
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_ui:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	call common_screenh_clear_hardware_screen
	
	call dbgx86Ui_draw_decorations
	call dbgx86Ui_draw_register_box
	call dbgx86Ui_draw_stack_box
	call dbgx86Ui_draw_flags_box
	call dbgx86Ui_draw_dssi_box
	call dbgx86Ui_draw_watch_box
	call dbgx86Ui_draw_source_area
	
	mov bh, COMMON_SCREEN_HEIGHT - 1
	mov bl, 0
	call common_screenh_move_hardware_cursor

	mov si, dbgx86UiMessageUiInstructions
	int 80h
	
	pop es
	pop ds
	popa
	ret


; Draws the flags box
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_flags_box:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov bh, DBGX86_FLAGS_BOX_TOP
	mov bl, DBGX86_FLAGS_BOX_LEFT
	mov ah, DBGX86_FLAGS_BOX_HEIGHT
	mov al, DBGX86_FLAGS_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiFlagsBoxTitle
	call common_draw_boxh_title

	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagCarry
	int 80h
	mov ax, DBGX86_FLAG_MASK_CARRY
	call dbgx86Ui_get_flag_status_string
	int 80h

	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP + 1
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagSign
	int 80h
	mov ax, DBGX86_FLAG_MASK_SIGN
	call dbgx86Ui_get_flag_status_string
	int 80h
	
	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP + 2
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagZero
	int 80h
	mov ax, DBGX86_FLAG_MASK_ZERO
	call dbgx86Ui_get_flag_status_string
	int 80h
	
	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP + 3
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagOverflow
	int 80h
	mov ax, DBGX86_FLAG_MASK_OVERFLOW
	call dbgx86Ui_get_flag_status_string
	int 80h
	
	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP + 4
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagAdjust
	int 80h
	mov ax, DBGX86_FLAG_MASK_ADJUST
	call dbgx86Ui_get_flag_status_string
	int 80h
	
	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP + 5
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagParity
	int 80h
	mov ax, DBGX86_FLAG_MASK_PARITY
	call dbgx86Ui_get_flag_status_string
	int 80h
	
	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP + 6
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagDirection
	int 80h
	mov ax, DBGX86_FLAG_MASK_DIRECTION
	call dbgx86Ui_get_flag_status_string
	int 80h
	
	mov bh, DBGX86_FLAGS_BOX_FIRST_REG_TOP + 7
	mov bl, DBGX86_FLAGS_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFlagInterrupt
	int 80h
	mov ax, DBGX86_FLAG_MASK_INTERRUPT
	call dbgx86Ui_get_flag_status_string
	int 80h
	
	pop es
	pop ds
	popa
	ret


; Returns a string which indicates whether the specified flag is 
; set or not.
; The string is meant to be user-readable.
;
; input:
;		AX - flag mask (only pertinent bit set)
; output:
;		SI - near pointer to string representing flag status
dbgx86Ui_get_flag_status_string:
	push bx
	
	push cs
	pop ds
	mov si, dbgx86UiFlagOnString			; assume on
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
	mov bx, word [ss:bx]					; BX := flags
	and bx, ax
	jnz dbgx86Ui_get_flag_status_string_done
	; it's off
	mov si, dbgx86UiFlagOffString
dbgx86Ui_get_flag_status_string_done:
	pop bx
	ret


; Draws the register box
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_register_box:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov bh, DBGX86_REG_BOX_TOP
	mov bl, DBGX86_REG_BOX_LEFT
	mov ah, DBGX86_REG_BOX_HEIGHT
	mov al, DBGX86_REG_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiRegistersBoxTitle
	call common_draw_boxh_title
	
	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiAx
	int 80h
	mov ax, word [cs:dbgx86HaltReturnAX]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiBx
	int 80h
	mov ax, word [cs:dbgx86HaltReturnBX]
	call common_hex_print_word_to_hardware

	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP + 1
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiCx
	int 80h
	mov ax, word [cs:dbgx86HaltReturnCX]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiDx
	int 80h
	mov ax, word [cs:dbgx86HaltReturnDX]
	call common_hex_print_word_to_hardware
	
	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP + 2
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiDs
	int 80h
	mov ax, word [cs:dbgx86HaltReturnDS]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiSi
	int 80h
	mov ax, word [cs:dbgx86HaltReturnSI]
	call common_hex_print_word_to_hardware
	
	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP + 3
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiEs
	int 80h
	mov ax, word [cs:dbgx86HaltReturnES]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiDi
	int 80h
	mov ax, word [cs:dbgx86HaltReturnDI]
	call common_hex_print_word_to_hardware
	
	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP + 4
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiSs
	int 80h
	mov ax, word [cs:dbgx86HaltReturnSS]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiSp
	int 80h
	mov ax, word [cs:dbgx86HaltReturnSP]
	call common_hex_print_word_to_hardware
	
	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP + 5
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiCs
	int 80h
	mov ax, word [cs:dbgx86HaltReturnCS]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiIp
	int 80h
	mov ax, word [cs:dbgx86UiHighlightedAddress]
	call common_hex_print_word_to_hardware
	
	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP + 6
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiBp
	int 80h
	mov ax, word [cs:dbgx86HaltReturnBP]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiFl
	int 80h
	mov bx, word [cs:dbgx86HaltReturnFlagsPtrOff]
	mov ax, word [ss:bx]
	call common_hex_print_word_to_hardware
	
	mov bh, DBGX86_REG_BOX_FIRST_REG_TOP + 7
	mov bl, DBGX86_REG_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiFs
	int 80h
	mov ax, word [cs:dbgx86HaltReturnFS]
	call common_hex_print_word_to_hardware
	mov si, dbgx86UiGs
	int 80h
	mov ax, word [cs:dbgx86HaltReturnGS]
	call common_hex_print_word_to_hardware
	
	pop es
	pop ds
	popa
	ret

	
; Draws the DS:SI box
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_dssi_box:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov bh, DBGX86_DSSI_BOX_TOP
	mov bl, DBGX86_DSSI_BOX_LEFT
	mov ah, DBGX86_DSSI_BOX_HEIGHT
	mov al, DBGX86_DSSI_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiDssiBoxTitle
	call common_draw_boxh_title

	mov bh, DBGX86_DSSI_BOX_FIRST_REG_TOP
	mov bl, DBGX86_DSSI_BOX_FIRST_REG_LEFT
	call common_screenh_move_hardware_cursor
	
	mov ds, word [cs:dbgx86HaltReturnDS]
	mov si, word [cs:dbgx86HaltReturnSI]	; DS:SI := pointer to bytes
	
	mov cx, DBGX86_DSSI_BOX_HEIGHT
dbgx86Ui_draw_dssi_box_loop:
	cmp cx, 0
	je dbgx86Ui_draw_dssi_box_loop_done
	
	push ds
	push si									; [1] save ptr to memory
	
	call dbgx86Ui_write_hex_ascii_line		; DS:SI := ptr to dumped line
	int 80h
	
	; next line
	inc bh									; cursor down
	mov bl, DBGX86_DSSI_BOX_FIRST_REG_LEFT	; cursor home
	call common_screenh_move_hardware_cursor
	
	dec cx									; one fewer lines to write
	
	pop si
	pop ds									; [1] restore ptr to memory
	add si, DBGX86_DSSI_BYTES_PER_LINE		; move pointer forward
	jmp dbgx86Ui_draw_dssi_box_loop
dbgx86Ui_draw_dssi_box_loop_done:
dbgx86Ui_draw_dssi_box_done:
	pop es
	pop ds
	popa
	ret
	
	
; Draws the stack box
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_stack_box:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov bh, DBGX86_STACK_BOX_TOP
	mov bl, DBGX86_STACK_BOX_LEFT
	mov ah, DBGX86_STACK_BOX_HEIGHT
	mov al, DBGX86_STACK_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiStackBoxTitle
	call common_draw_boxh_title

	; first entry location
	mov bh, DBGX86_STACK_BOX_FIRST_TOP
	mov bl, DBGX86_STACK_BOX_FIRST_LEFT
	
	; calculate number of entries	
	mov ax, word [cs:dbgx86HaltReturnSP]
	neg ax
	shr ax, 1			; 2 bytes per entry
	cmp ax, DBGX86_STACK_BOX_HEIGHT
	jbe dbgx86Ui_draw_stack_box_loop
	mov ax, DBGX86_STACK_BOX_HEIGHT
dbgx86Ui_draw_stack_box_loop:
	cmp ax, 0
	je dbgx86Ui_draw_stack_box_loop_done
	
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiStackBoxSegment
	int 80h
	
	push ax
	push bx
	shl ax, 1
	add ax, word [cs:dbgx86HaltReturnSP]
	sub ax, 2								; AX := (AX*2) + SP - 2
	call common_hex_print_word_to_hardware	; print offset
	mov si, dbgx86UiStackBoxCloseBracket
	int 80h
	
	mov bx, ax
	mov ax, word [ss:bx]					; AX := word on stack
	call common_hex_print_word_to_hardware	; print value
	pop bx
	pop ax
	
	dec bh
	dec ax
	jmp dbgx86Ui_draw_stack_box_loop
dbgx86Ui_draw_stack_box_loop_done:
	; draw marker to indicate stack top
	cmp bh, DBGX86_STACK_BOX_FIRST_TOP
	jae dbgx86Ui_draw_stack_box_pad_upward_prepare	; stack is empty
	; draw marker
	inc bh									; move it down for now
	mov bl, DBGX86_STACK_BOX_LEFT + 1
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiStackBoxStackTopMarker
	int 80h
	dec bh									; move it back up
	
dbgx86Ui_draw_stack_box_pad_upward_prepare:
	; fill remaining rows (upward) with blank lines, erasing previous entries
	mov bl, DBGX86_STACK_BOX_LEFT + 1
dbgx86Ui_draw_stack_box_pad_upward:
	cmp bh, DBGX86_STACK_BOX_TOP
	jbe dbgx86Ui_draw_stack_box_done

	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiStackBoxEmptyEntry
	int 80h
	dec bh
	jmp dbgx86Ui_draw_stack_box_pad_upward
	
dbgx86Ui_draw_stack_box_done:
	pop es
	pop ds
	popa
	ret
	

; Draws the section of the screen which shows the instruction
; on which the debugger is halted
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_source_area:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	; highlight first line
	mov bh, 1
	mov bl, 0
	call common_screenh_move_hardware_cursor
	mov cx, DBGX86_SCR_WIDTH
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_BLUE | COMMON_FONT_BRIGHT
	call common_screenh_write_attr
	
	; clear source area
	mov cx, DBGX86_SCR_WIDTH * DBGX86UI_SOURCE_AREA_HEIGHT
dbgx86Ui_draw_source_area_loop:
	mov si, dbgx86UiBlankSpace
	int 80h
	loop dbgx86Ui_draw_source_area_loop

	mov bh, 1
	mov bl, 0
	call common_screenh_move_hardware_cursor
	
	mov ax, word [cs:dbgx86UiHighlightedAddress]
	call dbgx86Listing_get_pointer_to_address	; DS:SI := pointer to line
	cmp ax, 0
	jne dbgx86Ui_draw_source_area_found_listing_line
	; address was not found in listing
	push cs
	pop ds
	mov si, dbgx86UiListingDoesntContainAddress
	int 80h
	jmp dbgx86Ui_draw_source_area_done

dbgx86Ui_draw_source_area_found_listing_line:
	; we're listing at least one line
	mov cx, DBGX86UI_SOURCE_AREA_HEIGHT + 1		; we DEC immediately
dbgx86Ui_draw_source_area_found_listing_line_loop:
	dec cx
	jz dbgx86Ui_draw_source_area_done	; we've written enough lines
	; here, DS:SI = pointer to line in listing
	push ds
	push si						; [1] save pointer to line in listing
	
	call dbgx86Ui_copy_line		; DS:SI := pointer to string of just line
	
	mov al, byte [ds:si+0]
	mov byte [cs:dbgx86UiAddressCheckBuffer+0], al
	mov al, byte [ds:si+1]
	mov byte [cs:dbgx86UiAddressCheckBuffer+1], al
	mov al, byte [ds:si+2]
	mov byte [cs:dbgx86UiAddressCheckBuffer+2], al
	mov al, byte [ds:si+3]
	mov byte [cs:dbgx86UiAddressCheckBuffer+3], al
	
	push ds
	push si									; [2] save	
	push cs
	pop ds
	mov si, dbgx86UiAddressCheckBuffer		; DS:SI := address check buffer
	call dbgx86Util_is_hex_number_string	
	pop si
	pop ds									; [2] restore
	cmp ax, 0				; not an address-preceded line, so no breakpoint
	je dbgx86Ui_draw_source_area_line_is_not_breakpointed
	; line starts with an address
	push ds
	push si									; [3] save	
	push cs
	pop ds
	mov si, dbgx86UiAddressCheckBuffer		; DS:SI := address check buffer
	call dbgx86Util_hex_atoi				; AX := address of this line
	pop si
	pop ds									; [3] restore
	
	mov dx, ax									; save in DX
	call dbgx86Breakpoints_get_handle_by_address	; AX := handle
	jc dbgx86Ui_draw_source_area_line_is_not_breakpointed
	
	call dbgx86Breakpoints_get_type				; BL := type
	cmp bl, BK_TYPE_USER_SET					; we only show user breakpoints
	jne dbgx86Ui_draw_source_area_line_is_not_breakpointed
	
	call dbgx86Breakpoints_get_address			; BX := breakpoint address
	cmp bx, dx									; is this line breakpointed?
	jne dbgx86Ui_draw_source_area_line_is_not_breakpointed	; no
	; this line is breakpointed, so we display a marker

	pusha
	call common_screenh_get_cursor_position
	add bl, 4								; move past address
	call common_screenh_move_hardware_cursor
	mov cx, 1
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_RED
	call common_screenh_write_attr			; breakpoint marker
	sub bl, 4								; restore cursor location
	call common_screenh_move_hardware_cursor
	popa
	
dbgx86Ui_draw_source_area_line_is_not_breakpointed:
dbgx86Ui_draw_source_area_write_line:
	; here, DS:SI = pointer to just a single line to write to screen
	int 80h
	
	pop si
	pop ds						; [1] restore pointer to line in listing
	call dbgx86Listing_move_to_next_line	; DS:SI := pointer to next line
	cmp ax, 0								; did we find another line?
	jne dbgx86Ui_draw_source_area_found_listing_line_loop	; yes
	; there wasn't another line
dbgx86Ui_draw_source_area_done:	
	pop es
	pop ds
	popa
	ret


; Draws decorations (borders, title, etc.)
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_decorations:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov bh, 0
	mov bl, 0
	call common_screenh_move_hardware_cursor
	; draw title bar
	mov cl, DBGX86_SCR_WIDTH
	mov si, TH_ASCII_LINE_HORIZONTAL_s
	mov ch, 0
dbgx86Ui_draw_decorations_title_bar:
	int 80h
	loop dbgx86Ui_draw_decorations_title_bar
	
	; write title
	mov bl, DBGX86_SCR_WIDTH / 2 - (dbgx86TitleStringEnd - dbgx86TitleString) / 2 - 2
	mov si, dbgx86TitleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_boxh_title
	
	pop es
	pop ds
	popa
	ret
	

; Returns a pointer to a string containing only the line whose start
; was specified as part of the input
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;	 DS:SI - pointer to string containing just current line
dbgx86Ui_copy_line:
	push es
	push di
	push ax
	push bx
	push cx
	
	mov bx, 0
dbgx86Ui_copy_line_find_line_end:
	cmp bx, DBGX86_SCR_WIDTH + 2
	ja dbgx86Ui_copy_line_find_line_string_end
	
	cmp byte [ds:si], 0
	je dbgx86Ui_copy_line_find_line_string_end
	cmp byte [ds:si], 13
	jne dbgx86Ui_copy_line_find_line_end_next
	
	cmp byte [ds:si+1], 0
	je dbgx86Ui_copy_line_find_line_string_end
	cmp byte [ds:si+1], 10
	jne dbgx86Ui_copy_line_find_line_end_next
	; we reached new line characters
	mov byte [cs:dbgx86UiLineCopyBuffer+bx+0], 13
	mov byte [cs:dbgx86UiLineCopyBuffer+bx+1], 10
	add bx, 2
	jmp dbgx86Ui_copy_line_find_line_string_end
dbgx86Ui_copy_line_find_line_end_next:
	; accumulate this character
	mov al, byte [ds:si]
	mov byte [cs:dbgx86UiLineCopyBuffer+bx], al
	inc si
	inc bx
	jmp dbgx86Ui_copy_line_find_line_end
	
dbgx86Ui_copy_line_find_line_string_end:
	mov byte [cs:dbgx86UiLineCopyBuffer+bx], 0		; terminator
	push cs
	pop ds
	mov si, dbgx86UiLineCopyBuffer					; return pointer in DS:SI
dbgx86Ui_copy_line_got_length_done:
	pop cx
	pop bx
	pop ax
	pop di
	pop es
	ret

	
; Potentially converts the provided character so that it can be printed.
; Such characters include backspace, line feed, etc.
;
; input:
;		AL - character to convert to printable
; output:
;		AL - printable character
dbgx85Ui_convert_non_printable_char:
	cmp al, COMMON_ASCII_NULL
	je dbgx85Ui_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BELL
	je dbgx85Ui_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_BACKSPACE
	je dbgx85Ui_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_TAB
	je dbgx85Ui_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_LINE_FEED
	je dbgx85Ui_convert_non_printable_char_convert
	cmp al, COMMON_ASCII_CARRIAGE_RETURN
	je dbgx85Ui_convert_non_printable_char_convert
	
	ret
dbgx85Ui_convert_non_printable_char_convert:
	mov al, '.'
	ret
	
	
; Writes a single line of hex and ASCII by dumping from the specified
; memory address
;
; input:
;	 DS:SI - pointer to memory to dump
; output:
;	 DS:SI - pointer to string holding dumped memory, zero-terminated
dbgx86Ui_write_hex_ascii_line:
	push ax
	push bx
	push cx
	push dx
	push di
	push es

	push cs
	pop es
	mov di, dbgx86SingleLineBuffer

	; write hex
	mov bx, DBGX86_DSSI_BYTES_PER_LINE
	mov dx, 2				; options: add spacing, don't zero-terminate
	call common_hex_string_to_hex					; write
	add di, DBGX86_DSSI_BYTES_PER_LINE * 3			; advance ES:DI
	
	; write ASCII
	cld
	mov cx, DBGX86_DSSI_BYTES_PER_LINE
dbgx86Ui_write_hex_ascii_line_loop:
	lodsb
	call dbgx85Ui_convert_non_printable_char
	stosb
	loop dbgx86Ui_write_hex_ascii_line_loop
	
	mov byte [es:di], 0				; terminate line	
	
	mov si, dbgx86SingleLineBuffer
	push es
	pop ds							; return result in DS:SI
	
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret


; Swaps between the virtual displays of debugger and watched program
;
; input:
;		none
; output:
;		none
dbgx86Ui_swap_virtual_displays:
	pusha
	
	mov ax, word [cs:dbgx86UiCurrentVirtualDisplayTaskId]
	cmp ax, word [cs:dbgx86DebuggerTaskId]
	jne dbgx86Ui_swap_virtual_displays_to_debugger
	; watched program's virtual display is becoming active
	mov ax, word [cs:dbgx86WatchedProgramTaskId]
	mov word [cs:dbgx86UiCurrentVirtualDisplayTaskId], ax
	int 96h					; make virtual display of watched program active
	
	jmp dbgx86Ui_swap_virtual_displays_done
dbgx86Ui_swap_virtual_displays_to_debugger:
	; debugger's virtual display is becoming active
	mov ax, word [cs:dbgx86DebuggerTaskId]
	mov word [cs:dbgx86UiCurrentVirtualDisplayTaskId], ax
	int 96h						; make virtual display of debugger active
dbgx86Ui_swap_virtual_displays_done:
	popa
	ret

	
; Shows the entire listing to the user
;
; input:
;		none
; output:
;		none
dbgx86Ui_show_listing:
	pusha
	push ds
	
	mov ds, word [cs:dbgx86ListingSeg]
	mov si, word [cs:dbgx86ListingOff]
	int 0A5h							; BX := string length
	mov cx, bx
	mov ax, 1							; options: wait on user at end of file
	call common_viewtxth_view_paged
	
	pop ds
	popa
	ret
	

; Displays and runs the breakpoint management UI
;
; input:
;		none
; output:
;		none	
dbgx86Ui_show_breakpoints:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	call dbgx86Ui_draw_breakpoints				; draw UI
	
	int 83h										; clear keyboard buffer
dbgx86Ui_show_breakpoints_read_input:
	hlt
	mov ah, 1
	int 16h 									; any key pressed?
	jz dbgx86Ui_show_breakpoints_read_input 	; no
	
	mov ah, 0
	int 16h										; AH := scan code

	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je dbgx86Ui_show_breakpoints_handle_exit
	
	cmp ah, COMMON_SCAN_CODE_A
	je dbgx86Ui_show_breakpoints_handle_add
	
	cmp ah, COMMON_SCAN_CODE_D
	je dbgx86Ui_show_breakpoints_handle_delete
	
	cmp ah, COMMON_SCAN_CODE_L
	je dbgx86Ui_show_breakpoints_handle_listing
	
	cmp ah, COMMON_SCAN_CODE_M
	je dbgx86Ui_show_breakpoints_handle_memory

dbgx86Ui_show_breakpoints_read_input_after_key_checks:
	jmp dbgx86Ui_show_breakpoints_read_input

dbgx86Ui_show_breakpoints_handle_delete:
	call dbgx86Ui_breakpoint_remove
	call common_screenh_clear_hardware_screen
	call dbgx86Ui_draw_breakpoints				; draw UIs
	jmp dbgx86Ui_show_breakpoints_read_input
	
dbgx86Ui_show_breakpoints_handle_add:
	call dbgx86Ui_breakpoint_add
	call common_screenh_clear_hardware_screen
	call dbgx86Ui_draw_breakpoints				; draw UI
	jmp dbgx86Ui_show_breakpoints_read_input
	
dbgx86Ui_show_breakpoints_handle_listing:
	call common_screenh_clear_hardware_screen
	call dbgx86Ui_show_listing
	call dbgx86Ui_draw_breakpoints				; draw UI
	jmp dbgx86Ui_show_breakpoints_read_input
	
dbgx86Ui_show_breakpoints_handle_memory:
	push ds
	push si
	mov si, word [cs:dbgx86UiHighlightedAddress]
	mov ds, word [cs:dbgx86BinarySeg]
	call common_memviewh_start
	pop si
	pop ds
	call dbgx86Ui_draw_breakpoints				; draw UI
	jmp dbgx86Ui_show_breakpoints_read_input
	
dbgx86Ui_show_breakpoints_handle_exit:
	jmp dbgx86Ui_show_breakpoints_done
	
dbgx86Ui_show_breakpoints_done:
	pop es
	pop ds
	popa
	ret


; Displays the breakpoint management UI
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_breakpoints:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	call common_screenh_clear_hardware_screen
	
	mov bh, 0
	mov bl, 0
	call common_screenh_move_hardware_cursor
	; draw title bar
	mov cl, DBGX86_SCR_WIDTH
	mov si, TH_ASCII_LINE_HORIZONTAL_s
	mov ch, 0
dbgx86Ui_draw_breakpoints_title_bar:
	int 80h
	loop dbgx86Ui_draw_breakpoints_title_bar
	
	; write title
	mov bl, DBGX86_SCR_WIDTH / 2 - (dbgx86BreakpointsStringEnd - dbgx86BreakpointsString) / 2 - 2
	mov si, dbgx86BreakpointsString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_boxh_title

	; list box
	mov bh, DBGX86_BK_LIST_BOX_TOP
	mov bl, DBGX86_BK_LIST_BOX_LEFT
	mov ah, DBGX86_BK_LIST_BOX_HEIGHT
	mov al, DBGX86_BK_LIST_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiBreakpointListBoxTitle
	call common_draw_boxh_title
	add bl, 12
	mov si, dbgx86UiBreakpointListBoxSeenTitle
	call common_draw_boxh_title
	
	; list active breakpoints
	call dbgx86Breakpoints_print_list

	; write instructions
	mov bh, COMMON_SCREEN_HEIGHT - 1
	mov bl, 0
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiBreakpointsUiPrompt
dbgx86Ui_draw_breakpoints_check_add:	
	call dbgx86Ui_breakpoints_can_add
	cmp ax, 0
	jne dbgx86Ui_draw_breakpoints_check_remove
	mov si, dbgx86UiBreakpointsUiPromptNoAdd
	jmp dbgx86Ui_draw_breakpoints_write_instructions
dbgx86Ui_draw_breakpoints_check_remove:
	call dbgx86Ui_breakpoints_can_remove
	cmp ax, 0
	jne dbgx86Ui_draw_breakpoints_write_instructions
	mov si, dbgx86UiBreakpointsUiPromptNoRemove
dbgx86Ui_draw_breakpoints_write_instructions:
	; here, DS:SI points to a message, according to what's possible
	int 80h
	
	pop es
	pop ds
	popa
	ret
	

; Attempts to add a breakpoint
;
; input:
;		none
; output:
;		none
dbgx86Ui_breakpoint_add:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax

	call dbgx86Ui_breakpoints_can_add
	cmp ax, 0
	je dbgx86Ui_breakpoint_add_done			; NOOP when we can't add
	
	; box
	mov bh, DBGX86_BK_ADD_BOX_TOP
	mov bl, DBGX86_BK_ADD_BOX_LEFT
	mov ah, DBGX86_BK_ADD_BOX_HEIGHT
	mov al, DBGX86_BK_ADD_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiBreakpointAddBoxTitle
	call common_draw_boxh_title

	; instructions
	mov bh, DBGX86_BK_ADD_BOX_FIRST_TOP
	mov bl, DBGX86_BK_ADD_BOX_FIRST_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiBreakpointAddInstructions
	int 80h
	
	call dbgx86Ui_read_hex_from_user
	cmp ax, 0
	je dbgx86Ui_breakpoint_add_done

dbgx86Ui_breakpoint_add_got_address:
	mov ax, bx										; AX := breakpoint address
	mov dx, ax										; save it in DX
	call dbgx86Breakpoints_get_handle_by_address	; AX := handle
	jc dbgx86Ui_breakpoint_add_got_address__does_not_exist
dbgx86Ui_breakpoint_add_got_address__exists:
	call dbgx86Breakpoints_set_type_user_set
	jmp dbgx86Ui_breakpoint_add_done

dbgx86Ui_breakpoint_add_got_address__does_not_exist:
	mov ax, dx										; AX := breakpoint address
	call dbgx86Breakpoints_add_breakpoint_by_address	; BX := handle

dbgx86Ui_breakpoint_add_done:
	pop es
	pop ds
	popa
	ret

	
; Checks whether a breakpoint can be removed
;
; input:
;		none
; output:
;		AX - 0 when a breakpoint cannot be removed, other value otherwise
dbgx86Ui_breakpoints_can_remove:
	push cx
	
	call dbgx86Breakpoints_count_user_set		; CX := number of breakpoints
	cmp cx, 0
	je dbgx86Ui_breakpoints_can_remove_no
	
	mov ax, 1
	jmp dbgx86Ui_breakpoints_can_remove_done
dbgx86Ui_breakpoints_can_remove_no:
	mov ax, 0
dbgx86Ui_breakpoints_can_remove_done:
	pop cx
	ret
	

; Checks whether a breakpoint can be added
;
; input:
;		none
; output:
;		AX - 0 when a breakpoint cannot be added, other value otherwise
dbgx86Ui_breakpoints_can_add:
	push cx
	
	call dbgx86Breakpoints_count_user_set		; CX := number of breakpoints
	cmp cx, DBGX86_BK_LIST_BOX_HEIGHT
	jae dbgx86Ui_breakpoints_can_add_no
	
	mov ax, 1
	jmp dbgx86Ui_breakpoints_can_add_done
dbgx86Ui_breakpoints_can_add_no:
	mov ax, 0
dbgx86Ui_breakpoints_can_add_done:
	pop cx
	ret
	
	
; Attempts to remove a breakpoint
;
; input:
;		none
; output:
;		none
dbgx86Ui_breakpoint_remove:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax

	call dbgx86Ui_breakpoints_can_remove
	cmp ax, 0
	je dbgx86Ui_breakpoint_remove_done		; NOOP when we can't remove
	
	; box
	mov bh, DBGX86_BK_REMOVE_BOX_TOP
	mov bl, DBGX86_BK_REMOVE_BOX_LEFT
	mov ah, DBGX86_BK_REMOVE_BOX_HEIGHT
	mov al, DBGX86_BK_REMOVE_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiBreakpointRemoveBoxTitle
	call common_draw_boxh_title

	; instructions
	mov bh, DBGX86_BK_REMOVE_BOX_FIRST_TOP
	mov bl, DBGX86_BK_REMOVE_BOX_FIRST_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiBreakpointRemoveInstructions
	int 80h
	
	call dbgx86Ui_read_hex_from_user
	cmp ax, 0
	je dbgx86Ui_breakpoint_remove_done

dbgx86Ui_breakpoint_remove_got_address:
	mov ax, bx										; AX := breakpoint address
	call dbgx86Breakpoints_get_handle_by_address	; AX := handle
	jc dbgx86Ui_breakpoint_remove_done				; NOOP when not found
	
	call dbgx86Breakpoints_get_type					; BL := type
	cmp bl, BK_TYPE_USER_SET
	jne dbgx86Ui_breakpoint_remove_done				; can only remove user-set
	; remove breakpoint with handle AX
	call dbgx86Breakpoints_get_address				; BX := breakpoint address
	mov si, bx
	mov ds, word [cs:dbgx86BinarySeg]				; DS:SI := ptr to bkpt
	
	call dbgx86Breakpoints_get_displaced_byte		; BL := displaced byte
	mov byte [ds:si], bl							; restore displaced byte
	
	call dbgx86Breakpoints_delete

dbgx86Ui_breakpoint_remove_done:	
	pop es
	pop ds
	popa
	ret
	
	
; Attempts to add a watch
;
; input:
;		none
; output:
;		none
dbgx86Ui_watch_add:
	pusha
	push ds
	push es

	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; box
	mov bh, DBGX86_WATCH_ADD_BOX_TOP
	mov bl, DBGX86_WATCH_ADD_BOX_LEFT
	mov ah, DBGX86_WATCH_ADD_BOX_HEIGHT
	mov al, DBGX86_WATCH_ADD_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	mov si, dbgx86UiWatchAddBoxTitle
	call common_draw_boxh_title

	; erase existing contents
	mov bh, DBGX86_WATCH_ADD_BOX_FIRST_TOP
	mov bl, DBGX86_WATCH_ADD_BOX_LEFT + 1
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiWatchAddErase
	int 80h

	; instructions
	mov bh, DBGX86_WATCH_ADD_BOX_FIRST_TOP
	mov bl, DBGX86_WATCH_ADD_BOX_FIRST_LEFT
	call common_screenh_move_hardware_cursor
	mov si, dbgx86UiWatchAddInstructions
	int 80h
	
	call dbgx86Ui_read_hex_from_user
	cmp ax, 0
	je dbgx86Ui_watch_add_done

dbgx86Ui_watch_add_got_address:
	mov ax, bx								; AX := memory address to watch
	call dbgx86Watch_set
	
	; copy 4-digit hex address into title string, so we show it on the title
	xchg ah, al								; humans read MSB first
	mov di, dbgx86UiWatchShowPopulatedBoxTitleInsertionPoint
	mov dx, 0						; don't zero-terminate, don't pad spaces
	call common_hex_word_to_hex

dbgx86Ui_watch_add_done:
	pop es
	pop ds
	popa
	ret
	
	
; Draws the watched memory box 
;
; input:
;		none
; output:
;		none
dbgx86Ui_draw_watch_box:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; box
	mov bh, DBGX86_WATCH_SHOW_BOX_TOP
	mov bl, DBGX86_WATCH_SHOW_BOX_LEFT
	mov ah, DBGX86_WATCH_SHOW_BOX_HEIGHT
	mov al, DBGX86_WATCH_SHOW_BOX_WIDTH
	call common_draw_boxh
	inc bl
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	call dbgx86Watch_is_set
	cmp ax, 0
	je dbgx86Ui_draw_watch_box_empty_title			; it's empty
	
	; it's not empty
	mov si, dbgx86UiWatchShowPopulatedBoxTitle
	call common_draw_boxh_title
	jmp dbgx86Ui_draw_watch_box_after_title

dbgx86Ui_draw_watch_box_empty_title:
	; it's empty
	mov si, dbgx86UiWatchShowEmptyBoxTitle
	call common_draw_boxh_title

dbgx86Ui_draw_watch_box_after_title:
	mov bh, DBGX86_WATCH_SHOW_BOX_FIRST_TOP
	mov bl, DBGX86_WATCH_SHOW_BOX_FIRST_LEFT
	call common_screenh_move_hardware_cursor
	
	call dbgx86Watch_is_set
	cmp ax, 0
	jne dbgx86Ui_draw_watch_box_values
	
	mov si, dbgx86UiWatchNoneSet
	int 80h
		
	jmp dbgx86Ui_draw_watch_box_done
dbgx86Ui_draw_watch_box_values:
	; values
	mov ds, word [cs:dbgx86BinarySeg]
	call dbgx86Watch_get
	mov si, ax								; DS:SI := pointer to bytes
	
	mov cx, DBGX86_WATCH_SHOW_BOX_HEIGHT
dbgx86Ui_draw_watch_box_loop:
	cmp cx, 0
	je dbgx86Ui_draw_watch_box_loop_done
	
	push ds
	push si									; [1] save ptr to memory
	
	call dbgx86Ui_write_hex_ascii_line		; DS:SI := ptr to dumped line
	int 80h
	
	; next line
	inc bh										; cursor down
	mov bl, DBGX86_WATCH_SHOW_BOX_FIRST_LEFT	; cursor home
	call common_screenh_move_hardware_cursor
	
	dec cx									; one fewer lines to write
	
	pop si
	pop ds									; [1] restore ptr to memory
	add si, DBGX86_WATCH_SHOW_BYTES_PER_LINE		; move pointer forward
	jmp dbgx86Ui_draw_watch_box_loop
dbgx86Ui_draw_watch_box_loop_done:
	
dbgx86Ui_draw_watch_box_done:
	pop es
	pop ds
	popa
	ret
	

; Attempts to read a hex number from the user
;
; input:
;		none
; output:
;		AX - 0 when user did not entered a valid hex number, other value 
;			 otherwise
;		BX - value read from user
dbgx86Ui_read_hex_from_user:
	push cx
	push dx
	push si
	push di
	push ds
	push es
	
	mov cx, 4					; maximum of 4 hex digits for address
	mov di, dbgx86UiUserEnteredAddressBuffer
	call common_input_read_user_line_h
	mov si, di
	call dbgx86Util_is_hex_number_string
	cmp ax, 0
	je dbgx86Ui_read_hex_from_user_done		; not a hex string
	
	call dbgx86Util_hex_atoi				; AX := numeric value
	mov bx, ax								; return it in BX
	mov ax, 1								; success

dbgx86Ui_read_hex_from_user_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	ret

	
%endif
