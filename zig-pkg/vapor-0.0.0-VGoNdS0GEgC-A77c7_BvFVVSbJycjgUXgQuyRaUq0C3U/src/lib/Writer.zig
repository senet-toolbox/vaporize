const std = @import("std");
const Writer = @This();
buffer: []u8,
size: usize,
pos: usize,

pub fn init(writer: *Writer, buffer: []u8) void {
    writer.* = .{
        .buffer = buffer,
        .size = buffer.len,
        .pos = 0,
    };
}

pub fn reset(self: *Writer) void {
    self.pos = 0;
}

pub fn writeByte(self: *Writer, byte: u8) !void {
    self.buffer[self.pos] = byte;
    self.pos += 1;
}

pub fn writeU8Num(self: *Writer, byte: u8) !void {
    const u32_string = fastLargeIntToString(byte);
    @memcpy(self.buffer[self.pos .. self.pos + u32_string.len], u32_string);
    self.pos += u32_string.len;
}

pub fn write(self: *Writer, value: []const u8) !void {
    @memcpy(self.buffer[self.pos .. self.pos + value.len], value);
    self.pos += value.len;
}

pub fn writeF32(self: *Writer, value: f32) !void {
    const f32_string = fastFloatToString(value);
    @memcpy(self.buffer[self.pos .. self.pos + f32_string.len], f32_string);
    self.pos += f32_string.len;
}

pub fn writeF16(self: *Writer, value: f16) !void {
    const f16_string = fastFloatToString(value);
    @memcpy(self.buffer[self.pos .. self.pos + f16_string.len], f16_string);
    self.pos += f16_string.len;
}

var float_buffer_16: [32]u8 = undefined;
fn fastFloat16ToString(value: f16) []const u8 {
    // Handle special cases
    if (std.math.isNan(value)) return "NaN";
    if (std.math.isInf(value)) return if (value > 0) "Infinity" else "-Infinity";
    if (value == 0.0) return "0";

    var buf_idx: usize = 0;
    var n = value;

    // Handle negative numbers
    if (n < 0) {
        float_buffer_16[buf_idx] = '-';
        buf_idx += 1;
        n = -n;
    }

    // Split into integer and fractional parts
    const int_part = @as(u32, @intFromFloat(@floor(n)));
    const frac_part = n - @floor(n);

    // Convert integer part
    if (int_part == 0) {
        float_buffer_16[buf_idx] = '0';
        buf_idx += 1;
    } else {
        const start_idx = buf_idx;
        var temp = int_part;

        // Get digits in reverse order
        while (temp > 0) {
            float_buffer_16[buf_idx] = @as(u8, @intCast(temp % 10)) + '0';
            buf_idx += 1;
            temp /= 10;
        }

        // Reverse the integer part
        std.mem.reverse(u8, float_buffer_16[start_idx..buf_idx]);
    }

    // Add decimal point and fractional part if needed
    if (frac_part > 0.0) {
        float_buffer_16[buf_idx] = '.';
        buf_idx += 1;

        var frac = frac_part;
        var precision: u8 = 0;
        const max_precision: u8 = 6; // Limit decimal places

        while (frac > 0.0 and precision < max_precision) {
            frac *= 10.0;
            const digit = @as(u8, @intFromFloat(@floor(frac)));
            float_buffer_16[buf_idx] = digit + '0';
            buf_idx += 1;
            frac = frac - @floor(frac);
            precision += 1;
        }

        // Remove trailing zeros
        while (buf_idx > 0 and float_buffer_16[buf_idx - 1] == '0') {
            buf_idx -= 1;
        }

        // Remove trailing decimal point if no fractional part remains
        if (buf_idx > 0 and float_buffer_16[buf_idx - 1] == '.') {
            buf_idx -= 1;
        }
    }

    return float_buffer_16[0..buf_idx];
}

var float_buffer: [32]u8 = undefined;
fn fastFloatToString(value: f32) []const u8 {
    // Handle special cases
    if (std.math.isNan(value)) return "NaN";
    if (std.math.isInf(value)) return if (value > 0) "Infinity" else "-Infinity";
    if (value == 0.0) return "0";

    var buf_idx: usize = 0;
    var n = value;

    // Handle negative numbers
    if (n < 0) {
        float_buffer[buf_idx] = '-';
        buf_idx += 1;
        n = -n;
    }

    // Split into integer and fractional parts
    const int_part = @as(u32, @intFromFloat(@floor(n)));
    const frac_part = n - @floor(n);

    // Convert integer part
    if (int_part == 0) {
        float_buffer[buf_idx] = '0';
        buf_idx += 1;
    } else {
        const start_idx = buf_idx;
        var temp = int_part;

        // Get digits in reverse order
        while (temp > 0) {
            float_buffer[buf_idx] = @as(u8, @intCast(temp % 10)) + '0';
            buf_idx += 1;
            temp /= 10;
        }

        // Reverse the integer part
        std.mem.reverse(u8, float_buffer[start_idx..buf_idx]);
    }

    // Add decimal point and fractional part if needed
    if (frac_part > 0.0) {
        float_buffer[buf_idx] = '.';
        buf_idx += 1;

        var frac = frac_part;
        var precision: u8 = 0;
        const max_precision: u8 = 6; // Limit decimal places

        while (frac > 0.0 and precision < max_precision) {
            frac *= 10.0;
            const digit = @as(u8, @intFromFloat(@floor(frac)));
            float_buffer[buf_idx] = digit + '0';
            buf_idx += 1;
            frac = frac - @floor(frac);
            precision += 1;
        }

        // Remove trailing zeros
        while (buf_idx > 0 and float_buffer[buf_idx - 1] == '0') {
            buf_idx -= 1;
        }

        // Remove trailing decimal point if no fractional part remains
        if (buf_idx > 0 and float_buffer[buf_idx - 1] == '.') {
            buf_idx -= 1;
        }
    }

    return float_buffer[0..buf_idx];
}

pub fn writeI32(self: *Writer, value: i32) !void {
    const remaining_buffer = self.buffer[self.pos..];
    const formatted = try std.fmt.bufPrint(remaining_buffer, "{d}", .{value});
    self.pos += formatted.len;
}

pub fn writeI16(self: *Writer, value: i16) !void {
    const remaining_buffer = self.buffer[self.pos..];
    const formatted = try std.fmt.bufPrint(remaining_buffer, "{d}", .{value});
    self.pos += formatted.len;
}

pub fn writeU16(self: *Writer, value: u16) !void {
    const u32_string = fastLargeIntToString(value);
    @memcpy(self.buffer[self.pos .. self.pos + u32_string.len], u32_string);
    self.pos += u32_string.len;
}

pub fn writeUsize(self: *Writer, value: usize) !void {
    const u32_string = fastLargeIntToString(value);
    @memcpy(self.buffer[self.pos .. self.pos + u32_string.len], u32_string);
    self.pos += u32_string.len;
}

var large_int_buffer: [32]u8 = undefined;
fn fastLargeIntToString(value: anytype) []const u8 {
    if (value == 0) return "0";

    var buf_idx: usize = large_int_buffer.len;
    var n = value;

    // Convert digits from right to left
    while (n > 0) {
        buf_idx -= 1;
        large_int_buffer[buf_idx] = @as(u8, @intCast(n % 10)) + '0';
        n /= 10;
    }

    return large_int_buffer[buf_idx..];
}




fn fastLargeF32ToString(value: f32) []const u8 {
    if (value == 0) return "0";

    var buf_idx: usize = large_int_buffer.len;
    var n = value;

    // Convert digits from right to left
    while (n > 0) {
        buf_idx -= 1;
        large_int_buffer[buf_idx] = @as(u8, @intCast(n % 10)) + '0';
        n /= 10;
    }

    return large_int_buffer[buf_idx..];
}

pub fn writeU32(self: *Writer, value: u32) !void {
    const u32_string = fastLargeIntToString(value);
    @memcpy(self.buffer[self.pos .. self.pos + u32_string.len], u32_string);
    self.pos += u32_string.len;
}

pub fn print(self: *Writer) !void {
    const len: usize = self.pos;
    self.buffer[len] = 0;
}
