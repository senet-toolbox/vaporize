const std = @import("std");
const Vapor = @import("vapor");
const Static = Vapor.Static;
const Pure = Vapor.Pure;
const UIContext = @import("UITree.zig");
const LifeCycle = @import("Vapor.zig").LifeCycle;
const UINode = @import("UITree.zig").UINode;
const Wasm = @import("wasm");
const PureTree = @import("PureTree.zig");
const Event = @import("Event.zig");
const Types = @import("types.zig");
const Box = Static.Box;
const TextFmt = Static.TextFmt;
const Text = Static.Text;
const CtxButton = Static.CtxButton;
const Stack = Static.Stack;
const Button = Static.Button;
const ButtonCycle = Static.ButtonCycle;
const Hooks = Static.Hooks;
const FrameAllocator = @import("FrameAllocator.zig");

pub var old_debugger_node: ?*UINode = null;
pub var new_debugger_node: ?*UINode = null;
pub var show_debugger: bool = true;

const MenuItem = struct {
    text: []const u8,
    on_press: *const fn () void,
    page: *const fn () void,
    index: usize = 0,
};

const menu: []const MenuItem = &.{
    MenuItem{ .text = "Trees", .on_press = toggleTree, .page = treePage, .index = 0 },
    MenuItem{ .text = "Debug", .on_press = debugToggle, .page = debugPage, .index = 1 },
    MenuItem{ .text = "Memory", .on_press = memoryToggle, .page = memoryPage, .index = 2 },
};

var current_menu: MenuItem = menu[1];

fn debugToggle() void {
    current_menu = menu[1];
    Vapor.cycle();
}

fn toggleBuildOptions() void {
    Vapor.lib.build_options.debug_level = .all;
    Vapor.cycle();
}

fn memoryToggle() void {
    current_menu = menu[2];
    Vapor.cycle();
}

fn treePage() void {
    current_menu = menu[0];
    Vapor.cycle();
}

fn debugPage() void {
    Box.id("debug").direction(.column).spacing(16).body()({
        Text("Debug").style(&.{
            .visual = .{ .font_size = 18 },
            .interactive = .hover_text(.hex("#4800FF")),
            .font_family = "IBM Plex Mono,monospace",
        });
        Hooks(.{ .mounted = mountTimer })({
            Box.direction(.column).spacing(4).body()({
                TextFmt("Generation time: {d}", .{Vapor.lib.Timer.generation_time}).style(&.{
                    .visual = .{ .font_size = 14 },
                    .font_family = "IBM Plex Mono,monospace",
                });
                TextFmt("Reconcile time: {d}", .{Vapor.lib.Timer.reconcile_time}).style(&.{
                    .visual = .{ .font_size = 14 },
                    .font_family = "IBM Plex Mono,monospace",
                });
                TextFmt("Commit time: {d}", .{Vapor.lib.Timer.commit_time}).style(&.{
                    .visual = .{ .font_size = 14 },
                    .font_family = "IBM Plex Mono,monospace",
                });
                TextFmt("Total time: {d}", .{Vapor.lib.Timer.total_time}).style(&.{
                    .visual = .{ .font_size = 14 },
                    .font_family = "IBM Plex Mono,monospace",
                });
            });
        });
    });
}

fn rerender() void {
    Vapor.cycle();
}

var memory_stats: ?FrameAllocator.Stats = null;
fn mountStats() void {
    Vapor.print("Mount Stats\n", .{});
    memory_stats = Vapor.getFrameArena().getStats();
    // Vapor.registerCtxTimeout(60, rerender, .{{}});
    Vapor.onEnd(Vapor.cycle);
    // Vapor.cycle();
}

fn mountTimer() void {
    // Vapor.onEnd(Vapor.cycle);
    Vapor.cycle();
}

fn memoryPage() void {
    Box.id("memory").direction(.column).spacing(16).body()({
        Text("Memory").style(&.{
            .visual = .{ .font_size = 18 },
            .interactive = .hover_text(.hex("#4800FF")),
            .font_family = "IBM Plex Mono,monospace",
        });
        Hooks(.{ .mounted = mountStats })({
            Box.direction(.column).spacing(4).body()({
                // const stats = Vapor.getFrameArena().getStats();
                if (memory_stats) |stats| {
                    TextFmt("Nodes: {d}", .{stats.nodes_allocated}).style(&.{
                        .visual = .{ .font_size = 14 },
                        .font_family = "IBM Plex Mono,monospace",
                    });
                    TextFmt("Tree Memory: {d}B", .{stats.tree_memory}).style(&.{
                        .visual = .{ .font_size = 14 },
                        .font_family = "IBM Plex Mono,monospace",
                    });
                    TextFmt("Commands: {d}", .{stats.commands_allocated}).style(&.{
                        .visual = .{ .font_size = 14 },
                        .font_family = "IBM Plex Mono,monospace",
                    });
                    TextFmt("Command Memory: {d}B", .{stats.command_memory}).style(&.{
                        .visual = .{ .font_size = 14 },
                        .font_family = "IBM Plex Mono,monospace",
                    });
                    TextFmt("Node Memory: {d}B", .{stats.nodes_memory}).style(&.{
                        .visual = .{ .font_size = 14 },
                        .font_family = "IBM Plex Mono,monospace",
                    });
                    TextFmt("Allocated Bytes: {d}B", .{stats.bytes_used}).style(&.{
                        .visual = .{ .font_size = 14 },
                        .font_family = "IBM Plex Mono,monospace",
                    });
                }
            });
        });
    });
}

pub const Debug = struct {
    const Self = @This();
    _elem_type: Vapor.ElementType,

    pub const Debugger = Self{ ._elem_type = .FlexBox };
    pub inline fn style(self: *const Self, style_ptr: *const Vapor.Style) fn (void) void {
        var elem_decl = Vapor.ElementDecl{
            .state_type = .static,
            .elem_type = self._elem_type,
            .style = style_ptr,
        };
        var mutable_style = style_ptr.*;
        mutable_style.direction = .column;
        elem_decl.style = &mutable_style;

        new_debugger_node = LifeCycle.open(elem_decl) orelse unreachable;

        LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close;
    }
};

const Tree = enum {
    Pure,
    Error,
};

var tree: Tree = .Pure;
fn toggleTree() void {
    if (tree == .Pure) {
        tree = .Error;
    } else {
        tree = .Pure;
    }
}

pub fn render() void {
    if (show_debugger) {
        Debug.Debugger.style(&.{
            .position = .{ .type = .fixed, .top = .px(0), .right = .px(0) },
            .size = .hw(.percent(100), .px(400)),
            // .padding = .tb(12, 12),
            .z_index = 999,
            .visual = .{ .background = .white, .border = .l(1, .hex("#CFCFCF")) },
        })({
            Stack.style(&.{
                .size = .hw(.percent(100), .percent(100)),
                .child_gap = 6,
            })({
                Box.layout(.left_center).border(.bottom(.hex("#CFCFCF"))).height(.px(27)).background(.hex("#F4F4F4")).spacing(8).body()({
                    for (menu, 0..) |item, i| {
                        Button(.{ .on_press = item.on_press })
                            // .border(.lr(.hex("#A3A3A3")))
                            .cursor(.pointer).body()({
                            Text(item.text).style(&.{
                                .visual = .{ .font_size = 14, .text_color = if (i == current_menu.index) .hex("#4800FF") else .hex("#A3A3A3") },
                                .interactive = .hover_text(.hex("#4800FF")),
                                .font_family = "IBM Plex Mono,monospace",
                            });
                        });
                    }
                });
                Stack.padding(.horizontal(8)).spacing(8).body()({
                    @call(.auto, current_menu.page, .{});
                });
                // Box.style(&.{
                //     .visual = .{ .border = .bottom(.hex("#000000")) },
                //     .child_gap = 6,
                //     .layout = .x_between_center,
                // })({
                //     // Trees;
                //     ButtonCycle(.{ .on_press = toggleTree }).background(.transparent).cursor(.pointer).body()({
                //         TextFmt("{s} Tree", .{@tagName(tree)}).style(&.{
                //             .visual = .{
                //                 .font_size = 18,
                //                 .font_weight = 400,
                //             },
                //             .interactive = .hover_text(.hex("#4800FF")),
                //             .font_family = "IBM Plex Mono,monospace",
                //         });
                //     });
                //
                //     Button(.{ .on_press = clearHighlight }).background(.transparent).cursor(.pointer).body()({
                //         Text("Clear").style(&.{
                //             .visual = .{ .font_size = 18 },
                //             .interactive = .hover_text(.hex("#4800FF")),
                //             .font_family = "IBM Plex Mono,monospace",
                //         });
                //     });
                // });
                // if (tree == .Pure) {
                //     displayChild(Vapor.pure_tree.root);
                // } else {
                //     displayChild(Vapor.error_tree.root);
                // }
            });
        });
    } else {
        new_debugger_node = null;
    }
}

fn highlightTarget(target_id: []const u8) void {
    Wasm.highlightTargetNode(target_id.ptr, target_id.len, 0);
}

fn highlightErrorTarget(target_id: []const u8) void {
    Wasm.highlightTargetNode(target_id.ptr, target_id.len, 1);
}

fn highlightHoverTarget(target_id: []const u8) void {
    Wasm.highlightHoverTargetNode(target_id.ptr, target_id.len, 0);
}

fn highlightHoverErrorTarget(target_id: []const u8) void {
    Wasm.highlightHoverTargetNode(target_id.ptr, target_id.len, 1);
}

fn clearHoverHighlight(_: *Event) void {
    Wasm.clearHoverHighlight();
}

fn clearHighlight() void {
    Wasm.clearHighlight();
}

fn highlight(target_id: []const u8) void {
    if (tree == .Pure) {
        highlightTarget(target_id);
    } else {
        highlightErrorTarget(target_id);
    }
}

fn hoverHighlight(target_id: []const u8, _: *Event) void {
    if (tree == .Pure) {
        highlightHoverTarget(target_id);
    } else {
        highlightHoverErrorTarget(target_id);
    }
}

fn mount(node: *PureTree.PureNode) void {
    _ = node.element.addInstListener(.mouseenter, node.uuid, hoverHighlight);
    _ = node.element.addListener(.mouseleave, clearHoverHighlight);
}

var margin_left: usize = 0;
fn displayChild(node: *PureTree.PureNode) void {
    margin_left += 10;
    for (node.children.items) |child| {
        const visual = Types.Visual{
            .font_size = 12,
            .border = if (child.dirty) .simple(.hex("#4800FF")) else .simple(.transparent),
        };
        Static.CtxHooks(.mounted, mount, .{child}, &.{})({
            CtxButton(highlight, .{child.uuid}).bind(&child.element).style(&.{
                .layout = .{},
                .direction = .row,
                .margin = .l(margin_left),
                .size = .hw(.fit, .fit),
                .padding = .lr(4, 4),
                .visual = visual,
            })({
                TextFmt("{s}", .{@tagName(child.ui_node.type)}).style(&.{
                    .visual = .{ .font_size = 12, .font_weight = 600 },
                    .margin = .r(4),
                });
                TextFmt("UUID: {s}", .{child.uuid}).style(&.{});
            });
        });
        displayChild(child);
    }
    margin_left -= 10;
}

pub fn onKeyPress(evt: *Event) void {
    const key = evt.key();
    if (std.mem.eql(u8, key, "x") and evt.metaKey()) {
        evt.preventDefault();
        show_debugger = true;
        Vapor.cycle();
    } else if (std.mem.eql(u8, key, "Escape")) {
        evt.preventDefault();
        show_debugger = false;
        Vapor.cycle();
    }
}
