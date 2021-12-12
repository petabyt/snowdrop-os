;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It is part of Snowdrop OS's graphical user interface (GUI) framework.
; It contains NOOP implementations of the functions that are part of the
; GUI extensions layer.
;
; When extensions are included into an application, the application is
; expected to include GUI extension modules BEFORE gui.asm. This causes the
; REAL implementation of gx_ functions to be included.
;
; The reason this is designed as such is to avoid any unwarranted increases
; to binary sizes.
;
; This version of the GUI framework relies on VGA mode 12h, 640x480, 16 
; colours.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_GUI_EXTENSIONS_
%define _COMMON_GUI_EXTENSIONS_


; Prepares extensions before usage
;
; input:
;		none
; output:
;		none
gx_prepare:
	ret
	
	
; Clears all storage for all extensions
;
; input:
;		none
; output:
;		none
gx_clear_storage:
	ret
	
	
; Returns whether the entities of some extension need to be rendered
;
; input:
;		none
; output:
;		AL - 0 when there is no need for rendering, other value otherwise
gx_get_need_render:
	mov al, 0
	ret
	
	
; Iterates through all entities of all extensions, rendering those 
; which need it
;
; input:
;		none
; output:
;		none
gx_render_all:
	ret


; Marks all entities of all extensions as needing render
;
; input:
;		none
; output:
;		none
gx_schedule_render_all:
	ret

	
; Considers the newly-dequeued event, and modifies state for any entities
; within each extension
;
; input:
;		none
; output:
;		none
gx_handle_event:
	ret
	

%endif
