// Color.zig
const Vapor = @import("../Vapor.zig");
const std = @import("std");
pub const Theme = enum {
    light,
    dark,
};

pub const ThemeColors = struct {
    border_color: [4]f32,
    text_color: [4]f32,
    background: [4]f32,
    primary: [4]f32,
    secondary: [4]f32,
    font_family: []const u8,
    shadow: [4]f32,
    border_cache_color: [4]f32,
    btn_color: [4]f32,
    tint: [4]f32,
    text_tint_color: [4]f32,
    alternate_tint: [4]f32,
    btn_tint: [4]f32,
    dark_text: [4]f32,
    form_input_border_color: [4]f32,
    danger: [4]f32,
};

pub const Light = ThemeColors{
    .border_color = Vapor.hexToRgba("#E9E9E9"),
    .text_color = .{ 0, 0, 0, 255 },
    .background = .{ 255, 255, 255, 255 },
    .primary = .{ 255, 255, 255, 255 },
    .secondary = .{ 0, 0, 0, 255 },
    .shadow = .{ 0, 0, 0, 15 },
    .border_cache_color = .{ 0, 0, 0, 40 },
    .font_family = "Montserrat",
    .btn_color = .{ 67, 64, 240, 255 },
    .tint = .{ 67, 64, 240, 255 },
    .text_tint_color = .{ 255, 255, 255, 255 },
    .alternate_tint = .{ 67, 64, 240, 255 },
    .btn_tint = Vapor.hexToRgba("#FF3838"),
    .dark_text = Vapor.hexToRgba("#8C8C8C"),
    .form_input_border_color = Vapor.hexToRgba("#E9E9E9"),
    .danger = .{ 255, 78, 51, 255 },
};

pub const Dark = ThemeColors{
    .border_color = Vapor.hexToRgba("#27272a"),
    .text_color = .{ 255, 255, 255, 255 },
    .background = .{ 0, 0, 0, 255 },
    .primary = .{ 0, 0, 0, 255 },
    .secondary = .{ 255, 255, 255, 255 },
    .shadow = .{ 255, 255, 255, 30 },
    .border_cache_color = .{ 255, 255, 255, 40 },
    .font_family = "Montserrat",
    .btn_color = Vapor.hexToRgba("#E5FF54"),
    .tint = Vapor.hexToRgba("#6338FF"),
    .text_tint_color = .{ 255, 255, 255, 255 },
    // .tint = Vapor.hexToRgba("#E5FF54"),
    .alternate_tint = Vapor.hexToRgba("#6338FF"),
    .btn_tint = Vapor.hexToRgba("#FF3838"),
    .dark_text = Vapor.hexToRgba("#8C8C8C"),
    .form_input_border_color = Vapor.hexToRgba("#27272a"),
    .danger = .{ 255, 78, 51, 255 },
};

const Color = @This();
theme: Theme = .light,
switched_theme: bool = false,

pub fn getDefaultThemeColors(self: Color) ThemeColors {
    return switch (self.theme) {
        .light => Light,
        .dark => Dark,
    };
}

pub fn getThemeColors(self: *Color) ThemeColors {
    return switch (self.theme) {
        .light => Light,
        .dark => Dark,
    };
}

pub fn switchTheme(self: *Color, theme_type: Theme) void {
    self.theme = theme_type;
    self.switched_theme = true;
    Vapor.global_rerender = true;
}

pub fn getAttribute(self: *Color, comptime attribute: []const u8) [4]f32 {
    const theme = self.getThemeColors();
    return @field(theme, attribute);
}

pub fn getDefaultAttribute(self: Color, comptime attribute: []const u8) [4]f32 {
    const theme = self.getDefaultThemeColors();
    return @field(theme, attribute);
}
