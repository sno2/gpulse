var a: i32 = 2;
var i: i32 = 0;
loop {
  if i >= 4 { break; }

  let step: i32 = 1;

  if i % 2 == 0 { continue; }

  a = a * 2;

  continuing {   // <2>
    i = i + step;
  }
}
