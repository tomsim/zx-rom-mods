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

	DEFS	$5B57 - $
BANK_F:	DEFB	$06
TARGET:	DEFW	0
RETADDR:DEFW	0		; TODO: abused by PoC code
BANK_M:	DEFB	0
K_STATE:DEFB	$00
K_WIDTH:DEFB	$20
K_TV:	DEFW	0
S_STATE:DEFB	$00
S_WIDTH:DEFB	$20
S_TV:	DEFW	0
S_MODE:	DEFS	1
C_SPCC:	DEFB	1
RCLINE:	DEFS	2		; current line being renumbered
RCSTART:DEFW	10		; starting line number for renumbering
RCSTEP:	DEFW	10		; step for renumbering
STEPPPC:EQU	$
STEPSUB:EQU	STEPPPC+2

INIT_5B00_L:	EQU	$ - $5B00

	ORG	INIT_5B00 + INIT_5B00_L
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
	INCLUDE "tokenizer.asm"

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
	ADD	A,A
	LD	(FLAGS2),A	; set-letter-by-letter mode
	LD	(HL),$3E
	DEC	HL
	LD	(HL),$00	; mark end of stack
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
	CALL	PAL_0		; ULAplus to ZX Spectrum mode
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

MULS_S:	LD	BC,$104C	; tight multiplication
	LD	HL,L2790	; S-NEXT
MULS_R:	EX	(SP),HL		; replace return address by it
	JR	DSWAP2

GOTO_CONT:
	POP	DE		; discard ERROR B
	LD	HL,SWAP
	PUSH	HL
JP_LBL:	LD	HL,(PROG)
	AND	A
	SBC	HL,BC		; subtract large target from PROG
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	ADD	HL,DE
	LD	(CH_ADD),HL
	SBC	HL,DE
	INC	HL
	LD	DE,SUBPPC
	LDI
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	ADD	HL,DE
	DEC	HL
	LD	D,(HL)
	DEC	HL
	LD	E,(HL)
	EX	DE,HL
	ADD	HL,DE
	INC	HL
	INC	HL
	LD	(NXTLIN),HL
	EX	DE,HL
	DEC	HL
	LD	E,(HL)
	DEC	HL
	LD	D,(HL)
	LD	(PPC),DE
	RET

ERROR_5:RST	$08
	DEFW	L0C86		; 5 Out of screen

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

ERR_CONT:
	CP	$07
	JR	Z,ERR7MSG
	CP	$1C
	JR	C,DSWAP2
	CALL	REPORT
ERR_C:	LD	HL,X1349
	EX	(SP),HL
	JR	DSWAP2
ERR7MSG:LD	DE,ERR7TXT
	CALL	MESSAGE
	JR	ERR_C

DIGIT_CONT:
	CALL	DDIGIT
	JR	NC,DSWAP2
	LD	A,C
DSWAP2:	JP	SWAP

DDIGIT:	CP	$A
	CCF
	RET	NC
	SUB	"A" - "0"
	RET	C
	AND	$DF
	CP	26
	CCF
	RET	C
	ADD	$0A
	RET

SCRN_CONT:			; TODO: support various screen modes
	LD	A,C
	CP	$20
	JR	NC,ERROR_5
	LD	A,B
	CP	$18
	JR	NC,ERROR_5
	JR	DSWAP2

INFIX_CONT:
	CP	$10
	JR	C,INFIX_T
	JR	DSWAP2

RUN_CONT:
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
	JR	ERRCNZ		; TODO: syntax error for other characters
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

INDEX_CONT:
	LD	A,L
	SUB	A,$AE
	JR	Z,IDX_FN
	LD	HL,OPERTB
	DEC	A
	JR	Z,IDX_DO
	LD	HL,OPENSTRM2
IDX_DO:	CALL	INDEXER
SWIDX:	JP	NC,SWAP
	POP	BC		; discard return address
	LD	C,(HL)
	LD	B,0
	ADD	HL,BC
	JP	(HL)

IDX_FN:	LD	A,C
	CP	OCT_T + 1
	JR	NC,SWERR
	SUB	FREE_T
	LD	HL,SCANFUNC2
	JR	C,IDX_DO
	LD	HL,FUNCTAB
	ADD	A,A
	LD	C,A
	LD	B,0
	ADD	HL,BC
	LD	A,(HL)
	INC	HL
	LD	H,(HL)
	LD	L,A
	POP	BC		; discard return address
	JP	(HL)

SEP_MISM:			; THEN-less IF and operator update in LET
	CP	$0D
	JR	Z,C_THEN
	CP	":"
	JR	Z,C_THEN
	PUSH	AF
	LD	A,(T_ADDR)
	CP	$8B		; EOL in STOP
	JP	Z,STOP
	CP	$7C		; = in LET
ERRCNZ:	JR	NZ,ERROR_C_NZ
	POP	AF
	JP	UPDATE

C_THEN:	LD	A,THEN_T	; THEN
	CP	C
	JR	NZ,ERROLD
	CALL	SYNTAX_Z	; checking sytax?
	JP	NZ,THENLESS	; if not, execute THENless IF
	RES	4,(IY+$37)	; signal that we're NOT after THEN
	LD	HL,L1B29	; STMT-L-1
ERROLD:	EX	(SP),HL
SWERR:	JP	SWAP		; we're done here

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

ERROR:	LD	HL,(CH_ADD)
	LD	(X_PTR),HL
	LD	HL,L0055
	EX	(SP),HL
	LD	L,(HL)
	JR	SWERR

STDERR_MSG:
	XOR	A
	PUSH	DE
	RST	$28
	DEFW	L1601
	POP	DE
	JR	MESSAGE

REPORT:	CP	MAX_ERR
	JR	C,REPORTZ
	SUB	$81
	LD	(ERR_NR),A
	EX	DE,HL
REPORTL:LD	A,(DE)		; Find end of command line
	INC	DE
	CP	$80
	JR	Z,MESSAGE
	CP	$0E
	JR	NZ,REPORTL
	INC	DE
	INC	DE
	INC	DE
	INC	DE
	INC	DE
	JR	REPORTL

REPORTZ:SUB	$1C
	LD	B,A
	INC	B
	ADD	"S"
	RST	$10
	LD	A," "
	RST	$10
	LD	DE,REPORTS
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
MSGNSP:	AND	$7F
	PUSH	DE
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
	DEFM	"RENU"
	DEFB	$80+"M"
	DEFM	"DEF PRO"
	DEFB	$80+"C"
	DEFM	"_Es"
	DEFB	$80+"8"
	DEFM	"STAC"
	DEFB	$80+"K"
	DEFB	$80+"@"
	DEFM	"PO"
	DEFB	$80+"P"
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
	DEFM	"END WHIL"
	DEFB	$80+"E"
	DEFM	"ON "
ERR_MSG:DEFM	"ERRO"
	DEFB	$80+"R"
	DEFM	"_Es"
	DEFB	$80+"Q"
	DEFM	"_Es"
	DEFB	$80+"W"
	DEFM	"_Es"
	DEFB	$80+"E"
	DEFM	"LOCA"
	DEFB	$80+"L"
	DEFM	"DELET"
	DEFB	$80+"E"
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
	DEFM	"US"
	DEFB	$80+"R"
	DEFM	"_E"
	DEFB	$80+"Y"
	DEFM	"UNTI"
	DEFB	$80+"L"
	DEFM	"ASSER"
	DEFB	$80+"T"
	DEFM	"_E"
	DEFB	$80+"B"
	DEFM	"END I"
	DEFB	$80+"F"
	DEFM	"YIEL"
	DEFB	$80+"D"
	DEFM	"PALETT"
	DEFB	$80+"E"
	DEFM	"EXI"
	DEFB	$80+"T"
	DEFM	"WHIL"
	DEFB	$80+"E"
	DEFM	"END PRO"
	DEFB	$80+"C"
	DEFM	"ELS"
	DEFB	$80+"E"
	DEFM	"PRO"
	DEFB	$80+"C"
	DEFM	"STE"
TOKENS0:DEFB	$80+"P"
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
	DEFM	"TIME$"		; E sT, $D5
	DEFB	$80+" "
	DEFM	"REF"		; E sR, $D6
	DEFB	$80+" "
	DEFM	"ITE"		; E sZ, $D7
	DEFB	$80+"M"
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
	DEFM	"<"		; E A, $E3
	DEFB	$80+"<"
	DEFM	" DATA"		; E D, $E4
	DEFB	$80+" "
	DEFM	">"		; E S, $E5
REPORTS:DEFB	$80+">"
	DEFM	"Missing EN"
	DEFB	$80+"D"		; S
	DEFM	"Label not foun"
	DEFB	$80+"d"		; T
	DEFM	"UNTIL without REPEA"
	DEFB	$80+"T"		; U
	DEFM	"ASSERT faile"
	DEFB	$80+"d"		; V
	DEFM	"END WHILE without WHIL"
	DEFB	$80+"E"		; W
	DEFM	"END PROC without DE"
	DEFB	$80+"F"		; X
MAX_ERR:EQU	$22
ERR7TXT:DEFM	"7 Missing PROC or GO SU"
	DEFB	$80+"B"

PEEK_T:	EQU	$BE
LINE_T:	EQU	$CA
THEN_T:	EQU	$CB
TO_T:	EQU	$CC
STEP_T:	EQU	$CD
FREE_T:	EQU	$CE
MEM_T:	EQU	$CF
TIME_T:	EQU	$D0
STICK_T:EQU	$D1
DPEEK_T:EQU	$D2
OPEN_T:	EQU	$D3
EOF_T:	EQU	$D4
REF_T:	EQU	$D6
HEX_T:	EQU	$D8
INK_T:	EQU	$D9
PAPER_T:EQU	$DA
FLASH_T:EQU	$DB
BRIGHT_T:EQU	$DC
INVERSE_T:EQU	$DD
OVER_T:	EQU	$DE
OCT_T:	EQU	$DF
XOR_T:	EQU	$E2
RL_T:	EQU	$E3
RR_T:	EQU	$E5

EFN_T:	EQU	$E6

RND_T:	EQU	$A5
AT_T:	EQU	$AC
CODE_T:	EQU	$AF
STR_T:	EQU	$C1
CHR_T:	EQU	$C2

PLAY_T:	EQU	$A4
PALETTE_T:EQU	$C3
ENDIF_T:EQU	$C5
WHILE_T:EQU	$C9
ENDPROC_T:EQU	$CA
ELSE_T:	EQU	$CB
PROC_T:	EQU	$CC
DEFPROC_T:EQU	$A8
LABEL_T:EQU	$AB
LOCAL_T:EQU	$B8
ENDWHILE_T:EQU	$B3
ONERROR_T:EQU	$B4
REPEAT_T:EQU	$BA
STOP_T:	EQU	$E2
DATA_T:	EQU	$E4
REM_T:	EQU	$EA
FOR_T:	EQU	$EB
GOSUB_T:EQU	$ED
NEXT_T:	EQU	$F3
POKE_T:	EQU	$F4
IF_T:	EQU	$FA

SYNTAX_Z:
	BIT	7,(IY+1)
	RET

	INCLUDE	"functions.asm"

; Mirror a memory area
; Input: HL=start, BC=length
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

; Put 0 on the calculator stack
STACK0:	RST	$28
	DEFW	L35BF		; STK-PNTRS
	RST	$28
	DEFW	L33A9		; TEST-5-SP
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

; print the decimal value of a word in register HL
DECWORD:LD	A,H
	OR	A
	LD	A,L
	JR	Z,DECBYTE
	LD	C,L
	LD	B,H
	RST	$28
	DEFW	L2D2B + 4	; STACK-BC
	RST	$28
	DEFW	L2DE3		; PRINT-FP
	RET

; print the decimal value of a byte in register A
DECBYTE:CP	10
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
	ADD	"0"
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
	DEFB	"!"
	DEFB	S_CPL - $
	DEFB	"?"
	DEFB	S_ELVIS - $
	DEFB	RR_T
	DEFB	S_RR - $
	DEFB	RL_T
	DEFB	S_RL - $
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
F_CPL2:	LD	HL,L2723	; S-OPERTR
	JR	SWPUSH

S_RL:	CALL	BWISE
	LD	BC,D_RLS
	JR	Z,S_FUNC2
	LD	BC,D_RLN
	JR	S_FUNC2

S_RR:	CALL	BWISE
	LD	BC,D_RRS
	JR	Z,S_FUNC2
	LD	BC,D_RRN
	JR	S_FUNC2

S_ADD:	POP	BC
	LD	BC,$0BCF	; + with priority 11
S_LOOP:	LD	HL,L2734	; S-LOOP
	JR	SWPUSH

S_ELVIS:RST	$20
	LD	A,(FLAGS)	; selector type in bit 6
	ADD	A,A
	JR	NC,S_ELVS
	ADD	A,A
	JR	NC,D_ELVS
	CALL	TEST_ZERO
	JR	Z,D_ELVZ0
	RST	$20
	CALL	SKIPEX
	JR	C,D_ELVR
	LD	(CH_ADD),HL
	RST	$28
	DEFW	L1E99		; FIND-INT2
	RST	$18
D_ELVSK:DEC	BC
	LD	A,B
	OR	C
	JR	Z,D_ELVZ
	PUSH	BC
	CALL	SKIPEX
	POP	BC
	JR	C,D_ELVZ
	LD	(CH_ADD),HL
	JR	D_ELVSK

D_ELVS:	LD	HL,(STKEND)
	DEC	HL
	LD	A,(HL)
	DEC	HL
	OR	(HL)
	JR	Z,D_ELVZ0
	RST	$20
	CALL	SKIPEX
	JR	C,D_ELVR
	DEC	HL
	LD	(CH_ADD),HL

D_ELVZ0:LD	HL,(STKEND)
	LD	DE,-5
	ADD	HL,DE
	LD	(STKEND),HL
	RST	$20
D_ELVZ:	RST	$28
	DEFW	L24FB		; SCANNING
	CP	")"
	JR	Z,F_CPL
D_ELVT:	CALL	SKIPEX
	JR	NC,D_ELVT
D_ELVR:	OR	A
	JR	NZ,ERROR_C_ELV
	LD	(CH_ADD),HL
	RST	$18
	JP	F_CPL2

BWISE:	CALL	SYNTAX_Z
	JR	NZ,BWISE2
	POP	BC
	LD	BC,$0AC8	; like AND, priority 10
	JR	S_LOOP

BITWISE:CALL	SYNTAX_Z
	JR	Z,S_ADD
BWISE2:	LD	BC,FSCAN
	RST	$28
	DEFW	L2D2B + 4		; STACK-BC
	BIT	6,(IY+$01)
	RET

S_ELVS:	PUSH	AF
	RST	$18
	CP	"("
	JR	NZ,ERROR_C_ELV
	RST	$20
	RST	$28
	DEFW	L24FB + 1	; SCANNING + 1
	CP	")"
	JR	NZ,S_ELVL
S_ELVE:	LD	A,(FLAGS)
	ADD	A,A
	POP	BC
	XOR	B
	ADD	A,A
F_CPLNC:JP	NC,F_CPL
ERROR_C_ELV:
	JP	ERROR_C
S_ELVL:	CP	","
	JR	NZ,ERROR_C_ELV
	POP	AF
	ADD	A,A
	LD	A,(FLAGS)
	JR	C,S_ELVN
	PUSH	AF
	RST	$20
	RST	$28
	DEFW	L24FB + 1	; SCANNING + 1
	CP	")"
	JR	NZ,ERROR_C_ELV
	POP	BC
	LD	A,(FLAGS)
	XOR	B
	ADD	A
	ADD	A
	JR	C,ERROR_C_ELV
	JR	F_CPLNC
S_ELVN:	ADD	A,A
	PUSH	AF
S_ELVNL:RST	$20
	RST	$28
	DEFW	L24FB + 1	; SCANNING + 1
	CP	")"
	JR	Z,S_ELVE
	CP	","
	JR	NZ,ERROR_C_ELV
	LD	A,(FLAGS)
	ADD	A,A
	POP	BC
	PUSH	AF
	XOR	B
	ADD	A,A
	JR	C,ERROR_C_ELV
	JR	S_ELVNL

; skip expression pointed by HL. CF cleared, it ends with comma
SKIPEX:	LD	DE,5
	LD	BC,0
SKIPEXL:LD	A,(HL)
	INC	HL
	CP	$0E
	JR	Z,SKIPNN
	CP	"("
	JR	Z,SKIPBR
	CP	"\""
	JR	Z,SKIPQT
	CP	")"
	JR	Z,SKIPCB
	CP	":"
	JR	Z,SKIPEE
	CP	$0D
	JR	Z,SKIPEE
	CP	THEN_T
	JR	Z,SKIPEE
	CP	","
	JR	NZ,SKIPEXL
	LD	A,B
	OR	C
	JR	NZ,SKIPEXL
	RET
SKIPNN:	ADD	HL,DE
	JR	SKIPEXL
SKIPBR:	INC	BC
	JR	SKIPEXL
SKIPQT:	CP	(HL)
	INC	HL
	JR	NZ,SKIPQT
	JR	SKIPEXL
SKIPCB:	LD	A,B
	OR	C
SKIPEE:	SCF
	RET	Z
	DEC	BC
	JR	SKIPEXL

UPDTABN:DEFB	"|"
	DEFB	D_BOR - $
	DEFB	"&"
	DEFB	D_BAND - $
	DEFB	XOR_T
	DEFB	D_XOR - $
	DEFB	RR_T
	DEFB	D_RRN - $
	DEFB	RL_T
	DEFB	D_RLN - $
	DEFB	0

D_BAND:	RST	$28
	DEFW	L2307		; STK-TO-BC
	AND	B
D_BORE:	LD	C,A
	LD	B,0
	JP	SWAP

D_BOR:	RST	$28
	DEFW	L2307		; STK-TO-BC
	OR	B
	JR	D_BORE

D_XOR:	RST	$28
	DEFW	L2307		; STK-TO-BC
	XOR	B
	JR	D_BORE

D_RRN:	RST	$28
	DEFW	L35BF		; STK-PNTRS
	RST	$28
	DEFW	L346E		; NEGATE

D_RLN:	RST	$28
	DEFW	L2307		; STK-TO-BC
	LD	A,B
	DEC	D
	JR	Z,D_RLNP
	NEG
D_RLNP:	AND	$07
	JR	Z,D_R0
	LD	B,A
	LD	A,C
D_RLL:	RLCA
	DJNZ	D_RLL
	LD	C,A		; B is already zeroed
SW_R0:	JP	SWAP

D_R0:	LD	B,A
	JR	SW_R0

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
	CALL	FETCH
	EX	DE,HL
	CALL	MIRROR
	JR	SMUL_E

UPDTABS:DEFB	"|"
	DEFB	D_BORS - $
	DEFB	"&"
	DEFB	D_BANDS - $
	DEFB	XOR_T
	DEFB	D_XORS - $
	DEFB	0

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
	JP	Z,SMUL_E
	LD	A,(DE)
	XOR	(HL)
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	BC
	JR	D_XORL

D_RLS:	RST	$28
	DEFW	L35BF		; STK-PNTRS
	RST	$28
	DEFW	L346E		; NEGATE
D_RRS:	POP	HL		; discard return address
	POP	HL		; RE-ENTRY
	POP	DE		; discard BREG?
	POP	DE		; discard USR
	LD	DE,$106F	; CHR$, a num-to-string function
	PUSH	DE
	LD	DE,0
	PUSH	DE		; BREG = 0
	PUSH	HL		; RE-ENTRY
	RST	$28
	DEFW	L2DA2		; FP-TO-BC
	JP	C,ERROR_B
	JR	Z,D_RR
	DEC	BC
	LD	A,B
	CPL
	LD	B,A
	LD	A,C
	CPL
	LD	C,A
D_RR:	SRA	B
	RR	C
	SRA	B
	RR	C
	SRA	B
	RR	C
	AND	$07
	PUSH	AF
	PUSH	BC
	INC	HL
	INC	HL
	INC	HL
	LD	C,(HL)
	INC	HL
	LD	B,(HL)
	LD	A,B
	OR	C
	JR	Z,D_RRE0
	POP	DE
	INC	HL
	LD	(HL),0
	INC	HL
	RL	D
	SBC	A,A
	RR	D
	LD	(HL),A
	INC	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	INC	HL
	INC	HL
	LD	(STKEND),HL	; Signed amount by which to rotate
	PUSH	BC		; LEN
	RST	$28
	DEFW	L2D2B + 4	; STACK-BC
	CALL	MODDIV
	LD	(STKEND),DE
	RST	$28
	DEFW	L2DA2		; FP-TO-BC
	POP	HL		; LEN
	JR	Z,D_RRPOS
	SBC	HL,BC
	LD	C,L
	LD	B,H
D_RRPOS:PUSH	BC
	RST	$28
	DEFW	L2BF1		; STK-FETCH
	PUSH	DE
	RST	$30
	RST	$28
	DEFW	L2AB2		; STK-STO
	POP	HL
	LD	(MEMBOT+1),HL
	LD	(MEMBOT+3),BC
	ADD	HL,BC
	POP	BC
	PUSH	BC
	LD	A,B
	OR	C
	JR	Z,D_RR0C
	SBC	HL,BC
	LDIR
D_RR0C:	POP	BC
	LD	HL,(MEMBOT+3)
	SBC	HL,BC
	LD	C,L
	LD	B,H
	LD	HL,(MEMBOT+1)
	LDIR
	POP	AF
	JR	Z,SW_R1
D_RRRL:	EX	AF,AF'
	CALL	FETCH
	PUSH	DE
	EX	DE,HL
	ADD	HL,BC
	DEC	HL
	LD	A,C
	OR	A
	JR	Z,D_RRB
	INC	B
D_RRB:	LD	A,(HL)
	RRA
	POP	HL
D_RRRR:	RR	(HL)
	INC	HL
	DEC	C
	JR	NZ,D_RRRR
	DJNZ	D_RRRR
	EX	AF,AF'
	DEC	A
	JR	NZ,D_RRRL
	JR	SW_R1

D_RRE0:	POP	BC
	POP	AF
SW_R1:	JP	SMUL_E

D_LBL:	LD	A,(HL)
	INC	HL
	OR	(HL)
	INC	HL
	OR	(HL)
	INC	HL
	OR	(HL)
	LD	(IY+MEMBOT+25-ERR_NR),LABEL_T
	CALL	Z,F_LBL
	DEC	HL
	DEC	HL
	DEC	HL
	LD	BC,L26B6 + 7	; S-SD-SKIP + 7
	PUSH	BC
SW_LBL:	JP	SWAP

F_LBL:	SET	7,(IY+FLAGS2-ERR_NR)	; Mark cache dirty
	LD	HL,(PROG)
F_LBLL:	LD	A,(HL)
	AND	$C0
	JR	NZ,ERROR_T	; T Label not found
	LD	DE,(MEMBOT+25)	; Label marker (LABEL_T or DEFPROC_T)
	RST	$28
	DEFW	X1D91		; inside LOOK-PROG
	JR	C,ERROR_T	; T Label not found
	LD	(LIST_SP),BC
	INC	HL
	LD	BC,(MEMBOT+26)	; label start
NXBC:	LD	A,(BC)
	INC	BC
	CP	$0E
	JR	Z,E_LBL		; label end
	CP	" " + 1
	JR	C,NXBC
	CP	"a"
	JR	C,L_DIG
	AND	$DF		; upper case
L_DIG:	LD	E,A
NXHL:	LD	A,(HL)
	INC	HL
	CP	$0E
	CALL	Z,NXHL1
	CP	" " + 1
	JR	C,NXHL
	RST	$28
	DEFW	L2C88		; ALPHANUM
	JR	NC,NXLBL
	CP	"a"
	JR	C,L_DIG2
	AND	$DF		; upper case
L_DIG2:	CP	E
	JR	Z,NXBC
NXLBL:	LD	HL,(LIST_SP)
	INC	HL
	JR	F_LBLL

NXHL1:	LD	(MEMBOT+28),HL
	INC	HL
	INC	HL
	INC	HL
	INC	HL
	INC	HL
NXHLR:	LD	A,(HL)
	INC	HL
	RET

ERROR_T:CALL	ERROR
	DEFB	$1C		; T Label not found

E_LBL:	LD	A,(HL)
	INC	HL
	CP	$0D
	JR	Z,E_LBL2
	CP	$0E
	CALL	Z,NXHL1
	CP	" " + 1
	JR	C,E_LBL
	RST	$28
	DEFW	L2C88		; ALPHANUM
	JR	C,NXLBL
E_LBL2:	LD	L,C
	LD	H,B
	INC	HL
	INC	HL
	EX	DE,HL
	LD	HL,(PROG)
	LD	BC,(MEMBOT+28)
	AND	A
	SBC	HL,BC
	EX	DE,HL
	LD	(HL),E
	INC	HL
	LD	(HL),D
	RET

FETCH:	LD	HL,(STKEND)
	DEC	HL
	LD	B,(HL)
	DEC	HL
	LD	C,(HL)
	DEC	HL
	LD	D,(HL)
	DEC	HL
	LD	E,(HL)
	RET

MAIN_ADD_CONT:
	PUSH	BC
;; TODO: find out why it gets reset
;;	BIT	7,(IY+FLAGS2-ERR_NR)
;;	CALL	NZ,RSTLBLS

	CALL	RSTLBLS
	RES	7,(IY+FLAGS2-ERR_NR)
	POP	BC
	JP	SWAP

RSTLBLS:LD	HL,(PROG)
	LD	DE,$0005
NX_LIN:	LD	A,(HL)
	AND	$C0
	RET	NZ
	ADD	HL,DE
	DEC	HL
NX_INS:	LD	A,(HL)
	INC	HL
	CP	PROC_T
	JR	Z,RST_PR
	CP	ELSE_T
	JR	Z,NX_INS
	DEFB	$01		; LD	BC, skip two bytes
NX_CHR:	LD	A,(HL)
	INC	HL
	CP	$0D
	JR	Z,NX_LIN
	CP	":"
	JR	Z,NX_INS
	CP	THEN_T
	JR	Z,NX_INS
	CP	"\""
	JR	Z,SKQUOT
	CP	$0E
	JR	Z,SKNUM
	CP	"@"
	JR	NZ,NX_CHR
RST_PR:	LD	A,$0E
SK_LBL:	CP	(HL)
	INC	HL
	JR	NZ,SK_LBL
	LD	B,E
RST_LBL:LD	(HL),D
	INC	HL
	DJNZ	RST_LBL
	JR	NX_CHR
SKQUOT:	CP	(HL)
	INC	HL
	JR	NZ,SKQUOT
	JR	NX_CHR
SKNUM:	ADD	HL,DE
	JR	NX_CHR


	INCLUDE "variables.asm"
	INCLUDE	"instructions.asm"

CM1:	DEFB	$00, $FF, $FF, $FF
C256:	DEFB	$00, $00, $00, $01, $00

	DEFS	INFIX_HOOK - $
; jump table from ROM1
	JP	INDEX_CONT
	JP	INFIX_CONT
	JP	STRNG_CONT
	JP	DIGIT_CONT
	JP	SCRN_CONT
	JP	GOTO_CONT
	JP	FOR_CONT
	JP	SKIP_FOR_CONT
	JP	NEXT_CONT
	JP	LV_CONT
	JP	RETURN_CONT
	JP	MAIN_ADD_CONT
	JP	ONERR_CONT
	JP	ERR_CONT
	JP	RUN_CONT
	JP	LOCAL_CONT
	JP	NEW128
	JP	STEP_CONT
	JP	PR_OUT
	JP	PR_IN
	JP	S_OUT
	JP	K_OUT
	JP	K_IN
	JP	X_OUT
	JP	X_IN
	JP	NX_OUT
	JP	NX_IN
	JP	F_SCAN
	DEFS	$4000 - $
