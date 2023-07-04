const std = @import("std");

pub const Span = struct {
    start: u32,
    end: u32,

    pub const zero = Span{ .start = 1, .end = 0 };

    pub fn init(start: u32, end: u32) Span {
        return Span{ .start = start, .end = end };
    }
};

pub const Node = union(enum) {
    /// An error node.
    err: Span,

    // Attributes
    attributed: *Attributed,

    // Literals
    identifier: Span,
    number_literal: *NumberLiteral,
    boolean_literal: *BooleanLiteral,
    template: *Template,
    call: *Call,

    // Unary Operations
    negate: *UnaryOp,
    not: *UnaryOp,
    bit_not: *UnaryOp,
    deref: *UnaryOp,
    ref: *UnaryOp,
    inc: *UnaryOp,
    dec: *UnaryOp,

    // Binary Operations
    add: *BinaryOp,
    sub: *BinaryOp,
    mul: *BinaryOp,
    div: *BinaryOp,
    mod: *BinaryOp,
    bit_left: *BinaryOp,
    bit_right: *BinaryOp,
    bit_and: *BinaryOp,
    bit_or: *BinaryOp,
    bit_xor: *BinaryOp,
    cmp_and: *BinaryOp,
    cmp_or: *BinaryOp,
    member: *BinaryOp,
    index: *BinaryOp,
    less_than: *BinaryOp,
    less_than_equal: *BinaryOp,
    greater_than: *BinaryOp,
    greater_than_equal: *BinaryOp,
    equal: *BinaryOp,
    not_equal: *BinaryOp,

    // Assignment Operations
    assign: *BinaryOp,
    add_assign: *BinaryOp,
    sub_assign: *BinaryOp,
    mul_assign: *BinaryOp,
    div_assign: *BinaryOp,
    mod_assign: *BinaryOp,
    bit_left_assign: *BinaryOp,
    bit_right_assign: *BinaryOp,
    bit_and_assign: *BinaryOp,
    bit_or_assign: *BinaryOp,
    bit_xor_assign: *BinaryOp,

    // Statements
    discard: Span,
    const_assert: *ConstAssert,
    phony: *Phony,
    const_decl: *ConstDecl,
    override_decl: *OverrideDecl,
    var_decl: *VarDecl,
    let_decl: *LetDecl,
    labeled_type: *LabeledType,
    fn_decl: *FnDecl,
    struct_decl: *StructDecl,
    type_alias: *TypeAlias,
    ret: *Ret,
    cont: Span,
    brk: Span,
    break_if: *BreakIf,
    scope: *Scope,

    // Control flow
    loop: *Loop,
    switch_stmt: *Switch,
    default_selector: Span,
    if_stmt: *If,
    else_stmt: *Else,
    while_stmt: *While,
    continuing: *Continuing,

    // Directives
    enable_directive: *EnableDirective,
    requires_directive: *RequiresDirective,
    diagnostic_directive: *DiagnosticControl,

    pub fn span(node: Node) Span {
        // TODO: most of the statements are incorrect...
        return switch (node) {
            .err => |x| x,
            .identifier => |x| x,
            .number_literal => |x| x.span,
            .boolean_literal => |x| x.span,
            .template => |x| x.name,
            .add, .sub, .mul, .div => |x| Span{
                .start = x.lhs.span().start,
                .end = x.rhs.span().end,
            },
            .discard => |x| x,
            .const_assert => |x| x.value.span(),
            .fn_decl => |x| x.name,
            .type_alias => |x| x.name,
            .call => |x| x.callee.span(),
            .member => |x| Span.init(x.lhs.span().start, x.rhs.span().end),
            else => std.debug.panic("Unsupported: {}", .{node}),
        };
    }
};

pub const Attributed = struct {
    attributes: []Attribute,
    inner: Node,
};

pub const CompoundStatement = struct {
    attributes: ?[]Attribute,
    scope: []Node,
};

pub const Attribute = union(enum) {
    @"align": Node,
    binding: Node,
    builtin: Node,
    @"const",
    diagnostic: DiagnosticControl,
    group: Node,
    id: Node,
    interpolate: InterpolateAttribute,
    invariant,
    location: Node,
    must_use,
    size: Node,
    workgroup_size: WorkgroupSizeAttribute,
    vertex,
    fragment,
    compute,
};

pub const DiagnosticControl = struct {
    severity: SeverityControlName,
    /// May be a null span.
    rule_namespace: Span,
    rule_name: Span,
};

pub const SeverityControlName = enum {
    unknown,
    @"error",
    warning,
    info,
    off,

    pub const Map = std.ComptimeStringMap(SeverityControlName, .{
        .{ "error", .@"error" },
        .{ "warning", .warning },
        .{ "info", .info },
        .{ "off", .off },
    });
};

pub const InterpolateAttribute = struct {
    first: Node,
    second: ?Node,
};

pub const WorkgroupSizeAttribute = struct {
    x: Node,
    y: ?Node,
    z: ?Node,
};

pub const NumberLiteral = struct {
    span: Span,
    kind: NumberKind,

    pub const NumberKind = enum {
        abstract_int,
        abstract_float,
        u32,
        i32,
        f32,
        f16,
    };
};

pub const BooleanLiteral = struct {
    span: Span,
    value: bool,
};

pub const Template = struct {
    name: Span,
    args: []Node,
};

pub const Call = struct {
    callee: Node,
    args: []Node,
};

// pub const NumberLiteral = struct {
//     span: Span,
//     kind: Kind,

//     pub const Kind = enum {
//         abstract_float,
//         abstract_int,
//         u32,
//         i32,
//         f32,
//     };
// };

pub const UnaryOp = struct {
    value: Node,
};

pub const BinaryOp = struct {
    lhs: Node,
    rhs: Node,
};

pub const ConstAssert = struct {
    value: Node,
};

pub const Phony = struct {
    value: Node,
};

pub const ConstDecl = struct {
    name: Span,
    typ: ?Node,
    value: Node,
};

pub const OverrideDecl = struct {
    name: Span,
    typ: ?Node,
    value: ?Node,
};

pub const VarDecl = struct {
    name: Span,
    access_mode: AccessMode,
    addr_space: ?AddrSpace,
    typ: ?Node,
    value: ?Node,
};

pub const LetDecl = struct {
    name: Span,
    typ: ?Node,
    value: Node,
};

// https://www.w3.org/TR/WGSL/#predeclared-enumerants
pub const AccessMode = enum {
    read,
    write,
    read_write,

    pub const Map = std.ComptimeStringMap(AccessMode, .{
        .{ "read", .read },
        .{ "write", .write },
        .{ "read_write", .read_write },
    });
};

// https://www.w3.org/TR/WGSL/#predeclared-enumerants
pub const AddrSpace = enum {
    function,
    private,
    workgroup,
    uniform,
    storage,
    handle,

    pub const Map = std.ComptimeStringMap(AddrSpace, .{
        .{ "function", .function },
        .{ "private", .private },
        .{ "workgroup", .workgroup },
        .{ "uniform", .uniform },
        .{ "storage", .storage },
    });
};

pub const FnDecl = struct {
    name: Span,
    /// `LabeledType` or `Attributed`
    params: []Node,
    ret: ?Node,
    scope: []Node,
};

pub const LabeledType = struct {
    name: Span,
    typ: Node,
};

pub const StructDecl = struct {
    name: Span,
    /// `LabeledType` or `Attributed`
    members: []Node,
};

pub const TypeAlias = struct {
    name: Span,
    value: Node,
};

pub const Ret = struct {
    value: ?Node,
};

pub const BreakIf = struct {
    value: Node,
};

pub const Scope = struct {
    scope: []Node,
};

pub const Loop = struct {
    attributes: ?[]Attribute,
    scope: []Node,
};

pub const Switch = struct {
    expression: Node,
    attributes: ?[]Attribute,
    clauses: []SwitchClause,
};

pub const SwitchClause = union(enum) {
    case: Case,
    default: Default,

    pub const Case = struct {
        selectors: []Node,
        attributes: ?[]Attribute,
        scope: []Node,
    };

    pub const Default = struct {
        attributes: ?[]Attribute,
        scope: []Node,
    };
};

pub const If = struct {
    expression: Node,
    attributes: ?[]Attribute,
    scope: []Node,
    /// Another `If` or `Else`.
    next: ?*Node,
};

pub const Else = CompoundStatement;

pub const While = struct {
    expression: Node,
    attributes: ?[]Attribute,
    scope: []Node,
};

pub const Continuing = CompoundStatement;

pub const EnableDirective = struct {
    names: []Span,
};

pub const RequiresDirective = struct {
    names: []Span,
};
