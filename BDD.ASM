;-------------------------------------------------------------------------------
;X      :100H   --CODE
;X      :FFFEH  --STACK
;X+1000H        --1.BIN INFO
;X+1001H        --1.BIN(0000H-FFDBH,65500)37CCF0DC
;X+2000H        --2.BIN INFO
;X+2001H        --2.BIN(0000H-FFDBH,65500)266FE0D3
;X+3000H        --3.BIN INFO
;X+3001H        --3.BIN(0000H-FFDBH,65500)3DFA1315
;X+4000H        --4.BIN INFO
;X+4001H        --4.BIN(0000H-FFDBH,65500)3BD1ECEB
;X+5000H        --5.BIN INFO
;X+5001H        --5.BIN(0000H-30D3H,12500)092834E8
;-------------------------------------------------------------------------------
ASSUME CS:CODE
CODE SEGMENT
    ORG 0100H
 START:
    JMP MAIN
    DB "KOIZUMI"
    DB 25H,06H,17H,21H,38H,00H
;---程序相关信息-----------------------------------------------------------------
    INFO_DATA_ADDRESS EQU THIS FAR - START + 100H  ;文件读取的数据地址
    THE_PROG_LEN EQU THEEND - START                ;程序长度
    FILE_COUNTS EQU 5                              ;5个文件
    UNIT_COUNTS EQU 549                            ;单元总数
    UNIT_COUNT EQU 0FFFFH - UNIT_COUNTS + 1
;---读取文件配置信息--------------------------------------------------------------
FILE_INFO:
    BUFFER DW 0010H                    ;数据缓冲区
    BUFFER_ADDRESS EQU 00

    HANDLE DW 0000H                    ;文件句柄
    HANDLE_ADDRESS EQU 02

    FILE_NAME DB '1.BIN',00,00,00,"$"  ;文件名
    FILE_NAME_ADDRESS EQU 04
    CS_FILE_NAME_ADDRESS EQU OFFSET FILE_NAME

    DB '!'
    DATA_BUFFER_ADDRESS EQU 10H        ;每个段中数据的起始位置
    START_READ_SEG  DW 1001H           ;从此开始读取数据
;-------------------------------------------------------------------------------
    ASCII_TABLE DB '0123456789ABCDEF'                   ;16B
;---显示信息---------------------------------------------------------------------
    PRO_SEG DB 'PROG SEGMENT IS '                       ;16B
    PRO_SEG_ADDRESS_BUFFER DB 4 DUP (30H)               ;4B
 ;      PCMEMORY DB '.BASEMEMORY HAS '
 ;     PCMEMSIZE DB 4 DUP (30H)
 ;               DB 'KB'
    PRESS_ENTER DB 13,10,'PRESS ENTER KEY TO CONTINUE$' ;30B
    ERRINFO_1 DB 'MISSING FILE:$'                       ;14B
 ;  ERRINFO_2 DB 'MEMORY SHORTAGE$'
    ERRINFO_3 DB 'FILE VERIFY FAIL:$'                   ;18B
;---主程序-----------------------------------------------------------------------
MAIN:
        CLD
        STI

        MOV DX,CS
        ADD WORD PTR [START_READ_SEG],DX
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
        CALL MOVE_FILE_INFO
        CALL READ_DISK
        CALL FILE_VERIFY

        CALL DELAY_005S_SET
        CALL DISPLAY
    PRO_END:
        MOV AX,4C00H        ;00:完成运行
        INT 21H
;-------------------------------------------------------------------------------
;---二进制数转字符串--;IN:DX=十六进制数,DI=输出字符串地址.OUT:DX=输出字符串地址------
HEX2ASC PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
        LEA BX,ASCII_TABLE
        MOV CX,4
        HEX2CHAR:
        PUSH CX
            XOR AL,AL
            MOV CX,4
            DX_SHIFT_AL:
                SHL DX,1
                RCL AL,1
            LOOP DX_SHIFT_AL
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
        MOV CX,FILE_COUNTS
        FILE_TEXT_LOOP:
            CLC                           ;CF置0,防止误触
            LEA DX,FILE_NAME
            MOV AX,3D00H
            INT 21H                       ;若打开成功,CF=0.失败则为1

            JNC NOT_MISS_FILE                   ;若CF=0
                LEA DX,ERRINFO_1
                MOV AH,09
                INT 21H
                LEA DX,FILE_NAME
                MOV AH,09
                INT 21H
                CLI                 ;关中断作为标志位
            NOT_MISS_FILE:
            MOV BX,DX
            INC BYTE PTR [BX]
            PUSH BX
                MOV BX,AX
                MOV AX,3E00H
                INT 21H             ;关文件
            POP BX
        LOOP FILE_TEXT_LOOP
        PUSHF
        POP AX
        CMP AL,00000010B   ;检测中断位
        JNE MISS_FILE
        MOV BYTE PTR [FILE_NAME],'1'
    POP DX
    POP CX
    POP BX
    POP AX
    POPF
    RET

    MISS_FILE:
    MOV AX,4C01H        ;01:文件缺少
    INT 21H
    FILE_TEXT ENDP
;---内存检测---------------------------------------------------------------------
MEMORY_TEXT PROC NEAR
    PUSH AX

    POP AX
    RET
    MEMORY_TEXT ENDP
;---配置文件传输信息--------------------------------------------------------------
MOVE_FILE_INFO PROC NEAR
    PUSH ES
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI
        MOV BX,ES

        MOV CX,FILE_COUNTS
        MOVE_FILE_INFO_NEXT_SEG:
        PUSH CX
            LEA SI,FILE_INFO
            ADD BX,1000H                    ;ES指向下一个段
            MOV ES,BX
            XOR DI,DI
            MOV CX,8
            REP MOVSW
        POP CX
        INC BYTE PTR CS:[FILE_NAME]     ;文件名+1
        LOOP MOVE_FILE_INFO_NEXT_SEG
        MOV BYTE PTR [FILE_NAME],'1'
    POP DI
    POP SI
    POP CX
    POP BX
    POP ES
    RET
    MOVE_FILE_INFO ENDP
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
        MOV CX,FILE_COUNTS
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
;---文件校验---------------------------------------------------------------------
FILE_VERIFY PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DS
    PUSH BP
    MOV BP,SP
    SUB SP,12
        MOV [BP-2],UNIT_COUNT
        LEA BX,[BP-4]
        MOV [BP-4], 0F0DCH      ;1.BIN校验  ;BX指向此
        MOV [BP-6], 0E0D3H      ;2.BIN校验
        MOV [BP-8], 01315H      ;3.BIN校验
        MOV [BP-10],0ECEBH      ;4.BIN校验
        MOV [BP-12],034E8H      ;5.BIN校验
        MOV AX,[START_READ_SEG]
        MOV DS,AX

        MOV CX,FILE_COUNTS
        FILE_VERIFY_LOOP:;一个段一个文件
        PUSH CX
            XOR DX,DX   ;累加器归零
            XOR SI,SI   ;指向第一个字
            MOV CX,131
            FILE_VERIFY_UNIT_LOOP:;每段131个单元
            PUSH CX
                MOV CX,250
                FILE_VERIFY_UNIT_IN_DATA_LOOP:;每个单元500字节
                    LODSW
                    ADD DX,AX           ;叠加段内数据的值(校验结果)
                LOOP FILE_VERIFY_UNIT_IN_DATA_LOOP
                INC WORD PTR [BP-2]     ;单元计数器
                JNZ FILE_VERIFY_LOOP_CONTINUE;若计数器未满
                    ADD SP,4            ;丢弃两个CX计数器
                    XOR SS:[BX],DX      ;若校验值正确，则将值置0
                        MOV AX,CS
                        MOV DS,AX       ;DS指向程序
                        LEA BX,[BP-4]   ;BX指向第一个文件校验值
                        MOV CX,FILE_COUNTS
                        FILE_VERIFY_TEST:
                            CMP WORD PTR [BX],0
                            JZ FILE_VERIFY_NOT_FAIL;如校验值不正确
                                MOV AH,09H
                                LEA DX,ERRINFO_3
                                INT 21H
                                MOV AH,09H
                                LEA DX,FILE_NAME
                                INT 21H             ;打印错误信息与文件名
                                CLI                 ;关闭中断作为标志位
                            FILE_VERIFY_NOT_FAIL:
                            SUB BX,2                ;下一个文件校验值
                            INC BYTE PTR [FILE_NAME];下一个文件
                        LOOP FILE_VERIFY_TEST
                        JMP SHORT FILE_VERIFY_END   ;退出文件校验
                FILE_VERIFY_LOOP_CONTINUE:
            POP CX    
            LOOP FILE_VERIFY_UNIT_LOOP
            XOR SS:[BX],DX
            SUB BX,2        ;若校验值正确，则将值置0
            MOV AX,DS
            ADD AX,1000H
            MOV DS,AX       ;下一个数据段
        POP CX
        LOOP FILE_VERIFY_LOOP

        FILE_VERIFY_END:
        PUSHF
        POP AX
        CMP AL,00000010B   ;检测中断位
        JE FILE_VERIFY_LOSE

        MOV BYTE PTR [FILE_NAME],'1';恢复文件名为初始值
    ADD SP,12
    POP BP
    POP DS
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    FILE_VERIFY_LOSE:
        MOV AX,4C02H        ;02:文件校验失败
        INT 21H
    FILE_VERIFY ENDP
;---8253设置程序-----------------------------------------------------------------
DELAY_005S_SET PROC NEAR
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
    DELAY_005S_SET ENDP
    CTRL_PORT_8253 EQU 43H          ;8253控制端口
    DATA_PORT_8253 EQU 40H          ;8253数据端口
;---显示-------------------------------------------------------------------------
DISPLAY PROC NEAR
    PUSH DS
    PUSH ES
    PUSH BP
    MOV BP,SP
    SUB SP,4
        XOR DI,DI   ;DI到第1行第1列
        MOV AX,0B800H
        MOV ES,AX   ;ES指向显示缓冲区
        MOV AX,[START_READ_SEG]
        MOV [BP-2],AX           ;数据段起始地址
        MOV [BP-4],UNIT_COUNT   ;单元计数器
        MOV CX,FILE_COUNTS
        HAND_OFFSET:;切换数据段
        PUSH CX
            MOV DS,[BP-2]
            XOR SI,SI;源指向数据第一个字节
            MOV CX,131
            HAND_UNIT:;切换单元(每段131个单元，每个单元500字节)
            PUSH CX
                MOV CX,4
                HAND_UNIT_IN_DATA:;切换单元内数据(125*4)
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
                    HLT                       ;暂停0.1秒
                POP CX
                LOOP HAND_UNIT_IN_DATA
                INC WORD PTR [BP-4]
                JNZ DISPLAY_CONTINUE          ;如果溢出说明已经读取全部单元
                    ADD SP,8
                    JMP SHORT DISPLAY_END
                DISPLAY_CONTINUE:
            POP CX
            LOOP HAND_UNIT
            ADD WORD PTR [BP-2],1000H   ;指向下一个数据段
        POP CX
        LOOP HAND_OFFSET
    ADD SP,4
    DISPLAY_END:
    POP BP
    POP ES
    POP DS
    RET
    DISPLAY ENDP
;-------------------------------------------------------------------------------
THEEND:
CODE ENDS
END START