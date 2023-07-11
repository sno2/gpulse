fn main() {
    const c = 2;
    var a: i32;
    let x: i32 = generateValue();
    switch x {
  		case 0: {
            a = 1;
        }
  		case 1, c {       // Const-expression can be used in case selectors
            a = 3;
  		}
  		case 3, default { // The default keyword can be used with other clauses
            a = 4;
  		}
	}
}
