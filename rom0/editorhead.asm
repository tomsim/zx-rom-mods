EDITOR_HEADER0:
	DEFB	$14,$01,$16,$00,$00,$13,$01,$10,$00
	DEFB	$11,$87
	DEFM	"BASIC"
	DEFB	$80 + ":"

EDITOR_HEADER1:
	DEFB	$17,$7A,$00,$11,$02,$18,$10,$06,$1A
	DEFB	$11,$04,$18,$10,$05,$1A,$11,$00,$18
	DEFB	$0F,$A0

EDITOR_HEADERN:
	DEFM	"NUMERI"
	DEFB	$80 + "C"
EDITOR_HEADERS:
	DEFM	"STRIN"
	DEFB	$80 + "G"

EDITOR_HEADERT:
	DEFM	"TEXT"
	DEFB	$80 + " "