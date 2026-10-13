const std = @import("std");
const UIContext = @import("UITree.zig");
const Fabric = @import("Fabric.zig");
const Style = @import("types.zig").Style;
const Color = @import("types.zig").Color;
const UINode = @import("UITree.zig").UINode;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Self = @This();

var layout_path: []const u8 = "";
pub var node_map: std.AutoHashMap(u64, usize) = undefined;
pub fn reconcile(old_ctx: *UIContext, new_ctx: *UIContext) void {
    reconcile_debug = false;
    if (old_ctx.root == null) return;
    if (new_ctx.root == null) return;
    node_map.clearRetainingCapacity();
    traverseNodes(old_ctx.root.?, new_ctx.root.?);
}

pub fn reconcileDebug(old_node: *UINode, new_node: *UINode) void {
    // Fabric.println("Reconciling debug\n", .{});
    reconcile_debug = true;
    node_map.clearRetainingCapacity();
    traverseNodes(old_node, new_node);
}

/// Compares two Style instances shallowly (all top-level fields).
/// Returns true if every field is equal, false otherwise.
pub fn nodesEqual(old_node: *UINode, new_node: *UINode) bool {
    if (old_node.compact_style == null and new_node.compact_style == null) return true;
    if (old_node.compact_style == null and new_node.compact_style != null) return false;
    if (old_node.compact_style != null and new_node.compact_style == null) return false;
    const a = old_node.compact_style.?;
    const b = new_node.compact_style.?;
    const a_basic = a.basic orelse return false;
    const b_basic = b.basic orelse return false;
    // Compare optional string fields
    if (!compareOptionalSlice(a_basic.id, b_basic.id)) return false;
    if (!compareOptionalSlice(old_node.text, new_node.text)) return false;
    if (!compareOptionalSlice(a_basic.style_id, b_basic.style_id)) return false;
    if (!compareOptionalSlice(old_node.href, new_node.href)) return false;

    // if (a_basic.hover != null and b_basic.hover != null) {
    //     const hovera = a_basic.hover.?;
    //     const hoverb = b_basic.hover.?;
    //     if (hovera_basic.background != null) {
    //         if (!compareRgba(hovera_basic.background.?, hoverb_basic.background.?)) return false;
    //     }
    // }

    // if (a_basic.layout != b_basic.layout) return false;
    if (a_basic.position != null and b_basic.position != null) {
        if (a_basic.position.?.type != b_basic.position.?.type) return false;
        if (a_basic.position.?.top != null and b_basic.position.?.top != null) {
            if (a_basic.position.?.top.?.value != b_basic.position.?.top.?.value) return false;
        }
        if (a_basic.position.?.bottom != null and b_basic.position.?.bottom != null) {
            if (a_basic.position.?.bottom.?.value != b_basic.position.?.bottom.?.value) return false;
        }
        if (a_basic.position.?.left != null and b_basic.position.?.left != null) {
            if (a_basic.position.?.left.?.value != b_basic.position.?.left.?.value) return false;
        }
        if (a_basic.position.?.right != null and b_basic.position.?.right != null) {
            if (a_basic.position.?.right.?.value != b_basic.position.?.right.?.value) return false;
        }
    }

    if (a_basic.direction != b_basic.direction) return false;

    if (a_basic.size) |a_size| {
        if (b_basic.size) |b_size| {
            if (a_size.width.size.minmax.min != b_size.width.size.minmax.min) return false;
            if (a_size.width.size.minmax.max != b_size.width.size.minmax.max) return false;
            if (a_size.height.size.minmax.min != b_size.height.size.minmax.min) return false;
            if (a_size.height.size.minmax.max != b_size.height.size.minmax.max) return false;
        }
    }

    if (a_basic.padding != null and b_basic.padding != null) {
        if (a_basic.padding.?.top != b_basic.padding.?.top) return false;
        if (a_basic.padding.?.left != b_basic.padding.?.left) return false;
        if (a_basic.padding.?.bottom != b_basic.padding.?.bottom) return false;
        if (a_basic.padding.?.right != b_basic.padding.?.right) return false;
    }
    if (a_basic.margin != null and b_basic.margin != null) {
        if (a_basic.margin.?.top != b_basic.margin.?.top) return false;
        if (a_basic.margin.?.left != b_basic.margin.?.left) return false;
        if (a_basic.margin.?.bottom != b_basic.margin.?.bottom) return false;
        if (a_basic.margin.?.right != b_basic.margin.?.right) return false;
    }

    if (a.visual != null and b.visual != null) {
        const a_visual = a.visual.?;
        const b_visual = b.visual.?;
        // if (a_visual.background != null and b_visual.background != null) {
        //     if (!compareRgba(a_visual.background.?, b_visual.background.?)) return false;
        // }

        if (a_visual.font_size != b_visual.font_size) return false;
        if (a_visual.letter_spacing != b_visual.letter_spacing) return false;
        if (a_visual.line_height != b_visual.line_height) return false;
        if (a_visual.font_weight != b_visual.font_weight) return false;
        if (a_visual.border_radius != null and b_visual.border_radius != null) {
            if (a_visual.border_radius.?.top_left != b_visual.border_radius.?.top_left) return false;
            if (a_visual.border_radius.?.top_right != b_visual.border_radius.?.top_right) return false;
            if (a_visual.border_radius.?.bottom_left != b_visual.border_radius.?.bottom_left) return false;
            if (a_visual.border_radius.?.bottom_right != b_visual.border_radius.?.bottom_right) return false;
        }
        if (a_visual.border_thickness != null and b_visual.border_thickness != null) {
            if (a_visual.border_thickness.?.top != b_visual.border_thickness.?.top) return false;
            if (a_visual.border_thickness.?.left != b_visual.border_thickness.?.left) return false;
            if (a_visual.border_thickness.?.right != b_visual.border_thickness.?.right) return false;
            if (a_visual.border_thickness.?.bottom != b_visual.border_thickness.?.bottom) return false;
        }
        if (a_visual.border_color != null and b_visual.border_color != null) {
            if (!compareRgba(a_visual.border_color.?, b_visual.border_color.?)) return false;
        }
        if (a_visual.border != null and b_visual.border != null) {
            const border_a = a_visual.border.?;
            const border_b = b_visual.border.?;
            if (border_a.color != null and border_b.color != null) {
                if (!compareRgba(border_a.color.?, border_b.color.?)) return false;
            }
        }
        // if (a_visual.text_color != null and b_visual.text_color != null) {
        //     if (!compareRgba(a_visual.text_color.?, b_visual.text_color.?)) return false;
        // }

        if (a_visual.opacity != b_visual.opacity) return false;
    }

    // if (a.overflow != b.overflow) return false;

    // if (a.overflow_x != b.overflow_x) return false;
    // if (a.overflow_y != b.overflow_y) return false;
    if (a_basic.layout != null and b_basic.layout != null) {
        if (a_basic.layout.?.y != b_basic.layout.?.y) return false;
        if (a_basic.layout.?.x != b_basic.layout.?.x) return false;
    }
    if (a_basic.child_gap != b_basic.child_gap) return false;
    if (!compareOptionalSlice(a_basic.dialog_id, b_basic.dialog_id)) return false;

    // // Compare non-optional slice fields
    // if (!std.mem.eql(u8, a.font_family_file, b.font_family_file)) return false;
    // if (!std.mem.eql(u8, a.font_family, b.font_family)) return false;
    // if (!std.mem.eql(f32, a.color[0..], b.color[0..])) return false;
    // if (a.text_decoration != b.text_decoration) return false;
    // if (a.shadow != b.shadow) return false;
    // if (a.white_space != b.white_space) return false;
    // if (a.flex_wrap != b.flex_wrap) return false;
    // if (a.key_frame != b.key_frame) return false;
    // if (a.animation != b.animation) return false;
    // if (a.z_index != b.z_index) return false;
    // if (a.list_style != b.list_style) return false;
    // if (a.blur != b.blur) return false;
    // if (a.outline != b.outline) return false;
    // if (a.transition != b.transition) return false;
    // if (a.show_scrollbar != b.show_scrollbar) return false;
    // if (a.hover != b.hover) return false;
    // if (a.btn_id != b.btn_id) return false;

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

var reconcile_debug: bool = false;
pub fn traverseNodes(old_node: *UINode, new_node: *UINode) void {
    // Fabric.println("{any}", .{Fabric.removed_nodes.items.len});
    if (!reconcile_debug and std.mem.eql(u8, old_node.uuid, "fabric-debugger")) {
        return;
    }
    if (Fabric.rerender_everything or old_node.dirty) {
        new_node.dirty = true;
        Fabric.has_dirty = true;
    } else if (!std.mem.eql(u8, old_node.uuid, new_node.uuid)) {
        // Fabric.println("Old node {s} new node {s}\n", .{ old_node.uuid, new_node.uuid });
        // If the uuids are different it means the node needs to be removed as it is a new node replacing an old node.
        new_node.dirty = true;
        Fabric.has_dirty = true;
        // Fabric.removed_nodes.append(.{ .uuid = old_node.uuid, .index = old_node.index }) catch {};
    } else {
        if (old_node.state_type == .pure) {
            // Static
            if (!nodesEqual(old_node, new_node)) {
                new_node.dirty = true;
                Fabric.has_dirty = true;
            } else {
                new_node.dirty = false;
            }
        } else if (new_node.state_type == .animation or old_node.state_type == .animation) {
        } else if (new_node.type != old_node.type) {
            new_node.dirty = true;
        } else if (new_node.hash != old_node.hash) {
            new_node.dirty = true;
        } else {
            new_node.dirty = false;
        }
    }

    if (old_node.children.items.len != new_node.children.items.len) {

        // Here we remove items, since old_node has more children than new_node
        // [1,2,3,4,5]
        // [3,4,5]
        // we should plan on improving this part of the algorithm since if we remove items 1,2 then below
        // we compare items 1,2,3 with 3,4,5 and so we remove and replace even though in the previous tree, we already had
        // 3,4,5 just different ids of the nodes. below 1 == 3, 2 == 4, 3 == 5
        // this is why keys are typically better in slices since if each node had a unique id, we could just compare
        // that was length independent then we can compare said slices
        if (old_node.children.items.len > new_node.children.items.len) {
            if (new_node.children.items.len == 0) {
                for (old_node.children.items, 0..) |node, j| {
                    if (!reconcile_debug and std.mem.eql(u8, node.uuid, "fabric-debugger")) {
                        continue;
                    }
                    Fabric.removed_nodes.append(.{ .uuid = node.uuid, .index = j }) catch {};
                }
                return;
            }

            // First we perform a diff sync checking the beginning and end of the slices;
            // this assume the keys are unique
            const len_old = old_node.children.items.len;
            const len_new = new_node.children.items.len;
            var i: usize = 0;
            blk: while (i < len_new) : (i += 1) {
                const new_child = new_node.children.items[i];
                const old_child = old_node.children.items[i];
                // Here we the first node are equal in uuid
                if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
                    traverseNodes(old_child, new_child);
                } else {
                    new_child.dirty = true;
                    Fabric.markChildrenDirty(new_child);
                    break :blk;
                }
            }
            // Fabric.println("Moving on\n", .{});

            // i = 1; then element 0 is the same and thus we want to check everything from the back up to element 1
            // since element 1 was checked in the previous loop
            var back_i_new: usize = len_new;
            var back_i_old: usize = len_old;
            // Here we decrement the back_i_new and back_i_old until we find a non equal element
            blk: while (back_i_new > i) : (back_i_new -= 1) {
                const new_child = new_node.children.items[back_i_new - 1];
                const old_child = old_node.children.items[back_i_old - 1];
                // Here we the last node are equal in uuid
                if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
                    traverseNodes(old_child, new_child);
                    back_i_old -= 1;
                } else {
                    break :blk;
                }
            }

            // now we know the middle section where nodes on either side are not equal
            // We only check reording if there are still new nodes to be processed
            // const end = back_i_old;
            const end_new = back_i_new;
            const end_old = back_i_old;
            // the start is the index of the first node that is not equal it is the same for both slices
            const start = i;
            // We create a node map of all the old nodes this is used to find the index of the new node in case things shifted
            for (old_node.children.items[start..end_old], 0..) |old_child, j| {
                node_map.put(hashKey(old_child.uuid), start + j) catch {
                    Fabric.printlnSrcErr("Could not put node into node_map {any}\n", .{old_child.uuid}, @src());
                };
            }

            // We iterate over the new nodes and compare them to the old nodes
            // And then we compare the new node to the old node
            if (end_new > 0) {
                for (new_node.children.items[start..end_new]) |new_child| {
                    // We check if the new node is in the node map if so then we know it shifted
                    const old_child_index = node_map.get(hashKey(new_child.uuid)) orelse continue;
                    _ = node_map.remove(hashKey(new_child.uuid));
                    const old_child = old_node.children.items[old_child_index];
                    traverseNodes(old_child, new_child);
                    // We mark this as dirty since we are shifting the nodes even if the nodes content hasnt changed
                    Fabric.has_dirty = true;
                }
            }

            // // Then we iterate through the node map and remove all the nodes that are not in the new node
            // var node_itr = node_map.iterator();
            // while (node_itr.next()) |entry| {
            //     const uuid = entry.key_ptr.*;
            //     const j = entry.value_ptr.*;
            //     // Fabric.println("Removing node {s}\n", .{uuid});
            //     if (!reconcile_debug and std.mem.eql(u8, uuid, "fabric-debugger")) {
            //         continue;
            //     }
            //
            //     Fabric.removed_nodes.append(.{ .uuid = uuid, .index = j }) catch {};
            // }

            for (old_node.children.items) |old_child| {
                if (!reconcile_debug and std.mem.eql(u8, old_child.uuid, "fabric-debugger")) {
                    continue;
                }
                const node = node_map.fetchRemove(hashKey(old_child.uuid)) orelse continue;
                Fabric.removed_nodes.append(.{ .uuid = old_child.uuid, .index = node.value }) catch {};
            }

            // for (old_node.children.items[start..end]) |node| {
            //     // if (!reconcile_debug and std.mem.eql(u8, node.uuid, "fabric-debugger")) {
            //     //     return;
            //     // }
            //     if (node.state_type == .animation) {
            //         const class_name_enter = node.style.?.child_styles.?[0].style_id;
            //         const class_name_exit = node.style.?.child_styles.?[1].style_id;
            //         const enter = std.mem.Allocator.dupe(Fabric.allocator_global, u8, class_name_enter) catch return;
            //         const exit = std.mem.Allocator.dupe(Fabric.allocator_global, u8, class_name_exit) catch return;
            //         const uuid = std.mem.Allocator.dupe(Fabric.allocator_global, u8, node.uuid) catch return;
            //
            //         // Use the duplicated uuid for BOTH calls
            //         Fabric.addToRemoveClassesList(uuid, enter); // Changed from node.uuid to uuid
            //         Fabric.addToClassesList(uuid, exit);
            //     }
            // }
        } else if (old_node.children.items.len > 0 and new_node.children.items.len > 0) {
            if (!reconcile_debug and std.mem.eql(u8, old_node.uuid, "fabric-debugger")) {
                return;
            }

            if (new_node.children.items.len == 0) {
                for (old_node.children.items, 0..) |node, j| {
                    // Fabric.println("Removing node {s}\n", .{node.uuid});
                    Fabric.removed_nodes.append(.{ .uuid = node.uuid, .index = j }) catch {};
                }
                return;
            }

            // First we perform a diff sync checking the beginning and end of the slices;
            // this assume the keys are unique
            const len_old = old_node.children.items.len;
            const len_new = new_node.children.items.len;
            // We check as long as i is less than old length sicne we are adding new nodes now
            var i: usize = 0;
            blk: while (i < len_old) : (i += 1) {
                const new_child = new_node.children.items[i];
                const old_child = old_node.children.items[i];
                // Here we the first node are equal in uuid
                if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
                    traverseNodes(old_child, new_child);
                } else {
                    // Fabric.println("Breaking\n", .{});
                    break :blk;
                }
            }
            // Fabric.println("Moving on\n", .{}); //

            // i = 1; then element 0 is the same and thus we want to check everything from the back up to element 1
            // since element 1 was checked in the previous loop
            var back_i_new: usize = len_new;
            var back_i_old: usize = len_old;
            // Here we decrement the back_i_new and back_i_old until we find a non equal element
            blk: while (back_i_old > i) : (back_i_old -= 1) {
                const new_child = new_node.children.items[back_i_new - 1];
                const old_child = old_node.children.items[back_i_old - 1];
                // Here we the last node are equal in uuid
                if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
                    traverseNodes(old_child, new_child);
                    back_i_new -= 1;
                } else {
                    break :blk;
                }
            } // Here old node has less then new_node, which means we added nodes

            // Fabric.println("Moving on\n", .{}); //
            // now we know the middle section where nodes on either side are not equal
            // We only check reording if there are still new nodes to be processed
            const end_new = back_i_new;
            const end_old = back_i_old;
            // the start is the index of the first node that is not equal it is the same for both slices
            const start = i;
            // We create a node map of all the new nodes this is used to find the index of the old node in case things shifted
            for (new_node.children.items[start..end_new], start..) |new_child, j| {
                node_map.put(hashKey(new_child.uuid), j) catch {
                    Fabric.printlnSrcErr("Could not put node into node_map {any}\n", .{new_child.uuid}, @src());
                };
            }

            // We iterate over the old nodes and compare them to the new nodes
            if (end_old > 0) {
                for (old_node.children.items[start..end_old], 0..) |old_child, j| {
                    // We check if the new node is in the node map if so then we know it shifted
                    const new_child_index = node_map.get(hashKey(old_child.uuid)) orelse {
                        // This means the old node is not in the new set of nodes
                        Fabric.removed_nodes.append(.{ .uuid = old_child.uuid, .index = start + j }) catch {};
                        continue;
                    };
                    _ = node_map.remove(hashKey(old_child.uuid));
                    const new_child = new_node.children.items[new_child_index];
                    traverseNodes(old_child, new_child);
                    // We mark this as dirty since we are shifting the nodes even if the nodes content hasnt changed
                    Fabric.has_dirty = true;
                }
            }
            // We iterate over the node map and mark all the nodes as dirty as these are added nodes
            var node_itr = node_map.valueIterator();
            while (node_itr.next()) |index| {
                const new_child = new_node.children.items[index.*];
                Fabric.markChildrenDirty(new_child);
            }

            for (new_node.children.items) |new_child| {
                // if (!reconcile_debug and std.mem.eql(u8, new_node.uuid, "fabric-debugger")) {
                //     continue;
                // }
                _ = node_map.fetchRemove(hashKey(new_child.uuid)) orelse continue;
            }

            Fabric.has_dirty = true;
        } else if (new_node.children.items.len > 0) {
            if (!reconcile_debug and std.mem.eql(u8, old_node.uuid, "fabric-debugger")) {
                return;
            }

            // Fabric.printlnSrc("Old is empty only new nodes {s}", .{old_node.uuid}, @src());
            // Fabric.println("Removing node {s}\n", .{old_node.uuid});
            Fabric.removed_nodes.append(.{ .uuid = old_node.uuid, .index = 0 }) catch {};
            for (new_node.children.items) |node| {
                Fabric.markChildrenDirty(node);
            }
        } else if (old_node.children.items.len > 0) {
            // Fabric.printlnSrc("New is empty only old nodes", .{}, @src());
            for (old_node.children.items, 0..) |old_child, j| {
                // Fabric.println("Removing node {s}\n", .{old_node.uuid});
                Fabric.removed_nodes.append(.{ .uuid = old_child.uuid, .index = j }) catch {};
            }
        }
    } else {
        for (old_node.children.items, 0..) |old_child, i| {
            // Fabric.printlnSrc("Same lengths {s} {s}", .{ old_node.uuid, new_node.uuid }, @src());
            traverseNodes(old_child, new_node.children.items[i]);
        }
    }
}
