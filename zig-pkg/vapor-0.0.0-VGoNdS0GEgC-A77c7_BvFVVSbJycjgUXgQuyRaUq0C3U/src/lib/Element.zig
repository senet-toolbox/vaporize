const types = @import("types.zig");
const Vapor = @import("Vapor.zig");
const UINode = @import("UITree.zig").UINode;
const ElementType = @import("types.zig").ElementType;
const std = @import("std");
const isWasi = Vapor.isWasi;
const Wasm = @import("wasm");
const Event = @import("Event.zig");
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Style = @import("types.zig").Style;

const Rect = struct {
    top: f32,
    left: f32,
    right: f32,
    bottom: f32,
    width: f32,
    height: f32,
};

const Offsets = struct {
    offset_top: f32,
    offset_left: f32,
    offset_right: f32,
    offset_bottom: f32,
    offset_width: f32,
    offset_height: f32,
};

const AttributeType = union(enum) {
    string: []const u8,
    number: f32,
};

pub const Element = struct {

    // Size and position related
    client_height: f32 = 0,
    client_width: f32 = 0,
    client_left: f32 = 0,
    client_top: f32 = 0,
    offset_height: f32 = 0,
    offsetWidth: u32 = 0,
    offset_left: f32 = 0,
    offset_top: f32 = 0,
    scroll_height: f32 = 0,
    scroll_width: f32 = 0,
    scroll_left: u32 = 0,
    scroll_top: u32 = 0,

    // Element properties
    id: ?[]const u8 = null,
    attribute: ?[]const u8 = null,
    draggable: bool = false,
    element_type: ElementType = .Box,
    _node_ptr: ?*UINode = null,
    text: []const u8 = "",
    on_change: ?*const fn (event: *Event) void = null,
    on_hover: ?*const fn (event: *Event) void = null,
    on_submit: ?*const fn (event: *Event) void = null,
    on_focus: ?*const fn (event: *Event) void = null,
    on_blur: ?*const fn (event: *Event) void = null,

    style: struct {
        top: f32 = 0,
        left: f32 = 0,
        right: f32 = 0,
        bottom: f32 = 0,
        background: []const u8 = "white",
    } = .{},

    pub fn _get_id(self: *Element) ?[]const u8 {
        if (self._node_ptr) |node| {
            return node.uuid;
        } else if (self.id) |id| {
            return id;
        } else {
            return null;
        }
    }
    pub fn scrollTop(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "scrollTop";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        self.scroll_top = value;
    }

    pub fn toOffsetWidth(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "offsetWidth";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        @field(self, attribute) = value;
    }

    pub fn getAttributeNumber(self: *Element, attribute: []const u8) u32 {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return 0;
        };
        return Vapor.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    pub fn cursorPosition(self: *Element) u32 {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return 0;
        };
        const attribute: []const u8 = "selectionStart";
        return Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    pub fn setCursorPosition(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Wasm.setCursorPositionWasm(id.ptr, id.len, value);
    }

    pub fn mutate(self: *Element, attribute: []const u8, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        @field(self, attribute) = value;
    }

    pub fn addInstListener(
        self: *const Element,
        event_type: types.EventType,
        cb: anytype,
        construct: anytype,
    ) ?usize {
        const ui_node = self._node_ptr orelse {
            Vapor.printlnSrc("Node is null", .{}, @src());
            return null;
        };
        return Vapor.elementInstEventListener(ui_node, event_type, construct, cb);
    }

    // pub fn getElementUnderMouse(self: *Element) ?Element {
    //     const ui_node = self._node_ptr orelse {
    //         Vapor.printlnSrc("Node is null", .{}, @src());
    //         return null;
    //     };
    //     const id_ptr = Wasm.getElementUnderMouse();
    //     const id = std.mem.span(id_ptr);
    //     defer Vapor.allocator_global.free(id);
    // }

    pub fn addListener(self: *Element, event_type: types.EventType, cb: *const fn (event: *Event) void) ?usize {
        const ui_node = self._node_ptr orelse {
            Vapor.printlnSrc("Node is null", .{}, @src());
            return null;
        };
        if (isWasi) {
            return Vapor.elementEventListener(ui_node, event_type, cb);
        } else {
            return 0;
        }
    }

    pub fn removeListener(
        self: *Element,
        event_type: types.EventType,
        cb_idx: usize,
    ) ?bool {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Vapor.destroyElementEventListener(id, event_type, cb_idx);
    }

    pub fn removeInstListener(
        self: *Element,
        event_type: types.EventType,
        cb_idx: usize,
    ) ?bool {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Vapor.destroyElementInstEventListener(id, event_type, cb_idx);
    }

    pub fn mutateStyle(self: *Element, style: *const Style) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };

        const fields = @typeInfo(Style).@"struct".fields;
        inline for (fields) |field| {
            const field_value = @field(style, field.name);
            const field_name = field.name;
            const field_type = field.type;
            switch (field_type) {
                []const u8 => {
                    mutateDomElementStyleString(
                        id.ptr,
                        id.len,
                        field_name.ptr,
                        field_name.len,
                        field_value.ptr,
                        field_value.len,
                    );
                },
                // Color => {
                //     mutateDomElementStyle(
                //         id.ptr,
                //         id.len,
                //         field_name.ptr,
                //         field_name.len,
                //         field_value.Literal.r,
                //         field_value.Literal.g,
                //         field_value.Literal.b,
                //         field_value.Literal.a,
                //     );
                // },
                else => {},
            }
        }
    }

    pub fn scrollLeft(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "scrollLeft";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        self.scroll_left = value;
    }

    pub fn getOffsets(self: *Element) ?Offsets {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        // const bounds_ptr = Vapor.getOffsets(id.ptr, @intCast(id.len));
        const bounds_ptr = if (isWasi) {
            return Wasm.getOffsetsWasm(id.ptr, id.len);
        } else {
            // Dummy implementation - return offsets with fake values
            // Assuming offsets contain [offsetX, offsetY]
            dummy_float_buffer[0] = 0.0; // offsetX
            dummy_float_buffer[1] = 0.0; // offsetY
            return &dummy_float_buffer;
        };

        return Offsets{
            .offset_top = bounds_ptr[0],
            .offset_left = bounds_ptr[1],
            .offset_right = bounds_ptr[2],
            .offset_bottom = bounds_ptr[3],
            .offset_width = bounds_ptr[4],
            .offset_height = bounds_ptr[5],
        };
    }

    pub fn getBoundingClientRect(self: *Element) ?Rect {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };

        const bounds_ptr = if (isWasi) {
            return Wasm.getBoundingClientRectWasm(id.ptr, id.len);
        } else {
            // Dummy implementation - return rectangle with fake values
            // Typically: [x, y, width, height, top, right, bottom, left]
            dummy_float_buffer[0] = 0.0; // x
            dummy_float_buffer[1] = 0.0; // y
            dummy_float_buffer[2] = 100.0; // width
            dummy_float_buffer[3] = 50.0; // height
            dummy_float_buffer[4] = 0.0; // top
            dummy_float_buffer[5] = 100.0; // right
            dummy_float_buffer[6] = 50.0; // bottom
            dummy_float_buffer[7] = 0.0; // left
            return &dummy_float_buffer;
        };

        return Rect{
            .top = bounds_ptr[0],
            .left = bounds_ptr[1],
            .right = bounds_ptr[2],
            .bottom = bounds_ptr[3],
            .width = bounds_ptr[4],
            .height = bounds_ptr[5],
        };
    }

    pub fn removeFromParent(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Vapor.removeFromParent(id.ptr, id.len);
    }

    pub fn clear(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const text = "";
        setTextFieldValue(id.ptr, @intCast(id.len), text.ptr, text.len);
    }
    pub fn setText(self: *Element, text: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        self.text = text;
        setTextFieldValue(id.ptr, @intCast(id.len), text.ptr, text.len);
    }

    pub fn getInputValue(self: *Element) ?[]const u8 {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        // const resp = if (isWasi) {
        const resp = Wasm.getInputValueWasm(id.ptr, id.len);
        // } else {
        //     // Dummy implementation - return empty string
        //     @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        //     const dummy_value = "dummy_input_value";
        //     @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        //     return &dummy_string_buffer;
        // };
        return std.mem.span(resp);
    }

    pub fn addChild(self: *Element, childId: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Vapor.addChild(id.ptr, id.len, childId.ptr, childId.len);
    }

    pub fn focus(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (self.element_type != .TextField) {
            Vapor.println("Can only focus on TextField Element, add element Type Input\n", .{});
            return;
        }
        // Vapor.addClass(id.ptr, id.len, classId.ptr, classId.len);
        Vapor.focus(id);
    }

    pub fn focused(self: *Element) bool {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return false;
        };
        return Vapor.focused(id);
    }

    pub fn addClass(self: *Element, classId: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        }; // Vapor.addClass(id.ptr, id.len, classId.ptr, classId.len);
        Vapor.addToClassesList(id, classId);
    }

    pub fn removeClass(self: *Element, classId: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        }; // Vapor.removeClass(id.ptr, id.len, classId.ptr, classId.len);
        Vapor.addToRemoveClassesList(id, classId);
    }

    pub fn click(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (self.element_type != .Input) {
            Vapor.println("Must be Input type", .{});
            return;
        }
        Vapor.callClickWASM(id.ptr, id.len);
    }
    pub fn startVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.startVideoWasm(id.ptr, id.len);
    }

    pub fn playVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.playVideoWasm(id.ptr, id.len);
    }

    pub fn pauseVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.pauseVideoWasm(id.ptr, id.len);
    }

    pub fn stopCamera(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.stopCameraWasm(id.ptr, id.len);
    }

    pub fn seekVideo(self: *Element, time: f32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.seekVideoWasm(id.ptr, id.len, time);
    }

    pub fn setVolume(self: *Element, volume: f32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.setVolumeWasm(id.ptr, id.len, volume);
    }

    pub fn muteVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.muteVideoWasm(id.ptr, id.len);
    }

    pub fn getVideoDuration(self: *Element) f32 {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        return Wasm.getVideoDurationWasm(id.ptr, id.len);
    }

    pub fn getVideoCurrentTime(self: *Element) f32 {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        return Wasm.getVideoCurrentTimeWasm(id.ptr, id.len);
    }

    pub fn translate3d(element: *Element, translation: Translate3d) void {
        const id = element._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            unreachable;
        };
        Wasm.translate3dWasm(id.ptr, id.len, translation.toString().ptr, translation.toString().len);
    }
};

pub fn setTextFieldValue(ptr: [*]const u8, len: u32, text_ptr: [*]const u8, text_len: u32) void {
    if (isWasi) {
        return Wasm.setInputValueWasm(ptr, len, text_ptr, text_len);
    } else {
        // Dummy implementation - return empty string
        return void;
    }
}

pub fn mutateDomElement(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: u32,
) void {
    if (isWasi) {
        Wasm.mutateDomElementWasm(id_ptr, id_len, attribute, attribute_len, value);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            Vapor.println("DOM: Would set element '{s}' attribute '{s}' to {d}\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

const Translate3d = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    pub fn toString(self: *const Translate3d) []const u8 {
        return Vapor.fmtln("translate3d({d}px, {d}px, 0)", .{
            self.x,
            self.y,
                // self.z,
        });
    }
};

pub fn mutateDomElementStyle(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void {
    if (isWasi) {
        Wasm.mutateDomElementStyleWasm(id_ptr, id_len, attribute, attribute_len, value);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            Vapor.println("DOM: Would set element '{s}' style '{s}' to {d:.2}\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

pub fn mutateDomElementStyleString(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void {
    if (isWasi) {
        Wasm.mutateDomElementStyleStringWasm(id_ptr, id_len, attribute, attribute_len, value_ptr, value_len);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            const value = value_ptr[0..value_len];
            Vapor.println("DOM: Would set element '{s}' style '{s}' to '{s}'\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

pub export fn getOnFocusCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        unreachable;
    };
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_focus_hash);
    return onid;
}

pub export fn getOnHoverCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        unreachable;
    };
    if (self.on_hover == null) return 0;
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_hover_hash);
    return onid;
}

pub export fn getOnChangeCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        unreachable;
    };
    if (self.on_change == null) return 0;
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_change_hash);
    return onid;
}

pub export fn getOnBlurCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        unreachable;
    };
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_blur_hash);
    return onid;
}

var dummy_float_buffer: [8]f32 = undefined;
var dummy_string_buffer: [256:0]u8 = undefined;
