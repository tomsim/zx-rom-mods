	INCLUDE	"../labels.asm"
	org	64640

ELLIP:	LD	HL,$000C
	ADD	HL,SP
	LD	SP,HL
	POP	BC
	LD	HL,$202F
	AND	A
	SBC	HL,BC
	JP	NZ,L1C8A

	RST	$20
	CALL	L1C7A		; read coordinate pair
	CALL	RESTK2
	RST	$20
	CALL	L1C7A		; read semiaxes
	CALL	RESTK2

	RST	$28		; calculate
	DEFB	$C1		; store ry
	DEFB	$02		; delete
	DEFB	$C0		; store rx
	DEFB	$02		; delete
	DEFB	$01		; exchange
	DEFB	$C2		; store cx
	DEFB	$E0		; get rx
	DEFB	$0F		; add cx + rx
	DEFB	$01		; exchange
	DEFB	$C3		; store cy
	DEFB	$38		; end
	CALL	L2307		; STK-TO-BC
	CALL	L22E5		; PLOT-SUB
	LD	A,(COORDS)
	CALL	L2D28		; STACK-A x
	LD	A,(COORDS+1)
	CALL	L2D28		; STACK-A y
	RST	$28
	DEFB	$E3		; get cy
	DEFB	$03		; sub y - cy
	DEFB	$31		; dup
	DEFB	$31		; dup
	DEFB	$04		; mul SQ(y-cy)
	DEFB	$E1		; get ry
	DEFB	$31		; dup
	DEFB	$04		; mul SQ ry
	DEFB	$C1		; store rry
	DEFB	$05		; div
	DEFB	$C5		; store yy
	DEFB	$02		; delete
	DEFB	$34,$32,$00	; stk 2 (float)
	DEFB	$E1		; get rry
	DEFB	$05		; div
	DEFB	$C3		; store ddy
	DEFB	$04		; mul
	DEFB	$C1		; store dy
	DEFB	$02		; delete
	DEFB	$E2		; get cx
	DEFB	$03		; sub x - cx
	DEFB	$31		; dup
	DEFB	$31		; dup
	DEFB	$04		; mul SQ(x-cx)
	DEFB	$E0		; get rx
	DEFB	$31		; dup
	DEFB	$04		; mul SQ rx
	DEFB	$C0		; store rrx
	DEFB	$05		; div
	DEFB	$E5		; get yy
	DEFB	$0F		; add xx + yy
	DEFB	$C4		; store rr
	DEFB	$02		; delete
	DEFB	$34,$32,$00	; stk 2 (float)
	DEFB	$E0		; get rrx
	DEFB	$05		; div
	DEFB	$C2		; store ddx
	DEFB	$04		; mul
	DEFB	$C0		; store dx
	DEFB	$02		; delete
	DEFB	$38		; end

DX:	EQU	MEMBOT
DY:	EQU	DX + 5
DDX:	EQU	DY + 5
DDY:	EQU	DDX + 5
RR:	EQU	DDY + 5

	LD	B,5
	LD	HL,MEMBOT
ELL0:	PUSH	BC
	CALL	L2F9B		; PREP-ADD
	EX	AF,AF'		; save exponent
	LD	A,(HL)
	INC	HL
	LD	B,(HL)
	INC	HL
	LD	C,(HL)
	INC	HL
	LD	D,(HL)
	INC	HL
	LD	E,(HL)
	PUSH	HL
	PUSH	BC
	EXX
	POP	DE
	LD	L,A
	EXX
	EX	AF,AF'
	LD	B,A		; restore exponent
	LD	A,$81
	SUB	B		; no overflow possible here?
	CALL	L2FDD		; SHIFT-FP
	EXX
	PUSH	DE
	LD	A,L
	EXX
	POP	BC
	; store in little-endian order
	LD	(HL),A
	DEC	HL
	LD	(HL),B
	DEC	HL
	LD	(HL),C
	DEC	HL
	LD	(HL),D
	DEC	HL
	LD	(HL),E
	POP	HL
	INC	HL
	POP	BC
	DJNZ	ELL0

ELL1:	CALL	SDX2
ELL1C:	CALL	DXGDY
	JR	C,ELL2
	CALL	INCY
	LD	A,(RR+3)
	ADD	A,A
	JR	NC,ELL1P
	CALL	DECX
	CALL	ADDX2
ELL1P:	CALL	DO_PLOT
	JR	ELL1C
ELL2:	CALL	ADX2

	CALL	ADY2
ELL2C:	LD	A,(DX+3)
	ADD	A,A
	JR	C,ELL3
	CALL	DECX
	LD	A,(RR+3)
	ADD	A,A
	JR	C,ELL2P
	CALL	INCY
	CALL	ADDY2
ELL2P:	CALL	DO_PLOT
	JR	ELL2C

ELL3:	DEC	(IY+COORDS-ERR_NR)
	CALL	DO_PLOT

	CALL	SDY
ELL3C:	CALL	MDXGDY
	JR	NC,ELL4
	CALL	DECX
	LD	A,(RR+3)
	ADD	A,A
	JR	NC,ELL3P
	CALL	DECY
	CALL	ADDY2
ELL3P:	CALL	DO_PLOT
	JR	ELL3C
ELL4:	CALL	ADY2

	CALL	SDX2
ELL4C:	LD	A,(DY+3)
	ADD	A,A
	JR	C,ELL5
	CALL	DECY
	LD	A,(RR+3)
	ADD	A,A
	JR	C,ELL4P
	CALL	DECX
	CALL	ADDX2
ELL4P:	CALL	DO_PLOT
	JR	ELL4C

ELL5:	DEC	(IY+COORDS+1-ERR_NR)
	CALL	DO_PLOT

	CALL	ADX
ELL5C:	CALL	DXGDY
	JR	NC,ELL6
	CALL	DECY
	LD	A,(RR+3)
	ADD	A,A
	JR	NC,ELL5P
	CALL	INCX
	CALL	ADDX2
ELL5P:	CALL	DO_PLOT
	JR	ELL5C
ELL6:	CALL	SDX2

	CALL	SDY2
ELL6C:	LD	A,(DX+3)
	ADD	A
	JR	NC,ELL7
	CALL	INCX
	LD	A,(RR+3)
	ADD	A,A
	JR	C,ELL6P
	CALL	DECY
	CALL	ADDY2
ELL6P:	CALL	DO_PLOT
	JR	ELL6C

ELL7:	INC	(IY+COORDS-ERR_NR)
	CALL	DO_PLOT

	CALL	ADY
ELL7C:	CALL	MDXGDY
	JR	C,ELL8
	CALL	INCX
	LD	A,(RR+3)
	ADD	A,A
	JR	NC,ELL7P
	CALL	INCY
	CALL	ADDY2
ELL7P:	CALL	DO_PLOT
	JR	ELL7C
ELL8:	CALL	SDY2

	CALL	ADX2
ELL8C:	LD	A,(DY+3)
	ADD	A,A
	JR	NC,ELL9
	CALL	INCY
	LD	A,(RR+3)
	ADD	A,A
	JR	C,ELL8P
	CALL	INCX
	CALL	ADDX2
ELL8P:	CALL	DO_PLOT
	JR	ELL8C

ELL9:
	LD	HL,$2758
	EXX
	RET

INCX:	INC	(IY+COORDS-ERR_NR)
	LD	BC,(DX+2)
	LD	DE,(DX)
	CALL	ADD2RR
	LD	HL,(DDX)
	ADD	HL,DE
	LD	(DX),HL
	LD	HL,(DDX+2)
	ADC	HL,BC
	LD	(DX+2),HL
	RET

INCY:	INC	(IY+COORDS+1-ERR_NR)
	LD	BC,(DY+2)
	LD	DE,(DY)
	CALL	ADD2RR
	LD	HL,(DDY)
	ADD	HL,DE
	LD	(DY),HL
	LD	HL,(DDY+2)
	ADC	HL,BC
	LD	(DY+2),HL
	RET

DECX:	DEC	(IY+COORDS-ERR_NR)
	LD	BC,(DDX+2)
	LD	DE,(DDX)
	LD	HL,(DX)
	AND	A
	SBC	HL,DE
	LD	(DX),HL
	EX	DE,HL
	LD	HL,(DX+2)
	SBC	HL,BC
	LD	(DX+2),HL
	LD	B,H
	LD	C,L
	JR	SUB2RR

DECY:	DEC	(IY+COORDS+1-ERR_NR)
	LD	BC,(DDY+2)
	LD	DE,(DDY)
	LD	HL,(DY)
	AND	A
	SBC	HL,DE
	LD	(DY),HL
	EX	DE,HL
	LD	HL,(DY+2)
	SBC	HL,BC
	LD	(DY+2),HL
	LD	B,H
	LD	C,L
	JR	SUB2RR

SDY:	LD	BC,(DY+2)
	LD	DE,(DY)
	JR	SUB2RR
SDY2:	LD	BC,(DY+2)
	LD	DE,(DY)
	JR	SUB2
SDX2:	LD	BC,(DX+2)
	LD	DE,(DX)
SUB2:	SRA	B
	RR	C
	RR	D
	RR	E
SUB2RR:	AND	A
	LD	HL,(RR)
	SBC	HL,DE
	LD	(RR),HL
	LD	HL,(RR+2)
	SBC	HL,BC
	LD	(RR+2),HL
	RET

ADY:	LD	BC,(DY+2)
	LD	DE,(DY)
	JR	ADD2RR
ADX:	LD	BC,(DX+2)
	LD	DE,(DX)
	JR	ADD2RR
ADDY2:	LD	BC,(DDY+2)
	LD	DE,(DDY)
	JR	ADD2
ADY2:	LD	BC,(DY+2)
	LD	DE,(DY)
	JR	ADD2
ADDX2:	LD	BC,(DDX+2)
	LD	DE,(DDX)
	JR	ADD2
ADX2:	LD	BC,(DX+2)
	LD	DE,(DX)
ADD2:	SRA	B
	RR	C
	RR	D
	RR	E
ADD2RR:	LD	HL,(RR)
	ADD	HL,DE
	LD	(RR),HL
	LD	HL,(RR+2)
	ADC	HL,BC
	LD	(RR+2),HL
	RET

DXGDY:	LD	DE,DX+3
	LD	HL,DY+3
	LD	B,4
ELLC:	LD	A,(DE)
	CP	(HL)
	RET	NZ
	DEC	HL
	DEC	DE
	DJNZ	ELLC
	RET

MDXGDY:	LD	DE,DX+3
	LD	HL,DY+3
	LD	B,4
ELLMC:	LD	A,(DE)
	CPL
	CP	(HL)
	RET	NZ
	DEC	HL
	DEC	DE
	DJNZ	ELLMC
	RET

RESTK2:	RST	$28
	DEFB	$38
	LD	BC,-5
	LD	D,H
	LD	E,L
	ADD	HL,BC
	JP	L3293		; RE-ST-TWO

DO_PLOT:	LD	BC,(COORDS)
	JP	L22E5 + 4	; PLOT-SUB
