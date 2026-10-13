const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const println = @import("Vapor.zig").println;
const printlnColor = @import("Vapor.zig").printlnColor;
const Vapor = @import("Vapor.zig");
const Types = @import("types.zig");
const Wasm = @import("wasm");
const isWasi = Vapor.isWasi;
const NodePool = @import("NodePool.zig");
const UINode = @import("UITree.zig").UINode;
const RenderCommand = @import("types.zig").RenderCommand;
const TreeNode = @import("UITree.zig").CommandsTree;

// The FrameAllocator is a simple allocator that allocates memory per render cycle.
// It is used to allocate memory for the render commands and the UI tree, text, and styles, etc.
// It is also used to allocate memory for the persistent arena, which is used to store data that
// should persist across frames.

// For each render cycle, beginFrame() is called to reset the current frame arena and get ready to allocate memory, for
// the next frame. This means we can just deinit a single allocator and there is no need to recurse down the tree.

const FrameData = struct {
    arena: std.heap.ArenaAllocator,
    stats: Stats = .{},
    // node_pool: NodePool,

};

pub const Stats = struct {
    nodes_allocated: usize = 0,
    tree_memory: usize = 0,
    command_memory: usize = 0,
    commands_allocated: usize = 0,
    bytes_used: usize = 0,
    nodes_memory: usize = 0,
};

const FrameAllocator = @This();
persistent_arena: Arena,
frames: [2]FrameData,
current_frame: usize = 0,
view: [2]FrameData,
current_route: usize = 0,
request_arena: Arena,

pub fn init(backing_allocator: std.mem.Allocator, _: usize) FrameAllocator {
    // Vapor.println("Node count {d}", .{node_count});
    // const frame_node_pool_1 = NodePool.init(backing_allocator, node_count) catch |err| {
    //     Vapor.printlnErr("Could not init NodePool {any}\n", .{err});
    //     unreachable;
    // };
    // const frame_node_pool_2 = NodePool.init(backing_allocator, node_count) catch |err| {
    //     Vapor.printlnErr("Could not init NodePool {any}\n", .{err});
    //     unreachable;
    // };
    //

    const frame1_arena = std.heap.ArenaAllocator.init(backing_allocator);
    const frame2_arena = std.heap.ArenaAllocator.init(backing_allocator);

    const previous_route_arena = std.heap.ArenaAllocator.init(backing_allocator);
    const current_route_arena = std.heap.ArenaAllocator.init(backing_allocator);

    // "Priming" the arenas.
    // This pre-allocates the first block to be large enough
    // to hold 'node_count' nodes. This makes the *first*
    // 'node_count' allocations guaranteed fast, with no
    // growth/syscalls.
    // const initial_bytes = node_count * @sizeOf(UINode);
    // try frame1_arena.ensureTotalCapacity(initial_bytes);
    // try frame2_arena.ensureTotalCapacity(initial_bytes);

    return .{
        .frames = [_]FrameData{
            .{ .arena = frame1_arena },
            .{ .arena = frame2_arena },
        },
        .persistent_arena = std.heap.ArenaAllocator.init(backing_allocator),
        .view = [_]FrameData{
            .{ .arena = previous_route_arena },
            .{ .arena = current_route_arena },
        },
        .request_arena = std.heap.ArenaAllocator.init(backing_allocator),
    };
}

pub fn deinit(self: *FrameAllocator) void {
    self.frames[0].arena.deinit();
    self.frames[1].arena.deinit();
    self.persistent_arena.deinit();
}

pub fn frameAllocator(self: *FrameAllocator) std.mem.Allocator {
    return self.frames[self.current_frame].arena.allocator();
}

pub fn requestAllocator(self: *FrameAllocator) std.mem.Allocator {
    return self.request_arena.allocator();
}

pub fn viewAllocator(self: *FrameAllocator) std.mem.Allocator {
    return self.view[self.current_route].arena.allocator();
}

pub fn incrementNodeCount(self: *FrameAllocator) void {
    self.frames[self.current_frame].stats.nodes_memory += @sizeOf(UINode);
    self.frames[self.current_frame].stats.nodes_allocated += 1;
}

pub fn incrementCommandCount(self: *FrameAllocator) void {
    self.frames[self.current_frame].stats.command_memory += @sizeOf(RenderCommand);
    self.frames[self.current_frame].stats.commands_allocated += 1;
}

pub fn addBytesUsed(self: *FrameAllocator, bytes: usize) void {
    self.frames[self.current_frame].stats.bytes_used += bytes;
}

pub fn uuidAlloc(self: *FrameAllocator) ?*[]u8 {
    self.frames[self.current_frame].stats.bytes_used += 16;
    var slice = self.frames[self.current_frame].arena.allocator().alloc(u8, 16) catch {
        Vapor.printlnSrcErr("UUID Alloc Failed\n", .{}, @src());
        // or the backing allocator fails.
        return null;
    };
    return &slice;
}

pub fn queryBytesUsed(self: *FrameAllocator) usize {
    const total = self.frames[self.current_frame].arena.queryCapacity();
    Vapor.println("String Bytes {d}", .{self.frames[self.current_frame].stats.bytes_used});
    Vapor.println("Nodes {d}", .{self.frames[self.current_frame].stats.nodes_memory});
    Vapor.println("Commands {d}", .{self.frames[self.current_frame].stats.command_memory});
    Vapor.println("Tree {d}", .{self.frames[self.current_frame].stats.tree_memory});
    Vapor.println("Other {d}", .{total - self.frames[self.current_frame].stats.bytes_used - self.frames[self.current_frame].stats.nodes_memory - self.frames[self.current_frame].stats.tree_memory - self.frames[self.current_frame].stats.command_memory});
    return total;
}

pub fn queryNodes(self: *FrameAllocator) usize {
    const total = self.frames[self.current_frame].stats.nodes_allocated;
    Vapor.println("-------------Nodes Allocated {d}", .{self.frames[self.current_frame].stats.nodes_allocated});
    return total;
}

/// Get allocator for data that should persist across frames
pub fn persistentAllocator(self: *FrameAllocator) std.mem.Allocator {
    return self.persistent_arena.allocator();
}

/// Start a new frame - swaps buffers and clears the old one
pub fn beginFrame(self: *FrameAllocator) void {
    if (Vapor.build_options.enable_debug and Vapor.build_options.debug_level == .all) {
        printPrevStats(self);
    }
    // Move to next frame
    const next_frame = (self.current_frame + 1) % 2;

    // Clear the frame we're about to use
    _ = self.frames[next_frame].arena.reset(.retain_capacity);
    self.frames[next_frame].stats = .{};

    self.current_frame = next_frame;
}

pub fn beginView(self: *FrameAllocator) void {
    // Move to next frame
    const next_route = (self.current_route + 1) % 2;

    // Clear the route we're about to use
    _ = self.view[next_route].arena.reset(.retain_capacity);
    self.view[next_route].stats = .{};

    self.current_route = next_route;
}

/// This is now just a simple, fast create() from the arena
pub fn commandAlloc(self: *FrameAllocator) ?*RenderCommand {
    // This is just a fast pointer bump
    const command = self.frames[self.current_frame].arena.allocator().create(RenderCommand) catch {
        // This will only fail if you run out of memory (OOM)
        // or the backing allocator fails.
        return null;
    };
    // You could even initialize the command here if needed
    return command;
}

/// This is now just a simple, fast create() from the arena
pub fn treeNodeAlloc(self: *FrameAllocator) ?*TreeNode {
    // This is just a fast pointer bump
    self.frames[self.current_frame].stats.tree_memory += @sizeOf(TreeNode);
    const tree_node = self.frames[self.current_frame].arena.allocator().create(TreeNode) catch {
        // This will only fail if you run out of memory (OOM)
        // or the backing allocator fails.
        return null;
    };
    // You could even initialize the command here if needed
    // command.* = UINode{ ... };
    return tree_node;
}

/// This is now just a simple, fast create() from the arena
pub fn nodeAlloc(self: *FrameAllocator) ?*UINode {
    // This is just a fast pointer bump
    // const node = self.persistentAllocator().create(UINode) catch {
    const node = self.frames[self.current_frame].arena.allocator().create(UINode) catch {
        // This will only fail if you run out of memory (OOM)
        // or the backing allocator fails.
        return null;
    };
    // You could even initialize the node here if needed
    return node;
}

/// Get stats for current frame
pub fn getStats(self: *FrameAllocator) Stats {
    return self.frames[self.current_frame].stats;
}

fn convertColorToString(color: Types.Color) []const u8 {
    return switch (color) {
        .Literal => |rgba| rgbaToString(rgba),
        else => "",
    };
}

fn rgbaToString(rgba: Types.Rgba) []const u8 {
    return std.fmt.allocPrint(Vapor.allocator_global, "rgba({d},{d},{d},{d})", .{
        rgba.r,
        rgba.g,
        rgba.b,
        rgba.a,
    }) catch return "";
}

pub fn printPrevStats(self: *FrameAllocator) void {
    var buffer: [4096]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    const stats = self.getStats();

    const color_buf = std.fmt.allocPrint(Vapor.allocator_global, "color: {s};", .{convertColorToString(.hex("#4800FF"))}) catch return;
    writer.print("%c", .{}) catch return;
    writer.print("╔══════════════════════════════╗\n", .{}) catch return;
    writer.print("║       Prev Frame Stats       ║\n", .{}) catch return;
    writer.print("╠══════════════════════════════╣\n", .{}) catch return;
    writer.print("║ Nodes allocated    : {d: >7} ║\n", .{stats.nodes_allocated}) catch return;
    writer.print("║ Commands allocated : {d: >7} ║\n", .{stats.commands_allocated}) catch return;
    writer.print("║ Bytes used         : {d: >7} ║\n", .{stats.bytes_used}) catch return;
    writer.print("╚══════════════════════════════╝\n", .{}) catch return;
    writer.print("%c", .{}) catch return;
    const style_2 = "";
    if (isWasi) {
        _ = Wasm.consoleLogColoredWasm(buffer[0..writer.end].ptr, buffer[0..writer.end].len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
    } else {
        // std.debug.print("{s}\n", .{buffer[0..writer.end]});
    }
}

pub fn printStats(self: *FrameAllocator) void {
    var buffer: [4096]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    const stats = self.getStats();

    const color_buf = std.fmt.allocPrint(Vapor.allocator_global, "color: {s};", .{convertColorToString(.hex("#4800FF"))}) catch return;
    writer.print("%c", .{}) catch return;
    writer.print("╔══════════════════════════════╗\n", .{}) catch return;
    writer.print("║    Frame Allocator Stats     ║\n", .{}) catch return;
    writer.print("╠══════════════════════════════╣\n", .{}) catch return;
    writer.print("║ Max Node count     : {d: >7} ║\n", .{Vapor.page_node_count}) catch return;
    writer.print("║ Nodes allocated    : {d: >7} ║\n", .{stats.nodes_allocated}) catch return;
    writer.print("║ Commands allocated : {d: >7} ║\n", .{stats.commands_allocated}) catch return;
    writer.print("║ Bytes used         : {d: >7} ║\n", .{stats.bytes_used}) catch return;
    writer.print("╚══════════════════════════════╝\n", .{}) catch return;
    writer.print("%c", .{}) catch return;
    const style_2 = "";
    if (isWasi) {
        _ = Wasm.consoleLogColoredWasm(buffer[0..writer.end].ptr, buffer[0..writer.end].len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
    } else {
        // std.debug.print("{s}\n", .{buffer[0..writer.end]});
    }
}

