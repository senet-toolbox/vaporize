const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Vapor = @import("Vapor.zig");
const Color = @import("types.zig").Color;
var current_label_len: usize = 0;
pub export fn getAriaLabel(node_ptr: ?*UINode) ?[*]const u8 {
    if (node_ptr == null) {
        return null;
    }
    if (node_ptr.?.aria_label) |label| {
        current_label_len = label.len;
        return label.ptr;
    }
    return null;
}
pub export fn getAriaLabelLen() usize {
    return current_label_len;
}

pub fn isDesktop() bool {
    return !isMobile();
}

pub fn isMobile() bool {
    if (!Vapor.isWasi) return false;
    if (Vapor.browser_width < 786) {
        return true;
    } else {
        return false;
    }
}

pub fn hashKey(key: []const u8) u32 {
    return std.hash.XxHash32.hash(0, key);
}

pub fn compareStyles(a: *const Vapor.Style, b: *const Vapor.Style) bool {
    if (a.blur != null and b.blur != null) {
        if (a.blur.? != b.blur.?) return false;
    }

    if (a.cursor != null and b.cursor != null) {
        if (a.cursor.? != b.cursor.?) return false;
    }

    if (a.list_style != null and b.list_style != null) {
        if (a.list_style.? != b.list_style.?) return false;
    }

    if (a.position != null and b.position != null) {
        if (a.position.?.type != b.position.?.type) return false;
        if (a.position.?.top != null and b.position.?.top != null) {
            if (a.position.?.top.?.value != b.position.?.top.?.value) return false;
        }
        if (a.position.?.bottom != null and b.position.?.bottom != null) {
            if (a.position.?.bottom.?.value != b.position.?.bottom.?.value) return false;
        }
        if (a.position.?.left != null and b.position.?.left != null) {
            if (a.position.?.left.?.value != b.position.?.left.?.value) return false;
        }
        if (a.position.?.right != null and b.position.?.right != null) {
            if (a.position.?.right.?.value != b.position.?.right.?.value) return false;
        }
    }

    if (a.direction != b.direction) return false;

    if (a.size) |a_size| {
        if (b.size) |b_size| {
            if (a_size.width.size.minmax.min != b_size.width.size.minmax.min) return false;
            if (a_size.width.size.minmax.max != b_size.width.size.minmax.max) return false;
            if (a_size.height.size.minmax.min != b_size.height.size.minmax.min) return false;
            if (a_size.height.size.minmax.max != b_size.height.size.minmax.max) return false;
        }
    }

    if (a.padding != null and b.padding != null) {
        if (a.padding.?.top != b.padding.?.top) return false;
        if (a.padding.?.left != b.padding.?.left) return false;
        if (a.padding.?.bottom != b.padding.?.bottom) return false;
        if (a.padding.?.right != b.padding.?.right) return false;
    }
    if (a.margin != null and b.margin != null) {
        if (a.margin.?.top != b.margin.?.top) return false;
        if (a.margin.?.left != b.margin.?.left) return false;
        if (a.margin.?.bottom != b.margin.?.bottom) return false;
        if (a.margin.?.right != b.margin.?.right) return false;
    }

    if (a.visual != null and b.visual != null) {
        const a_visual = a.visual.?;
        const b_visual = b.visual.?;
        if (a_visual.background != null and b_visual.background != null) {
            if (a_visual.background.?.color != null and b_visual.background.?.color != null) {
                if (!compareRgba(a_visual.background.?.color.?, b_visual.background.?.color.?)) return false;
            }
        }

        if (a_visual.font_size != b_visual.font_size) return false;
        if (a_visual.letter_spacing != b_visual.letter_spacing) return false;
        if (a_visual.line_height != b_visual.line_height) return false;
        if (a_visual.font_weight != b_visual.font_weight) return false;
        // if (a_visual.border_radius != null and b_visual.border_radius != null) {
        //     if (a_visual.border_radius.?.top_left != b_visual.border_radius.?.top_left) return false;
        //     if (a_visual.border_radius.?.top_right != b_visual.border_radius.?.top_right) return false;
        //     if (a_visual.border_radius.?.bottom_left != b_visual.border_radius.?.bottom_left) return false;
        //     if (a_visual.border_radius.?.bottom_right != b_visual.border_radius.?.bottom_right) return false;
        // }
        // if (a_visual.border_thickness != null and b_visual.border_thickness != null) {
        //     if (a_visual.border_thickness.?.top != b_visual.border_thickness.?.top) return false;
        //     if (a_visual.border_thickness.?.left != b_visual.border_thickness.?.left) return false;
        //     if (a_visual.border_thickness.?.right != b_visual.border_thickness.?.right) return false;
        //     if (a_visual.border_thickness.?.bottom != b_visual.border_thickness.?.bottom) return false;
        // }
        // if (a_visual.border_color != null and b_visual.border_color != null) {
        //     if (!compareRgba(a_visual.border_color.?, b_visual.border_color.?)) return false;
        // }
        if (a_visual.border != null and b_visual.border != null) {
            const border_a = a_visual.border.?;
            const border_b = b_visual.border.?;
            if (border_a.color != null and border_b.color != null) {
                if (!compareRgba(border_a.color.?, border_b.color.?)) return false;
            }
            if (border_a.radius != null and border_b.radius != null) {
                if (border_a.radius.?.top_left != border_b.radius.?.top_left) return false;
                if (border_a.radius.?.top_right != border_b.radius.?.top_right) return false;
                if (border_a.radius.?.bottom_left != border_b.radius.?.bottom_left) return false;
                if (border_a.radius.?.bottom_right != border_b.radius.?.bottom_right) return false;
            }
            // if (border_a.thickness != null and border_b.thickness != null) {
            if (border_a.thickness.top != border_b.thickness.top) return false;
            if (border_a.thickness.left != border_b.thickness.left) return false;
            if (border_a.thickness.right != border_b.thickness.right) return false;
            if (border_a.thickness.bottom != border_b.thickness.bottom) return false;
            // }
        }
        if (a_visual.text_color != null and b_visual.text_color != null) {
            if (!compareRgba(a_visual.text_color.?, b_visual.text_color.?)) return false;
        }

        if (a_visual.opacity != null and b_visual.opacity != null) {
            if (a_visual.opacity.? != b_visual.opacity.?) return false;
        }
    }

    // if (a.overflow != b.overflow) return false;

    // if (a.overflow_x != b.overflow_x) return false;
    // if (a.overflow_y != b.overflow_y) return false;
    if (a.layout != null and b.layout != null) {
        if (a.layout.?.y != b.layout.?.y) return false;
        if (a.layout.?.x != b.layout.?.x) return false;
    }

    if (a.child_gap != null and b.child_gap != null) {
        if (a.child_gap.? != b.child_gap.?) return false;
    }

    // return false;
    return true;
}

/// Helper to compare optional slices of u8
fn compareFloat32Slice(
    a: [4]u8,
    b: [4]u8,
) bool {
    if (a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]) {
        return true;
    } else {
        return false;
    }
}

fn compareRgba(a: Color, b: Color) bool {
    switch (a) {
        .Literal => {
            const c_a = a.Literal;
            const c_b = b.Literal;
            if (c_a.r == c_b.r and c_a.g == c_b.g and c_a.b == c_b.b and c_a.a == c_b.a) {
                return true;
            } else {
                return false;
            }
        },
        else => return false,
    }
}

fn compareOptionalUint32(
    a: ?u32,
    b: ?u32,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        return a.? == b.?;
    } else {
        return false;
    }
}

fn compareOptionalFloat32(
    a: ?f32,
    b: ?f32,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        return a.? == b.?;
    } else {
        return false;
    }
}
/// Helper to compare optional slices of u8
fn compareOptionalFloat32Slice(
    a: ?[4]u8,
    b: ?[4]u8,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        if (a.?[0] == b.?[0] and a.?[1] == b.?[1] and a.?[2] == b.?[2] and a.?[3] == b.?[3]) {
            return true;
        } else {
            return false;
        }
    } else {
        return false;
    }
}

/// Helper to compare optional slices of u8
fn compareOptionalSlice(
    a: ?[]const u8,
    b: ?[]const u8,
) bool {
    if (a == null and b == null) {
        return true;
    } else if (a != null and b != null) {
        return std.mem.eql(u8, a.?, b.?);
    } else {
        return false;
    }
}

pub fn cast(comptime T: type, opaque_ptr: *anyopaque) T {
    return @ptrCast(@alignCast(opaque_ptr));
}
