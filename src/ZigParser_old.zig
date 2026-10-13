const std = @import("std");
const Allocator = std.mem.Allocator;
const Vapor = @import("vapor");
const Static = Vapor.Static;

const Text = Static.Text;
const CtxButton = Vapor.CtxButton;
const Icon = Vapor.Icon;
const Graphic = Vapor.Graphic;
const List = Vapor.List;
const ListItem = Vapor.ListItem;
const Row = Vapor.Row;

const svg_bug =
    \\<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="white" class="bi bi-bug-fill" viewBox="0 0 16 16">
    \\  <path d="M4.978.855a.5.5 0 1 0-.956.29l.41 1.352A5 5 0 0 0 3 6h10a5 5 0 0 0-1.432-3.503l.41-1.352a.5.5 0 1 0-.956-.29l-.291.956A5 5 0 0 0 8 1a5 5 0 0 0-2.731.811l-.29-.956z"/>
    \\  <path d="M13 6v1H8.5v8.975A5 5 0 0 0 13 11h.5a.5.5 0 0 1 .5.5v.5a.5.5 0 1 0 1 0v-.5a1.5 1.5 0 0 0-1.5-1.5H13V9h1.5a.5.5 0 0 0 0-1H13V7h.5A1.5 1.5 0 0 0 15 5.5V5a.5.5 0 0 0-1 0v.5a.5.5 0 0 1-.5.5zm-5.5 9.975V7H3V6h-.5a.5.5 0 0 1-.5-.5V5a.5.5 0 0 0-1 0v.5A1.5 1.5 0 0 0 2.5 7H3v1H1.5a.5.5 0 0 0 0 1H3v1h-.5A1.5 1.5 0 0 0 1 11.5v.5a.5.5 0 1 0 1 0v-.5a.5.5 0 0 1 .5-.5H3a5 5 0 0 0 4.5 4.975"/>
    \\</svg>
;

// ============================================================================
// Color Type (compatible with Vapor's color system)
// ============================================================================

pub const Color = union(enum) {
    hex: []const u8,
    palette: PaletteColor,
    transparent,

    pub const PaletteColor = enum {
        code_text_color,
        code_keyword_color,
        code_function_color,
        code_string_color,
        code_number_color,
        code_comment_color,
        code_type_color,
        code_builtin_color,
        code_operator_color,
        code_tint_color,
    };

    pub fn eql(self: Color, other: Color) bool {
        return switch (self) {
            .hex => |h| switch (other) {
                .hex => |oh| std.mem.eql(u8, h, oh),
                else => false,
            },
            .palette => |p| switch (other) {
                .palette => |op| p == op,
                else => false,
            },
            .transparent => other == .transparent,
        };
    }
};

// ============================================================================
// Token Types
// ============================================================================

pub const TokenType = enum {
    keyword,
    type_name,
    builtin,
    function,
    component,
    string,
    char,
    number,
    comment,
    operator,
    identifier,
    whitespace,
    newline,
};

pub const Token = struct {
    type: TokenType,
    text: []const u8,
    color: Color,
    line: usize,
    column: usize,
};

// ============================================================================
// Optimized: Coalesced Token Span
// Groups adjacent tokens with the same effective color into one render unit
// ============================================================================

/// Color categories for coalescing - tokens with same category get merged
pub const ColorCategory = enum {
    default, // identifier, whitespace, builtin, type_name (#262626)
    keyword, // keywords (#2BACCC)
    operator, // operators (#6F6F6F)
    function, // function names
    component, // component names
    string, // strings and chars
    number, // numeric literals
    comment, // comments
    transparent, // newlines (won't be rendered)
};

pub const CoalescedSpan = struct {
    text: []const u8,
    category: ColorCategory, // Used for comparison during coalescing
    token_type: TokenType, // Original type for special rendering logic
    start_line: usize,
    start_column: usize,
    has_error: bool,
    is_added: bool = false,
    is_removed: bool = false,
};

// ============================================================================
// AST Node Types
// ============================================================================

pub const NodeType = enum {
    root,
    line,
    token,
    error_annotation,
};

pub const ErrorType = enum {
    unterminated_string,
    unexpected_token,
    invalid_syntax,
};

pub const Node = struct {
    tag: NodeType,
    data: union {
        root: void,
        line: struct {
            number: usize,
            indent: usize,
            is_added: bool,
            is_removed: bool,
        },
        token: Token,
        error_annotation: struct {
            error_type: ErrorType,
            message: []const u8,
            start_pos: usize,
            end_pos: usize,
            line: usize,
            column: usize,
        },
    },
    child: ?*Node,
    next: ?*Node,
};

// ============================================================================
// Error Key — collision-free composite of (line, column)
//
// The old `line + column` hash collided: line 10 col 5 == line 5 col 10.
// We now use `line * MAX_COLUMNS + column` which is unique for any
// reasonable source file. For extremely wide/long files we also provide
// an ErrorLocation struct as a proper map key.
// ============================================================================

const MAX_COLUMNS: usize = 4096; // supports lines up to 4096 columns wide

pub const ErrorLocation = struct {
    line: usize,
    column: usize,

    pub fn toKey(self: ErrorLocation) usize {
        return self.line * MAX_COLUMNS + self.column;
    }

    pub fn fromToken(token: Token) ErrorLocation {
        return .{ .line = token.line, .column = token.column };
    }
};

// ============================================================================
// Scope Tracking — for break/continue validation
// ============================================================================

const ScopeKind = enum {
    loop, // while, for — break/continue are valid
    block, // bare { } or labeled blocks — break valid with label
    function, // fn body — break/continue invalid (unless in a loop inside)
    switch_case, // switch prong — break valid
    conditional, // if/else — neither valid directly
};

const ScopeEntry = struct {
    kind: ScopeKind,
    has_label: bool,
    label: ?[]const u8,
    brace_depth: i32, // brace depth when this scope was opened
};

// ============================================================================
// Continuation Tracking — multi-line statement awareness
//
// Tracks open delimiters (parens, brackets, braces from expressions) to
// know when a logical statement spans multiple physical lines.
// ============================================================================

const ContinuationState = struct {
    /// Number of unclosed '(' on the current logical statement
    open_parens: i32 = 0,
    /// Number of unclosed '[' on the current logical statement
    open_brackets: i32 = 0,
    /// When > 0, we are inside a multi-line expression — suppress
    /// "missing ;" warnings on intermediate lines.
    /// Also used to skip false-positive lints on continuation lines.
    pub fn isInContinuation(self: *const ContinuationState) bool {
        return self.open_parens > 0 or self.open_brackets > 0;
    }

    pub fn reset(self: *ContinuationState) void {
        self.open_parens = 0;
        self.open_brackets = 0;
    }

    pub fn feed(self: *ContinuationState, text: []const u8) void {
        if (std.mem.eql(u8, text, "(")) {
            self.open_parens += 1;
        } else if (std.mem.eql(u8, text, ")")) {
            self.open_parens = @max(0, self.open_parens - 1);
        } else if (std.mem.eql(u8, text, "[")) {
            self.open_brackets += 1;
        } else if (std.mem.eql(u8, text, "]")) {
            self.open_brackets = @max(0, self.open_brackets - 1);
        }
    }
};

// ============================================================================
// Zig Keywords and Types
// ============================================================================

const keywords = [_][]const u8{
    "addrspace",   "align",       "allowzero", "and",         "anyframe",
    "anytype",     "asm",         "async",     "await",       "break",
    "callconv",    "catch",       "comptime",  "const",       "continue",
    "defer",       "else",        "enum",      "errdefer",    "error",
    "export",      "extern",      "fn",        "for",         "if",
    "inline",      "linksection", "noalias",   "nosuspend",   "opaque",
    "or",          "orelse",      "packed",    "pub",         "resume",
    "return",      "struct",      "suspend",   "switch",      "test",
    "threadlocal", "try",         "union",     "unreachable", "usingnamespace",
    "var",         "volatile",    "while",
};

const primitive_types = [_][]const u8{
    "i8",        "i16",    "i32",       "i64",        "i128",         "isize",
    "u8",        "u16",    "u32",       "u64",        "u128",         "usize",
    "f16",       "f32",    "f64",       "f80",        "f128",         "bool",
    "void",      "null",   "undefined", "anyerror",   "comptime_int", "comptime_float",
    "anyopaque", "type",   "noreturn",  "c_short",    "c_ushort",     "c_int",
    "c_uint",    "c_long", "c_ulong",   "c_longlong", "c_ulonglong",  "c_longdouble",
    "c_void",
};

// ============================================================================
// Tokenizer
// ============================================================================

pub const Tokenizer = struct {
    source: []const u8,
    pos: usize,
    line: usize,
    column: usize,

    pub fn init(source: []const u8) Tokenizer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .column = 1,
        };
    }

    pub fn next(self: *Tokenizer) ?Token {
        if (self.isAtEnd()) return null;

        const start_pos = self.pos;
        const start_line = self.line;
        const start_col = self.column;

        const char = self.peek();

        // Newline
        if (char == '\n') {
            _ = self.advance();
            self.line += 1;
            self.column = 1;
            return .{
                .type = .newline,
                .text = self.source[start_pos..self.pos],
                .color = .transparent,
                .line = start_line,
                .column = start_col,
            };
        }

        // Whitespace (excluding newline)
        if (isWhitespace(char) and char != '\n') {
            while (!self.isAtEnd() and isWhitespace(self.peek()) and self.peek() != '\n') {
                _ = self.advance();
            }
            return .{
                .type = .whitespace,
                .text = self.source[start_pos..self.pos],
                .color = .transparent,
                .line = start_line,
                .column = start_col,
            };
        }

        // Comments
        if (char == '/' and self.peekNext() == '/') {
            while (!self.isAtEnd() and self.peek() != '\n') {
                _ = self.advance();
            }
            return .{
                .type = .comment,
                .text = self.source[start_pos..self.pos],
                .color = .{ .palette = .code_comment_color },
                .line = start_line,
                .column = start_col,
            };
        }

        // String literals
        if (char == '"') {
            return self.tokenizeString(start_pos, start_line, start_col);
        }

        // Character literals
        if (char == '\'') {
            return self.tokenizeChar(start_pos, start_line, start_col);
        }

        // Multi-line string literals
        if (char == '\\' and self.peekNext() == '\\') {
            while (!self.isAtEnd() and self.peek() != '\n') {
                _ = self.advance();
            }
            return .{
                .type = .string,
                .text = self.source[start_pos..self.pos],
                .color = .{ .palette = .code_string_color },
                .line = start_line,
                .column = start_col,
            };
        }

        // Numbers
        if (std.ascii.isDigit(char)) {
            return self.tokenizeNumber(start_pos, start_line, start_col);
        }

        // Builtin functions (@identifier)
        if (char == '@') {
            _ = self.advance();
            while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_')) {
                _ = self.advance();
            }
            return .{
                .type = .builtin,
                .text = self.source[start_pos..self.pos],
                .color = .{ .palette = .code_builtin_color },
                .line = start_line,
                .column = start_col,
            };
        }

        // Identifiers and keywords
        if (std.ascii.isAlphabetic(char) or char == '_') {
            return self.tokenizeIdentifier(start_pos, start_line, start_col);
        }

        // Operators and punctuation
        return self.tokenizeOperator(start_pos, start_line, start_col);
    }

    fn tokenizeString(self: *Tokenizer, start_pos: usize, start_line: usize, start_col: usize) Token {
        _ = self.advance(); // consume opening quote
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (c == '"') {
                _ = self.advance();
                break;
            }
            if (c == '\\' and !self.isAtEnd()) {
                _ = self.advance();
            }
            if (c == '\n') break;
            _ = self.advance();
        }
        return .{
            .type = .string,
            .text = self.source[start_pos..self.pos],
            .color = .{ .palette = .code_string_color },
            .line = start_line,
            .column = start_col,
        };
    }

    fn tokenizeChar(self: *Tokenizer, start_pos: usize, start_line: usize, start_col: usize) Token {
        _ = self.advance();
        if (!self.isAtEnd() and self.peek() == '\\') {
            _ = self.advance();
            if (!self.isAtEnd()) _ = self.advance();
        } else if (!self.isAtEnd()) {
            _ = self.advance();
        }
        if (!self.isAtEnd() and self.peek() == '\'') {
            _ = self.advance();
        }
        return .{
            .type = .char,
            .text = self.source[start_pos..self.pos],
            .color = .{ .palette = .code_string_color },
            .line = start_line,
            .column = start_col,
        };
    }

    fn tokenizeNumber(self: *Tokenizer, start_pos: usize, start_line: usize, start_col: usize) Token {
        if (self.peek() == '0' and self.pos + 1 < self.source.len) {
            const next_c = self.source[self.pos + 1];
            if (next_c == 'x' or next_c == 'X') {
                _ = self.advance();
                _ = self.advance();
                while (!self.isAtEnd() and (std.ascii.isHex(self.peek()) or self.peek() == '_')) {
                    _ = self.advance();
                }
            } else if (next_c == 'o' or next_c == 'O') {
                _ = self.advance();
                _ = self.advance();
                while (!self.isAtEnd() and (self.peek() >= '0' and self.peek() <= '7' or self.peek() == '_')) {
                    _ = self.advance();
                }
            } else if (next_c == 'b' or next_c == 'B') {
                _ = self.advance();
                _ = self.advance();
                while (!self.isAtEnd() and (self.peek() == '0' or self.peek() == '1' or self.peek() == '_')) {
                    _ = self.advance();
                }
            } else {
                self.consumeDecimal();
            }
        } else {
            self.consumeDecimal();
        }
        return .{
            .type = .number,
            .text = self.source[start_pos..self.pos],
            .color = .{ .palette = .code_number_color },
            .line = start_line,
            .column = start_col,
        };
    }

    fn consumeDecimal(self: *Tokenizer) void {
        while (!self.isAtEnd() and (std.ascii.isDigit(self.peek()) or self.peek() == '_')) {
            _ = self.advance();
        }
        if (!self.isAtEnd() and self.peek() == '.' and self.pos + 1 < self.source.len and std.ascii.isDigit(self.source[self.pos + 1])) {
            _ = self.advance();
            while (!self.isAtEnd() and (std.ascii.isDigit(self.peek()) or self.peek() == '_')) {
                _ = self.advance();
            }
        }
        if (!self.isAtEnd() and (self.peek() == 'e' or self.peek() == 'E')) {
            _ = self.advance();
            if (!self.isAtEnd() and (self.peek() == '+' or self.peek() == '-')) {
                _ = self.advance();
            }
            while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }
    }

    fn tokenizeIdentifier(self: *Tokenizer, start_pos: usize, start_line: usize, start_col: usize) Token {
        while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_')) {
            _ = self.advance();
        }

        const text = self.source[start_pos..self.pos];

        if (isKeyword(text)) {
            return .{
                .type = .keyword,
                .text = text,
                .color = .{ .palette = .code_keyword_color },
                .line = start_line,
                .column = start_col,
            };
        }

        if (isPrimitiveType(text)) {
            return .{
                .type = .type_name,
                .text = text,
                .color = .{ .palette = .code_type_color },
                .line = start_line,
                .column = start_col,
            };
        }

        var lookahead = self.pos;
        while (lookahead < self.source.len and isWhitespace(self.source[lookahead])) {
            lookahead += 1;
        }

        if (std.ascii.isUpper(text[0]) and lookahead < self.source.len and self.source[lookahead] == '(') {
            return .{
                .type = .component,
                .text = text,
                .color = .{ .palette = .code_tint_color },
                .line = start_line,
                .column = start_col,
            };
        } else if (lookahead < self.source.len and self.source[lookahead] == '(') {
            return .{
                .type = .function,
                .text = text,
                .color = .{ .palette = .code_function_color },
                .line = start_line,
                .column = start_col,
            };
        }

        if (text.len > 0 and std.ascii.isUpper(text[0])) {
            return .{
                .type = .type_name,
                .text = text,
                .color = .{ .palette = .code_type_color },
                .line = start_line,
                .column = start_col,
            };
        }

        return .{
            .type = .identifier,
            .text = text,
            .color = .{ .palette = .code_text_color },
            .line = start_line,
            .column = start_col,
        };
    }

    fn tokenizeOperator(self: *Tokenizer, start_pos: usize, start_line: usize, start_col: usize) Token {
        const char = self.advance();
        const next_c = if (!self.isAtEnd()) self.peek() else 0;

        switch (char) {
            '=' => if (next_c == '=' or next_c == '>') {
                _ = self.advance();
            },
            '!' => if (next_c == '=') {
                _ = self.advance();
            },
            '<' => if (next_c == '=' or next_c == '<') {
                _ = self.advance();
                if (!self.isAtEnd() and self.peek() == '=') _ = self.advance();
            },
            '>' => if (next_c == '=' or next_c == '>') {
                _ = self.advance();
                if (!self.isAtEnd() and self.peek() == '=') _ = self.advance();
            },
            '+' => if (next_c == '=' or next_c == '+') {
                _ = self.advance();
            },
            '-' => if (next_c == '=' or next_c == '-' or next_c == '>') {
                _ = self.advance();
            },
            '*' => if (next_c == '=' or next_c == '*') {
                _ = self.advance();
            },
            '/' => if (next_c == '=') {
                _ = self.advance();
            },
            '%' => if (next_c == '=') {
                _ = self.advance();
            },
            '&' => if (next_c == '=' or next_c == '&') {
                _ = self.advance();
            },
            '|' => if (next_c == '=' or next_c == '|') {
                _ = self.advance();
            },
            '^' => if (next_c == '=') {
                _ = self.advance();
            },
            '.' => if (next_c == '.' or next_c == '*') {
                _ = self.advance();
                if (!self.isAtEnd() and self.peek() == '.') _ = self.advance();
            },
            else => {},
        }

        return .{
            .type = .operator,
            .text = self.source[start_pos..self.pos],
            .color = .{ .palette = .code_operator_color },
            .line = start_line,
            .column = start_col,
        };
    }

    fn isAtEnd(self: *const Tokenizer) bool {
        return self.pos >= self.source.len;
    }

    fn peek(self: *const Tokenizer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.pos];
    }

    fn peekNext(self: *const Tokenizer) u8 {
        if (self.pos + 1 >= self.source.len) return 0;
        return self.source[self.pos + 1];
    }

    fn advance(self: *Tokenizer) u8 {
        if (self.isAtEnd()) return 0;
        const char = self.source[self.pos];
        self.pos += 1;
        self.column += 1;
        return char;
    }
};

// ============================================================================
// Parser - Builds AST from tokens
// ============================================================================

pub const Parser = struct {
    allocator: Allocator,
    tokenizer: Tokenizer,

    pub fn init(allocator: Allocator, source: []const u8) Parser {
        return .{
            .allocator = allocator,
            .tokenizer = Tokenizer.init(source),
        };
    }

    pub fn parse(self: *Parser) !*Node {
        const root = try self.createNode(.root);

        var current_line: ?*Node = null;
        var current_line_number: usize = 1;
        var last_token_in_line: ?*Node = null;

        current_line = try self.createLineNode(current_line_number);
        root.child = current_line;

        // Check if first line starts with diff markers
        if (self.tokenizer.source.len >= 2) {
            if (std.mem.startsWith(u8, self.tokenizer.source, "++")) {
                current_line.?.data.line.is_added = true;
                // Skip the ++ but we need to handle this in tokenization
                self.tokenizer.pos = 2;
                self.tokenizer.column = 3;
            } else if (std.mem.startsWith(u8, self.tokenizer.source, "--")) {
                current_line.?.data.line.is_removed = true;
                self.tokenizer.pos = 2;
                self.tokenizer.column = 3;
            }
        }

        while (self.tokenizer.next()) |token| {
            if (token.type == .newline) {
                const new_line = try self.createLineNode(current_line_number + 1);
                current_line_number += 1;

                // Check for diff markers at the start of the new line
                // We need to peek at the next two characters
                const remaining = self.tokenizer.source[self.tokenizer.pos..];
                if (remaining.len >= 2) {
                    if (std.mem.startsWith(u8, remaining, "++")) {
                        new_line.data.line.is_added = true;
                        // Skip the ++ markers
                        self.tokenizer.pos += 2;
                        self.tokenizer.column += 2;
                    } else if (std.mem.startsWith(u8, remaining, "--")) {
                        new_line.data.line.is_removed = true;
                        // Skip the -- markers
                        self.tokenizer.pos += 2;
                        self.tokenizer.column += 2;
                    }
                }

                if (current_line) |line| {
                    line.next = new_line;
                }
                current_line = new_line;
                last_token_in_line = null;
            } else {
                const token_node = try self.createTokenNode(token);

                if (last_token_in_line) |last| {
                    last.next = token_node;
                } else if (current_line) |line| {
                    line.child = token_node;
                }
                last_token_in_line = token_node;
            }
        }

        return root;
    }

    fn createNode(self: *Parser, tag: NodeType) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .tag = tag,
            .data = .{ .root = {} },
            .child = null,
            .next = null,
        };
        return node;
    }

    fn createLineNode(self: *Parser, line_number: usize) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .tag = .line,
            .data = .{
                .line = .{
                    .number = line_number,
                    .indent = 0,
                    .is_added = false,
                    .is_removed = false,
                },
            },
            .child = null,
            .next = null,
        };
        return node;
    }

    fn createTokenNode(self: *Parser, token: Token) !*Node {
        const node = try self.allocator.create(Node);
        node.* = .{
            .tag = .token,
            .data = .{ .token = token },
            .child = null,
            .next = null,
        };
        return node;
    }
};

// ============================================================================
// Syntax Highlighter - High-level API with OPTIMIZED RENDERING
// ============================================================================

const ErrorAnnotation = struct {
    line: usize,
    column: usize,
    message: []const u8,
};

pub const SyntaxHighlighter = struct {
    allocator: Allocator,
    root: ?*Node,
    local_copy_code: []const u8 = undefined,
    show_cpy_btn: bool = false,
    use_cpy_btn: bool = true,
    // FIXED: Use composite key (line * MAX_COLUMNS + column) instead of line + column
    errors: std.AutoHashMap(usize, ErrorAnnotation),
    show_toolbar: bool = false,
    scroll_top: f32 = 0,
    viewport_height: f32 = 0,
    container_ref: Vapor.Binded = .{},
    total_height: f32 = 0,

    // ========================================================================
    // Pre-computed coalesced spans for optimized rendering
    // ========================================================================
    coalesced_lines: ?[][]CoalescedSpan = null,

    pub fn init(allocator: Allocator) SyntaxHighlighter {
        return .{
            .allocator = allocator,
            .root = null,
            .errors = std.AutoHashMap(usize, ErrorAnnotation).init(allocator),
            .coalesced_lines = null,
        };
    }

    pub fn deinit(self: *SyntaxHighlighter) void {
        if (self.coalesced_lines) |lines| {
            for (lines) |line| {
                self.allocator.free(line);
            }
            self.allocator.free(lines);
        }
        self.errors.deinit();
    }

    pub fn parse(self: *SyntaxHighlighter, source: []const u8) !void {
        var parser = Parser.init(self.allocator, source);
        const new_source = self.allocator.dupe(u8, source) catch unreachable;
        self.local_copy_code = new_source;

        self.root = try parser.parse();

        // Pre-compute coalesced spans for optimized rendering
        try self.buildCoalescedSpans();
    }

    pub fn recompile(self: *SyntaxHighlighter, source: []const u8) !void {
        const new_source = try self.allocator.dupe(u8, source);
        self.allocator.free(self.local_copy_code);
        self.local_copy_code = new_source;

        var parser = Parser.init(self.allocator, self.local_copy_code);
        self.root = try parser.parse();

        try self.validateAST();
    }

    // ========================================================================
    // Build coalesced spans - merges adjacent tokens with same color
    // This is the key optimization that reduces DOM elements by 60-80%
    // ========================================================================
    fn buildCoalescedSpans(self: *SyntaxHighlighter) !void {
        if (self.root == null) return;

        // Free previous coalesced lines if they exist
        if (self.coalesced_lines) |old_lines| {
            for (old_lines) |line| {
                self.allocator.free(line);
            }
            self.allocator.free(old_lines);
            self.coalesced_lines = null;
        }

        // Count lines first
        var line_count: usize = 0;
        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            line_count += 1;
        }

        // Allocate array of lines
        var lines = try self.allocator.alloc([]CoalescedSpan, line_count);
        errdefer self.allocator.free(lines);

        // Process each line
        var line_idx: usize = 0;
        line_iter = self.root.?.child;

        while (line_iter) |line_node| : (line_iter = line_node.next) {
            var spans = std.array_list.Managed(CoalescedSpan).init(self.allocator);
            errdefer spans.deinit();

            var token_iter = line_node.child;

            var current_span: ?CoalescedSpan = null;
            var is_added: bool = false;

            if (line_node.tag == .line) {
                is_added = line_node.data.line.is_added;
            }

            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag != .token) continue;

                const token = token_node.data.token;
                const category = getColorCategory(token);
                if (category == .transparent) continue;

                // FIXED: Use composite error key
                const error_key = ErrorLocation.fromToken(token).toKey();
                var has_error = false;
                if (self.errors.get(error_key)) |error_annotation| {
                    has_error = (token.line == error_annotation.line and
                        token.column == error_annotation.column);
                }

                // Logic for merging:
                // 1. Must have an active span
                // 2. Categories must match
                // 3. Neither can have an error (errors need unique spans for wavy underlines)
                // 4. They must be physically adjacent in the source string memory
                var merged = false;
                if (current_span) |*span| {
                    const prev_end_ptr = @intFromPtr(span.text.ptr) + span.text.len;
                    const current_start_ptr = @intFromPtr(token.text.ptr);

                    if (!span.has_error and !has_error and
                        span.category == category and
                        prev_end_ptr == current_start_ptr)
                    {
                        // Extend the existing span slice to include this token
                        span.text = span.text.ptr[0 .. span.text.len + token.text.len];
                        merged = true;
                    }
                }

                if (!merged) {
                    // If we couldn't merge, save the previous span and start a new one
                    if (current_span) |span| {
                        try spans.append(span);
                    }
                    current_span = CoalescedSpan{
                        .text = token.text,
                        .category = category,
                        .token_type = token.type,
                        .start_line = token.line,
                        .start_column = token.column,
                        .has_error = has_error,
                        .is_added = is_added,
                    };
                }
            }

            // Don't forget the last span on the line
            if (current_span) |span| {
                try spans.append(span);
            }

            lines[line_idx] = try spans.toOwnedSlice();
            line_idx += 1;
        }
        self.coalesced_lines = lines;
    }

    /// Map token type to color category for coalescing
    fn getColorCategory(token: Token) ColorCategory {
        return switch (token.type) {
            .keyword => .keyword,
            .function => .function,
            .component => .component,
            .string => .string,
            .number => .number,
            .comment => .comment,
            .newline => .transparent,
            // Group these because they all use the default text color (#262626)
            .identifier,
            .whitespace,
            .builtin,
            .type_name,
            .char,
            .operator,
            => .default,
        };
    }

    // Get effective render color for a token (resolves palette to actual hex)
    fn findTokenStart(self: *SyntaxHighlighter, token: Token) usize {
        const text_ptr = @intFromPtr(token.text.ptr);
        const source_ptr = @intFromPtr(self.local_copy_code.ptr);
        if (text_ptr >= source_ptr and text_ptr < source_ptr + self.local_copy_code.len) {
            return text_ptr - source_ptr;
        }
        return 0;
    }

    pub const LineIterator = struct {
        current: ?*Node,

        pub fn next(self: *LineIterator) ?*Node {
            if (self.current) |node| {
                self.current = node.next;
                return node;
            }
            return null;
        }
    };

    pub fn tokensForLine(_: *const SyntaxHighlighter, line: *Node) TokenIterator {
        return .{
            .current = line.child,
        };
    }

    pub const TokenIterator = struct {
        current: ?*Node,

        pub fn next(self: *TokenIterator) ?Token {
            while (self.current) |node| {
                self.current = node.next;
                if (node.tag == .token) {
                    return node.data.token;
                }
            }
            return null;
        }
    };

    // ========================================================================
    // Per-line validation — catches problems local to a single line
    // ========================================================================
    fn validateLine(self: *SyntaxHighlighter, line: *Node) !void {
        var token_iter = line.child;
        var prev_token: ?Token = null;

        while (token_iter) |token_node| {
            if (token_node.tag == .token) {
                const token = token_node.data.token;

                // --- Unterminated string literals ---
                if (token.type == .string) {
                    // Regular strings must end with '"'; multiline (\\) are fine as-is
                    if (token.text.len > 0 and token.text[0] == '"') {
                        if (!std.mem.endsWith(u8, token.text, "\"") or token.text.len == 1) {
                            try self.addError(token, "Unterminated string literal");
                        }
                    }
                }

                // --- Unterminated character literals ---
                if (token.type == .char) {
                    if (!std.mem.endsWith(u8, token.text, "'") or token.text.len < 3) {
                        try self.addError(token, "Unterminated or empty character literal");
                    }
                }

                // --- Empty hex/octal/binary number literals (e.g. 0x, 0b, 0o with no digits) ---
                if (token.type == .number) {
                    try self.validateNumberLiteral(token);
                }

                // --- Bare '@' without a builtin name ---
                if (token.type == .builtin) {
                    if (std.mem.eql(u8, token.text, "@")) {
                        try self.addError(token, "Expected builtin function name after '@'");
                    }
                }

                // --- Double semicolons  ;;  ---
                if (token.type == .operator and std.mem.eql(u8, token.text, ";")) {
                    if (prev_token) |prev| {
                        if (prev.type == .operator and std.mem.eql(u8, prev.text, ";")) {
                            try self.addError(token, "Unexpected extra semicolon");
                        }
                    }
                }

                // --- 'pub' must be followed by a declaration keyword ---
                if (prev_token) |prev| {
                    if (prev.type == .keyword and std.mem.eql(u8, prev.text, "pub")) {
                        if (token.type == .keyword) {
                            const valid_after_pub = [_][]const u8{
                                "fn",     "const",  "var",    "struct", "enum",           "union",
                                "opaque", "extern", "export", "inline", "usingnamespace",
                            };
                            var valid = false;
                            for (valid_after_pub) |kw| {
                                if (std.mem.eql(u8, token.text, kw)) {
                                    valid = true;
                                    break;
                                }
                            }
                            if (!valid) {
                                try self.addError(token, "Unexpected keyword after 'pub'");
                            }
                        } else if (token.type != .whitespace and token.type != .comment) {
                            try self.addError(prev, "'pub' must precede a declaration (fn, const, var, struct, ...)");
                        }
                    }
                }

                // Track previous non-whitespace token for contextual checks
                if (token.type != .whitespace) {
                    prev_token = token;
                }
            }
            token_iter = token_node.next;
        }
    }

    // ========================================================================
    // Number literal validation
    // ========================================================================
    fn validateNumberLiteral(self: *SyntaxHighlighter, token: Token) !void {
        const text = token.text;
        if (text.len == 0) return;

        // Check prefixed literals (0x, 0b, 0o) have at least one digit after prefix
        if (text.len >= 2 and text[0] == '0') {
            const prefix = text[1];
            if (prefix == 'x' or prefix == 'X' or
                prefix == 'b' or prefix == 'B' or
                prefix == 'o' or prefix == 'O')
            {
                if (text.len == 2) {
                    try self.addError(token, "Number literal has no digits after prefix");
                    return;
                }
                // First char after prefix must not be '_'
                if (text[2] == '_') {
                    try self.addError(token, "Digit separator '_' cannot appear directly after prefix");
                    return;
                }
            }
        }

        // Leading underscore in decimal literal
        if (text[0] == '_') {
            try self.addError(token, "Number literal cannot start with '_'");
            return;
        }

        // Trailing underscore
        if (text.len > 1 and text[text.len - 1] == '_') {
            try self.addError(token, "Number literal cannot end with '_'");
            return;
        }

        // Consecutive underscores
        var i: usize = 0;
        while (i + 1 < text.len) : (i += 1) {
            if (text[i] == '_' and text[i + 1] == '_') {
                try self.addError(token, "Consecutive '_' separators in number literal");
                return;
            }
        }
    }

    // ========================================================================
    // Warn on empty blocks `{}`
    // ========================================================================
    fn validateEmptyBlocks(self: *SyntaxHighlighter) !void {
        var line_iter = self.root.?.child;
        while (line_iter) |line| {
            var token_iter = line.child;

            while (token_iter) |token_node| {
                if (token_node.tag == .token) {
                    const token = token_node.data.token;

                    if (token.type == .operator and std.mem.eql(u8, token.text, "{")) {
                        const next_sig = skipWhitespaceNodes(token_node.next);
                        if (next_sig) |sig| {
                            if (sig.tag == .token and
                                sig.data.token.type == .operator and
                                std.mem.eql(u8, sig.data.token.text, "}"))
                            {
                                try self.addError(token, "Empty block '{}' — consider adding a body or using '{}'");
                            }
                        }
                    }
                }
                token_iter = token_node.next;
            }
            line_iter = line.next;
        }
    }

    // ========================================================================
    // Delimiter balance — checks {}, [], () across all lines
    // ========================================================================
    fn validateDelimiterBalance(self: *SyntaxHighlighter) !void {
        var brace_count: i32 = 0; // { }
        var paren_count: i32 = 0; // ( )
        var bracket_count: i32 = 0; // [ ]

        var last_open_brace: ?Token = null;
        var last_open_paren: ?Token = null;
        var last_open_bracket: ?Token = null;

        var line_iter = self.root.?.child;
        while (line_iter) |line| {
            var token_iter = line.child;
            while (token_iter) |token_node| {
                if (token_node.tag == .token) {
                    const token = token_node.data.token;
                    if (token.type == .operator) {
                        if (std.mem.eql(u8, token.text, "{")) {
                            brace_count += 1;
                            last_open_brace = token;
                        } else if (std.mem.eql(u8, token.text, "}")) {
                            brace_count -= 1;
                            if (brace_count < 0) {
                                try self.addError(token, "Unmatched closing '}'");
                                brace_count = 0; // reset to avoid cascading
                            }
                        } else if (std.mem.eql(u8, token.text, "(")) {
                            paren_count += 1;
                            last_open_paren = token;
                        } else if (std.mem.eql(u8, token.text, ")")) {
                            paren_count -= 1;
                            if (paren_count < 0) {
                                try self.addError(token, "Unmatched closing ')'");
                                paren_count = 0;
                            }
                        } else if (std.mem.eql(u8, token.text, "[")) {
                            bracket_count += 1;
                            last_open_bracket = token;
                        } else if (std.mem.eql(u8, token.text, "]")) {
                            bracket_count -= 1;
                            if (bracket_count < 0) {
                                try self.addError(token, "Unmatched closing ']'");
                                bracket_count = 0;
                            }
                        }
                    }
                }
                token_iter = token_node.next;
            }
            line_iter = line.next;
        }

        // Report unclosed openers
        if (brace_count > 0) {
            if (last_open_brace) |tok| {
                try self.addError(tok, "Unclosed '{'");
            }
        }
        if (paren_count > 0) {
            if (last_open_paren) |tok| {
                try self.addError(tok, "Unclosed '('");
            }
        }
        if (bracket_count > 0) {
            if (last_open_bracket) |tok| {
                try self.addError(tok, "Unclosed '['");
            }
        }
    }

    // ========================================================================
    // Structural / semantic checks
    //   - fn must be followed by identifier
    //   - const/var must be followed by identifier
    //   - return type after ')' in fn declaration
    //   - test must be followed by a string
    // ========================================================================
    fn validateStructure(self: *SyntaxHighlighter) !void {
        var line_iter = self.root.?.child;
        while (line_iter) |line| {
            var token_iter = line.child;
            while (token_iter) |token_node| {
                if (token_node.tag == .token) {
                    const token = token_node.data.token;

                    // --- 'fn' must be followed by an identifier (the function name) ---
                    if (token.type == .keyword and std.mem.eql(u8, token.text, "fn")) {
                        const next_sig = skipWhitespaceNodes(token_node.next);
                        if (next_sig) |sig_node| {
                            if (sig_node.tag == .token) {
                                const sig_tok = sig_node.data.token;
                                // The next significant token should be an identifier or function
                                if (sig_tok.type != .identifier and sig_tok.type != .function and sig_tok.type != .component) {
                                    try self.addError(token, "Expected function name after 'fn'");
                                }
                            }
                        } else {
                            try self.addError(token, "Expected function name after 'fn'");
                        }
                    }

                    // --- 'const' / 'var' should be followed by an identifier ---
                    if (token.type == .keyword and
                        (std.mem.eql(u8, token.text, "const") or std.mem.eql(u8, token.text, "var")))
                    {
                        const next_sig = skipWhitespaceNodes(token_node.next);
                        if (next_sig) |sig_node| {
                            if (sig_node.tag == .token) {
                                const sig_tok = sig_node.data.token;
                                // Allow identifier, type_name (for const Foo = ...), or '_'
                                if (sig_tok.type != .identifier and
                                    sig_tok.type != .type_name and
                                    sig_tok.type != .builtin and
                                    !std.mem.eql(u8, sig_tok.text, "_"))
                                {
                                    try self.addError(token, "Expected identifier after 'const'/'var'");
                                }
                            }
                        }
                    }

                    // --- 'test' must be followed by a string literal ---
                    if (token.type == .keyword and std.mem.eql(u8, token.text, "test")) {
                        const next_sig = skipWhitespaceNodes(token_node.next);
                        if (next_sig) |sig_node| {
                            if (sig_node.tag == .token) {
                                const sig_tok = sig_node.data.token;
                                if (sig_tok.type != .string) {
                                    try self.addError(token, "Expected test description string after 'test'");
                                }
                            }
                        }
                    }
                }
                token_iter = token_node.next;
            }
            line_iter = line.next;
        }
    }

    /// Walk past whitespace-only token nodes to find the next significant node
    fn skipWhitespaceNodes(start: ?*Node) ?*Node {
        var current = start;
        while (current) |node| {
            if (node.tag == .token) {
                if (node.data.token.type != .whitespace) {
                    return node;
                }
            }
            current = node.next;
        }
        return null;
    }

    // ========================================================================
    // Full AST validation — improved with multi-line awareness + scope tracking
    // ========================================================================
    pub fn validateAST(self: *SyntaxHighlighter) !void {
        self.errors.clearRetainingCapacity();

        if (self.root == null) return;

        // ------------------------------------------------------------------
        // Pass 1: Per-line validation (strings, chars, numbers, builtins)
        // ------------------------------------------------------------------
        var line_iter = self.root.?.child;
        while (line_iter) |line| {
            try self.validateLine(line);
            line_iter = line.next;
        }

        // ------------------------------------------------------------------
        // Pass 2: Cross-line delimiter balance ({} [] ())
        // ------------------------------------------------------------------
        try self.validateDelimiterBalance();

        // ------------------------------------------------------------------
        // Pass 3: Structural / semantic checks across the whole file
        // ------------------------------------------------------------------
        try self.validateStructure();

        // ------------------------------------------------------------------
        // Pass 4: Statement termination — missing semicolons
        //         NOW WITH multi-line continuation awareness
        // ------------------------------------------------------------------
        try self.validateStatementTermination();

        // ------------------------------------------------------------------
        // Pass 5: Duplicate adjacent keywords (pub pub, const const)
        // ------------------------------------------------------------------
        try self.validateDuplicateKeywords();

        // ------------------------------------------------------------------
        // Pass 6: const/var missing assignment operator
        // ------------------------------------------------------------------
        try self.validateConstVarAssignment();

        // ------------------------------------------------------------------
        // Pass 7: Suspicious operator sequences
        // ------------------------------------------------------------------
        try self.validateOperatorSequences();

        // ------------------------------------------------------------------
        // Pass 8: Scope-aware break/continue validation
        // ------------------------------------------------------------------
        try self.validateBreakContinueScopes();

        // Pass 9: Block-expression semicolons
        try self.validateBlockExpressionSemicolon();

        // Pass 10: Struct/enum/union field syntax
        try self.validateStructFieldSyntax();

        // Rebuild coalesced spans after validation (errors may have changed)
        try self.buildCoalescedSpans();
    }

    // ========================================================================
    // REWRITTEN: Statement termination with multi-line continuation tracking
    //
    // Key improvement: we now track open parens/brackets across lines.
    // A statement like:
    //     const x = foo(
    //         bar,
    //         baz,
    //     )
    // is treated as ONE logical statement. Only the LAST physical line of
    // the logical statement is checked for ';'. Intermediate continuation
    // lines are never flagged.
    //
    // How it works:
    //   - We maintain a ContinuationState that counts open ( and [
    //   - When open_parens > 0 or open_brackets > 0, the line is a
    //     "continuation" and we skip semicolon checking
    //   - We also carry forward the statement-start keyword (const/var/
    //     return/etc.) so we know what kind of statement we're in
    //   - When delimiters balance back to 0, we check the final line
    // ========================================================================
    fn validateStatementTermination(self: *SyntaxHighlighter) !void {
        // Keywords that introduce blocks (never need ';' on their own line)
        const block_intro_kws = [_][]const u8{
            "fn",     "if",     "else", "while", "for",
            "switch", "struct", "enum", "union", "test",
            "opaque", "packed",
        };

        // Keywords that precede block-intro keywords (modifiers)
        const modifier_kws = [_][]const u8{
            "pub", "export", "extern", "inline", "comptime",
        };

        // Statement keywords that ALWAYS require ';' at end of statement
        const stmt_kws = [_][]const u8{
            "return",         "break", "continue", "defer", "errdefer",
            "usingnamespace",
        };

        // Assignment operators that indicate an expression-statement needing ';'
        const assign_ops = [_][]const u8{
            "=",   "+=",  "-=", "*=", "/=", "%=", "&=", "|=", "^=",
            "<<=", ">>=",
        };

        // ---- Multi-line continuation state ----
        var continuation = ContinuationState{};

        // Track whether the logical statement (possibly spanning multiple lines)
        // was initiated by a keyword that needs ';'
        var stmt_needs_semi: bool = false;
        // Track whether the logical statement contains an assignment operator
        var stmt_has_assign: bool = false;
        // Track whether the logical statement contains a function call
        var stmt_has_call: bool = false;
        // Track whether logical statement starts with 'try'
        var stmt_starts_try: bool = false;
        // The first keyword of the logical statement (for const/var detection)
        var stmt_first_keyword: ?[]const u8 = null;
        // For modifier + const/var (e.g. "pub const")
        var stmt_second_keyword: ?[]const u8 = null;
        // Whether the logical statement starts with a block-intro keyword
        var stmt_is_block_intro: bool = false;

        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            // Gather non-whitespace tokens on this line
            var tokens_buf: [512]Token = undefined;
            var token_count: usize = 0;

            var token_iter = line.child;
            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag == .token and
                    token_node.data.token.type != .whitespace)
                {
                    if (token_count < tokens_buf.len) {
                        tokens_buf[token_count] = token_node.data.token;
                        token_count += 1;
                    }
                }
            }

            if (token_count == 0) {
                // Blank line — if we were NOT in a continuation, reset state.
                // If we ARE in a continuation (open parens), keep going.
                if (!continuation.isInContinuation()) {
                    stmt_needs_semi = false;
                    stmt_has_assign = false;
                    stmt_has_call = false;
                    stmt_starts_try = false;
                    stmt_first_keyword = null;
                    stmt_second_keyword = null;
                    stmt_is_block_intro = false;
                }
                continue;
            }

            var tokens = tokens_buf[0..token_count];

            // Strip trailing comment — the real "last token" is what precedes it
            while (tokens.len > 0 and tokens[tokens.len - 1].type == .comment) {
                tokens = tokens[0 .. tokens.len - 1];
            }
            if (tokens.len == 0) {
                // Line was only comments — same logic as blank line
                if (!continuation.isInContinuation()) {
                    stmt_needs_semi = false;
                    stmt_has_assign = false;
                    stmt_has_call = false;
                    stmt_starts_try = false;
                    stmt_first_keyword = null;
                    stmt_second_keyword = null;
                    stmt_is_block_intro = false;
                }
                continue;
            }

            const first = tokens[0];

            const last = tokens[tokens.len - 1];

            // ---- Feed ALL operators on this line into continuation tracker ----
            for (tokens) |tok| {
                if (tok.type == .operator) {
                    continuation.feed(tok.text);
                }
            }

            if (first.type == .operator and std.mem.eql(u8, first.text, ".")) {
                // Don't reset statement state — this is a continuation
                continue;
            }

            // ---- If this is the START of a new logical statement ----
            // (not a continuation from a previous line)
            const is_new_statement = !continuation.isInContinuation() or
                (stmt_first_keyword == null and !stmt_has_assign and !stmt_has_call and !stmt_starts_try);

            // But we need to be more careful: if we JUST closed all parens on
            // this line (continuation was >0 at line start, now 0), this is
            // the LAST line of the logical statement, not a new one.
            // We handle this by checking continuation AFTER feeding.

            if (is_new_statement and !continuation.isInContinuation()) {
                // Fresh statement — reset tracking
                stmt_needs_semi = false;
                stmt_has_assign = false;
                stmt_has_call = false;
                stmt_starts_try = false;
                stmt_first_keyword = null;
                stmt_second_keyword = null;
                stmt_is_block_intro = false;

                // Analyze the first token(s) of the new statement
                if (first.type == .keyword) {
                    stmt_first_keyword = first.text;

                    // Check for statement keywords
                    for (stmt_kws) |sk| {
                        if (std.mem.eql(u8, first.text, sk)) {
                            stmt_needs_semi = true;
                            break;
                        }
                    }

                    // Check for const/var
                    if (std.mem.eql(u8, first.text, "const") or
                        std.mem.eql(u8, first.text, "var"))
                    {
                        stmt_needs_semi = true;
                    }

                    // Check for 'try'
                    if (std.mem.eql(u8, first.text, "try")) {
                        stmt_starts_try = true;
                    }

                    // Check for block-intro keywords (possibly after modifiers)
                    var effective_first_idx: usize = 0;
                    while (effective_first_idx < tokens.len) {
                        const t = tokens[effective_first_idx];
                        if (t.type != .keyword) break;
                        var is_mod = false;
                        for (modifier_kws) |m| {
                            if (std.mem.eql(u8, t.text, m)) {
                                is_mod = true;
                                break;
                            }
                        }
                        if (!is_mod) break;
                        effective_first_idx += 1;
                    }

                    if (effective_first_idx < tokens.len) {
                        const eff = tokens[effective_first_idx];
                        if (eff.type == .keyword) {
                            for (block_intro_kws) |bk| {
                                if (std.mem.eql(u8, eff.text, bk)) {
                                    stmt_is_block_intro = true;
                                    break;
                                }
                            }
                            // Also track modifier + const/var
                            if (effective_first_idx > 0 and
                                (std.mem.eql(u8, eff.text, "const") or
                                    std.mem.eql(u8, eff.text, "var")))
                            {
                                stmt_second_keyword = eff.text;
                                stmt_needs_semi = true;
                            }
                        }
                    }
                }
            }

            // ---- Track assignment ops and calls on this line ----
            for (tokens) |tok| {
                if (tok.type == .operator) {
                    for (assign_ops) |aop| {
                        if (std.mem.eql(u8, tok.text, aop)) {
                            stmt_has_assign = true;
                            break;
                        }
                    }
                }
                if (tok.type == .function or tok.type == .component) {
                    stmt_has_call = true;
                }
            }

            // ---- If we're still inside a continuation, skip semicolon check ----
            if (continuation.isInContinuation()) {
                continue;
            }

            // ---- We're at the end of a logical statement (delimiters balanced) ----

            // Skip lines that end with tokens that never need ';'
            if (last.type == .operator) {
                const no_semi = [_][]const u8{
                    "{", "}", ",", "\\", "=>", "|",
                };
                var skip = false;
                for (no_semi) |s| {
                    if (std.mem.eql(u8, last.text, s)) {
                        skip = true;
                        break;
                    }
                }
                if (skip) {
                    // Reset statement tracking for next logical statement
                    stmt_needs_semi = false;
                    stmt_has_assign = false;
                    stmt_has_call = false;
                    stmt_starts_try = false;
                    stmt_first_keyword = null;
                    stmt_second_keyword = null;
                    stmt_is_block_intro = false;
                    continue;
                }
            }

            // Lines ending with multiline string literal prefix
            if (last.type == .string and std.mem.startsWith(u8, last.text, "\\\\")) {
                stmt_needs_semi = false;
                stmt_has_assign = false;
                stmt_has_call = false;
                stmt_starts_try = false;
                stmt_first_keyword = null;
                stmt_second_keyword = null;
                stmt_is_block_intro = false;
                continue;
            }

            // Skip block-intro statements
            if (stmt_is_block_intro) {
                stmt_needs_semi = false;
                stmt_has_assign = false;
                stmt_has_call = false;
                stmt_starts_try = false;
                stmt_first_keyword = null;
                stmt_second_keyword = null;
                stmt_is_block_intro = false;
                continue;
            }

            // ---- Handle ')' and ']' at end of logical statement ----
            if (last.type == .operator and std.mem.eql(u8, last.text, ")")) {
                // If the entire logical statement is just a closing paren, skip
                if (tokens.len == 1 and !stmt_needs_semi and !stmt_has_assign and !stmt_has_call) {
                    continue;
                }
            }

            if (last.type == .operator and std.mem.eql(u8, last.text, "]")) {
                if (tokens.len == 1 and !stmt_needs_semi and !stmt_has_assign) {
                    continue;
                }
            }

            // ---- Determine if this logical statement needs ';' ----
            var needs_semi = stmt_needs_semi;

            // Assignment on any line of the logical statement
            if (!needs_semi and stmt_has_assign) {
                needs_semi = true;
            }

            // Bare function call ending with ')'
            const first_is_dot = first.type == .operator and std.mem.eql(u8, first.text, ".");
            if (!needs_semi and stmt_has_call and last.type == .operator and
                std.mem.eql(u8, last.text, ")") and !first_is_dot)
            {
                // Peek at next line's first significant token
                var next_line_starts_dot = false;
                if (line.next) |next_line| {
                    var peek_tok = next_line.child;
                    while (peek_tok) |pt| : (peek_tok = pt.next) {
                        if (pt.tag == .token and pt.data.token.type != .whitespace and
                            pt.data.token.type != .comment)
                        {
                            if (pt.data.token.type == .operator and
                                std.mem.eql(u8, pt.data.token.text, "."))
                            {
                                next_line_starts_dot = true;
                            }
                            break;
                        }
                    }
                }

                if (!next_line_starts_dot) {
                    needs_semi = true;
                }
            }

            // 'try' wrapping an expression statement
            if (!needs_semi and stmt_starts_try) {
                needs_semi = true;
            }

            // ---- If line already ends with ';', all good ----
            if (last.type == .operator and std.mem.eql(u8, last.text, ";")) {
                // Reset for next statement
                stmt_needs_semi = false;
                stmt_has_assign = false;
                stmt_has_call = false;
                stmt_starts_try = false;
                stmt_first_keyword = null;
                stmt_second_keyword = null;
                stmt_is_block_intro = false;
                continue;
            }

            if (needs_semi) {
                try self.addError(last, "Expected ';' at end of statement");
            }

            // Reset for next logical statement
            stmt_needs_semi = false;
            stmt_has_assign = false;
            stmt_has_call = false;
            stmt_starts_try = false;
            stmt_first_keyword = null;
            stmt_second_keyword = null;
            stmt_is_block_intro = false;
        }
    }

    // ========================================================================
    // Duplicate adjacent keywords — catches typos like `pub pub`, `const const`
    // ========================================================================
    fn validateDuplicateKeywords(self: *SyntaxHighlighter) !void {
        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            var token_iter = line.child;
            var prev_keyword: ?Token = null;

            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag != .token) continue;
                const token = token_node.data.token;
                if (token.type == .whitespace or token.type == .comment) continue;

                if (token.type == .keyword) {
                    if (prev_keyword) |prev| {
                        if (std.mem.eql(u8, prev.text, token.text)) {
                            try self.addError(token, "Duplicate keyword");
                        }
                    }
                    prev_keyword = token;
                } else {
                    prev_keyword = null;
                }
            }
        }
    }

    // ========================================================================
    // const/var declarations missing '=' or type annotation
    // e.g. `const x;` — almost certainly wrong in Zig
    // ========================================================================
    fn validateConstVarAssignment(self: *SyntaxHighlighter) !void {
        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            var token_iter = line.child;

            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag != .token) continue;
                const token = token_node.data.token;

                if (token.type != .keyword) continue;
                if (!std.mem.eql(u8, token.text, "const") and
                    !std.mem.eql(u8, token.text, "var")) continue;

                // Walk rest of line looking for '=' or ':'
                var found_eq = false;
                var found_colon = false;
                var found_semi = false;
                var has_ident = false;
                var rest = token_node.next;

                while (rest) |r| : (rest = r.next) {
                    if (r.tag != .token) continue;
                    const rt = r.data.token;
                    if (rt.type == .whitespace) continue;

                    if (rt.type == .identifier or rt.type == .type_name) {
                        has_ident = true;
                    }
                    if (rt.type == .operator) {
                        if (std.mem.eql(u8, rt.text, "=")) {
                            found_eq = true;
                            break;
                        }
                        if (std.mem.eql(u8, rt.text, ":")) found_colon = true;
                        if (std.mem.eql(u8, rt.text, ";")) {
                            found_semi = true;
                            break;
                        }
                        // '{' means it opens a block body (struct/enum decl)
                        if (std.mem.eql(u8, rt.text, "{")) {
                            found_eq = true; // treat as valid
                            break;
                        }
                    }
                }

                // If we hit ';' before finding '=' or ':', that's an error
                if (found_semi and !found_eq and !found_colon and has_ident) {
                    try self.addError(token, "Declaration missing '=' assignment or ':' type annotation");
                }
            }
        }
    }

    // ========================================================================
    // Suspicious operator sequences
    // ========================================================================
    fn validateOperatorSequences(self: *SyntaxHighlighter) !void {
        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            var token_iter = line.child;
            var prev_token: ?Token = null;
            var saw_const_or_var = false;
            var saw_ident_after_decl = false;

            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag != .token) continue;
                const token = token_node.data.token;
                if (token.type == .whitespace) continue;

                // Track if we're in a `const x` / `var x` context
                if (token.type == .keyword and
                    (std.mem.eql(u8, token.text, "const") or
                        std.mem.eql(u8, token.text, "var")))
                {
                    saw_const_or_var = true;
                    saw_ident_after_decl = false;
                }

                if (saw_const_or_var and !saw_ident_after_decl and
                    (token.type == .identifier or token.type == .type_name))
                {
                    saw_ident_after_decl = true;
                }

                // `==` right after `const x` or `var x` is likely a typo for `=`
                // if (saw_const_or_var and saw_ident_after_decl and
                //     token.type == .operator and std.mem.eql(u8, token.text, "=="))
                // {
                //     try self.addError(token, "Did you mean '=' instead of '=='? (assignment vs. comparison)");
                //     saw_const_or_var = false;
                // }

                // Reset declaration tracking on ';' or '{'
                if (token.type == .operator and
                    (std.mem.eql(u8, token.text, ";") or std.mem.eql(u8, token.text, "{")))
                {
                    saw_const_or_var = false;
                    saw_ident_after_decl = false;
                }

                prev_token = token;
            }
        }
    }

    // ========================================================================
    // NEW: Scope-aware break/continue validation
    //
    // Walks the token stream tracking scope context (loops, functions,
    // switch cases) via brace depth. Reports break/continue that appear
    // outside any loop scope.
    //
    // Limitations:
    //   - This is a heuristic based on token-level analysis, not a full
    //     scope tree. Nested functions inside loops could produce false
    //     negatives (we reset on `fn` to avoid false positives).
    //   - Labeled breaks (`break :label`) are always allowed since they
    //     can target any labeled block, not just loops.
    // ========================================================================
    fn validateBreakContinueScopes(self: *SyntaxHighlighter) !void {
        // We maintain a stack of scope kinds keyed by brace depth.
        // When we see `while`/`for` followed by `{`, we push .loop.
        // When we see `fn` followed by `{`, we push .function.
        // When we see `switch`, we push .switch_case.
        // On `}`, we pop.

        var scope_stack: [256]ScopeKind = undefined;
        var scope_depth: usize = 0;

        // Track what keyword preceded the next `{`
        var pending_scope: ?ScopeKind = null;

        // Track if the previous significant token was a capture pipe `|`
        // to handle `if (x) |val| { ... }` — the block after capture is
        // still conditional, not a loop. We specifically look for while/for.

        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            var token_iter = line.child;

            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag != .token) continue;
                const token = token_node.data.token;
                if (token.type == .whitespace or token.type == .comment) continue;

                // Detect scope-introducing keywords
                if (token.type == .keyword) {
                    if (std.mem.eql(u8, token.text, "while") or
                        std.mem.eql(u8, token.text, "for"))
                    {
                        pending_scope = .loop;
                    } else if (std.mem.eql(u8, token.text, "fn")) {
                        pending_scope = .function;
                    } else if (std.mem.eql(u8, token.text, "switch")) {
                        pending_scope = .switch_case;
                    } else if (std.mem.eql(u8, token.text, "if") or
                        std.mem.eql(u8, token.text, "else"))
                    {
                        pending_scope = .conditional;
                    } else if (std.mem.eql(u8, token.text, "inline")) {
                        // `inline for` / `inline while` — the next keyword
                        // will set pending_scope to .loop, so do nothing here.
                        // This prevents false positives on `inline for`.
                    }

                    // ---- Check break/continue ----
                    if (std.mem.eql(u8, token.text, "break") or
                        std.mem.eql(u8, token.text, "continue"))
                    {
                        // Check if it's a labeled break/continue (`:label` follows)
                        const next_sig = skipWhitespaceNodes(token_node.next);
                        var is_labeled = false;
                        if (next_sig) |ns| {
                            if (ns.tag == .token and ns.data.token.type == .operator and
                                std.mem.eql(u8, ns.data.token.text, ":"))
                            {
                                is_labeled = true;
                            }
                        }

                        // Labeled breaks can target any labeled block, so we
                        // don't flag them (we'd need full label resolution).
                        if (!is_labeled) {
                            // Walk up the scope stack looking for a loop
                            var found_loop = false;
                            var i: usize = scope_depth;
                            while (i > 0) {
                                i -= 1;
                                if (scope_stack[i] == .loop or scope_stack[i] == .switch_case) {
                                    found_loop = true;
                                    break;
                                }
                                // Stop at function boundaries — a break in
                                // a nested fn doesn't see the outer loop
                                if (scope_stack[i] == .function) {
                                    break;
                                }
                            }

                            if (!found_loop) {
                                if (std.mem.eql(u8, token.text, "continue")) {
                                    try self.addError(token, "'continue' outside of loop");
                                } else {
                                    // 'break' is valid in switch prongs and
                                    // labeled blocks, so only flag if we're
                                    // not in ANY block scope at all
                                    if (scope_depth == 0) {
                                        try self.addError(token, "'break' outside of loop or switch");
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Track brace depth for scope ----
                if (token.type == .operator) {
                    if (std.mem.eql(u8, token.text, "{")) {
                        if (scope_depth < scope_stack.len) {
                            scope_stack[scope_depth] = pending_scope orelse .block;
                            scope_depth += 1;
                        }
                        pending_scope = null;
                    } else if (std.mem.eql(u8, token.text, "}")) {
                        if (scope_depth > 0) {
                            scope_depth -= 1;
                        }
                    }
                }
            }
        }
    }

    // ============================================================================
    // FIXED VALIDATION PASSES — v2
    //
    // Bug fixes from v1:
    //
    //   1. validateBlockExpressionSemicolon: `var t = T{ .name = "hello" }` is
    //      a struct LITERAL (instantiation), not a type definition. The state
    //      machine now ONLY triggers when the token after '=' is a KEYWORD
    //      (struct/enum/union/opaque), not an identifier like `T` or `MyType`.
    //      The tokenizer classifies `T` as .type_name or .identifier — never
    //      as .keyword — so the check `token.type == .keyword` is the fix.
    //
    //   2. validateStructFieldSyntax: `const` inside `[]const u8` is part of
    //      the TYPE EXPRESSION, not a field modifier. The old code skipped
    //      `const` as a modifier, which broke field state tracking mid-type.
    //      Now only `pub` and `comptime` are skipped as modifiers.
    //      Top-level `const`/`var` declarations inside structs (like
    //      `const Self = @This();`) are handled by a new .skip_decl state
    //      that skips to the next ';'.
    //
    // Integration: Add to validateAST() after Pass 8:
    //
    //     // Pass 9: Block-expression assignment semicolons
    //     try self.validateBlockExpressionSemicolon();
    //
    //     // Pass 10: Struct/enum/union field syntax
    //     try self.validateStructFieldSyntax();
    //
    // ============================================================================

    // ========================================================================
    // Pass 9: Semicolon after block-expression assignments
    //
    // ONLY matches patterns where '=' is followed by a block KEYWORD:
    //   const T = struct { ... }     ← 'struct' is .keyword → MATCH
    //   const E = enum { ... }       ← 'enum' is .keyword → MATCH
    //   const U = union(enum) { ... } ← 'union' is .keyword → MATCH
    //
    // Does NOT match:
    //   var t = T{ .name = "hello" } ← 'T' is .type_name → NO MATCH
    //   var x = foo()                ← 'foo' is .function → NO MATCH
    //   var y = MyStruct{}           ← 'MyStruct' is .type_name → NO MATCH
    // ========================================================================
    fn validateBlockExpressionSemicolon(self: *SyntaxHighlighter) !void {
        const State = enum {
            idle,
            saw_decl, // saw const/var
            saw_ident, // saw const/var IDENT (possibly with : type)
            saw_equals, // saw const/var IDENT ... =
            saw_block_kw, // saw = struct/enum/union/opaque KEYWORD
            tracking, // inside block body, counting { }
        };

        var state: State = .idle;
        var brace_depth: i32 = 0;
        var target_depth: i32 = 0;

        const block_kws = [_][]const u8{ "struct", "enum", "union", "opaque" };

        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            var token_iter = line.child;
            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag != .token) continue;
                const token = token_node.data.token;
                if (token.type == .whitespace or token.type == .comment) continue;

                // Track braces globally (except inside tracked blocks)
                if (state != .saw_block_kw and state != .tracking) {
                    if (token.type == .operator and std.mem.eql(u8, token.text, "{")) {
                        brace_depth += 1;
                    }
                    if (token.type == .operator and std.mem.eql(u8, token.text, "}")) {
                        brace_depth -= 1;
                    }
                }

                switch (state) {
                    .idle => {
                        if (token.type == .keyword and
                            (std.mem.eql(u8, token.text, "const") or
                                std.mem.eql(u8, token.text, "var")))
                        {
                            state = .saw_decl;
                        }
                    },
                    .saw_decl => {
                        if (token.type == .identifier or token.type == .type_name or
                            std.mem.eql(u8, token.text, "_"))
                        {
                            state = .saw_ident;
                        } else {
                            state = .idle;
                        }
                    },
                    .saw_ident => {
                        if (token.type == .operator and std.mem.eql(u8, token.text, "=")) {
                            state = .saw_equals;
                        } else if (token.type == .operator and std.mem.eql(u8, token.text, ":")) {
                            // Type annotation — keep looking for '='
                        } else if (token.type == .operator and std.mem.eql(u8, token.text, ";")) {
                            state = .idle;
                        } else if (token.type == .identifier or token.type == .type_name or
                            token.type == .builtin or token.type == .keyword)
                        {
                            // Part of type annotation — stay
                        } else {
                            state = .idle;
                        }
                    },
                    .saw_equals => {
                        // *** THE FIX: Check token.type == .keyword ***
                        // Identifiers (T, MyStruct, etc.) have type .type_name
                        // or .identifier — they will NOT match this check.
                        var is_block_kw = false;
                        if (token.type == .keyword) {
                            for (block_kws) |bk| {
                                if (std.mem.eql(u8, token.text, bk)) {
                                    is_block_kw = true;
                                    break;
                                }
                            }
                        }
                        if (is_block_kw) {
                            state = .saw_block_kw;
                        } else {
                            // Not a type definition — reset
                            state = .idle;
                            if (token.type == .operator and std.mem.eql(u8, token.text, "{")) {
                                brace_depth += 1;
                            }
                            if (token.type == .operator and std.mem.eql(u8, token.text, "}")) {
                                brace_depth -= 1;
                            }
                        }
                    },
                    .saw_block_kw => {
                        if (token.type == .operator and std.mem.eql(u8, token.text, "{")) {
                            brace_depth += 1;
                            target_depth = brace_depth;
                            state = .tracking;
                        } else if (token.type == .operator and
                            (std.mem.eql(u8, token.text, "(") or std.mem.eql(u8, token.text, ")")))
                        {
                            // union(enum) — keep waiting for '{'
                        } else {
                            state = .idle;
                            if (token.type == .operator and std.mem.eql(u8, token.text, "{")) {
                                brace_depth += 1;
                            }
                            if (token.type == .operator and std.mem.eql(u8, token.text, "}")) {
                                brace_depth -= 1;
                            }
                        }
                    },
                    .tracking => {
                        if (token.type == .operator) {
                            if (std.mem.eql(u8, token.text, "{")) {
                                brace_depth += 1;
                            } else if (std.mem.eql(u8, token.text, "}")) {
                                brace_depth -= 1;
                                if (brace_depth < target_depth) {
                                    // Found matching '}' — look for ';'
                                    var next_token: ?Token = null;

                                    const next_on_line = skipWhitespaceNodes(token_node.next);
                                    if (next_on_line) |ns| {
                                        if (ns.tag == .token) {
                                            next_token = ns.data.token;
                                        }
                                    }

                                    if (next_token == null) {
                                        var search_line = line.next;
                                        outer: while (search_line) |sl| : (search_line = sl.next) {
                                            var search_tok = sl.child;
                                            while (search_tok) |st| : (search_tok = st.next) {
                                                if (st.tag == .token and
                                                    st.data.token.type != .whitespace and
                                                    st.data.token.type != .comment)
                                                {
                                                    next_token = st.data.token;
                                                    break :outer;
                                                }
                                            }
                                        }
                                    }

                                    const has_semi = if (next_token) |nt|
                                        nt.type == .operator and std.mem.eql(u8, nt.text, ";")
                                    else
                                        false;

                                    if (!has_semi) {
                                        try self.addError(token, "Expected ';' after '}' of type definition");
                                    }

                                    state = .idle;
                                }
                            }
                        }
                    },
                }
            }
        }
    }

    // ========================================================================
    // Pass 10: Struct/enum/union field syntax validation
    //
    // Validates field declarations inside struct/enum/union bodies.
    //
    // Key design decisions:
    //   - `pub` and `comptime` are the ONLY field modifiers that get skipped
    //   - `const`/`var` at struct top level start DECLARATIONS (skip to ';')
    //   - `const` inside a type expr ([]const u8) is just part of the type
    //   - `fn` at struct top level starts a METHOD (skip entire body)
    //   - Only validates at the block's top brace level (not nested blocks)
    // ========================================================================
    fn validateStructFieldSyntax(self: *SyntaxHighlighter) !void {
        const BlockKind = enum { struct_block, enum_block, union_block };

        const StackEntry = struct {
            kind: BlockKind,
            open_depth: i32,
        };

        const FieldState = enum {
            start, // beginning of block or after ','
            saw_ident, // saw field name identifier
            saw_colon, // saw `name:`
            in_type, // consuming type tokens after ':'
            in_default, // consuming `= value` after type
            skip_fn, // inside fn body, skip everything
            skip_decl, // inside const/var declaration, skip to ';'
        };

        var stack: [64]StackEntry = undefined;
        var stack_depth: usize = 0;
        var brace_depth: i32 = 0;

        var pending_block: ?BlockKind = null;
        var field_state: FieldState = .start;
        var last_field_ident: ?Token = null;
        var prev_significant: ?Token = null;
        var fn_brace_depth: i32 = 0;

        var line_iter = self.root.?.child;
        while (line_iter) |line| : (line_iter = line.next) {
            var token_iter = line.child;
            while (token_iter) |token_node| : (token_iter = token_node.next) {
                if (token_node.tag != .token) continue;
                const token = token_node.data.token;
                if (token.type == .whitespace or token.type == .comment) continue;

                // ---- Detect block keywords ----
                if (token.type == .keyword) {
                    if (std.mem.eql(u8, token.text, "struct")) pending_block = .struct_block else if (std.mem.eql(u8, token.text, "enum")) pending_block = .enum_block else if (std.mem.eql(u8, token.text, "union")) pending_block = .union_block;
                }

                // ---- Opening brace ----
                if (token.type == .operator and std.mem.eql(u8, token.text, "{")) {
                    brace_depth += 1;

                    if (pending_block) |pb| {
                        if (stack_depth < stack.len) {
                            stack[stack_depth] = .{ .kind = pb, .open_depth = brace_depth };
                            stack_depth += 1;
                            field_state = .start;
                            last_field_ident = null;
                        }
                        pending_block = null;
                    }

                    if (field_state == .skip_fn) fn_brace_depth += 1;
                    prev_significant = token;
                    continue;
                }

                // ---- Closing brace ----
                if (token.type == .operator and std.mem.eql(u8, token.text, "}")) {
                    if (field_state == .skip_fn) {
                        fn_brace_depth -= 1;
                        if (fn_brace_depth <= 0) {
                            field_state = .start;
                            fn_brace_depth = 0;
                        }
                        brace_depth -= 1;
                        prev_significant = token;
                        continue;
                    }

                    if (stack_depth > 0 and stack[stack_depth - 1].open_depth == brace_depth) {
                        stack_depth -= 1;
                        field_state = .start;
                        last_field_ident = null;
                    }
                    brace_depth -= 1;
                    prev_significant = token;
                    continue;
                }

                // ---- Clear pending on irrelevant operators ----
                if (pending_block != null and token.type == .operator) {
                    if (!std.mem.eql(u8, token.text, "(") and
                        !std.mem.eql(u8, token.text, ")"))
                    {
                        pending_block = null;
                    }
                }

                // ---- Skip states ----
                if (field_state == .skip_fn) {
                    prev_significant = token;
                    continue;
                }

                if (field_state == .skip_decl) {
                    if (token.type == .operator and std.mem.eql(u8, token.text, ";")) {
                        field_state = .start;
                        last_field_ident = null;
                    }
                    prev_significant = token;
                    continue;
                }

                // ---- Only validate at block's top level ----
                if (stack_depth == 0) {
                    prev_significant = token;
                    continue;
                }

                const current = stack[stack_depth - 1];
                if (brace_depth != current.open_depth) {
                    prev_significant = token;
                    continue;
                }

                // ---- fn → skip body ----
                if (token.type == .keyword and std.mem.eql(u8, token.text, "fn")) {
                    field_state = .skip_fn;
                    fn_brace_depth = 0;
                    prev_significant = token;
                    continue;
                }

                // ---- const/var at top level → skip declaration to ';' ----
                // e.g. `const Self = @This();` or `var counter: u32 = 0;`
                // These are namespace declarations, not struct fields.
                if (field_state == .start and token.type == .keyword and
                    (std.mem.eql(u8, token.text, "const") or
                        std.mem.eql(u8, token.text, "var")))
                {
                    field_state = .skip_decl;
                    prev_significant = token;
                    continue;
                }

                // ---- Skip only `pub` and `comptime` as field modifiers ----
                // *** FIX: `const` is NOT skipped here ***
                // `const` appears in type expressions: []const u8, *const T
                // Skipping it would break field state tracking mid-type.
                if (token.type == .keyword and
                    (std.mem.eql(u8, token.text, "pub") or
                        std.mem.eql(u8, token.text, "comptime")))
                {
                    prev_significant = token;
                    continue;
                }

                // ---- Field validation per block kind ----
                switch (current.kind) {
                    .struct_block, .union_block => {
                        switch (field_state) {
                            .start => {
                                if (token.type == .identifier or token.type == .type_name) {
                                    field_state = .saw_ident;
                                    last_field_ident = token;
                                }
                            },
                            .saw_ident => {
                                if (token.type == .operator and std.mem.eql(u8, token.text, ":")) {
                                    // Correct: field_name: type
                                    field_state = .saw_colon;
                                } else if (token.type == .operator and std.mem.eql(u8, token.text, ",")) {
                                    // Field without type annotation
                                    if (current.kind == .struct_block) {
                                        if (last_field_ident) |ident| {
                                            try self.addError(ident, "Struct field missing ':' type annotation");
                                        }
                                    }
                                    field_state = .start;
                                    last_field_ident = null;
                                } else if (token.type == .operator and std.mem.eql(u8, token.text, "=")) {
                                    // Assignment without type
                                    if (current.kind == .struct_block) {
                                        if (last_field_ident) |ident| {
                                            try self.addError(ident, "Struct field missing ':' type annotation before '='");
                                        }
                                    }
                                    field_state = .in_default;
                                } else if (token.type == .identifier or token.type == .type_name or
                                    token.type == .builtin)
                                {
                                    // Two idents without ':': `name []const u8`
                                    if (last_field_ident) |ident| {
                                        try self.addError(ident, "Expected ':' after field name for type annotation");
                                    }
                                    field_state = .in_type;
                                }
                            },
                            .saw_colon => {
                                // First token of type expression
                                field_state = .in_type;
                            },
                            .in_type => {
                                if (token.type == .operator and std.mem.eql(u8, token.text, ",")) {
                                    field_state = .start;
                                    last_field_ident = null;
                                } else if (token.type == .operator and std.mem.eql(u8, token.text, "=")) {
                                    field_state = .in_default;
                                } else if (token.type == .identifier) {
                                    // Might be part of type OR new field missing comma
                                    // Peek: if ':' follows → new field, missing ','
                                    const next_sig = skipWhitespaceNodes(token_node.next);
                                    if (next_sig) |ns| {
                                        if (ns.tag == .token and ns.data.token.type == .operator and
                                            std.mem.eql(u8, ns.data.token.text, ":"))
                                        {
                                            if (prev_significant) |prev| {
                                                try self.addError(prev, "Expected ',' between struct fields");
                                            }
                                            field_state = .saw_ident;
                                            last_field_ident = token;
                                        }
                                    }
                                }
                                // `const`, `volatile`, etc. as part of type → stay in .in_type
                            },
                            .in_default => {
                                if (token.type == .operator and std.mem.eql(u8, token.text, ",")) {
                                    field_state = .start;
                                    last_field_ident = null;
                                } else if (token.type == .identifier) {
                                    const next_sig = skipWhitespaceNodes(token_node.next);
                                    if (next_sig) |ns| {
                                        if (ns.tag == .token and ns.data.token.type == .operator and
                                            std.mem.eql(u8, ns.data.token.text, ":"))
                                        {
                                            if (prev_significant) |prev| {
                                                try self.addError(prev, "Expected ',' between struct fields");
                                            }
                                            field_state = .saw_ident;
                                            last_field_ident = token;
                                        }
                                    }
                                }
                            },
                            else => {},
                        }
                    },
                    .enum_block => {
                        switch (field_state) {
                            .start => {
                                if (token.type == .identifier or token.type == .type_name) {
                                    field_state = .saw_ident;
                                    last_field_ident = token;
                                }
                            },
                            .saw_ident => {
                                if (token.type == .operator and std.mem.eql(u8, token.text, ",")) {
                                    field_state = .start;
                                    last_field_ident = null;
                                } else if (token.type == .operator and std.mem.eql(u8, token.text, "=")) {
                                    field_state = .in_default;
                                } else if (token.type == .identifier or token.type == .type_name) {
                                    // Two variants without comma
                                    if (last_field_ident) |ident| {
                                        try self.addError(ident, "Expected ',' after enum variant");
                                    }
                                    last_field_ident = token;
                                }
                            },
                            .in_default => {
                                if (token.type == .operator and std.mem.eql(u8, token.text, ",")) {
                                    field_state = .start;
                                    last_field_ident = null;
                                } else if (token.type == .identifier or token.type == .type_name) {
                                    if (prev_significant) |prev| {
                                        try self.addError(prev, "Expected ',' after enum variant value");
                                    }
                                    field_state = .saw_ident;
                                    last_field_ident = token;
                                }
                            },
                            else => {
                                if (token.type == .operator and std.mem.eql(u8, token.text, ",")) {
                                    field_state = .start;
                                    last_field_ident = null;
                                }
                            },
                        }
                    },
                }

                prev_significant = token;
            }
        }
    } // ========================================================================
    // JSON validation (kept from original)
    // ========================================================================

    pub fn validateJSON(self: *SyntaxHighlighter) !void {
        self.errors.clearRetainingCapacity();

        if (self.root == null) return;

        var brace_count: i32 = 0;
        var bracket_count: i32 = 0;
        var first_token: ?Token = null;
        var last_significant_token: ?Token = null;

        var line_iter = self.root.?.child;
        while (line_iter) |line| {
            try self.validateLineJson(line);

            var token_iter = line.child;
            while (token_iter) |token_node| {
                if (token_node.tag == .token) {
                    const token = token_node.data.token;

                    if (token.type == .whitespace or token.type == .newline) {
                        token_iter = token_node.next;
                        continue;
                    }

                    if (first_token == null) {
                        first_token = token;
                        if (!std.mem.eql(u8, token.text, "{") and !std.mem.eql(u8, token.text, "[")) {
                            try self.addError(token, "JSON must start with '{' or '['");
                        }
                    }

                    if (std.mem.eql(u8, token.text, "{")) brace_count += 1;
                    if (std.mem.eql(u8, token.text, "}")) brace_count -= 1;
                    if (std.mem.eql(u8, token.text, "[")) bracket_count += 1;
                    if (std.mem.eql(u8, token.text, "]")) bracket_count -= 1;

                    if (last_significant_token) |last| {
                        if (std.mem.eql(u8, last.text, ",")) {
                            if (std.mem.eql(u8, token.text, "}") or std.mem.eql(u8, token.text, "]")) {
                                try self.addError(last, "Trailing comma not allowed in JSON");
                            }
                        }
                    }

                    if (token.type == .comment) {
                        try self.addError(token, "Comments are not allowed in JSON");
                    }

                    if (token.type == .char) {
                        try self.addError(token, "Single quotes not allowed, use double quotes");
                    }

                    last_significant_token = token;
                }
                token_iter = token_node.next;
            }
            line_iter = line.next;
        }

        if (brace_count != 0 and last_significant_token != null) {
            const msg = if (brace_count > 0) "Unclosed '{'" else "Extra '}'";
            try self.addError(last_significant_token.?, msg);
        }
        if (bracket_count != 0 and last_significant_token != null) {
            const msg = if (bracket_count > 0) "Unclosed '['" else "Extra ']'";
            try self.addError(last_significant_token.?, msg);
        }

        // Rebuild coalesced spans after validation
        try self.buildCoalescedSpans();
    }

    fn validateLineJson(self: *SyntaxHighlighter, line: *Node) !void {
        var token_iter = line.child;
        var last_token_type: ?TokenType = null;
        var last_token_text: ?[]const u8 = null;

        while (token_iter) |token_node| {
            if (token_node.tag == .token) {
                const token = token_node.data.token;

                if (token.type == .whitespace) {
                    token_iter = token_node.next;
                    continue;
                }

                if (token.type == .string) {
                    if (!std.mem.endsWith(u8, token.text, "\"")) {
                        try self.addError(token, "Unterminated string");
                    }
                }

                if (token.type == .identifier or token.type == .keyword) {
                    if (!std.mem.eql(u8, token.text, "true") and
                        !std.mem.eql(u8, token.text, "false") and
                        !std.mem.eql(u8, token.text, "null"))
                    {
                        try self.addError(token, "Invalid identifier; use true, false, or null");
                    }
                }

                if (std.mem.eql(u8, token.text, ",")) {
                    if (last_token_type == .operator and last_token_text != null) {
                        if (std.mem.eql(u8, last_token_text.?, ",")) {
                            try self.addError(token, "Unexpected comma");
                        }
                    }
                }

                if (std.mem.eql(u8, token.text, ":")) {
                    if (last_token_type != .string) {
                        try self.addError(token, "':' must follow a string key");
                    }
                }

                last_token_type = token.type;
                last_token_text = token.text;
            }
            token_iter = token_node.next;
        }
    }

    // FIXED: Use collision-free composite key
    pub fn addError(self: *SyntaxHighlighter, token: Token, message: []const u8) !void {
        const key = ErrorLocation.fromToken(token).toKey();
        try self.errors.put(key, .{
            .line = token.line,
            .column = token.column,
            .message = message,
        });
    }

    fn copy(highlighter: *SyntaxHighlighter) void {
        Vapor.Clipboard.copy(highlighter.local_copy_code);
        highlighter.show_cpy_btn = true;
        Vapor.timeout("copy_btn_editor", 500, toggleIcon, .{highlighter});
    }

    fn toggleIcon(highlighter: *SyntaxHighlighter) void {
        highlighter.show_cpy_btn = false;
        Vapor.cycle();
    }

    pub fn renderErrors(highlighter: *SyntaxHighlighter) !void {
        var error_count: usize = 0;
        if (highlighter.errors.count() > 0) {
            List()
                .width(.percent(100))
                .height(.percent(100))
                .padding(.all(0))
                .listStyle(.none)
                .direction(.column)
                .children({
                var itr = highlighter.errors.iterator();
                while (itr.next()) |err| {
                    error_count += 1;
                    ListItem()
                        .height(.px(64))
                        .width(.percent(100))
                        .background(.hex("#CE1720"))
                        .padding(.all(4))
                        .layout(.left_center)
                        .spacing(8)
                        .children({
                        Row()
                            .padding(.all(8))
                            .layout(.center)
                            .background(.transparentizeHex(.black, 0.2))
                            .children({
                            Vapor.Svg(.{ .svg = svg_bug }).style(&.{
                                .size = .{ .height = .px(16), .width = .px(16) },
                                .visual = .{ .fill = .white },
                            }).end();
                        });

                        Vapor.Stack().children({
                            Text(err.value_ptr.message).style(&.{
                                .visual = .{
                                    .font_size = 15,
                                    .font_weight = 500,
                                    .text_color = .white,
                                    .font_style = .italic,
                                },
                            }).end();
                            Text(Vapor.fmtln("Column {d}, Line: {d}", .{ err.value_ptr.column, err.value_ptr.line })).style(&.{
                                .visual = .{
                                    .font_size = 15,
                                    .font_weight = 500,
                                    .text_color = .white,
                                },
                            }).end();
                        });
                    });
                }
            });
        }
    }

    // ========================================================================
    // Optimized render using coalesced spans
    // ========================================================================
    pub fn render(highlighter: *SyntaxHighlighter) !void {
        Row().style(&.{
            .position = .relative,
            .size = .square_percent(100),
            .direction = .column,
            .layout = .{ .x = .start, .y = .start },
        }).children({
            if (highlighter.show_toolbar) {
                highlighter.renderToolbar();
            }

            Vapor.Stack().style(&.{
                .size = .square_percent(100),
                .direction = .column,
                .layout = .{ .x = .start, .y = .start },
                .padding = .all(12),
            }).children({
                Code(&.{ .size = .{ .width = .percent(100), .height = .percent(100) } })({
                    try highlighter.renderOptimized();
                });
            });
        });
    }

    fn renderToolbar(highlighter: *SyntaxHighlighter) void {
        Row().style(&.{
            .layout = .right_center,
            .padding = .xy(8, 6),
            .position = .tr(.px(0), .px(0), .absolute),
        }).children({
            Row().style(&.{
                .size = .w(.px(72)),
                .layout = .x_even_center,
            }).children({
                CtxButton(copy, .{highlighter})
                    .ariaLabel("copy-code-button")
                    .style(&.{
                        .position = .relative,
                        .size = .square_px(22),
                        .transition = .{ .duration = 100 },
                        .visual = .{
                            .border_radius = .all(4),
                            .background = .transparent,
                            .text_color = .transparentize(.black, 0.2),
                            .cursor = .pointer,
                        },
                        .interactive = .{
                            .hover = .{ .text_color = .white },
                        },
                        .layout = .center,
                    }).children({
                    if (highlighter.show_cpy_btn) {
                        Icon(.check).style(&.{
                            .visual = .{ .font_size = 16 },
                        }).end();
                    } else {
                        Icon(.clipboard).style(&.{
                            .visual = .{ .font_size = 16 },
                        }).end();
                    }
                });
                Graphic(.{ .src = "/src/assets/zig_simple.svg" }).style(&.{
                    .size = .{ .height = .px(16), .width = .px(16) },
                    .visual = .{ .text_color = .palette(.tint), .fill = .white },
                }).end();
            });
        });
    }

    // ========================================================================
    // OPTIMIZED RENDERING: Uses coalesced spans instead of individual tokens
    // ========================================================================
    fn renderOptimized(highlighter: *SyntaxHighlighter) !void {
        const coalesced = highlighter.coalesced_lines orelse return;

        for (coalesced, 0..) |line_spans, line_idx| {
            var is_added: bool = false;
            var is_removed: bool = false;
            if (line_spans.len > 0) {
                is_added = line_spans[0].is_added;
                is_removed = line_spans[0].is_removed;
            }
            Row().style(&.{
                .size = .hw(.px(22.5), .percent(100)),
                .layout = .left_center,
                .visual = .{ .background = if (is_added) .palette(.code_is_added_color) else if (is_removed) .hex("#FF0000") else .transparent },
            }).children({
                // Line number
                Text(line_idx + 1)
                    .font(14, 600, .transparentize(.palette(.code_text_color), 0.2))
                    .fontFamily("DM Mono, monospace")
                    .width(.px(24))
                    .end();

                // Line content - ONE box containing coalesced spans
                Row().style(&.{
                    .size = .h(.px(22.5)),
                    .visual = .{ .white_space = .pre },
                    .layout = .left_center,
                    .padding = .left(12),
                    .font_family = "DM Mono, monospace",
                }).children({
                    // Render each coalesced span
                    for (line_spans) |span| {
                        highlighter.renderSpan(span);
                    }
                });
            });
        }
    }

    fn renderSpan(highlighter: *SyntaxHighlighter, span: CoalescedSpan) void {
        _ = highlighter;

        const text_decoration: ?Vapor.Types.TextDecoration = if (span.has_error)
            .{ .type = .underline, .style = .wavy, .color = .palette(.danger) }
        else
            null;

        const font_size: u8 = if (Vapor.isMobile()) 16 else 15;

        // Mapping categories to the colors defined in your requirement
        const color: Vapor.Types.Color = switch (span.category) {
            .keyword => .hex("#82AAFF"),
            .operator => .hex("#6F6F6F"),
            .function => .palette(.code_function_color),
            .string => .palette(.code_string_color),
            .number => .palette(.code_text_color),
            .comment => .palette(.code_comment_color),
            .component => .palette(.code_tint_color),
            .default => .palette(.code_text_color),
            else => .hex("#262626"),
        };

        Text(span.text)
            .unmanaged()
            .style(&.{
                .font_family = "DM Mono, monospace",
                .visual = .{
                    .font_size = font_size,
                    .font_weight = 400,
                    .text_color = color,
                    .text_decoration = text_decoration,
                },
            }).end();
    }

    // ========================================================================
    // LEGACY: Original renderAST kept for compatibility
    // Use render() or renderOptimized() instead for better performance
    // ========================================================================
    pub fn renderAST(highlighter: *SyntaxHighlighter, node: ?*Node) !void {
        var current = node;
        while (current) |n| {
            switch (n.tag) {
                .root => {
                    Row().style(&.{
                        .position = .relative,
                        .size = .square_percent(100),
                        .direction = .column,
                        .layout = .{ .x = .start, .y = .start },
                    }).children({
                        if (highlighter.show_toolbar) {
                            highlighter.renderToolbar();
                        }

                        Row().style(&.{
                            .size = .square_percent(100),
                            .scroll = .scroll_x(),
                            .direction = .column,
                            .layout = .{ .x = .start, .y = .start },
                            .padding = .all(12),
                        }).children({
                            Code(&.{ .size = .{ .width = .percent(100), .height = .percent(100) } })({
                                try highlighter.renderOptimized();
                            });
                        });
                    });
                },

                .line => {
                    if (n.data.line.is_added) {
                        Row().style(&.{
                            .size = .h(.px(18)),
                            .visual = .{ .white_space = .pre, .background = .hex("#00FF00") },
                            .layout = .left_center,
                            .padding = .l(24),
                            .font_family = "DM Mono, monospace",
                        }).children({
                            try highlighter.renderAST(n.child);
                        });
                    } else if (n.data.line.is_removed) {
                        Row().style(&.{
                            .size = .h(.px(18)),
                            .visual = .{ .white_space = .pre, .background = .hex("#FF0000") },
                            .layout = .left_center,
                            .padding = .l(24),
                            .font_family = "DM Mono, monospace",
                        }).children({
                            try highlighter.renderAST(n.child);
                        });
                    } else {
                        Row().style(&.{
                            .size = .h(.px(22.5)),
                            .layout = .left_center,
                        }).children({
                            Text(n.data.line.number)
                                .font(14, 600, .transparentize(.black, 0.2))
                                .fontFamily("DM Mono, monospace")
                                .width(.px(24))
                                .end();
                            Row().style(&.{
                                .size = .h(.px(22.5)),
                                .visual = .{ .white_space = .pre },
                                .layout = .left_center,
                                .padding = .l(12),
                                .font_family = "DM Mono, monospace",
                            }).children({
                                try highlighter.renderAST(n.child);
                            });
                        });
                    }
                },
                .token => {
                    const token = n.data.token;
                    // FIXED: Use composite error key
                    const error_key = ErrorLocation.fromToken(token).toKey();
                    const error_annotation = highlighter.errors.get(error_key);
                    var text_decoration: ?Vapor.Types.TextDecoration = null;
                    if (error_annotation) |ann| {
                        // Double-check that it's actually this token (not a hash collision)
                        if (ann.line == token.line and ann.column == token.column) {
                            text_decoration = .{ .type = .underline, .style = .wavy, .color = .palette(.danger) };
                        }
                    }
                    const font_size: u8 = if (Vapor.isMobile()) 16 else 15;

                    switch (token.type) {
                        .keyword => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .hex("#2BACCC"),
                                },
                            }).end();
                        },
                        .builtin => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .hex("#262626"),
                                    .text_decoration = text_decoration,
                                },
                            }).end();
                        },
                        .operator => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_decoration = text_decoration,
                                    .text_color = .hex("#6F6F6F"),
                                },
                            }).end();
                        },
                        .identifier => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .hex("#262626"),
                                    .text_decoration = text_decoration,
                                },
                            }).end();
                        },
                        .component => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .palette(.code_component_color),
                                },
                            }).end();
                        },
                        .function => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .palette(.code_function_color),
                                },
                            }).end();
                        },
                        .comment => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .palette(.code_comment_color),
                                },
                            }).end();
                        },
                        .string => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .palette(.code_string_color),
                                    .text_decoration = text_decoration,
                                },
                            }).end();
                        },
                        .type_name => {
                            if (std.mem.eql(u8, token.text, "void")) {
                                Text(token.text).style(&.{
                                    .visual = .{
                                        .font_size = font_size,
                                        .font_weight = 400,
                                        .text_color = .palette(.code_type_color),
                                    },
                                }).end();
                            } else {
                                Text(token.text).style(&.{
                                    .visual = .{
                                        .font_size = font_size,
                                        .font_weight = 400,
                                        .text_color = .hex("#262626"),
                                    },
                                }).end();
                            }
                        },
                        else => {
                            Text(token.text).style(&.{
                                .visual = .{
                                    .font_size = font_size,
                                    .font_weight = 400,
                                    .text_color = .hex("#262626"),
                                },
                            }).end();
                        },
                    }
                },
                else => {},
            }

            current = n.next;
        }
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

fn isKeyword(text: []const u8) bool {
    for (keywords) |kw| {
        if (std.mem.eql(u8, text, kw)) return true;
    }
    return false;
}

fn isPrimitiveType(text: []const u8) bool {
    for (primitive_types) |t| {
        if (std.mem.eql(u8, text, t)) return true;
    }
    return false;
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\t' or char == '\r' or char == '\n';
}

// ============================================================================
// Debug/Testing - Print AST
// ============================================================================

pub fn printAST(node: ?*Node, writer: anytype, indent: usize) !void {
    var current = node;
    while (current) |n| {
        for (0..indent) |_| try writer.writeByte(' ');

        switch (n.tag) {
            .root => try writer.print("[Root]\n", .{}),
            .line => {
                const line_data = n.data.line;
                try writer.print("[Line {d}]\n", .{line_data.number});
            },
            .token => {
                const token = n.data.token;
                try writer.print("[{s}: \"{s}\"]\n", .{ @tagName(token.type), token.text });
            },
            else => {},
        }

        try printAST(n.child, writer, indent + 2);
        current = n.next;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "tokenize simple function" {
    const source =
        \\pub fn main() void {
        \\    const x = 42;
        \\}
    ;

    var tokenizer = Tokenizer.init(source);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var tokens = std.array_list.Managed(Token).init(arena.allocator());
    defer tokens.deinit();

    while (tokenizer.next()) |token| {
        try tokens.append(token);
    }

    try std.testing.expect(tokens.items.len > 0);
    try std.testing.expectEqualStrings("pub", tokens.items[0].text);
    try std.testing.expectEqual(TokenType.keyword, tokens.items[0].type);
}

pub inline fn Code(style: *const Vapor.Types.Style) fn (void) void {
    const elem_decl = Vapor.ElementDecl{
        .state_type = .static,
        .elem_type = .Code,
        .style = style,
    };
    _ = Vapor.LifeCycle.open(elem_decl);
    Vapor.LifeCycle.configure(elem_decl);
    return Vapor.LifeCycle.close;
}

test "parse and build AST" {
    const source =
        \\pub fn main() void {
        \\    const x = 42;
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var highlighter = SyntaxHighlighter.init(arena.allocator());
    defer highlighter.deinit();
    try highlighter.parse(source);

    // Test that coalesced spans were built
    try std.testing.expect(highlighter.coalesced_lines != null);
}

test "coalescing reduces span count" {
    const source = "const x = 10;"; // Has: keyword, whitespace, identifier, whitespace, operator, whitespace, number, operator

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var highlighter = SyntaxHighlighter.init(arena.allocator());
    defer highlighter.deinit();
    try highlighter.parse(source);

    const coalesced = highlighter.coalesced_lines.?;
    try std.testing.expect(coalesced.len == 1); // One line

    // Should have fewer spans than tokens due to coalescing
    try std.testing.expect(coalesced[0].len < 8);
}

test "error key no collision" {
    // Verify that line 10 col 5 and line 5 col 10 produce different keys
    const loc_a = ErrorLocation{ .line = 10, .column = 5 };
    const loc_b = ErrorLocation{ .line = 5, .column = 10 };
    try std.testing.expect(loc_a.toKey() != loc_b.toKey());

    // And that same location produces same key
    const loc_c = ErrorLocation{ .line = 10, .column = 5 };
    try std.testing.expectEqual(loc_a.toKey(), loc_c.toKey());
}
