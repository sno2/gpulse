alias Arr = array<i32, 5>;

alias RTArr = array<vec4<f32>>;

alias single = f32;     // Declare an alias for f32
const pi_approx: single = 3.1415;
fn two_pi() -> single {
  return single(2) * pi_approx;
}
