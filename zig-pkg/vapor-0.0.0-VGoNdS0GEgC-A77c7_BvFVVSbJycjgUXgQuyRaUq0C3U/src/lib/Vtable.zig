const std = @import("std");

const Iterator = @This();
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    next: *const fn (ctx: *anyopaque) ?u32,
    // the init call takes a type and wraps the next function with a wrapper
    // returns a *const to and instance of the VTable struct
    pub fn init(Type: type) *const VTable {
        return &.{ .next = &struct {
            fn wrapCast(ctx: *anyopaque) ?u32 {
                const self: *Type = @ptrCast(@alignCast(ctx));
                return self.next();
            }
        }.wrapCast };
    }
};

pub fn next(self: Iterator) ?u32 {
    return self.vtable.next(self.ptr);
}

// Implemnentation of the interface!
const Range = struct {
    const Self = @This();

    start: u32 = 0,
    end: u32,
    step: u32 = 1,

    pub fn next(self: *Self) ?u32 {
        if (self.start >= self.end) return null;
        const result = self.start;
        self.start += self.step;
        return result;
    }

    // The implementation of the iterator
    pub fn iterator(self: *Self) Iterator {
        return .{ .ptr = self, .vtable = VTable.init(Self) };
    }
};
