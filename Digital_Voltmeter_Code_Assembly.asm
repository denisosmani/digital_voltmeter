;----------- SPI MCP32 ----------------
SCLK EQU 95H ; slaveClock  = 95H = P1.5
MOSI EQU 96H ; Din = 96h = P1.6
SS   EQU 97H ; slaveSelect = 97H = P1.7
MISO EQU 0A0H; Dout = A0 = P2.0
;--------------------------------------

;----------ANALOG MULTIPLEXER----------
OUTSA EQU 0A1H ; A pin of analog mux, 0A1H = P2.1
OUTSB EQU 0A2H ; B pin of analog mux  0A2H = P2.2
;--------------------------------------

;---------BUTTON-SHIFTREGISTER---------
SHLD EQU 0A3H
SHCLK EQU 0A4H
SO EQU 0A5H
;--------------------------------------

;----------------EEPROM----------------
SCL EQU P2.6
SDA EQU P2.7
;--------------------------------------

ORG 0000H
LJMP MAIN
ORG 000BH
LJMP T0_ISR

;----------------------------------MAIN-----------------------------------------
MAIN:
SETB SCL
SETB SDA

SETB OUTSA
SETB OUTSB ; zgjedhet dalja e 4-te default ( range: +/- 199.9 V )

MOV DPTR,#DIGITS ;DPTR = lokacioni i numrave per 7seg

MOV SP,#60H ; <-- STACK

SETB RS1
SETB RS0 ;Selektohet BANK 3

MOV R1,#00H
MOV R0,#50H ;parametrat per rutinen e display

CLR RS1 ;Selektrohet BANK 0
CLR RS0

MOV IE,#82H ;mundeso interruptin per timer0
MOV TMOD,#02H ;timer0 8-bit auto-reload
MOV TL0,#6D ;250 us = 4000Hz
MOV TH0,#6D
SETB TR0 ;fillon numerimi i timer0

MOV 42H,#4D ;4*250us = 1ms / frequency divider

MOV 43H,#00H
MOV 44H,#100D ;100ms msb(43h) dhe lsb(44h)

MOV 56H,#00H
MOV 57H,#100D ;100ms msb(56h) dhe lsb(57h)

MOV 26H,#06H
MOV 27H,#3FH
MOV 28H,#3FH ;vendoset vlera 100 ne display klikon MANUAL_SAMPLE_TIME, default
;---------------------------------/MAIN------------------------------------------


;---------------------------------FLAGS------------------------------------------
CHECK_FLAG_EXECUTE:

JNB 66H,CHECK_FLAG_EXECUTE
CLR 66H

LCALL MANUAL_RANGE

JNB 67H,CHECK_FLAG_EXECUTE ;nese nuk behet asnje matje nuk dergohet asnje byte
CLR 67H

LCALL SEND_ALL_BYTES

SJMP CHECK_FLAG_EXECUTE
;----------------------------------/FLAGS-----------------------------------------

;--------------------------------TIMER_0_ISR--------------------------------------
T0_ISR:
MOV 78H,A
MOV 58H,C
DJNZ 42H,END_T0ISR ;4*250us = 1ms

LCALL DISPLAY_RESULT ;shfaq rezultatin
LCALL GET_UPDATED_BUTTONS ;checks buttons

MOV 42H,#4D ;4*250us = 1ms ;Cdo 1ms mostrohet state-diagram / frequency divider
LCALL RELATIVE_TIME_1MS ;E inkrementron counterin e kohes relative, me rezolucion 1ms

;-----------------------------------------------
LCALL DECREMENT_16BIT ;Mostrohet n * 1ms, ku "n" = nr. 16 bitesh
MOV A,44H
JZ LSB_00
SJMP END_T0ISR
LSB_00:
MOV A,43H
JZ PERFUNDOI_KOHA_MOSTRIMIT
SJMP END_T0ISR ;nese nuk eshte zero
PERFUNDOI_KOHA_MOSTRIMIT:
;rimbushet me vleren e dhene nga perdoruesi
MOV 43H,56H ; MSB (56H) DHE LSB (57H)
MOV 44H,57H ;100ms msb(43h) dhe lsb(44h)
;-----------------------------------------------

SETB 66H ;flagu per mostrim

END_T0ISR:
MOV A,78H
MOV C,58H

RETI
;--------------------------------/TIMER_0_ISR--------------------------------------

;=========================================================================================
;				 FILLON - KOMUNIKIMI ME MCP3208
;=========================================================================================
SAMPLE: ;pas caktimit te brezit adekuat ne menyre automatike, e masim edhe njehere vleren

SETB SS ;mcp3208 nuk eshte e selektuar
CLR SCLK ;clk idles 'low' state, CPOL = 0
CLR MOSI

CLR SS; mcp3208 is selected
SETB MOSI ; START bit
SETB SCLK
NOP
CLR SCLK ;send START bit on falling edge
NOP
SETB SCLK
NOP
CLR SCLK ;send SGL bit MOSI = '1' , on falling edge

CLR MOSI
SETB SCLK
NOP
CLR SCLK ; send D2 = '0', on falling edge
NOP
SETB SCLK
NOP
CLR SCLK ;send D1 = '0', on falling edge
NOP
SETB SCLK

NOP
CLR SCLK  ; send D0 = '0', on falling edge
NOP

SETB SCLK
NOP
CLR SCLK  ;11th falling edge

MOV R4,#5D ;get 4 bits + nullBit
MOV A,#00H ;clr acc
GET_DATA_MSB:
NOP
SETB P2.0 ;P2.0 input pin
SETB SCLK ;(i.e 12th rising edge, null-bit is out)
NOP
MOV C,P2.0
RLC A
CLR SCLK
NOP ; falling edge
DJNZ R4, GET_DATA_MSB
MOV 30H,A


MOV R4,#8D ;get 8 bits
MOV A,#00H ;clr acc
GET_DATA_LSB:
NOP
SETB P2.0 ;P2.0 input pin
SETB SCLK ; (i.e 17th rising edge, null-bit is out)
NOP
MOV C,P2.0
RLC A
CLR SCLK
NOP ; falling edge
DJNZ R4, GET_DATA_LSB
MOV 31H,A
;=========================================================================================
;				  PERFUNDON - KOMUNIKIMI ME MCP3208
;=========================================================================================


;=========================================================================================
;		    FILLON - ZBRITJA, SHUMEZIMI ME 1000 DHE PJESTIMI ME 1024
;=========================================================================================
MOV 54H,#12D ; <--index for blank 1st 7seg
;vjen vlera nga mcp3208 dhe ruhet 30H(MSB) dhe 31H(LSB)
;krahasojme numrin a eshte me i madh se 2048 apo me i vogel
MOV A,30H
CJNE A,#08H,CHECK_CARRY_01     ;if (A)<(data), C=1
MOV A,31H
CJNE A,#00H,CHECK_CARRY_01     ;if(A) < (data), C=1
LJMP GREATER_THAN

CHECK_CARRY_01:
JC LESS_THAN
LJMP GREATER_THAN

;nese numri eshte me i vogel se 2048
;gjejme 2 komplementin e numrit
LESS_THAN:
DEC 54H ; store the dptr for minus sign, index for minus sign 1st 7seg
MOV R7,#17D
;nje komplementi
ONE_COMPLEMENT:
MOV A,30H
RLC A
CPL C
MOV 30H,A
MOV A,31H
RLC A
MOV 31H,A
DJNZ R7,ONE_COMPLEMENT

INC 31H ; add +1 for 2's complement

JC ADD_HIGH ;check if carry again
SJMP SUBTRACT_0

ADD_HIGH: ;nese ka carry shto ne 30H
MOV A,30H
ADDC A,#00H
MOV 30H,A
;SJMP SUBTRACT_0

SUBTRACT_0:
MOV A,#10H ; 4096 D = 1000 H
ADD A, 30H ; fshijme 4 bitat msb
MOV 2FH,A
CLR 7CH
CLR 7DH
CLR 7EH
CLR 7FH
MOV 30H,2FH


GREATER_THAN:
DEC 54H
;nese numri eshte me i madh se 2048
;per ta kthyer vleren ne brez, fillimisht e zbresim me 2048
;ruajme 2 komplementin e 2048 ne (MSB)4EH-4FH, 2 komplementi = 2048 poashtu
MOV 4EH,#08H
MOV 4FH,#00H

MOV A,30H
ADD A,4EH
MOV 2FH,A ;bit adressable

CLR 7CH   ;e fshijm carry pas mbledhjes me dy komplement te 2048
CLR 7DH
CLR 7EH
CLR 7FH
MOV 30H,2FH

;-----------------------------------------------------------------------------------------

;pastaj e shumezojme me 1000
;shumezuesi 1000 ruhet ne 33H(MSB) dhe 34H(LSB)
MOV 33H,#03H
MOV 34H,#0E8H

;kodi me poshte e shumezon numrin 12-bitesh ((MSB)30H-31H) qe vjen nga MCP3208 me 1000((MSB)33H-34H) dhe e ruan ne (MSB)30H-31H-32H
;regjistrat e prishur: 30H - 3AH
;shumezimi me 1000 behet me qellim qe te mos humbin numrat pas presjes kur pjestojme me shiftim
MOV A,31H
MOV B,34H
MUL AB
MOV 32H,A
MOV 35H,B

MOV A,30H
MOV B,34H
MUL AB
MOV 36H,A
MOV 37H,B

MOV A,33H
MOV B,31H
MUL AB
MOV 38H,A
MOV 39H,B

MOV A,33H
MOV B,30H
MUL AB
MOV 3AH,A

MOV A,35H
ADD A,36H
MOV 36H,A

MOV A,37H
ADDC A,39H
MOV 39H,A

MOV A,36H
ADD A,38H
MOV 31H,A

MOV A,39H
ADDC A,3AH
MOV 30H,A
;rezultati i shumezimit del max 3 bytes, ruhet 30H-31H-32H

;----------------------------------------------------------------------------------------

;per ta pjestuar numrin e ruajtur ne 30h-31h-32h me 1024, e shiftojme 10here ne te djathte
;rezultati do te jete 2 bytes ne rastin me te keq dhe ruhet ne (MSB) 31H-32H
MOV R2,#10D
HERE:

MOV A,30H
RRC A
MOV 30H,A

MOV A,31H
RRC A
MOV 31H,A

MOV A,32H
RRC A
MOV 32H,A

CLR C
DJNZ R2, HERE

;=========================================================================================
;		     PERFUNDON - ZBRITJA, SHUMEZIMI ME 1000 DHE PJESTIMI ME 1024
;=========================================================================================


;=========================================================================================
;			    FILLON - EKSTRAKTIMI I SHIFRAVE
;=========================================================================================

;kodi me poshte pjeston me 10 numrin qe gjendet ne (MSB)31H-32H
;dhe e ekstrakton mbetjen, keshtu ndodh 4 here per 4 shifra
MOV R0,#4FH ; ketu ruaj mbetjen
MOV 49H,#0AH ;  store 10

SHIFT_AGAIN:

CJNE R2,#10H,DONT_STORE_0 ; if (R2) < (data), CY=1
LCALL STORE_REMAINDER_0
DONT_STORE_0:		;store remainder
CLR C

;perfundo programin ketu
CJNE R0,#53H,DONT_END
LJMP END_DIVISION
DONT_END:
CLR C


LCALL SHIFT_LEFT
CHECK:
MOV A,49H ; A = 10
CJNE A, 41H, CHECK_CARRY ; if (A)<(data), CY=1
SJMP EQUAL
CHECK_CARRY:
JNB C, SHIFT_AGAIN

CLR C ;C fshihet qe te mos e ndikoj zbritjen
EQUAL:
MOV A,41H
SUBB A,49H
MOV 41H,A

CJNE R2,#10H,DONT_STORE_1 ; if (R2) < (data), CY=1
LCALL STORE_REMAINDER_1
DONT_STORE_1:

SETB C
LCALL SHIFT_LEFT
CLR C
SJMP CHECK


STORE_REMAINDER_0:
INC R0
MOV @R0,41H
MOV 41H,#00H
LCALL SHIFT_LEFT
MOV R2,#00H
RET


STORE_REMAINDER_1:
INC R0
MOV @R0,41H
MOV 41H,#00H
MOV R2,#0FFH
RET


SHIFT_LEFT:
INC R2

MOV A,32H
RLC A
MOV 32H,A

MOV A,31H
RLC A
MOV 31H,A

MOV A,41H
RLC A
MOV 41H,A

MOV A,40H
RLC A
MOV 40H,A

RET

END_DIVISION:
CLR C

;shifrat i ruan ne 53H, 52H, 51H,50H

;kodi me poshte i zevendson shifrat decimale me kodin e 7seg perkates, ne regjistrat perkates
MOV A,53H
MOV 59H,53H ;<-- Ruhet shifra e pare
MOVC A,@A+DPTR
MOV 53H,A

MOV A,52H
MOV 5AH,52H ;<-- Ruhet shifra e dyte
MOVC A,@A+DPTR
MOV 52H,A

MOV A,51H
MOV 5BH,51H ;<-- Ruhet shifra e parafundit
MOVC A,@A+DPTR
MOV 51H,A

MOV A,50H
MOV 5CH,50H ;<--Ruhet shifra e fundit
MOVC A,@A+DPTR
MOV 50H,A

MOV A,54H
;MOV 58H,54H ;<-- Ruhet parashenja #00H ose #40H
MOVC A,@A+DPTR
MOV 54H,A
MOV 58H,54H ;<-- Ruhet parashenja #00H ose #40H

RET ;return from sample subroutine
;=========================================================================================
;			    PERFUNDON - EKSTRAKTIMI I SHIFRAVE
;=========================================================================================


;=========================================================================================
;				  FILLON - KOMUNIKIMI ME TASTATURE
;=========================================================================================

GET_UPDATED_BUTTONS:

CLR SHLD ; load-mode of shiftregister with button-pressed values
CLR SHCLK ; clock of shiftregister idles in low-state

MOV R6,#8D ;8 bits of shiftregister

SETB SHLD ;shift-mode of shiftregister

NEXT_BUTTON:

SETB SO ;serial input pin of mcu is set '1'

MOV C,SO ;the value of shiftregister is moved to C
RLC A ;rotate-left Acc

SETB SHCLK ;low to high transition of shiftregister clock
CLR SHCLK  ;high to low transition of shiftregister clock
DJNZ R6,NEXT_BUTTON ;repeat to get all 8 bits from shiftregister

MOV 2DH,A ;send 8 bits to 2DH byte, -bitAddressable

RET

;=========================================================================================
;				     PERFUNDON - KOMUNIKIMI ME TASTATURE
;=========================================================================================


;=========================================================================================
;             FILLON - CAKTIMI MANUAL I RANGE
;=========================================================================================
;Nese dergohet zero ne lokacionin perkates, butoni eshte shtypur
MANUAL_RANGE:
;duhet te ruhet koha relative ne regjistra tjere, matet ne MSB-45H dhe LSB-46H
;dergohet ne MSB-5EH dhe LSB-5FH
MOV 5EH,45H
MOV 5FH,46H


;LCALL AUTOMATIC_RANGE ; per ta caktuar brezin adekuat, sepse duhet per krahasim, brezi ruhet ne reg. 2EH
;-------------------------------------------------------------------------
;LCALL GET_UPDATED_BUTTONS
;-------------------------------------------------------------------------
JNB 6FH,ZGJEDH_AUTOMATIKE ;bitat e regjistrit 2DH
JNB 6EH,ZGJEDH_MILIVOLT
JNB 6DH,ZGJEDH_1_999
JNB 6CH,ZGJEDH_19_99
JNB 6BH,ZGJEDH_199_9
JNB 6AH,ZGJEDH_MANUAL_SAMPLE_TIME

LJMP END_MANUAL_RANGE

;nese asnje button nuk shtypet, shfaqet: [ - - - - -]
;MOV 54H,#40H
;MOV 53H,#40H
;MOV 52H,#40H
;MOV 51H,#40H
;MOV 50H,#40H
;LJMP END_MANUAL_RANGE
;
ZGJEDH_MANUAL_SAMPLE_TIME:
LCALL MANUAL_SAMPLE_TIME ; thirret rutina e caktimit te kohes se mostrimit
LJMP END_MANUAL_RANGE ;dil nga manual_range routine

ZGJEDH_AUTOMATIKE:
LJMP ZGJEDH_AUTOMATIKE_0 ;percjell kercimin, error 8-bit relative

ZGJEDH_199_9:
LJMP ZGJEDH_199_9_0 ;percjell kercimin, error 8-bit relative

ZGJEDH_19_99:
LJMP ZGJEDH_19_99_0 ;percjell kercimin, error 8-bit relative
;------------------------------------------------
ZGJEDH_MILIVOLT:
LCALL AUTOMATIC_RANGE ; per ta caktuar brezin adekuat, sepse duhet per krahasim, brezi ruhet ne reg. 2EH

CLR OUTSB
CLR OUTSA

MOV A,#00H ;fshihet A, ruhet acc.1=0, acc.0=0

CJNE A,2EH, CHECK_RANGE_02 ;krahasojme brezin e zgjedhur me brezin automatik
SJMP BREZI_NJEJTE_02 ;nese brezi njejte = OK
CHECK_RANGE_02:
JB C,BREZI_VOGEL_02 ; brezi me i vogel se automatik, shfaq [-1], brezi me i madh = OK, llogarit dhe shfaq sipas brezit

BREZI_NJEJTE_02:

LCALL SAMPLE ;e ri llogarit vleren dhe per brezin e zgjedhur (rezultati del mir nese vlera i takon brezit perkates, ose nese brezi zgjedhet me i madh);

MOV A,51H  ;vendoset pika per milivolt (199.9 mV)
SETB ACC.7
MOV 51H,A
LJMP END_MANUAL_RANGE

BREZI_VOGEL_02:
MOV 54H,#40H
MOV 53H,#06H
MOV 52H,#00H
MOV 51H,#00H
MOV 50H,#00H

CLR 50H ;<--fshihet flagu i reg. 2A sepse brezi manual

MOV C,OUTSA ;ruajme brezin e automatik per mostren ne bitat e regjistrit 29H, per EEPROM
MOV 49H,C
MOV C,OUTSB
MOV 48H,C

LJMP END_MANUAL_RANGE
;------------------------------------------------
ZGJEDH_1_999:
LCALL AUTOMATIC_RANGE ; per ta caktuar brezin adekuat, sepse duhet per krahasim, brezi ruhet ne reg. 2EH
CLR OUTSB
SETB OUTSA

MOV A,#00H ;fshihet A

MOV C,OUTSA ;ruhet brezi ne A
MOV ACC.0,C
MOV C,OUTSB
MOV ACC.1,C

CJNE A,2EH, CHECK_RANGE_00 ;krahasojme brezin e zgjedhur me brezin automatik
SJMP BREZI_NJEJTE_00 ;nese brezi njejte = OK
CHECK_RANGE_00:
JB C,BREZI_VOGEL_00 ; brezi me i vogel se automatik, shfaq [-1], brezi me i madh = OK, llogarit dhe shfaq sipas brezit

BREZI_NJEJTE_00:
LCALL SAMPLE

MOV A,53H   ;vendoset pika per milivolt (1.999 V)
SETB ACC.7
MOV 53H,A
LJMP END_MANUAL_RANGE

BREZI_VOGEL_00:
MOV 54H,#40H ;-
MOV 53H,#06H ;1
MOV 52H,#00H
MOV 51H,#00H
MOV 50H,#00H

CLR 50H ;<--fshihet flagu i reg. 2A sepse brezi manual


MOV C,OUTSA ;ruajme brezin e automatik per mostren ne bitat e regjistrit 29H, per EEPROM
MOV 49H,C
MOV C,OUTSB
MOV 48H,C

SJMP END_MANUAL_RANGE
;------------------------------------------------
ZGJEDH_19_99_0:
LCALL AUTOMATIC_RANGE ; per ta caktuar brezin adekuat, sepse duhet per krahasim, brezi ruhet ne reg. 2EH
SETB OUTSB
CLR OUTSA

MOV A,#00H ;fshihet A

MOV C,OUTSA ;ruhet brezi ne A
MOV ACC.0,C
MOV C,OUTSB
MOV ACC.1,C

CJNE A,2EH, CHECK_RANGE_01 ;krahasojme brezin e zgjedhur me brezin automatik
SJMP BREZI_NJEJTE_01 ;nese brezi njejte = OK
CHECK_RANGE_01:
JB C,BREZI_VOGEL_01 ; brezi me i vogel se automatik, shfaq [-1], brezi me i madh = OK, llogarit dhe shfaq sipas brezit

BREZI_NJEJTE_01:
LCALL SAMPLE

MOV A,52H   ;vendoset pika per milivolt (19.99 V)
SETB ACC.7
MOV 52H,A
SJMP END_MANUAL_RANGE

BREZI_VOGEL_01:
MOV 54H,#40H ;-
MOV 53H,#06H ;1
MOV 52H,#00H
MOV 51H,#00H
MOV 50H,#00H

CLR 50H ;<--fshihet flagu i reg. 2A sepse brezi manual

MOV C,OUTSA ;ruajme brezin e automatik per mostren ne bitat e regjistrit 29H, per EEPROM
MOV 49H,C
MOV C,OUTSB
MOV 48H,C

SJMP END_MANUAL_RANGE
;-------------------------------------------------
ZGJEDH_199_9_0:
LCALL AUTOMATIC_RANGE ; per ta caktuar brezin adekuat, sepse duhet per krahasim, brezi ruhet ne reg. 2EH
SETB OUTSB
SETB OUTSA

LCALL SAMPLE

MOV A,51H   ;vendoset pika per milivolt (199.9 V)
SETB ACC.7
MOV 51H,A

CLR 50H ;<--fshihet flagu i reg. 2A sepse brezi manual

MOV C,OUTSA ;ruajme brezin e automatik per mostren ne bitat e regjistrit 29H, per EEPROM
MOV 49H,C
MOV C,OUTSB
MOV 48H,C

SJMP END_MANUAL_RANGE
;--------------------------------------------------
ZGJEDH_AUTOMATIKE_0:

LCALL AUTOMATIC_RANGE


MOV C,OUTSA ;ruajme brezin e automatik per mostren ne bitat e regjistrit 29H, per EEPROM
MOV 49H,C
MOV C,OUTSB
MOV 48H,C

END_MANUAL_RANGE:

RET ;return from manual range
;=========================================================================================
;               MBARON - CAKTIMI MANUAL I RANGE
;=========================================================================================


;=========================================================================================
;			           FILLON - AUTOMATIC RANGE
;=========================================================================================
AUTOMATIC_RANGE:
SETB 50H ;<-- Setohet biti 0 i reg. 2AH nese brezi automatik

SETB 67H ; <-- Setohet flagu qe tregon se matja eshte realizuar dhe mund te dergohetn bytet ne EEPROM

;by default eshte i zgjedhur brezi 4 (+/- 199.9 V)
;shikojm sa zero permban numri 4-shifror

SETB OUTSA ;zgjedhet range 19.99
SETB OUTSB

LCALL SAMPLE
;-------------------------------------------------------
MOV A,53H

CJNE A,#3FH,NOT_NEXT0 ; check if zero, 3FH eshte vlera e 7seg per nr. 0
SJMP NEXT0
NOT_NEXT0:

MOV A,51H ;vendos piken per range 199.9
SETB ACC.7
MOV 51H,A

SJMP DALJA4_0 ;nenkupton qe brezi eshte adekuat (+/- 199.9 V)

DALJA4_0:
LJMP DALJA4 ;error 8-bit relative
;--------------------------------------------------------
NEXT0:
MOV A,52H

CJNE A,#3FH,NOT_NEXT1 ;check if zero
SJMP NEXT1
NOT_NEXT1:
;nese display i dyte nuk eshte zero - duhet shikohet nese eshte 1 i takon brezit, nese eshte i ndryshem nuk i takon
MOV A,52H
CJNE A,#06H,NOT_ONE_0
SETB OUTSB ;zgjedhet range 19.99
CLR  OUTSA

LCALL SAMPLE

MOV A,52H ;vendoset pika per range 19.99
SETB ACC.7
MOV 52H,A

SJMP DALJA_TJETER
NOT_ONE_0:
SETB OUTSA ;zgjedhet range 199.9
SETB OUTSB

LCALL SAMPLE

MOV A,51H ;vendoset pika per range 19.99
SETB ACC.7
MOV 51H,A


SJMP DALJA_TJETER ;nenkupton qe vetem display i pare i shifrave eshte zero zgjedhet brezi (+/- 19.99 V)
;------------------------------------------------------------
NEXT1:
MOV A,51H

CJNE A,#3FH,NOT_NEXT2 ;check if zero
SJMP NEXT2
NOT_NEXT2:
;nese display i trete nuk eshte zero - duhet te shikohet nese eshte 1 i takon brezit, nese eshte i ndryshem nuk i takon
MOV A,51H
CJNE A,#06H,NOT_ONE_1

CLR OUTSB ;zgjedhet range 1.999
SETB OUTSA

LCALL SAMPLE

MOV A,53H ;vendoset pika per range 1.999
SETB ACC.7
MOV 53H,A

SJMP DALJA_TJETER
NOT_ONE_1: ;nuk eshte 1, nuk i takon brezit

SETB OUTSB ;zgjedhet range 19.99
CLR  OUTSA

LCALL SAMPLE

MOV A,52H ;vendoset pika per range 19.99
SETB ACC.7
MOV 52H,A

SJMP DALJA_TJETER ;nenkupton qe displayt 1 dhe 2 te shifrave jane zero zgjedhet brezi (+/- 1.999 V)
;--------------------------------------------------------------
NEXT2:
MOV A,50H

CJNE A,#3FH,NOT_NEXT3 ;check if zero
SJMP NEXT3
NOT_NEXT3:
;nese display i fundit nuk eshte zero - duhet shikohet nese eshte 1 ose jo, por fillimisht e ndrrojm brezin per rritje te saktesise (per raste kufitare)
;e zgjedhim brezin 19.99, per dallim nga rastet me larte
SETB OUTSB
CLR OUTSA
LCALL SAMPLE
;tani nuk e shikojme displayn e fundit (50H) por displayn e parafundit
MOV A,51H
CJNE A,#06H,NOT_ONE_2
;nese eshte 1, zgjedhet brezi 0.1999

CLR OUTSB ;zgjedhet range 0.1999
CLR OUTSA

LCALL SAMPLE

MOV A,51H   ;vendoset pika per milivolt (199.9 mV)
SETB ACC.7
MOV 51H,A
SJMP DALJA_TJETER

NOT_ONE_2: ;nese nuk eshte 1, zgjedhet brezi 1.999V
CLR OUTSB
SETB OUTSA

LCALL SAMPLE

MOV A,53H ;vendoset pika per range 1.999
SETB ACC.7
MOV 53H,A


SJMP DALJA_TJETER ;nenkupton qe displayt 1,2,3 te shifrave jane zero zgjedhet brezi (+/- 0.1999 V)
;-----------------------------------------------------------------------
NEXT3:
CLR OUTSB
CLR OUTSA ;nenkupton qe 4 displayt jane zero zgjedhet brezi (+/- 0.1999 V)

LCALL SAMPLE

MOV A,51H   ;vendoset pika per milivolt (019.9 mV)
SETB ACC.7
MOV 51H,A


DALJA_TJETER:

DALJA4: ; brezi eshte adekuat, vetem vazhdon ne rastin e +/- 199.9 V

MOV C,OUTSA ;ruajme brezin e automatik per mostren ne bitat e regjistrit 2EH (bit-addressable)
MOV 70H,C
MOV C,OUTSB
MOV 71H,C

RET
;=========================================================================================
;		        PERFUNDON - AUTOMATIC RANGE
;=========================================================================================


;=========================================================================================
;			      FILLON - MANUAL SAMPLE TIME
;=========================================================================================

MANUAL_SAMPLE_TIME:
JNB 6AH,MANUAL_SAMPLE_TIME ;Nuk vazhdohet ne subroutine deri sa OK button is unpressed

MOV 54H,#00H
MOV 53H,#00H
MOV 52H,26H ;<- disp_52
MOV 51H,27H ;<- disp_51
MOV 50H,28H ;<- disp_50

MOV R0,#50H ;regjistri per pointim te 7seg

MOV R1,#0FFH ;ruan vleren per disp

CHECK_BUTTONS_FOR_NEXT_PRESS:
JNB 6AH, PERFUNDO_MANUAL_SAMPLE_TIME
JNB 69H, INCREMENT_DISP_01
JNB 68H, CHANGE_DISP_01
SJMP CHECK_BUTTONS_FOR_NEXT_PRESS

INCREMENT_DISP_01:
LCALL INCREMENT_DISP

NOT_UNPRESSED_00:
JNB 69H, NOT_UNPRESSED_00 ;Nuk vazhdohet tutje, deri sa "+1" button is unpressed
LJMP CHECK_BUTTONS_FOR_NEXT_PRESS

CHANGE_DISP_01:
MOV R1,#0FFH
INC R0
CJNE R0,#53H,CAN_INCREMENT_11
MOV R0,#50H
CAN_INCREMENT_11:

NOT_UNPRESSED_01:
JNB 68H,NOT_UNPRESSED_01 ; Nuk vazhdohet tutje, deri sa "<<" button is unpressed
LJMP CHECK_BUTTONS_FOR_NEXT_PRESS

PERFUNDO_MANUAL_SAMPLE_TIME:

OK_UNPRESSED_11:
JNB 6AH,OK_UNPRESSED_11

;kur shtypet buttoni OK, ruhet vlera qe te shfaqet pastaj heren tjeter ne display kur do te caktohet nje vlere tjeter
MOV 28H,50H
MOV 27H,51H
MOV 26H,52H

;Kodi me poshte i ruan vlerat BCD ne reg
LCALL SEVESEG_TO_BCD_TO_HEX ;vleren e ruan ne msb-56H dhe 57H

LCALL AUTOMATIC_RANGE; <-- qe te shfaqet vlera e matur

RET ;perfundo caktimin e manual sample time

;--------------------------------------------------------------------
INCREMENT_DISP: ;Rutina per rritje +1 te displayt
INC R1

CJNE R1,#10D, CAN_INCREMENT ;Nese vlera me e madhe se 9 => kthehu ne 0
MOV R1,#00H
CAN_INCREMENT:
MOV A,R1
MOV @R0,A

MOV A,@R0
MOVC A,@A+DPTR
MOV @R0,A
RET ; perfundo rritjen e displayt
;----------------------------------------------------------------------
;=========================================================================================
;			      PERFUNDON - MANUAL SAMPLE TIME
;=========================================================================================


;=========================================================================================
;				    FILLON - SHFAQJA E SHIFRAVE
;=========================================================================================
DISPLAY_RESULT:
SETB P1.4
SETB P1.3
SETB P1.2
SETB P1.1
SETB P1.0

SETB RS1
SETB RS0 ;Selektohet BANK 3

MOV P0,@R0 ;ne fillim (R0) = 50H ndersa (R1) = 00H

CJNE R1,#00H,CHECK_1
CLR P1.4
SJMP END_DISPP
CHECK_1:
CJNE R1,#01H,CHECK_2
CLR P1.3
SJMP END_DISPP
CHECK_2:
CJNE R1,#02H,CHECK_3
CLR P1.2
SJMP END_DISPP
CHECK_3:
CJNE R1,#03H,CHECK_4
CLR P1.1
SJMP END_DISPP
CHECK_4:
CJNE R1,#04H,CHECK_5
CLR P1.0
SJMP END_DISPP
CHECK_5:

END_DISPP:
INC R0
INC R1

CJNE R0,#55H,CHECK_6
MOV R0,#50H
MOV R1,#00H
CHECK_6:

CLR RS1
CLR RS1

RET ; perfundon rutina e display

DIGITS: DB 3FH, 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H, 7FH, 6FH, 40H, 00H
                                                    ;minusi-->^    ^<---blank

;=========================================================================================
;				      PERFUNDON - SHFAQJA E SHIFRAVE
;=========================================================================================


;=========================================================================================
;				       FILLON - DECREMENT-16bit nr.
;=========================================================================================
;rutina i merr parametrat nga (MSB)43H dhe 44H (LSB)
;numri 16-bit ne decimal eshte "n", (n*1ms) = koha e mostrimit
DECREMENT_16BIT:
DECREMENT_UNTIL_0:
DEC 44H
MOV A,44H
JZ IT_IS_0_NOW
SJMP DECREMENTED_ONCE

IT_IS_0_NOW:
MOV A,43H
JZ DECREMENTED_ONCE
DEC 43H
MOV 44H,#0FFH
SJMP DECREMENT_UNTIL_0

DECREMENTED_ONCE:
RET
;=========================================================================================
;			    PERFUNDON - DECREMENT-16bit nr.
;=========================================================================================


;=========================================================================================
;	       FILLON - Counter - Kohe Relative
;=========================================================================================
;rutina i ruan parametrat ne MSB-45H dhe LSB-46H
RELATIVE_TIME_1MS:
INC 46H
MOV A,46H
CJNE A,#0FFH, NOT_OVERFLOW
MOV 46H,#00H
INC 45H

NOT_OVERFLOW:
MOV A,45H
CJNE A,#0FFH,END_REL_TIME_ROUTINE
MOV A,46H
CJNE A,#0FFH,END_REL_TIME_ROUTINE
MOV 46H,#00H ;Reset counter of relative time
MOV 45H,#00H
END_REL_TIME_ROUTINE:
RET
;=========================================================================================
;	       PERFUNDON - Counter - Kohe Relative
;=========================================================================================


;=========================================================================================
;		      FILLON - Konvertimi 7seg to BCD to HEX
;=========================================================================================
;kodi me poshte i merr vlerat e dhena nga perdoruesi ne 52H, 51H, 50H (tre displayt e fundit)
;dhe i konverton ne BCD pastaj ne HEX
;vlerat i ruan MSB-56H dhe LSB-57H

SEVESEG_TO_BCD_TO_HEX:
MOV A,#00H
TRY_NEW_VALUE00x:
MOV 47H,A ;ne 47H ruhet vlera BCD e njesheve
MOVC A,@A+DPTR
CJNE A,50H,VALUE_ISNT_EQUAL00x
SJMP CONVERT_SECOND_DIGIT
VALUE_ISNT_EQUAL00x:
MOV A,47H
INC A
SJMP TRY_NEW_VALUE00x

CONVERT_SECOND_DIGIT:
MOV A,#00H
TRY_NEW_VALUE0x0:
MOV 55H,A ;ne 55H ruhet vlera BCD e dhjetsheve
MOVC A,@A+DPTR
CJNE A,51H,VALUE_ISNT_EQUAL0x0
SJMP CONVERT_THIRD_DIGIT
VALUE_ISNT_EQUAL0x0:
MOV A,55H
INC A
SJMP TRY_NEW_VALUE0x0

CONVERT_THIRD_DIGIT:
MOV A,#00H
TRY_NEW_VALUEx00:
MOV 56H,A ;ne 55H ruhet vlera BCD e dhjetsheve
MOVC A,@A+DPTR
CJNE A,52H,VALUE_ISNT_EQUALx00
;ketu kalo te shumezimi te dhe mbledhja
SJMP SHUMEZO_VLERAT
VALUE_ISNT_EQUALx00:
MOV A,56H
INC A
SJMP TRY_NEW_VALUEx00

SHUMEZO_VLERAT:
MOV A,55H
MOV B,#0AH ;*10
MUL AB
MOV 55H,A

MOV A,56H
MOV B,#100D ;*100
MUL AB
MOV 56H,B
ADD A,55H
MOV 57H,A
MOV A,56H
ADDC A,#00H
MOV A,47H
ADD A,57H
MOV 57H,A
MOV A,56H
ADDC A,#00H
MOV 56H,A
RET ;RETURN FROM SEVEN SEG TO BCD
;=========================================================================================
;			    PERFUNDON - Konvertimi 7seg to BCD to HEX
;=========================================================================================


;=========================================================================================
;			     FILLON - Dergimi i te gjithe Bytes
;=========================================================================================
SEND_ALL_BYTES:
;5DH eshte buffer per data
MOV 5DH,5EH ;<-- LOW of relative TIME
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,5FH ;<-- HIGH of relative TIME
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,2AH ;<-- MANUAL=0/AUTOMATIC=1 Range
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,29H ;<-- Dalja 0,1,2,3
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,5CH ;shifra e fundit
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,5BH ;shifra e parafundit
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,5AH ;shifra e dyte
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,59H ;shifra e pare
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS

MOV 5DH,58H ; parashenja #00H ose 40H
LCALL SEND_ONE_BYTE_EEPROM
LCALL COUNT_ADDRESS
RET
;=========================================================================================
;			   PERFUNDON - Dergimi i te gjite Bytes
;=========================================================================================


;=========================================================================================
;		      FILLON - Komunikimi me EEPROM
;=========================================================================================

SEND_ONE_BYTE_EEPROM:

;----START----
CLR SDA
LCALL SHORT_DELAY
CLR SCL
LCALL SHORT_DELAY
;----/START----

;---SLAVE-ADDRESS---
MOV A,#0A0H
LCALL SHIFT_DATA_OUT
LCALL ACK_BIT_CHECK

JNC AGAIN_SLAVE_ADDRESS
SJMP $
AGAIN_SLAVE_ADDRESS:
;---/SLAVE-ADDRESS---

;-----WORD ADDRESS - 15 bit --
;WORD_ADDRESS:
LCALL SHORT_DELAY
MOV A,3EH ; <-- (vendoset msb i adreses)
LCALL SHIFT_DATA_OUT
LCALL ACK_BIT_CHECK
JNC WORD_ADDRESS
SJMP $
WORD_ADDRESS:
LCALL SHORT_DELAY
MOV A,3FH ; <-- (vendoset lsb i adreses)
LCALL SHIFT_DATA_OUT
LCALL ACK_BIT_CHECK
JNC WORD_ADDRESS_1
SJMP $
WORD_ADDRESS_1:
;-----WORD ADDRESS - 15bit --


;---DATA-------

MOV A,5DH ;<--- duhet ndryshohet (vendoset regjistri i data)
LCALL SHORT_DELAY
LCALL SHIFT_DATA_OUT
LCALL ACK_BIT_CHECK
JNC DATA_WRITE
SJMP $
DATA_WRITE:
;---DATA-------


;---STOP------
SETB SCL
LCALL SHORT_DELAY
SETB SDA
LCALL SHORT_DELAY
;----/STOP----


RET ;return from SEND_ONE_BYTE_EEPROM

SHORT_DELAY: ; delay e shkurt
MOV R0,#4D
DJNZ R0,$
RET


SHIFT_DATA_OUT: ;i dergon 8 bits ne bus each at a time
MOV R1,#8D
SHIFT_DATA_OUT0:
RLC A
MOV SDA,C
LCALL SHORT_DELAY
SETB SCL
LCALL SHORT_DELAY
CLR SCL
LCALL SHORT_DELAY
DJNZ R1,SHIFT_DATA_OUT0
RET

ACK_BIT_CHECK:
SETB SDA
LCALL SHORT_DELAY
SETB SCL
LCALL SHORT_DELAY
MOV C,SDA
LCALL SHORT_DELAY
CLR SCL
LCALL SHORT_DELAY ;<--
CLR SDA
RET
;=========================================================================================
;		     PERFUNDON - Komunikimi me EEPROM
;=========================================================================================

;=========================================================================================
;		      FILLON - Counteri i Addressave per EEPROM
;=========================================================================================
;rutina i ruan parametrat ne MSB-3EH dhe LSB-3FH
COUNT_ADDRESS:
INC 3FH
MOV A,3FH
CJNE A, #0FFH, REG_NOT_OVERFLOW_22
MOV A,3EH
CJNE A,#07FH, REG_NOT_OVERFLOW_23
INC 3FH
MOV 3EH,#00H
SJMP END_COUNTER_ADDRESS
REG_NOT_OVERFLOW_23:
INC 3EH
SJMP END_COUNTER_ADDRESS
REG_NOT_OVERFLOW_22:
END_COUNTER_ADDRESS:
RET
;=========================================================================================
;		      PERFUNDON - Counteri i Addresave per EEPROM
;=========================================================================================
END
