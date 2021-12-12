;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains functionality for synchronizing multiple tasks, each running a
; GUI framework application.
; The reason for this is to support the use case of such an application
; starting other such applications, and wanting certain choices the user
; made in the first application echoing over to the subsequent applications.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_SYNC_
%define _COMMON_GUI_SYNC_

guiSyncMyTaskId:				dw 0

guiSyncIsPrincipal:				db 0	; whether we HAVE become principal
guiSyncHasPrincipalIntention:	db 0	; whether this application can become
										; a "principal" - that is, dictates to
										; other GUI framework apps certain user
										; choices made here

; used by tasks to request becoming principal
guiSyncMessageTypeRequestPrincipal:			db 'guif-principal-request', 0

; used by principal tasks to deny others becoming principal
guiSyncMessageTypePrincipalRequestDenial:	db 'guif-principal-req-denial', 0
							; message format:
							; bytes:
							; 0 - 1     task ID of task denying principal
GUI_SYNC_MESSAGE_REQUEST_PRINCIPAL_DENIAL_SIZE		equ 2			; in bytes

;
; NOTE: there are restrictions around who can push "properties"
;       "state" is a package of data that can more generally be pushed by everyone
;

; used by tasks to transmit properties which may have been changed by the user
guiSyncMessageTypePropertiesPush:			db 'guif-properties-push', 0
							; message format:
							; bytes:
							; 0 - 1		task ID of task pushing properties
							; 2 - 2		palette: 0=regular, 1=inverted
							; 3 - 3		font: 0=regular, 1=bold
GUI_SYNC_MESSAGE_PROPERTIES_PUSH_SIZE		equ 4			; in bytes

GUI_SYNC_MESSAGE_PROPERTIES_PALETTE_INVERTED	equ 0
GUI_SYNC_MESSAGE_PROPERTIES_PALETTE_REGULAR		equ 1

; used by tasks to request a property push, perhaps during startup
guiSyncMessageTypeRequestPropertiesPush:	db 'guif-prop-push-request', 0
							; message format:
							; bytes:
							; 0 - 1     task ID of task requesting properties
GUI_SYNC_MESSAGE_REQUEST_PROPERTIES_PUSH_SIZE		equ 2	; in bytes							

; used by tasks to communicate state
; unlike properties, there are no restrictions on which tasks can communicate
; state
guiSyncMessageTypeStatePush:				db 'guif-state-push', 0
							; message format:
							; bytes:
							; 0 - 1     task ID of task requesting principal
							; 2 - 3     mouse position X
							; 4 - 5     mouse position Y
							; 6 - 6     flags:
							;                bit 0: set when task is exiting

GUI_SYNC_MESSAGE_STATE_PUSH_SIZE		equ 7	; in bytes	
GUI_SYNC_STATE_FLAG_IS_EXITING			equ 1

; used by tasks to tell other tasks they've started a task
guiSyncMessageTypeTaskStarted:	db 'guif-task-started', 0
							; message format:
							; bytes:
							; 0 - 1     task ID of task which published message
							; 2 - 3     task ID of newly-started task
GUI_SYNC_MESSAGE_TASK_STARTED_SIZE		equ 4	; in bytes	

guiSyncIsInitialized:			db 0
guiSyncTaskIsExiting:			db 0	; allowed values: 0 and 1
guiSyncTotalTaskCounter:		db 0	; includes me

guiSyncEmptyMessageBody:		db 0
guiSyncRequestPrincipalDenialMessageBody:	times GUI_SYNC_MESSAGE_REQUEST_PRINCIPAL_DENIAL_SIZE db 0
guiSyncPropertiesPushMessageBody:	times GUI_SYNC_MESSAGE_PROPERTIES_PUSH_SIZE db 0
guiSyncRequestPropertiesPushMessageBody:	times GUI_SYNC_MESSAGE_REQUEST_PROPERTIES_PUSH_SIZE db 0
guiSyncStatePushMessageBody:	times GUI_SYNC_MESSAGE_STATE_PUSH_SIZE db 0
guiSyncTaskStartedMessageBody:	times GUI_SYNC_MESSAGE_TASK_STARTED_SIZE db 0

guiSyncDisallowShutdownExplicit:	db 0


; Configures this GUI application to not allow the user to exit
;
; input:
;		none
; output:
;		none
gui_sync_disable_shutdown_explicit:
	mov byte [cs:guiSyncDisallowShutdownExplicit], 1
	ret


; Checks whether this task can shut down
;
; input:
;		none
; output:
;		AL - 0 when this task cannot shut down, other value otherwise
gui_sync_can_shutdown:
	push bx
	
	mov bl, 0								; assume no
	cmp byte [cs:guiSyncDisallowShutdownExplicit], 0
	jne gui_sync_can_shutdown_done			; cannot shutdown
	
	mov bl, 1								; assume yes
	
	call gui_sync_is_principal				; only principal is restricted
	cmp al, 0
	je gui_sync_can_shutdown_done
	
	call gui_sync_get_task_counter_atomic	; AL := task counter
	cmp al, 1
	jbe gui_sync_can_shutdown_done
	
	mov bl, 0								; no
gui_sync_can_shutdown_done:
	mov al, bl
	pop bx
	ret


; Get my task counter
;
; input:
;		none
; output:
;		AL - task counter, including me
gui_sync_get_task_counter_atomic:
	pushf
	cli
	mov al, byte [cs:guiSyncTotalTaskCounter]
	popf
	ret


; Increments my task counter
;
; input:
;		none
; output:
;		none
gui_sync_increment_task_counter_atomic:
	pushf
	cli
	inc byte [cs:guiSyncTotalTaskCounter]
	popf
	ret

	
; Decrements my task counter
;
; input:
;		none
; output:
;		none
gui_sync_decrement_task_counter_atomic:
	pushf
	cli
	dec byte [cs:guiSyncTotalTaskCounter]
	popf
	ret
	

; Shuts down this module
;
; input:
;		none
; output:
;		none
gui_sync_shutdown:
	pusha
	
	mov byte [cs:guiSyncTaskIsExiting], GUI_SYNC_STATE_FLAG_IS_EXITING
	
	mov ah, 1
	int 0C4h					; unsubscribe from all message types
	
	call gui_sync_publish_all_changes		; since we're shutting down,
											; send changes one more time
	
	mov byte [cs:guiSyncIsInitialized], 0
	mov byte [cs:guiSyncIsPrincipal], 0
	mov byte [cs:guiSyncHasPrincipalIntention], 0
	
	popa
	ret


; Returns whether this application is principal
;
; input:
;		none
; output:
;		AL - 0 when this application is not principal, other value otherwise
gui_sync_is_principal:
	mov al, byte [cs:guiSyncIsPrincipal]
	ret
	

; Initializes this component
;
; input:
;		AL - 0 when this application does not intend to be a principal,
;			 other value otherwise
; output:
;		none
gui_sync_initialize:
	pusha
	push ds
	push es
	
	cmp byte [cs:guiSyncIsInitialized], 0
	jne gui_sync_initialize_done
	
	mov byte [cs:guiSyncIsInitialized], 1
	mov byte [cs:guiSyncTaskIsExiting], 0
	mov byte [cs:guiSyncTotalTaskCounter], 1			; just me for now
	mov byte [cs:guiSyncHasPrincipalIntention], al
	
	cmp al, 0
	je gui_sync_initialize_done
	; we're trying to become principal
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; assume we are principal
	mov byte [cs:guiSyncIsPrincipal], 1
	
	; subscribe to principal request denial messages, so we know
	; whether our request to become principal has been denied
	mov si, guiSyncMessageTypePrincipalRequestDenial
	mov dx, cs
	mov bx, gui_sync_principal_request_denial_callback
	mov ah, 0
	int 0C4h								; subscribe
	
	; now request principal
	mov si, guiSyncEmptyMessageBody
	mov cx, 0								; size
	mov di, guiSyncMessageTypeRequestPrincipal
	mov ah, 2
	int 0C4h
	
	; by now we know for sure whether we are principal or not
	
	; subscribe to principal request messages, so we can deny
	; others' requests if we become principal
	mov si, guiSyncMessageTypeRequestPrincipal
	mov dx, cs
	mov bx, gui_sync_principal_request_callback
	mov ah, 0
	int 0C4h								; subscribe
	
	; order of these registrations is important: principal must be determined
	; before anything else takes place
	
	; subscribe to property pushes, so we can adjust if the user
	; changes properties of applications in a different application
	; than ourself
	mov si, guiSyncMessageTypePropertiesPush
	mov dx, cs
	mov bx, gui_sync_properties_push_callback
	mov ah, 0
	int 0C4h								; subscribe
	
	; subscribe to property push requests, so we can send properties
	; when asked to
	mov si, guiSyncMessageTypeRequestPropertiesPush
	mov dx, cs
	mov bx, gui_sync_request_properties_push_callback
	mov ah, 0
	int 0C4h
	
	; subscribe to state pushes, so we receive state from other tasks
	mov si, guiSyncMessageTypeStatePush
	mov dx, cs
	mov bx, gui_sync_state_push_callback
	mov ah, 0
	int 0C4h
	
	; subscribe to task start notifications, so we know when other
	; tasks start tasks
	mov si, guiSyncMessageTypeTaskStarted
	mov dx, cs
	mov bx, gui_sync_task_started_callback
	mov ah, 0
	int 0C4h
	
	call gui_sync_request_push_properties
	
gui_sync_initialize_done:
	pop es
	pop ds
	popa
	ret
	
	
; Publishes all messages pertaining to changes made here, so that
; other GUI applications can receive them.
;
; input:
;		none
; output:
;		none
gui_sync_publish_all_changes:
	pusha
	
	call gui_sync_push_properties
	call gui_sync_push_state
	
	popa
	ret


; Tells other tasks that I have started a task
;
; input:
;		AX - ID of newly-started task
; output:
;		none
gui_sync_publish_task_started:
	pusha
	push ds
	push es
	
	push ax
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov si, guiSyncTaskStartedMessageBody		; DS:SI := message body

	call gui_get_my_task_id						; AX := my task ID
	mov word [ds:si+0], ax						; task
	
	pop ax
	
	mov word [ds:si+2], ax						; started task
	
gui_sync_publish_task_started_publish:
	mov cx, GUI_SYNC_MESSAGE_TASK_STARTED_SIZE
	mov di, guiSyncMessageTypeTaskStarted
	mov ah, 2
	int 0C4h									; publish message
gui_sync_publish_task_started_done:
	pop es
	pop ds
	popa
	ret


; Pushes properties to other GUI applications that may be running
;
; input:
;		none
; output:
;		none
gui_sync_push_properties:
	pusha
	push ds
	push es
	
	cmp byte [cs:guiSyncIsPrincipal], 0
	je gui_sync_push_properties_done			; NOOP when I'm not principal
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov si, guiSyncPropertiesPushMessageBody	; DS:SI := message body
	
	mov al, byte [cs:guiIsRegularPalette]
	mov byte [ds:si+2], al						; palette
	
	mov al, byte [cs:guiIsBoldFont]
	mov byte [ds:si+3], al						; font
	
	call gui_get_my_task_id						; AX := my task ID
	mov word [ds:si+0], ax						; task
	
gui_sync_push_properties_publish:
	mov cx, GUI_SYNC_MESSAGE_PROPERTIES_PUSH_SIZE
	mov di, guiSyncMessageTypePropertiesPush
	mov ah, 2
	int 0C4h									; publish message
gui_sync_push_properties_done:
	pop es
	pop ds
	popa
	ret
	
	
; Pushes state to other GUI applications that may be running
;
; input:
;		none
; output:
;		none
gui_sync_push_state:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov si, guiSyncStatePushMessageBody			; DS:SI := message body
	
	call gui_get_my_task_id						; AX := my task ID
	mov word [ds:si+0], ax						; task
	
	call gui_mouse_get_position
	mov word [ds:si+2], bx						; X
	mov word [ds:si+4], ax						; Y
	
	mov al, 0									; flags
	or al, byte [cs:guiSyncTaskIsExiting]
	mov byte [ds:si+6], al
	
gui_sync_push_state_publish:
	mov cx, GUI_SYNC_MESSAGE_STATE_PUSH_SIZE
	mov di, guiSyncMessageTypeStatePush
	mov ah, 2
	int 0C4h									; publish message
gui_sync_push_state_done:
	pop es
	pop ds
	popa
	ret
	
	
; Requests a property push from other GUI applications
;
; input:
;		none
; output:
;		none
gui_sync_request_push_properties:
	pusha
	push ds
	push es
	
	cmp byte [cs:guiSyncIsPrincipal], 0
	jne gui_sync_request_push_properties_done			; NOOP when I am principal
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov si, guiSyncRequestPropertiesPushMessageBody	; DS:SI := message body
	
	call gui_get_my_task_id						; AX := my task ID
	mov word [ds:si+0], ax						; task
	
	mov cx, GUI_SYNC_MESSAGE_REQUEST_PROPERTIES_PUSH_SIZE
	mov di, guiSyncMessageTypeRequestPropertiesPush
	mov ah, 2
	int 0C4h									; publish message
gui_sync_request_push_properties_done:
	pop es
	pop ds
	popa
	ret


; Invoked when we have been denied becoming principal
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
gui_sync_principal_request_denial_callback:
	; if anybody publishes a message here, it means another principal is
	; denying us from becoming principal
	
	push ax
	call gui_get_my_task_id								; AX := my task ID
	cmp word [ds:si+0], ax				; did this denial come from myself?
	pop ax
	je gui_sync_principal_request_denial_callback_done	; I won't deny myself
	
	mov byte [cs:guiSyncIsPrincipal], 0
gui_sync_principal_request_denial_callback_done:
	retf

	
; Invoked when someone else is trying to become principal
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
gui_sync_principal_request_callback:
	; someone else is trying to become principal
	cmp byte [cs:guiSyncIsPrincipal], 0
	je gui_sync_principal_request_callback_done		; I am not principal, so
													; I won't deny it
													
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; publish a denial message
	mov si, guiSyncRequestPrincipalDenialMessageBody
	call gui_get_my_task_id					; AX := my task ID
	mov word [ds:si], ax					; store in message bytes
	mov cx, GUI_SYNC_MESSAGE_REQUEST_PRINCIPAL_DENIAL_SIZE
	mov di, guiSyncMessageTypePrincipalRequestDenial
	mov ah, 2
	int 0C4h
	
gui_sync_principal_request_callback_done:
	retf
	
	
; Invoked when someone is giving us properties
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
gui_sync_properties_push_callback:
	push ax
	call gui_get_my_task_id						; AX := my task ID
	cmp ax, word [ds:si+0]
	pop ax
	je gui_sync_properties_push_callback_done	; NOOP when this came from me
	
	pusha
	
	; palette
	mov bl, [ds:si+2]					; second byte := palette pushed to us
	mov al, GUI_EVENT_PALETTE_CHANGE
	call gui_event_enqueue_2bytes_atomic
	
	; font
	mov bl, [ds:si+3]					; second byte := font pushed to us
	mov al, GUI_EVENT_FONT_CHANGE
	call gui_event_enqueue_2bytes_atomic
	
	popa
	
gui_sync_properties_push_callback_done:
	retf


; Invoked when someone is requesting our properties
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
gui_sync_request_properties_push_callback:
	push ax
	call gui_get_my_task_id						; AX := my task ID
	cmp ax, word [ds:si+0]
	pop ax
	je gui_sync_request_properties_push_callback_done
												; NOOP when this came from me
	
	cmp byte [cs:guiSyncIsPrincipal], 0
	je gui_sync_request_properties_push_callback_done
												; NOOP when I'm not principal
	call gui_sync_push_properties
gui_sync_request_properties_push_callback_done:
	retf
	

; Invoked when we're receiving state from a different task
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
gui_sync_state_push_callback:
	push ax
	call gui_get_my_task_id						; AX := my task ID
	cmp ax, word [ds:si+0]
	pop ax
	je gui_sync_state_push_callback_done		; NOOP when this came from me

	; add appropriate events to respond to the state

gui_sync_state_push_callback__other_task_exit:
	test byte [ds:si+6], GUI_SYNC_STATE_FLAG_IS_EXITING
	jz gui_sync_state_push_callback_done
	; task who notified us is exiting
	mov al, GUI_EVENT_OTHER_TASK_EXIT
	mov bx, word [ds:si+0]						; task ID
	call gui_event_enqueue_3bytes_atomic
	
gui_sync_state_push_callback_done:
	retf

	
; Invoked when a task is notifying us that it has started
;
; input:
;	 DS:SI - pointer to message bytes
;	 ES:DI - pointer to message type
;		CX - message bytes length
;		AX - (reserved for future functionality)
;		BX - (reserved for future functionality)
;		DX - (reserved for future functionality)
; output:
;		none
gui_sync_task_started_callback:
	push ax
	call gui_get_my_task_id						; AX := my task ID
	cmp ax, word [ds:si+0]
	pop ax
	je gui_sync_task_started_callback_done		; NOOP when this came from me

	call gui_sync_increment_task_counter_atomic
gui_sync_task_started_callback_done:
	retf
	

%endif
