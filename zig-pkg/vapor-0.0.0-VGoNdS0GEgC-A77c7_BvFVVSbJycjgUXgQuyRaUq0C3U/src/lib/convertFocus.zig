const std = @import("std");
const mem = std.mem;
const Types = @import("types.zig");
const Alignment = Types.Alignment;
const Direction = Types.Direction;
const PositionType = Types.PositionType;
const UINode = @import("UITree.zig").UINode;
const Focus = Types.Focus;
const Sizing = Types.Sizing;
const FlexType = Types.FlexType;
const Pos = Types.Pos;
const Background = Types.Background;
const Transform = Types.Transform;
const RenderCommand = Types.RenderCommand;
const println = @import("Vapor.zig").println;

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
var focus_style: []const u8 = "";
var global_len: usize = 0;
pub export fn getFocusStyle(node_ptr: ?*UINode) ?[*]const u8 {
    if (node_ptr == null) return focus_style.ptr;
    const style = node_ptr.?.style orelse return null;
    const focus = style.focus.?;
    // Create a default Focus style
    // const focus = Focus{};

    // Use a fixed buffer with a fbs to build the CSS string
    var fbs = std.io.fixedBufferStream(&css_buffer);
    var writer = fbs.writer();

    // Start CSS block
    // writer.writeAll("{\n") catch {};

    // Write position properties
    if (focus.position) |fp| {
        writer.print("  position: {s};\n", .{positionTypeToCSS(fp.type)}) catch {};
        writer.writeAll("  left: ") catch {};
        posTypeToCSS(fp.left, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  right: ") catch {};
        posTypeToCSS(fp.right, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  top: ") catch {};
        posTypeToCSS(fp.top, writer) catch {};
        writer.writeAll(";\n") catch {};

        writer.writeAll("  bottom: ") catch {};
        posTypeToCSS(fp.bottom, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    if (focus.display) |d| {
        writer.writeAll("  display: ") catch {};
        flexTypeToCSS(d, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Write display and flex properties
    // writer.writeAll("  display: flex;\n") catch {};
    if (focus.direction) |fd| {
        writer.print("  flex-direction: {s};\n", .{directionToCSS(fd)}) catch {};
    }

    // Write width and height
    if (focus.width) |fw| {
        if (fw.type != .none) {
            writer.writeAll("  width: ") catch {};
            sizingTypeToCSS(fw, writer) catch {};
            writer.writeAll(";\n") catch {};
        }
    }

    if (focus.height) |fh| {
        if (fh.type != .none) {
            writer.writeAll("  height: ") catch {};
            sizingTypeToCSS(fh, writer) catch {};
            writer.writeAll(";\n") catch {};
        }
    }

    // Write font properties
    if (focus.font_size) |fs| {
        writer.print("  font-size: {d}px;\n", .{fs}) catch {};
    }
    if (focus.letter_spacing) |ls| {
        writer.print("  letter-spacing: {d}px;\n", .{@as(f32, @floatFromInt(ls)) / 1000.0}) catch {};
    }
    if (focus.line_height) |lh| {
        writer.print("  line-height: {d}px;\n", .{lh}) catch {};
    }

    if (focus.font_weight) |hf| {
        if (hf > 0) {
            writer.print("  font-weight: {d};\n", .{hf}) catch {};
        }
    }

    // Border properties
    if (focus.border_thickness) |fbt| {
        if (fbt.top > 0 or
            fbt.right > 0 or
            fbt.bottom > 0 or
            fbt.left > 0)
        {
            writer.print("  border-width: {d}px {d}px {d}px {d}px;\n", .{
                fbt.top,
                fbt.right,
                fbt.bottom,
                fbt.left,
            }) catch {};

            writer.writeAll("  border-style: solid;\n") catch {};
        }
    }
    if (focus.border_color) |border_color| {
        writer.writeAll("  border-color: ") catch {};
        colorToCSS(border_color, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Border radius
    if (focus.border_radius) |fbr| {
        if (fbr.top_left > 0 or
            fbr.top_right > 0 or
            fbr.bottom_right > 0 or
            fbr.bottom_left > 0)
        {
            writer.print("  border-radius: {d}px {d}px {d}px {d}px;\n", .{
                fbr.top_left,
                fbr.top_right,
                fbr.bottom_right,
                fbr.bottom_left,
            }) catch {};
        }
    }

    // Text color
    if (focus.text_color) |tc| {
        writer.writeAll("  color: ") catch {};
        colorToCSS(tc, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Padding
    if (focus.padding) |tp| {
        if (tp.top > 0 or
            tp.right > 0 or
            tp.bottom > 0 or
            tp.left > 0)
        {
            writer.print("  padding: {d}px {d}px {d}px {d}px;\n", .{
                tp.top,
                tp.right,
                tp.bottom,
                tp.left,
            }) catch {};
        }
    }

    // Alignment
    if (focus.child_alignment) |fca| {
        writer.print("  justify-content: {s};\n", .{alignmentToCSS(fca.x)}) catch {};
        writer.print("  align-items: {s};\n", .{alignmentToCSS(fca.y)}) catch {};
    }

    if (focus.child_gap > 0) {
        writer.print("  gap: {d}px;\n", .{focus.child_gap}) catch {};
    }

    // Background color
    if (focus.background) |fb| {
        writer.writeAll("  background-color: ") catch {};
        colorToCSS(fb, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Shadow
    if (focus.shadow.blur > 0 or focus.shadow.spread > 0 or
        focus.shadow.top > 0 or focus.shadow.left > 0)
    {
        writer.writeAll("  box-shadow: ") catch {};
        writer.print("{d}px {d}px {d}px {d}px ", .{
            focus.shadow.left,
            focus.shadow.top,
            focus.shadow.blur,
            focus.shadow.spread,
        }) catch {};

        colorToCSS(focus.shadow.color, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    // Transform
    if (focus.transform.type != .none) {
        writer.writeAll("  transform: ") catch {};
        transformToCSS(focus.transform, writer) catch {};
        writer.writeAll(";\n") catch {};
    }

    writer.print("  opacity: {d};\n", .{focus.opacity}) catch {};

    // Close CSS block
    // writer.writeAll("}\n") catch {};

    // Null-terminate the string
    const len: usize = @intCast(fbs.getPos() catch 0);
    css_buffer[len] = 0;
    focus_style = css_buffer[0..len];

    // Return a pointer to the CSS string
    return focus_style.ptr;
}

export fn getFocusLen() usize {
    return focus_style.len;
}

export fn getFocusEctClasses(node_ptr: ?*UINode) void {
    if (node_ptr == null) return;
    const node_style = node_ptr.?.style orelse return;
    const ptr = node_ptr.?;
    // Create a default Focus style

    for (node_style.child_styles.?) |style| {
        // Use a fixed buffer with a fbs to build the CSS string
        var fbs = std.io.fixedBufferStream(&css_buffer);
        var writer = fbs.writer();

        // Write position properties
        writer.print(".{s} ", .{style.style_id}) catch {};
        writer.writeAll("{\n") catch {};
        if (style.position) |p| {
            writer.print("  position: {s};\n", .{positionTypeToCSS(p.type)}) catch {};
            writer.writeAll("  left: ") catch {};
            posTypeToCSS(p.left, writer) catch {};
            writer.writeAll(";\n") catch {};

            writer.writeAll("  right: ") catch {};
            posTypeToCSS(p.right, writer) catch {};
            writer.writeAll(";\n") catch {};

            writer.writeAll("  top: ") catch {};
            posTypeToCSS(p.top, writer) catch {};
            writer.writeAll(";\n") catch {};

            writer.writeAll("  bottom: ") catch {};
            posTypeToCSS(p.bottom, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Write display and flex properties
        if (ptr.type == .FlexBox or ptr.type == .List or style.display != null) {
            writer.writeAll("  display: flex;\n") catch {};
            writer.print("  flex-direction: {s};\n", .{directionToCSS(style.direction)}) catch {};
        }

        // Write width and height
        if (style.display) |d| {
            writer.writeAll("  display: ") catch {};
            flexTypeToCSS(d, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Write width and height
        if (style.width) |fw| {
            if (fw.type != .none) {
                writer.writeAll("  width: ") catch {};
                sizingTypeToCSS(fw, writer) catch {};
                writer.writeAll(";\n") catch {};
            }
        }

        if (style.height) |fh| {
            if (fh.type != .none) {
                writer.writeAll("  height: ") catch {};
                sizingTypeToCSS(fh, writer) catch {};
                writer.writeAll(";\n") catch {};
            }
        }

        // Border properties
        if (style.border_thickness) |fbt| {
            if (fbt.top > 0 or
                fbt.right > 0 or
                fbt.bottom > 0 or
                fbt.left > 0)
            {
                writer.print("  border-width: {d}px {d}px {d}px {d}px;\n", .{
                    fbt.top,
                    fbt.right,
                    fbt.bottom,
                    fbt.left,
                }) catch {};

                writer.writeAll("  border-style: solid;\n") catch {};
            }
        }
        if (style.border_color) |fbc| {
            writer.writeAll("  border-color: ") catch {};
            colorToCSS(fbc, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Border radius
        if (style.border_radius) |fbr| {
            if (fbr.top_left > 0 or
                fbr.top_right > 0 or
                fbr.bottom_right > 0 or
                fbr.bottom_left > 0)
            {
                writer.print("  border-radius: {d}px {d}px {d}px {d}px;\n", .{
                    fbr.top_left,
                    fbr.top_right,
                    fbr.bottom_right,
                    fbr.bottom_left,
                }) catch {};
            }
        }

        // Text color
        if (style.text_color) |tc| {
            writer.writeAll("  color: ") catch {};
            colorToCSS(tc, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Padding
        if (style.padding) |tp| {
            if (tp.top > 0 or
                tp.right > 0 or
                tp.bottom > 0 or
                tp.left > 0)
            {
                writer.print("  padding: {d}px {d}px {d}px {d}px;\n", .{
                    tp.top,
                    tp.right,
                    tp.bottom,
                    tp.left,
                }) catch {};
            }
        }

        if (style.margin) |m| {
            writer.print("  margin: {d}px {d}px {d}px {d}px;\n", .{
                m.top,
                m.right,
                m.bottom,
                m.left,
            }) catch {};
        }

        // Alignment
        if (style.child_alignment) |fca| {
            writer.print("  justify-content: {s};\n", .{alignmentToCSS(fca.x)}) catch {};
            writer.print("  align-items: {s};\n", .{alignmentToCSS(fca.y)}) catch {};
        }

        if (style.child_gap > 0) {
            writer.print("  gap: {d}px;\n", .{style.child_gap}) catch {};
        }

        // Background color
        if (style.background) |fb| {
            writer.writeAll("  background-color: ") catch {};
            colorToCSS(fb, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        // Shadow
        if (style.shadow.blur > 0 or style.shadow.spread > 0 or
            style.shadow.top > 0 or style.shadow.left > 0)
        {
            writer.writeAll("  box-shadow: ") catch {};
            writer.print("{d}px {d}px {d}px {d}px ", .{
                style.shadow.left,
                style.shadow.top,
                style.shadow.blur,
                style.shadow.spread,
            }) catch {};

            colorToCSS(style.shadow.color, writer) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.z_index) |zi| {
            writer.print("  z-index: {d}", .{zi}) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.blur) |bl| {
            writer.print("  backdrop-filter: blur({d}px)", .{bl}) catch {};
            writer.writeAll(";\n") catch {};
        }

        if (style.overflow) |ovf| {
            switch (ovf) {
                .scroll => writer.writeAll("  overflow: scroll;\n") catch {},
                .hidden => writer.writeAll("  overflow: hidden;\n") catch {},
            }
        }

        if (style.overflow_x) |ovf| {
            switch (ovf) {
                .scroll => writer.writeAll("  overflow-x: scroll;\n") catch {},
                .hidden => writer.writeAll("  overflow-x: hidden;\n") catch {},
            }
        }

        if (style.overflow_y) |ovf| {
            switch (ovf) {
                .scroll => writer.writeAll("  overflow-y: scroll;\n") catch {},
                .hidden => writer.writeAll("  overflow-y: hidden;\n") catch {},
            }
        }

        if (style.flex_shrink) |fs| {
            writer.print("  flex-shrink: {d};\n", .{fs}) catch {};
        }

        writer.print("  opacity: {d};\n", .{style.opacity}) catch {};

        // Close CSS block
        writer.writeAll("}\n") catch {};

        // Null-terminate the string
        const len: usize = @intCast(fbs.getPos() catch 0);
        css_buffer[len] = 0;
        focus_style = css_buffer[0..len];
        println("{s}\n", .{focus_style});
    }
}

