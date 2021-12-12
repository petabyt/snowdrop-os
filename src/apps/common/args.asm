;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for dealing with program arguments.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ARGS_
%define _COMMON_ARGS_

argsFilenameParameterName:	db 'file', 0
argsFilenameBuffer:	times 257 db 0


; Read the value of the 'file' program argument and validate 
; that it contains an 8.3 file name.
;
; input:
;		none
; output:
;		AX - 0 when the argument was not found, or the value did not contain
;			 a valid 8.3 file name; other value otherwise
;	 DS:SI - pointer to value of program argument
common_args_read_file_file_arg:
	push cs
	pop ds
	mov si, argsFilenameParameterName
	call common_args_read_file_arg
	ret


; Read the value of the specified program argument and validate 
; that it contains an 8.3 file name.
;
; input:
;	 DS:SI - pointer to name of program argument
; output:
;		AX - 0 when the argument was not found, or the value did not contain
;			 a valid 8.3 file name; other value otherwise
;	 DS:SI - pointer to value of program argument
common_args_read_file_arg:
	push di
	push es
	
	push cs
	pop es
	
	mov di, argsFilenameBuffer
	int 0BFh					; read param value
	cmp ax, 0
	jne common_args_read_file_arg_found	; found!
	jmp common_args_read_file_arg_invalid
common_args_read_file_arg_found:
	; check whether the user entered a valid 8.3 file name
	push cs
	pop ds
	mov si, argsFilenameBuffer
	int 0A9h					; AX := 0 when file name is valid
	cmp ax, 0
	je common_args_read_file_arg_valid	; it's valid!
	; invalid
common_args_read_file_arg_invalid:
	mov ax, 0
	jmp common_args_read_file_arg_exit
	
common_args_read_file_arg_valid:
	; input was valid
	mov ax, 1							; success!
	
common_args_read_file_arg_exit:
	pop es
	pop di
	ret


%endif
