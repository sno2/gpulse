struct Particle {
  position: vec3<f32>,
  velocity: vec3<f32>
}
struct System {
  active_index: i32,
  timestep: f32,
  particles: array<Particle,100>
}
@group(0) @binding(0) var<storage,read_write> system: System;

@compute @workgroup_size(1)
fn main() {
  // Form a pointer to a specific Particle in storage memory.
  let active_particle: ptr<storage,Particle> =
      &system.particles[system.active_index];

  let delta_position: vec3<f32> = (*active_particle).velocity * system.timestep;
  let current_position: vec3<f32>  = (*active_particle).position;
  (*active_particle).position = delta_position + current_position;
}
