ASSUME CS:CODE;,DS:DATA,SS:STACK,ES:EXTRA  ;58000H  --1.BIN    |  R |
CODE SEGMENT                               ;60000H  --2.BIN    ^  E v
    ORG 0100H                              ;68000H  --3.BIN    |  A |
START:                                     ;70000H  --4.BIN    ^  D v
    CLD                                    ;78000H  --5.BIN    |    |
    STI                                    ;80000H  --6.BIN  L ^    v
                                           ;88000H  --7.BIN  O |    |
    CALL FILETEXT                          ;90000H  --8.BIN  A ^    v
                                           ;98000H  --9.BIN  D |    |
    MOV CX,9                               ;----------------------------
    CALL READDISK
    LOOP THIS FAR -3               ;循环上一条指令9次

    JMP DISPLAY
;----------------------------------
    DISKDATA DB 0FFH,97H           ;缓冲区段地址     ;0110H
    BUFFER   DB 10H,00H            ;数据缓冲区
    HANDLE   DB 00,00              ;文件句柄
             DB 00,00
    FILENAME DB '9.BIN',00,00,00   ;文件名
             DB '$' 
;----------------------------------
    CSDISKDATAADDR EQU OFFSET DISKDATA
    CSFILENAMEADDR EQU OFFSET FILENAME
;----------------------------------
      DISKDATAADDR EQU 00
        BUFFERADDR EQU 02
        HANDLEADDR EQU 04
      FILENAMEADDR EQU 08
    DATABUFFERADDR EQU 10H
;----------------------------------
    ERRINFO1 DB 'MISSING FILES',13,10,'$'
;-----------------
FILETEXT PROC NEAR
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
    RET
;----------------
MISSFILE:
    MOV DX,OFFSET ERRINFO1
    MOV AH,09
    INT 21H
    MOV DX,OFFSET FILENAME
    MOV AH,09
    INT 21H
    JMP PROEND
FILETEXT ENDP
;----------------------------------
READDISK PROC NEAR
    PUSHF
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
    POPF
    RET
READDISK ENDP
;----------------------------------
MOVDATA PROC NEAR
    PUSH AX
    PUSH BP

    MOV CX,8                      ;一共16字节
    MOV BP,OFFSET DISKDATA
MOVDATALOO:
    MOV AX,CS:[BP]
    MOV DS:[BP - 110H],AX           ;传输程序中的应用字段到数据头部
    ADD BP,2
    LOOP MOVDATALOO

    POP BP
    POP AX
    RET
MOVDATA ENDP
;----------------------------------
DISPLAY:
    XOR DI,DI

    MOV AX,0B800H
    MOV ES,AX
    MOV AX,05800H
    MOV DS,AX

    MOV CX,9                       ;切换数据段
HANDOFFSET:
    PUSH CX
    MOV SI,0000

    MOV CX,64                      ;切换一份数据
HANDDATA:
    PUSH CX

    MOV CX,4
HANDINDATA:                        ;切换500字节内的数据(125字节)
    PUSH CX

    XOR BX,BX
    MOV CX,125                     ;切换画面
HANDFRAMES:
    PUSH CX

    LODSB
    MOV CX,8                       ;切换画面像素
HANDBIT:
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

    CALL WAITONE
    POP CX
    LOOP HANDINDATA

    ADD SI,0CH                     ;500+12字节
    POP CX
    LOOP HANDDATA

    PUSH DS
    POP AX
    ADD AX,800H
    PUSH AX
    POP DS
    POP CX
    LOOP HANDOFFSET

    JMP PROEND
;----------------------------------
WAITONE PROC NEAR
    PUSH CX

    MOV CX,7500                    ;这里没有0.1秒
    NOP
    LOOP THIS FAR -1

    POP CX
    RET
WAITONE ENDP
;----------------------------------
PROEND:
    MOV AX,4C00H
    INT 21H
CODE ENDS
END START
