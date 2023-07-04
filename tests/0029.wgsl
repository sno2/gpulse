const a = 4;                  // AbstractInt with a value of 4.
const b : i32 = 4;            // i32 with a value of 4.
const c : u32 = 4;            // u32 with a value of 4.
const d : f32 = 4;            // f32 with a value of 4.
const e = vec3(a, a, a);      // vec3 of AbstractInt with a value of (4, 4, 4).
const f = 2.0;                // AbstractFloat with a value of 2.
const g = mat2x2(a, f, a, f); // mat2x2 of AbstractFloat with a value of:
                              // ((4.0, 2.0), (4.0, 2.0)).
                              // The AbstractInt a converts to AbstractFloat.
                              // An AbstractFloat cannot convert to AbstractInt.
const h = array(a, f, a, f);  // array of AbstractFloat with 4 components:
                              // (4.0, 2.0, 4.0, 2.0).
