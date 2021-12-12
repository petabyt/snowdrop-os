;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains routines for installation of Snowdrop OS on a different disk
; than the one from which was booting.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INSTALL_PROGRESS_SECTORS_PER_STEP	equ 48
INSTALL_PROGRESS_STEPS				equ 60

installDiskListing0:		db '    disk ', 0
installDiskListing1:		db 'h geometry: ', 0
installDiskListNoGeometry:	db 'h - FAILED to get geometry', 0
installDiskGeometryComma:	db 'h, ', 0
installDiskGeometryEnd:		db 'h CHS ', 0
installDiskActive:			db '(active)', 0

installTempSegment:				dw 0
installSourceDriveNumber:		db 99
installDestinationDriveNumber:	db 99

installPromptMessage:		db ' - PRESS [Y] TO INSTALL TO ANOTHER DISK - ', 0

mbrFilename:	db 'SNOWDROPMBR', 0
INSTALL_MBR_CHOICE_ANSWER_UNPARTITIONED	equ 0
INSTALL_MBR_CHOICE_ANSWER_MBR			equ 1
installMbrChoiceAnswer:			db 0
installMbrChoice0:				db '0', 0
installMbrChoice1:				db '1', 0
installMbrChoice:				db 13, 10, '    boot sector choice: (0=unpartitioned, 1=generic MBR): ', 0
INSTALL_MBR_CHOICE_LENGTH		equ 1
installMbrChoiceBuffer:			times INSTALL_MBR_CHOICE_LENGTH + 1 db 0

installAllowPropertyName:		db 'install_allow', 0

installConfirmation:			db 13, 10
								db '    this DESTROYS existing data on disk. Enter "do it!" to begin: ', 0
installConfirmationPhrase:		db 'do it!', 0
installConfirmationPhraseEnd:
INSTALL_CONFIRMATION_LENGTH		equ installConfirmationPhraseEnd - installConfirmationPhrase - 1
installConfirmationBuffer:		times INSTALL_CONFIRMATION_LENGTH + 1 db 0

INSTALL_MAX_DISKS				equ 6
installAvailableDiskIds:		times INSTALL_MAX_DISKS db 99
													; stores up to 6 disks
installAvailableDiskCount:		db 99
installCurrentDiskPointer:		dw installAvailableDiskIds
													; pointer into disk ID array
installInitialDiskId:			db 99

installSelectDiskMessage:		db 13, 10, '    press SPACE to cycle through disks, ENTER to accept, ESCAPE to exit', 13, 10
								; intentionally non-terminated
installDiskIdMessage:			db 13, '    installation target disk: ', 0
installCurrentDiskMessage:		db 'h (active)', 0
installEraseCurrentDiskMessage:	db 'h         ', 0

installConfirmationCancelled:	db 13, 10, '    [SKIPPED - not confirmed]', 13, 10, 0

installProgressDecoration:		db 13, 10, '    installing: ', 0
installProgressDone:			db 13, 10, '    installation to disk complete'
								db 13, 10, '    computer must now be restarted - press ENTER to restart', 0
installRestarting:				db 13, 10, '    restarting', 0
installHaltingCpu:				db 13, 10, '    restart faild - halting CPU ', 0

installInitialMessage:			db '.installer', 0
installInitialMessageStarting:	db 13, '.installer - available disks:                                              ', 13, 10, 0
installInitialMessageNotAllowed:	db '.installer [SKIPPED - configured off]', 13, 10 ,0
installSkippedOnlyOneDisk:		db ' [SKIPPED - no additional disks detected]', 13, 10, 0
installSkippedNoGeometry:		db 13, 10, '    [SKIPPED - cannot get disk geometry]', 13, 10, 0
installCannotAllocate:			db 13, 10, '    COULD NOT ALLOCATE MEMORY', 13, 10, 0
installFailedToRead:			db 13, 10, '    FAILED TO READ - HALTING', 0

installSkippedDiskTooSmall:		db 13, 10
								db '    [SKIPPED - destination disk too small]'
								db 13, 10, 0
								
installSkippedFromMbr:			db 13, 10
								db '    [SKIPPED - invalid boot sector choice]'
								db 13, 10, 0
								
installSkippedInvalidDiskChoice:	db 13, 10
								db '    [SKIPPED - invalid disk choice or cancelled]'
								db 13, 10, 0

installSkipped:					db 13, '.installer [SKIPPED]                                                       '
								db 13, 10, 0


; Prompts the user to install Snowdrop OS to a disk.
; This is the entry point into the installer kernel boot-up step.
;
; input
;		none
; output:
;		none
install_prompt:
	pusha
	push ds
	push es
	
	push cs
	pop ds
	
	call install_is_allowed
	cmp ax, 0
	jne install_prompt_start			; it's allowed
	; it's not allowed
	
	mov si, installInitialMessageNotAllowed
	call debug_print_string
	jmp install_prompt_done				; nothing more to do

install_prompt_start:
	mov si, installInitialMessage
	call debug_print_string
		
	; check that there are at least 2 disks
	int 0C2h							; AL - ID of current disk
										; AH - number of disks
	mov byte [cs:installSourceDriveNumber], al	; store for later
	cmp ah, 2
	jb install_prompt_skipped_only_one_disk	; only one disk, so we skip
	
	; now prompt the user, giving him a chance to cancel the initialization
	; this is to cover the case of some newer hardware on which initializing
	; the mouse driver causes the keyboard to lock up immediately
	mov si, installPromptMessage
	mov bh, 'y'							; can press both lower case
	mov bl, 'Y'							; and upper case
	mov dl, byte [cs:userChoiceTimeoutSeconds]	; seconds to wait
	call utility_countdown_user_prompt	; AL := 1 if user pressed Y
	cmp al, 1
	jne install_prompt_skipped			; user chose to skip

	; print list of disks
	mov si, installInitialMessageStarting
	call debug_print_string
	call install_print_disk_info
	
	; now let the user select the destination disk
	call install_ask_user_for_drive		; DL := target disk
	cmp ax, 0
	je install_prompt_skipped_invalid_disk_choice
	mov byte [cs:installDestinationDriveNumber], dl		; save it
	
	; now validate disk geometry
	call install_get_drive_geometry		; AX := cylinders
										; BX := heads
										; CX := sectors
	jc install_prompt_skipped_cannot_get_geometry
	
	cmp ax, word [cs:diskCylinders]
	jb install_prompt_skipped_too_small
	cmp bx, word [cs:diskHeads]
	jb install_prompt_skipped_too_small
	cmp cx, word [cs:diskSectorsPerTrack]
	jb install_prompt_skipped_too_small
	
install_begin:
	; here, byte installSourceDriveNumber has been populated
	; here, byte installDestinationDriveNumber has been populated
	; destination disk has been validated
install_prepare_mbr:
	mov si, installMbrChoice
	call debug_print_string
	mov di, installMbrChoiceBuffer
	mov cx, INSTALL_MBR_CHOICE_LENGTH		; character limit
	int 0A4h								; read user input
	
	mov byte [cs:installMbrChoiceAnswer], INSTALL_MBR_CHOICE_ANSWER_UNPARTITIONED
											; assume
	
	mov si, installMbrChoice0				; unpartitioned - don't need MBR
	int 0BDh								; AX := 0 when strings are equal
	cmp ax, 0
	je install_confirm
	
	mov si, installMbrChoice1				; MBR
	int 0BDh								; AX := 0 when strings are equal
	cmp ax, 0
	jne install_prompt_skipped_from_mbr		; invalid choice
	; user chose MBR
	mov byte [cs:installMbrChoiceAnswer], INSTALL_MBR_CHOICE_ANSWER_MBR
	
install_confirm:
	; ask user for a confirmation, since this destroys existing data on disk
	mov si, installConfirmation
	call debug_print_string

	mov di, installConfirmationBuffer
	mov cx, INSTALL_CONFIRMATION_LENGTH		; character limit
	int 0A4h								; read user input
	
	mov si, installConfirmationPhrase
	int 0BDh								; AX := 0 when strings are equal
	cmp ax, 0
	je install_confirmed					; user has confirmed
	
	mov si, installConfirmationCancelled
	call debug_print_string
	
	jmp install_prompt_done					; confirmation phrase mismatch
	
install_confirmed:
	; allocate a sector to which we're reading the data
	int 91h								; BX := allocated segment
	cmp ax, 0
	je install_can_start				; no error
	
	mov si, installCannotAllocate
	call debug_print_string
	call debug_print_newline
	jmp install_prompt_done					; couldn't allocate memory

install_can_start:
	mov word [cs:installTempSegment], bx	; store allocated segment
	mov si, installProgressDecoration
	call debug_print_string
	
	mov cx, INSTALL_PROGRESS_STEPS
install_draw_progress:
	mov al, 176							; ASCII
	call debug_print_char
	loop install_draw_progress
	
	mov cx, INSTALL_PROGRESS_STEPS
install_return_cursor:
	mov al, 8							; backspace
	call debug_print_char
	loop install_return_cursor
	
	; this is the loop that actually copies data from that boot disk to
	; the destination disk
	mov cx, INSTALL_PROGRESS_STEPS
	mov di, 0							; we start from sector 0
install_loop:
	pusha
	mov cx, 5							; small delay to still animate progress
	int 85h								; bar when source drive is very fast
	popa
	
	mov al, byte [cs:installSourceDriveNumber]
	mov byte [cs:driveNumber], al		; set source drive as current
	
	; read INSTALL_PROGRESS_SECTORS_PER_STEP sectors to ES:BX
	mov dx, word [cs:installTempSegment]
	mov es, dx
	mov bx, 0							; ES:BX := allocated_segment:0000
	mov al, INSTALL_PROGRESS_SECTORS_PER_STEP
	pusha
	call floppy_read_sectors
	popa
	jc install_failed_to_read			; halt computer on error

	; write INSTALL_PROGRESS_SECTORS_PER_STEP sectors from ES:BX to disk
	push cx
	mov cl, byte [cs:installDestinationDriveNumber]
	mov byte [cs:driveNumber], cl		; set destination as current
	pop cx
	call floppy_write_sectors
	
	add di, INSTALL_PROGRESS_SECTORS_PER_STEP	; advance sector bookmark
	
	mov al, 178							; ASCII
	call debug_print_char				; print progress
	loop install_loop
	
	; now write either unpartitioned or MBR boot sector, depending on user choice
	cmp byte [cs:installMbrChoiceAnswer], INSTALL_MBR_CHOICE_ANSWER_MBR
	jne install_check_unpartitioned
	; write MBR boot sector
	mov ax, 1							; "MBR"
	call floppy_write_bootloader_entry_point
	jmp install_done
	
install_check_unpartitioned:
	cmp byte [cs:installMbrChoiceAnswer], INSTALL_MBR_CHOICE_ANSWER_UNPARTITIONED
	jne install_done
	; write unpartitioned boot sector
	mov ax, 0							; "unpartitioned"
	call floppy_write_bootloader_entry_point
	
install_done:
	mov si, installProgressDone
	call debug_print_string
install_done_wait_enter:
	mov ah, 0
	int 16h
	cmp ah, SCAN_CODE_ENTER
	jne install_done_wait_enter
	; restart
	mov si, installRestarting
	call debug_print_string
	mov ax, 1							; "restart computer"
	int 9Bh								; computer power system call
	; in case restart fails, halt CPU
	mov si, installHaltingCpu
	call debug_print_string
	jmp crash_halt_prepare
	
install_prompt_skipped_only_one_disk:
	mov si, installSkippedOnlyOneDisk
	call debug_print_string
	jmp install_prompt_done
	
install_prompt_skipped_invalid_disk_choice:
	mov si, installSkippedInvalidDiskChoice
	call debug_print_string
	jmp install_prompt_done
	
install_prompt_skipped_cannot_get_geometry:
	mov si, installSkippedNoGeometry
	call debug_print_string
	jmp install_prompt_done
	
install_failed_to_read:
	mov si, installFailedToRead
	call debug_print_string
	jmp crash_halt
	
install_prompt_skipped_too_small:
	mov si, installSkippedDiskTooSmall
	call debug_print_string
	jmp install_prompt_done
	
install_prompt_skipped_from_mbr:
	mov si, installSkippedFromMbr
	call debug_print_string
	jmp install_prompt_done
	
install_prompt_skipped:
	mov si, installSkipped
	call debug_print_string
	jmp install_prompt_done
	
install_prompt_done:
	pop es
	pop ds
	popa
	ret


; Prints available disk info on screen
;
; input
;		none
; output:
;		none								
install_print_disk_info:
	pusha
	push ds
	push es
	push fs
	push gs
	
	push cs
	pop ds
	
	int 0C2h				; AL := ID of current disk
							; AH := number of disks
							; BL := ID of first disk
							; BH := ID of second disk, if one exists
							; CL := ID of third disk, if one exists
							; CH := ID of fourth disk, if one exists
							; DL := ID of fifth disk, if one exists
							; DH := ID of sixth disk, if one exists
	
install_print_disk_info_loop:
	cmp ah, 0
	je install_print_disk_info_done
	push dx
	mov dl, bl
	call install_print_single_disk_info
	pop dx
	dec ah
	
	cmp ah, 0
	je install_print_disk_info_done
	push dx
	mov dl, bh
	call install_print_single_disk_info
	pop dx
	dec ah
	
	cmp ah, 0
	je install_print_disk_info_done
	push dx
	mov dl, cl
	call install_print_single_disk_info
	pop dx
	dec ah
	
	cmp ah, 0
	je install_print_disk_info_done
	push dx
	mov dl, ch
	call install_print_single_disk_info
	pop dx
	dec ah
	
	cmp ah, 0
	je install_print_disk_info_done
	push dx
	mov dl, dl
	call install_print_single_disk_info
	pop dx
	dec ah
	
	cmp ah, 0
	je install_print_disk_info_done
	push dx
	mov dl, dh
	call install_print_single_disk_info
	pop dx
	dec ah
	
install_print_disk_info_done:	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	ret


; Prints single disk info on screen
;
; input
;		AL - current drive number
;		DL - drive number
; output:
;		none
install_print_single_disk_info:
	push ds
	pusha
	
	push ax								; [1]
	
	mov si, installDiskListing0
	call debug_print_string
	mov al, dl
	call debug_print_byte

	call install_get_drive_geometry		; AX := cylinders
										; BX := heads
										; CX := sectors
	jc install_print_single_disk_info_no_geometry
	
	mov si, installDiskListing1
	call debug_print_string
										
	call debug_print_word				; print cylinders
	
	mov si, installDiskGeometryComma
	call debug_print_string
	mov ax, bx							; AX := heads
	call debug_print_word
	
	mov si, installDiskGeometryComma
	call debug_print_string
	mov ax, cx							; CX := sectors
	call debug_print_word

	mov si, installDiskGeometryEnd
	call debug_print_string
	
	pop ax								; [1]
	
	cmp al, dl
	jne install_print_single_disk_info_done
	
	mov si, installDiskActive
	call debug_print_string
	jmp install_print_single_disk_info_done
	
install_print_single_disk_info_no_geometry:
	add sp, 2							; [1] clean up stack
	
	mov si, installDiskListNoGeometry
	call debug_print_string
	
install_print_single_disk_info_done:
	call debug_print_newline
	
	popa
	pop ds
	ret
	

; Gets geometry of specified drive
;
; input
;		DL - drive number
; output:
;	 CARRY - set on error, clear otherwise
;		AX - cylinders
;		BX - heads
;		CX - sectors								
install_get_drive_geometry:
	push dx
	push si
	push di
	push ds
	push es
	push fs
	push gs
	
	mov ah, 8
	int 13h								; get disk parameters
	jc install_get_drive_geometry_fail
	cmp ah, 0
	jne install_get_drive_geometry_fail

	; figure out CHS geometry
	
	mov al, ch
	mov ah, cl
	shr ah, 6
	inc ax								; AX := cylinders
	push ax								; [1] save cylinders
	
	mov al, dh
	mov ah, 0
	inc ax								; AX := heads 
	push ax								; [2] save heads
	
	mov ah, 0
	mov al, cl
	and al, 00111111b					; AX := sectors
	push ax								; [3] save sectors
	
	pop cx								; [3] CX := sectors
	pop bx								; [2] BX := heads
	pop ax								; [1] AX := cylinders
install_get_drive_geometry_success:
	clc
	jmp install_get_drive_geometry_done
install_get_drive_geometry_fail:
	stc
install_get_drive_geometry_done:
	pop gs
	pop fs
	pop es
	pop ds
	pop di
	pop si
	pop dx
	ret


; Asks user to select a disk to be the installation target.
; Assumes there are at least two disks.
;
; input
;		none
; output:
;		AX - 0 when there was an error, other value otherwise
;		DL - disk selected by user
install_ask_user_for_drive:
	pushf
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push si
	push di
	
	; get available disk info
	int 0C2h					; get available disk information
	mov byte [cs:installAvailableDiskIds + 0], bl
	mov byte [cs:installAvailableDiskIds + 1], bh
	mov byte [cs:installAvailableDiskIds + 2], cl
	mov byte [cs:installAvailableDiskIds + 3], ch
	mov byte [cs:installAvailableDiskIds + 4], dl
	mov byte [cs:installAvailableDiskIds + 5], dh
	mov byte [cs:installAvailableDiskCount], ah

	; here, AL = ID of current disk
	mov byte [cs:installInitialDiskId], al	; store it for later
	
	mov ch, 0
	mov cl, ah							; CX := available disk count
	mov di, installAvailableDiskIds
	repne scasb
	dec di									; bring DI back to the match
	mov word [cs:installCurrentDiskPointer], di	; assumes current disk exists 
											; among those disks returned above
	
	call install_handle_change_disk		; call this automatically to get off
										; the active disk, if that's the
										; first disk
	mov si, installSelectDiskMessage
	call debug_print_string
install_ask_user_for_drive_loop:
	; re-display disk
	mov si, installDiskIdMessage
	call debug_print_string
	mov si, word [cs:installCurrentDiskPointer]
	mov al, byte [cs:si]
	call debug_print_byte					; print disk ID

	mov si, installEraseCurrentDiskMessage
	cmp al, byte [cs:installInitialDiskId]	; is current disk the initial disk?
	jne install_ask_user_for_drive_loop_wait_key		; no
	mov si, installCurrentDiskMessage		; yes, so print a note
install_ask_user_for_drive_loop_wait_key:
	call debug_print_string				; prints either (active) or blanks,
										; to erase a previous (active)
	mov ah, 0
	int 16h						; wait for key
	cmp ah, SCAN_CODE_ENTER
	je install_ask_user_for_drive_success
	cmp ah, SCAN_CODE_ESCAPE
	je install_ask_user_for_drive_fail
	cmp ah, SCAN_CODE_SPACE_BAR
	jne install_ask_user_for_drive_loop
	; space was pressed
	call install_handle_change_disk
	
	jmp install_ask_user_for_drive_loop		; loop again
	
install_ask_user_for_drive_fail:
	mov ax, 0
	jmp install_ask_user_for_drive_done
install_ask_user_for_drive_success:
	mov si, word [cs:installCurrentDiskPointer]
	mov dl, byte [cs:si]					; DL := selected disk
	
	mov ax, 1
install_ask_user_for_drive_done:
	pop di
	pop si
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	popf
	ret
	
	
; Cycles to the next available disk.
; Affects variables involved in disk selection by user.
; 
; input:
;		none
; output:
;		none
install_handle_change_disk:
	pusha
	pushf
	push ds
	push es
	
install_handle_change_disk_do:
	inc word [cs:installCurrentDiskPointer]
	
	mov ax, installAvailableDiskIds
	mov ch, 0
	mov cl, byte [cs:installAvailableDiskCount]
	add ax, cx							; AX := just after last disk
	cmp word [cs:installCurrentDiskPointer], ax
	jb install_handle_change_disk_done
	
	; we've gone past the end of available disks
	mov word [cs:installCurrentDiskPointer], installAvailableDiskIds
										; move to first disk
install_handle_change_disk_done:
	mov si, word [cs:installCurrentDiskPointer]
	mov dl, byte [cs:si]					; DL := selected disk
	cmp dl, byte [cs:installSourceDriveNumber]
	je install_handle_change_disk_do	; skip over active disk, since it
										; makes no sense as a destination disk
	pop es
	pop ds
	popf
	popa
	ret


; Checks the kernel configuration to see whether installation is allowed
;
; input
;		none
; output:
;		AX - 0 when not allowed, other value otherwise
install_is_allowed:
	push ds
	push es
	push fs
	push gs
	push bx
	push cx
	push dx
	push si
	push di
	
	push cs
	pop ds	
	mov si, installAllowPropertyName
	call config_get_numeric_property_value
	cmp ax, 0							; was the property found?
	je install_is_allowed_fail			; no
	cmp cx, 0							; check property value
	je install_is_allowed_fail			; it's off
	
	jmp install_is_allowed_success
	
install_is_allowed_fail:
	mov ax, 0
	jmp install_is_allowed_done
install_is_allowed_success:
	mov ax, 1
install_is_allowed_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop gs
	pop fs
	pop es
	pop ds
	ret