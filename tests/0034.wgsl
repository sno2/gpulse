var<private> decibels: f32;
var<workgroup> worklist: array<i32,10>;

struct Params {
  specular: f32,
  count: i32
}

// Uniform buffer. Always read-only, and has more restrictive layout rules.
@group(0) @binding(2)
var<uniform> param: Params;    // A uniform buffer

// A storage buffer, for reading and writing
@group(0) @binding(0)
var<storage,read_write> pbuf: array<vec2<f32>>;

// Textures and samplers are always in "handle" space.
@group(0) @binding(1)
var filter_params: sampler;
