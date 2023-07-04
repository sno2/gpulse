diagnostic(off,derivative_uniformity);
var<private> d: f32;
fn helper() -> vec4<f32> {
  if (d < 0.5) {
    // The derivative_uniformity diagnostic is disabled here
    // by the global diagnostic filter.
    return textureSample(t,s,vec2(0,0));
  } else {
    // The derivative_uniformity diagnostic is set to 'warning' severity.
    @diagnostic(warning,derivative_uniformity) {
      return textureSample(t,s,vec2(0,0));
    }
  }
  return vec4(0.0);
}
