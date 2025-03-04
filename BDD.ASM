;58000H  --1.BIN    |  R |
;60000H  --2.BIN    ^  E v
;68000H  --3.BIN    |  A |
;70000H  --4.BIN    ^  D v
;78000H  --5.BIN    |    |
;80000H  --6.BIN  L ^    v
;88000H  --7.BIN  O |    |
;90000H  --8.BIN  A ^    v
;98000H  --9.BIN  D |    |
ASSUME CS:CODE;,DS:DATA,SS:STACK,ES:EXTRA
CODE SEGMENT
    ORG 0100H
START:
    CLD                             ;递增读取
    STI                             ;开启中断

    MOV DX,CS
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

    JMP DISPLAY

    PROEND:
    MOV AX,4C00H
    INT 21H
;-------------------------------------------------------------------------------
      INFODATAADDR EQU THIS FAR - START + 100H
        THEPROGLEN EQU THEEND - START
;-------------------------------------------------------------------------------
    CSDISKDATAADDR EQU OFFSET DISKDATA
    CSFILENAMEADDR EQU OFFSET FILENAME
;-------------------------------------------------------------------------------
      DISKDATAADDR EQU 00
        BUFFERADDR EQU 02
        HANDLEADDR EQU 04
      FILENAMEADDR EQU 08
    DATABUFFERADDR EQU 10H
      CTRLPORT8253 EQU 43H
      DATAPORT8253 EQU 40H
;-------------------------------------------------------------------------------
;-----18BYTES-------------------------------------------------------------------
      DISKDATA DB 0FFH,97H           ;缓冲区段地址
      BUFFER   DB 10H,00H            ;数据缓冲区
      HANDLE   DB 00,00              ;文件句柄
               DB 00,00
      FILENAME DB '9.BIN',00,00,00   ;文件名
               DB '$',00
;-------------------------------------------------------------------------------
        PROSEG DB 'PROG SEGMENT IS '
 PROSEGADDRBUF DB 4 DUP (30H)
;      PCMEMORY DB '.BASEMEMORY HAS '
;     PCMEMSIZE DB 4 DUP (30H)
;               DB 'KB'
    PRESSENTER DB 13,10,'PRESS ENTER KEY TO CONTINUE$'
      ERRINFO1 DB 'MISSING FILE:$'
    ASCIITABLE DB '0123456789ABCDEF'
;-------------------------------------------------------------------------------
HEX2ASC PROC NEAR   ;IN:DX=HEX NUM,DI=OUT BUFFER.OUT:DX=OUT BUFFER
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH ES
        PUSH DS
        POP ES
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
    POP ES
    POP CX
    POP BX
    POP AX
    RET
    HEX2ASC ENDP
;-------------------------------------------------------------------------------
FILETEXT PROC NEAR
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
    JMP PROEND
    FILETEXT ENDP
;-------------------------------------------------------------------------------
READDISK PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH BP
    PUSH DS
        MOV BP,CSDISKDATAADDR
        MOV AX,CS:[BP]
        MOV DS,AX                     ;DS指向缓冲区段

        CALL MOVDATA

        LEA DX,DS:[FILENAMEADDR]      ;DX指向文件名
        MOV AX,3D00H
        INT 21H                       ;AH打开文件AL读取方式只读

        MOV BX,AX                     ;BX文件号
        MOV AX,3F00H                  ;读文件
        MOV CX,8000H                  ;字节数8000H字节(32768字节)
        LEA DX,DS:[DATABUFFERADDR]    ;DX指向数据缓冲区
        INT 21H

        MOV AH,3EH                    ;关闭文件
        INT 21H

        MOV BP,[CSDISKDATAADDR]       ;
        MOV BX,CS:[BP]
        SUB BX,800H
        MOV CS:[BP],BX

        MOV BP,[CSFILENAMEADDR]       ;
        MOV BL,CS:[BP]
        DEC BL
        MOV CS:[BP],BL
    POP DS
    POP BP
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    READDISK ENDP
;-------------------------------------------------------------------------------
MOVDATA PROC NEAR
    PUSH AX
    PUSH BP
    MOV CX,8;一共16字节
    MOV BP,OFFSET DISKDATA
        MOVDATALOO:;传输程序中的应用字段到数据头部
        MOV AX,CS:[BP]
        MOV DS:[BP - INFODATAADDR],AX
        ADD BP,2
    LOOP MOVDATALOO
    POP BP
    POP AX
    RET
    MOVDATA ENDP
;-------------------------------------------------------------------------------
WAITSET PROC NEAR
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
    WAITSET ENDP
;-------------------------------------------------------------------------------
WAITONE PROC NEAR
    PUSH CX
        MOV CX,2            ;0.05s*2=0.1s
            HLT             ;停机,等待8253信号
        LOOP THIS FAR -1
    POP CX
    RET
    WAITONE ENDP
;-------------------------------------------------------------------------------
DISPLAY:
    XOR DI,DI

    CALL WAITSET

    MOV AX,0B800H
    MOV ES,AX
    MOV AX,05800H
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
                        PUSHF
                        POP DX
                        AND DX,0001
                        JNP WHITE
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
                CALL WAITONE;暂停0.1s
            POP CX
            LOOP HANDINDATA
            ADD SI,0CH;500+12字节
        POP CX
        LOOP HANDDATA
        MOV AX,DS
        ADD AX,800H
        PUSH AX
        POP DS
    POP CX
    LOOP HANDOFFSET
;-------------------------------------------------------------------------------
    JMP PROEND
    THEEND:
    DB "KOIZUMI"
CODE ENDS
END START