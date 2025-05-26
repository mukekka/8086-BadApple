;--------NEW--------
;X      :100H   --CODE
;X      :FFFEH  --STACK
;X+1000H        --1.BININFO
;X+1000H:10H    --1.BIN       |  R |
;X+1800H        --2.BININFO
;X+1800H:10H    --2.BIN       ^  E v
;X+2000H        --3.BININFO
;X+2000H:10H    --3.BIN       |  A |
;X+2800H        --4.BININFO
;X+2800H:10H    --4.BIN       ^  D v
;X+3000H        --5.BININFO
;X+3000H:10H    --5.BIN       |    |
;X+3800H        --6.BININFO
;X+3800H:10H    --6.BIN     L ^    v
;X+4000H        --7.BININFO
;X+4000H:10H    --7.BIN     O |    |
;X+4800H        --8.BININFO
;X+4800H:10H    --8.BIN     A ^    v
;X+5000H        --9.BININFO
;X+5000H:10H    --9.BIN     D |    |
;X+5800H        --END
ASSUME CS:CODE
CODE SEGMENT
    ORG 0100H
START:
    JMP MAIN
    DB "KOIZUMI";签名
    DB 25H,04H,15H,19H,59H,16H
;-----程序相关信息---------------------------------------------------------------
      INFODATAADDR EQU THIS FAR - START + 100H  ;文件读取的数据地址
        THEPROGLEN EQU THEEND - START           ;程序长度
;-----8253控制信息---------------------------------------------------------------
      CTRLPORT8253 EQU 43H          ;8253控制端口
      DATAPORT8253 EQU 40H          ;8253数据端口
;-----读取文件的信息16BYTES------------------------------------------------------
    DISKDATA DW 5000H                 ;缓存数据长度->缓冲区段地址
    DISKDATAADDR EQU 00
    CSDISKDATAADDR EQU OFFSET DISKDATA

    BUFFER   DW 0010H              ;数据缓冲区
    BUFFERADDR EQU 02

    HANDLE   DW 0000H              ;文件句柄
    HANDLEADDR EQU 04

    FILENAME DB '9.BIN',00,00,00,"$";文件名
    FILENAMEADDR EQU 06
    CSFILENAMEADDR EQU OFFSET FILENAME

             DB 05AH
    DATABUFFERADDR EQU 10H
;---缓冲区段地址-----------------------------------------------------------------
    STARTLOADADDRESS  DW 1001H      ;从此开始读取数据
;---显示信息---------------------------------------------------------------------
           PROSEG DB 'PROG SEGMENT IS '                     ;16B
    PROSEGADDRBUF DB 4 DUP (30H)                            ;4B
;      PCMEMORY DB '.BASEMEMORY HAS '
;     PCMEMSIZE DB 4 DUP (30H)
;               DB 'KB'
       PRESSENTER DB 13,10,'PRESS ENTER KEY TO CONTINUE$'   ;30B
       ASCIITABLE DB '0123456789ABCDEF'                     ;16B
         ERRINFO1 DB 'MISSING FILE:$'                       ;14B
;        ERRINFO2 DB 'MEMORY SHORTAGE$'
;-------------------------------------------------------------------------------
MAIN:
    CLD                             ;递增读取
    STI                             ;开启中断

    MOV DX,CS
    ADD WORD PTR [DISKDATA],DX
    ADD WORD PTR [STARTLOADADDRESS],DX

    LEA DI,PROSEGADDRBUF
    CALL HEX2ASC                    ;所在段地址转换为字符串

    LEA DX,PROSEG
    MOV AH,09H
    INT 21H

    MOV AH,01H
    INT 21H
    CMP AL,13                       ;按下回车键
    JNE PROEND
    
    CALL FILETEXT                   ;测试文件是否存在

    MOV CX,9
        CALL READDISK               ;读取文件到内存
    LOOP THIS FAR -3
    
    CALL DISPLAY

    PROEND:
    INT 20H
;-------------------------------------------------------------------------------
HEX2ASC PROC NEAR   ;IN:DX=HEX NUM,DI=OUT BUFFER.OUT:DX=OUT BUFFER
    PUSH AX
    PUSH BX
    PUSH CX
    ; PUSH ES
    ;     PUSH DS
    ;     POP ES
        LEA BX,ASCIITABLE
        MOV CX,4
        HEX2CHAR:
        PUSH CX
            XOR AL,AL
            MOV CX,4
            DXSHIFTAL:
                SHL DX,1
                RCL AL,1
            LOOP DXSHIFTAL
            XLAT
            STOSB
        POP CX
        LOOP HEX2CHAR
        MOV DX,DI
        XOR DI,DI
    ; POP ES
    POP CX
    POP BX
    POP AX
    RET
    HEX2ASC ENDP
;-------------------------------------------------------------------------------
FILETEXT PROC NEAR;测试文件是否存在
    PUSHF
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
        MOV CX,9
        FILETEXTLOO:
            CLC                           ;CF置0,防止误触
            MOV DX,OFFSET FILENAME
            MOV AX,3D00H
            INT 21H                       ;若打开成功,CF=0.失败则为1

            JC MISSFILE                   ;若CF=1
            MOV BX,DX
            DEC BYTE PTR [BX]

            PUSH BX
                MOV BX,AX
                MOV AX,3E00H
                INT 21H
            POP BX
        LOOP FILETEXTLOO
        MOV BYTE PTR [FILENAME],'9'
    POP DX
    POP CX
    POP BX
    POP AX
    POPF
    RET
    MISSFILE:
    MOV DX,OFFSET ERRINFO1
    MOV AH,09
    INT 21H
    MOV DX,OFFSET FILENAME
    MOV AH,09
    INT 21H
    INT 20H
    FILETEXT ENDP
;-------------------------------------------------------------------------------
READDISK PROC NEAR;读取磁盘文件到内存
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DS
        MOV BX,CSDISKDATAADDR
        MOV AX,CS:[BX]
        MOV DS,AX                     ;DS指向缓冲区段

        CALL MOVDATA

        LEA DX,DS:[FILENAMEADDR]      ;DX指向文件名
        MOV AX,3D00H
        INT 21H                       ;AH打开文件AL读取方式只读

        MOV BX,AX                     ;BX文件号
        MOV AX,3F00H                  ;读文件
        MOV CX,8000H                  ;8000H字节(32768字节)
        LEA DX,DS:[DATABUFFERADDR]    ;DX指向数据缓冲区
        INT 21H

        MOV AH,3EH                    ;关闭文件
        INT 21H

        MOV BX,CSDISKDATAADDR       ;获取缓冲区指针地址
        SUB WORD PTR CS:[BX],800H     ;缓冲地址-800H

        MOV BX,CSFILENAMEADDR       ;获取文件名指针地址
        DEC BYTE PTR CS:[BX]          ;文件名-1
    POP DS
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    READDISK ENDP
;-------------------------------------------------------------------------------
MOVDATA PROC NEAR;传输读取文件的信息
    PUSH AX
    PUSH BX
        MOV CX,8            ;一共16字节
        MOV BX,CSDISKDATAADDR
        MOVDATALOO:         ;传输程序中的应用字段到数据头部
            MOV AX,CS:[BX]
            MOV DS:[BX - INFODATAADDR],AX
            ADD BX,2
        LOOP MOVDATALOO
    POP BX
    POP AX
    RET
    MOVDATA ENDP
;-------------------------------------------------------------------------------
WAITSET PROC NEAR;8253设置程序
    PUSH AX
    PUSH DX
        MOV AL,00110110B    ;00:计数器0,11:先低字节后高字节,011:方波发生器
        MOV DX,CTRLPORT8253 ;8253控制端口
        OUT DX,AL

        MOV AX,59659        ;1.1931816MHz*0.05s=59659
        MOV DX,DATAPORT8253 ;8253数据端口
        OUT DX,AL
        XCHG AL,AH
        OUT DX,AL
    POP DX
    POP AX
    RET
    WAITSET ENDP
;-------------------------------------------------------------------------------
WAITONE PROC NEAR;暂停0.1秒
    ; PUSH CX
        ; MOV CX,2            ;0.05s*2=0.1s
            ; HLT             ;停机,等待8253信号
        ; LOOP THIS FAR -1
    ; POP CX
    ; RET
    WAITONE ENDP
;-------------------------------------------------------------------------------
DISPLAY:;显示数据
    CALL WAITSET

    XOR DI,DI
    MOV AX,0B800H
    MOV ES,AX
    MOV AX,[STARTLOADADDRESS]
    MOV DS,AX

    MOV CX,9
    HANDOFFSET:;切换数据段
    PUSH CX
        XOR SI,SI
        MOV CX,64
        HANDDATA:;切换一份数据
        PUSH CX
            MOV CX,4
            HANDINDATA:;切换500字节内的数据(125字节)
            PUSH CX
                XOR BX,BX
                MOV CX,125
                HANDFRAMES:;切换画面
                PUSH CX
                    LODSB
                    MOV CX,8
                    HANDBIT:;切换画面像素
                        SHL AL,1
                        JC WHITE
                            MOV WORD PTR ES:[BX],0020H     ;黑色
                            MOV WORD PTR ES:[BX+2],0020H
                            JMP THIS FAR +13
                        WHITE:
                            MOV WORD PTR ES:[BX],7FDBH     ;白色
                            MOV WORD PTR ES:[BX+2],7FDBH
                        ADD BX,4
                    LOOP HANDBIT
                POP CX
                LOOP HANDFRAMES
                ;CALL WAITONE;暂停0.1s
                HLT
                HLT
            POP CX
            LOOP HANDINDATA
            ADD SI,0CH;500+12字节
        POP CX
        LOOP HANDDATA
        MOV AX,DS   ;DS+800H
        ADD AX,800H
        PUSH AX
        POP DS
    POP CX
    LOOP HANDOFFSET
    RET
;-------------------------------------------------------------------------------
    THEEND:
CODE ENDS
END START
