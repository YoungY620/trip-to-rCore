# :wink: Report 2

## Dynamic mem allocation

- 一些问题
  - [内存映射](lab2/os/src/memory/config.rs), 偏移量值来源?

    ```Rust
    /// 内核使用线性映射的偏移量
    pub const KERNEL_MAP_OFFSET: usize = 0xffff_ffff_0000_0000;
    ```

    - **sv39 分页模式**中规定 **64 位的虚拟地址中, 高 25 位([63, 39]), 必须与第 38 位相同**, 否则认定地址无效. 
      然后, MMU 取出低 39 位, 尝试转化为 56 位物理地址( 56 位?)

      [出处](https://rcore-os.github.io/rCore-Tutorial-Book-v3/chapter4/3sv39-implementation-1.html#id3)
  - ELF (可执行链接文件) 中个字段的含义?
  - 实验题二:
    - [线段树](https://www.cnblogs.com/AC-King/p/7789013.html)
- 对于本实验分配内存的理解:
  - 整体思路: 如 C 中的`malloc/free` , 这里实现两个函数: `alloc/dealloc`
  - 首先是利用 buddy_system 为操作系统运行提供内存管理
  
  > `#[global_allocator]` 是一个特殊的标记，表示替换该程序的全局堆内存分配器。在嵌入式系统开发中，经常需要通过这种方式实现并使用 一个自定义的 堆分配器。 因此，对于这个OS本身这个程序，堆空间是由这样一个简陋的 buddy_system 维护的。[link](lab2/os/src/memory/heap.rs#L19)

  ```rust
  /// 堆，动态内存分配器
  ///
  /// ### `#[global_allocator]`
  /// [`LockedHeap`] 实现了 [`alloc::alloc::GlobalAlloc`] trait，
  /// 可以为全局需要用到堆的地方分配空间。例如 `Box` `Arc` 等
  #[global_allocator]
  static HEAP: LockedHeap = LockedHeap::empty();
  ```
  
  - 自底向上分析, 被分配的一段连续内存, 再rust中使用数组来表示, 由于数组的定义便是一段连续的内存. 这个数组用 **静态生命周期泛型** `'static` 修饰, 在程序的整个生命周期均有效: [见 address.rs](lab2/os/src/memory/address.rs)

    ```rust
    impl VirtualPageNumber {
        /// 从虚拟地址取得页面
        pub fn deref(self) -> &'static mut [u8; PAGE_SIZE] {
            VirtualAddress::from(self).deref()
        }
    }
    impl PhysicalPageNumber {
        /// 从物理地址经过线性映射取得页面
        pub fn deref_kernel(self) -> &'static mut [u8; PAGE_SIZE] {
            PhysicalAddress::from(self).deref_kernel()
        }
    }
    ```

  - 一般内存被分为多个 **大小固定** 的 **帧** (Frame), 如上所示, 帧大小为 `PAGE_SIZE` , [定义在 config.rs](lab2/os/src/memory/config.rs):

    ```rust
    /// 页 / 帧大小，必须是 2^n
    pub const PAGE_SIZE: usize = 4096;
    ```

  - 为了利用 Rust 本身的内存回收机制来回收之前使用 `alloc` 分配的现在不需要的内存 (out of scale), 将这块数组用 `FrameTracker` 封装, 并重写 (实现) 了 Drop trait  [frame_tracker.rs](lab2/os/src/memory/frame/frame_tracker.rs)

    ```rust
    /// 帧在释放时会放回 [`static@FRAME_ALLOCATOR`] 的空闲链表中
    impl Drop for FrameTracker {
        fn drop(&mut self) {
            FRAME_ALLOCATOR.lock().dealloc(self);
        }
    }
    ```

  - 同时 `FrameTracker` 还实现了 `DerefMut` 和 `Deref` 重载解引用运算符 `*` . 可以实现类似指针的操作 [说明](http://bean-li.github.io/Deref-DerefMut/) **(在哪用到了?)**
  - 如何判断哪些地址的内存空闲?
    - 利用 `algorithm` 中的分配算法 ([线段树](lab2/os/src/algorithm/src/allocator/segment_tree_allocator.rs), [栈](lab2/os/src/algorithm/src/allocator/stacked_allocator.rs)) 得到空闲的内存地址
  - 如何访问分配的空间?
    - 各种内存地址原本是 `usize` , 这里进行了[封装](lab2/os/src/memory/address.rs), 同时实现 `DerefMut` 和 `Deref` , 通过**裸指针**访问. rust中, 裸指针访问是不检查是否越界和数组是否声明的

      ```rust
      /// 从虚拟地址取得某类型的 &mut 引用
      pub fn deref<T>(self) -> &'static mut T {
          unsafe { &mut *(self.0 as *mut T) }
      }
      ```

  - 最终, 可以完整实现一开始说的两个方法: `alloc/dealloc`
    - 在程序的全局, 有一个 `FRAME_ALLOCATOR` ([位于allocator.rs](lab2/os/src/memory/frame/allocator.rs)) 自动初始化, 本质是加了互斥锁的结构体 `FrameAllocator` ([位于allocator.rs](lab2/os/src/memory/frame/allocator.rs))
    - `FrameAllocator` 装载了一个提供分配算法支持的 [`Allocator`](lab2/os/src/algorithm/src/allocator/mod.rs)和可供分配的内存范围
    - `alloc` : 算法 allocator 返回内存地址
    - `dealloc` : 内存帧 `FrameTracker` 被 drop 的时候自动调用
