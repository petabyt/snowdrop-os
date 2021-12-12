;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BASIC runtime library (RTL).
; This wraps the BASIC interpreter to make it available as a RTL.
;
; This file is an app targeting the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Snowdrop runtime library (RTL) contract:
;
; The RTL can assume:
;   - it can store state - it follows that it will be loaded once for
;     each consumer application
;
; The RTL must:
;   - include the routines base code as the first statement
;   - not take FLAGS as input or return FLAGS as output, for any of its calls
;   - define __rtl_function_registry (used by base to lookup functions) as
;     follows:
;         zero-terminated function name, 2-byte function start offset
;         zero-terminated function name, 2-byte function start offset
;         etc. for each function available to consumers
;   - define __rtl_function_registry_end immediately after
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	%include "rtl\base.asm"

	; this is required by base code to lookup and invoke functions on us
	; it is how we expose functions to consumers
__rtl_function_registry:
	db 'rtl_basic_gui_entry_point', 0	; function name
	dw rtl_basic_gui_entry_point		; function offset
	
	db 'rtl_memory_initialize', 0
	dw rtl_memory_initialize
__rtl_function_registry_end:


; The second-level entry point into BASIC+GUI framework.
;
; NOTE: Requires dynamic memory to have been initialized
;
; input:
;	 DS:SI - pointer to program text, zero-terminated
;		AX - settings
;			 bit             purpose
;			 0               show status on success
;			 1               show status on error
;			 2               wait for key on status
; output:
;		AX - 0 when an error occurred, other value otherwise
rtl_basic_gui_entry_point:
	call basic_gui_entry_point
	ret
	
	
; Initializes RTL's dynamic memory.
; Must be called before BASIC interpretation starts
;
; input:
;	 DS:SI - pointer to beginning of allocatable memory
;		AX - size of allocatable memory
; output:
;		AX - 0 when initialization failed, other value otherwise
rtl_memory_initialize:
	call common_memory_initialize
	ret


%include "common\basic\basic.asm"
