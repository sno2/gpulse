fn main() {
    var a: i32 = 2;
    var i: i32 = 0;
    loop {
        let step: i32 = 1;

        if i % 2 == 0 { continue; }

        a = a * 2;

        continuing {
            i = i + step;
			break if i >= 4;
		}
	}
}
