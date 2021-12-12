;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains help pages for Snowdrop OS's x86 assembler.
;
; It is meant to be included only when the consumer wants to 
; display x86 assembler help.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASMX86_HELP_
%define _COMMON_ASMX86_HELP_


asmx86HelpPage:
	db 'Snowdrop OS x86 assembler help page', 13, 10
	db '-----------------------------------', 13, 10
	db 13, 10
	db 'Non-CPU specific symbols: CONST, ORG, TIMES, DB, DW, $, $$', 13, 10
	db 13, 10
	db 'MOV: supports sources: sreg16, reg, imm, mem', 13, 10
	db '     supports destination: sreg16, reg, mem', 13, 10
	db 'where mem can be [sreg16 : imm16] or [sreg16 : reg16]', 13, 10
	db 'examples: mov ax, word [cs : 1234h];', 13, 10
	db '          mov cl, byte [ds : si];', 13, 10
	db '          mov word [ds : si], 1100b;', 13, 10
	db '          mov al, byte [ss : 500];', 13, 10
	db 13, 10
	db 'All other two-operand opcodes support only sources: reg, imm', 13, 10
	db '                              support only destinations: reg', 13, 10
	db 'Single operand opcodes support only: reg', 13, 10
	db 13, 10
	db 'Comment example: `"this is a comment";', 13, 10
	db 13, 10
	db 13, 10
	db 'List of supported opcodes', 13, 10
	db '-------------------------', 13, 10
	db 'General data transfer: MOV, XCHG, XLAT, XLATB, CBW, CWD', 13, 10
	db 13, 10
	db 'Logic and arithmetic:  INC, DEC, MUL, IMUL, DIV, IDIV, ADD, OR, ADC, SBB, AND,', 13, 10
	db '                       SUB, XOR, ROL, ROR, RCL, RCR, SHL, SAL, SHR, SAR', 13, 10
	db 13, 10
	db 'Conditional branching: CMP, TEST, JMP, JO, JNO, JS, JNS, JE, JZ, JNE, JNZ, JB,', 13, 10
	db '                       JNAE, JC, JNB, JAE, JNC, JBE, JNA, JA, JNBE, JL, JNGE,', 13, 10
	db '                       JGE, JNL, JLE, JNG, JG, JNLE, JP, JPE, JNP, JPO, JCXZ,', 13, 10
	db '                       LOOP, LOOPE, LOOPZ, LOOPNE, LOOPNZ', 13, 10
	db 13, 10
	db 'Procedures:            CALL, RET, RETF, IRET, INT, INT3, INTO, LEAVE, RETN', 13, 10
	db 13, 10
	db 'Stack operations:      PUSH, POP, PUSHA, POPA, PUSHF, POPF', 13, 10
	db 13, 10
	db 'String operations:     MOVSB, LODSB, STOSB, CMPSB, SCASB, MOVSW, LODSW, STOSW,', 13, 10
	db '                       CMPSW, SCASW, REP, REPE, REPNE, REPZ, REPNZ', 13, 10
	db 13, 10
	db 'Flag operations:       CLC, STC, CLI, STI, CLD, STD, CMC, SAHF, LAHF, SALC', 13, 10
	db 13, 10
	db 'Miscellaneous: IN, OUT, HLT, NOP', 13, 10
	db 0


; Displays the help page for the assembler
;
; input:
;		none
; output:
;		none
asmx86_help:
	pusha
	push ds
	
	push cs
	pop ds
	mov si, asmx86HelpPage

	int 0A5h							; BX := string length
	mov cx, bx
	mov ax, 0							; don't wait for user input at end
	call common_text_view_paged
	
	pop ds
	popa
	ret

	
%include "common\viewtext.asm"

%endif
