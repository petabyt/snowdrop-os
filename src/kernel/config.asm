;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains functionality for finding the startup app, by loading the 
; kernel configuration file, and reading kernel configuration properties.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

configFileName: db 'SNOWDROPCFG', 0		; FAT12 format

configFileSize: dw 0

configFileNotFound:		db 'Snowdrop OS kernel config file SNOWDROP.CFG '
						db 'was not found!', 0
configValueTempBuffer:			times 257 db 0
						
MAX_CONFIG_FILE_SIZE equ 4096
CONFIG_FILE_BUFFER_SIZE equ MAX_CONFIG_FILE_SIZE + 512
						; (extra bytes are needed since loading a file may
						; round up to the nearest 512 bytes because we cannot
						; load fractions of a sector)
configFileTooLarge:		db 'Kernel configuration file size cannot '
						db 'exceed 4096 bytes!', 0
configFileNoMemory:		db 'Cannot allocate memory for configuration file', 0

configFileBufferSeg:	dw 0
configFileBufferOff:	dw 0


; Returns the numeric value of the specified kernel configuration property
;
; input:			
;	 DS:SI - pointer to the name of the property to look up (zero-terminated)
; output:
;		AX - 0 when property was not found, other value otherwise
;		CX - numeric value when found
config_get_numeric_property_value:
	push ds
	push es
	push si
	push di
	
	push cs
	pop es
	mov di, configValueTempBuffer
	call config_get_property_value
	cmp ax, 0
	je config_get_numeric_property_value_done
	
	push cs
	pop ds
	mov si, configValueTempBuffer
	int 0BEh							; AX := integer value of property
	mov cx, ax							; return value in CX
	mov ax, 1							; success
	
config_get_numeric_property_value_done:
	pop di
	pop si
	pop es
	pop ds
	ret
						

; Returns the value of the specified kernel configuration property, by name.
;
; input:
;	 DS:SI - pointer to the name of the property to look up (zero-terminated)
;	 ES:DI - pointer to buffer into which property value will be read
; output:
;		AX - 0 when property was not found, another value otherwise
config_get_property_value:
	push fs
	push dx
	
	push word [cs:configFileBufferSeg]
	pop fs
	mov dx, word [cs:configFileBufferOff]	; FS:DX := config file buffer

	mov cx, word [cs:configFileSize]
	call params_get_parameter_value
	
	pop dx
	pop fs
	ret


; Prints all properties in the kernel configuration file
;
; input:
;		none
; output:
;		none
config_debug_list_all_properties:
	pusha
	push fs
	
	push word [cs:configFileBufferSeg]
	pop fs
	mov dx, word [cs:configFileBufferOff]	; FS:DX := config file buffer
	
	mov di, word [cs:configFileSize]
	call params_print_all_parameters
	
	pop fs
	popa
	ret


; Loads the Snowdrop OS kernel configuration file to memory.
;
; input:
;		none
; output:
;		none
config_load_config_file:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	; allocate
	mov ax, CONFIG_FILE_BUFFER_SIZE
	call dynmem_allocate					; DS:SI := buffer
	cmp ax, 0
	je config_no_mem
	
	; we got memory
	mov word [cs:configFileBufferSeg], ds
	mov word [cs:configFileBufferOff], si	; store
	
	push ds
	pop es
	mov di, si					; ES:DI points to config file buffer
								
	push cs
	pop ds
	mov si, configFileName		; DS:SI points to the config file name
	int 81h						; load config file
								; CX := file size
	cmp al, 0
	jne config_not_found ; did the config file fail to load?
	
	cmp cx, MAX_CONFIG_FILE_SIZE
	jae config_file_too_large
	
	mov word [cs:configFileSize], cx	; store file size
	
	pop es
	pop ds
	popa
	ret
config_no_mem:
	mov si, configFileNoMemory
	jmp crash_and_print
config_not_found:
	mov si, configFileNotFound
	call debug_println_string
	jmp crash
config_file_too_large:
	mov si, configFileTooLarge
	call debug_println_string
	jmp crash


; Unloads the Snowdrop OS kernel configuration file from memory.
;
; input:
;		none
; output:
;		none
config_unload_config_file:
	pusha
	push ds
	
	push word [cs:configFileBufferSeg]
	pop ds
	mov si, word [cs:configFileBufferOff]
	call dynmem_deallocate

	pop ds
	popa
	ret