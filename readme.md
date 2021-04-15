# :sun_with_face: 操作系统 rCore 之旅

## :rocket: About

rCore 及相关实验、复现、笔记，自用

## rCore 标准代码运行方式补充

- 记录一些运行过程中的问题及解决
- 原仓库
  - [rCore-Tutorial](https://github.com/yuzhouwudiyyc/rCore-Tutorial)
  - [os_kernel_lab](https://github.com/yuzhouwudiyyc/os_kernel_lab)
- 报错:
  - 最终修改了报错中的 virtio-drivers 源码, 应该不是个好办法

    ```rust
    error[E0658]: use of unstable library feature 'renamed_spin_loop'
     --> /home/yy/.cargo/git/checkouts/virtio-drivers-4fdfaa862bcdc399/6c5c8e2/src/gpu.rs:4:5
      |
    4 | use core::hint::spin_loop;
      |     ^^^^^^^^^^^^^^^^^^^^^
      |
      = note: see issue #55002 <https://github.com/rust-lang/rust/issues/55002> for more information
      = help: add `#![feature(renamed_spin_loop)]` to the crate attributes to enable

    error[E0658]: use of unstable library feature 'renamed_spin_loop'
       --> /home/yy/.cargo/git/checkouts/virtio-drivers-4fdfaa862bcdc399/6c5c8e2/src/gpu.rs:158:13
        |
    158 |             spin_loop();
        |             ^^^^^^^^^
        |
        = note: see issue #55002 <https://github.com/rust-lang/rust/issues/55002> for more information
        = help: add `#![feature(renamed_spin_loop)]` to the crate attributes to enable

    error: aborting due to 2 previous errors

    For more information about this error, try `rustc --explain E0658`.
    error: could not compile `virtio-drivers`.

    To learn more, run the command again with --verbose.
    warning: build failed, waiting for other jobs to finish...
    error: build failed
    make: *** [Makefile:24: kernel] Error 101
    ```

- 提示:

    ```rust
      Compiling os v0.1.0 (/home/yy/os_labs/os_kernel_lab/os)
        Finished dev [unoptimized + debuginfo] target(s) in 21.98s
    qemu-system-riscv64: -drive file=../user/build/disk.img,format=qcow2,id=sfs: Could not open '../user/build/disk.img': No such file or directory
    make: *** [Makefile:40: qemu] Error 1
    ```
  
  - 需要先在 `/user` 目录下执行 `make build` 生成对应的镜像

## 对 ucore-Tutorial README 的补充

[仓库原链接](https://github.com/DeathWish5/ucore-Tutorial)

对标 [rCore-Tutorial-v3](https://github.com/rcore-os/rCore-Tutorial-v3/) 的 C 版本代码。

主要参考 [xv6-riscv](https://github.com/mit-pdos/xv6-riscv)。

运行方式：

- 在root(`sudo -s指令`)用户下按照[文档](https://github.com/deathWish5/ucore-Tutorial-Book/blob/HEAD/lab0/%E5%AE%9E%E9%AA%8C%E7%8E%AF%E5%A2%83%E9%85%8D%E7%BD%AE.md)配置环境
- 于 user 目录 make, 得到用户文件(user/target/*.bin)
- 于 kernel 目录 make run，运行 os
