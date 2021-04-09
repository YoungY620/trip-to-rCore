# :last_quarter_moon_with_face:report 4

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