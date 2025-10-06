const AstEmitter = @This();

ast: *const Ast,
str: *Stringify,

pub fn emit(self: *AstEmitter) !void {
    try self.str.beginArray();
    for (self.ast.rootDecls()) |node| {
        try self.emitNode(node);
    }
    try self.str.endArray();
}

fn emitToken(self: *AstEmitter, maybe_token: ?TokenIndex) !void {
    if (maybe_token) |token| {
        try self.str.write(self.ast.tokenSlice(token));
    } else {
        try self.str.write(null);
    }
}

fn emitOptionalIndex(self: *AstEmitter, optional_index: Node.OptionalIndex) !void {
    if (optional_index.unwrap()) |node| {
        try self.emitNode(node);
    } else {
        try self.str.write(null);
    }
}

fn emitMaybeIndex(self: *AstEmitter, maybe_index: ?Node.Index) !void {
    if (maybe_index) |node| {
        try self.emitNode(node);
    } else {
        try self.str.write(null);
    }
}

fn emitNode(self: *AstEmitter, node: Node.Index) !void {
    const tag = self.ast.nodeTag(node);
    var buffer: [2]Node.Index = undefined;
    if (self.ast.fullFnProto(buffer[1..], node)) |fn_proto| {
        try self.emitFnProto(fn_proto);
    } else if (self.ast.fullVarDecl(node)) |var_decl| {
        try self.emitVarDecl(var_decl);
    } else if (self.ast.fullContainerDecl(buffer[0..], node)) |container_decl| {
        try self.emitContainerDecl(container_decl);
    } else if (self.ast.fullContainerField(node)) |container_field| {
        try self.emitContainerField(container_field);
    } else if (self.ast.fullPtrType(node)) |ptr_type| {
        try self.emitPtrType(ptr_type);
    } else if (self.ast.fullCall(buffer[1..], node)) |call| {
        try self.emitCall(call);
    } else {
        switch (tag) {
            .identifier => try self.emitIdentifier(node),
            .number_literal => try self.emitNumberLiteral(node),
            .string_literal => try self.emitStringLiteral(node),
            .enum_literal => try self.emitEnumLiteral(node),
            .field_access => try self.emitFieldAccess(node),
            .grouped_expression => try self.emitGroupedExpression(node),
            .builtin_call,
            .builtin_call_comma,
            .builtin_call_two,
            .builtin_call_two_comma,
            => try self.emitBuiltinCall(node),
            .bit_not,
            .bool_not,
            .negation,
            .negation_wrap,
            .optional_type,
            .address_of,
            .deref,
            => try self.emitUnaryExpr(node),
            .add,
            .add_wrap,
            .add_sat,
            .array_cat,
            .array_mult,
            .bang_equal,
            .bit_and,
            .bit_or,
            .shl,
            .shl_sat,
            .shr,
            .bit_xor,
            .bool_and,
            .bool_or,
            .div,
            .equal_equal,
            .greater_or_equal,
            .greater_than,
            .less_or_equal,
            .less_than,
            .merge_error_sets,
            .mod,
            .mul,
            .mul_wrap,
            .mul_sat,
            .sub,
            .sub_wrap,
            .sub_sat,
            .@"orelse",
            => try self.emitBinaryExpr(node),
            else => {
                std.debug.print("undhandled node tag {t}", .{tag});
                return error.UnhandledNodeTag;
            },
        }
    }
}

fn emitGroupedExpression(self: *AstEmitter, node: Node.Index) anyerror!void {
    const expr, _ = self.ast.nodeData(node).node_and_token;
    try self.emitNode(expr);
}

fn emitIdentifier(self: *AstEmitter, node: Node.Index) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("identifier");
    try self.str.objectField("name");
    try self.str.write(self.ast.getNodeSource(node));
    try self.str.endObject();
}

fn emitNumberLiteral(self: *AstEmitter, node: Node.Index) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("number_literal");
    try self.str.objectField("value");
    const str_value = self.ast.getNodeSource(node);
    if (std.fmt.parseInt(u32, str_value, 0) catch null) |int| {
        try self.str.write(int);
    } else if (std.fmt.parseFloat(f64, str_value) catch null) |float| {
        if (std.math.isFinite(float)) {
            try self.str.write(float);
        } else {
            try self.str.write(str_value);
        }
    } else {
        try self.str.write(str_value);
    }
    try self.str.endObject();
}

fn emitStringLiteral(self: *AstEmitter, node: Node.Index) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("string_literal");
    try self.str.objectField("value");
    const str_value = self.ast.getNodeSource(node);
    std.debug.assert(str_value.len >= 2);
    try self.str.write(str_value[1 .. str_value.len - 1]);
    try self.str.endObject();
}

fn emitEnumLiteral(self: *AstEmitter, node: Node.Index) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("enum_literal");
    try self.str.objectField("value");
    const str_value = self.ast.getNodeSource(node);
    try self.str.write(str_value[1..]);
    try self.str.endObject();
}

fn emitUnaryExpr(self: *AstEmitter, node: Node.Index) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write(self.ast.nodeTag(node));
    try self.str.objectField("expr");
    try self.emitNode(self.ast.nodeData(node).node);
    try self.str.endObject();
}

fn emitBinaryExpr(self: *AstEmitter, node: Node.Index) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write(self.ast.nodeTag(node));
    const lhs, const rhs = self.ast.nodeData(node).node_and_node;
    try self.str.objectField("lhs");
    try self.emitNode(lhs);
    try self.str.objectField("rhs");
    try self.emitNode(rhs);
    try self.str.endObject();
}

fn emitFieldAccess(self: *AstEmitter, node: Node.Index) anyerror!void {
    const data = self.ast.nodeData(node);

    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("field_access");
    try self.str.objectField("field");
    try self.emitToken(data.node_and_token.@"1");
    try self.str.objectField("type");
    try self.emitNode(data.node_and_token.@"0");
    try self.str.endObject();
}

fn emitBuiltinCall(self: *AstEmitter, node: Node.Index) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("builtin_call");
    try self.str.objectField("fn");
    try self.emitToken(self.ast.nodeMainToken(node));
    try self.str.objectField("params");
    try self.str.beginArray();
    var buffer: [2]Node.Index = undefined;
    if (self.ast.builtinCallParams(&buffer, node)) |params| {
        for (params) |param| {
            try self.emitNode(param);
        }
    }

    try self.str.endArray();
    try self.str.endObject();
}

fn emitPtrType(self: *AstEmitter, ptr_type: full.PtrType) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("ptr_type");
    try self.str.objectField("const");
    try self.str.write(ptr_type.const_token != null);
    try self.str.objectField("child_type");
    try self.emitNode(ptr_type.ast.child_type);
    try self.str.endObject();
}

fn emitFnProto(self: *AstEmitter, fn_proto: full.FnProto) anyerror!void {
    try self.str.beginObject();
    try self.str.objectField("tag");
    try self.str.write("fn_proto");

    try self.str.objectField("name");
    try self.emitToken(fn_proto.name_token);
    try self.str.objectField("visib");
    try self.emitToken(fn_proto.visib_token);
    try self.str.objectField("params");
    try self.str.beginArray();
    var it = fn_proto.iterate(self.ast);
    while (it.next()) |param| {
        try self.str.beginObject();
        try self.str.objectField("name");
        try self.emitToken(param.name_token);
        try self.str.objectField("type");
        try self.emitMaybeIndex(param.type_expr);
        try self.str.endObject();
    }
    try self.str.endArray();

    try self.str.endObject();
}

fn emitVarDecl(self: *AstEmitter, var_decl: full.VarDecl) anyerror!void {
    try self.str.beginObject();

    try self.str.objectField("tag");
    try self.str.write("var_decl");
    try self.str.objectField("name");
    try self.emitToken(var_decl.ast.mut_token + 1);
    try self.str.objectField("mut");
    try self.emitToken(var_decl.ast.mut_token);
    try self.str.objectField("visib");
    try self.emitToken(var_decl.visib_token);
    try self.str.objectField("type");
    try self.emitOptionalIndex(var_decl.ast.type_node);
    try self.str.objectField("init");
    try self.emitOptionalIndex(var_decl.ast.init_node);

    try self.str.endObject();
}

fn emitContainerDecl(self: *AstEmitter, container_decl: full.ContainerDecl) anyerror!void {
    try self.str.beginObject();

    try self.str.objectField("tag");
    try self.str.write("container_decl");
    try self.str.objectField("container_type");
    try self.emitToken(container_decl.ast.main_token);
    try self.str.objectField("members");
    try self.str.beginArray();
    for (container_decl.ast.members) |member| {
        try self.emitNode(member);
    }
    try self.str.endArray();

    try self.str.endObject();
}

fn emitContainerField(self: *AstEmitter, container_field: full.ContainerField) anyerror!void {
    try self.str.beginObject();

    try self.str.objectField("tag");
    try self.str.write("container_field");
    try self.str.objectField("name");
    try self.emitToken(container_field.ast.main_token);
    try self.str.objectField("type");
    try self.emitOptionalIndex(container_field.ast.type_expr);
    try self.str.objectField("value");
    try self.emitOptionalIndex(container_field.ast.value_expr);

    try self.str.endObject();
}

fn emitCall(self: *AstEmitter, call: full.Call) anyerror!void {
    try self.str.beginObject();

    try self.str.objectField("tag");
    try self.str.write("call");
    try self.str.objectField("fn");
    try self.str.write(self.ast.getNodeSource(call.ast.fn_expr));

    try self.str.objectField("params");
    try self.str.beginArray();
    for (call.ast.params) |param| {
        try self.emitNode(param);
    }
    try self.str.endArray();

    try self.str.endObject();
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Stringify = std.json.Stringify;
const Ast = std.zig.Ast;
const TokenIndex = Ast.TokenIndex;
const Node = Ast.Node;
const full = Ast.full;
