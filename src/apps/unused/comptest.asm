;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The ????????????????????????????????????? app.
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

		
BUFFER_SIZE			equ 15000
RUN_COUNT			equ 100			; each buffer will contain this many runs
ITERATION_COUNT		equ 10 * 80

uncompressedBuffer:
	times BUFFER_SIZE db 'a'
uncompressedBufferEnd:
	times BUFFER_SIZE db 'b'	; some extra space in case random numbers
									; are crazy

compressedBuffer1: 		times BUFFER_SIZE+128 db 'H'
compressedBuffer2: 		times BUFFER_SIZE+128 db 'K'

lengthMismatch:		db 'Length mismatch', 0
contentsMismatch:	db 'Contents mismatch', 0
allOk:				db 'All OK', 0
intro:				db 'This application tests the data compression library', 13, 10
					db 'Deflating then inflating 10 x 80 buffers', 13, 10, 0

progress:			db 178, 0


start:
	mov si, intro
	int 80h
	
	mov cx, ITERATION_COUNT
main_loop:
	push cx
	call fill_buffer
	mov si, uncompressedBuffer
	mov cx, uncompressedBufferEnd-uncompressedBuffer		; length
	call verify
	
	mov si, progress
	int 80h
	
	pop cx
	loop main_loop
	
	mov si, allOk
	int 80h
	int 95h

	
; Fills uncompressedBuffer with random runs
;
; input:
;		none
; output:
;		none
fill_buffer:
	pusha
	pushf
	push es
	
	push cs
	pop es
	mov di, uncompressedBuffer
	
	cld
	
	mov dx, RUN_COUNT
	
fill_buffer_loop:
	cmp di, uncompressedBufferEnd
	jae fill_buffer_done

	int 86h									; AX := random
	test ax, 00000111b						; 1 in 8 chance to write single
	jz fill_buffer_write_run
fill_buffer_write_single:
	cmp dx, 0								; do we have runs left?
	je fill_buffer_write_run
	
	mov byte [es:di], ah
	inc di
	jmp fill_buffer_loop
fill_buffer_write_run:
	dec dx									; runs left--
	mov cx, BUFFER_SIZE / (2*RUN_COUNT)	; CX := run length
												; fill up approximately 
												; half the buffer with run
fill_buffer_write_run__loop:
	int 86h									; AX := random
	mov byte [es:di], ah
	inc di
	loop fill_buffer_write_run__loop
	
fill_buffer_done:
	pop es
	popf
	popa
	ret


	

; Compresses then decompresses the specified buffer and asserts that the
; decompressed buffer is equal to the original
;
; input:
;	 	SI - buffer to verify
;		CX - length of buffer to verify
; output:
;		none
verify:
	pushf
	pusha
	push ds
	push es
	
	push cx									; [1] save passed-in length
	push si									; [2]
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov di, compressedBuffer1
	call common_compress_deflate			; DX := output length

	mov si, compressedBuffer1
	mov di, compressedBuffer2
	call common_compress_inflate			; CX := inflated size
	
	pop si									; [2]
	pop bx									; [1] BX := passed-in length
	
	; assert inflated size is equal to initial length
	cmp bx, cx
	jne verify__length_mismatch
	
	; assert inflated buffer contents are equal to initial buffer contents
	cld
	repe cmpsb
	jne verify__contents_mismatch

	pop es
	pop ds
	popa
	popf
	ret
	
verify__contents_mismatch:
	push cs
	pop ds
	mov si, contentsMismatch
	int 80h
	int 95h									; exit
	
verify__length_mismatch:
	push cs
	pop ds
	mov si, lengthMismatch
	int 80h
	int 95h									; exit
	
	

%include "common\args.asm"
%include "common\compress.asm"
