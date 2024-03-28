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
    LOOP THIS FAR -3               ;ѭ����һ��ָ��9��

    JMP DISPLAY
;----------------------------------
    DISKDATA DB 0FFH,97H           ;�������ε�ַ     ;0110H
    BUFFER   DB 10H,00H            ;���ݻ�����
    HANDLE   DB 00,00              ;�ļ����
             DB 00,00
    FILENAME DB '9.BIN',00,00,00   ;�ļ���
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
    CLC                           ;CF��0,��ֹ��
    MOV DX,OFFSET FILENAME
    MOV AX,3D00H
    INT 21H                       ;���򿪳ɹ�,CF=0.ʧ����Ϊ1

    JC MISSFILE                   ;��CF=1
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
    MOV DS,AX                     ;DSָ�򻺳�����

    CALL MOVDATA

    LEA DX,DS:[FILENAMEADDR]      ;DXָ���ļ���
    MOV AX,3D00H
    INT 21H                       ;AH���ļ�AL��ȡ��ʽֻ��

    MOV BX,AX                     ;BX�ļ���
    MOV AX,3F00H                  ;���ļ�
    MOV CX,8000H                  ;�ֽ���8000H�ֽ�(32768�ֽ�)
    LEA DX,DS:[DATABUFFERADDR]    ;DXָ�����ݻ�����
    INT 21H

    MOV AH,3EH                    ;�ر��ļ�
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

    MOV CX,8                      ;һ��16�ֽ�
    MOV BP,OFFSET DISKDATA
MOVDATALOO:
    MOV AX,CS:[BP]
    MOV DS:[BP - 110H],AX           ;��������е�Ӧ���ֶε�����ͷ��
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

    MOV CX,9                       ;�л����ݶ�
HANDOFFSET:
    PUSH CX
    MOV SI,0000

    MOV CX,64                      ;�л�һ������
HANDDATA:
    PUSH CX

    MOV CX,4
HANDINDATA:                        ;�л�500�ֽ��ڵ�����(125�ֽ�)
    PUSH CX

    XOR BX,BX
    MOV CX,125                     ;�л�����
HANDFRAMES:
    PUSH CX

    LODSB
    MOV CX,8                       ;�л���������
HANDBIT:
    SHL AL,1
    PUSHF
    POP DX
    AND DX,0001
    JNP WHITE
    MOV WORD PTR ES:[BX],0020H     ;��ɫ
    MOV WORD PTR ES:[BX+2],0020H
    JMP THIS FAR +13
WHITE:
    MOV WORD PTR ES:[BX],7FDBH     ;��ɫ
    MOV WORD PTR ES:[BX+2],7FDBH
    ADD BX,4
    LOOP HANDBIT

    POP CX
    LOOP HANDFRAMES

    CALL WAITONE
    POP CX
    LOOP HANDINDATA

    ADD SI,0CH                     ;500+12�ֽ�
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

    MOV CX,7500
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
