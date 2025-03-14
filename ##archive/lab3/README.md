# :cake:report 3

## 从虚拟地址到物理地址

- 一些基本概念
  - 这里使用 **sv39模式** 作为页表实现
    - 物理 56 位空间, 虚拟 39 位空间
    - 对 [64-38] 位的特殊规定
  - **页表项** : 64 位
    - [53-10] 位物理页号 + [9-0] 控制位
    - `xwr` 位: 特殊全为0时, 物理页号段表示下一级页表项的物理地址, 若不全为 0, 表示真实的物理页号 (定义**大页**)
  - **多级页表**
    - 39 位(有效)虚拟地址 = 9位页表索引 * 3 + 12 位offset(物理页内索引)
    - 过程:
      - 根据**页表基址**找到**页表**
      - 根据**页表索引**找到**页表项**
      - 根据**页表项**找到**下一级**页表的**基址**
      - 再根据 39 位虚拟地址中记录的的**下一级也表索引**找到**下一级页表项**
      - ...
  - 那么, 第一个**页表基址**在哪呢? **页表寄存器 `satp`**
    - `MODE` 位表示使用哪种页表实现, 8 表示sv39
    - `ASID` 跟进程有关
  - 快表
    - 属于计算机组成原理, 但有相关设置
    - 修改 `satp` 后 (映射方式改变) 和修改某一页表项后, TLB 的内容就失效了, 要刷新
    - `sfence.vma` 汇编指令用于刷新

## 修改内核

- 做了什么?
  - 从直接使用物理地址, 转变为使用虚拟地址
- 怎样做?
  - 准备: 在 [linker_script](lab3/os/src/linker.ld) 修改, 对齐 4KB 虚拟页
  - 准备: 修改 [memory/config.rs](lab3/os/src/memory/config.rs) 支持虚拟映射
  - 之前, `stap` 的 `mode` 字段是 `bare` (直访物理地址) 现在改为 `sv39` 模式, 这样 CPU 寻址方式变化, 会寻找映射表来访问

可能有疑问：内核程序如何左脚踩右脚自己设置自己使用自己实现的页表呢？实际上只需要向cpu通过satp寄存器说明页表的地址以及寻址模式，然后cpu就会顺着根页表通过虚拟地址访存的。

为了实现内核程序从直接使用物理地址转变为使用虚拟地址，需要进行以下几个关键步骤：

1. **修改链接脚本**：在 `linker.ld` 中，确保内核的各个段（如 `.text`、`.rodata`、`.data`、`.bss`）都对齐到 4KB 的边界。这是因为虚拟内存管理通常以页为单位进行管理，而页的大小通常是 4KB。

   ```ld
   /* 在 SECTIONS 中对齐各个段 */
   . = ALIGN(4K);
   text_start = .;
   .text : {
       *(.text.entry)
       *(.text .text.*)
   }
   . = ALIGN(4K);
   rodata_start = .;
   .rodata : {
       *(.rodata .rodata.*)
   }
   . = ALIGN(4K);
   data_start = .;
   .data : {
       *(.data .data.*)
   }
   . = ALIGN(4K);
   bss_start = .;
   .bss : {
       *(.sbss .bss .bss.*)
   }
   ```

2. **修改内存配置**：在 `config.rs` 中，定义内核的虚拟地址映射偏移量，并使用 `lazy_static!` 宏来定义内核代码结束的虚拟地址。

   ```rust
   /// 内核使用线性映射的偏移量
   pub const KERNEL_MAP_OFFSET: usize = 0xffff_ffff_0000_0000;

   lazy_static! {
       /// 内核代码结束的地址，即可以用来分配的内存起始地址
       pub static ref KERNEL_END_ADDRESS: VirtualAddress = VirtualAddress(kernel_end as usize);
   }
   ```

3. **设置页表模式**：在内核启动时，设置 CPU 的页表模式为 `sv39`，这需要在汇编代码中配置 `satp` 寄存器。`satp` 寄存器的 `MODE` 字段设置为 `8` 表示使用 `sv39` 模式。

   ```asm
   # 设置 satp 寄存器以启用 sv39 模式
   li t1, (8 << 60)
   or t0, t0, t1
   csrw satp, t0
   sfence.vma
   ```

4. **实现页表和映射**：在内核中实现页表和映射的逻辑，包括页表项 `PageTableEntry` 和页表 `PageTable` 的封装，以及映射 `Mapping` 的实现。这些结构和方法负责将虚拟地址映射到物理地址。

5. **内核重映射**：在内核初始化过程中，使用 `MappingSet` 类来自动化内核的重定向。这涉及到将内核的虚拟地址空间映射到物理地址空间。

通过这些步骤，内核程序可以从直接使用物理地址转变为使用虚拟地址，从而利用虚拟内存管理的优势，如内存保护和地址空间隔离。


## 实现页表和映射

- 面向对象的封装:
  - 页表项 `PageTableEntry` , 封装 `39` 位 `usize`
  - 页表 `PageTable` , 封装了一个512个页表项的集合 (正好4kb = 8b*512),
    - 与 `FrameTricker` 同理, 对应的封装用于索引的 `PageTableTricker`
  - 映射 `Mapping` , 抽象了属于某一 **线程(还是进程?)** 的虚拟空间中, 虚拟页到物理页的 (多级) 映射过程, 因此包括了多级页表, 虚拟页号与物理页帧之间的映射和 `map` 方法.
  - 另外, `Segment` 抽象了一段连续的内存, 可以对应课本中的段.  段本身**不关心分页**的问题, 因此在按页映射过程中, 会存在**内存对齐**的问题
  - 最后, `MappingSet` 抽象了一个进程(线程?) 对应的所有内存信息, 因此它包含了该进程使用的所有 `Segment` 和 映射 `Mapping`.
  - (要是有个类图uml就好了...)
  
## 内核重映射

- 这一部分实际是上一节的一个应用, 因为内核就是一个初始进程. 但这部分被写进了 `MappingSet` 以实现自动化的内核重定向
- 而之前汇编代码中的 `boot_page_table` 只是这些操作的准备

## 再谈机器通电过程

- 一个问题: 如何理解汇编代码中寄存器 `satp` 页表基址段的计算过程, 为什么要减去立即数 `0xffffffff00000000` :

  ```asm
  # 通过线性映射关系计算 boot_page_table 的物理页号
  lui t0, %hi(boot_page_table)
  li t1, 0xffffffff00000000
  sub t0, t0, t1
  srli t0, t0, 12
  # 8 << 60 是 satp 中使用 Sv39 模式的记号
  li t1, (8 << 60)
  or t0, t0, t1
  # 写入 satp 并更新 TLB
  csrw satp, t0
  sfence.vma
  ```

  - 在 `linker.ld` 中规定了代码的起始位置为高位虚拟地址空间, 因此对于该可执行文件 `elf` 来说, 使用的地址就是虚拟地址. 可以通过查看 `rust-objdump` 反汇编的汇编代码查看, 代码的地址均是高地址.
  - 因此, `boot_page_table` 是一个虚拟地址, 减去虚拟地址基址才是物理地址
  - 而对于 cpu 中的 pc 寄存器来说, 刚插电时, 固件 `OpenSBI` 先运行, 完成开机流程后指针跳到内核起始的**物理**地址, 然后按照计算机组成原理中讲的, pc 累加读取指令, 其值始终是物理地址
  - 直到执行到 `jr t0`, pc 寄存器被操作系统程序赋予 `rust_main` 标签值, 和 `boot_page_table` 一样, 这个值是一个虚拟地址, 从这里开始, pc 中的值才是虚拟地址.
  - 这也是为什么要在页表中加上 `0x8000_0000` 到 `0x8000_0000` 的映射: 当执行 `sfence.vma` 刷新快表后, CPU 的的寻址方式变为 sv39 映射方式, 但直到 `jr t0` 时 pc 的值才能使用虚拟地址
  - 初始页表时简易的大页页表, 1G 的大页足够完成内核重映射并替换掉这个错误的页表
  - 另外, 初始页表中的另一项: 第 510 项是用来映射 rust_main 地址的
