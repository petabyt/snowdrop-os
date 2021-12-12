;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The DESKTOP app.
; This app is intended to be the entry point into using various GUI
; applications.
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

MAX_STACK			equ 1000

LIST_HEAD_PTR_LEN		equ COMMON_LLIST_HEAD_PTR_LENGTH
LIST_HEAD_PTR_INITIAL	equ COMMON_LLIST_HEAD_PTR_INITIAL
; this list holds entities
appsHeadPtr:	times LIST_HEAD_PTR_LEN db LIST_HEAD_PTR_INITIAL
				; byte
				; 0 - 1        ID of application
				; 2 - 14       8.3 file name, zero-terminated
				; 15 - 26      FAT12 file name, zero-terminated
				; 27 - 28      icon ID
PAYLOAD_SIZE	equ 29
appPayloadBuffer:	times PAYLOAD_SIZE db 0

currentAppId:		dw 0

titleString:		db 'Snowdrop OS Desktop', 0

INSTRUCTIONS_X		equ 10
INSTRUCTIONS_Y		equ 450
instructions1:		db 'Shortcuts:', 0
instructions2:		db '            ALT-TAB switches task', 0
instructions3:		db '            CTRL-Q exits current task', 0


noticeLoadingApp:		db 'Starting application...', 0
noticeShutdown:			db 'Power off failed', 0
noticeReboot:			db 'Reboot failed', 0
noticeNoMemoryForFile:	db 'Not enough memory to load file', 0
noticeFileNotFound		db 'File not found', 0

buttonShutdown:		db 'Power Off', 0
SHUTDOWN_BUTTON_X	equ COMMON_GRAPHICS_SCREEN_WIDTH - 86
SHUTDOWN_BUTTON_Y	equ COMMON_GRAPHICS_SCREEN_HEIGHT - 20

buttonReboot:		db 'Reboot', 0
REBOOT_BUTTON_X		equ COMMON_GRAPHICS_SCREEN_WIDTH - 146
REBOOT_BUTTON_Y		equ COMMON_GRAPHICS_SCREEN_HEIGHT - 20

fargs:	db '', 0

configFileSeg:		dw 0
configFileOff:		dw 0		; pointer to config file buffer
CONFIG_FILE_MAX_SIZE		equ 4096 + 512
configFileSize:		dw 0

stepInitial:			db 'Starting DESKTOP', 13, 10, 0
stepInitDynMem:			db 'Initialized dynamic memory', 13, 10, 0
stepAllocatedConfig:	db 'Allocated memory for config file', 13, 10, 0
stepLoadedConfig:		db 'Loaded config file', 13, 10, 0

errorNoMemory:		db 'Failed to initialize dynamic memory, or not enough memory available', 13, 10, 0
errorNoConfig:		db 'Configuration file not found', 13, 10, 0
errorPressAKey:		db 'Press a key to exit', 13, 10, 0

configFAT12Filename:	db 'DESKTOP CFG', 0

appCount:			dw 0
paramAppCount:		db 'appcount', 0
paramApp:			db 'appXXXXXXXX', 0

PARAM_VALUE_MAX_LENGTH 		equ CONFIG_PARAM_VALUE_MAX_LENGTH
paramValueBuffer:			times PARAM_VALUE_MAX_LENGTH+1 db 0
paramParsedTokenBuffer:		times PARAM_VALUE_MAX_LENGTH+1 db 0

currentLoadedAppX:		dw 0
currentLoadedAppY:		dw 0

paramAllowExit:		db 'allowexit', 0
allowExit:			dw 1

FAILURE_DELAY		equ 200


start:
	mov si, stepInitial
	int 80h
	
	; initialize dynamic memory - this is required by GUI extensions
	mov si, allocatableMemoryStart
	mov ax, 65535 - MAX_STACK
	sub ax, allocatableMemoryStart
	call common_memory_initialize
	cmp ax, 0
	je no_memory
	mov si, stepInitDynMem
	int 80h
	
	; allocate memory for config file
	push ds
	mov ax, CONFIG_FILE_MAX_SIZE
	call common_memory_allocate
	mov word [cs:configFileSeg], ds
	mov word [cs:configFileOff], si
	pop ds
	cmp ax, 0
	je no_memory
	mov si, stepAllocatedConfig
	int 80h
	
	; initialize GUI framework extensions interface
	; this is required before any extensions can initialize
	call common_gx_initialize
	
	; initialize GUI framework extensions which we'll use here
	; they must be initialized before the GUI framework is prepared
	call common_gx_icon_initialize

	call common_gui_prepare					; must call this before any
											; other GUI framework functions
	
	; any long application initialization (e.g.: loading from disk, etc.)
	; should happen here, since the GUI framework has shown a "loading..."
	; notice
	
	; load config file
	push es
	mov si, configFAT12Filename
	mov es, word [cs:configFileSeg]
	mov di, word [cs:configFileOff]
	int 81h				; AL := 0 when successful
	mov word [cs:configFileSize], cx
	pop es
	cmp al, 0
	jne no_config
	
	; read property that tells us if we allow user to exit
	mov word [cs:allowExit], 1					; default to "yes" 
												; in case property not present
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov si, paramAllowExit
	mov di, paramValueBuffer
	mov fs, word [cs:configFileSeg]
	mov dx, word [cs:configFileOff]
	mov cx, word [cs:configFileSize]
	call common_config_get_parameter_value
	cmp ax, 0
	je after_allow_exit_read					; not found
	mov si, paramValueBuffer
	call common_string_signed_16bit_int_atoi	; AX := numeric value
	mov word [cs:allowExit], ax					; store
after_allow_exit_read:
	cmp word [cs:allowExit], 0
	jne after_allow_exit_configure
	; allow exit is 0
	call common_gui_disallow_exit
after_allow_exit_configure:	
	
	; set application title
	mov si, titleString						; DS:SI := pointer to title string
	call common_gui_title_set										
	
	; set up the initialized callback, which is invoked by the GUI framework
	; right after it has initialized itself
	mov si, initialized_callback
	call common_gui_initialized_callback_set
	
	mov si, on_refresh_callback
	call common_gui_on_refresh_callback_set	; we need to know when the GUI
											; framework refreshes the screen
											; so we draw our custom things

	; yield control permanently to the GUI framework
	call common_gui_start
	; the function above does not return control to the caller

no_memory:
	push cs
	pop ds
	mov si, errorNoMemory
	jmp print_error_and_exit
	
no_config:
	call common_gui_premature_shutdown
	push cs
	pop ds
	mov si, errorNoConfig
	jmp print_error_and_exit
	
print_error_and_exit:
	int 80h
	mov si, errorPressAKey
	int 80h
	mov ah, 0
	int 16h
	int 95h						; exit


; Draws a message on the screen
;
; input:
;		none
; output:
;		none	
draw_message:
	pusha
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	
	mov bx, INSTRUCTIONS_X				; position X
	mov ax, INSTRUCTIONS_Y				; position Y
	mov dx, 0							; options
	call common_gui_get_colour_decorations	; CX := colour
	
	mov si, instructions1				; DS:SI := pointer to string
	call common_gui_util_print_single_line_text_with_erase	; draw text
	
	add ax, COMMON_GRAPHICS_FONT_HEIGHT
	mov si, instructions2				; DS:SI := pointer to string
	call common_gui_util_print_single_line_text_with_erase	; draw text
	
	add ax, COMMON_GRAPHICS_FONT_HEIGHT
	mov si, instructions3				; DS:SI := pointer to string
	call common_gui_util_print_single_line_text_with_erase	; draw text
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
draw_message_done:
	popa
	ret
	
	
; Loads a file into a new memory segment
;
; input:
;	 DS:SI - pointer to FAT12-formatted file name
; output:
;		AX - 0 when there was a failure
;		BX - segment into which the file was loaded
load_file:
	push cx
	push dx
	push si
	push di
	push es
	
	; allocate a segment
	int 91h				; BX := seg
	cmp ax, 0
	jne load_file_fail_no_memory
	
	mov es, bx
	mov di, 0
	int 81h				; AL := 0 when successful
	cmp al, 0
	jne load_file_fail_could_not_load_file
	
	mov ax, 1
	jmp load_file_done
load_file_fail_could_not_load_file:
	; here, BX = allocated segment
	int 92h				; free segment
	
	push cs
	pop ds
	mov si, noticeFileNotFound
	call common_gui_util_show_notice
	
	mov cx, FAILURE_DELAY
	int 85h				; delay in case we fail
	jmp load_file_fail
load_file_fail_no_memory:
	push cs
	pop ds
	mov si, noticeNoMemoryForFile
	call common_gui_util_show_notice
	
	mov cx, FAILURE_DELAY
	int 85h				; delay in case we fail
	jmp load_file_fail
load_file_fail:
	mov ax, 0
load_file_done:
	pop es
	pop di
	pop si
	pop dx
	pop cx
	ret
	

; Creates an icon which, when clicked, will load and run an application
;
; input:
;	 DS:SI - pointer to 8.3 file name
;		AX - position X
;		BX - position Y
; output:
;		none
create_icon:
	pusha
	push ds
	push es
	push fs
	
	push ax
	push bx						; [1]

	mov ax, cs
	mov es, ax
	mov fs, ax
	
	mov di, appPayloadBuffer
	add di, 15					; ES:DI := ptr to FAT12 offset
	int 0A6h					; fill in FAT12 name
	
	mov di, appPayloadBuffer
	add di, 2					; ES:DI := ptr to 8.3 offset
	call common_string_copy		; fill in 8.3 name

	mov di, appPayloadBuffer
	mov ax, word [cs:currentAppId]
	mov word [es:di+0], ax		; fill in app ID
	
	mov bx, appsHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, PAYLOAD_SIZE
	call common_llist_add		; DS:SI := new list element
	
	inc word [cs:currentAppId]
	
	; now make a GUI element from the newly-added list element
	
	pop bx
	pop ax						; [1] restore X, Y
	
	push si
	add si, 2					; DS:SI := ptr to 8.3 file name
	call common_gx_icon_add
	pop si

	mov word [ds:si+27], ax		; store icon ID in list element
	
	push cs
	pop ds
	mov si, icon_click_callback
	call common_gx_icon_click_callback_set
	
	pop fs
	pop es
	pop ds
	popa
	ret
	

; Creates all icons defined in the config file
;
; input:
;		none
; output:
;		none	
create_all_icons:
	pusha
	push ds
	push es
	push fs
	push gs
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; read number of apps
	mov si, paramAppCount
	mov di, paramValueBuffer
	mov fs, word [cs:configFileSeg]
	mov dx, word [cs:configFileOff]
	mov cx, word [cs:configFileSize]
	call common_config_get_parameter_value
	cmp ax, 0
	je create_all_icons_fail_with_0_apps
	mov si, paramValueBuffer
	call common_string_signed_16bit_int_atoi	; AX := integer
	mov word [cs:appCount], ax
	
	cmp ax, 0
	je create_all_icons_apps_loop_done
create_all_icons_apps_loop:
	dec ax										; app numbers are 0-based
	call read_param_and_create_icon
	cmp ax, -1
	jg create_all_icons_apps_loop
create_all_icons_apps_loop_done:
	
	jmp create_all_icons_done
create_all_icons_fail_with_0_apps:
	mov word [cs:appCount], 0
	
create_all_icons_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret
	

; Creates an icon by reading a config parameter containing 
; the specified app ID
;
; input:
;		AX - app number
; output:
;		none	
read_param_and_create_icon:
	pusha
	push ds
	push es
	push fs
	push gs
	
	mov dx, cs
	mov ds, dx
	mov es, dx
	
	; build parameter name from prefix and number
	mov si, paramApp
	add si, 3									; move it to right past prefix
	call common_string_signed_16bit_int_itoa	; fill in number

	; read app parameter
	mov si, paramApp
	mov di, paramValueBuffer
	mov fs, word [cs:configFileSeg]
	mov dx, word [cs:configFileOff]
	mov cx, word [cs:configFileSize]
	call common_config_get_parameter_value
	cmp ax, 0
	je read_param_and_create_icon_done
	
	; break up parameter value into tokens
	mov si, paramValueBuffer
	mov di, paramParsedTokenBuffer
	
	; read X
	call common_config_read_token	; AX - 0 when no more tokens to read
									;      1 when a token was read (success)
									;      2 when there was an error
	cmp ax, 0
	je read_param_and_create_icon_done				; not enough tokens
	cmp ax, 2
	je read_param_and_create_icon_done				; error
	; store X
	xchg si, di
	call common_string_signed_16bit_int_atoi	; AX := integer
	mov word [cs:currentLoadedAppX], ax
	xchg si, di

	; read delimiter
	call common_config_read_token	; AX - 0 when no more tokens to read
									;      1 when a token was read (success)
									;      2 when there was an error
	cmp ax, 0
	je read_param_and_create_icon_done				; not enough tokens
	cmp ax, 2
	je read_param_and_create_icon_done				; error

	; read Y
	call common_config_read_token	; AX - 0 when no more tokens to read
									;      1 when a token was read (success)
									;      2 when there was an error
	cmp ax, 0
	je read_param_and_create_icon_done				; not enough tokens
	cmp ax, 2
	je read_param_and_create_icon_done				; error
	; store Y
	xchg si, di
	call common_string_signed_16bit_int_atoi	; AX := integer
	mov word [cs:currentLoadedAppY], ax
	xchg si, di

	; read delimiter
	call common_config_read_token	; AX - 0 when no more tokens to read
									;      1 when a token was read (success)
									;      2 when there was an error
	cmp ax, 0
	je read_param_and_create_icon_done				; not enough tokens
	cmp ax, 2
	je read_param_and_create_icon_done				; error

	; read app name
	call common_config_read_token	; AX - 0 when no more tokens to read
									;      1 when a token was read (success)
									;      2 when there was an error
	cmp ax, 0
	je read_param_and_create_icon_done				; not enough tokens
	cmp ax, 2
	je read_param_and_create_icon_done				; error
	
	mov si, di							; DS:SI := ptr to 8.3 app name
	mov ax, word [cs:currentLoadedAppX]
	mov bx, word [cs:currentLoadedAppY]
	call create_icon
read_param_and_create_icon_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret
	

;==============================================================================
; Callbacks
;==============================================================================

; Called by the GUI framework after it has initialized itself
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
initialized_callback:
	call create_all_icons
	
	mov si, buttonShutdown
	mov ax, SHUTDOWN_BUTTON_X
	mov bx, SHUTDOWN_BUTTON_Y
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov si, shut_down_click_callback
	call common_gui_button_click_callback_set
	
	mov si, buttonReboot
	mov ax, REBOOT_BUTTON_X
	mov bx, REBOOT_BUTTON_Y
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov si, reboot_click_callback
	call common_gui_button_click_callback_set
	
	retf


; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
shut_down_click_callback:
	mov ax, 0			; power off function
	int 9Bh
	
	push cs
	pop ds
	mov si, noticeShutdown
	call common_gui_util_show_notice
	
	mov cx, FAILURE_DELAY
	int 85h				; delay in case we fail
	
	call common_gui_redraw_screen
	retf
	

; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
reboot_click_callback:
	mov ax, 1			; reboot function
	int 9Bh
	
	push cs
	pop ds
	mov si, noticeReboot
	call common_gui_util_show_notice
	
	mov cx, FAILURE_DELAY
	int 85h				; delay in case we fail
	
	call common_gui_redraw_screen
	retf


; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
icon_click_callback:
	; find entry by handle
	push cs
	pop fs
	mov bx, appsHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, PAYLOAD_SIZE
	mov si, 27							; search at this offset
	mov dx, ax							; value to search
	call common_llist_find_by_word		; DS:SI := element
										; AX := 0 when not found
	cmp ax, 0
	je icon_click_callback_done

	push ds
	push si
	push cs
	pop ds
	mov si, noticeLoadingApp
	call common_gui_util_show_notice
	pop si
	pop ds
	
	; here, DS:SI = ptr to entry
	add si, 15					; DS:SI := ptr to FAT12 filename
	call load_file
	
	call common_gui_redraw_screen
	
	cmp ax, 0
	je icon_click_callback_done			; error

	mov si, fargs
	call common_gui_start_new_task
icon_click_callback_done:
	retf
	
	
; Callback for GUI framework's "on refresh". This will redraw anything custom
; we have to draw.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none	
on_refresh_callback:
	call draw_message
	retf


%include "common\vga640\gui\ext\gx.asm"				; must be included first

%include "common\vga640\gui\ext\gx_icon.asm"
%include "common\vga640\gui\gui.asm"
%include "common\memory.asm"
%include "common\string.asm"
%include "common\config.asm"
%include "common\dynamic\linklist.asm"


allocatableMemoryStart:
