* EQUIV DEFINITIONS
*
BLANK   EQU 32
BREAK   EQU 3
CR      EQU 13
LF      EQU 10
BS      EQU 8
SZOUT   EQU $100  * SIZE OF OUTPUT BUFFER
SZIN    EQU $100  * SIZE OF INPUT BUFFER
ATTR    EQU $0
*--------------------------------------------
*DIRECT PAGE COMMON
*
        ORG $0
*--------------------------------------------
*
* SCREEN DISPLAY COMMON
*
LINCOL
LIN     RMB 1   * CUR LINE
COL     RMB 1   * CUR COL
*--------------------------------------------
* COMMUNICATIONS COMMON
*
XSLICE  RMB 1
XBIT    RMB 1
XCHAR   RMB 1
RSLICE  RMB 1
RBIT    RMB 1
RCHAR   RMB 1
BHOLD   RMB 1
XHOLD   RMB 1
SOME    RMB 1
*--------------------------------------------
* BUFFERED I/O POINTERS
*
GETOUT  RMB 2
PUTOUT  RMB 2
*
GETIN   RMB 2
PUTIN   RMB 2
*--------------------------------------------
* PARAMETERS POKED IN BY BASIC
        ORG $200
CMAX    RMB 1         MAX COL
LMAX    RMB 1         MAX LINE
LFMAR   RMB 1         LEFT MARGIN
FCOLOR  RMB 1         FOREGROUND COLOR
BCOLOR  RMB 1         BACKGROUND COLOR
BAUD    RMB 2         BAUD RATE CONSTANT
AUTOLF  RMB 1         0-NO, 1-YES
DUPLEX  RMB 1         0-FULL, 1-HALF
*--------------------------------------------
* BUFFERS
*
        ORG   $4000
VIDBUF  RMB   $1800     SCREEN
INBUF   RMB   SZIN      INPUT BUF
OUTBUF  RMB   SZOUT     OUTPUT BUF
*--------------------------------------------
* MAINLINE
*--------------------------------------------
        ORG $6000
MAIN
*--------------------------------------------
* INITIALIZATION
*
        CLR   $FF40       TURN OFF DISK MOTOR
        CLR   $FFD9       SPEED UP CPU
        LBSR  CLRSCN     CLEAR SCREEN
*
*--------------------------------------------
* CLEAR I/O BUFFERS
*
        LDX   #OUTBUF
        STX   GETOUT
        STX   PUTOUT
        LDX   #INBUF
        STX   GETIN
        STX   PUTIN
        LDY   #SZIN+SZOUT
        LDB   #-1
ISET
        STB   ,X+       FILL BUFS WITH/-1'S
        LEAY  -1,Y
        BNE   ISET
*
        LBSR  TIMER     START TIMER
*--------------------------------------------
* BODY OF MAINLINE
*
LOOP1
        LBSR  RECV      RS232 -> A REC
        CMPA  #-1
        BEQ   LOOP2
        LBSR  PUT       A REC -> SCREEN
        BRA   LOOP1     (MORE IMPORTANT TO RCV THAN TO TRANS)
*
LOOP2
        LBSR  GET       KEYBOARD -> A REC
        CMPA  #-1
        BEQ   LOOP1
        TST   DUPLEX    SKIP IF FULL DUPLEX (0)
        BEQ   LOOP3
        LBSR  PUT       A REG -> SCREEN
LOOP3
        LBSR  SEND      A REG -> RS232
        BRA   LOOP1
*--------------------------------------------
* SEND CHARACTERS TO SERIAL PORT
* VIA OUTBUF
* ENTER W/ CHAR IN A REG
*
SEND
        PSHS  A
        LDX   PUTOUT
SND1
        LDB   ,X
        CMPB  #-1
        BNE   SND1    WAIT FOR LAST XMIT
        STA   ,X+     PUT CHAR IN BUFFER
        CMPX  #OUTBUF+SZOUT
        BNE   SND2
        LDX   #OUTBUF
SND2
        STX   PUTOUT
        PULS  A,PC
*--------------------------------------------
* RCV CHARACTER FROM SERIAL PORT VIA INBUF
* RETURN W/ CHAR IN A register
* -1 IF NOTHING RECEIVED
*
RECV
        LDX   GETIN
        LDA   ,X
        CMPA  #-1
        BEQ   RCV1
        LDB   #-1
        STB   ,X+
        CMPX  #INBUF+SZIN
        BNE   RCV1
        LDX   #INBUF
RCV1
        STX   GETIN
        RTS
*--------------------------------------------
* GET CHAR FROM KEYBOARD RETURN W/ CHAR IN
* REGISTER AND -1 IF NOTHING RECEIVED
*
GET
        LBSR  XYCALC
        LDB   1,X
        PSHS  B,X
        LDB   #$C0
        ORB   1,X
        STB   1,X
        JSR   [$A000]   CALL BASIC KEYBOARD ROUTINE
        BEQ   GET8
        ANDA  #$7F
        LDB   #$EF      CHECK CTRL KEY
        STB   $FF02
        LDB   $FF00
        ANDB  #$40
        BNE   GET9
        CMPA  #'=       BASIC KB DRV GIVES A PHONY "-"
        BEQ   GET8      ON CTRL KEY
        ANDA  #$1F      IF DOWN REMOVE BITS 5+6
        BRA   GET9
GET8
        LDA   #-1
GET9
        PULS  B,X
        STB   1,X
        RTS
*--------------------------------------------
* PUT CHAR TO SCREEN
* ENTER W/ CHAR IN A REG
*
PUT
        PSHS  A,X
        CMPA  #32
        BHS   PUT3
* TEST FOR CONTROL CHARACTER
        CMPA  #CR
        BEQ   PUT1
        CMPA  #LF
        BEQ   PUT2
        CMPA  #BS
        BNE   PUT9
* BACKSPACE
        DEC   COL
        BRA   PUT8
* CARRIAGE RETURN
PUT1
        LDB   LFMAR
        STB   COL
        TST   AUTOLF
        BEQ   PUT8
* LINEFEED
PUT2
        INC   LIN
        BRA   PUT8
* PRINTABLE CHARACTER
PUT3
        LBSR  XYCALC    (CALC SCREEN LOC)
        LDA   ,S
        STA   ,X        (STORE CHARACTER)
        INC   COL
* FIX X-Y LOG
PUT8
        BSR   XYFIX
PUT9
        PULS  A,X,PC
*--------------------------------------------
* BRING LINE/COL IN VALID RANGE
*
XYFIX
XY1
        LDD   LINCOL
        CMPB  CMAX
        BHS   HICOL
        CMPB  LFMAR
        BLO   LOCOL
        CMPA  LMAX
        BHS   HILIN
        BRA   XY9
* COLUMN TOO HIGH
* GO TO NEXT LINE
HICOL
        LDB   LFMAR
        STB   COL
        INC   LIN
        BRA   XY1
* COLUMN TOO LOW
* GO TO PREV LINE
LOCOL
        LDB   CMAX
        DECB
        STB   COL
        TST   LIN
        BEQ   XY1
        DEC   LIN
        BRA   XY1
* LINE TOO HIGH
* SCROLL
HILIN
        LBSR  SCROLL
        DEC   LIN
        BRA   XY1
XY9
        RTS
*--------------------------------------------
* CALCULATE X/Y SCREEN LOG
* ENTRY LINE/COL
* EXIT    X-SCREEN LOC
*
XYCALC
        LDX   #VIDBUF
        LDA   LIN
        LDB   CMAX
        LSLB        (ACCOUNT FOR ATTRIBUTE BYTE)
        MUL
        LEAX  D,X
        LDB   COL
        LSLB        (ACCOUNT FOR ATTRIBUTE BUTE)
        ABX
        RTS
*--------------------------------------------
* SCROLL SCREEN UP ONE LINE
*
SCROLL
        LDX   #VIDBUF
        LDB   CMAX
        LSLB      (ACCOUNT FOR ATTRIBUTE BYTE)
        CLRA
        LEAU  D,X
        LDA   LMAX
        DECA
        MUL
        TFR   D,Y
SCR1
        LDD   ,U++
        STD   ,X++
        LEAY  -2,Y
        BNE   SCR1
        LDA   CMAX
SCR2
        LDB   #BLANK
        STB   ,X+
        LDB   #ATTR
        STB   ,X+
        DECA
        BNE   SCR2
        RTS
*--------------------------------------------
* CLEAR SCREEN
*
CLRSCN
        LDB   FCOLOR      SET FOREGROUND COLOR
        STB   $FFB8
        LDB   BCOLOR      SET BACKGROUND COLOR
        STB   $FFB0
        STB   $FF9A       AND BORDER
        LDB   #$4C
        STB   $FF90       SET INITIALIZATION REGISTRER
        LDB   #3
        STB   $FF98       SET VIDDE MODE REGISTER
        LDB   #$5
        LDA   CMAX
        CMPA  #$50    <-  DIFFERENT HERE
        BNE   CL1
        LDB   #$15
CL1
        STB   $FF99       SET VIDEO RES REGISTER
        LDD   #VIDBUF
        LSRA
        RORB
        LSRA
        RORB
        LSRA
        RORB
        ORA   #$E0
        STA   $FF9D       SET VERT OFFSET REGISTER
        STB   $FF9E
        CLR   $FF9F

        LDX   #VIDBUF
        LDY   #80*24
        LDD   #BLANK*256+ATTR
CL2
        STD   ,X++        CLEAR SCREEN
        LEAY  -1,Y
        BNE   CL2
        CLR   LIN
        LDB   LFMAR
        STB   COL
        RTS
*--------------------------------------------
* SET UP PROGRAMMABLE
* INTERRUPT TIMER
*
TIMER
*
* SET UP INTERRUPTS
        ORCC  #$50
* TURN OFF OLD IRUPTS
        LDB   #$2C
        STB   $FF01
        STB   $FF03
        STB   $FF23
        STB   $FF23
        LDB   $FF00
        LDB   $FF02
        LDB   $FF20
        LDB   $FF22
*
        LEAX  DOFIRQ,PCR
        STX   $110          SET FIRQ PROGRAM
*
* SETUP TIMER INTERRUPT
        LDB   #$60
        STB   $FF91         SELECT CLOCK
        CLR   $FF92
        LDB   #$20
        STB   $FF93         ENABLE TIMER INTERRUPT
        LDB   #$5C
        STB   $FF90         ENABLE GIME FIRQ
        LDD   BAUD
        STB   $FF95
        STA   $FF94         SETUP TIMER COUNT  (originally STB)
*
* INIT XMITTER/RECVR
        CLR   RSLICE
        CLR   XSLICE
        CLR   RBIT
        CLR   XBIT
        ANDCC #$AF          ENABLE INTERRUPTS
        RTS
*--------------------------------------------
* PROCESS TIMER INTERRUPT
*
DOFIRQ
        STB   BHOLD
        CLR   $FF93       CLEAR TIMER INTERRUPT
        LDB   #$20
        STB   $FF93
*
* SERVICE TRANSMITTER
*
        DEC   XSLICE
        BNE   XMI9
        STX   XHOLD
        LDB   #7
        STB   XSLICE
        LDB   XBIT
        BEQ   XMI1
        DEC   XBIT
        BNE   XMI3
XMI1
        LDX   GETOUT
        LDB   ,X        ON NEXT BYTE IN BUFFER
        CMPB  #-1         -1
        BEQ   XMI8
        STB   XCHAR       ELSE
        LDB   #-1
        STB   ,X+
        CMPX  #OUTBUF+SZOUT
        BNE   XMI2
        LDX   #OUTBUF
XMI2
        STX   GETOUT      ADVANCE BUFFER POINTER
        LDB   #10
        STB   XBIT        XBIT 10 BITS
        ANDCC #$FE        START BUT/CARRY
        BRA   XMI4
XMI3
        LDB   XCHAR
        ORCC  #1          STOP BIT->CARRY
        RORB              DATA  BIT->CARRY
        STB   XCHAR
XMI4
        LDB   #0
        ROLB              CARRY->RS232 OUT
        ROLB
        STB   $FF20
XMI8
        LDX   XHOLD
XMI9
*
* SERVICE RECEIVER
*
        LDB   RBIT        IF NOT RECEIVING
        BEQ   RCI1         GO CHECK FOR START BIT
        DEC   RSLICE      ELSE
        BEQ   RCI3          CONTINUE TO RECEIVE
        BRA   RCI9
RCI1
        LDB   $FF22       WATCH FOR START BIT
        RORB
        BCC   RCI2          ** BHS ?
        CLR   RSLICE      NO START, CLEAR COUNTER
        BRA   RCI9
RCI2
        INC   RSLICE      POSSIBLE START, INC COUNTER
        LDB   RSLICE
        CMPB  #4          IF 4 X'S START RECEIVER
        BNE   RCI9
        LDB   #10         RECEIVE 10 BITS
        STB   RBIT
RCI3
        DEC   RBIT
        BEQ   RCI4        SEE IF FINISHED BYTE
        LDB   $FF22
        RORB              DATA BIT->CARRY
        LDB   RCHAR
        RORB              CARRY->RECV BYTE
        STB   RCHAR
        LDB   #7
        STB   RSLICE      SET COUNTER FOR NEXT BIT
        BRA   RCI9
RCI4
        STX   XHOLD
        LDX   PUTIN
        LDB   RCHAR
        STB   ,X+         DELIVER CHAR TO BUFFER
        CMPX  #INBUF+SZIN
        BNE   RCI5
        LDX   #INBUF
RCI5
        STX   PUTIN
        LDX   XHOLD
RCI9
        LDB   BHOLD
        RTI
*
        END MAIN
