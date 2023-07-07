fn main() {
    var a: i32 = 2;
    var i: i32 = 0;
    loop {
        if i >= 4 { break; }

        let step: i32 = 1;

        i = i + step;
        if i % 2 == 0 { continue; }

        a = a * 2;
    }
}
