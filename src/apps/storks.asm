;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The STORKS app.
; This is a game which demonstrates Snowdrop OS's game development-oriented 
; libraries.
;
; In Storks, the player must deliver the correct baby bundles to various 
; forest inhabitants, who reside in tree hollows.
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

	bits 16						; the CPU is assumed to function in 16-bit mode
	org 0						; apps are loaded at offset 0 by the caller

	jmp start


; sprite definitions for all sprites used in the game
; higher-numbered sprites are rendered "on top" of lower-numbered sprites
OBJECT_BOY_BUNDLE_SPRITE equ 0
OBJECT_GIRL_BUNDLE_SPRITE equ 1
WISH_FIRST_SPRITE equ 2
WISH_NUM_SPRITES equ 6
WISH_LAST_SPRITE equ WISH_FIRST_SPRITE + WISH_NUM_SPRITES - 1
HELD_BUNDLE_SPRITE equ WISH_LAST_SPRITE + 1
STORK_SPRITE equ HELD_BUNDLE_SPRITE + 1
; these are not using during the game; only to decoreate the menu screen
MENU_STORK_SPRITE1 equ STORK_SPRITE + 1				; used during menu
MENU_STORK_SPRITE2 equ MENU_STORK_SPRITE1 + 1		; used during menu


FADE_DELAY equ 0	; amount of delay during screen transitions
FORCE_SPAWN_AFTER_FRAME_COUNT equ 300
VIDEO_FRAME_DELAY equ 2	; amount of delay between video frames
ACTION_BUTTON_SCAN_CODE equ COMMON_SCAN_CODE_Z	; used for pick-up/drop off
WISH_GENERATION_CHANCE equ 200	; out of 65535, attempted every video frame

TIME_AVAILABLE equ 50			; how much time the player gets
MAX_SCORE equ 50				; score required to win
POINTS_PER_BUNDLE equ 2			; score increment for a successful delivery

INDICATOR_HEIGHT equ 4
INDICATOR_X equ 66
INDICATOR_Y equ 2
INDICATOR_VERTICAL_GAP equ 8
INDICATOR_LABEL_COLOUR equ 15

SOUND_PHASE_TRANSITION equ 0		; menu->game, game->menu (on key press)
SOUND_BUNDLE_PICK_UP equ 1			; stork just picked up a bundle
SOUND_BUNDLE_DROPOFF equ 2			; stork just dropped off a bundle
SOUND_VICTORY equ 3					; game ended in victory
SOUND_LOSS equ 4					; game ended in loss
SOUND_WRONG_BUNDLE_TYPE equ 5		; stork attempted to drop off wrong type

STORK_ANIMATION_FRAMES equ 4
STORK_ANIMATION_FRAME_DELAY equ 5
STORK_SPRITE_WIDTH equ 32
STORK_SPRITE_HEIGHT equ 32
STORK_SPEED equ 2				; in pixels per frame

OBJECT_BUNDLE_EDGE_OFFSET equ 10	; how far away from edge bundle objects are

OBJECT_BUNDLE_SPRITE_HEIGHT equ 16
OBJECT_BUNDLE_SPRITE_WIDTH equ 16

OBJECT_BOY_BUNDLE_SPRITE_X equ OBJECT_BUNDLE_EDGE_OFFSET
OBJECT_BOY_BUNDLE_SPRITE_Y equ COMMON_GRAPHICS_SCREEN_HEIGHT/2 - OBJECT_BUNDLE_SPRITE_HEIGHT/2

OBJECT_GIRL_BUNDLE_SPRITE_X equ COMMON_GRAPHICS_SCREEN_WIDTH - OBJECT_BUNDLE_SPRITE_WIDTH - OBJECT_BUNDLE_EDGE_OFFSET
OBJECT_GIRL_BUNDLE_SPRITE_Y equ COMMON_GRAPHICS_SCREEN_HEIGHT/2 - OBJECT_BUNDLE_SPRITE_HEIGHT/2

WISH_TYPE_NONE equ 0
WISH_TYPE_BOY equ 1
WISH_TYPE_GIRL equ 2

WISH_BITMAP_WIDTH equ 16
WISH_ANIMATION_FRAMES equ 5
WISH_ANIMATION_FRAMES_DELAY equ 20
wishSpriteXs: dw 113, 102, 98, 238, 231, 225
wishSpriteYs: dw 35, 77, 115, 10, 73, 125
wishTypes: times WISH_NUM_SPRITES dw WISH_TYPE_NONE
wishTypesEnd:		; mark end of array

; the background image is large enough to be loaded in its own segment
; all other images are loaded in buffers defined at the end of this file
backgroundFat12Filename:		db 'STORKS_BBMP', 0
storkFat12Filename:				db 'STORKS_SBMP', 0
boyBundleFat12Filename:			db 'STORKS_MBMP', 0
girlBundleFat12Filename:		db 'STORKS_FBMP', 0
boyWishFat12Filename:			db 'STORKS_NBMP', 0
girlWishFat12Filename:			db 'STORKS_GBMP', 0

; these sizes must be at least 512 bytes more than the actual file sizes, since
; we cannot load fractions of a sector
FILE_SIZE_STORK			equ 6000
FILE_SIZE_BOY_BUNDLE	equ 2000
FILE_SIZE_GIRL_BUNDLE	equ 2000
FILE_SIZE_BOY_WISH		equ 3000
FILE_SIZE_GIRL_WISH		equ 3000
FILE_SIZE_TOTAL			equ FILE_SIZE_STORK + FILE_SIZE_BOY_BUNDLE + FILE_SIZE_GIRL_BUNDLE + FILE_SIZE_BOY_WISH + FILE_SIZE_GIRL_WISH

storkFileContentsSeg:		dw 0
storkFileContentsOff:		dw 0
boyBundleFileContentsSeg:	dw 0
boyBundleFileContentsOff:	dw 0
girlBundleFileContentsSeg:	dw 0
girlBundleFileContentsOff:	dw 0
boyWishFileContentsSeg:		dw 0
boyWishFileContentsOff:		dw 0
girlWishFileContentsSeg:	dw 0
girlWishFileContentsOff:	dw 0

loadingMessage:	db 'LOADING...', 0
progressLabel: db 'PROGRESS', 0
timeLabel: db 'TIME', 0

victoryText: db 'WELL DONE! PRESS SPACE TO CONTINUE', 0
defeatText: db 'YOU LOST! PRESS SPACE TO CONTINUE', 0

menuTitle: db 'WELCOME TO STORKS!', 0
menuMessage:	db '  KEYS:', 13, 10
				db '        ARROWS - MOVE STORK', 13, 10
				db '             Z - PICK UP/DROP OFF', 13, 10
				db 13, 10
				db 13, 10
				db '        SPACE  - START GAME', 13, 10
				db '        ESCAPE - EXIT GAME', 13, 10
				db 13, 10
				db 13, 10
				db 13, 10
				db 13, 10
				db '   (WRITTEN BY SEBASTIAN MIHAI, 2017)'
				db 0


framesSinceLastWishSpawn: dw 0		; used to force a spawn
actionKeyWasPressedLastFrame:	db 0
actionKeyIsPressedThisFrame:	db 0
mustExit:				db 0
allocatedSegment: 		dw 0	; we'll load the background bitmap here
videoFrameCounter: dw 0
heldBundleType: dw WISH_TYPE_NONE

oldTimeRemaining: dw 0
timeRemaining: dw 0FFh
oldScore: dw 0FFh
score: dw 0

start:
	; -------------------------------------------------------------------------
	; initialization
	; -------------------------------------------------------------------------
	push cs
	pop ds
	mov si, dynamicMemoryArea
	mov ax, FILE_SIZE_TOTAL
	call common_memory_initialize
	cmp ax, 0
	je exit_shutdown_task
	
	call common_task_allocate_memory_or_exit	; BX := allocated segment
	mov word [cs:allocatedSegment], bx			; store allocated memory
	
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	int 83h						; clear keyboard buffer
	call common_keyboard_set_driver_mode_ignore_previous_handler
	call common_graphics_enter_graphics_mode
	call common_sprites_initialize
	mov ax, COMMON_SPRITES_CONFIG_VSYNC_ON_REFRESH | COMMON_SPRITES_CONFIG_ANIMATE_ON_REFRESH
	call common_sprites_set_config	; configure sprites library
	; done system-level initialization

	call load_bitmaps
	; done game-level initialization

	; -------------------------------------------------------------------------
	; main program loop
	; -------------------------------------------------------------------------
program_main_loop:
	call menu_phase				; show the menu and wait for user input
	cmp byte [cs:mustExit], 1	; are we set to exit?
	je exit_program				; yes
	
	call game_phase				; show the actual game
	jmp program_main_loop		; run menu phase again
	
	; -------------------------------------------------------------------------
	; clean-up and exit
	; -------------------------------------------------------------------------
exit_program:
	; exit program
	call common_graphics_leave_graphics_mode
	mov bx, word [cs:allocatedSegment]
	int 92h						; deallocate memory

	call common_keyboard_restore_driver_mode
exit_shutdown_task:
	int 95h						; exit

	
;------------------------------------------------------------------------------
; Game phases (highest level functions)
;------------------------------------------------------------------------------

; Runs the menu phase, waiting for the player to start the game
;
; input:
;		none
; output:
;		none
menu_phase:
	pusha
	
	call initialize_palette
	call common_sprites_destroy_all
	
	mov bl, 118
	call common_graphics_clear_screen_to_colour		; clear screen
	
	call initialize_menu_text
	call initialize_menu_storks
	
	; in case SPACE is already pressed, wait for it to be released
menu_phase_wait_release:
	mov bl, COMMON_SCAN_CODE_SPACE_BAR
	int 0BAh
	cmp al, 0						; is it pressed?
	jne menu_phase_wait_release		; yes
	
menu_phase_wait_key:
	mov cx, VIDEO_FRAME_DELAY
	int 85h							; delay
	
	mov bl, COMMON_SCAN_CODE_ESCAPE
	int 0BAh
	cmp al, 0						; is ESCAPE pressed?
	jne menu_phase_exit_game		; yes
	
	mov bl, COMMON_SCAN_CODE_SPACE_BAR
	int 0BAh
	cmp al, 0						; is SPACE pressed?
	jne menu_phase_done				; yes
	
	call common_sprites_refresh		; let sprites library refresh
	
	jmp menu_phase_wait_key			; keep waiting for key
	
menu_phase_exit_game:
	mov byte [cs:mustExit], 1
	jmp menu_phase_exit
	
menu_phase_done:
	mov ax, SOUND_PHASE_TRANSITION
	call play_sound
	
menu_phase_exit:
	mov cx, FADE_DELAY
	call common_graphics_fx_fade	; fade screen to black

	popa
	ret

	
; Runs the game phase (main game)
;
; input:
;		none
; output:
;		none
game_phase:
	pusha
	
	mov byte [cs:mustExit], 0
	mov byte [cs:actionKeyWasPressedLastFrame], 0
	mov byte [cs:actionKeyIsPressedThisFrame], 0
	mov word [cs:videoFrameCounter], 0
	mov word [cs:framesSinceLastWishSpawn], 0
	mov word [cs:heldBundleType], WISH_TYPE_NONE	; hold nothing
	
	mov word [cs:timeRemaining], TIME_AVAILABLE
	mov word [cs:oldTimeRemaining], 0	; guarantee an initial rendering of 
	mov word [cs:score], 0				; the time and progress indicators
	mov word [cs:oldScore], 0FFh		; by setting "old" and "new" variables
	
	call initialize_palette
	call common_sprites_destroy_all
	
	mov bl, 0										; black
	call common_graphics_clear_screen_to_colour		; clear screen

	call draw_background
	call initialize_indicator_labels
	
	call initialize_stork
	call initialize_objects
	call initialize_wishes
	
game_phase_main_loop:
	mov cx, VIDEO_FRAME_DELAY
	int 85h							; delay

	inc word [cs:videoFrameCounter]
	
	cmp word [cs:score], MAX_SCORE
	jae game_phase_victory			; victory!
	
	cmp word [cs:timeRemaining], 0
	je game_phase_defeat			; defeat!

	call update_time
	call refresh_indicators			; this may make changes to the background
	; no further background changes should be made past this point in the frame
	
	call is_wish_available			; AX := 0 when no wishes are available
	cmp ax, 0
	je game_phase_after_wish_generation
	call generate_wish
game_phase_after_wish_generation:
	call user_input_check
	
	call move_stork_check
	call pick_up_bundle_check
	call drop_off_bundle_check
	
	call animate_held_bundle
	
	call common_sprites_refresh		; let sprites library refresh

	mov bl, COMMON_SCAN_CODE_ESCAPE
	int 0BAh
	cmp al, 0						; is ESCAPE pressed?
	jne game_phase_done 			; yes
	
	jmp game_phase_main_loop		; run main loop again
	
game_phase_victory:
	mov ax, SOUND_VICTORY
	call play_sound
	
	call refresh_indicators			; refresh indicators one last time
	call victory_phase
	jmp game_phase_done
	
game_phase_defeat:
	mov ax, SOUND_LOSS
	call play_sound
	
	call refresh_indicators			; refresh indicators one last time
	call defeat_phase
	jmp game_phase_done
	
game_phase_done:
	mov cx, FADE_DELAY
	call common_graphics_fx_fade	; fade screen to black
	popa
	ret

	
; Runs the victory phase - that is, right after the player wins the game
;
; input:
;		none
; output:
;		none
victory_phase:
	pusha

	mov cl, 90				; initial colour
victory_phase_wait_for_key:
	push cx
	mov cx, 10
	int 85h					; delay
	pop cx
	
	mov dx, COMMON_TEXT_PRINT_FLAG_CENTRE
	mov si, victoryText
	mov ax, 170				; Y
	call common_graphics_text_print_at
	xor cx, 0FFh			; alternate between two colours
	
	mov bl, COMMON_SCAN_CODE_SPACE_BAR
	int 0BAh
	cmp al, 0						; is it pressed?
	je victory_phase_wait_for_key	; no
	
	mov ax, SOUND_PHASE_TRANSITION
	call play_sound
	
	mov cx, FADE_DELAY
	call common_graphics_fx_fade	; fade screen to black
	popa
	ret
	
	
; Runs the defeat phase - that is, right after the player loses the game
;
; input:
;		none
; output:
;		none
defeat_phase:
	pusha

	mov cl, 91				; initial colour
defeat_phase_wait_for_key:
	push cx
	mov cx, 10
	int 85h					; delay
	pop cx
	
	mov dx, COMMON_TEXT_PRINT_FLAG_CENTRE
	mov si, defeatText
	mov ax, 170				; Y
	call common_graphics_text_print_at
	xor cx, 0FFh			; alternate between two colours
	
	mov bl, COMMON_SCAN_CODE_SPACE_BAR
	int 0BAh
	cmp al, 0						; is it pressed?
	je defeat_phase_wait_for_key	; no
	
	mov ax, SOUND_PHASE_TRANSITION
	call play_sound
	
	mov cx, FADE_DELAY
	call common_graphics_fx_fade	; fade screen to black
	popa
	ret
	
	
;------------------------------------------------------------------------------
; Game logic procedures
;------------------------------------------------------------------------------

; Updates key press states
;
; input:
;		none
; output:
;		none
user_input_check:
	pusha
	
	mov al, byte [cs:actionKeyIsPressedThisFrame]
	mov byte [cs:actionKeyWasPressedLastFrame], al
	
	mov bl, ACTION_BUTTON_SCAN_CODE
	int 0BAh
	mov byte [cs:actionKeyIsPressedThisFrame], al
	
	popa
	ret
	
	
; Returns whether the action key has just been pressed (as in, it was not 
; pressed last frame, but it is pressed this frame)
;
; input:
;		none
; output:
;		AX - 0 when action was not just pressed, other value otherwise
is_action_key_just_pressed:
	mov al, byte [cs:actionKeyIsPressedThisFrame]
	xor al, byte [cs:actionKeyWasPressedLastFrame]
	and al, byte [cs:actionKeyIsPressedThisFrame]
	; here, AL is non-zero when key was not pressed last frame and
	; is pressed this frame
	ret
	
	
; Checks whether the stork is dropping off a bundle, and performs 
; the action if so
;
; input:
;		none
; output:
;		none
drop_off_bundle_check:
	pusha
	
	; check user input
	call is_action_key_just_pressed
	cmp al, 0
	je drop_off_bundle_check_done			; NOOP when button not pressed
	; is stork holding anything right now?
	cmp word [cs:heldBundleType], WISH_TYPE_NONE
	je drop_off_bundle_check_done			; NOOP when holding nothing
	; drop off bundle
	call drop_off_bundle
drop_off_bundle_check_done:
	popa
	ret
	

; Checks whether the stork is picking up a bundle, and performs 
; the action if so
;
; input:
;		none
; output:
;		none	
pick_up_bundle_check:
	pusha
	
	; check user input
	call is_action_key_just_pressed
	cmp al, 0
	je pick_up_bundle_check_done			; NOOP when button not pressed
	; collision with boy bundle?
pick_up_bundle_check_boy:
	cmp word [cs:heldBundleType], WISH_TYPE_BOY	; are we holding a boy bundle?
	je pick_up_bundle_check_girl				; yes, so we can't pick it up
	mov bh, OBJECT_BOY_BUNDLE_SPRITE
	mov bl, STORK_SPRITE
	call common_sprites_check_collision
	cmp al, 0								; are we colliding with boy bundle?
	je pick_up_bundle_check_girl			; no, so check the girl bundle
	; we're picking up the boy bundle
	call pick_up_boy_bundle
	jmp pick_up_bundle_check_done
pick_up_bundle_check_girl:
	cmp word [cs:heldBundleType], WISH_TYPE_GIRL
									; are we holding a girl bundle?
	je pick_up_bundle_check_done			; yes, so we can't pick it up
	mov bh, OBJECT_GIRL_BUNDLE_SPRITE
	mov bl, STORK_SPRITE
	call common_sprites_check_collision
	cmp al, 0								; are we colliding with boy bundle?
	je pick_up_bundle_check_done			; no, so we're done
	; we're picking up the boy bundle
	call pick_up_girl_bundle
pick_up_bundle_check_done:
	popa
	ret
	

; Makes the stork hold the boy bundle
;
; input:
;		none
; output:
;		none	
pick_up_boy_bundle:
	pusha
	
	mov ax, SOUND_BUNDLE_PICK_UP
	call play_sound
	
	mov word [cs:heldBundleType], WISH_TYPE_BOY
	
	mov al, OBJECT_BOY_BUNDLE_SPRITE
	call common_sprites_get_properties	; CX := stork X, DX := stork Y
	
	push word [cs:boyBundleFileContentsSeg]
	pop ds
	mov si, word [cs:boyBundleFileContentsOff]
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)

	mov bl, OBJECT_BUNDLE_SPRITE_WIDTH
	mov al, HELD_BUNDLE_SPRITE
	call common_sprites_create
	
	call reposition_held_bundle
	
	mov al, OBJECT_BOY_BUNDLE_SPRITE
	call relocate_bundle_object
	
	popa
	ret


; Makes the stork hold the girl bundle
;
; input:
;		none
; output:
;		none	
pick_up_girl_bundle:
	pusha
	
	mov ax, SOUND_BUNDLE_PICK_UP
	call play_sound
	
	mov word [cs:heldBundleType], WISH_TYPE_GIRL
	
	mov al, OBJECT_GIRL_BUNDLE_SPRITE
	call common_sprites_get_properties	; CX := stork X, DX := stork Y
	
	push word [cs:girlBundleFileContentsSeg]
	pop ds
	mov si, word [cs:girlBundleFileContentsOff]
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)

	mov bl, OBJECT_BUNDLE_SPRITE_WIDTH
	mov al, HELD_BUNDLE_SPRITE
	call common_sprites_create
	
	call reposition_held_bundle
	
	mov al, OBJECT_GIRL_BUNDLE_SPRITE
	call relocate_bundle_object
		
	popa
	ret
	

; Checks whether the user is moving the stork, and performs the action if so
;
; input:
;		none
; output:
;		none
move_stork_check:
	pusha
	mov dx, 0					; DX is used to check whether stork moved
move_stork_check_down:	
	mov bl, COMMON_SCAN_CODE_DOWN_ARROW
	int 0BAh
	cmp al, 0
	je move_stork_check_up		; down not pressed
	call move_stork_down
	mov dx, 1
move_stork_check_up:
	mov bl, COMMON_SCAN_CODE_UP_ARROW
	int 0BAh
	cmp al, 0
	je move_stork_check_left	; up not pressed
	call move_stork_up
	mov dx, 1
move_stork_check_left:
	mov bl, COMMON_SCAN_CODE_LEFT_ARROW
	int 0BAh
	cmp al, 0
	je move_stork_check_right	; left not pressed
	call move_stork_left
	mov dx, 1
move_stork_check_right:
	mov bl, COMMON_SCAN_CODE_RIGHT_ARROW
	int 0BAh
	cmp al, 0
	je move_stork_done			; right not pressed
	call move_stork_right
	mov dx, 1
move_stork_done:
	cmp dx, 0					; did the stork move?
	je move_stork_exit			; no, so just exit
	; the stork did move, so we have to re-position held bundle
	call reposition_held_bundle
move_stork_exit:
	popa
	ret
	

; Attempts to move the stork down
;
; input:
;		none
; output:
;		none
move_stork_down:
	pusha
	mov al, STORK_SPRITE
	call common_sprites_get_properties	; CX := X, DX := Y
	add dx, STORK_SPEED
	
	push dx
	add dx, STORK_SPRITE_HEIGHT
	cmp dx, COMMON_GRAPHICS_SCREEN_HEIGHT
	jae move_stork_down_overflow
	pop dx
	call common_sprites_move	; perform move
	popa
	ret
	
move_stork_down_overflow:
	pop dx
	mov dx, COMMON_GRAPHICS_SCREEN_HEIGHT - STORK_SPRITE_HEIGHT
	call common_sprites_move	; perform move
	popa
	ret
	
; Attempts to move the stork up
;
; input:
;		none
; output:
;		none
move_stork_up:
	pusha
	mov al, STORK_SPRITE
	call common_sprites_get_properties	; CX := X, DX := Y
	
	cmp dx, STORK_SPEED
	jb move_stork_up_overflow
	
	sub dx, STORK_SPEED
	call common_sprites_move	; perform move
	popa
	ret
move_stork_up_overflow:
	mov dx, 0
	call common_sprites_move	; perform move
	popa
	ret
	
; Attempts to move the stork left
;
; input:
;		none
; output:
;		none
move_stork_left:
	pusha
	mov al, STORK_SPRITE
	call common_sprites_hflip_set
	
	call common_sprites_get_properties	; CX := X, DX := Y

	cmp cx, STORK_SPEED + OBJECT_BUNDLE_EDGE_OFFSET
	jb move_stork_left_overflow

	sub cx, STORK_SPEED
	call common_sprites_move	; perform move
	popa
	ret
	
move_stork_left_overflow:
	mov cx, OBJECT_BUNDLE_EDGE_OFFSET
	call common_sprites_move	; perform move
	popa
	ret

; Attempts to move the stork right
;
; input:
;		none
; output:
;		none
move_stork_right:
	pusha
	mov al, STORK_SPRITE
	call common_sprites_hflip_clear
	
	call common_sprites_get_properties	; CX := X, DX := Y
	add cx, STORK_SPEED
	
	push cx
	add cx, STORK_SPRITE_WIDTH
	cmp cx, COMMON_GRAPHICS_SCREEN_WIDTH - OBJECT_BUNDLE_EDGE_OFFSET
	jae move_stork_right_overflow
	pop cx
	call common_sprites_move	; perform move
	popa
	ret
	
move_stork_right_overflow:
	pop cx
	mov cx, COMMON_GRAPHICS_SCREEN_WIDTH - STORK_SPRITE_WIDTH - OBJECT_BUNDLE_EDGE_OFFSET
	call common_sprites_move	; perform move
	popa
	ret


; Repositions the sprite of the bundle held by the stork, after the stork 
; moves
;
; input:
;		none
; output:
;		none	
reposition_held_bundle:
	pusha
	
	mov al, STORK_SPRITE
	call common_sprites_get_properties	; CX := stork X, DX := stork Y
										; BL := stork flags
	test bl, SPRITE_FLAG_HFLIP
	jnz reposition_held_bundle_stork_is_facing_left
reposition_held_bundle_stork_is_facing_right:
	; shift relative to stork position
	add cx, 20							; shift X position
	jmp reposition_held_bundle_done
	
reposition_held_bundle_stork_is_facing_left:
	; shift relative to stork position
	sub cx, 4							; shift X position

reposition_held_bundle_done:
	add dx, 14							; shift Y position
	mov al, HELD_BUNDLE_SPRITE
	call common_sprites_move			; move held bundle
	
	popa
	ret
	

; Makes the stork-held bundle wiggle by flipping it horizontally
; every few frames
;
; input:
;		none
; output:
;		none	
animate_held_bundle:
	pusha
	
	test word [cs:videoFrameCounter], 4		; animate every few frames
	jz animate_held_bundle_done
	mov al, HELD_BUNDLE_SPRITE
	call common_sprites_hflip_toggle
animate_held_bundle_done:	
	popa
	ret
	

; Attempts to drop off a bundle (boy or girl)
;
; Called when:
;   - user has pressed the action button
;   - stork is holding a bundle
;
; input:
;		none
; output:
;		none
drop_off_bundle:
	pusha

	mov bh, HELD_BUNDLE_SPRITE
	mov bl, WISH_FIRST_SPRITE
drop_off_bundle_loop:
	call common_sprites_check_collision
	cmp al, 0
	jne drop_off_bundle_is_collision	; we have a collision
	inc bl								; next wish sprite
	cmp bl, WISH_LAST_SPRITE
	jbe drop_off_bundle_loop			; we're not past last wish sprite
	jmp drop_off_bundle_done			; we're past the last wish sprite

drop_off_bundle_is_collision:
	; the stork is colliding with a "wish bubble" (which may be invisible!)
	; here, BL = sprite of wish with which the stork collided

	sub bl, WISH_FIRST_SPRITE		; convert BL to wish index
	mov bh, 0						; BX := BL
	shl bx, 1						; convert to offset
	mov ax, word [cs:heldBundleType]
	
	cmp word [cs:wishTypes+bx], WISH_TYPE_NONE
	je drop_off_bundle_done			; if the wish slot contains NONE, then it
									; is invisible, so we don't play a sound
									; and just exit
	
	cmp ax, word [cs:wishTypes+bx]	; is type held equal to wish type?
	jne drop_off_bundle_wrong_type	; no, so there's nothing to do
									; (play sound as we exit)

	; stork is on top of a hollow with a wish that matches the held bundle
	mov ax, SOUND_BUNDLE_DROPOFF
	call play_sound
	
	mov word [cs:wishTypes+bx], WISH_TYPE_NONE	; clear wish type
	shr bx, 1						; convert to index
	mov al, bl						; AL := wish index
	add al, WISH_FIRST_SPRITE		; convert AL to sprite number
	call common_sprites_hide		; hide wish
	
	mov al, HELD_BUNDLE_SPRITE
	call common_sprites_hide		; hide held bundle
	mov word [cs:heldBundleType], WISH_TYPE_NONE	; we're now holding nothing

	call increase_score
	jmp drop_off_bundle_done
	
drop_off_bundle_wrong_type:
	mov ax, SOUND_WRONG_BUNDLE_TYPE
	call play_sound
	
drop_off_bundle_done:
	popa
	ret


; Increases the player score
;
; input:
;		none
; output:
;		none	
increase_score:
	pusha
	
	add word [cs:score], POINTS_PER_BUNDLE

	popa
	ret
	

; Creates a wish and makes it visible
;
; input:
;		AL - wish index
; output:
;		none
create_wish:
	pusha
	
	mov ah, 0					; AX := wish index
	push ax						; [1] save wish index
	
	mov bx, ax					; BX := wish index
	shl bx, 1					; convert to offset
	
	; decide if the wish is for a boy or a girl
	int 86h						; AX := random number
	and ax, 1
	jz create_wish_girl
create_wish_boy:
	push word [cs:boyWishFileContentsSeg]
	pop ds
	mov si, word [cs:boyWishFileContentsOff]
	mov word [cs:wishTypes+bx], WISH_TYPE_BOY
	jmp create_wish_sex_chosen
create_wish_girl:
	push word [cs:girlWishFileContentsSeg]
	pop ds
	mov si, word [cs:girlWishFileContentsOff]
	mov word [cs:wishTypes+bx], WISH_TYPE_GIRL

create_wish_sex_chosen:
	pop ax						; [1] restore wish index
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)
	; here, BX = wish entry offset, from above
	mov cx, word [cs:wishSpriteXs+bx]	; CX := X location
	mov dx, word [cs:wishSpriteYs+bx]	; DX := Y location
	
	mov bl, WISH_BITMAP_WIDTH	; sprite side size (sprites are square)
	add al, WISH_FIRST_SPRITE	; convert wish number to wish sprite number
	call common_sprites_create
	
	mov bl, WISH_ANIMATION_FRAMES		; number of animation frames
	mov cx, WISH_ANIMATION_FRAMES_DELAY ; vid. frames between animation changes
	call common_sprites_set_animation_params
	call common_sprites_animate			; start animating this sprite
	
	popa
	ret

	
; Attempts to generate a new wish
; Assumes that at least one wish slot is available
;
; input:
;		none
; output:
;		none
generate_wish:
	pusha
	
	cmp word [cs:framesSinceLastWishSpawn], FORCE_SPAWN_AFTER_FRAME_COUNT
	jae generate_wish_try	; if it's time to force a spawn, we can skip over
							; the initial "dice roll"
	
	int 86h			; AX := random number
	cmp ax, WISH_GENERATION_CHANCE
	jae generate_wish_no	; we're not generating anything this time

generate_wish_try:
	int 86h			; AX := random number
	and ax, 7		; AX := AX mod 8

	cmp ax, WISH_NUM_SPRITES
	jae generate_wish_try	; was greater than index of last wish, so retry

	; here, AX contains a random wish index
	mov bx, ax
	shl bx, 1			; convert to offset
	add bx, wishTypes	; convert to pointer
generate_wish_find_spot:
	cmp word [cs:bx], WISH_TYPE_NONE	; is this slot available?
	je generate_wish_found_spot			; yes!
	; this spot is taken, so we try the next one
	add bx, 2		; next entry (2 bytes per entry)
	cmp bx, wishTypesEnd		; are we past the end?
	jb generate_wish_find_spot	; no, so loop again
	; we're past end, so restart at the beginning
	mov bx, wishTypes			; reset pointer to first element of array
								; the assumption of at least one empty spot
	jmp generate_wish_find_spot	; prevents this from looping infinitely
	
generate_wish_found_spot:
	; here, BX = pointer to random empty spot in the wishTypes array
	sub bx, wishTypes			; convert to offset
	shr bx, 1					; convert to index (2 bytes per entry)
	mov al, bl					; AL := index
	call create_wish			; create wish with index in AL
	
	mov word [cs:framesSinceLastWishSpawn], 0	; we just generated a wish
	jmp generate_wish_done
	
generate_wish_no:
	; we're not generating a wish this time
	inc word [cs:framesSinceLastWishSpawn]
	
generate_wish_done:
	popa
	ret

	
; Checks whether any wish slots are available for population
;
; input:
;		none
; output:
;		AX - 0 when no slots are available, other value otherwise
is_wish_available:
	push bx
	
	mov bx, wishTypes			; initialize pointer to first element
is_wish_available_loop:
	cmp word [cs:bx], WISH_TYPE_NONE
	je is_wish_available_yes	; if this slot is available, we're done
	
	add bx, 2			; next offset
	cmp bx, wishTypesEnd
	jb is_wish_available_loop
	; reached past end, and nothing found
is_wish_available_no:
	mov ax, 0
	jmp is_wish_available_exit
is_wish_available_yes:
	mov ax, 1
is_wish_available_exit:
	pop bx
	ret

	
; Moves a bundle object to a random vertical location
;
; input:
;		AL - sprite number of bundle object to move vertically
; output:
;		none
relocate_bundle_object:
	pusha
	
	push ax
	
	int 86h					; AX := random number
	mov bx, ax
	and bx, 127				; AX := AX mod 128
	add bx, COMMON_GRAPHICS_SCREEN_HEIGHT/2 - 128/2 - OBJECT_BUNDLE_SPRITE_HEIGHT/2
	pop ax					; AX := sprite number
	push bx					; save new Y position
	
	call common_sprites_get_properties	; CX := X, DX := Y
	pop dx						; DX := new Y position	
	call common_sprites_move	; perform move
	
	popa
	ret

	
; Keeps the progress indicator updated during game play
;
; input:
;		none
; output:
;		none
refresh_progress_indicator:
	pusha
	
	mov bx, INDICATOR_X
	mov ax, INDICATOR_Y
	call common_graphics_coordinate_to_video_offset
	mov di, ax
	
	mov dx, word [cs:score]		; current value
	mov cx, MAX_SCORE		; maximum value
	mov bl, 2					; frame colour
	mov bh, 47					; bar colour
	mov ax, INDICATOR_HEIGHT	; height
	call common_graphics_utils_draw_prograss_indicator
	
	popa
	ret


; Updates the game time
;
; input:
;		none
; output:
;		none	
update_time:
	pusha
	
	cmp word [cs:timeRemaining], 0
	je update_time_done
	
	mov ax, word [cs:videoFrameCounter]
	and ax, 127
	cmp ax, 127
	jne update_time_done
	
	dec word [cs:timeRemaining]
update_time_done:
	popa
	ret
	

; Keeps the time indicator updated during game play
;
; input:
;		none
; output:
;		none
refresh_time_indicator:
	pusha

	mov bx, INDICATOR_X
	mov ax, INDICATOR_Y + INDICATOR_VERTICAL_GAP
	call common_graphics_coordinate_to_video_offset
	mov di, ax
	
	mov dx, word [cs:timeRemaining]
	mov cx, TIME_AVAILABLE		; maximum value
	mov bl, 4					; frame colour
	mov bh, 39					; bar colour
	mov ax, INDICATOR_HEIGHT	; height
	call common_graphics_utils_draw_prograss_indicator
	
	popa
	ret
	

; Refresh all gauges visible on screen.
; This is the only place where background modifications are made.
;
; input:
;		none
; output:
;		none	
refresh_indicators:
	pusha

	mov ax, word [cs:score]
	cmp ax, word [cs:oldScore]
	jne refresh_indicators_perform		; score has changed, so refresh
	
	mov bx, word [cs:timeRemaining]
	cmp bx, word [cs:oldTimeRemaining]
	jne refresh_indicators_perform		; time has changed, so refresh
	
	jmp refresh_indicators_done			; NOOP when nothing changed

refresh_indicators_perform:
	call common_sprites_background_change_prepare	; begin background change
	call refresh_progress_indicator				; perform all background
	call refresh_time_indicator					; changes
	call common_sprites_background_change_finish	; finish background change
	
	mov word [cs:oldScore], ax			; old score := new score
	mov word [cs:oldTimeRemaining], bx	; old time := new time
	
refresh_indicators_done:	
	popa
	ret
	
	
; Plays a Storks sound effect
;
; input:
;		AX - sound effect ID
; output:
;		none
play_sound:
	pusha
	
	cmp ax, SOUND_PHASE_TRANSITION
	je play_sound_phase_transition
	cmp ax, SOUND_BUNDLE_PICK_UP
	je play_sound_pick_up
	cmp ax, SOUND_BUNDLE_DROPOFF
	je play_sound_drop_off
	cmp ax, SOUND_VICTORY
	je play_sound_victory
	cmp ax, SOUND_LOSS
	je play_sound_loss
	cmp ax, SOUND_WRONG_BUNDLE_TYPE
	je play_sound_wrong_bundle_type
	jmp play_sound_done
	
play_sound_phase_transition:
	mov ch, COMMON_SOUND_MODE_NORMAL	; sound mode
	mov cl, 5					; duration in ticks
	mov dx, 0					; per-tick frequency shift
	mov ax, 2031				; D
	int 0B9h					; output
	mov ax, 1612				; F#
	int 0B9h					; output
	mov ax, 1355				; A
	jmp play_sound_perform
play_sound_pick_up:
	mov ch, COMMON_SOUND_MODE_NORMAL	; sound mode
	mov cl, 8					; duration in ticks
	mov dx, -60					; per-tick frequency shift
	mov ax, 2031				; D to A
	jmp play_sound_perform
play_sound_drop_off:
	mov ch, COMMON_SOUND_MODE_NORMAL	; sound mode
	mov cl, 4					; duration in ticks
	mov dx, 0					; per-tick frequency shift
	mov ax, 2711				; A
	int 0B9h					; output
	mov ax, 2152				; C#
	int 0B9h					; output
	mov ax, 1809				; E
	jmp play_sound_perform
play_sound_victory:
	mov ch, COMMON_SOUND_MODE_NORMAL	; sound mode
	mov cl, 30					; duration in ticks
	mov dx, 0					; per-tick frequency shift
	mov ax, 3043				; G
	int 0B9h					; output
	mov ax, 2415				; B
	int 0B9h					; output
	mov ax, 2031				; D
	jmp play_sound_perform
play_sound_loss:
	mov ch, COMMON_SOUND_MODE_NORMAL	; sound mode
	mov cl, 30					; duration in ticks
	mov dx, 0					; per-tick frequency shift
	mov ax, 2152				; C#
	int 0B9h					; output
	mov ax, 1809				; E
	int 0B9h					; output
	mov ax, 2873				; G
	jmp play_sound_perform
play_sound_wrong_bundle_type:
	mov ch, COMMON_SOUND_MODE_NORMAL	; sound mode
	mov cl, 6					; duration in ticks
	mov dx, 0					; per-tick frequency shift
	mov ax, 2152				; C#
	int 0B9h					; output
	mov ax, 4304				; C#

play_sound_perform:
	; output the sound
	int 0B9h					; output
	
play_sound_done:
	popa
	ret


;------------------------------------------------------------------------------
; Initialization procedures
;------------------------------------------------------------------------------

; Initializes text next to the indicators
;
; input:
;		none
; output:
;		none
initialize_indicator_labels:
	pusha
	
	; progress
	mov dx, COMMON_TEXT_PRINT_FLAG_DOUBLE_WIDTH
	mov si, progressLabel
	mov bx, INDICATOR_X - 8*8 - 2
	mov ax, INDICATOR_Y - 2
	mov cl, INDICATOR_LABEL_COLOUR
	call common_graphics_text_print_at
	
	; time
	mov si, timeLabel
	add bx, 4*8
	add ax, INDICATOR_VERTICAL_GAP
	call common_graphics_text_print_at
	
	popa
	ret

	
; Initializes all wishes to NONE
;
; input:
;		none
; output:
;		none
initialize_wishes:
	pusha
	pushf
	
	mov ax, WISH_TYPE_NONE
	mov cx, WISH_NUM_SPRITES
	mov di, wishTypes
	cld
	rep stosw
	
	popf
	popa
	ret


; Initializes the palette that will be used for all game graphics
;
; input:
;		none
; output:
;		none
initialize_palette:
	pusha
	push ds
	
	; make the background BMP's palette current, since all BMP palettes of 
	; our BMPs are the same as that
	push word [cs:allocatedSegment]
	pop ds
	mov si, 0					; DS:SI := pointer to background BMP file data
	call common_bmp_get_VGA_palette_from_bmp	; DS:SI := ptr to palette
	call common_graphics_load_palette
	
	pop ds
	popa
	ret


; Creates stork sprite
;
; input:
;		none
; output:
;		none
initialize_stork:
	pusha

	push word [cs:storkFileContentsSeg]
	pop ds
	mov si, word [cs:storkFileContentsOff]
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)

	mov cx, COMMON_GRAPHICS_SCREEN_WIDTH/2-STORK_SPRITE_WIDTH/2		; sprite X
	mov dx, COMMON_GRAPHICS_SCREEN_HEIGHT/2-STORK_SPRITE_HEIGHT/2	; sprite Y
	mov bl, STORK_SPRITE_WIDTH	; sprite side size (sprites are square)
	mov al, STORK_SPRITE
	call common_sprites_create
	
	mov bl, STORK_ANIMATION_FRAMES	; number of animation frames
	mov cx, STORK_ANIMATION_FRAME_DELAY	; vid. frames between animation changes
	call common_sprites_set_animation_params
	call common_sprites_animate		; start animating this sprite
	
	popa
	ret
	

; Decorates the menu with text
;
; input:
;		none
; output:
;		none
initialize_menu_text:
	pusha
	
	; draw a coloured strip
	mov bx, 0
	mov ax, 15
	call common_graphics_coordinate_to_video_offset
	mov di, ax
	mov ax, 64
	mov dx, COMMON_GRAPHICS_SCREEN_WIDTH
	mov bl, 190
	call common_graphics_draw_rectangle_solid
	
	; title
	mov dx, COMMON_TEXT_PRINT_FLAG_CENTRE | COMMON_TEXT_PRINT_FLAG_DOUBLE_WIDTH
	mov si, menuTitle
	mov ax, 42
	mov cl, 37
	call common_graphics_text_print_at
	
	; rest of text on menu screen
	mov si, menuMessage
	mov dx, COMMON_TEXT_PRINT_FLAG_NORMAL
	mov bx, 0
	mov ax, 90
	mov cl, 15
	call common_graphics_text_print_at
	
	popa
	ret
	
	
; Creates the stork sprites used on the menu screen
;
; input:
;		none
; output:
;		none
initialize_menu_storks:
	pusha
		
	push word [cs:storkFileContentsSeg]
	pop ds
	mov si, word [cs:storkFileContentsOff]
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)

	mov cx, 40		; sprite X
	mov dx, 30		; sprite Y
	mov bl, STORK_SPRITE_WIDTH	; sprite side size (sprites are square)
	mov al, MENU_STORK_SPRITE1
	call common_sprites_create
	
	mov bl, STORK_ANIMATION_FRAMES	; number of animation frames
	mov cx, STORK_ANIMATION_FRAME_DELAY	; vid. frames between animation changes
	call common_sprites_set_animation_params
	call common_sprites_animate		; start animating this sprite
	
	; second stork
	mov cx, 248		; sprite X
	mov dx, 30		; sprite Y
	mov bl, STORK_SPRITE_WIDTH	; sprite side size (sprites are square)
	mov al, MENU_STORK_SPRITE2
	call common_sprites_create
	
	mov bl, STORK_ANIMATION_FRAMES	; number of animation frames
	mov cx, STORK_ANIMATION_FRAME_DELAY	; vid. frames between animation changes
	call common_sprites_set_animation_params
	call common_sprites_animate		; start animating this sprite
	
	call common_sprites_hflip_set
	
	popa
	ret
	

; Creates objects sprites (the boy and girl bundles that can be picked up)
;
; input:
;		none
; output:
;		none
initialize_objects:
	pusha
	
	push word [cs:boyBundleFileContentsSeg]
	pop ds
	mov si, word [cs:boyBundleFileContentsOff]
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)

	mov cx, OBJECT_BOY_BUNDLE_SPRITE_X
	mov dx, OBJECT_BOY_BUNDLE_SPRITE_Y
	mov bl, OBJECT_BUNDLE_SPRITE_WIDTH
	mov al, OBJECT_BOY_BUNDLE_SPRITE
	call common_sprites_create
	
	push word [cs:girlBundleFileContentsSeg]
	pop ds
	mov si, word [cs:girlBundleFileContentsOff]
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	mov si, di					; DS:SI := pointer to pixel data
								; (calls farther down need pointer in DS:SI)

	mov cx, OBJECT_GIRL_BUNDLE_SPRITE_X
	mov dx, OBJECT_GIRL_BUNDLE_SPRITE_Y
	mov bl, OBJECT_BUNDLE_SPRITE_WIDTH
	mov al, OBJECT_GIRL_BUNDLE_SPRITE
	call common_sprites_create
	
	popa
	ret
	

; Draws the background bitmap, which is assumed to have been loaded
; already.
;
; input:
;		none
; output:
;		none
draw_background:
	pusha
	push ds
	push es
	
	push word [cs:allocatedSegment]
	pop ds
	mov si, 0					; DS:SI now points to file data
	call common_bmp_get_pixel_data_pointer ; DS:DI := pointer to pixel data
	call common_bmp_get_dimensions	; AX:BX - height of image
									; CX:DX - width of image
	
	mov ax, bx						; AX := low word of image height
									; DX = low word of image width (from above)
	push word [cs:allocatedSegment]
	pop ds
	mov bx, di						; DS:BX := pointer to pixel data
	mov si, dx						; SI := low word of bitmap width
	mov di, 0						; offset in video memory
	call common_graphics_draw_rectangle_opaque
	
	pop es
	pop ds
	popa
	ret
	

; Loads all bitmap files into memory
;
; input:
;		none
; output:
;		none
load_bitmaps:
	pusha
	
	; title
	mov dx, COMMON_TEXT_PRINT_FLAG_CENTRE | COMMON_TEXT_PRINT_FLAG_DOUBLE_WIDTH
	mov si, loadingMessage
	mov ax, 96							; Y position
	mov cl, 37
	call common_graphics_text_print_at
	
	; background
	push cs
	pop ds
	mov si, backgroundFat12Filename	; DS:SI now points to file name
	push word [cs:allocatedSegment]
	pop es
	mov di, 0					; ES:DI now points to where we'll load file
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
								
	push cs
	pop es
	
	; stork
	mov ax, FILE_SIZE_STORK					; allocate this many bytes
	call common_memory_allocate		; DS:SI := newly allocated pointer
	mov word [cs:storkFileContentsSeg], ds
	mov word [cs:storkFileContentsOff], si
	push cs
	pop ds
	mov si, storkFat12Filename
	push word [cs:storkFileContentsSeg]
	pop es
	mov di, word [cs:storkFileContentsOff]
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes	
								
	; boy bundle
	mov ax, FILE_SIZE_BOY_BUNDLE			; allocate this many bytes
	call common_memory_allocate		; DS:SI := newly allocated pointer
	mov word [cs:boyBundleFileContentsSeg], ds
	mov word [cs:boyBundleFileContentsOff], si
	push cs
	pop ds
	mov si, boyBundleFat12Filename
	push word [cs:boyBundleFileContentsSeg]
	pop es
	mov di, word [cs:boyBundleFileContentsOff]
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
	; girl bundle
	mov ax, FILE_SIZE_GIRL_BUNDLE			; allocate this many bytes
	call common_memory_allocate		; DS:SI := newly allocated pointer
	mov word [cs:girlBundleFileContentsSeg], ds
	mov word [cs:girlBundleFileContentsOff], si
	push cs
	pop ds
	mov si, girlBundleFat12Filename
	push word [cs:girlBundleFileContentsSeg]
	pop es
	mov di, word [cs:girlBundleFileContentsOff]
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
	; boy wish
	mov ax, FILE_SIZE_BOY_WISH			; allocate this many bytes
	call common_memory_allocate		; DS:SI := newly allocated pointer
	mov word [cs:boyWishFileContentsSeg], ds
	mov word [cs:boyWishFileContentsOff], si
	push cs
	pop ds
	mov si, boyWishFat12Filename
	push word [cs:boyWishFileContentsSeg]
	pop es
	mov di, word [cs:boyWishFileContentsOff]
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes

	; girl wish
	mov ax, FILE_SIZE_GIRL_WISH			; allocate this many bytes
	call common_memory_allocate		; DS:SI := newly allocated pointer
	mov word [cs:girlWishFileContentsSeg], ds
	mov word [cs:girlWishFileContentsOff], si
	push cs
	pop ds
	mov si, girlWishFat12Filename
	push word [cs:girlWishFileContentsSeg]
	pop es
	mov di, word [cs:girlWishFileContentsOff]
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
	popa
	ret
	

%include "common\bmp.asm"
%include "common\vga320\graphics.asm"
%include "common\gra_fx.asm"
%include "common\vga320\gra_text.asm"
%include "common\vga320\gra_util.asm"
%include "common\text.asm"
%include "common\keyboard.asm"
%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\sound.asm"
%include "common\tasks.asm"
%include "common\memory.asm"

%include "common\vga320\sprite_m.asm"	; configure library to use medium-sized sprites
%include "common\vga320\sprites.asm"	; include sprites library

; the background BMP file data is loaded into its own allocated segment
dynamicMemoryArea:
