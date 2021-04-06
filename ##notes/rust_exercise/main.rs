fn main() {
    let array: [i32; 3] = [1, 2, 3];

    println!("{:?}", array); // [1, 2, 3]

    let ptr: *const i32 = &array as *const [i32; 3] as *const i32;

    unsafe {
        let a = ((ptr as usize) + 0) as *mut i32;

        let a2: &mut i32 = &mut *a;
        *a2 = 123;

        let b = ((ptr as usize) + 4) as *mut i32;

        let b2: &mut i32 = &mut *b;
        *b2 = 456;

        let c = ((ptr as usize) + 8) as *mut i32;

        let c2: &mut i32 = &mut *c;
        *c2 = 789;

        let d = ((ptr as usize) + 12) as *mut i32;

        let d2: &mut i32 = &mut *d;
        println!("before: {}",*d2);
        *d2 = 912;
        println!("after: {}",*d2);
    }

    println!("{:?}", array); // [123, 456, 789]
}