const std = @import("std");
const mem = std.mem;
const Types = @import("types.zig");
const Alignment = Types.Alignment;
const Direction = Types.Direction;
const PositionType = Types.PositionType;
const UINode = @import("UITree.zig").UINode;
const Hover = Types.Hover;
const Sizing = Types.Sizing;
const FlexType = Types.FlexType;
const Pos = Types.Pos;
const Background = Types.Background;
const Transform = Types.Transform;
const RenderCommand = Types.RenderCommand;
const println = @import("Fabric.zig").println;

// Global buffer to store the CSS string for returning to JavaScript
var css_buffer: [4096]u8 = undefined;

// Helper function to convert Direction enum to CSS flex-direction
fn directionToCSS(dir: Direction) []const u8 {
    return switch (dir) {
        .column => "column",
        .row => "row",
    };
}

// Helper function to convert Alignment to CSS values
fn alignmentToCSS(_align: Alignment) []const u8 {
    return switch (_align) {
        .center => "center",
        .top => "flex-start",
        .bottom => "flex-end",
        .start => "flex-start",
        .end => "flex-end",
        .between => "space-between",
        .even => "space-evenly",
    };
}

// Helper function to convert PositionType to CSS values
fn positionTypeToCSS(pos_type: PositionType) []const u8 {
    return switch (pos_type) {
        .relative => "relative",
        .absolute => "absolute",
        .fixed => "fixed",
        .sticky => "sticky",
    };
}

fn posTypeToCSS(pos: Pos, writer: anytype) !void {
    switch (pos.type) {
        .fit => try writer.writeAll("fit-content"),
        .grow => try writer.writeAll("auto"),
        .percent => try writer.print("{d}%", .{pos.value * 100}),
        .fixed => try writer.print("{d}px", .{pos.value}),
    }
}

// Helper function to convert SizingType to CSS values
fn sizingTypeToCSS(sizing: Sizing, writer: anytype) !void {
    switch (sizing.type) {
        .fit => try writer.writeAll("fit-content"),
        .percent => try writer.print("{d}%", .{sizing.size.minmax.min}),
        .fixed => try writer.print("{d}px", .{sizing.size.minmax.min}),
        .elastic => try writer.writeAll("auto"), // Could also use min/max width/height in separate properties
        .elastic_percent => try writer.print("{d}%", .{sizing.size.percent.min}),
        .clamp_px => try writer.print("clamp({d}px,{d}px,{d}px)", .{ sizing.size.clamp_px.min, sizing.size.clamp_px.preferred, sizing.size.clamp_px.max }),
        .clamp_percent => try writer.print("clamp({d}%,{d}%,{d}%)", .{ sizing.size.clamp_px.min, sizing.size.clamp_px.preferred, sizing.size.clamp_px.max }),
        .none, .grow => {},
        else => {},
    }
}

// Function to convert FlexType enum to a CSS string
fn flexTypeToCSS(flex_type: FlexType, writer: anytype) !void {
    switch (flex_type) {
        .Flex, .Center => try writer.writeAll("flex"),
        .Stack => try writer.writeAll("block"),
        .Flow => try writer.writeAll("inline-block"),
        .None => try writer.writeAll("none"),
    }
}

// Helper function to convert color array to CSS rgba
fn colorToCSS(color: Background, writer: anytype) !void {
    const alpha = @as(f32, @floatFromInt(color.a)) / 255.0;
    try writer.print("rgba({d}, {d}, {d}, {d})", .{
        color.r,
        color.g,
        color.b,
        alpha,
    });
}

// Function to convert TransformType to CSS
fn transformToCSS(transform: Transform, writer: anytype) !void {
    switch (transform.type) {
        .none => {},
        .scale => try writer.print("scale({d})", .{transform.scale_size}),
        .scaleY => try writer.print("scaleY({d})", .{transform.scale_size}),
        .scaleX => try writer.print("scaleX({d})", .{transform.scale_size}),
        .translateX => try writer.print("translateX({d})", .{transform.dist}),
        .translateY => try writer.print("translateY({d})", .{transform.dist}),
    }
}

// Export this function to be called from JavaScript to get the CSS representation
var hover_style: []const u8 = "";
var global_len: usize = 0;
pub export fn __getHoverStyle(node_ptr: ?*UINode) ?[*]const u8 {
    if (node_ptr == null) return hover_style.ptr;
    _ = node_ptr.?.style orelse return null;
    // const hover = style.hover.?;
    // // Create a default Hover style
    // // const hover = Hover{};
    //
    // // Use a fixed buffer with a fbs to build the CSS string
    // var fbs = std.io.fixedBufferStream(&css_buffer);
    // var writer = fbs.writer();
    //
    // // Start CSS block
    // // writer.writeAll("{\n") catch {};
    //
    // // Write position properties
    // if (hover.position) |hp| {
    //     writer.print("  position: {s};\n", .{positionTypeToCSS(hp.type)}) catch {};
    //     writer.writeAll("  left: ") catch {};
    //     posTypeToCSS(hp.left, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    //
    //     writer.writeAll("  right: ") catch {};
    //     posTypeToCSS(hp.right, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    //
    //     writer.writeAll("  top: ") catch {};
    //     posTypeToCSS(hp.top, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    //
    //     writer.writeAll("  bottom: ") catch {};
    //     posTypeToCSS(hp.bottom, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }
    //
    // if (hover.display) |d| {
    //     writer.writeAll("  display: ") catch {};
    //     flexTypeToCSS(d, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }
    //
    // // Write display and flex properties
    // // writer.writeAll("  display: flex;\n") catch {};
    // if (hover.direction) |hd| {
    //     writer.print("  flex-direction: {s};\n", .{directionToCSS(hd)}) catch {};
    // }
    //
    // // Write width and height
    // if (hover.width) |hw| {
    //     if (hw.type != .none) {
    //         writer.writeAll("  width: ") catch {};
    //         sizingTypeToCSS(hw, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    // }
    //
    // if (hover.height) |hh| {
    //     if (hh.type != .none) {
    //         writer.writeAll("  height: ") catch {};
    //         sizingTypeToCSS(hh, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    // }
    //
    // // Write font properties
    // if (hover.font_size) |fs| {
    //     writer.print("  font-size: {d}px;\n", .{fs}) catch {};
    // }
    // if (hover.letter_spacing) |ls| {
    //     writer.print("  letter-spacing: {d}px;\n", .{@as(f32, @floatFromInt(ls)) / 1000.0}) catch {};
    // }
    // if (hover.line_height) |lh| {
    //     writer.print("  line-height: {d}px;\n", .{lh}) catch {};
    // }
    //
    // if (hover.font_weight) |hf| {
    //     if (hf > 0) {
    //         writer.print("  font-weight: {d};\n", .{hf}) catch {};
    //     }
    // }
    //
    // // Border properties
    // if (hover.border_thickness) |hbt| {
    //     if (hbt.top > 0 or
    //         hbt.right > 0 or
    //         hbt.bottom > 0 or
    //         hbt.left > 0)
    //     {
    //         writer.print("  border-width: {d}px {d}px {d}px {d}px;\n", .{
    //             hbt.top,
    //             hbt.right,
    //             hbt.bottom,
    //             hbt.left,
    //         }) catch {};
    //
    //         writer.writeAll("  border-style: solid;\n") catch {};
    //     }
    // }
    // if (hover.border_color) |border_color| {
    //     writer.writeAll("  border-color: ") catch {};
    //     colorToCSS(border_color, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }
    //
    // // Border radius
    // if (hover.border_radius) |hbr| {
    //     if (hbr.top_left > 0 or
    //         hbr.top_right > 0 or
    //         hbr.bottom_right > 0 or
    //         hbr.bottom_left > 0)
    //     {
    //         writer.print("  border-radius: {d}px {d}px {d}px {d}px;\n", .{
    //             hbr.top_left,
    //             hbr.top_right,
    //             hbr.bottom_right,
    //             hbr.bottom_left,
    //         }) catch {};
    //     }
    // }
    //
    // // Text color
    // if (hover.text_color) |tc| {
    //     writer.writeAll("  color: ") catch {};
    //     colorToCSS(tc, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }
    //
    // // Padding
    // if (hover.padding) |tp| {
    //     if (tp.top > 0 or
    //         tp.right > 0 or
    //         tp.bottom > 0 or
    //         tp.left > 0)
    //     {
    //         writer.print("  padding: {d}px {d}px {d}px {d}px;\n", .{
    //             tp.top,
    //             tp.right,
    //             tp.bottom,
    //             tp.left,
    //         }) catch {};
    //     }
    // }
    //
    // // Alignment
    // if (hover.child_alignment) |hca| {
    //     writer.print("  justify-content: {s};\n", .{alignmentToCSS(hca.x)}) catch {};
    //     writer.print("  align-items: {s};\n", .{alignmentToCSS(hca.y)}) catch {};
    // }
    //
    // if (hover.child_gap > 0) {
    //     writer.print("  gap: {d}px;\n", .{hover.child_gap}) catch {};
    // }
    //
    // // Background color
    // if (hover.background) |hb| {
    //     writer.writeAll("  background-color: ") catch {};
    //     colorToCSS(hb, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }
    //
    // // Shadow
    // if (hover.shadow.blur > 0 or hover.shadow.spread > 0 or
    //     hover.shadow.top > 0 or hover.shadow.left > 0)
    // {
    //     writer.writeAll("  box-shadow: ") catch {};
    //     writer.print("{d}px {d}px {d}px {d}px ", .{
    //         hover.shadow.left,
    //         hover.shadow.top,
    //         hover.shadow.blur,
    //         hover.shadow.spread,
    //     }) catch {};
    //
    //     colorToCSS(hover.shadow.color, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }
    //
    // // Transform
    // if (hover.transform.type != .none) {
    //     writer.writeAll("  transform: ") catch {};
    //     transformToCSS(hover.transform, writer) catch {};
    //     writer.writeAll(";\n") catch {};
    // }
    //
    // writer.print("  opacity: {d};\n", .{hover.opacity}) catch {};
    //
    // // Close CSS block
    // // writer.writeAll("}\n") catch {};
    //
    // // Null-terminate the string
    // const len: usize = @intCast(fbs.getPos() catch 0);
    // css_buffer[len] = 0;
    // hover_style = css_buffer[0..len];

    // Return a pointer to the CSS string
    return hover_style.ptr;
}

export fn __getHoverLen() usize {
    return hover_style.len;
}

export fn getHoverEctClasses(node_ptr: ?*UINode) void {
    if (node_ptr == null) return;
    _ = node_ptr.?.style orelse return;
    // const ptr = node_ptr.?;
    // // Create a default Hover style
    //
    // for (node_style.child_styles.?) |style| {
    //     // Use a fixed buffer with a fbs to build the CSS string
    //     var fbs = std.io.fixedBufferStream(&css_buffer);
    //     var writer = fbs.writer();
    //
    //     // Write position properties
    //     writer.print(".{s} ", .{style.style_id}) catch {};
    //     writer.writeAll("{\n") catch {};
    //     if (style.position) |p| {
    //         writer.print("  position: {s};\n", .{positionTypeToCSS(p.type)}) catch {};
    //         writer.writeAll("  left: ") catch {};
    //         posTypeToCSS(p.left, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //
    //         writer.writeAll("  right: ") catch {};
    //         posTypeToCSS(p.right, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //
    //         writer.writeAll("  top: ") catch {};
    //         posTypeToCSS(p.top, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //
    //         writer.writeAll("  bottom: ") catch {};
    //         posTypeToCSS(p.bottom, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //
    //     // Write display and flex properties
    //     if (ptr.type == .FlexBox or ptr.type == .List or style.display != null) {
    //         writer.writeAll("  display: flex;\n") catch {};
    //         writer.print("  flex-direction: {s};\n", .{directionToCSS(style.direction)}) catch {};
    //     }
    //
    //     // Write width and height
    //     if (style.display) |d| {
    //         writer.writeAll("  display: ") catch {};
    //         flexTypeToCSS(d, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //
    //     // Write width and height
    //     if (style.width) |hw| {
    //         if (hw.type != .none) {
    //             writer.writeAll("  width: ") catch {};
    //             sizingTypeToCSS(hw, writer) catch {};
    //             writer.writeAll(";\n") catch {};
    //         }
    //     }
    //
    //     if (style.height) |hh| {
    //         if (hh.type != .none) {
    //             writer.writeAll("  height: ") catch {};
    //             sizingTypeToCSS(hh, writer) catch {};
    //             writer.writeAll(";\n") catch {};
    //         }
    //     }
    //
    //     // Border properties
    //     if (style.border_thickness) |hbt| {
    //         if (hbt.top > 0 or
    //             hbt.right > 0 or
    //             hbt.bottom > 0 or
    //             hbt.left > 0)
    //         {
    //             writer.print("  border-width: {d}px {d}px {d}px {d}px;\n", .{
    //                 hbt.top,
    //                 hbt.right,
    //                 hbt.bottom,
    //                 hbt.left,
    //             }) catch {};
    //
    //             writer.writeAll("  border-style: solid;\n") catch {};
    //         }
    //     }
    //     if (style.border_color) |hbc| {
    //         writer.writeAll("  border-color: ") catch {};
    //         colorToCSS(hbc, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //
    //     // Border radius
    //     if (style.border_radius) |hbr| {
    //         if (hbr.top_left > 0 or
    //             hbr.top_right > 0 or
    //             hbr.bottom_right > 0 or
    //             hbr.bottom_left > 0)
    //         {
    //             writer.print("  border-radius: {d}px {d}px {d}px {d}px;\n", .{
    //                 hbr.top_left,
    //                 hbr.top_right,
    //                 hbr.bottom_right,
    //                 hbr.bottom_left,
    //             }) catch {};
    //         }
    //     }
    //
    //     // Text color
    //     if (style.text_color) |tc| {
    //         writer.writeAll("  color: ") catch {};
    //         colorToCSS(tc, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //
    //     // Padding
    //     if (style.padding) |tp| {
    //         if (tp.top > 0 or
    //             tp.right > 0 or
    //             tp.bottom > 0 or
    //             tp.left > 0)
    //         {
    //             writer.print("  padding: {d}px {d}px {d}px {d}px;\n", .{
    //                 tp.top,
    //                 tp.right,
    //                 tp.bottom,
    //                 tp.left,
    //             }) catch {};
    //         }
    //     }
    //
    //     if (style.margin) |m| {
    //         writer.print("  margin: {d}px {d}px {d}px {d}px;\n", .{
    //             m.top,
    //             m.right,
    //             m.bottom,
    //             m.left,
    //         }) catch {};
    //     }
    //
    //     // Alignment
    //     if (style.child_alignment) |hca| {
    //         writer.print("  justify-content: {s};\n", .{alignmentToCSS(hca.x)}) catch {};
    //         writer.print("  align-items: {s};\n", .{alignmentToCSS(hca.y)}) catch {};
    //     }
    //
    //     if (style.child_gap > 0) {
    //         writer.print("  gap: {d}px;\n", .{style.child_gap}) catch {};
    //     }
    //
    //     // Background color
    //     if (style.background) |hb| {
    //         writer.writeAll("  background-color: ") catch {};
    //         colorToCSS(hb, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //
    //     // Shadow
    //     if (style.shadow.blur > 0 or style.shadow.spread > 0 or
    //         style.shadow.top > 0 or style.shadow.left > 0)
    //     {
    //         writer.writeAll("  box-shadow: ") catch {};
    //         writer.print("{d}px {d}px {d}px {d}px ", .{
    //             style.shadow.left,
    //             style.shadow.top,
    //             style.shadow.blur,
    //             style.shadow.spread,
    //         }) catch {};
    //
    //         colorToCSS(style.shadow.color, writer) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //     //
    //     // // Text-Deco
    //     // if (style.text_decoration) |td| {
    //     //     writer.writeAll("  text-decoration: ") catch {};
    //     //     textDecoToCSS(td, writer) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //     //
    //     // if (style.white_space) |ws| {
    //     //     writer.writeAll("  white-space: ") catch {};
    //     //     whiteSpaceToCSS(ws, writer) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //     // if (style.flex_wrap) |fw| {
    //     //     writer.writeAll("  flex-wrap: ") catch {};
    //     //     flexWrapToCSS(fw, writer) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //     //
    //     // if (style.animation) |an| {
    //     //     writer.writeAll("  animation: ") catch {};
    //     //     animationToCSS(an, writer) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     //     writer.print("  animation-delay: {any}s", .{an.delay}) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //     //
    //     if (style.z_index) |zi| {
    //         writer.print("  z-index: {d}", .{zi}) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //
    //     if (style.blur) |bl| {
    //         writer.print("  backdrop-filter: blur({d}px)", .{bl}) catch {};
    //         writer.writeAll(";\n") catch {};
    //     }
    //
    //     if (style.overflow) |ovf| {
    //         switch (ovf) {
    //             .scroll => writer.writeAll("  overflow: scroll;\n") catch {},
    //             .hidden => writer.writeAll("  overflow: hidden;\n") catch {},
    //         }
    //     }
    //
    //     if (style.overflow_x) |ovf| {
    //         switch (ovf) {
    //             .scroll => writer.writeAll("  overflow-x: scroll;\n") catch {},
    //             .hidden => writer.writeAll("  overflow-x: hidden;\n") catch {},
    //         }
    //     }
    //
    //     if (style.overflow_y) |ovf| {
    //         switch (ovf) {
    //             .scroll => writer.writeAll("  overflow-y: scroll;\n") catch {},
    //             .hidden => writer.writeAll("  overflow-y: hidden;\n") catch {},
    //         }
    //     }
    //
    //     if (style.flex_shrink) |fs| {
    //         writer.print("  flex-shrink: {d};\n", .{fs}) catch {};
    //     }
    //
    //     // if (style.list_style) |ls| {
    //     //     writer.writeAll("  list-style: ") catch {};
    //     //     listStyleToCSS(ls, writer) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //     //
    //     // if (style.outline) |ol| {
    //     //     writer.writeAll("  outline: ") catch {};
    //     //     outlineStyleToCSS(ol, writer) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //     //
    //     writer.print("  opacity: {d};\n", .{style.opacity}) catch {};
    //
    //     // if (style.transition) |tr| {
    //     //     writer.writeAll("  transition: ") catch {};
    //     //     transitionStyleToCSS(tr, writer);
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //     //
    //     // if (!style.show_scrollbar) {
    //     //     writer.writeAll("  scrollbar-width: none;\n") catch {};
    //     //     show_scrollbar = false;
    //     // }
    //     // if (style.accent_color) |ac| {
    //     //     writer.writeAll("  accent-color: ") catch {};
    //     //     colorToCSS(ac, writer) catch {};
    //     //     writer.writeAll(";\n") catch {};
    //     // }
    //
    //     // Close CSS block
    //     writer.writeAll("}\n") catch {};
    //
    //     // Null-terminate the string
    //     const len: usize = @intCast(fbs.getPos() catch 0);
    //     css_buffer[len] = 0;
    //     hover_style = css_buffer[0..len];
    //     println("{s}\n", .{hover_style});
    // }
}

// // Function to get just the hover direction CSS value
// export fn getHoverDirection() [*:0]const u8 {
//     const hover = Hover{};
//     const dir_str = directionToCSS(hover.direction);
//
//     // Copy to buffer and null-terminate
//     @memcpy(&css_buffer, dir_str);
//     css_buffer[dir_str.len] = 0;
//
//     return &css_buffer;
// }
//
// // Function to debug the memory layout of the Hover struct
// export fn debugHoverLayout() void {
//     std.debug.print("Size of Hover: {}\n", .{@sizeOf(Hover)});
//
//     inline for (std.meta.fields(Hover)) |field| {
//         std.debug.print("Field {s}: offset={}, size={}\n", .{ field.name, @offsetOf(Hover, field.name), @sizeOf(field.type) });
//     }
//
//     // Specifically for direction
//     std.debug.print("Direction offset: {}\n", .{@offsetOf(Hover, "direction")});
//     std.debug.print("Direction size: {}\n", .{@sizeOf(Direction)});
// }

// // Function to retrieve the offset of a specific field
// export fn getFieldOffset(comptime field_name: []const u8) usize {
//     return @offsetOf(Hover, field_name);
// }
//
// // Function specifically for direction field
// export fn getDirectionOffset() usize {
//     return @offsetOf(Hover, "direction");
// }
//
// // Function to get the size of the Direction enum
// export fn getDirectionSize() usize {
//     return @sizeOf(Direction);
// }
//
// // Function to get the actual direction value
// export fn getDirectionValue() u8 {
//     const hover = Hover{};
//     return @intFromEnum(hover.direction);
// }
