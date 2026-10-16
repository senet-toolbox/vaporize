const Vapor = @import("vapor");
const std = @import("std");
const Box = Vapor.Box;
const Text = Vapor.Text;
const TextField = Vapor.TextField;
const Stack = Vapor.Stack;
const Center = Vapor.Center;
const Icon = Vapor.Icon;
const Label = Vapor.Label;
const utils = Vapor.utils;
const FieldType = @import("Form.zig").FieldType;

var background: Vapor.Types.Background = .palette(.background);

const FieldValue = union(enum) {
    string: *[]const u8,
    password: *[]const u8,
    number: *i32,
    bool: *bool,
    email: *[]const u8,
    credit_card: *[]const u8,
    telephone: *[]const u8,
};

pub fn new() void {
    focus_states = std.StringHashMap(bool).init(Vapor.arena(.persist));
    field_values = std.StringHashMap(FieldValue).init(Vapor.arena(.persist));
}

// Change the map type
var focus_states: ?std.StringHashMap(bool) = null;

var field_values: std.StringHashMap(FieldValue) = undefined;

// Helper to extract the unique ID from the input value
fn getPtrId(val: FieldValue) usize {
    return switch (val) {
        .string => |ptr| @intFromPtr(ptr),
        .number => |ptr| @intFromPtr(ptr),
        .bool => |ptr| @intFromPtr(ptr),
        .password => |ptr| @intFromPtr(ptr),
        .email => |ptr| @intFromPtr(ptr),
        .credit_card => |ptr| @intFromPtr(ptr),
        .telephone => |ptr| @intFromPtr(ptr),
    };
}

fn toggleFocus(id: []const u8, _: *Vapor.Event) void {
    if (focus_states == null) return;
    // We only track the currently focused item, so we can just put it
    // If you want to support multi-focus, use get/put logic
    focus_states.?.put(id, true) catch unreachable;
}

/// Format credit card: "1234567890123456" -> "1234 5678 9012 3456"
pub fn formatCreditCard(input: []const u8, buf: []u8) []u8 {
    var digits: [16]u8 = undefined;
    var digit_count: usize = 0;

    // Extract only digits (max 16)
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            if (digit_count < 16) {
                digits[digit_count] = c;
                digit_count += 1;
            }
        }
    }

    // Format with spaces every 4 digits
    var out_idx: usize = 0;
    for (digits[0..digit_count], 0..) |c, i| {
        if (i > 0 and i % 4 == 0) {
            buf[out_idx] = ' ';
            out_idx += 1;
        }
        buf[out_idx] = c;
        out_idx += 1;
    }

    return buf[0..out_idx];
}

pub fn creditCardCallback(callback: Callback, evt: *Vapor.Event) void {
    const credit_card_buf = callback.value.credit_card;
    const text = evt.text();
    if (text.len == 0) return;
    if (text.len > 16) return;
    var buf: [32]u8 = undefined;
    const formatted = formatCreditCard(evt.text(), buf[0..]);
    credit_card_buf.* = Vapor.fmtln("{s}", .{formatted});
}

pub fn formatPhone(input: []const u8, buf: []u8) []u8 {
    var digits: [10]u8 = undefined;
    var digit_count: usize = 0;

    // Extract only digits (max 10)
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            if (digit_count < 10) {
                digits[digit_count] = c;
                digit_count += 1;
            }
        }
    }

    var out_idx: usize = 0;

    if (digit_count >= 1) {
        buf[out_idx] = '(';
        out_idx += 1;
    }

    // First 3 digits
    for (digits[0..@min(digit_count, 3)]) |c| {
        buf[out_idx] = c;
        out_idx += 1;
    }

    if (digit_count >= 3) {
        buf[out_idx] = ')';
        out_idx += 1;
        buf[out_idx] = ' ';
        out_idx += 1;
    }

    // Next 3 digits
    if (digit_count > 3) {
        for (digits[3..@min(digit_count, 6)]) |c| {
            buf[out_idx] = c;
            out_idx += 1;
        }
    }

    if (digit_count >= 6) {
        buf[out_idx] = '-';
        out_idx += 1;
    }

    // Last 4 digits
    if (digit_count > 6) {
        for (digits[6..digit_count]) |c| {
            buf[out_idx] = c;
            out_idx += 1;
        }
    }

    return buf[0..out_idx];
}

fn telephoneCallback(callback: Callback, evt: *Vapor.Event) void {
    const telephone_buf = callback.value.telephone;
    const text = evt.text();
    if (text.len == 0) return;
    if (text.len > 10) return;
    var buf: [32]u8 = undefined;
    const formatted = formatPhone(evt.text(), buf[0..]);
    telephone_buf.* = Vapor.fmtln("{s}", .{formatted});
    if (callback.on_change) |on_change| {
        on_change(evt);
    }
}

fn stringCallback(callback: Callback, evt: *Vapor.Event) void {
    const string_buf = callback.value.string;
    const text = evt.text();
    string_buf.* = text;

    if (callback.on_change) |on_change| {
        on_change(evt);
    }
}

fn passwordCallback(callback: Callback, evt: *Vapor.Event) void {
    const password_buf = callback.value.password;
    const text = evt.text();
    password_buf.* = text;

    if (callback.on_change) |on_change| {
        on_change(evt);
    }
}

fn emailCallback(callback: Callback, evt: *Vapor.Event) void {
    const email_buf = callback.value.email;
    const text = evt.text();
    email_buf.* = text;

    if (callback.on_change) |on_change| {
        on_change(evt);
    }
}

fn numberCallback(callback: Callback, evt: *Vapor.Event) void {
    const number_buf = callback.value.number;
    const number = evt.number() catch 0;
    number_buf.* = number;

    if (callback.on_change) |on_change| {
        on_change(evt);
    }
}

const Field = @This();
label: ?[]const u8 = null,
field_name: []const u8 = "",
type: FieldType = .string,
trans_label: bool = false,
/// Field must be a stable pointer, do not use a pointer within a render function, this is considered unsafe undefined behavior.
value: ?FieldValue = null,
config: Vapor.Types.TextFieldConfig = .{},
default_value: ?DefaultValue = null,
on_change: ?*const fn (evt: *Vapor.Event) void = null,

fn handleFocus(id: []const u8, _: *Vapor.Event) void {
    Vapor.print("Focus: {s}\n", .{id});
    if (focus_states != null) {
        // We only track the active focus.
        // Optional: You could clear other keys here if you want strictly one focus.
        focus_states.?.put(id, true) catch unreachable;
    }
}

fn handleBlur(id: []const u8, _: *Vapor.Event) void {
    if (focus_states != null) {
        focus_states.?.put(id, false) catch unreachable;
    }
}

fn getFieldType(field_value: FieldType) Vapor.Types.InputTypes {
    return switch (field_value) {
        .string => .string,
        .number => .int,
        .password => .password,
        .email => .email,
        .credit_card => .string,
        .telephone => .string,
        else => .string,
    };
}

fn ErasedField(field: Field) Vapor.TextFieldBuilder(.pure) {
    const field_type = getFieldType(field.type);

    return TextField(field_type)
        .fieldName(field.field_name)
        .font(14, 300, null)
        .padding(.xy(12, 8))
        .outline(.none)
        .background(.transparent)
        .fontFamily("Montserrat")
        .font(14, 300, .palette(.text_color));
}

fn destroy(stable_id: []const u8) void {
    _ = focus_states.?.remove(stable_id);
}

fn checkLength(value: FieldValue) bool {
    switch (value) {
        .string, .telephone, .credit_card, .email, .password => |v| {
            if (v.*.len > 0) {
                return true;
            }
        },
        .number => |v| {
            if (v.* > 0) {
                return true;
            }
        },
        else => {},
    }
    return false;
}

fn Container() Vapor.Builder(.pure) {
    return Stack()
        .width(.percent(100))
        .spacing(8)
        .pos(.relative)
        .height(.px(36));
}

pub const DefaultValue = union(enum) {
    string: []const u8,
    number: i32,
    bool: bool,
};

fn createValue(stable_id: []const u8, field_type: FieldType, default_value: ?DefaultValue) FieldValue {
    return field_values.get(stable_id) orelse {
        const stable_id_alloc = Vapor.arena(.persist).alloc(u8, stable_id.len) catch unreachable;
        @memcpy(stable_id_alloc, stable_id);
        return switch (field_type) {
            .string, .cvv, .expiry => {
                const string_field = Vapor.arena(.persist).create([]const u8) catch unreachable;
                string_field.* = if (default_value) |default| default.string else "";
                const value = FieldValue{ .string = string_field };
                field_values.put(stable_id_alloc, value) catch unreachable;
                focus_states.?.put(stable_id_alloc, false) catch unreachable;
                return value;
            },
            .credit_card => {
                const string_field = Vapor.arena(.persist).create([]const u8) catch unreachable;
                var formatted: []const u8 = "";
                if (default_value) |default| {
                    formatted = default.string;
                    var buf: [32]u8 = undefined;
                    formatted = std.fmt.allocPrint(Vapor.arena(.frame), "{s}", .{formatCreditCard(default.string, buf[0..])}) catch unreachable;
                }
                string_field.* = formatted;
                const value = FieldValue{ .credit_card = string_field };
                field_values.put(stable_id_alloc, value) catch unreachable;
                focus_states.?.put(stable_id_alloc, false) catch unreachable;
                return value;
            },
            .password => {
                const string_field = Vapor.arena(.persist).create([]const u8) catch unreachable;
                string_field.* = if (default_value) |default| default.string else "";
                const value = FieldValue{ .password = string_field };
                field_values.put(stable_id_alloc, value) catch unreachable;
                focus_states.?.put(stable_id_alloc, false) catch unreachable;
                return value;
            },
            .email => {
                const string_field = Vapor.arena(.persist).create([]const u8) catch unreachable;
                string_field.* = if (default_value) |default| default.string else "";
                const value = FieldValue{ .email = string_field };
                field_values.put(stable_id_alloc, value) catch unreachable;
                focus_states.?.put(stable_id_alloc, false) catch unreachable;
                return value;
            },
            .number => {
                const int_field = Vapor.arena(.persist).create(i32) catch unreachable;
                int_field.* = if (default_value) |default| default.number else 0;
                const value = FieldValue{ .number = int_field };
                field_values.put(stable_id_alloc, value) catch unreachable;
                focus_states.?.put(stable_id_alloc, false) catch unreachable;
                return value;
            },
            .telephone => {
                const telephone_field = Vapor.arena(.persist).create([]const u8) catch unreachable;
                telephone_field.* = if (default_value) |default| default.string else "";
                const value = FieldValue{ .telephone = telephone_field };
                field_values.put(stable_id_alloc, value) catch unreachable;
                focus_states.?.put(stable_id_alloc, false) catch unreachable;
                return value;
            },
        };
    };
}

const Callback = struct {
    value: FieldValue,
    on_change: ?*const fn (evt: *Vapor.Event) void,
};

pub fn render(field: Field) void {
    const container = Container();
    const stable_id = container.getUUID();
    const value = field.value orelse createValue(stable_id, field.type, field.default_value);

    // 1. Check focus state
    const is_focused = if (focus_states) |fs| fs.get(stable_id) orelse false else false;

    // 2. Animation / Style variables
    const trans: f32 = if (is_focused or field.trans_label or checkLength(value)) -50 else 50;
    const scale: f32 = if (is_focused or field.trans_label or checkLength(value)) 0.9 else 1;
    // Adjust label left position if there is a left icon so it doesn't clash
    const label_left: f32 = if (is_focused or field.trans_label) 12 + 12 else 12;

    const z_index: f32 = if (is_focused) 10 else 0;
    const text_color: Vapor.Types.Color = if (is_focused) .palette(.tint) else .transparentize(.palette(.text_color), 0.5);

    // 3. Calculate Input Padding based on icons
    // We reserve ~40px of space if an icon is present

    container.border(.round(if (is_focused) .palette(.tint) else .palette(.border_color_light), .all(12)))
        .shadow(.{
            .color = if (is_focused) .transparentize(.palette(.tint), 0.2) else .transparent,
            .spread = 3,
        })
        .children({
        Vapor.Static.HooksCtx(.destroy, destroy, .{stable_id})({
            // --- 3. RENDER LABEL ---
            if (field.label) |label| {
                Label(label)
                    .background(background)
                    .pos(.{ .left = .px(label_left), .type = .absolute })
                    .padding(.horizontal(2))
                    .transition(.{
                        .properties = &.{ .transform, .scale, .left },
                        .duration = 100,
                        .timing = .easeInOut,
                    })
                    .inlineStyle("transform: translateY({d}%) scale({d}); z-index: {d};", .{ trans, scale, z_index })
                    .font(14, 300, text_color)
                    .fontFamily("Montserrat")
                    .end();
            }

            // --- 4. RENDER INPUT FIELD ---
            switch (field.type) {
                .string => {
                    const text_field: Vapor.TextFieldBuilder(.pure) = ErasedField(field);
                    text_field
                        // OVERRIDE Padding here to account for icons
                        .pos(.absolute)
                        .onEvent(.focus, handleFocus, stable_id)
                        .onEvent(.blur, handleBlur, stable_id)
                        .onEvent(.input, stringCallback, Callback{ .value = value, .on_change = field.on_change })
                        .border(.none)
                        .width(.percent(100))
                        .val(value.string)
                        .end();
                },
                .telephone => {
                    const text_field: Vapor.TextFieldBuilder(.pure) = ErasedField(field);
                    text_field
                        // OVERRIDE Padding here to account for icons
                        .pos(.absolute)
                        .onEvent(.focus, handleFocus, stable_id)
                        .onEvent(.blur, handleBlur, stable_id)
                        .border(.none)
                        .width(.percent(100))
                        .onEvent(.input, telephoneCallback, Callback{ .value = value, .on_change = field.on_change })
                        .val(value.telephone)
                        .end();
                },
                .credit_card => {
                    const text_field: Vapor.TextFieldBuilder(.pure) = ErasedField(field);
                    text_field
                        // OVERRIDE Padding here to account for icons
                        .pos(.absolute)
                        .onEvent(.focus, handleFocus, stable_id)
                        .onEvent(.blur, handleBlur, stable_id)
                        .border(.none)
                        .width(.percent(100))
                        .onEvent(.input, creditCardCallback, Callback{ .value = value, .on_change = field.on_change })
                        .val(value.credit_card)
                        .config(.{ .max = 19 })
                        .end();
                },
                .email => {
                    const text_field: Vapor.TextFieldBuilder(.pure) = ErasedField(field);
                    text_field
                        // OVERRIDE Padding here to account for icons
                        .pos(.absolute)
                        .onEvent(.focus, handleFocus, stable_id)
                        .onEvent(.blur, handleBlur, stable_id)
                        .width(.percent(100))
                        .onEvent(.input, emailCallback, Callback{ .value = value, .on_change = field.on_change })
                        .border(.none)
                        .val(value.email)
                        .end();
                },
                .password => {
                    const text_field: Vapor.TextFieldBuilder(.pure) = ErasedField(field);
                    text_field
                        // OVERRIDE Padding here to account for icons
                        .pos(.absolute)
                        .onEvent(.focus, handleFocus, stable_id)
                        .onEvent(.blur, handleBlur, stable_id)
                        .width(.percent(100))
                        .onEvent(.input, passwordCallback, Callback{ .value = value, .on_change = field.on_change })
                        .border(.none)
                        .val(value.password)
                        .end();
                },
                .number => {
                    const text_field: Vapor.TextFieldBuilder(.pure) = ErasedField(field);
                    text_field
                        // OVERRIDE Padding here to account for icons
                        .pos(.absolute)
                        .onEvent(.focus, handleFocus, stable_id)
                        .onEvent(.blur, handleBlur, stable_id)
                        .border(.none)
                        .width(.percent(100))
                        .onEvent(.input, numberCallback, Callback{ .value = value, .on_change = field.on_change })
                        .border(.none)
                        .config(field.config)
                        .end();
                },
                else => {},
            }
        });
    });
}
