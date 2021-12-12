;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This file provides functionality common to multiple Snowdrop OS apps.
; It contains fundamental definitions for Snowdrop OS's BASIC interpreter.
;
; This file is part of the Snowdrop OS homebrew operating system
;			written by Sebastian Mihai, http://sebastianmihai.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%ifndef _COMMON_BASIC_DEFS_
%define _COMMON_BASIC_DEFS_

BASIC_TEXT_SCREEN_COLUMN_COUNT		equ 80
BASIC_TEXT_SCREEN_ROW_COUNT			equ 25

BASIC_TOKEN_MAX_LENGTH				equ 150
BASIC_CHAR_LINE_ENDING				equ COMMON_ASCII_LINE_FEED
BASIC_CHAR_STRING_DELIMITER			equ COMMON_ASCII_DOUBLEQUOTE
BASIC_CHAR_INSTRUCTION_DELIMITER	equ ';'
BASIC_CHAR_LABEL_DELIMITER			equ ':'
BASIC_CHAR_ARGUMENT_DELIMITER		equ ','

BASIC_VAR_NAME_MAX_LENGTH			equ 32
BASIC_LABEL_NAME_MAX_LENGTH			equ BASIC_VAR_NAME_MAX_LENGTH

basicNewlineToken:				db BASIC_CHAR_LINE_ENDING, 0
basicInstructionDelimiterToken:	db BASIC_CHAR_INSTRUCTION_DELIMITER, 0
basicArgumentDelimiterToken:	db BASIC_CHAR_ARGUMENT_DELIMITER, 0

basicOldKeyboardDriverMode:		dw 99

basicIgnoredTokenChars:			; the tokenizer ignores these characters
	db COMMON_ASCII_BLANK
	db COMMON_ASCII_TAB
	db COMMON_ASCII_CARRIAGE_RETURN
basicIgnoredTokenCharsCount equ $ - basicIgnoredTokenChars

basicStopTokenChars:			; the tokenizer stops on these characters
	db BASIC_CHAR_INSTRUCTION_DELIMITER
	db BASIC_CHAR_ARGUMENT_DELIMITER
basicStopTokenCharsCount equ $ - basicStopTokenChars

basicCurrentToken:			times BASIC_TOKEN_MAX_LENGTH+1 db 0

TOKEN_PARSE_NONE_LEFT	equ 0
TOKEN_PARSE_PARSED		equ 1
TOKEN_PARSE_ERROR		equ 2

basicProgramTextSeg:		dw 0
basicProgramTextOff:		dw 0
basicMoreTokensAvailable:	db 1
basicProgramTextPointerBeforeProcessing:	dw 0

basicTextAttribute:			db 99
basicHaltingDueToNonError:	db 0

basicBranchCacheLabel:		times BASIC_LABEL_NAME_MAX_LENGTH+1 db 0
basicBranchCacheNearPtr:	dw 0

basicCurrentLineNumber:						dw 1
basicCurrentInstructionNumber:				dw 1

basicInterpretationEndMessagePtr: dw 0		; pointer to string

basicNewline:				db 13, 10, 0
basicMessagePrefix1:		db '[BASIC ', 0
basicMessagePrefix2:		db ':', 0
basicMessagePrefix3:		db '] ', 0

basicMessageEmpty:			db 0
basicMessageNewline:		db 13, 10, 0
basicMessageStatusError:	db 'ERROR: ', 0
basicMessageStatusOk:		db 'Execution completed', 0
basicMessageTooManyInstructionTokens:	db 'Instruction token limit exceeded', 0
basicMessageExpectedKeywordOrNewlineOrLabel:	db 'Expected keyword, label, or new line', 0
basicMessageExpectedKeywordOrNewline:	db 'Expected keyword or new line', 0
basicMessageInvalidState:	db 'Invalid state', 0
basicMessageUnknownError:	db 'Unknown error', 0
basicMessageLabelNotUnique:	db 'Duplicate label detected', 0
basicMessageCantExecuteUnknownKeyword:	db 'Cannot execute unknown keyword', 0
basicMessageUnsupportedExpressionTokenCount:	db 'Unsupported number of tokens in expression', 0
basicMessageVariableNotFound:	db 'Undefined variable', 0
basicMessageInvalidVariableName:	db 'Invalid variable name', 0
basicMessageUnknownOperator:	db 'Unknown operator', 0
basicMessageUnknownFunction:	db 'Unknown function', 0
basicMessageOperatorNotSupported:	db 'Operator not supported for operand type(s)', 0
basicMessageIntegerOutOfRange:	db 'Integer out of range; allowed interval is [-32768, 32767]', 0
basicMessageIntegerDivideByZero:	db 'Integer division by zero', 0
basicMessageInvalidAssignedVariableName:	db 'Invalid assigned variable name', 0
basicMessageMissingEqualsSign:	db 'Missing equals sign', 0
basicMessageVariablesFull:	db 'Cannot define any more variables', 0
basicMessageMissingCannotAssignCounter:	db 'Cannot assign values to counter variables', 0
basicMessageInvalidLabelName:	db 'Invalid label name', 0
basicMessageLabelNotFound:	db 'Label not found', 0
basicMessageUserBreakRequest:	db 'User break request', 0
basicMessageTokenMustBeQSL:		db 'Token must be a quoted string literal', 0
basicMessageMissingTo:	db 'Missing TO token', 0
basicMessageCounterNotValidVariable:	db 'Loop counter must be a valid variable name', 0
basicMessageForToNotNumeric:	db 'TO expression must be numeric', 0
basicMessageForStepNotNumeric:	db 'STEP expression must be numeric', 0
basicMessageForInitialNotNumeric:	db 'Initial value must be numeric', 0
basicMessageCannotAllocateCounterVariable:	db 'Cannot allocate counter variable', 0
basicMessageNextNeedsCounterVariable:	db 'NEXT must be followed by a single token containing a counter variable name', 0
basicMessageConditionExpressionNotNumeric:	db 'Condition expression must be logical or numeric', 0
basicMessageIfThenNotFound:	db 'THEN not found', 0
basicMessageIfNestedIfs:	db 'Nested IF instructions are not supported', 0
basicMessageCallStackOverflow:	db 'CALL stack overflow', 0
basicMessageReturnStackUnderflow:	db 'Cannot RETURN without a prior CALL', 0
basicMessageArgumentMustBeString:	db 'Expression must be of type string', 0
basicMessageArgumentMustBeNumeric:	db 'Expression must be numeric', 0
basicMessageArgumentMustBePositive:	db 'Expression must be positive', 0
basicMessageArgumentMustNotBeNegative:	db 'Expression must not be negative', 0
basicMessageMustBeAVariable:	db 'Expression must be a variable', 0
basicMessageVariableCannotBeCounter:	db 'Variable cannot be a counter', 0
basicMessageInputValueNotNumeric:	db 'INPUTN value is not numeric', 0
basicMessageNoComma:	db 'Missing comma', 0
basicMessageAtRowOutOfBounds:	db 'AT row out of bounds', 0
basicMessageAtColumnOutOfBounds:	db 'AT column out of bounds', 0
basicMessageColoursBackgroundUnknown:	db 'Unsupported background colour', 0
basicMessageColoursFontUnknown:	db 'Unsupported font colour', 0
basicMessageArgumentMustBeByte: db 'Expression must be between 0 and 255, inclusive', 0
basicMessageShiftAmountMustBeByte:	db 'Shift amount must be between 0 and 255, inclusive', 0
basicMessageRotateAmountMustBeByte:	db 'Rotate amount must be between 0 and 255, inclusive', 0
basicMessageDurationMustBeByte: db 'Duration must be between 0 and 255, inclusive', 0
basicMessageFrequencyNumberOutOfBounds: db 'Frequency number must be between 100 and 30000, inclusive', 0
basicMessageStop:	db 'STOP instruction reached', 0
basicMessageArgumentMustBeSingleCharacterString: db 'Argument must be of type string, and contain one character', 0
basicMessageArgumentMustBeStringContainingNumber:	db 'Argument must be of type string, and contain an integer', 0
basicMessageArgumentMustContainBinaryNumber: db 'Argument contain a binary number of at most 16 digits', 0
basicMessageParallelDriverNotAvailable:	db 'Parallel port driver unavailable', 0
basicMessageParallelRegisterNumberOutOfBounds:	db 'Register number must be between 0 and 2, inclusive', 0
basicMessageParallelValueMustBeByte:	db 'Value to write must be between 0 and 255, inclusive', 0
basicMessageSerialDriverNotAvailable:	db 'Serial port driver unavailable', 0
basicMessageSerialValueMustBeByte:		db 'Value to write must be between 0 and 255, inclusive', 0
basicMessageFuncArgArg:	db 'Two-argument functions must be of the form <function> <arg1>, <arg2>', 0
basicMessageFuncArgArgArg:	db 'Three-argument functions must be of the form <function> <arg1>, <arg2>, <arg3>', 0
basicMessageCharAtRowOutOfBounds:	db 'CHARAT row out of bounds', 0
basicMessageCharAtColOutOfBounds:	db 'CHARAT column out of bounds', 0
basicMessageFirstArgumentMustBeNumber:	db 'First argument must be numeric', 0
basicMessageFirstArgumentMustBeString:	db 'First argument must be a string', 0
basicMessageSecondArgumentMustBeNumber:	db 'Second argument must be numeric', 0
basicMessageSecondArgumentMustBeString:	db 'Second argument must be a string', 0
basicMessageThirdArgumentMustBeNumber:	db 'Third argument must be numeric', 0
basicMessageSubstringIndexMustBeNonnegative:	db 'SUBSTRING start index must not be negative', 0
basicMessageSubstringLengthMustBeNonnegative:	db 'SUBSTRING length must not be negative', 0
basicMessageSubstringOverrun:	db 'SUBSTRING the sum of start index and substring length must not be greater than the length of the original string', 0
basicMessageStringAtPositionOutOfBounds:	db 'STRINGAT index out of bounds', 0
basicMessageCannotCallGuiBeginTwice:	db 'GUIBEGIN must be called at most once', 0
basicMessageGuiXOutOfBounds:			db 'X coord. must be between 0 and 639', 0
basicMessageGuiYOutOfBounds:			db 'Y coord. must be between 0 and 479', 0
basicMessageGuiAtDeltaXOutOfBounds:		db 'resulting X coord. must be between 0 and 639', 0
basicMessageGuiAtDeltaYOutOfBounds:		db 'resulting Y coord. must be between 0 and 479', 0
basicMessageGuiXMustBeNoLessThanCurrentX:	db 'Destination X coord. cannot be less than current X coord.', 0
basicMessageGuiYMustBeNoLessThanCurrentY:	db 'Destination Y coord. cannot be less than current Y coord.', 0
basicMessageTokenTooLong:		db 'Token too long', 0
basicMessageGuiExited:			db 'Execution completed - GUI exited', 0
basicMessageFirstArgMustBeASingleCharString: db 'First argument must be of type string, and contain one character', 0
basicMessageGuiPrepareFailed:	db 'GUI framework preparation failed (possibly because no mouse driver is present)', 0

basicFatalPrepareErrorNoMem:	db 13, 10, 'FATAL: BASIC requires the dynamic memory module to have been initialized.'
								db 13, 10, 'Press a key to abort BASIC interpreter preparation.'
								db 0

basicDebugMsgLastTokenMessage:			db 'Last parsed token: ', 0
basicDebugMsgLastInstructionMessage:	db 'Last parsed instruction: ', 0
basicDebugMsgTokenQuote:				db '"', 0
basicDebugMsgBlank:						db ' ', 0

BASIC_EVAL_TYPE_STRING		equ 0
BASIC_EVAL_TYPE_NUMBER		equ 1

BASIC_OPERATOR_PLUS				equ 0
BASIC_OPERATOR_MINUS			equ 1
BASIC_OPERATOR_DIVIDE			equ 2
BASIC_OPERATOR_MULTIPLY			equ 3
BASIC_OPERATOR_MODULO			equ 4
BASIC_OPERATOR_EQUALS			equ 5
BASIC_OPERATOR_GREATER			equ 6
BASIC_OPERATOR_LESS				equ 7
BASIC_OPERATOR_LESSOREQUAL		equ 8
BASIC_OPERATOR_GREATEROREQUAL	equ 9
BASIC_OPERATOR_DIFFERENT		equ 10
BASIC_OPERATOR_XOR				equ 11
BASIC_OPERATOR_OR				equ 12
BASIC_OPERATOR_AND				equ 13
BASIC_OPERATOR_BITAND			equ 14
BASIC_OPERATOR_BITOR			equ 15
BASIC_OPERATOR_BITXOR			equ 16
BASIC_OPERATOR_BITSHIFTL		equ 17
BASIC_OPERATOR_BITSHIFTR		equ 18
BASIC_OPERATOR_BITROTATEL		equ 19
BASIC_OPERATOR_BITROTATER		equ 20

basicOperatorPlus:				db '+', 0
basicOperatorMinus:				db '-', 0
basicOperatorDivide:			db '/', 0
basicOperatorMultiply:			db '*', 0
basicOperatorModulo:			db '%', 0

basicOperatorEquals:			db '=', 0
basicOperatorGreater:			db '>', 0
basicOperatorLess:				db '<', 0
basicOperatorLessOrEqual:		db '<=', 0
basicOperatorGreaterOrEqual:	db '>=', 0
basicOperatorDifferent:			db '<>', 0
basicOperatorAnd:				db 'AND', 0
basicOperatorOr:				db 'OR', 0
basicOperatorXor:				db 'XOR', 0
basicOperatorBitAnd:			db 'BITAND', 0
basicOperatorBitOr:				db 'BITOR', 0
basicOperatorBitXor:			db 'BITXOR', 0
basicOperatorBitShiftL:			db 'BITSHIFTL', 0
basicOperatorBitShiftR:			db 'BITSHIFTR', 0
basicOperatorBitRotateL:		db 'BITROTATEL', 0
basicOperatorBitRotateR:		db 'BITROTATER', 0

BASIC_FUNCTION_LEN				equ 0
BASIC_FUNCTION_RND				equ 1
BASIC_FUNCTION_KEY				equ 2
BASIC_FUNCTION_NOT				equ 3
BASIC_FUNCTION_CHR				equ 4
BASIC_FUNCTION_ASCII			equ 5
BASIC_FUNCTION_VAL				equ 6
BASIC_FUNCTION_BIN				equ 7
BASIC_FUNCTION_SERIALDATAAVAIL	equ 8
BASIC_FUNCTION_CHARAT			equ 9
BASIC_FUNCTION_SUBSTRING		equ 10
BASIC_FUNCTION_STRINGAT			equ 11
BASIC_FUNCTION_GUIACTIVEELEMENTID		equ 12
BASIC_FUNCTION_GUIBUTTONADD				equ 13
BASIC_FUNCTION_GUICHECKBOXADD			equ 14
BASIC_FUNCTION_GUICHECKBOXISCHECKED		equ 15
BASIC_FUNCTION_GUIRADIOADD				equ 16
BASIC_FUNCTION_GUIRADIOISSELECTED		equ 17
BASIC_FUNCTION_GUIIMAGEASCIIADD			equ 18
BASIC_FUNCTION_GUIIMAGEISSELECTED		equ 19

basicFunctionLen:				db 'LEN', 0
basicFunctionRnd:				db 'RND', 0
basicFunctionKey:				db 'KEY', 0
basicFunctionNot:				db 'NOT', 0
basicFunctionChr:				db 'CHR', 0
basicFunctionAscii:				db 'ASCII', 0
basicFunctionVal:				db 'VAL', 0
basicFunctionBin:				db 'BIN', 0
basicFunctionSerialDataAvail:	db 'SERIALDATAAVAIL', 0
basicFunctionCharAt:			db 'CHARAT', 0
basicFunctionSubstring:			db 'SUBSTRING', 0
basicFunctionStringAt:			db 'STRINGAT', 0

basicFunctionGuiActiveElementId:	db 'GUIACTIVEELEMENTID', 0
basicFunctionGuiButtonAdd:			db 'GUIBUTTONADD', 0
basicFunctionGuiCheckboxAdd:		db 'GUICHECKBOXADD', 0
basicFunctionGuiCheckboxIsChecked:	db 'GUICHECKBOXISCHECKED', 0
basicFunctionGuiRadioAdd:			db 'GUIRADIOADD', 0
basicFunctionGuiRadioIsSelected:	db 'GUIRADIOISSELECTED', 0
basicFunctionGuiImageAsciiAdd:		db 'GUIIMAGEASCIIADD', 0
basicFunctionGuiImageIsSelected:	db 'GUIIMAGEISSELECTED', 0

BASIC_TRUE	equ 1
BASIC_FALSE	equ 0

basicSymbolEquals:		db '=', 0
basicSymbolTo:			db 'TO', 0
basicSymbolStep:		db 'STEP', 0
basicSymbolThen:		db 'THEN', 0
basicSymbolElse:		db 'ELSE', 0

; used to evaluate expressions
basicEvalOperatorType:				dw 99
basicEvalLeftOperandType:			dw 99
basicEvalLeftOperandNumericValue:	dw 99
basicEvalRightOperandType:			dw 99
basicEvalRightOperandNumericValue:	dw 99

basicEvalFunctionType:				dw 99
basicEvalRightArgumentType:			dw 99
basicEvalRightArgumentNumericValue:	dw 99
basicEvalLeftArgumentType:			dw 99
basicEvalLeftArgumentNumericValue:	dw 99
basicEvalThirdArgumentType:			dw 99
basicEvalThirdArgumentNumericValue:	dw 99

basicExeTwoNumericExpressionsCommaTokenIndex:	db 99
basicExeTwoNumericExpressionsFirstValue:		dw 99
basicExeIntStringCommaTokenIndex:				db 99
basicExeIntStringExpressionsFirstValue:			dw 99

basicExeWaitKeyScanAndAsciiValue:	dw 0

; used to store temporary expression evaluation results
basicExecutionExpressionType:	dw 0
basicExecutionNumericValue:		dw 0
basicExecutionStringValue0:		times BASIC_TOKEN_MAX_LENGTH+1 db 0

basicItoaBuffer:			times 32 db 0
basicPrivateOnlyBuffer0:	times BASIC_TOKEN_MAX_LENGTH+1 db 0
				; a buffer that cannot be referenced by pointers which are
				; function arguments or return values

basicInterpreterParserResumePoint:	dw 0
				; near pointer to resume point
				; used by instruction execution to branch
				; used instead of the stack to reduce the number of push/pops
											
basicState:				db 99	; the interpreter state, modified by various
								; token types (newline, keyword, etc.)
BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE_OR_LABEL				equ 0
							; we've just seen a newline, instruction delimiter,
							; or are at the beginning of the program text
BASIC_STATE_AWAITING_KEYWORD_OR_NEWLINE							equ 1
							; most recent non-newline token we've seen 
							; was a label
BASIC_STATE_AWAITING_INST_DELIMITER_OR_NEWLINE_OR_INST_FRAGMENT	equ 2
							; we've just seen a keyword, and are now
							; accumulating the rest of the instruction


; these store the tokens of the instruction currently being read (token by 
; token), or being executed
BASIC_MAX_INSTRUCTION_TOKENS	equ 32
basicCurrentKeyword:	times BASIC_TOKEN_MAX_LENGTH+1 db 0
basicCurrentInstTokens: times (BASIC_TOKEN_MAX_LENGTH+1)*BASIC_MAX_INSTRUCTION_TOKENS db 0
basicCurrentInstTokenCount:	db 0

; used by the evaluation logic to store intermediate results
basicEvalBuffer0:	times BASIC_TOKEN_MAX_LENGTH+1 db 0
basicEvalBuffer1:	times BASIC_TOKEN_MAX_LENGTH+1 db 0
basicEvalBuffer2:	times BASIC_TOKEN_MAX_LENGTH+1 db 0

basicForToTokenIndex:	db 0
basicForStepTokenIndex:	db 0
basicForHasStep:		db 0
basicForInitialValue:	dw 0
basicForToValue:		dw 0
basicForStepValue:		dw 0

basicForCounterHandle:	dw 0
basicInterpreterIsInForSkipMode:			db 0
basicInterpreterForSkipModeCounterHandle:	dw 0

basicIfHasElse:			db 0
basicIfThenTokenIndex:	db 0
basicIfElseTokenIndex:	db 0

basicLptAvailable:			db 0
basicLptPortBaseAddress:	dw 0
basicSerialAvailable:		db 0


; keywords
basicKeywordStart:		; marker
basicKeywordPrint:		db 'PRINT', 0
basicKeywordPrintln:	db 'PRINTLN', 0
basicKeywordLet:		db 'LET', 0
basicKeywordGoto:		db 'GOTO', 0
basicKeywordRem:		db 'REM', 0
basicKeywordFor:		db 'FOR', 0
basicKeywordNext:		db 'NEXT', 0
basicKeywordIf:			db 'IF', 0
basicKeywordCall:		db 'CALL', 0
basicKeywordReturn:		db 'RETURN', 0
basicKeywordInputS:		db 'INPUTS', 0
basicKeywordInputN:		db 'INPUTN', 0
basicKeywordAt:			db 'AT', 0
basicKeywordColours:	db 'COLOURS', 0
basicKeywordPause:		db 'PAUSE', 0
basicKeywordWaitKey:	db 'WAITKEY', 0
basicKeywordNoop:		db 'NOOP', 0
basicKeywordBeep:		db 'BEEP', 0
basicKeywordBeepW:		db 'BEEPW', 0
basicKeywordStop:		db 'STOP', 0
basicKeywordCls:		db 'CLS', 0
basicKeywordParallelW:	db 'PARALLELW', 0
basicKeywordSerialW:	db 'SERIALW', 0
basicKeywordSerialR:	db 'SERIALR', 0
basicKeywordYield:		db 'YIELD', 0
basicKeywordGuiBegin:	db 'GUIBEGIN', 0
basicKeywordGuiButtonDelete:	db 'GUIBUTTONDELETE', 0
basicKeywordGuiButtonDisable:	db 'GUIBUTTONDISABLE', 0
basicKeywordGuiButtonEnable:	db 'GUIBUTTONENABLE', 0
basicKeywordGuiCheckboxEnable:	db 'GUICHECKBOXENABLE', 0
basicKeywordGuiCheckboxDisable:	db 'GUICHECKBOXDISABLE', 0
basicKeywordGuiCheckboxDelete:	db 'GUICHECKBOXDELETE', 0
basicKeywordGuiCheckboxSetIsChecked:	db 'GUICHECKBOXSETISCHECKED', 0
basicKeywordGuiCurrentSetRadioGroup:	db 'GUISETCURRENTRADIOGROUP', 0
basicKeywordGuiRadioDelete:		db 'GUIRADIODELETE', 0
basicKeywordGuiRadioDisable:	db 'GUIRADIODISABLE', 0
basicKeywordGuiRadioEnable:		db 'GUIRADIOENABLE', 0
basicKeywordGuiRadioSetIsSelected:	db 'GUIRADIOSETISSELECTED', 0
basicKeywordGuiImageAsciiSetText:	db 'GUIIMAGEASCIISETTEXT', 0
basicKeywordGuiImageSetIsSelected:	db 'GUIIMAGESETISSELECTED', 0
basicKeywordGuiImageSetShowSelectedMark db 'GUIIMAGESETSHOWSELECTEDMARK', 0
basicKeywordGuiImageEnable:		db 'GUIIMAGEENABLE', 0
basicKeywordGuiImageDisable:	db 'GUIIMAGEDISABLE', 0
basicKeywordGuiImageDelete:		db 'GUIIMAGEDELETE', 0
basicKeywordGuiImageSetShowHoverMark:	db 'GUIIMAGESETSHOWHOVERMARK', 0
basicKeywordGuiPrint:			db 'GUIPRINT', 0
basicKeywordGuiAt:				db 'GUIAT', 0
basicKeywordGuiAtDelta:			db 'GUIATDELTA', 0
basicKeywordGuiRectangleEraseTo:	db 'GUIRECTANGLEERASETO', 0
basicKeywordGuiClearAll:		db 'GUICLEARALL', 0
basicKeywordEnd:		; marker


basicResumeNearPointer:	dw 0	; resume point

BASIC_STATE_NONRESUMABLE_SUCCESS	equ 1	; reached the end of the program
											; a non-error halt, such as STOP,
											; or user-requested via keyboard
BASIC_STATE_NONRESUMABLE_ERROR		equ 2	; an error occurred
BASIC_STATE_RESUMABLE				equ 3	; BASIC yields to later resume
											; (also current after init.)

basicInterpreterState:	db BASIC_STATE_NONRESUMABLE_SUCCESS
				; an end-of-the-line state, making it necessary to initialize

basicMustHaltAndYield:	db 0	; set during execution to indicate
								; that the interpreter must return to caller,
								; but remain in a resumable state

%endif
