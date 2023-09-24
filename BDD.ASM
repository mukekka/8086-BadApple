;//远离这个程序.可读性极差
;//里面有很多乱七八糟的JMP和CALL,还有机器码.虽然占比并不大.
;//
;//这个程序本来是打算放在BOOT扇区里的.
;//你可以看到下面有个FAT表,末尾有个55AA和07C00H后面的512字节缓冲区.我懒得删了
;//如果做成引导程序,整个程序仅512B,数据一张320KB的软盘就能放下
;//奈何技术不够,需要依靠DOS提供的中断
;//
;//以后再说吧
ASSUME CS:CODE;,DS:DATA;,SS:STACK,ES:EXTRA
;2000:0000-0030:STACK
;2000:0030:EXS  20H
;2000:0031      00H
;2000:0032:FLG  10H
;2000:0033      00H
;2000:0034:HDL  FFH
;2000:0035      00H
;2000:0036:FIN  "1.bin"
;2000:003B-003F 00H
;2000:0040:BUF

DATA EQU 2000H
STACK EQU 0030H
EXS EQU 0030H
FLG EQU 0032H
HDL EQU 0034H
FIN EQU 0036H
BUF EQU 0040H

;DATA SEGMENT
;----------------STACK
;    DB 030H DUP (00);24 WORD STACK ELEMENT
;----------------
;EXS DB 20H              ;DATA(EXTRA SEGMENT)
;    DB 00
;FLG DB 01               ;PARITY FLAG
;NTH DB 06 DUP (00)      ;NOTHING
;----------------
;FIN DB '1.bin',00       ;FILE NAME
;HDL DW 0FFH             ;FILE HANDLE
;BUF DB 8000H DUP (?)    ;FILE BUFFER;把这东西丢掉能省整整32K的容量
;DATA ENDS
;//
CODE SEGMENT
ORG 0100H
;    JMP ART
;    ORG 07C00H
;ART:JMP S
;    OEMLabel        DB "6324NMSL"
;    BytesPerSector  DW 512
;    SectorsPerCluster DB 1
;    ReservedSectors DW 1
;    NumberOfFATs    DB 1;2
;    RootEntries     DW 1;224
;    TotalSectors    DW 1440
;    Media           DB 0F9H;
;    SectorsPerFAT   DW 3;9
;    SectorsPerTrack DW 9;18
;    Heads           DW 2;1
;    HiddenSectors   DW 0,0
;    TotalSectors32  DW 0,0
;    DriveNumber     DB 0
;    Reserved        DB 0
;    Signature       DB 029H
;    VolumeID        DB 0AAH,0BBH,0CCH,0DDH
;    VolumeLabel     DB "SOTTOWCSNDM"
;    FileSystem      DB "FAT12",20H,20H,20H
;----------------STACK
;    DB 030H DUP (00);24 WORD STACK ELEMENT
;----------------DISPLAY BUFFER
START:
  S:CLD                 ;SI&DI++
    STI                 ;ALLOW INT

    MOV AX,DATA
    MOV SS,AX
    MOV SP,STACK
   ;MOV AX,DATA         ;SPECIFY THE STACK
   ;MOV SS,AX
   ;LEA SP,[EXS]

    MOV BX,CS
    CALL COS

    CALL W01

    XOR DI,DI           ;TRANSMISSION OFFSET ADDRESS
;----------------        ;LOAD FILE TO MEMORY
;    MOV CX,9            ;本应该用这段程序把BIN载入到20000H到60000H这段内存里,
;LFM:PUSH CX             ;这样实机运行可以减少磁盘读取的时间,
;    CALL DSR            ;但我内存分配技术太差劲,以后技术提升了在做修改
;    POP CX              ;
;    LOOP LFM
;----------------
;    MOV BYTE PTR [EXS],20H

    MOV AX,0B800H
    MOV ES,AX

    MOV AX,DATA
    MOV DS,AX
    CALL SPC

    MOV CX,9            ;HANDOFF IMAGE DATA SEGMENT
LP5:PUSH CX
    CALL DSR
    ;MOV AH,[EXS]
    ;XOR AL,AL
    ;ADD [EXS],10H

    ;XOR SI,SI
    MOV SI,BUF

    MOV CX,64           ;HANDOFF COMPRESS FRAMES
LP4:PUSH CX

    MOV CX,4
LP3:PUSH CX

    XOR BX,BX
    MOV CX,125
LP2:PUSH CX

    LODSB
    MOV CX,8
LP1:SHL AL,1
    PUSHF
    POP DX
    AND DX,0001
    JNP THIS FAR +15    ;出现了
    MOV WORD PTR ES:[BX],00020H
    MOV WORD PTR ES:[BX+2],00020H
    JMP THIS FAR +13
    MOV WORD PTR ES:[BX],07FDBH
    MOV WORD PTR ES:[BX+2],07FDBH
    ADD BX,4
    LOOP LP1

    POP CX
    LOOP LP2

    CALL DLY
    POP CX
    LOOP LP3

    ADD SI,0CH
    POP CX
    LOOP LP4

    POP CX
    LOOP LP5

    MOV AH,4CH
    INT 21H
    ;HLT
    ;INT 19H
;-------------------------------------------
;----------------FUNCTION
W01:PUSH AX

    MOV AH,0
    INT 16H

    CMP AL,13
    JNE W01-4

    POP AX
    RET
;----------THE CODE SEGMENT ADDRESS
COS:MOV AX,CS
    MOV DS,AX

    MOV DI,4
INF:MOV CX,4
    XOR AL,AL
    SHL BX,1
    RCL AL,1
    LOOP INF+5
    PUSH BX
    CALL PIT
    POP BX
    DEC DI
    CMP DI,0
    JNZ INF

CSE:MOV CX,PIT-CO1
    LEA SI,[CO1]
    LODSB
    CALL A37+2
    LOOP CSE+8

    RET
CO1 DB 13,10,'PRESS ENTER TO CONTINUE',13,10
;----------PRINT
PIT:CMP AL,09H          ;PRINTF THE AL TO ASCII
    JA A37
    ADD AL,030H
    JMP A37+2
A37:ADD AL,037H
    MOV AH,0EH
    MOV BL,07H
    INT 010H
    XOR AX,AX
    RET
;----------DISK READ    ;READ FILE TO MEMORY
DSR:PUSHF               ;读取文件
    PUSH AX             ;
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DS

    MOV AX,DATA         ;DOS READ DISK
    MOV DS,AX

    MOV DX,FIN
    MOV AH,3DH
    MOV AL,00H
    INT 21H
;    MOV [HDL],AX

    MOV BX,AX
    MOV AH,03FH
    MOV DX,BUF
    MOV CX,08000H
    INT 21H

    MOV AH,03EH
    INT 21H

    DB 0FEH,06,36H,00H
    ;INC BYTE PTR [FIN]

    ;CALL RTM

    ;INC BP             ;BIOS READ DISK
    ;MOV AX,BP          ;I ABANDONED THIS PROG
    ;MOV CX,10          ;BIOS太难搞了
    ;DIV CX
    ;MOV CH,AL
    ;MOV CL,DL
    ;CMP CL,0
    ;JNZ THIS FAR +4
    ;INC CL
    ;MOV AX,CS
    ;MOV ES,AX
    ;MOV AH,02
    ;MOV AL,01
    ;XOR DX,DX
    ;MOV BX,OFFSET BUF;[07E00H]    ;LEA BX,[BUF]
    ;INT 013H

    POP DS
    POP DX
    POP CX
    POP BX
    POP AX
    POPF
    RET
;----------------
;RTM:PUSH DS                     ;READ TO USE MEMORY
;    PUSH ES                     ;把缓冲区里的数据读取到20000H和60000H里
;    PUSH CX                     ;暂时不用它
;    PUSH SI
;    PUSH AX
;
;    MOV AH,[EXS]                ;IF DI=0 GOTO THIS
;    XOR AL,AL
;    MOV ES,AX
;    MOV SI,OFFSET BUF
;    MOV CX,8000H
;    REP MOVSB
;
;    AND [FLG],1
;    JNP THIS FAR +5             ;IF ODD,JUMP
;    ADD BYTE PTR [EXS],10H      ;ES+1000H
;    NOT [FLG]                   ;NEGATION FLAG
;
;    POP AX
;    POP SI
;    POP CX
;    POP ES
;    POP DS
;    RET
;----------------
SPC:DB 0C7H,06,30H,00,20H,00
   ;MOV WORD PTR [30H],2000H;EXS
    DB 0C7H,06,32H,00,10H,00
   ;MOV WORD PTR [32H],1000H;FLG
    DB 0C7H,06,34H,00,0FFH,00
   ;MOV WORD PTR [34H],0FF00H;HDL
    DB 0C7H,06,36H,00,'1.'
   ;MOV WORD PTR [36H],'1.'
    DB 0C7H,06,38H,00,'BI'
   ;MOV WORD PTR [38H],'BI'
    DB 0C7H,06,3AH,00,'N',00
   ;MOV WORD PTR [03AH],'N '
    DB 0C7H,06,3CH,00,00,00
    DB 0C7H,06,3EH,00,00,00
    RET
;----------------
DLY:PUSH AX
    PUSH CX

    MOV CX,6500
    NOP
    LOOP THIS FAR -1

    POP CX
    POP AX
    RET
;----------------
;    DB 510-(THIS FAR-S) DUP (00)
;    DB 055H,0AAH
;----------------
;BUF:;ORG 07E00H
CODE ENDS
END START
