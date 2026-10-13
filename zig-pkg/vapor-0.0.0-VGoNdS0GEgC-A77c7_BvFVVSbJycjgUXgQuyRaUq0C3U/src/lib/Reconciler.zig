const std = @import("std");
const UIContext = @import("UITree.zig");
const Vapor = @import("Vapor.zig");
const Style = @import("types.zig").Style;
const Color = @import("types.zig").Color;
const UINode = @import("UITree.zig").UINode;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Self = @This();

var layout_path: []const u8 = "";
// pub var node_map: std.StringHashMap(usize) = undefined;
var reconcile_debug: bool = false;

pub fn reconcile(old_ctx: *UIContext, new_ctx: *UIContext) void {
    reconcile_debug = false;
    if (old_ctx.root == null or new_ctx.root == null) return;

    // node_map is file-scoped, so it's reused. Clear it.
    traverseNodes(old_ctx.root.?, new_ctx.root.?);
}

// --- Child Reconciliation Helpers ---

/// Case: Old children exist, new children list is empty.
fn removeAllChildren(old_items: []*UINode) void {
    for (old_items, 0..) |old_child, j| {
        // TODO: You may want to skip the debugger here too
        Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = j }) catch {};
    }
}

/// Case: Old children list is empty, new children exist.
fn addAllChildren(new_items: []*UINode) void {
    // Mark all new children as dirty (for creation)

    for (new_items) |node| {
        Vapor.markChildrenDirty(node);
    }
    Vapor.has_dirty = true;
}

/// Case: Both lists have the same number of children.
// We cannot remove any nodes here as they just may have shifted
fn reconcileSameLength(old_items: []*UINode, new_items: []*UINode) void {
    for (old_items, 0..) |old_child, i| {
        const new_child = new_items[i];
        traverseNodes(old_child, new_child);
    }
}

/// Case: Keyed-diffing when old_items.len > new_items.len (Deletions)
fn reconcileDeletions(old_items: []*UINode, new_items: []*UINode, _: *UINode) void {
    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    const len_old = old_items.len;
    const len_new = new_items.len;

    // 1. Sync from start
    var i: usize = 0;
    while (i < len_new) : (i += 1) {
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i_old: usize = len_old;
    var back_i_new: usize = len_new;
    while (back_i_new > i and back_i_old > i) {
        // ... (logic unchanged) ...
        const old_child = old_items[back_i_old - 1];
        const new_child = new_items[back_i_new - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i_old -= 1;
            back_i_new -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end_new = back_i_new;

    // Add all *old* nodes from the middle section to the (local) map
    for (old_items[start..back_i_old], start..) |old_child, j| {
        node_map.put(old_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{old_child.uuid}, @src());
        };
    }

    // Iterate *new* nodes in the middle section
    if (end_new > start) {
        for (new_items[start..end_new]) |new_child| {
            // Vapor.print("New {s}\n", .{new_child.uuid});
            if (node_map.fetchRemove(new_child.uuid)) |old_child_entry| {
                const old_child = old_items[old_child_entry.value];
                traverseNodes(old_child, new_child); // This recursive call is now safe
                Vapor.has_dirty = true; // It moved
            } else {
                new_child.dirty = true;
                Vapor.has_dirty = true;
                new_child.state_type = .added;
                Vapor.markChildrenDirty(new_child);
            }
        }
    }

    // 4. Any nodes *left* in the (local) map are deletions
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const j = entry.value_ptr.*;
        const uuid = entry.key_ptr.*;
        Vapor.removed_nodes.append(.{ .uuid = uuid, .index = j }) catch {};
    }
}

fn reconcileSame(old_items: []*UINode, new_items: []*UINode) void {
    // ---
    // FIX: Create a local map.
    // NOTE: You MUST replace 'Vapor.allocator' with your actual allocator!
    // ---
    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    const len = old_items.len;

    // 1. Sync from start
    var i: usize = 0;
    while (i < len) : (i += 1) {
        // ... (logic unchanged) ...
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i: usize = len;
    while (back_i > i) {
        // ... (logic unchanged) ...
        const old_child = old_items[back_i - 1];
        const new_child = new_items[back_i - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end = back_i;

    // Add all *new* nodes from the middle section to the (local) map
    for (new_items[start..end], start..) |new_child, j| {
        node_map.put(new_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{new_child.uuid}, @src());
        };
    }

    // Iterate *old* nodes in the middle section
    for (old_items[start..end], start..) |old_child, offset| {
        if (node_map.fetchRemove(old_child.uuid)) |new_child_entry| {
            const new_child = new_items[new_child_entry.value];
            traverseNodes(old_child, new_child); // This recursive call is now safe
            Vapor.has_dirty = true; // It moved
        } else {
            Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = offset }) catch {};
        }
    }

    // 4. Any nodes *left* in the (local) map are *additions*.
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const new_child_index = entry.value_ptr.*;
        // This is now safe! The map only contains indices for *this* call's new_items.
        const new_child = new_items[new_child_index];
        new_child.state_type = .added;
        Vapor.markChildrenDirty(new_child); // Mark for creation
    }
    Vapor.has_dirty = true; // Parent is dirty due to adds/moves
}

/// Case: Keyed-diffing when new_items.len > old_items.len (Additions)
fn reconcileAdditions(old_items: []*UINode, new_items: []*UINode) void {
    // ---
    // FIX: Create a local map.
    // NOTE: You MUST replace 'Vapor.allocator' with your actual allocator!
    // ---
    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    const len_old = old_items.len;
    const len_new = new_items.len;

    // 1. Sync from start
    var i: usize = 0;
    while (i < len_old) : (i += 1) {
        // ... (logic unchanged) ...
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i_old: usize = len_old;
    var back_i_new: usize = len_new;
    while (back_i_old > i and back_i_new > i) {
        // ... (logic unchanged) ...
        const old_child = old_items[back_i_old - 1];
        const new_child = new_items[back_i_new - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i_old -= 1;
            back_i_new -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end_old = back_i_old;
    const end_new = back_i_new;

    // Add all *new* nodes from the middle section to the (local) map
    for (new_items[start..end_new], start..) |new_child, j| {
        node_map.put(new_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{new_child.uuid}, @src());
        };
    }

    // Iterate *old* nodes in the middle section
    for (old_items[start..end_old], start..) |old_child, offset| {
        if (node_map.fetchRemove(old_child.uuid)) |new_child_entry| {
            const new_child = new_items[new_child_entry.value];
            traverseNodes(old_child, new_child); // This recursive call is now safe
            Vapor.has_dirty = true; // It moved
        } else {
            Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = offset }) catch {};
        }
    }

    // 4. Any nodes *left* in the (local) map are *additions*.
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const new_child_index = entry.value_ptr.*;
        // This is now safe! The map only contains indices for *this* call's new_items.
        const new_child = new_items[new_child_index];
        new_child.state_type = .added;
        Vapor.markChildrenDirty(new_child); // Mark for creation
    }
    Vapor.has_dirty = true; // Parent is dirty due to adds/moves
}

// --- Main Reconciler Function ---
var empty_slice: []*UINode = &[_]*UINode{};
pub fn traverseNodes(old_node: *UINode, new_node: *UINode) void {
    // --- 1. Reconcile current node properties ---
    // This logic is much flatter and easier to read.
    const changed = (new_node.finger_print != old_node.finger_print);
    new_node.style_changed = (new_node.style_hash != old_node.style_hash);

    var is_dirty = changed or
        Vapor.rerender_everything or
        old_node.dirty;

    if (!std.mem.eql(u8, old_node.uuid, new_node.uuid)) {
        // There is a strange bug where using the potential_nodes is weird and causes a crash
        is_dirty = true;
    }

    new_node.dirty = is_dirty;
    if (is_dirty) {
        Vapor.has_dirty = true;
    }

    // --- 2. Reconcile children ---
    // Get child slices, defaulting to an empty slice if children are null.
    // This avoids all the `children != null` checks.
    const old_items = if (old_node.children) |l| l.items else empty_slice;
    const new_items = if (new_node.children) |l| l.items else empty_slice;

    // This single if/else block replaces all the nested logic.
    if (new_items.len == 0) {
        if (old_items.len > 0) {
            // Case: New is empty, Old had items -> Remove all old
            removeAllChildren(old_items);
        }
        // Else: Both empty -> Do nothing
    } else if (old_items.len == 0) {
        // Case: New has items, Old was empty -> Add all new
        addAllChildren(new_items);
    } else if (old_items.len == new_items.len) {
        // Case: Same length -> Simple 1:1 traversal
        reconcileSame(old_items, new_items);
    } else {
        // Case: Different lengths -> Keyed diff
        if (old_items.len > new_items.len) {
            // Vapor.print("Reconcile deletions\n", .{});
            reconcileDeletions(old_items, new_items, new_node);
        } else {
            reconcileAdditions(old_items, new_items);
        }
    }
}
