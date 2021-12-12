;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The FILEMAN app.
; The purpose of this File Manager app is to let the user browse and 
; manage the files on the disk.
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

allocatedSegment: dw 0			; segment number of segment used for copying
largeNumberBufferString: times 16 db 0			; will hold the result of itoa

titleString: db "Snowdrop OS File Manager", 0
TITLE_STRING_LENGTH equ $ - titleString - 1		; - 1 to account for terminator

diskEmptyString1: db "                                   DISK EMPTY                                   ", 0
diskEmptyString2: db "               INSERT ANOTHER DISK AND PRESS [F5] TO RE-SCAN DISK               ", 0
diskEmptyString3: db "                      PRESS [F2] TO WRITE THE STORED FILE                       ", 0
diskEmptyString4: db "                      PRESS [F10] TO CHANGE DISK                                ", 0
diskEmptyString5: db "                      PRESS [ESCAPE] TO EXIT                                    ", 0

fileBoxTitleString: db "Name", 0
fileBoxSizeString: db "Size", 0
instructionsTitleString: db "Actions", 0
diskStatusTitleString: db "Disk Status", 0
loadedFileTitleString: db "Loaded File", 0
diskIdString:		db "      Disk ID: ", 0

confirmDeletionString: db "Press [Y] to confirm deletion", 0
noMemoryString: db "Failed to allocate memory. Exiting...", 0
					
FILE_BOX_TOP equ 2
FILE_BOX_LEFT equ 3
FILE_BOX_NAME_LEFT equ FILE_BOX_LEFT + 4
FILE_BOX_SIZE_LEFT equ FILE_BOX_LEFT + 16
FILE_BOX_CONTENTS_HEIGHT equ 18
FILE_BOX_CONTENTS_WIDTH equ 40

rowOfBlanksStrings: times FILE_BOX_CONTENTS_WIDTH db " " ; as many blanks as
				    db 0								 ; box is wide, plus
														 ; string terminator
PAGE_SIZE equ FILE_BOX_CONTENTS_HEIGHT - 2	; account for blank lines at
											; top and bottom
SCREEN_HEIGHT equ 25
SCREEN_WIDTH equ 80

CONFIRMATION_TOP	equ FILE_BOX_TOP + FILE_BOX_CONTENTS_HEIGHT + 2
CONFIRMATION_LEFT	equ FILE_BOX_LEFT + 1
CONFIRMATION_LENGTH equ FILE_BOX_CONTENTS_WIDTH

NUM_DIRECTORY_ENTRIES equ 224
DIRECTORY_ENTRY_SIZE equ 32			; bytes
DIRECTORY_SIZE equ DIRECTORY_ENTRY_SIZE * NUM_DIRECTORY_ENTRIES

JUST_PAST_DIRECTORY_END equ rootDirectory + DIRECTORY_SIZE
	; pointer to immediately after the end of the root directory

MAX_PAGES equ ( NUM_DIRECTORY_ENTRIES / PAGE_SIZE ) + 1
pageStartBookmarks: times MAX_PAGES dw 0	; pointers to first entry in
											; every page
currentPage: 			dw 1337		; number of current page
numFilesOnCurrentPage:	dw 1337		; between 0 and PAGE_SIZE-1
cursorIndex:			dw 1337		; between 0 and numFilesOnCurrentPage-1
numTotalPages:			dw 1337		; total number of pages we're showing

; this array stores a pointer to each of the 11-character file names
; visible on the current page, so that file operations can be keyed off of them
currentPageFileNames: times PAGE_SIZE dw 0	; pointers to 11-byte strings
											; indexed by cursorIndex
; instructions box variables
INSTRUCTIONS_BOX_CONTENTS_HEIGHT equ 11
INSTRUCTIONS_BOX_CONTENTS_WIDTH equ 24
INSTRUCTIONS_BOX_TOP equ FILE_BOX_TOP
INSTRUCTIONS_BOX_LEFT equ SCREEN_WIDTH - INSTRUCTIONS_BOX_CONTENTS_WIDTH - 5

readFileInstructionString:		db "  F1: read file", 0
writeFileInstructionString:		db "  F2: write file", 0
viewInstructionString: 			db "  F3: view file", 0
rescanInstructionString: 		db "  F5: re-scan disk", 0
deleteInstructionString:		db "  F8: delete file", 0
changeDiskString:				db " F10: change disk", 0
pagingInstructionString:		db "  ", 27, 26, ": next/prev page", 0
cursorInstructionString:		db "  ", 24, 25, ": cursor up/down", 0
exitInstructionString:			db " ESC: exit", 0

; disk status box variables
DISK_STATUS_BOX_CONTENTS_HEIGHT equ 3
DISK_STATUS_BOX_CONTENTS_WIDTH equ INSTRUCTIONS_BOX_CONTENTS_WIDTH
DISK_STATUS_BOX_TOP equ 15
DISK_STATUS_BOX_LEFT equ INSTRUCTIONS_BOX_LEFT

freeSpaceSuffixString: db " bytes free", 0
freeSpaceFilesSuffixString: db " files free", 0

; loaded file box variables
LOADED_FILE_BOX_CONTENTS_HEIGHT equ 1
LOADED_FILE_BOX_CONTENTS_WIDTH equ INSTRUCTIONS_BOX_CONTENTS_WIDTH
LOADED_FILE_BOX_TOP equ 20
LOADED_FILE_BOX_LEFT equ INSTRUCTIONS_BOX_LEFT

loadedFileName: times 11 db ' ', 0	; stores name of currently loaded file
loadedFileSize: dw 0				; stores size of currently loaded file
loadedFileExists: db 0				; changed to 1 once a file is loaded

; previous/next page label variables
PREVIOUS_LABEL_TOP equ FILE_BOX_TOP + 1
PREVIOUS_LABEL_LEFT equ FILE_BOX_LEFT + 2
previousPageLabelString: db "<<<", 0
PREVIOUS_LABEL_LENGTH equ $ - previousPageLabelString - 1

nextPageLabelString: db ">>>", 0
NEXT_LABEL_LENGTH equ $ - nextPageLabelString - 1
NEXT_LABEL_TOP equ FILE_BOX_TOP + 1
NEXT_LABEL_LEFT equ FILE_BOX_LEFT + FILE_BOX_CONTENTS_WIDTH - NEXT_LABEL_LENGTH

; page number label (current/out of) variables
pageNumberLabelString1: db "page ", 0
pageNumberLabelString2: db " of ", 0
PAGE_NUMBER_LABEL_LENGTH equ $ - pageNumberLabelString1 - 1
PAGE_NUMBER_LABEL_TOP equ FILE_BOX_TOP + 1
PAGE_NUMBER_LABEL_LEFT equ FILE_BOX_LEFT + 14

MAX_DISKS				equ 6
availableDiskIds:		times MAX_DISKS db 99		; stores up to 6 disks
availableDiskCount:		db 99
currentDiskPointer:		dw availableDiskIds		; pointer into disk ID array
initialDiskId:			db 99
lastDiskId:				db 99

CHANGE_DISK_BOX_TOP					equ 16
CHANGE_DISK_BOX_CONTENTS_HEIGHT		equ 1
CHANGE_DISK_BOX_CONTENTS_WIDTH		equ 61
CHANGE_DISK_BOX_LEFT 				equ SCREEN_WIDTH/2 - CHANGE_DISK_BOX_CONTENTS_WIDTH/2 - 2
changeDiskTitleString:				db 'Select Disk', 0
diskIdMessage:				db ' (SPACE to change, ENTER to accept)   disk ID: ', 0
eraseCurrentDiskMessage:	db 'h          ', 0
currentDiskMessage:			db 'h (current)', 0


; IMPORTANT: DS:SI is always maintained to point at the first root directory
;            entry of the NEXT page, or to just past the end of the root
;            directory in case there are no further pages
start:
	; allocate a memory segment to hold any files we read (for copying)
	int 91h							; BX := allocated segment, AX:=0 on success
	cmp ax, 0
	jne no_memory					; if AX != 0, memory was not allocated
	
	; make my own virtual display active, to not clobber my parent task's
	int 9Ah						; AX := current (my) task ID
	int 96h						; activate virtual display of task in AX
	
	; we allocated memory, so save its segment number, and initialize
	mov word [allocatedSegment], bx	; store allocated memory

	int 0C2h					; get available disk information
	mov byte [cs:availableDiskIds + 0], bl
	mov byte [cs:availableDiskIds + 1], bh
	mov byte [cs:availableDiskIds + 2], cl
	mov byte [cs:availableDiskIds + 3], ch
	mov byte [cs:availableDiskIds + 4], dl
	mov byte [cs:availableDiskIds + 5], dh
	mov byte [cs:availableDiskCount], ah

	; here, AL = ID of current disk
	mov byte [cs:initialDiskId], al		; store it for later
	mov byte [cs:lastDiskId], al
	
	mov ch, 0
	mov cl, ah							; CX := available disk count
	mov di, availableDiskIds
	repne scasb
	dec di								; bring DI back to the match
	mov word [cs:currentDiskPointer], di	; assumes current disk exists 
										; among those disks returned above	
	
	call initialize
check_user_input:
	call check_input
	jmp check_user_input		; infinite "check user input" loop
no_memory:
	mov si, noMemoryString
	int 80h						; print error string
	jmp exit_program


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
; Checks whether a previous page (to which we can navigate) exists
;
; input
;	 	none
; output
;		AX - 1 if a previous page exists, 0 otherwise
has_previous_page:
	cmp word [currentPage], 2
	jae has_previous_page_yes
	mov ax, 0						; no
	ret
has_previous_page_yes:
	mov ax, 1						; yes
	ret
	

; Given a start pointer, check whether at least one more file entry exists 
; until the end of the root directory.
; The file entry at the start pointer is included in the scan.
;
; input
;	 DS:SI - start pointer into the root directory (pointing at a file entry)
; output
;		AX - 1 if an entry exists, 0 if it doesn't
has_next_page:
	push si
	cmp si, JUST_PAST_DIRECTORY_END			; have we started past the end?
	jae has_next_page_done					; yes
has_next_page_loop:
	cmp byte [ds:si+0], 0E5h				; is this a deleted entry?
	je has_next_page_next					; yes
	cmp byte [ds:si+0], 0					; is this an empty entry?
	je has_next_page_next					; yes
	; not empty or deleted, so this entry contains a file
	pop si
	mov ax, 1								; return that an entry exists
	ret
has_next_page_next:
	add si, DIRECTORY_ENTRY_SIZE			; next entry
	cmp si, JUST_PAST_DIRECTORY_END			; are we just past the end?
	jae has_next_page_done					; yes
	jmp has_next_page_loop					; next entry
has_next_page_done:
	pop si
	mov ax, 0								; return that no entry was found
	ret
	
	
; Erases all space inside the file box, as well as set all attributes to 
; white on black.
; As a consequence, also hides the cursor.
;
erase_box_contents:
	pusha
	
	mov cx, FILE_BOX_CONTENTS_HEIGHT
	add bh, FILE_BOX_TOP + 1
	mov bl, FILE_BOX_LEFT + 1
erase_box_contents_loop:
	int 9Eh						; move cursor
	
	push cx
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_BLACK
	int 9Fh						; attributes
	pop cx
	
	inc bh						; next row
	mov si, rowOfBlanksStrings
	int 97h						; print
	loop erase_box_contents_loop
	
	popa
	ret


; Given a start pointer, attempt to fill the box with files.
; Stops early if not enough files are left from the start pointer to
; the end of the root directory.
;
; input
;	 DS:SI - start pointer into the root directory (pointing at a file entry)
; output
;		DX - number of files displayed on page (between 0 and PAGE_SIZE)
;	 DS:SI - pointer to entry right after the last shown file (could be 
;			 pointing past the end of the root directory)
;		Updates [numFilesOnCurrentPage] 
print_one_page_of_files:
	push ax
	push bx
	push cx
	push di
	
	call erase_box_contents
	
	mov cx, PAGE_SIZE
	mov dx, -1								; index in the box, zero-based
print_one_page_of_files_loop:
	cmp byte [ds:si+0], 0E5h				; is this a deleted entry?
	je print_one_page_of_files_entry_empty	; yes
	cmp byte [ds:si+0], 0					; is this an empty entry?
	je print_one_page_of_files_entry_empty	; yes
	jmp print_one_page_of_files_print

print_one_page_of_files_entry_empty:
	add si, DIRECTORY_ENTRY_SIZE			; next entry
	cmp si, JUST_PAST_DIRECTORY_END			; are we just past the end?
	jae print_one_page_of_files_done		; yes
	jmp print_one_page_of_files_loop

print_one_page_of_files_print:
	; we now print the current entry
	inc dx									; next box index (reaches 0 when
											; we get here for the first file)

	mov bx, dx								; BX := box index
	shl bx, 1								; 2 bytes per pointer in array
	mov di, currentPageFileNames
	mov word [es:di+bx], si					; save pointer to file name
											
	call print_file_entry
	add si, DIRECTORY_ENTRY_SIZE			; next entry
	cmp si, JUST_PAST_DIRECTORY_END			; are we just past the end?
	jae print_one_page_of_files_done		; yes
	loop print_one_page_of_files_loop		; no, so loop again

print_one_page_of_files_done:
	inc dx									; index in box was 0-based, and
											; we're returning the quantity
	
	mov word [numFilesOnCurrentPage], dx	; save number of files on 
											; the page we just rendered
	cmp dx, 0
	je print_one_page_of_files_return		; if page was empty, just return
	; when page is not empty, move cursor to first file on the page
	mov ax, 0
	call move_cursor						; move cursor to index 0
print_one_page_of_files_return:
	call print_page_number
	
	pop di
	pop cx
	pop bx
	pop ax
	ret
	

; Prints a file entry into the file box, at the specified "box index"
;
; input
;	 DS:SI - pointer to beginning of root directory file entry
;		DL - index in the box (e.g.: entry with index 0 is printed at the
;			 top of the box
print_file_entry:
	pusha
	push si						; [1] save pointer to beginning of entry
	
	; first, print file name
	mov bh, dl
	add bh, FILE_BOX_TOP + 2
	mov bl, FILE_BOX_LEFT + 3
	int 9Eh						; move cursor
	
	mov al, byte [ds:si+8]		; save byte that's right after the first 8 bytes
								; of the file name
	mov byte [ds:si+8], 0		; put a 0 there temporarily (string terminator)
	int 97h						; print first 8 bytes of file name
	mov byte [ds:si+8], al		; restore original value
	
	mov dl, ' '					; print a blank space so that the extension
	int 98h						; doesn't follow immediately after the first
								; 8 characters of the file name
	
	add si, 8					; point at last 3 bytes of the file name
	mov al, byte [ds:si+3]		; save byte that's right after the file name
	mov byte [ds:si+3], 0		; put a 0 there temporarily (string terminator)
	int 97h						; print last 3 bytes of file name
	mov byte [ds:si+3], al		; restore original value
	
	; then, print file size
	pop si						; [2] restore pointer to beginning of entry
	
	add bl, 12
	int 9Eh						; move cursor

	mov ax, word [ds:si+28]		; lowest 2 bytes of file size go in AX
	mov dx, word [ds:si+30]		; highest 2 bytes of file size go in DX
	mov si, largeNumberBufferString
	mov bl, 2					; formatting option 2 - commas + leading blanks
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI
	int 97h						; print file size string
	
	popa
	ret


; Draws the box that contains the file list, as well as its title labels
;	
draw_file_box:
	pusha
	
	mov bh, FILE_BOX_TOP
	mov bl, FILE_BOX_LEFT
	mov ah, FILE_BOX_CONTENTS_HEIGHT
	mov al, FILE_BOX_CONTENTS_WIDTH
	call common_draw_box
	
	add bl, 5
	mov si, fileBoxTitleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title
	
	add bl, 14
	mov si, fileBoxSizeString
	call common_draw_box_title
	
	popa
	ret
	
	
; Draws a box around the edge of the screen, and prints the title
;
draw_outer_screen_box:
	pusha
	
	mov bh, 0
	mov bl, 0
	mov ah, SCREEN_HEIGHT - 3
	mov al, SCREEN_WIDTH - 2
	call common_draw_box
	
	mov bl, SCREEN_WIDTH / 2 - TITLE_STRING_LENGTH / 2 - 2
	mov si, titleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title

	popa
	ret	
	

; Clears the confirmation area
;
erase_confirmation_area:
	pusha
	
	mov bh, CONFIRMATION_TOP
	mov bl, CONFIRMATION_LEFT
	int 9Eh						; move cursor
	mov dl, COMMON_FONT_COLOUR_BLACK | COMMON_BACKGROUND_COLOUR_BLACK	; "hide" text
	mov cx, CONFIRMATION_LENGTH ; this many characters
	int 9Fh						; attributes (passed in DL)
	call hide_video_cursor
	
	popa
	ret

	
; Prints confirmation text
;
; input
;		DS:SI - pointer to string to print
print_confirmation:
	pusha
	
	mov bh, CONFIRMATION_TOP
	mov bl, CONFIRMATION_LEFT
	int 9Eh						; move cursor
	mov dl, COMMON_FONT_COLOUR_MAGENTA | COMMON_FONT_BRIGHT | COMMON_FONT_BLINKING | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, CONFIRMATION_LENGTH	; this many characters
	int 9Fh						; attributes (passed in DL)

	int 97h						; print	string at DS:SI
	call hide_video_cursor
	
	popa
	ret
	
	
; Writes the loaded file to disk
;
; output:
;		AX - 0 when the file was written
handle_write_file:
	pusha
	pushf
	
	cmp byte [loadedFileExists], 0
	je handle_write_file_failure	; if no file is loaded, we're done
	
	push es
	mov cx, word [loadedFileSize]	; CX := file size
	mov si, loadedFileName		; DS:SI points to file name we're writing
	mov ax, word [allocatedSegment]
	mov es, ax
	mov di, 0					; ES:DI := allocatedSegment:0000
	int 9Dh						; write file
	pop es
	
	mov byte [loadedFileExists], 0	; clear loaded file
	
	mov cx, 11
	mov di, loadedFileName		; ES:DI points to loaded file name
	mov al, ' '
	cld
	rep stosb					; store 11 blanks in the loaded file name
	
	call draw_loaded_file_box
	call hide_video_cursor
	
	popf
	popa
	mov ax, 0					; return success
	ret
handle_write_file_failure:
	popf
	popa
	mov ax, 1					; return failure
	ret


; Loads current file into memory and then displays it
; 
handle_view:
	pusha
	pushf
	push ds
	push es
	
	call handle_read_file
	
	int 0A0h					; clear screen
	mov ds, word [cs:allocatedSegment]
	mov si, 0					; DS:SI := allocatedSegment:0000
	mov cx, word [cs:loadedFileSize]
	mov ax, COMMON_TEXT_VIEW_PAGED_FLAG_WAIT_FOR_USER_INPUT_AT_END
	call common_text_view_paged
	
	pop es
	pop ds
	popf
	popa
	call redraw_full_current_screen
	ret


; Allows the user to pick another disk to become current
;
; input:
;		none
; output:
;		none
handle_change_disk:
	pusha
	push ds
	push es
	
	mov bh, CHANGE_DISK_BOX_TOP
	mov bl, CHANGE_DISK_BOX_LEFT
	mov ah, CHANGE_DISK_BOX_CONTENTS_HEIGHT
	mov al, CHANGE_DISK_BOX_CONTENTS_WIDTH
	call common_draw_box
	call common_textbox_clear
	
	add bl, 2
	mov si, changeDiskTitleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title

handle_change_disk_loop:
	; re-display disk
	mov bh, CHANGE_DISK_BOX_TOP + 1
	mov bl, CHANGE_DISK_BOX_LEFT + 1
	int 9Eh					; move cursor
	mov si, diskIdMessage
	int 97h
	mov si, word [cs:currentDiskPointer]
	mov al, byte [cs:si]
	call byte_to_hex		; CX := two ASCII chars which represent the input
	mov dl, ch
	int 98h					; print char
	mov dl, cl
	int 98h					; print char
	
	mov si, eraseCurrentDiskMessage
	cmp al, byte [cs:lastDiskId]	; is last current disk the initial disk?
	jne handle_change_disk_loop_wait_key		; no
	mov si, currentDiskMessage			; yes, so print a note
handle_change_disk_loop_wait_key:
	int 97h								; prints either (current) or blanks,
										; to erase a previous (current)
	mov ah, 0
	int 16h						; wait for key
	cmp ah, COMMON_SCAN_CODE_ENTER
	je handle_change_disk_done
	cmp ah, COMMON_SCAN_CODE_SPACE_BAR
	jne handle_change_disk_loop
	; space was pressed
	call next_disk
	jmp handle_change_disk_loop
handle_change_disk_done:
	mov si, word [cs:currentDiskPointer]
	mov al, byte [cs:si]
	mov byte [cs:lastDiskId], al
	
	pop es
	pop ds
	popa
	ret
	
	
; Cycles to the next available disk
; 
; input:
;		none
; output:
;		none
next_disk:
	pusha
	pushf
	push ds
	push es

	inc word [cs:currentDiskPointer]
	
	mov ax, availableDiskIds
	mov ch, 0
	mov cl, byte [cs:availableDiskCount]
	add ax, cx							; AX := just after last disk
	cmp word [cs:currentDiskPointer], ax
	jb next_disk_done
	
	; we've gone past the end of available disks
	mov word [cs:currentDiskPointer], availableDiskIds	; move to first disk
	
next_disk_done:
	mov si, word [cs:currentDiskPointer]
	mov al, byte [cs:si]
	int 0C3h							; change disk
	
	pop es
	pop ds
	popf
	popa
	ret


; Renders the entire screen, without changing page or moving cursor
; 	
redraw_full_current_screen:
	pusha
	pushf
	push ds
	push es
	
	call redraw
	
	mov ax, cs
	mov ds, ax
	mov es, ax
	
	mov di, pageStartBookmarks
	dec word [cs:currentPage]		; print_one_page_of_files expects to be
									; right behind page we're listing
	mov bx, word [cs:currentPage]
	shl bx, 1
	mov si, word [cs:di+bx]			; SI := pageStartBookmarks[ currentPage ]
	
	mov ax, word [cs:cursorIndex]	; save cursor index
	call print_one_page_of_files
	inc word [cs:currentPage]
	
	call print_previous_page_label
	call print_next_page_label
	
	call move_cursor				; move cursor to saved index
	
	pop es
	pop ds
	popf
	popa
	ret
	

; Loads current file into memory
;
handle_read_file:
	pusha
	pushf
	
	push es						; [1] - save ES
	
	mov bx, word [cursorIndex]
	shl bx, 1					; BX := offset into file name pointers array
	add bx, currentPageFileNames ; BX points to the 2-byte file name pointer
	mov si, word [bx]			; SI := 2-byte pointer to file name
								; DS:SI now points to file name

	mov ax, word [allocatedSegment]
	mov es, ax
	mov di, 0					; ES:DI := allocatedSegment:0000
	int 81h						; read file

	mov word [loadedFileSize], cx	; store file size
	mov byte [loadedFileExists], 1	; store that we actually read a file

	pop es						; [1] - restore ES
	mov di, loadedFileName		; ES:DI points to loaded file name variable
								; DS:SI still points to 11-char FAT file name
	mov cx, 11
	cld
	rep movsb					; copy 11 file name characters
	
	mov byte [loadedFileExists], 1	; mark file as loaded
	
	call draw_loaded_file_box
	call hide_video_cursor
	
	popf
	popa
	ret
	
	
; Prompts user for confirmation and then deletes the current file,
; re-initializing the program (including re-reading the disk)
;
handle_delete:
	pusha
	
	; print confirmation
	mov si, confirmDeletionString
	call print_confirmation

	; wait for a key
	int 83h						; clear keyboard buffer
	mov ah, 0					; "block and wait for key"
	int 16h						; read key, AH := scan code, AL := ASCII
	cmp ah, COMMON_SCAN_CODE_Y
	jne	handle_delete_cancelled	; if key was not [Y], cancel deletion
	
	; perform deletion
	mov bx, word [cursorIndex]
	shl bx, 1					; BX := offset into file name pointers array
	add bx, currentPageFileNames ; BX points to the 2-byte file name pointer
	mov si, word [bx]			; SI := 2-byte pointer to file name
								; DS:SI now points to file name
	int 9Ch						; kernel "delete file" system call
	
	; deletion done, now re-initialize
	popa						; first clean up stack (throw away values)
	call initialize				; reset program to initial values
	ret
handle_delete_cancelled:
	call erase_confirmation_area
	popa
	ret
	
	
; Checks whether the user is pressing any keys, handling them as necessary
;
check_input:
	pushf
	push ax
	push bx
	push cx
	push dx
	
	mov ah, 1
	int 16h					; check whether any key is pressed
	jz check_input_done 	; no key pressed
	; a key was pressed, so read and handle it
	mov ah, 0
	int 16h					; read key, AH := scan code, AL := ASCII
	; flow into the switch-case structure below
check_input_check_rescan:
	cmp ah, COMMON_SCAN_CODE_F5
	jne check_input_check_change_disk
	
	; handle RE-SCAN
	call initialize
	jmp check_input_done
check_input_check_change_disk:
	cmp byte [cs:availableDiskCount], 1
	jbe check_input_check_read_file
	cmp ah, COMMON_SCAN_CODE_F10
	jne check_input_check_read_file
	
	; handle CHANGE DISK
	call handle_change_disk
	call initialize
	jmp check_input_done
check_input_check_read_file:
	cmp ah, COMMON_SCAN_CODE_F1
	jne check_input_check_write_file
	
	; handle READ FILE
	call handle_read_file
	jmp check_input_done
check_input_check_write_file:
	cmp ah, COMMON_SCAN_CODE_F2
	jne check_input_check_delete
	
	; handle WRITE FILE
	call handle_write_file
	cmp ax, 0						; did we actually write the file?
	jne check_input_done			; no
	call initialize					; yes, so re-initialize
	jmp check_input_done
check_input_check_delete:
	cmp ah, COMMON_SCAN_CODE_F8
	jne check_input_check_view
	
	; handle DELETE
	call handle_delete
	jmp check_input_done
check_input_check_view:
	cmp ah, COMMON_SCAN_CODE_F3
	jne check_input_check_escape
	
	; handle VIEW
	call handle_view
	jmp check_input_done
check_input_check_escape:
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	jne check_input_check_down
	
	; handle ESCAPE
	mov bx, word [allocatedSegment]
	int 92h							; deallocate memory
	jmp exit_program

check_input_check_down:
	cmp ah, COMMON_SCAN_CODE_DOWN_ARROW
	jne check_input_check_up
	
	; handle down arrow
	mov ax, word [cursorIndex]
	inc ax							; we're moving cursor down
	call move_cursor				; move cursor
	jmp check_input_done
check_input_check_up:
	cmp ah, COMMON_SCAN_CODE_UP_ARROW
	jne check_input_check_left
	
	; handle up arrow
	mov ax, word [cursorIndex]
	dec ax							; we're moving cursor up
	call move_cursor				; move cursor
	jmp check_input_done
check_input_check_left:
	cmp ah, COMMON_SCAN_CODE_LEFT_ARROW
	jne check_input_check_right
	
	; handle left arrow
	call try_page_backward
	jmp check_input_done
check_input_check_right:
	cmp ah, COMMON_SCAN_CODE_RIGHT_ARROW
	jne check_input_done
	
	; handle right arrow
	call try_page_forward
	; flow into "done" below
check_input_done:
	pop dx
	pop cx
	pop bx
	pop ax
	popf
	ret


; Attempt to move page forward	
;
; input
;	 DS:SI - start pointer into the root directory (pointing at a file entry)
; output
;		DX - number of files displayed on page (between 0 and PAGE_SIZE)
;	 DS:SI - pointer to entry right after the last shown file (could be 
;			 pointing past the end of the root directory)
try_page_forward:
	push ax
	push bx
	
	mov dx, 0						; initially, we have 0 files to display
	call has_next_page				; AX := 1 when a next page is available
	cmp ax, 1
	jne try_page_forward_done		; if AX != 1, we're done
	
	; change page forward
	mov di, pageStartBookmarks
	mov bx, word [currentPage]
	shl bx, 1
	mov word [es:di+bx], si			; pageStartBookmarks[ currentPage ] := SI
	call print_one_page_of_files	; DS:SI now points to right after last file
									; printed on current page
	inc word [currentPage]
	
	call print_previous_page_label
	call print_next_page_label
try_page_forward_done:
	pop bx
	pop ax
	ret


; Attempt to move page backward
;
; input
;	 DS:SI - start pointer into the root directory (pointing at a file entry)
; output
;		DX - number of files displayed on page (between 0 and PAGE_SIZE)
;	 DS:SI - pointer to entry right after the last shown file (could be 
;			 pointing past the end of the root directory)
try_page_backward:
	push ax
	push bx
	
	mov dx, 0						; initially, we have 0 files to display
	call has_previous_page			; AX := 1 when a previous page is available
	cmp ax, 1
	jne try_page_backward_done		; if AX != 1, we're done
	
	; change page backward
	mov di, pageStartBookmarks
	
	dec word [currentPage]
	dec word [currentPage]
	mov bx, word [currentPage]
	shl bx, 1
	mov si, word [es:di+bx]			; SI := pageStartBookmarks[ currentPage ]
	call print_one_page_of_files
	inc word [currentPage]
	
	call print_previous_page_label
	call print_next_page_label
try_page_backward_done:
	pop bx
	pop ax
	ret

	
; Displays the "page X of Y" message
;
print_page_number:
	pusha
	
	mov bh, PAGE_NUMBER_LABEL_TOP
	mov bl, PAGE_NUMBER_LABEL_LEFT
	int 9Eh						; move cursor
	
	mov dl, COMMON_FONT_COLOUR_GREEN | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, PAGE_NUMBER_LABEL_LENGTH + 8	; this many characters
	int 9Fh									; attributes
	
	mov si, pageNumberLabelString1
	int 97h
	
	; print current page number
	mov ax, word [currentPage]		; lowest 2 bytes of file size go in AX
	inc ax							; page numbers are 1-based
	mov dx, 0						; highest 2 bytes of file size go in DX
	mov si, largeNumberBufferString
	mov bl, 3					; formatting option 3 - no leading zeroes
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI
	int 97h						; print
	
	mov si, pageNumberLabelString2
	int 97h
	
	; print total number of pages
	mov ax, word [numTotalPages]	; lowest 2 bytes of file size go in AX
	mov dx, 0						; highest 2 bytes of file size go in DX
	mov si, largeNumberBufferString
	mov bl, 3					; formatting option 3 - no leading zeroes
	int 0A2h					; convert unsigned 32bit in DX:AX to a string
								; in DS:SI
	int 97h						; print

	call hide_video_cursor

	popa
	ret
	
	
; Displays a message in the case that the disk is empty.	
;
print_disk_empty:
	pusha
	
	mov bh, SCREEN_HEIGHT / 2 - 1
	mov bl, 0
	int 9Eh						; move cursor
	
	mov cx, SCREEN_WIDTH * 3	; set attributes for three message lines
	
	cmp byte [cs:availableDiskCount], 1
	jbe print_disk_empty_calculate_height_after_f10
	add cx, SCREEN_WIDTH
	
print_disk_empty_calculate_height_after_f10:
	cmp byte [loadedFileExists], 0
	je print_disk_empty_print	; if no file is stored, we can just print
	add cx, SCREEN_WIDTH		;   else we're writing another line
	
print_disk_empty_print:
	
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_RED
	int 9Fh						; attributes
	
	mov si, diskEmptyString1
	int 97h						; print
	mov si, diskEmptyString2
	int 97h						; print
	
	cmp byte [loadedFileExists], 0
	je print_disk_empty_after_f2	; if no file is stored, we skip over 
									; the third line (the one about writing
									; the stored file)
	mov si, diskEmptyString3
	int 97h						; print
print_disk_empty_after_f2:
	cmp byte [cs:availableDiskCount], 1
	jbe print_disk_empty_after_f10

	mov si, diskEmptyString4
	int 97h						; print
	
print_disk_empty_after_f10:
	mov si, diskEmptyString5
	int 97h						; print
	
	popa
	ret	


; Draws the cursor at the specified location, with the specified colour
;
; input
;		DL - attribute byte to use when drawing the cursor
;		AX - index of slot in the file list where the cursor will be drawn
draw_cursor:
	pusha
	
	mov bh, al					; ignore high byte
	add bh, FILE_BOX_TOP + 2	; offset downward from top of box
	mov bl, FILE_BOX_LEFT + 1	; offset to the right from left edge of box
	int 9Eh						; move cursor
	
	mov cx, FILE_BOX_CONTENTS_WIDTH	; set attributes on this many characters
	int 9Fh						; attributes (passed in DL)
	
	popa
	ret
	
	
; Erases the cursor from its current location
;
erase_cursor_at_current_location:
	pusha
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_BACKGROUND_COLOUR_BLACK
	mov ax, [cursorIndex]
	call draw_cursor
	popa
	ret
	

; Shows the cursor at its current location
;
show_cursor_at_current_location:
	pusha
	mov dl, COMMON_FONT_COLOUR_WHITE | COMMON_FONT_BRIGHT | COMMON_BACKGROUND_COLOUR_BROWN
	mov ax, [cursorIndex]
	call draw_cursor
	popa
	ret


; Moves the cursor from the current position to a specified position.
; NOOP if the cursor is not allowed to move there (out of range, etc.).
;
; input
;		AX - index of destination file list slot for the cursor
move_cursor:
	pusha
	mov bx, word [numFilesOnCurrentPage]
	cmp ax, bx
	jae move_cursor_done		; if destination is out of range, we're done
	; perform cursor move
	call erase_cursor_at_current_location
	mov word [cursorIndex], ax	; save new cursor location
	call show_cursor_at_current_location
move_cursor_done:
	call hide_video_cursor		; after moving the cursor, we hide the video
								; cursor so that it won't linger somewhere on
								; the screen
	popa
	ret
	
	
; Hide video cursor by moving it to the bottom of the screen, and making that
; character black ink on black background
;
hide_video_cursor:
	pusha
	
	mov bh, SCREEN_HEIGHT - 1
	mov bl, 0
	int 9Eh						; move cursor
	
	mov dl, COMMON_FONT_COLOUR_BLACK | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, 1					; set attributes on this many characters
	int 9Fh						; attributes (passed in DL)
	
	popa
	ret


; Draws the box containing the status of the disk
;	
draw_disk_status_box:
	pusha
	
	mov bh, DISK_STATUS_BOX_TOP
	mov bl, DISK_STATUS_BOX_LEFT
	mov ah, DISK_STATUS_BOX_CONTENTS_HEIGHT
	mov al, DISK_STATUS_BOX_CONTENTS_WIDTH
	call common_draw_box
	
	add bl, 9
	mov si, diskStatusTitleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title
	
	; print disk ID
	mov bh, DISK_STATUS_BOX_TOP + 1
	mov bl, DISK_STATUS_BOX_LEFT + 6
	int 9Eh					; move cursor
	mov si, diskIdString
	int 97h

	mov si, word [cs:currentDiskPointer]
	mov al, byte [cs:si]
	call byte_to_hex		; CX := two ASCII chars which represent the input
	mov dl, ch
	int 98h					; print char
	mov dl, cl
	int 98h					; print char
	mov dl, 'h'
	int 98h					; print char
	
	; print amount of free disk space, in bytes
	mov bh, DISK_STATUS_BOX_TOP + 2
	mov bl, DISK_STATUS_BOX_LEFT + 2
	int 9Eh					; move cursor
	
	int 0A3h				; DX:AX := available disk space, in bytes
	mov si, largeNumberBufferString
	mov bl, 2				; formatting option 2 - commas + leading blanks
	int 0A2h				; convert unsigned 32bit in DX:AX to a string
							; in DS:SI

	int 97h					; print number
	mov si, freeSpaceSuffixString
	int 97h					; print suffix label
	
	; print number of available files
	mov bh, DISK_STATUS_BOX_TOP + 3
	mov bl, DISK_STATUS_BOX_LEFT + 2
	int 9Eh					; move cursor
	
	int 0A1h				; CX := available files count
	mov dx, 0
	mov ax, cx				; DX:AX := available files count
	mov si, largeNumberBufferString
	mov bl, 2				; formatting option 2 - commas + leading blanks
	int 0A2h				; convert unsigned 32bit in DX:AX to a string
							; in DS:SI
	int 97h					; print number
	mov si, freeSpaceFilesSuffixString
	int 97h					; print suffix label
	
	popa
	ret

	
; Draws the box containing information on the file loaded into memory
;	
draw_loaded_file_box:
	pusha
	
	mov bh, LOADED_FILE_BOX_TOP
	mov bl, LOADED_FILE_BOX_LEFT
	mov ah, LOADED_FILE_BOX_CONTENTS_HEIGHT
	mov al, LOADED_FILE_BOX_CONTENTS_WIDTH
	call common_draw_box
	
	add bl, 9
	mov si, loadedFileTitleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title
	
	; print name of loaded file
	mov bh, LOADED_FILE_BOX_TOP + 1
	mov bl, LOADED_FILE_BOX_LEFT + 12
	int 9Eh					; move cursor
	
	mov si, loadedFileName
	mov al, byte [ds:si+8]		; save byte that's right after the first 8 bytes
								; of the file name
	mov byte [ds:si+8], 0		; put a 0 there temporarily (string terminator)
	int 97h						; print first 8 bytes of file name
	mov byte [ds:si+8], al		; restore original value
	
	mov dl, ' '					; print a blank space so that the extension
	int 98h						; doesn't follow immediately after the first
								; 8 characters of the file name
	
	add si, 8					; move to beginning of 3-character extension
	int 97h						; print extension
	
	popa
	ret
	
	
; Draws the box containing instructions, such as which keys do what
;
draw_instructions_box:
	pusha
	
	mov bh, INSTRUCTIONS_BOX_TOP
	mov bl, INSTRUCTIONS_BOX_LEFT
	mov ah, INSTRUCTIONS_BOX_CONTENTS_HEIGHT
	mov al, INSTRUCTIONS_BOX_CONTENTS_WIDTH
	call common_draw_box

	add bl, 13
	mov si, instructionsTitleString
	mov dl, COMMON_FONT_COLOUR_CYAN | COMMON_BACKGROUND_COLOUR_BLACK
	call common_draw_box_title

	mov bh, INSTRUCTIONS_BOX_TOP + 1
	mov bl, INSTRUCTIONS_BOX_LEFT + 2
	int 9Eh					; move cursor
	mov si, readFileInstructionString
	int 97h					; print
	
	mov bh, INSTRUCTIONS_BOX_TOP + 2
	int 9Eh					; move cursor
	mov si, writeFileInstructionString
	int 97h					; print
	
	mov bh, INSTRUCTIONS_BOX_TOP + 3
	int 9Eh					; move cursor
	mov si, viewInstructionString
	int 97h					; print
	
	mov bh, INSTRUCTIONS_BOX_TOP + 4
	int 9Eh					; move cursor
	mov si, rescanInstructionString
	int 97h					; print
	
	mov bh, INSTRUCTIONS_BOX_TOP + 5
	int 9Eh					; move cursor
	mov si, deleteInstructionString
	int 97h					; print
	
	cmp byte [cs:availableDiskCount], 1
	jbe draw_instructions_box_after_change_disk		; one disk is available
													; so we can't change it
	mov bh, INSTRUCTIONS_BOX_TOP + 6
	int 9Eh					; move cursor
	mov si, changeDiskString
	int 97h					; print
	
draw_instructions_box_after_change_disk:

	mov bh, INSTRUCTIONS_BOX_TOP + 8
	int 9Eh					; move cursor
	mov si, pagingInstructionString
	int 97h					; print
	
	mov bh, INSTRUCTIONS_BOX_TOP + 9
	int 9Eh					; move cursor
	mov si, cursorInstructionString
	int 97h					; print
	
	mov bh, INSTRUCTIONS_BOX_TOP + 11
	int 9Eh					; move cursor
	mov si, exitInstructionString
	int 97h					; print
	
	popa
	ret


; Prints "previous page" label, if a previous page is available
;
print_previous_page_label:
	pusha
	
	call has_previous_page
	cmp ax, 1							; do we have a previous page?
	jne print_previous_page_label_done	; no
	; we have a previous page, so print the label
	mov bh, PREVIOUS_LABEL_TOP
	mov bl, PREVIOUS_LABEL_LEFT
	int 9Eh						; move cursor
	
	mov dl, COMMON_FONT_COLOUR_GREEN | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, PREVIOUS_LABEL_LENGTH	; this many characters
	int 9Fh							; attributes
	
	mov si, previousPageLabelString
	int 97h

	call hide_video_cursor
print_previous_page_label_done:
	popa
	ret


; Prints "next page" label, if a next page is available
;	
print_next_page_label:
	pusha
	
	call has_next_page
	cmp ax, 1						; do we have a next page?
	jne print_next_page_label_done	; no
	; we have a next page, so print the label
	mov bh, NEXT_LABEL_TOP
	mov bl, NEXT_LABEL_LEFT
	int 9Eh						; move cursor
	
	mov dl, COMMON_FONT_COLOUR_GREEN | COMMON_BACKGROUND_COLOUR_BLACK
	mov cx, NEXT_LABEL_LENGTH	; this many characters
	int 9Fh							; attributes
	
	mov si, nextPageLabelString
	int 97h

	call hide_video_cursor
print_next_page_label_done:
	popa
	ret


; Redraws screen
;	
redraw:
	pusha
	push ds
	push es
	
	int 0A0h					; clear screen
	
	call draw_file_box
	call draw_outer_screen_box
	call draw_disk_status_box
	call draw_loaded_file_box	
	call draw_instructions_box
	
	pop es
	pop ds
	popa
	ret

	
; Functionality for initialization exists in its own routine so that it can 
; be called again if the user swaps disks
;
initialize:
	pushf
initialize_after_pushes:
	call redraw
	
	cld
	mov di, rootDirectory
	mov cx, DIRECTORY_SIZE
	mov al, 0
	rep stosb					; zero out root directory
	
	mov di, pageStartBookmarks
	mov cx, MAX_PAGES
	mov ax, 0
	rep stosw					; zero out page start bookmarks
	
	mov di, rootDirectory		; load root directory to ES:DI
	int 87h
	
	mov ax, NUM_DIRECTORY_ENTRIES	; AX := total file slots count
	int 0A1h						; CX := free file slots count
	sub ax, cx						; AX := number of file slots in use
	mov dl, PAGE_SIZE
	div dl							; AL := file count div PAGE_SIZE
									; AH := file count mod PAGE_SIZE
	cmp ah, 0
	je initialize_store_page_count	; if remainder is 0, store quotient
	inc al							;     else quotient++
initialize_store_page_count:
	mov ah, 0						; AX := AL
	mov word [numTotalPages], ax	; store page count
	
	mov word [numFilesOnCurrentPage], 0
	mov word [cursorIndex], 0
	mov word [currentPage], 0
	mov di, pageStartBookmarks
	
	mov si, rootDirectory		; DS:SI now points to start of root directory

	; move page forward to reach first page
	call try_page_forward				; DX := number of files on first page
	cmp dx, 0							; when disk is empty, DX = 0
	jne initialize_disk_not_empty		; if disk not empty, continue
	
	; disk is empty, so prompt user for action
	call print_disk_empty				; print message
initialize_disk_empty_wait_for_key:
	mov ah, 0
	int 16h					; block and read key, AH := scan code, AL := ASCII
	
initialize_disk_empty_check_f5:
	cmp ah, COMMON_SCAN_CODE_F5
	je initialize_after_pushes	; if user presses "re-scan", then re-initialize

initialize_disk_empty_check_esc:
	cmp ah, COMMON_SCAN_CODE_ESCAPE
	je initialize_exit_program	; if user presses ESCAPE, then exit program
	
initialize_disk_empty_check_f10:
	cmp byte [cs:availableDiskCount], 1
	jbe initialize_disk_empty_check_f2	; NOOP when we have fewer than 2 disks
	
	cmp ah, COMMON_SCAN_CODE_F10
	jne initialize_disk_empty_check_f2
	; if user presses "change disk", then do that and then re-initialize
	call handle_change_disk
	jmp initialize_after_pushes
								
initialize_disk_empty_check_f2:
	cmp ah, COMMON_SCAN_CODE_F2
	jne initialize_disk_empty_next_key
	
	call handle_write_file		; if user pressed F2, write the loaded file
	cmp ax, 0						; did we actually write the file?
	je initialize_after_pushes		; yes, so re-initialize
									; no, so read next key
initialize_disk_empty_next_key:
	jmp initialize_disk_empty_wait_for_key
initialize_exit_program:
	mov bx, word [allocatedSegment]
	int 92h							; deallocate memory
	jmp exit_program
initialize_disk_not_empty:
	; continue initialization	
	int 83h							; clear keyboard buffer
	
	popf
	ret

	
; Convert a hex digit to its character representation
; Example: 10 -> 'A'
;
; input:
;		AL - hex digit
; output:
;		CL - hex digit to char
hex_digit_to_char:
	push ax
	cmp al, 9
	jbe hex_digit_to_char_under9
	add al, 7		; offset in ASCII table from '0' to 'A'
					; minus 9 (since 10 must map to 'A')
hex_digit_to_char_under9:
	add al, '0'
	mov cl, al
	pop ax
	ret
	
	
; Renders a byte as two hex digit characters
; Example: 20 -> "1" "8"
;
; input:
;		AL - byte to render
; output:
;		CX - two characters which represent the input
byte_to_hex:
	push ax
	push bx
	push dx
	
	mov ah, 0
	mov bl, 16
	div bl			; quotient in AL, remainder in AH
	
	call hex_digit_to_char		; CL := char
	mov ch, cl
	mov al, ah
	call hex_digit_to_char		; CL := char
	
	pop dx
	pop bx
	pop ax
	ret
	
	
; Reached via JMP
exit_program:
	mov al, byte [cs:initialDiskId]
	int 0C3h							; restore disk
	int 95h


%include "common\scancode.asm"
%include "common\colours.asm"
%include "common\textbox.asm"
%include "common\viewtext.asm"

rootDirectory: 					; we'll load the root directory here
