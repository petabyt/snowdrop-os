;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It handles running the startup app, after the kernel has initialized.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

OVERRIDE_APP_NAME_MAX_LENGTH equ 8
overrideStartupAppName: times OVERRIDE_APP_NAME_MAX_LENGTH+1 db 0

initStartupAppEnterString1:	db 13, 
							db '.startup application (', 0
initStartupAppEnterString2:	db ') - ENTER NEW STARTUP APP NAME: ', 0

initAppEnterWithName1:		db '.startup application (', 0
initAppEnterWithName2:		db ') - PRESS [Y] TO OVERRIDE - ', 0
							
initStartupAppString1:		db 13, '.startup application (', 0
initStartupAppString2:		db ')', 0

eraseLineString: db 13, '                                                                               ', 0
startupAppWasOverridden:	dw 0

startupServices:			db '.services', 13, 10, 0
startupInvalidServiceName:	db '    skipping service (name too long)', 13, 10, 0
startupLoadedService:		db '" - loaded', 13, 10, 0
startupCannotLoadFile:		db '" - not found', 13, 10, 0
startupNoMemoryForService:	db '" - could not allocate memory', 13, 10, 0
startupServiceTab:			db '    "', 0

startupServiceLastAllocatedSegment:		dw 0

propertyServices:		db 'services', 0			; property in config file

propertyStartupApp: 	db 'startup_app_name', 0	; startup app name property
startUpAppFileNameFat12:	db '        APP', 0 	; in FAT12 format
dotFormatStartUpFileName:	times 13 db 0	; used to convert to 8.3 format

startupServiceFilenameFat12:	db '        APP', 0 	; in FAT12 format

startupAppFailedLoadString1: db 'Could not load startup application ', 0 

tempPropertyValueBuffer:	times 129 db 0
tempServiceName:			times 129 db 0

appPropertyNotFound:	db 'Property startup_app_name was not found in '
						db 'the configuration file.', 0
							
appNameTooLongString: 	db 'Startup application name cannot exceed 8 characters! ', 0


; Called by the kernel initialization code to pass control to the
; scheduler, to run the startup app.
;
; NOTE: this is reached via jmp, and NOT call, as it is not meant to return
;
; input:
;		none
; output:
;		none
startup_start_app:
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	call startup_start_app_override_check	; did the user override the
											; configured startup app?
	mov word [cs:startupAppWasOverridden], ax
	cmp ax, 0
	jne startup_start_app_name_found		; yes, we won't read it from config
	; no override - proceed with reading the startup app name from config
	mov di, startUpAppFileNameFat12
	call startup_read_startup_app_file_name	; read startup app name

startup_start_app_name_found:
	; here, [startUpAppFileNameFat12] contains the FAT12 startup app name
	mov si, eraseLineString
	int 80h
	
	mov si, initStartupAppString1
	call debug_print_string
	
	mov si, startUpAppFileNameFat12	; convert name to uppercase, since
	int 82h								; that's how FAT12 stores names
	
	mov si, startUpAppFileNameFat12
	mov di, dotFormatStartUpFileName
	int 0B3h							; convert to 8.3 file name
	mov si, dotFormatStartUpFileName
	call debug_print_string
	
	mov si, initStartupAppString2
	call debug_println_string
	
	; ask memory manager for a memory segment
	; the startup app task will be loaded in this segment
	int 91h				; BX := allocated segment
	push bx
	pop es				; ES := allocated segment
	mov di, 0			; ES:DI points to where the startup app will be loaded
	mov si, startUpAppFileNameFat12
	int 81h				; load startup app to memory
	
	cmp al, 0
	jne startup_start_app_failed ; did the startup app fail to load?
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; the startup app has been loaded successfully
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	; the reason we load services now is to avoid a potential dead-end
	; situation when there's not enough memory to load the startup app
	; in this situation, the user would be unable to override the startup app
	; to a text editor to edit the kernel configuration file, to ultimately
	; remove some services from the list
	
	; ... unless the startup app was overridden
	cmp word [cs:startupAppWasOverridden], 0
	jne startup_add_startup_app_to_scheduler	; startup app was overridden
	
	call startup_load_services			; load services BEFORE startup app

startup_add_startup_app_to_scheduler:
	; here, BX = startup app allocated segment (from above)
	mov si, emptyString					; DS:SI := empty string (task params)
	int 93h								; add startup app task based on segment
										; AX := task ID (offset)
	call scheduler_get_display_id_for_task ; AX := display ID of specified task
	call display_initialize_active_display

	cmp word [cs:startupAppWasOverridden], 0
	je startup_cleanup_and_yield		; startup app was not overridden
	
	call startup_load_services			; load services AFTER startup app

startup_cleanup_and_yield:
	; cleanup any left-overs in the kernel
	call config_unload_config_file
	
	call version_print					; show the "welcome" message right
										; before passing control to the 
										; scheduler
	
	jmp scheduler_start					; start the scheduler
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; control has now been given to the scheduler
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

startup_start_app_failed:
	mov si, startupAppFailedLoadString1		; print first half of message
	call debug_print_string
	mov si, dotFormatStartUpFileName		; print start app name
	call debug_print_string
	jmp crash


; Loads all services listed in the appropriate property of the config file
;
; input:
;		none
; output:
;		none
startup_load_services:
	pushf
	pusha
	push ds
	push es

	cld
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov si, startupServices
	int 80h
	
	; does the config file specify services?
	mov di, tempPropertyValueBuffer
	mov si, propertyServices
	call config_get_property_value
	cmp ax, 0
	je startup_load_services_done			; not specified, so we're done

	mov si, tempPropertyValueBuffer
	mov di, tempServiceName
startup_load_services_loop:
	cmp byte [ds:si], 0
	je startup_load_services_after_token
	; we've still got characters
	cmp byte [ds:si], ','					; we're at the end of a token
	je startup_load_services_after_token
	; we're inside a token
	movsb									; accumulate it
	jmp startup_load_services_loop
	
startup_load_services_after_token:
	; here, ES:DI is immediately after last character of token, that is the
	; spot to receive a terminator
	mov byte [es:di], 0						; add terminator to token
	mov di, tempServiceName					; ES:DI := token
	
	; validate and start service
	call startup_load_service_by_name
	
	cmp byte [ds:si], 0
	je startup_load_services_done	; we got here because we are out of chars
	
	; we got here because we found a comma
	inc si									; move to after comma
	mov di, tempServiceName					; ES:DI := token buffer
	jmp startup_load_services_loop
startup_load_services_done:
	pop es
	pop ds
	popa
	popf
	ret
	

; Prompts user for startup app override, allowing him to enter the name of
; the startup app, bypassing the one set in the kernel configuration file.
; If the user chose to override, he is then prompted for an app name.
;
; input:
;	 ES:DI - pointer to service name
; output:
;		none	
startup_load_service_by_name:
	pusha
	pushf
	push ds
	push es
	
	push es
	pop ds
	mov si, di						; DS:SI := service name
	
	int 0A5h						; BX := string length
	cmp bx, 1
	jb startup_load_service_by_name_done
	cmp bx, 8
	ja startup_load_service_by_name_invalid_name

	; print service name to screen
	push cs
	pop ds
	mov si, startupServiceTab
	int 80h
	
	push es
	pop ds
	mov si, di
	int 80h							; DS:SI := service name
	
	; convert service name to FAT12 file name
	cld
	push cs
	pop es
	mov di, startupServiceFilenameFat12
	mov cx, 8
	mov al, ' '
	rep stosb						; clear out first eight characters
	
	mov di, startupServiceFilenameFat12
	int 0A5h
	mov cx, bx						; CX := length of service name
	rep movsb						; fill in FAT12 name buffer
	
	push cs
	pop ds
	mov si, startupServiceFilenameFat12
	int 82h							; convert service name to uppercase
	
	; here, DS:SI points to service file name in FAT12 format
	
	; allocate memory for service
	int 91h				; BX := allocated segment
	cmp ax, 0
	jne startup_load_service_by_name_no_memory
	
	; load service from file
	mov word [cs:startupServiceLastAllocatedSegment], bx
	push bx
	pop es				; ES := allocated segment
	mov di, 0			; ES:DI points to where the startup app will be loaded
	int 81h				; load startup app to memory
	cmp al, 0
	jne startup_load_service_by_name_cannot_load
	
	; create task based on segment where we loaded service
	; here, BX = allocated segment (from above)
	push cs
	pop ds
	mov si, emptyString					; DS:SI := empty string (task params)
	int 93h								; add startup app task based on segment
										; AX := task ID (offset)
	; print "loaded"
	mov si, startupLoadedService
	int 80h
	jmp startup_load_service_by_name_done

startup_load_service_by_name_cannot_load:
	; free memory we allocated for the service
	mov bx, word [cs:startupServiceLastAllocatedSegment]
	int 92h								; deallocate
	
	push cs
	pop ds
	mov si, startupCannotLoadFile
	int 80h
	jmp startup_load_service_by_name_done
	
startup_load_service_by_name_no_memory:
	push cs
	pop ds
	mov si, startupNoMemoryForService
	int 80h
	jmp startup_load_service_by_name_done
	
startup_load_service_by_name_invalid_name:
	push cs
	pop ds
	mov si, startupInvalidServiceName
	int 80h
	jmp startup_load_service_by_name_done
	
startup_load_service_by_name_done:
	pop es
	pop ds
	popf
	popa
	ret
	
	
; Prompts user for startup app override, allowing him to enter the name of
; the startup app, bypassing the one set in the kernel configuration file.
; If the user chose to override, he is then prompted for an app name.
;
; input:
;		none
; output:
;		AX - 0 when user did not override; other value otherwise
startup_start_app_override_check:
	pusha
	pushf
	push ds
	push es
	
	mov ax, cs
	mov es, ax
	mov ds, ax
	
	; does the config file specify a startup app?
	mov di, tempPropertyValueBuffer
	mov si, propertyStartupApp
	call config_get_property_value
	cmp ax, 0
	je startup_start_app_override_check_input	; not specified, so we force

	; print a message which includes the app name as configured
	mov si, initAppEnterWithName1
	call debug_print_string
	; print configured app name
	mov si, tempPropertyValueBuffer
	call debug_print_string
	; rest of message is printed by the "wait for user input" utility
	mov si, initAppEnterWithName2
startup_start_app_override_check_wait_for_input:
	; here, DS:SI points to message to show user when prompting him for an app
	mov bh, 'y'							; can press both lower case
	mov bl, 'Y'							; and upper case
	mov dl, byte [cs:userChoiceTimeoutSeconds]	; seconds to wait
	call utility_countdown_user_prompt	; AL := 1 if user pressed N
	cmp al, 1
	jne startup_start_app_override_check_no	; no override
	; user has chosen to override

startup_start_app_override_check_input:
	mov si, eraseLineString
	int 80h
	
	mov si, initStartupAppEnterString1
	int 80h
	mov si, tempPropertyValueBuffer
	int 80h
	mov si, initStartupAppEnterString2
	int 80h
	
	mov di, overrideStartupAppName
	mov cx, OVERRIDE_APP_NAME_MAX_LENGTH	; character limit
	int 0A4h								; read user input
	
	mov si, overrideStartupAppName
	int 0A5h								; BX := string length
	cmp bx, 0
	je startup_start_app_override_check_input	; need at least one character
	cmp bx, OVERRIDE_APP_NAME_MAX_LENGTH
	ja startup_start_app_override_check_input	; can't be too long

	; user input is valid
	; now copy characters from what the user entered to the FAT12 name buffer
	mov si, overrideStartupAppName
	mov di, startUpAppFileNameFat12
	mov cx, bx								; app name length
	cld
	rep movsb
	
startup_start_app_override_check_yes:
	pop es
	pop ds
	popf
	popa
	mov ax, 1
	ret
startup_start_app_override_check_no:
	pop es
	pop ds
	popf
	popa
	mov ax, 0
	ret
	
	
; Read startup app name from the configuration file and into the 
; provided buffer.
;
; NOTE: does NOT add terminator character after the file name
;
; input:
;	 ES:DI - pointer to where startup app file name will be stored
; output:
;		none
startup_read_startup_app_file_name:
	pushf
	pusha
	push ds
	
	push es
	push di									; [1] save

	mov ax, cs
	mov es, ax
	mov ds, ax
	mov di, tempPropertyValueBuffer
	mov si, propertyStartupApp
	call config_get_property_value
	cmp ax, 0
	je startup_read_startup_app_file_name_not_found	; property not found

	mov si, tempPropertyValueBuffer
	int 0A5h
	cmp bx, 8										; app name longer than 8?
	ja startup_read_startup_app_file_name_overrun	; we're done
	
	; copy app name into passed-in string
	pop di
	pop es									; [1] restore
	
	; here, ES:DI points to target buffer, as passed in
	; here, DS:SI points to app name, as read from config
	mov cx, bx								; CX := app name length
	cld
	rep movsb								; copy app name
	
	pop ds
	popa
	popf
	ret
startup_read_startup_app_file_name_not_found:
	mov si, appPropertyNotFound
	call debug_println_string
	jmp crash
startup_read_startup_app_file_name_overrun:
	mov si, appNameTooLongString
	call debug_println_string
	jmp crash
