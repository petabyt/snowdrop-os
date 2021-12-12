;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The SHUTDOWN app.
; This app demonstrates how to use the "power off" kernel service interrupt
; to shut down the computer.
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

failureString: 	db "APM power off command failed.", 0
connectionString: 	 db "Unable to connect to APM interface.", 0
selectVersionString: db "Unable to select APM driver version 1.2.", 0
installationCheckString: db "APM installation check failed. APM is not available.", 0

start:
	mov ax, 0			; "power off"
	int 9Bh				; invoke "power services" system call
	
	; if we get here, the power off operation failed
	cmp ax, 0
	je installation_check_failure
	cmp ax, 1
	je cannot_connect_interface
	cmp ax, 2
	je cannot_select_driver_version
	; case 3 falls through, to below
power_off_command_failed:
	mov si, failureString
	int 80h	
	int 95h						; exit

installation_check_failure:
	mov si, installationCheckString
	int 80h
	int 95h						; exit
	
cannot_connect_interface:
	mov si, connectionString
	int 80h
	int 95h						; exit
	
cannot_select_driver_version:
	mov si, selectVersionString
	int 80h
	int 95h						; exit
