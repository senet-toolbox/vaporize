const std = @import("std");
const Vapor = @import("Vapor.zig");
const UINode = @import("UITree.zig").UINode;
const ElementType = @import("types.zig").ElementType;
const Writer = @import("Writer.zig");

var hasher = std.hash.Wyhash.init(5213);
var buf_128: [128]u8 = undefined;
var writer: Writer = undefined;
pub const KeyGenerator = struct {
    // Thread-local call counter that resets each render cycle
    var call_counter: usize = 0;
    var component_index: usize = 0;

    // Call this at the beginning of each render cycle
    pub fn resetCounter() void {
        call_counter = 0;
    }

    // Call this at the beginning of each render cycle
    pub fn incrementCount() void {
        call_counter += 1;
    }

    pub fn incrementComponentCount() void {
        component_index += 1;
    }

    // Call this at the beginning of each render cycle
    pub fn getCount() usize {
        return call_counter;
    }

    pub fn getComponentCount() usize {
        return component_index;
    }

    // Call this at the beginning of each render cycle
    pub fn setCount(count: usize) void {
        call_counter = count;
    }

    pub fn setComponentCount(count: usize) void {
        component_index = count;
    }

    pub fn initWriter() void {
        writer.init(&buf_128);
    }

    pub fn generateCommonStyleKey(ids: []const []const u8, allocator: *std.mem.Allocator) []const u8 {

        // Hash all the IDs in order
        for (ids) |id| {
            hasher.update(id);
        }

        // Generate the final hash
        const hash = hasher.final();

        // Convert to UUID-like string (128-bit represented as hex)
        const result = std.fmt.allocPrint(allocator.*, "common-{x:0>16}", .{hash}) catch |err| {
            Vapor.printlnSrcErr("Could not allocate common style key: {any}", .{err}, @src());
            return "fallback-common-key";
        };

        return result;
    }

    pub fn generateStyleKey(tag: []const u8, ids: []const []const u8, allocator: *std.mem.Allocator) []const u8 {

        // Hash all the IDs in order
        for (ids) |id| {
            hasher.update(id);
        }

        // Generate the final hash
        const hash = hasher.final();

        // Convert to UUID-like string (128-bit represented as hex)
        const result = std.fmt.allocPrint(allocator.*, "{s}-{x:0>16}", .{ tag, hash }) catch |err| {
            Vapor.printlnSrcErr("Could not allocate common style key: {any}", .{err}, @src());
            return "fallback-common-key";
        };

        return result;
    }

    pub fn hashKey(key: []const u8) u32 {
        var h: u32 = 5381;
        for (key) |char| {
            h = ((h << 5) +% h) +% char;
        }
        h = h *% 2654435761;
        return h;
    }

    pub fn generateHashKey(
        buf: []u8,
        hash: u32,
        tag: []const u8,
    ) []const u8 {
        // writer.init(&buf_128);
        writer.reset();
        writer.write(tag) catch "";
        writer.writeByte('_') catch "";
        writer.writeU32(hash) catch "";
        const key = writer.buffer[0..writer.pos];
        @memcpy(buf[0..key.len], key);
        return buf[0..key.len];
    }

    pub fn generateHashKeyAlloc(
        allocator: *std.mem.Allocator,
        hash: u32,
        tag: []const u8,
    ) []const u8 {
        const result = std.fmt.allocPrint(allocator.*, "{s}-{any}", .{ tag, hash }) catch |err| {
            Vapor.printlnSrcErr("Could not allocate common style key: {any}", .{err}, @src());
            return "fallback-common-key";
        };

        return result;
    }

    pub fn generateKey_(
        uuid_buf: []u8,
        elem_type: ElementType,
        parent_type: ElementType,
        index: usize,
        depth: usize,
    ) []const u8 {

        // const key = std.fmt.bufPrint(uuid_buf, "{s}-{d}-{d}-genk", .{
        //     @tagName(elem_type),
        //     call_counter,
        //     index orelse 0
        // }) catch |err| {
        //     // This will fail if uuid_buf is too small.
        //     // For a UI, you might want to panic() in debug
        //     // or return a default key.
        //     Vapor.println("Failed to generate key: {any}\n", .{err});
        //     return "";
        // };
        // return key;

        // call_counter += 1;
        // component_index += 1;
        writer.reset();
        const tag_name: usize = @intFromEnum(elem_type);
        const tag_parent: usize = @intFromEnum(parent_type);
        // writer.write(tag_name) catch unreachable;
        // writer.write(parent_key) catch "";
        // writer.write(tag_parent[0..@min(4, tag_parent.len)]) catch "";
        writer.writeUsize(tag_parent) catch unreachable;
        writer.writeUsize(tag_name) catch unreachable;
        // writer.writeByte('_') catch unreachable;
        writer.writeUsize(depth) catch unreachable;
        // writer.writeByte('_') catch unreachable;
        writer.writeUsize(index) catch unreachable;
        // const hash = std.hash.XxHash32.hash(0, writer.buffer[0..writer.pos]);
        // writer.reset();
        // writer.writeU32(43644629) catch "";
        // writer.writeByte('_') catch "";
        // writer.write(tag_name[0..@min(4, tag_name.len)]) catch "";
        // writer.write("-genk") catch "";
        const key = writer.buffer[0..writer.pos];
        @memcpy(uuid_buf[0..key.len], key);
        return uuid_buf[0..key.len];
    }

    pub fn u32ToBase36(value: u32, buffer: []u8) []u8 {
        // Maximum length for u32 in base36 is 7 characters (36^7 > 2^32).
        // Ensure buffer has at least 8 bytes (7 chars + null terminator).
        if (buffer.len < 8) @panic("Buffer too small for base36 u32");

        var v = value;
        var i: usize = buffer.len - 1;

        // Null-terminate
        buffer[i] = 0;

        // Handle zero explicitly
        if (v == 0) {
            i -= 1;
            buffer[i] = '0';
            return buffer[i..];
        }

        while (v > 0) {
            i -= 1;
            const digit = v % 36;
            v /= 36;
            buffer[i] = if (digit < 10)
                @as(u8, @intCast('0' + digit))
            else
                @as(u8, @intCast('a' + (digit - 10)));
        }

        return buffer[i..];
    }

    pub fn generateKey(
        uuid_buf: []u8,
        elem_type: ElementType,
        parent_key: []const u8,
        depth: usize,
    ) []const u8 {
        const index = getComponentCount();
        // call_counter += 1;
        // component_index += 1;
        writer.init(&buf_128);
        const tag_name = @tagName(elem_type);
        writer.write(tag_name) catch "";
        writer.write(parent_key) catch "";
        writer.writeUsize(depth) catch "";
        writer.writeUsize(index) catch "";
        const hash = hashKey(writer.buffer[0..writer.pos]);
        writer.reset();
        writer.write(tag_name[0..@min(4, tag_name.len)]) catch "";
        writer.writeByte('_') catch "";
        writer.writeU32(hash) catch "";
        writer.write("-genk") catch "";
        const key = writer.buffer[0..writer.pos];
        @memcpy(uuid_buf[0..key.len], key);
        return uuid_buf[0..key.len];
    }

    // Similar update for generateListItemKey
    pub fn generateListItemKey(
        parent_key: []const u8,
        item_key: anytype,
        index: usize,
    ) []const u8 {
        // Increment call counter for each component creation
        const current_count = call_counter;
        call_counter += 1;

        // Include parent key in the hash
        hasher.update(parent_key);

        // Include the call counter
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{current_count}) catch &count_buf;
        hasher.update(count_str);

        // Include index for stability even if order changes
        var idx_buf: [16]u8 = undefined;
        const idx_str = std.fmt.bufPrint(&idx_buf, "{d}", .{index}) catch &idx_buf;
        hasher.update(idx_str);

        // Include the item key if it's a string
        if (@TypeOf(item_key) == []const u8) {
            hasher.update(item_key);
        } else {
            // Convert non-string keys to string
            var key_buf: [32]u8 = undefined;
            const key_str = std.fmt.bufPrint(&key_buf, "{any}", .{item_key}) catch &key_buf;
            hasher.update(key_str);
        }

        // Generate the final hash
        const hash = hasher.final();

        // Convert hash to a readable string
        var buf: [64]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "li_{x}_{d}_{d}", .{ hash, index, current_count }) catch &buf;

        // Allocate permanent storage for the key
        var allocator = std.heap.page_allocator;
        const result = allocator.alloc(u8, key.len) catch return "fallback_key";
        std.mem.copy(u8, result, key);

        return result;
    }
};
