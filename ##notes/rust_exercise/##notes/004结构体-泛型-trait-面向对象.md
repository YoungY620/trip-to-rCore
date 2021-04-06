# 面向对象

## 语法基础

### 结构体

- 定义 `struct`
- 结构体数据的所有权:
  - 

### 泛型

- 三类 : **函数, 结构体, 方法**, 另外特殊的: **生命周期**
- **函数中**:

    ```rust
    fn largest<T>(list: &[T]) -> T {    
    ```

  - 在使用过程中, 需要规定泛型 `T` 实现了某种 trait , 比如 "可比较" 等
- **结构体中**: 定义中标注, 自动识别一致性

    ```rust
    struct PointDiff<T, U> {
        x: T,
        y: U,
    }
    struct PointSame<T> {
        x: T,
        y: T,
    }
    fn main() {
        let int_and_float = PointSame { x: 5, y: 1.0 };// error!
        let both_float = PointSame { x: 1.0, y: 4.0 };
        let float_and_int = PointDiff { x: 5.0, y: 4 };
    }
    ```

- **方法实现中** (`impl` 中): 在impl中声明, 否则不知道 `T, U` 是否为一般类. 
  - 这一设计允许了只对泛型为某一类型的 `struct` 实现方法

  ```rust
    struct Point<T, U> {
        x: T,
        y: U,
    }

    // 只对 U 实现了 Copy 的 Point 实现 mixup 方法.
    impl<T, U: Copy> Point<T, U> {
        fn mixup<V, W>(self, other: Point<V, W>) -> Point<T, W> {
            Point {
                x: self.x,
                y: other.y,
            }
        }
    }
  ```

### trait

- `trait` : 功能类似于接口
  - 结构体 `struct` 实现(多个) `trait` (类似接口):

    ```rust
    impl Summary for Tweet {
    ```

  - `trait` 自身也可以提供默认实现
- 泛型实现 `trait` :
  - `impl trait` 语法
  - Trait Bound ( `:` ) 语法

    ```rust
    pub fn notify<T: Summary + Display>(item: T) {
    ```

  - 也可以用 `where` 语句:

    ```rust
    fn some_function<T, U>(t: T, u: U) -> i32
        where T: Display + Clone,
              U: Clone + Debug
    {
    ```
  
  - 

## Encapsulation 封装

- 定义属性和方法

    ```rust
    pub struct Obj{
        name: String,
        num: i32,
    }    
    ```

    ```rust
    impl Obj{
        pub fn add(&mut self, value: i32) {
            self.list.push(value);
            self.update_average();
        }
    }
    ```

## 实现

- 
