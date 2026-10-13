const std = @import("std");
const Vapor = @import("../Vapor.zig");
const isWasi = Vapor.isWasi;
const Wasm = Vapor.Wasm;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;

pub const Kit = @This();

/// This function takes a slice of json and parses it into a struct
/// # Parameters:
/// - `T`: struct type
/// - `slice`: []const u8,
///
/// # Returns:
/// T: struct
///
/// # Usage:
/// ```zig
/// const my_struct = try Kit.glue(MyStruct, json_slice);
/// ```
/// NOTE: This function dellocates the parsed struct, after use, clone it if you need it beyond the scope of the function
pub fn glue(comptime T: type, slice: []const u8) !T {
    const parsed = std.json.parseFromSlice(
        T,
        Vapor.getFrameAllocator(),
        slice,
        .{},
    ) catch return error.MalformedJson;

    return parsed.value;
}

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

pub const String = struct {
    start: usize,
    len: usize,
    capacity: usize,
    contents: [65535]u8 = undefined,

    pub fn new() String {
        return String{
            .start = 0,
            .len = 0,
            .capacity = 65535,
        };
    }

    pub fn init(initial: []const u8) String {
        var new_string = String.new();
        new_string.append_str(initial);
        return new_string;
    }

    pub fn append_str(self: *String, input: []const u8) void {
        const required_len = self.len + input.len;
        const required_capacity = required_len + (10 - required_len % 10);

        // Case 1: contents exists and is big enough
        if (required_capacity <= self.capacity) {
            @memcpy(self.contents[self.len .. self.len + input.len], input);
            self.len = required_len;
        }
    }
};

pub fn fastJson(comptime T: type, data: T, writer: *String) !void {
    const fields = @typeInfo(T).@"struct".fields;
    writer.append_str("{");
    inline for (fields, 0..) |f, j| {
        const field_value_optional = @field(data, f.name);
        const is_optional = @typeInfo(f.type) == .optional;
        const field_type: type = getUnderlyingType(@TypeOf(field_value_optional));
        if (!is_optional or (is_optional and field_value_optional != null)) {
            const field_value = getUnderlyingValue(field_type, @TypeOf(field_value_optional), field_value_optional);
            writer.append_str("\"");
            writer.append_str(f.name);
            writer.append_str("\"");
            writer.append_str(": ");
            switch (field_type) {
                i8, i16, i32, i64, i128, f16, f32, f64, f128 => {
                    const max_len = 20;
                    var buf: [max_len]u8 = undefined;
                    const value = try std.fmt.bufPrint(&buf, "{any}", .{field_value});
                    writer.append_str(value);
                },
                bool => {
                    if (field_value) {
                        writer.append_str("true");
                    } else {
                        writer.append_str("false");
                    }
                },
                [][]const u8, []const []const u8 => {
                    writer.append_str("[");
                    for (field_value, 0..) |e, i| {
                        writer.append_str("\"");
                        writer.append_str(e);
                        writer.append_str("\"");
                        if (i < field_value.len - 1) writer.append_str(",");
                    }
                    writer.append_str("]");
                },
                []i8, []i16, []i32, []i64, []i128, []f16, []f32, []f64, []f128 => {
                    writer.append_str("[");
                    for (field_value, 0..) |e, i| {
                        const max_len = 4;
                        var buf: [max_len]u8 = undefined;
                        const value = try std.fmt.bufPrint(&buf, "{any}", .{e});
                        writer.append_str(value);
                        if (i > 0) writer.append_str(",");
                    }
                    writer.append_str("]");
                },
                []const u8 => {
                    writer.append_str("\"");
                    writer.append_str(field_value);
                    writer.append_str("\"");
                },
                else => {
                    switch (@typeInfo(field_type)) {
                        .@"struct" => {
                            var inner_writer = String.new();
                            try fastJson(field_type, field_value, &inner_writer);
                            const payload = inner_writer.contents[0..inner_writer.len];
                            writer.append_str(payload);
                        },
                        else => {},
                    }
                },
            }
            if (j < fields.len - 1) writer.append_str(", ");
        }
    }
    writer.append_str("}");
}

const AbortController = enum {
    signal,
};

pub const FetchAction = struct {
    runFn: FetchActionProto,
    deinitFn: FetchNodeProto,
};

pub const FetchActionProto = *const fn (*FetchAction, Response) void;
pub const FetchNodeProto = *const fn (*FetchNode) void;

pub const FetchNode = struct { data: FetchAction };

export fn scheduleTick(id: u32) void {
    if (Vapor.response_registry.get(id)) |_| {
        return;
    }
    if (isWasi) {
        _ = Wasm.tick(id);
    }
}

const Future = struct {
    id: u32,
    pub fn await(future: *@This()) ?Response {
        if (Vapor.response_registry.get(future.id)) |resp| {
            return resp;
        }
        _ = Wasm.tick(future.id);
        return null;
    }
};

pub fn fetchAwait(url: []const u8, http_req: HttpReq) *Future {
    var writer = String.new();
    writer.append_str("{\n\"method\": ");
    writer.append_str("\"");
    writer.append_str(@tagName(http_req.method));
    writer.append_str("\"");
    if (http_req.headers) |headers| {
        writer.append_str(",\n\"headers\": {\n");
        constructHeaders(headers, http_req.extra_headers, &writer);
        writer.append_str("\n}");
    } else if (http_req.extra_headers.len > 0) {
        writer.append_str(",\n\"headers\": {\n");
        var count: usize = 1;
        for (http_req.extra_headers) |header| {
            writer.append_str("\"");
            writer.append_str(header.name);
            writer.append_str("\"");
            writer.append_str(": ");
            writer.append_str("\"");
            writer.append_str(header.value);
            writer.append_str("\"");
            if (count < http_req.extra_headers.len) {
                writer.append_str(",\n");
            }
            count += 1;
        }
        writer.append_str("\n}");
    }

    if (http_req.credentials) |credentials| {
        writer.append_str(",\n\"credentials\": ");
        writer.append_str("\"");
        writer.append_str(credentials);
        writer.append_str("\"");
    }

    if (http_req.body) |body| {
        writer.append_str(",\n\"body\": ");
        switch (http_req.body_type) {
            .string => {
                writer.append_str("\"");
                writer.append_str(body);
                writer.append_str("\"");
            },
            .json => {
                writer.append_str(body);
            },
        }
    }
    writer.append_str("\n}");

    const final = writer.contents[0..writer.len];
    const json = std.json.fmt(final, .{ .whitespace = .indent_1 }).value;

    const id = Vapor.fetch_registry.count() + 1;

    const future = Vapor.allocator_global.create(Future) catch |err| {
        Vapor.println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    future.* = .{
        .id = id,
    };
    fetchWasm(url.ptr, url.len, id, json.ptr, json.len);
    return future;
}

pub fn fetch(url: []const u8, cb: fn (Response) void, http_req: HttpReq) void {
    var writer = String.new();
    writer.append_str("{\n\"method\": ");
    writer.append_str("\"");
    writer.append_str(@tagName(http_req.method));
    writer.append_str("\"");
    if (http_req.headers) |headers| {
        writer.append_str(",\n\"headers\": {\n");
        constructHeaders(headers, http_req.extra_headers, &writer);
        writer.append_str("\n}");
    } else if (http_req.extra_headers.len > 0) {
        writer.append_str(",\n\"headers\": {\n");
        var count: usize = 1;
        for (http_req.extra_headers) |header| {
            writer.append_str("\"");
            writer.append_str(header.name);
            writer.append_str("\"");
            writer.append_str(": ");
            writer.append_str("\"");
            writer.append_str(header.value);
            writer.append_str("\"");
            if (count < http_req.extra_headers.len) {
                writer.append_str(",\n");
            }
            count += 1;
        }
        writer.append_str("\n}");
    }

    if (http_req.credentials) |credentials| {
        writer.append_str(",\n\"credentials\": ");
        writer.append_str("\"");
        writer.append_str(credentials);
        writer.append_str("\"");
    }

    if (http_req.body) |body| {
        writer.append_str(",\n\"body\": ");
        switch (http_req.body_type) {
            .string => {
                writer.append_str("\"");
                writer.append_str(body);
                writer.append_str("\"");
            },
            .json => {
                writer.append_str(body);
            },
        }
    }
    writer.append_str("\n}");

    const final = writer.contents[0..writer.len];
    const json = std.json.fmt(final, .{ .whitespace = .indent_1 }).value;

    const Closure = struct {
        fetch_node: FetchNode = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        fn runFn(_: *FetchAction, resp: Response) void {
            @call(.auto, cb, .{resp});
        }
        fn deinitFn(node: *FetchNode) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        Vapor.println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{};

    const id = Vapor.fetch_registry.count() + 1;
    Vapor.fetch_registry.put(id, &closure.fetch_node) catch |err| {
        Vapor.println("Button Function Registry {any}\n", .{err});
        return;
    };
    fetchWasm(url.ptr, url.len, id, json.ptr, json.len);
    // return id;
}

var last_time: i64 = 0;
pub fn throttle() bool {
    const current_time = std.time.milliTimestamp();
    if (current_time - last_time < 8) {
        return true;
    }
    last_time = current_time;
    return false;
}

extern fn fetchWasm(
    url_ptr: [*]const u8,
    url_len: usize,
    callback_id: usize,
    http_req_offset_ptr: [*]u8,
    size: usize,
) void;

extern fn fetchParamsWasm(
    url_ptr: [*]const u8,
    url_len: usize,
    callback_id: usize,
    http_req_offset_ptr: [*]u8,
    size: usize,
) void;

extern fn setWindowLocationWasm(
    url_ptr: [*]const u8,
    url_len: usize,
) void;

pub fn setWindowLocation(url: []const u8) void {
    if (isWasi) {
        setWindowLocationWasm(url.ptr, url.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{url}, @src());
    }
}

extern fn navigateWasm(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

pub fn navigate(path: []const u8) void {
    if (isWasi) {
        navigateWasm(path.ptr, path.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{path}, @src());
    }
}

extern fn backWasm() void;

pub fn back() void {
    if (isWasi) {
        backWasm();
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi", .{}, @src());
    }
}

extern fn routePushWASM(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

pub fn routePush(path: []const u8) void {
    if (isWasi) {
        routePushWASM(path.ptr, path.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{path}, @src());
    }
}

extern fn getWindowInformationWasm() [*:0]u8;

pub fn getWindowPath() ?[]const u8 {
    if (isWasi) {
        return std.mem.span(getWindowInformationWasm());
    } else {
        return null;
    }
}

extern fn getWindowParamsWasm() [*:0]u8;

pub fn getWindowParams() ?[]const u8 {
    if (isWasi) {
        const params = getWindowParamsWasm();
        const params_str = std.mem.span(params);
        if (params_str.len == 0) {
            return null;
        } else {
            return params_str;
        }
    } else {
        Vapor.printlnSrc("Attempted to get params, but not wasi", .{}, @src());
        return null;
    }
}

pub fn findIndex(haystack: []const u8, needle: u8) ?usize {
    const vec_len = 16;
    const Vec16 = @Vector(16, u8);
    const splt_16: Vec16 = @splat(@as(u8, needle));
    if (haystack.len >= vec_len) {
        var i: usize = 0;
        while (i + vec_len <= haystack.len) : (i += vec_len) {
            const v = haystack[i..][0..vec_len].*;
            const vec: Vec16 = @bitCast(v);
            const mask = vec == splt_16;
            const bits: u16 = @bitCast(mask);
            if (bits != 0) {
                return i + @ctz(bits);
            }
        }
    }
    var i: usize = 0;
    while (i < haystack.len) : (i += 1) {
        if (haystack[i] == needle) return i;
    }
    return null;
}

fn decoder(encoded: []const u8, decoded: *std.array_list.Managed(u8)) !void {
    var i: usize = 0;
    while (i < encoded.len) : (i += 1) {
        if (encoded[i] == '%') {
            // Ensure there's enough room for two hex characters
            if (i + 2 >= encoded.len) {
                return error.InvalidInput;
            }

            const hex = encoded[i + 1 .. i + 3];
            const decodedByte = try std.fmt.parseInt(u8, hex, 16);
            try decoded.append(decodedByte);
            i += 2; // Skip over the two hex characters
        } else if (encoded[i] == '+') {
            // Replace '+' with a space
            try decoded.append(' ');
        } else {
            try decoded.append(encoded[i]);
        }
    }
}

pub fn parseParams(url: []const u8, allocator: *std.mem.Allocator) !?std.StringHashMap([]const u8) {
    const params_start = findIndex(url, '?') orelse return null;
    // Details
    var params = std.StringHashMap([]const u8).init(allocator.*);

    // Loop
    var pos = params_start + 1;
    while (pos < url.len) : (pos += 1) {
        const param_pair_end = findIndex(url[pos..], '&') orelse {
            // We only have one pair hence we add and return
            const seperator = findIndex(url[pos..], '=') orelse return error.SeperatorNotFound;
            const key = url[pos .. seperator + pos];
            var decoded = std.array_list.Managed(u8).init(allocator.*);
            try decoder(url[seperator + pos + 1 .. url.len], &decoded);
            const value = try decoded.toOwnedSlice();
            try params.put(key, value);
            return params;
        };
        // now we find the sperator in this pair and add it to the hashmap and continue on to the next
        // id=123
        const pair = url[pos .. param_pair_end + pos];
        const seperator = findIndex(pair, '=') orelse return error.SeperatorNotFound;
        const key = pair[0..seperator];
        var decoded = std.array_list.Managed(u8).init(allocator.*);
        try decoder(pair[seperator + 1 ..], &decoded);
        const value = try decoded.toOwnedSlice();
        try params.put(key, value);
        pos += param_pair_end;
    }
    return params;
}

pub const ResponseError = struct {
    type: []const u8 = "",
    message: []const u8 = "",
};

pub const OkResponse = struct {
    code: u32,
    message: []const u8,
    type: []const u8,
    ok: bool,
    body: []const u8,
};

pub const ErrResponse = struct {
    code: u32,
    type: []const u8,
    message: []const u8,
    ok: bool,
};

pub const Response = union(enum) {
    ok: OkResponse,
    err: ErrResponse,
    pub fn isOk(self: Response) bool {
        return switch (self) {
            .ok => true,
            else => false,
        };
    }

    pub fn isErr(self: Response) bool {
        return switch (self) {
            .err => true,
            else => false,
        };
    }
};

export fn resumeCallback(id: u32, resp_ptr: [*:0]u8) void {
    const resp = std.mem.span(resp_ptr);
    // this std.json.parseFromSlice is extermely memory costly 43kb alone
    const parsed_value: std.json.Parsed(Response) = std.json.parseFromSlice(Response, Vapor.arena(.persist), resp, .{}) catch |err| {
        Vapor.printlnSrcErr("Error could not parse response {any}\n", .{err}, @src());
        return;
    };

    if (parsed_value.value == .err) {
        Vapor.printlnErr("\nERROR CODE: {d}\nERROR TYPE: {s}\nERROR MESSAGE: {s}\n", .{
            parsed_value.value.err.code,
            parsed_value.value.err.type,
            parsed_value.value.err.message,
        });
    }

    const json_resp: Response = parsed_value.value;
    // Vapor.response_registry.put(id, json_resp) catch |err| {
    //     Vapor.println("Button Function Registry {any}\n", .{err});
    //     return;
    // };
    const node = Vapor.fetch_registry.get(id) orelse return;
    @call(.auto, node.data.runFn, .{ &node.data, json_resp });
}

pub const HttpReqOffset = struct {
    method_ptr: [*]const u8 = undefined,
    method_len: usize = 0,
    content_type_ptr: ?[*]const u8 = null,
    content_type_len: ?usize = null,
    authorization_ptr: ?[*]const u8 = null,
    authorization_len: ?usize = null,
    accept_ptr: ?[*]const u8 = null,
    accept_len: ?usize = null,
    user_agent_ptr: ?[*]const u8 = null,
    user_agent_len: ?usize = null,
    body_ptr: ?[*]const u8 = null,
    body_len: ?usize = null,
    extra_headers_ptr: ?[*]const HttpHeader = null,
    extra_headers_len: ?usize = null,
    mode_ptr: ?[*]const u8 = null,
    mode_len: ?usize = null,
    redirect_ptr: ?[*]const u8 = null,
    redirect_len: ?usize = null,
    referrer_policy_ptr: ?[*]const u8 = null,
    referrer_policy_len: ?usize = null,
    integrity_ptr: ?[*]const u8 = null,
    integrity_len: ?usize = null,
    use_credentials: bool = false,
};

pub const HttpHeader = struct {
    name: []const u8,
    value: []const u8,
};

const Headers = struct {
    content_type: []const u8 = "text/html",
    authorization: ?[]const u8 = null,
    accept: ?[]const u8 = null,
    user_agent: ?[]const u8 = null,
};

const BodyType = enum {
    string,
    json,
};

const Methods = enum {
    GET,
    POST,
    PATCH,
    DELETE,
    OPTIONS,
};

pub const HttpReq = struct {
    method: Methods,
    headers: ?Headers = null,
    body: ?[]const u8 = null,
    body_type: BodyType = .string,
    mode: ?[]const u8 = null,
    redirect: ?[]const u8 = null,
    referrer_policy: ?[]const u8 = null,
    integrity: ?[]const u8 = null,
    use_credentials: bool = false,
    credentials: ?[]const u8 = null,
    extra_headers: []const HttpHeader = &.{},
};

var http_req_view: HttpReqOffset = HttpReqOffset{};
fn generateHttpLayout(http_req: HttpReq) *u8 {
    http_req_view.method_ptr = @tagName(http_req.method).ptr;
    http_req_view.method_len = @tagName(http_req.method).len;

    if (http_req.headers) |h| {
        if (h.content_type) |ct| {
            http_req_view.content_type_ptr = ct.ptr;
            http_req_view.content_type_len = ct.len;
        }
        if (h.authorization) |au| {
            http_req_view.authorization_ptr = au.ptr;
            http_req_view.authorization_len = au.len;
        }
        if (h.accept) |ac| {
            http_req_view.accept_ptr = ac.ptr;
            http_req_view.accept_len = ac.len;
        }
        if (h.user_agent) |us| {
            http_req_view.user_agent_ptr = us.ptr;
            http_req_view.user_agent_len = us.len;
        }

        if (http_req.extra_headers.len > 0) {
            http_req_view.extra_headers_ptr = http_req.extra_headers.ptr;
            http_req_view.extra_headers_len = http_req.extra_headers.len;
        }
    }
    if (http_req.body) |b| {
        http_req_view.body_ptr = b.ptr;
        http_req_view.body_len = b.len;
    }
    if (http_req.mode) |m| {
        http_req_view.mode_ptr = m.ptr;
        http_req_view.mode_len = m.len;
    }
    if (http_req.redirect) |r| {
        http_req_view.redirect_ptr = r.ptr;
        http_req_view.redirect_len = r.len;
    }
    if (http_req.referrer_policy) |rp| {
        http_req_view.referrer_policy_ptr = rp.ptr;
        http_req_view.referrer_policy_len = rp.len;
    }
    if (http_req.integrity) |i| {
        http_req_view.integrity_ptr = i.ptr;
        http_req_view.integrity_len = i.len;
    }
    http_req_view.use_credentials = http_req.use_credentials;

    const ptr: *u8 = @ptrCast(&http_req_view);
    return ptr;
}

var http_buf: [4096]u8 = undefined;
fn constructHeaders(headers: Headers, extra_headers: []const HttpHeader, writer: *String) void {
    writer.append_str("\"Content-Type\": ");
    writer.append_str("\"");
    writer.append_str(headers.content_type);
    writer.append_str("\"");
    if (headers.user_agent) |user_agent| {
        writer.append_str(",\n");
        writer.append_str("\"User-Agent\": ");
        writer.append_str("\"");
        writer.append_str(user_agent);
        writer.append_str("\"");
    }
    if (headers.authorization) |authorization| {
        writer.append_str(",\n");
        writer.append_str("\"Authorization\": ");
        writer.append_str("\"");
        writer.append_str(authorization);
        writer.append_str("\"");
    }
    if (headers.accept) |accept| {
        writer.append_str(",\n");
        writer.append_str("\"Accept\": ");
        writer.append_str("\"");
        writer.append_str(accept);
        writer.append_str("\"");
    }

    for (extra_headers) |header| {
        writer.append_str(",\n");
        writer.append_str("\"");
        writer.append_str(header.name);
        writer.append_str("\"");
        writer.append_str(": ");
        writer.append_str("\"");
        writer.append_str(header.value);
        writer.append_str("\"");
    }
}

pub fn fetchWithParams(url: []const u8, self: anytype, cb: anytype, http_req: HttpReq) void {
    var writer = String.new();
    writer.append_str("{\n\"method\": ");
    writer.append_str("\"");
    writer.append_str(@tagName(http_req.method));
    writer.append_str("\"");
    if (http_req.headers) |headers| {
        writer.append_str(",\n\"headers\": {\n");
        constructHeaders(headers, http_req.extra_headers, &writer);
        writer.append_str("\n}");
    } else if (http_req.extra_headers.len > 0) {
        writer.append_str(",\n\"headers\": {\n");
        var count: usize = 1;
        for (http_req.extra_headers) |header| {
            writer.append_str("\"");
            writer.append_str(header.name);
            writer.append_str("\"");
            writer.append_str(": ");
            writer.append_str("\"");
            writer.append_str(header.value);
            writer.append_str("\"");
            if (count < http_req.extra_headers.len) {
                writer.append_str(",\n");
            }
            count += 1;
        }
        writer.append_str("\n}");
    }

    if (http_req.credentials) |credentials| {
        writer.append_str(",\n\"credentials\": ");
        writer.append_str("\"");
        writer.append_str(credentials);
        writer.append_str("\"");
    }

    if (http_req.body) |body| {
        writer.append_str(",\n\"body\": ");
        switch (http_req.body_type) {
            .string => {
                writer.append_str("\"");
                writer.append_str(body);
                writer.append_str("\"");
            },
            .json => {
                writer.append_str(body);
            },
        }
    }
    writer.append_str("\n}");

    const final = writer.contents[0..writer.len];
    const json = std.json.fmt(final, .{ .whitespace = .indent_1 }).value;
    // const http_req_offset_ptr = generateHttpLayout(http_req);

    const Args = @TypeOf(self);
    const Closure = struct {
        self: Args,
        fetch_node: FetchNode = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *FetchAction, resp: Response) void {
            const fetch_node: *FetchNode = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", fetch_node));
            @call(.auto, cb, .{ closure.self, resp });
        }
        //
        fn deinitFn(node: *FetchNode) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("fetch_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        Vapor.println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .self = self,
    };

    const id = Vapor.fetch_registry.count() + 1;
    Vapor.fetch_registry.put(id, &closure.fetch_node) catch |err| {
        Vapor.println("Button Function Registry {any}\n", .{err});
        return;
    };
    fetchParamsWasm(url.ptr, url.len, id, json.ptr, json.len);
}

const http = std.http;

const Param = struct {
    key: []const u8,
    value: []const u8,
};

pub fn scrollTo(x: f32, y: f32) void {
    if (isWasi) {
        Wasm.scrollToWasm(x, y);
    }
}

pub const QueryBuilder = struct {
    allocator: std.mem.Allocator,
    params: std.array_list.Managed(Param),
    str: []const u8,

    /// This function takes a pointer to this QueryBuilder instance.
    /// Deinitializes the query builder instance
    /// # Parameters:
    /// - `target`: *QueryBuilder.
    /// - `allocator`: std.mem.Allocator.
    ///
    /// # Returns:
    /// void.
    pub fn init(query_builder: *QueryBuilder, allocator: std.mem.Allocator) !void {
        query_builder.* = .{
            .allocator = allocator,
            .params = std.array_list.Managed(Param).init(allocator),
            .str = "",
        };
    }

    /// This function takes a pointer to this QueryBuilder instance.
    /// Deinitializes the query builder instance, loops over the keys and values to free
    /// # Parameters:
    /// - `target`: *QueryBuilder.
    ///
    /// # Returns:
    /// void.
    pub fn deinit(query_builder: *QueryBuilder) void {
        for (query_builder.params.items) |param| {
            query_builder.allocator.free(param.key);
            query_builder.allocator.free(param.value);
        }
        query_builder.params.deinit();
        if (query_builder.str.len > 0) {
            query_builder.allocator.free(query_builder.str);
        }
    }

    /// This function adds a value and key to the query builder.
    /// # Example
    /// try query.add("client_id", "98f3$j%gw54u4562$");
    ///
    /// # Parameters:
    /// - `key`: []const u8.
    /// - `value`: []const u8.
    ///
    /// # Returns:
    /// void and adds to query builder list.
    pub fn add(query_builder: *QueryBuilder, key: []const u8, value: []const u8) !void {
        const key_dup = try query_builder.allocator.dupe(u8, key);
        const value_dup = try query_builder.allocator.dupe(u8, value);
        try query_builder.params.append(.{ .key = key_dup, .value = value_dup });
    }

    /// This function removes a key.
    /// # Example
    /// try query.remove("client_id");
    ///
    /// # Parameters:
    /// - `key`: []const u8.
    ///
    /// # Returns:
    /// void
    pub fn remove(query_builder: *QueryBuilder, key: []const u8) !void {
        // utils.assert_cm(query_builder.query_param_list.capacity > 0, "QueryBuilder not initilized");
        for (query_builder.params.items, 0..) |query_param, i| {
            if (std.mem.eql(u8, query_param.key, key)) {
                _ = query_builder.query_param_list.orderedRemove(i);
                break;
            }
        }
    }

    /// This function encodes the url pass.
    /// # Example
    /// try query.urlEncoder("https://accounts.google.com/o/oauth2/v2/auth");
    ///
    /// # Parameters:
    /// - `url`: []const u8.
    ///
    /// # Returns:
    /// []const u8
    pub fn urlEncoder(query_builder: *QueryBuilder, url: []const u8) ![]const u8 {
        var encoded = std.array_list.Managed(u8).init(query_builder.allocator);
        defer encoded.deinit();

        for (url) |c| {
            switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '-', '_', '.', '~' => try encoded.append(c),
                ' ' => try encoded.appendSlice("%20"),
                else => {
                    try encoded.writer().print("%{X:0>2}", .{c});
                },
            }
        }

        return encoded.toOwnedSlice();
    }

    /// This function encodes the query and set query_builder.str.
    /// # Example
    /// try query.queryStrEncode();
    ///
    /// # Returns:
    /// void
    pub fn queryStrEncode(query_builder: *QueryBuilder) !void {
        if (query_builder.params.items.len == 0) {
            query_builder.str = "";
            return;
        }

        var list = std.array_list.Managed(u8).init(query_builder.allocator);
        errdefer list.deinit();

        for (query_builder.params.items, 0..) |param, i| {
            if (i > 0) {
                try list.append('&');
            }

            // URL encode key
            const encoded_key = try query_builder.urlEncoder(param.key);
            defer query_builder.allocator.free(encoded_key);
            try list.appendSlice(encoded_key);

            try list.append('=');

            // URL encode value
            const encoded_value = try query_builder.urlEncoder(param.value);
            defer query_builder.allocator.free(encoded_value);
            try list.appendSlice(encoded_value);
        }

        query_builder.str = try list.toOwnedSlice();
    }

    /// This function generates the queried url plus the precursor url.
    /// # Example
    /// try query.generateUrl("https://accounts.google.com/o/oauth2/v2/auth", query.str);
    ///
    /// # Parameters:
    /// - `base_url`: []const u8.
    /// - `query`: []const u8.
    ///
    /// # Returns:
    /// []const u8
    pub fn generateUrl(query_builder: *QueryBuilder, base_url: []const u8, query: []const u8) ![]const u8 {
        var result = std.array_list.Managed(u8).init(query_builder.allocator);
        errdefer result.deinit();

        try result.appendSlice(base_url);
        if (query.len > 0) {
            try result.append('?');
            try result.appendSlice(query);
        }

        return result.toOwnedSlice();
    }

    // Helper function to get parameters in order
    pub fn getParams(query_builder: *QueryBuilder) []const Param {
        return query_builder.params.items;
    }
};

pub const ObserverOptions = struct {
    threshold: f32 = 0,
    rootMargin_top: i32 = 0,
    rootMargin_right: i32 = 0,
    rootMargin_bottom: i32 = 0,
    rootMargin_left: i32 = 0,
};

// Field type enum that JS can understand
pub const FieldType = enum(u8) {
    u8_type,
    i8_type,
    u16_type,
    i16_type,
    u32_type,
    i32_type,
    u64_type,
    i64_type,
    f32_type,
    f64_type,
    bool_type,
    string_type, // ptr + len pair
};

// Schema field descriptor
pub const FieldDescriptor = packed struct {
    field_type: FieldType,
    offset: u32,
    name_ptr: usize,
    name_len: usize,
};

// Generic schema generator
pub fn StructSchema(comptime T: type) type {
    return struct {
        pub var fields: []FieldDescriptor = undefined;
        pub fn init() void {
            const type_info = @typeInfo(T);
            if (type_info != .@"struct") {
                @compileError("StructSchema only works with struct types");
            }

            const struct_fields = type_info.@"struct".fields;
            fields = Vapor.arena(.persist).alloc(FieldDescriptor, struct_fields.len) catch unreachable;

            inline for (struct_fields, 0..) |field, i| {
                const field_type = mapZigTypeToFieldType(field.type);
                // Vapor.print("Field {s} type {d} {any} {any}\n", .{ field.name, field_type, @offsetOf(T, field.name), @intFromPtr(field.name.ptr) });
                fields[i] = FieldDescriptor{
                    .field_type = field_type,
                    .offset = @offsetOf(T, field.name),
                    .name_ptr = @intFromPtr(field.name.ptr),
                    .name_len = field.name.len,
                };
            }
        }

        pub fn getSchema() []FieldDescriptor {
            return fields;
        }

        pub fn getSchemaLength() usize {
            return fields.len;
        }
    };
}

fn mapZigTypeToFieldType(comptime T: type) FieldType {
    return switch (T) {
        u8 => .u8_type,
        i8 => .i8_type,
        u16 => .u16_type,
        i16 => .i16_type,
        u32 => .u32_type,
        i32 => .i32_type,
        u64 => .u64_type,
        i64 => .i64_type,
        f32 => .f32_type,
        f64 => .f64_type,
        bool => .bool_type,
        else => blk: {
            // Check if it's a string type (ptr + len)
            const type_info = @typeInfo(T);
            if (type_info == .Pointer) {
                break :blk .string_type;
            }
            @compileError("Unsupported type: " ++ @typeName(T));
        },
    };
}

/// Observer is a struct that allows you to observe the visibility of an element
/// and call a callback when the element becomes visible or invisible
/// # Parameters:
/// - `name`: []const u8,
/// - `callback`: anytype,
/// - `options`: ObserverOptions,
///
/// # Returns:
/// Observer
///
/// # Usage:
/// ```zig
/// const observer = Kit.Observer.new("my_observer", onObserver, .{ .threshold = 0.5 });
///
/// fn onObserver(target: Observer.Target) void {
///     const target: Observer.Target = target;
///     _ = target;
/// }
/// ``` NOTE: This function dellocates, after use, clone the fields if need them outsside the handler function
/// # Example:
/// ```zig
/// const observer = Kit.Observer.new("my_observer", onObserver, .{ .threshold = 0.5 });
///
/// var target_link: []const u8 = "";
/// fn onObserver(target: Observer.Target) void {
///     const target: Observer.Target = target;
///     target_link = Vapor.clone(target.url);
/// }
/// ```
pub const Observer = struct {
    pub const Target = struct {
        url: []const u8,
        is_in_view: bool,
        index: usize,
    };
    name: []const u8,
    callback: *const fn (Target) void,
    oberver_nodes: std.array_list.Managed(Vapor.ObserverNode),

    pub fn new(name: []const u8, callback: fn (Target) void, options: ObserverOptions) Observer {
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.printlnSrcErr("Bridge: Observer callback called without object, this is a js side issue", .{}, @src());
                    Vapor.printlnSrcErr("No object found", .{}, @src());
                    return;
                };
                const target: Target = Vapor.convertFromDynamicToType(Target, object);
                @call(.auto, callback, .{target});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.persist).create(Closure) catch |err| {
            Vapor.println("Error could not create closure {any}\n ", .{err});
            unreachable;
        };
        closure.* = .{};

        const hash = hashKey(name);
        Vapor.ctx_callback_registry.put(hash, &closure.run_node) catch |err| {
            Vapor.println("Button Function Registry {any}\n", .{err});
        };

        if (isWasi) {
            Wasm.createObserverWasm(hash, &options);
        }

        return Observer{
            .name = name,
            .callback = callback,
            .oberver_nodes = std.array_list.Managed(Vapor.ObserverNode).init(Vapor.arena(.persist)),
        };
    }

    pub fn disconnect(self: *Observer) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.reinitObserverWasm(hash);
    }

    pub fn destroy(name: []const u8) void {
        if (!isWasi) return;
        Wasm.destroyObserverWasm(name.ptr, name.len);
    }

    pub fn observe(self: *Observer, item: Vapor.ObserverNode, index: ?usize) void {
        if (!isWasi) return;
        self.oberver_nodes.append(item) catch unreachable;
        const hash = hashKey(self.name);
        switch (item) {
            .uuid => |uuid| {
                Wasm.observeWasm(hash, uuid.ptr, uuid.len, index orelse 0);
            },
            .type => |element_type| {
                const element_type_str = @tagName(element_type);
                Wasm.observeWasm(hash, element_type_str.ptr, element_type_str.len, index orelse 0);
            },
        }
    }

    // pub fn observe(self: *Observer, items: []const Vapor.ObserverNode) void {
    //     self.oberver_nodes.appendSlice(items) catch unreachable;
    //     Vapor.observer_nodes.put(self.name, self.oberver_nodes) catch unreachable;
    //     Wasm.observeWasm(self.name.ptr, self.name.len);
    // }

    // fn addCallBack(name: []const u8, cb: anytype, comptime T: type) void {}
};

const ObserverExport = Vapor.exportStruct(ObserverOptions);
pub export fn getObserverOptions(options: *ObserverOptions) [*]const u8 {
    ObserverExport.init();
    ObserverExport.instance = options.*;
    return ObserverExport.getInstancePtr();
}

pub export fn getObserverFieldCount() u32 {
    return ObserverExport.getFieldCount();
}

pub export fn getObserverFieldDescriptor(index: u32) ?*const Vapor.FieldDescriptor() {
    return ObserverExport.getFieldDescriptor(index);
}

export fn getObserverNodeCount(observer_name: [*:0]u8) usize {
    const name = std.mem.span(observer_name);
    const nodes = Vapor.observer_nodes.get(name) orelse return 0;
    return nodes.items.len;
}

export fn getObserverNode(observer_name: [*:0]u8, index: usize) ?[*]const u8 {
    const name = std.mem.span(observer_name);
    const nodes = Vapor.observer_nodes.get(name) orelse return null;
    const node = nodes.items[index];
    return node.uuid.ptr;
}

export fn getObserverNodeLength(observer_name: [*:0]u8, index: usize) usize {
    const name = std.mem.span(observer_name);
    const nodes = Vapor.observer_nodes.get(name) orelse return 0;
    const node = nodes.items[index];
    return node.uuid.len;
}
