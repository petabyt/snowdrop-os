;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The DEFLATE app.
; This app compresses files.
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

sourceBufferTooLarge:	db 'Error: source file too large', 0
unknownError:		db 'Error: operation failed for an unknown reason', 0
diskFull:			db 'Error: disk is full', 0
maxFilesReached:	db 'Error: maximum number of files on disk has already been reached', 0
fileNotFound:		db 'Error: source file not found', 0
noMemoryString:		db 'Error: cannot allocate memory for source file', 0
noOutputSegmentMemoryString:
					db 'Error: cannot allocate memory for output buffer', 0
usageString: 	db 13, 10
				db 'Example usage:    DEFLATE [file=large.txt] [target=small.txt]'
				db 13, 10, 0

outputMessage1:	db 'Compressed to ', 0
outputMessage2:	db ' bytes. Writing output file...', 13, 10, 0
inputMessage1:	db 'Read in ', 0
inputMessage2:	db ' bytes. Compressing...', 13, 10, 0
readingMessage:	db 'Reading input file...', 13, 10, 0

fileLoadSegment:	dw 9999h
outputSegment:		dw 9999h					; stores deflated buffer
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
	
	int 91h								; allocate memory
										; AX = 0 on success; BX := segment
	cmp ax, 0
	jne no_memory
	; here, BX = allocated segment
	mov word [cs:fileLoadSegment], bx	; save allocated segment value

	int 91h								; allocate memory
										; AX = 0 on success; BX := segment
	cmp ax, 0
	jne no_memory_output_segment
	; here, BX = allocated segment
	mov word [cs:outputSegment], bx
	
	push cs
	pop ds
	mov si, readingMessage
	int 80h
	
	mov si, fat12SourceFilename			; DS:SI := source file name
	mov es, word [cs:fileLoadSegment]
	mov di, 0							; ES:DI := start of allocated segment
	int 81h								; load file into ES:DI
	cmp al, 0							; success?
	jne source_file_not_found			; no
	; here, CX = source file size (in bytes)

	; report input file size
	pusha
	push ds
	push cs
	pop ds
	mov ax, cx
	mov dx, 0					; DX:AX := input file size
	mov si, largeNumberBufferString
	mov bl, 4					; formatting option
	int 0A2h					; convert unsigned 32bit in DX:AX to string
	
	; report number of bytes copied
	mov si, inputMessage1
	int 80h
	mov si, largeNumberBufferString
	int 80h
	mov si, inputMessage2
	int 80h
	pop ds
	popa
	
	; deflate it!
	mov ds, word [cs:fileLoadSegment]
	mov si, 0
	mov es, word [cs:outputSegment]
	mov di, 0
	; CX already has source file size
	call common_compress_deflate		; DX := output length
	cmp ax, 0
	je too_large
	
	; report deflated size
	pusha
	push ds
	push cs
	pop ds
	
	mov ax, dx
	mov dx, 0					; DX:AX := deflated size
	mov si, largeNumberBufferString
	mov bl, 4					; formatting option
	int 0A2h					; convert unsigned 32bit in DX:AX to string
	
	; report number of bytes copied
	mov si, outputMessage1
	int 80h
	mov si, largeNumberBufferString
	int 80h
	mov si, outputMessage2
	int 80h
	pop ds
	popa	
	
	push cs
	pop ds
	mov si, fat12TargetFilename			; DS:SI := target file name
										; ES:DI = start of output segment
										;         (from above)
	mov cx, dx							; CX := compressed size
	int 9Dh								; write file
	cmp ax, 1
	je max_files_reached
	cmp ax, 2
	je disk_full
	cmp ax, 0
	jne unknown_error
		
	int 95h								; exit	
	

unknown_error:
	push cs
	pop ds
	mov si, unknownError
	int 80h
	int 95h								; exit		

too_large:
	push cs
	pop ds
	mov si, sourceBufferTooLarge
	int 80h
	int 95h								; exit
	
disk_full:
	push cs
	pop ds
	mov si, diskFull
	int 80h
	int 95h								; exit	
	
max_files_reached:
	push cs
	pop ds
	mov si, maxFilesReached
	int 80h
	int 95h								; exit
	
source_file_not_found:
	push cs
	pop ds
	mov si, fileNotFound
	int 80h
	int 95h								; exit
	
no_memory:
	push cs
	pop ds
	mov si, noMemoryString
	int 80h
	int 95h						; exit

no_memory_output_segment:
	push cs
	pop ds
	mov si, noOutputSegmentMemoryString
	int 80h
	int 95h						; exit

print_usage_and_exit:
	push cs
	pop ds
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
%include "common\compress.asm"
