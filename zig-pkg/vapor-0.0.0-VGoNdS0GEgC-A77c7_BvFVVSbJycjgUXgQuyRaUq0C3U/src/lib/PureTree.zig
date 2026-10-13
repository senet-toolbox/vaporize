const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const UI = @import("UITree.zig");
const Vapor = @import("Vapor.zig");
const Element = @import("Element.zig").Element;
const print = Vapor.println;

pub const PureNode = struct {
    uuid: []const u8,
    ui_node: *UINode,
    children: std.array_list.Managed(*PureNode),
    dirty: bool = false,
    element: Element,
};

// The stack holds the current node we are traversing and the next node
// We add the next node to the front of the stack this way we can keep track of the order the nodes are added in
const StackItem = struct {
    node: ?*PureNode = null,
    next: ?*StackItem = null,
};

const PureTree = @This();
allocator: *std.mem.Allocator,
root: *PureNode,
current_parent: ?*PureNode = null,
stack: ?*StackItem = null,

pub fn init(pure_tree: *PureTree, ui_node: *UINode, allocator: *std.mem.Allocator) !void {
    const root = try allocator.create(PureNode);
    root.* = .{
        .uuid = ui_node.uuid,
        .ui_node = ui_node,
        .children = std.array_list.Managed(*PureNode).init(allocator.*),
        .element = Element{},
    };
    const item = try allocator.create(StackItem);
    item.* = .{ .node = root };
    pure_tree.* = .{
        .allocator = allocator,
        .root = root,
        .stack = item,
        .current_parent = root,
    };
}

pub fn createNode(pure_tree: *PureTree, ui_node: *UINode) !*PureNode {
    const node = try pure_tree.allocator.create(PureNode);
    node.* = .{
        .uuid = ui_node.uuid,
        .ui_node = ui_node,
        .dirty = ui_node.dirty,
        .children = std.array_list.Managed(*PureNode).init(pure_tree.allocator.*),
        .element = Element{},
    };

    return node;
}

/// takes the current stack item and the next node we are going to look at, adds the new node to the front of the stack
/// and set the current stack item to the next item
pub fn queueStackItem(pure_tree: *PureTree, current_item: *StackItem, node: *PureNode) !*StackItem {
    const item = try pure_tree.allocator.create(StackItem);
    item.* = .{ .node = node, .next = current_item };
    return item;
}

pub fn openNode(pure_tree: *PureTree, child: *PureNode) !void {
    const stack = pure_tree.stack orelse return error.StackNull;
    const parent = stack.node orelse return error.StackNull;
    try parent.children.append(child);
    const item = try pure_tree.queueStackItem(stack, child);
    pure_tree.stack = item;
}

pub fn popStack(pure_tree: *PureTree) ?*PureNode {
    const item = pure_tree.stack orelse return null;
    defer pure_tree.allocator.destroy(item);
    pure_tree.stack = item.next;
    return item.node.?;
}

/// Public function to start printing the tree.
pub fn printTree(self: *PureTree) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    // 1. Print the root node's UUID.
    writer.print("{s}\n", .{self.root.uuid}) catch {};

    // 2. Iterate through the root's direct children to start the process.
    for (self.root.children.items, 0..) |child, i| {
        const is_last = (i == self.root.children.items.len - 1);
        // Start the recursion with an empty prefix.
        try self.printNode(&writer, child, "", is_last);
    }
    Vapor.println("PureTree {s}\n", .{buffer[0..writer.end]});
}

/// Private recursive function to print a node and its descendants.
fn printNode(self: *PureTree, writer: anytype, node: *PureNode, prefix: []const u8, is_last: bool) !void {
    // 1. Print the prefix inherited from the parent.
    try writer.print("{s}", .{prefix});

    // 2. Print the connector for the current node.
    //    - Use "└──" if it's the last child.
    //    - Use "├──" otherwise.
    const connector = if (is_last) "└── " else "├── ";
    try writer.print("{s}", .{connector});

    // 3. Print the node's own data.
    try writer.print("{s} {any}\n", .{ node.uuid, node.dirty });

    // 4. Prepare the prefix for the *children* of this node.
    //    - If this node was the last one, the connection from its parent is done, so we use a space.
    //    - Otherwise, the connection continues, so we use a vertical bar "│".
    var child_prefix_buffer: [1024]u8 = undefined; // Adjust size if needed
    const new_prefix = try std.fmt.bufPrint(&child_prefix_buffer, "{s}{s}", .{
        prefix,
        if (is_last) "    " else "│   ",
    });

    // 5. Recurse for all children using the new prefix.
    for (node.children.items, 0..) |child, i| {
        const child_is_last = (i == node.children.items.len - 1);
        try self.printNode(writer, child, new_prefix, child_is_last);
    }
}

test "PureTree" {
    var allocator = std.heap.page_allocator;
    const ui_tree = UINode.init(null, .Box, &allocator) catch unreachable;
    ui_tree.uuid = "root";

    var pure_tree: PureTree = undefined;
    try pure_tree.init(ui_tree, &allocator);

    // inserting nodes
    const pure_node_1 = try pure_tree.createNode(ui_tree);
    pure_node_1.uuid = "1";
    try pure_tree.openNode(pure_node_1);
    try std.testing.expectEqualDeep(pure_node_1, pure_tree.popStack());

    const pure_node_2 = try pure_tree.createNode(ui_tree);
    pure_node_2.uuid = "2";
    try pure_tree.openNode(pure_node_2);

    const pure_node_3 = try pure_tree.createNode(ui_tree);
    pure_node_3.uuid = "3";
    try pure_tree.openNode(pure_node_3);
    try std.testing.expectEqualDeep(pure_node_3, pure_tree.popStack());
    try std.testing.expectEqualDeep(pure_node_2, pure_tree.popStack());

    const pure_node_4 = try pure_tree.createNode(ui_tree);
    pure_node_4.uuid = "4";
    try pure_tree.openNode(pure_node_4);

    const pure_node_5 = try pure_tree.createNode(ui_tree);
    pure_node_5.uuid = "5";
    try pure_tree.openNode(pure_node_5);

    const pure_node_6 = try pure_tree.createNode(ui_tree);
    pure_node_6.uuid = "6";
    try pure_tree.openNode(pure_node_6);

    try std.testing.expectEqualDeep(pure_node_6, pure_tree.popStack());
    try std.testing.expectEqualDeep(pure_node_5, pure_tree.popStack());

    const pure_node_7 = try pure_tree.createNode(ui_tree);
    pure_node_7.uuid = "7";
    try pure_tree.openNode(pure_node_7);

    try std.testing.expectEqualDeep(pure_node_7, pure_tree.popStack());
    try std.testing.expectEqualDeep(pure_node_4, pure_tree.popStack());
    try std.testing.expectEqualDeep(pure_tree.root, pure_tree.popStack());
    // testing traversal
    try pure_tree.printTree();
}
