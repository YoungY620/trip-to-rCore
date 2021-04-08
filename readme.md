# :cake:操作系统 rCore 之旅

## About

rCore 及相关实验、复现、笔记，自用+分享+纪念

## 对 ucore-Tutorial README 的补充

[仓库原链接](https://github.com/DeathWish5/ucore-Tutorial)

对标 [rCore-Tutorial-v3](https://github.com/rcore-os/rCore-Tutorial-v3/) 的 C 版本代码。

主要参考 [xv6-riscv](https://github.com/mit-pdos/xv6-riscv)。

运行方式：

* 在root(`sudo -s指令`)用户下按照[文档](https://github.com/deathWish5/ucore-Tutorial-Book/blob/HEAD/lab0/%E5%AE%9E%E9%AA%8C%E7%8E%AF%E5%A2%83%E9%85%8D%E7%BD%AE.md)配置环境
* 于 user 目录 make, 得到用户文件(user/target/*.bin)
* 于 kernel 目录 make run，运行 os
