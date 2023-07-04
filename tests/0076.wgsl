struct VertexOutput {
   @builtin(position) my_pos: vec4<f32>
 }

 @vertex
fn vs_main(
    @builtin(vertex_index) my_index: u32,
    @builtin(instance_index) my_inst_index: u32,
) -> VertexOutput {}

struct FragmentOutput {
   @builtin(frag_depth) depth: f32,
   @builtin(sample_mask) mask_out: u32
 }

 @fragment
fn fs_main(
    @builtin(front_facing) is_front: bool,
    @builtin(position) coord: vec4<f32>,
    @builtin(sample_index) my_sample_index: u32,
    @builtin(sample_mask) mask_in: u32,
) -> FragmentOutput {}

 @compute @workgroup_size(64)
fn cs_main(
    @builtin(local_invocation_id) local_id: vec3<u32>,
    @builtin(local_invocation_index) local_index: u32,
    @builtin(global_invocation_id) global_id: vec3<u32>,
) {}
