;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FCOPY app.
; This app copies files on disk.
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

	bits 16
	org 0

	jmp start

sourceFileArg:	db 'file', 0
fat12SourceFilename:	times 20 db 0		; stores file name in FAT12 format

targetFileArg:	db 'target', 0
fat12TargetFilename:	times 20 db 0		; stores file name in FAT12 format

unknownError:		db 'Error: operation failed for an unknown reason', 0
diskFull:			db 'Error: disk is full', 0
maxFilesReached:	db 'Error: maximum number of files on disk has already been reached', 0
fileNotFound:		db 'Error: source file not found', 0
cannotBeSame:		db 'Error: the two file names must be different', 0
noMemoryString:		db 'Error: not enough memory', 0
usageString: 	db 13, 10
				db 'Example usage:    FCOPY [file=sm.txt] [target=sm_copy.txt]'
				db 13, 10, 0

successMessage1:	db 'Successfully copied ', 0
successMessage2:	db ' bytes.', 0

allocatedSegment:	dw 9999
largeNumberBufferString: times 16 db 0			; will hold the result of itoa
				
start:
	; read and store FAT12 version of source file name
	mov si, sourceFileArg
	mov di, fat12SourceFilename
	call read_file_name_argument
	
	; read and store FAT12 version of target file name
	mov si, targetFileArg
	mov di, fat12TargetFilename
	call read_file_name_argument

	mov si, fat12SourceFilename
	mov di, fat12TargetFilename
	int 0BDh							; compare file names
	cmp ax, 0
	je file_names_are_equal
	
	int 91h								; allocate memory
										; AX = 0 on success; BX := segment
	cmp ax, 0
	jne no_memory
	; here, BX = allocated segment
	mov word [cs:allocatedSegment], bx	; save allocated segment value
	
	mov si, fat12SourceFilename			; DS:SI := source file name
	mov es, bx
	mov di, 0							; ES:DI := start of allocated segment
	int 81h								; load file into ES:DI
	cmp al, 0							; success?
	jne source_file_not_found			; no
	; here, CX = source file size (in bytes)
	
	mov si, fat12TargetFilename			; DS:SI := target file name
										; ES:DI = start of allocated segment
										;         (from above)
										; CX = size of source file in bytes
	int 9Dh								; write file
	cmp ax, 1
	je max_files_reached
	cmp ax, 2
	je disk_full
	cmp ax, 0
	jne unknown_error
	; copy succeeded
	
	; convert copied file size to string
	mov dx, 0
	mov ax, cx					; DX:AX := size of copied file in bytes
	mov si, largeNumberBufferString
	mov bl, 4					; formatting option
	int 0A2h					; convert unsigned 32bit in DX:AX to string
	
	; report number of bytes copied
	mov si, successMessage1
	int 80h
	mov si, largeNumberBufferString
	int 80h
	mov si, successMessage2
	int 80h
	
	; clean up and exit
	mov word bx, [cs:allocatedSegment]	; BX := allocated segment
	int 92h								; free memory
	int 95h								; exit	
	
	

unknown_error:
	mov word bx, [cs:allocatedSegment]	; BX := allocated segment
	int 92h								; free memory
	mov si, unknownError
	int 80h
	int 95h								; exit		

disk_full:
	mov word bx, [cs:allocatedSegment]	; BX := allocated segment
	int 92h								; free memory
	mov si, diskFull
	int 80h
	int 95h								; exit	
	
max_files_reached:
	mov word bx, [cs:allocatedSegment]	; BX := allocated segment
	int 92h								; free memory
	mov si, maxFilesReached
	int 80h
	int 95h								; exit
	
source_file_not_found:
	mov word bx, [cs:allocatedSegment]	; BX := allocated segment
	int 92h								; free memory
	mov si, fileNotFound
	int 80h
	int 95h						; exit
	
no_memory:
	mov si, noMemoryString
	int 80h
	int 95h						; exit

file_names_are_equal:
	mov si, cannotBeSame
	int 80h
	int 95h						; exit
	
print_usage_and_exit:
	mov si, usageString
	int 80h
	int 95h						; exit


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
; Read file name from parameter, or show error and exit if value was invalid
; or not present.
;
; input:
;	 DS:SI - pointer to name of file argument
;	 ES:DI - pointer to where to store the FAT12 format version of the 
;			 argument value
; output:
;		none
read_file_name_argument:
	pusha
	pushf
	push ds
	
	; read value of argument 'file'
	call common_args_read_file_arg	; DS:SI := pointer to 8.3 file name
	cmp ax, 0
	jne read_file_name_argument_valid	; valid!

	; not found or invalid; show error message and exit
	push cs
	pop ds
	mov si, usageString
	int 80h
	int 95h							; exit program

read_file_name_argument_valid:
	; here, ES:DI points to where we'll store the FAT12 version of
	; the file name
	int 0A6h					; convert 8.3 file name to FAT12 format

	pop ds
	popf
	popa
	ret
	

%include "common\args.asm"
