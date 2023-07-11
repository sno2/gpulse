fn main() {
    var i: i32 = 0;
    loop {
        if i >= 4 { break; }
        if i % 2 == 0 { continue; } // <3>

        let step: i32 = 2;

        continuing {
            i = i + step;
        }
    }
}
