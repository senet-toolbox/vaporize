const std = @import("std");
const Vapor = @import("Vapor.zig");
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const UINode = @import("UITree.zig").UINode;

/// onCreateNode takes a node, callback, and arguments
/// Calls the callback when the node is created
/// # Parameters:
/// - `ui_node`: *UINode,
/// - `callback`: anytype,
/// - `args`: anytype,
///
/// # Returns:
/// void
///
/// # Usage:
/// ```zig
/// const onCreateNode = Hooks.onCreateNode;
/// onCreateNode(ui_node, onCreateNodeCallback, .{ .id = id });
///
/// fn onCreateNodeCallback(on_create: *Vapor.onCreate) void {
///     const on_create_node: *Vapor.Node = @fieldParentPtr("data", on_create);
///     const closure: *@This() = @alignCast(@fieldParentPtr("run_node", on_create_node));
///     _ = closure.arguments;
/// }
/// ```
pub fn onCreateNode(ui_node: *UINode, callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.onCreateData = .{ .data = .{ .runFn = runFn } },
        fn runFn(on_create: *Vapor.onCreate) void {
            const run_node: *Vapor.onCreateData = @fieldParentPtr("data", on_create);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
    };

    const closure = Vapor.getFrameAllocator().create(Closure) catch |err| {
        Vapor.printlnSrcErr("Error could not create closure {any}\n ", .{err}, @src());
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    Vapor.on_create_node_funcs.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
        Vapor.printlnSrcErr("Hooks Function Registry {any}\n", .{err}, @src());
    };
}

export fn callOnCreateNode(id_ptr: [*:0]u8) void {
    const id = std.mem.span(id_ptr);
    defer Vapor.allocator_global.free(id);
    const kv = Vapor.on_create_node_funcs.fetchRemove(hashKey(id)) orelse return;
    const on_create_node: *Vapor.onCreateData = kv.value;
    @call(.auto, on_create_node.data.runFn, .{&on_create_node.data});
}
