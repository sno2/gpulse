const ast = @import("ast.zig");
const Span = ast.Span;
const Node = ast.Node;
const Dumper = @This();

const State = struct {
    indent: u32,
};

fn writeIndent(state: *State) void {
    _ = state;
}

pub fn dump(state: *State, node: *const Node) void {
    _ = node;
    _ = state;
}
