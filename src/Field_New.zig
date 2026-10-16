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

var background: Vapor.Types.Color = .palette(.background);

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
var focused: ?[]const u8 = null;

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

pub fn creditCardCallback(credit_card_buf: *[]const u8, evt: *Vapor.Event) void {
    credit_card_buf.* = evt.text();
    const text = evt.text();

    if (text.len == 0) {
        credit_card_buf.* = "";
        return;
    }

    if (text.len > 16) return;
    var buf: [32]u8 = undefined;
    const formatted = formatCreditCard(evt.text(), buf[0..]);
    credit_card_buf.* = std.fmt.allocPrint(Vapor.arena(.frame), "{s}", .{formatted}) catch unreachable;
}

/// Format expiry date: "1225" -> "12/25"
pub fn formatExpiry(input: []const u8, buf: []u8) []u8 {
    var digits: [4]u8 = undefined;
    var digit_count: usize = 0;

    // Extract only digits (max 4)
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            if (digit_count < 4) {
                digits[digit_count] = c;
                digit_count += 1;
            }
        }
    }

    var out_idx: usize = 0;

    // First 2 digits (month)
    for (digits[0..@min(digit_count, 2)]) |c| {
        buf[out_idx] = c;
        out_idx += 1;
    }

    // Add separator after month
    if (digit_count > 2) {
        buf[out_idx] = '/';
        out_idx += 1;
    }

    // Last 2 digits (year)
    if (digit_count > 2) {
        for (digits[2..digit_count]) |c| {
            buf[out_idx] = c;
            out_idx += 1;
        }
    }

    return buf[0..out_idx];
}

fn expiryCallback(expiry_buf: *[]const u8, evt: *Vapor.Event) void {
    expiry_buf.* = evt.text();
    const text = evt.text();
    if (text.len == 0) {
        expiry_buf.* = "";
        return;
    }

    if (text.len > 4) return;
    var buf: [32]u8 = undefined;
    const formatted = formatExpiry(evt.text(), buf[0..]);
    expiry_buf.* = Vapor.fmtln("{s}", .{formatted});
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

fn telephoneCallback(telephone_buf: *[]const u8, evt: *Vapor.Event) void {
    const text = evt.text();
    if (text.len == 0 or text.len > 10) {
        telephone_buf.* = text;
        return;
    }
    var buf: [32]u8 = undefined;
    const formatted = formatPhone(text, buf[0..]);
    telephone_buf.* = Vapor.fmtln("{s}", .{formatted});
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
placeholder: ?[]const u8 = null,
backgroud: ?Vapor.Types.Color = null,

fn handleFocus(id: []const u8, _: *Vapor.Event) void {
    if (focus_states != null) {
        // We only track the active focus.
        // Optional: You could clear other keys here if you want strictly one focus.
        focused = id;
        focus_states.?.put(id, true) catch unreachable;
    }
}

fn handleBlur(id: []const u8, _: *Vapor.Event) void {
    if (focus_states != null) {
        focused = null;
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
        .expiry => .string,
        .cvv => .string,
    };
}

fn ErasedField(field: Field, field_id: []const u8) Vapor.TextFieldBuilder(.pure) {
    const field_type = getFieldType(field.type);

    return TextField(field_type)
        .id(field_id)
        .fieldName(field.field_name)
        .font(14, 300, null)
        .padding(.xy(12, 8))
        .outline(.none, null)
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
            .string, .cvv => {
                const string_field = Vapor.arena(.persist).create([]const u8) catch unreachable;
                string_field.* = if (default_value) |default| default.string else "";
                const value = FieldValue{ .string = string_field };
                field_values.put(stable_id_alloc, value) catch unreachable;
                focus_states.?.put(stable_id_alloc, false) catch unreachable;
                return value;
            },
            .expiry => {
                const string_field = Vapor.arena(.persist).create([]const u8) catch unreachable;
                var formatted: []const u8 = "";
                if (default_value) |default| {
                    formatted = default.string;
                    var buf: [32]u8 = undefined;
                    formatted = std.fmt.allocPrint(Vapor.arena(.frame), "{s}", .{formatExpiry(default.string, buf[0..])}) catch unreachable;
                }
                string_field.* = formatted;
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

fn renderLabel(label: []const u8, label_left: f32, trans: f32, scale: f32, z_index: f32, text_color: Vapor.Types.Color) Vapor.Builder(.pure) {
    return Label(label)
        .background(background)
        .pos(.{ .left = .px(label_left), .type = .absolute })
        .padding(.horizontal(2))
        .transition(.{
            .properties = &.{ .transform, .left },
            .duration = 100,
            .timing = .easeInOut,
        })
        .font(14, 300, text_color)
        .inlineStyle("transform: translateY({d}%) scale({d}); z-index: {d};", .{ trans, scale, z_index })
        .fontFamily("Montserrat");
}

pub fn render(field: Field) void {
    const container = Container();
    const stable_id = container.getUUID();
    const value = field.value orelse createValue(stable_id, field.type, field.default_value);

    // 1. Check focus state
    const is_focused = if (focus_states) |fs| fs.get(stable_id) orelse false else false;

    // 2. Animation / Style variables
    const trans: f32 = if (is_focused or field.trans_label or checkLength(value) or field.placeholder != null) -50 else 50;
    const scale: f32 = if (is_focused or field.trans_label or checkLength(value) or field.placeholder != null) 0.9 else 1;
    // Adjust label left position if there is a left icon so it doesn't clash
    const label_left: f32 = if (is_focused or field.trans_label) 12 + 12 else 12;

    const z_index: f32 = if (is_focused) 10 else 0;

    // 3. Calculate Input Padding based on icons
    // We reserve ~40px of space if an icon is present

    const active_background_color: Vapor.Types.Color = if (field.backgroud) |bg| bg else .palette(.tint);
    const text_color: Vapor.Types.Color = if (is_focused) active_background_color else .transparentize(.palette(.text_color), 0.8);

    container.border(.round(if (is_focused) active_background_color else .palette(.border_color_light), .all(12)))
        .shadow(.glow(3, if (is_focused) .transparentize(active_background_color, 0.2) else .transparent))
        .onDestroy(destroy, .{stable_id})
        .children({
        const field_id = Vapor.fmtln("{s}_{s}", .{ field.field_name, stable_id });
        var label_component: ?Vapor.Builder(.pure) = null;
        if (field.label) |label| {
            label_component = renderLabel(label, label_left, trans, scale, z_index, text_color);
            label_component.?.fieldName(field_id).end();
        }

        const text_field: Vapor.TextFieldBuilder(.pure) = ErasedField(field, field_id);

        // --- 3. RENDER LABEL ---
        // --- 4. RENDER INPUT FIELD ---
        switch (field.type) {
            .string => {
                text_field
                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .border(.none)
                    .width(.percent(100))
                    .bind(value.string)
                    .placeholder(if (field.placeholder) |placeholder| placeholder else "")
                    .end();
            },
            .expiry => {
                text_field
                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .border(.none)
                    .width(.percent(100))
                    .onEvent(.input, expiryCallback, .{value.string})
                    .val(value.string)
                    .placeholder(if (field.placeholder) |placeholder| placeholder else "")
                    .end();
            },
            .cvv => {
                text_field
                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .border(.none)
                    .width(.percent(100))
                    .bind(value.string)
                    .placeholder(if (field.placeholder) |placeholder| placeholder else "")
                    .end();
            },
            .telephone => {
                text_field
                    // .pos(.absolute)
                    // .onEventCtx(.focus, handleFocus, .{stable_id})
                    // .onEventCtx(.blur, handleBlur, .{stable_id})
                    // .border(.none)
                    // .width(.percent(100))
                    // .bind(value.telephone)
                    // .placeholder(if (field.placeholder) |placeholder| placeholder else "")

                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .border(.none)
                    .width(.percent(100))
                    .onEvent(.input, telephoneCallback, .{value.telephone})
                    .val(value.telephone)
                    .placeholder(if (field.placeholder) |placeholder| placeholder else "")
                    .end();
            },
            .credit_card => {
                text_field
                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .border(.none)
                    .width(.percent(100))
                    .onEvent(.input, creditCardCallback, .{value.credit_card})
                    .val(value.credit_card)
                    .config(.{ .max = 19 })
                    .placeholder(if (field.placeholder) |placeholder| placeholder else "")
                    .end();
            },
            .email => {
                text_field
                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .width(.percent(100))
                    .bind(value.email)
                    .border(.none)
                    .placeholder(if (field.placeholder) |placeholder| placeholder else "")
                    .end();
            },
            .password => {
                text_field
                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .width(.percent(100))
                    .bind(value.password)
                    .border(.none)
                    .placeholder(if (field.placeholder) |placeholder| placeholder else "")
                    .end();
            },
            .number => {
                text_field
                    // OVERRIDE Padding here to account for icons
                    .pos(.absolute)
                    .onEvent(.focus, handleFocus, .{stable_id})
                    .onEvent(.blur, handleBlur, .{stable_id})
                    .border(.none)
                    .width(.percent(100))
                    .bind(value.number)
                    .border(.none)
                    .config(field.config)
                    // .placeholder(if (field.placeholder) |placeholder| placeholder else 0)
                    .end();
            },
        }
    });
}
