struct PointLight {                          //             align(16) size(32)
  position : vec3f,                          // offset(0)   align(16) size(12)
  // -- implicit member alignment padding -- // offset(12)            size(4)
  color : vec3f,                             // offset(16)  align(16) size(12)
  // -- implicit struct size padding --      // offset(28)            size(4)
}

struct LightStorage {                        //             align(16)
  pointCount : u32,                          // offset(0)   align(4)  size(4)
  // -- implicit member alignment padding -- // offset(4)             size(12)
  point : array<PointLight>,                 // offset(16)  align(16) elementsize(32)
}

@group(0) @binding(1) var<storage> lights : LightStorage;
