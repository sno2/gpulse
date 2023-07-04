struct S {
  a : f32,
  b : u32,
  c : f32
}

@group(0) @binding(0)
var<storage> v : S;

fn foo() {
  let x = v.b; // Does not access memory locations for v.a or v.c.
}
