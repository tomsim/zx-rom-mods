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
RST18:	RST	$28
	DEFW	$0018
	RET
	DEFS	$20 - $

; Collect next character
RST20:	RST	$28
	DEFW	$0020
	RET
	DEFS	$28 - $

; Call routine from ROM1
RST28:	EX	(SP),HL
	PUSH	AF
	LD	A,(HL)
	INC	HL
	INC	HL
	JP	CALL_ROM1
	DEFS	$30 - $

; Error restart in this ROM0
RST30:	PUSH	HL
	LD	HL,$0008
	EX	(SP),HL
	JP	SWAP
	DEFS	$38 - $

; IM1 routine
RST38:	PUSH	HL
	LD	HL,POPHLRET
	PUSH	HL
	LD	HL,SWAP
	PUSH	HL
	LD	HL,RST38
	PUSH	HL
	JP	SWAP
POPHLRET:
	POP	HL
	RET

CALL_ROM1:
	LD	(RETADDR),HL
	DEC	HL
	LD	H,(HL)
	LD	L,A
	POP	AF
	LD	(TARGET),HL
	LD	HL,YOUNGER
	EX	(SP),HL
	PUSH	HL
	LD	HL,(TARGET)
	EX	(SP),HL
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
	LD	BC,$7FFD
	LD	A,$30		; ROM 1, RAM 0, paging disabled
	OUT	(C),A

INIT_5B00:	EQU	$

	ORG	$5B00
SWAP:	PUSH	AF
	PUSH	BC
	LD	BC,$7FFD
	LD	A,(BANK_M)
	XOR	$10
;;; Interrupts are best left alone.
;;;	DI
	LD	(BANK_M),A
	OUT	(C),A
;;;	EI
	POP	BC
	POP	AF
	RET

YOUNGER:CALL	SWAP
	PUSH	HL
	LD	HL,(RETADDR)
	EX	(SP),HL
	RET

RAMNMI:	DI
	LD	A,$10
	LD	BC,$7FFD
	OUT	(C),A
	JP	NMIVEC

POUT:	CALL	IOSWAP
PIN:	CALL	IOSWAP
KOUT:	CALL	IOSWAP
KIN:	CALL	IOSWAP
YOUT:	CALL	IOSWAP
YIN:	CALL	IOSWAP
XOUT:	CALL	IOSWAP
XIN:	CALL	IOSWAP
NXOUT:	CALL	IOSWAP
NXIN:	CALL	IOSWAP
IOSWAP:	LD	DE,IODISP
	PUSH	DE
	JP	SWAP

	DEFS	$5B57 - $
BANK_F:	DEFB	$06
TARGET:	DEFW	0
RETADDR:DEFW	0
BANK_M:	DEFB	0
RAMRST:	RST	$08
RAMERR:	DEFB	$0B
INIT_5B00_L:	EQU	$ - $5B00

	ORG	INIT_5B00 + INIT_5B00_L
IODISP:	EX	AF,AF'
	POP	DE
	LD	HL,IOJP-PIN
	ADD	HL,DE
	JP	(HL)
IOJP:	JP	PR_OUT
	JP	PR_IN
	JP	K_OUT
	JP	K_IN
	JP	Y_OUT
	JP	Y_IN
	JP	X_OUT
	JP	X_IN
	JP	NX_OUT
	JP	NX_IN

PR_OUT:
PR_IN:
K_OUT:
K_IN:
Y_OUT:
Y_IN:
X_OUT:
X_IN:
NX_OUT:
NX_IN:
	JP	SWAP		; Empty plug

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
STARTN:	LD	(RAMTOP),HL
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
	LD	A,$3F
	LD	I,A
	IM	1
	EI
	LD	HL,CHINFO
	LD	(CHANS),HL
	LD	DE,CHINFO0
	LD	BC,$0015
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
	LD	HL,L15C6
	LD	DE,STRMS
	LD	BC,$E
	RST	$28
	DEFW	LDIRR
	LD	(IY+$31),$02
	RST	$28
	DEFW	L0D6B
	LD	DE,COPYRIGHT
	CALL	STDERR_MSG
	XOR	A
	LD	DE,L1539 - 1
	RST	$28
	DEFW	L0C0A
	SET	5,(IY+$02)
	LD	DE,L12A9
	PUSH	DE
	JP	SWAP

STDERR_MSG:
	XOR	A
	PUSH	DE
	RST	$28
	DEFW	L1601
	POP	DE
MESSAGE:LD	A,(DE)
	AND	$7F
	RST	$10		; No need for recursion here
	LD	A,(DE)
	INC	DE
	ADD	A,A
	JR	NC,MESSAGE
	RET

CHINFO0:DEFW	PRINT_OUT
	DEFW	L10A8
	DEFB	"K"
	DEFW	PRINT_OUT
	DEFW	L15C4
	DEFB	"S"
	DEFW	L0F81
	DEFW	L15C4
	DEFB	"R"
	DEFW	POUT
	DEFW	PIN
	DEFB	"P"

COPYRIGHT:
	DEFB	$7F
	DEFM	" 2019 ePoint Systems Ltd"
	DEFB	$8D

	DEFS	$4000 - $