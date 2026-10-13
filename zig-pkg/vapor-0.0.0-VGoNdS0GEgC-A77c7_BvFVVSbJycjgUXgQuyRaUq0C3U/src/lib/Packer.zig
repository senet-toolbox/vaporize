const std = @import("std");
const types = @import("types.zig");

const Packer = @This();

pub var visuals: std.AutoHashMap(u32, *const types.PackedVisual) = undefined;
pub var layouts: std.AutoHashMap(u32, *const types.PackedLayout) = undefined;
pub var positions: std.AutoHashMap(u32, *const types.PackedPosition) = undefined;
pub var margins_paddings: std.AutoHashMap(u32, *const types.PackedMarginsPaddings) = undefined;
pub var animations: std.AutoHashMap(u32, *const types.PackedAnimations) = undefined;
pub var interactives: std.AutoHashMap(u32, *const types.PackedInteractive) = undefined;
pub var layouts_pool: std.heap.MemoryPool(types.PackedLayout) = undefined;
pub var positions_pool: std.heap.MemoryPool(types.PackedPosition) = undefined;
pub var margins_paddings_pool: std.heap.MemoryPool(types.PackedMarginsPaddings) = undefined;
pub var visuals_pool: std.heap.MemoryPool(types.PackedVisual) = undefined;
pub var animations_pool: std.heap.MemoryPool(types.PackedAnimations) = undefined;
pub var interactives_pool: std.heap.MemoryPool(types.PackedInteractive) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    initPackedData(allocator);
    initPools(allocator);
}

fn initPackedData(persistent_allocator: std.mem.Allocator) void {
    visuals = std.AutoHashMap(u32, *const types.PackedVisual).init(persistent_allocator);
    layouts = std.AutoHashMap(u32, *const types.PackedLayout).init(persistent_allocator);
    positions = std.AutoHashMap(u32, *const types.PackedPosition).init(persistent_allocator);
    margins_paddings = std.AutoHashMap(u32, *const types.PackedMarginsPaddings).init(persistent_allocator);
    animations = std.AutoHashMap(u32, *const types.PackedAnimations).init(persistent_allocator);
    interactives = std.AutoHashMap(u32, *const types.PackedInteractive).init(persistent_allocator);
}

fn initPools(persistent_allocator: std.mem.Allocator) void {
    layouts_pool = std.heap.MemoryPool(types.PackedLayout).init(persistent_allocator);
    positions_pool = std.heap.MemoryPool(types.PackedPosition).init(persistent_allocator);
    margins_paddings_pool = std.heap.MemoryPool(types.PackedMarginsPaddings).init(persistent_allocator);
    visuals_pool = std.heap.MemoryPool(types.PackedVisual).init(persistent_allocator);
    animations_pool = std.heap.MemoryPool(types.PackedAnimations).init(persistent_allocator);
    interactives_pool = std.heap.MemoryPool(types.PackedInteractive).init(persistent_allocator);
}
