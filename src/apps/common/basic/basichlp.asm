;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains help pages for Snowdrop OS's BASIC interpreter.
;
; It is meant to be included only when the consumer wants to 
; display BASIC help.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_HELP_
%define _COMMON_BASIC_HELP_

basicHelpPage:
	db '_Functions_:  LEN <str> - string length   VAL <str> - string to integer', 13, 10
	db 'KEY <int> - true when key (scan code) is down  CHR <int> - ASCII to string', 13, 10
	db 'ASCII <str> - get ASCII value of char. RND <int> - random between 0 and <int>-1', 13, 10
	db 'BIN <str> - binary number string to integer  CHARAT <row>, <col> - get char. at', 13, 10
	db 'SERIALDATAAVAIL - true when SERIALR can read   SUBSTRING <str>,<start>,<length>', 13, 10
	db 'STRINGAT <str>, <index> - char. at index', 13, 10
	db '_Operators_:  + - * / % =  > < >= <= <> (logical)AND OR XOR NOT', 13, 10
	db '(bitwise)BITAND BITOR BITXOR BITSHIFTL BITSHIFTR BITROTATEL BITROTATER', 13, 10
	db 13, 10
	db '_Instructions_:  PRINT <exp>     PRINTLN <exp>      PRINTLN   - print to screen', 13, 10
	db 'LET <var> = <exp> - variable assignment    GOTO <label> - jump to label', 13, 10
	db 'STOP - stop execution    AT <row>, <col> - move cursor', 13, 10
	db 'FOR <var> = <int> TO <int> STEP <exp>  ... NEXT <var> - specified increment', 13, 10
	db 'FOR <var> = <int> TO <int>  ... NEXT <var> - increment of 1', 13, 10
	db 'IF <exp> THEN <instruction1> [ELSE <instruction2>]', 13, 10
	db 'CALL <label>   RETURN - jump and return to calling point   REM "comment"', 13, 10
	db 'INPUTS <var> - read string from user     INPUTN <var> - read integer from user', 13, 10
	db 'COLOURS <font>, <background> - changes current text colours', 13, 10
	db 'PAUSE <int> - halt (centiseconds)      NOOP - does nothing', 13, 10
	db 'WAITKEY <var> - waits for keypress and saves it as a string', 13, 10
	db 'BEEP <frequency>, <duration> - beep and continue     CLS - clear screen', 13, 10
	db 'BEEPW <frequency>, <duration> - beep and halt', 13, 10
	db 'PARALLELW <register>, <value> - write to parallel port', 13, 10
	db 'SERIALW <int> - write to serial port     SERIALR <var> - read from serial port'
	db 0


basicGuiHelpPage:
	db 'YIELD - give up control    GUIBEGIN <title string> - prepare GUI framework', 13, 10
	db 'GUIACTIVEELEMENTID - returns handle of GUI element which caused last event', 13, 10
	db '', 13, 10
	db 'GUIBUTTONADD <label>, <x>, <y> - create button and return its ID', 13, 10
	db 'GUIBUTTONDELETE <id>   GUIBUTTONDISABLE <id>  GUIBUTTONENABLE <id>', 13, 10
	db 'GUICHECKBOXADD <label>, <x>, <t> - create checkbox and return its ID', 13, 10
	db 'GUICHECKBOXENABLE <id>  GUICHECKBOXDISABLE <id>  GUICHECKBOXDELETE <id>', 13, 10
	db 'GUICHECKBOXISCHECKED <id> - returns checked   GUIPRINT <exp> - prints 8x8 chars', 13, 10
	db 'GUICHECKBOXSETISCHECKED <id>, <is_checked> - sets whether it is checked', 13, 10
	db 'GUISETCURRENTRADIOGROUP <group_id> - sets group ID to be used with RADIO calls', 13, 10
	db 'GUIRADIOADD <label>, <x>, <y> - create radio button and return its ID', 13, 10
	db 'GUIRADIODELETE <id>  GUIRADIODISABLE <id>  GUIRADIOENABLE <id>', 13, 10
	db 'GUIRADIOISSELECTED <id> - whether is selected  GUICLEARALL - delete elements', 13, 10
	db 'GUIRADIOSETISSELECTED <id>, <is_selected> - sets whether it is selected', 13, 10
	db 'GUIIMAGEASCIIADD <text>, <x>, <y> - creates text image and returns its ID', 13, 10
	db 'GUIIMAGEASCIISETTEXT <id>, <text> - changes ASCII image text', 13, 10
	db 'GUIIMAGESETISSELECTED <id>, <is_selected> - selects or deselects', 13, 10
	db 'GUIIMAGEISSELECTED <id> - whether is selected    GUIRECTANGLEERASETO <x>,<y>', 13, 10
	db 'GUIIMAGESETSHOWSELECTEDMARK <id>, <is_shown> - whether selected marker is shown', 13, 10
	db 'GUIIMAGEDISABLE <id>  GUIIMAGEENABLE <id>  GUIIMAGEDELETE <id>', 13, 10
	db 'GUIIMAGESETSHOWHOVERMARK <id>, <is_shown> - whether hover outline is shown', 13, 10
	db 'GUIAT <x>,<y> - new location  GUIATDELTA <dx>,<dy> - new location by delta', 13, 10
	db '_Events_: timerTickEvent buttonClickEvent checkboxChangeEvent radioChangeEvent', 13, 10
	db '         imageLeftClickedEvent imageRightClickedEvent imageSelectedChangeEvent', 13, 10
	db '         guiRefreshEvent'
	db 0


; Displays the help page for the BASIC interpreter
;
; input:
;		none
; output:
;		none
basic_help:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, basicHelpPage
	int 97h
	
	pop ds
	popa
	ret

	
; Displays the help page for BASIC's GUI-specific help
;
; input:
;		none
; output:
;		none
basic_gui_help:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, basicGuiHelpPage
	int 97h
	
	pop ds
	popa
	ret
	

%endif
