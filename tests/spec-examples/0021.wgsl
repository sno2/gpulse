struct Particle {
   position: vec2f,
   velocity: vec2f,
   color_index: i32,
}

@group(0) @binding(0)
var<storage,read_write> the_particle: Particle;

fn particle_velocity_component(p: Particle, i: i32) -> f32 {
  return the_particle.velocity[i]; // A valid reference when i is 0 or 1.
}
