FUNCTAB:DEFW	S_FREE		; FREE
	DEFW	S_MEM		; MEM$
	DEFW	S_TIME		; TIME
	DEFW	S_STICK		; STICK
	DEFW	S_DPEEK		; DPEEK
	DEFW	F_STR0		; OPEN #
	DEFW	F_STR0		; EOF #
	DEFW	S_TIMES		; TIME$
	DEFW	S_REF		; REF
	DEFW	S_ITEM		; ITEM
	DEFW	S_HEX		; HEX
	DEFW	F_STR0		; INK
	DEFW	F_STR0		; PAPER
	DEFW	F_STR0		; FLASH
	DEFW	F_STR0		; BRIGHT
	DEFW	F_STR0		; INVERSE
	DEFW	F_STR0		; OVER
	DEFW	S_OCT		; OCT
	DEFW	F_STR0		; E C
	DEFW	F_STR0		; E V
	DEFW	F_STR0		; ><
	DEFW	F_STR0		; <<
	DEFW	F_STR0		; DATA
	DEFW	F_STR0		; >>

SCANFUNC2:
	DEFB	CODE_T
	DEFB	S_CODE - $
	DEFB	CHR_T
	DEFB	S_CHR - $
	DEFB	STR_T
	DEFB	S_STR - $
	DEFB	"@"
	DEFB	S_LBL - $
	DEFB	0

S_STR:	LD	BC,$106E	; actually STR$
	PUSH	BC
	RST	$20
	CP	"("
	JR	NZ,F_STRS	; actually STR$
	RST	$20
	RST	$28
	DEFW	L1C82		; CLASS_06, numeric expression followed by whatever
	CP	")"
	JP	NZ,S_STR_NEW
	LD	BC,X25F1	; S-BRACKET end
	JR	F_STR0

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

S_TIMES:CALL	SYNTAX_Z
	JR	Z,F_SNUM
	LD	BC,FSCAN
	RST	$28
	DEFW	L2D2B + 4	; STACK_BC
	LD	BC,D_TIMES
	JR	S_FUNC

F_STRS:	LD	BC,L24FF	; S-LOOP-1
F_STR0:	PUSH	BC
RSWAP:	JP	SWAP

S_LBL:	CALL	SYNTAX_Z
	JP	Z,S_LBLS
	RST	$20
	LD	(MEMBOT+26),HL	; label start
L_LBL:	LD	A,(HL)
	CP	$0E
	INC	HL
	JR	NZ,L_LBL
	JP	D_LBL

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

S_OCT:	CALL 	SYNTAX_Z
	JR	NZ,S_STK_NUM
	LD	C,$08
	JR	S_NUM

S_HEX:	CALL 	SYNTAX_Z
	JR	NZ,S_STK_NUM
	LD	C,$10
S_NUM:	RST	$20		; skip prefix
	RST	$28
	DEFW	DEC2FP + 2
	RST	$28
	DEFW	L2C9B + 3
	LD	HL,L268D + 8	;  S_DECIMAL
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

ERROR_B:RST	$28
	DEFW	L046C		; B Integer out of range

D_DPEEK:RST	$28
	DEFW	L1E99		; FIND_INT2
	LD	L,C
	LD	H,B
	LD	C,(HL)
	INC	HL
	LD	B,(HL)
	JR	RSWAP1

S_ITEM:	CALL	SYNTAX_Z
	JR	Z,S_TIME_END
	LD	HL,(CH_ADD)
	PUSH	HL
	LD	HL,(DATADD)
	PUSH	HL
	LD	A,(HL)
	CP	")"
	JR	Z,N_ITEM
	CP	"("
	JR	Z,D_ITEM
	CP	","
	JR	Z,D_ITEM
	LD	DE,DATA_T
	RST	$28
	DEFW	L1D86		; LOOK_PROG
	JR	C,N_ITEM
D_ITEM:	RST	$28
	DEFW	L0077		; TEMP_PTR1
	RST	$28
	DEFW	L24FB		; SCANNING
	LD	A,(FLAGS)
	RLCA
	RLCA
	AND	$01
	INC	A
	LD	HL,(STKEND)
	DEC	HL
	DEC	HL
	LD	(HL),0
	DEC	HL
	LD	(HL),A
	DEC	HL
	LD	(HL),0
	DEC	HL
	LD	(HL),0
E_ITEM:	POP	HL
	LD	(DATADD),HL
	POP	HL
	LD	(CH_ADD),HL
	JR	S_TIME_END
N_ITEM:	CALL	STACK0
	JR	E_ITEM

STK_BASE:
	LD	A,(MEMBOT+27)
STK_A:	CALL	STACK_ZERO
	INC	HL
	INC	HL
	LD	(HL),A
	DEC	HL
	DEC	HL		; stack base
	RET

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
	JP	S_TIME_END

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

S_LBLS:	LD	B,0
	CALL	S_LBLL
S_LBLE:	LD	BC,L26C3	; S_NUMERIC
	PUSH	BC
	JR	CSWAPR

S_LBLL:	RST	$20
	RST	$28
	DEFW	L2C88		; ALPHANUM
	INC	B
	JR	Z,ERR_CL
S_LBLI:	JR	C,S_LBLL
	DJNZ	S_LBLC
ERR_CL:	JP	ERROR_C
S_LBLC:	LD	BC,$0006
	RST	$28
	DEFW	L1655		; MAKE-ROOM
	INC	HL
	LD	(HL),$0E
	LD	BC,$0500	; TODO: maybe B is enough
S_LBL0:	INC	HL
	LD	(HL),C
	DJNZ	S_LBL0
	RST	$28
	DEFW	L0077		; TEMP-PTR1
	RET

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

ERROR_6:RST	$28
	DEFW	L31AD		; 6 Number too big

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

; STR$() with multiple arguments
S_STR_NEW:
	POP	BC		; discard STR$ and priority
	CP	","
	JR	NZ,ERROR_C
	CALL	SYNTAX_Z
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
	CALL	SYNTAX_Z
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
	CALL	SYNTAX_Z
	JR	Z,S_STR_D
	PUSH	AF
	CALL	STACK0
	POP	AF
	JR	S_STR_D

ERROR_C:RST	$28
	DEFW	L1C8A		; C Nonsense in BASIC

S_STR3:	CP	","
	JR	NZ,ERROR_C
	RST	$20
	RST	$28
	DEFW	L1C82		; CLASS_06, numeric expression followed by whatever
	CP	")"
	JR	NZ,ERROR_C	; must be followed by ")"
	CALL	SYNTAX_Z
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
	LD	(STKEND),HL
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

D_TIMES:POP	HL		; discard return address
	POP	HL		; RE-ENTRY
	POP	DE		; discard BREG?
	POP	DE		; discard USR
	LD	DE,$106F	; CHR$
	PUSH	DE		; replace by CHR$
	LD	DE,0
	PUSH	DE		; BREG = 0
	PUSH	HL
	LD	BC,2+1+2+1+2+1+2
	RST	$30
	EX	DE,HL
	LD	HL,TIMEFE
TIMESL:	LD	A,(HL)
	CP	$0B
	JR	NC,TIMESD
	PUSH	BC
	PUSH	DE
	PUSH	HL
	RST	$28
	DEFW	L2D28		; STACK-A
	CALL	MOD2A
	POP	HL
	POP	DE
	POP	BC
	ADD	"0"
	LD	(DE),A
	LD	A,C
	CP	2+1+2+1+2+1+2
	JR	NZ,TIMESN
	LD	A,(DE)
	ADD	A,A
	SUB	A,"0"
	LD	(DE),A
TIMESN:	DEC	HL
	DEC	DE
	DEC	C
	JR	NZ,TIMESL
	INC	DE
	XOR	A
	LD	HL,(STKEND)
	DEC	HL
	LD	(HL),A
	DEC	HL
	LD	(HL),2+1+2+1+2+1+2
	DEC	HL
	LD	(HL),D
	DEC	HL
	LD	(HL),E
	LD	DE,(STKEND)
TMSW:	JP	SWAP

TIMESD:	LDD
	JR	TIMESL

TIMEF:	DEFB	10,10,":",6,10,":",6,10,".",10
TIMEFE:	DEFB	5

S_REF:	RST	$20		; advance past the REF token
	RST	$28
	DEFW	L28B2		; LOOK-VARS
	JP	C,ERROR_2
	JR	NZ,NOREF
	RST	$28
	DEFW	L2996		; STK_VAR
	LD	A,(FLAGS)
	ADD	A,A
	JP	NC,S_LBLE
	ADD	A,A
	JR	C,S_REFBC
	RST	$28
	DEFW	L2BF1		; STK-FETCH
	LD	B,D
	LD	C,E
	JR	S_REF_D
NOREF:	LD	A,(FLAGS)
	CP	$C0
S_REF_E:JP	C,S_LBLE
S_REFBC:INC	HL
	LD	B,H
	LD	C,L
S_REF_D:RST	$28
	DEFW	L2D2B + 4	; STACK-BC
	JP	S_LBLE
