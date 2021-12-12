;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The SNOWMINE app.
; This is a Minesweeper-inspired game which relies on the GUI framework.
;
; The game board surface area is 75% of Minesweeper's Intermediate surface
; area. The mine density is equal to Minesweeper's Intermediate mine density,
; at 0.15625 mines per cell.
;
; I've designed it this way because I like Minesweeper's Intermediate
; difficulty, but I find the board too large.
;
; This version relies on the VGA mode 12h, 640x480, 16 colours.
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

NUM_MINES					equ 30
GRID_WIDTH					equ 16
GRID_HEIGHT					equ 12

CELL_WIDTH_PIXELS			equ 12
CELL_HEIGHT_PIXELS			equ 12
GRID_WIDTH_PIXELS			equ GRID_WIDTH * CELL_WIDTH_PIXELS
GRID_TOTAL_CELLS			equ GRID_WIDTH * GRID_HEIGHT

GRID_TOP					equ 40
GRID_LEFT					equ COMMON_GRAPHICS_SCREEN_WIDTH/2-GRID_WIDTH_PIXELS/2

titleString:				db 'Snowmine', 0
authorString:				db 'Written by Sebastian Mihai, 2018', 0
newGameString:				db 'NEW GAME', 0

NEW_GAME_BUTTON_WIDTH		equ GRID_WIDTH_PIXELS
HIDDEN_CELL_COLOUR			equ GUI__COLOUR_3

tileImageFileName:			db 'SNOWMINEBMP', 0
TILE_IMAGE_WIDTH			equ 12
TILE_IMAGE_HEIGHT			equ 108
TILE_WIDTH					equ 12
TILE_HEIGHT					equ 12

; tile indices into the BMP file
TILE_SAFE_0_ADJACENT		equ 0	; a safe cell with 0 adjacent mines
TILE_MINE_UNEXPLODED		equ 9	; a mined cell, revealed at game over
TILE_MINE_EXPLODED			equ 10	; a mined cell clicked by the user
TILE_FLAG					equ 11	; a flagged cell
TILE_FLAG_WRONG				equ 12	; an incorrectly flagged cell, revealed
									; at game over

coveredImageData:
		times CELL_WIDTH_PIXELS db GUI__COLOUR_1	; top row
		times CELL_HEIGHT_PIXELS-2 db GUI__COLOUR_1, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, HIDDEN_CELL_COLOUR, GUI__COLOUR_1
												; middle rows
		times CELL_WIDTH_PIXELS db GUI__COLOUR_1	; bottom row

GRID_ARRAY_ENTRY_SIZE			equ 3
GRID_ARRAY_LENGTH				equ GRID_WIDTH * GRID_HEIGHT
GRID_ARRAY_TOTAL_SIZE_BYTES equ GRID_ARRAY_LENGTH*GRID_ARRAY_ENTRY_SIZE ; in bytes

FLAG_MINED				equ 1	; whether cell contains a mine
FLAG_FLAGGED			equ 2	; user placed a flag on the cell
FLAG_REVEALED			equ 4	; whether cell was revealed by the user

; structure info (per array entry)
; bytes
;     0-1 image handle
;     2-2 flags
gridStorage: times GRID_ARRAY_TOTAL_SIZE_BYTES db 0

atLeastOneCellRevealed:			db 0	; used to choose when to generate mines


start:
	call common_gui_prepare					; must call this before any
											; other GUI framework functions

	; any long application initialization (e.g.: loading from disk, etc.)
	; should happen here, since the GUI framework has shown a "loading..."
	; notice
	call images_test_load_image_file		; load BMP file
	
	; set application title
	mov si, titleString						; DS:SI := pointer to title string
	call common_gui_title_set										
	
	; set up the initialized callback, which is invoked by the GUI framework
	; right after it has initialized itself
	mov si, application_initialized_callback
	call common_gui_initialized_callback_set

	mov si, on_refresh_callback
	call common_gui_on_refresh_callback_set	; we need to know when the GUI
											; framework refreshes the screen
											; so we draw our custom things
	call common_gui_start
	; control has now been yielded permanently to the GUI framework


; Generates mines in random cells, EXCEPT for in the specified cell
; The exclusion exists to ensure that the first revealed cell does not
; contain a mine.
;
; input:
;		BX - offset of grid cell excluded from the receipt of a mine
; output:
;		none
generate_mines:
	pusha

	mov cx, NUM_MINES					; we will generate this many mines
	cmp cx, 0
	je generate_mines_done				; for debugging only
generate_mines_loop:
	call get_random_cell				; AX := random cell offset

	mov si, ax
	cmp bx, si							; is it the excluded cell?
	je generate_mines_loop				; yes, so generate another one
	
	test byte [cs:gridStorage+si+2], FLAG_MINED	; is this cell already mined?
	jnz generate_mines_loop				; yes, so generate another one
	
	or byte [cs:gridStorage+si+2], FLAG_MINED	; place a mine in this cell
	
	loop generate_mines_loop			; next mine
generate_mines_done:
	popa
	ret
	

; Returns a random grid cell
;
; input:
;		none
; output:
;		AX - offset of random grid cell
get_random_cell:
	push bx
	push dx
	
	int 86h						; AX := random number
	and ax, 16383				; AX := random MOD 16384
	mov bl, GRID_TOTAL_CELLS
	div bl						; AH := 0 .. TOTAL-1
	mov al, ah
	mov bl, GRID_ARRAY_ENTRY_SIZE
	mul bl						; AX := random grid offset
	
	pop dx
	pop bx
	ret
	
	
; Initializes all cells before a new game is started
;
; input:
;		none
; output:
;		none
initialize_cells_for_new_game:
	pusha
	push ds

	mov byte [cs:atLeastOneCellRevealed], 0
	
	push cs
	pop ds
	
	mov si, gridStorage
	mov bx, 0				; offset of array slot being checked
initialize_cells_for_new_game_loop:
	pusha

	mov byte [cs:si+bx+2], 0		; mark this cell as covered
	
	; now initialize corresponding GUI image
	mov ax, word [cs:si+bx]			; AX := image handle for this cell
	mov si, coveredImageData		; DS:SI := pointer to image data
	call common_gui_image_set_data

	mov si, cell_left_clicked_callback				; might have been cleared
	call common_gui_image_left_click_callback_set	; from the previous game
													; (if it contained a flag)
	mov si, cell_right_clicked_callback
	call common_gui_image_right_click_callback_set

	call common_gui_image_enable	; might have been disabled from the
									; previous game
	popa
initialize_cells_for_new_game_next:
	add bx, GRID_ARRAY_ENTRY_SIZE				; next slot
	cmp bx, GRID_ARRAY_TOTAL_SIZE_BYTES			; are we past the end?
	jb initialize_cells_for_new_game_loop		; no
initialize_cells_for_new_game_done:
	pop ds
	popa
	ret


; Generate GUI images corresponding to cells
;
; input:
;		none
; output:
;		none
create_cell_images:
	pusha
	push ds

	push cs
	pop ds
	
	mov si, gridStorage
	mov bx, 0				; offset of array slot being checked
create_cell_images_loop:
	push bx
	push si

	mov ax, bx
	mov cl, GRID_ARRAY_ENTRY_SIZE
	div cl									; AL := index
	mov ah, 0								; AX := index
	mov cl, GRID_WIDTH
	div cl									; AL := row, AH := column
	push ax
	
	mov cl, CELL_HEIGHT_PIXELS
	mul cl									; AX := row in pixels
	add ax, GRID_TOP						; AX := position Y
	mov bx, ax								; BX := position Y
	
	pop ax									; AL := row, AH := column
	
	mov al, ah								; AL := column
	mov cl, CELL_WIDTH_PIXELS
	mul cl									; AX := column in pixels
	add ax, GRID_LEFT						; AX := position X
	
	mov si, coveredImageData				; DS:SI := pointer to image data
	mov dx, CELL_HEIGHT_PIXELS				; height
	mov cx, CELL_WIDTH_PIXELS				; width
	mov di, CELL_WIDTH_PIXELS				; canvas width
	call common_gui_image_add				; AX := handle
	
	mov si, cell_left_clicked_callback
	call common_gui_image_left_click_callback_set
	
	mov si, cell_right_clicked_callback
	call common_gui_image_right_click_callback_set
	
	mov bx, 0										; configure image to not
	call common_gui_image_set_show_selected_mark	; change when selected
	
	pop si
	pop bx
	
	mov word [cs:si+bx], ax					; store image handle for this cell
	
create_cell_images_next:
	add bx, GRID_ARRAY_ENTRY_SIZE	; next slot
	cmp bx, GRID_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb create_cell_images_loop			; no
create_cell_images_done:
	pop ds
	popa
	ret

	
; Shows the positions of all mines on the grid
;
; input:
;		none
; output:
;		none
show_all_mines:
	pusha

	mov cx, 0						; reveal for the "game over" case
	mov bx, 0						; offset of array slot being checked
show_all_mines_loop:
	call reveal_cell
	
	add bx, GRID_ARRAY_ENTRY_SIZE	; next slot
	cmp bx, GRID_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb show_all_mines_loop			; no
show_all_mines_done:
	popa
	ret

	
; Sets the image of the specified cell according to its status
;
; input:
;		BX - offset of grid cell
;		CX - 0 when we're only revealing mines and incorrect flags (game over)
;			 other value otherwise (revealing during normal game play)
; output:
;		none
reveal_cell:
	pusha
	push ds
	
	push cs
	pop ds
	
	mov ax, word [cs:gridStorage+bx]	; AX := image handle
	call common_gui_image_disable
										
	; case 1: this cell has a mine which has been clicked
	mov dl, byte [cs:gridStorage+bx+2]
	and dl, FLAG_MINED | FLAG_REVEALED
	cmp dl, FLAG_MINED | FLAG_REVEALED	; user has just clicked this cell
	je reveal_cell_exploded_mine		; and it exploded
	
	; case 2: this cell has an unexploded mine
	test byte [cs:gridStorage+bx+2], FLAG_MINED
	jnz reveal_cell_unexploded_mine
	
	; case 3: this cell is flagged and has no mine
	test byte [cs:gridStorage+bx+2], FLAG_FLAGGED
	jnz reveal_cell_flagged_not_mined
	
	cmp cx, 0							; are we only revealing mines and
										; incorrect flags?
	je reveal_cell_done					; yes, so no further cases apply
	
	; case 4: this cell is not flagged and does not contain a mine
	call count_adjacent_mines			; CX := adjacent mine count
	add cx, TILE_SAFE_0_ADJACENT		; index tile
	call get_tile_data_pointer			; DS:SI := pointer to tile data
	call common_gui_image_set_data
	jmp reveal_cell_done
	
reveal_cell_flagged_not_mined:
	; cell has flag, but has no mine
	cmp cx, 0							; are we only revealing mines and
										; incorrect flags?
	jne reveal_cell_done				; no, so do nothing
	; reveal it
	mov cx, TILE_FLAG_WRONG				; tile
	call get_tile_data_pointer			; DS:SI := pointer to tile data
	call common_gui_image_set_data
	jmp reveal_cell_done
	
reveal_cell_unexploded_mine:
	; unexploded mine (revealed only at game over)
	test byte [cs:gridStorage+bx+2], FLAG_FLAGGED	; flagged correctly?
	jnz reveal_cell_done				; yes, so do nothing
	; it's not flagged, so reveal the mine
	mov cx, TILE_MINE_UNEXPLODED		; tile
	call get_tile_data_pointer			; DS:SI := pointer to tile data
	call common_gui_image_set_data
	jmp reveal_cell_done
	
reveal_cell_exploded_mine:
	; exploded mine
	mov cx, TILE_MINE_EXPLODED					; tile
	call get_tile_data_pointer					; DS:SI := pointer to tile data
	call common_gui_image_set_data
	jmp reveal_cell_done

reveal_cell_done:
	; mark as revealed
	or byte [cs:gridStorage+bx+2], FLAG_REVEALED
	
	pop ds
	popa
	ret

	
; Gets the offset of the grid cell which owns the specified image
;
; input:
;		AX - image handle to search
; output:
;		BX - offset of grid cell which owns the specified image
grid_get_offset_by_image_handle:
	mov bx, 0				; offset of array slot being checked
grid_get_offset_by_image_handle_loop:
	cmp word [cs:gridStorage+bx], ax
	je grid_get_offset_by_image_handle_done

	add bx, GRID_ARRAY_ENTRY_SIZE		; next slot
	cmp bx, GRID_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb grid_get_offset_by_image_handle_loop			; no
grid_get_offset_by_image_handle_done:
	ret

	
; Returns the row and column of the specified grid cell
;
; input:
;		BX - offset of grid cell
; output:
;		AL - row
;		AH - column
get_coords_by_offset:
	push bx

	mov ax, bx
	mov bl, GRID_ARRAY_ENTRY_SIZE
	div bl					; AL := index, AH := 0
	
	mov bl, GRID_WIDTH
	div bl					; AL := row, AH := column
	
	pop bx
	ret


; Returns the offset of the specified grid cell
;
; input:
;		AL - row
;		AH - column
; output:
;		BX - offset of grid cell
get_offset_by_coords:
	push ax
	push cx
	push dx
	
	movzx cx, ah			; CX := column
	
	mov bl, GRID_WIDTH
	mul bl					; AX := row * width
	add ax, cx				; AX := row * width + column
							; (that is, AX := index)
	mov cx, GRID_ARRAY_ENTRY_SIZE
	mul cx					; DX:AX := offset
							; but, DX = 0, so AX := offset
	
	mov bx, ax				; return offset in BX
	
	pop dx
	pop cx
	pop ax
	ret


; Counts the mines in the specified grid cell
; If an invalid grid cell was specified (co-ordinates out of bounds), returns 0
;
; input:
;		AL - row
;		AH - column
; output:
;		DX - mine count of specified grid cell (either 0 or 1)
;	 CARRY - clear when grid cell was valid (within grid bounds)
;			 set otherwise
get_mine_count_at_coords:
	stc									; default validity result: invalid
	mov dx, 0							; default mine count for invalid
										; cells (outside grid bounds)

	cmp ah, GRID_WIDTH					; if the cell passed in was either to
										; the left or right of grid, it'll be
										; seen as either 0FFh or GRID_WIDTH by
										; this unsigned comparison, making it
										; sufficient for both overflow cases
	jae get_mine_count_at_coords_done	; we have horizontal overflow
	
	cmp al, GRID_HEIGHT					; same reasoning as above
	jae get_mine_count_at_coords_done	; we have vertical overflow

	; there is no overflow - this is an actual grid cell
	call get_offset_by_coords					; BX := offset
	test byte [cs:gridStorage+bx+2], FLAG_MINED	; [1] check flag
	clc									; validity result: valid
	jz get_mine_count_at_coords_done	; [1] not mined, so default value stays
	; it's mined
	mov dx, 1							; one mine
get_mine_count_at_coords_done:
	ret


; Counts the mines around the specified grid cell
;
; input:
;		BX - offset of grid cell
; output:
;		CX - adjacent mine count
count_adjacent_mines:
	push ax
	push bx
	push dx
	
	call get_coords_by_offset		; AL := row, AH := column
	
	mov cx, 0						; mine count accumulator
	
	dec al							; top
	call get_mine_count_at_coords
	add cx, dx
	
	inc ah							; top-right
	call get_mine_count_at_coords
	add cx, dx
	
	inc al							; right
	call get_mine_count_at_coords
	add cx, dx
	
	inc al							; bottom-right
	call get_mine_count_at_coords
	add cx, dx
	
	dec ah							; bottom
	call get_mine_count_at_coords
	add cx, dx
	
	dec ah							; bottom-left
	call get_mine_count_at_coords
	add cx, dx
	
	dec al							; left
	call get_mine_count_at_coords
	add cx, dx
	
	dec al							; top-left
	call get_mine_count_at_coords
	add cx, dx
	
	pop dx
	pop bx
	pop ax
	ret


; Checks and handles whether the player won.
; Victory is achieved by having an equal number of mines and hidden cells.
;
; input:
;		none
; output:
;		none
check_victory:
	pusha

	mov cx, 0						; counts hidden cells
	mov bx, 0						; offset of array slot being checked
check_victory_loop:
	test byte [cs:gridStorage+bx+2], FLAG_REVEALED
	jnz check_victory_loop_next		; this cell is not hidden
	inc cx							; this cell is hidden
check_victory_loop_next:
	add bx, GRID_ARRAY_ENTRY_SIZE	; next slot
	cmp bx, GRID_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb check_victory_loop			; no

	; now compare
	cmp cx, NUM_MINES
	jne check_victory_done			; no victory
	
	; we have victory, so place flags on all mines and disable cells
	mov bx, 0							; offset of array slot being checked
check_victory_flag_loop:
	test byte [cs:gridStorage+bx+2], FLAG_MINED
	jz check_victory_flag_loop_next		; not mined, so we don't flag it
	; it's mined, so we flag it
	or byte [cs:gridStorage+bx+2], FLAG_FLAGGED | FLAG_REVEALED	; flag it
	; change its image and disable it
	mov ax, word [cs:gridStorage+bx]	; AX := image handle
	call common_gui_image_disable
	mov cx, TILE_FLAG					; tile
	call get_tile_data_pointer			; DS:SI := pointer to tile data
	call common_gui_image_set_data
	
check_victory_flag_loop_next:
	add bx, GRID_ARRAY_ENTRY_SIZE		; next slot
	cmp bx, GRID_ARRAY_TOTAL_SIZE_BYTES	; are we past the end?
	jb check_victory_flag_loop			; no

check_victory_done:	
	popa
	ret
	

; Writes the author string
;
; input:
;		none
; output:
;		none
write_author_string:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	mov si, authorString

	mov ax, COMMON_GRAPHICS_SCREEN_HEIGHT - COMMON_GRAPHICS_FONT_HEIGHT - 5	; position Y
	
	call common_gui_get_colour_foreground	; CH := 0, CL := colour
	mov dx, 2							; options - "center text"
	call common_graphics_text_print_at
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
	pop ds
	popa
	ret	


; Callback for GUI framework's "on refresh". This will redraw anything custom
; we have to draw.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none	
on_refresh_callback:
	call write_author_string
	retf
	

; Handles the case when the user clicked a safe cell
;
; input:
;		BX - offset of grid cell that was clicked
; output:
;		none
handle_safe_click:
	pusha

	call auto_reveal_many
	call check_victory
	
	popa
	ret


; Handles the case when the user clicked a mined cell
;
; input:
;		none
; output:
;		none
handle_game_over:
	pusha
	
	call show_all_mines
	
	popa
	ret


; Starting from the specified cell reveal neighbouring cells progressively,
; revealing all connected zero-adjacent mines cells, as well as a border of
; one or more adjacent mine cells.
;
; input:
;		BX - offset of grid cell serving as the starting point
; output:
;		none
auto_reveal_many:
	pusha
	
	; enqueue starting cell, to get the iterations started
	mov dl, bl								; DL := LSB of cell offset
	call common_queue_enqueue
	mov dl, bh								; DL := MSB of cell offset
	call common_queue_enqueue				; enqueue cell offset (word)
	
auto_reveal_many_check_queue:
	; we're done when the queue is empty
	call common_queue_get_length
	cmp ax, 0
	je auto_reveal_many_done				; queue is empty, so we're done
	
	; queue still has cells, so we continue dequeueing
	call common_queue_dequeue				; DL := LSB of cell offset
	mov bl, dl
	call common_queue_dequeue				; DL := MSB of cell offset
	mov bh, dl								; BX := cell offset
	
	; process the cell we've just dequeued
	; here, BX = cell offset

	mov cx, 1								; reveal for normal game play
	call reveal_cell						; reveal this cell
	
	call count_adjacent_mines				; CX := adjacent mine count
	cmp cx, 0
	ja auto_reveal_many_check_queue			; this cell has more than zero
											; adjacent mines, so we don't
											; consider its neighbours
	
	call get_coords_by_offset				; AL := row, AH := column

	; consider neighbours
	dec al							; top
	call try_enqueue_cell
	
	inc ah							; top-right
	call try_enqueue_cell
	
	inc al							; right
	call try_enqueue_cell
	
	inc al							; bottom-right
	call try_enqueue_cell
	
	dec ah							; bottom
	call try_enqueue_cell
	
	dec ah							; bottom-left
	call try_enqueue_cell
	
	dec al							; left
	call try_enqueue_cell
	
	dec al							; top-left
	call try_enqueue_cell

	jmp auto_reveal_many_check_queue	; check queue again
auto_reveal_many_done:
	popa
	ret

	
; Helper for auto-revealing zero-adjacent mine cells.
; When the specified coordinates represent a valid, hidden,
; non-mined grid cell, the cell's offset is enqueued.
;
; input:
;		AL - row
;		AH - column
; output:
;		none
try_enqueue_cell:
	pusha
	cmp ah, GRID_WIDTH					; if the cell passed in was either to
										; the left or right of grid, it'll be
										; seen as either 0FFh or GRID_WIDTH by
										; this unsigned comparison, making it
										; sufficient for both overflow cases
	jae try_enqueue_cell_done			; we have horizontal overflow
	
	cmp al, GRID_HEIGHT					; same reasoning as above
	jae try_enqueue_cell_done			; we have vertical overflow

	; there is no overflow - this is an actual grid cell
	call get_offset_by_coords			; BX := offset
	test byte [cs:gridStorage+bx+2], FLAG_REVEALED | FLAG_MINED
	jnz try_enqueue_cell_done			; already revealed or mined
	
	; enqueue it
	mov dl, bl							; DL := LSB of cell offset
	call common_queue_enqueue
	mov dl, bh							; DL := MSB of cell offset
	call common_queue_enqueue			; enqueue cell offset (word)
try_enqueue_cell_done:
	popa
	ret
	
	
; Loads the bitmap file into memory
;
; input:
;		none
; output:
;		none
images_test_load_image_file:
	pusha
	push ds
	push es
	
	push cs
	pop ds
	mov si, tileImageFileName		; DS:SI now points to file name
	push cs
	pop es
	mov di, tileImageDataBuffer	; ES:DI now points to where we'll load file
	call common_bmp_load		; load file: AL = 0 when successful
								; CX = file size in bytes
								
	pop es
	pop ds
	popa
	ret
	

; Returns a pointer to the beginning of tile data for the specified
; tile index, from within the tile image
;
; input:
;		CX - tile index (in the tile image)
; output:
;	 DS:SI - pointer to beginning of tile data
get_tile_data_pointer:
	push ax
	push bx
	push cx
	push dx
	push di

	mov ax, TILE_WIDTH * TILE_HEIGHT
	mul cx								; DX:AX := offset
										; assume DX = 0, so AX = offset
	
	mov si, tileImageDataBuffer			; DS:SI := pointer to BMP
	call common_bmp_get_pixel_data_pointer	; DS:DI := pointer to pixel data
	mov si, di								; DS:SI := pointer to pixel data

	add si, ax							; DS:SI := pointer to specified tile
	
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret


;------------------------------------------------------------------------------
;
; Callbacks
; (GUI callbacks do not need to preserve any registers)
;
;------------------------------------------------------------------------------

; Invoked when a grid cell is left clicked
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
cell_left_clicked_callback:
	push ax
	
	cmp byte [cs:atLeastOneCellRevealed], 0	; is this the first clicked cell?
	jne cell_left_clicked_callback_perform	; no
	
	; this is the first clicked cell, so we will generate all mines	
	call grid_get_offset_by_image_handle	; BX := clicked grid cell offset
	call generate_mines						; generate all mines

	mov byte [cs:atLeastOneCellRevealed], 1	; we have clicked our first cell
	; mines have been generated, we can now proceed with processing the click

cell_left_clicked_callback_perform:
	pop ax									; restore image handle
	
	push cs
	pop ds
	
	call grid_get_offset_by_image_handle	; BX := clicked cell grid offset
	or byte [cs:gridStorage+bx+2], FLAG_REVEALED	; flag as revealed
	
	test byte [cs:gridStorage+bx+2], FLAG_MINED	; is it mined?
	jz cell_left_clicked_callback_safe		; no
	
	; it's mined, so it's game over
	call handle_game_over

	jmp cell_left_clicked_callback_done
cell_left_clicked_callback_safe:
	; it's safe
	call handle_safe_click
cell_left_clicked_callback_done:
	retf
	
	
; Invoked when a grid cell is right clicked
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
cell_right_clicked_callback:
	call grid_get_offset_by_image_handle	; BX := clicked cell grid offset
	xor byte [cs:gridStorage+bx+2], FLAG_FLAGGED	; toggle "flagged" flag
	
	; update image data accordingly
	push cs
	pop ds
	test byte [cs:gridStorage+bx+2], FLAG_FLAGGED
	jz cell_right_clicked_callback_not_flagged
	
cell_right_clicked_callback_flagged:
	; image has become flagged
	
	; clear left click callback, to prevent left-clicking on flagged cells
	call common_gui_image_left_click_callback_clear

	mov cx, TILE_FLAG							; tile
	call get_tile_data_pointer					; DS:SI := pointer to tile data
	jmp cell_right_clicked_callback_set_image
cell_right_clicked_callback_not_flagged:
	; image has become unflagged
	
	; set left click callback, to allow left-clicking again
	mov si, cell_left_clicked_callback
	call common_gui_image_left_click_callback_set
	mov si, coveredImageData			; DS:SI := pointer to image data
cell_right_clicked_callback_set_image:
	call common_gui_image_set_data
	retf


; Invoked when the "New Game" button is clicked
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - button handle
; output:
;		none
new_game_button_callback:
	call initialize_cells_for_new_game
	retf
	

; Invoked right after GUI framework has finished initializing.
; Meant for applications to add initial UI components.
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - button handle
; output:
;		none
application_initialized_callback:
	push cs
	pop ds

	; create "new game" button
	mov si, newGameString
	mov ax, COMMON_GRAPHICS_SCREEN_WIDTH/2 - NEW_GAME_BUTTON_WIDTH/2	; X
	mov bx, GRID_TOP - COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE - 8 ; position Y
	mov dx, COMMON_GUI_BUTTON_HEIGHT_SINGLE_LINE	; height
	mov cx, NEW_GAME_BUTTON_WIDTH
	call common_gui_button_add						; AX := button handle
	mov si, new_game_button_callback
	call common_gui_button_click_callback_set

	; create GUI images corresponding to each cell
	call create_cell_images
	
	; and finally, start a new game
	call initialize_cells_for_new_game
	retf


;------------------------------------------------------------------------------
;
; Includes and tile image buffer (where we load the BMP)
;
;------------------------------------------------------------------------------

; we need many images, so we must configure the GUI framework accordingly
	
%ifndef _COMMON_GUI_CONF_COMPONENT_LIMITS_
%define _COMMON_GUI_CONF_COMPONENT_LIMITS_
GUI_RADIO_LIMIT 		equ 0	; maximum number of radio available
GUI_IMAGES_LIMIT 		equ GRID_WIDTH*GRID_HEIGHT
								; maximum number of images available
GUI_CHECKBOXES_LIMIT 	equ 0	; maximum number of checkboxes available
GUI_BUTTONS_LIMIT 		equ 2	; maximum number of buttons available
%endif

; we need a larger queue, so override its default size
;
%ifndef _COMMON_QUEUE_CONF_
%define _COMMON_QUEUE_CONF_
QUEUE_LENGTH equ 4096			; queue size in bytes
%endif
%include "common\queue.asm"

%include "common\vga640\gui\gui.asm"
%include "common\gra_font.asm"
%include "common\vga640\gra_text.asm"
%include "common\bmp.asm"

tileImageDataBuffer:			; this is where we load the BMP file
								; which contains all graphics
