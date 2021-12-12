;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The NOSNAKES app.
; This is a multiplayer (over the serial port) game for two players, in which
; a player loses if their snake collides with any non-empty space, such 
; as his or the enemy snake, borders, etc.
;
; Each player controls their snake using the arrow keys.
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
	
FIELD_BOX_TOP equ 0
FIELD_BOX_LEFT equ 0
FIELD_BOX_CONTENTS_HEIGHT equ COMMON_SCREEN_HEIGHT - 4
FIELD_BOX_CONTENTS_WIDTH equ COMMON_SCREEN_WIDTH - 2
gameTitle: db "No Snakes!  (for Snowdrop OS, 2016)", 0

DIRECTION_UP	equ 's'
DIRECTION_DOWN	equ 'x'
DIRECTION_LEFT	equ 'z'
DIRECTION_RIGHT	equ 'c'

serverWon:				db 0
clientWon:				db 0

myPositionChanged:		db 0
myPositionX:			db COMMON_SCREEN_WIDTH / 2 - 1
myPositionY:			db FIELD_BOX_CONTENTS_HEIGHT / 2 + 1
myDirection:			db DIRECTION_LEFT
myLastDirection:		db DIRECTION_LEFT

enemyPositionChanged:	db 0
enemyPositionX:			db COMMON_SCREEN_WIDTH / 2
enemyPositionY:			db FIELD_BOX_CONTENTS_HEIGHT / 2 + 1
enemyDirection:			db DIRECTION_RIGHT
enemyLastDirection:		db DIRECTION_RIGHT

controlsString: db "[Arrow keys to move]    ", 0
youString: 		db COMMON_ASCII_BLOCK, COMMON_ASCII_BLOCK, "-You    ", 0
enemyString:	db COMMON_ASCII_BLOCK, COMMON_ASCII_BLOCK, "-Enemy", 0
youWonMessage:	db "   You won! Press [ESC] to exit.   ", 0
youLostMessage:	db "   You lost! Press [ESC] to exit.   ", 0
awaitingClient:	db 13, 10, "[SERVER] Awaiting client ..", 0
awaitingServer:	db 13, 10, "[CLIENT] Awaiting server ..", 0

MY_COLOUR equ COMMON_FONT_COLOUR_GREEN | COMMON_BACKGROUND_COLOUR_BLACK
ENEMY_COLOUR equ COMMON_FONT_COLOUR_RED | COMMON_BACKGROUND_COLOUR_BLACK

; these byte values are used to keep the client synchronized
PACKET_SERVER_MY_SNAKE_POSITION		equ 0F0h	; X and Y bytes follow
PACKET_SERVER_ENEMY_SNAKE_POSITION	equ 0F1h	; X and Y bytes follow
PACKET_SERVER_WON					equ 0F2h	; game is over and server won
PACKET_SERVER_LOST					equ 0F3h	; game is over and server lost
; these byte values are sent by the client to indicate direction change
PACKET_CLIENT_DIRECTION_UP			equ 0F6h
PACKET_CLIENT_DIRECTION_DOWN		equ 0F7h
PACKET_CLIENT_DIRECTION_LEFT		equ 0F8h
PACKET_CLIENT_DIRECTION_RIGHT		equ 0F9h
; these are used to synchronize game start
PACKET_SERVER_START_REQUESTED		equ 0F4h	; used to sync game start
PACKET_CLIENT_START_ACKNOWLEDGED	equ 0F5h	; used to sync game start

EMPTY_SCREEN_ATTRIBUTES equ COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_BLACK
	
noSerialDriverMessage: 	db "No serial port driver present. Exiting...", 0
introMessage:			db 13, 10,
						db "No Snakes! (for Snowdrop OS, 2016)", 13, 10
						db "Press", 13, 10
						db "      [S] to run in SERVER mode", 13, 10
						db "      [C] to run in CLIENT mode", 13, 10
						db "    [ESC] to exit", 13, 10
						db 0

oldInterruptHandlerSegment:	dw 0	; these are used to save and then restore
oldInterruptHandlerOffset:	dw 0	; the previous interrupt handler

OBSTACLE_ATTRIBUTES equ COMMON_FONT_COLOUR_BLUE | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
NUM_OBSTACLES equ 62
obstaclePositions: 		; array of obstacle positions (2 bytes per, x then y)
	db 10, 5
	db 10, 6
	db 10, 7
	db 11, 5
	db 12, 5
	db 13, 5
	db 14, 5
	db 15, 5			; top left corner
	
	db 10, 15
	db 10, 16
	db 10, 17
	db 11, 17
	db 12, 17
	db 13, 17
	db 14, 17
	db 15, 17			; bottom left corner
	
	db 69, 5
	db 69, 6
	db 69, 7
	db 68, 5
	db 67, 5
	db 66, 5
	db 65, 5
	db 64, 5			; top right corner
	
	db 69, 15
	db 69, 16
	db 69, 17
	db 68, 17
	db 67, 17
	db 66, 17
	db 65, 17
	db 64, 17			; bottom right corner
	
	db 26, 3
	db 26, 4
	db 26, 5
	db 26, 6
	db 26, 10
	db 26, 11
	db 26, 12
	db 26, 16
	db 26, 17
	db 26, 18
	db 26, 19			; left gates
	
	db 53, 3
	db 53, 4
	db 53, 5
	db 53, 6
	db 53, 10
	db 53, 11
	db 53, 12
	db 53, 16
	db 53, 17
	db 53, 18
	db 53, 19			; right gates
	
	db 38, 8
	db 39, 8
	db 40, 8
	db 41, 8			; upper horizontal
	
	db 38, 14
	db 39, 14
	db 40, 14
	db 41, 14			; lower horizontal


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Program entry point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
start:
	int 0ADh					; AL := serial driver status
	cmp al, 0					; 0 means "driver not loaded"
	je no_serial				; print error message and exit
	
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	call register_interrupt_handler	; register our interrupt handler
	
	int 83h						; clear keyboard buffer
	
	mov ax, 0305h				; set keyboard to be most responsive
	mov bx, 0
	int 16h
	
	mov si, introMessage
	int 97h						; print
wait_option:
	mov ah, 0
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	cmp ah, COMMON_SCAN_CODE_S
	je start_server				; we're running in server mode
	cmp ah, COMMON_SCAN_CODE_C
	je start_client				; we're running in client mode
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je exit						; we're exiting
	jmp wait_option				; read key again

no_serial:
	mov si, noSerialDriverMessage
	int 80h						; print message
	int 95h						; exit without cleaning up (since we haven't
								; installed our interrupt handler yet)
exit:
cleanup_and_exit:
	call restore_interrupt_handler	; restore old interrupt handler
	int 95h						; exit
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BEGIN client mode entry point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Entry point when running in client mode
; The main loop is found immediately below.
;
start_client:
	call client_await_server_start
	
	call common_queue_clear			; initialize the "received data" queue
	call draw_play_area

	mov byte [myDirection], DIRECTION_RIGHT		; client starts facing right
	mov byte [myLastDirection], DIRECTION_RIGHT
	
	mov byte [enemyDirection], DIRECTION_LEFT	; server starts facing left
	mov byte [enemyLastDirection], DIRECTION_LEFT
	
	mov al, byte [myPositionX]
	mov bl, byte [enemyPositionX]
	mov byte [enemyPositionX], al
	mov byte [myPositionX], bl					; reverse value
	
	mov al, byte [myPositionY]
	mov bl, byte [enemyPositionY]
	mov byte [enemyPositionY], al
	mov byte [myPositionY], bl					; reverse value
	
	call set_my_position_changed	; mark snakes as having moved initially ..
	call set_enemy_position_changed
	
	call draw_my_snake				; .. so we can draw them initially
	call draw_enemy_snake
	call hide_video_cursor
	int 83h						; clear keyboard buffer
client_main_loop:
	call clear_position_changed
	
	call client_check_user_input		; handle keys pressed by user
	
	call client_check_server_update_me	; handle updates from server regarding
										; my snake
	call client_check_server_update_him	; handle updates from server regarding
										; his snake
	
	call hide_video_cursor			; we don't want the cursor lingering around
	
	jmp client_main_loop			; run main loop again

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; END client mode entry point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BEGIN server mode entry point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Entry point when running in server mode.
; The main loop is found immediately below.
;
start_server:
	call await_client_start
	
	call common_queue_clear			; initialize the "received data" queue
	call draw_play_area

	mov byte [myDirection], DIRECTION_LEFT		; server starts facing left
	mov byte [enemyDirection], DIRECTION_RIGHT	; client starts facing right
	
	call set_my_position_changed	; mark snakes as having moved initially ..
	call set_enemy_position_changed

	call send_my_snake_position
	call send_enemy_snake_position	; send snake positions to client
	
	call draw_my_snake				; .. so we can draw them initially
	call draw_enemy_snake
	call hide_video_cursor
	
	; delay the start of the game by a bit, so that the client has 
	; time to initialize, and the user has some time to read the 
	; controls legend and locate his snake
	mov cx, 200
	int 85h							; delay
	
	int 83h						; clear keyboard buffer
	; this main loop runs the entire game
server_main_loop:
	call clear_position_changed
	
	call delay						; short delay, so we can remain responsive
	call check_user_input			; handle keys pressed by user
	call delay						; short delay, so we can remain responsive
	call check_user_input			; handle keys pressed by user
	
	call check_client_input			; handle input from the client
	
	call move_my_snake
	call move_enemy_snake			; move snakes

	call determine_winner
	
	call send_snake_positions_to_client
	
	call handle_client_won
	call handle_server_won			; deal with the "game over" case
	
	call draw_my_snake
	call draw_enemy_snake			; draw snakes
	
	call hide_video_cursor			; we don't want the cursor lingering around
	
	jmp server_main_loop			; run main loop again

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; END server mode entry point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; Tell client about the new positions, so it can draw the snakes
;
send_snake_positions_to_client:
	; we don't transmit if one of the snakes just collided
	cmp byte [clientWon], 0
	jne send_snake_positions_to_client_done	; don't transmit if "game over"
	cmp byte [serverWon], 0
	jne send_snake_positions_to_client_done	; don't transmit if "game over"
	
	; transmit
	call send_my_snake_position
	call send_enemy_snake_position	; send snake positions to client
send_snake_positions_to_client_done:
	ret


; Handle case when the server has sent an updated on my snake's position
;
client_check_server_update_me:
	pusha
	call common_queue_peek					; DL := next byte in queue
	cmp ax, 0								; success? (queue not empty)
	jne client_check_server_update_me_done	; no, so we're done
	
	call client_check_and_handle_game_over_packet	; possible "game over"

	cmp dl, PACKET_SERVER_ENEMY_SNAKE_POSITION	; is it my position?
	jne client_check_server_update_me_done		; no, so we're done
	
	; the server is transmitting my snake's position
	call common_queue_dequeue				; dequeue marker packet
	; next two packets contain my new position
	call serial_block_and_read_next			; DL := my new X coordinate
	mov byte [myPositionX], dl
	call serial_block_and_read_next			; DL := my new Y coordinate
	mov byte [myPositionY], dl
	
	call set_my_position_changed
	call draw_my_snake						; draw my snake at the new location
client_check_server_update_me_done:
	popa
	ret


; Handle case when the server has sent an updated on my snake's position
;
client_check_server_update_him:
	pusha
	call common_queue_peek					; DL := next byte in queue
	cmp ax, 0								; success? (queue not empty)
	jne client_check_server_update_him_done	; no, so we're done
	
	call client_check_and_handle_game_over_packet	; possible "game over"
	
	cmp dl, PACKET_SERVER_MY_SNAKE_POSITION	; is it the server's position?
	jne client_check_server_update_him_done	; no, so we're done
	
	; the server is transmitting his snake's position
	call common_queue_dequeue				; dequeue marker packet
	; next two packets contain my new position
	call serial_block_and_read_next			; DL := server snake's X coordinate
	mov byte [enemyPositionX], dl
	call serial_block_and_read_next			; DL := server snake's Y coordinate
	mov byte [enemyPositionY], dl
	
	call set_enemy_position_changed
	call draw_enemy_snake					; draw my snake at the new location
client_check_server_update_him_done:
	popa
	ret
	
	
; If the specified byte is a "won" or "lost" packet, handle it accordingly
;
; input:
;		DL - packet byte
client_check_and_handle_game_over_packet:
	pusha
	cmp dl, PACKET_SERVER_WON				; has the server just won?
	je you_lost_and_exit					; then I just lost
	cmp dl, PACKET_SERVER_LOST				; has the server just lost?
	je you_won_and_exit						; then I just won
	popa
	ret

	
; End state - called (or jumped into) when local player won.
; Stack and registers are not maintained, since this procedure makes 
; the program exit.
;
you_won_and_exit:
	mov si, youWonMessage
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_GREEN
	call draw_outcome_message		; display "you won" message
	call wait_for_key_and_exit
	

; End state - called (or jumped into) when local player lost.
; Stack and registers are not maintained, since this procedure makes 
; the program exit.
;
you_lost_and_exit:
	mov si, youLostMessage
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_RED
	call draw_outcome_message		; display "you lost" message
	call wait_for_key_and_exit
	
	
; If the user is pressing a direction, transmit it to the server
;
client_check_user_input:
	pusha
	mov ah, 1
	int 16h 					; any key pressed?
	jz client_check_user_input_done	; no
	mov ah, 0					; yes, so block and read it
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_UP_ARROW
	je client_check_user_input_up
	cmp ah, COMMON_SCAN_CODE_DOWN_ARROW
	je client_check_user_input_down
	cmp ah, COMMON_SCAN_CODE_LEFT_ARROW
	je client_check_user_input_left
	cmp ah, COMMON_SCAN_CODE_RIGHT_ARROW
	je client_check_user_input_right
	jmp client_check_user_input_done	; unrecognized key
	; directional keys are handled below, 
	; transmitting the direction to the server
client_check_user_input_up:
	mov al, PACKET_CLIENT_DIRECTION_UP
	int 0AFh		; send direction
	jmp client_check_user_input_done
client_check_user_input_down:
	mov al, PACKET_CLIENT_DIRECTION_DOWN
	int 0AFh		; send direction
	jmp client_check_user_input_done
client_check_user_input_left:
	mov al, PACKET_CLIENT_DIRECTION_LEFT
	int 0AFh		; send direction
	jmp client_check_user_input_done
client_check_user_input_right:
	mov al, PACKET_CLIENT_DIRECTION_RIGHT
	int 0AFh		; send direction
	jmp client_check_user_input_done
client_check_user_input_done:
	popa
	ret


; Block until the servers tells us to start
;
client_await_server_start:
	pusha
	
	mov si, awaitingServer
	int 97h						; print "waiting..."
	
	call common_queue_clear
client_await_server_start_loop:
	mov ah, 1
	int 16h 					; any key pressed?
	jz client_await_server_start_send_packet	; no
	mov ah, 0					; yes, so block and read it
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je cleanup_and_exit			; user has exited	
client_await_server_start_send_packet:
	mov dl, '.'
	int 98h						; print a dot
	
	; wait a while
	mov cx, 50
	int 85h			; delay
	
	call common_queue_get_length
	cmp ax, 0							; nothing received from server?
	je client_await_server_start_loop	; loop again
	
	; queue contains something
	call common_queue_dequeue			; DL := byte from server
										; AX = 0 when successful
	cmp dl, PACKET_SERVER_START_REQUESTED
	jne client_await_server_start_loop	; this byte from the server was
										; not a start request
	; acknowledge start request
	mov al, PACKET_CLIENT_START_ACKNOWLEDGED
	int 0AFh		; send "start acknowledged"
	popa
	ret
	

; Called after the game is over, it cleans up, waits for a key, and exits game
;
wait_for_key_and_exit:
	int 83h						; clear keyboard buffer
	mov ah, 0
	int 16h			; block and wait for key: AL := ASCII
					; AH := scan code
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne wait_for_key_and_exit	; user pressed something else
	
	; exit program
	jmp cleanup_and_exit


; Sets [clientWon] to non-zero when server's snake collides
; 
set_won_on_my_snake_collision:
	pusha
	
	mov bh, byte [myPositionY]
	mov bl, byte [myPositionX]
	int 0B2h						; AL := ASCII character at screen location
									; 0 means "empty"
	mov byte [clientWon], al
	
	popa
	ret


; Sets [serverWon] to non-zero when clients's snake collides
; 
set_won_on_enemy_snake_collision:
	pusha
	
	mov bh, byte [enemyPositionY]
	mov bl, byte [enemyPositionX]
	int 0B2h						; AL := ASCII character at screen location
									; 0 means "empty"
	mov byte [serverWon], al
	
	popa
	ret
	

; If either snake collided, sets respective [clientWon] or [serverWon].
; If both snakes collided, chooses a winner randomly, similarly
; setting above-mentioned flags.
;
determine_winner:
	pusha
	call set_won_on_my_snake_collision
	call set_won_on_enemy_snake_collision
	; [clientWon] and [serverWon] are now filled in according to the situation
	
	; now check whether both have collided at the same time
	cmp byte [serverWon], 0
	je determine_winner_done	; both were not 1
	cmp byte [clientWon], 0
	je determine_winner_done	; both were not 1
	
	; both snakes collided at the same time, so choose winner randomly
	int 86h						; AX := next random number
	test ax, 1					; test bit 0
	jnz determine_winner_client_wins
	mov byte [clientWon], 0
	mov byte [serverWon], 1
	jmp determine_winner_done
determine_winner_client_wins:
	mov byte [clientWon], 1
	mov byte [serverWon], 0
determine_winner_done:
	popa
	ret
	
	
; Check and handle case when client won
;	
handle_client_won:
	pusha
	
	cmp byte [clientWon], 0
	je handle_client_won_done	; no collision
	; I lost
	
	mov al, PACKET_SERVER_LOST
	int 0AFh						; tell client that server lost
	
	call you_lost_and_exit
handle_client_won_done:	
	popa
	ret

	
; Check and handle case when server won
;
handle_server_won:
	pusha
	
	cmp byte [serverWon], 0
	je handle_server_won_done	; no, so no collision
	; I won
	
	mov al, PACKET_SERVER_WON
	int 0AFh						; tell client that server won

	call you_won_and_exit
handle_server_won_done:	
	popa
	ret
	
	
; Cause small delay
;
delay:
	pusha
	mov cx, 6
	int 85h							; delay
	popa
	ret
	
	
; Send the position of my snake to the client, if the snake has moved
;
send_my_snake_position:
	cmp byte [myPositionChanged], 0
	je send_my_snake_position_done	; if the snake's position hasn't changed
									; we're not sending anything
	; send it!
	mov al, PACKET_SERVER_MY_SNAKE_POSITION
	int 0AFh					; send marker
	mov al, byte [myPositionX]
	int 0AFh					; send x
	mov al, byte [myPositionY]
	int 0AFh					; send y
send_my_snake_position_done:
	ret


; Send the position of the enemy snake to the client, if the snake has moved
;
send_enemy_snake_position:
	cmp byte [enemyPositionChanged], 0
	je send_enemy_snake_position_done
							; if the snake's position hasn't changed
							; we're not sending anything
	; send it!
	mov al, PACKET_SERVER_ENEMY_SNAKE_POSITION
	int 0AFh					; send marker
	mov al, byte [enemyPositionX]
	int 0AFh					; send x
	mov al, byte [enemyPositionY]
	int 0AFh					; send y
send_enemy_snake_position_done:
	ret
	

; Move my snake according to direction and current position
;
move_my_snake:
	pusha
	call set_my_position_changed

	mov dl, byte [myDirection]
	mov dh, byte [myLastDirection]
	mov ch, byte [myPositionX]
	mov cl, byte [myPositionY]
	call move_snake
	mov byte [myLastDirection], dh
	mov byte [myPositionX], ch
	mov byte [myPositionY], cl
	
	popa
	ret


; Move enemy snake according to direction and current position
;
move_enemy_snake:
	pusha
	call set_enemy_position_changed

	mov dl, byte [enemyDirection]
	mov dh, byte [enemyLastDirection]
	mov ch, byte [enemyPositionX]
	mov cl, byte [enemyPositionY]
	call move_snake
	mov byte [enemyLastDirection], dh
	mov byte [enemyPositionX], ch
	mov byte [enemyPositionY], cl
	
	popa
	ret
	
	
; Given the current direction, perform movement
;
; input:
;		DL - direction in which movement is attempted
;		DH - last direction of snake
;		CH - current snake X
;		CL - current snake Y
; output:
;		DH - last direction of snake
;		CH - current snake X
;		CL - current snake Y
move_snake:
move_snake_check_direction:
	mov al, dl
	cmp al, DIRECTION_UP
	je move_snake_up
	cmp al, DIRECTION_DOWN
	je move_snake_down
	cmp al, DIRECTION_LEFT
	je move_snake_left
	cmp al, DIRECTION_RIGHT
	je move_snake_right
	
move_snake_up:
	cmp dh, DIRECTION_DOWN
	jne move_snake_up_perform		; I was not moving down
	mov dl, DIRECTION_DOWN
	jmp move_snake_check_direction	; pressing UP while moving down is NOOP
move_snake_up_perform:
	dec cl
	mov dh, al
	jmp move_snake_done
	
move_snake_down:
	cmp dh, DIRECTION_UP
	jne move_snake_down_perform		; I was not moving up
	mov dl, DIRECTION_UP
	jmp move_snake_check_direction	; pressing DOWN while moving up is NOOP
move_snake_down_perform:
	inc cl
	mov dh, al
	jmp move_snake_done

move_snake_left:
	cmp dh, DIRECTION_RIGHT
	jne move_snake_left_perform		; I was not moving right
	mov dl, DIRECTION_RIGHT
	jmp move_snake_check_direction	; left while moving right is NOOP
move_snake_left_perform:
	dec ch
	mov dh, al
	jmp move_snake_done

move_snake_right:
	cmp dh, DIRECTION_LEFT
	jne move_snake_right_perform		; I was not moving left
	mov dl, DIRECTION_LEFT
	jmp move_snake_check_direction	; right while moving left is NOOP
move_snake_right_perform:
	inc ch
	mov dh, al
	jmp move_snake_done

move_snake_done:
	ret	
	

; Draw head of my snake at the snake's current location
;
draw_my_snake:
	pusha
	cmp byte [myPositionChanged], 0
	je draw_my_snake_done			; if the snake's position hasn't changed
									; we're not drawing anything
	mov bh, byte [myPositionY]
	mov bl, byte [myPositionX]
	int 9Eh							; move cursor
	
	mov cx, 1
	mov dl, MY_COLOUR
	int 9Fh							; write attributes
	
	mov dl, COMMON_ASCII_BLOCK
	int 98h							; write "block" character
draw_my_snake_done:
	popa
	ret


; Draw head of enemy snake at the snake's current location
;
draw_enemy_snake:
	pusha
	cmp byte [enemyPositionChanged], 0
	je draw_enemy_snake_done		; if the snake's position hasn't changed
									; we're not drawing anything
	mov bh, byte [enemyPositionY]
	mov bl, byte [enemyPositionX]
	int 9Eh							; move cursor
	
	mov cx, 1
	mov dl, ENEMY_COLOUR
	int 9Fh							; write attributes
	
	mov dl, COMMON_ASCII_BLOCK
	int 98h							; write "block" character
draw_enemy_snake_done:
	popa
	ret
	
	
; If the user is pressing a key, set [myDirection] appropriately
;
check_user_input:
	pusha
	mov ah, 1
	int 16h 					; any key pressed?
	jz check_user_input_done	; no
	mov ah, 0					; yes, so block and read it
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_UP_ARROW
	je check_user_input_up
	cmp ah, COMMON_SCAN_CODE_DOWN_ARROW
	je check_user_input_down
	cmp ah, COMMON_SCAN_CODE_LEFT_ARROW
	je check_user_input_left
	cmp ah, COMMON_SCAN_CODE_RIGHT_ARROW
	je check_user_input_right
	jmp check_user_input_done	; unrecognized key
	; directional keys are handled below
check_user_input_up:
	mov byte [myDirection], DIRECTION_UP
	jmp check_user_input_done
check_user_input_down:
	mov byte [myDirection], DIRECTION_DOWN
	jmp check_user_input_done
check_user_input_left:
	mov byte [myDirection], DIRECTION_LEFT
	jmp check_user_input_done
check_user_input_right:
	mov byte [myDirection], DIRECTION_RIGHT
	jmp check_user_input_done
check_user_input_done:
	popa
	ret


; If the client has transmitted a direction, set [enemyDirection] appropriately
; If more than one bytes are available from the client, the last byte which 
; represents a direction is the one that's kept.
;
check_client_input:
	pusha
check_client_input_check_any:
	call common_queue_get_length
	cmp ax, 0							; nothing received from client
	je check_client_input_done
	; handle input from client
	call common_queue_dequeue			; DL := byte from client
										; AX = 0 when successful
	call is_valid_client_input			; AX = 0 when input is directional
	cmp ax, 0
	jne check_client_input_check_any	; not directional, so see if queue
										; contains anything else
	; here, DL = direction packet from client
	call direction_packet_to_direction	; DL := direction
	mov byte [enemyDirection], dl		; store last read direction
	jmp check_client_input_check_any	; read subsequent bytes from client
check_client_input_done:
	popa
	ret	


; Check if a given byte read from the client represents a valid directional
; input.	
;
; input:
;		DL - byte to check
; output:
;		AX - 0 when input is valid
is_valid_client_input:
	cmp dl, PACKET_CLIENT_DIRECTION_UP
	je is_valid_client_input_yes
	cmp dl, PACKET_CLIENT_DIRECTION_DOWN
	je is_valid_client_input_yes
	cmp dl, PACKET_CLIENT_DIRECTION_LEFT
	je is_valid_client_input_yes
	cmp dl, PACKET_CLIENT_DIRECTION_RIGHT
	je is_valid_client_input_yes
	; not valid direction
	mov ax, 1
	ret
is_valid_client_input_yes:
	mov ax, 0
	ret
	
	
set_my_position_changed:
	mov byte [myPositionChanged], 1
	ret
	
set_enemy_position_changed:
	mov byte [enemyPositionChanged], 1
	ret
	
clear_position_changed:
	mov byte [myPositionChanged], 0
	mov byte [enemyPositionChanged], 0
	ret	

	
; Block until a byte is available from the serial port, and read it
;
; output:
;		DL - byte read
serial_block_and_read_next:
	push ax
serial_block_and_read_next_loop:
	call common_queue_get_length
	cmp ax, 0							; nothing in the queue?
	je serial_block_and_read_next_loop	; loop again
	call common_queue_dequeue			; DL := byte from server
	
	pop ax
	ret


; Block until the client acknowledges game start
;
await_client_start:
	pusha
	
	mov si, awaitingClient
	int 97h						; print "waiting..."
	
	call common_queue_clear
await_client_start_loop:
	mov ah, 1
	int 16h 					; any key pressed?
	jz await_client_start_send_packet	; no
	mov ah, 0					; yes, so block and read it
	int 16h						; block and wait for key: AL := ASCII
								; AH := scan code
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je cleanup_and_exit			; user has exited	
await_client_start_send_packet:
	mov dl, '.'
	int 98h						; print a dot
	
	; request start
	mov al, PACKET_SERVER_START_REQUESTED
	int 0AFh		; send "start requested"
	
	; wait a while
	mov cx, 50
	int 85h			; delay

await_client_start_check_queue:
	; check if the client responded
	call common_queue_get_length
	cmp ax, 0							; nothing received from client
	je await_client_start_loop			; send start request again
	; handle input from client
	call common_queue_dequeue			; DL := byte from client
										; AX = 0 when successful
	cmp dl, PACKET_CLIENT_START_ACKNOWLEDGED
	jne await_client_start_check_queue	; this byte from the client was
										; not a start acknowledgement
	; we received start acknowledgement from the client
	popa
	ret


; Convert a direction packet to a direction enum
;
; input:
;		DL - direction packet
; output:
;		DL - direction
direction_packet_to_direction:
	cmp dl, PACKET_CLIENT_DIRECTION_UP
	je direction_packet_to_direction_up
	cmp dl, PACKET_CLIENT_DIRECTION_DOWN
	je direction_packet_to_direction_down
	cmp dl, PACKET_CLIENT_DIRECTION_LEFT
	je direction_packet_to_direction_left
	cmp dl, PACKET_CLIENT_DIRECTION_RIGHT
	je direction_packet_to_direction_right
direction_packet_to_direction_up:
	mov dl, DIRECTION_UP
	ret
direction_packet_to_direction_down:
	mov dl, DIRECTION_DOWN
	ret
direction_packet_to_direction_left:
	mov dl, DIRECTION_LEFT
	ret
direction_packet_to_direction_right:
	mov dl, DIRECTION_RIGHT
	ret
	

; Renders a message at the end of the game
;
; input:
;		DS:SI - pointer to string
;		DL - attributes
draw_outcome_message:
	pusha

	int 0A5h
	mov cx, bx					; CX := string length
	
	mov bh, COMMON_SCREEN_HEIGHT - 2	; row
	mov bl, 3
	int 9Eh						; move cursor
	
	; here, DL = attributes to set
	; here, CX = string length
	int 9Fh						; attributes
	int 97h						; write string
	
	call hide_video_cursor
	popa
	ret	


; Draws a number of obstacles on the playfield
;
draw_obstacles:
	pusha
	
	mov cx, NUM_OBSTACLES
	mov si, obstaclePositions
draw_obstacles_loop:
	push cx							; save loop counter
	
	mov bh, byte [ds:si+1]
	mov bl, byte [ds:si+0]
	int 9Eh							; move cursor
	
	mov cx, 1
	mov dl, OBSTACLE_ATTRIBUTES
	int 9Fh							; write attributes
	
	mov dl, COMMON_ASCII_DARKEST
	int 98h							; write obstacle character

	add si, 2						; next obstacle (2 bytes per)
	pop cx							; restore loop counter
	loop draw_obstacles_loop		; next obstacle
	
	popa
	ret
	
	
; Entry point into drawing the entire screen
;	
draw_play_area:
	pusha
	mov dl, EMPTY_SCREEN_ATTRIBUTES
	call common_clear_screen_to_colour
	
	mov bh, FIELD_BOX_TOP
	mov bl, FIELD_BOX_LEFT
	mov ah, FIELD_BOX_CONTENTS_HEIGHT
	mov al, FIELD_BOX_CONTENTS_WIDTH
	call common_draw_box
	
	add bl, 20
	mov si, gameTitle
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title
	
	mov bh, COMMON_SCREEN_HEIGHT - 2
	mov bl, 18
	int 9Eh								; move cursor
	
	mov si, controlsString
	int 97h								; print
	
	mov dl, MY_COLOUR
	mov cx, 2
	int 9Fh								; coloured square
	
	mov si, youString
	int 97h								; print
	
	mov dl, ENEMY_COLOUR
	mov cx, 2
	int 9Fh								; coloured square
	
	mov si, enemyString
	int 97h								; print

	call draw_obstacles					; obstacles
	
	call hide_video_cursor
	
	popa
	ret
	
	
; Hide video cursor by moving it to the bottom of the screen, and making that
; character black ink on black background
;
hide_video_cursor:
	pusha
	
	mov bh, COMMON_SCREEN_HEIGHT - 1
	mov bl, 0
	int 9Eh						; move cursor
	
	mov dl, COMMON_FONT_COLOUR_BLACK | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, 1					; set attributes on this many characters
	int 9Fh						; attributes (passed in DL)
	
	popa
	ret
	
	
; Registers our interrupt handler for interrupt 0AEh, Snowdrop OS serial port
; driver's "serial user interrupt".
;
register_interrupt_handler:
	pusha

	pushf
	cli
	mov al, 0AEh				; we're registering for interrupt 0AEh
	mov di, interrupt_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)
	mov word [cs:oldInterruptHandlerOffset], bx	 ; save offset of old handler
	mov word [cs:oldInterruptHandlerSegment], dx ; save segment of old handler
	popf
	
	popa
	ret
	

; Restores the previous interrupt 0AEh handler (that is, before this program
; started).
;
restore_interrupt_handler:
	pusha
	push es

	mov di, word [cs:oldInterruptHandlerOffset]
	mov ax, word [cs:oldInterruptHandlerSegment]
	mov es, ax					; ES:DI := old interrupt handler
	
	mov al, 0AEh				; we're registering for interrupt 0AEh
	int 0B0h					; register interrupt handler

	pop es
	popa
	ret
	

; This is our interrupt handler, which will be registered with interrupt 0AEh.
; It will be called by the serial port driver whenever it has a byte for us.
;
; input:
;		AL - byte read from serial port
interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs						; save all registers
	
	push cs
	pop ds
	
	mov dl, al					; enqueue call below expects byte in DL
	call common_queue_enqueue	; queue up the byte we got from the driver

	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf						; restore all registers
	iret						; return control


%include "common\scancode.asm"
%include "common\ascii.asm"
%include "common\colours.asm"
%include "common\screen.asm"
%include "common\textbox.asm"
%include "common\queue.asm"
