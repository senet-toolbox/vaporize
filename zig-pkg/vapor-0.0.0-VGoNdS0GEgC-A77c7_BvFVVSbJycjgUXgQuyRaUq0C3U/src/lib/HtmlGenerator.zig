const std = @import("std");

const Vapor = @import("Vapor.zig");

const UINode = @import("UITree.zig").UINode;

const utils = @import("utils.zig");

const hashKey = utils.hashKey;

const println = Vapor.println;

var writer: *std.Io.Writer = undefined;

pub fn generate(root: *UINode, new_writer: *std.Io.Writer, style_path: []const u8) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("Failed to deinit gpa");
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    const allocator = arena.allocator();
    defer arena.deinit();
    writer = new_writer;
    const html_template = std.fs.cwd().readFileAlloc(allocator, "template.html", 0x100000) catch unreachable;

    // Write everything before the head
    const head_target = "</head>";
    const start = std.mem.indexOf(u8, html_template, head_target) orelse unreachable;
    writer.writeAll(html_template[0..start]) catch unreachable;
    const style_link = std.fmt.allocPrint(allocator, "  <link rel=\"stylesheet\" href=\"/{s}\" />", .{style_path}) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        unreachable;
    };
    // Write the style link
    writer.writeAll(style_link) catch unreachable;
    writer.writeAll("\n</head>") catch unreachable;

    // Find the contents div
    const target = "<div id=\"contents\" style=\"display: contents\">";
    var end = std.mem.indexOf(u8, html_template, target) orelse unreachable;
    end += target.len;

    // Write everything after the head
    writer.writeAll(html_template[start..end]) catch unreachable;
    if (root.children) |children| {
        for (children.items) |child| {
            createHtmlTree(child);
        }
    }
    writer.writeAll("</div>\n</body>\n</html>") catch unreachable;
}

/// Writes an optional HTML attribute if the value is not null.
fn writeOptionalProp(name: []const u8, value: ?[]const u8) void {
    if (value) |v| {
        _ = writer.write(name) catch unreachable;
        _ = writer.write("=\"") catch unreachable;
        _ = writer.write(v) catch unreachable; // TODO: Escape attribute value
        _ = writer.write("\"") catch unreachable;
    }
}

/// Writes all common HTML attributes from the UINode.
fn writeAllProps(ui_node: *UINode) void {
    // Write mandatory ID
    _ = writer.write(" ") catch unreachable;
    _ = writer.write(" id=\"") catch unreachable;
    _ = writer.write(ui_node.uuid) catch unreachable;
    _ = writer.write("\"") catch unreachable;

    // Write optional props
    writeOptionalProp(" class", ui_node.class);
    writeOptionalProp(" aria-label", ui_node.aria_label);
    if (ui_node.type != .Graphic) {
        if (ui_node.type == .Image) {
            writeOptionalProp(" src", ui_node.href);
        } else {
            writeOptionalProp(" href", ui_node.href);
        }
    }

    // TODO: Add other attributes as needed, e.g., 'src' for 'video'
}

pub fn createDivOpen(ui_node: *UINode) void {
    _ = writer.write("<div") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}

pub fn createDivClose() void {
    _ = writer.write("</div>") catch unreachable;
}

pub fn createButtonOpen(ui_node: *UINode) void {
    _ = writer.write("<button") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}

pub fn createButtonClose() void {
    _ = writer.write("</button>") catch unreachable;
}

pub fn createParagraph(ui_node: *UINode) void {
    _ = writer.write("<p") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
    _ = writer.write("</p>") catch unreachable;
}

pub fn createField(ui_node: *UINode) void {
    _ = writer.write("<p") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
    _ = writer.write("</p>") catch unreachable;
}

pub fn createLinkOpen(ui_node: *UINode) void {
    _ = writer.write("<a") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createLinkClose() void {
    _ = writer.write("</a>") catch unreachable;
}

pub fn createIconOpen(ui_node: *UINode) void {
    _ = writer.write("<i") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createIconClose() void {
    _ = writer.write("</i>") catch unreachable;
}

pub fn createImageOpen(ui_node: *UINode) void {
    _ = writer.write("<img") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createImageClose() void {
    _ = writer.write("</img>") catch unreachable;
}

pub fn createGraphicOpen(ui_node: *UINode) void {
    _ = writer.write("<div") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createGraphicClose() void {
    _ = writer.write("</div>") catch unreachable;
}

pub fn createListOpen(ui_node: *UINode) void {
    _ = writer.write("<ul") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}

pub fn createListItemClose() void {
    _ = writer.write("</li>") catch unreachable;
}

pub fn createListItemOpen(ui_node: *UINode) void {
    _ = writer.write("<li") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write("\">") catch unreachable;
}
pub fn createListClose() void {
    _ = writer.write("</ul>") catch unreachable;
}

pub fn createSectionOpen(ui_node: *UINode) void {
    _ = writer.write("<section") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
}
pub fn createSectionClose() void {
    _ = writer.write("</section>") catch unreachable;
}

pub fn createCodeOpen(ui_node: *UINode) void {
    _ = writer.write("<code") catch unreachable;
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
}
pub fn createCodeClose() void {
    _ = writer.write("</code>") catch unreachable;
}

pub fn createHeadingOpen(ui_node: *UINode) void {
    _ = writer.write("<h") catch unreachable;
    if (ui_node.level) |level| {
        // Write the slice to the file
        _ = writer.print("{any}", .{level}) catch unreachable;
    }
    writeAllProps(ui_node);
    _ = writer.write(">") catch unreachable;
    if (ui_node.text) |text| {
        _ = writer.write(text) catch unreachable; // TODO: Escape HTML content
    }
}
pub fn createHeadingClose() void {
    _ = writer.write("</h>") catch unreachable;
}

pub fn createElementOpen(ui_node: *UINode) void {
    switch (ui_node.type) {
        .FlexBox => {
            createDivOpen(ui_node);
        },

        .Text => {
            createParagraph(ui_node);
        },
        .Icon => {
            createIconOpen(ui_node);
        },
        .TextFmt => {
            createField(ui_node);
        },

        .Button, .CtxButton, .ButtonCycle => {
            createButtonOpen(ui_node);
        },
        // Assuming EType.Link exists for nodes with 'href'
        .Link, .RedirectLink => {
            createLinkOpen(ui_node);
        },

        .Image => {
            createImageOpen(ui_node);
        },

        .HtmlText => {
            createParagraph(ui_node);
        },

        .List => {
            createListOpen(ui_node);
        },

        .ListItem => {
            createListItemOpen(ui_node);
        },

        .Graphic => {
            createGraphicOpen(ui_node);
        },

        .Intersection => {
            createSectionOpen(ui_node);
        },

        .Code => {
            createCodeOpen(ui_node);
        },
        .Heading => {
            createHeadingOpen(ui_node);
        },

        else => {
            // createDivOpen(ui_node);
        },
    }
}

pub fn createElementClose(ui_node: *UINode) void {
    switch (ui_node.type) {
        .FlexBox => {
            createDivClose();
        },

        .Button, .CtxButton, .ButtonCycle => {
            createButtonClose();
        },
        // Assuming EType.Link exists
        .Link, .RedirectLink => {
            createLinkClose();
        },

        .Icon => {
            createIconClose();
        },

        .Image => {
            createImageClose();
        },

        .Graphic => {
            createGraphicClose();
        },

        .List => {
            createListClose();
        },

        .ListItem => {
            createListItemClose();
        },

        .Intersection => {
            createSectionClose();
        },

        .Code => {
            createCodeClose();
        },
        .Heading => {
            createHeadingClose();
        },
        else => {
            // createDivClose();
        },
    }
}

pub fn createHtmlTree(node: *UINode) void {
    // println("UI: {s}\n", .{node.uuid});
    createElementOpen(node);

    // If node type is NOT .Text (which handles its own text)
    // and it HAS text, write it as content.
    // This is for <button>Text</button> or <a>Text</a>
    _ = writer.write("\n") catch unreachable;
    if (node.children) |children| {
        for (children.items) |child| {
            createHtmlTree(child);
        }
    }

    // Only call close for non-atomic elements
    if (node.type != .Text) {
        createElementClose(node);
        _ = writer.write("\n") catch unreachable;
    }
}

