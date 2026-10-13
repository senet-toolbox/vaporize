const std = @import("std");
const UIContext = @import("UITree.zig");
const UINode = UIContext.UINode;
const Types = @import("types.zig");
const Engine = @This();
const Vapor = @import("Vapor.zig");

pub fn createStack(ui_ctx: *UIContext, parent: *UINode) void {
    if (parent.children.items.len == 0) return;

    for (parent.children.items) |child| {
        ui_ctx.stackRegister(child) catch {
            Vapor.println("Could not stack register\n", .{});
            unreachable;
        };
    }
    var i = parent.children.items.len - 1;
    while (true) {
        const child = parent.children.items[i];
        if (i == 0) {
            ui_ctx.createStack(child);
            break;
        } else {
            ui_ctx.createStack(child);
        }
        i -= 1;
    }
}

// calcWidths is breadth post order first
// we calculate the widths of the children of said parent, then we add these widths to the parent
// if box has three buttons, each button is 100px wide, then box is 300px wide
pub fn calcWidth(ui_ctx: *UIContext) void {
    while (ui_ctx.stack) |stack| {
        var padding: Types.Padding = .{};
        var margin: Types.Margin = .{};
        var box_sizing: UIContext.BoxSizing = .{};
        var parent_box_sizing: UIContext.BoxSizing = .{};
        const ui_node = stack.ptr orelse unreachable;

        if (ui_node.box_sizing) |box| {
            box_sizing = box;
        }

        if (ui_node.style) |style| {
            if (style.padding) |p| {
                padding = p;
            }
            if (style.margin) |m| {
                margin = m;
            }
        }
        const total_padding: f32 = @floatFromInt(padding.left + padding.right);
        const total_margin: f32 = @floatFromInt(margin.left + margin.right);
        if (ui_node.style) |style| {
            if (style.size == null) {
                box_sizing.width += total_padding;
            }
        }

        const parent = ui_node.parent orelse return;

        if (parent.box_sizing) |box| {
            parent_box_sizing = box;
        }

        var child_gap: f32 = @floatFromInt(parent.children.items.len - 1);
        if (parent.style) |parent_style| {
            child_gap *= @as(f32, @floatFromInt(parent_style.child_gap));

            if (parent_style.size == null) {
                if (parent_style.direction == .row) {
                    parent_box_sizing.width += total_padding;
                    parent_box_sizing.width += child_gap;
                    parent_box_sizing.width += total_margin;
                    parent_box_sizing.width += box_sizing.width;
                } else {
                    parent_box_sizing.width = @max(box_sizing.width, parent_box_sizing.width);
                }
            }
        }
        ui_node.box_sizing = box_sizing;
        parent.box_sizing = parent_box_sizing;
        ui_ctx.stackPop();
    }
}
// Breadth first search
// Grow the element widths
// Direction row

fn growWidths(ui_ctx: *UIContext, parent: *UINode) void {
    ui_ctx.stackRegister(parent) catch {
        Vapor.println("Could not stack register\n", .{});
        unreachable;
    };
    if (parent.children.items.len == 0) return;
    const parent_box_sizing = parent.box_sizing orelse return;
    var remaining_width = parent_box_sizing.width;
    var padding: Types.Padding = .{};
    var margin: Types.Margin = .{};
    if (parent.style) |style| {
        if (style.padding) |p| {
            padding = p;
        }
        if (style.margin) |m| {
            margin = m;
        }
    }
    // We subtract the padding from the remaining width of the parent element
    remaining_width -= @floatFromInt(padding.left + padding.right);

    // We first calculate the remaining widths by looping through the children
    // and subtracting the widths of the children from the remaining width
    for (parent.children.items) |child| {
        const parent_style = parent.style orelse return;
        const child_style = child.style orelse continue;
        const child_size = child_style.size orelse continue;
        const child_box_sizing = child.box_sizing orelse continue;
        if (parent_style.direction == .row and child_size.width.type != .percent) {
            remaining_width -= child_box_sizing.width;
        }
    }

    // We then subtract the child gap from the remaining width by multiplying it by the number of children
    var child_gap: f32 = @floatFromInt(parent.children.items.len - 1);
    if (parent.style) |parent_style| {
        child_gap *= @as(f32, @floatFromInt(parent_style.child_gap));
        if (parent_style.direction == .row) {
            remaining_width -= child_gap;
        }
    }
}

// calcWidths is breadth post order first
// we calculate the widths of the children of said parent, then we add these widths to the parent
// if box has three buttons, each button is 100px wide, then box is 300px wide
pub fn calcHeights(ui_ctx: *UIContext) void {
    while (ui_ctx.stack) |stack| {
        var padding: Types.Padding = .{};
        var margin: Types.Margin = .{};
        var box_sizing: UIContext.BoxSizing = .{};
        var parent_box_sizing: UIContext.BoxSizing = .{};
        const ui_node = stack.ptr orelse unreachable;

        if (ui_node.box_sizing) |box| {
            box_sizing = box;
        }

        if (ui_node.style) |style| {
            if (style.padding) |p| {
                padding = p;
            }
            if (style.margin) |m| {
                margin = m;
            }
        }
        const total_padding: f32 = @floatFromInt(padding.left + padding.right);
        const total_margin: f32 = @floatFromInt(margin.left + margin.right);
        if (ui_node.style) |style| {
            if (style.size == null) {
                box_sizing.width += total_padding;
            }
        }

        const parent = ui_node.parent orelse return;

        if (parent.box_sizing) |box| {
            parent_box_sizing = box;
        }

        var child_gap: f32 = @floatFromInt(parent.children.items.len - 1);
        if (parent.style) |parent_style| {
            child_gap *= @as(f32, @floatFromInt(parent_style.child_gap));

            if (parent_style.size == null) {
                if (parent_style.direction == .row) {
                    parent_box_sizing.width += total_padding;
                    parent_box_sizing.width += child_gap;
                    parent_box_sizing.width += total_margin;
                    parent_box_sizing.width += box_sizing.width;
                } else {
                    parent_box_sizing.width = @max(box_sizing.width, parent_box_sizing.width);
                }
            }
        }
        ui_node.box_sizing = box_sizing;
        parent.box_sizing = parent_box_sizing;
        ui_ctx.stackPop();
    }
}
