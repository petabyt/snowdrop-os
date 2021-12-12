;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains routines for data compression and decompression.
;
; This library supports the following versions:
;     version 0: no compression (fallen back onto when a key cannot be found)
;     version 1: RLE with 4-byte keys
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_COMPRESS_
%define _COMMON_COMPRESS_


COMMON_COMPRESS_MAX_SUPPORTED_SIZE		equ 65300

; version 0: no compression
COMMON_COMPRESS_HEADER_SIZE_V0			equ 5
				; 1 byte for version identifier
				; 2 bytes for inflated size
				; 2 bytes for total deflated buffer size (includes header)
COMMON_COMPRESS_HEADER_IDENTIFIER_V0	equ 0


; version 1
COMMON_COMPRESS_HEADER_SIZE_V1			equ 9
				; 1 byte for version identifier
				; 2 bytes for inflated size
				; 2 bytes for total deflated buffer size (includes header)
				; 4 bytes for key
COMMON_COMPRESS_HEADER_IDENTIFIER_V1	equ 1

COMMON_COMPRESS_KEY_LENGTH_V1			equ 4			; in bytes
COMMON_COMPRESS_RUN_ENTRY_SIZE_V1		equ COMMON_COMPRESS_KEY_LENGTH_V1+2+1
				; +2 for the run length
				; +1 for the byte value repeated in the run

COMMON_COMPRESS_SMALLEST_REPLACEABLE_RUN_V1	equ COMMON_COMPRESS_RUN_ENTRY_SIZE_V1 + 1

COMMON_COMPRESS_KEY_ATTEMPTS			equ 1000

decompressKeyBuffer:		times COMMON_COMPRESS_KEY_LENGTH_V1 db 0
compressKeyBuffer:			times COMMON_COMPRESS_KEY_LENGTH_V1 db 0
compressDestinationBufferSegment:		dw 0
compressDestinationBufferOffset:		dw 0


; Returns information on the source buffer, assumed to be compressed.
; The main use of this function is to allow the consumer to allocate a large
; enough buffer prior to inflating a compressed buffer.
;
; input:
;	 DS:SI - pointer to source buffer
; output:
;		AL - 0 if recognized, other value otherwise
;		AH - identifier (version, etc.), when recognized
;		CX - inflated size, when recognized
;			 this is the required destination buffer size when inflating
;		DX - total size of deflated buffer, when recognized (including header)
common_compress_info:
	mov ah, byte [ds:si+0]		; AH := identifier
	cmp ah, COMMON_COMPRESS_HEADER_IDENTIFIER_V1
	je common_compress_info_v1
	cmp ah, COMMON_COMPRESS_HEADER_IDENTIFIER_V0
	je common_compress_info_v0
	
	mov al, 0					; "not recognized"
	jmp common_compress_info_done
	
common_compress_info_v1:
	mov ah, byte [ds:si+0]		; AH := identifier
	mov cx, word [ds:si+1]		; CX := inflated size
	mov dx, word [ds:si+3]		; DX := total deflated size (includes header)
	mov al, 1					; "recognized"
	jmp common_compress_info_done
	
common_compress_info_v0:
	mov ah, byte [ds:si+0]		; AH := identifier
	mov cx, word [ds:si+1]		; CX := inflated size
	mov dx, word [ds:si+3]		; DX := total deflated size (includes header)
	mov al, 1					; "recognized"
	jmp common_compress_info_done
	
common_compress_info_done:
	ret

	
; Decompresses a buffer
;
; input:
;	 DS:SI - pointer to compressed buffer
;	 ES:DI - pointer to destination (inflated) buffer
;            (use common_compress_info to determine required destination
;			 buffer size)
; output:
;		AX - 0 when format of compressed buffer is not supported, 
;			 other value otherwise
;		CX - destination (inflated) buffer size
common_compress_inflate:
	pushf
	push bx
	push dx
	push si
	push di
	push ds
	push es
	
	cld
	
	cmp byte [ds:si+0], COMMON_COMPRESS_HEADER_IDENTIFIER_V0
	je common_compress_inflate__v0
	cmp byte [ds:si+0], COMMON_COMPRESS_HEADER_IDENTIFIER_V1
	je common_compress_inflate__v1
	jmp common_compress_inflate_unsupported
common_compress_inflate__v0:
	mov cx, word [ds:si+1]					; CX := inflated size
	push cx									; [1]
	
	add si, COMMON_COMPRESS_HEADER_SIZE_V0	; DS:SI := ptr to bytes
	
	; since v0 is uncompressed, inflated size equals deflated size
	rep movsb								; v0 is uncompressed, so we just
											; copy verbatim
	pop cx									; [1]
	jmp common_compress_inflate_success
common_compress_inflate__v1:
	mov cx, word [ds:si+1]					; CX := inflated size
	push cx									; [2]
	
	mov dx, word [ds:si+3]					; DX := total deflated size
	sub dx, COMMON_COMPRESS_HEADER_SIZE_V1	; DX := deflated size of bytes
	
	mov ax, word [ds:si+5]
	mov word [cs:decompressKeyBuffer+0], ax
	mov ax, word [ds:si+7]
	mov word [cs:decompressKeyBuffer+2], ax	; store key
	
	add si, COMMON_COMPRESS_HEADER_SIZE_V1	; DS:SI := ptr to bytes
	
common_compress_inflate__v1__loop:
	; here, DX = bytes remaining in the source buffer
	; here, DS:SI = ptr to source buffer
	; here, ES:DI = ptr to destination buffer
	cmp dx, 0								; are we at the end of the buffer?
	je common_compress_inflate__v1_done		; yes
	
	cmp dx, COMMON_COMPRESS_RUN_ENTRY_SIZE_V1	; can a run entry still fit
	jb common_compress_inflate__v1__loop_non_run	; in what's left of the
												; source buffer?
	; yes, so check for a run entry
	
	; first, copy as many bytes as a key from source buffer into our 
	; compare buffer
	push ds
	push es
	push bx
	push cx
	push si
	push di
	
	; here, DX = bytes remaining in the source buffer
	; here, DS:SI = ptr to source buffer
	push cs
	pop es
	mov di, decompressKeyBuffer				; ES:DI := key
	
	mov bx, dx								; BX := source buffer size
											; (remaining)
	mov cx, COMMON_COMPRESS_KEY_LENGTH_V1	
	call common_bufutil_starts_with			; [*] AX = 0 when buffer does not
											; start with key
	pop di
	pop si
	pop cx
	pop bx
	pop es
	pop ds
	
	cmp ax, 0								; [*]
	je common_compress_inflate__v1__loop_non_run	; key mismatch, so no run
	; a run entry starts at DS:SI

	mov al, byte [ds:si+COMMON_COMPRESS_KEY_LENGTH_V1+2]	; AL := run value
	mov cx, word [ds:si+COMMON_COMPRESS_KEY_LENGTH_V1]	; CX := run length
	rep stosb											; write run
	
	add si, COMMON_COMPRESS_RUN_ENTRY_SIZE_V1	; skip over run entry in
												; source buffer
	sub dx, COMMON_COMPRESS_RUN_ENTRY_SIZE_V1	; remaining -= run entry size
	jmp common_compress_inflate__v1__loop
	
common_compress_inflate__v1__loop_non_run:
	; we're not at the beginning of a run, so we copy this byte verbatim
	mov al, byte [ds:si]
	mov byte [es:di], al
	inc si
	inc di
	dec dx									; remaining--
	jmp common_compress_inflate__v1__loop
	
common_compress_inflate__v1_done:	
	pop cx									; [2]
	jmp common_compress_inflate_success

common_compress_inflate_unsupported:
	mov ax, 0
	jmp common_compress_inflate_done
common_compress_inflate_success:
	mov ax, 1
common_compress_inflate_done:
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop bx
	popf
	ret
	

; Compresses a buffer
;
; input:
;	 DS:SI - pointer to source buffer
;	 ES:DI - pointer to destination buffer; must hold at least
;			 CX+128 bytes
;		CX - size of source buffer, in bytes
; output:
;		AX - 0 when input buffer is too large, other value otherwise
;		DX - size of destination buffer, in bytes
common_compress_deflate:
	pushf
	push bx
	push cx
	push si
	push di
	push ds
	push es
	
	mov word [cs:compressDestinationBufferSegment], es
	mov word [cs:compressDestinationBufferOffset], di
	
	cld
	
	cmp cx, COMMON_COMPRESS_MAX_SUPPORTED_SIZE
	ja common_compress_deflate_error
	
	call _compress_find_key
	cmp ax, 0
	jne common_compress_deflate__got_key	; we got a key, so 
											; we can proceed normally
common_compress_deflate__did_not_get_key:
	; version 0
	
	; when we couldn't find a key, we perform no compression, but still
	; output success
	
	; write header
	pusha
	mov byte [es:di+0], COMMON_COMPRESS_HEADER_IDENTIFIER_V0	; identifier
	
	mov word [es:di+1], cx					; inflated size
	
	mov word [es:di+3], cx					; total deflated buffer size
	add word [es:di+3], COMMON_COMPRESS_HEADER_SIZE_V0	; (includes header)
	popa
	
	mov dx, word [es:di+3]					; return total destinatio buffer
											; size in DX
	
	; write input verbatim
	add di, COMMON_COMPRESS_HEADER_SIZE_V0	; move past header
	rep movsb								; copy all source bytes verbatim
	jmp common_compress_no_key_v0
	
common_compress_deflate__got_key:
	; version 1
	
	; write header
	pusha
	mov byte [es:di+0], COMMON_COMPRESS_HEADER_IDENTIFIER_V1	; identifier
	
	mov word [es:di+1], cx					; inflated size
	mov word [es:di+3], 0					; total deflated buffer size
											; (includes header)
											; filled in at the end
	mov bx, word [cs:compressKeyBuffer+0]
	mov word [es:di+5], bx
	mov bx, word [cs:compressKeyBuffer+2]
	mov word [es:di+7], bx					; key
	popa
	add di, COMMON_COMPRESS_HEADER_SIZE_V1	; move past header
	
	; begin compression
	mov dx, si
	add dx, cx
	dec dx									; DS:DX := pointer to last byte
											; of source buffer
common_compress_deflate__loop:
	; here DS:DX = pointer to last byte of source buffer
	; here DS:SI = pointer to current location in source buffer
	call _compress_get_run_length			; AX := run length
											; (0 if overrun)
	cmp ax, 0								; we're past buffer end
	je common_compress_deflate_success_with_key_v1	; so we're done
	
	; a run was found
	cmp ax, COMMON_COMPRESS_SMALLEST_REPLACEABLE_RUN_V1	; is it worth it?
	jae common_compress_deflate__loop_write_run_entry		; yes
	
	; the run is too small, so we don't add a run entry
	; instead, we just copy all bytes in the run to destination buffer
	mov cx, ax								; CX := run length
	rep movsb								; copy run bytes verbatim
	jmp common_compress_deflate__loop			; next run
	
common_compress_deflate__loop_write_run_entry:
	; write run information to destination buffer
	mov bx, word [cs:compressKeyBuffer+0]
	mov word [es:di+0], bx
	mov bx, word [cs:compressKeyBuffer+2]
	mov word [es:di+2], bx					; write key
	
	mov word [es:di+4], ax					; write run length
	
	mov bl, byte [ds:si]
	mov byte [es:di+6], bl					; write run value
	
	add si, ax								; DS:SI := ptr to immediately 
											; after run
	add di, COMMON_COMPRESS_RUN_ENTRY_SIZE_V1	; ES:DI := ptr to after 
											; newly-written run entry
	jmp common_compress_deflate__loop		; next run

common_compress_no_key_v0:
	; version 0 epilogue
	
	; here DX = size of source buffer
	mov ax, 1								; "success"
	jmp common_compress_deflate_done

common_compress_deflate_success_with_key_v1:
	; version 1 epilogue
	
	; here, ES:DI = ptr to right after the end of the destination buffer
	mov dx, di
	sub dx, word [cs:compressDestinationBufferOffset]	; DX := destination buffer length
	
	mov di, word [cs:compressDestinationBufferOffset]	; ES:DI := start of destination buf
	mov word [es:di+3], dx					; total deflated buffer size
											; (includes header)
	
	mov ax, 1								; "success"
	jmp common_compress_deflate_done

common_compress_deflate_error:
	mov ax, 0								; "error"
	jmp common_compress_deflate_done
	
common_compress_deflate_done:
	pop es
	pop ds
	pop di
	pop si
	pop cx
	pop bx
	popf
	ret


; Returns the length of the run starting from the beginning of the specified
; buffer - that is, the number of contiguous bytes whose values are all equal
; to the value of the first byte in the buffer whose value is not equal.
;
; Example: A B C D D D E F 
;          |             |
;          SI            DX
; returns AX = 0
;
; Example: D D D E F 
;          |       |
;          SI      DX
; returns AX = 3
;
; input:
;	 DS:SI - pointer to source buffer
;	 DS:DX - pointer to last byte of the source buffer
; output:
;		AX - run length
_compress_get_run_length:
	push bx
	push cx
	push dx
	push si
	push di
	
	mov bx, 0							; run is 0 length initially
										; (in case SI > DX)

	mov al, byte [ds:si]				; AL := first byte of run
_compress_get_run_length__loop:
	cmp si, dx
	ja _compress_get_run_length_done	; we're past the end
	
	cmp al, byte [ds:si]
	jne _compress_get_run_length_done	; run is over
	
	; advance
	inc si
	inc bx								; update count

	jmp _compress_get_run_length__loop
_compress_get_run_length_done:
	; here BX = run length
	mov ax, bx							; return it in AX
	
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
	
; Computes a key string with the property that it is not a substring of the
; source buffer.
; WARNING: Overwrites existing destination buffer contents, for the purpose of
;          being able to do indexof on the source buffer
;
; input:
;	 DS:SI - pointer to source buffer
;		CX - size of source buffer, in bytes
; output:
;		AX - 0 when a key could not be computed, 1 otherwise
_compress_find_key:
	pushf
	push ds
	push es
	push bx
	push cx
	push dx
	push si
	push di

	cld
	
	push cs
	pop es
	mov di, compressKeyBuffer	; ES:DI := ptr to key being considered
	
	mov dx, COMMON_COMPRESS_KEY_ATTEMPTS
_compress_find_key__loop:
	; here, DS:SI = ptr to source buffer
	; here, CX = size of source buffer
	; here, ES:DI = ptr to key being considered
	
	; generate a key
	push ax
	int 86h				; AX := random
	mov word [cs:compressKeyBuffer+0], ax
	int 86h				; AX := random
	mov word [cs:compressKeyBuffer+2], ax
	pop ax
	
	; verify key
	push cx								; [1]
	
	mov bx, cx							; BX := source buffer length
	mov cx, COMMON_COMPRESS_KEY_LENGTH_V1	; CX := key length
	call common_bufutil_first_indexof	; AX := 0 when not found
										; BX := index when found
	pop cx								; [1]
	cmp ax, 0
	je _compress_find_key_success		; key not found, so success
	
	; key was found, which means it is invalid, so move to next key
	inc dword [cs:compressKeyBuffer+0]

	dec dx								; attempts--
	jnz _compress_find_key__loop
	
_compress_find_key_error:
	mov ax, 0
	jmp _compress_find_key_done
_compress_find_key_success:
	mov ax, 1
_compress_find_key_done:
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop es
	pop ds
	popf
	ret


%include "common\buf_util.asm"

%endif
