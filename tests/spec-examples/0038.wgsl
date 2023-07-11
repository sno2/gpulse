var a: vec3<f32> = vec3<f32>(1., 2., 3.);
var b: f32 = a.y;          // b = 2.0
var c: vec2<f32> = a.bb;   // c = (3.0, 3.0)
var d: vec3<f32> = a.zyx;  // d = (3.0, 2.0, 1.0)
var e: f32 = a[1];         // e = 2.0
