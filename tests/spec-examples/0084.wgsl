// Array where:
//   - alignment is 4 = AlignOf(f32)
//   - element stride is 4 = roundUp(AlignOf(f32),SizeOf(f32)) = roundUp(4,4)
//   - size is 32 = stride * number_of_elements = 4 * 8
var small_stride: array<f32, 8>;

// Array where:
//   - alignment is 16 = AlignOf(vec3<f32>) = 16
//   - element stride is 16 = roundUp(AlignOf(vec3<f32>), SizeOf(vec3<f32>))
//                          = roundUp(16,12)
//   - size is 128 = stride * number_of_elements = 16 * 8
var bigger_stride: array<vec3<f32>, 8>;
