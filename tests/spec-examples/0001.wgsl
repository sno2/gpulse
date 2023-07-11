var<private> d: f32;
fn helper() -> vec4<f32> {
  // Disable the derivative_uniformity diagnostic in the
  // body of the "if".
  if (d < 0.5) @diagnostic(off,derivative_uniformity) {
    return textureSample(t,s,vec2(0,0));
  }
  return vec4(0.0);
}
