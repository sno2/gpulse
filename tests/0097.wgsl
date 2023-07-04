struct PointLight {
  position : vec3f,
  color : vec3f,
}

struct LightStorage {
  pointCount : u32,
  point : array<PointLight>,
}

@group(0) @binding(1) var<storage> lights : LightStorage;

fn num_point_lights() -> u32 {
  return arrayLength( &lights.point );
}
