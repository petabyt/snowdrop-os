;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains fundamental definitions for Snowdrop OS's assembler.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_ASM_DEFS_
%define _COMMON_ASM_DEFS_

ASM_TOKEN_MAX_LENGTH				equ 64
ASM_CHAR_LINE_ENDING				equ COMMON_ASCII_LINE_FEED
ASM_CHAR_STRING_DELIMITER			equ COMMON_ASCII_DOUBLEQUOTE
ASM_CHAR_INSTRUCTION_DELIMITER		equ ';'
ASM_CHAR_LABEL_DELIMITER			equ ':'
ASM_CHAR_ARGUMENT_DELIMITER			equ ','
ASM_CHAR_CONST_ASSIGNMENT			equ '='
ASM_CHAR_POINTER_BRACKET_OPEN		equ '['
ASM_CHAR_POINTER_BRACKET_CLOSE		equ ']'

ASM_VAR_NAME_MAX_LENGTH				equ 32	; do NOT change this value without
											; changing variable storage scheme
ASM_LABEL_NAME_MAX_LENGTH			equ ASM_VAR_NAME_MAX_LENGTH

asmNewlineToken:				db ASM_CHAR_LINE_ENDING, 0
asmInstructionDelimiterToken:	db ASM_CHAR_INSTRUCTION_DELIMITER, 0
asmArgumentDelimiterToken:		db ASM_CHAR_ARGUMENT_DELIMITER, 0

asmIgnoredTokenChars:			; the tokenizer ignores these characters
	db COMMON_ASCII_BLANK
	db COMMON_ASCII_TAB
	db COMMON_ASCII_CARRIAGE_RETURN
asmIgnoredTokenCharsCount equ $ - asmIgnoredTokenChars

asmStopTokenChars:			; the tokenizer stops on these characters
	db ASM_CHAR_INSTRUCTION_DELIMITER
	db ASM_CHAR_ARGUMENT_DELIMITER
	db ASM_CHAR_CONST_ASSIGNMENT
	db ASM_CHAR_POINTER_BRACKET_OPEN
	db ASM_CHAR_POINTER_BRACKET_CLOSE
asmStopTokenCharsCount equ $ - asmStopTokenChars

asmCurrentToken:			times ASM_TOKEN_MAX_LENGTH+1 db 0

TOKEN_PARSE_NONE_LEFT	equ 0
TOKEN_PARSE_PARSED		equ 1
TOKEN_PARSE_ERROR		equ 2

asmProgramTextSeg:		dw 0
asmProgramTextOff:		dw 0
asmOutputBufferSeg:		dw 0
asmOutputBufferOff:		dw 0

asmMoreTokensAvailable:	db 1
asmProgramTextPointerBeforeProcessing:	dw 0

ASM_PASS_1_DUMMY_ADDRESS	equ 5555
ASM_PASS_0			equ 0					; origin and "pure" CONST resolution pass
ASM_PASS_1			equ 1					; label resolution pass
ASM_PASS_2			equ 2					; final bytecode generation
asmPass				db 99

ASM_NUMBER_FORMAT_BINARY	equ 0
ASM_NUMBER_FORMAT_HEX		equ 1
ASM_NUMBER_FORMAT_DECIMAL	equ 2

asmCurrentLineNumber:						dw 1
asmCurrentInstructionNumber:				dw 1

asmInterpretationEndMessagePtr: dw 0		; pointer to string

asmNewline:				db 13, 10, 0
asmMessagePrefix1:		db '[ASM ', 0
asmMessagePrefix2:		db ',', 0
asmMessagePrefix3:		db ' at ', 0
asmMessagePrefix4:		db '] ', 0

asmMessageEmpty:			db 0
asmMessageNewline:		db 13, 10, 0
asmMessageStatusError:	db 'ERROR: ', 0
asmMessageStatusOk:		db 'Completed successfully', 0
asmMessageTooManyInstructionTokens:	db 'Instruction token limit exceeded', 0
asmMessageExpectedKeywordOrNewlineOrLabel:	db 'Expected keyword, label, or new line', 0
asmMessageExpectedKeywordOrNewline:	db 'Expected keyword or new line', 0
asmInvalidSyntax:		db 'Invalid syntax', 0
asmMessageInvalidState:	db 'Invalid state', 0
asmMessageUnknownError:	db 'Unknown error', 0
asmMessageLabelNotUnique:	db 'Duplicate label detected', 0
asmMessageInvalidAssignedVariableName:	db 'Invalid constant name', 0
asmConstantRedefined:		db 'Constant redefined', 0
asmMessageNeedOpcode:	db 'Need opcode or pseudo opcode (db, etc.) after times', 0
asmMessageTimesMultiplierMustBeNumeric:	db 'Times multiplier must be numeric', 0
asmMessageUnsupportedExpressionTokenCount:	db 'Unsupported number of tokens in expression', 0
asmMessageVariableNotFound:	db 'Undefined symbol', 0
asmMessageInvalidVariableName:	db 'Undefined symbol', 0
asmConstantValueMustBeNumeric:	db 'Constant value must be numeric', 0
asmMessageUnknownOperator:	db 'Unknown operator', 0
asmMessageUnknownFunction:	db 'Unknown function', 0
asmMessageOperatorNotSupported:	db 'Operator not supported for operand type(s)', 0
asmMessageIntegerDivideByZero:	db 'Integer division by zero', 0
asmMessageMissingEqualsSign:	db 'Missing equals sign', 0
asmMessageVariablesFull:	db 'Cannot define any more constants and labels', 0
asmMessageInvalidLabelName:	db 'Invalid label name', 0
asmMessageArgumentMustBeString:	db 'Expression must be of type string', 0
asmMessageArgumentMustBeNumeric:	db 'Expression must be numeric', 0
asmMessageNoComma:	db 'Missing comma', 0
asmMessageArgumentMustBeByte: db 'Expression must be between 0 and 255, inclusive', 0
asmMessageShiftAmountMustBeByte:	db 'Shift amount must be between 0 and 255, inclusive', 0
asmMessageFirstArgumentMustBeNumber:	db 'First argument must be numeric', 0
asmMessageSecondArgumentMustBeString:	db 'Second argument must be a string', 0
asmMessageTokenTooLong:		db 'Token too long', 0
asmMessageTokenMustBeQSL:		db 'Token must be a quoted string literal', 0
asmMessageCannotSetOriginMoreThanOnce:	db 'Cannot set origin more than once', 0
asmMessageCannotSetOriginAfterEmittedBytes:	db 'Cannot set origin once any bytes have been emitted', 0
asmMessageTokenMustBeASingleNumber:	db 'Origin value must be a single number', 0
asmMessageWarnListingOffsetOverflow:	db 'Warning: listing buffer overflowed beyond FFFF', 13, 10, 0
asmMessageErrorBytecodeOffsetOverflow:	db 'Error: bytecode output buffer would overflow its segment, so assembly was halted', 0
asmMessageWarnSingleByteOverflow:		db 'Warning: multi-byte value was downcast to a single byte', 13, 10, 0

asmSymbolEquals:		db '=', 0
asmSymbolComma:			db ',', 0

asmDebugMsgLastTokenMessage:		db 'Last parsed token: ', 0
asmDebugMsgLastInstructionMessage:	db 'Last parsed instruction: ', 0
asmDebugMsgTokenQuote:				db '"', 0
asmDebugMsgBlank:					db ' ', 0

ASM_EVAL_TYPE_STRING		equ 0
ASM_EVAL_TYPE_NUMBER		equ 1

ASM_OPERATOR_PLUS			equ 0
ASM_OPERATOR_MINUS			equ 1
ASM_OPERATOR_DIVIDE			equ 2
ASM_OPERATOR_MULTIPLY		equ 3
ASM_OPERATOR_MODULO			equ 4
ASM_OPERATOR_BITAND			equ 14
ASM_OPERATOR_BITOR			equ 15
ASM_OPERATOR_BITXOR			equ 16
ASM_OPERATOR_BITSHIFTL		equ 17
ASM_OPERATOR_BITSHIFTR		equ 18

asmOperatorPlus:			db '+', 0
asmOperatorMinus:			db '-', 0
asmOperatorDivide:			db '/', 0
asmOperatorMultiply:		db '*', 0
asmOperatorModulo:			db '%', 0

asmOperatorBitAnd:			db '&', 0
asmOperatorBitOr:			db '|', 0
asmOperatorBitXor:			db '^', 0
asmOperatorBitShiftL:		db '<<', 0
asmOperatorBitShiftR:		db '>>', 0

; used to evaluate expressions
asmEvalOperatorType:				dw 99
asmEvalLeftOperandType:				dw 99
asmEvalLeftOperandNumericValue:		dw 99
asmEvalRightOperandType:			dw 99
asmEvalRightOperandNumericValue:	dw 99

asmEvalFunctionType:				dw 99
asmEvalRightArgumentType:			dw 99
asmEvalRightArgumentNumericValue:	dw 99
asmEvalLeftArgumentType:			dw 99
asmEvalLeftArgumentNumericValue:	dw 99
asmEvalThirdArgumentType:			dw 99
asmEvalThirdArgumentNumericValue:	dw 99

asmExeTwoNumericExpressionsCommaTokenIndex:	db 99
asmExeTwoNumericExpressionsFirstValue:		dw 99
asmExeIntStringCommaTokenIndex:				db 99
asmExeIntStringExpressionsFirstValue:		dw 99


; used to store temporary expression evaluation results
asmExecutionExpressionType:	dw 0
asmExecutionNumericValue:	dw 0
asmExecutionStringValue0:	times ASM_TOKEN_MAX_LENGTH+1 db 0

asmItoaBuffer:			times 32 db 0
asmPrivateOnlyBuffer0:	times ASM_TOKEN_MAX_LENGTH+1 db 0
				; a buffer that cannot be referenced by pointers which are
				; function arguments or return values

asmInterpreterParserResumePoint:	dw 0
				; near pointer to resume point
				; used by instruction execution to branch
				; used instead of the stack to reduce the number of push/pops
											
asmState:				db 99	; the interpreter state, modified by various
								; token types (newline, keyword, etc.)
ASM_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL				equ 0
							; we've just seen a newline, instruction delimiter,
							; or are at the beginning of the program text
ASM_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT	equ 2
							; we've just seen a keyword, and are now
							; accumulating the rest of the instruction


; these store the tokens of the instruction currently being read (token by 
; token), or being executed
ASM_MAX_INSTRUCTION_TOKENS	equ 32			; this must be less than 250
asmCurrentKeyword:	times ASM_TOKEN_MAX_LENGTH+1 db 0
asmCurrentInstTokens: times (ASM_TOKEN_MAX_LENGTH+1)*ASM_MAX_INSTRUCTION_TOKENS db 0
asmCurrentInstTokenCount:	db 0
asmPreviousKeyword:	times ASM_TOKEN_MAX_LENGTH+1 db 0

asmLastInstructionBuffer: times (ASM_TOKEN_MAX_LENGTH+1)*(ASM_MAX_INSTRUCTION_TOKENS+1) db 65

; used by the evaluation logic to store intermediate results
asmEvalBuffer0:	times ASM_TOKEN_MAX_LENGTH+1 db 0
asmEvalBuffer1:	times ASM_TOKEN_MAX_LENGTH+1 db 0

; keywords
asmKeywordStart:	; BEGINNING marker
asmKeywordPrint:	db 'PRINT', 0
asmKeywordConst:	db 'CONST', 0
asmKeywordDw:		db 'DW', 0
asmKeywordDb:		db 'DB', 0
asmKeywordTimes:	db 'TIMES', 0
asmKeywordComment:	db '`', 0
asmKeywordOrg:		db 'ORG', 0
; x86-specific opcodes below
asmx86KeywordInt:	db 'INT', 0
asmx86KeywordMov:	db 'MOV', 0
asmx86KeywordJmp:	db 'JMP', 0

asmx86KeywordAdd:	db 'ADD', 0
asmx86KeywordOr:	db 'OR', 0
asmx86KeywordAdc:	db 'ADC', 0
asmx86KeywordSbb:	db 'SBB', 0
asmx86KeywordAnd:	db 'AND', 0
asmx86KeywordSub:	db 'SUB', 0
asmx86KeywordXor:	db 'XOR', 0
asmx86KeywordCmp:	db 'CMP', 0

asmx86KeywordRol:	db 'ROL', 0
asmx86KeywordRor:	db 'ROR', 0
asmx86KeywordRcl:	db 'RCL', 0
asmx86KeywordRcr:	db 'RCR', 0
asmx86KeywordShl:	db 'SHL', 0
asmx86KeywordSal:	db 'SAL', 0
asmx86KeywordShr:	db 'SHR', 0
asmx86KeywordSar:	db 'SAR', 0

asmx86KeywordJo:	db 'JO', 0
asmx86KeywordJno:	db 'JNO', 0
asmx86KeywordJs:	db 'JS', 0
asmx86KeywordJns:	db 'JNS', 0
asmx86KeywordJe:	db 'JE', 0
asmx86KeywordJz:	db 'JZ', 0
asmx86KeywordJne:	db 'JNE', 0
asmx86KeywordJnz:	db 'JNZ', 0
asmx86KeywordJb:	db 'JB', 0
asmx86KeywordJnae:	db 'JNAE', 0
asmx86KeywordJc:	db 'JC', 0
asmx86KeywordJnb:	db 'JNB', 0
asmx86KeywordJae:	db 'JAE', 0
asmx86KeywordJnc:	db 'JNC', 0
asmx86KeywordJbe:	db 'JBE', 0
asmx86KeywordJna:	db 'JNA', 0
asmx86KeywordJa:	db 'JA', 0
asmx86KeywordJnbe:	db 'JNBE', 0
asmx86KeywordJl:	db 'JL', 0
asmx86KeywordJnge:	db 'JNGE', 0
asmx86KeywordJge:	db 'JGE', 0
asmx86KeywordJnl:	db 'JNL', 0
asmx86KeywordJle:	db 'JLE', 0
asmx86KeywordJng:	db 'JNG', 0
asmx86KeywordJg:	db 'JG', 0
asmx86KeywordJnle:	db 'JNLE', 0
asmx86KeywordJp:	db 'JP', 0
asmx86KeywordJpe:	db 'JPE', 0
asmx86KeywordJnp:	db 'JNP', 0
asmx86KeywordJpo:	db 'JPO', 0
asmx86KeywordJcxz:	db 'JCXZ', 0
asmx86KeywordCall:	db 'CALL', 0
asmx86KeywordRet:	db 'RET', 0
asmx86KeywordRetf:	db 'RETF', 0
asmx86KeywordIret:	db 'IRET', 0
asmx86KeywordPush:	db 'PUSH', 0
asmx86KeywordPop:	db 'POP', 0
asmx86KeywordPusha:	db 'PUSHA', 0
asmx86KeywordPopa:	db 'POPA', 0
asmx86KeywordPushf:	db 'PUSHF', 0
asmx86KeywordPopf:	db 'POPF', 0
asmx86KeywordClc:	db 'CLC', 0
asmx86KeywordStc:	db 'STC', 0
asmx86KeywordCli:	db 'CLI', 0
asmx86KeywordSti:	db 'STI', 0
asmx86KeywordCld:	db 'CLD', 0
asmx86KeywordStd:	db 'STD', 0
asmx86KeywordInc:	db 'INC', 0
asmx86KeywordDec:	db 'DEC', 0
asmx86KeywordMul:	db 'MUL', 0
asmx86KeywordImul:	db 'IMUL', 0
asmx86KeywordDiv:	db 'DIV', 0
asmx86KeywordIdiv:	db 'IDIV', 0
asmx86KeywordIn:	db 'IN', 0
asmx86KeywordOut:	db 'OUT', 0

asmx86KeywordMovsb:	db 'MOVSB', 0
asmx86KeywordLodsb:	db 'LODSB', 0
asmx86KeywordStosb:	db 'STOSB', 0
asmx86KeywordCmpsb:	db 'CMPSB', 0
asmx86KeywordScasb:	db 'SCASB', 0

asmx86KeywordMovsw:	db 'MOVSW', 0
asmx86KeywordLodsw:	db 'LODSW', 0
asmx86KeywordStosw:	db 'STOSW', 0
asmx86KeywordCmpsw:	db 'CMPSW', 0
asmx86KeywordScasw:	db 'SCASW', 0

asmx86KeywordRep:	db 'REP', 0
asmx86KeywordRepe:	db 'REPE', 0
asmx86KeywordRepne:	db 'REPNE', 0
asmx86KeywordRepz:	db 'REPZ', 0
asmx86KeywordRepnz:	db 'REPNZ', 0

asmx86KeywordTest:	db 'TEST', 0
asmx86KeywordXchg:	db 'XCHG', 0
asmx86KeywordHlt:	db 'HLT', 0
asmx86KeywordNop:	db 'NOP', 0
asmx86KeywordCmc:	db 'CMC', 0

asmx86KeywordSahf:	db 'SAHF', 0
asmx86KeywordLahf:	db 'LAHF', 0
asmx86KeywordSalc:	db 'SALC', 0

asmx86KeywordInt3:	db 'INT3', 0
asmx86KeywordInto:	db 'INTO', 0
asmx86KeywordLeave:	db 'LEAVE', 0
asmx86KeywordXlat:	db 'XLAT', 0
asmx86KeywordXlatb:	db 'XLATB', 0
asmx86KeywordCbw:	db 'CBW', 0
asmx86KeywordCwd:	db 'CWD', 0
asmx86KeywordRetn:	db 'RETN', 0

asmx86KeywordLoop:	db 'LOOP', 0
asmx86KeywordLoope:	db 'LOOPE', 0
asmx86KeywordLoopz:	db 'LOOPZ', 0
asmx86KeywordLoopne:	db 'LOOPNE', 0
asmx86KeywordLoopnz:	db 'LOOPNZ', 0

asmKeywordEnd:		; END marker

; reserved symbols:
asmReservedSymbolsStart:		; marker
asmReservedSymbolDollar:		db '$', 0
asmReservedSymbolDollarDollar:	db '$$', 0
asmReservedSymbolsEnd:			; marker


ASM_STATE_NONRESUMABLE_SUCCESS	equ 1	; reached the end of the program
											; a non-error halt, such as STOP,
											; or user-requested via keyboard
ASM_STATE_NONRESUMABLE_ERROR	equ 2	; an error occurred


asmInterpreterState:	db ASM_STATE_NONRESUMABLE_SUCCESS
				; an end-of-the-line state, making it necessary to initialize

%endif
