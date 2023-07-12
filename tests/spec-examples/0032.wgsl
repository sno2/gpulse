fn main() {
    var i: i32;         // Initial value is 0.  Not recommended style.
    loop {
        var twice: i32 = 2 * i;   // Re-evaluated each iteration.
        i++;
        if i == 5 { break; }
    }
}
