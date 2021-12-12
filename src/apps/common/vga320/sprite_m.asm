;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It configures the sprites library to allow medium-sized sprites.
; 
; NOTE: This file is meant to be included BEFORE sprites.asm, to configure 
;       the limits of the sprite library
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_SPRITES_LIMITS_
%define _COMMON_SPRITES_LIMITS_

COMMON_SPRITES_SPRITE_MAX_SIZE equ 32			; side length, in pixels
COMMON_SPRITES_MAX_SPRITES equ 16

%endif
