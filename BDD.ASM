;-------------------------------------------------------------------------------
;X      :100H   --CODE
;X      :FFFEH  --STACK
;X+1000H        --1.BIN INFO            L|  R|
;X+1001H        --1.BIN(0010H-FFEBH)     v   v
;X+2000H        --2.BIN INFO            O|  E|
;X+2001H        --2.BIN(0010H-FFEBH)     v   v
;X+3000H        --3.BIN INFO            A|  A|
;X+3001H        --3.BIN(0010H-FFEBH)     v   v
;X+4000H        --4.BIN INFO            D|  D|
;X+4001H        --4.BIN(0010H-FFEBH)     v   v
;X+5000H        --5.BIN INFO             |   |
;X+5001H        --5.BIN(0010H-30E3H)     v   v
;-------------------------------------------------------------------------------
ASSUME CS:CODE
CODE SEGMENT
    ORG 0100H
 START:
    JMP MAIN
    DB "KOIZUMI"
    DB 25H,06H,15H,03H,44H,00H
;---程序相关信息-----------------------------------------------------------------
    INFO_DATA_ADDRESS EQU THIS FAR - START + 100H  ;文件读取的数据地址
    THE_PROG_LEN EQU THEEND - START           ;程序长度
;---读取文件的信息16BYTES--------------------------------------------------------
    DISK_DATA DW 0000H;遗留

    BUFFER DW 0010H                    ;数据缓冲区
    BUFFER_ADDRESS EQU 02

    HANDLE DW 0000H                    ;文件句柄
    HANDLE_ADDRESS EQU 04

    FILE_NAME DB '1.BIN',00,00,00,"$"  ;文件名
    FILE_NAME_ADDRESS EQU 06
    CS_FILE_NAME_ADDRESS EQU OFFSET FILE_NAME

             DB 05AH
    DATA_BUFFER_ADDRESS EQU 10H        ;每个段中数据的起始位置
;---缓冲区段地址-----------------------------------------------------------------
    START_LOAD_SEG  DW 1001H      ;从此开始读取数据
;---显示信息---------------------------------------------------------------------
           PRO_SEG DB 'PROG SEGMENT IS '                     ;16B
  PRO_SEG_ADDRESS_BUFFER DB 4 DUP (30H)                            ;4B
 ;      PCMEMORY DB '.BASEMEMORY HAS '
 ;     PCMEMSIZE DB 4 DUP (30H)
 ;               DB 'KB'
       PRESS_ENTER DB 13,10,'PRESS ENTER KEY TO CONTINUE$'   ;30B
       ASCII_TABLE DB '0123456789ABCDEF'                     ;16B
         ERRINFO_1 DB 'MISSING FILE:$'                       ;14B
 ;        ERRINFO_2 DB 'MEMORY SHORTAGE$'
;---主程序-----------------------------------------------------------------------
    MAIN:
        CLD
        STI

        MOV DX,CS
        ADD WORD PTR [START_LOAD_SEG],DX

        LEA DI,PRO_SEG_ADDRESS_BUFFER
        CALL HEX2ASC
        LEA DX,PRO_SEG
        MOV AH,09H
        INT 21H

        MOV AH,01H
        INT 21H
        CMP AL,13
        JNE PRO_END

        CALL FILE_TEXT
        CALL MOVE_DATA_INFO
        CALL READ_DISK

        CALL DELAY_1S

        CALL DISPLAY
    PRO_END:
        MOV AH,4CH
        INT 21H
;---二进制数转字符串--------------------------------------------------------------
HEX2ASC PROC NEAR   ;IN:DX=HEX NUM,DI=OUT BUFFER.OUT:DX=OUT BUFFER
    PUSH AX
    PUSH BX
    PUSH CX
        LEA BX,ASCII_TABLE
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
    POP CX
    POP BX
    POP AX
    RET
    HEX2ASC ENDP
;---测试文件存在-----------------------------------------------------------------
FILE_TEXT PROC NEAR
    PUSHF
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
        MOV CX,5
        FILETEXTLOO:
            CLC                           ;CF置0,防止误触
            MOV DX,OFFSET FILE_NAME
            MOV AX,3D00H
            INT 21H                       ;若打开成功,CF=0.失败则为1

            JC MISSFILE                   ;若CF=1
            MOV BX,DX
            INC BYTE PTR [BX]

            PUSH BX
                MOV BX,AX
                MOV AX,3E00H
                INT 21H
            POP BX
        LOOP FILETEXTLOO
        MOV BYTE PTR [FILE_NAME],'1'
    POP DX
    POP CX
    POP BX
    POP AX
    POPF
    RET

    MISSFILE:
    MOV DX,OFFSET ERRINFO_1
    MOV AH,09
    INT 21H
    MOV DX,OFFSET FILE_NAME
    MOV AH,09
    INT 21H
    INT 20H
    FILE_TEXT ENDP
;---配置文件传输信息--------------------------------------------------------------
MOVE_DATA_INFO PROC NEAR
    PUSH ES
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI
        MOV BX,ES
        ADD BX,1000H                    ;ES指向下一个段

        MOV CX,5
        MOVE_DATA_INFO_NEXT_SEG:
        PUSH CX
            LEA SI,DISK_DATA
            MOV ES,BX
            XOR DI,DI
            MOV CX,8
            REP MOVSW
        POP CX
        ADD BX,1000H                    ;目标指向下一个段
        MOV CS:[DISK_DATA],BX           ;段地址指向新段(下一个段)
        INC BYTE PTR CS:[FILE_NAME]     ;文件名+1
        LOOP MOVE_DATA_INFO_NEXT_SEG
    POP DI
    POP SI
    POP CX
    POP BX
    POP ES
    RET
    MOVE_DATA_INFO ENDP
;---读取文件到内存----------------------------------------------------------------
READ_DISK PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DS
    PUSH BP
    MOV BP,SP
    SUB SP,2
        MOV [BP-2],DS
        MOV CX,5
        READ_DISK_LOOP:
        PUSH CX
            ADD [BP-2],1000H
            MOV DS,[BP-2]

            LEA DX,DS:[FILE_NAME_ADDRESS]       ;指向文件名
            MOV AX,3D00H
            INT 21H                             ;AH打开文件AL读取方式只读

            MOV BX,AX                           ;BX文件号
            MOV AX,3F00H                        ;读文件
            MOV CX,65500                        ;65500字节
            LEA DX,DS:[DATA_BUFFER_ADDRESS]     ;DX指向数据缓冲区
            INT 21H

            MOV AH,3EH                          ;关闭文件
            INT 21H
        POP CX
        LOOP READ_DISK_LOOP
    ADD SP,2
    POP BP
    POP DS
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    READ_DISK ENDP
;---8253设置程序-----------------------------------------------------------------
DELAY_1S PROC NEAR
    PUSH AX
    PUSH DX
        MOV AL,00110110B      ;00:计数器0,11:先低字节后高字节,011:方波发生器
        MOV DX,CTRL_PORT_8253 ;8253控制端口
        OUT DX,AL

        MOV AX,59659          ;1.1931816MHz*0.05s=59659
        MOV DX,DATA_PORT_8253 ;8253数据端口
        OUT DX,AL
        XCHG AL,AH
        OUT DX,AL
    POP DX
    POP AX
    RET
    DELAY_1S ENDP
    CTRL_PORT_8253 EQU 43H          ;8253控制端口
    DATA_PORT_8253 EQU 40H          ;8253数据端口
;-------------------------------------------------------------------------------
DISPLAY PROC NEAR
    PUSH DS
    PUSH ES
    PUSH BP
    MOV BP,SP
    SUB SP,4
    ;[BP-2]:数据段地址
    ;[BP-4]:单元计数器
        XOR DI,DI   ;DI到第1行第1列
        MOV AX,0B800H
        MOV ES,AX
        PUSH [START_LOAD_SEG]
        POP [BP-2]
        MOV [BP-4],64987 ;将计数器设为65535与549(单元数)的差+1,计数完成后将溢出

        MOV CX,5
        HAND_OFFSET:;切换数据段
        PUSH CX
            MOV DS,[BP-2]
            XOR SI,SI;源指向数据第一个字
            MOV CX,131
            HAND_UNIT:;切换单元(500字节)
            PUSH CX
                MOV CX,4
                HAND_UNIT_IN_DATA:;切换单元内数据
                PUSH CX
                    XOR BX,BX
                    MOV CX,125
                    HAND_FRAME:;切换画面
                    PUSH CX
                        LODSB
                        MOV CX,8
                        HAND_BIT:;切换像素
                            SHL AL,1
                            JC WHITE
                                MOV WORD PTR ES:[BX],0020H     ;黑色
                                MOV WORD PTR ES:[BX+2],0020H
                                JMP THIS FAR +13
                            WHITE:
                                MOV WORD PTR ES:[BX],7FDBH     ;白色
                                MOV WORD PTR ES:[BX+2],7FDBH
                            ADD BX,4
                        LOOP HAND_BIT
                    POP CX
                    LOOP HAND_FRAME
                    HLT
                    HLT
                POP CX
                LOOP HAND_UNIT_IN_DATA
                INC WORD PTR [BP-4]
                JNZ DISPLAY_CONTINUE          ;如果溢出说明已经读取全部单元
                    ADD SP,4
                    JMP SHORT DISPLAY_END
                DISPLAY_CONTINUE:
            POP CX
            LOOP HAND_UNIT
            ADD WORD PTR [BP-2],1000H   ;指向下一个数据段
        POP CX
        LOOP HAND_OFFSET
        DISPLAY_END:
    ADD SP,4
    POP BP
    POP ES
    POP DS
    RET
    DISPLAY ENDP
;-------------------------------------------------------------------------------
THEEND:
CODE ENDS
END START