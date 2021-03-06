;; CIRCLE speedup. Fits in the space of the original

STK_TO_A:	EQU	2314H
STK_TO_BC:	EQU	2307H
REPORT_B_3:	EQU	24F9H
PLOT_SUB:	EQU	22E5H
TEMPS:		EQU	0D4DH

		ORG	233BH
C_R_GRE_1:	CALL	STK_TO_A
		PUSH	AF
		CALL	STK_TO_BC
		POP	AF
CIRCLE_INT:	LD	H,A
		LD	L,0
		RRA
CIRCLE_L3:	LD	DE,00FCH
CIRCLE_L1:	PUSH	AF
CIRCLE_L2:	PUSH	HL
		PUSH	BC
		LD	A,B
		ADD	H
		LD	B,A
		LD	A,C
		ADD	L
		LD	C,A
		PUSH	DE
		CALL	PLOT_SUB
		POP	DE
		POP	BC
		POP	HL
		LD	A,0FBH
		CP	E
		LD	A,L
		JR	Z,CIRCLE_M
		NEG
CIRCLE_M:	LD	L,H
		LD	H,A
		INC	E
		JR	NZ,CIRCLE_L2
		DEC	D
		JR	NZ,CIRCLE_N
		NEG
		LD	H,A
CIRCLE_N:	POP	AF
		INC	L
		SUB	A,L
		JR	NC,CIRCLE_NC
		ADD	A,H
		DEC	H
CIRCLE_NC:	LD	E,A
		LD	A,L
		CP	H
		LD	A,E
		JR	Z,CIRCLE_L3
		LD	DE,01F8H
		JR	C,CIRCLE_L1
		JP	TEMPS
