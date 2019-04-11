	INCLUDE	"../labels.asm"
	INCLUDE	"sysvars128.asm"

	ORG	$0000
; Cold reset
RST00:	DI
	LD	BC, $692B
RST00L:	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,RST00L	; No instruction fetch from 0008, for IF1 compatibility
	JP	RESET
	DEFS	$10 - $

; Print a character
RST10:	RST	$28
	DEFW	$0010
	RET
	DEFS	$18 - $

; Collect a character
RST18:	LD	HL,(CH_ADD)
	LD	A,(HL)
TEST_CHAR:
	CALL	SKIP_OVER
	RET	NC

; Collect next character
RST20:	CALL	CH_ADD_1
	JR	TEST_CHAR
	DEFS	$28 - $

; Call routine from ROM1
RST28:	EX	(SP),HL
	PUSH	AF
	LD	A,(HL)
	JP	CALL_ROM1
	DEFS	$30 - $

; Make BC spaces
RST30:	RST	$28
	DEFW	$0030
	RET
	DEFS	$38 - 2 - $

PAGEIRQ:OUT	(C),A
; IM1 routine
RST38:	PUSH	AF
	PUSH	BC
	LD	BC,IRQSWAP
	PUSH	BC
	LD	A,(BANK_M)
	XOR	$10
	LD	(BANK_M),A
	OR	$10		; force ROM1, whatever is in BANK_M
	LD	BC,$7FFD
	JR	PAGEIRQ

CALL_ROM1:
	LD	(TARGET),A
	INC	HL
	LD	A,(HL)
	LD	(TARGET+1),A	; target address in TARGET
	POP	AF
	INC	HL
	EX	(SP),HL		; return address on stack
	PUSH	HL
	LD	HL,SWAP
	EX	(SP),HL		; return address, SWAP on stack
	PUSH	HL
	LD	HL,(TARGET)
	EX	(SP),HL		; return address, SWAP, target address on stack
	JP	SWAP

	DEFS	$66 - $
NMI:	PUSH	AF
	PUSH	HL
	LD	HL,(NMIADD)
	LD	A,H
	JR	Z,NONMI
	JP	(HL)
NONMI:	POP	HL
	POP	AF
	RETN

; This positions the compatibility switch to a guaranteed RET in ROM1
	DEFS	$0074 - $

SPECTRUM:
	LD	A,$30		; ROM 1, RAM 0, paging disabled
SPECTRUM_PAGE:
	LD	BC,$7FFD
	OUT	(C),A

NEW128:	DI
	XOR	A
	LD	(BANK_M),A
	LD	HL,(RAMTOP)
	JP	STARTN

INIT_5B00:	EQU	$

	ORG	$5B00
SWAP:	PUSH	AF
	PUSH	BC
IRQSWAP:LD	BC,$7FFD
	LD	A,(BANK_M)
	XOR	$10
; Reentrancy fixed, no need to miss interrupts
;;;	DI
	LD	(BANK_M),A
	OUT	(C),A
;;;	EI
	POP	BC
	POP	AF
	RET

RAMNMI:	DI
	LD	BC,$7FFD
	LD	A,(BANK_M)
	OR	$10
	LD	(BANK_M),A
	OUT	(C),A
	JP	NMIVEC

POUT:	CALL	IOSWAP
PIN:	CALL	IOSWAP
SOUT:	CALL	IOSWAP
KOUT:	CALL	IOSWAP
KIN:	CALL	IOSWAP
XOUT:	CALL	IOSWAP
XIN:	CALL	IOSWAP
NXOUT:	CALL	IOSWAP
NXIN:	CALL	IOSWAP
FSCAN:	CALL	IOSWAP
IOSWAP:	LD	DE,IODISP
	PUSH	DE
	JP	SWAP

	DEFS	$5B57 - $
BANK_F:	DEFB	$06
TARGET:	DEFW	0
RETADDR:DEFW	0		; TODO: abused by PoC code
BANK_M:	DEFB	0
RAMRST:	RST	$08
RAMERR:	DEFB	$0B
K_STATE:DEFB	$00
K_WIDTH:DEFB	$20
K_TV:	DEFW	0
S_STATE:DEFB	$00
S_WIDTH:DEFB	$20
S_TV:	DEFW	0
C_SPCC:	DEFB	1

INIT_5B00_L:	EQU	$ - $5B00

	ORG	INIT_5B00 + INIT_5B00_L
IODISP:	EX	AF,AF'
	POP	DE
	LD	HL,IOJP-PIN
	ADD	HL,DE
	EX	AF,AF'
	JP	(HL)
IOJP:	JP	PR_OUT
	JP	PR_IN
	JP	S_OUT
	JP	K_OUT
	JP	K_IN
	JP	X_OUT
	JP	X_IN
	JP	NX_OUT
	JP	NX_IN
F_SCAN:	LD	HL,10
	ADD	HL,SP
	LD	A,(HL)
	INC	HL
	EX	AF,AF'
	LD	A,(HL)
	LD	E,L
	LD	D,H
	DEC	HL
	DEC	HL
	LD	BC,10
	LDDR
	POP	HL
	LD	H,A
	EX	AF,AF'
	LD	L,A
	JP	(HL)

	INCLUDE "channels.asm"

PR_OUT:
PR_IN:
X_OUT:
X_IN:
NX_OUT:
NX_IN:
	JP	SWAP

R_LINK:	DEFB	$00, $03, $00, $07, $01, $00, $04, $FF

RESET:	LD	A,8		; check and clear all banks
	LD	HL,$FFFF
	LD	BC,$7FFD
	LD	DE,R_LINK+7
TESTL1:	DEC	A
	OUT	(C),A
	LD	(HL),A
	JR	NZ,TESTL1
	LD	A,8
TESTL2:	DEC	A
	LD	BC,$7FFD
	OUT	(C),A
	OUT	($FE),A
	CP	(HL)
	JR	Z,RAMOK
	HALT			; freeze with border showing the faulty RAM
RAMOK:	LD	SP,L3D00	; Two zero bytes for RET in ROM1
	INC	C
	IN	C,(C)
	BIT	0,C		; SPACE key pressed?
	JP	Z,SPECTRUM	; if so, enter compatibility mode
	EX	DE,HL
	LDD
	EX	DE,HL
	LD	BC,$4000
	INC	L
TESTL3:	DEC	L
	LD	(HL),C
	JR	NZ,TESTL3
	DEC	H
	DJNZ	TESTL3
	LD	HL,$FFFF
	OR	A
	JR	NZ,TESTL2

	LD	A,7
	OUT	($FE),A
	LD	SP,TSTACK
	EXX
	LD	HL,INIT_5B00
	LD	DE,$5B00
	LD	BC,INIT_5B00_L
	LDIR
	EXX
	LD	(P_RAMT),HL
	LD	DE,$3EAF
	LD	BC,$A8
	EX	DE,HL
	RST	$28
	DEFW	LDDRR
	EX	DE,HL
	INC	HL
	LD	(UDG),HL
	DEC	HL
	LD	BC,$0140
	LD	(RASP),BC
	LD	(RAMTOP),HL
STARTN:	LD	A,$10
	LD	(FLAGS),A	; indicate 128k mode
	LD	(HL),$3E
	DEC	HL
	LD	SP,HL
	DEC	HL
	DEC	HL
	LD	(ERR_SP),HL
	LD	HL,$3C00
	LD	(CHARS),HL
	LD	HL,RAMNMI
	LD	(NMIADD),HL
	LD	IY,ERR_NR
R_KEY:	XOR	A
	IN	A,($FE)
	OR	$E0
	INC	A
	JR	NZ,R_KEY
	LD	A,$3F
	LD	I,A
	IM	1
	EI
	LD	HL,CHINFO
	LD	(CHANS),HL
	LD	DE,CHINFO0
	LD	BC,CHINFO0_E - CHINFO0
	EX	DE,HL
	LDIR
	EX	DE,HL
	DEC	HL
	LD	(DATADD),HL
	INC	HL
	LD	(PROG),HL
	LD	(VARS),HL
	LD	(HL),$80
	INC	HL
	LD	(E_LINE),HL
	LD	(HL),$0D
	INC	HL
	LD	(HL),$80
	INC	HL
	LD	(WORKSP),HL
	LD	(STKBOT),HL
	LD	(STKEND),HL
	LD	A,$38
	LD	(ATTR_P),A
	LD	(ATTR_T),A
	LD	(BORDCR),A
	LD	HL,$0523
	LD	(REPDEL),HL
	DEC	(IY-$3A)
	DEC	(IY-$36)
	LD	HL,INIT_STRM
	LD	DE,STRMS
	LD	BC,$0E
	LDIR
	LD	(IY+$31),$02
	RST	$28
	DEFW	L0D6B
	LD	DE,COPYRIGHT
	CALL	STDERR_MSG
	XOR	A
	LD	DE,L1539 - 1	; copyright message
	RST	$28
	DEFW	L0C0A		; PO-MSG
	SET	5,(IY+$02)
	LD	DE,L12A9
	PUSH	DE
	JP	SWAP

CH_ADD_1:
	LD	HL,(CH_ADD)
	INC	HL
	LD	(CH_ADD),HL
	LD	A,(HL)
	RET

SKIP_OVER:
	CP	$21
	RET	NC
	CP	$0D
	RET	Z
	CP	1
	RET	C
	CP	6
	CCF
	RET	NC
	CP	$18
	CCF
	RET	C
	INC	HL
	CP	$16
	JR	C,SKIPS2
	INC	HL
SKIPS2:	SCF
	LD	(CH_ADD),HL
	RET

ERROR_5:CALL	ERROR
	DEFB	$04

INFIX_T:CP	$0C		; multiplication?
	JR	NZ,DSWAP2
	CALL	SYNTAX_Z
	JR	Z,MULS_S
	POP	BC		; discard return address
	LD	BC,FSCAN
	RST	$28
	DEFW	L2D2B + 4		; STACK-BC
	LD	BC,D_STRING
	JP	S_FUNC

MULS_S:	LD	BC,$104C	; tight multiplication
	LD	HL,L2790	; S-NEXT
MULS_R:	EX	(SP),HL		; replace return address by it
	JR	DSWAP2

ERR_CONT:
	POP	BC
	EX	(SP),HL
	CP	$1C
	JR	C,DSWAP2
	SUB	$1C
	LD	B,A
	INC	B
	ADD	"S"
	RST	$10
	LD	A," "
	RST	$10
	LD	DE,REPORTS
	CALL	TOKEN
	LD	HL,X1349
	EX	(SP),HL
	JR	DSWAP2

DIGIT_CONT:
	POP	BC
	EX	(SP),HL
	CP	$A
	CCF
	JR	NC,DSWAP2
	SUB	"A" - "0"
	JR	C,DSWAP
	AND	$DF
	CP	26
	CCF
	JR	C,DSWAP
	ADD	$0A
DSWAP2:	JP	SWAP
DSWAP:	LD	A,C
	JR	DSWAP2

SCRN_CONT:			; TODO: support various screen modes
	POP	BC
	EX	(SP),HL
	LD	A,C
	CP	$20
	JR	NC,ERROR_5
	LD	A,B
	CP	$18
	JR	NC,ERROR_5
	JR	DSWAP2

INFIX_CONT:
	POP	BC
	EX	(SP),HL
	CP	$10
	JR	C,INFIX_T
	JR	DSWAP2

OPER_CONT:
	POP	BC
	EX	(SP),HL
	LD	HL,OPERTB
	CALL	INDEXER
	JP	NC,SWAP
	LD	C,(HL)
	ADD	HL,BC
	POP	BC		; discard OPERTB
	JP	(HL)

DISPAT:	BIT	4,(IY+1)
	JP	Z,GO48		; USR 0 mode
	LD	A,(BANK_M)
	AND	$C7		; force ROM0
	LD	(BANK_M),A
	OUT	(C),A
	EI
	POP	BC
	POP	AF
	EX	(SP),HL
	PUSH	BC
	LD	BC,RUNNER
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	JR	Z,RUN_CONT
	LD	BC,SCANNER
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	JR	Z,SCAN_CONT
	LD	BC,OPERTR
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	JR	Z,OPER_CONT
	LD	BC,DIGITR
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	JR	Z,DIGIT_CONT
	LD	BC,SCRNER
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	JR	Z,SCRN_CONT
	LD	BC,INFIXR
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	JR	Z,INFIX_CONT
	LD	BC,ERRRR
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	JP	Z,ERR_CONT
	LD	BC,OPENER
	AND	A
	SBC	HL,BC
	ADD	HL,BC
	POP	BC
	EX	(SP),HL
	JR	Z,OPEN_CONT
	JP	NEW128

RUN_CONT:
	POP	BC
	POP	HL		; discard return to REPORT C
	INC	B		; B=$00 for instruction mismatch and B=$1B for separator mismatch
	DJNZ	SEP_MISM

	DEC	B		; B becomes FF here
	LD	C,A
	LD	HL,P_END
	ADD	HL,BC
	LD	C,(HL)
	INC	B		; B becomes 0 again
	ADD	HL,BC
	CP	$B2		; TOKEN $80
	JR	NC,GET_PARAM	; jump for tokens
	JR	ERROR_C_NZ	; TODO: syntax error for other characters
SCAN_LOOP:
	LD	HL,(T_ADDR)
GET_PARAM:
	LD	A,(HL)
	INC	HL
	LD	(T_ADDR),HL
	LD	BC,SCAN_LOOP
	PUSH	BC
	LD	C,A
	CP	$20
	JR	NC,SEPARATOR
	LD	HL,CMDCLASS2
	LD	B,$00
	ADD	HL,BC
	LD	C,(HL)
	ADD	HL,BC
	PUSH	HL
	RST	$18
	DEC	B
	RET

SCAN_CONT:
	POP	BC
	EX	(SP),HL
	LD	HL,SCANFUNC2
INDEX_CONT:
	CALL	INDEXER
	JP	NC,SWAP
	POP	BC		; discard return address
	LD	C,(HL)
	LD	B,0
	ADD	HL,BC
	JP	(HL)

SEP_MISM:			; THEN-less IF and operator update in LET
	CP	$0D
	JR	Z,C_THEN
	CP	":"
	JR	Z,C_THEN
	PUSH	AF
	LD	A,(T_ADDR)
	CP	$7C		; = in LET
	JR	NZ,ERROR_C_NZ
	POP	AF
	JP	UPDATE

C_THEN:	LD	A,$CB		; THEN
	CP	C
	JR	NZ,ERROR_C_NZ
	BIT	7,(IY+$01)	; checking sytax?
	JP	Z,SWAP		; if so, we're done here
	JP	THENLESS

OPEN_CONT:
	LD	HL,OPENSTRM2
	JR	INDEX_CONT

SEPARATOR:
	RST	$18
	CP	C
ERROR_C_NZ:
	JP	NZ,ERROR_C
	RST	$20
	RET

INDEXER_1:
	INC	HL
INDEXER:LD	A,(HL)
	AND	A
	RET	Z
	CP	C
	INC	HL
	JR	NZ,INDEXER_1
	SCF
	RET

ERROR:	POP	HL
	LD	A,(HL)
ERRORA:	LD	(RAMERR),A
	RST	$28
	DEFW	RAMRST

STDERR_MSG:
	XOR	A
	PUSH	DE
	RST	$28
	DEFW	L1601
	POP	DE
	JR	MESSAGE
TOKEN:	LD	A,(DE)
	ADD	A,A
	INC	DE
	JR	NC,TOKEN
	RET	Z		; end of token table
	DJNZ	TOKEN
	LD	A,(DE)
	CP	" "
	JR	NZ,MSGNSP
	BIT	0,(IY+$01)
	JR	NZ,MSGSKIP
MESSAGE:LD	A,(DE)
	AND	$7F
MSGNSP:	PUSH	DE
	EXX
	RST	$10
	EXX
	POP	DE
	LD	A,(DE)
MSGSKIP:INC	DE
	ADD	A,A
	JR	NC,MESSAGE
	RES	0,(IY+$01)	; allow leading space
	CP	$40		; 2 * " "
	RET	NZ
	INC	A		; clear Z
	SET	0,(IY+$01)	; suppress leading space
	RET

OPENSTRM2:
	DEFB	0		; TODO: empty plug

CHINFO0:
K_CH:	DEFW	PRINT_OUT
	DEFW	L10A8
	DEFB	"K"
S_CH:	DEFW	PRINT_OUT
	DEFW	L15C4
	DEFB	"S"
R_CH:	DEFW	L0F81
	DEFW	L15C4
	DEFB	"R"
P_CH:	DEFW	POUT
	DEFW	PIN
	DEFB	"P"

KCHAN:	DEFW	KOUT
	DEFW	KIN
	DEFB	"K"
	DEFW	0
	DEFW	0		; TODO: proper close
	DEFW	KCHAN_E - KCHAN
KCHAN_E:
SCHAN:	DEFW	SOUT
	DEFW	L15C4
	DEFB	"S"
	DEFW	0
	DEFW	0		; TODO: proper close
	DEFW	SCHAN_E - SCHAN
SCHAN_E:
	DEFB	$80
CHINFO0_E:	EQU	$

INIT_STRM:
	DEFW	KCHAN - CHINFO0 + 1	; stream $FD offset to channel 'K'
        DEFW    SCHAN - CHINFO0 + 1	; stream $FE offset to channel 'S'
        DEFW    R_CH - CHINFO0 + 1	; stream $FF offset to channel 'R'

        DEFW    KCHAN - CHINFO0 + 1	; stream $00 offset to channel 'K'
        DEFW    KCHAN - CHINFO0 + 1	; stream $01 offset to channel 'K'
        DEFW    SCHAN - CHINFO0 + 1	; stream $02 offset to channel 'S'
        DEFW    P_CH - CHINFO0 + 1	; stream $03 offset to channel 'P'

COPYRIGHT:
	DEFB	$7F
	DEFM	" 2019 ePoint Systems Ltd"
TOKENS1:DEFB	$8D
; instructions between $A5 and $CD
	DEFM	"_E"
	DEFB	$80+"T"
	DEFM	"_E"
	DEFB	$80+"N"
	DEFM	"_E"
	DEFB	$80+"M"
	DEFM	"_Es"
	DEFB	$80+"2"
	DEFM	"_Es"
	DEFB	$80+"8"
	DEFM	"_Es"
	DEFB	$80+"K"
	DEFM	"_Es"
	DEFB	$80+"L"
	DEFM	"_S"
	DEFB	$80+"I"
	DEFM	"PLA"
	DEFB	$80+"Y"
	DEFM	"_Es"
	DEFB	$80+"J"
	DEFM	"_E"
	DEFB	$80+"I"
	DEFM	"_E"
	DEFB	$80+"J"
	DEFM	"_E"
	DEFB	$80+"K"
	DEFM	"_E"
	DEFB	$80+"Q"
	DEFM	"_E"
	DEFB	$80+"W"
	DEFM	"_E"
	DEFB	$80+"E"
	DEFM	"_Es"
	DEFB	$80+"Q"
	DEFM	"_Es"
	DEFB	$80+"W"
	DEFM	"_Es"
	DEFB	$80+"E"
	DEFM	"_E"
	DEFB	$80+"Z"
	DEFM	"_E"
	DEFB	$80+"X"
	DEFM	"REPEA"
	DEFB	$80+"T"
	DEFM	"_E"
	DEFB	$80+"H"
	DEFM	"_E"
	DEFB	$80+"F"
	DEFM	"_E"
	DEFB	$80+"G"
	DEFM	"POK"
	DEFB	$80+"E"
	DEFM	"_Es"
	DEFB	$80+"I"
	DEFM	"_E"
	DEFB	$80+"L"
	DEFM	"_E"
	DEFB	$80+"Y"
	DEFM	"UNTI"
	DEFB	$80+"L"
	DEFM	"_s"
	DEFB	$80+"S"
	DEFM	"_E"
	DEFB	$80+"B"
	DEFM	"END I"
	DEFB	$80+"F"
	DEFM	"_s"
	DEFB	$80+"Y"
	DEFM	"_s"
	DEFB	$80+"Q"
	DEFM	"_s"
	DEFB	$80+"E"
	DEFM	"_s"
	DEFB	$80+"W"
	DEFM	"_Es"
	DEFB	$80+"3"
	DEFM	"ELS"
	DEFB	$80+"E"
	DEFM	"_s"
	DEFB	$80+"F"
	DEFM	"_s"
TOKENS0:DEFB	$80+"D"
; functions, etc. beyond $CE
	DEFM	"FRE"		; E s1, $CE
	DEFB	$80+"E"
	DEFM	"MEM"		; E s9, $CF
	DEFB	$80+"$"
	DEFM	"TIM"		; E s0, $D0
	DEFB	$80+"E"
	DEFM	"STIC"		; E s6, $D1
	DEFB	$80+"K"
	DEFM	"DPEEK"		; E s7,	$D2
	DEFB	$80+" "
	DEFM	"OPEN "		; E s4, $D3
	DEFB	$80+"#"
	DEFM	"EOF "		; E s5, $D4
	DEFB	$80+"#"
	DEFM	"_Es"		; E sT, $D5
	DEFB	$80+"T"
	DEFM	"_Es"		; E sR, $D6
	DEFB	$80+"R"
	DEFM	"_Es"		; E sZ, $D7
	DEFB	$80+"Z"
	DEFM	"HEX"		; E sH, $D8
	DEFB	$80+" "
	DEFM	"INK"		; E sX, $D9
	DEFB	$80+" "
	DEFM	"PAPER"		; E sC, $DA
	DEFB	$80+" "
	DEFM	"FLASH"		; E sV, $DB
	DEFB	$80+" "
	DEFM	"BRIGHT"	; E sB, $DC
	DEFB	$80+" "
	DEFM	"INVERSE"	; E sM, $DD
	DEFB	$80+" "
	DEFM	"OVER"		; E sN, $DE
	DEFB	$80+" "
	DEFM	"OCT"		; E sO, $DF
	DEFB	$80+" "
	DEFM	"_E"		; E C, $E0
	DEFB	$80+"C"
	DEFM	"_E"		; E V, $E1
	DEFB	$80+"V"
	DEFM	">"		; sA, $E2
	DEFB	$80+"<"
	DEFM	"READ "		; E A, $E3
	DEFB	$80+"#"
	DEFM	"_E"		; E D, $E4
	DEFB	$80+"D"
	DEFM	"_E"		; E S, $E5
REPORTS:DEFB	$80+"S"
	DEFM	"UNTIL without REPEA"
	DEFB	$80+"T"
	DEFM	"Missing END I"
	DEFB	$80+"F"

PEEK_T:	EQU	$BE
FREE_T:	EQU	$CE
MEM_T:	EQU	$CF
TIME_T:	EQU	$D0
STICK_T:EQU	$D1
DPEEK_T:EQU	$D2
OPEN_T:	EQU	$D3
EOF_T:	EQU	$D4
HEX_T:	EQU	$D8
OCT_T:	EQU	$DF
XOR_T:	EQU	$E2
READ_T:	EQU	$E3

EFN_T:	EQU	$E6

RND_T:	EQU	$A5
CODE_T:	EQU	$AF
STR_T:	EQU	$C1
CHR_T:	EQU	$C2
ENDIF_T:EQU	$C5
ELSE_T:	EQU	$CB
PLAY_T:	EQU	$A4
POKE_T:	EQU	$F4
IF_T:	EQU	$FA

SYNTAX_Z:
	BIT	7,(IY+1)
	RET

SCANFUNC2:
	DEFB	MEM_T
	DEFB	S_MEM - $
	DEFB	DPEEK_T
	DEFB	S_DPEEK - $
	DEFB	STICK_T
	DEFB	S_STICK	- $
	DEFB	CODE_T
	DEFB	S_CODE - $
	DEFB	CHR_T
	DEFB	S_CHR - $
	DEFB	STR_T
	DEFB	S_STR - $
	DEFB	FREE_T
	DEFB	S_FREE - $
	DEFB	TIME_T
	DEFB	S_TIME - $
	DEFB	HEX_T
	DEFB	S_HEX - $
	DEFB	OCT_T
	DEFB	S_OCT - $
	DEFB	0

S_MEM:	RST	$20
	LD	HL,FLAGS
	RES	6,(HL)
	BIT	7,(HL)
	JR	Z,S_MEM_END
	LD	DE,1
	LD	BC,$FFFF
	RST	$28
	DEFW	L2AB1		; STK-ST-0
S_MEM_END:
	LD	BC,L2712
	PUSH	BC
	JR	RSWAP

S_DPEEK:CALL	SYNTAX_Z
	JR	Z,F_NUM
	LD	BC,FSCAN
	RST	$28
	DEFW	L2D2B + 4		; STACK-BC
	LD	BC,D_DPEEK
S_FUNC:	PUSH	BC
	LD	BC,$10ED	; USR
	PUSH	BC
	LD	BC,L270D	; S-PUSH-PO
	PUSH	BC
	LD	BC,$11C1	; TIGHT EXCHANGE
	JR	RSWAP

F_NUM:	LD	BC,L270D	; S-PUSH-PO
	PUSH	BC
	LD	BC,$10EB	; like PEEK
	JR	RSWAP

F_STR:	LD	BC,L270D	; S-PUSH-PO
	PUSH	BC
	LD	BC,$109C	; like CODE
	JR	RSWAP

F_SNUM:	LD	BC,L270D	; S-PUSH-PO
	PUSH	BC
	LD	BC,$106E	; like STR$
	JR	RSWAP

F_STRS:	LD	BC,L24FF	; S-LOOP-1
F_STR0:	PUSH	BC
RSWAP:	JP	SWAP

S_STR_OLD:
	LD	BC,X25F1	; S-BRACKET end
	JR	F_STR0

S_STR:	LD	BC,$106E	; actually STR$
	PUSH	BC
	RST	$20
	CP	"("
	JR	NZ,F_STRS	; actually STR$
	RST	$20
	RST	$28
	DEFW	L1C82		; CLASS_06, numeric expression followed by whatever
	CP	")"
	JR	Z,S_STR_OLD
	JP	S_STR_NEW

S_CODE:	CALL	SYNTAX_Z
	JR	Z,F_STR
	LD	BC,FSCAN
	RST	$28
	DEFW	L2D2B + 4	; STACK-BC
	LD	BC,D_CODE
	JR	S_FUNC

S_CHR:	CALL	SYNTAX_Z
	JR	Z,F_SNUM
	LD	BC,FSCAN
	RST	$28
	DEFW	L2D2B + 4	; STACK_BC
	LD	BC,D_CHR
	JR	S_FUNC

S_FREE:	CALL	SYNTAX_Z
	JR	Z,S_TEND
	RST	$28
	DEFW	L1F1A		; FREE-MEM
	OR	A
	SBC	HL,BC
	SBC	HL,BC
	LD	C,L
	LD	B,H
	LD	HL,L2630	; S-PI-END
	PUSH	HL
	LD	HL,L2D2B + 4	; STACK-BC
	JR	HLSWAP

S_OCT:	BIT	7,(IY+$01)
	JR	NZ,S_STK_NUM
	LD	C,$08
	JR	S_NUM

S_HEX:	BIT	7,(IY+$01)
	JR	NZ,S_STK_NUM
	LD	C,$10
S_NUM:	RST	$20		; skip prefix
	RST	$28
	DEFW	DEC2FP + 2
	RST	$28
	DEFW	L2C9B + 3
	LD	HL,L268D + 8
	JR	HLSWAP

S_STICK:RST	$28
	DEFW	L2522		; S-2-COORD
S_TEND:	JR	Z,S_TIME_END
	RST	$28
	DEFW	L2307		; STK-TO-BC
	DEC	D
	JR	NZ,ERRBNZ
	DEC	E
ERRBNZ:	JR	NZ,ERROR_B
	RRA
	LD	A,B
	ADC	A,A
	CP	8
	JR	NC,ERROR_B
	LD	HL,STICK_TAB
	LD	C,A
	LD	B,0
	ADD	HL,BC
	LD	C,(HL)
	ADD	HL,BC
	JP	(HL)

S_STK_NUM:
	LD	HL,L26B5
HLSWAP:	PUSH	HL
RSWAP1:	JP	SWAP

S_TIME:	CALL	SYNTAX_Z
	JR	Z,S_TIME_END
TIME_R:	LD	A,(FRAMES+2)
	LD	B,A
	LD	HL,(FRAMES)
	LD	A,(FRAMES+2)
	LD	DE,(FRAMES)
	CP	B
	JR	NZ,TIME_R
	SBC	HL,DE
	JR	NZ,TIME_R
	OR	A
	JR	Z,TIME_L
	LD	C,E
	LD	E,A
	LD	B,L
	LD	A,$98
TIME_N:	BIT	7,E
	JR	NZ,TIME_D
	SLA	C
	RL	D
	RL	E
	DEC	A
	JR	TIME_N
TIME_D:	RES	7,E
	JR	TIME_S
TIME_L:	LD	C,D
	LD	D,E
	LD	E,L
	LD	B,L
TIME_S:	RST	$28
	DEFW	L2AB6		; STK-STORE
S_TIME_END:
	LD	BC,L2630	; S-PI-END
S_FNC_E:PUSH	BC
S_SWAP:	LD	B,0
	JR	RSWAP1

ERROR_B:CALL	ERROR
	DEFB	$0A		; B Integer out of range

STK_BASE:
	LD	A,(MEMBOT+27)
STK_A:	CALL	STACK_ZERO
	INC	HL
	INC	HL
	LD	(HL),A
	DEC	HL
	DEC	HL		; stack base
	RET

D_DPEEK:RST	$28
	DEFW	L1E99		; FIND_INT2
	LD	L,C
	LD	H,B
	LD	C,(HL)
	INC	HL
	LD	B,(HL)
	JR	RSWAP1

STICK_TAB:
	DEFB	KEMPSTON_FIRE - $
	DEFB	KEMPSTON_STICK - $
	DEFB	SINCLAIR1_FIRE - $
	DEFB	SINCLAIR1_STICK - $
	DEFB	SINCLAIR2_FIRE - $
	DEFB	SINCLAIR2_STICK - $
	DEFB	CURSOR_FIRE - $
	DEFB	CURSOR_STICK - $

CURSOR_STICK:
	LD	A,$F7
	IN	A,($FE)
	CPL
	AND	$10
	RRCA
	RRCA
	LD	C,A
	LD	A,$EF
	IN	A,($FE)
	CPL
	LD	B,A
	AND	$18
	RRCA
	RRCA
	RRCA
	OR	C
	LD	C,A
	LD	A,B
	AND	$4
	ADD	A,A
	OR	C
	JR	STICK_END

SINCLAIR1_FIRE:
	LD	A,$EF
	IN	A,($FE)
	CPL
	AND	$01
	JR	STICK_END
CURSOR_FIRE:
SINCLAIR2_FIRE:
	LD	A,$F7
	IN	A,($FE)
	CPL
	JR	STICK_FIRE
KEMPSTON_FIRE:
	IN	A,($1F)
STICK_FIRE:
	AND	$10
	RRCA
	RRCA
	RRCA
	RRCA
STICK_END:
	RST	$28
	DEFW	L2D28		; STACK-A
	JR	S_TIME_END

SINCLAIR1_STICK:
	LD	A,$EF
	IN	A,($FE)
	LD	C,A
	LD	B,4
S2S_L:	RR	C
	ADC	A,A
	DJNZ	S2S_L
STICK_1:CPL
STICK_2:AND	$0F
	LD	B,A
	RRA
	SRL	A
	XOR	B
	AND	$03
	LD	C,A
	ADD	A,A
	ADD	A,A
	OR	C
	XOR	B
	JR	STICK_END

SINCLAIR2_STICK:
	LD	A,$F7
	IN	A,($FE)
	JR	STICK_1

KEMPSTON_STICK:
	IN	A,($1F)
	JR	STICK_2

D_CPL:	BIT	6,(IY+$01)
	JR	NZ,D_CPLN
;;	RST	$28
;;	DEFW	L35BF		; STK-PNTRS
	INC	HL
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	INC	HL
	LD	C,(HL)
	INC	HL
	LD	B,(HL)
D_CPLL:	LD	A,B
	OR	C
	JR	Z,D_CODEE
	LD	A,(DE)
	CPL
	LD	(DE),A
	INC	DE
	DEC	BC
	JR	D_CPLL
D_CPLN:	RST	$28
	DEFW	L1E94		; FIND_INT1
	CPL
	LD	HL,L2D28	; STACK-A
	EX	(SP),HL
	JR	CDSWAP

D_CODE:	RST	$28
	DEFW	L2BF1		; STK-FETCH
	LD	A,B
	OR	C
	JR	Z,CSWAPR
	EX	DE,HL
	ADD	HL,BC
	XOR	A
CODEL1:	DEC	HL
	CP	(HL)
	JR	NZ,CODE_D
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,CODEL1
CSWAPR:	JP	SWAP
CODE_D:	LD	A,B
	OR	A
	JR	NZ,ERROR_6	; 6 Number too big
	DEC	C
	JR	Z,D_CODE1
	DEC	C
	LD	A,C
	LD	B,(HL)
	DEC	HL
D_CODE1:LD	C,(HL)
	JP	Z,SWAP
	EX	(SP),HL		; discard STACK-BC, save pointer
	PUSH	AF		; save counter
	RST	$28
	DEFW	L2D2B + 4		; STACK-BC
	RST	$28
	DEFW	L35BF		; STK-PNTRS
	RST	$28
	DEFW	L3297		; RE-STACK
	EX	DE,HL		; pointer to exponent to DE
	POP	BC		; counter in B
	POP	HL		; restore pointer
CODEL2:	DEC	HL
	PUSH	BC
	LD	A,(DE)
	ADD	8		; * 256
	JR	C,ERROR_6
	LD	(DE),A
	PUSH	DE
	PUSH	HL
	LD	A,(HL)
	RST	$28
	DEFW	L2D28		; STACK-A with space check
	CALL	STEPBACK
	RST	$28
	DEFW	L3014		; ADDITION
	LD	(STKEND),DE
	POP	HL
	POP	DE
	POP	BC
	DJNZ	CODEL2
D_CODEE:LD	HL,(STKEND)
	EX	DE,HL
CDSWAP:	JP	SWAP

D_CHR:	POP	HL		; discard return address
	POP	HL		; RE-ENTRY
	POP	DE		; discard BREG?
	POP	DE		; discard USR
	LD	DE,$106F	; CHR$
	PUSH	DE		; replace by CHR$
	LD	DE,0
	PUSH	DE		; BREG = 0
	PUSH	HL
	RST	$28
	DEFW	L35BF		; STK-PNTRS
	RES	6,(IY+$01)	; string result
	LD	A,(HL)
	OR	A
	JR	NZ,D_CHRL
	RST	$28
	DEFW	L1E99		; FIND-INT2
	JR	NZ,ERROR_B_2
	LD	A,B
	OR	A
	JR	NZ,D_CHR2
	LD	A,C
	LD	BC,L35C9 + 7
	PUSH	BC
	JP	SWAP

ERROR_6:CALL	ERROR
	DEFB	$05		; Number too big

D_CHR2:	PUSH	BC
	LD	BC,$0002
	RST	$30
	POP	BC
	EX	DE,HL
	LD	(HL),C
	INC	HL
	LD	(HL),B
	DEC	HL
	EX	DE,HL
	LD	BC,$0002
CHR2_E:	RST	$28
	DEFW	L35C9 + $0E
	JP	SWAP
D_CHRL:	INC	HL
	BIT	7,(HL)
	JR	NZ,ERROR_B_2
	DEC	HL
	LD	A,(HL)
	SUB	$78
	RRCA
	RRCA
	RRCA
	AND	$1F
	LD	C,A
	LD	B,0
	RST	$30
	EX	DE,HL
	LD	(MEMBOT+28),HL
	LD	(K_CUR),HL
	RST	$28
	DEFW	L35BF		; STK-PNTRS
CHRL_L:	PUSH	DE
	RST	$28
	DEFW	L33A9		; TEST-5-SP
	LD	HL,C256
	LD	BC,$0005
	LDIR			; STK-256
	POP	HL
	LD	(STKEND),DE
	CALL	MOD2A
	LD	HL,(K_CUR)
	LD	(HL),A
	INC	HL
	LD	(K_CUR),HL
	RST	$28
	DEFW	L35BF		; STK-PNTRS
	LD	A,(HL)
	OR	A
	JR	NZ,CHRL_L
	INC	HL
	INC	HL
	LD	DE,(K_CUR)
	LDI
	LDI
	EX	DE,HL
	LD	DE,(MEMBOT+28)
	SBC	HL,DE
	LD	C,L
	LD	B,H
	JR	CHR2_E

ERROR_B_2:
	JP	ERROR_B

MIRROR:	LD	D,(HL)
	DEC	BC
	LD	A,B
	OR	C
	RET	Z
	ADD	HL,BC
	LD	E,(HL)
	LD	(HL),D
	SBC	HL,BC
	LD	(HL),E
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,MIRROR
	RET

; STR$() with multiple arguments
S_STR_NEW:
	POP	BC		; discard STR$ and priority
	CP	","
	JR	NZ,ERROR_C
	BIT	7,(IY+$01)
	JR	Z,S_STR_S
	LD	BC,$0001
	RST	$30
	LD	(K_CUR),HL
	PUSH	HL		; save cursor
	LD	HL,(CURCHL)
	PUSH	HL		; save channel
	LD	A,$FF
	RST	$28
	DEFW	L1601		; CHAN-OPEN, open R channel
	RST	$28
	DEFW	L35BF		; STK-PNTRS
	INC	HL
	BIT	7,(HL)		; check sign
	JR	Z,S_STR_S	; if positive, do nothing
	LD	A,"-"
	RST	$10		; print "-"
	RST	$28
	DEFW	L346E		; NEGATE
S_STR_S:RST	$20
	RST	$28
	DEFW	L1C82		; CLASS_06, numeric expression followed by whatever
	BIT	7,(IY+$01)
	JR	Z,S_ST0_S
	PUSH	AF
	RST	$28
	DEFW	L35BF		; STK-PNTRS
	RST	$28
	DEFW	L33C0		; DUP
	LD	(STKEND),DE
	RST	$28
	DEFW	L1E94		; FIND-INT1
	CP	2
	JR	C,ERROR_B_2	; base zero and one prohibited
	CP	37		; maximum base 36, digits [0-9A-Z]
	JR	NC,ERROR_B_2
	LD	(MEMBOT+27),A	; save base
	POP	AF
S_ST0_S:CP	")"
	JR	NZ,S_STR3
	BIT	7,(IY+$01)
	JR	Z,S_STR_D
	PUSH	AF
	RST	$28
	DEFW	L35BF		; STK-PNTRS
	RST	$28
	DEFW	L33A9		; TEST-5-SP
	CALL	STACK_ZERO
	POP	AF
	JR	S_STR_D

ERROR_C:CALL	ERROR
	DEFB	$0B		; C Nonsense in BASIC

S_STR3:	CP	","
	JR	NZ,ERROR_C
	RST	$20
	RST	$28
	DEFW	L1C82		; CLASS_06, numeric expression followed by whatever
	CP	")"
	JR	NZ,ERROR_C	; must be followed by ")"
	BIT	7,(IY+$01)
S_STR_D:JR	Z,S_STR_END
	RST	$28
	DEFW	L1E94		; FIND-INT1
	OR	A
	JP	M,ERROR_B	; No more than 127 places after dot
	PUSH	AF		; Number of digits on CPU stack, Z set, if 0
	JR	Z,NROUND
	LD	HL,MEMBOT
	RST	$28
	DEFW	L350B		; ZERO to M0
	POP	AF
	PUSH	AF
	RST	$28
	DEFW	L2D60		; E-LOOP
	CALL	STK_BASE
NROUND:	CALL	MOD2A
	ADD	"0"
	CP	"9"+1
	JR	C,STR_NUM
	ADD	A,7
STR_NUM:RST	$10		; print digit
	INC	HL
	INC	DE		; adjust pointers
	POP	AF
	DEC	A
	PUSH	AF
	ADD	A,A
	JR	NZ,STR_DG
	LD	A,"."
	RST	$10
	INC	HL
	INC	DE		; adjust pointers
STR_DG:	JR	NC,STR_FR	; still fractional
	RST	$28
	DEFW	L34E9		; TEST-ZERO
	JR	C,D_STR_E
STR_FR:	CALL	STK_BASE
	JR	NROUND

D_STR_E:POP	AF		; fractional digits, Z set if zero
	CALL	STEPBACK	; remove zero quotient from stack
	POP	HL		; restore channel
	RST	$28
	DEFW	L1615		; channel flags
	POP	DE		; start pointer
	LD	HL,(K_CUR)
	AND	A
	SBC	HL,DE
	LD	B,H
	LD	C,L
	PUSH	BC
	PUSH	DE
	EX	DE,HL
	LD	A,(HL)
	CP	"-"
	JR	NZ,STR_P
	INC	HL
	DEC	BC
STR_P:	CALL	MIRROR
	POP	DE
	POP	BC
S_STR_END:
	LD	HL,X266E
	PUSH	HL
	JP	SWAP

; Replace a,b on top of stack by INT(a/b) and return a MOD b in register A.
MOD2A:	CALL	MODDIV
	RST	$28
	DEFW	L343C		; EXCHANGE
	RST	$28
	DEFW	L2DA2		; FP-TO-BC (and A)
	RET

; Replace a,b on top of stack by a MOD b, INT(a/b)
MODDIV:	RST	$28
	DEFW	L36A0		; MOD
; Move both pointers back by one entry
STEPBACK:
	LD	BC,-5
	ADD	HL,BC
	EX	DE,HL
	ADD	HL,BC
	EX	DE,HL
	RET

; Put 0 on the calculator stack, without testing available space
STACK_ZERO:
	LD	L,E
	LD	H,D
	LD	BC,$500
STK0_L:	LD	(HL),C
	INC	HL
	DJNZ	STK0_L
	LD	(STKEND),HL
	EX	DE,HL
	RET

; print the decimal value of a byte in register A
DECBYTE:
	CP	10
	JR	NC,P_DB1
	ADD	"0"
	RST	$10
	RET
P_DB1:	LD	E,100
	SUB	A,E
	JR	C,P_DB2
	LD	D,"1"
	SUB	A,E
	LD	A,0
	ADC	A,D
	PUSH	AF
	RST	$10
	POP	AF
P_DB2:	ADD	A,E
	ADD	A,A
	LD	E,A
	XOR	A
	LD	B,7
P_DB2L:	RL	E
	ADC	A,A
	DAA
	DJNZ	P_DB2L
	LD	E,A
	RLCA
	RLCA
	RLCA
	RLCA
	AND	$0F
	ADD	"0"
	RST	$10
	LD	A,E
	AND	$0F
	RST	$10
	RET

OPERTB:	DEFB	"|"
	DEFB	S_BOR - $
	DEFB	"&"
	DEFB	S_BAND - $
	DEFB	XOR_T
	DEFB	S_XOR - $
	DEFB	"%"
	DEFB	S_MOD - $
	DEFB	"'"
	DEFB	S_CPL - $
	DEFB	0

S_BOR:	CALL	BITWISE
	JR	NZ,S_BORN
	LD	BC,D_BORS
	JR	S_FUNC2
S_BORN:	LD	BC,D_BOR
S_FUNC2:JP	S_FUNC

S_XOR:	CALL	BITWISE
	JR	NZ,S_XORN
	LD	BC,D_XORS
	JR	S_FUNC2
S_XORN:	LD	BC,D_XOR
	JR	S_FUNC2

S_BAND:	CALL	BITWISE
	JR	NZ,S_BANDN
	LD	BC,D_BANDS
	JR	S_FUNC2
S_BANDN:LD	BC,D_BAND
	JR	S_FUNC2

S_MOD:	LD	BC,$0BC2	; delete with priority 11
	PUSH	BC
	LD	BC,$0BF2	; mod with priority 11
SWNEXT:	LD	HL,L2790	; S-NEXT
SWPUSH:	PUSH	HL
SWAPOP:	JP	SWAP

S_CPL:	CALL	SYNTAX_Z
	JR	Z,F_CPL
	BIT	6,(IY+$01)
	JR	NZ,S_CPLN
	RST	$28
	DEFW	L2BF1		; STK-FETCH
	PUSH	DE
	RST	$30
	RST	$28
	DEFW	L2AB2		; STK-STO
	POP	HL
S_CPLL:	LD	A,B
	OR	C
	JR	Z,F_CPL
	LD	A,(HL)
	CPL
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	BC
	JR	S_CPLL
S_CPLN:	RST	$28
	DEFW	L1E94		; FIND-INT1
;;	DEFW	L1E99		; FIND-INT2
	CPL
;;	LD	C,A
;;	LD	A,B
;;	CPL
;;	LD	B,A
	RST	$28
	DEFW	L2D28		; STACK-A
;;	DEFW	L2D2B + 4	; STACK-BC
F_CPL:	RST	$20		; advance
	LD	HL,L2723	; S-OPERTR
	JR	SWPUSH

S_ADD:	POP	BC
	LD	BC,$0BCF	; + with priority 11
	LD	HL,L2734
	JR	SWPUSH


BITWISE:CALL	SYNTAX_Z
	JR	Z,S_ADD
	LD	BC,FSCAN
	RST	$28
	DEFW	L2D2B + 4		; STACK-BC
	BIT	6,(IY+$01)
	RET

D_BAND:	RST	$28
	DEFW	L2307		; STK-TO-BC
	AND	B
D_BORE:	LD	C,A
	LD	B,0
	JR	SWAPOP

D_BOR:	RST	$28
	DEFW	L2307		; STK-TO-BC
	OR	B
	JR	D_BORE

D_XOR:	RST	$28
	DEFW	L2307		; STK-TO-BC
	XOR	B
	JR	D_BORE

D_TWOS:	POP	BC		; return here
	POP	HL		; discard return address
	POP	HL		; RE-ENTRY
	POP	DE		; discard BREG?
	POP	DE		; discard USR
	LD	DE,$106F	; CHR$, a num-to-string function
	PUSH	DE		; replace by CHR$
	LD	DE,0
	PUSH	DE		; BREG = 0
	PUSH	HL
	PUSH	BC
	RST	$28
	DEFW	L2BF1		; STK-FETCH
	PUSH	DE
	PUSH	BC
	RST	$28
	DEFW	L2BF1		; STK-FETCH
	POP	HL
	PUSH	HL
	AND	A
	SBC	HL,BC
	JR	NC,SSWP
	PUSH	DE
	JR	SNOSWP
SSWP:	POP	HL
	POP	AF
	PUSH	DE
	PUSH	BC
	PUSH	AF
	LD	C,L
	LD	B,H
SNOSWP:	RST	$30
	RST	$28
	DEFW	L2AB2		; STK-STO
	POP	HL
	LD	A,B
	OR	C
	PUSH	DE
	PUSH	BC
	JR	Z,SEMPTY
	LDIR
SEMPTY:	POP	AF
	POP	DE
	POP	BC
	POP	HL
	RET

D_STRING:
	POP	HL		; discard return address
	POP	HL		; RE-ENTRY
	POP	DE		; discard BREG?
	POP	DE		; discard USR
	LD	DE,$106F	; CHR$, a num-to-string function
	PUSH	DE
	LD	DE,0
	PUSH	DE		; BREG = 0
	PUSH	HL
	RST	$28
	DEFW	L35BF		; STK-PNTRS
	INC	HL
	BIT	7,(HL)		; check sign
	DEC	HL
	PUSH	AF		; Z clear, if negative
	JR	Z,D_NFLIP
	RST	$28
	DEFW	L346E + 4	; NEGATE + 4
D_NFLIP:DEC	HL
	LD	B,(HL)
	DEC	HL
	LD	C,(HL)		; string length to BC
	PUSH	BC
	RST	$28
	DEFW	L2D2B + 4		; STACK-BC
	CALL	STEPBACK
	RST	$28
	DEFW	L30CA		; MULTIPLY
	LD	(STKEND),DE
	RST	$28
	DEFW	L1E99		; FIND-INT2
	POP	HL
	SBC	HL,BC
	EX	DE,HL
	DEC	HL
	LD	(HL),B
	DEC	HL
	LD	(HL),C
	DEC	HL
	JR	C,D_SLONG
	LD	D,(HL)
	DEC	HL
	LD	E,(HL)
	POP	AF		; restore sign in Z
	JR	Z,SMUL_E
	PUSH	DE
	RST	$30		; BC-SPACES
	POP	HL
	PUSH	DE
	PUSH	BC
	LDIR
	POP	BC
	POP	HL
	PUSH	HL
	CALL	MIRROR
	POP	DE
	LD	HL,(STKEND)
	DEC	HL
	DEC	HL
	DEC	HL
	LD	(HL),D
	DEC	HL
	LD	(HL),E
SMUL_E:	LD	DE,(STKEND)
	JP	SWAP

D_SLONG:PUSH	HL		; address pointer
	PUSH	DE		; excess length
	RST	$30
	POP	HL
	LD	(MEMBOT+28),HL	; save excess length
	ADD	HL,BC		; HL is old length
	EX	(SP),HL		; retrieve address pointer
	ADD	HL,BC		; stack has moved
	LD	B,(HL)
	LD	(HL),D
	DEC	HL
	LD	C,(HL)
	LD	(HL),E
	LD	H,B
	LD	L,C
	POP	BC
	PUSH	DE
	LDIR
	POP	HL
	LD	A,(MEMBOT+28)
	CPL
	LD	C,A
	LD	A,(MEMBOT+29)
	CPL
	LD	B,A
	INC	BC
	LDIR
	POP	AF
	JR	Z,SMUL_E
	LD	HL,(STKEND)
	DEC	HL
	LD	B,(HL)
	DEC	HL
	LD	C,(HL)
	DEC	HL
	LD	D,(HL)
	DEC	HL
	LD	E,(HL)
	EX	DE,HL
	CALL	MIRROR
	JR	SMUL_E

D_BANDS:CALL	D_TWOS
	PUSH	AF
	PUSH	BC
D_BANDL:LD	A,B
	OR	C
	JR	Z,D_FILLS
	LD	A,(DE)
	AND	(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	BC
	JR	D_BANDL
D_FILLS:POP	BC
	POP	HL
	SBC	HL,BC
	JR	Z,SMUL_E
	EX	DE,HL
D_FILLL:LD	(HL),0
	INC	HL
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,D_FILLL
	JR	SMUL_E

D_BORS:	CALL	D_TWOS
D_BORL:	LD	A,B
	OR	C
	JR	Z,SMUL_E
	LD	A,(DE)
	OR	(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	BC
	JR	D_BORL

D_XORS:	CALL	D_TWOS
D_XORL:	LD	A,B
	OR	C
	JR	Z,SMUL_E
	LD	A,(DE)
	XOR	(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	BC
	JR	D_XORL


	INCLUDE	"instructions.asm"

C256:	DEFB	$00, $00, $00, $01, $00

	DEFS	$3CF8 - $
GO48:	LD	A,$10		; ROM1, RAM0
	OUT	(C),A
	JP	DISPAT
	NOP
	DEFS	$300
