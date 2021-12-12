;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains functionality for interaction with the computer's power 
; management interface.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ERROR_INSTALLATION_CHECK equ 0
ERROR_REAL_MODE_INTERFACE_CONNECTION equ 1
ERROR_APM_DRIVER_1P2_UNSUPPORTED equ 2
ERROR_STATE_CHANGE equ 3


; Allows access to power-related functions
;
; input:
;		AX - 0=attempts to put the computer in a power off state via APM.
; 	     	 1=attempts to restart the computer
; output:
;		AX - when input AX=0, error code as follows:
;                0 = installation check failed
;                1 = real mode connection failed
;                2 = APM driver version 1.2 unsupported
;                3 = state change to "off" failed
; 			 when input AX=1, undefined
power_service:
	; this entry point procedure should not preserve any registers, so
	; it allows specific functions to return values in arbitrary registers
	
	cmp ax, 0
	je power_service_poweroff
	cmp ax, 1
	je power_service_restart
	jmp power_service_done
power_service_poweroff:
	call power_off
	jmp power_service_done
power_service_restart:
	call power_restart
	jmp power_service_done
power_service_done:
	ret


; Attempts to restart computer via bit 0 of the 8042 PS/2 controller
;
; input:
;		none
; output:
;		none
power_restart:
	pusha
	call ps2controller_wait_before_write
	mov al, 0FEh
	out 64h, al
	popa
	ret
	


; Attempts to put the computer in a power off state via APM
;
; output:
;			AX - error code as follows:
;				0 = installation check failed
;				1 = real mode connection failed
;				2 = APM driver version 1.2 unsupported
;				3 = state change to "off" failed
power_off:
	push bx
	push cx

	mov ax, 5300h		; "installation check" APM function
	mov bx, 0			; system BIOS device ID is 0
	int 15h				; invoke APM interrupt
	jc installation_check_failure

	mov ax, 5301h		; "connect real mode interface" APM function
	mov bx, 0			; system BIOS device ID is 0
	int 15h				; invoke APM interrupt
	jc cannot_connect_interface

	mov ax, 530Eh		; "select driver version" APM function
	mov bx, 0			; system BIOS device ID is 0
	mov cx, 0102h		; select APM version 1.2 (since "turn off system"
						; functionality is only available in APM 1.2 and later)
	int 15h				; invoke APM interrupt
	jc cannot_select_driver_version

	mov ax, 5307h		; "set state" APM function
	mov cx, 0003h		; "turn off system" state
	mov bx, 0001h		; "all power-managed devices" device ID is 1
	int 15h				; invoke APM interrupt
	
	; if system has not powered off, handle the error below
	
power_off_command_failed:
	mov ax, ERROR_STATE_CHANGE
	jmp power_off_done

installation_check_failure:
	mov ax, ERROR_INSTALLATION_CHECK
	jmp power_off_done
	
cannot_connect_interface:
	mov ax, ERROR_REAL_MODE_INTERFACE_CONNECTION
	jmp power_off_done
	
cannot_select_driver_version:
	mov ax, ERROR_APM_DRIVER_1P2_UNSUPPORTED
	
power_off_done:
	pop cx
	pop bx
	ret
