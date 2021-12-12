;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains GUI framework constants defaults, which may be overridden 
; by consumers.
;
; Generally, consumers would override some of the settings contained here 
; when either:
;     1. they need to work with more buttons, images, etc. than defined here
;     2. they wish to save memory by reducing the number of components needed
;     3. they want to modify other settings, such as the colour scheme
;
; IMPORTANT: For simplicity, this file should only be 
;            included from gui_core.asm
; IMPORTANT: Attempting to use more components than defined by these (or
;            overridden) limits will result in undefined behaviour
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; override these to have fewer or more available components
%ifndef _COMMON_GUI_CONF_COMPONENT_LIMITS_
%define _COMMON_GUI_CONF_COMPONENT_LIMITS_
GUI_RADIO_LIMIT 		equ 12	; maximum number of radio available
GUI_IMAGES_LIMIT 		equ 12	; maximum number of images available
GUI_CHECKBOXES_LIMIT 	equ 12	; maximum number of checkboxes available
GUI_BUTTONS_LIMIT 		equ 12	; maximum number of buttons available
%endif


; override these to change the colour scheme of the GUI framework
%ifndef _COMMON_GUI_CONF_COLOURS_
%define _COMMON_GUI_CONF_COLOURS_
; colour palette used by all GUI components
GUI__COLOUR_0	equ COMMON_GRAPHICS_COLOUR_BLACK		; foreground main colour
GUI__COLOUR_1	equ COMMON_GRAPHICS_COLOUR_WHITE		; background colour
GUI__COLOUR_2	equ COMMON_GRAPHICS_COLOUR_DARK_GRAY	; foreground decorations colour
GUI__COLOUR_3	equ COMMON_GRAPHICS_COLOUR_LIGHT_GRAY	; foreground "disabled" colour
%endif


; override these to have access to larger or more numerous sprites
%ifndef _COMMON_SPRITES_LIMITS_
%define _COMMON_SPRITES_LIMITS_
COMMON_SPRITES_SPRITE_MAX_SIZE equ 8	; override sprite library defaults
COMMON_SPRITES_MAX_SPRITES equ 4		; to values more suitable for me
%endif
