;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains address watching functionality for Snowdrop OS's debugger.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_DBGX86_WATCH_
%define _COMMON_DBGX86_WATCH_


dbgx86WatchIsSet:			db 0
dbgx86WatchAddress:			dw 0


; Gets watched value
;
; input:
;		none
; output:
;		AX - address to watch
dbgx86Watch_get:
	mov ax, word [cs:dbgx86WatchAddress]
	ret


; Sets watched value
;
; input:
;		AX - address to watch
; output:
;		none
dbgx86Watch_set:
	mov byte [cs:dbgx86WatchIsSet], 1
	mov word [cs:dbgx86WatchAddress], ax
	ret

	
; Initializes the watched value module
;
; input:
;		none
; output:
;		AX - 0 when watch is not set, other value otherwise
dbgx86Watch_is_set:
	mov ah, 0
	mov al, byte [cs:dbgx86WatchIsSet]
	ret
	

; Initializes the watched value module
;
; input:
;		none
; output:
;		none
dbgx86Watch_initialize:
	mov byte [cs:dbgx86WatchIsSet], 0
	ret


%endif
