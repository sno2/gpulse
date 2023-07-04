// array<f32,8> and array<i32,8> are different types:
// different element types
var<private> a: array<f32,8>;
var<private> b: array<i32,8>;
var<private> c: array<i32,8u>;  // array<i32,8> and array<i32,8u> are the same type

const width = 8;
const height = 8;

// array<i32,8>, array<i32,8u>, and array<i32,width> are the same type.
// Their element counts evaluate to 8.
var<private> d: array<i32,width>;

// array<i32,height> and array<i32,width> are the same type.
var<private> e: array<i32,width>;
var<private> f: array<i32,height>;
