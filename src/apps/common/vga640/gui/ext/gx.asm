;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
;
; This is the main interface between the GUI framework and individual
; extensions.
; Its purpose is to accept registrations of various callbacks coming from
; individual extensions, and invoke them in turn.
;
; Thus, this interface opens the way to the creation of new GUI framework
; components that can optionally be included and used by a consumer
; application - without the need to modify the GUI framework itself.
;
; In a consumer application, this file MUST be included BEFORE gui.asm,
; directly or indirectly via an extension source file. Also, it must be
; initialized BEFORE any extensions are initialized.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_EXTENSIONS_
%define _COMMON_GUI_EXTENSIONS_

GX_LIST_HEAD_PTR_LEN		equ COMMON_LLIST_HEAD_PTR_LENGTH
GX_LIST_HEAD_PTR_INITIAL	equ COMMON_LLIST_HEAD_PTR_INITIAL

; this list holds extension registrations
gxExtensionsHeadPtr:	times GX_LIST_HEAD_PTR_LEN db GX_LIST_HEAD_PTR_INITIAL
				; byte
				; 0 - 1        registration number
				; 2 - 3        "on prepare" callback segment
				; 4 - 5        "on prepare" callback offset
				; 6 - 7        "on clear storage" callback segment
				; 8 - 9        "on clear storage" callback offset
				; 10 - 11      "on need render" callback segment
				; 12 - 13      "on need render" callback offset
				; 14 - 15      "on render all" callback segment
				; 16 - 17      "on render all" callback offset
				; 18 - 19      "on schedule render all" callback segment
				; 20 - 21      "on schedule render all" callback offset
				; 22 - 23      "on handle event" callback segment
				; 24 - 25      "on handle event" callback offset
GX_EXTENSIONS_PAYLOAD_SIZE	equ 26

; stores data so it can be added as a new element
gxExtensionsPayload:			times GX_EXTENSIONS_PAYLOAD_SIZE db 0
				
gxNextExtensionRegistrationNumber:		dw 0
gxExtensionNeedsRendering:				db 0


; Initializes the GUI framework extensions interface.
;
; input:
;		none
; output:
;		none
common_gx_initialize:
	pusha
	
	call common_memory_is_initialized
	cmp ax, 0
	jne common_gx_initialize_memory_is_ok
	; this should only happen if the application developer forgot to
	; initialize dynamic memory
	; set video mode
	mov ah, 0							; function 0 is "set video mode"
	mov al, 3							; text mode
	int 10h								; set video mode
	int 0B4h							; dump regs
	jmp $								; lock up
common_gx_initialize_memory_is_ok:	
	mov word [cs:gxNextExtensionRegistrationNumber], 0
common_gx_initialize_done:
	popa
	ret

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	
; NOTE:
;
; The functions below are meant to be invoked ONLY by extensions wishing to
; register with the GUI framework interface.
; GUI framework or consumer applications should NOT invoke these directly.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	

; Allocates an ID that an extension can subsequently use to register itself
; with the GUI framework.
; That registration number is how the GUI framework interface identifies a
; given extension after it is registered.
;
; input:
;		none
; output:
;		AX - registration number
gx_register_extension:
	pusha
	push ds
	push es
	push fs
	
	mov ax, cs
	mov es, ax
	mov fs, ax
	
	; add a new list element, having current registration number stored within
	mov di, gxExtensionsPayload			; ES:DI := pointer to buffer
	mov ax, word [cs:gxNextExtensionRegistrationNumber]
	mov word [es:di+0], ax				; store registration number
	
	mov bx, gxExtensionsHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_EXTENSIONS_PAYLOAD_SIZE
	call common_llist_add				; DS:SI := new list element
	
	pop fs
	pop es
	pop ds
	popa
	mov ax, word [cs:gxNextExtensionRegistrationNumber]	; return it
	inc word [cs:gxNextExtensionRegistrationNumber]
	ret
	

; Registers an extension for the "on prepare" step.
; These generally occur before the GUI framework has been given control.
;
; input:
;		AX - registration number
;	 ES:DI - pointer to callback
;			 callback contract:
;               MUST return via retf
;               Not required to preserve any registers
;				input:
;					none
;				output:
;					none
; output:
;		none
gx_register__on_prepare:
	pusha
	push ds
	
	call _gx_find_registration	; DS:SI := ptr to registration
	cmp ax, 0
	je gx_register__on_prepare_done	; not found
	
	mov word [ds:si+2], es		; segment
	mov word [ds:si+4], di		; offset
gx_register__on_prepare_done:	
	pop ds
	popa
	ret
	

; Registers an extension for the "on clear storage" step.
; These generally occur when the user wants to clear all components.
;
; input:
;		AX - registration number
;	 ES:DI - pointer to callback
;			 callback contract:
;               MUST return via retf
;               Not required to preserve any registers
;				input:
;					none
;				output:
;					none
; output:
;		none
gx_register__on_clear_storage:
	pusha
	push ds
	
	call _gx_find_registration	; DS:SI := ptr to registration
	cmp ax, 0
	je gx_register__on_clear_storage_done	; not found
	
	mov word [ds:si+6], es		; segment
	mov word [ds:si+8], di		; offset
gx_register__on_clear_storage_done:	
	pop ds
	popa
	ret
	
	
; Registers an extension for the "on need render" step.
; These generally occur when the GUI framework establishes whether components
; need to render again.
;
; input:
;		AX - registration number
;	 ES:DI - pointer to callback
;			 callback contract:
;               MUST return via retf
;               Not required to preserve any registers
;				input:
;					none
;				output:
;					AL - 0 when extension doesn't need rendering, other value otherwise
; output:
;		none
gx_register__on_need_render:
	pusha
	push ds
	
	call _gx_find_registration	; DS:SI := ptr to registration
	cmp ax, 0
	je gx_register__on_need_render_done	; not found
	
	mov word [ds:si+10], es		; segment
	mov word [ds:si+12], di		; offset
gx_register__on_need_render_done:
	pop ds
	popa
	ret
	

; Registers an extension for the "on render all" step.
; These generally occur when the GUI framework has found that some components
; need rendering.
;
; input:
;		AX - registration number
;	 ES:DI - pointer to callback
;			 callback contract:
;               MUST return via retf
;               Not required to preserve any registers
;				input:
;					none
;				output:
;					none
; output:
;		none
gx_register__on_render_all:
	pusha
	push ds
	
	call _gx_find_registration	; DS:SI := ptr to registration
	cmp ax, 0
	je gx_register__on_render_all_done	; not found
	
	mov word [ds:si+14], es		; segment
	mov word [ds:si+16], di		; offset
gx_register__on_render_all_done:
	pop ds
	popa
	ret
	
	
; Registers an extension for the "on schedule render all" step.
; These generally occur when the GUI framework wishes to request that
; all components of an extension are scheduled for the next render.
;
; input:
;		AX - registration number
;	 ES:DI - pointer to callback
;			 callback contract:
;               MUST return via retf
;               Not required to preserve any registers
;				input:
;					none
;				output:
;					none
; output:
;		none
gx_register__on_schedule_render_all:
	pusha
	push ds
	
	call _gx_find_registration	; DS:SI := ptr to registration
	cmp ax, 0
	je gx_register__on_schedule_render_all_done	; not found
	
	mov word [ds:si+18], es		; segment
	mov word [ds:si+20], di		; offset
gx_register__on_schedule_render_all_done:
	pop ds
	popa
	ret
	
	
; Registers an extension for the "on schedule render all" step.
; These generally occur when the GUI framework allows extensions to
; handle a newly-dequeued event.
;
; input:
;		AX - registration number
;	 ES:DI - pointer to callback
;			 callback contract:
;               MUST return via retf
;               Not required to preserve any registers
;				input:
;					ES:DI - pointer to event bytes
;				output:
;					none
; output:
;		none
gx_register__on_handle_event:
	pusha
	push ds
	
	call _gx_find_registration	; DS:SI := ptr to registration
	cmp ax, 0
	je gx_register__on_handle_event_done	; not found
	
	mov word [ds:si+22], es		; segment
	mov word [ds:si+24], di		; offset
gx_register__on_handle_event_done:
	pop ds
	popa
	ret
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	
; NOTE:
;
; The functions below are meant to be invoked ONLY by the GUI framework.
; NO extensions or consumer applications should invoke these directly.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Prepares extensions before usage
;
; input:
;		none
; output:
;		none
gx_prepare:
	pusha
	mov si, _gx_on_prepare_callback
	call _gx_registrations_foreach
	popa
	ret
	
	
; Clears all storage for all extensions
;
; input:
;		none
; output:
;		none
gx_clear_storage:
	pusha
	mov si, _gx_on_clear_storage_callback
	call _gx_registrations_foreach
	popa
	ret
	
	
; Returns whether some entities of some extension need to be rendered
;
; input:
;		none
; output:
;		AL - 0 when there is no need for rendering, other value otherwise
gx_get_need_render:
	pusha
	
	mov byte [cs:gxExtensionNeedsRendering], 0
	mov si, _gx_on_need_render_callback
	call _gx_registrations_foreach
	
	popa
	mov al, byte [cs:gxExtensionNeedsRendering]		; result
	ret
	
	
; Iterates through all entities of all extensions, rendering those 
; which need it
;

; input:
;		none
; output:
;		none
gx_render_all:
	pusha
	mov si, _gx_on_render_all_callback
	call _gx_registrations_foreach
	popa
	ret


; Marks all entities of all extensions as needing render
;
; input:
;		none
; output:
;		none
gx_schedule_render_all:
	pusha
	mov si, _gx_on_schedule_render_all_callback
	call _gx_registrations_foreach
	popa
	ret

	
; Considers the newly-dequeued event, and modifies state for any entities
; within each extension
;
; input:
;		none
; output:
;		none
gx_handle_event:
	pusha
	mov si, _gx_on_handle_event_callback
	call _gx_registrations_foreach
	popa
	ret
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	
; Helpers below
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Finds an extension using a registration number
;
; input:
;		AX - registration number
; output:
;		AX - 0 when no such registration found, other value otherwise
;	 DS:SI - pointer to registration, when found
_gx_find_registration:
	push bx
	push cx
	push dx
	push di
	push fs

	push ax								; [1]
	
	mov ax, cs
	mov fs, ax
	
	mov bx, gxExtensionsHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_EXTENSIONS_PAYLOAD_SIZE
	mov si, 0							; registration number is at offset 0
	pop dx								; [1] registration number value
	call common_llist_find_by_word		; DS:SI := element
										; AX := 0 when not found
	pop fs
	pop di
	pop dx
	pop cx
	pop bx
	ret

	
; Invokes a callback for all registered extensions
;
; input:
;	 CS:SI - pointer to callback
; output:
;		none
_gx_registrations_foreach:
	pusha
	push ds
	push fs
	
	mov ax, cs
	mov ds, ax
	mov fs, ax
	
	mov bx, gxExtensionsHeadPtr			; FS:BX := pointer to pointer to head
	mov cx, GX_EXTENSIONS_PAYLOAD_SIZE
	call common_llist_foreach
	
	pop fs
	pop ds
	popa
	ret
	
	
; Callback for "on prepare".
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
_gx_on_prepare_callback:
	push word [ds:si+2]				; segment
	push word [ds:si+4]				; offset
	pop si
	pop ds							; DS:SI := ptr to callback
	
	call gui_invoke_callback
	mov ax, 1						; keep traversing
	retf
	
	
; Callback for "on clear storage".
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
_gx_on_clear_storage_callback:
	push word [ds:si+6]				; segment
	push word [ds:si+8]				; offset
	pop si
	pop ds							; DS:SI := ptr to callback
	
	call gui_invoke_callback
	mov ax, 1						; keep traversing
	retf
	

; Callback for "on need render".
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
_gx_on_need_render_callback:
	push word [ds:si+10]			; segment
	push word [ds:si+12]			; offset
	pop si
	pop ds							; DS:SI := ptr to callback
	call _gx_invoke_callback_one_result	; AL - 0 when there is no need for
										; rendering, other value otherwise
	cmp al, 0
	je _gx_on_need_render_callback_keep_going
	; this extension needs rendering
	mov byte [cs:gxExtensionNeedsRendering], 1
	mov ax, 0						; stop traversing
	jmp _gx_on_need_render_callback_done
_gx_on_need_render_callback_keep_going:
	mov ax, 1						; keep traversing
_gx_on_need_render_callback_done:
	retf


; Callback for "on render all".
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
_gx_on_render_all_callback:
	push word [ds:si+14]			; segment
	push word [ds:si+16]			; offset
	pop si
	pop ds							; DS:SI := ptr to callback
	
	call gui_invoke_callback
	mov ax, 1						; keep traversing
	retf
	

; Callback for "on schedule render all".
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
_gx_on_schedule_render_all_callback:
	push word [ds:si+18]			; segment
	push word [ds:si+20]			; offset
	pop si
	pop ds							; DS:SI := ptr to callback
	
	call gui_invoke_callback
	mov ax, 1						; keep traversing
	retf
	
	
; Callback for "on handle event".
;
; NOTES: MUST return via retf
;        not required to preserve any registers
;        behaviour is undefined if callback modifies list structure
;
; input:
;	 DS:SI - pointer to currently-iterated list element
;		DX - index of currently-iterated list element
; output:
;		AX - 0 when traversal must stop, other value otherwise
_gx_on_handle_event_callback:
	push word [ds:si+22]			; segment
	push word [ds:si+24]			; offset
	pop si
	pop ds							; DS:SI := ptr to callback
	
	push cs
	pop es							; this is where GUI framework
	mov di, dequeueEventBytesBuffer	; dequeues event bytes
	
	call gui_invoke_callback
	mov ax, 1						; keep traversing
	retf


; Invokes the specified callback with no arguments, returning
; a result in one register
;
; input:
;	 DS:SI - pointer to callback
; output:
;		AX - callback result
_gx_invoke_callback_one_result:
	push bx
	push cx
	push dx
	push si
	push di
	push bp
	pushf
	push ds
	push es
	push fs
	push gs
	
	; setup return address
	push cs
	push word _gx_invoke_callback_one_result_return	; return address on stack
	
	; setup "call far" address
	push ds			; callback segment
	push si			; callback offset
	retf			; "call far"
	; once the callback executes its own retf, execution returns below
_gx_invoke_callback_one_result_return:
	pop gs
	pop fs
	pop es
	pop ds
	popf
	pop bp
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret


%define _COMMON_MEMORY_CONFIG_			; override default chunk count value
COMMON_MEMORY_MAX_CHUNKS	equ 500
%include "common\memory.asm"
%include "common\dynamic\linklist.asm"

%ifndef _COMMON_GUI_CONF_COMPONENT_LIMITS_
%define _COMMON_GUI_CONF_COMPONENT_LIMITS_
GUI_RADIO_LIMIT 		equ 32	; maximum number of radio available
GUI_IMAGES_LIMIT 		equ 64	; maximum number of images available
GUI_CHECKBOXES_LIMIT 	equ 32	; maximum number of checkboxes available
GUI_BUTTONS_LIMIT 		equ 32	; maximum number of buttons available
%endif
%include "common\vga640\gui\gui.asm"
	

%endif
