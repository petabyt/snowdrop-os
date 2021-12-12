;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains routines for various geometrical operations.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GEOMETRY_
%define _COMMON_GEOMETRY_


; Tests whether the two specified rectangles overlap.
; The rectangles are defined via their corner coordinates.
;
; input:
;		AX - first rectangle left
;		BX - first rectangle right
;		CX - first rectangle top
;		DX - first rectangle bottom
;		SI - second rectangle left
;		DI - second rectangle right
;		FS - second rectangle top
;		GS - second rectangle bottom
; output:
;		AL - 0 when there is no overlap, or a different value otherwise
common_geometry_test_rectangle_overlap_by_coords:
	pusha
	
	cmp ax, di					; first.left > second.right
	ja common_geometry_test_rectangle_overlap_no
	cmp bx, si					; first.right < second.left
	jb common_geometry_test_rectangle_overlap_no
	
	push gs
	pop ax
	cmp cx, ax					; first.top > second.bottom
	ja common_geometry_test_rectangle_overlap_no
	push fs
	pop ax
	cmp dx, ax					; first.bottom < second.top
	jb common_geometry_test_rectangle_overlap_no

common_geometry_test_rectangle_overlap_yes:
	popa
	mov al, 1
	ret
common_geometry_test_rectangle_overlap_no:
	popa
	mov al, 0
	ret

	
; Tests whether the two specified rectangles overlap.
; The rectangles are defined via the coordinates of one corner and 
; the size of each rectangle.
;
; input:
;		AX - first rectangle left
;		BX - first rectangle width
;		CX - first rectangle top
;		DX - first rectangle height
;		SI - second rectangle left
;		DI - second rectangle width
;		FS - second rectangle top
;		GS - second rectangle height
; output:
;		AL - 0 when there is no overlap, or a different value otherwise
common_geometry_test_rectangle_overlap_by_size:
	push bx
	push dx
	push di
	push gs
	
	; set up parameters to call the "by coordinates" call
	
	push ax					; [1]
	push bx					; [2]
	mov ax, fs
	mov bx, gs
	add ax, bx
	dec ax
	mov gs, ax				; GS := second rectangle bottom
	pop bx					; [2]
	pop ax					; [1]
	
	add bx, ax
	dec bx					; BX := first rectangle right
	
	add dx, cx
	dec dx					; DX := first rectangle bottom
	
	add di, si
	dec di					; DI := second rectangle right
	
	call common_geometry_test_rectangle_overlap_by_coords
	
	pop gs
	pop di
	pop dx
	pop bx
	ret
	

%endif
