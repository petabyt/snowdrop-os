;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains utilities for dealing with memory buffers.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BUFFER_UTILITIES_
%define _COMMON_BUFFER_UTILITIES_
	

; Finds first occurrence of the needle buffer into haystack buffer
;
; input
;	 DS:SI - pointer to haystack (buffer in which we search)
;		BX - haystack length
;	 ES:DI - pointer to needle (buffer we are looking for)
;		CX - needle length
; output
;		AX - 0 when needle was not found or needle is empty
;			 other value otherwise	
;		BX - index at which the needle was found, when found
common_bufutil_first_indexof:
	push cx
	push dx
	push si
	push di

	cmp cx, 0
	je common_bufutil_first_indexof_no		; needle is empty
	
	mov dx, si								; DX := start of haystack
	
common_bufutil_first_indexof__loop:
	; here, BX = remaining haystack length
	; here, CX = needle length
	cmp cx, bx
	ja common_bufutil_first_indexof_no		; needle is longer than what's
											; left of the haystack

	call common_bufutil_starts_with			; AX := 0 when doesn't start with
	cmp ax, 0
	jne common_bufutil_first_indexof_yes	; it starts with it

	; doesn't start with it, and we still have more to go
	inc si									; next haystack byte
	dec bx									; one fewer bytes in haystack
	jmp common_bufutil_first_indexof__loop
	
common_bufutil_first_indexof_yes:
	; here SI points to a character in the haystack
	; here DX points to start of haystack
	sub si, dx								; SI := index
	
	mov bx, si								; BX := index
	mov ax, 1
	jmp common_bufutil_first_indexof_done
common_bufutil_first_indexof_no:
	mov ax, 0
common_bufutil_first_indexof_done:
	pop di
	pop si
	pop dx
	pop cx
	ret
	

; Checks whether one buffer begins with another buffer 
;
; input
;	 DS:SI - pointer to haystack (buffer in which we search)
;		BX - haystack length
;	 ES:DI - pointer to needle (buffer we are looking for)
;		CX - needle length
; output
;		AX - 0 when haystack does not begin with needle or needle is empty
;			 other value otherwise
common_bufutil_starts_with:
	push bx
	push cx
	push dx
	push si
	push di
	pushf
	
	cmp cx, bx
	ja common_bufutil_starts_with__no	; needle is longer
	
	; compare as many bytes as needle is long
	cld
	repe cmpsb							; compare string of bytes
	jne common_bufutil_starts_with__no
	
common_bufutil_starts_with__yes:
	mov ax, 1
	jmp common_bufutil_starts_with_done
common_bufutil_starts_with__no:
	mov ax, 0
common_bufutil_starts_with_done:
	popf
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret


%endif
