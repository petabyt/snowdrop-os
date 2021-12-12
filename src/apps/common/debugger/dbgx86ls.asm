;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains routines which deal with a program listing, needed 
; for Snowdrop OS's debugger.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DBGX86_LISTING_
%define _COMMON_DBGX86_LISTING_


dbgx86ListingNextAddressHexBuffer:		times 5 db 0
dbgx86ListingAddressCheckBuffer:		times 5 db 0


; Returns the offset of the origin of the watched program
;
; input:
;		none
; output:
;		AX - 0 when origin not found, other value otherwise
;		BX - origin offset value
dbgx86Listing_get_origin:
	push ds
	push si
	
	mov ds, word [cs:dbgx86ListingSeg]
	mov si, word [cs:dbgx86ListingOff]	; DS:SI := pointer to listing
	call dbgx86Listing_get_next_address
	
	pop si
	pop ds
	ret


; Returns the numeric value of the next address from the listing,
; starting from the specified string
;
; input:
;		AX - address to look up in the listing
; output:
;		AX - 0 when address was not found, other value otherwise
;	 DS:SI - pointer to first hex digit of address in the listing
dbgx86Listing_get_pointer_to_address:
	push bx
	push cx
	
	mov cx, ax							; CX := address to lookup
	
	mov ds, word [cs:dbgx86ListingSeg]
	mov si, word [cs:dbgx86ListingOff]	; DS:SI := pointer to listing
dbgx86Listing_get_pointer_to_address_loop:
	call dbgx86Listing_get_next_address	; BX := next address value
										; DS:SI = pointer to address
	cmp ax, 0
	je dbgx86Listing_get_pointer_to_address_not_found
	
	cmp bx, cx							; is this the one we're looking for?
	jne dbgx86Listing_get_pointer_to_address_loop	; no
	
	; here, DS:SI points to first hex digit of the address we were looking for
	mov ax, 1							; success
	jmp dbgx86Listing_get_pointer_to_address_done
dbgx86Listing_get_pointer_to_address_not_found:
	mov ax, 0							; failure
dbgx86Listing_get_pointer_to_address_done:
	pop cx
	pop bx
	ret
	

; Returns the numeric value of the next address from the listing,
; starting from the specified string
;
; input:
;	 DS:SI - pointer to listing
; output:
;		AX - 0 when there were no further address entries,
;			 other value otherwise
;		BX - next address value
;	 DS:SI - pointer to first hex digit of address when found,
;			 undefined when not found
dbgx86Listing_get_next_address:
	push cx
	
dbgx86Listing_get_next_address_loop:
	cmp byte [ds:si], 0
	je dbgx86Listing_get_next_address_not_found
	
	call dbgx86Listing_starts_with_newline_address
	cmp ax, 0

	jne dbgx86Listing_get_next_address_atoi
	
	inc si
	jmp dbgx86Listing_get_next_address_loop
	
dbgx86Listing_get_next_address_atoi:
	add si, 2							; skip over newline
	; here, DS:SI points to first hex digit of address
	mov al, byte [ds:si+0]
	mov byte [cs:dbgx86ListingNextAddressHexBuffer+0], al
	mov al, byte [ds:si+1]
	mov byte [cs:dbgx86ListingNextAddressHexBuffer+1], al
	mov al, byte [ds:si+2]
	mov byte [cs:dbgx86ListingNextAddressHexBuffer+2], al
	mov al, byte [ds:si+3]
	mov byte [cs:dbgx86ListingNextAddressHexBuffer+3], al
	
	push ds
	push si								; [1] save output pointer
	
	push cs
	pop ds
	mov si, dbgx86ListingNextAddressHexBuffer
	
	call dbgx86Util_hex_atoi			; AX := atoi
	mov bx, ax							; return it in BX
	mov ax, 1							; success
	
	pop si
	pop ds								; [1] restore output pointer
	
	jmp dbgx86Listing_get_next_address_done

dbgx86Listing_get_next_address_not_found:
	mov ax, 0
	
dbgx86Listing_get_next_address_done:
	pop cx
	ret

	
; Moves input pointer to the beginning of next line, if one exists
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string doesn't have another line, other value otherwise
;	 DS:SI - pointer to beginning of next line, if one exists
dbgx86Listing_move_to_next_line:

dbgx86Listing_move_to_next_line_loop:	
	cmp byte [ds:si], 0						; are we at the end?
	je dbgx86Listing_move_to_next_line_fail	; yes
	cmp byte [ds:si+1], 0					; only one more char?
	je dbgx86Listing_move_to_next_line_fail	; yes
	cmp byte [ds:si], 13					; this char is 13?
	jne dbgx86Listing_move_to_next_line_loop_next	; no
	cmp byte [ds:si+2], 0					; only two more chars?
	je dbgx86Listing_move_to_next_line_fail	; yes
	cmp byte [ds:si+1], 10					; next char is 10?
	je dbgx86Listing_move_to_next_line_success	; yes
	; flow into next
dbgx86Listing_move_to_next_line_loop_next:
	inc si
	jmp dbgx86Listing_move_to_next_line_loop
	
dbgx86Listing_move_to_next_line_fail:
	mov ax, 0
	ret
dbgx86Listing_move_to_next_line_success:
	; when we get here, DS:SI points to the 13 character
	add si, 2						; DS:SI := pointer to right after 13, 10
	mov ax, 1
	ret
	
; Checks whether the specified string starts with a newline 
; and then an address
;
; input:
;	 DS:SI - pointer to string, zero-terminated
; output:
;		AX - 0 when string doesn't start with address, other value otherwise
dbgx86Listing_starts_with_newline_address:
	pusha
	push ds
	
	int 0A5h							; BX := string length
	cmp bx, 6							; 13, 10, "3B9F"
	jb dbgx86Listing_starts_with_newline_address_no	; too short
	
	cmp byte [ds:si+0], 13
	jne dbgx86Listing_starts_with_newline_address_no
	cmp byte [ds:si+1], 10
	jne dbgx86Listing_starts_with_newline_address_no

	; copy into zero-terminated buffer
	mov al, byte [ds:si+2]
	mov byte [cs:dbgx86ListingAddressCheckBuffer+0], al
	mov al, byte [ds:si+3]
	mov byte [cs:dbgx86ListingAddressCheckBuffer+1], al
	mov al, byte [ds:si+4]
	mov byte [cs:dbgx86ListingAddressCheckBuffer+2], al
	mov al, byte [ds:si+5]
	mov byte [cs:dbgx86ListingAddressCheckBuffer+3], al
	push cs
	pop ds
	mov si, dbgx86ListingAddressCheckBuffer

	call dbgx86Util_is_hex_number_string
	cmp ax, 0
	je dbgx86Listing_starts_with_newline_address_no

dbgx86Listing_starts_with_newline_address_yes:
	pop ds
	popa
	mov ax, 1
	ret
dbgx86Listing_starts_with_newline_address_no:
	pop ds
	popa
	mov ax, 0
	ret
	

%endif
