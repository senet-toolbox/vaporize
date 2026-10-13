//     e - l - l - o
//   /
// h - a - t
//       \
//        v - e
const std = @import("std");
const UITree = @import("UITree.zig");
const Vapor = @import("Vapor.zig");
const mem = std.mem;

const RadixError = error{
    FailedToInitRadix,
    FailedToCreateNode,
};

const Radix = @This();
allocator: std.mem.Allocator,
root: *Node,

fn findCommonPrefix(a: []const u8, b: []const u8) usize {
    var i: usize = 0;
    while (i < a.len and i < b.len and a[i] == b[i]) : (i += 1) {}
    return i;
}

pub const Node = struct {
    prefix: []const u8,
    tree: ?*UITree,
    query_param: []const u8,
    is_dynamic: bool,
    children: std.StringHashMap(*Node),
    param_child: ?*Node,
    is_end: bool,
    page: *const fn () void,
    sub_path: []const u8,

    fn findChildWithCommonPrefix(node: *Node, prefix: []const u8) ?*Node {
        var children_itr = node.children.iterator();
        var best_match: ?*Node = null;
        var max_common_len: usize = 0;

        while (children_itr.next()) |c| {
            const child_prefix = c.value_ptr.*.prefix;
            const common_len = findCommonPrefix(child_prefix, prefix);
            if (common_len > max_common_len) {
                max_common_len = common_len;
                best_match = c.value_ptr.*;
            }
        }
        return best_match;
    }

    // hello is the node and i is 4 since we passed hell
    fn splitNode(
        self: *Node,
        at: usize,
        allocator: std.mem.Allocator,
        page: *const fn () void,
    ) !*Node {
        // We take the current node and set it as the child,
        // so now we move everything from current to child
        // current = handleUsers -> child = handleUsers while now current = treeUser
        // since we split the node
        // we create a new node of o
        const new_node = try allocator.create(Node);
        new_node.* = Node{
            .prefix = self.prefix[at..],
            .tree = self.tree,
            .query_param = self.query_param,
            .is_dynamic = self.is_end,
            .children = self.children,
            .param_child = self.param_child,
            .is_end = true,
            .page = page,
            .sub_path = self.sub_path[at..],
        };

        // set the current node to hell
        self.prefix = self.prefix[0..at];
        self.sub_path = self.sub_path[0..at];
        self.children = std.StringHashMap(*Node).init(allocator);
        // store the new_node o in the hell node
        try self.children.put(new_node.prefix, new_node);

        return new_node;
    }
};

pub fn init(target: *Radix, arena: *std.mem.Allocator) !void {
    const root_node = try arena.*.create(Node);
    root_node.* = Node{
        .prefix = "",
        .tree = null,
        .query_param = "",
        .is_dynamic = false,
        .children = std.StringHashMap(*Node).init(arena.*),
        .param_child = null,
        .is_end = false,
        .page = undefined,
        .sub_path = "",
    };
    target.* = .{
        .root = root_node,
        .allocator = arena.*,
    };
}

pub fn deinit(radix: *Radix) void {
    // radix.allocator.destroy(radix.root);
    radix.recurseDestroy(radix.root);
}

// Recursively process all children
fn recurseDestroy(radix: *Radix, node: *Node) void {
    var children_itr = node.children.iterator();
    while (children_itr.next()) |child| {
        radix.recurseDestroy(child.value_ptr.*);
    }
    node.children.deinit();
    radix.allocator.destroy(node);
}

fn newNode(
    radix: *Radix,
    prefix: []const u8,
    tree: *UITree,
    query_param: []const u8,
    is_end: bool,
    page: *const fn () void,
    sub_path: []const u8,
) !*Node {
    const node = try radix.allocator.create(Node);
    node.* = Node{
        .prefix = prefix, // Initialize the prefix field
        .tree = tree,
        .query_param = query_param,
        .is_dynamic = false,
        .children = std.StringHashMap(*Node).init(radix.allocator),
        .param_child = null,
        .is_end = is_end,
        .page = page,
        .sub_path = sub_path,
    };
    return node;
}

fn findSegmentEndIdx(path: []const u8) usize {
    var idx: usize = 0;
    while (idx < path.len and path[idx] != '/') : (idx += 1) {
        if (path[idx] == 0) return idx;
    }
    return idx;
}

// /api/test
const Route = struct {
    ui_tree: *UITree = undefined,
    page: *const fn () void = undefined,
    is_dynamic: bool = false,
    path: []const u8,
};
pub fn searchRoute(radix: *const Radix, path: []const u8) ?Route {
    var node_path: std.array_list.Managed(u8) = std.array_list.Managed(u8).init(Vapor.arena(.frame));
    // var param_args: ?*std.array_list.Managed(ParamInfo) = null;
    var node = radix.root;
    var start: usize = 1;

    // Manually parse path segments to avoid iterator overhead
    while (start < path.len) : (start += 1) {
        if (path[start] == '/') continue;
        if (path[start] == '#') break;
        if (path[start] == ' ') break;
        if (path[start] == 0) break;
        // api/test
        // Skip leading slashes
        if (start >= path.len) break;
        const end = findSegmentEndIdx(path[start..]) + start;
        const segment = path[start..end];
        start = end;

        var remaining = segment;
        while (remaining.len > 0) {
            const match = node.findChildWithCommonPrefix(remaining) orelse return null;

            const common_len = findCommonPrefix(match.prefix, remaining);

            if (common_len != match.prefix.len) return null;
            remaining = remaining[common_len..];
            node = match;
            node_path.append('/') catch unreachable;
            node_path.appendSlice(match.sub_path) catch unreachable;
        }

        // Handle dynamic parameters
        if (node.param_child) |dynamic_child| {
            // Look ahead for next segment
            var param_start = start;
            while (param_start < path.len and path[param_start] == '/') : (param_start += 1) {}
            if (param_start >= path.len) break;

            const param_end = std.mem.indexOfScalarPos(u8, path, param_start, '/') orelse path.len;
            _ = path[param_start..param_end];
            start = param_end + 1;
            node = dynamic_child;
            node_path.append('/') catch unreachable;
            node_path.appendSlice(dynamic_child.sub_path) catch unreachable;
        }
    }

    if (node.is_end) {
        return Route{
            .ui_tree = node.tree.?,
            .page = node.page,
            .is_dynamic = node.is_dynamic,
            .path = node_path.toOwnedSlice() catch unreachable,
        };
    }
    return null;
}

pub fn addRoute(
    radix: *Radix,
    path: []const u8,
    tree: *UITree,
    page: *const fn () void,
) !void {
    var path_iter = mem.tokenizeScalar(u8, path, '/');
    try radix.insert(&path_iter, tree, page);
}

fn insert(
    radix: *Radix,
    segments: *mem.TokenIterator(u8, .scalar),
    tree: *UITree,
    page: *const fn () void,
) !void {
    var node = radix.root;
    while (segments.next()) |segment| {
        var segement_remaining = segment;
        const is_dynamic = segment[0] == ':';
        if (is_dynamic) {
            const param = segment[1..];
            if (node.param_child) |_| return error.ConflictDynamicRoute;
            const dynamic_node = try radix.newNode(":dynamic", tree, param, true, page, segment);
            node.param_child = dynamic_node;
            node.is_end = true;
            return;
        }

        // Inside the insertion loop:
        while (segement_remaining.len > 0) {
            // hell is common with hello, hell
            // this finds is there is a child with hell prefix
            const matching_child = node.findChildWithCommonPrefix(segement_remaining);
            if (matching_child) |child| {
                var i: usize = 0;
                // The word_remingin is hello
                // Find length of common prefix which is hell for hello which is 4
                while (i < child.prefix.len and i < segement_remaining.len and child.prefix[i] == segement_remaining[i]) : (i += 1) {}

                if (i < child.prefix.len) {
                    _ = try child.splitNode(i, radix.allocator, page);
                    // Once we splitt the node we need to set the current to the correct route func
                    child.tree = tree;
                    child.prefix = segement_remaining[0..i];
                    child.sub_path = segement_remaining[0..i];
                    child.param_child = null;
                    node = child;
                    // Focus on the PARENT (the split node, now "hell")
                } else {
                    node = child;
                }
                // Advance the word remianing
                segement_remaining = segement_remaining[i..];
            } else {
                // const param = if (is_dynamic) segment[1..] else "";
                // create a new RouteFunc
                // check the current node hello startwith hell
                const new_node = try radix.newNode(
                    segement_remaining,
                    tree,
                    "",
                    false,
                    page,
                    segement_remaining,
                );
                try node.children.put(segement_remaining, new_node);
                node = new_node;
                break;
            }
        }
    }
    node.is_end = true;
}

/// Update the UITree for a specific route path
/// Returns true if the route was found and updated, false otherwise
pub fn updateRouteTree(radix: *Radix, path: []const u8, new_tree: *UITree) bool {
    var node = radix.root;
    var start: usize = 1;

    // Parse path segments similar to searchRoute
    while (start < path.len) : (start += 1) {
        if (path[start] == '/') continue;
        if (path[start] == '#') break;
        if (path[start] == ' ') break;
        if (path[start] == 0) break;

        if (start >= path.len) break;
        const end = findSegmentEndIdx(path[start..]) + start;
        const segment = path[start..end];
        start = end;

        var remaining = segment;
        while (remaining.len > 0) {
            const match = node.findChildWithCommonPrefix(remaining) orelse return false;
            const common_len = findCommonPrefix(match.prefix, remaining);

            if (common_len != match.prefix.len) return false;
            remaining = remaining[common_len..];
            node = match;
        }

        // Handle dynamic parameters
        if (node.param_child) |dynamic_child| {
            var param_start = start;
            while (param_start < path.len and path[param_start] == '/') : (param_start += 1) {}
            if (param_start >= path.len) break;

            const param_end = std.mem.indexOfScalarPos(u8, path, param_start, '/') orelse path.len;
            start = param_end + 1;
            node = dynamic_child;
        }
    }

    // Update the tree if this is an end node
    if (node.is_end) {
        node.tree = new_tree;
        return true;
    }
    return false;
}

fn printTree(radix: *const Radix) !void {
    var buffer = std.array_list.Managed(u8).init(radix.allocator);
    defer buffer.deinit();
    // Start traversal from the root's children (root itself has no prefix)
    try printNode(radix.root, &buffer);
}

fn printNode(node: *const Node, buffer: *std.array_list.Managed(u8)) !void {
    // Save current buffer length to backtrack later
    const original_len = buffer.items.len;

    // Append this node's prefix to the buffer
    try buffer.appendSlice(node.prefix);

    // print("\n{s}", .{node.prefix});
    // If this node marks the end of a word, print the accumulated buffer

    // Recursively process all children
    var children_itr = node.children.iterator();
    while (children_itr.next()) |child| {
        try printNode(child.value_ptr.*, buffer);
    }

    if (node.param_child) |child| {
        if (child.is_end) {
            try buffer.appendSlice(child.prefix);
        }
    }

    // Backtrack: remove this node's prefix to prepare for sibling paths
    buffer.shrinkRetainingCapacity(original_len);
}
