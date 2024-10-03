%include"boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

;---------------------构建GDT及其内部的描述符--------------------------
	GDT_BASE:
		dd 0x00000000
		dd 0x00000000
	CODE_DESC:
		dd 0x0000FFFF
		dd DESC_CODE_HIGH4
	DATA_STACK_DESC:
		dd 0x0000FFFF
		dd DESC_DATA_HIGH4
	VIDEO_DESC:
		dd 0x80000007							;limit=(0xbffff-0xb8000)/4k=0x7
		dd DESC_VIDEO_HIGH4						;此时dpi为0
	
	GDT_SIZE		equ		$-GDT_BASE
	GDT_LIMIT		equ		GDT_SIZE-1
	times 60 dq 0								;此处预留60个描述符的空位
	SELECTOR_CODE	equ		(0x0001<<3)+TI_GDT+RPL0	;相当于(CODE_DESC-GDT_BASE)/8+TI_GDT+RPL0
	SELECTOR_DATA	equ		(0x0002<<3)+TI_GDT+RPL0
	SELECTOR_VIDEO	equ		(0x0003<<3)+TI_GDT+RPL0

;人工对齐256字节到ards_nr
;total_mem_bytes用于保存内存容量,以字节为单位,此位置比较好记
;当前偏移loader.bin文件头0x200字节
;loader.bin的加载地址是0x900
;故total_mem_bytes内存中的地址是0xb00
;将来在内核中咱们会引用此地址
	total_mem_bytes dd 0

;以下是GDT的指针,前2字节是GDT界限,后4字节是GDT起始地址

	gdt_ptr		dw	GDT_LIMIT
				dd	GDT_BASE
	loadermsg	db 'loading the kernel...'
	ards_buf times 223 db 0
	ards_nr dw 0			;用于记录ARDS结构体的数量

loader_start:

;-------------------------------------------------------------------------------
;INT 0x10	功能号:0x13	功能描述:打印字符串
;-------------------------------------------------------------------------------
;输入:
;AH 子功能号=13H
;BH=页码
;BL=属性(若AL=00H或01H)
;CX=字符串长度
;(DH,DL)=坐标(行,列)
;ES:BP=字符串地址
;AL=显示输出方式
;0-字符串中只含显示字符,其显示属性在BL中,显示后,光标位置不变
;1-字符串中只含显示字符,其显示属性在BL中,显示后,光标位置改变
;2-字符串中含显示字符和显示属性.显示后,光标位置不变
;3-字符串中含显示字符和显示属性.显示后,光标位置改变
;无返回值
	mov sp,LOADER_BASE_ADDR
	mov bp,loadermsg
	mov cx,21
	mov ax,0x1301
	mov bx,0x001f
	mov dx,0x1800
	int 0x10
;---------------------获取内存容量------------------------------
;int 15h eax=0000E820h,edx=534D4150h('SMAP')获取内存布局
	xor ebx,ebx					;第一次调用时,ebx值要为0
	mov edx,0x534d4150			;edx只赋值一次,循环体中不会改变
	mov di,ards_buf				;ards结构缓冲区
.e820_mem_get_loop:				;循环获取每个ARDS内存范围描述结构
	mov eax,0x0000e820			;执行int 0x15后,eax值变为0x534d4150,所以每次执行int前都要更新为子功能号
	mov ecx,20					;ARDS地址范围描述符结构大小是20字节
	int 0x15
	jc .e820_failed_so_try_e801	;若cf位为1则有错误发生,尝试0xe801子功能
	add di,cx					;使di增加20字节指向缓冲区中新的ARDS结构位置
	inc word [ards_nr]			;记录ARDS数量
	cmp ebx,0					;若ebx为0且cf位不为1,这说明ards全部返回,当前已是最后一个
	jnz .e820_mem_get_loop
;在所有ards结构中
;找出(base_add_low+length_low)的最大值,即内存的容量
	mov cx,[ards_nr]
;遍历每一个ARDS结构体,循环次数是ARDS的数量
	mov ebx,ards_buf
	xor edx,edx					;edx为最大的内存容量,在此先清0
.find_max_mem_area:				;无需判断type是否为1,最大的内存块一定是可被使用的
	mov eax,[ebx]				;base_add_low
	add eax,[ebx+8]				;length_low
	add ebx,20					;指向缓冲区中下一个ARDS结构
;--------------------准备进入保护模式---------------------------
;1 打开A20Gate(关闭地址回绕)
;2 加载GDT
;3 将cr0的pe位置1(进入保护模式)

	;-----------打开A20Gate--------
	in al,0x92
	or al,0000_0010B
	out 0x92,al

	;-----------加载GDT------------
	lgdt [gdt_ptr]

	;----------cr0第0位置1---------
	mov eax,cr0
	or eax,0x00000001
	mov cr0,eax

	jmp dword SELECTOR_CODE:p_mode_start	;刷新流水线


[bits 32]
p_mode_start:
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP
	mov ax,SELECTOR_VIDEO
	mov gs,ax

	mov byte [gs:160],'P'

	jmp $
