;主引导程序
;
;LOADER_BASE_ADDR equ 0xA000
;LOADER_START_SECTOR equ 0x2
;-------------------------------------
SECTION MBR vstart=0x7c00 ;告诉编译器把此段的起始地址编译为0x7c00
    mov ax,cs   ;此行及以下4行->用cs(code segment)的值初始化其他寄存器
    mov ds,ax   ;没有从立即数到段寄存器的电路实现
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00   ;初始化栈指针,0x7c00以下暂时是安全的区域
	mov ax,0xb800	;显存段地址
	mov gs,ax		;通过ax中转

;清屏利用0x06号功能,上卷全部行,即可清屏
;----------------------------------------
;INT 0x10   功能号:0x06 功能描述:上卷窗口
;输入:
;AH 功能号=0x06
;AL=上卷的行数(如果为0,表示全部)
;BH=上卷行属性
;(CL,CH)=窗口左上角的(X,Y)位置
;(DL,DH)=窗口右下角的(X,Y)位置
;无返回值:
    mov ax,0x600
    mov bx,0x700
    mov cx,0            ;左上角:(0,0)
    mov dx,0x184f       ;右下角:(80,25)
                        ;VGA文本模式中,一行只能容纳80个字符,共25行
                        ;下标从零开始,所以0x18=24,0x4f=79
    int 0x10            ;INT 0x10

;;;;;;;;;;;;;;;;; 打印字符串 ;;;;;;;;;;;;;;;;;;;;;
	mov byte [gs:0x00],'H'
	mov byte [gs:0x01],0xA4
	mov byte [gs:0x02],'e'
	mov byte [gs:0x03],0xA4
	mov byte [gs:0x04],'l'
	mov byte [gs:0x05],0xA4
	mov byte [gs:0x06],'l'
	mov byte [gs:0x07],0xA4
	mov byte [gs:0x08],'o'
	mov byte [gs:0x09],0xA4
	mov byte [gs:0x10],'W'
	mov byte [gs:0x11],0xA4
	mov byte [gs:0x12],'o'
	mov byte [gs:0x13],0xA4
	mov byte [gs:0x14],'r'
	mov byte [gs:0x15],0xA4
	mov byte [gs:0x16],'l'
	mov byte [gs:0x17],0xA4
	mov byte [gs:0x18],'d'
	mov byte [gs:0x19],0xA4
;;;;;;;;;;;;;;;; 打印字符串结束 ;;;;;;;;;;;;;

	jmp $				;通过无限循环使程序悬停在此

	times 510-($-$$) db 0
	db 0x55,0xaa
