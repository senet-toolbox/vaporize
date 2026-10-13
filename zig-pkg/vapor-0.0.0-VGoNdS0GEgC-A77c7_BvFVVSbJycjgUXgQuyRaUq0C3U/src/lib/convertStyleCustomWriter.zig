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
const PackedTransition = Types.PackedTransition;
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
        dots,
        color,
        list_style,
        outline,
        // animation_specs,
        transition,
        shadow,
        border,
        border_radius,
        flex_type,
        string_literal, // For values like "flex", "center", etc.
        opacity,
        font_style,
        aspect_ratio,
        gradient,
        layers,
        caret,
        resize,
    };

    // Union to hold the actual data
    const Data = union(Tag) {
        position_type: Types.PositionType,
        direction: Types.Direction,
        sizing: Types.Sizing,
        padding: Types.Padding,
        cursor: Types.Cursor,
        appearance: Types.Appearance,
        transform_type: Types.PackedTransform,
        transform_origin: Types.TransformOrigin,
        margin: Types.Margin,
        pos: Types.Pos,
        text_decoration: Types.PackedTextDecoration,
        white_space: Types.WhiteSpace,
        flex_wrap: Types.FlexWrap,
        alignment: Types.Alignment,
        layer: Types.PackedGrid,
        dots: Types.PackedDots,
        color: Types.PackedColor,
        list_style: Types.ListStyle,
        outline: Types.Outline,
        // animation_specs: Animation.Specs,
        transition: Types.PackedTransition,
        shadow: Types.PackedShadow,
        border: Types.Border,
        border_radius: Types.BorderRadius,
        flex_type: Types.FlexType,
        string_literal: []const u8,
        opacity: f32,
        font_style: Types.FontStyle,
        aspect_ratio: Types.AspectRatio,
        gradient: Types.PackedGradient,
        layers: Types.PackedLayers,
        caret: Types.PackedCaret,
        resize: Types.Resize,
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
        .font_style => fontStyleToCSS(value.data.font_style, writer) catch {},
        .padding => {
            writer.writeU8Num(value.data.padding.top) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(value.data.padding.right) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(value.data.padding.bottom) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(value.data.padding.left) catch {};
            writer.write("px") catch {};
        },
        .cursor => cursorToCSS(value.data.cursor, writer) catch {},
        .appearance => appearanceToCSS(value.data.appearance, writer) catch {},
        .transform_type => {
            const transform = value.data.transform_type;
            const slice = transform.type_ptr.?.*[0..transform.type_len];
            for (slice) |t| {
                switch (t) {
                    .scale => {
                        writer.write("scale(") catch {};
                        writer.writeF16(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .scaleY => {
                        writer.write("scaleY(") catch {};
                        writer.writeF16(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .scaleX => {
                        writer.write("scaleX(") catch {};
                        writer.writeF16(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .translateX => {
                        writer.write("translateX(") catch {};
                        writer.writeF16(transform.trans_x) catch {};
                        if (transform.size_type == .percent) {
                            writer.write("%)") catch {};
                        } else if (transform.size_type == .px) {
                            writer.write("px)") catch {};
                        }
                    },
                    .translateY => {
                        writer.write("translateY(") catch {};
                        writer.writeF16(transform.trans_y) catch {};
                        if (transform.size_type == .percent) {
                            writer.write("%)") catch {};
                        } else if (transform.size_type == .px) {
                            writer.write("px)") catch {};
                        }
                    },
                    .rotate => {
                        writer.write("rotate(") catch {};
                        writer.writeF16(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateX => {
                        writer.write("rotateX(") catch {};
                        writer.writeF16(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateY => {
                        writer.write("rotateY(") catch {};
                        writer.writeF16(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateXYZ => {
                        writer.write("rotateX(") catch {};
                        writer.writeF16(transform.x) catch {};
                        writer.write("deg) ") catch {};
                        writer.write("rotateY(") catch {};
                        writer.writeF16(transform.y) catch {};
                        writer.write("deg) ") catch {};
                        writer.write("rotateZ(") catch {};
                        writer.writeF16(transform.z) catch {};
                        writer.write("deg)") catch {};
                    },
                    .none => {},
                }
                writer.writeByte(' ') catch {};
            }
        },
        .transform_origin => transformOriginToCSS(value.data.transform_origin, writer) catch {},
        .margin => {
            writer.writeI16(value.data.margin.top) catch {};
            writer.write("px ") catch {};
            writer.writeI16(value.data.margin.right) catch {};
            writer.write("px ") catch {};
            writer.writeI16(value.data.margin.bottom) catch {};
            writer.write("px ") catch {};
            writer.writeI16(value.data.margin.left) catch {};
            writer.write("px") catch {};
        },
        .pos => posTypeToCSS(value.data.pos, writer) catch {},
        .text_decoration => textDecoToCSS(value.data.text_decoration, writer) catch {},
        .white_space => whiteSpaceToCSS(value.data.white_space, writer) catch {},
        .flex_wrap => flexWrapToCSS(value.data.flex_wrap, writer) catch {},
        .alignment => alignmentToCSS(value.data.alignment, writer) catch {},
        .layer => gridToCSS(value.data.layer, writer) catch {},
        .dots => dotsToCSS(value.data.dots, writer) catch {},
        .gradient => gradientToCSS(value.data.gradient, writer) catch {},
        .layers => layersToCSS(value.data.layers, writer) catch {},
        .color => colorToCSS(value.data.color, writer) catch {},
        .list_style => listStyleToCSS(value.data.list_style, writer) catch {},
        .outline => outlineStyleToCSS(value.data.outline, writer) catch {},
        .opacity => writer.writeF32(value.data.opacity) catch {},
        .resize => resizeToCSS(value.data.resize, writer) catch {},
        // .animation_specs => animationToCSS(value.data.animation_specs, writer) catch {},
        .transition => transitionStyleToCSS(value.data.transition, writer),
        .shadow => {
            const shadow = value.data.shadow;
            writer.writeI16(shadow.left) catch {};
            writer.write("px ") catch {};
            writer.writeI16(shadow.top) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(shadow.blur) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(shadow.spread) catch {};
            writer.write("px ") catch {};
            colorToCSS(shadow.color, writer) catch {};
        },
        .border => {
            const border = value.data.border;
            writer.writeU8Num(border.top) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(border.right) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(border.bottom) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(border.left) catch {};
            writer.write("px") catch {};
        },
        .border_radius => {
            const radius = value.data.border_radius;
            if (radius.top_left == radius.top_right and radius.top_left == radius.bottom_right and radius.top_left == radius.bottom_left) {
                writer.writeU8Num(radius.top_left) catch {};
                writer.write("px") catch {};
            } else {
                writer.writeU8Num(radius.top_left) catch {};
                writer.write("px ") catch {};
                writer.writeU8Num(radius.top_right) catch {};
                writer.write("px ") catch {};
                writer.writeU8Num(radius.bottom_right) catch {};
                writer.write("px ") catch {};
                writer.writeU8Num(radius.bottom_left) catch {};
                writer.write("px") catch {};
            }
        },
        .flex_type => flexTypeToCSS(value.data.flex_type, writer) catch {},
        .caret => caretToCSS(value.data.caret, writer) catch {},

        .aspect_ratio => aspectRatioToCSS(value.data.aspect_ratio, writer) catch {},
        // This new case handles simple string values efficiently.
        .string_literal => writer.write(value.data.string_literal) catch {},
    }
    writer.write(";\n") catch {};
}

// Maps for simple enum-to-string conversions
const direction_map = [_][]const u8{ "column", "row" };
const alignment_map = [_][]const u8{ "none", "center", "flex-start", "flex-end", "flex-start", "flex-end", "space-between", "space-evenly", "flex-start" };
const position_type_map = [_][]const u8{ "none", "relative", "absolute", "fixed", "sticky" };
const float_type_map = [_][]const u8{ "top", "bottom", "left", "right" };
const transform_origin_map = [_][]const u8{ "top", "bottom", "right", "left" };
const text_decoration_type_map = [_][]const u8{ "default", "none", "inherit", "underline", "initial", "overline", "unset", "revert" };
const text_decoration_style_map = [_][]const u8{ "default", "solid", "double", "dotted", "dashed", "wavy", "inherit", "initial", "revert", "unset" };
const appearance_map = [_][]const u8{ "none", "auto", "button", "textfield", "menulist", "searchfield", "textarea", "checkbox", "radio", "inherit", "initial", "revert", "unset" };
const outline_map = [_][]const u8{ "default", "none", "auto", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset", "inherit", "initial", "revert", "unset" };
const cursor_map = [_][]const u8{ "default", "pointer", "help", "grab", "zoom-in", "zoom-out" };
const box_sizing_map = [_][]const u8{ "content-box", "border-box", "padding-box", "inherit", "initial", "revert", "unset" };
const list_style_map = [_][]const u8{ "default", "none", "disc", "circle", "square", "decimal", "decimal-leading-zero", "lower-roman", "upper-roman", "lower-alpha", "upper-alpha", "lower-greek", "armenian", "georgian", "inherit", "initial", "revert", "unset" };
const flex_wrap_map = [_][]const u8{ "none", "nowrap", "wrap", "wrap-reverse", "inherit", "initial", "revert", "unset" };
const white_space_map = [_][]const u8{ "default", "normal", "nowrap", "pre", "pre-wrap", "pre-line", "break-spaces", "inherit", "initial", "revert", "unset" };
const flex_type_map = [_][]const u8{ "default", "flex", "inline", "block", "inline-block" };
const timing_function_map = [_][]const u8{ "ease", "linear", "ease-in", "ease-out", "ease-in-out", "bounce", "elastic" };
const animation_direction_map = [_][]const u8{ "normal ", "reverse ", "forwards ", "alternate " };
const font_style_map = [_][]const u8{ "default", "normal", "italic" };
const aspect_ratio_map = [_][]const u8{ "none", "1 / 1", "3 / 4", "16 / 9" };
const caret_map = [_][]const u8{ "none", "block", "line" };
const resize_map = [_][]const u8{ "default", "none", "both", "horizontal", "vertical" };

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

fn fontStyleToCSS(font_style: Types.FontStyle, writer: writer_t) !void {
    try writeMappedString(Types.FontStyle, font_style, &font_style_map, writer);
}

fn floatTypeToCSS(float_type: FloatType) []const u8 {
    return float_type_map[@intFromEnum(float_type)];
}

fn transformOriginToCSS(origin: TransformOrigin, writer: anytype) !void {
    try writeMappedString(TransformOrigin, origin, &transform_origin_map, writer);
}

fn aspectRatioToCSS(aspect_ratio: Types.AspectRatio, writer: anytype) !void {
    try writeMappedString(Types.AspectRatio, aspect_ratio, &aspect_ratio_map, writer);
}

fn textDecoToCSS(deco: Types.PackedTextDecoration, writer: anytype) !void {
    try writeMappedString(Types.TextDecorationType, deco.type, &text_decoration_type_map, writer);
    if (deco.style != .default) {
        try writer.writeByte(' ');
        try writeMappedString(Types.TextDecorationStyle, deco.style, &text_decoration_style_map, writer);
    }

    if (deco.color.has_color or deco.color.has_token) {
        try writer.writeByte(' ');
        colorToCSS(deco.color, writer) catch {};
    }
}
// Helper function to convert SizingType to CSS values
fn sizingTypeToCSS(sizing: Sizing, writer: writer_t) !void {
    switch (sizing.type) {
        .fit => try writer.write("fit-content"),
        .grow => try writer.write("flex:1"),
        .auto => try writer.write("auto"),
        .percent => {
            try writer.writeF32(sizing.size.min);
            try writer.writeByte('%');
        },
        .fixed => {
            try writer.writeF32(sizing.size.min);
            try writer.write("px");
        },
        .elastic => try writer.write("auto"), // Could also use min/max width/height in separate properties
        .elastic_percent => {
            try writer.writeF32(sizing.size.min);
            try writer.writeByte('%');
        },
        .clamp_px => {
            try writer.write("clamp(");
            try writer.writeF32(sizing.size.min);
            try writer.write("px,");
            try writer.writeF32(sizing.size.preferred);
            try writer.write("px,");
            try writer.writeF32(sizing.size.max);
            try writer.write("px)");
        },
        .clamp_percent => {
            try writer.write("clamp(");
            try writer.writeF32(sizing.size.min);
            try writer.write("%,");
            try writer.writeF32(sizing.size.preferred);
            try writer.write("%,");
            try writer.writeF32(sizing.size.max);
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
        else => {},
    }
}

// Helper function to convert color array to CSS rgba
fn colorToCSS(color: Types.PackedColor, writer: anytype) !void {
    if (color.has_color) {
        writeRgba(writer, color.color) catch {};
    } else if (color.has_token) {
        writeThematic(writer, color.token) catch {};
    }
}

fn writeThematic(writer: anytype, thematic: Types.Thematic) !void {
    if (thematic.alpha > -1) {
        try writer.write("rgba(");
        try writer.write("var(--");
        try writer.write(@tagName(thematic.token));
        try writer.write("), ");
        try writer.writeF32(thematic.alpha);
        try writer.writeByte(')');
    } else {
        try writer.write("rgb(var(--");
        try writer.write(@tagName(thematic.token));
        try writer.write("))");
    }
}

fn writeRgba(writer: anytype, rgba: Types.Rgba) !void {
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
}

// Helper function to convert color array to CSS rgba
fn gridToCSS(grid: Types.PackedGrid, writer: anytype) !void {
    writer.write("linear-gradient(90deg, ") catch {};
    const grid_color = grid.packed_color.has_color;
    if (grid_color) {
        const rgba = grid.packed_color.color;
        writeRgba(writer, rgba) catch {};
    } else {
        writeThematic(writer, grid.packed_color.token) catch {};
    }
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px, ") catch {};
    writeRgba(writer, .{}) catch {};
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px),") catch {};

    writer.write("linear-gradient(180deg, ") catch {};
    if (grid_color) {
        const rgba = grid.packed_color.color;
        writeRgba(writer, rgba) catch {};
    } else {
        writeThematic(writer, grid.packed_color.token) catch {};
    }
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px, ") catch {};
    writeRgba(writer, .{}) catch {};
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px)") catch {};
}

fn dotsToCSS(dots: Types.PackedDots, writer: anytype) !void {
    writer.write("radial-gradient(circle, ") catch {};
    const dots_color = dots.packed_color.has_color;
    if (dots_color) {
        const rgba = dots.packed_color.color;
        writeRgba(writer, rgba) catch {};
    } else {
        writeThematic(writer, dots.packed_color.token) catch {};
    }
    writer.writeByte(' ') catch {};
    writer.writeF16(dots.radius) catch {};
    writer.write("px, ") catch {};
    writer.write("transparent") catch {};
    writer.writeByte(' ') catch {};
    writer.writeF16(0) catch {};
    writer.write("px)") catch {};
}

fn gradientToCSS(gradient: Types.PackedGradient, writer: writer_t) !void {
    switch (gradient.type) {
        .linear => {
            writer.write("linear-gradient(") catch {};
        },
        .radial => {
            writer.write("radial-gradient(") catch {};
        },
        else => {
            Vapor.printlnSrcErr("Gradient is not radius or linear", .{}, @src());
        },
    }
    switch (gradient.direction.type) {
        .to_top => writer.write("to top") catch {},
        .to_bottom => writer.write("to bottom") catch {},
        .to_left => writer.write("to left") catch {},
        .to_right => writer.write("to right") catch {},
        .angle => {
            writer.writeF32(gradient.direction.angle) catch {};
            writer.write("deg") catch {};
        },
        .none => {},
    }
    var colors = gradient.colors_ptr orelse {
        Vapor.printlnSrcErr("Colors ptr is null", .{}, @src());
        return;
    };
    for (colors[0..gradient.colors_len]) |color| {
        writer.write(", ") catch {};
        colorToCSS(color, writer) catch {};
    }
    writer.write(")") catch {};
}

fn linesToCSS(lines: Types.PackedLines, writer: anytype) !void {
    writer.write("repeating-linear-gradient(") catch {};

    switch (lines.direction) {
        .horizontal => writer.write("0deg") catch {},
        .vertical => writer.write("90deg") catch {},
        .diagonal_up => writer.write("-45deg") catch {},
        .diagonal_down => writer.write("45deg") catch {},
    }

    writer.write(", ") catch {};

    const has_color = lines.color.has_color;
    if (has_color) {
        writeRgba(writer, lines.color.color) catch {};
    } else {
        writeThematic(writer, lines.color.token) catch {};
    }

    writer.write(" 0px, ") catch {};

    if (has_color) {
        writeRgba(writer, lines.color.color) catch {};
    } else {
        writeThematic(writer, lines.color.token) catch {};
    }

    writer.writeByte(' ') catch {};
    writer.writeU8Num(lines.thickness) catch {};
    writer.write("px, transparent ") catch {};
    writer.writeU8Num(lines.thickness) catch {};
    writer.write("px, transparent ") catch {};
    writer.writeU8Num(lines.spacing) catch {};
    writer.write("px)") catch {};
}

fn layersToCSS(packed_layers: Types.PackedLayers, writer: writer_t) !void {
    // const start = writer.pos;
    for (packed_layers.items_ptr.?[0..packed_layers.len], 0..) |layer, i| {
        switch (layer) {
            .Grid => |grid| {
                try gridToCSS(grid, writer);
            },
            .Dot => |dots| {
                try dotsToCSS(dots, writer);
            },
            .Lines => |lines| {
                try linesToCSS(lines, writer);
            },
            .Gradient => |gradient| {
                try gradientToCSS(gradient, writer);
            },
        }
        if (i < packed_layers.len - 1) {
            writer.write(", \n") catch {};
        } else {
            writer.write(";\n") catch {};
        }
    }

    writer.write("background-size: ") catch {};
    for (packed_layers.items_ptr.?[0..packed_layers.len], 0..) |layer, i| {
        switch (layer) {
            .Grid => |grid| {
                writer.writeU16(grid.size) catch {};
                writer.write("px ") catch {};
                writer.writeU16(grid.size) catch {};
                writer.write("px, ") catch {};

                writer.writeU16(grid.size) catch {};
                writer.write("px ") catch {};
                writer.writeU16(grid.size) catch {};
                writer.write("px") catch {};
            },
            .Lines => |lines| {
                writer.writeU16(lines.spacing) catch {};
                writer.write("px ") catch {};
                writer.writeU16(lines.spacing) catch {};
                writer.write("px") catch {};
            },
            .Dot => |dots| {
                writer.writeU16(dots.spacing) catch {};
                writer.write("px ") catch {};
                writer.writeU16(dots.spacing) catch {};
                writer.write("px") catch {};
            },
            .Gradient => {
                writer.write("100% 100%") catch {};
            },
        }
        if (i < packed_layers.len - 1) {
            writer.write(", \n") catch {};
        } else {
            writer.write(";\n") catch {};
        }
    }

    writer.write("background-position: center center") catch {};
    // Vapor.printlnSrcErr("GradientToCSS {s}", .{writer.buffer[start..writer.pos]}, @src());
}

fn appearanceToCSS(appearance: Appearance, writer: anytype) !void {
    try writeMappedString(Appearance, appearance, &appearance_map, writer);
}

// Function to convert OutlineStyle enum to a CSS string
fn outlineStyleToCSS(outline: Outline, writer: anytype) !void {
    try writeMappedString(Outline, outline, &outline_map, writer);
}

fn transitionStyleToCSS(style: PackedTransition, writer: writer_t) void {
    const properties = style.properties_ptr orelse return;
    const slice = properties.*[0..style.properties_len];
    if (slice.len > 0) {
        for (slice) |p| {
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

fn caretToCSS(caret: Types.PackedCaret, writer: anytype) !void {
    // try writeMappedString(Types.CaretType, caret.type, &caret_map, writer);
    // writer.writeByte(' ') catch {};
    colorToCSS(caret.color, writer) catch {};
}

fn resizeToCSS(resize: Types.Resize, writer: anytype) !void {
    Vapor.print("Resize: {any}\n", .{resize});
    try writeMappedString(Types.Resize, resize, &resize_map, writer);
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
    // writer.write(" ") catch {};
    // writer.writeF32(animation.duration_ms) catch {};
    // writer.write("s ") catch {};
    // try writeMappedString(TimingFunction, animation.timing_function, &timing_function_map, writer);
    // try writeMappedString(AnimDir, animation.direction, &animation_direction_map, writer);
    // if (animation.iteration_count.iter_count == 0) {
    //     try writer.write("infinite");
    // }
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

pub fn generateVisual(visual: *const Types.PackedVisual, writer: writer_t) void {
    // Color color
    if (visual.background.has_color or visual.background.has_token) {
        writePropValue("background-color", .{ .tag = .color, .data = .{ .color = visual.background } }, writer);
    }
    // if (visual.background_gradient.type != .none) {
    //     writePropValue("background-image", .{ .tag = .gradient, .data = .{ .gradient = visual.background_gradient } }, writer);
    // }
    // if (visual.background_grid.packed_color.has_color or visual.background_grid.packed_color.has_token) {
    //     writePropValue("background-image", .{ .tag = .layer, .data = .{ .layer = visual.background_grid } }, writer);
    // } else if (visual.background_dots.packed_color.has_color or visual.background_dots.packed_color.has_token) {
    //     writePropValue("background-image", .{ .tag = .dots, .data = .{ .dots = visual.background_dots } }, writer);
    // }

    if (visual.packed_layers.items_ptr != null) {
        writePropValue("background-image", .{ .tag = .layers, .data = .{ .layers = visual.packed_layers } }, writer);

        if (visual.is_text_gradient) {
            writer.write("background-clip: text;\n") catch {};
            writer.write("-webkit-background-clip: text;\n") catch {};
            writer.write("-webkit-text-fill-color: transparent;\n") catch {};
        }
    }

    if (visual.blur > 0) {
        writer.write("backdrop-filter:blur(") catch {};
        writer.writeU8Num(visual.blur) catch {};
        writer.write("px);\n") catch {};
    }

    if (visual.cursor != .default) {
        writePropValue("cursor", .{ .tag = .cursor, .data = .{ .cursor = visual.cursor } }, writer);
    }

    // Write font properties
    if (visual.font_size > 0) {
        writer.write("font-size:") catch {};
        writer.writeU8Num(visual.font_size) catch {};
        writer.write("px;\n") catch {};
    }

    if (visual.ellipsis != .none) {
        switch (visual.ellipsis) {
            .dot => {
                writer.write("text-overflow: ellipsis;\n") catch {};
                writer.write("overflow: hidden;\n") catch {};
                writer.write("white-space: nowrap;\n") catch {};
            },
            .dash => {
                writer.write("text-overflow: ---;\n") catch {};
                writer.write("overflow: hidden;\n") catch {};
                writer.write("white-space: nowrap;\n") catch {};
            },
            else => {},
        }
    }

    // if (visual.letter_spacing > 0) {
    //     writer.write("letter-spacing:") catch {};
    //     writer.writeI32(visual.letter_spacing) catch {};
    //     writer.write("px;\n") catch {};
    // }
    // if (visual.line_height) |lh| {
    //     writer.write("line-height:") catch {};
    //     writer.writeI32(lh) catch {};
    //     writer.write("px;\n") catch {};
    // }

    if (visual.font_family_ptr) |font_family_ptr| {
        writer.write("font-family:") catch {};
        const font_family = font_family_ptr[0..visual.font_family_len];
        writer.write(font_family) catch {};
        writer.write(";\n") catch {};
    }

    if (visual.fill.has_color or visual.fill.has_token) {
        writePropValue("fill", .{ .tag = .color, .data = .{ .color = visual.fill } }, writer);
    }

    if (visual.stroke.has_color or visual.stroke.has_token) {
        writePropValue("stroke", .{ .tag = .color, .data = .{ .color = visual.stroke } }, writer);
    }

    if (visual.font_weight > 0) {
        writer.write("font-weight:") catch {};
        writer.writeUsize(visual.font_weight) catch {};
        writer.write(";\n") catch {};
    }

    if (visual.font_style != .default) {
        writePropValue("font-style", .{ .tag = .font_style, .data = .{ .font_style = visual.font_style } }, writer);
    }

    if (visual.has_border_thickeness) {
        const border_thickness = visual.border_thickness;
        writePropValue("border-width", .{ .tag = .border, .data = .{ .border = border_thickness } }, writer);
        writer.write("border-style: solid;\n") catch {};
    }
    // else if (ptr.type == .Button or ptr.type == .CtxButton) {
    //     _ = writer.write("border:none;\n") catch {};
    // }
    if (visual.has_border_color) {
        const border_color = visual.border_color;
        writePropValue("border-color", .{ .tag = .color, .data = .{ .color = border_color } }, writer);
    }
    if (visual.has_border_radius) {
        const border_radius = visual.border_radius;
        writePropValue("border-radius", .{ .tag = .border_radius, .data = .{ .border_radius = border_radius } }, writer);
    }

    // Text color
    if (visual.text_color.has_color or visual.text_color.has_token) {
        const color = visual.text_color;
        // if (ptr.type == .Svg or ptr.type == .Graphic) {
        //     writePropValue("fill", .{ .tag = .color, .data = .{ .color = color } }, writer);
        //     writePropValue("stroke", .{ .tag = .color, .data = .{ .color = color } }, writer);
        // } else {
        writePropValue("color", .{ .tag = .color, .data = .{ .color = color } }, writer);
        // }
    }

    if (visual.list_style != .default) {
        writePropValue("list-style", .{ .tag = .list_style, .data = .{ .list_style = visual.list_style } }, writer);
    }

    if (visual.outline != .default) {
        writePropValue("outline", .{ .tag = .outline, .data = .{ .outline = visual.outline } }, writer);
    }

    // Shadow
    if (visual.shadow.blur > 0 or visual.shadow.spread > 0 or
        visual.shadow.top != 0 or visual.shadow.left != 0)
    {
        writePropValue("box-shadow", .{ .tag = .shadow, .data = .{ .shadow = visual.shadow } }, writer);
    }

    // Text-Deco
    if (visual.text_decoration.type != .default) {
        writePropValue("text-decoration", .{ .tag = .text_decoration, .data = .{ .text_decoration = visual.text_decoration } }, writer);
    }

    // Transform
    if (visual.has_opacity) {
        writePropValue("opacity", .{ .tag = .opacity, .data = .{ .opacity = visual.opacity } }, writer);
    }

    if (visual.has_white_space) {
        writePropValue("white-space", .{ .tag = .white_space, .data = .{ .white_space = visual.white_space } }, writer);
    }

    if (visual.has_transitions and visual.transitions.properties_ptr != null) {
        writePropValue("transition", .{ .tag = .transition, .data = .{ .transition = visual.transitions } }, writer);
    }

    // There is experimental support for caret type ie block or line
    if (visual.caret.type != .none) {
        writePropValue("caret-color", .{ .tag = .caret, .data = .{ .caret = visual.caret } }, writer);
    }

    if (visual.resize != .default) {
        writePropValue("resize", .{ .tag = .resize, .data = .{ .resize = visual.resize } }, writer);
    }
}

// Export this function to be called from JavaScript to get the CSS representation
pub var style_style: []const u8 = "";
var global_len: usize = 0;
var show_scrollbar: bool = true;
// 61.8kb before this function
// adds 20kb

pub fn generateLayout(layout_ptr: *const Types.PackedLayout, writer: *Writer) void {
    const layout = layout_ptr.layout;
    const direction = layout_ptr.direction;
    if (layout_ptr.flex != .default) {
        writePropValue("display", .{ .tag = .flex_type, .data = .{ .flex_type = layout_ptr.flex } }, writer);
        writePropValue("flex-direction", .{ .tag = .direction, .data = .{ .direction = direction } }, writer);
    }
    if (layout.x != .none and layout.y != .none) {
        if (direction == .row) {
            writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
            writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
        } else {
            writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
            writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
        }
    } else if (layout_ptr.text_align.x != .none) {
        writePropValue("text-align", .{ .tag = .alignment, .data = .{ .alignment = layout_ptr.text_align.x } }, writer);
    }
    // Alignment
    if (layout_ptr.child_gap > 0) {
        writer.write("gap:") catch {};
        writer.writeU8Num(layout_ptr.child_gap) catch {};
        writer.write("px;\n") catch {};
    }

    const size = layout_ptr.size;
    if (size.width.type != .none and size.width.type != .grow) {
        if (size.width.type == .min_max_vp) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("vw;\n") catch {};
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("vw;\n") catch {};
        } else if (size.width.type == .elastic_percent) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("%;\n") catch {};
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("%;\n") catch {};
        } else {
            writePropValue("width", .{ .tag = .sizing, .data = .{ .sizing = size.width } }, writer);
        }
    } else if (size.width.type == .grow) {
        writer.write("flex: 1;\n") catch {};
        // writer.write("min-width: 0;\n") catch {};
    }

    if (size.height.type != .none and size.height.type != .grow) {
        if (size.height.type == .min_max_vp) {
            writer.write("min-height:") catch {};
            writer.writeF32(size.height.size.min) catch {};
            writer.write("vh;\n") catch {};
            writer.write("max-height:") catch {};
            writer.writeF32(size.height.size.max) catch {};
            writer.write("vh;\n") catch {};
        } else {
            writePropValue("height", .{ .tag = .sizing, .data = .{ .sizing = size.height } }, writer);
        }
    } else if (size.height.type == .grow) {
        writer.write("flex: 1;\n") catch {};
        // writer.write("min-height: 0;\n") catch {};
    }
    const scroll = layout_ptr.scroll;
    switch (scroll.x) {
        .scroll => writer.write("overflow-x:scroll;\n") catch {},
        .hidden => writer.write("overflow-x:hidden;\n") catch {},
        else => {},
    }
    switch (scroll.y) {
        .scroll => writer.write("overflow-y:scroll;\n") catch {},
        .hidden => writer.write("overflow-y:hidden;\n") catch {},
        else => {},
    }
    if (layout_ptr.flex_wrap != .none) {
        writePropValue("flex-wrap", .{ .tag = .flex_wrap, .data = .{ .flex_wrap = layout_ptr.flex_wrap } }, writer);
    }

    if (layout_ptr.aspect_ratio != .none) {
        writePropValue("aspect-ratio", .{ .tag = .aspect_ratio, .data = .{ .aspect_ratio = layout_ptr.aspect_ratio } }, writer);
        writer.write("object-fit: cover;\n") catch {};
    }
}

pub fn generatePositions(position: *const Types.PackedPosition, writer: *Writer) void {
    writePropValue("position", .{ .tag = .position_type, .data = .{ .position_type = position.position_type } }, writer);
    if (position.top.type != .none) {
        writePropValue("top", .{ .tag = .pos, .data = .{ .pos = position.top } }, writer);
    }
    if (position.right.type != .none) {
        writePropValue("right", .{ .tag = .pos, .data = .{ .pos = position.right } }, writer);
    }
    if (position.bottom.type != .none) {
        writePropValue("bottom", .{ .tag = .pos, .data = .{ .pos = position.bottom } }, writer);
    }
    if (position.left.type != .none) {
        writePropValue("left", .{ .tag = .pos, .data = .{ .pos = position.left } }, writer);
    }

    if (position.z_index > 0) {
        writer.write("z-index:") catch {};
        writer.writeI16(position.z_index) catch {};
        writer.write(";\n") catch {};
    }
}

pub fn generateMarginsPadding(margin_paddings_ptr: *const Types.PackedMarginsPaddings, writer: *Writer) void {
    writePropValue("padding", .{ .tag = .padding, .data = .{ .padding = margin_paddings_ptr.padding } }, writer);
    writePropValue("margin", .{ .tag = .margin, .data = .{ .margin = margin_paddings_ptr.margin } }, writer);

    // if (style.font_family) |ff| {
    //     writer.write("font-family:") catch {};
    //     writer.write(ff) catch {};
    //     writer.write(";\n") catch {};
    // }
    //
    // if (style.transition) |tr| {
    //     writePropValue("transition", .{ .tag = .transition, .data = .{ .transition = tr } }, writer);
    // }
    //
    // if (!style.show_scrollbar) {
    //     writer.write("scrollbar-width:none;\n") catch {};
    //     show_scrollbar = false;
    // }
    //
    // if (style.cursor) |c| {
    //     writePropValue("cursor", .{ .tag = .cursor, .data = .{ .cursor = c } }, writer);
    // } else if (ptr.type == .Button or ptr.type == .CtxButton or ptr.type == .ButtonCycle) {
    //     writePropValue("cursor", .{ .tag = .cursor, .data = .{ .cursor = .pointer } }, writer);
    // }
    //
    // if (style.appearance) |ap| {
    //     writePropValue("appearance", .{ .tag = .appearance, .data = .{ .appearance = ap } }, writer);
    // }
    //
    // if (style.will_change) |wc| {
    //     switch (wc) {
    //         .transform => {
    //             writer.write("will-change:") catch {};
    //             writer.write("transform") catch {};
    //             writer.write(";\n") catch {};
    //         },
    //         else => {},
    //     }
    // }
    //
    // if (style.transform_origin) |to| {
    //     writePropValue("transform-origin", .{ .tag = .transform_origin, .data = .{ .transform_origin = to } }, writer);
    // }

    // writer.write("box-sizing: border-box;\n") catch {};

    // Null-terminate the string
    // const len: usize = writer.pos;
    // css_buffer[len] = 0;
    // style_style = css_buffer[0..len];
}

pub fn generateAnimations(animations: *const Types.PackedAnimations, writer: anytype) void {
    // if (animations.has_transitions) {
    //     writePropValue("transition", .{ .tag = .transition, .data = .{ .transition = animations.transitions } }, writer);
    // }
    // Transform
    if (animations.has_transform and animations.transform.type_ptr != null) {
        writePropValue("transform", .{ .tag = .transform_type, .data = .{ .transform_type = animations.transform } }, writer);
    }
}

pub fn generateStylePass(ptr: ?*UINode, writer: *Writer) void {
    const node_ptr = ptr orelse return;
    const packed_field_ptrs = node_ptr.packed_field_ptrs orelse return;
    // Use a fixed buffer with a fbs to build the CSS string

    if (packed_field_ptrs.layout_ptr) |layout_ptr| {
        generateLayout(layout_ptr, writer);
    }

    if (packed_field_ptrs.position_ptr) |position_ptr| {
        generatePositions(position_ptr, writer);
    }

    if (packed_field_ptrs.margins_paddings_ptr) |margin_paddings_ptr| {
        generateMarginsPadding(margin_paddings_ptr, writer);
    }

    if (packed_field_ptrs.visual_ptr) |visual_ptr| {
        generateVisual(visual_ptr, writer);
    }

    // if (packed_field_ptrs.animations_ptr) |animations_ptr| {
    //     generateAnimations(animations_ptr, writer);
    // }

    // if (node_ptr.animation_enter) |animation_enter| {
    //     generateAnimation(animation_enter, writer);
    // }
}

pub fn generateAnimation(animation: *const Animation, writer: *Writer) void {
    writer.write("animation:") catch {};
    writer.write(animation._name) catch {};
    writer.writeByte(' ') catch {};
    writer.writeU32(animation.duration_ms) catch {};
    writer.write("ms ") catch {};
    switch (animation.easing_fn) {
        .linear => {
            writer.write("linear") catch {};
        },
        .easeIn => {
            writer.write("ease-in") catch {};
        },
        .easeOut => {
            writer.write("ease-out") catch {};
        },
        .easeInOut => {
            writer.write("ease-in-out") catch {};
        },
    }
}

pub export fn getStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_field_ptrs = node_ptr.packed_field_ptrs orelse return null;
    // Use a fixed buffer with a fbs to build the CSS string
    var writer: Writer = undefined;
    writer.init(&css_buffer);

    if (packed_field_ptrs.layout_ptr) |layout_ptr| {
        generateLayout(layout_ptr, &writer);
    }

    if (packed_field_ptrs.position_ptr) |position_ptr| {
        generatePositions(position_ptr, &writer);
    }

    if (packed_field_ptrs.margins_paddings_ptr) |margin_paddings_ptr| {
        generateMarginsPadding(margin_paddings_ptr, &writer);
    }

    // if (node_ptr.animation_enter) |animation_enter| {
    //     generateAnimation(animation_enter, &writer);
    // }

    if (packed_field_ptrs.visual_ptr) |visual_ptr| {
        generateVisual(visual_ptr, &writer);
    }
    // Return a pointer to the CSS string
    const len: usize = writer.pos;
    css_buffer[len] = 0;
    style_style = css_buffer[0..len];
    return style_style.ptr;
}

pub export fn getGlobalStyle() ?[*]const u8 {
    // const user_defaults = Vapor.Style.getDefault();
    // generateStyle(null, &user_defaults);
    // Return a pointer to the CSS string
    return style_style.ptr;
}
pub const Catalog = struct {
    themes: []const Types.ThemeDefinition,
};

pub var global_style: []const u8 = "";
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
pub export fn getVisualStyle(ptr: ?*UINode, visual_type: u8) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;

    var writer: Writer = undefined;
    writer.init(&css_buffer);
    if (visual_type == 3) {
        const visual = packed_fields.visual_ptr orelse return null;
        generateVisual(visual, &writer);

        // Null-terminate the string
        const len: usize = writer.pos;
        css_buffer[len] = 0;
        visual_style = css_buffer[0..len];

        return visual_style.ptr;
    }

    const interactive = packed_fields.interactive_ptr orelse return null;
    // const node_style = node_ptr.?.compact_style orelse return null;
    if (visual_type == 0) {
        // const visual = interactive.hover.?;
        const hover = interactive.hover;
        generateVisual(&hover, &writer);
        const hover_position = interactive.hover_position;
        if (interactive.has_hover_position) {
            generatePositions(&hover_position, &writer);
        }
    } else if (visual_type == 1) {
        // const visual = interactive.focus.?;
        const focus = interactive.focus;
        generateVisual(&focus, &writer);
    } else if (visual_type == 2) {
        // const visual = interactive.focus_within.?;
        const focus_within = interactive.focus_within;
        generateVisual(&focus_within, &writer);
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

var position_style: []const u8 = "";
export fn getPositionStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_position = packed_fields.position_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&css_buffer);
    generatePositions(packed_position, &writer);

    // Null-terminate the string
    const len: usize = writer.pos;
    css_buffer[len] = 0;
    position_style = css_buffer[0..len];

    // Return a pointer to the CSS string
    return position_style.ptr;
}

export fn getPositionLen() usize {
    return position_style.len;
}

var layout_style: []const u8 = "";
export fn getLayoutStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_layout = packed_fields.layout_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&css_buffer);
    generateLayout(packed_layout, &writer);

    // Null-terminate the string
    const len: usize = writer.pos;
    css_buffer[len] = 0;
    layout_style = css_buffer[0..len];

    // Return a pointer to the CSS string
    return layout_style.ptr;
}

export fn getLayoutLen() usize {
    return layout_style.len;
}

var mapa_style: []const u8 = "";
export fn getMapaStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_margin_paddings = packed_fields.margins_paddings_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&css_buffer);
    generateMarginsPadding(packed_margin_paddings, &writer);

    // Null-terminate the string
    const len: usize = writer.pos;
    css_buffer[len] = 0;
    mapa_style = css_buffer[0..len];

    // Return a pointer to the CSS string
    return mapa_style.ptr;
}

export fn getMapaLen() usize {
    return mapa_style.len;
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
