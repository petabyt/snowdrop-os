;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is the main Snowdrop OS kernel file. It includes other files 
; directly. It is a larger file because it contains all entry points into
; system services provided via interrupts.
;
; Despite the size of this file, it remains very readable, due to its list-like
; structure.
;
; It is responsible for:
;	- initialization of components
;	- setting up interrupt handlers to provide services to apps
;	- adding a task based on the startup application
;	- starting the scheduler, yielding control
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel contract:
; input:
;			drive number in AL
;			valid stack (SS and SP)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	bits 16
	org 0

	jmp kernel_start

KERNEL_MAX_TASKS_AND_VIRTUAL_DISPLAYS	equ 8
						; despite scheduler and display
						; modules being separate, how much space is statically
						; allocated for their storage must match
						; (this is why it is defined "above" those modules)
KERNEL_TEXT_VIDEO_MODE			equ 03h

userChoiceTimeoutSeconds:		db 0		; seconds to wait for user input
userChoiceTimeoutPropertyName:	db 'user_choice_timeout_seconds', 0
internalSpeakerPropertyName:	db 'internal_speaker', 0
mouseDivisorPropertyName:		db 'mouse_divisor', 0
mouseDivisorAcceleratedPropertyName:	db 'mouse_divisor_accelerated', 0
mouseConfigureOverridePropertyName:		db 'mouse_force_to', 0

initStartingString:			db 13, 10, 'Snowdrop OS kernel loaded. Now initializing:', 0
initInterruptsString:		db '.system call interrupts', 0
readConfigurationString: 	db '.configuration', 0

initSystemTimerString1:		db '.system timer (at ', 0
initSystemTimerString2:		db 'Hz)', 0

initRandomNumbersString:	db '.random number generator', 0
initMemoryManagerString:	db '.memory manager', 0
initSchedulerString:		db '.task scheduler', 0
initDisplayString:			db '.virtual display driver', 0
initSoundStringEnabled:		db '.sound driver (internal speaker)', 0
initSoundStringDisabled:	db '.sound driver [SKIPPED - CONFIGURED OFF]', 0
initKeyboardString:			db '.keyboard driver (IRQ1)', 0
initMessagingString:		db '.messaging', 0

initialDriveNumber:			db 99
initialSchedulerFlags:		dw 0
largeNumberBufferString: times 32 db 0			; will hold the result of itoa

initMouseString:			db '.PS/2 mouse driver - PRESS [Y] TO OVERRIDE - ', 0
initMouseNoDeviceString:	db 13, '.PS/2 mouse driver [SKIPPED - DEVICE NOT FOUND]                           ', 0
initMouseSkippedOverriddenOffString:	db '.PS/2 mouse driver [SKIPPED - configured off]', 0
initPseudoMouseLoadedString:	db 13,'.PS/2 mouse driver (keyboard-based pseudo driver)                             ', 0
initMouseLoadedString:		db 13, '.PS/2 mouse driver (IRQ12)                                                    ', 0
					; the 13 is "carriage return" - similar to pressing Home
initMouseSkippedString:		db 13, '.PS/2 mouse driver [SKIPPED]                                                  ', 0
					; the 13 is "carriage return" - similar to pressing Home

initSerialLoadedString1:		db '.serial port driver (IRQ4, base I/O at ', 0
initSerialLoadedString2:		db 'h)', 0
initSerialNotFoundString:		db '.serial port driver [SKIPPED - PORT NOT FOUND]', 0
					
initParallelLoadedString1:		db '.parallel port driver (base I/O at ', 0
initParallelLoadedString2:		db 'h)', 0
initParallelNotFoundString:		db '.parallel port driver [SKIPPED - PORT NOT FOUND]', 0

interruptsInitialized:			db 0

; the kernel workspace segment is organized as such:
;   start offset    end offset      length   purpose
;              0         2FFFh       3000h   file system driver work memory
;          3000h         FDFFh       CE00h   kernel general purpose memory
;                        
; at runtime, kernel general purpose memory can contain:
;           512b for unpartitioned loader sector
;           512b for MBR loader sector
;           512b (param buffer) + 4096b (virtual display) per task
kernelWorkspaceSegment:			dw 0		; 64kb of memory needed by kernel
KERNEL_DYN_MEMORY_START_OFFSET	equ 3000h	; low 12k reserved for file system
KERNEL_DYN_MEMORY_LENGTH		equ 0CE00h


kernel_start:
	push cs
	pop ds
	push cs
	pop es

	mov byte [cs:initialDriveNumber], al ; AL = drive number (from boot loader)
	
	mov word [cs:kernelWorkspaceSegment], cs
	add word [cs:kernelWorkspaceSegment], 1000h	; save workspace segment
	
	mov ah, 0Fh							; function 0F is "get video mode" in AL
	int 10h
	cmp al, KERNEL_TEXT_VIDEO_MODE		; is it the right one?
	je kernel_start_after_video_mode	; yes
	
	; set video mode
	mov ah, 0							; function 0 is "set video mode"
	mov al, KERNEL_TEXT_VIDEO_MODE
	int 10h								; set video mode

kernel_start_after_video_mode:
	; calculate and save scheduler's flags value (used when starting a task)
	sti									; some machines start out with 
										; interrupts disabled, so we'll enable
	cld									; by contract, when tasks are started,
	pushf								; the direction flag is cleared
	pop word [cs:initialSchedulerFlags]	; store flags for now

	; start initialization
	call debug_print_newline
	mov si, initStartingString
	call debug_println_string
kernel_initialize_components:
	; now initialize the kernel

	; WARNING: do NOT initialize any other kernel modules before the timer!
	call kernel_init_timer				; the timer is a dependency of other
										; kernel initialization steps, and 
										; must occur before all other kernel
										; components are initialized
	call kernel_init_memory
	call kernel_init_interrupts

	call kernel_init_random
	call kernel_init_messaging
	call kernel_init_scheduler
	
	call kernel_init_filesystem
	call kernel_read_configuration
	
	call install_prompt
	
	call kernel_init_keyboard
	call kernel_init_mouse
	call kernel_init_serial
	call kernel_init_parallel
	call kernel_init_display
	call kernel_init_sound

	jmp startup_start_app
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; we do not return from this call
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subroutines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kernel_init_keyboard:
	pusha
	
	mov si, initKeyboardString
	call debug_println_string
	
	call keyboard_initialize
	
	popa
	ret
	

kernel_init_filesystem:
	pusha
	
	mov ax, word [cs:kernelWorkspaceSegment]
	mov bl, byte [cs:initialDriveNumber]
	call floppy_initialize
	
	popa
	ret


kernel_read_configuration:
	pusha
	push fs

	mov si, readConfigurationString
	call debug_println_string
	
	call config_load_config_file
	
	mov si, userChoiceTimeoutPropertyName
	mov di, configValueTempBuffer
	call config_get_property_value		; configValueTempBuffer := value of 
										; user choice timeout
	cmp ax, 0							; was the property found?
	jne kernel_read_configuration_parse	; yes!
	; no, use a default value
	mov byte [cs:userChoiceTimeoutSeconds], 2
	jmp kernel_read_configuration_exit
	
kernel_read_configuration_parse:
	mov si, configValueTempBuffer
	int 0BEh						; AX := user choice timeout integer
	mov byte [cs:userChoiceTimeoutSeconds], al	; store it

kernel_read_configuration_exit:
	pop fs
	popa
	ret
	

kernel_init_timer:
	pusha
	
	mov si, initSystemTimerString1
	call debug_print_string
	
	; install NOOP higher-level timer handler
	mov al, 0B8h
	mov bx, kernel_interrupt_noop
	call kernel_set_interrupt
	
	; install callback handler
	mov al, 1Ch
	mov bx, kernel_interrupt_user_timer
	call kernel_set_interrupt

	call timer_initialize
	
	; display frequency
	mov dx, 0
	call timer_get_frequency	; DX:AX := frequency
	mov si, largeNumberBufferString
	mov bl, 4					; formatting option 4: no leading spaces
								; with commas
	call string_unsigned_32bit_itoa ; convert unsigned 32bit in DX:AX to string
	call debug_print_string
	mov si, initSystemTimerString2
	call debug_println_string
	
	; install explicitly-invoked handlers
	mov al, 84h
	mov bx, kernel_interrupt_timer_get_current_ticks
	call kernel_set_interrupt
	
	mov al, 85h
	mov bx, kernel_interrupt_timer_delay
	call kernel_set_interrupt
	
	popa
	ret

kernel_init_display:
	pusha
	
	mov si, initDisplayString
	call debug_println_string
	
	call display_initialize
	
	popa
	ret
	
kernel_init_memory:
	pusha
	
	mov si, initMemoryManagerString
	call debug_print_string
	
	mov ax, cs							; this segment + 2000h is used as the 
	add ax, 2000h						; first allocatable segment
	call memory_initialize
	
	popa
	ret
	
kernel_init_scheduler:
	pusha
	
	mov si, initSchedulerString
	call debug_println_string
	
	mov ax, word [cs:initialSchedulerFlags] ; AX := initial FLAGS, calculated
											; when kernel was entered
	call scheduler_initialize
	
	popa
	ret
	
kernel_init_random:
	pusha
	
	mov si, initRandomNumbersString
	call debug_println_string
	
	call random_initialize
	
	popa
	ret

kernel_init_messaging:
	pusha
	
	mov si, initMessagingString
	call debug_println_string
	
	call messages_initialize

	popa
	ret

	
kernel_init_sound:
	pusha
	
	mov si, internalSpeakerPropertyName
	mov di, configValueTempBuffer
	call config_get_property_value		; configValueTempBuffer := value
	cmp ax, 0							; was the property found?
	je kernel_init_sound_enable			; no, so enable by default
	; parse property value
	mov si, configValueTempBuffer
	int 0BEh							; AX := integer value of property
	cmp ax, 0
	jne kernel_init_sound_enable		; it's enabled!
kernel_init_sound_disable:
	mov ax, 0
	mov si, initSoundStringDisabled
	call debug_println_string
	jmp kernel_init_sound_proceed
kernel_init_sound_enable:
	mov ax, 1
	mov si, initSoundStringEnabled
	call debug_println_string
kernel_init_sound_proceed:
	call speaker_initialize
	call sound_initialize
	
	popa
	ret


; Helper function - set mouse parameters from configuration
;
kernel_init_mouse_read_config:
	pusha
	; divisor
	mov si, mouseDivisorPropertyName
	mov di, configValueTempBuffer
	call config_get_property_value		; configValueTempBuffer := value
	cmp ax, 0							; was the property found?
	je kernel_init_mouse_read_config_after_divisor	; no, so enable by default
	; parse property value
	mov si, configValueTempBuffer
	int 0BEh							; AX := integer value of property
	call mouse_manager_set_divisor		; set value
kernel_init_mouse_read_config_after_divisor:
	; divisor for under acceleration
	mov si, mouseDivisorAcceleratedPropertyName
	mov di, configValueTempBuffer
	call config_get_property_value		; configValueTempBuffer := value
	cmp ax, 0							; was the property found?
	je kernel_init_mouse_read_config_done	; no, so enable by default
	; parse property value
	mov si, configValueTempBuffer
	int 0BEh							; AX := integer value of property
	call mouse_manager_set_divisor_accelerated	; set value

kernel_init_mouse_read_config_done:
	popa
	ret
	

kernel_init_mouse:
	pusha
	
	call mouse_general_initialize_preliminary
	; this has initialized the mouse driver type to whatever was in
	; the configuration file
	; it may changed, since we haven't yet asked user
	
	mov si, mouseConfigureOverridePropertyName	; is it overridden in config?
	call config_get_numeric_property_value
	cmp ax, 0							; was the property found and numeric?
	je kernel_init_mouse_ask_user		; no
	cmp cx, 0							; check property value
	je kernel_init_mouse_overridden_off	; it's forced off
	; it's forced on
	jmp kernel_init_mouse_enable
	
kernel_init_mouse_ask_user:	
	; now prompt the user, giving him a chance to cancel the initialization
	; this is to cover the case of some newer hardware on which initializing
	; the mouse driver causes the keyboard to lock up immediately

	call mouse_prompt					; AX := 0 when user wants no mouse
										;		1 when user wants pseudo mouse
										;		2 when user wants real mouse
										;		3 when user does nothing
	cmp ax, 3
	je kernel_init_mouse_enable
	cmp ax, 2
	je kernel_init_mouse_enable__hardware
	cmp ax, 1
	je kernel_init_mouse_enable__pseudo
	jmp kernel_init_mouse_skipped		; we're skipping the mouse driver
	
kernel_init_mouse_enable:
	; user did not override or was forced in configuration,
	; so we proceed with loading the mouse driver
	; using whatever type was set in the configuration file
	call mouse_get_configured_driver_type	; AX := 0(hardware) or 1(pseudo)
	cmp ax, 0
	je kernel_init_mouse_enable__hardware

kernel_init_mouse_enable__pseudo:
	; we're configuring a pseudo-mouse, which is keyboard-driven
	mov si, initPseudoMouseLoadedString
	call debug_println_string
	
	mov cx, MOUSE_DRIVER_TYPE_PSEUDO
	call mouse_set_configured_driver_type
	
	call kernel_init_mouse_register_high_level_interrupts
	
	mov al, 74h						; when in pseudo-mouse, we want IRQ12
	mov bx, kernel_interrupt_noop_with_ack_master_slave	
									; to be NOOP, but still acknowledge
	call kernel_set_interrupt		; the interrupt request
	call mouse_pseudo_initialize
	
	call mouse_general_mark_driver_loaded
	popa
	ret
kernel_init_mouse_enable__hardware:
	; we're configuring a hardware mouse
	
	; we only check for a hardware mouse if configured driver type is hardware
	call mouse_device_is_present		; is a PS/2 mouse installed?
	cmp ax, 0
	je kernel_init_mouse_no_device		; no	
	; a PS/2 mouse is installed
	
	mov si, initMouseLoadedString
	call debug_println_string
	
	mov cx, MOUSE_DRIVER_TYPE_HARDWARE
	call mouse_set_configured_driver_type
	
	call mouse_initialize
	call kernel_init_mouse_read_config		; configure mouse per config file

	call kernel_init_mouse_register_high_level_interrupts
	
	mov al, 74h							; kernel hardware interrupt, via IRQ12
	mov bx, kernel_mouse_irq_handler	; it is called by the PIC when PS/2
	call kernel_set_interrupt			; controller has data for us
	
	call mouse_general_mark_driver_loaded
	popa
	ret
kernel_init_mouse_overridden_off:
	mov si, initMouseSkippedOverriddenOffString
	call debug_println_string
	popa
	ret
kernel_init_mouse_skipped:	
	mov si, initMouseSkippedString
	call debug_println_string
	popa
	ret
kernel_init_mouse_no_device:
	mov si, initMouseNoDeviceString
	call debug_println_string
	popa
	ret
	

; Helper: registers mouse driver interrupts that are common to
; all driver types
;
; input
;		none
; output
;		none
kernel_init_mouse_register_high_level_interrupts:
	pusha
	
	mov al, 0C0h								; this handler receives mouse
	mov bx, kernel_interrupt_noop				; state data every time a
	call kernel_set_interrupt					; mouse event is raised by
												; the hardware
												; (requires mouse manager to
												; have been initialized)
	
	mov al, 8Bh										 ; this interrupt receives
	mov bx, kernel_mouse_irq_handler_state_changed_raw ; raw PS/2 data from the
	call kernel_set_interrupt						 ; IRQ12 handler below
	
	mov al, 8Ch								; this interrupt returns raw
	mov bx, kernel_mouse_interrupt_poll_raw	
											; PS/2 data when called explicitly
	call kernel_set_interrupt				; by consumers
	
	mov al, 8Fh								; this interrupt returns mouse 
	mov bx, kernel_mouse_irq_handler_manager_poll	; coordinates when called 
	call kernel_set_interrupt				; by consumers
	
	mov al, 90h
	mov bx, kernel_mouse_irq_handler_manager_initialize
	call kernel_set_interrupt
	
	popa
	ret

	
kernel_init_serial:
	pusha

	call serial_initialize
	
	mov al, 0AFh
	mov bx, kernel_serial_blocking_send
	call kernel_set_interrupt
	
	mov al, 0AEh						; serial IRQ4 handler calls this after
	mov bx, kernel_serial_noop_user_handler	; reading a byte
	call kernel_set_interrupt			; meant to be replaced by consumers
	
	call serial_get_driver_status
	cmp al, 0
	je kernel_init_serial_skipped		; driver was not loaded
	
	; port was found, so finish initialization
	mov al, 0Ch							; kernel hardware interrupt, via IRQ4
	mov bx, kernel_serial_irq_handler	; it is called by the PIC
	call kernel_set_interrupt
	
	; print "initialized" message, along with the base I/O address
	mov si, initSerialLoadedString1
	call debug_print_string
	call serial_get_base_address		; AX := serial port base I/O address
	call debug_print_word
	mov si, initSerialLoadedString2
	call debug_println_string
	
	popa
	ret
kernel_init_serial_skipped:	
	mov si, initSerialNotFoundString	; print "not found"
	call debug_println_string
	
	popa
	ret
	
	
kernel_init_parallel:
	pusha

	call parallel_initialize
	mov al, 0B6h
	mov bx, kernel_parallel_send
	call kernel_set_interrupt
	
	call parallel_get_driver_status		; AL := 1 when driver is loaded
	cmp al, 1
	je kernel_init_parallel_found		; the driver is loaded
	
	mov si, initParallelNotFoundString	; print "not found"
	call debug_println_string
	jmp kernel_init_parallel_done		; we're done
kernel_init_parallel_found:
	; print "initialized" message, along with the base I/O address
	mov si, initParallelLoadedString1
	call debug_print_string
	call parallel_get_base_address		; AX := parallel port base I/O address
	call debug_print_word
	mov si, initParallelLoadedString2
	call debug_println_string
kernel_init_parallel_done:
	popa
	ret
	
	
kernel_init_interrupts:
	pusha
	
	mov si, initInterruptsString
	call debug_println_string
	
	mov al, 80h
	mov bx, kernel_interrupt_print_string
	call kernel_set_interrupt
	
	mov al, 81h
	mov bx, kernel_interrupt_load_file
	call kernel_set_interrupt

	mov al, 82h
	mov bx, kernel_interrupt_string_to_uppercase
	call kernel_set_interrupt

	mov al, 83h
	mov bx, kernel_interrupt_clear_keyboard_buffer
	call kernel_set_interrupt
	
	mov al, 86h
	mov bx, kernel_get_next_random_number
	call kernel_set_interrupt

	mov al, 87h
	mov bx, kernel_interrupt_load_directory
	call kernel_set_interrupt

	mov al, 88h
	mov bx, kernel_interrupt_print_dump_vram
	call kernel_set_interrupt

	mov al, 89h
	mov bx, kernel_interrupt_speaker_play
	call kernel_set_interrupt
	
	mov al, 8Ah
	mov bx, kernel_interrupt_speaker_stop
	call kernel_set_interrupt
	
	mov al, 8Dh		; we define this mouse-specific interrupt here, since it
					; always has to be present (even when driver is not loaded)
	mov bx, kernel_mouse_irq_handler_driver_status
	call kernel_set_interrupt
	
	mov al, 8Eh
	mov bx, kernel_interrupt_print_byte
	call kernel_set_interrupt

	mov al, 91h
	mov bx, kernel_allocate_memory
	call kernel_set_interrupt
	
	mov al, 92h
	mov bx, kernel_free_memory
	call kernel_set_interrupt

	mov al, 93h
	mov bx, kernel_scheduler_add_task
	call kernel_set_interrupt
	
	mov al, 94h
	mov bx, kernel_scheduler_task_yield
	call kernel_set_interrupt
	
	mov al, 95h
	mov bx, kernel_scheduler_task_exit
	call kernel_set_interrupt
	
	mov al, 96h
	mov bx, kernel_interrupt_activate_virtual_display_of_task
	call kernel_set_interrupt
	
	mov al, 97h
	mov bx, kernel_interrupt_display_write_string
	call kernel_set_interrupt
	
	mov al, 98h
	mov bx, kernel_interrupt_display_write_character
	call kernel_set_interrupt
	
	mov al, 99h
	mov bx, kernel_scheduler_get_task_status
	call kernel_set_interrupt
	
	mov al, 9Ah
	mov bx, kernel_scheduler_get_current_task_id
	call kernel_set_interrupt
	
	mov al, 9Bh
	mov bx, kernel_power_service
	call kernel_set_interrupt
	
	mov al, 9Ch
	mov bx, kernel_interrupt_delete_file
	call kernel_set_interrupt
	
	mov al, 9Dh
	mov bx, kernel_interrupt_write_file
	call kernel_set_interrupt
	
	mov al, 9Eh
	mov bx, kernel_interrupt_display_set_cursor_position
	call kernel_set_interrupt
	
	mov al, 9Fh
	mov bx, kernel_interrupt_display_write_attribute
	call kernel_set_interrupt

	mov al, 0A0h
	mov bx, kernel_interrupt_display_clear_screen
	call kernel_set_interrupt
	
	mov al, 0A1h
	mov bx, kernel_interrupt_get_free_file_slots_count
	call kernel_set_interrupt
	
	mov al, 0A2h
	mov bx, kernel_interrupt_unsigned_32bit_to_string
	call kernel_set_interrupt
	
	mov al, 0A3h
	mov bx, kernel_interrupt_get_available_disk_space
	call kernel_set_interrupt
	
	mov al, 0A4h
	mov bx, kernel_interrupt_user_input_read_line
	call kernel_set_interrupt
	
	mov al, 0A5h
	mov bx, kernel_interrupt_string_length
	call kernel_set_interrupt
	
	mov al, 0A6h
	mov bx, kernel_interrupt_convert_dot_filename_to_fat12
	call kernel_set_interrupt
	
	mov al, 0A7h
	mov bx, kernel_interrupt_display_dump_screen
	call kernel_set_interrupt
	
	mov al, 0A8h
	mov bx, kernel_interrupt_print_dump
	call kernel_set_interrupt
	
	mov al, 0A9h
	mov bx, kernel_interrupt_string_validate_dot_filename
	call kernel_set_interrupt
	
	mov al, 0AAh
	mov bx, kernel_get_cursor_position
	call kernel_set_interrupt
	
	mov al, 0ABh
	mov bx, kernel_interrupt_format_disk
	call kernel_set_interrupt
	
	mov al, 0ACh
	mov bx, kernel_interrupt_write_bootloader
	call kernel_set_interrupt
	
	mov al, 0ADh	; we define this serial-specific interrupt here, since it
					; always has to be present (even when driver is not loaded)
	mov bx, kernel_interrupt_serial_driver_status
	call kernel_set_interrupt
	
	mov al, 0B0h
	mov bx, kernel_interrupt_handler_install
	call kernel_set_interrupt
	
	mov al, 0B1h
	mov bx, kernel_interrupt_read_fat_image
	call kernel_set_interrupt
	
	mov al, 0B2h
	mov bx, kernel_interrupt_read_character_attribute
	call kernel_set_interrupt
	
	mov al, 0B3h
	mov bx, kernel_interrupt_convert_fat12_to_dot_filename
	call kernel_set_interrupt
	
	mov al, 0B4h
	mov bx, kernel_interrupt_dump_registers		; defined in included file
	call kernel_set_interrupt
	
	mov al, 0B5h
	mov bx, kernel_interrupt_set_task_lifetime
	call kernel_set_interrupt
	
	mov al, 0B7h	; we define this parallel-specific interrupt here, since it
					; always has to be present (even when driver is not loaded)
	mov bx, kernel_interrupt_parallel_driver_status
	call kernel_set_interrupt
	
	; 0B8h is registered elsewhere, and is the user timer interrupt
	
	mov al, 0B9h
	mov bx, kernel_interrupt_add_sound
	call kernel_set_interrupt

	mov al, 0BAh
	mov bx, kernel_interrupt_get_key_status
	call kernel_set_interrupt
	
	mov al, 0BBh
	mov bx, kernel_interrupt_get_keyboard_driver_mode
	call kernel_set_interrupt
	
	mov al, 0BCh
	mov bx, kernel_interrupt_set_keyboard_driver_mode
	call kernel_set_interrupt
	
	mov al, 0BDh
	mov bx, kernel_interrupt_string_compare
	call kernel_set_interrupt
	
	mov al, 0BEh
	mov bx, kernel_interrupt_unsigned_16bit_atoi
	call kernel_set_interrupt
	
	mov al, 0BFh
	mov bx, kernel_scheduler_get_current_task_parameter
	call kernel_set_interrupt
	
	; 0C0h is registered elsewhere, and is the mouse manager event callback
	; handler
	
	mov al, 0C1h
	mov bx, kernel_sound_queue_clear
	call kernel_set_interrupt
	
	mov al, 0C2h
	mov bx, kernel_disk_get_info
	call kernel_set_interrupt
	
	mov al, 0C3h
	mov bx, kernel_set_current_disk
	call kernel_set_interrupt
	
	mov al, 0C4h
	mov bx, kernel_messaging_functions
	call kernel_set_interrupt
	
	mov al, 0C5h
	mov bx, kernel_extra_mouse_manager_functions
	call kernel_set_interrupt
	
	mov al, 0C6h
	mov bx, kernel_extra_scheduler_functions
	call kernel_set_interrupt
	
	call kernel_register_noop_user_handlers		; registers 0F0h to 0FFh
	
	mov byte [cs:interruptsInitialized], 1
	
	popa
	ret

	
; Registers NOOP interrupt handlers for all custom user interrupts,
; 0F0h to 0FFh.
;
kernel_register_noop_user_handlers:
	pusha

	mov bx, kernel_interrupt_noop
	mov al, 0EFh
kernel_register_noop_user_handlers_loop:
	inc al
	call kernel_set_interrupt
	cmp al, 0FFh
	jb kernel_register_noop_user_handlers_loop
	
	popa
	ret
	

; Helper used by kernel initialization code to register interrupt handler
;
; input:
;			interrupt handler pointer offset in BX
;			interrupt vector number in AL
kernel_set_interrupt:
	pusha
	push es
	
	push cs
	pop es
	mov di, bx						; ES:DI := pointer to interrupt handler
	call interrupt_handler_install
	
	pop es
	popa
	ret


; Installs the specified interrupt handler, returning a pointer to the old
; (previous) interrupt handler.
;
; input
;		AL - interrupt number
;		ES:DI - pointer to interrupt handler to install
; output:
;		DX:BX - pointer to old interrupt handler
kernel_interrupt_handler_install:
	pushf
	push ax
	push cx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call interrupt_handler_install
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop cx
	pop ax
	popf
	
	iret
	
	
; input:
;		AL - byte to print
kernel_interrupt_print_byte:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call display_vram_print_byte
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
; input:
;		DS:SI pointer to string
kernel_interrupt_print_string:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	; write directly to the video ram
	call display_vram_output_string
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret

	
; Invoked after a byte has been read from the serial port.
; Meant to be replaced by user interrupt handlers, whenever a user program
; wants to receive bytes from the serial port.
;
; input:
;		AL - byte read from serial port
kernel_serial_noop_user_handler:
	iret


; Prints a specified number of characters from a string	to the
; current task's virtual display
;
; input:
;		DS:SI - pointer to string
;		CX - number of characters to print
kernel_interrupt_print_dump:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_print_dump
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret

	
; Prints a specified number of characters from a string	to vram
;
; input:
;		DS:SI - pointer to string
;		CX - number of characters to print
kernel_interrupt_print_dump_vram:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call display_vram_print_dump
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; input:
;		DS:SI pointer to string
kernel_interrupt_string_to_uppercase:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call string_to_uppercase
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	

; input:
;		none
; output:
;		none	
kernel_sound_queue_clear:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call common_sound_queue_clear
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; Sets current disk
;
; input
;		AL - ID of disk to be made current
; output
;		AX - 0 when operation succeeded
;			 1 when operation failed because the specified disk does not exist
kernel_set_current_disk:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call fat12_set_current_disk
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret

	
; Extra scheduler functions
;
; Function 0: set task target on next yield.
; input:
;		AH - 0
;		BX - task ID of task which will become active after on next yield
; output:
;		AX - not preserved (reserved for future functionality)
kernel_extra_scheduler_functions:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	cmp ah, 0
	je kernel_extra_scheduler_functions_0
	jmp kernel_extra_scheduler_functions_done

kernel_extra_scheduler_functions_0:
	mov ax, bx								; AX := task
	call scheduler_set_next_task
	jmp kernel_extra_scheduler_functions_done
	
kernel_extra_scheduler_functions_done:
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	

; Extra mouse manager functions
;
; Function 0: move mouse to specified location. NOOP if 
; coordinates are out of bounds.
; input:
;		AH - 0
;		DX - Y coordinate
;		BX - X coordinate
; output:
;		AX - not preserved (reserved for future functionality)
kernel_extra_mouse_manager_functions:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	cmp ah, 0
	je kernel_extra_mouse_manager_functions_0
	jmp kernel_extra_mouse_manager_functions_done

kernel_extra_mouse_manager_functions_0:
	call mouse_manager_move_to
	jmp kernel_extra_mouse_manager_functions_done
	
kernel_extra_mouse_manager_functions_done:
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	

; Messaging functions
;
; Function 0: subscribe to be notified of messages of the specified type
; input
;		AH - 0
;	 DS:SI - pointer to message type string, no longer than 32 characters
;	 DX:BX - pointer to consumer function; consumer contract:
;		input:
;			 DS:SI - pointer to message bytes
;			 ES:DI - pointer to message type
;				CX - message bytes length
;		output:
;			none
;		Consumer may not add or remove consumers
; output
;		AX - not preserved (reserved for future functionality)
;
; Function 1: unsubscribe all consumers subscribed by the current task
; input
;		AH - 1
; output
;		AX - not preserved (reserved for future functionality)
;
; Function 2: unsubscribe all consumers subscribed to the specified message 
; type, by the current task
; input
;		AH - 2
;	 ES:DI - message type
; output
;		AX - not preserved (reserved for future functionality)
;
; Function 3: publish a message of the specified type
; input
;		AH - 3
;	 DS:SI - pointer to message contents
;	 ES:DI - message type
;		CX - length of message contents
; output
;		AX - not preserved (reserved for future functionality)
kernel_messaging_functions:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	cmp ah, 0
	je kernel_messaging_functions_0
	cmp ah, 1
	je kernel_messaging_functions_1
	cmp ah, 2
	je kernel_messaging_functions_2
	jmp kernel_messaging_functions_done

kernel_messaging_functions_0:
	call messages_subscribe_task
	jmp kernel_messaging_functions_done
kernel_messaging_functions_1:
	call scheduler_has_started			; AX := 0 if scheduler not started
	cmp ax, 0
	je kernel_messaging_functions_done
	
	int 9Ah								; AX := current task ID
	mov dx, ax
	call messages_unsubscribe_all_by_task
	jmp kernel_messaging_functions_done
kernel_messaging_functions_2:
	call messages_publish
	jmp kernel_messaging_functions_done
	
kernel_messaging_functions_done:
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	
; Returns disk information
;
; input
;		none
; output
;		AL - ID of current disk
;		AH - number of drives
;		BL - ID of first disk
;		BH - ID of second disk, if one exists
;		CL - ID of third disk, if one exists
;		CH - ID of fourth disk, if one exists
;		DL - ID of fifth disk, if one exists
;		DH - ID of sixth disk, if one exists
kernel_disk_get_info:
	pushf
	push si
	push di
	push ds
	push es
	push fs
	push gs
	
	call fat12_get_disk_info
	
	pop gs
	pop fs
	pop es
	pop ds
	pop di
	pop si
	popf
	iret
	

; Converts a 32-bit unsigned integer to a decimal string.
; Adds ASCII 0 terminator at the end of the string.
; Works for numbers between 0 and 655,359,999 (270FFFFFh), inclusive, only.
;
; input
;		DX:AX - number to convert, no larger than 655,359,999 (270FFFFFh)
;		DS:SI - pointer to buffer where the result will be stored
;				(must be a minimum of 16 bytes long)
;		   BL - formatting option, as follows (for input 834104):
;				0 - no formatting, eg: "000834104"
;				1 - leading spaces, eg: "   834104"
;				2 - leading spaces and commas, eg: "   834,104"
;				3 - no leading spaces, eg: "834104"
;				4 - no leading spaces with commas, eg: "834,104"
; output
;		none
kernel_interrupt_unsigned_32bit_to_string:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call string_unsigned_32bit_itoa
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	

; input:
;		none
kernel_interrupt_clear_keyboard_buffer:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call keyboard_clear_bios_buffer
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret

; input:
;		DS:SI - pointer to first character of the string
kernel_interrupt_display_write_string:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call scheduler_has_started				; AX := 0 if scheduler not started
	cmp ax, 0
	jne kernel_interrupt_display_write_string_has_task	; use current task
	
	; scheduler not yet started, so output directly to video memory
	call display_vram_output_string
	jmp kernel_interrupt_display_write_string_done
	
kernel_interrupt_display_write_string_has_task:
	; use current task's virtual display
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_output_string
	
kernel_interrupt_display_write_string_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Sets the position of the cursor in the display of the current task
;
; input
;		BH - cursor row
;		BL - cursor column
; output
;		none
kernel_interrupt_display_set_cursor_position:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_set_cursor_position
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	

; Writes attribute byte to the current task's virtual display
;
; input
;		CX - repeat this many times
;		DL - attribute byte
; output
;		none
kernel_interrupt_display_write_attribute:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_write_attribute
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	

; Clears the current task's virtual display, moves cursor to row 0, column 0, 
; and sets all attributes to light gray on black
;
; input
;		none
; output
;		none
kernel_interrupt_display_clear_screen:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_clear_screen
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Reads a complete floppy FAT image in preparation for a disk format operation.
;
; input:
;		ES:DI - pointer to where file data will be loaded
;				(must be able to hold at least 32kb)
;				(must not cross any 64kb boundaries)
; output:
;		AL - status (0=success, 1=not found)
kernel_interrupt_read_fat_image:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call floppy_read_fat_image_entry_point
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	
	
; Returns the current status (pressed or not pressed) of the specified key
;
; Input:
;		BL - scan code
; Output:
;		AL - pressed/not pressed status, as such:
;				0 - not pressed
;				otherwise pressed
kernel_interrupt_get_key_status:
	pushf
	push bx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call keyboard_get_key_status
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop bx
	popf
	iret
	
	
; Converts a 16-bit string representation of a decimal unsigned integer to  
; the respective unsigned integer.
;
; input
;		 DS:SI - pointer to string representation of integer (zero-terminated)
; output
;			AX - resulting integer
kernel_interrupt_unsigned_16bit_atoi:
	pushf
	push bx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call string_unsigned_16bit_atoi
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop bx
	popf
	iret
	
	
; Formats the current disk with the specified FAT12 image.
;
; WARNING: DESTROYS BOOT SECTOR AND ALL FILES PRESENT ON THE DISK.
;
; input:
;		DS:SI - pointer to FAT12 image
; output:
;		none
kernel_interrupt_format_disk:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call floppy_format_disk_entry_point
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	

; Writes the Snowdrop OS boot loader to the current disk.
;
; input
;		AX - 0=unpartitioned, 1=MBR, other value NOOP
; output
;		none
kernel_interrupt_write_bootloader:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call floppy_write_bootloader_entry_point
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret	

	
; Changes the way the keyboard driver functions
;
; Input:
;		AX - driver mode, as follows:
;			0 - off; delegate everything to previous handler (BIOS usually)
;			1 - on; ignore previous handler
; Output:
;		none
;
kernel_interrupt_set_keyboard_driver_mode:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call keyboard_set_driver_mode
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; Returns the current keyboard driver mode
;
; Input:
;		none
; Output:
;		AX - driver mode, as follows:
;			0 - off; delegate everything to previous handler (BIOS usually)
;			1 - on; ignore previous handler
;
kernel_interrupt_get_keyboard_driver_mode:
	pushf
	push bx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call keyboard_get_driver_mode
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop bx
	popf
	iret
	

; Dumps the virtual display of the current task.
; Dumps the vram if the specified virtual display is the 
; active virtual display.
; The buffer must be able to store 4000 bytes (80 columns x 25 rows x 2 bytes).
;
; input
;	 ES:DI - pointer to where the virtual display will be dumped
;            (must be able to store 4000 bytes)
; output
;		none
kernel_interrupt_display_dump_screen:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_dump_screen
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	

; input:
;		DL - ASCII character to print	
kernel_interrupt_display_write_character:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs

	call scheduler_has_started				; AX := 0 if scheduler not started
	cmp ax, 0
	jne kernel_interrupt_display_write_character_has_task	; use current task
	
	; scheduler not yet started, so output directly to video memory
	call display_output_character_to_vram
	jmp kernel_interrupt_display_write_character_done
	
kernel_interrupt_display_write_character_has_task:
	; output to the virtual display of the current task
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_output_character
	
kernel_interrupt_display_write_character_done:
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret

	
; This is registered with the hardware interrupt (IRQ) in charge of 
; transmitting PS/2 mouse events
;
; input:
;		none
kernel_mouse_irq_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call mouse_irq_handler
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; This is the serial port IRQ handler, called whenever the hardware has data
; available for us.
; It reads all available data on the serial port, calling a user interrupt
; for each byte that it read.
; The default user interrupt handler is NOOP.
;
; For non-blocking (interrupt-driven) serial port reading, consumers are 
; expected to replace the user interrupt handler with their own.
;
; input:
;		none
kernel_serial_irq_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call serial_irq_handler
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; This handler is a software interrupt called by the mouse hardware interrupt
; whenever it accumulates enough state bytes.
; It is meant to be overridden by a user interrupt handler whenever a user 
; program needs to interact with the mouse in a more advanced fashion, by 
; having access to the raw PS/2 data.
;
; input:
;		BH - bit 7 - Y overflow
;			 bit 6 - X overflow
;			 bit 5 - Y sign bit
;			 bit 4 - X sign bit
;			 bit 3 - unused and indeterminate
;			 bit 2 - middle button
;			 bit 1 - right button
;			 bit 0 - left button
;		DH - X movement (delta X)
;		DL - Y movement (delta Y)
kernel_mouse_irq_handler_state_changed_raw:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call mouse_state_changed_raw_handler
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; Initializes the mouse manager, which allows for polling by consumer programs.
; Also puts the mouse cursor at the centre of the bounding box.
;
; input:
;		BX - width of the bounding box within which the mouse cursor will move
;		DX - height of the bounding box within which the mouse cursor will move
kernel_mouse_irq_handler_manager_initialize:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call mouse_manager_initialize
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; input:
;		none
kernel_interrupt_user_timer:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call timer_callback
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Reads characters from the keyboard into the specified buffer.
; It reads no more than the specified limit, and adds a terminator character
; of ASCII 0 at the end, once the user presses Enter to finish inputting.
; The specified buffer must have enough room for one more character than the
; specified count.
; Echoes typed characters to the current task's virtual display.
;
; input
;		CX - maximum number of characters to read
;	 ES:DI - pointer to buffer (must fit CX+1 characters)
; output
;		none
kernel_interrupt_user_input_read_line:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call utilities_input_read_user_line
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; Adds a sound with the specified characteristics to the sound queue. 
;
; Input:
;		AX - frequency (see int 89h documentation for example frequencies)
;		CL - length of sound in timer ticks (one tick is 10ms)
;		DX - per-tick frequency delta (used to change frequency every tick)
;		CH - sound mode, where:
;				0 - normal (queued sound)
;				1 - immediate (automatically becomes next to play)
;				2 - exclusive (all other sounds are removed, queue is locked
;					while this sound plays)
; Output:
;		none
kernel_interrupt_add_sound:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call common_sound_queue_add
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret

; input:
;		AX - ID (offset) of task whose virtual display is to be made active
; output:
;		none
kernel_interrupt_activate_virtual_display_of_task:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs

	call scheduler_get_display_id_for_task ; AX := display ID of specified task
	call display_activate				   ; make display active

	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Converts a 8.3 dot file name to a fixed-size, padded, upper-case 
; FAT12-compliant file name.
; Must contain a dot.
; Must have between 1 and 8 characters before the dot.
; Must have between 1 and 3 characters after the dot.
;
; Example: "abcd.000" is converted to "ABCD    000"
;          "abcdefgh.aaa" is converted to "ABCDEFGHAAA"
;          "abc" is converted to "ABC        "
;
; input:
;		DS:SI - pointer to 8.3 dot file name
;		ES:DI - pointer to buffer to hold the resulting FAT12 file name
; output:
;		(none, but fills buffer passed in)
kernel_interrupt_convert_dot_filename_to_fat12:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs

	call string_convert_dot_filename_to_fat12

	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Converts a FAT12-compliant file name to a 8.3 dot file name 
;
; Example: "ABCD    000" is converted to "ABCD.000"
;          "ABCDEFGHAAA" is converted to "ABCDEFGH.AAA"
;          "ABC       A" is converted to "ABC.A"
; input:
;		DS:SI - pointer to FAT12-compliant file name
;		ES:DI - pointer to buffer to hold the resulting 8.3 dot file name
;				(must be able to hold at least 13 characters)
; output:
;		(none, but fills buffer passed in)
kernel_interrupt_convert_fat12_to_dot_filename:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs

	call string_convert_fat12_to_dot_filename

	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; input:
;			DS:SI pointer to 11-byte buffer containing 
;				  file name in FAT12 format
;			ES:DI pointer to where file data will be loaded
; output:
;			AL - status (0=success, 1=not found)
;			CX - file size in bytes
; Note: This interrupt is NOT reentrant
kernel_interrupt_load_file:
	pushf
	push bx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call floppy_load_file_entrypoint
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop bx
	popf
	
	iret
	

; input:
;		none
; output:
;		BH - bit 7 - Y overflow
;			 bit 6 - X overflow
;			 bit 5 - Y sign bit
;			 bit 4 - X sign bit
;			 bit 3 - always 1
;			 bit 2 - middle button
;			 bit 1 - right button
;			 bit 0 - left button
;		DH - X movement (delta X)
;		DL - Y movement (delta Y)
kernel_mouse_interrupt_poll_raw:
	pushf
	push ax
	push cx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call mouse_get_configured_driver_type
	cmp ax, MOUSE_DRIVER_TYPE_HARDWARE
	jne kernel_mouse_interrupt_poll_raw__pseudo
	call mouse_poll_raw
	jmp kernel_mouse_interrupt_poll_raw_done
	
kernel_mouse_interrupt_poll_raw__pseudo:
	call mouse_pseudo_poll_raw
	
kernel_mouse_interrupt_poll_raw_done:
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop cx
	pop ax
	popf
	
	iret


; Returns the current mouse location (in user coordinates), and buttons state.
;
; output:
;		AL - bits 3 to 7 - unused and indeterminate
;			 bit 2 - middle button current state
;			 bit 1 - right button current state
;			 bit 0 - left button current state
;		BX - X position in user coordinates
;		DX - Y position in user coordinates
kernel_mouse_irq_handler_manager_poll:
	pushf
	push cx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call mouse_manager_poll
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop cx
	popf	
	iret


; input:
;			none
; output:
;			AL = 1 when driver is loaded, 0 otherwise
kernel_mouse_irq_handler_driver_status:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call mouse_get_driver_status
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	
	
; Blocks until the serial port is ready to send.
; Once that happens, it sends the specified byte.
; USES PORT COM1 BY DEFAULT.
;
; input:
;		AL - byte to send
; output:
;		none
kernel_serial_blocking_send:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call serial_blocking_send
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; Sends the specified data byte to the parallel port's data pins
; USES PORT LPT1 BY DEFAULT.
;
; input:
;		AL - byte to send
kernel_parallel_send:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call parallel_send
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; input:
;			none
; output:
;			AL = 1 when driver is loaded, 0 otherwise
kernel_interrupt_serial_driver_status:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call serial_get_driver_status
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	
	iret
	
	
; input:
;			none
; output:
;			AL = 1 when driver is loaded, 0 otherwise
;			DX = port base address (only if driver is loaded)
kernel_interrupt_parallel_driver_status:
	pushf
	push bx
	push cx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call parallel_get_driver_status
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop cx
	pop bx
	popf
	
	iret
	
	
; input:
;			none
; output:
;			current ticks count in AX
kernel_interrupt_timer_get_current_ticks:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call timer_get_current_ticks
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret

	
; Compares two strings ASCII-wise
;
; input
;		  DS:SI - pointer to first string
;		  ES:DI - pointer to second string
; output
;			AX - 0 when the strings are equal
;				 1 when the first string is lower (ASCII-wise)
;				 2 when the second string is lower (ASCII-wise)
kernel_interrupt_string_compare:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call string_compare
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	
	
; Returns the amount of available disk space, in bytes
;
; input:
;		none
; output:
;		DX:AX - amount of available disk space, in bytes
;				(least significant bytes in AX, most significant bytes in DX)
kernel_interrupt_get_available_disk_space:
	pushf
	push bx
	push cx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call floppy_get_available_disk_space_entry_point
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop cx
	pop bx
	popf
	iret
	

; input:
;		number of system timer ticks to wait in CX
kernel_interrupt_timer_delay:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call timer_delay
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; Deallocates a segment
;
; input
;		BX - segment to deallocate
kernel_free_memory:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call memory_free_segment
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret	
	

; Play a sound
;
; input
;			frequency number (see table) in AX
kernel_interrupt_speaker_play:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call speaker_play_note
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret

	
; The entry point into the "delete file" workflow
;
; input:
;		DS:SI - pointer to 11-byte buffer containing file name in FAT12 format
; output:
;		none (fails silently)
kernel_interrupt_delete_file:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call floppy_delete_file_entry_point
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
	
	
; Stop sound being played
;
; input
;			none
kernel_interrupt_speaker_stop:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call speaker_stop
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret

	
; Invoked when the current task wishes to yield to another task
; NOTE: unlike a regular interrupt handler, this does not return; instead,
;       it saves the return address and task state, and makes the scheduler
;       run the next task in the list. The scheduler will consume the return
;       address presently pushed on the stack
kernel_scheduler_task_yield:
	jmp scheduler_task_yield


; Invoked when the current task wishes to exit

; NOTE: unlike a regular interrupt handler, this does not return; instead,
;       it makes the scheduler run the next task in the list. The scheduler 
;       will consume the return address presently pushed on the stack
;
kernel_scheduler_task_exit:
	pusha
	
	; first, we will switch to the virtual display of the exiting task's 
	; parent task, if the exiting task's display is active
	call scheduler_get_current_task_id		; AX := current (exiting) task ID
	call scheduler_get_display_id_for_task	; AX := display ID of exiting task
	mov bx, ax								; BX := display ID of exiting task
	call display_get_active_display_id		; AX := active display ID
	cmp bx, ax								; is exiting task's display active?
	jne kernel_scheduler_task_exit_after_parent_display_activation	; no
	
	; yes, switch to parent's display
	call scheduler_get_current_task_id		; AX := current (exiting) task ID
	call scheduler_get_parent_task_id		; AX := ID of current task's parent
	call scheduler_get_display_id_for_task	; AX := display ID of parent task
	call display_activate					; switch to display with ID in AX
	
kernel_scheduler_task_exit_after_parent_display_activation:
	call scheduler_get_current_task_lifetime	; AX := lifetime mode
	cmp ax, 0				
	; "keep memory"?
	jne kernel_scheduler_task_exit_deallocate	; no, so we deallocate
	
	; task is keeping memory, so we mark all of its segments as not owned
	; this is to prevent their accidental deallocation when a task with the
	; same ID is created and then exits
	call scheduler_get_current_task_id		; AX := current (exiting) task ID
	call memory_mark_unowned_by_owner
	jmp kernel_scheduler_task_exit_perform

kernel_scheduler_task_exit_deallocate:
	call scheduler_get_current_task_id		; AX := current (exiting) task ID
	; unsubscribe any message consumers subscribed by exiting task
	mov dx, ax								; DX := exiting task ID
	call messages_unsubscribe_all_by_task
	; deallocate memory
	call memory_free_by_owner
	
	; now perform the task exit
kernel_scheduler_task_exit_perform:
	popa
	jmp scheduler_task_exit
	

; Specify a segment containing an app, which will be run by the scheduler
;
; input
;			BX - segment containing the app that must be run as a task
;		 DS:SI - pointer to string containing serialized parameter data for the 
;				 task being created (maximum 256 bytes)
; output
;			AX - ID (offset) of newly created task
kernel_scheduler_add_task:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp

	call display_allocate	; allocate new virtual display for our new task
							; AX := virtual display ID							
	mov dx, ax				; scheduler_add_task expects display ID in DX
	call scheduler_add_task	; AX := task ID
	
	; here, BX = allocated segment
	call memory_set_task_owner

	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	
	
; input:
;			ES:DI pointer to where the root directory will be loaded
; output:
;			number of 32-byte FAT12 root directory entries in AX
kernel_interrupt_load_directory:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call floppy_load_root_directory_entrypoint
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	
	iret

	
; Allocates a 64kb memory segment for consumer to use
;
; output
;		AX - 0 when allocation succeeded
;		BX - segment number of the newly allocated segment, when successful
kernel_allocate_memory:
	pushf
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call memory_allocate_segment		; BX := segment
	cmp ax, 0
	jne kernel_allocate_memory_done		; failure
	; allocation succeeded
	
	call scheduler_has_started			; AX := 0 when not started
	cmp ax, 0
	je kernel_allocate_memory_done_success	; nothing more to do
	; scheduler has started, so we can set memory's owner task
	
	; here, BX = allocated segment
	call scheduler_get_current_task_id	; AX := task
	call memory_set_task_owner
	
kernel_allocate_memory_done_success:
	mov ax, 0
kernel_allocate_memory_done:
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	popf
	
	iret
	
	
; input:
;			none
; output:
;			next random number in AX
kernel_get_next_random_number:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call random_get_next
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf	
	iret

	
; input:
;			none
; output:
;			AX - ID (offset) of the current task
kernel_scheduler_get_current_task_id:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call scheduler_get_current_task_id
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret


; Gets the value of the specified parameter, of the currently running task
;
; input:
;	 DS:SI - pointer to the name of the parameter to look up (zero-terminated)
;	 ES:DI - pointer to buffer into which parameter value will be read
; output:
;		AX - 0 when parameter was not found, another value otherwise
kernel_scheduler_get_current_task_parameter:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_task_parameter		; AX := 0 when param not found
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret


; Reads a character and attribute from the current task's virtual display, 
; from the specified location
;
; input:
;		BH - location row
;		BL - location column
; output:
;		AH - attribute byte
;		AL - ASCII character byte
kernel_interrupt_read_character_attribute:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_read_character_attribute
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	

; Gets the cursor position in the current task's virtual display
;
; input
;		none
; output
;		BH - row
;		BL - column
kernel_get_cursor_position:
	pushf
	push ax
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call scheduler_get_current_task_id		; AX := current task ID
	call scheduler_get_display_id_for_task	; AX := display ID of current task
	call display_wrapper_get_cursor_position
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	popf
	iret
	

; Returns the number of free root directory entries
;
; input:
;		none
; output:
;		CX - number of free root directory entries
kernel_interrupt_get_free_file_slots_count:
	pushf
	push ax
	push bx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call floppy_get_free_root_directory_entries_entrypoint
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop bx
	pop ax
	popf
	iret
	
	
; Writes a file with the specified name to the disk
;
; input:
;		DS:SI - pointer to 11-byte buffer containing file name in FAT12 format
;		ES:DI - pointer to file contents buffer (cannot cross 64kb boundaries)
;		   CX - size of file content in bytes
; output:
;			AX - status, as such:
;				0 = success
;				1 = failure: maximum number of files reached
;				2 = failure: disk full
kernel_interrupt_write_file:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call floppy_write_file_entry_point
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	

; Returns the length of a ASCII 0 terminated string
;
; input
;		DS:SI - pointer to string
; output
;		   BX - string length, not including terminator
kernel_interrupt_string_length:
	pushf
	push ax
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call string_length
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	popf
	iret
	

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
kernel_power_service:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call power_service
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	

; Checks whether the specified 8.3 dot file name is valid:
;	Must contain one dot.
;	Must have between 1 and 8 characters before the dot.
;	Must have between 1 and 3 characters after the dot.
;
; Example: "abcd.000"
;          "abcdefgh.aaa"
;          "abc.a"
; input:
;	 DS:SI - pointer to 8.3 dot file name
; output:
;		AX - 0 when the file name is a valid 8.3 file name
kernel_interrupt_string_validate_dot_filename:
	pushf
	push bx
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call string_validate_dot_filename
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	popf
	iret
	

; input
;		AX - task ID (offset)
; output
;		AX - status:
;				0FFFFh - not present
;				otherwise - present
;		BX - 1 when this task's virtual display is currently active, 0 otherwise
kernel_scheduler_get_task_status:
	pushf
	push cx
	push dx
	push si
	push di
	
	push ds
	push es
	push fs
	push gs
	push bp

	mov dx, ax								; save task ID
	call scheduler_get_task_status			; AX := task status of task in AX
	cmp ax, 0FFFFh							; is the task ID invalid?
	je kernel_scheduler_get_task_status_done ; yes
	; task exists, so we can continue to fill in the other return values
	
	mov ax, dx								; AX := task ID
	call scheduler_get_display_id_for_task	; AX := display ID of task
	mov bx, ax								; BX := display ID of task
	call display_get_active_display_id		; AX := active display ID
	cmp ax, bx								; is the task's display active?
	je kernel_scheduler_get_task_status_active	; yes
	
	; no, it's not active
	mov bx, 0								; return "task display not active"
	mov ax, dx								; AX := task ID
	call scheduler_get_task_status			; return task status of task in AX
	jmp kernel_scheduler_get_task_status_done

kernel_scheduler_get_task_status_active:
	mov bx, 1								; return "task display is active"
	mov ax, dx								; AX := task ID
	call scheduler_get_task_status			; return task status of task in AX
kernel_scheduler_get_task_status_done:
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop di
	pop si
	pop dx
	pop cx
	popf
	
	iret


; Sets the lifetime of the current task
; 
; input
;		BL - lifetime parameters
;			bit 0 - when set, keep memory after task exit
;           bit 1-7 - unused
; output
;		none
kernel_interrupt_set_task_lifetime:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	call scheduler_get_current_task_id		; AX := current (exiting) task ID
	call scheduler_set_task_lifetime
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret


; A dummy interrupt handler
;
kernel_interrupt_noop:
	iret


; A dummy interrupt handler which acknowledges the interrupt with
; both master and slave PIC
;
kernel_interrupt_noop_with_ack_master_slave:
	pusha
	mov al, 20h
	out 0A0h, al					; send EOI to slave PIC
	out 20h, al						; send EOI to master PIC
	popa
	iret
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Drivers, services, utilities, etc., which are part of the kernel
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "params.asm"	; logic for dealing with serialized parameter lists
%include "startup.asm"	; logic for starting the startup app

%include "fat12.asm"	; FAT12 driver - high level routines and entry points
						; relies on functionality from files below
%include "fat12fat.asm"	; FAT12 driver - allocation table routines
%include "fat12dir.asm"	; FAT12 driver - root directory routines
%include "fat12ut.asm"	; FAT12 driver - utilities
%include "fat12fmt.asm"	; FAT12 driver - formatting routines

%include "mouse.asm"	; highest-level, general mouse driver routines
%include "mousepsd.asm"	; pseudo-mouse driver
%include "mousecom.asm"	; PS/2 mouse driver communication routines (low level)
%include "mousemgr.asm"	; PS/2 mouse driver user-facing routines (high level)

%include "serial.asm"	; serial port communications driver

%include "debug.asm"	; debugging utilities
%include "crash.asm"	; routines for dealing with unrecoverable errors
%include "string.asm"	; string routines
%include "keyboard.asm"	; keyboard routines
%include "config.asm"	; routines for working with kernel config files
%include "timer.asm"	; system timer
%include "speaker.asm"	; low-level IBM PC internal speaker routines
%include "memory.asm"	; memory manager for memory segments
%include "mem_dyn.asm"	; memory manager module for dynamic memory
%include "messages.asm"	; messaging system
%include "sched.asm"	; task scheduler
%include "power.asm"	; APM interfacing code (power management)
%include "intr.asm"		; routines for interrupt handler management
%include "parallel.asm"	; parallel port driver
%include "install.asm"	; allows user to install Snowdrop OS to another disk
%include "sound.asm"	; sound driver (internal speaker)
%include "version.asm"	; values that usually change with each version
%include "util_cdn.asm"	; utilities - countdown-based user choice input
%include "util_inp.asm"	; utilities - read line of text from user
%include "util_dbg.asm"	; utilities - registry/stack dumping
%include "util_lst.asm"	; utilities - linked lists
%include "scancode.asm"	; keyboard scan code definitions

%include "displayh.asm"	; CRT hardware driver (low level)
%include "displayv.asm"	; virtual display driver (low level)
%include "display.asm"	; virtual display user-facing (high level)
						; relies on displayh and displayv from above
