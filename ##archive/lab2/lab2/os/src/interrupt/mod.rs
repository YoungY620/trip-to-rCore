#![allow(dead_code)]
#![allow(unused_imports)]
//! 中断模块
//! 
//! 
mod handler;
mod context;
mod timer;

/// 初始化中断相关的子模块
/// 
/// - [`handler::init`]
/// - [`timer::init`]
pub fn init() {
    handler::init();
    timer::init();
    println!("mod interrupt initialized");
}