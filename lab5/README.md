# :flags: report 5

## 设备树

- RISC-V 中， 固件 openSBI 负责扫描了外设. 返回了两个值:
  - `_hart_id` : 硬件线程，可以理解为执行的 CPU 核(?
  - `dtb_pa` : 就是设备树的树根, 从他开始遍历设备 [device_tree.rs](lab5/os/src/devices/device_tree.rs), `dtb_va` 是对应的虚拟地址:

    ```rust
    /// 遍历设备树并初始化设备
    pub fn init(dtb_va: VirtualAddress) {
        let header = unsafe { &*(dtb_va.0 as *const DtbHeader) };
        // from_be 是大小端序的转换（from big endian）
        let magic = u32::from_be(header.magic);
        if magic == DEVICE_TREE_MAGIC {
            let size = u32::from_be(header.size);
            // 拷贝数据，加载并遍历
            let data = unsafe { slice::from_raw_parts(dtb_va.0 as *const u8, size as usize) };
            if let Ok(dt) = DeviceTree::load(data) {
                walk(&dt.root);
            }
        }
    }
    ```

## 外设的探求, 使用

- **virtio** ([Virtual I/O](https://www.ozlabs.org/~rusty/virtio-spec/virtio-paper.pdf))
- 一个基于半虚拟化的通用设备抽象
- `MMIO` **内存映射读写** :
  - `reg` 段可能存放详细信息的存放位置, 如 (0x10000000 - 0x10010000)
  - 而: 我们内存的空间仅为0x80000000 到 0x88000000
  - `reg` 中的这段地址就属于 MMIO: **将外设映射为内存的一部分**
- **DMA 技术**:
  - 需要一段 **连续的** 内存空间
  - DMA 不会经过 CPU 的 MMU 技术 (内存管理单元)
- `virtio_drivers` 库, 帮助遍历, 探查外设信息
  - `virtio_mmio.rs` 中的函数是他要是用的 (DMA 技术)

## (块)设备抽象

- [Driver](lab5/os/src/devices/driver.rs): 
  - 对硬件读写行为的抽象
- 块设备 [BlockDevice](../os_kernel_lab/os/src/drivers/block/mod.rs)
  - 一个具体设备的抽象? 引用一个驱动
- virtio-blk 块设备驱动[VirtIOBlkDriver](lab5/os/src/devices/block/virtio_blk.rs)
  - 实现了驱动, 是专门为块设备抽象的派生

## 文件系统

- sfs

## 思路

- 打包一个硬盘镜像. 标准程序中使用`rcore-fs-fuse` 工具打包到 `/user/build/`. 在 MakeFile 中标记:

  ```makefile
  USER_DIR    := ../user
  USER_BUILD  := $(USER_DIR)/build
  IMG_FILE    := $(USER_BUILD)/disk.img
  ```

  QEMU 模拟器把他当作外设挂载到系统上 (注意 `IMG_FILE`), 使用 virtio 协议 `-device virtio-blk-device,drive=sfs`:

  ```makefile
  # 运行 QEMU
  qemu: build
      @qemu-system-riscv64 \
          -machine virt \
          -nographic \
          -bios default \
          -device loader,file=$(BIN_FILE),addr=0x80200000 \
          -drive file=$(IMG_FILE),format=qcow2,id=sfs \
          -device virtio-blk-device,drive=sfs
  ```

  这之后才是操作系统的范畴

## 思考题

- [为什么物理地址到虚拟地址转换直接线性映射，而虚拟地址到物理地址却要查表？](https://rcore-os.github.io/rCore-Tutorial-deploy/docs/lab-5/guide/part-2.html)
  - 出内核栈之外的内存都是线性映射的, 而内核栈是按帧映射的
  - 涉及到什么时候调用 `virtio_virt_to_phys` 和 `virtio_phys_to_virt` ?
