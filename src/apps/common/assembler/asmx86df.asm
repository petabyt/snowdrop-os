;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains definitions for Snowdrop OS's assembler.
;
; Contents of this file are x86-specific.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_X86_DEF_
%define _COMMON_ASM_X86_DEF_


ASMX86_REG_AX		equ 0
ASMX86_REG_BX		equ 1
ASMX86_REG_CX		equ 2
ASMX86_REG_DX		equ 3
ASMX86_REG_SI		equ 4
ASMX86_REG_DI		equ 5
ASMX86_REG_SP		equ 6
ASMX86_REG_BP		equ 7

ASMX86_REG_AL		equ 8
ASMX86_REG_AH		equ 9
ASMX86_REG_BL		equ 10
ASMX86_REG_BH		equ 11
ASMX86_REG_CL		equ 12
ASMX86_REG_CH		equ 13
ASMX86_REG_DL		equ 14
ASMX86_REG_DH		equ 15

ASMX86_REG_CS		equ 16
ASMX86_REG_SS		equ 17
ASMX86_REG_DS		equ 18
ASMX86_REG_ES		equ 19
ASMX86_REG_FS		equ 20
ASMX86_REG_GS		equ 21

ASMX86_REG_AL_AX_ENCODING		equ 0

asmx86RegAx:		db 'AX', 0
asmx86RegBx:		db 'BX', 0
asmx86RegCx:		db 'CX', 0
asmx86RegDx:		db 'DX', 0
asmx86RegSi:		db 'SI', 0
asmx86RegDi:		db 'DI', 0
asmx86RegSp:		db 'SP', 0
asmx86RegBp:		db 'BP', 0

asmx86RegAl:		db 'AL', 0
asmx86RegAh:		db 'AH', 0
asmx86RegBl:		db 'BL', 0
asmx86RegBh:		db 'BH', 0
asmx86RegCl:		db 'CL', 0
asmx86RegCh:		db 'CH', 0
asmx86RegDl:		db 'DL', 0
asmx86RegDh:		db 'DH', 0

asmx86RegCs:		db 'CS', 0
asmx86RegSs:		db 'SS', 0
asmx86RegDs:		db 'DS', 0
asmx86RegEs:		db 'ES', 0
asmx86RegFs:		db 'FS', 0
asmx86RegGs:		db 'GS', 0

asmx86RegIp:		db 'IP', 0

asmx86MessageCantExecuteUnknownOpcode:	db 'Unknown opcode or unsupported register/memory/immediate combination', 0
asmx86MessageExpressionMustBeNumeric:			db 'Expression must be numeric', 0
asmx86MessageUnsupportedExpressionTokenCount:	db 'Unsupported number of tokens in expression', 0
asmx86MessageUnsupportedOperands:		db 'Unsupported combination of operands', 0
asmx86MessageInappropriateSuffix:		db 'Inappropriate suffix for given prefix', 0
asmx86MessageExpectedNoArguments:		db 'Expected no arguments', 0

ASMX86_REG_IS_VALID_OFFSET					equ 00000001b

ASMX86_REG_IS_ASSIGNABLE_TO_SEG				equ 10000000b
ASMX86_REG_IS_SEGMENT						equ 01000000b
ASMX86_REG_CAN_RECEIVE_REG_OR_MEM_OR_POP	equ 00100000b
ASMX86_REG_IS_16BIT							equ 00010000b
ASMX86_REG_CAN_RECEIVE_IMM					equ 00001000b
ASMX86_REG_IS_8BIT							equ 00000000b

ASMX86_REG_MASK_ENCODING					equ 00000111b

asm86xMovImmediateSource:			dw 0
asm86xMovSourceRegisterTokenIndex:	db 0
asm86xMovSourceRegisterInfo:		db 0
asm86xMovSourceMemoryRegInfo:		dw 0
asm86xMovSourceMemoryImm16:			dw 0
asm86xMovSourceImm16:				dw 0
asm86xMovDestinationRegisterInfo:	db 0
asm86xMovSrcTokenRange:				dw 0
asm86xMovDestMemoryRegInfo:			dw 0
asm86xMovDestMemoryImm16:			dw 0
asm86xMovDestMemoryType:			dw 0
asm86xMovDestMemorySize:			db 0

asmx86SegmentOffsetSeparatorToken:	db ':', 0
asmx86OpenPointerBracket:			db '[', 0
asmx86ClosedPointerBracket:			db ']', 0

asmx86ReservedWord:			db 'word', 0
asmx86ReservedByte:			db 'byte', 0

asmx86TryResolveMemSegmentRegisterEncoding:		db 0

asmx86TryResolveMemFirstAndLastIndicesOfOffset:			dw 0
asmx86TryResolveMemFirstAndLastIndicesInsideBrackets:	dw 0
asmx86TryResolveMemResultSize:		db 0
ASMX86_MEM_REFERENCE_SIZE_16BIT		equ ASMX86_REG_IS_16BIT	
							; for easy size matching tests
ASMX86_MEM_REFERENCE_SIZE_8BIT		equ 00000000b

; opcode selectors for the ADD-rooted family of opcodes
ASMX86_ADD_FAMILY_DISPLACEMENT_ADD	equ 0
ASMX86_ADD_FAMILY_DISPLACEMENT_OR	equ 1
ASMX86_ADD_FAMILY_DISPLACEMENT_ADC	equ 2
ASMX86_ADD_FAMILY_DISPLACEMENT_SBB	equ 3
ASMX86_ADD_FAMILY_DISPLACEMENT_AND	equ 4
ASMX86_ADD_FAMILY_DISPLACEMENT_SUB	equ 5
ASMX86_ADD_FAMILY_DISPLACEMENT_XOR	equ 6
ASMX86_ADD_FAMILY_DISPLACEMENT_CMP	equ 7

asmx86TryResolveSimpleDestinationRegInfo:	db 0
asmx86EmitSimpleOpcodeRegReg:			db 0
asmx86EmitSimpleOpcodeRegImm:			db 0
asmx86EmitSimpleModrmExtensionRegImm:	db 0

ASMX86_OPCODE_FLAG_16BIT				equ 00000001b
ASMX86_OPCODE_FLAG_DESTINATION_REGISTER	equ 00000010b

asmx86EmitSimpleImm8SourceOpcodeRegImm:				db 0
asmx86EmitSimpleImm8SourceModrmExtensionRegImm:		db 0

ASMX86_ROL_FAMILY_DISPLACEMENT_ROL		equ 0
ASMX86_ROL_FAMILY_DISPLACEMENT_ROR		equ 1
ASMX86_ROL_FAMILY_DISPLACEMENT_RCL		equ 2
ASMX86_ROL_FAMILY_DISPLACEMENT_RCR		equ 3
ASMX86_ROL_FAMILY_DISPLACEMENT_SHL_SAL	equ 4		; these are equivalent
ASMX86_ROL_FAMILY_DISPLACEMENT_SHR		equ 5
ASMX86_ROL_FAMILY_DISPLACEMENT_SAR		equ 7

asmx86Emit2ByteOpcodeImm16Byte0:			db 0
asmx86Emit2ByteOpcodeImm16Byte1:			db 0
asmx86Emit2ByteOpcodeImm16Displacement:		dw 0

ASMX86_PUSHPOP_PUSH		equ 0
ASMX86_PUSHPOP_POP		equ 1

asmx86TryEmitPushPopSelector:			db 0

asmx86OutImm16Destination:				dw 0
asmx86OutCommaIndex:					db 0

ASMX86_REP_SUFFIX_FAMILY_MOVS		equ 0
ASMX86_REP_SUFFIX_FAMILY_LODS		equ 1
ASMX86_REP_SUFFIX_FAMILY_STOS		equ 2
ASMX86_REP_SUFFIX_FAMILY_CMPS		equ 3
ASMX86_REP_SUFFIX_FAMILY_SCAS		equ 4

asmx86EmitSimpleRegRegOpcodeRegReg:		db 0

asmx86Emit1ByteOpcodeImm8Byte0:			db 0
asmx86Emit1ByteOpcodeImm8Displacement:	dw 0	
	
%endif
