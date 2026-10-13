// CSS Rules, classnames must always be with dashes, cannot use icon types
const std = @import("std");
const UITree = @import("UITree.zig");
const UINode = UITree.UINode;
const indexOf = UITree.indexOf;
const StyleWriter = @import("convertStyleCustomWriter.zig");
const generateStyle = StyleWriter.generateStyle;
const Vapor = @import("Vapor.zig");
const Writer = @import("Writer.zig");
const KeyGenerator = @import("Key.zig").KeyGenerator;
const Types = @import("types.zig");
const Packer = @import("Packer.zig");

const Generator = @This();
buffer: [8192 * 12]u8 = undefined,
start: usize = 0,
end: usize = 0,
pub fn init(gen: *Generator) void {
    gen.* = .{};
}

pub fn deinit(gen: *Generator) void {
    gen.start = 0;
    gen.end = 0;
    gen = undefined;
    gen.buffer = undefined;
}

var writer: Writer = undefined;
// -----------------------------------------------------------------------------
// SECTION 1: Original Helper Functions (Unchanged)
// -----------------------------------------------------------------------------
// These functions are already simple, single-purpose wrappers.

fn writeCss(node: *UINode) void {
    writer.writeByte('{') catch {};
    writer.writeByte('\n') catch {};
    StyleWriter.generateStylePass(node, &writer);
    writer.writeByte('}') catch {};
    writer.writeByte('\n') catch {};
}

fn writeLayout(layout_ptr: *const Types.PackedLayout) void {
    StyleWriter.generateLayout(layout_ptr, &writer);
}

fn writeVisual(visual_ptr: *const Types.PackedVisual) void {
    StyleWriter.generateVisual(visual_ptr, &writer);
}

fn writeInteractive(interactive_ptr: *const Types.PackedInteractive) void {
    const hover = interactive_ptr.hover;
    const hover_position = interactive_ptr.hover_position;
    StyleWriter.generateVisual(&hover, &writer);
    StyleWriter.generatePositions(&hover_position, &writer);
}

fn writeAnimation(animation_ptr: *const Types.PackedAnimations) void {
    StyleWriter.generateAnimations(animation_ptr, &writer);
}

fn writePos(pos_ptr: *const Types.PackedPosition) void {
    StyleWriter.generatePositions(pos_ptr, &writer);
}

fn writeMarginPaddings(margin_paddings_ptr: *const Types.PackedMarginsPaddings) void {
    StyleWriter.generateMarginsPadding(margin_paddings_ptr, &writer);
}

fn writeToken(token: []const u8) void {
    writer.writeByte('.') catch {};
    writer.write(token) catch {};
    writer.writeByte('{') catch {};
    writer.writeByte('\n') catch {};
}

// -----------------------------------------------------------------------------
// SECTION 2: New & Refactored Helper Functions
// -----------------------------------------------------------------------------

/// NEW: This helper just performs the buffer copy.
fn appendWriterToGenerator(gen: *Generator) void {
    const len: usize = writer.pos;
    gen.end += len;
    @memcpy(gen.buffer[gen.start..gen.end], writer.buffer[0..len]);
    gen.start += len;
}

/// REFACTORED: Now uses the new appendWriterToGenerator helper.
fn writeToGlobal(gen: *Generator) void {
    writer.writeByte('}') catch {};
    writer.writeByte('\n') catch {};
    appendWriterToGenerator(gen);
}

/// NEW: This generic function replaces ALL the loops in `writeAllStyles`.
fn writeCommonStyleGroup(
    gen: *Generator,
    allocator: std.mem.Allocator,
    map: anytype,
    class_prefix: []const u8,
    key_buf: *[128]u8,
    write_fn: anytype,
    token_suffix: ?[]const u8,
) void {
    var itr = map.iterator();
    while (itr.next()) |entry| {
        const hash = entry.key_ptr.*;
        const value_ptr = entry.value_ptr.*;
        const common_key = KeyGenerator.generateHashKey(key_buf, hash, class_prefix);

        var local_buffer: [4096]u8 = undefined;
        writer.init(local_buffer[0..]);

        if (token_suffix) |suffix| {
            // Handle special cases like ":hover"
            const full_token = std.fmt.allocPrint(allocator, "{s}{s}", .{ common_key, suffix }) catch unreachable;
            writeToken(full_token);
            // No free needed, `allocator` is a frame allocator
        } else {
            writeToken(common_key);
        }

        write_fn(value_ptr); // Call the specific function (e.g., writeLayout)
        gen.writeToGlobal();
    }
}

/// NEW: This helper consolidates the repeated logic in `writeNodeStyle`.
fn writeFullNodeRule(gen: *Generator, node: *UINode, selector: []const u8) void {
    var buffer: [4096]u8 = undefined;
    writer.init(buffer[0..]);

    writer.writeByte('.') catch {};
    writer.write(selector) catch {};

    writeCss(node); // This writes the full { ...styles... } block

    appendWriterToGenerator(gen);
}

// -----------------------------------------------------------------------------
// SECTION 3: Consolidated Public Functions
// -----------------------------------------------------------------------------

/// REFACTORED: Now dramatically simpler, just calls the new helper.
pub fn writeAllStyles(gen: *Generator) void {
    const allocator = Vapor.arena(.frame);
    var key_buf: [128]u8 = undefined; // Shared buffer for key generation

    writeCommonStyleGroup(gen, allocator, &Packer.layouts, "lay", &key_buf, writeLayout, null);
    writeCommonStyleGroup(gen, allocator, &Packer.visuals, "vis", &key_buf, writeVisual, null);
    writeCommonStyleGroup(gen, allocator, &Packer.positions, "pos", &key_buf, writePos, null);
    writeCommonStyleGroup(gen, allocator, &Packer.margins_paddings, "mapa", &key_buf, writeMarginPaddings, null);

    // Special cases with ":hover"
    writeCommonStyleGroup(gen, allocator, &Packer.interactives, "intr", &key_buf, writeInteractive, ":hover");
    writeCommonStyleGroup(gen, allocator, &Packer.animations, "anim", &key_buf, writeAnimation, ":hover");
}

/// REFACTORED: Now uses the `writeFullNodeRule` helper.
pub fn writeNodeStyle(gen: *Generator, node: *UINode) void {
    const class = node.class;

    if (class) |c| {
        var tokenized = std.mem.tokenizeScalar(u8, c, ' ');
        while (tokenized.next()) |token| {
            if (contains(token, "genk")) {
                // Generate the "fbc-..." selector
                var fbc_buf: [256]u8 = undefined; // Buffer for UUID string
                const fbc_selector = std.fmt.bufPrint(&fbc_buf, "fbc-{s}", .{node.uuid}) catch unreachable;
                writeFullNodeRule(gen, node, fbc_selector);
            } else if (token.len > 0 and node.type != .Icon) {
                writeFullNodeRule(gen, node, token);
            }
        }
    }
}

pub fn printCSS(gen: *Generator) void {
    const buffer = gen.buffer[0..gen.end];
    Vapor.println("{s}", .{buffer});
}

pub fn getCSS(gen: *Generator) []const u8 {
    return gen.buffer[0..gen.end];
}

/// Uses SIMD to check if a needle exists within a haystack.
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
    // // 1. Handle edge cases.
    // if (needle.len == 0) return true;
    // if (haystack.len < needle.len) return false;
    //
    // // Use a 32-byte vector (256 bits), common for AVX2.
    // const VEC_LEN = 32;
    // // For shorter needles, a scalar search is often faster.
    // if (haystack.len < VEC_LEN) {
    //     return std.mem.indexOf(u8, haystack, needle) != null;
    // }
    // const Vec = @Vector(VEC_LEN, u8);
    //
    // // 2. Prepare for the SIMD search.
    // // Create vectors with the first and last characters of the needle
    // // repeated across all lanes.
    // const first_splat: Vec = @splat(needle[0]);
    // const last_splat: Vec = @splat(needle[needle.len - 1]);
    //
    // var i: usize = 0;
    //
    // // 3. Main SIMD loop.
    // // Process the haystack in VEC_LEN-byte chunks.
    // while (i + needle.len - 1 + VEC_LEN <= haystack.len) : (i += VEC_LEN) {
    //     // Load a vector starting at `i`.
    //     const v1: Vec = @bitCast(haystack[i..][0..VEC_LEN].*);
    //     // Load a second vector, offset to align with the needle's last character.
    //     const v2: Vec = @bitCast(haystack[i + needle.len - 1 ..][0..VEC_LEN].*);
    //
    //     // Compare v1 to the first character and v2 to the last character.
    //     const eq_first = v1 == first_splat;
    //     const eq_last = v2 == last_splat;
    //
    //     // Combine the results. A '1' indicates a potential match where both
    //     // the first and last characters are in the correct positions.
    //     const combined_mask = eq_first & eq_last;
    //
    //     // Cast the boolean vector mask to an integer to quickly check for any matches.
    //     var bits: u32 = @bitCast(combined_mask);
    //
    //     // 4. Verify potential matches.
    //     // If bits is non-zero, we have one or more potential candidates in this chunk.
    //     while (bits != 0) {
    //         // Find the index of the candidate within the vector.
    //         const offset = @ctz(bits); // Count Trailing Zeros
    //         const match_start_index = i + offset;
    //
    //         // Perform a full, precise comparison to confirm the match.
    //         if (std.mem.eql(u8, needle, haystack[match_start_index..][0..needle.len])) {
    //             return true; // Found it!
    //         }
    //
    //         // Clear the checked bit and continue to the next candidate in the chunk.
    //         bits &= (bits - 1);
    //     }
    // }
    //
    // // 5. Handle the remainder.
    // // Check the final portion of the haystack that didn't fit into a full vector chunk.
    // if (std.mem.indexOf(u8, haystack[i..], needle) != null) {
    //     return true;
    // }
    //
    // return false;
}
