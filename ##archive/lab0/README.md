# :100: Report

## Tool Prep.

### GCC

建议始终加上`-Wall`参数, 输出常见错误、警告

### gdb

使用gcc编译，加上`-g`参数:

```Bash
gcc -Wall gdb_test.c -o gdb_test -g
```

## 剔除环境依赖

- **堆栈展开**: 发生错误时, caller调用栈逐层回溯
- Rust是一种 **运行时系统** : main函数并不是程序执行的第一个函数. rust入口点是 `start` **语义项**标记的函数. 重写整个 `crt0` 入口点:
  - Rust 会先跳到C语言运行环境中的 `crt0` 准备环境. 因此这里是 `extern "C"`
  - 禁用函数**编译时**的 **名称重整(name mangling)** : 编译后名称不变, 而非经过 **散列化** 等操作得出的函数名.
  
  ```Rust
  #[no_mangle]
  pub extern "C" fn _start() -> ! {
  }
  ```

- **目标三元组（Target Triple）** : 为描述系统环境, `rustc --version --verbose`

    ```Bash
    host: x86_64-unknown-linux-gnu
    ```

  - `<arch><sub>-<vendor>-<sys>-<abi>` : CPU 架构 x86_64、供应商 unknown、操作系统 linux 和二进制接口 gnu

## 调整内存布局

- **链接脚本**：在未设置虚拟硬件时, 调整代码在内存中的位置? 真实效果是什么?
  - 根据链接脚本编译所有内核代码

## 重写入口点

- 这一章是: 调整代码特权级, 运行操作系统级别的指令
- 机器真正第一条指令: bootloader, openSBI充当
- **RISC-V 特权级** : 
  - 系统层次:
    - ABI/AEE -- SBI/SEE
    - ABI (Application Binary Interface)
- **固件** : risc-v 中的OpenSBI

## 整理一下通电后的流程

- 这节主要讲了通电后的过程
- 准备: 首先根据链接脚本编译内核代码, 脚本规定了汇编之后各段代码的位置, 以及执行入口 label.
- 通电后, 首先运行bootloader: 内外设检测. 这里的bootloader实现为OpenSBI, opensbi将特权级转为内核态, 跳转到固定位置 `0x80200000` 开始执行. 这也是为什么要调整内存布局
  - 查看生成的 elf 可执行文件:

    ```bash
    rust-objdump target/riscv64imac-unknown-none-elf/debug/os -x --arch-name=riscv64 >> mem.txt # redirection
    ```

  - 查看反汇编代码, 可以看到_start标签正是位于 `0x80200000`:

    ```bash
    rust-objdump target/riscv64imac-unknown-none-elf/debug/os -d --arch-name=riscv64 >> dasm.txt
    ```

- 之后 `_start` 跳转到rust_main, 开始 rust 代码.
