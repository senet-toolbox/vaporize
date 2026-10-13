const std = @import("std");
const Vapor = @import("Vapor.zig");
const UINode = @import("UITree.zig").UINode;
const NodePool = @This();
slots: []UINode,
free_count: usize,

pub fn init(allocator: std.mem.Allocator, capacity: usize) !NodePool {
    if (capacity == 0) return error.CapacityCannotBeZero;
    return NodePool{
        .slots = try allocator.alloc(UINode, capacity),
        .free_count = capacity,
    };
}

pub fn deinit(pool: *NodePool, allocator: std.mem.Allocator) void {
    allocator.free(pool.slots);
}

pub fn resetFreeList(pool: *NodePool) void {
    pool.free_count = @intCast(pool.slots.len);
}

pub fn alloc(pool: *NodePool) ?*UINode {
    if (pool.free_count == 0) return null;
    // Pop from freelist
    pool.free_count -= 1;
    const slot_index = pool.free_count;

    return &pool.slots[slot_index];
}
