MAKE_B:	LD      BC,$000B
	PUSH	HL
	LD	HL,(PROG)
	DEC	HL
        PUSH    BC
        RST	$28
	DEFW	L1655		; MAKE-ROOM
        POP     BC
	POP	HL
        LDDR
        EX      DE,HL
	RET

ERROR_F:RST	$28
	DEFW	L1765		; F Invalid file name

OPENSTRM2:
	DEFB	"X"
	DEFB	OPENX - $
	DEFB	"Z"
	DEFB	OPENZ - $
	DEFB	0

CLOSESTRM2:
	DEFB	"X"
	DEFB	CLOSEX - $
	DEFB	0

CLOSEX:	LD	HL,BANK_M
	LD	A,(HL)
	OR	A
	JR	NZ,CLOSE_NX
	PUSH	DE		; save letter address
	INC	DE
	INC	DE
	LD	A,(DE)		; reclaim bank
	LD	BC,$7FFD
	LD	(HL),A
	OUT	(C),A
	LD	A,(BANK_F)
	LD	($FFFF),A
	LD	A,(HL)
	LD	(BANK_F),A
	XOR	A
	LD	(HL),A
	OUT	(C),A
	INC	DE
	INC	DE
	INC	DE
	EX	DE,HL
	LD	C,(HL)		; fetch descriptor length
	INC	HL
	LD	B,(HL)
	POP	HL		; restore letter address
	DEC	HL
	DEC	HL
	DEC	HL
	DEC	HL		; HL = descriptor start
	RST	$28
	DEFW	L19E8		; RECLAIM-2
CLOSE_NX:
	POP	AF
HLSW:	POP	HL
	JP	SWAP

OPENX:	LD	E,$15
	JR	OPENXZ
OPENZ:	LD	E,$20

OPENXZ:	POP	BC		; length of channel description
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,ERROR_F
	LD	D,0
	LD	A,(BANK_M)
	OR	A
	JR	NZ,HLSW
	LD	A,$15
	CP	E
	JR	Z,OPENX1
	LD	DE,(CHANZ)
	LD	A,D
	OR	E
	JR	NZ,HLSW
	LD	HL,Z_CHAN_E - 1
	CALL	MAKE_B
	LD	DE,(CHANS)
	AND	A
	SBC	HL,DE
	INC	HL
	INC	HL
	LD	(CHANZ),HL
	EX	DE,HL		; TODO: can be saved, if necessary
	JR	HLSW

ERROR_4:RST	$28
	DEFW	L1F15		; 4 Out of memory

OPENX1:	LD      HL,X_CHAN_E - 1
	CALL	MAKE_B
	LD	A,(BANK_F)
	INC	A
	JR	Z,ERROR_4
	DEC	A
	PUSH	HL
	POP	IX
	LD	(IX+7),A
        LD      DE,(CHANS)
        AND     A
        SBC     HL,DE
        INC     HL
        INC     HL
	PUSH	HL		; save channel offset

NEWCO:	LD	(OLDSP),SP
	LD	SP,TSTACK
	LD	BC,$7FFD
	LD	(BANK_M),A
	OUT	(C),A
	LD	A,($FFFF)
	LD	(BANK_F),A
	LD	DE,$C000
	LD	HL,EMPTY_STRMS
	LD	BC,EMPTY - EMPTY_STRMS
	LDIR			; streams $FD, $FE, $FF, $00, $01, $02, $03
	LD	L,E
	LD	H,D
	INC	E
	LD	(HL),B
	LD	C,NEWVARS - NEWSTRMS + EMPTY_STRMS - EMPTY - 1
	LDIR			; all other streams are closed
	LD	HL,EMPTY
	LD	C,EMPTY2 - EMPTY
	LDIR			; system variables
	LD	HL,CHINFO0
	LD	C,CHINFO0_E - CHINFO0 - 1
	LDIR			; channels K, S, R, P
	LD	HL,EMPTY2
	LD	C,EMPTY_E - EMPTY2
	LDIR			; channels X,Z and empty program
	LD	HL,EMPTY_STK
	LD	DE,$FFFA
	LD	(NEWERR_SP),DE
	LD	C,6
	LDIR
	LD	A,(BANK_M)
	PUSH	AF
	XOR	A
	LD	BC,$7FFD
	LD	(BANK_M),A
	OUT	(C),A
	POP	AF
	LD	SP,(OLDSP)
	CALL	SWAPIN
	POP	DE	; restore channel offset
	POP	HL	; restore HL
	JP	SWAP

X_OUT:	EX	AF,AF'
	LD	HL,(CURCHL)
	LD	DE,6
	ADD	HL,DE
	LD	A,(HL)
	CALL	SWAPIN_SAVE
	JP	SWAP

SWAPIN_SAVE:
	EXX
	PUSH	BC
	PUSH	DE
	PUSH	HL
	CALL	SWAPIN
	POP	HL
	POP	DE
	POP	BC
	EXX
	RET

SWAPIN:	LD	(OLDSP),SP
	CALL	SWAP_SYSVARS
	LD	SP,(NEWSP)
	RET

SWAPOUT:LD	(NEWSP),SP
	LD	A,(BANK_M)
	CALL	SWAP_SYSVARS
	XOR	A
	LD	BC,$7FFD
	LD	(BANK_M),A
	OUT	(C),A
	LD	SP,(OLDSP)
	RET

NEW_X_OUT:
	JR	C,NEW_X_OUT_1
	LD	IX,(CURCHL)
	BIT	0,(IX+5)
	JR	NZ,NX_SW	; No controls with full buffer
NEW_X_OUT_1:
	LD	(IY+$00),$FF	; Do not pass error condition
	CALL	SWAPOUT_SAVE
	JR	NC,NX_SW	; No output clash
	LD	IX,(CURCHL)
	LD	(IX+6),A
	SET	0,(IX+5)
NX_SW:	JP	SWAP

NEW_X_IN:
	LD	HL,(CURCHL)
	LD	DE,5
	ADD	HL,DE
	BIT	0,(HL)		; First check the buffer
	JR	Z,NEW_X_IN_1
	RES	0,(HL)
	INC	HL
	LD	A,(HL)
	SCF
	JP	SWAP
NEW_X_IN_1:
	XOR	A
	CALL	SWAPOUT_SAVE
	JP	SWAP

SWAPOUT_SAVE:
	EX	AF,AF'
	EXX
	PUSH	BC
	PUSH	DE
	PUSH	HL
	CALL	SWAPOUT
	POP	HL
	POP	DE
	POP	BC
	EXX
	EX	AF,AF'
	RET

X_IN:	XOR	A
	EX	AF,AF'		; Reads on the other side return empty.
	LD	HL,(CURCHL)
	LD	DE,6
	ADD	HL,DE
	LD	A,(HL)
	CALL	SWAPIN_SAVE
	EX	AF,AF'
	JR	C,XI_SW		; Not channel state control
	PUSH	AF
	LD	A,$7F		; This is copied from L1F54 for speed
	IN	A,($FE)
	RRA
	JR	C,X_IN_C
	RST	$28
	DEFW	X1F5A
	JP	NC,ERROR_L	; Allow for BREAKing out of read-read deadlock
X_IN_C:	POP	AF
	OR	A
	JR	Z,XI_SW		; RESET passed on as empty string
	CP	$20		; control codes passed on, $20 as empty string, else EOF
XI_SW:	JP	SWAP

SWAP_SYSVARS:
	LD	DE,TSTACK
	LD	HL,RAMTOP+1
	LDD
	LDD
	LD	L,FLAGX - KSTATE
	LD	BC,4
	LDDR
	LD	L,STKEND+1 - KSTATE
	LD	BC,30
	LDDR
	DEC	L	; SUBPPC
	LD	C,6
	LDDR
	LD	L,ERR_SP+1 - KSTATE
	LDD
	LDD
	LD	L,STRMS+37 - KSTATE
	LD	BC,38
	LDDR
	EX	DE,HL
	POP	BC	; RET address
	DEC	L
	LD	(HL),B
	DEC	L
	LD	(HL),C	; moved to temporary stack
	LD	SP,HL
	LD	BC,$7FFD
	LD	(BANK_M),A
	OUT	(C),A
	INC	E
	LD	HL,NEWSTRMS
	LD	BC,38
	LDIR
	LD	E,ERR_SP - KSTATE
	LDI
	LDI
	LD	E,NEWPPC - KSTATE
	LD	BC,6
	LDIR
	INC	E
	LD	C,30
	LDIR
	LD	E,OLDPPC - KSTATE
	LD	C,4
	LDIR
	LD	E,RAMTOP - KSTATE
	LDI
	LDI
	EX	DE,HL
	DEC	E
	LD	HL,TSTACK
	LD	BC,NEWCHINFO-NEWSTRMS
	LDDR
	RET

PROGVAL:EQU	NEWCHINFO + $0B + $0B + 1 + $14

EMPTY_STRMS:
	DEFW	$0001,$0020,$000B,$0015,$0001,$0006,$0010	; K,Z,R,X,K,S,P
EMPTY:	DEFW	PROGVAL		; VARS
	DEFW	0		; DEST
	DEFW	NEWCHINFO	; CHANS
	DEFW	0		; CURCHL
	DEFW	PROGVAL		; PROG
	DEFW	0		; NXTLIN
	DEFW	PROGVAL-1	; DATADD
	DEFW	PROGVAL+1	; E_LINE
	DEFW	0		; K_CUR
	DEFW	0		; CH_ADD
	DEFW	0		; X_PTR
	DEFW	PROGVAL+3	; WORKSP
	DEFW	PROGVAL+3	; STKBOT
	DEFW	PROGVAL+3	; STKEND
	DEFW	0		; OLDPPC
	DEFB	0		; OSPCC
	DEFB	0		; FLAGX
	DEFW	$FFFD		; RAMTOP
EMPTY2:
NEW_X_CHAN:
	DEFW	NXOUT
	DEFW	NXIN
	DEFB	"X"
	DEFB	0		; flags 0 - buffer empty/full
	DEFB	0		; buffer
	DEFW	0		; ?
	DEFW	NEW_X_CHAN_E-NEW_X_CHAN
NEW_X_CHAN_E:	EQU	$
Z_CHAN:	DEFW	ZOUT
	DEFW	ZIN
	DEFB	"Z"
	DEFS	4
	DEFW	Z_CHAN_E - Z_CHAN
Z_CHAN_E:	EQU	$
EMPTY3:	DEFB	$80,$80,$0D,$80	; channels terminator, empty BASIC program, empty editor line
EMPTY_E:	EQU	$

EMPTY_STK:
	DEFW	MAIN1,$3E00,$FFFA

X_CHAN:	DEFW	XOUT
	DEFW	XIN
	DEFB	"X"
	DEFB	0		; flags
	DEFB	0		; memory bank
	DEFW	0		; ?
	DEFW	X_CHAN_E - X_CHAN
X_CHAN_E:	EQU	$

