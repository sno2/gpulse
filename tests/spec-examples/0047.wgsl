fn main() {
    var a: i32 = 2;
    var i: i32 = 0;      // <1>
    loop {
        if i >= 4 { break; }

        a = a * 2;

        i++;
    }
}
