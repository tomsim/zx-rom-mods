FP_CALC_2:
	LD	A,(BREG)
	JR	SCAN_ENT

CALCULATE:
	RST	$30
	DEFW	L35BF	; STK-PNTRS
	LD	A,B
	LD	(BREG),A
	EXX
	EX	(SP),HL
	EXX
RE_ENTRY:
	LD	(STKEND),DE
	EXX
	LD	A,(HL)
	INC	HL
	PUSH	HL
SCAN_ENT:
	AND	A
	JP	P,FIRST_3D
	LD	D,A
	AND	$60
	RRCA
	RRCA
	RRCA
	RRCA
	ADD	A,$7C
	LD	L,A
	LD	A,D
	AND	$1F
	JR	ENT_TABLE
FIRST_3D:
	CP	$18
	JR	NC,DOUBLE_A
	EXX
	LD	BC,$FFFB
	LD	D,H
	LD	E,L
	ADD	HL,BC
	EXX
DOUBLE_A:
	CP	$38		; end-calc ?
	JR	Z,END_CALC
	CP	$3B
	JR	Z,FP_CALC_2
	RLCA
	LD	L,A
	OR	A		; jump-true?
	JR	NZ,ENT_TABLE
	DEC	A		; signal jump-true
ENT_TABLE:
	LD	DE,L32D7	; table of addresses
	LD	H,$00
	ADD	HL,DE
	RST	$30
	DEFW	X2AF0		; LD DE,(HL) in ROM1
	LD	HL,RE_ENTRY
	EX	(SP),HL
	CP	2*$33		; jump ?
	JR	Z,JUMP_2
	CP	2*$35		; dec-jr-nz ?
	JR	Z,DEC_JR_NZ
	CP	$FF		; jump-true ?
	JR	Z,JUMP_TRUE
	PUSH	HL
	LD	HL,SWAP
	EX	(SP),HL
	PUSH	DE
	EXX
	LD	BC,(BREG-1)
	CP	2*$34		; stk-data
	JP	NZ,SWAP
; Exceptions that need to be handled in this ROM
STK_DATA:
	POP	HL		; discard jump address
	LD	H,D
	LD	L,E
	RST	$30
	DEFW	L33A9		; TEST-5-SP
; BC = $0005 at this point
	EXX
	PUSH	HL
	EXX
	EX	(SP),HL
	LD	A,(HL)
	AND	$C0
	RLCA
	RLCA
	LD	C,A
	INC	C
	LD	A,(HL)
	AND	$3F
	JR	NZ,FORMEXP
	INC	HL
	LD	A,(HL)
FORMEXP:ADD	A,$50
	LD	(DE),A
	LD	A,$05
	SUB	C
	INC	HL
	INC	DE
	LDIR
	LD	BC,STK_DATA_CONT
	PUSH	BC
	RST	$10

JUMP:	EXX
JUMP_2:	LD	E,(HL)
	LD	A,E
	RLA
	SBC	A,A
	LD	D,A
	ADD	HL,DE
	EXX
	RET

END_CALC:
	POP	HL
	EX	(SP),HL
	EXX
	RET

JUMP_TRUE:
	EXX
	INC	DE
	INC	DE
	LD	A,(DE)
	DEC	DE
	DEC	DE
	AND	A
	JR	NZ,JUMP
	EXX
	INC	HL
	EXX
	RET

DEC_JR_NZ:
	PUSH	HL
	LD	HL,BREG
	DEC	(HL)
	POP	HL
	JR	NZ,JUMP_2
	INC	HL
	EXX
	RET
