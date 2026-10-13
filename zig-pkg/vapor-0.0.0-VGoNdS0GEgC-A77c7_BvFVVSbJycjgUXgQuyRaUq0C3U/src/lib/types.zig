const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Vapor = @import("Vapor.zig");
pub const Transition = @import("Transition.zig").Transition;
pub const TransitionProperty = @import("Transition.zig").TransitionProperty;
pub const PackedTransition = @import("Transition.zig").PackedTransition;
const ColorTheme = @import("constants/Color.zig");
const Animation = @import("Animation.zig");
pub const ElementType = @import("user_config").ElementType;
pub const ThemeTokens = @import("user_config").ThemeTokens;
pub const color_theme: ColorTheme = ColorTheme{};
const isMobile = @import("utils.zig").isMobile;
const Event = @import("Event.zig");
const Theme = @import("theme");

pub const ThemeDefinition = struct {
    default: bool = false,
    name: []const u8,
    theme: Theme.Colors,
};

pub const TimingFunction = enum(u8) {
    linear,
    ease,
    ease_in,
    ease_out,
    ease_in_out,
    bounce,
    elastic,
};

pub fn switchColorTheme() void {
    switch (color_theme.theme) {
        .dark => color_theme.theme = .light,
        .light => color_theme.theme = .dark,
    }
}

pub const Direction = enum(u8) {
    column = 0,
    row = 1,
};

pub const SizingType = enum(u8) {
    none,
    fit,
    grow,
    percent,
    fixed,
    elastic,
    elastic_percent,
    clamp_px,
    clamp_percent,
    min_max_vp,
    auto,
};

const MinMax = packed struct {
    min: f32 = 0,
    max: f32 = 0,

    pub fn eql(self: MinMax, other: MinMax) bool {
        return self.min == other.min and self.max == other.max;
    }
};

const Clamp = packed struct {
    min: f32 = 0,
    max: f32 = 0,
    preferred: f32 = 0,

    pub fn eql(self: MinMax, other: MinMax) bool {
        return self.min == other.min and self.max == other.max;
    }
};

const Tag = enum {
    minmax,
    clamp,
};

// Make it a tagged union by adding an enum
pub const SizingConstraint = packed struct {
    min: f32 = 0,
    max: f32 = 0,
    preferred: f32 = 0,
};

// const SizingConstraint = packed struct {
//     tag: Tag,
//     data: SizingUnion,
//     // minmax: MinMax,
//     // percent: MinMax,
//     // clamp_percent: Clamp,
//     // clamp_px: Clamp,
//     // min_max_vp: MinMax,
//
//     // pub fn eql(self: SizingConstraint, other: SizingConstraint) bool {
//     //     if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
//     //
//     //     return switch (self) {
//     //         .min_max_vp => |mm| mm.eql(other.min_max_vp),
//     //         .minmax => |mm| mm.eql(other.minmax),
//     //         .percent => |mm| mm.eql(other.percent),
//     //         .clamp_px => |mm| mm.eql(other.clamp_px),
//     //         .clamp_percent => |mm| mm.eql(other.clamp_percent),
//     //     };
//     // }
// };

pub const Size = packed struct {
    width: Sizing = .{},
    height: Sizing = .{},
    pub const full = Size{ .width = .percent(100), .height = .percent(100) };
    pub fn square_px(size: f32) Size {
        return .{
            .width = .px(size),
            .height = .px(size),
        };
    }
    pub fn square_percent(size: f32) Size {
        return .{
            .width = .percent(size),
            .height = .percent(size),
        };
    }
    /// Creates a height sizing
    pub fn h(size: Sizing) Size {
        return .{
            .height = size,
        };
    }
    /// Creates a width sizing
    pub fn w(size: Sizing) Size {
        return .{
            .width = size,
        };
    }
    /// Creates a height and width sizing
    pub fn hw(height: Sizing, width: Sizing) Size {
        return .{
            .width = width,
            .height = height,
        };
    }
    /// Creates a height and width sizing with pixel values
    pub fn hw_px(height: f32, width: f32) Size {
        return .{
            .width = .px(width),
            .height = .px(height),
        };
    }
    /// Creates a height and width sizing with percent values
    pub fn hw_percent(height: f32, width: f32) Size {
        return .{
            .width = .percent(width),
            .height = .percent(height),
        };
    }
};

pub const Sizing = packed struct {
    size: SizingConstraint = .{},
    type: SizingType = .none,

    pub const grow = Sizing{ .type = .grow, .size = .{ .min = 0, .max = 0 } };
    pub const auto = Sizing{ .type = .auto, .size = .{ .min = 0, .max = 0 } };
    pub const fit = Sizing{ .type = .fit, .size = .{ .min = 0, .max = 0 } };
    pub const full = percent(100);

    pub fn px(size: f32) Sizing {
        return .{ .type = .fixed, .size = .{
            .min = size,
            .max = size,
        } };
    }

    pub fn elastic(min: f32, max: f32) Sizing {
        return .{ .type = .elastic, .size = .{
            .min = min,
            .max = max,
        } };
    }

    pub fn percent(size: f32) Sizing {
        return .{ .type = .percent, .size = .{
            .min = size,
            .max = size,
        } };
    }

    // pub fn @"%"(size: f32) Sizing {
    //     return .{ .type = .percent, .size = .{ .minmax = .{
    //         .min = size,
    //     } } };
    // }
    //
    // pub fn elastic_percent(min: f32, max: f32) Sizing {
    //     return .{ .type = .elastic_percent, .size = .{ .percent = .{
    //         .min = min,
    //         .max = max,
    //     } } };
    // }
    //
    // pub fn clamp_px(min: f32, boundary: f32, max: f32) Sizing {
    //     return .{ .type = .clamp_px, .size = .{ .clamp_px = .{
    //         .min = min,
    //         .boundary = boundary,
    //         .max = max,
    //     } } };
    // }
    //
    pub fn min_max_vp(min: f32, max: f32) Sizing {
        return .{ .type = .min_max_vp, .size = .{
            .min = min,
            .max = max,
        } };
    }

    pub fn mobile_desktop_percent(mobile: f32, desktop: f32) Sizing {
        if (isMobile()) {
            return .{ .type = .percent, .size = .{
                .min = mobile,
                .max = mobile,
            } };
        }
        return .{ .type = .percent, .size = .{
            .min = desktop,
            .max = desktop,
        } };
    }
    //
    pub fn mobile_desktop(mobile: Sizing, desktop: Sizing) Sizing {
        if (isMobile()) {
            return mobile;
        } else {
            return desktop;
        }
    }
    //
    // pub fn clamp_percent(min: f32, preferred: f32, max: f32) Sizing {
    //     return .{ .type = .clamp_percent, .size = .{ .clamp_percent = .{
    //         .min = min,
    //         .preferred = preferred,
    //         .max = max,
    //     } } };
    // }
    //
    // // Add custom equality function for Sizing
    // pub fn eql(self: Sizing, other: Sizing) bool {
    //     return self.type == other.type and self.size.eql(other.size);
    // }
};

pub const PosType = enum(u8) {
    fit = 0,
    grow = 1,
    percent = 2,
    fixed = 3,
};

pub const Pos = packed struct {
    type: SizingType = .none,
    value: f32 = 0,

    pub const grow = Pos{ .type = .grow, .value = 0 };
    pub fn px(pos: f32) Pos {
        return .{ .type = .fixed, .value = pos };
    }

    pub fn percent(pos: f32) Pos {
        return .{ .type = .percent, .value = pos };
    }
};
// Represents a single background image source and its properties.
pub const Image = struct {
    url: []const u8,
    // TODO: Add other CSS properties like repeat, size, position
    // repeat: enum { repeat, no_repeat, repeat_x, repeat_y } = .repeat,
    // size: union(enum) { auto, cover, contain, explicit: struct { w: f32, h: f32 } } = .auto,
};

// Represents a generated grid pattern.
pub const Grid = struct {
    size: u8 = 0,
    color: Color = .transparent,
    thickness: u8 = 1,
};

pub const Dot = struct {
    radius: f16 = 0,
    spacing: u8 = 0,
    color: Color = .transparent,
};

const DirectionType = enum(u8) {
    none,
    to_top,
    to_bottom,
    to_left,
    to_right,
    angle,
};

pub const GradientDirection = packed struct {
    type: DirectionType = .none,
    angle: f32 = 0,
    pub const to_top = GradientDirection{ .type = .to_top };
    pub const to_bottom = GradientDirection{ .type = .to_bottom };
    pub const to_left = GradientDirection{ .type = .to_left };
    pub const to_right = GradientDirection{ .type = .to_right };
    pub fn deg(value: f32) GradientDirection {
        return .{ .angle = value, .type = .angle };
    }
};

pub const GradientType = enum(u8) {
    none,
    linear,
    radial,
};

pub const Gradient = struct {
    type: GradientType = .none,
    colors: []const Color,
    direction: GradientDirection,
};

pub const Lines = struct {
    direction: LinesDirection,
    color: Color,
    thickness: u8 = 1,
    spacing: u8 = 10,
};

pub const LinesDirection = enum(u8) {
    horizontal,
    vertical,
    diagonal_up,
    diagonal_down,
};

// A BackgroundLayer can be one of several mutually exclusive types,
// like an image or a generated pattern. This is a perfect use for a union.
pub const BackgroundLayer = union(enum) {
    Image: Image,
    Grid: Grid,
    Dot: Dot,
    Gradient: Gradient,
    Lines: Lines,

    /// Creates a background with a grid pattern on top of a transparent color.
    pub fn grid(size: u8, thickness: u8, color: Color) BackgroundLayer {
        return .{
            .Grid = .{
                .size = size,
                .thickness = thickness,
                .color = color,
            },
        };
    }

    pub fn dot(radius: f16, spacing: u8, color: Color) BackgroundLayer {
        return .{
            .Dot = .{
                .radius = radius,
                .spacing = spacing,
                .color = color,
            },
        };
    }

    pub fn gradient(gradient_type: GradientType, dir: GradientDirection, colors: []const Color) BackgroundLayer {
        return .{
            .Gradient = .{
                .type = gradient_type,
                .direction = dir,
                .colors = colors,
            },
        };
    }

    pub fn line(thickness: u8, spacing: u8, dir: LinesDirection, color: Color) BackgroundLayer {
        return .{
            .Lines = .{
                .thickness = thickness,
                .spacing = spacing,
                .direction = dir,
                .color = color,
            },
        };
    }
};

// The main Background struct now models CSS properties more closely.
// It has a base color and an optional top layer.
pub const Background = struct {
    color: ?Color = null,
    layer: ?BackgroundLayer = null,

    pub const white = Background{ .color = .{ .Literal = .{ .r = 255, .g = 255, .b = 255, .a = 1 } } };
    pub const black = Background{ .color = .{ .Literal = .{ .r = 0, .g = 0, .b = 0, .a = 1 } } };
    pub const red = Background{ .color = .{ .Literal = .{ .r = 255, .g = 0, .b = 0, .a = 1 } } };
    pub const green = Background{ .color = .{ .Literal = .{ .r = 0, .g = 255, .b = 0, .a = 1 } } };
    pub const blue = Background{ .color = .{ .Literal = .{ .r = 0, .g = 0, .b = 255, .a = 1 } } };
    pub const yellow = Background{ .color = .{ .Literal = .{ .r = 255, .g = 255, .b = 0, .a = 1 } } };
    pub const cyan = Background{ .color = .{ .Literal = .{ .r = 0, .g = 255, .b = 255, .a = 1 } } };
    pub const magenta = Background{ .color = .{ .Literal = .{ .r = 255, .g = 0, .b = 255, .a = 1 } } };
    pub const light_blue = Background{ .color = .{ .Literal = .{ .r = 0, .g = 255, .b = 255, .a = 1 } } };
    pub const vapor_blue = Background{ .color = .vapor_blue };

    /// Creates a background with only a solid color.
    pub fn solid(color: Color) Background {
        return .{ .color = color };
    }

    /// Creates a background with a grid pattern on top of a transparent color.
    pub fn grid(size: u8, thickness: u8, color: Color) Background {
        return .{
            .layer = .{ .Grid = .{
                .size = size,
                .thickness = thickness,
                .color = color,
            } },
        };
    }

    pub fn dot(radius: f16, spacing: u8, color: Color) Background {
        return .{
            .layer = .{ .Dot = .{
                .radius = radius,
                .spacing = spacing,
                .color = color,
            } },
        };
    }

    pub fn gradient(gradient_type: GradientType, dir: GradientDirection, colors: []const Color) Background {
        return .{
            .layer = .{ .Gradient = .{
                .type = gradient_type,
                .direction = dir,
                .colors = colors,
            } },
        };
    }

    /// Creates a background with an image on top of a specified background color.
    pub fn image(url: []const u8, bg_color: Color) Background {
        return .{
            .color = bg_color,
            .layer = .{ .Image = .{ .url = url } },
        };
    }

    // --- Convenience functions from your original code, now updated ---

    pub fn hex(hex_str: []const u8) Background {
        return .solid(.hex(hex_str));
    }

    pub fn palette(thematic: ThemeTokens) Background {
        return .solid(.palette(thematic));
    }

    pub fn transparentizeHex(color: Color, alpha: f32) Background {
        return Background{ .color = color.transparentizeHex(alpha) };
    }

    pub fn darken(color: Color, percentage: f32) Background {
        return Background{ .color = color.darken(percentage) };
    }
    pub const transparent = Background.solid(.transparent);
};

pub const Thematic = packed struct {
    token: ThemeTokens,
    alpha: f32 = -1,
};
pub const Rgba = packed struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, a: f32 = 0 };
pub const Color = union(enum) {
    Literal: Rgba, // A hardcoded, specific color
    Thematic: Thematic, // A token name, like "primaryText" or "accentColor"

    pub const transparent = Color{ .Literal = .{ .r = 0, .g = 0, .b = 0, .a = 0 } };
    pub const white = Color{ .Literal = .{ .r = 255, .g = 255, .b = 255, .a = 1 } };
    pub const black = Color{ .Literal = .{ .r = 0, .g = 0, .b = 0, .a = 1 } };
    pub const red = Color{ .Literal = .{ .r = 255, .g = 0, .b = 0, .a = 1 } };
    pub const green = Color{ .Literal = .{ .r = 0, .g = 255, .b = 0, .a = 1 } };
    pub const blue = Color{ .Literal = .{ .r = 0, .g = 0, .b = 255, .a = 1 } };
    pub const yellow = Color{ .Literal = .{ .r = 255, .g = 255, .b = 0, .a = 1 } };
    pub const cyan = Color{ .Literal = .{ .r = 0, .g = 255, .b = 255, .a = 1 } };
    pub const magenta = Color{ .Literal = .{ .r = 255, .g = 0, .b = 255, .a = 1 } };
    pub const vapor_blue = Color.hex("#2108FF");
    pub fn palette(thematic: ThemeTokens) Color {
        return .{ .Thematic = .{ .token = thematic } };
    }
    pub fn hex(hex_str: []const u8) Color {
        const rgba_arr = Vapor.hexToRgba(hex_str);
        return .{ .Literal = .{
            .r = @as(u8, @intFromFloat(rgba_arr[0])),
            .g = @as(u8, @intFromFloat(rgba_arr[1])),
            .b = @as(u8, @intFromFloat(rgba_arr[2])),
            .a = rgba_arr[3],
        } };
    }

    // Function to darken a hex color string by a percentage and return Color struct
    pub fn darken(_: Color, percentage: f32) Color {
        if (percentage < 0.0 or percentage > 100.0) {
            @panic("Percentage must be between 0 and 100");
        }
        //
        // if (color == .Thematic) return Color{ .Thematic = .{
        //     .token = color.Thematic.token,
        //     .alpha = alpha,
        // } };
        // const r = color.Literal.r;
        // const g = color.Literal.g;
        // const b = color.Literal.b;
        // return .{ .Literal = .{
        //     .r = r,
        //     .g = g,
        //     .b = b,
        //     .a = alpha,
        // } };
        //
        // const rgba_arr = Vapor.hexToRgba(hex_str);
        // const factor = 1.0 - (percentage / 100.0);
        //
        // return .{
        //     .Literal = .{
        //         .r = @intFromFloat(@as(f32, @floatFromInt(rgba_arr[0])) * factor),
        //         .g = @intFromFloat(@as(f32, @floatFromInt(rgba_arr[1])) * factor),
        //         .b = @intFromFloat(@as(f32, @floatFromInt(rgba_arr[2])) * factor),
        //         .a = rgba_arr[3], // Keep alpha unchanged
        //     },
        // };
    }

    // // Function to lighten a hex color string by a percentage and return Color struct
    pub fn lighten(hex_str: []const u8, percentage: f32) Color {
        if (percentage < 0.0 or percentage > 100.0) {
            @panic("Percentage must be between 0 and 100");
        }

        const rgba_arr = Vapor.hexToRgba(hex_str);
        const factor = percentage / 100.0;

        return .{
            .Literal = .{
                .r = @intFromFloat(@as(f32, @floatFromInt(rgba_arr[0])) + (@as(f32, 255.0) - @as(f32, @floatFromInt(rgba_arr[0]))) * factor),
                .g = @intFromFloat(@as(f32, @floatFromInt(rgba_arr[1])) + (@as(f32, 255.0) - @as(f32, @floatFromInt(rgba_arr[1]))) * factor),
                .b = @intFromFloat(@as(f32, @floatFromInt(rgba_arr[2])) + (@as(f32, 255.0) - @as(f32, @floatFromInt(rgba_arr[2]))) * factor),
                .a = rgba_arr[3], // Keep alpha unchanged
            },
        };
    }
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .Literal = .{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        } };
    }
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .Literal = .{
            .r = r,
            .g = g,
            .b = b,
            .a = 1,
        } };
    }
    pub fn transparentizeHex(color: Color, alpha: f32) Color {
        if (color == .Thematic) return Color{ .Thematic = .{
            .token = color.Thematic.token,
            .alpha = alpha,
        } };
        const r = color.Literal.r;
        const g = color.Literal.g;
        const b = color.Literal.b;
        return .{ .Literal = .{
            .r = r,
            .g = g,
            .b = b,
            .a = alpha,
        } };
    }
};

pub const Padding = packed struct {
    top: u8 = 0,
    bottom: u8 = 0,
    left: u8 = 0,
    right: u8 = 0,
    pub fn all(size: u8) Padding {
        return Padding{
            .top = size,
            .bottom = size,
            .left = size,
            .right = size,
        };
    }
    pub fn tblr(top: u8, bottom: u8, left: u8, right: u8) Padding {
        return Padding{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
        };
    }

    pub fn tb(top: u8, bottom: u8) Padding {
        return Padding{
            .top = top,
            .bottom = bottom,
            .left = 0,
            .right = 0,
        };
    }
    pub fn lr(left: u8, right: u8) Padding {
        return Padding{
            .top = 0,
            .bottom = 0,
            .left = left,
            .right = right,
        };
    }
    pub fn horizontal(size: u8) Padding {
        return Padding{
            .top = 0,
            .bottom = 0,
            .left = size,
            .right = size,
        };
    }
    pub fn vertical(size: u8) Padding {
        return Padding{
            .top = size,
            .bottom = size,
            .left = 0,
            .right = 0,
        };
    }
    pub fn t(size: u8) Padding {
        return Padding{
            .top = size,
            .bottom = 0,
            .left = 0,
            .right = 0,
        };
    }
    pub fn l(size: u8) Padding {
        return Padding{
            .top = 0,
            .bottom = 0,
            .left = size,
            .right = 0,
        };
    }
    pub fn r(size: u8) Padding {
        return Padding{
            .top = 0,
            .bottom = 0,
            .left = 0,
            .right = size,
        };
    }
    pub fn b(size: u8) Padding {
        return Padding{
            .top = 0,
            .bottom = size,
            .left = 0,
            .right = 0,
        };
    }
};

pub const Margin = packed struct {
    top: i16 = 0,
    bottom: i16 = 0,
    left: i16 = 0,
    right: i16 = 0,
    pub fn all(size: i16) Margin {
        return Margin{
            .top = size,
            .bottom = size,
            .left = size,
            .right = size,
        };
    }
    pub fn tblr(top: i16, bottom: i16, left: i16, right: i16) Margin {
        return Margin{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
        };
    }
    pub fn tb(top: i16, bottom: i16) Margin {
        return Margin{
            .top = top,
            .bottom = bottom,
        };
    }
    pub fn br(bottom: i16, right: i16) Margin {
        return Margin{
            .bottom = bottom,
            .right = right,
        };
    }
    pub fn lr(left: i16, right: i16) Margin {
        return Margin{
            .left = left,
            .right = right,
        };
    }
    pub fn t(top: i16) Margin {
        return Margin{
            .top = top,
        };
    }
    pub fn b(bottom: i16) Margin {
        return Margin{
            .bottom = bottom,
        };
    }
    pub fn l(left: i16) Margin {
        return Margin{
            .left = left,
        };
    }
    pub fn r(right: i16) Margin {
        return Margin{
            .right = right,
        };
    }
};

pub const Overflow = enum(u8) {
    default,
    scroll,
    hidden,
};

pub const Scroll = packed struct {
    x: Overflow = .default,
    y: Overflow = .default,

    pub fn none() Scroll {
        return .{ .x = .hidden, .y = .hidden };
    }

    pub fn none_x() Scroll {
        return .{ .x = .hidden };
    }

    pub fn none_y() Scroll {
        return .{ .y = .hidden };
    }
    pub fn scroll() Scroll {
        return .{ .x = .scroll, .y = .scroll };
    }

    pub fn scroll_x() Scroll {
        return .{ .x = .scroll };
    }

    pub fn scroll_y() Scroll {
        return .{ .y = .scroll };
    }
};

pub const BorderRadius = packed struct {
    top_left: u8 = 0,
    top_right: u8 = 0,
    bottom_left: u8 = 0,
    bottom_right: u8 = 0,
    fn default() BorderRadius {
        return BorderRadius{
            .top_left = 0,
            .top_right = 0,
            .bottom_left = 0,
            .bottom_right = 0,
        };
    }
    pub fn all(radius: u8) BorderRadius {
        return BorderRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
    pub fn specific(top_left: u8, top_right: u8, bottom_left: u8, bottom_right: u8) BorderRadius {
        return BorderRadius{
            .top_left = top_left,
            .top_right = top_right,
            .bottom_left = bottom_left,
            .bottom_right = bottom_right,
        };
    }
    pub fn top_bottom(top_radius: u8, bottom_radius: u8) BorderRadius {
        return BorderRadius{
            .top_left = top_radius,
            .top_right = top_radius,
            .bottom_left = bottom_radius,
            .bottom_right = bottom_radius,
        };
    }
    pub fn bottom(radius: u8) BorderRadius {
        return BorderRadius{
            .top_left = 0,
            .top_right = 0,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
    pub fn top(radius: u8) BorderRadius {
        return BorderRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = 0,
            .bottom_right = 0,
        };
    }
    pub fn left_right(left: u8, right: u8) BorderRadius {
        return BorderRadius{
            .top_left = left,
            .top_right = right,
            .bottom_left = left,
            .bottom_right = right,
        };
    }
};

pub const Shadow = struct {
    top: i16 = 0,
    left: i16 = 0,
    blur: u8 = 0,
    spread: u8 = 0,
    color: Color = .{ .Literal = .{} },

    pub fn elevation(size: i16, color: Color) Shadow {
        return .{
            .blur = 0,
            .spread = 0,
            .top = size,
            .left = 0,
            .color = color,
        };
    }

    // // Material Design-style elevation levels
    // pub fn elevationSmall(color: Color) Shadow {
    //     return .{
    //         .top = 1,
    //         .left = 0,
    //         .blur = 3,
    //         .spread = 0,
    //         .color = color,
    //     };
    // }
    //
    // pub fn elevationMedium(color: Color) Shadow {
    //     return .{
    //         .top = 4,
    //         .left = 0,
    //         .blur = 8,
    //         .spread = 0,
    //         .color = color,
    //     };
    // }
    //
    // pub fn elevationLarge(color: Color) Shadow {
    //     return .{
    //         .top = 8,
    //         .left = 0,
    //         .blur = 16,
    //         .spread = 0,
    //         .color = color,
    //     };
    // }
    //
    // pub fn elevationXLarge(color: Color) Shadow {
    //     return .{
    //         .top = 12,
    //         .left = 0,
    //         .blur = 24,
    //         .spread = 0,
    //         .color = color,
    //     };
    // }

    // Flat/subtle shadow for cards
    pub fn card(color: Color) Shadow {
        return .{
            .top = 4,
            .left = 4,
            .blur = 0,
            .spread = 0,
            .color = color,
        };
    }

    // Dropdown/overlay shadow
    pub fn dropdown(color: Color) Shadow {
        return .{
            .top = 6,
            .left = 0,
            .blur = 12,
            .spread = 0,
            .color = color,
        };
    }

    // Modal/dialog shadow
    pub fn modal(color: Color) Shadow {
        return .{
            .top = 16,
            .left = 0,
            .blur = 32,
            .spread = 0,
            .color = color,
        };
    }

    // Inset shadow (for pressed buttons, input fields)
    pub fn inset(color: Color) Shadow {
        return .{
            .top = 0,
            .left = 0,
            .blur = 2,
            .spread = 1,
            .color = color,
        };
    }

    // Glow effect
    pub fn glow(size: u8, color: Color) Shadow {
        return .{
            .top = 0,
            .left = 0,
            .blur = size,
            .spread = size / 2,
            .color = color,
        };
    }
};
pub const Border = packed struct {
    top: u8 = 0,
    bottom: u8 = 0,
    left: u8 = 0,
    right: u8 = 0,
    pub const solid = Border{ .top = 1, .bottom = 1, .left = 1, .right = 1 };
    pub const none = Border{ .top = 0, .bottom = 0, .left = 0, .right = 0 };
    pub fn default() Border {
        return Border{
            .top = 0,
            .bottom = 0,
            .left = 0,
            .right = 0,
        };
    }
    pub fn all(thickness: u8) Border {
        return Border{
            .top = thickness,
            .bottom = thickness,
            .left = thickness,
            .right = thickness,
        };
    }
    pub fn tblr(top: u8, bottom: u8, left: u8, right: u8) Border {
        return Border{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
        };
    }

    pub fn tb(thickness: u8) Border {
        return Border{
            .top = thickness,
            .bottom = thickness,
            .left = 0,
            .right = 0,
        };
    }
    pub fn lr(thickness: u8) Border {
        return Border{
            .top = 0,
            .bottom = 0,
            .left = thickness,
            .right = thickness,
        };
    }

    pub fn b(thickness: u8) Border {
        return Border{
            .top = 0,
            .bottom = thickness,
            .left = 0,
            .right = 0,
        };
    }

    pub fn t(thickness: u8) Border {
        return Border{
            .top = thickness,
            .bottom = 0,
            .left = 0,
            .right = 0,
        };
    }

    pub fn l(thickness: u8) Border {
        return Border{
            .top = 0,
            .bottom = 0,
            .left = thickness,
            .right = 0,
        };
    }

    pub fn r(thickness: u8) Border {
        return Border{
            .top = 0,
            .bottom = 0,
            .left = 0,
            .right = thickness,
        };
    }
};

pub const Alignment = enum(u8) {
    none,
    center,
    top,
    bottom,
    start,
    end,
    between,
    even,
    in_line,
};

pub const BoundingBox = struct {
    /// X coordinate of the top-left corner
    x: f32,
    /// Y coordinate of the top-left corner
    y: f32,
    /// Width of the bounding box
    width: f32,
    /// Height of the bounding box
    height: f32,
};

pub const FloatType = enum(u8) {
    right,
    left,
    top,
    bottom,
};

pub const PositionType = enum(u8) {
    none,
    relative,
    absolute,
    fixed,
    sticky,
};

pub const Position = struct {
    right: ?Pos = null,
    left: ?Pos = null,
    top: ?Pos = null,
    bottom: ?Pos = null,
    type: PositionType = .relative,
    z_index: ?i16 = null,

    pub const relative = Position{ .type = .relative };
    pub const absolute = Position{ .type = .absolute };

    pub const nav = Position{
        .left = .px(0),
        .right = .px(0),
        .type = .fixed,
        .top = .px(0),
        .z_index = 999,
    };

    /// Creates a top bottom left right position
    pub fn tblr(top: Pos, bottom: Pos, left: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
            .type = pos_type,
        };
    }
    /// Creates a top bottom position
    pub fn tb(top: Pos, bottom: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .bottom = bottom,
            .type = pos_type,
        };
    }
    /// Creates a left right position
    pub fn lr(left: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .left = left,
            .right = right,
            .type = pos_type,
        };
    }
    /// Creates a bottom right position
    pub fn br(bottom: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .bottom = bottom,
            .right = right,
            .type = pos_type,
        };
    }
    /// Creates a top left position
    pub fn tl(top: Pos, left: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .left = left,
            .type = pos_type,
        };
    }
    /// Creates a bottom left position
    pub fn bl(bottom: Pos, left: Pos, pos_type: PositionType) Position {
        return .{
            .bottom = bottom,
            .left = left,
            .type = pos_type,
        };
    }
    /// Creates a top right position
    pub fn tr(top: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .right = right,
            .type = pos_type,
        };
    }
};

pub const TransformType = enum(u8) {
    none,
    translateX,
    translateY,
    scale,
    scaleY,
    scaleX,
    rotate,
    rotateX,
    rotateY,
    rotateXYZ,
};

pub const Transform = struct {
    const Direction = enum(u8) {
        up,
        down,
        left,
        right,
    };
    size_type: SizeType = .none,
    scale_size: f16 = 1,
    trans_x: f16 = 0,
    trans_y: f16 = 0,
    deg: f16 = 0,
    x: f16 = 0,
    y: f16 = 0,
    z: f16 = 0,
    type: []const TransformType = &.{.none},
    opacity: f16 = 1,

    pub fn scale() Transform {
        return .{ .scale_size = 1.04, .type = &.{.scale}, .size_type = .scale };
    }

    pub fn scaleDecimal(value: f16) Transform {
        return .{ .scale_size = value, .type = &.{.scale}, .size_type = .scale };
    }

    pub fn up(dist: f16) Transform {
        return .{ .trans_y = -dist, .type = &.{.translateY}, .size_type = .px };
    }

    pub fn direction_scale(dir: Transform.Direction, dist: f16, scale_size: f16) Transform {
        switch (dir) {
            .up => return .{ .trans_y = -dist, .scale_size = scale_size, .type = &.{ .translateY, .scale }, .size_type = .px },
            .down => return .{ .trans_y = dist, .scale_size = scale_size, .type = &.{ .translateY, .scale }, .size_type = .px },
            .left => return .{ .trans_x = -dist, .scale_size = scale_size, .type = &.{ .translateX, .scale }, .size_type = .px },
            .right => return .{ .trans_x = dist, .scale_size = scale_size, .type = &.{ .translateX, .scale }, .size_type = .px },
        }
    }

    pub fn down(dist: f16) Transform {
        return .{ .trans_y = dist, .type = &.{.translateY}, .size_type = .px };
    }

    pub fn left(dist: f16) Transform {
        return .{ .trans_x = -dist, .type = &.{.translateX}, .size_type = .px };
    }
    pub fn right(dist: f16) Transform {
        return .{ .trans_x = dist, .type = &.{.translateX}, .size_type = .px };
    }

    pub fn left_percent(percent: f16) Transform {
        return .{ .trans_x = percent, .type = &.{.translateX}, .size_type = .percent };
    }

    pub fn top_percent(percent: f16) Transform {
        return .{ .percent = percent, .type = &.{.translateY}, .size_type = .percent };
    }

    pub fn rotate(deg: f16) Transform {
        return .{ .deg = deg, .type = &.{.rotate}, .size_type = .deg };
    }

    pub fn rotateX(deg: f16) Transform {
        return .{ .deg = deg, .type = &.{.rotateX}, .size_type = .deg };
    }

    pub fn rotateY(deg: f16) Transform {
        return .{ .deg = deg, .type = &.{.rotateY}, .size_type = .deg };
    }

    pub fn rotateXYZ(x: f16, y: f16, z: f16) Transform {
        return .{ .x = x, .y = y, .z = z, .type = &.{.rotateXYZ}, .size_type = .deg };
    }
};

pub const Focus = struct {
    position: ?Position = null,
    display: ?FlexType = null,
    direction: ?Direction = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,
    text_color: ?Color = null,
    padding: ?Padding = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Color = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    opacity: f16 = 1,
    child_style: ?ChildStyle = null,
};

// pub const Hover = struct {
//     position: ?Position = null,
//     display: ?FlexType = null,
//     direction: ?Direction = null,
//     width: ?Sizing = null,
//     height: ?Sizing = null,
//     font_size: ?i32 = null,
//     letter_spacing: ?i32 = null,
//     line_height: ?i32 = null,
//     font_weight: ?usize = null,
//
//     border_radius: ?BorderRadius = null,
//     border_thickness: ?Border = null,
//     border_color: ?Color = null,
//
//     border: ?struct {
//         thickness: Border = .all(1),
//         color: ?Color = null,
//         radius: ?BorderRadius = null,
//     } = null,
//
//     text_color: ?Color = null,
//     padding: ?Padding = null,
//     child_alignment: ?struct { x: Alignment, y: Alignment } = null,
//     child_gap: u16 = 0,
//     background: ?Color = null,
//     shadow: Shadow = .{},
//     transform: Transform = .{},
//     opacity: f32 = 1,
//     child_style: ?ChildStyle = null,
// };

pub const Hover = struct {
    position: ?Position = null,
    // display: ?FlexType = null,
    // direction: ?Direction = null,

    /// Size configuration for the element
    size: ?Size = null,

    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,

    border: ?struct {
        thickness: Border = .all(1),
        color: ?Color = null,
        radius: ?BorderRadius = null,
    } = null,

    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,

    text_color: ?Color = null,
    padding: ?Padding = null,

    /// External spacing configuration
    margin: ?Margin = .{},

    // child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Color = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    // opacity: f32 = 1,
    child_style: ?ChildStyle = null,
};

pub const CheckMark = struct {
    position: ?Position = null,
    display: ?FlexType = null,
    direction: ?Direction = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,
    text_color: ?Color = null,
    padding: ?Padding = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Color = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    opacity: f16 = 1,
    child_style: ?ChildStyle = null,
};

pub const Dim = struct {
    type: SizingType = .fit,
    pub const grow = Sizing{ .type = .grow, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };
    pub const fit = Sizing{ .type = .fit, .size = .{ .minmax = .{ .min = 0, .max = 0 } } };
    pub fn fixed(size: f32) Sizing {
        return .{ .type = .fixed, .size = .{ .minmax = .{
            .min = size,
            .max = size,
        } } };
    }
    pub fn elastic(min: f32, max: f32) Sizing {
        return .{ .type = .elastic, .size = .{ .minmax = .{
            .min = min,
            .max = max,
        } } };
    }
};

pub const Resize = enum(u8) {
    default,
    none,
    both,
    horizontal,
    vertical,
};

pub const TextDecoration = struct {
    pub const none = TextDecoration{ .type = .none };
    pub const overline = TextDecoration{ .type = .overline };
    pub const underline = TextDecoration{ .type = .underline };
    pub const line_through = TextDecoration{ .type = .line_through };
    pub const blink = TextDecoration{ .type = .blink };
    type: TextDecorationType = .none,
    style: TextDecorationStyle = .default,
    color: ?Color = null,
};

pub const TextDecorationStyle = enum(u8) {
    default,
    solid,
    double,
    dotted,
    dashed,
    wavy,
};

pub const TextDecorationType = enum(u8) {
    default,
    none,
    overline,
    underline,
    inherit,
    initial,
    revert,
    unset,
};

pub const WhiteSpace = enum(u8) {
    default,
    normal, // Collapses whitespace and breaks on necessary
    nowrap, // Collapses whitespace but prevents breaking
    pre, // Preserves whitespace and breaks on newlines
    pre_wrap, // Preserves whitespace and breaks as needed
    pre_line, // Collapses whitespace but preserves line breaks
    break_spaces, // Like pre-wrap but also breaks at spaces
    inherit, // Inherits from parent
    initial, // Default value
    revert, // Reverts to inherited value
    unset, // Resets to inherited value or initial
};

// Enum definition for CSS list-style-type property
pub const ListStyle = enum(u8) {
    default,
    none, // No bullet or marker
    disc, // Filled circle (default for unordered lists)
    circle, // Open circle
    square, // Square marker
    decimal, // Decimal numbers (default for ordered lists)
    decimal_leading_zero, // Decimal numbers with a leading zero (e.g. 01, 02, 03, ...)
    lower_roman, // Lowercase roman numerals (i, ii, iii, ...)
    upper_roman, // Uppercase roman numerals (I, II, III, ...)
    lower_alpha, // Lowercase alphabetic (a, b, c, ...)
    upper_alpha, // Uppercase alphabetic (A, B, C, ...)
    lower_greek, // Lowercase Greek letters (α, β, γ, ...)
    armenian, // Armenian numbering
    georgian, // Georgian numbering
    inherit, // Inherits from parent element
    initial, // Resets to the default value
    revert, // Reverts to the inherited value if explicitly changed
    unset, // Resets to inherited or initial value
};

pub const Outline = enum(u8) {
    default,
    none, // No outline
    auto, // Default outline (typically browser-specific)
    dotted, // Dotted outline
    dashed, // Dashed outline
    solid, // Solid outline
    double, // Two parallel solid lines
    groove, // 3D grooved effect
    ridge, // 3D ridged effect
    inset, // 3D inset effect
    outset, // 3D outset effect
    inherit, // Inherits from the parent element
    initial, // Resets to the default value
    revert, // Reverts to the inherited value if explicitly changed
    unset, // Resets to inherited or initial value
};

pub const FlexType = enum(u8) {
    default,
    flex, // "flex"
    flow, // "inline"
    center,
    stack, // "inline-flex"
    none, // "centers the child content"
    center_stack, // "centers the child content"
};

// Enum definition for flex-wrap property
pub const FlexWrap = enum(u8) {
    none,
    nowrap, // Single-line, no wrapping
    wrap, // Multi-line, wrapping if needed
    wrap_reverse, // Multi-line, reverse wrapping direction
    inherit, // Inherits from parent
    initial, // Default value
    revert, // Reverts to inherited value
    unset, // Resets to inherited value or initial
};

pub const KeyFrame = struct {
    tag: []const u8,
    from: Transform = .{},
    to: Transform = .{},
};
const AnimDir = enum {
    normal,
    reverse,
    forwards,
};

const Iteration = struct {
    iter_count: u32 = 1,
    pub fn infinite() Iteration {
        return .{
            .iter_count = 0,
        };
    }
    pub fn count(c: u32) Iteration {
        return .{
            .iter_count = c,
        };
    }
};

pub const AnimationType = struct {
    tag: []const u8,
    delay: f32 = 0,
    direction: AnimDir = .normal,
    duration: f32 = 0,
    iteration_count: Iteration = .count(1),
    timing_function: TimingFunction = .ease,
};

pub const ChildStyle = struct {
    style_id: []const u8,
    display: ?FlexType = null,
    position: ?Position = null,
    direction: Direction = .row,
    background: ?Color = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,
    text_color: ?Color = null,
    padding: ?Padding = null,
    margin: ?Margin = null,
    overflow: ?Overflow = null,
    overflow_x: ?Overflow = null,
    overflow_y: ?Overflow = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u32 = 0,
    flex_shrink: ?u32 = null,
    font_family_file: []const u8 = "",
    font_family: []const u8 = "",
    opacity: f16 = 1,
    text_decoration: ?TextDecoration = null,
    shadow: ?Shadow = .{},
    white_space: ?WhiteSpace = null,
    flex_wrap: ?FlexWrap = null,
    key_frame: ?KeyFrame = null,
    key_frames: ?[]const KeyFrame = null,
    // animation: ?Animation.Specs = null,
    z_index: ?i16 = null,
    list_style: ?ListStyle = null,
    blur: ?u32 = null,
    outline: ?Outline = null,
    transition: ?Transition = null,
    show_scrollbar: bool = true,
    btn_id: u32 = 0,
    dialog_id: ?[]const u8 = null,
    accent_color: ?[4]u8 = null,
};

pub const Cursor = enum(u8) {
    default,
    pointer,
    help,
    grab,
    zoom_in,
    zoom_out,
};

pub const Appearance = enum(u8) {
    none = 0, // Remove default styling completely
    auto = 1, // Default browser styling
    button = 2, // Style as a button
    textfield = 3, // Style as a text input field
    menulist = 4, // Style as a dropdown menu
    searchfield = 5, // Style as a search input
    textarea = 6, // Style as a multiline text area
    checkbox = 7, // Style as a checkbox
    radio = 8, // Style as a radio button
    inherit = 9, // Inherit from parent
    initial = 10, // Default value
    revert = 11, // Revert to inherited value
    unset = 12, // Reset to inherited value or initial
};

pub const BoxSizing = enum(u8) {
    content_box = 0, // Default CSS box model
    border_box = 1, // Alternative CSS box model (padding and border included in width/height)
    padding_box = 2, // Experimental value (width/height includes content and padding)
    inherit = 3, // Inherits from parent
    initial = 4, // Default value
    revert = 5, // Reverts to inherited value
    unset = 6, // Resets to inherited value or initial
};

pub const TransformOrigin = enum(u8) {
    top = 0,
    bottom = 1,
    right = 2,
    left = 3,
};

pub const Layout = packed struct {
    x: Alignment = .none,
    y: Alignment = .none,
    pub const in_line = Layout{ .x = .in_line, .y = .in_line };
    pub const flex = Layout{};
    pub const center = Layout{ .x = .center, .y = .center };
    pub const top_center = Layout{ .x = .center, .y = .start };
    pub const left_center = Layout{ .x = .start, .y = .center };
    pub const right_center = Layout{ .x = .end, .y = .center };
    pub const bottom_center = Layout{ .x = .center, .y = .end };
    pub const top_right = Layout{ .x = .end, .y = .start };
    pub const top_left = Layout{ .x = .start, .y = .start };
    pub const bottom_right = Layout{ .x = .end, .y = .end };
    pub const bottom_left = Layout{ .x = .start, .y = .end };
    pub const x_even = Layout{ .x = .even, .y = .start };
    pub const x_even_center = Layout{ .x = .even, .y = .center };
    pub const y_even = Layout{ .x = .start, .y = .even };
    pub const y_even_center = Layout{ .x = .center, .y = .even };
    pub const x_between = Layout{ .x = .between, .y = .start };
    pub const x_between_center = Layout{ .x = .between, .y = .center };
    pub const x_between_bottom = Layout{ .x = .between, .y = .end };
    pub const x_between_top = Layout{ .x = .between, .y = .start };
    pub const y_between_center = Layout{ .x = .center, .y = .between };
};

pub const BorderGrouped = struct {
    thickness: Border = .all(1),
    color: ?Color = .hex("#000000"),
    radius: ?BorderRadius = null,

    pub const none = BorderGrouped{ .thickness = .all(0) };

    pub fn solid(thickness: Border, color: Color, radius: BorderRadius) BorderGrouped {
        return .{
            .thickness = thickness,
            .color = color,
            .radius = radius,
        };
    }

    pub fn sharp(thickness: Border, color: Color) BorderGrouped {
        return .{
            .thickness = thickness,
            .color = color,
        };
    }

    pub fn simple(color: Color) BorderGrouped {
        return .{ .color = color }; // Uses default thickness = .all(1)
    }

    pub fn thin(color: Color) BorderGrouped {
        return .{ .thickness = .all(1), .color = color };
    }

    pub fn thick(color: Color) BorderGrouped {
        return .{ .thickness = .all(2), .color = color };
    }

    // Just thickness, use default color
    pub fn width(thickness: Border) BorderGrouped {
        return .{ .thickness = thickness };
    }

    // Rounded variants (common radius values)
    pub fn round(color: Color, radius: BorderRadius) BorderGrouped {
        return .{ .color = color, .radius = radius };
    }

    pub fn pill(color: Color) BorderGrouped {
        return .{ .color = color, .radius = .all(99) }; // Large radius for pill shape
    }

    // Side-specific shortcuts
    pub fn bottom(color: Color) BorderGrouped {
        return .{ .thickness = .b(1), .color = color };
    }

    pub fn l(thickness: u8, color: Color) BorderGrouped {
        return .{ .thickness = .l(thickness), .color = color };
    }

    pub fn r(thickness: u8, color: Color) BorderGrouped {
        return .{ .thickness = .l(thickness), .color = color };
    }

    pub fn tb(color: Color) BorderGrouped {
        return .{ .thickness = .tb(1), .color = color };
    }

    pub fn lr(color: Color) BorderGrouped {
        return .{ .thickness = .lr(1), .color = color };
    }

    pub fn top(color: Color) BorderGrouped {
        return .{ .thickness = .t(1), .color = color };
    }
};

const FontParams = struct {
    _size: i32,
    _weight: ?usize = null,
    _color: ?Color = null,
    pub fn size(font_size: i32) FontParams {
        return .{
            ._size = font_size,
        };
    }
    pub fn weight(font_weight: ?u16) FontParams {
        return .{
            ._weight = font_weight,
        };
    }

    pub fn color(font_color: ?Color) FontParams {
        return .{
            ._color = font_color,
        };
    }
    pub fn all(font_size: u8, font_weight: ?u16, font_color: ?Color) FontParams {
        return .{
            ._size = font_size,
            ._weight = font_weight,
            ._color = font_color,
        };
    }
    pub fn size_weight(font_size: u8, font_weight: ?u16) FontParams {
        return .{
            ._size = font_size,
            ._weight = font_weight,
        };
    }
    pub fn size_color(font_size: i32, font_color: ?Color) FontParams {
        return .{
            ._size = font_size,
            ._color = font_color,
        };
    }
};

pub const FontStyle = enum(u8) { default, normal, italic };

pub const CaretType = enum(u8) {
    none,
    block,
    line,
};

pub const Caret = struct {
    type: CaretType = .none,
    color: ?Color = null,
};

pub const PackedCaret = packed struct {
    type: CaretType = .none,
    color: PackedColor = .{},
};

pub const Visual = struct {
    /// Color color as RGBA array [red, green, blue, alpha] (0-255 each)
    /// Default: transparent black
    background: ?Background = null,

    layer: ?BackgroundLayer = null,
    layers: ?[]const BackgroundLayer = null,

    /// Font size in pixels
    font_size: ?u8 = null,

    /// Letter spacing in pixels (can be negative for tighter spacing)
    letter_spacing: ?u8 = null,

    /// Line height in pixels for text content
    line_height: ?u8 = null,

    /// Font weight (100-900, where 400 is normal, 700 is bold)
    font_weight: ?u16 = null,

    /// Font style (normal, italic)
    font_style: ?FontStyle = null,

    /// Border radius configuration for rounded corners
    border_radius: ?BorderRadius = null,

    /// Border thickness specification
    border_thickness: ?Border = null,

    /// Border color as RGBA array [red, green, blue, alpha]
    border_color: ?Color = null,

    border: ?BorderGrouped = null,

    /// Text color as RGBA array [red, green, blue, alpha]
    /// Default: solid black
    text_color: ?Color = null,

    /// Ellipsis configuration
    ellipsis: ?Ellipsis = null,

    /// Gradient color as RGBA array [red, green, blue, alpha]
    // gradient: ?[]const Color = null,

    /// Element opacity (0.0 = fully transparent, 1.0 = fully opaque)
    opacity: ?f16 = null,

    /// Shadow configuration for drop shadows
    shadow: ?Shadow = null,

    /// 2D/3D transformation configuration
    transform: ?Transform = null,

    /// Text decoration (underline, strikethrough, etc.)
    text_decoration: ?TextDecoration = null,

    cursor: ?Cursor = null,

    fill: ?Color = null,
    stroke: ?Color = null,
    blur: ?u8 = 0,

    caret: ?Caret = null,

    /// Outline configuration (different from border)
    outline: ?Outline = null,

    /// White space handling (normal, nowrap, pre, pre-wrap)
    white_space: ?WhiteSpace = null,

    resize: ?Resize = null,

    pub fn font(size: u8, weight: ?u16, color: ?Color) Visual {
        return .{
            .font_size = size,
            .font_weight = weight,
            .text_color = color,
        };
    }

    pub fn borderSolid(thickness: Border, color: Color) Visual {
        return .{
            .border = BorderGrouped{
                .thickness = thickness,
                .color = color,
            },
        };
    }

    // Background shortcuts
    pub fn bg(background: Background) Visual {
        return .{ .background = background };
    }

    pub fn pill(color: Color) Visual {
        return .{ .border = .pill(color) };
    }

    pub fn when(condition: bool, visual_true: Visual, visual_false: Visual) Visual {
        if (condition) {
            return visual_true;
        } else {
            return visual_false;
        }
    }

    pub fn button(background: Background, border: BorderGrouped) Visual {
        return .{
            .background = background,
            .border = border,
        };
    }
};

pub const Interactive = struct {
    hover_layout: ?Layout = null,
    hover_position: ?Position = null,
    hover: ?Visual = null,
    focus: ?Visual = null,
    focus_within: ?Visual = null,

    pub fn hover_scale() Interactive {
        return .{
            .hover = .{ .transform = .scale() },
        };
    }

    pub fn hoverScaleTextBackground(color: Color, background: Background) Interactive {
        return .{
            .hover = .{ .transform = .scale(), .background = background, .text_color = color },
        };
    }
    pub fn hover_text(color: Color) Interactive {
        return .{
            .hover = .{ .text_color = color },
        };
    }
};

const PackedPosType = enum(u8) {
    fit = 0,
    grow = 1,
    percent = 2,
    fixed = 3,
    elastic = 4,
    elastic_percent = 5,
    clamp_px = 6,
    clamp_percent = 7,
    none = 8,
};

const PackedSizeType = packed struct {
    type: SizingType = .fit,
    value: f32 = 0,
};

pub const AspectRatio = enum(u8) {
    none = 0,
    square = 1,
    portrait = 2,
    landscape = 3,
};

pub const PackedLayout = packed struct {
    flex: FlexType = .default,
    layout: Layout = .{},
    direction: Direction = .row,
    size: Size = .{},
    child_gap: u8 = 0,
    scroll: Scroll = .{},
    flex_wrap: FlexWrap = .none,
    text_align: Layout = .{},
    aspect_ratio: AspectRatio = .none,
};

pub const PackedPosition = packed struct {
    position_type: PositionType = .none,
    top: Pos = .{},
    right: Pos = .{},
    bottom: Pos = .{},
    left: Pos = .{},
    z_index: i16 = 0,
};

pub const PackedMarginsPaddings = packed struct {
    padding: Padding = .{},
    margin: Margin = .{},
};

pub const PackedGrid = packed struct {
    size: u8 = 0,
    thickness: u8 = 1,
    packed_color: PackedColor = .{},
};

pub const PackedLines = packed struct {
    direction: LinesDirection = .horizontal,
    color: PackedColor = .{},
    thickness: u8 = 1,
    spacing: u8 = 10,
};

pub const PackedDots = packed struct {
    radius: f16 = 0,
    spacing: u8 = 0,
    packed_color: PackedColor = .{},
};

pub const PackedGradient = packed struct {
    type: GradientType = .none,
    direction: GradientDirection = .{},
    colors_ptr: ?[*]const PackedColor = null,
    colors_len: usize = 0,
};

pub const PackedLayer = union(enum) {
    Grid: PackedGrid,
    Dot: PackedDots,
    Gradient: PackedGradient,
    Lines: PackedLines,
};

pub const PackedColor = packed struct {
    has_token: bool = false,
    has_color: bool = false,
    color: Rgba = undefined,
    token: Thematic = undefined,
};

pub const PackedShadow = packed struct {
    top: i16 = 0,
    left: i16 = 0,
    blur: u8 = 0,
    spread: u8 = 0,
    color: PackedColor = .{},
};

const SizeType = enum(u8) {
    percent,
    deg,
    px,
    scale,
    none,
};

pub const PackedTransform = packed struct {
    size_type: SizeType = .none,
    type: TransformType = .none,
    scale_size: f16 = 1,
    trans_x: f16 = 0,
    trans_y: f16 = 0,
    deg: f16 = 0,
    x: f16 = 0,
    y: f16 = 0,
    z: f16 = 0,
    opacity: f16 = 1,
    type_ptr: ?*[]TransformType = null,
    type_len: usize = 0,

    pub fn set(packed_transform: *PackedTransform, transform: *const Transform) void {
        const type_slice = transform.type;
        const slice_ptr = Vapor.frame_arena.persistentAllocator().create([]TransformType) catch unreachable;
        var slice: []TransformType = Vapor.frame_arena.persistentAllocator().alloc(TransformType, type_slice.len) catch unreachable;
        for (type_slice, 0..) |element, i| {
            slice[i] = element;
        }

        slice_ptr.* = slice;
        packed_transform.type_ptr = slice_ptr;
        packed_transform.type_len = slice.len;
        packed_transform.size_type = transform.size_type;
        packed_transform.scale_size = transform.scale_size;
        packed_transform.trans_x = transform.trans_x;
        packed_transform.trans_y = transform.trans_y;
        packed_transform.deg = transform.deg;
        packed_transform.x = transform.x;
        packed_transform.y = transform.y;
        packed_transform.z = transform.z;
        packed_transform.opacity = transform.opacity;
    }
};

pub const Ellipsis = enum(u8) {
    none,
    dot,
    dash,
};

pub const PackedLayers = packed struct {
    items_ptr: ?[*]const PackedLayer = null,
    len: usize = 0,
};

pub const PackedTextDecoration = packed struct {
    type: TextDecorationType = .none,
    style: TextDecorationStyle = .default,
    color: PackedColor = .{},
};

pub const PackedVisual = packed struct {
    background: PackedColor = .{},
    packed_layers: PackedLayers = .{},
    has_border_radius: bool = false,
    border_radius: BorderRadius = .{},
    has_border_thickeness: bool = false,
    border_thickness: Border = .{},
    has_border_color: bool = false,
    border_color: PackedColor = .{},
    font_size: u8 = 0,
    font_weight: u16 = 0,
    text_color: PackedColor = .{},
    font_style: FontStyle = .default,
    has_opacity: bool = false,
    ellipsis: Ellipsis = .none,
    opacity: f16 = 1,
    text_decoration: PackedTextDecoration = .{},
    blur: u8 = 0,
    list_style: ListStyle = .default,
    outline: Outline = .default,
    shadow: PackedShadow = .{},
    has_white_space: bool = false,
    white_space: WhiteSpace = .normal,
    cursor: Cursor = .default,
    fill: PackedColor = .{},
    stroke: PackedColor = .{},
    font_family_ptr: ?[*]const u8 = null,
    font_family_len: usize = 0,
    has_transitions: bool = false,
    transitions: PackedTransition = undefined,
    is_text_gradient: bool = false,
    caret: PackedCaret = .{},
    resize: Resize = .default,
};

pub const PackedInteractive = packed struct {
    has_hover: bool = false,
    hover: PackedVisual = undefined,
    has_hover_position: bool = false,
    hover_position: PackedPosition = undefined,
    has_focus: bool = false,
    focus: PackedVisual = undefined,
    has_focus_within: bool = false,
    focus_within: PackedVisual = undefined,
};

pub const PackedAnimations = packed struct {
    has_transform: bool = false,
    transform: PackedTransform = undefined,
};

/// Global user-defined default style that overrides system defaults
var user_defaults: ?Style = null;
pub const default: Style = Style{};

/// Comprehensive styling struct that provides CSS-like properties for UI components.
/// Supports layout, visual styling, typography, animations, and interactions.
/// Uses a three-tier inheritance system: system defaults -> user defaults -> component styles.
///
/// # Usage Example:
/// ```zig
/// const button_style = Style.with(.{
///     .background = .{ 70, 130, 180, 255 }, // Steel blue
///     .border_radius = .all(8),
///     .padding = .all(12),
///     .font_weight = 600,
/// });
/// ```
pub const Style = struct {
    /// Unique identifier for the element id="92d7dd45a43f36e4_Text_0-genk...
    /// this defaults to the uuid of the element, which is autogenerated
    /// It is used during reconciliation to find the correct node to update
    /// duplicate ids on the same page are considered undefined behaviour
    id: ?[]const u8 = null,

    /// Class-like identifier for grouping styles
    style_id: ?[]const u8 = null,

    /// Positioning method (static, relative, absolute, fixed)
    position: ?Position = null,

    /// Flex direction for child elements (row, column, row-reverse, column-reverse)
    direction: Direction = .row,

    /// Size configuration for the element
    size: ?Size = null,

    /// Aspect ratio configuration for the element
    aspect_ratio: ?AspectRatio = null,

    /// Internal spacing configuration
    padding: ?Padding = null,

    /// External spacing configuration
    margin: ?Margin = null,

    /// Style Props
    visual: ?Visual = null,

    /// Horizontal overflow behavior
    scroll: ?Scroll = null,

    /// Alignment configuration for child elements
    layout: ?Layout = null,

    /// Gap between child elements in pixels
    child_gap: ?u8 = null,

    /// Font family name (e.g., "Arial", "Helvetica", "Montserrat")
    font_family: ?[]const u8 = null,

    /// Flex wrap behavior (nowrap, wrap, wrap-reverse)
    flex_wrap: ?FlexWrap = null,

    /// Single keyframe for simple animations
    key_frame: ?KeyFrame = null,

    /// Array of keyframes for complex animations
    key_frames: ?[]const KeyFrame = null,

    /// Animation specifications (duration, timing, etc.)
    animation: ?Animation.Specs = null,

    /// Animation name for exit/removal animations
    exit_animation: ?[]const u8 = null,

    /// List styling for ul/ol elements
    list_style: ?ListStyle = null,

    /// Transition specifications for smooth property changes
    transition: ?Transition = null,

    /// Whether to show scrollbars when content overflows
    show_scrollbar: bool = true,

    /// Interactive
    interactive: ?Interactive = null,

    /// Button identifier for click handling
    btn_id: u32 = 0,

    /// Dialog identifier for modal/popup elements
    dialog_id: ?[]const u8 = null,

    /// Array of child-specific style overrides
    child_styles: ?[]*const ChildStyle = null,

    /// Element appearance override
    appearance: ?Appearance = null,

    /// Custom checkmark styling for checkboxes
    checkmark_style: ?CheckMark = null,

    /// Hint to browser about which properties will change (optimization)
    will_change: ?TransitionProperty = null,

    /// Origin point for transformations
    transform_origin: ?TransformOrigin = null,

    /// Backface visibility for 3D transforms
    backface_visibility: ?[]const u8 = null,

    /// Gets the current base style to use for inheritance.
    /// Returns user-defined defaults if set, otherwise returns system defaults.
    ///
    /// # Returns:
    /// Style - The base style configuration
    ///
    /// # Usage:
    /// ```zig
    /// const base = Style.getDefault();
    /// const custom = Style{ .font_size = 16 }.merge(base);
    /// ```
    pub fn getDefault() Style {
        return user_defaults orelse default;
    }

    /// Merges this style with a base style, creating a new style where
    /// non-default properties from this style override the base style.
    /// Only properties that differ from system defaults are applied.
    ///
    /// # Parameters:
    /// - `base`: *const Style - The style with base properties
    /// - `override`: Style - The override style to merge with
    ///
    /// # Returns:
    /// Style - New style with merged properties
    ///
    /// # Usage:
    /// ```zig
    /// const base_style = Style{ .font_size = 14, .padding = .all(8) };
    /// const override_style = Style{ .font_size = 18 }; // Only override font size
    /// const merged = base_style.merge(override_style);
    /// // Result: font_size = 18, padding = .all(8)
    /// ```
    pub fn merge(base: *const Style, override: Style) Style {
        // var result = base.*;
        // inline for (@typeInfo(Style).@"struct".fields) |field| {
        //     const field_value = @field(override, field.name);
        //     const default_value = @field(default, field.name);
        //
        //     // Only override if the field is not the default value
        //     if (!std.meta.eql(field_value, default_value)) {
        //         @field(result, field.name) = field_value;
        //     }
        // }

        var result = base.*;

        if (override.id != null) result.id = override.id;
        if (override.style_id != null) result.style_id = override.style_id;
        if (override.position != null) result.position = override.position;
        if (override.direction != .row) result.direction = override.direction;
        if (override.size != null) result.size = override.size;
        if (override.padding != null) result.padding = override.padding;
        if (override.margin != null) result.margin = override.margin;
        if (override.visual != null) result.visual = override.visual;
        if (override.scroll != null) result.scroll = override.scroll;
        if (override.layout != null) result.layout = override.layout;
        if (override.font_family != null) result.font_family = override.font_family;
        if (override.flex_wrap != null) result.flex_wrap = override.flex_wrap;
        if (override.key_frame != null) result.key_frame = override.key_frame;
        if (override.key_frames != null) result.key_frames = override.key_frames;
        // if (override.animation != null) result.animation = override.animation;
        // if (override.exit_animation != null) result.exit_animation = override.exit_animation;
        if (override.list_style != null) result.list_style = override.list_style;
        if (override.transition != null) result.transition = override.transition;
        if (override.show_scrollbar != true) result.show_scrollbar = override.show_scrollbar;
        if (override.interactive != null) result.interactive = override.interactive;
        if (override.btn_id != 0) result.btn_id = override.btn_id;
        if (override.dialog_id != null) result.dialog_id = override.dialog_id;
        if (override.child_styles != null) result.child_styles = override.child_styles;
        if (override.appearance != null) result.appearance = override.appearance;
        if (override.checkmark_style != null) result.checkmark_style = override.checkmark_style;
        if (override.will_change != null) result.will_change = override.will_change;
        if (override.transform_origin != null) result.transform_origin = override.transform_origin;
        if (override.backface_visibility != null) result.backface_visibility = override.backface_visibility;
        if (override.child_gap != null) result.child_gap = override.child_gap;

        return result;
    }

    pub fn extend(self: *Style, target: Style) void {
        if (target.id != null) self.id = target.id;
        if (target.style_id != null) self.style_id = target.style_id;
        if (target.position != null) self.position = target.position;
        if (target.direction != .row) self.direction = target.direction;
        if (target.size != null) self.size = target.size;
        if (target.padding != null) self.padding = target.padding;
        if (target.margin != null) self.margin = target.margin;
        if (target.visual != null) self.visual = target.visual;
        if (target.scroll != null) self.scroll = target.scroll;
        if (target.layout != null) self.layout = target.layout;
        if (target.font_family != null) self.font_family = target.font_family;
        if (target.flex_wrap != null) self.flex_wrap = target.flex_wrap;
        if (target.key_frame != null) self.key_frame = target.key_frame;
        if (target.key_frames != null) self.key_frames = target.key_frames;
        // if (target.animation != null) self.animation = target.animation;
        // if (target.exit_animation != null) self.exit_animation = target.exit_animation;
        if (target.list_style != null) self.list_style = target.list_style;
        if (target.transition != null) self.transition = target.transition;
        if (target.show_scrollbar != true) self.show_scrollbar = target.show_scrollbar;
        if (target.interactive != null) self.interactive = target.interactive;
        if (target.btn_id != 0) self.btn_id = target.btn_id;
        if (target.dialog_id != null) self.dialog_id = target.dialog_id;
        if (target.child_styles != null) self.child_styles = target.child_styles;
        if (target.appearance != null) self.appearance = target.appearance;
        if (target.checkmark_style != null) self.checkmark_style = target.checkmark_style;
        if (target.will_change != null) self.will_change = target.will_change;
        if (target.transform_origin != null) self.transform_origin = target.transform_origin;
        if (target.backface_visibility != null) self.backface_visibility = target.backface_visibility;
        if (target.child_gap != null) self.child_gap = target.child_gap;
    }
    //
    // // pub fn extend(self: *Style, target: Style) void {
    // //     inline for (@typeInfo(Style).@"struct".fields) |field| {
    // //         const target_value = @field(target, field.name);
    // //         const field_value = @field(self, field.name);
    // //         const default_value = @field(default, field.name);
    // //
    // //         // Only override if the field is not the default value
    // //         if (!std.meta.eql(field_value, target_value) and !std.meta.eql(target_value, default_value)) {
    // //             @field(self, field.name) = target_value;
    // //         }
    // //     }
    // // }
    //
    // // /// Creates a new style by merging the provided overrides with the current default style.
    // // /// This is the primary way to create styled components with inheritance.
    // // ///
    // // /// # Parameters:
    // // /// - `overrides`: Style - Style properties to override defaults
    // // ///
    // // /// # Returns:
    // // /// Style - New style with default properties and specified overrides
    // // ///
    // // /// # Usage:
    // // /// ```zig
    // // /// // Create a button style with custom background and padding
    // // /// const button_style = Style.override(.{
    // // ///     .background = .{ 70, 130, 180, 255 }, // Steel blue
    // // ///     .padding = .all(12),
    // // ///     .border_radius = .all(6),
    // // ///     .text_color = .{ 255, 255, 255, 255 }, // White text
    // // /// });
    // // ///
    // // /// // Create a card style with shadow and border
    // // /// const card_style = Style.override(.{
    // // ///     .background = .{ 255, 255, 255, 255 }, // White background
    // // ///     .shadow = .{ .blur = 10, .color = .{ 0, 0, 0, 50 } },
    // // ///     .border_radius = .all(8),
    // // ///     .padding = .all(16),
    // // /// });
    // // /// ```
    // // pub fn override(overrides: Style) Style {
    // //     return overrides.merge(Style.getDefault());
    // // }
    //
    // /// Sets the global user defaults that will be used as the base for all future styles.
    // /// This allows you to establish consistent theming across your application.
    // ///
    // /// # Parameters:
    // /// - `new_default`: Style - The new default style configuration
    // ///
    // /// # Returns:
    // /// void
    // ///
    // /// # Usage:
    // /// ```zig
    // /// // Set up application-wide defaults
    // /// Style.setDefault(.{
    // ///     .font_family = "Inter",
    // ///     .font_size = 14,
    // ///     .text_color = .{ 33, 37, 41, 255 }, // Dark gray
    // ///     .background = .{ 248, 249, 250, 255 }, // Light gray
    // /// });
    // ///
    // /// // All subsequent Style.override() calls will inherit these defaults
    // /// const button = Style.override(.{ .padding = .all(8) });
    // /// // button now has Inter font, 14px size, dark gray text, etc.
    // /// ```
    // pub fn setDefault(new_default: Style) void {
    //     user_defaults = new_default;
    // }
};
pub const Config = struct {
    style: Style,
};

pub const HooksIds = struct {
    created_id: u32 = 0,
    mounted_id: u32 = 0,
    updated_id: u32 = 0,
    destroy_id: u32 = 0,
};

const InputType = enum(u8) {
    text = 0,
    number = 1,
    password = 2,
    radio = 3,
    checkbox = 4,
    email = 5,
    search = 6,
    telephone = 7,
};
const Callback = *const fn (*Event) void;
pub const InputParamsStr = struct {
    default: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    value: ?[]const u8 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
    include_capital: ?u32 = null,
    onInput: ?Callback = null,
};

pub const InputParamsEmail = struct {
    type: InputTypes = .email,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const InputParamsPassword = struct {
    type: InputTypes = .password,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const InputParamsTelephone = struct {
    type: InputTypes = .telephone,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

const InputParamsFloat = struct {
    default: ?f32 = null,
    tag: ?[]const u8 = null,
    value: ?f32 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
};

pub const InputParamsInt = struct {
    type: InputTypes = .int,
    default: ?i32 = null,
    value: ?i32 = null,
};

pub const InputParamsString = struct {
    type: InputTypes = .string,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

const InputParamsRadio = struct {
    tag: []const u8,
    value: []const u8,
    required: ?bool = null,
    checked: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
};

const InputParamsCheckBox = struct {
    tag: ?[]const u8 = null,
    checked: bool = false,
    required: ?bool = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
    checkmark: ?Style = null,
};

pub const InputParamsFile = struct {
    type: InputTypes = .file,
    // tag: ?[]const u8 = null,
    // required: ?bool = null,
    // disabled: ?bool = null,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const InputTypes = enum(u8) {
    int,
    float,
    string,
    checkbox,
    radio,
    password,
    email,
    file,
    telephone,
    none,
};

pub const TextFieldParams = union(enum) {
    string: InputParamsString,
    int: InputParamsInt,
    // float: InputParamsFloat,
    // on_change: ?*const fn (event: *Event) void = null,
    // checkbox: InputParamsCheckBox,
    // radio: InputParamsRadio,
    password: InputParamsPassword,
    email: InputParamsEmail,
    telephone: InputParamsTelephone,
    file: InputParamsFile,
};

pub const StateType = enum {
    static,
    pure,
    dynamic,
    animation,
    grain,
    err,
    removed,
    added,
};

pub const ButtonType = enum {
    submit,
    button,
};

pub const ElementDeclaration = struct {
    hooks: HooksIds = .{},
    style: ?*const Style = null,
    elem_type: ElementType,
    text: ?[]const u8 = null,
    svg: []const u8 = "",
    href: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    show: bool = true,
    text_field_params: ?TextFieldParams = null,
    event_type: ?EventType = null,
    state_type: StateType = .static,
    aria_label: ?[]const u8 = null,
    tooltip: ?*const Tooltip = null,
    animation_enter: ?*const Animation = null,
    animation_exit: ?*const Animation = null,
    video: ?*const Video = null,
    /// Used for passing ect data
    udata: usize = 0,
    level: ?u8 = null,
    name: ?[]const u8 = null,
};

pub const Tooltip = struct {
    text: []const u8,
    style: ?Style = null,
};

pub const RenderCommand = struct {
    /// Rectangular box that fully encloses this UI element
    elem_type: ElementType,
    text: []const u8 = "",
    href: []const u8 = "",
    style: ?*const Style = null,
    id: []const u8 = "",
    index: usize = 0,
    hooks: HooksIds,
    node_ptr: *UINode,
    hover: bool = false,
    focus: bool = false,
    focus_within: bool = false,
    class: ?[]const u8 = null,
    render_type: StateType = .static,
    tooltip: ?*Tooltip = null,
    has_children: bool = true,
    hash: u32 = 0,
    style_changed: bool = false,
};

pub const EventType = enum(u8) {
    // Mouse events
    none = 0,
    click, // Fired when a pointing device button is clicked.
    dblclick, // Fired when a pointing device button is double-clicked.
    mousedown, // Fired when a pointing device button is pressed.
    mouseup, // Fired when a pointing device button is released.
    mousemove, // Fired when a pointing device is moved.
    mouseover, // Fired when a pointing device is moved onto an element.
    mouseout, // Fired when a pointing device is moved off an element.
    mouseenter, // Similar to mouseover but does not bubble.
    mouseleave, // Similar to mouseout but does not bubble.
    contextmenu, // Fired when the right mouse button is clicked.

    // Keyboard events
    keydown, // Fired when a key is pressed.
    keyup, // Fired when a key is released.
    keypress, // Fired when a key that produces a character value is pressed.

    // Focus events
    focus, // Fired when an element gains focus.
    blur, // Fired when an element loses focus.
    focusin, // Fired when an element is about to receive focus.
    focusout, // Fired when an element is about to lose focus.

    // Form events
    change, // Fired when the value of an element changes.
    input, // Fired every time the value of an element changes.
    submit, // Fired when a form is submitted.
    reset, // Fired when a form is reset.

    // Window events
    resize, // Fired when the window is resized.
    scroll, // Fired when the document view is scrolled.
    wheel, // Fired when the mouse wheel is rotated.

    // Drag & Drop events
    drag, // Fired continuously while an element or text selection is being dragged.
    dragstart, // Fired at the start of a drag operation.
    dragend, // Fired at the end of a drag operation.
    dragover, // Fired when an element is being dragged over a valid drop target.
    dragenter, // Fired when a dragged element enters a valid drop target.
    dragleave, // Fired when a dragged element leaves a valid drop target.
    drop, // Fired when a dragged element is dropped on a valid drop target.

    // Clipboard events
    copy, // Fired when the user initiates a copy action.
    cut, // Fired when the user initiates a cut action.
    paste, // Fired when the user initiates a paste action.

    // Touch events
    touchstart, // Fired when one or more touch points are placed on the touch surface.
    touchmove, // Fired when one or more touch points are moved along the touch surface.
    touchend, // Fired when one or more touch points are removed from the touch surface.
    touchcancel, // Fired when a touch point is disrupted (e.g., by a modal interruption).

    // Pointer events (unify mouse, touch, and pen input)
    pointerover, // Fired when a pointer enters the hit test boundaries of an element.
    pointerenter, // Similar to pointerover but does not bubble.
    pointerdown, // Fired when a pointer becomes active.
    pointermove, // Fired when a pointer changes coordinates.
    pointerup, // Fired when a pointer is no longer active.
    pointercancel, // Fired when a pointer is canceled.
    pointerout, // Fired when a pointer moves out of an element.
    pointerleave, // Similar to pointerout but does not bubble.

    // Document / Media / Error events
    load, // Fired when a resource and its dependent resources have finished loading.
    unload, // Fired when the document is being unloaded.
    abort, // Fired when the loading of a resource is aborted.
    show,
    close,
    cancel,
};

pub const Video = struct {
    src: ?[]const u8 = null,
    autoplay: bool = false,
    muted: bool = false,
    loop: bool = false,
    controls: bool = false,
};
