// Storage buffers
@group(0) @binding(0)
var<storage,read> buf1: Buffer;       // Can read, cannot write.
@group(0) @binding(0)
var<storage> buf2: Buffer;            // Can read, cannot write.
@group(0) @binding(1)
var<storage,read_write> buf3: Buffer; // Can both read and write.

struct ParamsTable {weight: f32}

// Uniform buffer. Always read-only, and has more restrictive layout rules.
@group(0) @binding(2)
var<uniform> params: ParamsTable;     // Can read, cannot write.
