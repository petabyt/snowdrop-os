;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains a framework for working with graphical sprites. Ultimately, this 
; accomplishes things like:
;     - move images across a background (without "erasing" it)
;     - animate images from "animation strips" of consecutive frames
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_SPRITES_LIMITS_
%define _COMMON_SPRITES_LIMITS_

; These sprite limits are defined separately so that they could be overridden 
; by including a separate file before including THIS file.
; The separate file can define other values for these.
; In essence, the values here are defaults.
;
; For example, other include files may define the sprites to be 
; larger and fewer
COMMON_SPRITES_SPRITE_MAX_SIZE equ 16			; side length, in pixels
COMMON_SPRITES_MAX_SPRITES equ 50

%endif


%ifndef _COMMON_SPRITES_
%define _COMMON_SPRITES_

; these govern sprite behaviour
SPRITE_FLAG_ACTIVE 	  equ 00000001b	; whether this sprite is in use
SPRITE_FLAG_ANIMATING equ 00000010b	; whether this sprite is being animated
SPRITE_FLAG_DIRTY_X	  equ 00000100b	; whether this sprite has moved 
									; horizontally since it was last drawn
SPRITE_FLAG_DIRTY_Y	  equ 00001000b	; whether this sprite has moved
									; vertically since it was last drawn
SPRITE_FLAG_VISIBLE	  equ 00010000b	; whether this sprite is shown on screen
SPRITE_FLAG_HFLIP	  equ 00100000b	; whether this sprite is flipped
									; horizontally

; format of a single sprites table entry:
; bytes
;     0-1 X position
;     2-3 Y position
;     4-5 pointer to pixel data of frame 0 (segment)
;     6-7 pointer to pixel data of frame 0 (offset)
;     8-8 flags, as such:
;           bit 0 - set when sprite is active (on screen)
;           bit 1 - set when the sprite is animating
;           bit 2 - set when the sprite has moved horizontally 
;                   since it was last drawn
;           bit 3 - set when the sprite has moved vertically 
;                   since it was last drawn
;           bit 4 - set when the sprite is visible on screen
;           bit 5 - set when the sprite is flipped horizontally
;         bit 6-7 - unused
;    9-10 old X position
;   11-12 old Y position
;   13-13 pixel data side length (sprites are square)

;   14-14 current animation frame number
;   15-15 total animation frames
;   16-17 video frames per animation frame
;   18-19 video frames countdown in current animation frame

;   20-21 pointer to current animation frame pixel data (offset)

;   22-31 unused
;   32-   background rectangle buffer (used to preserve pixels behind sprite)

; the following are all in bytes
SPRITES_TABLE_ENTRY_HEADER_SIZE equ 32
SPRITES_TABLE_ENTRY_DATA_SIZE equ COMMON_SPRITES_SPRITE_MAX_SIZE * COMMON_SPRITES_SPRITE_MAX_SIZE
SPRITES_TABLE_ENTRY_SIZE equ SPRITES_TABLE_ENTRY_HEADER_SIZE + 	SPRITES_TABLE_ENTRY_DATA_SIZE
SPRITES_TABLE_SIZE equ COMMON_SPRITES_MAX_SPRITES * SPRITES_TABLE_ENTRY_SIZE

spritesTable: times SPRITES_TABLE_SIZE db 0
spritesTableEnd:				; marker for end of array

spritesDirtyFlag: db 0			; when non-zero, the next refresh will redraw
								; sprites
spritesConfig: dw 0				; can be set by consumers to modify the
								; behaviour of the sprites library

COMMON_SPRITES_CONFIG_VSYNC_ON_REFRESH equ 1
					; wait for vsync before redrawing sprites
COMMON_SPRITES_CONFIG_ANIMATE_ON_REFRESH equ 2
					; animate all sprites before redrawing sprites

; Initializes the sprites data area. Sets all sprites as inactive
;
; Input:
;		none
; Output:
;		none
common_sprites_initialize:
	pushf
	pusha
	push es
	
	push cs
	pop es
	
	mov al, 0
	mov cx, SPRITES_TABLE_SIZE
	mov di, spritesTable
	cld
	rep stosb					; zero out sprites table
	
	mov byte [cs:spritesDirtyFlag], 0
	mov word [cs:spritesConfig], 0
	
	pop es
	popa
	popf
	ret


; Configures the sprites library
;
; Input:
;		AX - configuration flags
; Output:
;		none	
common_sprites_set_config:
	pusha
	
	mov word [cs:spritesConfig], ax
	
	popa
	ret
	

; Returns properties of the specified sprite
;
; Input:
;		AL - sprite number
; Output:
;		CX - X position
;		DX - Y position
;		BL - flags
common_sprites_get_properties:
	push es
	push di
	
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	mov cx, word [es:di+0]			; CX := current X
	mov dx, word [es:di+2]			; DX := current Y
	mov bl, byte [es:di+8]			; BL := sprite flags
	
	pop di
	pop es
	ret
	

; Marks sprites for rendering during the next refresh operation
;
; Input:
;		none
; Output:
;		none
common_sprites_invalidate:
	pusha
	
	mov byte [cs:spritesDirtyFlag], 1
	
	popa
	ret


; Changes the position of the specified sprite
;
; Input:
;		AL - sprite number
;		CX - X position
;		DX - Y position
; Output:
;		none	
common_sprites_move:
	pusha
	push es
	
	cmp cx, COMMON_GRAPHICS_SCREEN_WIDTH
	jae sprites_move_done			; don't move out of bounds
	
	cmp dx, COMMON_GRAPHICS_SCREEN_HEIGHT
	jae sprites_move_done			; don't move out of bounds
	
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
common_sprites_move_check_horizontal:
	cmp word [es:di+0], cx			; are current X and new X equal?
	je common_sprites_move_check_vertical	; yes, so no horizontal movement
	test byte [es:di+8], SPRITE_FLAG_DIRTY_X ; is it dirty already?
	jnz common_sprites_move_horizontal_perform	; yes, so we don't store old
	; store old X, only the FIRST time this sprite moves this frame
	mov ax, word [es:di+0]			; AX := current X
	mov word [es:di+9], ax			; old X := current X
	; this sprite is now no longer synchronized with the display
	or byte [es:di+8], SPRITE_FLAG_DIRTY_X	; mark THIS sprite as dirty
	mov byte [cs:spritesDirtyFlag], 1		; mark sprites overall as dirty
common_sprites_move_horizontal_perform:
	; perform horizontal movement
	mov word [es:di+0], cx			; store new X position
	
	; now check for vertical movement
common_sprites_move_check_vertical:
	cmp word [es:di+2], dx			; are current Y and new Y equal?
	je sprites_move_done			; yes, so no vertical movement
	test byte [es:di+8], SPRITE_FLAG_DIRTY_Y ; is it dirty already?
	jnz common_sprites_move_vertical_perform	; yes, so we don't store old
	; store old Y, only the FIRST time this sprite moves this frame
	mov ax, word [es:di+2]			; AX := current Y
	mov word [es:di+11], ax			; old Y := current Y
	; this sprite is now no longer synchronized with the display
	or byte [es:di+8], SPRITE_FLAG_DIRTY_Y	; mark THIS sprite as dirty
	mov byte [cs:spritesDirtyFlag], 1		; mark sprites overall as dirty
common_sprites_move_vertical_perform:
	; perform vertical movement
	mov word [es:di+2], dx			; store new Y position
	
sprites_move_done:
	pop es
	popa
	ret
	
	
; Makes the specified sprite invisible
;
; Input:
;		AL - sprite number
; Output:
;		none
common_sprites_hide:
	pusha
	push es

	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
	mov al, byte [es:di+8]			; AL := flags
	
	test al, SPRITE_FLAG_VISIBLE
	jz common_sprites_hide_done		; already hidden, so NOOP

	mov bl, 0FFh
	xor bl, SPRITE_FLAG_VISIBLE
	and al, bl						; clear "is visible" bit
	mov byte [es:di+8], al

	; sprites are now no longer synchronized with the display
	mov byte [cs:spritesDirtyFlag], 1
	
common_sprites_hide_done:
	pop es
	popa
	ret
	
	
; Makes the specified sprite visible
;
; Input:
;		AL - sprite number
; Output:
;		none
common_sprites_show:
	pusha
	push es

	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
	test byte [es:di+8], SPRITE_FLAG_VISIBLE
	jnz common_sprites_show_done	; already visible, so NOOP
	
	or byte [es:di+8], SPRITE_FLAG_VISIBLE	; set "is visible" bit

	; sprites are now no longer synchronized with the display
	mov byte [cs:spritesDirtyFlag], 1
	
common_sprites_show_done:
	pop es
	popa
	ret

	
; Marks the specified sprite as horizontally flipped
;
; Input:
;		AL - sprite number
; Output:
;		none
common_sprites_hflip_set:
	pusha
	push es

	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
	test byte [es:di+8], SPRITE_FLAG_HFLIP
	jnz common_sprites_hflip_set_done		; already flipped, so NOOP
	
	or byte [es:di+8], SPRITE_FLAG_HFLIP	; set "is horizontally flipped" bit

	; sprites are now no longer synchronized with the display
	mov byte [cs:spritesDirtyFlag], 1
	
common_sprites_hflip_set_done:
	pop es
	popa
	ret

	
; Toggles the horizontal flip status of the specified sprite
;
; Input:
;		AL - sprite number
; Output:
;		none
common_sprites_hflip_toggle:
	pusha
	push es

	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
	xor byte [es:di+8], SPRITE_FLAG_HFLIP	; toggle "horizontally flipped" bit

	; sprites are now no longer synchronized with the display
	mov byte [cs:spritesDirtyFlag], 1

	pop es
	popa
	ret
	
	
; Marks the specified sprite as not horizontally flipped
;
; Input:
;		AL - sprite number
; Output:
;		none
common_sprites_hflip_clear:
	pusha
	push es

	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
	mov al, byte [es:di+8]			; AL := flags
	
	test al, SPRITE_FLAG_HFLIP
	jz common_sprites_hflip_clear_done	; already hidden, so NOOP

	mov bl, 0FFh
	xor bl, SPRITE_FLAG_HFLIP
	and al, bl						; clear "is visible" bit
	mov byte [es:di+8], al

	; sprites are now no longer synchronized with the display
	mov byte [cs:spritesDirtyFlag], 1
	
common_sprites_hflip_clear_done:
	pop es
	popa
	ret


; Removes all sprites from use
;
; Input:
;		none
; Output:
;		none
common_sprites_destroy_all:
	pusha
	
	call restore_all_background_rectangles
	
	mov al, 0
common_sprites_destroy_all_loop:
	call common_sprites_destroy
	inc al
	cmp al, COMMON_SPRITES_MAX_SPRITES
	jb common_sprites_destroy_all_loop
	
	; no sprites means no sprites are out of date
	mov byte [cs:spritesDirtyFlag], 0
	
	popa
	ret
	
	
; Removes the specified sprite from use
;
; Input:
;		AL - sprite number
; Output:
;		none
common_sprites_destroy:
	pusha
	push es
	
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	test byte [es:di+8], SPRITE_FLAG_ACTIVE
	jz common_sprites_destroy_done	; if sprite is not active, it's a NOOP
	
	call restore_all_background_rectangles
				; we want all existing sprites to be removed from the screen
				; so that restoring the background rectangle of the sprite
				; being hidden doesn't corrupt the pixels of another sprite
	
	mov byte [es:di+8], 0			; clear all flags

	; re-draw all sprites
	call save_all_background_rectangles
	call render_all_sprites
	
common_sprites_destroy_done:
	pop es
	popa
	ret
	

; Refreshes all sprites, if needed (when they're out of sync with what's 
; on screen).
; NOTE: This procedure is meant to be called at the end of every
;       animation frame.
;
; Input:
;		none
; Output:
;		none
common_sprites_refresh:
	pusha
	
	test word [cs:spritesConfig], COMMON_SPRITES_CONFIG_ANIMATE_ON_REFRESH
	jz common_sprites_refresh_start		; we're not animating before refresh
	; we're animating before refresh
	call common_sprites_animate_all	; advance animation frames for sprites
	
common_sprites_refresh_start:
	cmp byte [cs:spritesDirtyFlag], 0
	je sprites_refresh_done				; if not dirty, there's nothing to do
	; sprites are dirty, so render them
	call restore_all_background_rectangles
	call save_all_background_rectangles
	call render_all_sprites
	
sprites_refresh_done:
	popa
	ret
	

; Prepares the sprites library for a background change.
; NOTE: This procedure is meant to be called RIGHT BEFORE any modifications 
;       are made to the background.
;       The consumer is required to call this explicitly because it would not
;       be feasible for the sprite library to try to detect whether the 
;       background has changed every frame.
;
; Input:
;		none
; Output:
;		none	
common_sprites_background_change_prepare:
	pusha
	
	call restore_all_background_rectangles
	
	popa
	ret
	

; Instructs the sprites library that a background change has completed.
; NOTE: This procedure is meant to be called RIGHT AFTER any modifications 
;       are made to the background.
;       The consumer is required to call this explicitly because it would not
;       be feasible for the sprite library to try to detect whether the 
;       background has changed every frame.
;
; Input:
;		none
; Output:
;		none	
common_sprites_background_change_finish:
	pusha
	
	call save_all_background_rectangles
	call render_all_sprites
	
	popa
	ret	
	

; Makes the specified sprite active, visible, and initializes 
; all data needed to render the sprite.
;
; By default, a sprite is considered to have a single animation frame.
;
; Input:
;		AL - sprite number
;		BL - sprite side size
;		CX - X position
;		DX - Y position
;	 DS:SI - pointer to pixel data
; Output:
;		none
common_sprites_create:
	pusha
	push es
	
	call restore_all_background_rectangles
	
				; we want all existing sprites to be removed from the screen
				; so that we can "cut out" and save a "clean" background
				; rectangle for this sprite

	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
	mov word [es:di+0], cx			; store X position
	mov word [es:di+9], cx			; store old X position
	
	mov word [es:di+2], dx			; store Y position
	mov word [es:di+11], dx			; store old Y position
	
	mov al, SPRITE_FLAG_ACTIVE | SPRITE_FLAG_VISIBLE
	mov byte [es:di+8], al			; store flags

	mov word [es:di+4], ds			; store pixel data pointer segment
	mov word [es:di+6], si			; store pixel data pointer offset
	
	mov byte [es:di+13], bl			; store side length
	
	; initial animation variables are set assuming the sprite is not
	; animated
	mov byte [es:di+14], 0			; store current frame
	mov byte [es:di+15], 1			; store total frames
	mov word [es:di+16], 10			; store dummy number of video frames 
									; per animation frame
	mov word [es:di+18], 10			; store number of video frames 
									; remaining in current animation frame
	call recalculate_pixel_data_pointer	; recalculate pointer based on 
										; animation frame

	; re-draw all sprites
	call save_all_background_rectangles
	call render_all_sprites

	pop es
	popa
	ret
	

; NOTE: Assumes the background rectangle of this sprite 
; has already been restored
;
; Input:
;		AL - sprite number
; Output:
;		none
render_sprite:
	pusha
	push es
	push ds
	
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	
	mov bx, word [es:di+0]		; X
	mov dx, word [es:di+2]		; Y
	mov cl, byte [es:di+13]		; side size

	; move sprite data pixels to video memory
	push word [es:di+4]			; segment of frame 0
	pop ds	
	push word [es:di+20]		; offset of current frame
	pop si						; DS:SI now points to pixel data of current
								; animation frame
	
	mov al, byte [es:di+8]		; AL := sprite flags
	test al, SPRITE_FLAG_VISIBLE
	jz render_sprite_done_drawing	; NOOP when sprite is not visible

	; here, AL = sprite flags, from above
	call draw_sprite			; draw it!

render_sprite_done_drawing:
	; update positions
	mov word [es:di+9], bx		; old X = X
	mov word [es:di+11], dx		; old Y = Y

	; clear dirty flags
	mov al, 0FFh
	xor al, SPRITE_FLAG_DIRTY_X
	xor al, SPRITE_FLAG_DIRTY_Y
	and byte [es:di+8], al
	
	pop ds
	pop es
	popa
	ret
	

; Copies pixel data for all active and visible sprites to the screen.
; 
; Input:
;		none
; Output:
;		none
render_all_sprites:
	pusha
	push es
	
	mov al, 0
render_all_sprites_loop:
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	mov bl, byte [es:di+8]			; AL := sprite flags
	test bl, SPRITE_FLAG_ACTIVE
	jz render_all_sprites_next		; skip if not active
	
	call render_sprite
render_all_sprites_next:
	inc al
	cmp al, COMMON_SPRITES_MAX_SPRITES
	jne render_all_sprites_loop		; next sprite
	
	; sprites are now synchronized with the display
	mov byte [cs:spritesDirtyFlag], 0
	
	pop es
	popa
	ret
	
	
; Advances animation frame for all sprites
; 
; Input:
;		none
; Output:
;		none
common_sprites_animate_all:
	pusha
	push es
	
	mov al, 0
sprites_animate_all_loop:
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	mov bl, byte [es:di+8]			; AL := sprite flags
	test bl, SPRITE_FLAG_ACTIVE
	jz sprites_animate_all_next		; skip if not sprite is not active
	test bl, SPRITE_FLAG_VISIBLE
	jz sprites_animate_all_next		; skip if not sprite is not visible
	test bl, SPRITE_FLAG_ANIMATING
	jz sprites_animate_all_next		; skip if not sprite is not animating now
	
	; now decrease video frame countdown for this sprite
	dec word [es:di+18]				; decrement video frame countdown
	jnz sprites_animate_all_next	; if we haven't reached 0, we don't need
									; to advance animation frame
	; advance animation frame
	
	; sprites are now no longer synchronized with the display, since an
	; animation frame is changing
	mov byte [cs:spritesDirtyFlag], 1
	
	mov bx, word [es:di+16]			; BX := video frames per animation frame
	mov word [es:di+18], bx			; reset video frame countdown
	
	mov bl, byte [es:di+14]			; BL := current animation frame
	inc bl							; next animation frame
	cmp bl, byte [es:di+15]			; if current animation frame <
									;    total animation frames, we're done
	jb sprites_animate_all_store_animation_frame
	mov bl, 0						; else restart from animation frame 0
sprites_animate_all_store_animation_frame:
	mov byte [es:di+14], bl			; store new animation frame number
	call recalculate_pixel_data_pointer	; recalculate pointer based on new
										; animation frame
sprites_animate_all_next:
	inc al
	cmp al, COMMON_SPRITES_MAX_SPRITES
	jne sprites_animate_all_loop	; next sprite
	
	pop es
	popa
	ret
	
	
; Called when the current animation frame of a sprite has changed, 
; this procedure re-calculates the pointer to pixel data, so that it 
; points to the beginning of the current frame
;
; Input:
;	 ES:DI - pointer to sprite table slot of specified sprite
; Output:
;		none
recalculate_pixel_data_pointer:
	pusha

	push word [es:di+6]
	pop si						; SI := offset of pixel data beginning
	
	mov cl, byte [es:di+13]		; side size
	
	mov al, cl					; AL := side size
	mul cl						; AX := (side size)*(side size)
								; that is, AX = pixels per animation frame

	mov bh, 0
	mov bl, byte [es:di+14]		; BX := current animation frame number
	
	mul bx						; DX:AX := offset to pixel data of current
								;          animation frame
								; ASSUMPTION: DX = 0
								
	add si, ax					; SI := offset to beginning of pixel data
								; of current animation frame
								
	mov word [es:di+20], si		; store new pointer to pixel data of current
								; animation frame

	popa
	ret
	
	
; Sets parameters used to animate the specified sprite
;
; Input:
;		AL - sprite number
;		BL - total number of animation frames
;		CX - number of video frames between animation frame changes
; Output:
;	 	none
common_sprites_set_animation_params:
	pusha
	
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot

	mov byte [es:di+14], 0			; store current frame
	mov byte [es:di+15], bl			; store total frames
	
	mov word [es:di+16], cx			; store number of video frames 
									; per animation frame
	mov word [es:di+18], cx			; store number of video frames 
									; remaining in current animation frame
									
	call recalculate_pixel_data_pointer	; recalculate pointer based on new
										; animation frame
	popa
	ret


; Begins animation for the specified sprite
;
; Input:
;		AL - sprite number
; Output:
;	 	none	
common_sprites_animate:
	pusha
	push es
	
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	or byte [es:di+8], SPRITE_FLAG_ANIMATING
	
	pop es
	popa
	ret
	
	
; Stops animation for the specified sprite
;
; Input:
;		AL - sprite number
; Output:
;	 	none	
common_sprites_freeze_frame:
	pusha
	push es
	
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot
	mov bl, SPRITE_FLAG_ANIMATING	; BL := flag we're turning off
	xor bl, 0FFh					; flip
	and byte [es:di+8], bl			; clear bit
	
	pop es
	popa
	ret
	

; Shuts down all sprites - should be called before screen (background)
; is erased/redrawn.
; 
; Input:
;		none
; Output:
;		none	
common_sprites_shutdown:
	pusha
	call common_sprites_destroy_all
	popa
	ret
	

; Restore background rectangles from all sprites' PREVIOUS positions.
; The reason why we restore all backgrounds at once is so that a re-render 
; of a sprite with a low sprite number is not over-drawn when restoring the 
; background of a sprite with a high sprite number.
; 
; Input:
;		none
; Output:
;		none
restore_all_background_rectangles:
	pusha
	push ds
	push es
	
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov di, spritesTable			; ES:DI := beginning of sprite table
	
	test word [cs:spritesConfig], COMMON_SPRITES_CONFIG_VSYNC_ON_REFRESH
	jz restore_all_background_rectangles_start	; we're not waiting for vsync
	; wait for vsync
	call common_graphics_wait_vsync	; synchronize with vertical retrace	
	
restore_all_background_rectangles_start:	
	mov cx, COMMON_SPRITES_MAX_SPRITES
restore_all_background_rectangles_loop:			; for each sprite
	mov al, byte [es:di+8]			; AL := sprite flags
	test al, SPRITE_FLAG_ACTIVE
	jz restore_all_background_rectangles_next	; skip if not active

	; now draw rectangle
	push di

	mov dh, 0
	mov dl, byte [es:di+13]			; DX := side size
	
	mov bx, word [es:di+9]			; old X
	mov ax, word [es:di+11]			; old Y
	call common_graphics_coordinate_to_video_offset	; AX := video memory offset
	
	; here, DS = CS
	add di, SPRITES_TABLE_ENTRY_HEADER_SIZE
	mov bx, di						; DS:BX now points to background rectangle
	
	mov di, ax						; DI := offset in video memory
	mov ax, dx						; AX := height (side size), from above
									; DX = width (side size), from above
	mov si, dx						; bitmap width := side size

	call common_graphics_draw_rectangle_opaque
	pop di
restore_all_background_rectangles_next:
	add di, SPRITES_TABLE_ENTRY_SIZE	; ES:DI now points to next table entry
	
	loop restore_all_background_rectangles_loop	; next sprite
		
	pop es
	pop ds
	popa
	ret


; Gets pointer to the sprites table slot of the specified sprite
;
; Input:
;		AL - sprite number
; Output:
;	 ES:DI - pointer to sprites table slot of specified sprite
get_sprite_table_pointer:
	push ax
	push bx
	push dx
	
	push cs
	pop es					; ES := this segment

	mov ah, 0				; AX := AL
	mov bx, SPRITES_TABLE_ENTRY_SIZE
	mul bx					; DX:AX := offset
							; assumption: DX = 0 due to total number of sprites
	mov di, ax				; DI := offset into sprites table
	add di, spritesTable	; ES:DI now points to beginning of table entry
	
	pop dx
	pop bx
	pop ax
	ret


; "save" the specified sprite-sized video memory rectangle to the
; specified destination
;
; Input:
;		BX - X coordinate
;		DX - Y coordinate
;		CL - side size (sprites are square)
;	 ES:DI - pointer to destination buffer
; Output:
;		none
save_background_rectangle:
	pusha
	mov ax, dx						; Y coordinate
									; X coordinate is already in BX
	call common_graphics_coordinate_to_video_offset	; AX := video memory offset
	mov si, ax
	
	mov ah, 0
	mov al, cl						; AX := height
	
	mov dh, 0
	mov dl, cl						; DX := height
	
	call common_graphics_copy_video_rectangle_to_buffer
	popa
	ret

	
; Copies the pixels "behind" all active sprites to each sprite's 
; "background rectangle"
;
; Input:
;		none
; Output:
;		none
save_all_background_rectangles:
	pusha
	push es
	
	push cs
	pop es
	mov di, spritesTable			; ES:DI := beginning of sprite table
	
	mov cx, COMMON_SPRITES_MAX_SPRITES
save_all_background_rectangles_loop:			; for each sprite
	mov al, byte [es:di+8]			; AL := sprite flags
	test al, SPRITE_FLAG_ACTIVE
	jz save_all_background_rectangles_next	; skip if not active

	; now save rectangle
	push di							; save pointer to entry
	mov bx, word [es:di+0]			; X
	mov ax, word [es:di+2]			; Y
	call common_graphics_coordinate_to_video_offset	; AX := video memory offset
	
									; X is already in BX from above
	mov dx, word [es:di+2]			; Y
	
	push cx							; save loop index
	mov cl, byte [es:di+13]			; side size
	
	add di, SPRITES_TABLE_ENTRY_HEADER_SIZE
									; ES:DI now points to background rectangle
	call save_background_rectangle
	
	pop cx							; restore loop index
	pop di							; restore pointer to entry
save_all_background_rectangles_next:
	add di, SPRITES_TABLE_ENTRY_SIZE	; ES:DI now points to next table entry
	
	loop save_all_background_rectangles_loop	; next sprite
		
	pop es
	popa
	ret
	
	
; Draw a sprite at the specified location
;
; Input:
;		BX - X coordinate
;		DX - Y coordinate
;		CL - pixel data side size
;	 DS:SI - pointer to sprite pixel data
;		AL - sprite flags
; Output:
;		none
draw_sprite:
	pusha
	
	push ax						; [4] save sprite flags
	push si						; [1] save SI
	
	mov ch, 0					; CX := width (side size)
	push cx						; [2] save bitmap side size
	
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH
	sub ax, cx
	cmp bx, ax
	mov di, cx					; DI := bitmap side size (we're not near edge)
	jb draw_sprite_done_width	; if x >= (320-width) then width:= 320 - x
	mov di, COMMON_GRAPHICS_SCREEN_WIDTH
	sub di, bx
draw_sprite_done_width:
	; width of sprite is in CX now
	push di						; [3] save bitmap rendered width (might be
								; smaller near right edge of screen)
	; here, CX = bitmap side size, as passed in
	mov ax, COMMON_GRAPHICS_SCREEN_HEIGHT
	sub ax, cx
	cmp dx, ax
	jb draw_sprite_done_height	; if y >= (200-height) then height := 200 - y
	mov cx, COMMON_GRAPHICS_SCREEN_HEIGHT
	sub cx, dx					
draw_sprite_done_height:
	; height of sprite is in CX now
	mov ax, dx					; AX := Y coordinate
	call common_graphics_coordinate_to_video_offset	; AX := video memory offset
	mov di, ax
	pop dx						; [3] DX := rendered sprite width
	pop si						; [2] SI := bitmap side size
	
	pop bx						; [1] restore passed-in SI value
								; so that DS:BX points to sprite pixel data
	
	; now select a rectangle drawing function, based on sprite flags
	pop ax						; [4] restore sprite flags
	test al, SPRITE_FLAG_HFLIP	; is it horizontally flipped?
	jnz draw_sprite_hflipped	; yes
	; not flipped, so draw it normally
	mov ax, cx					; AX := sprite height (was saved in CX above)
	call common_graphics_draw_rectangle_transparent
	jmp draw_sprite_exit
draw_sprite_hflipped:
	; draw it horizontally flipped
	mov ax, cx					; AX := sprite height
	; advance pixel data pointer by (total_width - rendered_width), since
	; it's horizontally flipped
	add bx, si
	sub bx, dx					; BX := BX + total_width - rendered_width
	call common_graphics_draw_rectangle_hflipped_transparent
	
draw_sprite_exit:
	popa
	ret

	
; Check whether the specified sprites are colliding
;
; Input:
;		BH - first sprite number
;		BL - second sprite number
; Output:
;		AL - 0 when there is no collision, or a different value otherwise
common_sprites_check_collision:
	pusha
	push es
	push fs
	push gs

	mov al, bh						; first sprite
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot

	test byte [es:di+8], SPRITE_FLAG_ACTIVE
	jz common_sprites_check_collision_no	; not active, so no collision
	
	push word [es:di+0]			; [1] first sprite X
	push word [es:di+2]			; [2] first sprite Y
	push word [es:di+13]		; [3] first sprite side length (byte!)

	mov al, bl						; second sprite
	call get_sprite_table_pointer	; ES:DI := pointer to sprite table slot

	test byte [es:di+8], SPRITE_FLAG_ACTIVE
	jz common_sprites_check_collision_no_pop_first
								; not active, so no collision
	
	; prepare parameters for the second sprite
	mov si, word [es:di+0]			; SI := second sprite left
	mov dx, word [es:di+2]
	mov fs, dx						; FS := second sprite top
	mov dx, word [es:di+13]			; only a byte, though
	mov dh, 0						; clear MSB and only keep LSB
	mov gs, dx						; GS := second sprite height (square)
	mov di, dx						; DI := second sprite width (square)

	; prepare parameters for the first sprite (pushed previously)
	pop dx						; [3] DX := first sprite height (byte, square)
	mov dh, 0					; clear MSB and only keep LSB
	mov bx, dx					; BX := first sprite width (square)
	pop cx						; [2] CX := first sprite top
	pop ax						; [1] AX := first sprite left
	
	call common_geometry_test_rectangle_overlap_by_size	; AL := result
	cmp al, 0
	je common_sprites_check_collision_no
	
common_sprites_check_collision_yes:
	pop gs
	pop fs
	pop es
	popa
	mov al, 1
	ret

common_sprites_check_collision_no_pop_first:
	add sp, 6						; [1], [2], [3]
common_sprites_check_collision_no:
	pop gs
	pop fs
	pop es
	popa
	mov al, 0
	ret
	
	
%include "common\vga320\graphics.asm"
%include "common\geometry.asm"
	
%endif
