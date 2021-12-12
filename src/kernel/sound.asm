;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It allows for play back of PC speaker sounds with specified durations.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SOUND_FREQUENCY_SILENCE equ 0

SOUND_MODE_NORMAL 		equ 0
SOUND_MODE_IMMEDIATE	equ 1
SOUND_MODE_EXCLUSIVE	equ 2

SOUND_QUEUE_ENTRY_SIZE equ 8		; in bytes
SOUND_QUEUE_ENTRIES equ 25
SOUND_QUEUE_SIZE equ SOUND_QUEUE_ENTRY_SIZE * SOUND_QUEUE_ENTRIES	; in bytes

; The sound queue stores entries representing sounds queued up by consumers
; It is implemented as a circular buffer, like so:
;  +-> [entry 0] --> [entry 1] --> [entry2] --> [entryN] -->+
;  |                                                        |
;  +--------------------------------------------------------+
;
; Format of an entry (by byte, low endian):
;     0 - number of frames remaining to output this sound
;   1-1 - total number of frames
;   2-2 - not used
;   3-4 - initial frequency
;   5-6 - per-frame frequency delta
;   7-7 - sound mode
soundQueue times SOUND_QUEUE_SIZE db 0
soundQueueEnd:

soundQueueOffset dw 0	; the offset of the current entry in the queue
						; used to offset from the address of soundQueue
soundQueueIsLocked db 0	; when 1, the queue will not accept new sounds

forceSpeakerOn db 0		; indicates that the next time we output sound, we
						; should force the speaker to turn on

oldTimerHandlerSeg: dw 0
oldTimerHandlerOff: dw 0


; Gets queue population count
;
; Input:
;		none
; Output:
;		CX - number of sounds in queue
;		BX - maximum queue capacity
common_sound_queue_get_count:
	push ax
	push dx
	push si
	
	mov cx, 0
	mov si, soundQueue
	sub si, SOUND_QUEUE_ENTRY_SIZE				; start at -1
common_sound_queue_get_count_loop:
	add si, SOUND_QUEUE_ENTRY_SIZE				; next entry
	
	cmp si, soundQueueEnd						; if we're past queue end
	jae common_sound_queue_get_count_done		;     then we're done
	
	cmp byte [cs:si+0], 0						; if entry has no frames left
	je common_sound_queue_get_count_loop		;     then we don't count it
	
	inc cx										; sound is active - count it!
	jmp common_sound_queue_get_count_loop
	
common_sound_queue_get_count_done:
	mov bx, SOUND_QUEUE_ENTRIES
	
	pop si
	pop dx
	pop ax
	ret

	
; Adds a sound with the specified characteristics to the sound queue. 
;
; Input:
;		AX - frequency (see int 89h documentation for example frequencies)
;		CL - length of sound in timer ticks (one tick is 10ms)
;		DX - per-tick frequency delta (used to change frequency every tick)
;		CH - sound mode, where:
;				0 - normal (queued sound)
;				1 - immediate (automatically becomes next to play)
;				2 - exclusive (all other sounds are removed, queue is locked
;					while this sound plays)
; Output:
;		none
common_sound_queue_add:
	cmp byte [cs:soundQueueIsLocked], 0
	jne sound_queue_add_done		; if queue is locked, we won't add sound

	pushf
	cli								; don't want the sound playing interrupt
									; messing with our queue now
	
	; handle exclusive sound mode
	cmp ch, SOUND_MODE_EXCLUSIVE		; is it exclusive?
	jne common_sound_queue_add_perform	; no
	call common_sound_queue_clear		; yes, clear all other sounds
	call common_sound_queue_lock		; queue becomes locked while we play 
										; our exclusive sound
common_sound_queue_add_perform:	
	; now add the sound
	push ax
	push bx
	push cx
	push dx
	push si
	
	push ds
	push es
	push fs
	push gs
	push bp
	
	call sound_queue_get_next_available_slot ; CS:DI := pointer to empty slot
	
	pop bp
	pop gs
	pop fs
	pop es
	pop ds
	
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	; now fill in the entry (CS:DI points to its beginning)
	mov byte [cs:di+0], cl 	; byte 0 holds number of frames (input in CL)
	mov byte [cs:di+1], cl 	; byte 1 holds total number of frames
	mov word [cs:di+3], ax	; bytes 3-4 hold initial frequency (input in AX)
	mov word [cs:di+5], dx 	; bytes 5-6 hold per-frame frequency delta (in DX)
	mov byte [cs:di+7], ch 	; byte 7 holds sound mode (input in CH)
	
	cmp ch, SOUND_MODE_IMMEDIATE
	jne sound_queue_add_finished_adding
	sub di, soundQueue						; convert pointer to offset
	mov word [cs:soundQueueOffset], di		; play this sound NOW if immediate
	
sound_queue_add_finished_adding:
	popf									; re-enable interrupts
sound_queue_add_done:
	ret


; Starting from immediately after the current entry, returns a pointer to 
; the next available entry.
;
; NOTE: In case of a full buffer, this routine returns the slot right BEFORE
;       the current slot, basically overwriting the "last" sound in the queue
;
; NOTE: Destroys all registers!
;
; Input:
;		None
; Output:
;		CS:DI - pointer to next available slot
sound_queue_get_next_available_slot:
	mov di, word [cs:soundQueueOffset]		; start at current pointer
	jmp sound_queue_get_next_available_slot_loop
	soundQueueLastOffset dw 0			; private variable!
sound_queue_get_next_available_slot_loop:
	; here, DI = last checked offset
	; we save it in case the queue is full and we add right before current
	mov word [cs:soundQueueLastOffset], di
	
	call sound_queue_get_next_offset		; DI := next offset
	push di									; save next offset
	add di, soundQueue	; CS:DI now points to the entry that may be empty
	cmp byte [cs:di+0], 0	; if zero frames remaining in this entry
	je sound_queue_get_next_available_slot_done 
						; then we found our available slot
	pop di				; restore offset
	push di				; [3]
	; this entry isn't empty
	
	; if we have come back to the current offset, the queue is full
	; in this case, we'll return the entry right BEFORE current offset
	
	cmp di, word [cs:soundQueueOffset]
								; if we haven't looped back to the current
								; offset, then we can continue looking
	jne sound_queue_get_next_available_slot_loop_next 
	
	; by having reached the current offset, we've come full circle
	; the queue is full, and we'll return the entry right BEFORE current
	pop di				; [3] we have an extra value on the stack

	mov di, word [cs:soundQueueLastOffset]
	add di, soundQueue	; CS:DI now points to the entry we're returning
	ret
	
sound_queue_get_next_available_slot_loop_next:
	pop di				; [3]
	jmp sound_queue_get_next_available_slot_loop
sound_queue_get_next_available_slot_done:
	add sp, 2					; we have an extra value on the stack
	ret


; Advances the current position in the sound queue
;
; Input:
;       none
; Output:
;       none
sound_queue_advance_pointer:
	mov di, word [cs:soundQueueOffset]
	call sound_queue_get_next_offset
	mov word [cs:soundQueueOffset], di
	ret
	

; Gets the offset of next entry, cycling to the beginning when needed
;
; Input:
;       DI - offset to start from (not inclusive)
; Output:
;       DI - offset of next entry
sound_queue_get_next_offset:
	add di, SOUND_QUEUE_ENTRY_SIZE			; move pointer forward
	
	cmp di, SOUND_QUEUE_SIZE
	jb sound_queue_get_next_offset_done	; if pointer < total size
											;     then we're done
	mov di, 0								; else reset it to the beginning
sound_queue_get_next_offset_done:
	ret
	

; Meant to be called before any sound operations are performed
;
; Input:
;       none
; Output:
;       none
sound_initialize:
	call common_sound_queue_unlock
	call common_sound_queue_clear
	
	mov word [cs:soundQueueOffset], 0
	
	pushf
	cli							; we don't want interrupts firing before we've
								; saved the old handler address
	mov al, 0B8h				; register to be called by the system timer
	mov di, sound_playback_interrupt_handler	; ES:DI := interrupt handler
	int 0B0h					; register interrupt handler
								; (returns old interrupt handler in DX:BX)
	
	; save old handler address, so our handler can invoke it
	mov word [cs:oldTimerHandlerOff], bx	; save offset of old handler
	mov word [cs:oldTimerHandlerSeg], dx ; save segment of old handler
	popf						; restore flags (and potentially interrupts)
	
	ret

	
; Disallows any future sounds from being enqueued
;
; Input:
;       none
; Output:
;       none
common_sound_queue_lock:
	mov byte [cs:soundQueueIsLocked], 1
	ret
	
	
; Allows sounds to be enqueued
;
; Input:
;       none
; Output:
;       none
common_sound_queue_unlock:
	mov byte [cs:soundQueueIsLocked], 0
	ret
	

; Remove everything from the sound queue, stopping all playback
;
; Input:
;       none
; Output:
;       none
common_sound_queue_clear:
	pusha
	pushf
	push es
	
	cmp byte [cs:soundQueueIsLocked], 0
	jne common_sound_queue_clear_done		; can't clear a locked queue
	
	int 8Ah						; stop speaker
	
	push cs
	pop es
	mov di, soundQueue
	mov cx, SOUND_QUEUE_SIZE
	mov al, 0
	cld
	rep stosb
common_sound_queue_clear_done:	
	pop es
	popf
	popa
	ret


; Meant to be invoked periodically, this routine plays 
; through the sounds in the queue.
;
; Input:
;       none
; Output:
;       none
common_sound_continue_playing:
	pusha

	mov di, word [cs:soundQueueOffset]
	add di, soundQueue			; CS:DI now points to current entry
	
	cmp byte [cs:di+0], 0		; byte 0 of entry contains frames remaining
	jne sound_continue_playing_output ; if frames remaining is not 0,
									  ; we have some frames left to play
									  ; for the current queue entry
sound_continue_playing_next_sound:
	; we ran out of frames for the current sound, so advance to the next entry
	call sound_queue_advance_pointer
	
	mov di, word [cs:soundQueueOffset]
	add di, soundQueue			; CS:DI now points to next sound entry

	cmp byte [cs:di+0], 0		; byte 0 of entry contains frames remaining
	je sound_continue_playing_exit		; if even next entry is empty,
										; then the whole queue is empty
sound_continue_playing_output:
	; we are now going to turn on the speaker
	; CS:DI points to current entry at this point
	dec byte [cs:di+0]			; byte 0 of entry contains frames remaining
								; which is now 1 lower
								
	; skip to where we output the sound if the per-frame frequency delta 
	; is non-zero (since we now have to output a different frequency)
	cmp word [cs:di+5], 0
	jne sound_continue_playing_output_perform
	
	; if we got here, we have a single frequency sound (zero frequency delta)
	
	cmp byte [cs:forceSpeakerOn], 0				; are being forced to output?
	jne sound_continue_playing_output_perform	; yes
	
	; if we already turned it on previously, do nothing
	mov dl, byte [cs:di+1]
	dec dl						; DL := total frames - 1
	cmp byte [cs:di+0], dl		; if (frames remaining) < (total frames - 1)
								;     then the sound had already started,
								;          so we don't start it again
	jb sound_continue_playing_done
	
sound_continue_playing_output_perform:
	; actually output to speaker by turning it on
	mov ax, word [cs:di+3]		; AX := frequency
	cmp ax, SOUND_FREQUENCY_SILENCE	; is it the "silence" magic 
											; frequency value?
	je sound_continue_playing_silence		; yes, so don't actually play it
	
	int 89h						; turn on speaker (frequency in AX)

	mov dx, word [cs:di+5]
	add word [cs:di+3], dx		; modify frequency by "delta" amount
	
	mov byte [cs:forceSpeakerOn], 0	; we've just output, so the speaker was on
									; this has been satisfied
	
	jmp sound_continue_playing_done
sound_continue_playing_silence:
	int 8Ah							; stop speaker
sound_continue_playing_done:
	call try_handle_end_of_sound	; if we just reached the end of this sound,
									; we may have a few things to do
sound_continue_playing_exit:									
	popa
	ret


; Handles actions to be performed as the sound plays its last tick.
; For example, in the case of exclusive sounds, the queue must be unlocked 
; when the exclusive sound finishes playing, so that sound queueing 
; can resume.
;
; Input:
;		CS:DI - pointer to sound entry
; Output:
;		None
try_handle_end_of_sound:
	pusha
	
	cmp byte [cs:di+0], 0
	jne try_handle_end_of_sound_done	; not yet at end
	
	; we are at the end
	int 8Ah								; stop speaker
	
try_handle_end_of_sound_exclusive:
	cmp byte [cs:di+7], SOUND_MODE_EXCLUSIVE
	jne try_handle_end_of_sound_immediate
	; handle SOUND_MODE_EXCLUSIVE
	call common_sound_queue_unlock		; when an exclusive sound finishes,
										; we must unlock queue, to allow
										; sounds again
	jmp try_handle_end_of_sound_done
try_handle_end_of_sound_immediate:
	cmp byte [cs:di+7], SOUND_MODE_IMMEDIATE
	jne try_handle_end_of_sound_done	; nothing to do
	; handle SOUND_MODE_IMMEDIATE
	mov byte [cs:forceSpeakerOn], 1		; when an immediate sound finishes, 
										; we have to resume from the "middle"
										; of another sound, so we must force 
										; the speaker to turn on

	jmp try_handle_end_of_sound_done
	
try_handle_end_of_sound_done:
	popa
	ret
	

; This interrupt handler is registered for interrupt 1Ch (timer)
;
sound_playback_interrupt_handler:
	pushf
	pusha
	push ds
	push es
	push fs
	push gs
	
	;--------------------------------------------------------------------------
	; BEGIN PAYLOAD (as in, what this handler is supposed to do)
	;--------------------------------------------------------------------------
	pushf
	call common_sound_continue_playing
	popf
	;--------------------------------------------------------------------------
	; END PAYLOAD
	;--------------------------------------------------------------------------
	
	; the idea now is to simulate calling the old handler via an "int" opcode
	; this takes two steps:
	;     1. pushing FLAGS, CS, and return IP (3 words)
	;     2. far jumping into the old handler, which takes two steps:
	;         2.1. pushing the destination segment and offset (2 words)
	;         2.2. using retf to accomplish a far jump
	
	; push registers to simulate the behaviour of the "int" opcode
	pushf													; FLAGS
	push cs													; return CS
	push word interrupt_handler_old_handler_return_address	; return IP

	; invoke previous handler
	; use retf to simulate a "jmp far [oldHandlerSeg]:[oldHandlerOff]"
	push word [cs:oldTimerHandlerSeg]
	push word [cs:oldTimerHandlerOff]
	retf						; invoke previous handler
	; old handler returns to the address immediately below
interrupt_handler_old_handler_return_address:		
	
	pop gs
	pop fs
	pop es
	pop ds
	popa
	popf
	iret
