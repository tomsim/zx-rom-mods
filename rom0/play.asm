DURATION:	EQU	0
COUNTER:	EQU	1
OCTAVE:		EQU	2
ENVELOPE:	EQU	3
VOLUME:		EQU	4
PSG_CH:		EQU	5


PLAY:	RST	$30
	DEFW	L1C8C		; CLASS-0A, string expression
	CALL	CHECK_END
	LD	E,7
	LD	A,$3E
	CALL	OUTAY
	RST	$30
	DEFW	L2BF1		; STK-FETCH
	LD	HL,$000F	; PGS_CH=0, VOLUME=15
	PUSH	HL
	LD	L,$05		; ENVELOPE=0, OCTAVE=5
	PUSH	HL
	LD	L,$18		; COUNTER=0, DURATION=24
	PUSH	HL
	LD	IX,0
	ADD	IX,SP
PLAY_LOOP:
	PUSH	DE
	PUSH	BC
	CALL	PLAY_SCAN
	POP	BC
	POP	DE
	CP	")"
	JR	Z,PLAY_LOOP
	POP	HL
	POP	HL
	POP	HL		; discard PLAY state
	RET

PLAY_TAB:
	DEFM	"N"
	DEFB	PLAY_SCAN - $
	DEFM	"O"
	DEFB	PLAY_OCTAVE - $
	DEFM	"("
	DEFB	PLAY_REP - $
	DEFM	"H"
	DEFB	PLAY_RET - $
	DEFM	")"
	DEFB	PLAY_RET - $
	DEFM	"V"
	DEFB	PLAY_VOLUME - $
	DEFM	"U"
	DEFB	PLAY_SETENV - $
	DEFM	"W"
	DEFB	PLAY_ENVELOPE - $
	DEFM	"X"
	DEFB	PLAY_ENVDUR - $
	DEFM	"T"
	DEFB	PLAY_TEMPO - $
	DEFM	"!"
	DEFB	PLAY_COMMENT - $
PLAY_TTAB:
	DEFM	"#"
	DEFB	PLAY_SHARP - $
	DEFM	"$"
	DEFB	PLAY_FLAT - $
	DEFM	"&"
	DEFB	PLAY_REST - $
	DEFB	0

PLAY_ENVDUR:
	CALL	PLAY_NUM
	EX	AF,AF'
	PUSH	DE
	LD	E,11
	LD	A,L
	PUSH	BC
	CALL	OUTAY
	INC	E
	LD	A,H
	CALL	OUTAY
	POP	BC
	POP	DE
	JR	PLAY_CONT_EX

PLAY_ENVELOPE:
	CALL	PLAY_NUM
	EX	AF,AF'
	LD	A,7
	CALL	PLAY_RANGE
	PUSH	DE
	LD	DE,ENVELOPES
	ADD	HL,DE
	POP	DE
	LD	A,(HL)
	LD	(IX+ENVELOPE),A
	JR	PLAY_CONT_EX

PLAY_SETENV:
	CALL	PLAY_NEXT
	RET	Z
	EX	AF,AF'
	LD	L,$1F
	JR	PLAY_SETVOL

PLAY_COMMENT:
	CALL	PLAY_NEXT
PLAY_RET:
	RET	Z
	CP	"!"
	JR	Z,PLAY_SCAN
	JR	PLAY_COMMENT

PLAY_REP:
	PUSH	DE
	PUSH	BC
	CALL	PLAY_SCAN
	POP	BC
	POP	DE
	CALL	PLAY_SCAN
	JR	PLAY_SCAN

PLAY_OCTAVE:
	CALL	PLAY_NUM
	EX	AF,AF'
	LD	A,8
	CALL	PLAY_RANGE
	LD	(IX+OCTAVE),L
	JR	PLAY_CONT_EX

PLAY_TEMPO:
	CALL	PLAY_NUM
	EX	AF,AF'
	LD	A,240
	CALL	PLAY_RANGE
	LD	A,59
	CP	L
	JR	NC,PLAY_ERROR_NC
	LD	A,L
	LD	(TEMPO),A
	JR	PLAY_CONT_EX

PLAY_TRIPLET:
	PUSH	HL
	LD	A,3
PLAY_TL:PUSH	AF
	CALL	PLAY_STEP
	CALL	NOTE
	JR	C,PLAY_NOTE
	LD	HL,PLAY_TTAB
	JR	PLAY_INDEX

PLAY_VOLUME:
	CALL	PLAY_NUM
	EX	AF,AF'
	LD	A,15
	CALL	PLAY_RANGE
PLAY_SETVOL:
	LD	(IX+VOLUME),L
PLAY_CONT_EX:
	EX	AF,AF'
	JR	PLAY_CONT

NOTE_LENGTH:
	CALL	PLAY_NUMERIC
	RET	Z
	DEC	DE
	INC	BC
	PUSH	BC
	CALL	PLAY_RANGE12
	LD	BC,DURATIONS
	LD	A,L
	ADD	HL,BC
	CP	10
	LD	A,(HL)
	LD	H,(IX+DURATION)
	LD	(IX+DURATION),A
	POP	BC
	JR	NC,PLAY_TRIPLET
PLAY_SCAN:
	CALL	PLAY_NEXT
PLAY_CONT:
	RET	Z
	CALL	NOTE
	JR	C,PLAY_NOTE
	RST	$30
	DEFW	L2D1B		; NUMERIC
	JR	NC,NOTE_LENGTH
	LD	HL,PLAY_TAB
PLAY_INDEX:
	PUSH	BC
	LD	C,A
	CALL	INDEXER
	JR	NC,PLAY_ERROR_NC
	LD	C,(HL)
	LD	B,$00
	ADD	HL,BC
	POP	BC
	JP	(HL)

PLAY_REST:
	PUSH	BC
	PUSH	DE
	JR	PLAY_TOO_LOW

PLAY_SHARP:
	CALL	PLAY_STEP
	CALL	NOTE
	JR	NC,PLAY_ERROR_NC
	INC	A
	JR	PLAY_NOTE

PLAY_FLAT:
	CALL	PLAY_STEP
	CALL	NOTE
PLAY_ERROR_NC:
	JP	NC,PLAY_ERROR
	DEC	A
PLAY_NOTE:
	INC	A
PLAY_FNOTE:
	PUSH	BC
	ADD	A,A
	CP	$18
	JR	C,PLAY_LOW
	SUB	A,$18
PLAY_LOW:
	LD	C,A
	LD	A,(IX+OCTAVE)
	SBC	A,$FF
	LD	B,0
	LD	HL,NOTES
	ADD	HL,BC
	PUSH	DE
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	OR	A
	JR	Z,PLAY_TOO_LOW
	DEC	A
	JR	Z,NOTE_DONE
	LD	B,A
NOTE_L:	SRL	D
	RR	E
	DJNZ	NOTE_L
	JR	NC,NOTE_DONE
	INC	DE
NOTE_DONE:
	BIT	4,D
	JR	NZ,PLAY_TOO_LOW
	LD	A,E
	LD	E,0
	CALL	OUTAY
	INC	E
	LD	A,D
	CALL	OUTAY
	LD	A,(IX+VOLUME)
	LD	E,8
	CALL	OUTAY
	LD	A,(IX+ENVELOPE)
	LD	E,13
	OR	A
	CALL	NZ,OUTAY
PLAY_TOO_LOW:
	LD	DE,125
	LD	L,(IX+DURATION)
	LD	H,D
	RST	$30
	DEFW	L30A9		; HLxDE
	LD	E,(IX+COUNTER)
	AND	A
	SBC	HL,DE
	LD	A,(TEMPO)
	LD	E,A
PLAY_HOLD:
	HALT
	SBC	HL,DE
	JR	Z,PLAY_DONE
	JR	NC,PLAY_HOLD
PLAY_DONE:
	LD	E,8
	XOR	A
	CALL	OUTAY
	POP	DE
	LD	A,L
	NEG
	LD	(IX+COUNTER),A
	LD	A,(IX+DURATION)
	LD	L,A
	DEC	A
	AND	L
	POP	BC
	JR	NZ,PLAY_SCAN2
	POP	AF
	DEC	A
	JP	NZ,PLAY_TL
	POP	HL
	LD	(IX+DURATION),H
PLAY_SCAN2:
	JP	PLAY_SCAN

PLAY_STEP:
	CALL	PLAY_NEXT
	RET	NZ
PLAY_ERROR:
	RST	$30
	DEFW	L34E7		; A Invalid argument

PLAY_NEXT:
	LD	A,B
	OR	C
	RET	Z
	LD	A,(DE)
	INC	DE
	DEC	BC
	RET

PLAY_NUM:
	CALL	PLAY_STEP
	RST	$30
	DEFW	L2D1B		; NUMERIC
	JR	C,PLAY_ERROR
PLAY_NUMERIC:
	SUB	A,"0"
	LD	L,A
	LD	H,0
PLAYNL:	CALL	PLAY_NEXT
	RET	Z		; end-of-string
	RST	$30
	DEFW	L2D1B		; NUMERIC
	RET	C
	SUB	A,"0"
	PUSH	BC
	LD	C,L
	LD	B,H
	ADD	HL,HL		; HL * 2
	ADD	HL,HL		; HL * 4
	ADD	HL,BC		; HL * 5	note 9999*5=49995<65536
	POP	BC
	ADD	HL,HL		; HL * 10
	JR	C,PLAY_ERROR
	ADD	A,L
	LD	L,A
	JR	NC,PLAYNL
	INC	H
	JR	NZ,PLAYNL
	JR	PLAY_ERROR

PLAY_RANGE12:
	LD	A,12
PLAY_RANGE:
	CP	L
	JR	C,PLAY_ERROR
	DEC	H
	INC	H
	RET	Z
	JR	PLAY_ERROR

ENVELOPES:
	DEFB	$09, $0F, $0B, $0D, $08, $0C, $0E, $0A

DURATIONS: 			; multiply by 125 for BPM
	DEFB	3, 6, 9, 12, 18, 24, 36, 48, 72, 96, 4, 8, 16

NOTES:	DEFW	$1C0E		; Cb0	15.43 Hz
	DEFW	$1A7B		; C0	16.35 Hz
	DEFW	$18FE		; C#0	17.32 Hz
	DEFW	$1797		; D0	18.35 Hz
	DEFW	$1644		; D#0	19.45 Hz
	DEFW	$1504		; E0	20.60 Hz
	DEFW	$13D6		; F0	21.83 Hz
	DEFW	$12B9		; F#0	23.12 Hz
	DEFW	$11AC		; G0	24.50 Hz
	DEFW	$10AE		; G#0	25.96 Hz
	DEFW	$0FBF		; A0	27.50 Hz
	DEFW	$0EDC		; A#0	29.14 Hz
	DEFW	$0E07		; B0	30.87 Hz
	DEFW	$0D3D		; C1	32.70 Hz

NOTE:	RST	$30
	DEFW	L2C8D		; ALPHA
	RET	NC
	CP	"h"
	RET	NC
	BIT	5,A
	JR	NZ,NOTE1
	CP	"H"
	RET	NC
	OR	$20
	CALL	NOTE1
	SUB	A,-12		; sets CF
	RET

NOTE1:	SUB	A,"c"
	JR	NC,NOTE2
	ADD	A,7
NOTE2:	ADD	A,A
	CP	5
	ADC	A,$FF		; sets CF
	RET

OUTAY:	LD	BC,$FFFD
	OUT	(C),E
	LD	B,$BF
	OUT	(C),A
	RET

