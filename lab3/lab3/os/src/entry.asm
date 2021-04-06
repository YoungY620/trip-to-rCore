# 操作系统启动时所需的指令以及字段
#
# 我们在 linker.ld 中将程序入口设置为了 _start，因此在这里我们将填充这个标签
# 它将会执行一些必要操作，然后跳转至我们用 rust 编写的入口函数
#
# 关于 RISC-V 下的汇编语言，可以参考 https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md
# %hi 表示取 [12,32) 位，%lo 表示取 [0,12) 位

    .section .text.entry
    .globl _start
# 目前 _start 的功能：将预留的栈空间写入 $sp，然后跳转至 rust_main
_start:
    # 计算 boot_page_table 的物理页号, 即计算stap中存的页表基址
    # 虚拟地址加上这个值, 变为一级页表中的页表项的物理地址
    # `%hi(sym)`表示 sym 的高 20 位
    # `lui`     一个转移指令, 和 %hi 一起使用, 表示 转移高 20 位到 t0
    # `t0`:     temporary register 0
    lui t0, %hi(boot_page_table)    
    li t1, 0xffffffff00000000   # li 加载立即数
    sub t0, t0, t1              # sub t0=t0-t1
    srli t0, t0, 12             # 逻辑右移 12 位
    # 8 << 60 是 satp 中使用 Sv39 模式的记号
    # (`<<` 应该是左移, 因为 satp 左侧第一位是标识sv39模式的)
    li t1, (8 << 60)
    or t0, t0, t1               # '与'位运算
    # 写入 satp 并更新 TLB
    csrw satp, t0               # 写 CRS 寄存器
    sfence.vma

    # 加载栈地址
    lui sp, %hi(boot_stack_top)
    addi sp, sp, %lo(boot_stack_top)
    # 跳转至 rust_main
    lui t0, %hi(rust_main)
    addi t0, t0, %lo(rust_main)
    jr t0

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

    # 初始内核映射所用的页表
    .section .data
    .align 12
boot_page_table:
    # .quad 表示一个八字节
    # 这里表示, 这一行就占了一个八字节, 用 0 填充
    # 这和高级语言的思维方式不一样
    .quad 0
    .quad 0
    # 第 2 项：0x8000_0000 -> 0x8000_0000，0xcf 表示 VRWXAD 均为 1
    # 回忆: 10 位之前为地址
    # 左移 10 位, 因为一个页表项的低 10 位为状态位, 详见readme
    .quad (0x80000 << 10) | 0xcf
    # 用 0 占位 507 个八字节, 所以下一行就是第 510 个八字节了
    .zero 507 * 8
    # 第 510 项：0xffff_ffff_8000_0000 -> 0x8000_0000，0xcf 表示 VRWXAD 均为 1
    .quad (0x80000 << 10) | 0xcf
    .quad 0