;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The HANGMAN app.
; This is a version of the well-known word guessing game with the same name.
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

MAX_STACK			equ 1000

titleString:		db 'Hangman', 0

WORD_X				equ 110
WORD_Y				equ 290
wordLabel:			db 'Word:', 0
wordRealLabel:		db 'Answer:', 0

MAN_X				equ 425
MAN_Y				equ 80
MAN_HEAD_SIDE_LENGTH	equ 50
MAN_NECK_LENGTH:		equ 25
MAN_SHOULDER_LENGTH:	equ 80
MAN_ARM_LENGTH			equ 60
MAN_BODY_LENGTH			equ 90
MAN_WAIST_LENGTH		equ 60
MAN_LEG_LENGTH			equ 120

GALLOWS_ROPE_LENGTH		equ 25
GALLOWS_TOP_LENGTH		equ 150
GALLOWS_HEIGHT			equ 350
GALLOWS_BOTTOM_LENGTH	equ 300

GUESS_X			equ 110
GUESS_Y			equ 160
guessLabel:		db 'Your guess:', 0
GUESS_OFFSET	equ 24

guessButton:		db 'Guess', 0
guessButtonHandle:	dw 0

stepInitial:		db 'Starting HANGMAN', 13, 10, 0
stepInitDynMem:		db 'Initialized dynamic memory', 13, 10, 0
errorNoMemory:		db 'Failed to initialize dynamic memory, or not enough memory available', 13, 10, 0
errorPressAKey:		db 'Press a key to exit', 13, 10, 0

emptyString:		db 0

isGameStarted:		db 0
isGameOver:			db 0
isWon:				db 0;

categorySelectLabel:	db 'Select category:', 0

CATEGORY_RADIO_GROUP	equ 0
CATEGORY_RADIO_X		equ 270
CATEGORY_RADIO_TOP		equ 200
CATEGORY_RADIO_Y_GAP	equ 14

categoryFruitLabel:		db 'Fruit', 0
categoryFruit:			dw 0
categoryDessertsLabel:	db 'Desserts', 0
categoryDesserts:		dw 0
categoryAnimalsLabel:	db 'Animals', 0
categoryAnimals:		dw 0

startButton:			db 'Start', 0

category:				db 0

CATEGORY_FRUIT			equ 0
CATEGORY_DESSERTS		equ 1
CATEGORY_ANIMALS		equ 2

mistakes:				db 0
MAX_MISTAKES			equ 6

; first two bytes store handle of respective letter
letters:
letterA:	db 0, 0, 'A', 0
letterB:	db 0, 0, 'B', 0
letterC:	db 0, 0, 'C', 0
letterD:	db 0, 0, 'D', 0
letterE:	db 0, 0, 'E', 0
letterF:	db 0, 0, 'F', 0
letterG:	db 0, 0, 'G', 0
letterH:	db 0, 0, 'H', 0
letterI:	db 0, 0, 'I', 0
letterJ:	db 0, 0, 'J', 0
letterK:	db 0, 0, 'K', 0
letterL:	db 0, 0, 'L', 0
letterM:	db 0, 0, 'M', 0
letterN:	db 0, 0, 'N', 0
letterO:	db 0, 0, 'O', 0
letterP:	db 0, 0, 'P', 0
letterQ:	db 0, 0, 'Q', 0
letterR:	db 0, 0, 'R', 0
letterS:	db 0, 0, 'S', 0
letterT:	db 0, 0, 'T', 0
letterU:	db 0, 0, 'U', 0
letterV:	db 0, 0, 'V', 0
letterW:	db 0, 0, 'W', 0
letterX:	db 0, 0, 'X', 0
letterY:	db 0, 0, 'Y', 0
letterZ:	db 0, 0, 'Z', 0
LETTER_ENTRY_SIZE		equ 4

HIDDEN_CHAR			equ '_'
CURRENT_WORD_BUFFER_SIZE	equ 64
wordToGuessOffset:	dw 0
currentWord:		times CURRENT_WORD_BUFFER_SIZE db HIDDEN_CHAR
					db 0				; terminator
victoryMessage:		db 'Congratulations!', 0
lossMessage:		db 'You lose!', 0

backToMenuButton:	db 'Play Again', 0
BACK_BUTTON_X		equ 270
BACK_BUTTON_Y		equ 350

fPinapple:		db 'PINEAPPLE', 0
fApple:			db 'APPLE', 0
fPear:			db 'PEAR', 0
fCantaloupe:	db 'CANTALOUPE', 0
fMango:			db 'MANGO', 0
fPapaya:		db 'PAPAYA', 0
fAvocado:		db 'AVOCADO', 0
fBlueberry:		db 'BLUEBERRY', 0
fStrawberry:	db 'STRAWBERRY', 0
fRaspberry:		db 'RASPBERRY', 0
fBlackberry:	db 'BLACKBERRY', 0
fBanana:		db 'BANANA', 0
fWatermelon:	db 'WATERMELON', 0
fOrange:		db 'ORANGE', 0
fLemon:			db 'LEMON', 0
fKiwi:			db 'KIWI', 0
fPeach:			db 'PEACH', 0

fruits:	dw fPinapple, fApple, fPear, fCantaloupe, fMango, fPapaya
		dw fAvocado, fBlueberry, fStrawberry, fRaspberry, fBlackberry
		dw fBanana, fWatermelon, fOrange, fLemon, fKiwi, fPeach
fruitsEnd:

dCupcake		db 'CUPCAKE', 0
dCookie			db 'COOKIE', 0
dTurnover		db 'TURNOVER', 0
dCake			db 'CAKE', 0
dPie			db 'PIE', 0
dIcecream		db 'ICECREAM', 0
dChocolate		db 'CHOCOLATE', 0
dPancake		db 'PANCAKE', 0
dDonut			db 'DONUT', 0
dCandy			db 'CANDY', 0

desserts:	dw dCupcake, dCookie, dTurnover, dCake, dPie, dIcecream
			dw dChocolate, dPancake, dDonut, dCandy
dessertsEnd:

aBear:			db 'BEAR', 0
aRabbit:		db 'RABBIT', 0
aSquirrel:		db 'SQUIRREL', 0
aPig:			db 'PIG', 0
aChipmunk:		db 'CHIPMUNK', 0
aCow:			db 'COW', 0
aFox:			db 'FOX', 0
aDog:			db 'DOG', 0
aCat:			db 'CAT', 0
aAlligator:		db 'ALLIGATOR', 0
aFlamingo:		db 'FLAMINGO', 0
aRaccoon:		db 'RACCOON', 0
aKangaroo:		db 'KANGAROO', 0
aMoose:			db 'MOOSE', 0

animals:	dw aBear, aRabbit, aSquirrel, aPig, aChipmunk, aCow, aFox, aDog
			dw aCat, aAlligator, aFlamingo, aRaccoon, aKangaroo, aMoose
animalsEnd:


start:
	mov si, stepInitial
	int 80h
	
	call common_gui_prepare					; must call this before any
											; other GUI framework functions
	
	; any long application initialization (e.g.: loading from disk, etc.)
	; should happen here, since the GUI framework has shown a "loading..."
	; notice
	
	; set application title
	mov si, titleString						; DS:SI := pointer to title string
	call common_gui_title_set										
	
	; set up the initialized callback, which is invoked by the GUI framework
	; right after it has initialized itself
	mov si, initialized_callback
	call common_gui_initialized_callback_set
	
	mov si, on_refresh_callback
	call common_gui_on_refresh_callback_set	; we need to know when the GUI
											; framework refreshes the screen
											; so we draw our custom things
											
	; yield control permanently to the GUI framework
	call common_gui_start
	; the function above does not return control to the caller


; Draws the hang man on the screen
;
; input:
;		none
; output:
;		none
draw_man:
	pusha
	push ds
	
	call common_gui_draw_begin			; tell GUI framework that we are
										; about to draw on the screen
	push cs
	pop ds
	
	call common_gui_get_colour_foreground
	mov dx, cx							; DX := colour
	
	; gallows rope
	mov bx, MAN_X + MAN_HEAD_SIDE_LENGTH/2
	mov ax, MAN_Y - GALLOWS_ROPE_LENGTH
	mov cx, GALLOWS_ROPE_LENGTH
	call common_graphics_draw_vertical_line_solid_by_coords
	
	; gallows top
	sub bx, GALLOWS_TOP_LENGTH / 2
	mov cx, GALLOWS_TOP_LENGTH
	call common_graphics_draw_line_solid
	
	; gallows vertical
	add bx, GALLOWS_TOP_LENGTH
	mov cx, GALLOWS_HEIGHT
	call common_graphics_draw_vertical_line_solid_by_coords

	; gallows bottom
	add ax, GALLOWS_HEIGHT
	sub bx, GALLOWS_BOTTOM_LENGTH*2/3
	mov cx, GALLOWS_BOTTOM_LENGTH
	call common_graphics_draw_line_solid
	
	cmp byte [cs:mistakes], 1
	jb draw_man_done
	
	; head
	mov bx, MAN_X
	mov ax, MAN_Y
	mov cx, MAN_HEAD_SIDE_LENGTH
	mov si, MAN_HEAD_SIDE_LENGTH
	call common_graphics_draw_rectangle_outline_by_coords
	
	cmp byte [cs:mistakes], 2
	jb draw_man_done
	
	; neck
	pusha
	mov cx, MAN_NECK_LENGTH
	add bx, MAN_HEAD_SIDE_LENGTH / 2
	add ax, MAN_HEAD_SIDE_LENGTH
	call common_graphics_draw_vertical_line_solid_by_coords
	popa
	
	cmp byte [cs:mistakes], 3
	jb draw_man_done
	
	; shoulders
	add ax, MAN_HEAD_SIDE_LENGTH + MAN_NECK_LENGTH
	sub bx, (MAN_SHOULDER_LENGTH-MAN_HEAD_SIDE_LENGTH)/2
	mov cx, MAN_SHOULDER_LENGTH
	call common_graphics_draw_line_solid
	
	cmp byte [cs:mistakes], 4
	jb draw_man_done
	
	; left arm
	mov cx, MAN_ARM_LENGTH
	call common_graphics_draw_vertical_line_solid_by_coords
	
	; right arm
	add bx, MAN_SHOULDER_LENGTH
	call common_graphics_draw_vertical_line_solid_by_coords
	
	cmp byte [cs:mistakes], 5
	jb draw_man_done
	
	; body
	sub bx, MAN_SHOULDER_LENGTH/2
	mov cx, MAN_BODY_LENGTH
	call common_graphics_draw_vertical_line_solid_by_coords

	cmp byte [cs:mistakes], 6
	jb draw_man_done
	
	; waist
	add ax, MAN_BODY_LENGTH
	sub bx, MAN_WAIST_LENGTH/2
	mov cx, MAN_WAIST_LENGTH
	call common_graphics_draw_line_solid
	
	cmp byte [cs:mistakes], 7
	jb draw_man_done
	
	; left leg
	mov cx, MAN_LEG_LENGTH
	call common_graphics_draw_vertical_line_solid_by_coords
	
	; right leg
	add bx, MAN_WAIST_LENGTH
	call common_graphics_draw_vertical_line_solid_by_coords
	
	call common_gui_draw_end			; tell GUI framework that 
										; we finished drawing
draw_man_done:
	pop ds
	popa
	ret
	

; Returns a pointer to a letter entry, by handle
;
; input:
;		AX - handle
; output:
;		SI - near pointer to letter entry
lookup_letter_pointer:
	push cx
	
	mov si, letters
	mov cx, 26
lookup_letter_pointer_loop:
	cmp word [cs:si], ax
	je lookup_letter_pointer_done
	add si, LETTER_ENTRY_SIZE
	loop lookup_letter_pointer_loop
lookup_letter_pointer_done:
	pop cx
	ret
	

; Writes the current word to screen
;
; input:
;		none
; output:
;		none	
draw_word:
	push ds
	pusha
	
	push cs
	pop ds
	mov si, currentWord
	
	mov bx, WORD_X
	mov ax, WORD_Y
	call common_gui_util_print_single_line_text_with_erase
	
	popa
	pop ds
	ret


; Checks whether the player has won
;
; input:
;		none
; output:
;		AX - 0 when not a win yet, other value otherwise
check_win:
	push si
	
	mov si, currentWord
check_win_loop:
	cmp byte [cs:si], 0
	je check_win_yes				; we reached the end, so it's a win
	cmp byte [cs:si], HIDDEN_CHAR
	je check_win_no					; still contains HIDDEN characters
	inc si
	jmp check_win_loop				; next char
check_win_yes:
	pop si
	mov ax, 1
	ret
check_win_no:	
	pop si
	mov ax, 0
	ret
	

; Create the necessary entities to drive the game menu
;
; input:
;		none
; output:
;		none
create_menu:
	push ds
	pusha
	pushf
	
	push cs
	pop ds

	mov byte [cs:mistakes], 0
	mov byte [cs:isGameOver], 0
	mov byte [cs:isGameStarted], 0
	
	; clear current word buffer
	push cs
	pop es
	mov di, currentWord
	mov cx, CURRENT_WORD_BUFFER_SIZE
	mov al, HIDDEN_CHAR
	cld
	rep stosb
	
	; category selection
	mov bx, CATEGORY_RADIO_TOP
	
	mov di, CATEGORY_RADIO_GROUP					; group
	mov ax, CATEGORY_RADIO_X
	add bx, CATEGORY_RADIO_Y_GAP					; position Y
	mov si, categoryFruitLabel
	call common_gui_radio_add_auto_scaled			; AX := handle
	mov word [cs:categoryFruit], ax
	push bx
	mov bx, 1
	call common_gui_radio_set_checked
	pop bx
	
	mov di, CATEGORY_RADIO_GROUP					; group
	mov ax, CATEGORY_RADIO_X
	add bx, CATEGORY_RADIO_Y_GAP					; position Y
	mov si, categoryDessertsLabel
	call common_gui_radio_add_auto_scaled			; AX := handle
	mov word [cs:categoryDesserts], ax
	
	mov di, CATEGORY_RADIO_GROUP					; group
	mov ax, CATEGORY_RADIO_X
	add bx, CATEGORY_RADIO_Y_GAP					; position Y
	mov si, categoryAnimalsLabel
	call common_gui_radio_add_auto_scaled			; AX := handle
	mov word [cs:categoryAnimals], ax
	
	; "start" button
	mov si, startButton
	mov ax, CATEGORY_RADIO_X
	add bx, CATEGORY_RADIO_Y_GAP + 4				; position Y
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov si, start_click_callback
	call common_gui_button_click_callback_set
	
	popf
	popa
	pop ds
	ret


; Create the button that will take the user back to the menu
;
; input:
;		none
; output:
;		none	
add_back_to_menu_button:
	pusha
	push ds
	
	mov si, backToMenuButton
	mov ax, BACK_BUTTON_X
	mov bx, BACK_BUTTON_Y
	call common_gui_button_add_auto_scaled			; AX := button handle
	mov si, initialized_callback
	call common_gui_button_click_callback_set
	
	pop ds
	popa
	ret
	

; Picks a word, given the selected category in cs:category
;
; input:
;		none
; output:
;		fills in [cs:wordToGuessOffset]
;		fills in [cs:currentWord]
pick_word:
	pusha
	pushf
	push ds
	push es
	
	mov si, fruits
	mov bx, (fruitsEnd - fruits)/2		; each pointer is 2 bytes
	cmp byte [cs:category], CATEGORY_FRUIT
	je pick_word_generate
	
	mov si, animals
	mov bx, (animalsEnd - animals)/2		; each pointer is 2 bytes
	cmp byte [cs:category], CATEGORY_ANIMALS
	je pick_word_generate
	
	mov si, desserts
	mov bx, (dessertsEnd - desserts)/2		; each pointer is 2 bytes

pick_word_generate:
	; here, BX = number of choices in the current category
	; here, CS:SI = pointer to first pointer to word in category
	int 86h						; AX := random
	mov dx, 0					; DX:AX := random
	div bx						; DX := random % (number of words in category)
	shl dx, 1					; each pointer is 2 bytes
	add si, dx					; CS:SI := ptr to ptr to picked word
	
	mov si, word [cs:si]		; SI := offset of picked word
	mov word [cs:wordToGuessOffset], si	; save it
	
	push cs
	pop es
	mov di, currentWord
	mov cx, CURRENT_WORD_BUFFER_SIZE
	mov al, HIDDEN_CHAR
	cld
	rep stosb					; populate current word
	
	pop es
	pop ds
	popf
	popa
	ret


;==============================================================================
; Callbacks
;==============================================================================

; Called by the GUI framework after it has initialized itself
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		none
; output:
;		none
initialized_callback:
	call common_gui_clear_all
	call create_menu
	retf
	

; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
start_click_callback:
	push cs
	pop ds
	
	mov byte [cs:category], CATEGORY_FRUIT	; assume
	mov ax, word [cs:categoryFruit]
	call common_gui_radio_get_checked
	cmp bx, 0
	jne start_click_callback__got_category

	mov byte [cs:category], CATEGORY_DESSERTS	; assume
	mov ax, word [cs:categoryDesserts]
	call common_gui_radio_get_checked
	cmp bx, 0
	jne start_click_callback__got_category
	
	mov byte [cs:category], CATEGORY_ANIMALS
start_click_callback__got_category:
	call pick_word								; fills in
												;     wordToGuessOffset
												;     currentWord
	mov byte [cs:isGameStarted], 1
	; clear all and set up game controls
	call common_gui_clear_all
	
	; terminate guess buffer after as many letters as the word to guess
	mov si, word [cs:wordToGuessOffset]			; DS:SI := ptr to word
	int 0A5h									; BX := string length
	mov byte [cs:currentWord+bx], 0

	mov si, letterA + 2
	mov ax, GUESS_X
	mov bx, GUESS_Y
	mov cx, 26									; this many letters
start_click_callback__guess_buttons_loop:
	pusha
	call common_gui_button_add_auto_scaled		; AX := button handle
	mov word [cs:si-2], ax
	mov si, guess_click_callback
	call common_gui_button_click_callback_set
	popa
	
	; move a row down every several letters
	push cx
	neg cx
	add cx, 26
	inc cx
	and cx, 7
	pop cx
	jnz start_click_callback__guess_buttons_loop_next
	
	mov ax, GUESS_X - GUESS_OFFSET				; move to before leftmost
	add bx, GUESS_OFFSET						; row down
	
start_click_callback__guess_buttons_loop_next:	
	add si, LETTER_ENTRY_SIZE
	add ax, GUESS_OFFSET
	loop start_click_callback__guess_buttons_loop
	
	retf


; Callback
;
; IMPORTANT: Callbacks MUST use retf upon returning
;
; input:
;		AX - handle
; output:
;		none
guess_click_callback:	
	call common_gui_button_disable		; each button can be clicked only once
	call lookup_letter_pointer			; CS:SI := ptr to letter entry
	
	mov al, byte [cs:si+2]				; AL := letter ASCII
	
	; replace occurrences of guessed letter into current word
	mov dl, 0							; nothing yet replaced
	
	mov si, word [cs:wordToGuessOffset]
	dec si								; start at -1
	mov di, currentWord - 1				; start at -1
guess_click_callback__replace_loop:
	inc si
	inc di
	
	cmp byte [cs:si], 0
	je guess_click_callback__replace_loop_done		; end of word
	cmp byte [cs:si], al
	jne guess_click_callback__replace_loop	; this is a different letter
	; this is a match, so populate into CS:DI
	mov byte [cs:di], al				; replace "hidden"
	mov dl, 1							; we had a replacement
	jmp guess_click_callback__replace_loop

guess_click_callback__replace_loop_done:
	cmp dl, 0
	jne guess_click_callback_check_win	; no mistake when something replaced
	; this is a mistake
	inc byte [cs:mistakes]
	call draw_man
	; is it game over?
	cmp byte [cs:mistakes], MAX_MISTAKES
	jbe guess_click_callback_done		; it's not game over
guess_click_callback_lose:
	; it's game over!
	mov byte [cs:isGameOver], 1
	mov byte [cs:isWon], 0
	call common_gui_clear_all
	call add_back_to_menu_button
	call common_gui_redraw_screen
	retf
guess_click_callback_check_win:
	call draw_word
	call check_win
	cmp ax, 0
	je guess_click_callback_done		; not a win yet
guess_click_callback_win:
	; player won!
	mov byte [cs:isGameOver], 1
	mov byte [cs:isWon], 1
	call common_gui_clear_all
	call add_back_to_menu_button
	call common_gui_redraw_screen
	retf
guess_click_callback_done:
	call draw_word
	retf


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
	push cs
	pop ds

	cmp byte [cs:isGameStarted], 0
	jne on_refresh_callback__game
on_refresh_callback__menu:	
	; category select label
	mov bx, CATEGORY_RADIO_X
	mov ax, CATEGORY_RADIO_TOP - 4
	mov si, categorySelectLabel
	call common_gui_util_print_single_line_text_with_erase	
	retf

on_refresh_callback__game:
	call draw_word
	
	; word label
	mov bx, WORD_X - 95
	mov ax, WORD_Y
	mov si, wordLabel
	call common_gui_util_print_single_line_text_with_erase
	
	call draw_man
	
	cmp byte [cs:isGameOver], 0
	jne on_refresh_callback_game_over
	
	; guess box label
	mov bx, GUESS_X - 95
	mov ax, GUESS_Y + 6
	mov si, guessLabel
	call common_gui_util_print_single_line_text_with_erase
	
	jmp on_refresh_callback_done

on_refresh_callback_game_over:
	cmp byte [cs:isWon], 0
	je on_refresh_callback_loss
	
on_refresh_callback_victory:
	push cs
	pop ds
	mov si, victoryMessage
	call common_gui_util_show_notice
	
	jmp on_refresh_callback_done
	
on_refresh_callback_loss:
	push cs
	pop ds
	mov si, lossMessage
	call common_gui_util_show_notice
	
	; answer label
	mov bx, WORD_X - 95
	mov ax, WORD_Y + 16
	mov si, wordRealLabel
	call common_gui_util_print_single_line_text_with_erase
	
	; answer word
	mov bx, WORD_X
	mov ax, WORD_Y + 16
	mov si, word [cs:wordToGuessOffset]
	call common_gui_util_print_single_line_text_with_erase

on_refresh_callback_done:
	retf

%ifndef _COMMON_GUI_CONF_COMPONENT_LIMITS_
%define _COMMON_GUI_CONF_COMPONENT_LIMITS_
GUI_RADIO_LIMIT 		equ 12	; maximum number of radio available
GUI_IMAGES_LIMIT 		equ 12	; maximum number of images available
GUI_CHECKBOXES_LIMIT 	equ 12	; maximum number of checkboxes available
GUI_BUTTONS_LIMIT 		equ 32	; maximum number of buttons available
%endif
	
%include "common\vga640\gui\gui.asm"
