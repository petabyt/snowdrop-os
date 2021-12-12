;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains definitions for commonly-used ASCII codes
; 
; NOTE: Since extended scan codes are not supported, certain keys will 
;       generate the same scan code. Examples include left and right control
;       keys, left and right alt keys.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASCII_
%define _COMMON_ASCII_

COMMON_ASCII_NULL 				equ 0
COMMON_ASCII_BELL 				equ 7
COMMON_ASCII_BACKSPACE 			equ 8
COMMON_ASCII_TAB 				equ 9
COMMON_ASCII_LINE_FEED 			equ 10
COMMON_ASCII_CARRIAGE_RETURN 	equ 13
COMMON_ASCII_BLANK				equ 32
COMMON_ASCII_DOUBLEQUOTE		equ 34
COMMON_ASCII_BLOCK				equ 0DBh
COMMON_ASCII_DARKEST			equ 178
COMMON_ASCII_LIGHTEST			equ 176


; Checks whether the specified ASCII code would yield a character on screen
; when printed
;
; input:
;		AL - ASCII
; output:
;	 CARRY - set when printable, clear otherwise
common_ascii_is_printable:
	cmp al, 32
	jb common_ascii_is_printable_no
	cmp al, 126
	ja common_ascii_is_printable_no
	
	stc
	ret
common_ascii_is_printable_no:
	clc
	ret

%endif
