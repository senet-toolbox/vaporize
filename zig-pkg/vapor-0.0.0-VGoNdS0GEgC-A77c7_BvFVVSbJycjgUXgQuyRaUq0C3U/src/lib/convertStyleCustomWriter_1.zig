const std = @import("std");
const mem = std.mem;
const Types = @import("types.zig");
const Alignment = Types.Alignment;
const Direction = Types.Direction;
const PositionType = Types.PositionType;
const FloatType = Types.FloatType;
const UINode = @import("UITree.zig").UINode;
const Sizing = Types.Sizing;
const Transform = Types.Transform;
const TextDecoration = Types.TextDecoration;
const Appearance = Types.Appearance;
const WhiteSpace = Types.WhiteSpace;
const FlexWrap = Types.FlexWrap;
const BoxSizing = Types.BoxSizing;
const Pos = Types.Pos;
const PosType = Types.PosType;
const FlexType = Types.FlexType;
const TransformOrigin = Types.TransformOrigin;
const Vapor = @import("Vapor.zig");
const Animation = Vapor.Animation;
const AnimationType = Types.AnimationType;
const ListStyle = Types.ListStyle;
const Transition = Types.Transition;
const TimingFunction = Types.TimingFunction;
const Outline = Types.Outline;
const Cursor = Types.Cursor;
const Color = Types.Color;
const Writer = @import("Writer.zig");
const AnimDir = @import("Animation.zig").AnimDir;
const Theme = @import("theme");

const writer_t = *Writer;
// Global buffer to store the CSS string for returning to JavaScript
var css_buffer: [4096]u8 = undefined;

const PropValue = struct {
    tag: Tag,
    data: Data,

    // Enum to identify the type
    const Tag = enum {
        position_type,
        direction,
        sizing,
        padding,
        cursor,
        appearance,
        transform_type,
        transform_origin,
        margin,
        pos,
        text_decoration,
        white_space,
        flex_wrap,
        alignment,
        layer,
        color,
        list_style,
        outline,
        animation_specs,
        transition,
        shadow,
        border,
        border_radius,
        flex_type,
        string_literal, // For values like "flex", "center", etc.
    };

    // Union to hold the actual data
    const Data = union(Tag) {
        position_type: Types.PositionType,
        direction: Types.Direction,
        sizing: Types.Sizing,
        padding: Types.Padding,
        cursor: Types.Cursor,
        appearance: Types.Appearance,
        transform_type: Types.Transform,
        transform_origin: Types.TransformOrigin,
        margin: Types.Margin,
        pos: Types.Pos,
        text_decoration: Types.TextDecoration,
        white_space: Types.WhiteSpace,
        flex_wrap: Types.FlexWrap,
        alignment: Types.Alignment,
        layer: Types.BackgroundLayer,
        color: Types.Color,
        list_style: Types.ListStyle,
        outline: Types.Outline,
        animation_specs: Animation.Specs,
        transition: Types.Transition,
        shadow: Types.Shadow,
        border: Types.Border,
        border_radius: Types.BorderRadius,
        flex_type: Types.FlexType,
        string_literal: []const u8,
    };
};

/// Writes a CSS property and its value to the writer.
/// This function uses a tagged union (PropValue) to prevent code bloat from monomorphization.
fn writePropValue(prop: []const u8, value: PropValue, writer: writer_t) void {
    writer.write(prop) catch return;
    writer.writeByte(':') catch return;

    switch (value.tag) {
        // else => {},
        .position_type => positionTypeToCSS(value.data.position_type, writer) catch {},
        .direction => directionToCSS(value.data.direction, writer) catch {},
        .sizing => sizingTypeToCSS(value.data.sizing, writer) catch {},
        .padding => {
            writer.writeU32(value.data.padding.top) catch {};
            writer.write("px ") catch {};
            writer.writeU32(value.data.padding.right) catch {};
            writer.write("px ") catch {};
            writer.writeU32(value.data.padding.bottom) catch {};
            writer.write("px ") catch {};
            writer.writeU32(value.data.padding.left) catch {};
            writer.write("px") catch {};
        },
        .cursor => cursorToCSS(value.data.cursor, writer) catch {},
        .appearance => appearanceToCSS(value.data.appearance, writer) catch {},
        .transform_type => {
            const transform = value.data.transform_type;
            for (transform.type) |t| {
                switch (t) {
                    .scale => {
                        writer.write("scale(") catch {};
                        writer.writeF32(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .scaleY => {
                        writer.write("scaleY(") catch {};
                        writer.writeF32(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .scaleX => {
                        writer.write("scaleX(") catch {};
                        writer.writeF32(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .translateX => {
                        writer.write("translateX(") catch {};
                        if (transform.percent) |percent| {
                            writer.writeF32(percent) catch {};
                            writer.write("%)") catch {};
                        } else if (transform.dist) |dist| {
                            writer.writeF32(dist) catch {};
                            writer.write("px)") catch {};
                        }
                    },
                    .translateY => {
                        writer.write("translateY(") catch {};
                        if (transform.percent) |percent| {
                            writer.writeF32(percent) catch {};
                            writer.write("%)") catch {};
                        } else if (transform.dist) |dist| {
                            writer.writeF32(dist) catch {};
                            writer.write("px)") catch {};
                        }
                    },
                    .rotate => {
                        writer.write("rotate(") catch {};
                        writer.writeF32(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateX => {
                        writer.write("rotateX(") catch {};
                        writer.writeF32(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateY => {
                        writer.write("rotateY(") catch {};
                        writer.writeF32(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateXYZ => {
                        writer.write("rotateX(") catch {};
                        writer.writeF32(transform.x) catch {};
                        writer.write("deg) ") catch {};
                        writer.write("rotateY(") catch {};
                        writer.writeF32(transform.y) catch {};
                        writer.write("deg) ") catch {};
                        writer.write("rotateZ(") catch {};
                        writer.writeF32(transform.z) catch {};
                        writer.write("deg)") catch {};
                    },
                    .none => {},
                }
                writer.writeByte(' ') catch {};
            }
        },
        .transform_origin => transformOriginToCSS(value.data.transform_origin, writer) catch {},
        .margin => {
            writer.writeU32(value.data.margin.top) catch {};
            writer.write("px ") catch {};
            writer.writeU32(value.data.margin.right) catch {};
            writer.write("px ") catch {};
            writer.writeU32(value.data.margin.bottom) catch {};
            writer.write("px ") catch {};
            writer.writeU32(value.data.margin.left) catch {};
            writer.write("px") catch {};
        },
        .pos => posTypeToCSS(value.data.pos, writer) catch {},
        .text_decoration => textDecoToCSS(value.data.text_decoration, writer) catch {},
        .white_space => whiteSpaceToCSS(value.data.white_space, writer) catch {},
        .flex_wrap => flexWrapToCSS(value.data.flex_wrap, writer) catch {},
        .alignment => alignmentToCSS(value.data.alignment, writer) catch {},
        .layer => layerToCSS(value.data.layer, writer) catch {},
        .color => colorToCSS(value.data.color, writer) catch {},
        .list_style => listStyleToCSS(value.data.list_style, writer) catch {},
        .outline => outlineStyleToCSS(value.data.outline, writer) catch {},
        .animation_specs => animationToCSS(value.data.animation_specs, writer) catch {},
        .transition => transitionStyleToCSS(value.data.transition, writer),
        .shadow => {
            const shadow = value.data.shadow;
            writer.writeF32(shadow.left) catch {};
            writer.write("px ") catch {};
            writer.writeF32(shadow.top) catch {};
            writer.write("px ") catch {};
            writer.writeF32(shadow.blur) catch {};
            writer.write("px ") catch {};
            writer.writeF32(shadow.spread) catch {};
            writer.write("px ") catch {};
            colorToCSS(shadow.color, writer) catch {};
        },
        .border => {
            const border = value.data.border;
            writer.writeF32(border.top) catch {};
            writer.write("px ") catch {};
            writer.writeF32(border.right) catch {};
            writer.write("px ") catch {};
            writer.writeF32(border.bottom) catch {};
            writer.write("px ") catch {};
            writer.writeF32(border.left) catch {};
            writer.write("px") catch {};
        },
        .border_radius => {
            const radius = value.data.border_radius;
            if (radius.top_left == radius.top_right and radius.top_left == radius.bottom_right and radius.top_left == radius.bottom_left) {
                writer.writeF32(radius.top_left) catch {};
                writer.write("px") catch {};
            } else {
                writer.writeF32(radius.top_left) catch {};
                writer.write("px ") catch {};
                writer.writeF32(radius.top_right) catch {};
                writer.write("px ") catch {};
                writer.writeF32(radius.bottom_right) catch {};
                writer.write("px ") catch {};
                writer.writeF32(radius.bottom_left) catch {};
                writer.write("px") catch {};
            }
        },
        .flex_type => flexTypeToCSS(value.data.flex_type, writer) catch {},

        // This new case handles simple string values efficiently.
        .string_literal => writer.write(value.data.string_literal) catch {},
    }
    writer.write(";\n") catch {};
}

// Maps for simple enum-to-string conversions
const direction_map = [_][]const u8{ "column", "row" };
const alignment_map = [_][]const u8{ "center", "flex-start", "flex-end", "flex-start", "flex-end", "space-between", "space-evenly" };
const position_type_map = [_][]const u8{ "relative", "absolute", "fixed", "sticky" };
const float_type_map = [_][]const u8{ "top", "bottom", "left", "right" };
const transform_origin_map = [_][]const u8{ "top", "bottom", "right", "left" };
const text_decoration_map = [_][]const u8{ "none", "inherit", "underline", "initial", "overline", "unset", "revert" };
const appearance_map = [_][]const u8{ "none", "auto", "button", "textfield", "menulist", "searchfield", "textarea", "checkbox", "radio", "inherit", "initial", "revert", "unset" };
const outline_map = [_][]const u8{ "none", "auto", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset", "inherit", "initial", "revert", "unset" };
const cursor_map = [_][]const u8{ "pointer", "help", "grab", "zoom-in", "zoom-out" };
const box_sizing_map = [_][]const u8{ "content-box", "border-box", "padding-box", "inherit", "initial", "revert", "unset" };
const list_style_map = [_][]const u8{ "none", "disc", "circle", "square", "decimal", "decimal-leading-zero", "lower-roman", "upper-roman", "lower-alpha", "upper-alpha", "lower-greek", "armenian", "georgian", "inherit", "initial", "revert", "unset" };
const flex_wrap_map = [_][]const u8{ "nowrap", "wrap", "wrap-reverse", "inherit", "initial", "revert", "unset" };
const white_space_map = [_][]const u8{ "normal", "nowrap", "pre", "pre-wrap", "pre-line", "break-spaces", "inherit", "initial", "revert", "unset" };
const flex_type_map = [_][]const u8{ "flex", "inline-flex", "block", "inline-block", "none" };
const timing_function_map = [_][]const u8{ "ease", "linear", "ease-in", "ease-out", "ease-in-out", "bounce", "elastic" };
const animation_direction_map = [_][]const u8{ "normal ", "reverse ", "forwards ", "alternate " };

/// Generic helper to write a CSS string from a pre-defined map based on an enum's value.
/// The `string_map` must have its string literals in the same order as the enum declaration.
inline fn writeMappedString(
    comptime EnumType: type,
    value: EnumType,
    string_map: []const []const u8,
    writer: anytype,
) !void {
    try writer.write(string_map[@intFromEnum(value)]);
}

fn directionToCSS(dir: Direction, writer: writer_t) !void {
    try writeMappedString(Direction, dir, &direction_map, writer);
}

fn alignmentToCSS(_align: Alignment, writer: writer_t) !void {
    try writeMappedString(Alignment, _align, &alignment_map, writer);
}

fn positionTypeToCSS(pos_type: PositionType, writer: writer_t) !void {
    try writeMappedString(PositionType, pos_type, &position_type_map, writer);
}

fn floatTypeToCSS(float_type: FloatType) []const u8 {
    return float_type_map[@intFromEnum(float_type)];
}

fn transformOriginToCSS(origin: TransformOrigin, writer: anytype) !void {
    try writeMappedString(TransformOrigin, origin, &transform_origin_map, writer);
}

fn textDecoToCSS(deco: TextDecoration, writer: anytype) !void {
    try writeMappedString(TextDecoration, deco, &text_decoration_map, writer);
}
// Helper function to convert SizingType to CSS values
fn sizingTypeToCSS(sizing: Sizing, writer: writer_t) !void {
    switch (sizing.type) {
        .fit => try writer.write("fit-content"),
        .grow => try writer.write("flex:1"),
        .percent => {
            try writer.writeF32(sizing.size.minmax.min);
            try writer.writeByte('%');
        },
        .fixed => {
            try writer.writeF32(sizing.size.minmax.min);
            try writer.write("px");
        },
        .elastic => try writer.write("auto"), // Could also use min/max width/height in separate properties
        .elastic_percent => {
            try writer.writeF32(sizing.size.percent.min);
            try writer.writeByte('%');
        },
        .clamp_px => {
            try writer.write("clamp(");
            try writer.writeF32(sizing.size.clamp_px.min);
            try writer.write("px,");
            try writer.writeF32(sizing.size.clamp_px.preferred);
            try writer.write("px,");
            try writer.writeF32(sizing.size.clamp_px.max);
            try writer.write("px)");
        },
        .clamp_percent => {
            try writer.write("clamp(");
            try writer.writeF32(sizing.size.clamp_px.min);
            try writer.write("%,");
            try writer.writeF32(sizing.size.clamp_px.preferred);
            try writer.write("%,");
            try writer.writeF32(sizing.size.clamp_px.max);
            try writer.write("%)");
        },
        .none => {},
        else => {},
    }
}

fn posTypeToCSS(pos: Pos, writer: writer_t) !void {
    switch (pos.type) {
        .fit => try writer.write("fit-content"),
        .grow => try writer.write("auto"),
        .percent => {
            try writer.writeF32(pos.value);
            try writer.writeByte('%');
        },
        .fixed => {
            try writer.writeF32(pos.value);
            try writer.write("px");
        },
    }
}

// Helper function to convert color array to CSS rgba
fn colorToCSS(color: Color, writer: anytype) !void {
    switch (color) {
        .Literal => |rgba| {
            // const alpha = @as(f32, @floatFromInt(rgba.a)) / 255.0;
            // const alpha = @round(@as(f32, @floatFromInt(rgba.a)) / 255.0 * 100.0) / 100.0;
            // Vapor.println("alpha: {any}", .{alpha});
            if (rgba.a == 1) {
                try writer.write("rgb(");
                try writer.writeU8Num(rgba.r);
                try writer.writeByte(',');
                try writer.writeU8Num(rgba.g);
                try writer.writeByte(',');
                try writer.writeU8Num(rgba.b);
                try writer.writeByte(')');
            } else {
                try writer.write("rgba(");
                try writer.writeU8Num(rgba.r);
                try writer.writeByte(',');
                try writer.writeU8Num(rgba.g);
                try writer.writeByte(',');
                try writer.writeU8Num(rgba.b);
                try writer.writeByte(',');
                try writer.writeF32(rgba.a);
                try writer.writeByte(')');
            }
        },
        .Thematic => |thematic| {
            if (thematic.alpha) |alpha| {
                try writer.write("rgba(");
                try writer.write("var(--");
                try writer.write(@tagName(thematic.token));
                try writer.write("), ");
                try writer.writeF32(alpha);
                try writer.writeByte(')');
            } else {
                try writer.write("rgb(var(--");
                try writer.write(@tagName(thematic.token));
                try writer.write("))");
            }
        },
    }
}

// Helper function to convert color array to CSS rgba
fn layerToCSS(layer: Types.BackgroundLayer, writer: anytype) !void {
    switch (layer) {
        .Image => |image| {
            writer.write("url(") catch {};
            writer.write(image.url) catch {};
            writer.writeByte(')') catch {};
            return;
        },
        .Grid => |grid| {
            writer.write("linear-gradient(90deg, ") catch {};
            colorToCSS(grid.color, writer) catch {};
            writer.writeByte(' ') catch {};
            writer.writeI32(grid.thickness) catch {};
            writer.write("px, ") catch {};
            colorToCSS(.transparent, writer) catch {};
            writer.writeByte(' ') catch {};
            writer.writeI32(grid.thickness) catch {};
            writer.write("px),") catch {};

            writer.write("linear-gradient(") catch {};
            colorToCSS(grid.color, writer) catch {};
            writer.writeByte(' ') catch {};
            writer.writeI32(grid.thickness) catch {};
            writer.write("px, ") catch {};
            colorToCSS(.transparent, writer) catch {};
            writer.writeByte(' ') catch {};
            writer.writeI32(grid.thickness) catch {};
            writer.write("px);\n") catch {};

            writer.write("background-size: ") catch {};
            writer.writeF32(grid.size) catch {};
            writer.write("px ") catch {};
            writer.writeF32(grid.size) catch {};
            writer.write("px;\n") catch {};
            writer.write("background-position: center center;\n") catch {};
        },
    }
}

fn appearanceToCSS(appearance: Appearance, writer: anytype) !void {
    try writeMappedString(Appearance, appearance, &appearance_map, writer);
}

// Function to convert OutlineStyle enum to a CSS string
fn outlineStyleToCSS(outline: Outline, writer: anytype) !void {
    try writeMappedString(Outline, outline, &outline_map, writer);
}

fn transitionStyleToCSS(style: Transition, writer: anytype) void {
    if (style.properties) |prop| {
        for (prop) |p| {
            switch (p) {
                .transform => {
                    const tag_name = @tagName(p);
                    writer.write(tag_name) catch return;
                    writer.write(" ") catch return;
                },
                else => {},
            }
        }
    } else {
        writer.write("all ") catch return;
    }
    writer.writeU32(style.duration) catch return;
    writer.write("ms ") catch return;
    try writeMappedString(TimingFunction, style.timing, &timing_function_map, writer);
}

// Function to convert ListStyle enum to CSS string
fn cursorToCSS(cursor_type: Cursor, writer: anytype) !void {
    try writeMappedString(Cursor, cursor_type, &cursor_map, writer);
}

// Function to convert ListStyle enum to CSS string
fn listStyleToCSS(list_style: ListStyle, writer: anytype) !void {
    try writeMappedString(ListStyle, list_style, &list_style_map, writer);
}

// Function to convert FlexWrap enum to CSS string
fn flexWrapToCSS(flex_wrap: FlexWrap, writer: anytype) !void {
    try writeMappedString(FlexWrap, flex_wrap, &flex_wrap_map, writer);
}
fn animationToCSS(animation: Animation.Specs, writer: anytype) !void {
    writer.write(animation.tag) catch {};
    writer.write(" ") catch {};
    writer.writeF32(animation.duration_s) catch {};
    writer.write("s ") catch {};
    try writeMappedString(TimingFunction, animation.timing_function, &timing_function_map, writer);
    try writeMappedString(AnimDir, animation.direction, &animation_direction_map, writer);
    if (animation.iteration_count.iter_count == 0) {
        try writer.write("infinite");
    }
}

fn whiteSpaceToCSS(white_space: WhiteSpace, writer: anytype) !void {
    try writeMappedString(WhiteSpace, white_space, &white_space_map, writer);
}

// Function to convert FlexType enum to a CSS string
fn flexTypeToCSS(flex_type: FlexType, writer: anytype) !void {
    try writeMappedString(FlexType, flex_type, &flex_type_map, writer);
}

pub fn checkSize(size: *const Types.Size, writer: writer_t) void {
    if (size.width.type != .none and size.width.type != .grow) {
        if (size.width.type == .min_max_vp) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.min_max_vp.max) catch {};
            writer.write("vw;\n") catch {};
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.min_max_vp.max) catch {};
            writer.write("vw;\n") catch {};
        } else if (size.width.type == .elastic_percent) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.min_max_vp.max) catch {};
            writer.write("%;\n") catch {};
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.min_max_vp.max) catch {};
            writer.write("%;\n") catch {};
        } else {
            writePropValue("width", .{ .tag = .sizing, .data = .{ .sizing = size.width } }, writer);
        }
    } else if (size.width.type == .grow) {
        writer.write("flex: 1;\n") catch {};
    }

    if (size.height.type != .none and size.height.type != .grow) {
        if (size.height.type == .min_max_vp) {
            writer.write("min-height:") catch {};
            writer.writeF32(size.height.size.min_max_vp.min) catch {};
            writer.write("vh;\n") catch {};
            writer.write("max-height:") catch {};
            writer.writeF32(size.height.size.min_max_vp.max) catch {};
            writer.write("vh;\n") catch {};
        } else {
            writePropValue("height", .{ .tag = .sizing, .data = .{ .sizing = size.height } }, writer);
        }
    } else if (size.height.type == .grow) {
        writer.write("flex: 1;\n") catch {};
    }
}

pub fn checkVisual(ptr: ?*UINode, visual: *const Types.Visual, writer: writer_t, visual_type: u8) void {
    // Color color
    if (visual.background) |background| {
        if (background.color) |color| {
            writePropValue("background-color", .{ .tag = .color, .data = .{ .color = color } }, writer);
        }
        if (background.layer) |layer| {
            writePropValue("background-image", .{ .tag = .layer, .data = .{ .layer = layer } }, writer);
        }
    } else if (ptr != null) {
        if (ptr.?.type == .Button or ptr.?.type == .CtxButton) {
            _ = writer.write("background-color:rgba(0,0,0,0);\n") catch {};
        }
    }

    // Write font properties
    if (visual.font_size) |fs| {
        writer.write("font-size:") catch {};
        writer.writeI32(fs) catch {};
        writer.write("px;\n") catch {};
    }
    if (visual.letter_spacing) |ls| {
        writer.write("letter-spacing:") catch {};
        writer.writeI32(ls) catch {};
        writer.write("px;\n") catch {};
    }
    if (visual.line_height) |lh| {
        writer.write("line-height:") catch {};
        writer.writeI32(lh) catch {};
        writer.write("px;\n") catch {};
    }

    if (visual.font_weight) |sf| {
        writer.write("font-weight:") catch {};
        writer.writeUsize(sf) catch {};
        writer.write(";\n") catch {};
    }

    if (visual.border) |border| {
        const border_thickness = border.thickness;
        writePropValue("border-width", .{ .tag = .border, .data = .{ .border = border_thickness } }, writer);
        if (border.color) |border_color| {
            writePropValue("border-color", .{ .tag = .color, .data = .{ .color = border_color } }, writer);
        }
        writer.write("border-style: solid;\n") catch {};

        // Border radius
        if (border.radius) |border_radius| {
            writePropValue("border-radius", .{ .tag = .border_radius, .data = .{ .border_radius = border_radius } }, writer);
        }
    } else if (visual.border_thickness) |border_thickness| {
        writePropValue("border-width", .{ .tag = .border, .data = .{ .border = border_thickness } }, writer);
        if (visual.border_color) |border_color| {
            writePropValue("border-color", .{ .tag = .color, .data = .{ .color = border_color } }, writer);
        }
        writer.write("border-style:solid;\n") catch {};
    } else if (visual_type != 0) {
        if (ptr != null) {
            if (ptr.?.type == .Button or ptr.?.type == .CtxButton or ptr.?.type == .ButtonCycle) {
                _ = writer.write("border:none;\n") catch {};
            }
        }
    }

    // Border radius
    if (visual.border_radius) |border_radius| {
        writePropValue("border-radius", .{ .tag = .border_radius, .data = .{ .border_radius = border_radius } }, writer);
    }

    // Text color
    if (visual.text_color) |color| {
        if (ptr == null) {
            writePropValue("color", .{ .tag = .color, .data = .{ .color = color } }, writer);
        } else if (ptr.?.type == .Svg or ptr.?.type == .Graphic) {
            writePropValue("fill", .{ .tag = .color, .data = .{ .color = color } }, writer);
            writePropValue("stroke", .{ .tag = .color, .data = .{ .color = color } }, writer);
        } else {
            writePropValue("color", .{ .tag = .color, .data = .{ .color = color } }, writer);
        }
    }

    // Shadow
    if (visual.shadow.blur > 0 or visual.shadow.spread > 0 or
        visual.shadow.top > 0 or visual.shadow.left > 0)
    {
        writePropValue("box-shadow", .{ .tag = .shadow, .data = .{ .shadow = visual.shadow } }, writer);
    }
    // Transform
    if (visual.transform) |tr| {
        writePropValue("transform", .{ .tag = .transform_type, .data = .{ .transform_type = tr } }, writer);
    }

    // Transform
    if (visual.opacity) |opacity| {
        writer.write("opacity:") catch {};
        writer.writeF32(opacity) catch {};
        writer.write(";\n") catch {};
    }
}

// Export this function to be called from JavaScript to get the CSS representation
pub var style_style: []const u8 = "";
var global_len: usize = 0;
var show_scrollbar: bool = true;
// 61.8kb before this function
// adds 20kb

pub fn generateStyle(ptr: ?*UINode, style: *const Types.Style) void {
    // Use a fixed buffer with a fbs to build the CSS string
    var writer: Writer = undefined;
    writer.init(&css_buffer);

    // Write position properties
    if (style.position) |p| {
        writePropValue("position", .{ .tag = .position_type, .data = .{ .position_type = p.type } }, &writer); // adds 9kb
        if (p.left) |pl| {
            writePropValue("left", .{ .tag = .pos, .data = .{ .pos = pl } }, &writer);
        }
        if (p.right) |pr| {
            writePropValue("right", .{ .tag = .pos, .data = .{ .pos = pr } }, &writer);
        }
        if (p.top) |pt| {
            writePropValue("top", .{ .tag = .pos, .data = .{ .pos = pt } }, &writer);
        }
        if (p.bottom) |pb| {
            writePropValue("bottom", .{ .tag = .pos, .data = .{ .pos = pb } }, &writer);
        }
    }

    // Write display and flex properties
    if (ptr != null and ptr.?.type == .FlexBox) {
        writePropValue("display", .{ .tag = .flex_type, .data = .{ .flex_type = .Flex } }, &writer);
        writePropValue("flex-direction", .{ .tag = .direction, .data = .{ .direction = style.direction } }, &writer);
        if (style.layout) |layout| {
            if (style.direction == .row) {
                writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, &writer);
                writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, &writer);
            } else {
                writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, &writer);
                writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, &writer);
            }
        }
    } else if (style.layout) |layout| {
        if (ptr != null and ptr.?.text != null and layout.x == .center and layout.y == .center and ptr.?.type != .Svg) {
            writePropValue("text-align", .{ .tag = .alignment, .data = .{ .alignment = .center } }, &writer);
        } else {
            writePropValue("display", .{ .tag = .flex_type, .data = .{ .flex_type = .Flex } }, &writer);
            writePropValue("flex-direction", .{ .tag = .direction, .data = .{ .direction = style.direction } }, &writer);

            if (layout.x == .center and layout.y == .center) {
                writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = .center } }, &writer);
                writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = .center } }, &writer);
            } else {
                if (style.direction == .row) {
                    writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, &writer);
                    writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, &writer);
                } else {
                    writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, &writer);
                    writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, &writer);
                }
            }
        }
    }

    if (style.size) |size| {
        if (size.width.type != .none and size.width.type != .grow) {
            if (size.width.type == .min_max_vp) {
                writer.write("max-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("vw;\n") catch {};
                writer.write("min-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("vw;\n") catch {};
            } else if (size.width.type == .elastic_percent) {
                writer.write("max-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("%;\n") catch {};
                writer.write("min-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("%;\n") catch {};
            } else {
                writePropValue("width", .{ .tag = .sizing, .data = .{ .sizing = size.width } }, &writer);
            }
        } else if (size.width.type == .grow) {
            writer.write("flex: 1;\n") catch {};
        }

        if (size.height.type != .none and size.height.type != .grow) {
            if (size.height.type == .min_max_vp) {
                writer.write("min-height:") catch {};
                writer.writeF32(size.height.size.min_max_vp.min) catch {};
                writer.write("vh;\n") catch {};
                writer.write("max-height:") catch {};
                writer.writeF32(size.height.size.min_max_vp.max) catch {};
                writer.write("vh;\n") catch {};
            } else {
                writePropValue("height", .{ .tag = .sizing, .data = .{ .sizing = size.height } }, &writer);
            }
        } else if (size.height.type == .grow) {
            writer.write("flex: 1;\n") catch {};
        }
    }

    // Padding
    if (style.padding) |padding| {
        writePropValue("padding", .{ .tag = .padding, .data = .{ .padding = padding } }, &writer);
    }
    if (style.margin) |margin| {
        writePropValue("margin", .{ .tag = .margin, .data = .{ .margin = margin } }, &writer);
    }

    if (style.visual) |visual| {
        checkVisual(ptr, &visual, &writer, 4);
    }

    // Alignment
    if (style.child_gap) |gap| {
        writer.write("gap:") catch {};
        writer.writeU32(gap) catch {};
        writer.write("px;\n") catch {};
    }

    // Text-Deco
    if (style.text_decoration) |td| {
        writePropValue("text-decoration", .{ .tag = .text_decoration, .data = .{ .text_decoration = td } }, &writer);
    }

    if (style.white_space) |ws| {
        writePropValue("white-space", .{ .tag = .white_space, .data = .{ .white_space = ws } }, &writer);
    }
    if (style.flex_wrap) |fw| {
        writePropValue("flex-wrap", .{ .tag = .flex_wrap, .data = .{ .flex_wrap = fw } }, &writer);
    }

    if (style.animation) |an| {
        writePropValue("animation", .{ .tag = .animation_specs, .data = .{ .animation_specs = an } }, &writer);
        writer.write("animation-delay:") catch {};
        writer.writeF32(an.delay) catch {};
        writer.write("s;\n") catch {};
    }

    if (style.z_index) |zi| {
        writer.write("z-index:") catch {};
        writer.writeF32(zi) catch {};
        writer.write(";\n") catch {};
    }

    if (style.blur) |bl| {
        writer.write("backdrop-filter:blur(") catch {};
        writer.writeU32(bl) catch {};
        writer.write("px);\n") catch {};
    }

    if (style.scroll) |scroll| {
        if (scroll.x) |x| {
            switch (x) {
                .scroll => writer.write("overflow-x:scroll;\n") catch {},
                .hidden => writer.write("overflow-x:hidden;\n") catch {},
            }
        }
        if (scroll.y) |y| {
            switch (y) {
                .scroll => writer.write("overflow-y:scroll;\n") catch {},
                .hidden => writer.write("overflow-y:hidden;\n") catch {},
            }
        }

        if (style.position == null) {
            writer.write("position:relative;\n") catch {};
        }
    }

    if (style.list_style) |ls| {
        writePropValue("list-style", .{ .tag = .list_style, .data = .{ .list_style = ls } }, &writer);
    }

    if (style.outline) |ol| {
        writePropValue("outline", .{ .tag = .outline, .data = .{ .outline = ol } }, &writer);
    }

    if (style.font_family.len > 0) {
        writer.write("font-family:") catch {};
        writer.write(style.font_family) catch {};
        writer.write(";\n") catch {};
    }

    if (style.transition) |tr| {
        writePropValue("transition", .{ .tag = .transition, .data = .{ .transition = tr } }, &writer);
    }

    if (!style.show_scrollbar) {
        writer.write("scrollbar-width:none;\n") catch {};
        show_scrollbar = false;
    }

    if (style.cursor) |c| {
        writePropValue("cursor", .{ .tag = .cursor, .data = .{ .cursor = c } }, &writer);
    } else if (ptr != null and ptr.?.type == .Button or ptr.?.type == .CtxButton or ptr.?.type == .ButtonCycle) {
        writePropValue("cursor", .{ .tag = .cursor, .data = .{ .cursor = .pointer } }, &writer);
    }

    if (style.appearance) |ap| {
        writePropValue("appearance", .{ .tag = .appearance, .data = .{ .appearance = ap } }, &writer);
    }

    if (style.will_change) |wc| {
        switch (wc) {
            .transform => {
                writer.write("will-change:") catch {};
                writer.write("transform") catch {};
                writer.write(";\n") catch {};
            },
            else => {},
        }
    }

    if (style.transform_origin) |to| {
        writePropValue("transform-origin", .{ .tag = .transform_origin, .data = .{ .transform_origin = to } }, &writer);
    }

    // writer.write("box-sizing: border-box;\n") catch {};

    // Null-terminate the string
    const len: usize = writer.pos;
    css_buffer[len] = 0;
    style_style = css_buffer[0..len];
}

pub fn generateStylePass(ptr: ?*UINode, style: *const Types.Style, writer: *Writer) void {
    // Use a fixed buffer with a fbs to build the CSS string

    // Write position properties
    if (style.position) |p| {
        writePropValue("position", .{ .tag = .position_type, .data = .{ .position_type = p.type } }, writer); // adds 9kb
        if (p.left) |pl| {
            writePropValue("left", .{ .tag = .pos, .data = .{ .pos = pl } }, writer);
        }
        if (p.right) |pr| {
            writePropValue("right", .{ .tag = .pos, .data = .{ .pos = pr } }, writer);
        }
        if (p.top) |pt| {
            writePropValue("top", .{ .tag = .pos, .data = .{ .pos = pt } }, writer);
        }
        if (p.bottom) |pb| {
            writePropValue("bottom", .{ .tag = .pos, .data = .{ .pos = pb } }, writer);
        }
    }

    // Write display and flex properties
    if (ptr != null and ptr.?.type == .FlexBox) {
        writePropValue("display", .{ .tag = .flex_type, .data = .{ .flex_type = .Flex } }, writer);
        writePropValue("flex-direction", .{ .tag = .direction, .data = .{ .direction = style.direction } }, writer);
        if (style.layout) |layout| {
            if (style.direction == .row) {
                writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
                writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
            } else {
                writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
                writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
            }
        }
    } else if (style.layout) |layout| {
        if (ptr != null and ptr.?.text != null and layout.x == .center and layout.y == .center and ptr.?.type != .Svg) {
            writePropValue("text-align", .{ .tag = .alignment, .data = .{ .alignment = .center } }, writer);
        } else {
            writePropValue("display", .{ .tag = .flex_type, .data = .{ .flex_type = .Flex } }, writer);
            writePropValue("flex-direction", .{ .tag = .direction, .data = .{ .direction = style.direction } }, writer);

            if (layout.x == .center and layout.y == .center) {
                writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = .center } }, writer);
                writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = .center } }, writer);
            } else {
                if (style.direction == .row) {
                    writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
                    writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
                } else {
                    writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
                    writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
                }
            }
        }
    }

    if (style.size) |size| {
        if (size.width.type != .none and size.width.type != .grow) {
            if (size.width.type == .min_max_vp) {
                writer.write("max-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("vw;\n") catch {};
                writer.write("min-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("vw;\n") catch {};
            } else if (size.width.type == .elastic_percent) {
                writer.write("max-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("%;\n") catch {};
                writer.write("min-width:") catch {};
                writer.writeF32(size.width.size.min_max_vp.max) catch {};
                writer.write("%;\n") catch {};
            } else {
                writePropValue("width", .{ .tag = .sizing, .data = .{ .sizing = size.width } }, writer);
            }
        } else if (size.width.type == .grow) {
            writer.write("flex: 1;\n") catch {};
        }

        if (size.height.type != .none and size.height.type != .grow) {
            if (size.height.type == .min_max_vp) {
                writer.write("min-height:") catch {};
                writer.writeF32(size.height.size.min_max_vp.min) catch {};
                writer.write("vh;\n") catch {};
                writer.write("max-height:") catch {};
                writer.writeF32(size.height.size.min_max_vp.max) catch {};
                writer.write("vh;\n") catch {};
            } else {
                writePropValue("height", .{ .tag = .sizing, .data = .{ .sizing = size.height } }, writer);
            }
        } else if (size.height.type == .grow) {
            writer.write("flex: 1;\n") catch {};
        }
    }

    // Padding
    if (style.padding) |padding| {
        writePropValue("padding", .{ .tag = .padding, .data = .{ .padding = padding } }, writer);
    }
    if (style.margin) |margin| {
        writePropValue("margin", .{ .tag = .margin, .data = .{ .margin = margin } }, writer);
    }

    if (style.visual) |visual| {
        checkVisual(ptr, &visual, writer, 4);
    }

    // Alignment
    if (style.child_gap) |gap| {
        writer.write("gap:") catch {};
        writer.writeU32(gap) catch {};
        writer.write("px;\n") catch {};
    }

    // Text-Deco
    if (style.text_decoration) |td| {
        writePropValue("text-decoration", .{ .tag = .text_decoration, .data = .{ .text_decoration = td } }, writer);
    }

    if (style.white_space) |ws| {
        writePropValue("white-space", .{ .tag = .white_space, .data = .{ .white_space = ws } }, writer);
    }
    if (style.flex_wrap) |fw| {
        writePropValue("flex-wrap", .{ .tag = .flex_wrap, .data = .{ .flex_wrap = fw } }, writer);
    }

    if (style.animation) |an| {
        writePropValue("animation", .{ .tag = .animation_specs, .data = .{ .animation_specs = an } }, writer);
        writer.write("animation-delay:") catch {};
        writer.writeF32(an.delay) catch {};
        writer.write("s;\n") catch {};
    }

    if (style.z_index) |zi| {
        writer.write("z-index:") catch {};
        writer.writeF32(zi) catch {};
        writer.write(";\n") catch {};
    }

    if (style.blur) |bl| {
        writer.write("backdrop-filter:blur(") catch {};
        writer.writeU32(bl) catch {};
        writer.write("px);\n") catch {};
    }

    if (style.scroll) |scroll| {
        if (scroll.x) |x| {
            switch (x) {
                .scroll => writer.write("overflow-x:scroll;\n") catch {},
                .hidden => writer.write("overflow-x:hidden;\n") catch {},
            }
        }
        if (scroll.y) |y| {
            switch (y) {
                .scroll => writer.write("overflow-y:scroll;\n") catch {},
                .hidden => writer.write("overflow-y:hidden;\n") catch {},
            }
        }

        if (style.position == null) {
            writer.write("position:relative;\n") catch {};
        }
    }

    // writer.write("scrollbar-width:none;\n") catch {};
    if (style.list_style) |ls| {
        writePropValue("list-style", .{ .tag = .list_style, .data = .{ .list_style = ls } }, writer);
    }

    if (style.outline) |ol| {
        writePropValue("outline", .{ .tag = .outline, .data = .{ .outline = ol } }, writer);
    }

    if (style.font_family.len > 0) {
        writer.write("font-family:") catch {};
        writer.write(style.font_family) catch {};
        writer.write(";\n") catch {};
    }

    if (style.transition) |tr| {
        writePropValue("transition", .{ .tag = .transition, .data = .{ .transition = tr } }, writer);
    }

    if (!style.show_scrollbar) {
        writer.write("scrollbar-width:none;\n") catch {};
        show_scrollbar = false;
    }

    if (style.cursor) |c| {
        writePropValue("cursor", .{ .tag = .cursor, .data = .{ .cursor = c } }, writer);
    }

    if (style.appearance) |ap| {
        writePropValue("appearance", .{ .tag = .appearance, .data = .{ .appearance = ap } }, writer);
    }

    if (style.will_change) |wc| {
        switch (wc) {
            .transform => {
                writer.write("will-change:") catch {};
                writer.write("transform") catch {};
                writer.write(";\n") catch {};
            },
            else => {},
        }
    }

    if (style.transform_origin) |to| {
        writePropValue("transform-origin", .{ .tag = .transform_origin, .data = .{ .transform_origin = to } }, writer);
    }

    // writer.write("box-sizing: border-box;\n") catch {};

    // Null-terminate the string
    // const len: usize = writer.pos;
    // css_buffer[len] = 0;
    // style_style = css_buffer[0..len];
}

pub export fn getStyle(node_ptr: ?*UINode) ?[*]const u8 {
    if (node_ptr == null) return style_style.ptr;
    const style = node_ptr.?.style orelse return null;
    generateStyle(node_ptr, style);
    // Return a pointer to the CSS string
    return style_style.ptr;
}

pub export fn getGlobalStyle() ?[*]const u8 {
    const user_defaults = Vapor.Style.getDefault();
    generateStyle(null, &user_defaults);
    // Return a pointer to the CSS string
    return style_style.ptr;
}
pub const Catalog = struct {
    themes: []const Types.ThemeDefinition,
};

var global_style: []const u8 = "";
var global_buffer: [4096]u8 = undefined;
var has_default: bool = false;
pub fn setGlobalStyleVariables(catalog: Catalog) void {
    const theme_fields = @typeInfo(Theme.Colors).@"struct".fields;
    var writer: Writer = undefined;
    writer.init(&global_buffer);

    for (catalog.themes) |theme_def| {
        const name = theme_def.name;
        const theme = theme_def.theme;
        if (theme_def.default and has_default) {
            Vapor.printlnErr("Theme {s} is default, but another theme is also default", .{name});
            return;
        }
        if (theme_def.default) {
            has_default = true;
            writer.write(":root") catch {};
        } else {
            // here we write the root theme
            writer.write("[data-theme=") catch {};
            writer.writeByte('"') catch {};
            writer.write(name) catch {};
            writer.writeByte('"') catch {};
            writer.write("]") catch {};
        }
        writer.write(" {\n") catch {};

        inline for (theme_fields) |field| {
            const field_value = @field(theme, field.name);
            const field_name = field.name;
            const field_type = field.type;
            switch (field_type) {
                []const u8 => {
                    writer.write("--") catch {};
                    writer.write(field_name) catch {};
                    writer.writeByte(':') catch {};
                    writer.write(field_value) catch {};
                    writer.write(";\n") catch {};
                },
                Color => {
                    writer.write("--") catch {};
                    writer.write(field_name) catch {};
                    writer.writeByte(':') catch {};
                    writer.writeU8Num(field_value.Literal.r) catch {};
                    writer.writeByte(',') catch {};
                    writer.writeU8Num(field_value.Literal.g) catch {};
                    writer.writeByte(',') catch {};
                    writer.writeU8Num(field_value.Literal.b) catch {};
                    // writer.writeByte(',') catch {};
                    // writer.writeF32(field_value.Literal.a) catch {};
                    writer.writeByte(';') catch {};
                    // colorToCSS(field_value, &writer) catch {};
                    writer.write(";\n") catch {};
                },
                else => {},
            }
        }
        writer.write("}\n") catch {};
    }
    const len: usize = writer.pos;
    global_buffer[len] = 0;
    global_style = global_buffer[0..len];
}

pub export fn getGlobalVariablesPtr() [*]const u8 {
    return global_style.ptr;
}

pub export fn getGlobalVariablesLen() usize {
    return global_style.len;
}

export fn showScrollBar() bool {
    return show_scrollbar;
}

export fn getStyleLen() usize {
    return style_style.len;
}

var visual_style: []const u8 = "";
pub export fn getVisualStyle(node_ptr: ?*UINode, visual_type: u8) ?[*]const u8 {
    if (node_ptr == null) return visual_style.ptr;
    const node_style = node_ptr.?.style orelse return null;
    const interactive = node_style.interactive orelse return null;
    const ptr = node_ptr.?;
    var writer: Writer = undefined;
    writer.init(&css_buffer);
    if (visual_type == 0) {
        const visual = interactive.hover.?;
        checkVisual(ptr, &visual, &writer, 0);
    } else if (visual_type == 1) {
        const visual = interactive.focus.?;
        checkVisual(ptr, &visual, &writer, 1);
    } else if (visual_type == 2) {
        const visual = interactive.focus_within.?;
        checkVisual(ptr, &visual, &writer, 2);
    }
    // Null-terminate the string
    const len: usize = writer.pos;
    css_buffer[len] = 0;
    visual_style = css_buffer[0..len];

    // Return a pointer to the CSS string
    return visual_style.ptr;
}

export fn getVisualLen() usize {
    return visual_style.len;
}

var tooltip_style: []const u8 = "";
pub export fn getTooltipStyle(
    _: ?*UINode,
) ?[*]const u8 {
    return null;
    // if (node_ptr == null) return style_style.ptr;
    // const tooltip = node_ptr.?.tooltip orelse return null;
    // const style = tooltip.style orelse return null;
    // var writer: Writer = undefined;
    // writer.init(&css_buffer);
    // writer.write("content: attr(data-tooltip);\n") catch {};
    // generateStylePass(node_ptr, &style, &writer);
    // // Null-terminate the string
    // const len: usize = writer.pos;
    // css_buffer[len] = 0;
    // tooltip_style = css_buffer[0..len];
    //
    // // Return a pointer to the CSS string
    // return tooltip_style.ptr;
}

export fn getTooltipStyleLen() usize {
    return tooltip_style.len;
}
