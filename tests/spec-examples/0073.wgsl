var<private> x : i32 = 0;

fn f1(p1 : ptr<function, i32>, p2 : ptr<function, i32>) {
  *p1 = *p2;
}

fn f2(p1 : ptr<function, i32>, p2 : ptr<function, i32>) {
  f1(p1, p2);
}

fn f3() {
  var a : i32 = 0;
  f2(&a, &a);  // Invalid. Cannot pass two pointer parameters
               // with the same root identifier when one or
               // more are written (even by a subfunction).
}

fn f4(p1 : ptr<function, i32>, p2 : ptr<function, i32>) -> i32 {
  return *p1 + *p2;
}

fn f5() {
  var a : i32 = 0;
  let b = f4(&a, &a); // Valid. p1 and p2 in f4 are both only read.
}

fn f6(p : ptr<private, i32>) {
  x = *p;
}

fn f7(p : ptr<private, i32>) -> i32 {
  return x + *p;
}

fn f8() {
  let a = f6(&x); // Invalid. x is written as a global variable and
                  // read as a parameter.
  let b = f7(&x); // Valid. x is only read as both a parameter and
                  // a variable.
}
