const std = @import("std");
const Fabric = @import("Fabric.zig");
const KeyGenerator = @import("Key.zig").KeyGenerator;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const CompactStyle = @import("types.zig").CompactStyle;

const types = @import("types.zig");

const Item = struct {
    ptr: ?*UINode,
    next: ?*Item = null,
};

const Style = types.Style;
const EType = types.ElementType;
const RenderCommand = types.RenderCommand;
const ElemDecl = types.ElementDeclaration;
const Direction = types.Direction;
const HooksIds = types.HooksIds;
const InputParams = types.InputParams;

pub var key_depth_map: std.AutoHashMap(u64, usize) = undefined;
pub var ui_nodes: []UINode = undefined;
pub const UIContext = @This();
root: ?*UINode = null,
current_parent: ?*UINode = null,
stack: ?*Item = null,
root_stack_ptr: ?*Item = null,
node_pool: std.heap.MemoryPool(UINode),
style_pool: std.heap.MemoryPool(CompactStyle),
basic_style_pool: std.heap.MemoryPool(types.Basic),
visual_style_pool: std.heap.MemoryPool(types.Visual),
interactive_style_pool: std.heap.MemoryPool(types.Interactive),
memory_pool: std.heap.MemoryPool(Item),
render_cmd_memory_pool: std.heap.MemoryPool(RenderCommand),
tree_memory_pool: std.heap.MemoryPool(CommandsTree),
current_offset: f32 = 0,
ui_tree: ?*CommandsTree = null,

pub const CommandsTree = struct {
    node: *RenderCommand,
    children: std.array_list.Managed(*CommandsTree),
};

pub const BoxSizing = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub var styles: std.array_list.Managed(*Style) = undefined;

pub const UINode = struct {
    dirty: bool = false,
    parent: ?*UINode = null,
    type: EType = EType.FlexBox,
    // style: ?*Style = null,
    compact_style: ?*CompactStyle = null,
    children: std.ArrayListUnmanaged(*UINode),
    text: ?[]const u8 = null,
    uuid: []const u8 = "",
    uuid_buf: [64]u8 = undefined,
    href: ?[]const u8 = null,
    index: usize = 0,
    hooks: HooksIds = .{},
    input_params: ?*const InputParams = null,
    event_type: ?types.EventType = null,
    state_type: types.StateType = .pure,
    aria_label: ?[]const u8 = null,
    class: ?[]const u8 = null,
    // tooltip: ?types.Tooltip = null,

    pub fn deinit(ui_node: *UINode) void {
        ui_node.children.deinit();
    }

    pub fn addChild(parent: *UINode, child: *UINode) !void {
        if (parent.children.items.len + 1 >= 128) return error.ChildArrayOutOfBounds;
        parent.children.appendBounded(child) catch {
            return error.ChildArrayOutOfMemory;
        };
    }
};

pub fn init(ui_ctx: *UIContext, parent: ?*UINode, etype: EType) !*UINode {
    const node = try ui_ctx.node_pool.create();
    Fabric.frame_arena.incrementNodeCount();
    node.* = .{
        .parent = parent,
        .type = etype,
        .children = try std.ArrayListUnmanaged(*UINode).initCapacity(Fabric.frame_arena.getFrameAllocator(), 128),
    };
    return node;
}

/// initContext initializes the UIContext and its associated memory pools
pub fn initContext(ui_ctx: *UIContext) !void {
    const allocator = Fabric.frame_arena.getFrameAllocator();
    ui_ctx.* = .{
        .node_pool = std.heap.MemoryPool(UINode).init(allocator),
        .style_pool = std.heap.MemoryPool(CompactStyle).init(allocator),
        .basic_style_pool = std.heap.MemoryPool(types.Basic).init(allocator),
        .visual_style_pool = std.heap.MemoryPool(types.Visual).init(allocator),
        .interactive_style_pool = std.heap.MemoryPool(types.Interactive).init(allocator),
        .memory_pool = std.heap.MemoryPool(Item).init(allocator),
        .render_cmd_memory_pool = std.heap.MemoryPool(RenderCommand).init(allocator),
        .tree_memory_pool = std.heap.MemoryPool(CommandsTree).init(allocator),
    };

    // Either change the init function to return a pointer directly
    const node_ptr = try ui_ctx.init(null, EType.Block);
    node_ptr.uuid = "fabric_root_id";
    node_ptr.dirty = false;
    ui_ctx.root = node_ptr;
    const item: *Item = try ui_ctx.memory_pool.create();
    item.* = .{
        .ptr = node_ptr,
    };
    ui_ctx.root_stack_ptr = item;
    ui_ctx.stack = item;
    node_count = 0;
    if (node_count >= nodes.len) {
        Fabric.printlnErr("Page Node count is too small {d}", .{node_count});
    } else {
        nodes[node_count] = ui_ctx.root.?;
    }
    node_count += 1;
}

pub fn deinit(ui_ctx: *UIContext) void {
    ui_ctx.root.?.children = undefined;
    ui_ctx.root = null;
    ui_ctx.ui_tree = null;
}

pub fn stackRegister(ui_ctx: *UIContext, ui_node: *UINode) !void {
    const item: *Item = try ui_ctx.memory_pool.create();
    const current_stack = ui_ctx.stack;
    item.* = .{
        .ptr = ui_node,
    };

    if (current_stack) |stack| {
        item.next = stack;
    }

    ui_ctx.stack = item;
}

pub fn stackPop(ui_ctx: *UIContext) void {
    const current_stack = ui_ctx.stack orelse return;
    ui_ctx.stack = current_stack.next;
}

pub var uuid_depth: usize = 0;
var current_tree: usize = 0;
fn setUUID(parent: *UINode, child: *UINode) void {
    uuid_depth += 1;
    const count = key_depth_map.get(hashKey(parent.uuid)) orelse blk: {
        break :blk 0;
    };

    // Set the keyGenerator count
    KeyGenerator.setCount(count);
    // KeyGenerator.resetCounter();
    const index: usize = uuid_depth;
    if (child.uuid.len > 0) {
        child.index = KeyGenerator.getCount();
        KeyGenerator.incrementCount();
    } else {
        child.uuid = KeyGenerator.generateKey(
            &child.uuid_buf,
            child.type,
            parent.uuid,
            index,
        );
        child.index = KeyGenerator.getCount();
        // we add this so that animations are sepeate, we need to be careful though since
        // if a user does not specifc a id for a class, and the  rerender tree has the same id
        // and then previous one uses an animation then that transistion and animation will be
        // applied to the new parent since it has the same class name and styling
    }
    // Put the new keygenerator count in to the key_dpeht_map;
    key_depth_map.put(hashKey(parent.uuid), KeyGenerator.getCount()) catch |err| {
        Fabric.printlnSrcErr("{any}", .{err}, @src());
    };
}

// Open takes a current stack and adds the elements depth first search
// Open and close get called in sequence
// depth first search
pub fn open(ui_ctx: *UIContext, elem_decl: ElemDecl) !*UINode {
    const stack = ui_ctx.stack.?;
    // Parent node
    const current_open = stack.ptr orelse unreachable;
    // Fabric.frame_arena.incrementNodeCount();
    // ui_nodes[node_count] = .{
    //     .parent = current_open,
    //     .type = elem_decl.elem_type,
    //     .children = try std.ArrayListUnmanaged(*UINode).initCapacity(Fabric.frame_arena.getFrameAllocator(), 128),
    // };
    const node = try ui_ctx.init(current_open, elem_decl.elem_type);

    // ui_nodes[node_count].state_type = elem_decl.state_type;

    // var node = ui_nodes[node_count];
    try current_open.addChild(node);
    try ui_ctx.stackRegister(node);

    setUUID(current_open, node);
    return node;
}

pub fn configure(ui_ctx: *UIContext, elem_decl: ElemDecl) *UINode {
    const stack = ui_ctx.stack orelse unreachable;
    const current_open = stack.ptr orelse unreachable;
    const style = elem_decl.style;

    if (style != null and style.?.id != null) {
        current_open.uuid = style.?.id.?;
    }

    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
    } else if (elem_decl.elem_type == .Input) {
        current_open.input_params = elem_decl.input_params.?;
        current_open.text = elem_decl.text orelse "";
    } else if (elem_decl.text) |text| {
        current_open.text = text;
    }

    current_open.href = elem_decl.href;
    current_open.type = elem_decl.elem_type;

    if (style) |s| {
        const style_ptr = ui_ctx.style_pool.create() catch unreachable;
        style_ptr.* = .{};

        const basic_style_ptr = ui_ctx.basic_style_pool.create() catch unreachable;
        basic_style_ptr.* = .{
            .id = s.id,
            .style_id = s.style_id,
            .position = s.position,
            .direction = s.direction,
            .size = s.size,
            .padding = s.padding,
            .margin = s.margin,
            .scroll = s.scroll,
            .text_decoration = s.text_decoration,
            .layout = s.layout,
            .child_gap = s.child_gap,
            .font_family = s.font_family,
            .white_space = s.white_space,
            .flex_wrap = s.flex_wrap,
            .key_frame = s.key_frame,
            .key_frames = s.key_frames,
            .animation = s.animation,
            .exit_animation = s.exit_animation,
            .z_index = s.z_index,
            .list_style = s.list_style,
            .blur = s.blur,
            .outline = s.outline,
            .transition = s.transition,
            .show_scrollbar = s.show_scrollbar,
            .cursor = s.cursor,
            .btn_id = s.btn_id,
        };
        style_ptr.basic = basic_style_ptr;

        if (s.visual) |visual| {
            const visual_style_ptr = ui_ctx.visual_style_pool.create() catch unreachable;
            visual_style_ptr.* = visual;
            style_ptr.visual = visual_style_ptr;
        }

        if (s.interactive) |interactive| {
            const interactive_style_ptr = ui_ctx.interactive_style_pool.create() catch unreachable;
            interactive_style_ptr.* = interactive;
            style_ptr.interactive = interactive_style_ptr;
        }

        // style_ptr.* = s.*;
        // styles.appendAssumeCapacity(style_ptr);
        current_open.compact_style = style_ptr;

        if (s.style_id == null and elem_decl.elem_type == .Icon and elem_decl.href != null) {
            current_open.class = std.fmt.allocPrint(Fabric.allocator_global, "{s} fbc-{s}", .{ elem_decl.href.?, current_open.uuid }) catch "";
        } else if (s.style_id != null) {
            current_open.class = s.style_id;
        } else {
            // current_open.class = std.fmt.allocPrint(Fabric.allocator_global, "fbc-{s}", .{current_open.uuid}) catch "";
        }
        if (node_count >= nodes.len) {
            Fabric.printlnErr("Page Node count is too small {d}", .{node_count});
        } else {
            nodes[node_count] = current_open;
            node_count += 1;
        }
    }

    if (current_open.type == .Hooks or current_open.type == .HooksCtx) {
        current_open.hooks = elem_decl.hooks;
    }
    current_open.state_type = elem_decl.state_type;
    current_open.aria_label = elem_decl.aria_label;
    // if (elem_decl.tooltip) |tooltip| {
    //     current_open.tooltip = tooltip.*;
    // }

    return current_open;
}

// close is breadth post order first
pub fn close(ui_ctx: *UIContext) void {
    if (uuid_depth > 0) {
        uuid_depth -= 1;
    } else {
        Fabric.printlnSrcErr("Depth is negative {}", .{uuid_depth}, @src());
    }
    ui_ctx.stackPop();
}

pub fn endContext(ui_ctx: *UIContext) void {
    const root = ui_ctx.root.?;
    const render_cmd: *RenderCommand = ui_ctx.render_cmd_memory_pool.create() catch unreachable;
    Fabric.frame_arena.incrementCommandCount();
    render_cmd.* = .{
        .elem_type = root.type,
        .href = "",
        // .style = root.style,
        .hooks = root.hooks,
        .node_ptr = root,
        .id = root.uuid,
        .index = 0,
    };
    root.dirty = false;

    const tree: *CommandsTree = ui_ctx.tree_memory_pool.create() catch unreachable;
    tree.* = .{
        .node = render_cmd,
        .children = std.array_list.Managed(*CommandsTree).init(Fabric.frame_arena.getFrameAllocator()),
    };
    ui_ctx.ui_tree = tree;
}

pub fn createStack(ui_ctx: *UIContext, parent: *UINode) void {
    if (parent.children.items.len == 0) return;

    for (parent.children.items) |child| {
        ui_ctx.stackRegister(child) catch {
            Fabric.println("Could not stack register\n", .{});
            unreachable;
        };
    }
    var i = parent.children.items.len - 1;
    while (true) {
        const child = parent.children.items[i];
        if (i == 0) {
            ui_ctx.createStack(child);
            break;
        } else {
            ui_ctx.createStack(child);
        }
        i -= 1;
    }
}

// Breadth first search
// This calcualtes the positions;
var depth: usize = 0;
pub fn traverseChildren(ui_ctx: *UIContext, parent_op: ?*UINode, ui_tree_parent: *CommandsTree) void {
    if (parent_op) |parent| {
        if (parent.children.items.len > 0) {
            ui_tree_parent.children = std.array_list.Managed(*CommandsTree).init(Fabric.frame_arena.getFrameAllocator());
            depth += 1;
            for (parent.children.items) |child| {
                const render_cmd: *RenderCommand = ui_ctx.render_cmd_memory_pool.create() catch unreachable;
                Fabric.frame_arena.incrementCommandCount();
                render_cmd.* = .{
                    .elem_type = child.type,
                    .text = child.text orelse "",
                    .href = child.href orelse "",
                    // .style = child.style,
                    .id = child.uuid,
                    .index = child.index,
                    .hooks = child.hooks,
                    .node_ptr = child,
                    .render_type = child.state_type,
                    // .tooltip = child.tooltip,
                };

                if (child.compact_style) |style| {
                    if (style.interactive) |interactive| {
                        if (interactive.hover) |_| {
                            render_cmd.hover = true;
                        }
                        if (interactive.focus) |_| {
                            render_cmd.focus = true;
                        }
                        if (interactive.focus_within) |_| {
                            render_cmd.focus_within = true;
                        }
                    }
                    Fabric.generator.writeNodeStyle(child);
                    if (child.class) |id| {
                        render_cmd.class = id;
                    }
                }
                const tree: *CommandsTree = ui_ctx.tree_memory_pool.create() catch unreachable;
                tree.* = .{
                    .node = render_cmd,
                    .children = std.array_list.Managed(*CommandsTree).init(Fabric.frame_arena.getFrameAllocator()),
                };
                ui_tree_parent.children.append(tree) catch unreachable;
                // if (child.state_type == .animation) {
                //     const class_name = child.style.?.child_styles.?[0].style_id;
                //     Fabric.addToClassesList(child.uuid, class_name);
                // }
            }
            for (parent.children.items, 0..) |child, j| {
                ui_ctx.traverseChildren(child, ui_tree_parent.children.items[j]);
            }
            depth -= 1;
        }
    }
}
pub fn traverse(ui_ctx: *UIContext) void {
    ui_ctx.traverseChildren(ui_ctx.root, ui_ctx.ui_tree.?);
}

pub var nodes: []*UINode = undefined;
var node_count: usize = 0;
var seen_count: usize = 0;

pub var common_nodes: []usize = undefined;
pub var common_size_nodes: []usize = undefined;
pub var common_visual_nodes: []usize = undefined;

pub var seen_nodes: []bool = undefined;

pub var common_uuids: [][]const u8 = undefined;
pub var common_size_uuids: [][]const u8 = undefined;
pub var common_visual_uuids: [][]const u8 = undefined;

var common_count: usize = 0;
var common_size_count: usize = 0;
var common_visual_count: usize = 0;

pub var target_node_index: usize = 0;
pub var base_styles: []Style = undefined;
pub var base_style_count: usize = 0;
var common_size_style: ?Style = null;
var common_visual_style: ?Style = null;

pub fn reconcileStyles(node: *UINode) void {
    if (node.style != null) {
        // We only incrment the target node index if the node has a style
        deduplicateStyles(node);
        if (common_count > 1) {
            const common = KeyGenerator.generateCommonStyleKey(common_uuids[0..common_count], &Fabric.allocator_global);
            for (common_nodes[0..common_count]) |node_index| {
                const c_node = nodes[node_index];
                if (c_node.class) |class| {
                    c_node.class = std.fmt.allocPrint(Fabric.allocator_global, "{s} {s}", .{ class, common }) catch return;
                } else {
                    c_node.class = common;
                }
                c_node.style.?.style_id = c_node.class;
            }
        }
        target_node_index += 1;
    }
    for (node.children.items) |child| {
        reconcileStyles(child);
    }
}
pub fn deduplicateStyles(target_node: *UINode) void {
    common_count = 0;
    common_nodes[common_count] = target_node_index;
    common_uuids[common_count] = target_node.uuid;
    // Set the target node as seen
    seen_nodes[target_node_index] = true;
    common_count += 1;
    // if no style then return
    if (target_node.style == null) return;
    const target_style = target_node.style orelse return;
    // if the style id is set then we dont want to gen a common style
    if (target_style.style_id != null) return;

    for (nodes[0..node_count], 0..) |node, i| {
        if (seen_nodes[i]) continue;

        const node_style = node.style orelse continue;

        if (node_style.style_id) |_| continue;

        const same = std.meta.eql(target_style, node_style);
        // We first check if the whole style is the same
        if (same) {
            common_nodes[common_count] = i;
            common_uuids[common_count] = node.uuid;
            common_count += 1;
            seen_nodes[i] = true;
            continue;
        }
    }
}

pub fn reconcileSizes(node: *UINode) void {
    if (node.style != null) {
        // We only incrment the target node index if the node has a style
        deduplicateSizes(node);
        if (common_count > 1) {
            const common = KeyGenerator.generateStyleKey("size", common_uuids[0..common_count], &Fabric.allocator_global);
            // base_styles[base_style_count] = Style{};
            // base_styles[base_style_count].visual = node.style.?.visual.?;
            // base_styles[base_style_count].style_id = common;
            // base_style_count += 1;
            for (common_nodes[0..common_count]) |node_index| {
                const c_node = nodes[node_index];
                if (c_node.class) |class| {
                    c_node.class = std.fmt.allocPrint(Fabric.allocator_global, "{s} {s}", .{ class, common }) catch return;
                } else {
                    c_node.class = std.fmt.allocPrint(Fabric.allocator_global, "{s} {s}", .{ c_node.uuid, common }) catch return;
                }
                c_node.style.?.style_id = c_node.class;
            }
        }
        target_node_index += 1;
    }
    for (node.children.items) |child| {
        reconcileSizes(child);
    }
}

pub fn deduplicateSizes(target_node: *UINode) void {
    common_count = 0;
    common_nodes[common_count] = target_node_index;
    common_uuids[common_count] = target_node.uuid;
    // Set the target node as seen
    seen_nodes[target_node_index] = true;
    common_count += 1;
    // if no style then return
    if (target_node.style == null) return;
    const target_style = target_node.style orelse return;
    const style_id = target_style.style_id orelse return;
    if (indexOf(style_id, "size")) |_| return;
    for (nodes[0..node_count], 0..) |node, i| {
        if (seen_nodes[i]) continue;

        const node_style = node.style orelse continue;
        const node_size = node_style.size orelse continue;
        const target_size = target_style.size orelse continue;
        if (std.meta.eql(target_size, node_size)) {
            common_nodes[common_count] = i;
            common_uuids[common_count] = node.uuid;
            common_count += 1;
            seen_nodes[i] = true;
        }
    }
}

pub fn reconcileVisuals(node: *UINode) void {
    if (node.style != null) {
        // We only incrment the target node index if the node has a style
        deduplicateVisuals(node);
        if (common_count > 1) {
            const common = KeyGenerator.generateStyleKey("visual", common_uuids[0..common_count], &Fabric.allocator_global);
            // base_styles[base_style_count] = Style{};
            // base_styles[base_style_count].visual = node.style.?.visual.?;
            // base_styles[base_style_count].style_id = std.fmt.allocPrint(Fabric.allocator_global, "{s}", .{common}) catch return;
            // base_style_count += 1;
            for (common_nodes[0..common_count]) |node_index| {
                const c_node = nodes[node_index];
                if (c_node.class) |class| {
                    c_node.class = std.fmt.allocPrint(Fabric.allocator_global, "{s} {s}", .{ class, common }) catch return;
                } else {
                    c_node.class = std.fmt.allocPrint(Fabric.allocator_global, "{s} {s}", .{ c_node.uuid, common }) catch return;
                }
                c_node.style.?.style_id = c_node.class;
                // c_node.style.?.visual = null;
            }
        }
        target_node_index += 1;
    }
    for (node.children.items) |child| {
        reconcileVisuals(child);
    }
}

pub fn deduplicateVisuals(target_node: *UINode) void {
    common_count = 0;
    common_nodes[common_count] = target_node_index;
    common_uuids[common_count] = target_node.uuid;
    // Set the target node as seen
    seen_nodes[target_node_index] = true;
    common_count += 1;
    // if no style then return
    if (target_node.style == null) return;
    const target_style = target_node.style orelse return;
    // If the style id is not set then it doesnt have anything in common
    const style_id = target_style.style_id orelse return;
    // If it does have something in common then return
    if (indexOf(style_id, "visual")) |_| return;
    for (nodes[0..node_count], 0..) |node, i| {
        if (seen_nodes[i]) continue;

        const node_style = node.style orelse continue;
        const node_visual = node_style.visual orelse continue;
        const target_visual = target_style.visual orelse continue;
        if (std.meta.eql(target_visual, node_visual)) {
            common_nodes[common_count] = i;
            common_uuids[common_count] = node.uuid;
            common_count += 1;
            seen_nodes[i] = true;
            // node.style.?.visual = null;
        }
    }
}

/// Finds the first index of a `needle` within a `haystack` using SIMD acceleration.
/// Returns the starting byte index of the `needle` if found, otherwise `null`.
pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    // Basic edge cases
    if (needle.len == 0) return 0;
    if (haystack.len < needle.len) return null;

    const first_char = needle[0];
    const last_possible_start = haystack.len - needle.len;

    // SIMD setup for 16-byte vectors (128-bit)
    const vec_len = 16;
    const Vec16 = @Vector(vec_len, u8);

    // Create a vector where every element is the first character of the needle.
    // This will be used to compare against 16 bytes of the haystack at once.
    const first_char_vec: Vec16 = @splat(first_char);

    var i: usize = 0;

    // Main SIMD loop. It processes the haystack in 16-byte chunks.
    // The loop condition ensures we don't read past the end of the haystack.
    while (i + vec_len <= haystack.len) : (i += vec_len) {
        // Load a 16-byte chunk from the haystack into a vector.
        const chunk = haystack[i..][0..vec_len].*;
        const haystack_vec: Vec16 = @bitCast(chunk);

        // Perform 16 parallel comparisons. The result is a mask vector.
        const eq_mask = haystack_vec == first_char_vec;

        // Convert the mask vector into a single u16 integer. Each bit in this
        // integer corresponds to a match for the first character in the chunk.
        var bits: u16 = @bitCast(eq_mask);

        // If bits is 0, no potential matches were found in this chunk, so we continue.
        if (bits == 0) continue;

        // If there are potential matches, iterate through each of them.
        while (bits != 0) {
            // `@ctz` (count trailing zeros) finds the index of the first match in our 16-byte chunk.
            const offset = @ctz(bits);
            const potential_idx = i + offset;

            // Ensure the potential match is not too close to the end of the haystack
            // for the full needle to fit.
            if (potential_idx > last_possible_start) {
                // Since offsets are processed in increasing order, no further
                // matches in this chunk can be valid.
                break;
            }

            // Now, verify if the full substring matches at this position.
            if (std.mem.eql(u8, haystack[potential_idx..][0..needle.len], needle)) {
                // We found it!
                return potential_idx;
            }

            // Clear the bit we just checked so we can find the next one.
            // This is a common trick to iterate over set bits.
            bits &= (bits - 1);
        }
    }

    // Scalar fallback loop for the remaining part of the haystack that didn't
    // fit into a full 16-byte chunk.
    while (i <= last_possible_start) : (i += 1) {
        // A simple check is sufficient here.
        if (haystack[i] == first_char and std.mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            return i;
        }
    }

    return null;
}
