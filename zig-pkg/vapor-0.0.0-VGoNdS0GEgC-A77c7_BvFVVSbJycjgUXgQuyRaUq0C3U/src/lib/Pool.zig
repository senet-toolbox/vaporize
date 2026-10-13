const std = @import("std");

// Pool-aware data types
pub const StringData = union(enum) {
    pool_ptr_32: struct {
        ptr: *[32]u8,
        len: u8,
    },
    pool_ptr_64: struct {
        ptr: *[64]u8,
        len: u8,
    },
    pool_ptr_128: struct {
        ptr: *[128]u8,
        len: u8,
    },
    pool_ptr_256: struct {
        ptr: *[256]u8,
        len: u8,
    },
    pool_ptr_512: struct {
        ptr: *[512]u8,
        len: u8,
    },
    pool_ptr_1024: struct {
        ptr: *[1024]u8,
        len: u16,
    },

    pub fn asSlice(self: *const StringData) []const u8 {
        // We sue pointers since The problem is that switch with capture (|d|) in Zig copies the union data, not references it.
        return switch (self.*) {
            .pool_ptr_32 => |*d| d.ptr[0..d.len],
            .pool_ptr_64 => |*d| d.ptr[0..d.len],
            .pool_ptr_128 => |*d| d.ptr[0..d.len],
            .pool_ptr_256 => |*d| d.ptr[0..d.len],
            .pool_ptr_512 => |*d| d.ptr[0..d.len],
            .pool_ptr_1024 => |*d| d.ptr[0..d.len],
        };
    }
};

const Pool = @This();
// Slots - pool of available slots
did_init: bool = false,
slot_32: [][32]u8,
slots_64: [][64]u8,
slots_128: [][128]u8,
slots_256: [][256]u8,
slots_512: [][512]u8,
slots_1024: [][1024]u8,
// Freelist - stack of available slot indices
free_list_32: []u32,
free_list_64: []u32,
free_list_128: []u32,
free_list_256: []u32,
free_list_512: []u32,
free_list_1024: []u32,
// Free count - number of free slots
free_count_32: u32,
free_count_64: u32,
free_count_128: u32,
free_count_256: u32,
free_count_512: u32,
free_count_1024: u32,

pub fn init(allocator: std.mem.Allocator, capacity: u32) !Pool {
    return Pool{
        .slot_32 = try allocator.alloc([32]u8, capacity),
        .slots_64 = try allocator.alloc([64]u8, capacity),
        .slots_128 = try allocator.alloc([128]u8, capacity),
        .slots_256 = try allocator.alloc([256]u8, capacity),
        .slots_512 = try allocator.alloc([512]u8, capacity),
        .slots_1024 = try allocator.alloc([1024]u8, capacity),
        .free_list_32 = try allocator.alloc(u32, capacity),
        .free_list_64 = try allocator.alloc(u32, capacity),
        .free_list_128 = try allocator.alloc(u32, capacity),
        .free_list_256 = try allocator.alloc(u32, capacity),
        .free_list_512 = try allocator.alloc(u32, capacity),
        .free_list_1024 = try allocator.alloc(u32, capacity),
        .free_count_32 = capacity,
        .free_count_64 = capacity,
        .free_count_128 = capacity,
        .free_count_256 = capacity,
        .free_count_512 = capacity,
        .free_count_1024 = capacity,
    };
}

pub fn initGlobalPool(allocator: std.mem.Allocator, capacity: u32) !Pool {
    return Pool{
        .slot_32 = try allocator.alloc([32]u8, capacity),
        .slots_64 = try allocator.alloc([64]u8, capacity),
        .free_list_32 = try allocator.alloc(u32, capacity),
        .free_list_64 = try allocator.alloc(u32, capacity),
        .free_count_32 = capacity,
        .free_count_64 = capacity,
    };
}
pub fn deinitGlobalPool(pool: *Pool, allocator: std.mem.Allocator) void {
    allocator.free(pool.slot_32);
    allocator.free(pool.slots_64);
    allocator.free(pool.free_list_32);
    allocator.free(pool.free_list_64);
}

pub fn resetFreeList(pool: *Pool) void {
    pool.free_count_32 = @intCast(pool.slot_32.len);
    pool.free_count_64 = @intCast(pool.slots_64.len);
    pool.free_count_128 = @intCast(pool.slots_128.len);
    pool.free_count_256 = @intCast(pool.slots_256.len);
    pool.free_count_512 = @intCast(pool.slots_512.len);
    pool.free_count_1024 = @intCast(pool.slots_1024.len);
}

pub fn deinit(pool: *Pool, allocator: std.mem.Allocator) void {
    allocator.free(pool.slot_32);
    allocator.free(pool.slots_64);
    allocator.free(pool.slots_128);
    allocator.free(pool.slots_256);
    allocator.free(pool.slots_512);
    allocator.free(pool.slots_1024);
    allocator.free(pool.free_list_32);
    allocator.free(pool.free_list_64);
    allocator.free(pool.free_list_128);
    allocator.free(pool.free_list_256);
    allocator.free(pool.free_list_512);
    allocator.free(pool.free_list_1024);
}

pub fn initFreelist(pool: *Pool) void {
    pool.did_init = true;
    // Initialize freelist with all indices

    for (0..pool.slot_32.len) |i| {
        pool.free_list_32[i] = @intCast(i);
    }

    for (0..pool.slots_64.len) |i| {
        pool.free_list_64[i] = @intCast(i);
    }

    for (0..pool.slots_128.len) |i| {
        pool.free_list_128[i] = @intCast(i);
    }

    for (0..pool.slots_256.len) |i| {
        pool.free_list_256[i] = @intCast(i);
    }

    for (0..pool.slots_512.len) |i| {
        pool.free_list_512[i] = @intCast(i);
    }

    for (0..pool.slots_1024.len) |i| {
        pool.free_list_1024[i] = @intCast(i);
    }

    pool.free_count_32 = @intCast(pool.slot_32.len);
    pool.free_count_64 = @intCast(pool.slots_64.len);
    pool.free_count_128 = @intCast(pool.slots_128.len);
    pool.free_count_256 = @intCast(pool.slots_256.len);
    pool.free_count_512 = @intCast(pool.slots_512.len);
    pool.free_count_1024 = @intCast(pool.slots_1024.len);
}

pub fn alloc_32(pool: *Pool) ?*[32]u8 {
    if (pool.free_count_32 == 0) return null;
    // Pop from freelist
    pool.free_count_32 -= 1;
    const slot_index = pool.free_list_32[pool.free_count_32];

    return &pool.slot_32[slot_index];
}

pub fn alloc_64(pool: *Pool) ?*[64]u8 {
    if (pool.free_count_64 == 0) return null;

    // Pop from freelist
    pool.free_count_64 -= 1;
    const slot_index = pool.free_list_64[pool.free_count_64];

    return &pool.slots_64[slot_index];
}

pub fn alloc_128(pool: *Pool) ?*[128]u8 {
    if (pool.free_count_128 == 0) return null;

    // Pop from freelist
    pool.free_count_128 -= 1;
    const slot_index = pool.free_list_128[pool.free_count_128];

    return &pool.slots_128[slot_index];
}

pub fn alloc_256(pool: *Pool) ?*[256]u8 {
    if (pool.free_count_256 == 0) return null;

    // Pop from freelist
    pool.free_count_256 -= 1;
    const slot_index = pool.free_list_256[pool.free_count_256];

    return &pool.slots_256[slot_index];
}

pub fn alloc_512(pool: *Pool) ?*[512]u8 {
    if (pool.free_count_512 == 0) return null;

    // Pop from freelist
    pool.free_count_512 -= 1;
    const slot_index = pool.free_list_512[pool.free_count_512];

    return &pool.slots_512[slot_index];
}

pub fn alloc_1024(pool: *Pool) ?*[1024]u8 {
    if (pool.free_count_1024 == 0) return null;

    // Pop from freelist
    pool.free_count_1024 -= 1;
    const slot_index = pool.free_list_1024[pool.free_count_1024];

    return &pool.slots_1024[slot_index];
}

pub fn free(pool: *Pool, string_data: StringData) void {
    switch (string_data) {
        .pool_ptr_32 => |d| {
            pool.free_32(d.ptr);
        },
        .pool_ptr_64 => |d| {
            pool.free_64(d.ptr);
        },
        .pool_ptr_128 => |d| {
            pool.free_128(d.ptr);
        },
        .pool_ptr_256 => |d| {
            pool.free_256(d.ptr);
        },
        .pool_ptr_512 => |d| {
            pool.free_512(d.ptr);
        },
        .pool_ptr_1024 => |d| {
            pool.free_1024(d.ptr);
        },
        else => {},
    }
}

pub fn free_32(pool: *Pool, ptr: *[32]u8) void {
    // Calculate index from pointer arithmetic
    const slot_index = (@intFromPtr(ptr) - @intFromPtr(pool.slot_32.ptr)) / 32;

    // Push back to freelist
    pool.free_list_32[pool.free_count_32] = @intCast(slot_index);
    pool.free_count_32 += 1;
}

pub fn free_64(pool: *Pool, ptr: *[64]u8) void {
    // Calculate index from pointer arithmetic
    const slot_index = (@intFromPtr(ptr) - @intFromPtr(pool.slots_64.ptr)) / 64;

    // Push back to freelist
    pool.free_list_64[pool.free_count_64] = @intCast(slot_index);
    pool.free_count_64 += 1;
}

pub fn free_128(pool: *Pool, ptr: *[128]u8) void {
    // Calculate index from pointer arithmetic
    const slot_index = (@intFromPtr(ptr) - @intFromPtr(pool.slots_128.ptr)) / 128;

    // Push back to freelist
    pool.free_list_128[pool.free_count_128] = @intCast(slot_index);
    pool.free_count_128 += 1;
}

pub fn free_256(pool: *Pool, ptr: *[256]u8) void {
    // Calculate index from pointer arithmetic
    const slot_index = (@intFromPtr(ptr) - @intFromPtr(pool.slots_256.ptr)) / 256;

    // Push back to freelist
    pool.free_list_256[pool.free_count_256] = @intCast(slot_index);
    pool.free_count_256 += 1;
}

pub fn free_512(pool: *Pool, ptr: *[512]u8) void {
    // Calculate index from pointer arithmetic
    const slot_index = (@intFromPtr(ptr) - @intFromPtr(pool.slots_512.ptr)) / 512;

    // Push back to freelist
    pool.free_list_512[pool.free_count_512] = @intCast(slot_index);
    pool.free_count_512 += 1;
}

pub fn free_1024(pool: *Pool, ptr: *[1024]u8) void {
    // Calculate index from pointer arithmetic
    const slot_index = (@intFromPtr(ptr) - @intFromPtr(pool.slots_1024.ptr)) / 1024;

    // Push back to freelist
    pool.free_list_1024[pool.free_count_1024] = @intCast(slot_index);
    pool.free_count_1024 += 1;
}

pub fn createString(pool: *Pool, data: []const u8) !StringData {
    if (!pool.did_init) return error.FreeListPoolNotInitialized;
    if (data.len <= 32) {
        const ptr = pool.alloc_32() orelse return error.ListEmpty;
        @memcpy(ptr[0..data.len], data);
        return StringData{ .pool_ptr_32 = .{
            .ptr = ptr,
            .len = @intCast(data.len),
        } };
    } else if (data.len <= 64) {
        const ptr = pool.alloc_64() orelse return error.ListEmpty;
        @memcpy(ptr[0..data.len], data);
        return StringData{ .pool_ptr_64 = .{
            .ptr = ptr,
            .len = @intCast(data.len),
        } };
    } else if (data.len <= 128) {
        const ptr = pool.alloc_128() orelse return error.ListEmpty;
        @memcpy(ptr[0..data.len], data);
        return StringData{ .pool_ptr_128 = .{
            .ptr = ptr,
            .len = @intCast(data.len),
        } };
    } else if (data.len <= 256) {
        const ptr = pool.alloc_256() orelse return error.ListEmpty;
        @memcpy(ptr[0..data.len], data);
        return StringData{ .pool_ptr_256 = .{
            .ptr = ptr,
            .len = @intCast(data.len),
        } };
    } else if (data.len <= 512) {
        const ptr = pool.alloc_512() orelse return error.ListEmpty;
        @memcpy(ptr[0..data.len], data);
        return StringData{ .pool_ptr_512 = .{
            .ptr = ptr,
            .len = @intCast(data.len),
        } };
    } else if (data.len <= 1024) {
        const ptr = pool.alloc_1024() orelse return error.ListEmpty;
        @memcpy(ptr[0..data.len], data);
        return StringData{ .pool_ptr_1024 = .{
            .ptr = ptr,
            .len = @intCast(data.len),
        } };
    } else {
        return error.StringTooLarge;
    }
}

test "string pool" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("Memmory leak...");
    const allocator = gpa.allocator();

    var pool = try Pool.init(allocator, 10);
    defer pool.deinit(allocator);

    pool.initFreelist();

    const str1 = pool.alloc_32() orelse return error.AllocFailed;
    const str2 = pool.alloc_32() orelse return error.AllocFailed;
    const str3 = pool.alloc_32() orelse return error.AllocFailed;

    pool.free_32(str1);
    pool.free_32(str2);
    pool.free_32(str3);

    try std.testing.expectEqual(pool.free_count_32, 10);
}
