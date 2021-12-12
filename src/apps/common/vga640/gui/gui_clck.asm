;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains logic for displaying a clock.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_CLOCK_
%define _COMMON_GUI_CLOCK_

GUI_CLOCK_SEPARATOR			equ ':'
GUI_CLOCK_RENDER_INTERVAL	equ 5

guiClockCountDownToRender:	db 0
guiClockNeedRender:			db 1
guiClockBuffer:		times 9 db 0


; Prepares module before usage
;
; input:
;		none
; output:
;		none
gui_clock_prepare:
	pusha
	
	mov byte [cs:guiClockNeedRender], 1
	mov byte [cs:guiClockCountDownToRender], 0
	
	popa
	ret

	
; Clears all storage for this module
;
; input:
;		none
; output:
;		none
gui_clock_clear_storage:
	; while we don't actually clear any data, we want the clock
	; to appear immediately after a possible redraw, so we schedule it
	mov byte [cs:guiClockNeedRender], 1
	ret
	
	
; Returns whether some of this module's entities need to be rendered
;
; input:
;		none
; output:
;		AL - 0 when there is no need for rendering, other value otherwise
gui_clock_get_need_render:
	mov al, byte [cs:guiClockNeedRender]
	ret
	
	
; Iterates through all entities, rendering those which need it
;
; input:
;		none
; output:
;		none
gui_clock_render_all:
	pusha
	pushf
	push ds

	clc
	mov ah, 2
	int 1Ah
	jc gui_clock_render_all_done	; RTC error, so we do nothing

	mov al, ch					; hours
	call gui_util_decode_BCD
	add al, '0'
	add ah, '0'
	mov byte [cs:guiClockBuffer+0], ah
	mov byte [cs:guiClockBuffer+1], al

	mov byte [cs:guiClockBuffer+2], GUI_CLOCK_SEPARATOR

	mov al, cl					; minutes
	call gui_util_decode_BCD
	add al, '0'
	add ah, '0'
	mov byte [cs:guiClockBuffer+3], ah
	mov byte [cs:guiClockBuffer+4], al
	
	mov byte [cs:guiClockBuffer+5], GUI_CLOCK_SEPARATOR
	
	mov al, dh					; seconds
	call gui_util_decode_BCD
	add al, '0'
	add ah, '0'
	mov byte [cs:guiClockBuffer+6], ah
	mov byte [cs:guiClockBuffer+7], al

	push cs
	pop ds
	mov si, guiClockBuffer
	
	; now display buffer, which holds ASCII representation of clock
	; zero-terminated
	mov bx, GUI_BORDER_OUTER_MARGIN + 1
	mov ax, GUI_BORDER_OUTER_MARGIN + 1
	call common_gui_util_print_single_line_text_with_erase
	
gui_clock_render_all_done:
	mov byte [cs:guiClockNeedRender], 0
	pop ds
	popf
	popa
	ret
	
	
; Marks all entities of this module as needing render
;
; input:
;		none
; output:
;		none
gui_clock_schedule_render_all:
	mov byte [cs:guiClockNeedRender], 1
	ret
	
	
; Considers the newly-dequeued event, and modifies state for any entities
; within this module
;
; input:
;		none
; output:
;		none
gui_clock_handle_event:
	; is event applicable?
	cmp byte [cs:dequeueEventBytesBuffer], GUI_EVENT_TIMER_TICK
	jne gui_clock_handle_event_done
	
	pusha
	
	cmp byte [cs:guiClockCountDownToRender], 0
	jne gui_clock_handle_event__next
	
	; it needs render
	mov byte [cs:guiClockNeedRender], 1
	mov byte [cs:guiClockCountDownToRender], GUI_CLOCK_RENDER_INTERVAL
gui_clock_handle_event__next:
	dec byte [cs:guiClockCountDownToRender]
	popa
gui_clock_handle_event_done:
	ret
	
	
%endif
