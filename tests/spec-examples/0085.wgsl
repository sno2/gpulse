// Array where:
//   - alignment is 4 = AlignOf(f32)
//   - element stride is 4 = roundUp(AlignOf(f32),SizeOf(f32)) = 4
// If B is the effective buffer binding size for the binding on the
// draw or dispatch command, the number of elements is:
//   N_runtime = floor(B / element stride) = floor(B / 4)
@group(0) @binding(0)
var<storage> weights: array<f32>;

// Array where:
//   - alignment is 16 = AlignOf(vec3<f32>) = 16
//   - element stride is 16 = roundUp(AlignOf(vec3<f32>), SizeOf(vec3<f32>))
//                          = roundUp(16,12)
// If B is the effective buffer binding size for the binding on the
// draw or dispatch command, the number of elements is:
//   N_runtime = floor(B / element stride) = floor(B / 16)
var<storage> directions: array<vec3<f32>>;
