;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file is included directly in the Snowdrop OS kernel.
; It contains internal speaker routines, used to generate sounds.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

speakerIsEnabled: dw 0

; Stop sound being played
;
; input
;			AX - 0 when the speaker is disabled; other value otherwise
; output
;			none
speaker_initialize:
	pusha
	
	mov word [cs:speakerIsEnabled], ax
	
	popa
	ret


; Note 	Frequency 	Frequency #
; C 	130.81 	9121
; C# 	138.59 	8609
; D 	146.83 	8126
; D# 	155.56 	7670
; E 	164.81 	7239
; F 	174.61 	6833
; F# 	185.00 	6449
; G 	196.00 	6087
; G# 	207.65 	5746
; A 	220.00 	5423
; A# 	233.08 	5119
; B 	246.94 	4831
; Middle C 	261.63 	4560
; C# 	277.18 	4304
; D 	293.66 	4063
; D# 	311.13 	3834
; E 	329.63 	3619
; F 	349.23 	3416
; F# 	369.99 	3224
; G 	391.00 	3043
; G# 	415.30 	2873
; A 	440.00 	2711
; A# 	466.16 	2559
; B 	493.88 	2415
; C 	523.25 	2280
; C# 	554.37 	2152
; D 	587.33 	2031
; D# 	622.25 	1917
; E 	659.26 	1809
; F 	698.46 	1715
; F# 	739.99 	1612
; G 	783.99 	1521
; G# 	830.61 	1436
; A 	880.00 	1355
; A# 	923.33 	1292
; B 	987.77 	1207
; C 	1046.50 1140

; Play a sound
;
; input
;			frequency number (see table) in AX
speaker_play_note:
	pusha
	
	cmp word [cs:speakerIsEnabled], 0
	je speaker_play_note_done				; NOOP when speaker is disabled
	
	push ax
	mov al, 182
	out 43h, al		; tell speaker we're about to play a note
	pop ax
	
	out 42h, al		; output low byte
	mov al, ah
	out 42h, al		; output high byte
	
	in al, 61h
	or al, 00000011b
	out 61h, al		; setting lowest two bits turns on note

speaker_play_note_done:
	popa
	ret

; Stop sound being played
;
; input
;			none
speaker_stop:
	pusha

	cmp word [cs:speakerIsEnabled], 0
	je speaker_stop_done					; NOOP when speaker is disabled
	
	in al, 61h
	and al, 11111100b
	out 61h, al		; clearing lowest two bits cancels note

speaker_stop_done:
	popa
	ret
	