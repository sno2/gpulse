fn bar(p : ptr<function, f32>) {
}

fn baz(p : ptr<private, i32>) {
}

fn bar2(p : ptr<function, f32>) {
  let a = &*&*(p);

  bar(p); // Valid
  bar(a); // Valid
}

struct S {
  x : i32
}

var usable_priv : i32;
var unusable_priv : array<i32, 4>;
fn foo() {
  var usable_func : f32;
  var unusable_func : S;

  let a_priv = &usable_priv;
  let b_priv = a_priv;
  let c_priv = &*&usable_priv;
  let d_priv = &(unusable_priv.x);
  let e_priv = d_priv;

  let a_func = &usable_func;
  let b_func = &unusable_func;
  let c_func = &(*b_func)[0];
  let d_func = c_func;
  let e_func = &*a_func;

  baz(&usable_priv); // Valid, address-of a variable.
  baz(a_priv);       // Valid, effectively address-of a variable.
  baz(b_priv);       // Valid, effectively address-of a variable.
  baz(c_priv);       // Valid, effectively address-of a variable.
  baz(d_priv);       // Invalid, memory view has changed.
  baz(e_priv);       // Invalid, memory view has changed.

  bar(&usable_func); // Valid, address-of a variable.
  bar(c_func);       // Invalid, memory view has changed.
  bar(d_func);       // Invalid, memory view has changed.
  bar(e_func);       // Valid, effectively address-of a variable.
}
