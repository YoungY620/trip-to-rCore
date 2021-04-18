#![no_std] // 移除标准库
#![feature(...)] // 开启一些不稳定的功能
#[global_allocator] // 使用库来实现动态内存分配
#[panic_handler]

mod sbi;
mod console;
mod panic;
