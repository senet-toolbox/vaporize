const std = @import("std");
const Vapor = @import("Vapor.zig");
const isWasi = Vapor.isWasi;
const UIContext = @import("UITree.zig");
const CommandsTree = UIContext.CommandsTree;
const Types = @import("types.zig");
const EventType = Types.EventType;
const RenderCommand = Types.RenderCommand;
const UINode = UIContext.UINode;
const Event = @import("Event.zig");
const StyleCompiler = @import("convertStyleCustomWriter.zig");
const Wasm = @import("wasm");
const Writer = @import("Writer.zig");
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Kit = @import("kit/Kit.zig");
const Packer = @import("Packer.zig");

export fn hookInstCallback(id: u32) void {
    const hook_cb = Vapor.hooks_inst_callbacks.get(id).?;
    const params_str = Vapor.Kit.getWindowParams() orelse "";
    const path = Kit.getWindowPath() orelse {
        Vapor.printlnSrcErr("Hooks ERROR: Could not get window path", .{}, @src());
        return;
    };
    var params = std.StringHashMap([]const u8).init(Vapor.arena(.frame));
    if (params_str.len != 0) {
        params = Kit.parseParams(params_str, &Vapor.allocator_global) catch return orelse return;
    }
    const context = Vapor.HookContext{
        .from_path = "",
        .to_path = path,
        .params = params,
        .query = params,
    };
    @call(.auto, hook_cb, .{context});
}
export fn getCtxNodeChild(tree: *CommandsTree, index: usize) ?*CommandsTree {
    if (tree.node.node_ptr.children == null) return null;
    const ui_node = tree.node.node_ptr.children.?.items[index];
    for (tree.children.items, 0..) |item, i| {
        if (std.mem.eql(u8, ui_node.uuid, item.node.id)) {
            return tree.children.items[i];
        }
    }
    return null;
}

export fn getTreeNodeChildCommand(tree: *CommandsTree) *RenderCommand {
    return tree.node;
}

export fn setDirtyToFalse(node: *UINode) void {
    node.dirty = false;
}

export fn getDirtyNodeCount() usize {
    return Vapor.dirty_nodes.items.len;
}

export fn getDirtyNode() [*]const RenderCommand {
    const node = Vapor.dirty_nodes.items.ptr;
    return node;
}

export fn getAddedNodeCount() usize {
    return Vapor.added_nodes.items.len;
}

export fn getAddedNode() [*]const RenderCommand {
    const node = Vapor.added_nodes.items.ptr;
    return node;
}

export fn getNextSiblingPtr(ui_node: *UINode) ?[*]const u8 {
    const parent = ui_node.parent orelse return null;
    const children = parent.children orelse return null;
    if (ui_node.index + 1 >= children.items.len) return null;
    const sibling = children.items[ui_node.index + 1];
    return sibling.uuid.ptr;
}

export fn getNextSiblingLen(ui_node: *UINode) usize {
    const parent = ui_node.parent orelse return 0;
    const children = parent.children orelse return 0;
    if (ui_node.index + 1 >= children.items.len) return 0;
    const sibling = children.items[ui_node.index + 1];
    return sibling.uuid.len;
}

export fn checkPotentialNode(_: *UINode) bool {
    // Vapor.potential_nodes.get(node.uuid) orelse return false;
    return false;
}

export fn getNodeParentId(node: *UINode) ?[*]const u8 {
    const parent = node.parent orelse return null;
    return parent.uuid.ptr;
}

export fn getNodeParentIdLen(node: *UINode) usize {
    const parent = node.parent orelse return 0;
    return parent.uuid.len;
}

// The first node needs to be marked as false always
export fn markCurrentTreeDirty() void {
    if (!Vapor.has_context) return;
    const root = Vapor.current_ctx.root orelse return;
    Vapor.markChildrenDirty(root);
}

export fn markUINodeTreeDirty(node: *UINode) void {
    Vapor.markChildrenDirty(node);
}
export fn inputCallback(id_ptr: [*:0]u8) void {
    const id = std.mem.span(id_ptr);
    defer Vapor.allocator_global.free(id);
    const element = Vapor.element_registry.get(hashKey(id)) orelse return;
    const text = element.getInputValue() orelse unreachable;
    element.text = text;
}

export fn getElementPtr(id_ptr: [*:0]u8) ?*Vapor.Element {
    const id = std.mem.span(id_ptr);
    defer Vapor.allocator_global.free(id);
    const element = Vapor.element_registry.get(hashKey(id)) orelse return null;
    return element;
}

export fn callback(callbackId: u32) void {
    const continuation = Vapor.continuations[callbackId];
    if (continuation) |cb| {
        @call(.auto, cb, .{});
    }
}

//
// Global buffer to store the CSS string for returning to JavaScript
var common_style_buffer: [8192 * 6]u8 = undefined;
var common_style: []const u8 = "";
pub export fn getBaseStyles() ?[*]const u8 {
    // var fbs = std.io.fixedBufferStream(&common_style_buffer);
    // var writer = fbs.writer();
    // const base_styles = UIContext.base_styles[0..UIContext.base_style_count];
    // var start: usize = 0;
    // var end: usize = 0;
    // var writer: Writer = undefined;
    // for (base_styles) |style| {
    //     var buffer: [4096]u8 = undefined;
    //     writer.init(buffer[0..]);
    //     writer.writeByte('.') catch |err| {
    //         Vapor.printlnSrcErr("{any}", .{err}, @src());
    //         return null;
    //     };
    //     writer.write(style.style_id.?) catch |err| {
    //         Vapor.printlnSrcErr("{any}", .{err}, @src());
    //         return null;
    //     };
    //     writer.write(" {\n") catch |err| {
    //         Vapor.printlnSrcErr("{any}", .{err}, @src());
    //         return null;
    //     };
    //     StyleCompiler.generateStylePass(null, &style, &writer);
    //     writer.write("}\n") catch |err| {
    //         Vapor.printlnSrcErr("{any}", .{err}, @src());
    //         return null;
    //     };
    //     end += writer.pos;
    //     @memcpy(common_style_buffer[start..end], buffer[0..writer.pos]);
    //     start += writer.pos;
    // }
    //
    // common_style_buffer[end] = 0;
    // common_style = common_style_buffer[0..end];
    return common_style.ptr;
}

pub export fn getBaseStylesLen() usize {
    return common_style.len;
}

var animations_str: []const u8 = "";
pub export fn getAnimationsPtr() ?[*]const u8 {
    var animations = Vapor.animations.iterator();
    var writer: Writer = undefined;
    var buffer: [4096]u8 = undefined;
    writer.init(&buffer);
    while (animations.next()) |entry| {
        const animation = entry.value_ptr.*;
        writer.write("@keyframes ") catch {};
        writer.write(animation._name) catch {};
        writer.writeByte(' ') catch {};
        writer.write("{\n") catch {};
        // From
        writer.write("from { ") catch {};
        writer.write("transform: ") catch {};
        switch (animation._type) {
            .scaleY => {
                writer.write("scaleY(") catch {};
                writer.writeF32(animation.from_value) catch {};
            },
            .scaleX => {
                writer.write("scaleX(") catch {};
                writer.writeF32(animation.from_value) catch {};
            },
            .translateX => {
                writer.write("translateX(") catch {};
                writer.writeF32(animation.from_value) catch {};
                writer.write("px") catch {};
            },
            .translateY => {
                writer.write("translateY(") catch {};
                writer.writeF32(animation.from_value) catch {};
                writer.write("px") catch {};
            },
            else => {},
        }
        writer.write(");") catch {};
        writer.write("}\n") catch {};

        writer.write("to { ") catch {};
        writer.write("transform: ") catch {};
        switch (animation._type) {
            .scaleY => {
                writer.write("scaleY(") catch {};
                writer.writeF32(animation.to_value) catch {};
            },
            .scaleX => {
                writer.write("scaleX(") catch {};
                writer.writeF32(animation.to_value) catch {};
            },
            .translateX => {
                writer.write("translateX(") catch {};
                writer.writeF32(animation.to_value) catch {};
                writer.write("px") catch {};
            },
            .translateY => {
                writer.write("translateY(") catch {};
                writer.writeF32(animation.to_value) catch {};
                writer.write("px") catch {};
            },
            else => {},
        }
        writer.write(");") catch {};
        writer.write("}\n") catch {};
        writer.write("}\n") catch {};
    }
    const len: usize = writer.pos;
    buffer[len] = 0;
    animations_str = buffer[0..len];
    return animations_str.ptr;
}

pub export fn getAnimationsLen() usize {
    return animations_str.len;
}

pub export fn hasExitAnimation(node_ptr: *UINode) bool {
    if (node_ptr.animation_exit != null) {
        return true;
    }
    return false;
}

pub export fn pendingClassesToAdd() void {
    // if (isWasi) {
    //     for (Vapor.classes_to_add.items) |clta| {
    //         Wasm.addClass(clta.element_id.ptr, clta.element_id.len, clta.style_id.ptr, clta.style_id.len);
    //     }
    //     Vapor.classes_to_add.clearAndFree();
    // }
}
pub export fn pendingClassesToRemove() void {
    // if (isWasi) {
    //     for (Vapor.classes_to_remove.items) |cltr| {
    //         Wasm.removeClass(cltr.element_id.ptr, cltr.element_id.len, cltr.style_id.ptr, cltr.style_id.len);
    //     }
    //     Vapor.classes_to_remove.clearAndFree();
    // }
}

export fn cleanUp() void {

    // Vapor.clean_up_ctx.deinit();
    // Vapor.allocator_global.destroy(Vapor.clean_up_ctx);
    Vapor.clean_up_ctx = undefined;
}

export fn timeOutCtxCallback(id_ptr: [*:0]u8) void {
    const id = std.mem.span(id_ptr);
    defer Vapor.allocator_global.free(id);
    const node = Vapor.callback_registry.get(hashKey(id)) orelse return;
    @call(.auto, node.data.runFn, .{&node.data});
}

export fn onEndCtxCallback() void {
    const length = Vapor.on_end_ctx_funcs.items.len;
    Vapor.println("onEndCtxCallback {d}\n", .{length});
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const node = Vapor.on_end_ctx_funcs.orderedRemove(i);
        @call(.auto, node.data.runFn, .{&node.data});
        if (i == 0) return;
    }
}

export fn timeoutCtxCallBackId(id: usize) void {
    const node = Vapor.time_out_ctx_registry.get(id) orelse return;
    defer _ = Vapor.time_out_ctx_registry.remove(id);
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

export fn timeoutCallBackId(id: usize) void {
    const func = Vapor.time_out_registry.get(id) orelse return;
    defer _ = Vapor.time_out_registry.remove(id);
    @call(.auto, func, .{});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

// This function gets called from JavaScript when a timeout completes
export fn resumeExecution(callbackId: u32) void {
    const continuation = Vapor.continuations[callbackId];
    if (continuation) |func| {
        // Clear the slot
        Vapor.continuations[callbackId] = null;
        // Call the continuation function
        func();
    }
}
