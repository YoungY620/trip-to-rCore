# :last_quarter_moon_with_face:report 4

> 实验 4 怎么这么难啊。。。

## 进程与线程

- 程序 (Program) 到进程 (Process)
  - 为每个进程分配运行栈
- 进程与线程
  - 将进程运行的动态特性抽离出来为**线程**
  - 线程共享内存空间, 即使有独立的栈

### 抽象

- 线程的抽象
  - 根本 : 执行的调度单位
    - 线程id: 系统调用
    - **运行栈**
    - **运行 context** : 线程不执行时
      - **与中断处理 context 不同**
    - 所属进程
- 进程的抽象
  - 资源分配的单位
    - 用户态标识
    - **访存空间**
  - 同进程中的每个线程虽然有独立的栈, 但都是共享一块内存空间 (具体: 共享一个 `MemorySet`), 进程负责为下属的线程分配空间:

    ```rust
    pub fn alloc_page_range(
        &self,
        size: usize,
        flags: Flags,
    ) -> MemoryResult<Range<VirtualAddress>> {
        // ...... //
        // 返回地址区间（使用参数 size，而非向上取整的 alloc_size）
        Ok(Range::from(range.start..(range.start + size)))
    }
    ```

- 处理器
  - 对进程池, 线程管理的封装 (尤其是中断当前进程等)
- **存疑**:
  - 内核栈?
  - LOCK? :

    ```rust
    lazy_static! {
        /// 全局的 [`Processor`]
        pub static ref PROCESSOR: Lock<Processor> = Lock::new(Processor::default());
    }
    ```

## 暂记思路

- 一开始插电, `openSBI` 将 `pc` 指向内核第一条代码, 现在运行的是一个操作系统元初进程. (叫不叫进程?)
- 第一步, 得到全局静态的, 懒加载的处理器实例 `PROCESSOR`

  ```rust
  let mut processor = PROCESSOR.lock();
  ```

- 在这个处理器实例中, 开了一个内核进程:

  ```rust
  // 创建一个内核进程
  let kernel_process = Process::new_kernel().unwrap();
  ```

  `new_kernel()` 进行了内核重映射, 和上个实验 (lab 3) 一样, 替换掉了简陋而错误的内核栈
- 注册了几个内核线程, 准备运行
  - 注册一个线程需要: 所属的进程, 入口程序, 程序参数
- 运行:
  - 第一个线程: 通过调度获得 `context`

    ```rust
    // 获取第一个线程的 Context, 
    // `prepare_next_thread()` 内部是调用了调度器
    let context = PROCESSOR.lock().prepare_next_thread();
    ```

  - 启动: 调用汇编标签 `__restore`, 入参为上面变量 `context` 的地址, **而这个地址正是我们实现的内核栈 ([kernel_stack.rs](lab4/os/src/process/kernel_stack.rs)) 实例的栈顶**
    - 汇编代码 ([interru.asm](lab4/os/src/interrupt/interrupt.asm)):

      ```asm
      __restore:
          mv      sp, a0
          # 恢复 CSR
          # ......
          # 将内核栈地址写入 sscratch
          # ...... 略
          sret
      ```

      - `a0` 实际上是 [`/interrupt/handler.rs:handle_interrupt`](lab4/os/src/interrupt/handler.rs) 的返回值 
        - (`__interrupt` 标签下调用了 `handle_interrupt`, 在 `handle_interrupt` 之后顺次执行了 `__restore` 下的代码)
        - 寄存器 `a0` 的作用: return value or function argument 0
      - `__restore` 在两处被调用, 寄存器 `a0` 也有两种赋值情况.
        - 一处在普通的 interrupt 中, 返回原来的 context;
        - 另一处是在线程结束时, 返回新的 context
      - 初始, 寄存器 `sp`, `sscratch` 的值都为0, `sp` 在运行过程中被用作栈指针被不断赋值, 在 `__restore` 中被赋值, `sscratch` 为内核栈顶 (叫中断栈更合适, 因为他只是存了被挂起的线程上下文), `sp` 仍为栈指针
      - `sret` 之后, 进入用户态执行这个线程
  - 线程结束 (一种实现方式):
    - `context` 中 `ra` 寄存器保存线程结束时返回的地址
    - 写入了一个线程结束函数 `kernel_thread_exit()`:

      ```rust
      // 创建线程
      let thread = Thread::new(process, entry_point, arguments).unwrap();
      // 设置线程的返回地址为 kernel_thread_exit
      thread
          .as_ref()
          .inner()
          .context
          .as_mut()
          .unwrap()
          .set_ra(kernel_thread_exit as usize);
      ```

    - 发了一个普通 `ebreak`, 然后在 `handle_interrupt()` 中判断如果当前发 `ebreak` 的线程死了, 就准备下一个.
- 切换
  - 每个时钟中断

    ```rust
    /// 处理时钟中断
    fn supervisor_timer(context: &mut Context) -> *mut Context {
        timer::tick();
        PROCESSOR.lock().park_current_thread(context);
        PROCESSOR.lock().prepare_next_thread()
    }
    ```

- 休眠
  - 一个懒加载的休眠线程, 只做一件事不断休眠: `wfi`, 像个下夜老大爷

    ```rust
    lazy_static! {
        /// 空闲线程：当所有线程进入休眠时，切换到这个线程——它什么都不做，只会等待下一次中断
        static ref IDLE_THREAD: Arc<Thread> = Thread::new(
            Process::new_kernel().unwrap(),
            wait_for_interrupt as usize,
            None,
        ).unwrap();
    }

    /// 不断让 CPU 进入休眠等待下一次中断
    unsafe fn wait_for_interrupt() {
        loop {
            llvm_asm!("wfi" :::: "volatile");
        }
    }
    ```

  - 这个休眠守护线程的使用: 本身是静态全局的变量, 但本身并不被使用, 在 [Processor](lab4/os/src/process/processor.rs) 中调用时使用 `clone()` 赋值给 `current_thread`, 当 `current_thread` 被赋予新值时这个克隆的线程又被丢弃 (rust 垃圾处理特性, 自动调用 `drop()`):

    ```rust
    /// 激活下一个线程的 `Context` 
    pub fn prepare_next_thread(&mut self) -> *mut Context {
        // 向调度器询问下一个线程
        if let Some(next_thread) = self.scheduler.get_next() {
            // 准备下一个线程
            let context = next_thread.prepare();
            self.current_thread = Some(next_thread);
            context
        } else {
            // 没有活跃线程
            if self.sleeping_threads.is_empty() {
                // 也没有休眠线程，则退出
                panic!("all threads terminated, shutting down");
            } else {
                // 有休眠线程，则等待中断
                self.current_thread = Some(IDLE_THREAD.clone());
                IDLE_THREAD.prepare()
            }
        }
    }
    ```

## 实验题

- **线程切换之中，页表是何时切换的？页表的切换会不会影响程序 / 操作系统的运行？为什么？**
  - 在 `Thread::prepare()` 中, 调用父进程 `MemorySet` 的 `activate()` 刷新了页表
- (后两题还得实现stdin才能做)
