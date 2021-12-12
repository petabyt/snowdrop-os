;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The MAKEBOOT app.
; This app makes a FAT12 floppy disk bootable (with Snowdrop OS) by:
;     - writing the Snowdrop OS boot loader to the disk's boot sector
;     - copying core Snowdrop OS files to the disk
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

allocatedSegment: dw 0			; we load files prior to copying

startingMessage: db "Starting...", 13, 10, 0
noMemoryMessage: db "Not enough memory. Exiting...", 0
confirmationMessage: 
 db 13, 10, "The MAKEBOOT utility copies the Snowdrop OS core to another disk"
 db 13, 10
 db 13, 10, "Press [Y] to begin", 13, 10, 
 db "Press any other key to exit", 13, 10, 0

doneMessage:
 db 13, 10
 db "Done copying the Snowdrop OS core. Your new disk is now bootable.", 13, 10
 db "You should now copy any desired apps, and then configure ", 13, 10
 db "Snowdrop OS by modifying SNOWDROP.CFG.", 13, 10, 0

INSTALL_MBR_CHOICE_ANSWER_UNPARTITIONED	equ 0
INSTALL_MBR_CHOICE_ANSWER_MBR			equ 1
installMbrChoice:				db 13, 10, 'Select boot sector type: (0=unpartitioned, 1=generic MBR): ', 0
installMbrChoiceBuffer:			db 0FFh

writeBootMessage:	db 13, 10, "Preparing to write boot loader", 13, 10, 0
readFileMessage:	db 13, 10, "Preparing to read ", 0
writeFileMessage:	db "Preparing to write ", 0
newlineMessage:			db 13, 10, 0

sourceDiskMessage:		db "Insert source disk and press [Y] to read", 13, 10, 0
targetDiskMessage:		db "Insert target disk and press [Y] to write", 13, 10, 0

kernelFilename:			db "SNOWDROP.KRN", 0
configFilename:			db "SNOWDROP.CFG", 0
fatImageFilename:		db "SNOWDROP.FAT", 0
mbrImageFilename:		db "SNOWDROP.MBR", 0

fatFileNameBuffer:		times 16 db 0

cannotWriteFileMessage: db "UNABLE TO WRITE FILE. EXITING...", 0
fileNotFoundMessage: 	db "UNABLE TO READ FILE. EXITING...", 0


start:
	mov si, confirmationMessage
	int 80h						; print confirmation
	int 83h						; clear keyboard buffer
	mov ah, 0
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_Y
	jne done					; if user did not press Y, we're done

	; user pressed Y, so begin
	mov si, startingMessage
	int 80h						; print "starting..."
	
	; allocate a segment, which we'll use as a temp buffer
	int 91h							; BX := allocated segment, AX:=0 on success
	cmp ax, 0
	jne done						; if AX != 0, memory was not allocated
	
	mov word [allocatedSegment], bx	; store allocated memory

	; step 1 - write boot loader to the target disk
	
	mov byte [cs:installMbrChoiceBuffer], INSTALL_MBR_CHOICE_ANSWER_UNPARTITIONED
									; assume unpartitioned
ask_loader_choice:
	mov si, installMbrChoice
	int 80h
	mov ah, 0
	int 16h							; read key
	cmp al, INSTALL_MBR_CHOICE_ANSWER_UNPARTITIONED + '0'
	je got_loader_choice			; already the assumed choice, so continue
	cmp al, INSTALL_MBR_CHOICE_ANSWER_MBR + '0'
	jne ask_loader_choice			; unsupported choice
	mov byte [cs:installMbrChoiceBuffer], INSTALL_MBR_CHOICE_ANSWER_MBR
got_loader_choice:
	mov si, writeBootMessage
	int 80h						; print
	mov si, targetDiskMessage
	int 80h						; print
boot_loader_wait_key:
	int 83h						; clear keyboard buffer
	mov ah, 0
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_Y
	jne boot_loader_wait_key	; if user did not press Y, read again	
	
	mov ah, 0
	mov al, byte [cs:installMbrChoiceBuffer]	; AX := sector choice
	int 0ACh					; write boot loader to disk

	; step 2 - copy core Snowdrop OS files to the target disk
	mov si, kernelFilename
	call transfer_file
	cmp ax, 1
	je cannot_write_file
	cmp ax, 2
	je file_not_found
	
	mov si, configFilename
	call transfer_file
	cmp ax, 1
	je cannot_write_file
	cmp ax, 2
	je file_not_found
	
	mov si, fatImageFilename
	call transfer_file
	cmp ax, 1
	je cannot_write_file
	cmp ax, 2
	je file_not_found
	
	mov si, mbrImageFilename
	call transfer_file
	cmp ax, 1
	je cannot_write_file
	cmp ax, 2
	je file_not_found
	
	; we're done!
	mov si, doneMessage
	int 80h						; print
	jmp deallocate
	
cannot_write_file:
	mov si, cannotWriteFileMessage
	int 80h
	jmp deallocate
	
file_not_found:
	mov si, fileNotFoundMessage
	int 80h
	
deallocate:
	mov bx, word [allocatedSegment]
	int 92h						; deallocate memory
	jmp done
	
no_memory:
	mov si, noMemoryMessage
	int 80h						; print
done:
	int 95h						; exit

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Prompts user, reads, prompts user, writes.
; 
; input:
;		DS:SI - pointer to 8.3 file name
; output:
;		AX - result, as follows:
;			0 = success
;			1 = could not write file to target disk
;			2 = file not found on source disk
transfer_file:
	pusha
	
	mov dx, si					; keep pointer to file name in DX
	
	mov si, readFileMessage
	int 80h						; print
	mov si, dx					; SI := file name
	int 80h						; print
	mov si, newlineMessage
	int 80h						; print
	mov si, sourceDiskMessage
	int 80h

transfer_file_wait_key1:
	int 83h						; clear keyboard buffer
	mov ah, 0
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_Y
	jne transfer_file_wait_key1	; if user did not press Y, read again
	
	; read file
	push es
	mov si, dx					; SI := file name
	mov di, fatFileNameBuffer
	int 0A6h					; convert file name to FAT12
	mov si, fatFileNameBuffer
	mov ax, word [allocatedSegment]
	mov es, ax
	mov di, 0
	int 81h						; read file
	pop es
	cmp al, 0
	jne transfer_file_not_found	; file not found, so we're done
	
	mov si, writeFileMessage
	int 80h						; print
	mov si, dx					; SI := file name
	int 80h						; print
	mov si, newlineMessage
	int 80h						; print
	mov si, targetDiskMessage
	int 80h

transfer_file_wait_key2:
	int 83h						; clear keyboard buffer
	mov ah, 0
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_Y
	jne transfer_file_wait_key2	; if user did not press Y, read again
	
	; write file
	push es
	mov si, fatFileNameBuffer
	mov ax, word [allocatedSegment]
	mov es, ax
	mov di, 0
	int 9Dh
	pop es
	cmp ax, 0
	jne transfer_file_cannot_write	; failed to write, so we're done
	; we finished successfully
	popa
	mov ax, 0					; return success
	ret
transfer_file_not_found:
	popa
	mov ax, 2					; return "file not found"
	ret
transfer_file_cannot_write:
	popa
	mov ax, 1					; return "cannot write file"
	ret


%include "common\scancode.asm"
