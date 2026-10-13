const std = @import("std");
const Vapor = @import("vapor");
const Wasm = @import("wasm");
const isWasi = Vapor.lib.isWasi;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Event = @import("Event.zig");

const FileInfo = struct {
    name: []const u8 = undefined,
    size: u32 = undefined,
    type: []const u8 = undefined,
};

const File = struct {
    contents: []const u8 = "",
    file_info: FileInfo,
    index: usize,
};

pub const FileReader = @This();
event: *Event,
contents: ?[]const u8 = null,
file_index: usize = 0,
file_count: usize = 0,
files: Vapor.Array(File),

pub fn init(event: *Event) FileReader {
    return .{
        .event = event,
        .files = Vapor.array(File, .persist),
    };
}

pub const FileContents = struct {
    contents: []const u8,
};

pub const FileTypes = enum {
    @"text/plain",
    @"text/html",
    @"text/css",
    @"text/javascript",
    @"application/json",
    @"application/javascript",
    @"application/wasm",
    @"image/png",
    @"image/jpeg",
    @"image/webp",
};

pub fn readText(file_reader: *FileReader, file_index: usize, onload: fn ([]const u8) void) void {
    if (isWasi) {
        var callback_id = file_reader.event.id;
        callback_id +%= hashKey("form-text");
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.printlnSrcErr("Bridge: Observer callback called without object, this is a js side issue", .{}, @src());
                    Vapor.printlnSrcErr("No object found", .{}, @src());
                    return;
                };
                const file: FileContents = Vapor.convertFromDynamicToType(FileContents, object);
                @call(.auto, onload, .{file.contents});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.frame).create(Closure) catch |err| {
            Vapor.printErr("Failed to create onload closure {any}\n", .{err});
            return;
        };
        closure.* = .{};

        Vapor.ctx_callback_registry.put(callback_id, &closure.run_node) catch |err| {
            Vapor.printErr("Failed to register onload callback {any}\n", .{err});
            return;
        };

        Wasm.readFileAsTextWasm(file_reader.evt.id, file_index, callback_id);
    }
    return;
}

pub fn readBase64(file_reader: *FileReader, file_index: usize, onload: fn ([]const u8) void) void {
    if (isWasi) {
        var callback_id = file_reader.event.id;
        callback_id +%= hashKey("form-base64");
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.printlnSrcErr("Bridge: Observer callback called without object, this is a js side issue", .{}, @src());
                    Vapor.printlnSrcErr("No object found", .{}, @src());
                    return;
                };
                const file: FileContents = Vapor.convertFromDynamicToType(FileContents, object);
                @call(.auto, onload, .{file.contents});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.frame).create(Closure) catch |err| {
            Vapor.println("Error could not create closure {any}\n ", .{err});
            unreachable;
        };
        closure.* = .{};

        const id = Vapor.ctx_callback_registry.count() + 1;
        Vapor.ctx_callback_registry.put(id, &closure.run_node) catch |err| {
            Vapor.println("Button Function Registry {any}\n", .{err});
            unreachable;
        };

        Wasm.readFileAsBase64Wasm(file_reader.evt.id, file_index, callback_id);
    }
    return;
}

pub fn downloadFile(file_name: []const u8, data: []const u8, mime_type: FileTypes) void {
    const file_type = @tagName(mime_type);
    if (isWasi) {
        Wasm.downloadFileWasm(file_name.ptr, file_name.len, data.ptr, data.len, file_type.ptr, file_type.len);
    }
}

pub fn createURLfromFile(file_reader: *FileReader, file_index: usize) ![]const u8 {
    if (isWasi) {
        const ptr = Wasm.createObjectURLWasm(file_reader.event.id, file_index);
        return std.mem.span(ptr);
    }
    return error.NonWasi;
}

pub fn fileInfo(file_reader: *FileReader, file_index: usize) !FileInfo {
    if (isWasi) {
        const handle = Wasm.getFileInfoWasm(file_reader.event.id, file_index);
        const obj = Vapor.lib.finalizeObject(handle);
        var cloned_form: FileInfo = .{};
        const fields = @typeInfo(FileInfo).@"struct".fields;
        inline for (fields, 0..) |field, i| {
            const obj_value = obj.fields.items[i].value;
            switch (@typeInfo(field.type)) {
                .pointer => |ptr| {
                    if (ptr.size == .slice) {
                        @field(cloned_form, field.name) = obj_value.string;
                    }
                },
                .int => {
                    if (obj_value == .string) {
                        @field(cloned_form, field.name) = std.fmt.parseInt(field.type, obj_value.string, 10) catch |err| blk: {
                            Vapor.printErr("Error parsing int field {s} value {s} {any}", .{ field.name, obj_value.string, err });
                            break :blk 0;
                        };
                    } else {
                        @field(cloned_form, field.name) = @intCast(obj_value.int);
                        Vapor.printSrcErr("WE NEED TO CHECK THIS SO THAT THE SIGNDNESS IS OKAY", .{}, @src());
                    }
                },
                else => {
                    Vapor.printlnErr("Cannot set non string or int float types TYPE: {any}", .{@TypeOf(obj_value)});
                },
            }
        }
        if (file_reader.files.items.len < file_index) {
            file_reader.files.items[file_index] = File{
                .file_info = cloned_form,
                .index = file_index,
            };
        } else {
            try file_reader.files.append(
                File{
                    .file_info = cloned_form,
                    .index = file_index,
                },
            );
        }
        return cloned_form;
    }
}
