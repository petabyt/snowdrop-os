;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The BEAR app.
; This app displays a bear.
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
	
bearString:
	db "                       -/++/:                              :+shhy/              "
	db "                     +hNMMMMMmy:  ---:://osyyyyhhoo/:- -+dNMMMMNNNy:            "
	db "                   -yNMMMNNNNNMNhhNNNNMMMMMMMMMMMMMMNNdmMMMNNNNNNNMNs           "
	db "                   yMMNNNNmmmmNMMMMMMMMMMMMMMMMMMMMMMMMMMMNmmmmmmmmmms          "
	db "                  -NNNNmmmdhdNMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNmdddddddy-         "
	db "                  /NmmmddddNMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNdmmmdhs-         "
	db "                  :ddddhhmMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNmmdhs:          "
	db "                   oyyhdNMMMMMMMMNNmmmNMMMMMMMMMMNddhhmNMMMMMMMMMNds:           "
	db "                    +mNMMMMMMMMMNhyys+omMMMMMMMMNy+/::+hNNMMMMMMMMN+            "
	db "                   -dMMMMMMMMMMMmo:- -:yNMMMMMMMNs   --ymNNNNNNMMNNh            "
	db "                   sMMMMMMMMMMMMNh:  -+dNMMMMMMMNm+:-:odNNNNNNNNNNNm:           "
	db "                   mMMMMMMMMMMMMMNdhyhmMMMMMMMMMMMmdddmNNNNmmmmmmmmmo           "
	db "                   mNNNNNNNNNNNMMMMMMMMMMMMMMMMMMMMMNNNNNNmmmmmmmmmd+           "
	db "                   mNNNNmmmmNNNNNNMMMMMMMMMMMMMMMMMMMNmmmmmddddddddh:           "
	db "                   hmmmddhhdmmmmmNMMMMMMMMMMMMMMMMMMMMmddddddddhhhhs            "
	db "                   /ddmdhhyhddddmMMMMMMMMmhyssosydNNNNmdddhhhhhhhhh:            "
	db "                    +hddhhyyhhhhmMMMMMMMh//:-----/dmmmmdhhhhhhhhhho             "
	db "                  :+osshdhyyyyyhdNMMMMNNdo:    :+yhddmmhyyyhhhhhho:             "
	db "                 +ys/--/ssyyyyyyhmNNNNmdhhys+/oyyhhhddhsssyyysso/::             "
	db "               :ssss+   -:/+osyssydmddhssysys+yyy+yhhy+:::/::::::::             "
	db "             -sysssso:   --:::/++++shhhs:/oss++o+syyo/:::::----:://-            "
	db "            /ssooosso+:  --::-- ----:/osso+oossss+:----:::::::::::/:            "
	db "           /sooosssso+++: ---:::::::::::-://::--:::::::::::://+++++/            "
	db 0
 
start:
	mov si, bearString
	int 80h
	
done:
	int 95h						; exit
