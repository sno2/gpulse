fn main() {
	var a: i32 = 2;
	{ // Introduce new scope for loop variable i
		var i: i32 = 0;
		loop {
			if !(i < 4) {
				break;
			}

			if a == 0 {
				continue;
			}
			a = a + 2;

			continuing {
				i++;
			}
		}
	}
}