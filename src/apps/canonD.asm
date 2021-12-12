;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The CANOND app.
; This app is meant to show an example of how to use the internal speaker
; interrupts provided by the Snowdrop OS kernel.
; It plays Pachelbel's Canon in D.
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

	; Array of the notes to play, 0-terminated
	;                D     A     B    F#     G     D     G     A
canonInDNotes: dw 4063, 5423, 4831, 6449, 6087, 8126, 6087, 5423, 0
messageString: db "Playing Pachelbel's Canon in D:  ", 0
notesString: db "D  ", 0, "A  ", 0, "B  ", 0, "F# ", 0, "G  ", 0, "D  ", 0, "G  ", 0, "A  ", 0 
	
start:
	mov si, messageString
	int 80h
	
	mov di, notesString
	mov si, canonInDNotes
play_loop:	
	lodsw
	cmp ax, 0
	je done			; if the note is a 0, we reached the end
	
	push si
	mov si, di
	int 80h			; print note
	add di, 4		; move to next note string
	pop si
	
	int 89h			; output note in AX
	
	mov cx, 60
	int 85h			; sustain note for a while
	
	int 8Ah			; stop sound
	
	mov cx, 15
	int 85h			; silence for a little bit
	
	jmp play_loop	; next note
	
done:
	int 95h						; exit
