;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains colour definitions for text output.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_COLOURS_
%define _COMMON_COLOURS_

COMMON_FONT_COLOUR_BLACK 	equ 000b
COMMON_FONT_COLOUR_BLUE 	equ 001b
COMMON_FONT_COLOUR_GREEN 	equ 010b
COMMON_FONT_COLOUR_CYAN 	equ 011b
COMMON_FONT_COLOUR_RED		equ 100b
COMMON_FONT_COLOUR_MAGENTA	equ 101b
COMMON_FONT_COLOUR_BROWN 	equ 110b
COMMON_FONT_COLOUR_WHITE 	equ 111b

COMMON_FONT_BRIGHT			equ 00001000b
COMMON_FONT_BLINKING		equ 10000000b

COMMON_BACKGROUND_COLOUR_BLACK		equ 0000000b
COMMON_BACKGROUND_COLOUR_BLUE 		equ 0010000b
COMMON_BACKGROUND_COLOUR_GREEN		equ 0100000b
COMMON_BACKGROUND_COLOUR_CYAN 		equ 0110000b
COMMON_BACKGROUND_COLOUR_RED 		equ 1000000b
COMMON_BACKGROUND_COLOUR_MAGENTA 	equ 1010000b
COMMON_BACKGROUND_COLOUR_BROWN		equ 1100000b
COMMON_BACKGROUND_COLOUR_WHITE		equ 1110000b

%endif
