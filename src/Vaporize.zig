const std = @import("std");
const Vapor = @import("vapor");
const Allocator = std.mem.Allocator;
const Text = Vapor.Text;
const Box = Vapor.Box;
const Heading = Vapor.Heading;
const List = Vapor.List;
const ListItem = Vapor.ListItem;
const Code = Vapor.Code;
const Graphic = Vapor.Graphic;
const Image = Vapor.Image;
const RedirectLink = Vapor.RedirectLink;
const Stack = Vapor.Stack;
const Center = Vapor.Center;
const Section = Vapor.Section;
const SyntaxHighlighter = @import("ZigParser.zig").SyntaxHighlighter;
const Snippet = @import("Snippet.zig");
const ListStyle = Vapor.Types.ListStyle;
const Button = Vapor.Button;
const TextField = Vapor.TextField;
const Label = Vapor.Label;
const FormComponent = Vapor.Form;
const SubmitButton = Vapor.SubmitButton;
const FormParser = @import("Form.zig");
const ValidationResult = FormParser.ValidationResult;
const ValidationError = FormParser.ValidationError;
pub const Form = FormParser.Form;
pub const Field = @import("Field.zig");
const DefaultValue = Field.DefaultValue;
const Switch = @import("Switch.zig");
pub const generateForm = @import("Form.zig").generateForm;
const Tooltip = @import("Tooltip.zig");
const TextArea = @import("TextArea.zig");

// Internal storage uses anyopaque
const CallbackEntry = struct {
    func: *const fn (*anyopaque) void,
    ctx: *anyopaque,
};

pub fn Condition(comptime T: type) type {
    return struct {
        callback: ?*const fn (*T) void = null,
        value: bool = false,
        target_field: ?[]const u8 = null,

        // Internal: erases for storage
        pub fn erased(self: *@This()) CallbackEntry {
            return .{
                .func = @ptrCast(self.callback),
                .ctx = undefined, // or whatever context you need
            };
        }
    };
}

// Your framework internally does this (once, hidden from user)
pub fn invokeCallback(entry: CallbackEntry, form_ptr: *anyopaque) void {
    entry.func(form_ptr);
}

/// ## The Abstract Syntax Tree (AST)
///
/// This defines the structure of our parsed Markdown.
/// Each element (Heading, Paragraph, Text) becomes a Node.
/// Defines what kind of Markdown element a Node represents.
pub const NodeType = enum {
    Root,
    Heading,
    Paragraph,
    Text,
    Bold, // Added
    Italic, // Added
    Code, // Added
    List, // <-- NEW
    ListItem, // <-- NEW
    Svg, // <-- NEW
    Image, // <-- NEW
    CodeBlock,
    Section,
    RunBlock,
    Snippet,
    Link,
    Box,
    Button,
    TextField,
    Form,
    Table, // <-- NEW
    TableRow, // <-- NEW
    TableCell, // <-- NEW
    Dropdown,
    FormSection,
    Switch,
    BlockQuote,
    HorizontalRule,
    TextArea,
    RightAligned,
    StyledContainer,
};

// // Enum definition for CSS list-style-type property
// pub const ListStyle = enum(u8) {
//     default,
//     none, // No bullet or marker
//     disc, // Filled circle (default for unordered lists)
//     circle, // Open circle
//     square, // Square marker
//     decimal, // Decimal numbers (default for ordered lists)
//     decimal_leading_zero, // Decimal numbers with a leading zero (e.g. 01, 02, 03, ...)
//     lower_roman, // Lowercase roman numerals (i, ii, iii, ...)
//     upper_roman, // Uppercase roman numerals (I, II, III, ...)
//     lower_alpha, // Lowercase alphabetic (a, b, c, ...)
//     upper_alpha, // Uppercase alphabetic (A, B, C, ...)
//     lower_greek, // Lowercase Greek letters (α, β, γ, ...)
//     armenian, // Armenian numbering
//     georgian, // Georgian numbering
//     inherit, // Inherits from parent element
//     initial, // Resets to the default value
//     revert, // Reverts to the inherited value if explicitly changed
//     unset, // Resets to inherited or initial value
// };
//
/// --- NEW: Recursive List Parsing ---
const ListMarker = enum { @"-", @"*", @"+" };
const UnorderedMarker = enum { @"-", @"*", @"+" };
// Represents a detected ordered list marker
const OrderedMarkerInfo = struct {
    style: ListStyle, // .decimal, .lower_alpha, etc.
    delimiter: u8, // '.' or ')'
};

// A marker is a "sum type" or "tagged union".
// It can be EITHER Unordered OR Ordered.
const Marker = union(enum) {
    Unordered: UnorderedMarker,
    Ordered: OrderedMarkerInfo,
};

// The LineInfo struct is updated to use the new Marker union
const LineInfo = struct {
    indent: usize,
    marker: ?Marker = null, // null if not a list item
    content_start_pos: usize, // absolute position in self.source
};
/// A single node in the AST.
/// We use a first-child/next-sibling structure for efficiency.
pub const Node = struct {
    tag: NodeType,

    // Type-specific data.
    // Using a union saves memory.
    data: union {
        heading: struct {
            level: u8,
        },
        text: struct {
            content: []const u8, // A slice of the *original* source text
        },
        code: struct {
            content: []const u8,
        },
        image: struct {
            alt_text: []const u8,
            src: []const u8,
        },
        code_block: struct {
            editor: *SyntaxHighlighter,
            content: []const u8,
            language: ?[]const u8,
        },
        snippet: struct {
            content: []const u8,
            ptr: *Snippet,
        },
        section: struct {
            id: []const u8,
        },
        run_block: struct {
            src: []const u8,
        },
        link: struct {
            href: []const u8,
            title: []const u8,
        },
        list: struct {
            list_type: ListStyle,
        },
        button: struct {
            text: []const u8,
            on_click: ?*const fn () void,
        },
        textfield: struct {
            title: []const u8,
            type: FormParser.FieldType = .string,
            err: ?*ValidationResult = null,
            err_index: usize = 0,
            config: Vapor.Types.TextFieldConfig = .{},
            default_value: ?DefaultValue = null,
            placeholder: ?DefaultValue = null,
        },
        textarea: struct {
            title: []const u8,
            err: ?*ValidationResult = null,
            err_index: usize = 0,
        },
        formsection: struct {
            title: []const u8,
        },
        dropdown: struct {
            title: []const u8,
            show: bool = false,
            tags: []const []const u8 = &.{},
            err: ?*ValidationResult = null,
        },
        table: struct {
            column_count: usize,
            has_header: bool,
        },
        table_row: struct {
            is_header: bool,
        },
        table_cell: struct {
            first_column: bool = false,
            is_header: bool,
            alignment: TableAlignment,
        },
        toggle: struct {
            title: []const u8,
            condition: *anyopaque,
        },
        block_quote: struct {
            content: []const u8,
        },
        right_aligned: struct {
            content: []const u8,
        },
        styled_container: struct {
            style_class: []const u8, // "accent", "success", "warning", "user", "assistant"
        },
        none: void,
    },

    child: ?*Node, // Pointer to the first child node
    next: ?*Node, // Pointer to the next sibling node
};

// Add alignment enum
pub const TableAlignment = enum {
    left,
    center,
    right,
    default,
};

const Item = struct {
    ptr: ?*Node,
    next: ?*Item = null,
};

pub const Self = @This();
var did_init: bool = false;
allocator: ?Allocator = null,
root: *Node,
style_config: StyleConfig = .{},

pub fn initAnimations() void {
    Field.new();
    TextArea.new();
    Switch.new();
    Tooltip.new();
    Tooltip.background = .palette(.danger);
    Tooltip.alternate_text_color = .white;
    Tooltip.alternate_background = .palette(.danger);
    Tooltip.svg_color = .palette(.danger);

    Vapor.injectCSS(
        \\ input[type="radio"] {
        \\   appearance: none;
        \\   -webkit-appearance: none;
        \\   width: 18px;
        \\   height: 18px;
        \\   border: 1px solid #ccc;
        \\   border-radius: 50%;
        \\   cursor: pointer;
        \\   position: relative;
        \\   transition: border-color 0.2s;
        \\ }
        \\ input[type="radio"]::after {
        \\   content: "";
        \\   position: absolute;
        \\   width: 8px;
        \\   height: 8px;
        \\   background: rgba(var(--tint));
        \\   border-radius: 50%;
        \\   top: 50%;
        \\   left: 50%;
        \\   transform: translate(-50%, -50%) scale(0);
        \\   transition: transform 0.15s ease;
        \\ }
        \\ input[type="radio"]:checked {
        \\   border-color: rgba(var(--tint));
        \\ }
        \\ input[type="radio"]:checked::after {
        \\   transform: translate(-50%, -50%) scale(1);
        \\ }
        \\ input[type="radio"]:hover {
        \\   border-color: rgba(var(--tint));
        \\ }
    );
}

pub fn init(allocator: Allocator, style_config: StyleConfig) !Self {
    if (!did_init) {
        initAnimations();
        global_style = style_config;
        did_init = true;
    }
    const root = allocator.create(Node) catch |err| {
        Vapor.printErr("Could Not create Root Node", .{});
        return err;
    };
    root.* = .{
        .tag = .Root,
        .data = .{ .none = {} }, // Default to none
        .child = null,
        .next = null,
    };
    return Self{
        .allocator = allocator,
        .root = root,
        .style_config = style_config,
    };
}

/// Helper to create a new Node using the arena.
pub fn createNode(self: *Self, tag: NodeType) !*Node {
    const allocator = self.allocator orelse return error.AllocatorNotFound;
    const node = try allocator.create(Node);
    node.* = .{
        .tag = tag,
        .data = .{ .none = {} }, // Default to none
        .child = null,
        .next = null,
    };
    return node;
}

/// ## The Parser
///
/// This struct holds the state of the parsing process.
/// It uses an ArenaAllocator for all Node allocations.
pub const Parser = struct {
    arena: Allocator, // The parent allocator (e.g., GPA)
    source: []const u8,
    pos: usize,
    stack: ?*Item = null,

    /// Initializes a new parser with a given allocator and source text.
    pub fn init(allocator: Allocator, source: []const u8) Parser {
        const node = allocator.create(Node) catch unreachable;
        node.* = .{
            .tag = .Root,
            .data = .{ .none = {} }, // Default to none
            .child = null,
            .next = null,
        };
        const item = allocator.create(Item) catch unreachable;
        item.* = .{
            .ptr = node,
            .next = null,
        };
        return Parser{
            .arena = allocator, // Get the allocator interface
            .source = source,
            .pos = 0,
            .stack = item,
        };
    }

    /// Helper to create a new Node using the arena.
    fn createNode(self: *Parser, tag: NodeType) !*Node {
        const node = try self.arena.create(Node);
        node.* = .{
            .tag = tag,
            .data = .{ .none = {} }, // Default to none
            .child = null,
            .next = null,
        };
        try self.stackRegister(node);
        return node;
    }

    pub fn stackRegister(parser: *Parser, node: *Node) !void {
        const item: *Item = try parser.arena.create(Item);
        item.* = .{ .ptr = node };

        const current_stack = parser.stack;
        if (current_stack) |stack| {
            item.next = stack;
        }

        parser.stack = item;
    }

    pub fn stackPop(parser: *Parser) void {
        const current_stack = parser.stack orelse return;
        parser.stack = current_stack.next;
    }

    /// --- Parsing Logic ---
    /// The main parsing function. Returns the Root node of the AST.
    pub fn parse(parser: *Parser) !*Node {
        const stack = parser.stack orelse return error.StackEmpty;
        const root = stack.ptr orelse return error.StackEmpty;
        var last_section: ?*Node = null;

        while (!parser.isAtEnd()) {
            parser.skipBlankLines();
            if (parser.isAtEnd()) break;

            const block = try parser.parseBlock();

            switch (block.tag) {
                .Section => {
                    // New section begins
                    if (last_section) |section| {
                        section.next = block;
                    } else {
                        root.child = block;
                    }
                    last_section = block;
                },
                else => {
                    // Add block to current section (or root if no section yet)
                    const parent = last_section orelse root;
                    parser.attachChild(parent, block);
                },
            }
        }

        return root;
    }

    /// Attaches `child` to the end of `parent`'s child list.
    fn attachChild(_: *Parser, parent: *Node, child: *Node) void {
        if (parent.child) |first| {
            var last = first;
            while (last.next) |next| {
                last = next;
            }
            last.next = child;
        } else {
            parent.child = child;
        }
    }

    /// Dispatches to the correct block parser based on the current char.
    fn parseBlock(self: *Parser) anyerror!*Node {
        // --- MODIFIED ---
        if (self.isListItemStart()) {
            return try self.parseList(0);
        }
        // --- END MODIFICATION ---

        // Check for table
        if (self.isTableStart()) {
            return try self.parseTable();
        }

        const char = self.peek();
        switch (char) {
            '{' => return self.parseSection(),
            '#' => return self.parseHeading(),
            '%' => return self.parseSnippet(),
            // The '-', '*', '+' case is now handled above
            '-', '*', '+' => {
                // MODIFIED:
                if (self.isListItemStart()) return try self.parseList(0);
                return self.parseParagraph();
                // },
            },
            '`' => {
                // Detect fenced code block (```lang)
                if (self.matchCodeFence()) return self.parseCodeBlock();
                return self.parseParagraph();
            },
            '@' => {
                // Detect fenced code block (```lang)
                _ = self.advance();
                return self.parseRunBlock();
            },
            // '>' => {
            //     _ = self.advance();
            //     return self.parseBlockQuote();
            // },
            '>' => {
                // Check for right-alignment: >>>
                if (self.pos + 2 < self.source.len and
                    self.source[self.pos + 1] == '>' and
                    self.source[self.pos + 2] == '>')
                {
                    _ = self.advance(); // >
                    _ = self.advance(); // >
                    _ = self.advance(); // >
                    return self.parseRightAligned();
                }
                // Existing blockquote
                _ = self.advance();
                return self.parseBlockQuote();
            },
            ':' => {
                if (self.matchContainerFence()) {
                    return self.parseStyledContainer();
                }
                return self.parseParagraph();
            },

            else => return self.parseParagraph(),
        }
    }

    fn parseRightAligned(self: *Parser) !*Node {
        // Skip leading space
        if (!self.isAtEnd() and self.peek() == ' ') _ = self.advance();

        const node = try self.createNode(.RightAligned);
        const content = self.consumeSingleLine();
        try self.parseInlines(node, content);
        return node;
    }

    fn matchContainerFence(self: *Parser) bool {
        return self.pos + 2 < self.source.len and
            self.source[self.pos] == ':' and
            self.source[self.pos + 1] == ':' and
            self.source[self.pos + 2] == ':';
    }

    fn parseStyledContainer(self: *Parser) !*Node {
        // Consume opening :::
        _ = self.advance();
        _ = self.advance();
        _ = self.advance();

        // Read style class (e.g., "accent", "user", "assistant")
        if (!self.isAtEnd() and self.peek() == ' ') _ = self.advance();
        const class_start = self.pos;
        while (!self.isAtEnd() and self.peek() != '\n') _ = self.advance();
        const style_class = std.mem.trim(u8, self.source[class_start..self.pos], " \t");

        if (!self.isAtEnd()) _ = self.advance(); // skip newline

        const node = try self.createNode(.StyledContainer);
        node.data = .{ .styled_container = .{ .style_class = style_class } };

        // Parse inner blocks until closing :::
        var last_child: ?*Node = null;
        while (!self.isAtEnd()) {
            self.skipBlankLines();
            if (self.isAtEnd()) break;
            if (self.matchContainerFence()) {
                // Consume closing :::
                _ = self.advance();
                _ = self.advance();
                _ = self.advance();
                // Skip rest of line
                while (!self.isAtEnd() and self.peek() != '\n') _ = self.advance();
                if (!self.isAtEnd()) _ = self.advance();
                break;
            }
            const block = try self.parseBlock();
            if (last_child) |last| {
                last.next = block;
            } else {
                node.child = block;
            }
            last_child = block;
        }

        return node;
    }

    fn parseBlockQuote(self: *Parser) !*Node {
        const line_start = self.pos;
        self.consumeLine(); // Advance pos to the end of the line
        const line_end = self.pos;

        // Get the content slice
        const content = std.mem.trim(u8, self.source[line_start..line_end], " \t");

        // Create the BlockQuote node
        const node = try self.createNode(.BlockQuote);

        // --- MODIFIED ---
        // Instead of creating one text node, parse the inlines
        try self.parseInlines(node, content);
        // ----------------

        return node;
    }

    fn parseRunBlock(self: *Parser) !*Node {
        // Capture optional language
        const lang_start = self.pos;
        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }
        const lang_end = self.pos;
        const src = std.mem.trim(u8, self.source[lang_start..lang_end], " \t");

        // Create CodeBlock node
        const node = try self.createNode(.RunBlock);
        node.data = .{ .run_block = .{
            .src = src,
        } };

        return node;
    }

    fn parseCodeBlock(self: *Parser) !*Node {
        // Consume the opening ```
        _ = self.advance();
        _ = self.advance();
        _ = self.advance();

        // Capture optional language
        const lang_start = self.pos;
        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }
        const lang_end = self.pos;
        const language = std.mem.trim(u8, self.source[lang_start..lang_end], " \t");

        // Skip newline
        if (self.peek() == '\n') _ = self.advance();

        const code_start = self.pos;

        // Find closing ```
        while (!self.isAtEnd()) {
            if (self.matchCodeFence()) break;
            _ = self.advance();
        }

        const code_end = self.pos;
        const raw_content = self.source[code_start..code_end];

        // Process escape sequences
        const code_content = try self.processEscapes(raw_content);

        // Consume closing fence
        if (self.matchCodeFence()) {
            _ = self.advance();
            _ = self.advance();
            _ = self.advance();
        }

        // Create CodeBlock node
        const node = try self.createNode(.CodeBlock);
        const editor: *SyntaxHighlighter = self.arena.create(SyntaxHighlighter) catch unreachable;
        editor.* = .init(self.arena);
        editor.scrolling_enabled = true;
        editor.parse(code_content) catch unreachable;
        node.data = .{
            .code_block = .{
                .editor = editor,
                .content = code_content,
                .language = if (language.len > 0) language else null,
            },
        };

        return node;
    }
    fn matchCodeFence(self: *Parser) bool {
        // Check for three backticks at current position
        return self.pos + 2 < self.source.len and
            self.source[self.pos] == '`' and
            self.source[self.pos + 1] == '`' and
            self.source[self.pos + 2] == '`';
    }

    /// Consumes characters until a single newline or EOF is reached.
    /// Returns the content slice *without* the newline.
    /// Advances parser *past* the newline if found.
    fn consumeSingleLine(self: *Parser) []const u8 {
        const line_start = self.pos;

        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }

        const line_end = self.pos;

        // Skip the newline itself
        if (!self.isAtEnd() and self.peek() == '\n') {
            _ = self.advance();
        }

        return std.mem.trim(u8, self.source[line_start..line_end], " \t");
    }

    fn parseSection(self: *Parser) !*Node {
        while (self.peek() != '#') {
            _ = self.advance();
        }
        _ = self.advance();
        const content = self.consumeSingleLine();

        // Create the Section node
        const node = try self.createNode(.Section);
        node.data = .{ .section = .{ .id = content[0 .. content.len - 1] } };

        // 3. Link the new block into the Root's child list
        return node;
    }

    /// Parses a heading, e.g., "## My Title"
    fn parseSnippet(self: *Parser) !*Node {
        _ = self.advance();

        const content = self.consumeSingleLine();
        // Create the Snippet node
        const snippet = self.arena.create(Snippet) catch unreachable;
        snippet.init();
        const node = try self.createNode(.Snippet);
        node.data = .{
            .snippet = .{
                .content = content,
                .ptr = snippet,
            },
        };
        return node;
    }

    /// Parses a heading, e.g., "## My Title"
    fn parseHeading(self: *Parser) !*Node {
        var level: u8 = 0;
        while (self.peek() == '#') {
            _ = self.advance();
            level += 1;
        }

        // Skip the space after the '#'
        if (self.peek() == ' ') {
            _ = self.advance();
        }

        const content = self.consumeSingleLine();

        // Create the Heading node
        const node = try self.createNode(.Heading);
        node.data = .{ .heading = .{ .level = level } };

        // --- MODIFIED ---
        // Instead of creating one text node, parse the inlines
        try self.parseInlines(node, content);
        // ----------------

        return node;
    }

    /// Parses a simple, single-line paragraph.
    fn parseParagraph(self: *Parser) !*Node {
        const line_start = self.pos;
        self.consumeLine(); // Advance pos to the end of the line
        const line_end = self.pos;
        // Get the content slice
        const raw_content = std.mem.trim(u8, self.source[line_start..line_end], " \t");

        if (std.mem.eql(u8, raw_content, "---")) {
            const node = try self.createNode(.HorizontalRule);
            return node;
        }

        // Process escape sequences
        const content = try self.processEscapes(raw_content);

        // Create the Paragraph node
        const node = try self.createNode(.Paragraph);
        // --- MODIFIED ---
        // Instead of creating one text node, parse the inlines
        try self.parseInlines(node, content);
        // ----------------
        return node;
    }

    /// Processes backslash escape sequences in content.
    /// For example, \| becomes |, \\ becomes \
    fn processEscapes(self: *Parser, input: []const u8) ![]const u8 {
        // Quick check: if no backslashes, return as-is
        if (std.mem.indexOfScalar(u8, input, '\\') == null) {
            return input;
        }

        var buffer = std.array_list.Managed(u8).init(self.arena);

        var i: usize = 0;
        while (i < input.len) {
            const char = input[i];

            if (char == '\\' and i + 1 < input.len) {
                // Skip the backslash and add the next character directly
                i += 1;
                try buffer.append(input[i]);
            } else {
                try buffer.append(char);
            }

            i += 1;
        }

        return buffer.items;
    }
    /// Helper to get indentation and list marker info for the current line.
    fn getLineInfo(self: *const Parser) LineInfo {
        var indent: usize = 0;
        var i = self.pos;

        // 1. Calculate indentation (supports spaces and tabs)
        while (i < self.source.len) {
            const char = self.source[i];
            if (char == ' ') {
                indent += 1;
                i += 1;
            } else if (char == '\t') {
                // Treat a tab as expanding to the next 4-space stop
                indent = (indent / 4 + 1) * 4;
                i += 1;
            } else {
                break;
            }
        }

        const content_start_idx = i;

        // 2. Check for Unordered Markers ('-', '*', '+')
        if (content_start_idx + 1 < self.source.len and self.source[content_start_idx + 1] == ' ') {
            const marker_char = self.source[content_start_idx];
            const marker: ?UnorderedMarker = switch (marker_char) {
                '-' => .@"-",
                '*' => .@"*",
                '+' => .@"+",
                else => null,
            };

            if (marker) |m| {
                return .{
                    .indent = indent,
                    .marker = .{ .Unordered = m },
                    .content_start_pos = content_start_idx + 2, // Skip marker and space
                };
            }
        }

        // 3. Check for Ordered Markers (e.g., "1.", "a.", "I)")
        var marker_end = content_start_idx;
        while (marker_end < self.source.len and
            std.ascii.isAlphanumeric(self.source[marker_end]))
        {
            marker_end += 1;
        }

        if (marker_end > content_start_idx and // found an alphanumeric part
            marker_end + 1 < self.source.len and // has room for delim + space
            (self.source[marker_end] == '.' or self.source[marker_end] == ')') and
            self.source[marker_end + 1] == ' ')
        {
            // We have a valid ordered marker, e.g., "1." or "a."
            const delim_char = self.source[marker_end];
            const marker_content = self.source[content_start_idx..marker_end];

            // Now, determine style
            var style: ListStyle = .decimal; // Default
            var all_digits = true;
            for (marker_content) |c| {
                if (!std.ascii.isDigit(c)) all_digits = false;
            }

            if (all_digits) {
                style = .decimal;
            } else if (marker_content.len == 1) {
                const char = marker_content[0];
                if (char == 'i') style = .lower_roman else if (char == 'I') style = .upper_roman else if (std.ascii.isLower(char)) style = .lower_alpha else if (std.ascii.isUpper(char)) style = .upper_alpha else style = .decimal; // Failsafe
            } else {
                // Not a simple case (e.g., "iv.", "ab.").
                // For this parser, we'll just base it on the first char.
                const char = marker_content[0];
                if (std.ascii.isLower(char)) style = .lower_alpha else if (std.ascii.isUpper(char)) style = .upper_alpha else style = .decimal; // Failsafe
            }

            return .{
                .indent = indent,
                .marker = .{ .Ordered = .{
                    .style = style,
                    .delimiter = delim_char,
                } },
                .content_start_pos = marker_end + 2, // skip delim and space
            };
        }

        // Not a list item
        return .{ .indent = indent, .marker = null, .content_start_pos = content_start_idx };
    }

    /// Checks whether the current position starts a list item.
    fn isListItemStart(self: *const Parser) bool {
        const info = self.getLineInfo();
        // We only check for a marker. parseList will handle indentation.
        return info.marker != null;
    }

    /// Parses an unordered list, recursively handling nested lists.
    /// `min_indent` is the indentation level required to be part of the *current* list.
    fn parseList(self: *Parser, min_indent: usize) !*Node {
        // --- PEEK at the first item to determine list type ---
        const first_line_info = self.getLineInfo();
        const first_marker = first_line_info.marker orelse {
            // This should be impossible if called from parseBlock,
            // but return an empty list node just in case.
            return self.createNode(.List);
        };

        // --- Determine the list style from the *first* item ---
        const list_style: ListStyle = switch (first_marker) {
            .Unordered => |marker| switch (marker) {
                .@"-" => .disc,
                .@"*" => .circle, // Use .circle as you had hardcoded [cite: 106]
                .@"+" => .square,
            },
            .Ordered => |info| info.style,
        };

        const list_node = try self.createNode(.List);
        list_node.data = .{
            .list = .{
                .list_type = list_style, // <-- Set the type dynamically!
            },
        };
        var last_item: ?*Node = null;

        while (!self.isAtEnd()) {
            self.skipBlankLines(); // Skip blank lines between items [cite: 107]
            if (self.isAtEnd()) break;

            const info = self.getLineInfo();

            // Check if this line is a valid list item for this level
            if (info.marker == null or info.indent < min_indent) {
                // Not a list item, or it's de-dented.
                // This means the current list is done. [cite: 109-110]
                break;
            }

            // --- NEW CHECK: Stop if marker type *changes* ---
            // (e.g., from "1." to "-") at the same indent level
            if (info.marker) |current_marker| {
                // Check if both markers are of the same kind (both Unordered or both Ordered)
                const is_same_type = (first_marker == .Unordered and current_marker == .Unordered) or
                    (first_marker == .Ordered and current_marker == .Ordered);

                if (!is_same_type and info.indent == min_indent) {
                    // Same indentation level, but changed from ordered to unordered
                    // or vice-versa. This is a new list.
                    break;
                }
            }
            // --- End New Check ---

            // --- It's a valid item for this list ---

            // 1. Consume the line's content
            self.pos = info.content_start_pos;
            const content = self.consumeSingleLine();

            // 2. Create the ListItem node
            const item_node = try self.createNode(.ListItem);
            try self.parseInlines(item_node, content);

            // 3. Link this item into the list
            if (last_item) |last| {
                last.next = item_node;
            } else {
                list_node.child = item_node;
            }
            last_item = item_node;

            // 4. --- Check for a nested list ---
            // Peek at the *next* line to see if it's a nested list
            if (!self.isAtEnd()) {
                const next_line_info = self.getLineInfo();

                if (next_line_info.marker != null and next_line_info.indent > info.indent) {
                    // The next line is a list item and it's *more* indented.
                    // This means it's a nested list belonging to the *current item*.
                    const nested_list = try self.parseList(next_line_info.indent);

                    // Attach the nested list as a child of the *current item*
                    self.attachChild(item_node, nested_list);
                }
            }
        }
        return list_node;
    }

    /// --- NEW: Inline Parser ---
    ///
    /// This parses the content of a block (like a paragraph)
    /// for inline elements like bold, italic, and code.
    fn parseInlines(self: *Parser, parent: *Node, content: []const u8) !void {
        var cursor: usize = 0;
        var text_start: usize = 0;
        var last_child: ?*Node = null;

        while (cursor < content.len) {
            const char = content[cursor];
            switch (char) {
                '[' => {
                    // Markdown image syntax: ![alt](src)
                    const alt_start = cursor + 1;
                    if (std.mem.indexOf(u8, content[alt_start..], "]")) |alt_end_offset| {
                        const alt_end = alt_start + alt_end_offset;
                        const after_bracket = alt_end + 1;

                        if (after_bracket < content.len and content[after_bracket] == '(') {
                            const src_start = after_bracket + 1;
                            if (std.mem.indexOf(u8, content[src_start..], ")")) |src_end_offset| {
                                const src_end = src_start + src_end_offset;

                                // 1. Flush preceding text
                                if (text_start < cursor) {
                                    const text_node = try self.createNode(.Text);
                                    text_node.data = .{ .text = .{ .content = content[text_start..cursor] } };
                                    if (last_child) |last| last.next = text_node else parent.child = text_node;
                                    last_child = text_node;
                                }

                                // 2. Create Image node
                                var image_node: *Node = undefined;
                                image_node = try self.createNode(.Link);
                                image_node.data = .{
                                    .link = .{
                                        .title = content[alt_start..alt_end],
                                        .href = content[src_start..src_end],
                                    },
                                };
                                if (last_child) |last| last.next = image_node else parent.child = image_node;
                                last_child = image_node;

                                // 3. Advance cursor
                                cursor = src_end + 1;
                                text_start = cursor;
                                continue;
                            }
                        }
                    }

                    cursor += 1; // If not matched, continue as normal
                },

                '!' => {
                    // Markdown image syntax: ![alt](src)
                    if (cursor + 1 < content.len and content[cursor + 1] == '[') {
                        const alt_start = cursor + 2;
                        if (std.mem.indexOf(u8, content[alt_start..], "]")) |alt_end_offset| {
                            const alt_end = alt_start + alt_end_offset;
                            const after_bracket = alt_end + 1;

                            if (after_bracket < content.len and content[after_bracket] == '(') {
                                const src_start = after_bracket + 1;
                                if (std.mem.indexOf(u8, content[src_start..], ")")) |src_end_offset| {
                                    const src_end = src_start + src_end_offset;

                                    // 1. Flush preceding text
                                    if (text_start < cursor) {
                                        const text_node = try self.createNode(.Text);
                                        text_node.data = .{ .text = .{ .content = content[text_start..cursor] } };
                                        if (last_child) |last| last.next = text_node else parent.child = text_node;
                                        last_child = text_node;
                                    }

                                    // 2. Create Image node
                                    const src = content[src_start..src_end];
                                    var image_node: *Node = undefined;
                                    if (std.mem.indexOf(u8, src, ".svg") != null) {
                                        image_node = try self.createNode(.Svg);
                                    } else {
                                        image_node = try self.createNode(.Image);
                                    }
                                    image_node.data = .{
                                        .image = .{
                                            .alt_text = content[alt_start..alt_end],
                                            .src = content[src_start..src_end],
                                        },
                                    };

                                    if (last_child) |last| last.next = image_node else parent.child = image_node;
                                    last_child = image_node;

                                    // 3. Advance cursor
                                    cursor = src_end + 1;
                                    text_start = cursor;
                                    continue;
                                }
                            }
                        }
                    }

                    cursor += 1; // If not matched, continue as normal
                },
                '_' => {
                    // Check for Italic: _
                    if (std.mem.indexOf(u8, content[cursor + 1 ..], "_")) |end_offset| {
                        const inner_start = cursor + 1;
                        const inner_end = cursor + 1 + end_offset;
                        const outer_end = inner_end + 1;

                        // 1. Flush text
                        if (text_start < cursor) {
                            const text_node = try self.createNode(.Text);
                            text_node.data = .{ .text = .{ .content = content[text_start..cursor] } };
                            if (last_child) |last| {
                                last.next = text_node;
                            } else {
                                parent.child = text_node;
                            }
                            last_child = text_node;
                        }

                        // 2. Create Italic node
                        const italic_node = try self.createNode(.Italic);
                        if (last_child) |last| {
                            last.next = italic_node;
                        } else {
                            parent.child = italic_node;
                        }
                        last_child = italic_node;

                        // 3. RECURSE
                        try self.parseInlines(italic_node, content[inner_start..inner_end]);

                        // 4. Move cursor
                        cursor = outer_end;
                        text_start = cursor;
                    } else {
                        // No closing tag
                        cursor += 1;
                    }
                },
                '*' => {
                    if (cursor + 1 < content.len and content[cursor + 1] == '*') {
                        // Found start '**'. Look for end.
                        if (std.mem.indexOf(u8, content[cursor + 2 ..], "**")) |end_offset| {
                            const inner_start = cursor + 2;
                            const inner_end = cursor + 2 + end_offset;
                            const outer_end = inner_end + 2;

                            // 1. Flush any text before this
                            if (text_start < cursor) {
                                const text_node = try self.createNode(.Text);
                                text_node.data = .{ .text = .{ .content = content[text_start..cursor] } };
                                if (last_child) |last| {
                                    last.next = text_node;
                                } else {
                                    parent.child = text_node;
                                }
                                last_child = text_node;
                            }

                            // 2. Create Bold node
                            const bold_node = try self.createNode(.Bold);
                            if (last_child) |last| {
                                last.next = bold_node;
                            } else {
                                parent.child = bold_node;
                            }
                            last_child = bold_node;

                            // 3. RECURSE: Parse inlines *within* the bold tags
                            try self.parseInlines(bold_node, content[inner_start..inner_end]);

                            // 4. Move cursor past
                            cursor = outer_end;
                            text_start = cursor;
                        } else {
                            // No closing tag, treat as text
                            cursor += 1;
                        }
                    } else {
                        // Check for Italic: *
                        if (std.mem.indexOf(u8, content[cursor + 1 ..], "*")) |end_offset| {
                            const inner_start = cursor + 1;
                            const inner_end = cursor + 1 + end_offset;
                            const outer_end = inner_end + 1;

                            // 1. Flush text
                            if (text_start < cursor) {
                                const text_node = try self.createNode(.Text);
                                text_node.data = .{ .text = .{ .content = content[text_start..cursor] } };
                                if (last_child) |last| {
                                    last.next = text_node;
                                } else {
                                    parent.child = text_node;
                                }
                                last_child = text_node;
                            }

                            // 2. Create Italic node
                            const italic_node = try self.createNode(.Italic);
                            if (last_child) |last| {
                                last.next = italic_node;
                            } else {
                                parent.child = italic_node;
                            }
                            last_child = italic_node;

                            // 3. RECURSE
                            try self.parseInlines(italic_node, content[inner_start..inner_end]);

                            // 4. Move cursor
                            cursor = outer_end;
                            text_start = cursor;
                        } else {
                            // No closing tag
                            cursor += 1;
                        }
                    }
                },
                // Check for Code: `
                '`' => {
                    if (std.mem.indexOf(u8, content[cursor + 1 ..], "`")) |end_offset| {
                        const inner_start = cursor + 1;
                        const inner_end = cursor + 1 + end_offset;
                        const outer_end = inner_end + 1;

                        // 1. Flush text
                        if (text_start < cursor) {
                            const text_node = try self.createNode(.Text);
                            text_node.data = .{ .text = .{ .content = content[text_start..cursor] } };
                            if (last_child) |last| {
                                last.next = text_node;
                            } else {
                                parent.child = text_node;
                            }
                            last_child = text_node;
                        }

                        // 2. Process escape sequences in code content
                        const raw_code_content = content[inner_start..inner_end];
                        const code_content = try self.processEscapes(raw_code_content);

                        // 3. Create Code node
                        const code_node = try self.createNode(.Code);
                        code_node.data = .{ .code = .{ .content = code_content } };
                        if (last_child) |last| {
                            last.next = code_node;
                        } else {
                            parent.child = code_node;
                        }
                        last_child = code_node;

                        // 4. NO RECURSION for code blocks.
                        // 5. Move cursor
                        cursor = outer_end;
                        text_start = cursor;
                    } else {
                        // No closing tag
                        cursor += 1;
                    }
                },
                else => {
                    // Regular character
                    cursor += 1;
                },
            }
        }

        // End of loop, flush any remaining text
        if (text_start < content.len) {
            const text_node = try self.createNode(.Text);
            text_node.data = .{ .text = .{ .content = content[text_start..content.len] } };
            if (last_child) |last| {
                last.next = text_node;
            } else {
                parent.child = text_node;
            }
            // _ = last_child; // Not needed anymore
        }
    }

    /// --- Utility Functions ---
    fn isAtEnd(self: *const Parser) bool {
        return self.pos >= self.source.len;
    }

    /// Returns the character at the current position without consuming it.
    fn peek(self: *const Parser) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.pos];
    }

    /// Consumes and returns the character at the current position.
    fn advance(self: *Parser) u8 {
        if (self.isAtEnd()) return 0;
        const char = self.source[self.pos];
        self.pos += 1;
        return char;
    }

    /// Consumes characters until a blank line (`\n\n`) or EOF is reached.
    /// That means it will treat single newlines as part of the same paragraph.
    fn consumeLine(self: *Parser) void {
        while (!self.isAtEnd()) {
            // Stop if we find a blank line: two consecutive newlines
            if (self.peek() == '\n') {
                // Look ahead one character
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '\n') {
                    break; // Double newline -> end of paragraph
                }
            }

            _ = self.advance();
        }
    }

    /// Skips one or more blank lines.
    fn skipBlankLines(self: *Parser) void {
        while (self.peek() == '\n') {
            _ = self.advance();
        }
    }

    /// Checks if current position starts a table (line with | characters)
    fn isTableStart(self: *const Parser) bool {
        var i = self.pos;

        // Skip leading whitespace
        while (i < self.source.len and (self.source[i] == ' ' or self.source[i] == '\t')) {
            i += 1;
        }

        // Check if line starts with | or contains | before newline
        if (i >= self.source.len) return false;

        // Must start with | for valid table (but not \|)
        if (self.source[i] != '|') return false;

        // Scan the line to ensure it has table structure
        var pipe_count: usize = 0;
        while (i < self.source.len and self.source[i] != '\n') {
            // Skip escaped pipes
            if (self.source[i] == '\\' and i + 1 < self.source.len and self.source[i + 1] == '|') {
                i += 2; // Skip both \ and |
                continue;
            }
            if (self.source[i] == '|') pipe_count += 1;
            i += 1;
        }

        // Need at least 2 pipes for a valid table row (|cell| or |cell|cell|)
        return pipe_count >= 2;
    }

    /// Parses a markdown table
    fn parseTable(self: *Parser) !*Node {
        const table_node = try self.createNode(.Table);
        var last_row: ?*Node = null;
        var column_count: usize = 0;
        var has_header = false;
        var alignments: [32]TableAlignment = [_]TableAlignment{.default} ** 32; // Max 32 columns
        var row_index: usize = 0;

        while (!self.isAtEnd()) {
            // Skip blank lines shouldn't happen in middle of table
            if (self.peek() == '\n') {
                _ = self.advance();
                continue;
            }

            // Check if this line is still part of the table
            if (!self.isTableStart()) break;

            // const line_start = self.pos;
            const line_content = self.consumeTableLine();

            // Check if this is the separator row (|---|---|)
            if (self.isSeparatorRow(line_content)) {
                has_header = true;
                // Parse alignments from separator
                self.parseAlignments(line_content, &alignments);

                // Mark previous row as header
                if (last_row) |row| {
                    row.data.table_row.is_header = true;
                    // Update cells to be header cells
                    var cell = row.child;
                    while (cell) |c| {
                        if (c.tag == .TableCell) {
                            c.data.table_cell.is_header = true;
                        }
                        cell = c.next;
                    }
                }
                row_index += 1;
                continue;
            }

            // Parse the row
            const row_node = try self.parseTableRow(line_content, row_index == 0 and !has_header, &alignments);

            // Count columns from first row
            if (column_count == 0) {
                var cell = row_node.child;
                while (cell) |c| {
                    column_count += 1;
                    cell = c.next;
                }
            }

            // Link row to table
            if (last_row) |last| {
                last.next = row_node;
            } else {
                table_node.child = row_node;
            }
            last_row = row_node;
            row_index += 1;
        }

        table_node.data = .{
            .table = .{
                .column_count = column_count,
                .has_header = has_header,
            },
        };

        return table_node;
    }

    /// Consumes a single table line and returns it without the newline
    fn consumeTableLine(self: *Parser) []const u8 {
        const line_start = self.pos;

        while (!self.isAtEnd() and self.peek() != '\n') {
            _ = self.advance();
        }

        const line_end = self.pos;

        // Skip newline
        if (!self.isAtEnd() and self.peek() == '\n') {
            _ = self.advance();
        }

        return std.mem.trim(u8, self.source[line_start..line_end], " \t");
    }

    /// Checks if a line is a separator row (|---|:---:|---:|)
    fn isSeparatorRow(_: *Parser, line: []const u8) bool {
        var has_dashes = false;
        var i: usize = 0;

        while (i < line.len) {
            const char = line[i];

            // Skip escaped characters
            if (char == '\\' and i + 1 < line.len) {
                i += 2;
                continue;
            }

            switch (char) {
                '|', ':', '-', ' ', '\t' => {
                    if (char == '-') has_dashes = true;
                },
                else => return false,
            }
            i += 1;
        }

        return has_dashes;
    }
    /// Parses alignment from separator row
    fn parseAlignments(_: *Parser, line: []const u8, alignments: *[32]TableAlignment) void {
        var col_idx: usize = 0;
        var i: usize = 0;

        // Skip leading |
        if (i < line.len and line[i] == '|') i += 1;

        while (i < line.len and col_idx < 32) {
            // Skip whitespace
            while (i < line.len and (line[i] == ' ' or line[i] == '\t')) i += 1;

            if (i >= line.len) break;

            const cell_start = i;
            var has_left_colon = false;
            var has_right_colon = false;

            // Check for left colon
            if (line[i] == ':') {
                has_left_colon = true;
                i += 1;
            }

            // Skip dashes
            while (i < line.len and line[i] == '-') i += 1;

            // Check for right colon
            if (i < line.len and line[i] == ':') {
                has_right_colon = true;
                i += 1;
            }

            // Skip whitespace
            while (i < line.len and (line[i] == ' ' or line[i] == '\t')) i += 1;

            // Skip pipe
            if (i < line.len and line[i] == '|') i += 1;

            // Only count if we actually had content
            if (i > cell_start) {
                if (has_left_colon and has_right_colon) {
                    alignments[col_idx] = .center;
                } else if (has_right_colon) {
                    alignments[col_idx] = .right;
                } else if (has_left_colon) {
                    alignments[col_idx] = .left;
                } else {
                    alignments[col_idx] = .default;
                }
                col_idx += 1;
            }
        }
    }

    /// Parses a single table row
    fn parseTableRow(self: *Parser, line: []const u8, is_potential_header: bool, alignments: *[32]TableAlignment) !*Node {
        const row_node = try self.createNode(.TableRow);
        row_node.data = .{
            .table_row = .{
                .is_header = false, // Will be set later if separator follows
            },
        };

        var last_cell: ?*Node = null;
        var col_idx: usize = 0;
        var i: usize = 0;

        // Skip leading |
        if (i < line.len and line[i] == '|') i += 1;

        while (i < line.len and col_idx < 32) {
            const cell_start = i;

            // Find end of cell (next unescaped | or end of line)
            while (i < line.len) {
                // Check for escaped pipe - skip it
                if (line[i] == '\\' and i + 1 < line.len and line[i + 1] == '|') {
                    i += 2; // Skip both \ and |
                    continue;
                }
                // Unescaped pipe = end of cell
                if (line[i] == '|') break;
                i += 1;
            }

            const raw_cell_content = std.mem.trim(u8, line[cell_start..i], " \t");

            // Process escape sequences in cell content
            const cell_content = try self.processEscapes(raw_cell_content);

            // Skip the pipe
            if (i < line.len and line[i] == '|') {
                i += 1;
            }

            // Skip trailing empty cell after last |
            if (i >= line.len and cell_content.len == 0) break;

            // Create cell node
            const cell_node = try self.createNode(.TableCell);
            cell_node.data = .{
                .table_cell = .{
                    .is_header = is_potential_header,
                    .alignment = alignments[col_idx],
                    .first_column = col_idx == 0,
                },
            };

            // Parse inline content within the cell
            try self.parseInlines(cell_node, cell_content);

            // Link cell to row
            if (last_cell) |last| {
                last.next = cell_node;
            } else {
                row_node.child = cell_node;
            }
            last_cell = cell_node;
            col_idx += 1;
        }

        return row_node;
    }
};

/// ## AST Traversal
///
/// This function demonstrates how to "walk" or "traverse" the tree
/// recursively, printing out its structure.
pub fn traversePrint(node: ?*Node, writer: *std.io.Writer, indent: usize) !void {
    var current = node;
    while (current) |n| {
        // 1. Print indentation
        for (0..indent) |_| {
            try writer.writeByte(' ');
        }

        // 2. Print the current node's info
        switch (n.tag) {
            .Root => try writer.print("[Root]\n", .{}),
            .Heading => {
                try writer.print("[Heading (L{d})]\n", .{n.data.heading.level});
            },
            .Paragraph => try writer.print("[Paragraph]\n", .{}),
            .Text => {
                try writer.print("[Text: \"{s}\"]\n", .{n.data.text.content});
            },
            .List => {
                try writer.print("[List]\n", .{});
            },
            .ListItem => {
                try writer.print("[ListItem]\n", .{});
            },
            .TextField => {
                try writer.print("[TextField]\n", .{});
            },
            .Switch => {
                try writer.print("[Switch]\n", .{});
            },
            .FormSection => {
                try writer.print("[FormSection]\n", .{});
            },
            .Form => {
                try writer.print("[Form]\n", .{});
            },
            // --- ADDED ---
            .Bold => try writer.print("[Bold]\n", .{}),
            .Italic => try writer.print("[Italic]\n", .{}),
            .Code => {
                try writer.print("[Code: \"{s}\"]\n", .{n.data.code.content});
            },
            else => {},
            // -------------
        }

        // 3. Recursively traverse this node's children
        try traversePrint(n.child, writer, indent + 1);

        // 4. Move to the next sibling
        current = n.next;
    }
}

pub const default_style_config = StyleConfig{};
pub var global_style: ?StyleConfig = null;
pub const StyleConfig = struct {
    code_style: Vapor.Types.Style = .{ .visual = .{ .text_color = .hex("#212121"), .background = .white } },
    switch_style: Vapor.Types.Style = .{ .visual = .{ .background = .transparentizeHex(.palette(.tint), 0.7) } },
    text_style: Vapor.Types.Style = .{ .visual = .{ .text_color = .hex("#212121") } },
    heading_style: Vapor.Types.Style = .{ .visual = .{ .text_color = .hex("#333333") } },
    text_field_style: Vapor.Types.Style = .{
        .size = .hw(.px(38), .percent(100)),
        .padding = .tblr(4, 4, 8, 8),
        .font_family = "IBM Plex Mono,monospace",
        .interactive = .{
            .hover = .{
                .border = .simple(.black),
            },
        },
        .visual = .{
            .border = .simple(.hex("#E1E1E1")),
            .background = .palette(.tint),
            .outline = .none,
        },
    },
    list_style: Vapor.Types.Style = .{
        .layout = .left_center,
        .direction = .column,
        .size = .w(.percent(100)),
        .child_gap = 8,
    },
    link_style: Vapor.Types.Style = .{ .visual = .{ .text_color = .vapor_blue } },
    button_style: Vapor.Types.Style = .{
        .layout = .in_line,
        .size = .w(.percent(100)),
        .padding = .tb(6, 6),
        .visual = .{
            .border = .sharp(.solid, .hex("#FF0000")),
            .text_color = .white,
            .background = .black,
        },
    },
    submit_style: Vapor.Types.Style = .{
        .layout = .center,
        .size = .w(.percent(100)),
        .margin = .{ .top = 32 },
        .visual = .{
            .border = .round(.transparentizeHex(.palette(.background), 0.5), .all(4)),
            .background = .transparentizeHex(.palette(.background), 0.9),
            .cursor = .pointer,
            .font_size = 16,
            .text_color = .white,
            .new_shadow = Vapor.Types.NewShadow.init()
                .inset(0, -2, .transparentizeHex(.palette(.background), 0.5))
                .drop(0, 1, 3, .transparentizeHex(.palette(.background), 0.1)),
        },
        .transition = .{ .duration = 100 },
        .interactive = .{
            .hover = .{
                .new_shadow = Vapor.Types.NewShadow.init()
                    .inset(0, -2, .transparentizeHex(.black, 0))
                    .drop(0, 1, 3, .transparentizeHex(.black, 0)),
            },
        },
        .padding = .tblr(4, 4, 8, 8),
        .child_gap = 8,
        .font_family = "IBM Plex Sans,monospace",
    },
    struct_style: Vapor.Types.Style = .{
        .size = .w(.percent(100)),
        .padding = .tb(6, 6),
    },
    table_style: Vapor.Types.Style = .{
        .size = .w(.percent(100)),
        .direction = .column,
        .margin = .tb(16, 16),
        .visual = .{
            .border = .simple(.hex("#E1E1E1")),
            .border_radius = .all(4),
        },
    },
    table_header_style: Vapor.Types.Style = .{
        .size = .w(.percent(100)),
        .direction = .row,
        .layout = .left_center,
        .visual = .{
            .background = .palette(.tint),
            .border = .bottom(1, .black),
            .text_color = .white,
        },
    },
    table_row_style: Vapor.Types.Style = .{
        .size = .w(.percent(100)),
        .direction = .row,
        .layout = .left_center,
        .visual = .{
            .background = .transparent,
            .border = .bottom(1, .black),
            .text_color = .black,
        },
    },
    table_cell_style: Vapor.Types.Style = .{
        .padding = .tblr(8, 8, 12, 12),
        .visual = .{
            .border = .bottom(1, .hex("#E1E1E1")),
        },
    },
};

pub const Style = struct {
    is_bold: bool = false,
    is_italic: bool = false,
    level: u8 = 0,
};

pub fn getUnderlyingType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .optional => std.meta.Child(T),
        else => T,
    };
}

pub fn getUnderlyingValue(comptime T: type, comptime OT: type, v: OT) T {
    return switch (@typeInfo(OT)) {
        .optional => v.?,
        else => v,
    };
}

pub fn compile(self: *Self, value: anytype) !void {
    if (self.allocator == null) return error.AllocatorNotSet;
    const root = try self.createNode(.Root);
    current_parent = null;
    try self.generate(root, "root", value);
    try traverse(root, self.style, void, null);
}

pub fn MarkDown(self: *Self, components: anytype) type {
    return struct {
        self: *Self = self,
        node: ?*Node = null,
        tag_f: @TypeOf(components) = components,
        source: []const u8 = "",
        parse_arena: ?std.heap.ArenaAllocator = null,

        // Validate component signatures at comptime
        comptime {
            for (components) |comp| {
                if (!@hasField(@TypeOf(comp), "function")) {
                    @compileError("Component missing .function field");
                }
                if (@hasField(@TypeOf(comp), "args")) {
                    const ArgsType = @TypeOf(comp.args);
                    const FnInfo = @typeInfo(@TypeOf(comp.function));
                    for (FnInfo.@"fn".params) |param| {
                        if (param.type != ArgsType) {
                            @compileError("Function takes incorrect type");
                        }
                    }
                }
            }
        }

        /// Compiles markdown source. Safe to call repeatedly — each call
        /// resets the internal arena, freeing all previous nodes and source.
        pub fn compile(markdown: *@This(), source_input: []const u8) !void {
            const tft = @typeInfo(@TypeOf(components));
            if (tft != .@"struct") {
                Vapor.printErr("Invalid Tagged Functions {any}\n", .{@typeInfo(@TypeOf(components))});
                return error.InvalidTaggedFunctions;
            }

            // Initialize arena on first call only
            if (markdown.parse_arena == null) {
                if (self.allocator) |allocator| {
                    markdown.parse_arena = std.heap.ArenaAllocator.init(allocator);
                } else {
                    std.log.err("Allocator not found. Please instantiate the Vaporize struct first", .{});
                    return error.AllocatorNotFound;
                }
            } else {
                // Subsequent calls: reset instead of re-creating
                _ = markdown.parse_arena.?.reset(.retain_capacity);
            }

            const arena_alloc = markdown.parse_arena.?.allocator();
            const new_source = try arena_alloc.dupe(u8, source_input);

            var parser = Parser.init(arena_alloc, new_source);
            const node = try parser.parse();
            markdown.node = node;
            markdown.source = new_source;
        }

        /// Frees all memory. Call when done with this markdown instance.
        pub fn deinit(markdown: *@This()) void {
            markdown.parse_arena.?.deinit();
            markdown.node = null;
            markdown.source = "";
        }

        pub fn render(markdown: *@This()) !void {
            if (markdown.node == null) return error.NodeNotFoundMustCompileFirst;
            try markdown.self.traverse(markdown.node.?, .{}, &markdown.tag_f);
        }
    };
}

pub fn attachChild(_: *Self, parent: *Node, child: *Node) void {
    if (parent.child) |first| {
        var last = first;
        while (last.next) |next| {
            last = next;
        }
        last.next = child;
    } else {
        parent.child = child;
    }
}

var current_parent: ?*Node = null;
fn generate(self: *Self, parent: *Node, field_name: []const u8, value: anytype) !void {
    const VT = @TypeOf(value);
    current_parent = current_parent orelse parent;
    switch (@typeInfo(VT)) {
        .@"struct" => {
            const struct_node = try self.createNode(.Box);
            self.attachChild(current_parent.?, struct_node);
            current_parent = struct_node;
            const fields = @typeInfo(VT).@"struct".fields;
            inline for (fields) |field| {
                const FT = field.type;
                var field_value: getUnderlyingType(FT) = undefined;
                if (@typeInfo(FT) == .optional) {
                    field_value = @field(value, field.name) orelse continue;
                } else {
                    field_value = @field(value, field.name);
                }
                try self.generate(current_parent.?, field.name, field_value);
            }
            current_parent = parent;
        },
        .pointer => |ptr| {
            switch (ptr.size) {
                .c => {},
                .many => {},
                .one => {
                    switch (ptr.child) {
                        fn () void => {
                            const node = try self.createNode(.Button);
                            node.data = .{ .button = .{ .text = field_name, .on_click = value } };
                            current_parent = node;
                            try self.generate(current_parent.?, field_name, field_name);
                            current_parent = parent;
                            self.attachChild(current_parent.?, node);
                        },
                        else => {
                            Vapor.print("slice\n", .{});
                            const node = try self.createNode(.Text);
                            node.data = .{ .text = .{ .content = value } };
                            self.attachChild(current_parent.?, node);
                        },
                    }
                },
                .slice => {
                    const node = try self.createNode(.Text);
                    node.data = .{ .text = .{ .content = value } };
                    self.attachChild(current_parent.?, node);
                },
            }
        },
        .int => {
            const node = try self.createNode(.Text);
            node.data = .{ .text = .{ .content = std.fmt.allocPrint(self.allocator, "{d}", .{value}) catch unreachable } };
            self.attachChild(current_parent.?, node);
        },
        .float => {
            const node = try self.createNode(.Text);
            node.data = .{ .text = .{ .content = std.fmt.allocPrint(self.allocator, "{d}", .{value}) catch unreachable } };
            self.attachChild(current_parent.?, node);
        },
        .array => {
            const node = try self.createNode(.List);
            node.data = .{ .list = .{ .list_type = .disc } };
            self.attachChild(current_parent.?, node);
            current_parent = node;
            for (value) |item| {
                const list_item_node = try self.createNode(.ListItem);
                current_parent = list_item_node;
                try self.generate(current_parent.?, field_name, item);
                self.attachChild(node, list_item_node);
            }
            current_parent = parent;
        },
        else => {},
    }
}

// We need to store the state of the parent so we can restore style
// when we finish a child and move to the parent's sibling.
// 1. Update StackItem to store the 'closer' function
const StackItem = struct {
    node: *Node,
    style: Style,
    // We need to remember the function that closes this specific node
    // closer: ?*const fn (void) void,
    closer: ?Vapor.Builder(.pure),
    is_section: bool = false, // Add this field

};

fn ErrorText(err: *ValidationError) void {
    // if (err == null) return;
    // const e: *ValidationError = @ptrCast(@alignCast(err));
    Text(err.message)
        .cursor(.help)
        .inlineStyle(
            \\min-width: 0;
            \\max-width: 100%;    /* never exceed parent */
            \\width: fit-content; /* only take what's needed */
            \\overflow-wrap: break-word; /* wrap long words if needed */
        , .{})
        .font(12, null, .red)
        .height(.px(16))
        // .width(.percent(100))
        .ellipsis(.dot)
        .end();
}

pub fn traverseForm(self: *Self, node: ?*Node, style: Style, value: anytype) !void {
    const allocator = self.allocator orelse return error.AllocatorNotFound;
    // 1. The 'Backtrack' Stack
    // This holds nodes that are currently "Open" in the UI.
    var stack = std.array_list.Managed(StackItem).init(allocator);
    defer stack.deinit();

    var current_node = node;
    var current_style = style;
    var skip = false;
    var section_depth: u32 = 0; // Track nesting depth

    // Loop until we have no node to process and the stack is empty
    while (current_node != null) {
        const n = current_node.?;

        // --- STEP 1: CALCULATE STYLE FOR THIS NODE ---
        // We create a mutable copy for this specific node context
        var node_style = current_style;

        var current_closer: ?Vapor.Builder(.pure) = null;
        var is_section = false; // Track if this node is a section

        switch (n.tag) {
            .Root => {},
            .Heading => {
                current_closer = Box().style(&.{
                    .layout = .in_line,
                    .size = .w(.percent(100)),
                    .padding = .tb(12, 12),
                });
                node_style.level = n.data.heading.level;
            },
            .Bold => {
                node_style.is_bold = true;
            },
            .Italic => {
                node_style.is_italic = true;
            },
            .Svg => {
                const src = n.data.image.src;
                Box().style(&.{
                    .size = .{ .width = .percent(100), .height = .percent(100) },
                    .padding = .tb(16, 16),
                    .layout = .center,
                }).children({
                    Graphic(.{ .src = src }).style(&.{
                        .layout = .center,
                        .size = .{ .width = .percent(70), .height = .auto },
                        .visual = .{ .fill = self.style_config.text_style.visual.?.text_color, .stroke = self.style_config.text_style.visual.?.text_color },
                        .aspect_ratio = .landscape,
                    }).end();
                });
            },
            .Image => {
                const src = n.data.image.src;
                current_closer = Box().style(&.{
                    .size = .{ .width = .percent(100), .height = .percent(100) },
                    .padding = .tb(32, 32),
                    .layout = .center,
                });
                Image(.{ .src = src }).style(&.{
                    .size = .{ .width = .percent(70), .height = .auto },
                    .aspect_ratio = .landscape,
                }).end();
            },
            .Section => {
                current_closer = Section().id(n.data.section.id).style(&.{
                    .child_gap = 4,
                    .direction = .column,
                    .size = .hw(.percent(100), .grow),
                    .layout = .{},
                });
            },
            .Snippet => {
                const snippet = n.data.snippet.ptr;
                const content = n.data.snippet.content;
                Box().style(&.{
                    .size = .{ .width = .percent(100), .height = .fit },
                    .margin = .tb(4, 4),
                    .layout = .center,
                }).children({
                    snippet.code(content);
                });
            },
            .Paragraph => {
                current_closer = Box().style(&.{
                    .layout = .in_line,
                    .size = .w(.percent(100)),
                    .padding = .tb(6, 6),
                });
            },
            .Text => {
                if (node_style.level > 0) {
                    switch (node_style.level) {
                        1 => {
                            Heading(node_style.level, n.data.text.content).style(&.{
                                .visual = .{ .font_weight = 700, .font_size = 42 },
                                .font_family = "IBM Plex Sans,sans-serif",
                                .margin = .tb(16, 0),
                            }).end();
                        },
                        2 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{ .font_weight = 400, .font_size = 28 },
                            .font_family = "IBM Plex Sans,sans-serif",
                            .margin = .tb(16, 0),
                        }).end(),
                        3 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{ .font_weight = 600, .font_size = 24 },
                            .font_family = "IBM Plex Sans,sans-serif",
                            .margin = .tb(12, 0),
                        }).end(),
                        4 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{ .font_weight = 400, .font_size = 20 },
                            .font_family = "IBM Plex Sans,sans-serif",
                        }).end(),
                        5 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{ .font_weight = 300, .font_size = 18 },
                            .font_family = "IBM Plex Sans,sans-serif",
                        }).end(),
                        6 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{ .font_weight = 200 },
                            .font_family = "IBM Plex Sans,sans-serif",
                        }).end(),
                        else => {},
                    }
                } else {
                    Text(n.data.text.content).style(&.{
                        .layout = .in_line,
                        .visual = .{
                            .font_size = 16,
                            .font_weight = if (node_style.is_bold) 600 else 400,
                            .font_style = if (node_style.is_italic) .italic else null,
                            .text_color = self.style_config.text_style.visual.?.text_color,
                        },
                    }).end();
                }
            },
            .List => {
                current_closer = List().style(&.{
                    .layout = .left_center,
                    .direction = .column,
                    .size = .w(.percent(100)),
                    .child_gap = 8,
                    .list_style = n.data.list.list_type,
                });
            },
            .ListItem => {
                current_closer = ListItem().style(&.{});
            },
            .RunBlock => {
                const src = n.data.run_block.src;
                const ptr = @typeInfo(@TypeOf(value)).pointer.child;
                const fncs = @typeInfo(ptr).@"struct".fields;
                inline for (fncs) |func| {
                    if (func.type == ?*ValidationResult) break;
                    const anon_func = func.defaultValue() orelse continue;
                    if (@hasField(func.type, "args")) {
                        if (std.mem.eql(u8, src, anon_func.tag)) {
                            @call(.auto, anon_func.function, .{anon_func.args});
                        }
                    } else if (std.mem.eql(u8, src, anon_func.tag)) {
                        @call(.auto, anon_func.function, .{});
                    }
                }
            },
            .Link => {
                const href = n.data.link.href;
                const title = n.data.link.title;
                RedirectLink(.{ .url = href, .aria_label = title }).style(&.{
                    .layout = .in_line,
                    .visual = .{
                        .cursor = .pointer,
                    },
                }).children({
                    Text(title).style(&.{
                        .layout = .in_line,
                        .visual = .{
                            .font_size = 16,
                            .font_weight = if (style.is_bold) 600 else 400,
                            .font_style = if (style.is_italic) .italic else null,
                        },
                    }).end();
                });
            },
            .Code => {
                Code(n.data.code.content).style(&.{
                    .layout = .in_line,
                    .visual = .{
                        .font_size = 15,
                        .font_weight = if (style.is_bold) 600 else 400,
                        .text_color = self.style_config.code_style.visual.?.text_color,
                    },
                    .font_family = "JetBrains Mono,Fira Code,Consolas,monospace",
                }).end();
            },
            .FormSection => {
                const targeted = value.conditionals.get(n.data.formsection.title) orelse true;
                if (targeted) {
                    const title = Vapor.utils.stringReplace(Vapor.utils.firstLetterToUpper(n.data.formsection.title, .frame), "_", " ", .frame);

                    // Style based on depth
                    const font_size: u8 = switch (section_depth) {
                        0, 1 => 18, // Top level: large
                        2 => 14, // Subsection: smaller
                        else => 12, // Deeper: even smaller
                    };

                    const font_weight: u16 = switch (section_depth) {
                        0, 1 => 700, // Top level: bold
                        2 => 600, // Subsection: semi-bold
                        else => 500, // Deeper: medium
                    };

                    const text_color: Vapor.Types.Color = switch (section_depth) {
                        0 => .black, // Top level: normal
                        else => .transparentizeHex(.black, 0.6), // Subsection: muted/gray
                    };

                    is_section = true;
                    section_depth += 1;
                    current_closer = Section().style(&.{
                        .layout = .flex,
                        .flex_wrap = .wrap,
                        .direction = .row,
                        .size = .hw(.fit, .percent(100)),
                        .child_gap = 16,
                        .margin = .tb(0, 0),
                        .padding = if (section_depth > 1) .left(16) else .all(0),
                        .visual = .{
                            .border = if (section_depth > 1) .sharp(.left(1), .black) else .none,
                        },
                    });

                    Text(title).style(&.{
                        .layout = .in_line,
                        .size = .w(.percent(100)),
                        .visual = .{
                            .font_size = font_size,
                            .font_weight = font_weight,
                            .font_style = if (node_style.is_italic) .italic else null,
                            .text_color = text_color,
                        },
                        .margin = .tb(if (section_depth > 1) 12 else 24, 0),
                    }).end();
                } else {
                    skip = true;
                }
            },
            .Switch => {
                current_closer = Box().style(&.{
                    .layout = .x_between_center,
                    .direction = .row,
                    .size = .hw(.fit, .percent(100)),
                });
                const title = Vapor.utils.stringReplace(Vapor.utils.firstLetterToUpper(n.data.toggle.title, .frame), "_", " ", .frame);
                Text(title).style(&.{
                    .layout = .in_line,
                    .visual = .{
                        .font_size = 16,
                        .font_weight = if (style.is_bold) 600 else 400,
                        .font_style = if (style.is_italic) .italic else null,
                    },
                    .margin = .tb(0, 0),
                }).end();
                const t = getUnderlyingType(@TypeOf(value));
                if (@typeInfo(t) == .pointer) {
                    const PtrInfo = @typeInfo(t).pointer;

                    // 2. Ensure the child type has the field "form_data"
                    if (@hasField(PtrInfo.child, "form_data")) {
                        // Since 'value' is a pointer, we dereference it to access the field
                        const form_value = value.*.form_data;
                        const FormType = @TypeOf(form_value.*);
                        const condition: *Condition(FormType) = @ptrCast(@alignCast(n.data.toggle.condition));
                        const visual = if (self.style_config.switch_style.visual) |v| v else default_style_config.switch_style.visual.?;
                        Switch.render(n.data.toggle.title, FormType, form_value, condition, &value.conditionals, visual.background);
                    }
                }
            },
            .TextArea => {
                current_closer = Box()
                    .style(&.{
                    .layout = .top_left,
                    .direction = .column,
                    .size = .hw(.fit, .percent(100)),
                    .child_gap = 4,
                });
                const title = Vapor.utils.stringReplace(Vapor.utils.firstLetterToUpper(n.data.textarea.title, .frame), "_", " ", .frame);
                var label: Vapor.Builder(.pure) = Label(title);

                var text_area: Vapor.TextAreaBuilder(.pure) = TextArea.render(.{
                    .label = title,
                    .field_name = n.data.textarea.title,
                });

                const uuid = text_area.getUUID();
                const id = Vapor.fmtln("{s}_{s}", .{ title, uuid });

                label.fieldName(id).style(&self.style_config.text_style).end();

                text_area.id(id).height(.px(72)).end();

                Box()
                    .inlineStyle(
                        \\min-width: 0;
                        \\max-width: 100%;
                    , .{})
                    .style(&.{
                        .size = .h(.px(16)),
                    }).children({
                    if (n.data.textarea.err) |err| {
                        for (err.errors.items) |*e| {
                            if (std.mem.eql(u8, e.field, n.data.textarea.title)) {
                                Tooltip.create(.{
                                    .background = .palette(.danger),
                                    .stroke_color = .palette(.danger),
                                    .content = e.message,
                                    .title = title,
                                })
                                    .Trigger(ErrorText, .{e})
                                    .end();
                            } else {
                                Vapor.Null();
                            }
                        }
                    }
                });
            },
            .TextField => {
                const t = getUnderlyingType(@TypeOf(value));
                const has_component = if (@typeInfo(t) == .pointer) blk: {
                    const PtrInfo = @typeInfo(t).pointer;

                    // 2. Ensure the child type has the field "form_data"
                    if (@hasField(PtrInfo.child, "form_data")) {
                        // Since 'value' is a pointer, we dereference it to access the field
                        const form_value = value.*.form_data;
                        const FormType = @TypeOf(form_value.*);

                        // 3. Check for the declaration on the Type itself
                        if (@hasDecl(FormType, "__components")) {
                            // Access the decl directly from the type
                            const components = FormType.__components;
                            const components_info = @typeInfo(@TypeOf(components));

                            if (components_info == .@"struct") {
                                inline for (components_info.@"struct".fields) |field| {
                                    // 4. runtime string comparison is fine, but field.name is comptime
                                    if (std.mem.eql(u8, field.name, n.data.textfield.title)) {

                                        // 5. This is the likely 'TODO' panic:
                                        // Instead of defaultValue(), access the field from the static 'components' instance
                                        const field_component = @field(components, field.name);

                                        var err: ?ValidationError = null;
                                        if (n.data.textfield.err) |text_err| {
                                            for (text_err.errors.items) |e| {
                                                if (std.mem.eql(u8, e.field, n.data.textfield.title)) {
                                                    err = e;
                                                }
                                            }
                                        }
                                        @call(.auto, field_component, .{ value.*.form_data, err });
                                        break :blk true;
                                    }
                                }
                            }
                        }
                    }
                    break :blk false;
                };

                if (!has_component) {
                    const width: usize = if (section_depth > 0) 150 else 48;
                    current_closer = Box()
                        .inlineStyle("flex: 1 1 {d}px; min-width: 0; align-self: stretch;max-width: 100%;", .{width})
                        .style(&.{
                        .layout = .top_left,
                        .direction = .column,
                        .size = .hw(.auto, .auto),
                        .child_gap = 4,
                    });
                    // Label(Vapor.utils.stringReplace(Vapor.utils.firstLetterToUpper(n.data.textfield.title, .frame), "_", " ", .frame)).style(&self.style_config.text_style);
                    const title = Vapor.utils.stringReplace(Vapor.utils.firstLetterToUpper(n.data.textfield.title, .frame), "_", " ", .frame);

                    // const visual = if (self.style_config.text_field_style.visual) |v| v else default_style_config.text_field_style.visual.?;

                    Field.Field(.{
                        .type = n.data.textfield.type,
                        .label = title,
                        .config = n.data.textfield.config,
                        .field_name = n.data.textfield.title,
                        .default_value = n.data.textfield.default_value,
                        .placeholder = n.data.textfield.placeholder,
                        // .backgroud = visual.background,
                    }).render();
                    Box()
                        .inlineStyle(
                            \\min-width: 0;
                            \\max-width: 100%;
                        , .{})
                        .style(&.{
                            // .layout = .left_center,
                            .size = .h(.px(16)),
                        }).children({
                        // TextField(n.data.textfield.type).fieldName(n.data.textfield.title).style(&self.style_config.text_field_style);
                        if (n.data.textfield.err) |err| {
                            for (err.errors.items) |*e| {
                                if (std.mem.eql(u8, e.field, n.data.textfield.title)) {
                                    // Tooltip.renderCtx(.{
                                    //     .name = title,
                                    //     .title = title,
                                    //     .content = e.message,
                                    //     .trigger_ctx = ErrorText,
                                    //     .ctx = @ptrCast(@alignCast(e)),
                                    // });
                                    Tooltip.create(.{
                                        .background = .palette(.danger),
                                        .stroke_color = .palette(.danger),
                                        .content = e.message,
                                        .title = title,
                                    })
                                        .Trigger(ErrorText, .{e})
                                        .end();
                                } else {
                                    Vapor.Null();
                                }
                            }
                        }
                    });
                }
            },
            .Dropdown => {
                current_closer = Vapor.FieldSet().style(&.{
                    .layout = .left_center,
                    .direction = .column,
                    .size = .hw(.fit, .percent(100)),
                    .child_gap = 4,
                });

                // Button(.{ .on_press = value.*.form_data.toggle })
                //     .border(.simple(.black)).children({
                //     Text("Increment").fontSize(18).end();
                // });

                const t = getUnderlyingType(@TypeOf(value));
                const has_component = if (@typeInfo(t) == .pointer) blk: {
                    const PtrInfo = @typeInfo(t).pointer;

                    // 2. Ensure the child type has the field "form_data"
                    if (@hasField(PtrInfo.child, "form_data")) {
                        // Since 'value' is a pointer, we dereference it to access the field
                        const form_value = value.*.form_data;
                        const FormType = @TypeOf(form_value.*);

                        // 3. Check for the declaration on the Type itself
                        if (@hasDecl(FormType, "__components")) {
                            // Access the decl directly from the type
                            const components = FormType.__components;
                            const components_info = @typeInfo(@TypeOf(components));

                            if (components_info == .@"struct") {
                                inline for (components_info.@"struct".fields) |field| {
                                    // 4. runtime string comparison is fine, but field.name is comptime
                                    if (std.mem.eql(u8, field.name, n.data.dropdown.title)) {

                                        // 5. This is the likely 'TODO' panic:
                                        // Instead of defaultValue(), access the field from the static 'components' instance
                                        const field_component = @field(components, field.name);

                                        var err: ?ValidationError = null;
                                        if (n.data.textfield.err) |text_err| {
                                            for (text_err.errors.items) |e| {
                                                if (std.mem.eql(u8, e.field, n.data.textfield.title)) {
                                                    err = e;
                                                }
                                            }
                                        }
                                        @call(.auto, field_component, .{ value.*.form_data, err });
                                        break :blk true;
                                    }
                                }
                            }
                        }
                    }
                    break :blk false;
                };

                if (!has_component) {
                    const PtrInfo = @typeInfo(t).pointer;
                    // 2. Ensure the child type has the field "form_data"
                    if (@hasField(PtrInfo.child, "form_data")) {
                        const tags = n.data.dropdown.tags;
                        const title = Vapor.utils.stringReplace(Vapor.utils.firstLetterToUpper(n.data.dropdown.title, .frame), "_", " ", .frame);
                        for (tags) |tag| {
                            Field.Field(.{
                                .type = .radio,
                                .label = tag,
                                // .config = n.data.textfield.config,
                                .field_name = n.data.dropdown.title,
                                .default_value = .{ .string = tag },
                                // .placeholder = n.data.textfield.placeholder,
                                // .backgroud = visual.background,
                            }).render();
                        }
                        Box()
                            .inlineStyle("min-width: 0; max-width: 100%;", .{})
                            .style(&.{ .size = .h(.px(16)) }).children({
                            if (n.data.dropdown.err) |err| {
                                for (err.errors.items) |*e| {
                                    if (std.mem.eql(u8, e.field, n.data.dropdown.title)) {
                                        Tooltip.create(.{
                                            .background = .palette(.danger),
                                            .stroke_color = .palette(.danger),
                                            .content = e.message,
                                            .title = title,
                                        })
                                            .Trigger(ErrorText, .{e})
                                            .end();
                                    } else {
                                        Vapor.Null();
                                    }
                                }
                            }
                        });
                    }
                }
            },
            else => {},
        }

        // --- STEP 2: OPEN UI ELEMENT ---
        // This calls your ui_ctx.open(...) internally
        // We pass 'node_style' because that is the style FOR THIS node and its children

        // --- STEP 3: DETERMINE NEXT MOVE ---

        if (!skip and n.child != null) {
            const child = n.child.?;
            // A: GO DEEPER (Container)

            // 1. Push the CURRENT node and its CLOSER to the stack
            try stack.append(.{
                .node = n,
                .style = current_style, // Save parent style
                .closer = current_closer, // Save the closer function!
                .is_section = is_section, // Save whether this was a section
            });

            // 2. Move to child
            current_node = child;
            current_style = node_style; // Apply new style to child
        } else {
            // B: LEAF NODE (No children)

            // 1. If this node produced a closer, call it immediately
            //    (This closes empty boxes, or leaf items like Images)
            if (current_closer) |closer| {
                closer.children({});
            }

            // Decrement depth if this was a section leaf (no children)
            if (is_section) {
                section_depth -= 1;
            }

            if (n.next) |sibling| {
                current_node = sibling;
                // Style remains 'current_style' (parent's style)
            } else {
                // C: BACKTRACK
                current_node = null; // Stop unless we find a path up

                while (stack.items.len > 0) {
                    // 1. Pop the Parent
                    const parent_item = stack.pop() orelse break;

                    // 2. CRITICAL: CLOSE THE PARENT CONTAINER
                    //    We are now exiting the parent, so we call the builder
                    //    we saved when we entered it.
                    if (parent_item.closer) |closer| {
                        closer.children({});
                    }

                    // Decrement depth when closing a section
                    if (parent_item.is_section) {
                        section_depth -= 1;
                    }

                    // 3. Check if Parent has a Sibling
                    if (parent_item.node.next) |parent_sibling| {
                        current_node = parent_sibling;
                        current_style = parent_item.style; // Restore ancestor style
                        break; // Resume outer loop
                    }

                    // If parent has no sibling, loop continues to pop grandparent...
                }
            }
        }
    }
}

fn CodeBox(code: *SyntaxHighlighter, title: []const u8) void {
    Stack().width(.percent(100))
        .height(.percent(100))
        .background(.transparentize(.black, 0.2))
        .radius(.all(18))
        .padding(.xy(8, 8))
        .children({
        Stack().width(.percent(100))
            .height(.percent(100))
            .background(.hex("#111110"))
            .radius(.all(10))
            .padding(.xy(8, 16))
            .children({
            Box()
                .width(.percent(100))
                .height(.percent(6))
                .padding(.horizontal(24))
                .children({
                Box()
                    .padding(.all(8))
                    .width(.fit)
                    .layout(.center)
                    .height(.percent(100))
                    .border(.bottom(1, .white))
                    .children({
                    Text(title)
                        .fontStyle(.italic)
                        .fontFamily("Geist Mono, monospace")
                        .font(14, 300, .white).end();
                });
            });
            Center().width(.percent(100))
                .height(.percent(94))
                .scroll(.scroll_y())
                .border(.round(.hex("#383735"), .all(6)))
                .background(.hex("#282828"))
                .children({
                code.render() catch unreachable;
            });
        });
    });
}

pub fn traverse(self: *Self, node: ?*Node, style: Style, value: anytype) !void {
    const allocator = self.allocator orelse return error.AllocatorNotFound;
    // 1. The 'Backtrack' Stack
    // This holds nodes that are currently "Open" in the UI.
    var stack = std.array_list.Managed(StackItem).init(allocator);
    defer stack.deinit();

    var current_node = node;
    var current_style = style;
    var column_count: usize = 0;

    // Loop until we have no node to process and the stack is empty
    while (current_node != null) {
        const n = current_node.?;

        // --- STEP 1: CALCULATE STYLE FOR THIS NODE ---
        // We create a mutable copy for this specific node context
        var node_style = current_style;
        var current_closer: ?Vapor.Builder(.pure) = null;

        switch (n.tag) {
            .Root => {},
            .Heading => {
                current_closer = Box().style(&.{
                    .layout = .in_line,
                    .size = .w(.percent(100)),
                    .padding = .tb(12, 12),
                });
                node_style.level = n.data.heading.level;
            },
            .Bold => {
                node_style.is_bold = true;
            },
            .BlockQuote => {
                current_closer = Box()
                    .style(&Vapor.Types.Style{
                    .layout = .in_line,
                    .size = .w(.percent(100)),
                    .padding = .left(12),
                    .visual = .{ .border = .solid(.left(3), .transparentize(.black, 0.2), .all(0)) },
                });
            },
            .HorizontalRule => {
                current_closer = Box()
                    .style(&Vapor.Types.Style{
                    .size = .hw(.px(1), .percent(100)),
                    .margin = .vertical(12),
                    .visual = .bg(.transparentize(.black, 0.2)),
                });
            },
            .Italic => {
                node_style.is_italic = true;
            },
            .Svg => {
                const src = n.data.image.src;
                Box().style(&.{
                    .size = .{ .width = .percent(100), .height = .percent(100) },
                    .padding = .tb(16, 16),
                    .layout = .center,
                }).children({
                    Graphic(.{ .src = src }).style(&.{
                        .layout = .center,
                        .size = .{ .width = .percent(70), .height = .auto },
                        .visual = .{ .fill = self.style_config.text_style.visual.?.text_color, .stroke = self.style_config.text_style.visual.?.text_color },
                        .aspect_ratio = .landscape,
                    }).end();
                });
            },
            .Image => {
                const src = n.data.image.src;
                current_closer = Box().style(&.{
                    .size = .{ .width = .percent(100), .height = .percent(100) },
                    .padding = .tb(32, 32),
                    .layout = .center,
                });
                Image(.{ .src = src }).style(&.{
                    .size = .{ .width = .percent(70), .height = .auto },
                    .aspect_ratio = .landscape,
                }).end();
            },
            .Section => {
                current_closer = Section().id(n.data.section.id).style(&.{
                    .child_gap = 4,
                    .direction = .column,
                    .size = .hw(.percent(100), .grow),
                    .margin = .tb(0, 48),
                    .layout = .{},
                });
            },
            .Snippet => {
                const snippet = n.data.snippet.ptr;
                const content = n.data.snippet.content;
                Box().style(&.{
                    .size = .{ .width = .percent(100), .height = .fit },
                    .margin = .tb(4, 4),
                    .layout = .center,
                }).children({
                    snippet.code(content);
                });
            },
            .Paragraph => {
                current_closer = Box().style(&.{
                    .layout = .in_line,
                    .size = .w(.percent(100)),
                    // .padding = .tb(6, 6),
                });
            },
            .Text => {
                if (node_style.level > 0) {
                    switch (node_style.level) {
                        1 => {
                            Heading(node_style.level, n.data.text.content).style(&.{
                                .visual = .{
                                    .font_weight = 700,
                                    .font_size = 42,
                                    .text_color = self.style_config.text_style.visual.?.text_color,
                                },
                                .font_family = "IBM Plex Sans,sans-serif",
                                // .margin = .tb(16, 0),
                            }).end();
                        },
                        2 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{
                                .font_weight = 400,
                                .font_size = 28,
                                .text_color = self.style_config.text_style.visual.?.text_color,
                            },
                            .font_family = "IBM Plex Sans,sans-serif",
                            // .margin = .tb(16, 0),
                        }).end(),
                        3 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{
                                .font_weight = 600,
                                .font_size = 24,
                                .text_color = self.style_config.text_style.visual.?.text_color,
                            },
                            .font_family = "IBM Plex Sans,sans-serif",
                            // .margin = .tb(12, 0),
                        }).end(),
                        4 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{
                                .font_weight = 400,
                                .font_size = 20,
                                .text_color = self.style_config.text_style.visual.?.text_color,
                            },
                            .font_family = "IBM Plex Sans,sans-serif",
                        }).end(),
                        5 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{
                                .font_weight = 300,
                                .font_size = 18,
                                .text_color = self.style_config.text_style.visual.?.text_color,
                            },
                            .font_family = "IBM Plex Sans,sans-serif",
                        }).end(),
                        6 => Heading(node_style.level, n.data.text.content).style(&.{
                            .visual = .{
                                .font_weight = 200,
                                .text_color = self.style_config.text_style.visual.?.text_color,
                            },
                            .font_family = "IBM Plex Sans,sans-serif",
                        }).end(),
                        else => {},
                    }
                } else {
                    Text(n.data.text.content)
                        .unmanaged()
                        .style(&.{
                            .layout = .in_line,
                            .visual = .{
                                .font_size = 16,
                                .font_weight = if (node_style.is_bold) 600 else 400,
                                .font_style = if (node_style.is_italic) .italic else null,
                                // .text_color = self.style_config.text_style.visual.?.text_color,
                            },
                        }).end();
                }
            },
            .List => {
                current_closer = List().style(&.{
                    .layout = .left_center,
                    .direction = .column,
                    .size = .w(.percent(100)),
                    .child_gap = 8,
                    .list_style = n.data.list.list_type,
                    .padding = .left(32),
                    .visual = .{
                        .text_color = self.style_config.text_style.visual.?.text_color,
                    },
                });
            },
            .CodeBlock => {
                var editor = n.data.code_block.editor;
                editor.show_toolbar = true;
                Box().style(&.{
                    .size = .{ .width = .percent(100), .height = .percent(100) },
                    .margin = .tb(16, 32),
                    .layout = .center,
                    .visual = .{
                        // .background = self.style_config.code_style.visual.?.background,
                        // .border = self.style_config.code_style.visual.?.border,
                    },
                }).children({
                    CodeBox(editor, "sample.zig");
                    // editor.render() catch unreachable;
                });
            },
            .ListItem => {
                current_closer = ListItem().style(&.{});
            },
            .RunBlock => {
                const src = n.data.run_block.src;
                const ptr = @typeInfo(@TypeOf(value)).pointer.child;
                const fncs = @typeInfo(ptr).@"struct".fields;
                inline for (fncs) |func| {
                    if (func.type == ?*ValidationResult) break;
                    const anon_func = func.defaultValue() orelse continue;
                    if (@hasField(func.type, "args")) {
                        if (std.mem.eql(u8, src, anon_func.tag)) {
                            @call(.auto, anon_func.function, .{anon_func.args});
                        }
                    } else if (std.mem.eql(u8, src, anon_func.tag)) {
                        @call(.auto, anon_func.function, .{});
                    }
                }
            },
            .Link => {
                const href = n.data.link.href;
                const title = n.data.link.title;
                RedirectLink(.{ .url = href, .aria_label = title }).style(&.{
                    .layout = .in_line,
                    .visual = .{
                        .cursor = .pointer,
                    },
                }).children({
                    Text(title).style(&.{
                        .layout = .in_line,
                        .visual = .{
                            .font_size = 16,
                            .font_weight = if (style.is_bold) 600 else 400,
                            .font_style = .italic,
                            .text_color = self.style_config.link_style.visual.?.text_color,
                        },
                    }).end();
                });
            },
            .Code => {
                Code(n.data.code.content).style(&.{
                    .layout = .in_line,
                    .visual = .{
                        .font_size = 15,
                        .font_weight = if (style.is_bold) 600 else 400,
                        .text_color = self.style_config.code_style.visual.?.text_color,
                    },
                    .font_family = "JetBrains Mono,Fira Code,Consolas,monospace",
                }).end();
            },
            .Box => {
                current_closer = Box().style(&.{
                    .layout = .left_center,
                    .direction = .column,
                    .size = .hw(.fit, .percent(100)),
                    .child_gap = 8,
                });
            },
            // Add these cases to the switch in traverse:
            .Table => {
                column_count = n.data.table.column_count;
                // Import or define Table component if not already available
                current_closer = Box().style(&.{
                    .size = .w(.percent(100)),
                    .direction = .column,
                    .margin = .tb(16, 16),
                    .visual = .{
                        .border = .sharp(.tblr(1, 0, 1, 1), .black),
                        .border_radius = .all(4),
                    },
                    .scroll = .scroll_x(),
                });
            },

            .TableRow => {
                const is_header = n.data.table_row.is_header;
                const table_header_style = self.style_config.table_header_style;
                const table_row_style = self.style_config.table_row_style;
                if (is_header) {
                    current_closer = Box().style(&table_header_style);
                } else {
                    current_closer = Box().style(&table_row_style);
                }
            },

            .TableCell => {
                const cell_data = n.data.table_cell;
                const alignment: Vapor.Types.Layout = switch (cell_data.alignment) {
                    .left => .left_center,
                    .center => .center,
                    .right => .right_center,
                    .default => .left_center,
                };

                const first_column_width: Vapor.Types.Sizing = if (column_count > 3 and cell_data.first_column) .percent(20) else .grow;
                current_closer = Box().style(&.{
                    .size = .hw(.fit, first_column_width),
                    .padding = .tblr(8, 8, 12, 12),
                    .layout = alignment,
                    .visual = .{
                        .font_weight = if (cell_data.is_header) 600 else 400,
                        .text_color = if (cell_data.is_header) self.style_config.table_header_style.visual.?.text_color else self.style_config.table_row_style.visual.?.text_color,
                    },
                });
            },

            .RightAligned => {
                current_closer = Box().style(&.{
                    .layout = .right_center,
                    .size = .w(.percent(100)),
                    .padding = .tb(6, 6),
                });
            },
            .StyledContainer => {
                const class = n.data.styled_container.style_class;

                // Map class names to colors
                const bg: Vapor.Types.Color = if (std.mem.eql(u8, class, "user"))
                    .palette(.highlight_color)
                else if (std.mem.eql(u8, class, "assistant"))
                    .transparent
                else if (std.mem.eql(u8, class, "success"))
                    .transparentizeHex(.green, 0.9)
                else if (std.mem.eql(u8, class, "warning"))
                    .transparentizeHex(.yellow, 0.9)
                else
                    .transparentizeHex(.blue, 0.9);

                const text_color: Vapor.Types.Color = if (std.mem.eql(u8, class, "user"))
                    .white
                else
                    self.style_config.text_style.visual.?.text_color.?;

                current_closer = Box().style(&.{
                    .size = .w(.percent(100)),
                    .direction = .column,
                    .padding = .all(16),
                    .margin = .tb(8, 8),
                    .child_gap = 8,
                    .visual = .{
                        .background = bg,
                        .border_radius = .all(12),
                        .border = .sharp(.all(1), .transparentize(.black, 0.1)),
                        .text_color = text_color,
                    },
                });
            },

            else => {},
        }

        if (n.child != null) {
            const child = n.child.?;
            // A: GO DEEPER (Container)

            // 1. Push the CURRENT node and its CLOSER to the stack
            try stack.append(.{
                .node = n,
                .style = current_style, // Save parent style
                .closer = current_closer, // Save the closer function!
            });

            // 2. Move to child
            current_node = child;
            current_style = node_style; // Apply new style to child
        } else {
            // B: LEAF NODE (No children)

            // 1. If this node produced a closer, call it immediately
            //    (This closes empty boxes, or leaf items like Images)
            if (current_closer) |closer| {
                closer.children({});
            }

            if (n.next) |sibling| {
                current_node = sibling;
                // Style remains 'current_style' (parent's style)
            } else {
                // C: BACKTRACK
                current_node = null; // Stop unless we find a path up

                while (stack.items.len > 0) {
                    // 1. Pop the Parent
                    const parent_item = stack.pop() orelse break;

                    // 2. CRITICAL: CLOSE THE PARENT CONTAINER
                    //    We are now exiting the parent, so we call the builder
                    //    we saved when we entered it.
                    if (parent_item.closer) |closer| {
                        closer.children({});
                    }

                    // 3. Check if Parent has a Sibling
                    if (parent_item.node.next) |parent_sibling| {
                        current_node = parent_sibling;
                        current_style = parent_item.style; // Restore ancestor style
                        break; // Resume outer loop
                    }

                    // If parent has no sibling, loop continues to pop grandparent...
                }
            }
        }
    }
}

/// ## Main Function
///
/// This sets up the parser, runs it on some sample
/// Markdown, and then traverses the resulting AST.
pub fn main() !void {
    // Note: Your buffered writer setup is slightly different from std.io.getStdOut()
    // but it's perfectly valid.
    var buffer: [4096]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&buffer);
    var stdout = &writer.interface;
    // const stdout = &stdout_buffer;

    // Use a General Purpose Allocator as the "parent"
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    // --- MODIFIED: New sample input ---
    const markdown =
        \\# Main Heading
        \\
        \\- Item 1
        \\  - Nested item 1
        \\  - Nested item 2
        \\- Item 2
        \\  - Nested item 3
        \\
        \\This is the second paragraph.
    ;
    // --------------------------------------------------   // ---------------------------------

    // 1. Initialize the parser
    var parser = Parser.init(allocator, markdown);
    var vaporize = init(allocator);
    vaporize.compile("Hello World!");

    // 2. Run the parser
    const root_node = try parser.parse();

    // 3. Traverse and print the tree
    try stdout.print("--- AST Traversal ---\n", .{});
    try traversePrint(root_node, stdout, 0);
    stdout.flush() catch {};
}
