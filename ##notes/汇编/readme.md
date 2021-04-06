# 汇编

**[原书链接-zh](汇编/Professional%20Assembly%20Language,%20作者%20Richard%20Blum%20中文版.pdf)**


## 汇编语言基础

### 什么是汇编语言

什么是汇编语言? 汇编语言与一般语言的区别?

- 处理器指令
  - 指令格式
    - 这里介绍的是Intel IA-系列
- 使用汇编
  - **定义数据**
    - 两种方式: 内存中和堆栈中
    - 使用内存: 包含指向标记, 数据类型 (决定保留字节长度) 和默认值. 数据类型 `.ascii`, `.long`
  - **命令**
    - 一般老式的汇编没有现代 HLL 控制流(if/while)的特性
    - `.section` 命令, 用于定义内存段
    - 任何程序均要包含: 数据段, bss段, 文本段
      - *数据段* : 声明数据段落后, 该段不能拓展, 静态
      - *bss段* : *程序中声明的* 数据的缓冲区
      - *文本段* : 指令码

### 开发与范例

- 开发工具最低限度要求: 汇编器, 连接器(linker), 调试器
- 一个汇编程序

  ```asm
  # cpuid.s
  # Sample program to extract
  # the processor Vendor ID
  .section .data
  output :
          .ascii "The processor Vendor ID is 'xxxxxxxxxxx' \n"
  .section .text
  .global _start
  _start :
          movl $0, %eax
          cpuid
  movl $output, %edi
  movl %ebx, 28(%edi)
  movl %edx, 32(%edi)
  movl %ecx, 36(%edi)
  movl $4, %eax
  movl $1, %ebx
  movl $output, %ecx
  movl $42, %edx
  int $0x80
  movl $1, %eax
  movl $0, %ebx
  int $0x80
  ```

  - 定义段 : `.section` 
  - 默认一个汇编程序从 `_start` 标签开始 (GNU), 找不到该标签会报错. 也可以自定义起点
  - `.globl` 定义可被外部文件调用的标签, `.globl _start` 允许外部访问入口程序
  - `cpuid` 指令
    - `EAX` 寄存器内容作为入参, `EBX`, `ECX`, `EDX` 存返回值, 各存4个字节, 这里 `movl %0，%eax` 装载入参为 0
    - `36{%edi}` 表示, 相对于 `%edi` 的位置为 36 字节的地址
    - `int $0x80` 提出一个 80 值得系统中断执行系统调用, 具体系统调用由 `EAX` 决定: `movl $4, %eax`, 表示 write
      - `EAX` 包含系统调用值.
      - `EBX` 包含要写人的文件描述符.
      - `ECX` 包含字符串的开头.
      - `EDX` 包含字符串的长度.
- 第二个例子: 链接 C 库函数

  ```asm
  #cpuid2.s View the CPUID Vendor ID string using C library calls
  .section .data
  output:
          .asciz "The processor Vendor ID is '%s' \n"
  .section .bss
          .lcomm buffer, 12
  .section .text
  .globl _start
  _start:
          movl $0, %eax
          cpuid
          movl $buffer, %edi
          movl %ebx, (%edi)
          movl %edx, 4(%edi)
          movl %ecx, 8(%edi)
          push $buffer
          push $output
          call printf
          addl $8, %esp
          push $0
          call exit
  ```

  - 两种链接
    - **静态链接**: 直接链接为一个巨大的可执行文件.
    - **动态链接**: 在程序运行时, 由os调用动态链接库. 动态链接库可共享. 
  - 动态库文件: linux 中标准 c 动态库 `libc.so.x` x代表版本
  - GNU 参数 `-lx` 表示链接 `/lib/libx.so` 文件, 如上, 这里的 x 为 c
  - 实现动态链接还需要加载动态连接程序: linux中是 `ld-linux.so.2`, GNU 中用法为加 `-dynamic-linker` (无法运行)

    ```bash
    $ ld -dynamic-linker /lib/ld-linux.so.2 -o cpuid2 -lc cpuid2.o
    $ ./cpuid2
    The processor Vendor ID is 'GenuineIntel'
    ```

  - 使用 gcc 则更简单, 但需要将 `_start` 改为 `main` (无法运行)

    ```asm
    $ gcc -o cpuid2 cpuid2.s
    $ ./cpuid2
    The processor Vendor ID is ‘GenuineIntel’
    ```

## 汇编程序设计基础

### 数据

- 表示符号:
  - `%` (AT&T) 寄存器前
  - `$` (AT&T) 立即数和静态标签(下面data段中)
- 定义: bss段, data段
  - data段:
    - 需要: 标签(数据第一个字节位置), 数据长度(数据类型), 默认值(一个或多个)
    - 一个速查表:

      | Directive   | Data                | Type |
      | ----------  |------               |------|
      |.ascii       | Text                |**string**
      |.asciz       |Null-terminated text | **string**
      |.byte        | Byte                |**value**
      |.double      |Double-precision floating-point | **number**
      |.float       | Single-precision floating-point | **number**
      |.int         |32-bit integer       | **number**
      |.long        |32-bit integer       | **number** (same as .int)
      |.octa        |16-byte integer      | **number**
      |.quad        |8-byte integer       | **number**
      |.single      |Single-precision floating-point | **number** (same as .float)
  - **定义静态符号 `.equ`**, 在data段, 声明后不可更改
  - bss段
    - 两种: `.lcomm`, `.comm`, 
    - `.lcomm` 特殊: 存储的数据不会被外部代码访问
    - 在 [rCore lab](../../rCore-Tutorial/os/src/entry.asm) 中, `.space` 是一个伪指令:

      ```asm
      # 回忆：bss 段是 ELF 文件中只记录长度，而全部初始化为 0 的一段内存空间
      # 这里声明字段 .bss.stack 作为操作系统启动时的栈
      .section .bss.stack
      .global boot_stack
      boot_stack:
          # 16K 启动栈大小
          .space 4096 * 16
          .global boot_stack_top
      boot_stack_top:
          # 栈结尾
      ```
  
- 传送数据 
  - `mov`
    - `movx source, destination`
    - `movx` 中的 x 表示字长: 
      - `l` 32 位, `w`: 16位, `b` 8位
      - *特殊的 `s` 用于把字符串移动
    - 内存与寄存器之间的

      ```asm
      values:
        .int 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60
      ```

      - `base_address(offset_address, index, size)` 变址
        - `movl values(, %edi, 4), %eax` 取 20
      - `movl %edx, 4(%edi)` 间接
  - `cmov`: 条件传送
  - 交换指令...
- 堆栈

### 控制流
