const std = @import("std");
const Vapor = @import("Vapor.zig");
const Wasm = @import("wasm");
const isWasi = Vapor.isWasi;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;

pub const Event = @This();
id: u32,
type: Vapor.Types.EventType,
pub fn element_id(evt: *Event) []const u8 {
    const key_str: []const u8 = "target";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    return std.mem.span(resp);
}

pub fn key(evt: *Event) []const u8 {
    const key_str: []const u8 = "key";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    return std.mem.span(resp);
}

pub fn metaKey(evt: *Event) bool {
    const key_str: []const u8 = "metaKey";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    switch (resp[0]) {
        't' => return true,
        'f' => return false,
        else => return false,
    }
}
pub fn text(evt: *Event) []const u8 {
    const resp = getEventDataInput(evt.id);
    return std.mem.span(resp);
}

export fn readObject(callback_ptr: u32, object_ptr: ?*Vapor.DynamicObject) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        Vapor.printlnSrcErr("Callback not found\n", .{}, @src());
        return;
    };
    node.data.dynamic_object = object_ptr;
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

pub fn formData(evt: *Event, form_value: anytype) ?@typeInfo(@TypeOf(form_value)).pointer.child {
    if (isWasi) {
        const handle = Wasm.formDataWasm(evt.id);
        const obj = Vapor.finalizeObject(handle);
        var cloned_form: @typeInfo(@TypeOf(form_value)).pointer.child = form_value.*;
        const fields = @typeInfo(@TypeOf(cloned_form)).@"struct".fields;
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
                            Vapor.printlnErr("Error parsing int field {s} value {s} {any}", .{ field.name, obj_value.string, err });
                            break :blk 0;
                        };
                    } else {
                        @field(cloned_form, field.name) = @intCast(obj_value.int);
                        Vapor.printlnSrcErr("WE NEED TO CHECK THIS SO THAT THE SIGNDNESS IS OKAY", .{}, @src());
                    }
                },
                else => {
                    Vapor.printlnErr("Cannot set non string or int float types TYPE: {any}", .{@TypeOf(obj_value)});
                },
            }
        }
        return cloned_form;
    }
    return null;
}

pub fn preventDefault(evt: *Event) void {
    if (isWasi) {
        Wasm.eventPreventDefault(evt.id);
    }
}

pub fn clientX(evt: *Event) f32 {
    const key_str: []const u8 = "clientX";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

pub fn clientY(evt: *Event) f32 {
    const key_str: []const u8 = "clientY";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

pub fn offsetX(evt: *Event) f32 {
    const key_str: []const u8 = "offsetX";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

pub fn offsetY(evt: *Event) f32 {
    const key_str: []const u8 = "offsetY";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

pub fn movementX(evt: *Event) f32 {
    const key_str: []const u8 = "movementX";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

pub fn movementY(evt: *Event) f32 {
    const key_str: []const u8 = "movementY";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

// Static buffers for the dummy returns
var dummy_string_buffer: [256:0]u8 = undefined;
pub fn getEventData(id: u32, ptr: [*]const u8, len: u32) [*:0]u8 {
    if (isWasi) {
        return Wasm.getEventDataWasm(id, ptr, len);
    } else {
        // Dummy implementation - return empty string
        @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        const dummy_value = "dummy_event_data";
        @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        return &dummy_string_buffer;
    }
}

pub fn getEventDataInput(id: u32) [*:0]u8 {
    if (isWasi) {
        return Wasm.getEventDataInputWasm(id);
    } else {
        // Dummy implementation - return empty string
        @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        const dummy_value = "dummy_input_value";
        @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        return &dummy_string_buffer;
    }
}

pub fn getEventDataNumber(id: u32, ptr: [*]const u8, len: u32) f32 {
    if (isWasi) {
        return Wasm.getEventDataNumberWasm(id, ptr, len);
    } else {
        // Dummy implementation - return 0.0
        return 0.0;
    }
}

export fn eventCallback(id: u32) void {
    const evt_node = Vapor.events_callbacks.get(id) orelse unreachable;
    var event = Event{
        .id = id,
        .type = evt_node.evt_type,
    };
    @call(.auto, evt_node.cb, .{&event});
    if (Vapor.mode == .atomic and evt_node.evt_type != .pointermove and evt_node.ui_node.?.type != .Form) {
        Vapor.cycle();
    }
}

export fn eventInstCallback(id: u32) void {
    const evt_node = Vapor.events_inst_callbacks.get(id).?;
    var event = Event{
        .id = id,
        .type = evt_node.evt_type,
    };
    @call(.auto, evt_node.data.evt_cb, .{ &evt_node.data, &event });
    if (Vapor.mode == .atomic and evt_node.evt_type != .pointermove and evt_node.evt_type != .submit) {
        Vapor.cycle();
    }
}

export fn registerAllListenerCallbacks() void {
    if (!isWasi) return;
    var evt_itr = Vapor.nodes_with_events.iterator();
    while (evt_itr.next()) |entry| {
        const ui_node = entry.value_ptr.*;
        if (ui_node.event_handlers) |handlers| {
            for (handlers.handlers.items) |handler| {
                if (handler.ctx_aware) {
                    const ctx_node: *const Vapor.CtxAwareEventNode = @ptrCast(@alignCast(handler.cb_opaque));
                    @call(.auto, ctx_node.data.runFn, .{&ctx_node.data});
                    // _ = Vapor.elementInstEventListener(ui_node.uuid, handler.type, ctx_node.data.arguments, ctx_node.data.runFn);
                    // _ = Vapor.elementInstEventListener(ui_node.uuid, handler.type, handler.cb_opaque, evt_node.cb);
                } else {
                    const cb: *const fn (*Vapor.Event) void = @ptrCast(@alignCast(handler.cb_opaque));
                    _ = Vapor.elementEventListener(ui_node, handler.type, cb);
                }
            }
        }
    }
}
