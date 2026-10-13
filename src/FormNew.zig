const std = @import("std");
const Vapor = @import("vapor");
const Self = @import("Vaporize.zig").Self;
const Node = @import("Vaporize.zig").Node;
const getUnderlyingType = @import("Vaporize.zig").getUnderlyingType;
const getUnderlyingValue = @import("Vaporize.zig").getUnderlyingValue;
const FormComponent = @import("vapor").Form;
const SubmitButton = @import("vapor").SubmitButton;
const Text = @import("vapor").Text;
const Box = @import("vapor").Box;
const Style = @import("vapor").Style;
const Condition = @import("Vaporize.zig").Condition;
const CallbackEntry = @import("Vaporize.zig").CallbackEntry;
const traversePrint = @import("Vaporize.zig").traversePrint;
const default_style_config = @import("Vaporize.zig").default_style_config;
const TextArea = @import("TextArea.zig");

pub const FieldType = enum {
    string,
    number,
    password,
    email,
    credit_card,
    telephone,
    cvv,
    expiry,
};

fn getFieldType(field_value: FieldType) Vapor.Types.InputTypes {
    return switch (field_value) {
        .string => .string,
        .number => .int,
        .password => .password,
        .email => .email,
        .credit_card => .string,
        .telephone => .string,
        .cvv => .string,
        .expiry => .string,
    };
}

pub var current_parent: ?*Node = null;
pub fn Form(comptime T: type) type {
    return struct {
        const Vaporize = @This();

        const InnerForm = struct {
            form_data: *T,
            validation_error: ?*ValidationResult = null,
            on_submit: ?*const fn (T) void,
            conditionals: std.StringHashMap(bool),
            default_value: ?T = null,
        };

        self: ?*Self = null,
        inner_form: ?*InnerForm = null,
        on_submit: ?*const fn (T) void = null,
        default_value: ?T = null,

        pub fn compile(vaporize: *Vaporize) !void {
            const allocator = Vapor.arena(.persist);
            const inner_self = allocator.create(Self) catch |err| {
                Vapor.printErr("Error: {any}\n", .{err});
                unreachable;
            };
            const style = if (Self.global_style) |s| s else Self.default_style_config;
            inner_self.* = try Self.init(allocator, style);
            const inner_form = try allocator.create(InnerForm);
            const validation_error = allocator.create(ValidationResult) catch |err| {
                Vapor.printErr("Error: {any}\n", .{err});
                unreachable;
            };
            validation_error.* = ValidationResult.init(allocator);

            const form_data = try allocator.create(T);
            form_data.* = T{};

            inner_form.* = .{
                .form_data = form_data,
                .validation_error = validation_error,
                .conditionals = std.StringHashMap(bool).init(Vapor.arena(.persist)),
                .on_submit = vaporize.on_submit,
                .default_value = vaporize.default_value,
            };
            vaporize.inner_form = inner_form;
            vaporize.* = .{
                .self = inner_self,
                .inner_form = inner_form,
                .default_value = vaporize.default_value,
            };

            const root = try vaporize.self.?.createNode(.Form);
            current_parent = null;
            vaporize.self.?.root = root;
            field_index = 0;
            vaporize.self.?.generateForm(vaporize.self.?.root, "root", T, {}, T, vaporize.inner_form.?, vaporize.default_value) catch |err| {
                Vapor.printErr("Error: {any}\n", .{err});
            };
        }
        pub fn render(vaporize: *const Vaporize) void {
            if (vaporize.self == null) {
                std.log.err("Please Instaniate vaporize before using the Form render function\n", .{});
                return;
            }
            if (vaporize.inner_form == null) {
                std.log.err("Please Instaniate vaporize before using the Form render function\n", .{});
                return;
            }
            traverseForm(vaporize.self.?, vaporize.self.?.root, vaporize.inner_form.?) catch |err| {
                std.log.err("Please Instaniate vaporize before using the Form render function\n", .{});
                std.log.err("{any}\n", .{err});
            };
        }
    };
}

pub const Validation = struct {
    err: ?[]const u8 = null,
    // Length constraints (for strings)
    min: ?usize = null,
    max: ?usize = null,

    // Value constraints (for numbers)
    min_value: ?i64 = null,
    max_value: ?i64 = null,

    // Field type validation
    field_type: ?FieldType = .string,

    // Content validation
    includes: ?[]const u8 = null,
    excludes: ?[]const u8 = null,
    pattern: ?[]const u8 = null,

    // Flags
    required: bool = false,
    trim: bool = true, // Trim whitespace before validation

    // Custom validation function
    custom: ?*const fn (value: anytype) bool = null,
    match: bool = false,
    target_field: []const u8 = "",
    depends_on: ?[]const u8 = null,

    placeholder: ?[]const u8 = null,
};

// Validation error structure
pub const ValidationError = struct {
    field: []const u8,
    message: []const u8,
};

// Validation result
pub const ValidationResult = struct {
    valid: bool = true,
    errors: std.array_list.Managed(ValidationError),

    pub fn init(allocator: std.mem.Allocator) ValidationResult {
        return .{
            .errors = std.array_list.Managed(ValidationError).init(allocator),
        };
    }

    pub fn deinit(self: *ValidationResult) void {
        self.errors.deinit();
    }
};

// Main validation function
pub fn validateForm(form_closure: anytype, evt: *Vapor.Event) void {
    evt.preventDefault();

    if (!@hasField(@typeInfo(@TypeOf(form_closure)).pointer.child, "form_data")) {
        Vapor.print("form_data not defined\n", .{});
        return;
    }
    if (!@hasField(@typeInfo(@TypeOf(form_closure)).pointer.child, "on_submit")) {
        Vapor.print("on_submit not defined\n", .{});
        return;
    }

    const form_value = @field(form_closure, "form_data");
    const on_submit = @field(form_closure, "on_submit");

    const result: *ValidationResult = form_closure.validation_error orelse {
        Vapor.printErr("validation_error not defined\n", .{});
        return;
    };
    errdefer result.deinit();

    // Check if validations exist
    if (!@hasDecl(@TypeOf(form_value.*), "__validations")) {
        Vapor.print("No validations defined for form\n", .{});
        return;
    }

    const validations = @TypeOf(form_value.*).__validations;

    // Parse form data
    const parsed_form = evt.formData(form_value) orelse {
        result.valid = false;
        result.errors.append(.{
            .field = "form",
            .message = "Failed to parse form data",
        }) catch {};
        return;
    };

    // Get form fields
    const FormType = @TypeOf(parsed_form);
    const form_fields = @typeInfo(FormType).@"struct".fields;

    result.errors.clearRetainingCapacity();

    // Validate each field
    inline for (form_fields) |field| {
        if (@typeInfo(field.type) == .@"struct") {
            const inner_fields = @typeInfo(field.type).@"struct".fields;
            const section = @field(parsed_form, field.name);

            inline for (inner_fields) |inner_field| {
                const field_name = inner_field.name;

                // Skip if no validation for this field
                if (!@hasField(@TypeOf(validations), field_name)) continue;

                const field_value = @field(section, field_name);
                const validation = @field(validations, field_name);

                // Validate the field
                const field_valid = validateField(field_name, field_value, validation, result) catch |err| {
                    Vapor.printErr("Validation failed: {any}\n", .{err});
                    return;
                };
                if (!field_valid) {
                    result.valid = false;
                } else {
                    if (validation.match) {
                        const target_field_value = @field(section, validation.target_field);
                        const match_valid = matchField(field_value, target_field_value);
                        Vapor.printErr("Validation failed: {any} {any}\n", .{ match_valid, validation.match });
                        if (!match_valid) {
                            result.valid = false;
                            result.errors.append(.{
                                .field = field_name,
                                .message = "Values do not match",
                            }) catch |err| {
                                Vapor.printErr("Error: {any}\n", .{err});
                            };
                        }
                    } else {
                        result.errors.append(.{
                            .field = field_name,
                            .message = "",
                        }) catch |err| {
                            Vapor.printErr("Error: {any}\n", .{err});
                        };
                    }
                }
            }
        } else {

            //////////////////////

            const field_name = field.name;

            // Skip if no validation for this field
            if (!@hasField(@TypeOf(validations), field_name)) continue;

            const field_value = @field(parsed_form, field_name);
            const validation = @field(validations, field_name);

            // Validate the field
            const field_valid = validateField(field_name, field_value, validation, result) catch |err| {
                Vapor.printErr("Validation failed: {any}\n", .{err});
                return;
            };
            if (!field_valid) {
                result.valid = false;
            } else {
                if (validation.match) {
                    const target_field_value = @field(parsed_form, validation.target_field);
                    const match_valid = matchField(field_value, target_field_value);
                    Vapor.printErr("Validation failed: {any} {any}\n", .{ match_valid, validation.match });
                    if (!match_valid) {
                        result.valid = false;
                        result.errors.append(.{
                            .field = field_name,
                            .message = "Values do not match",
                        }) catch |err| {
                            Vapor.printErr("Error: {any}\n", .{err});
                        };
                    }
                } else {
                    result.errors.append(.{
                        .field = field_name,
                        .message = "",
                    }) catch |err| {
                        Vapor.printErr("Error: {any}\n", .{err});
                    };
                }
            }
        }
    }

    if (on_submit) |submit| {
        submit(parsed_form);
    }

    Vapor.cycle();

    return;
}

// Validate individual field
fn validateField(
    field_name: []const u8,
    value: anytype,
    validation: Validation,
    result: *ValidationResult,
) !bool {
    var is_valid = true;
    const ValueType = @TypeOf(value);

    // Helper to add error
    const addError = struct {
        fn add(res: *ValidationResult, fname: []const u8, val: Validation, msg: []const u8) !void {
            const error_msg = val.err orelse msg;
            try res.errors.append(.{
                .field = fname,
                .message = error_msg,
            });
        }
    }.add;

    // Required check
    if (validation.required) {
        const is_empty = blk: switch (@typeInfo(ValueType)) {
            .pointer => |ptr| switch (ptr.size) {
                .slice => {
                    if (ptr.child == []const u8) {
                        std.log.info("slice {any}", .{value});
                        break :blk value[0].len == 0;
                    } else {
                        break :blk value.len == 0;
                    }
                },
                else => false,
            },
            .optional => value == null,
            else => false,
        };

        if (is_empty) {
            try addError(result, field_name, validation, "This field is required");
            return false;
        }
    }

    // Type-specific validation
    switch (@typeInfo(ValueType)) {
        .pointer => |ptr| switch (ptr.size) {
            .slice => {
                var str_value: []const u8 = "";
                if (ptr.child == []const u8) {
                    std.log.info("slice {any}", .{value});
                    str_value = value[0];
                } else {
                    str_value = value;
                }
                // String validations

                // Trim if requested
                if (validation.trim) {
                    str_value = std.mem.trim(u8, str_value, " \t\n\r");
                }

                // Min length
                if (validation.min) |min| {
                    if (str_value.len < min) {
                        const msg = try std.fmt.allocPrint(
                            result.errors.allocator,
                            "Must be at least {d} characters",
                            .{min},
                        );
                        try addError(result, field_name, validation, msg);
                        is_valid = false;
                    }
                }

                // Max length
                if (validation.max) |max| {
                    if (str_value.len > max) {
                        const msg = try std.fmt.allocPrint(
                            result.errors.allocator,
                            "Must be at most {d} characters",
                            .{max},
                        );
                        try addError(result, field_name, validation, msg);
                        is_valid = false;
                    }
                }

                // Includes check
                if (validation.includes) |substr| {
                    if (std.mem.indexOf(u8, str_value, substr) == null) {
                        const msg = try std.fmt.allocPrint(
                            result.errors.allocator,
                            "Must contain '{s}'",
                            .{substr},
                        );
                        try addError(result, field_name, validation, msg);
                        is_valid = false;
                    }
                }

                // Excludes check
                if (validation.excludes) |substr| {
                    if (std.mem.indexOf(u8, str_value, substr) != null) {
                        const msg = try std.fmt.allocPrint(
                            result.errors.allocator,
                            "Must not contain '{s}'",
                            .{substr},
                        );
                        try addError(result, field_name, validation, msg);
                        is_valid = false;
                    }
                }

                // Field type validation
                if (validation.field_type) |field_type| {
                    const type_valid = blk: switch (field_type) {
                        .email => validateEmail(str_value),
                        .password => validatePassword(str_value),
                        // .url => validateUrl(str_value),
                        .telephone => validatePhone(str_value),
                        .credit_card => {
                            const is_valid_credit_card = validateCreditCard(str_value);
                            break :blk is_valid_credit_card;
                        },
                        .cvv => validateCvv(str_value),
                        .expiry => validateExpiry(str_value),
                        // .alphanumeric => validateAlphanumeric(str_value),
                        else => true,
                    };

                    if (!type_valid) {
                        const msg = switch (field_type) {
                            .email => "Must be a valid email address",
                            .password => "Password must be at least 8 characters with uppercase, lowercase, and numbers",
                            // .url => "Must be a valid URL",
                            .telephone => "Must be a valid phone number",
                            .credit_card => "Must be a valid credit card number",
                            // .alphanumeric => "Must contain only letters and numbers",
                            else => "Invalid format",
                        };
                        try addError(result, field_name, validation, msg);
                        is_valid = false;
                    }
                }
            },
            else => {},
        },

        .int, .comptime_int => {
            // Number validations
            if (validation.min_value) |min| {
                if (value < min) {
                    const msg = try std.fmt.allocPrint(
                        result.errors.allocator,
                        "Must be at least {d}",
                        .{min},
                    );
                    try addError(result, field_name, validation, msg);
                    is_valid = false;
                }
            }

            if (validation.max_value) |max| {
                if (value > max) {
                    const msg = try std.fmt.allocPrint(
                        result.errors.allocator,
                        "Must be at most {d}",
                        .{max},
                    );
                    try addError(result, field_name, validation, msg);
                    is_valid = false;
                }
            }
        },

        else => {},
    }

    // Custom validation
    if (validation.custom) |custom_fn| {
        if (!custom_fn(value)) {
            try addError(result, field_name, validation, "Validation failed");
            is_valid = false;
        }
    }

    return is_valid;
}

// Validation helper functions
fn validateEmail(email: []const u8) bool {
    if (email.len < 5) return false;

    // Check for @ symbol
    const at_index = std.mem.indexOf(u8, email, "@") orelse return false;
    if (at_index == 0 or at_index == email.len - 1) return false;

    // Check for multiple @ symbols
    const after_at = email[at_index + 1 ..];
    if (std.mem.indexOf(u8, after_at, "@") != null) return false;

    // Check for domain dot
    const dot_index = std.mem.lastIndexOf(u8, after_at, ".") orelse return false;
    if (dot_index == 0 or dot_index == after_at.len - 1) return false;

    // Basic character validation
    for (email) |char| {
        if (!std.ascii.isAlphanumeric(char) and
            char != '@' and char != '.' and
            char != '-' and char != '_' and
            char != '+')
        {
            return false;
        }
    }

    return true;
}

fn validatePassword(password: []const u8) bool {
    if (password.len < 8) return false;

    var has_upper = false;
    var has_lower = false;
    var has_digit = false;

    for (password) |char| {
        if (std.ascii.isUpper(char)) has_upper = true;
        if (std.ascii.isLower(char)) has_lower = true;
        if (std.ascii.isDigit(char)) has_digit = true;
    }

    return has_upper and has_lower and has_digit;
}

fn matchField(password: []const u8, target: []const u8) bool {
    return std.mem.eql(u8, password, target);
}

fn validateUrl(url: []const u8) bool {
    // Basic URL validation
    if (url.len < 10) return false;

    // Check for protocol
    const has_http = std.mem.startsWith(u8, url, "http://");
    const has_https = std.mem.startsWith(u8, url, "https://");

    return has_http or has_https;
}

fn validatePhone(phone: []const u8) bool {
    // Basic phone validation (digits, spaces, hyphens, parentheses, plus)
    if (phone.len < 10) return false;

    var digit_count: usize = 0;
    for (phone) |char| {
        if (std.ascii.isDigit(char)) {
            digit_count += 1;
        } else if (char != ' ' and char != '-' and char != '(' and char != ')' and char != '+') {
            return false;
        }
    }

    return digit_count >= 10 and digit_count <= 15;
}

fn validateAlphanumeric(str: []const u8) bool {
    for (str) |char| {
        if (!std.ascii.isAlphanumeric(char)) return false;
    }
    return true;
}

fn validateCreditCard(card: []const u8) bool {
    if (card.len < 16) return false;
    std.log.info("card {d}", .{card.len});
    // Extract only digits
    var digits: [16]u8 = undefined;
    var digit_count: usize = 0;

    for (card) |char| {
        if (std.ascii.isDigit(char)) {
            if (digit_count < 16) {
                digits[digit_count] = char;
                digit_count += 1;
            }
        } else if (char != ' ' and char != '-') {
            // Invalid character
            return false;
        }
    }

    // Most cards are 13-16 digits
    if (digit_count < 13 or digit_count > 16) return false;

    // Luhn algorithm (checksum validation)
    var sum: u32 = 0;
    var is_even = false;
    var i: usize = digit_count;
    while (i > 0) {
        i -= 1;
        var digit: u32 = digits[i] - '0';

        if (is_even) {
            digit *= 2;
            if (digit > 9) {
                digit -= 9;
            }
        }

        sum += digit;
        is_even = !is_even;
    }

    return (sum % 10) == 0;
}

fn validateCvv(cvv: []const u8) bool {
    // Extract only digits
    var digit_count: usize = 0;

    for (cvv) |char| {
        if (std.ascii.isDigit(char)) {
            digit_count += 1;
        } else {
            // CVV should only contain digits
            return false;
        }
    }

    // CVV is 3 digits for most cards, 4 for Amex
    return digit_count >= 3 and digit_count <= 4;
}

fn validateExpiry(expiry: []const u8) bool {
    // Extract only digits
    var digits: [4]u8 = undefined;
    var digit_count: usize = 0;

    for (expiry) |char| {
        if (std.ascii.isDigit(char)) {
            if (digit_count < 4) {
                digits[digit_count] = char;
                digit_count += 1;
            }
        } else if (char != '/') {
            // Only digits and slash allowed
            return false;
        }
    }

    // Need exactly 4 digits (MMYY)
    if (digit_count != 4) return false;

    // Parse month (first 2 digits)
    const month = (@as(u32, digits[0] - '0') * 10) + @as(u32, digits[1] - '0');

    // Month must be 01-12
    if (month < 1 or month > 12) return false;

    // Parse year (last 2 digits)
    const year = (@as(u32, digits[2] - '0') * 10) + @as(u32, digits[3] - '0');

    // Basic year range check (00-99 maps to 2000-2099)
    // You could add current date checking here if needed
    _ = year;

    return true;
}

var field_index: usize = 0;
pub fn generateForm(self: *Self, parent: *Node, field_name: []const u8, comptime VT: type, value: anytype, comptime form_type: type, form_value: anytype, default_value: ?VT) !void {
    current_parent = current_parent orelse parent;
    const validations = if (@hasDecl(form_type, "__validations")) blk: {
        break :blk @TypeOf(form_type.__validations);
    } else @TypeOf(.{});
    switch (@typeInfo(VT)) {
        .@"struct" => {
            if (VT == Condition(form_type)) {
                const condition = Vapor.arena(.persist).create(Condition(form_type)) catch unreachable;
                condition.* = Condition(form_type){ .callback = value.callback, .value = value.value, .target_field = value.target_field };
                if (value.target_field) |existing| {
                    form_value.conditionals.put(existing, false) catch unreachable;
                }
                const opaque_condition: *anyopaque = @ptrCast(@alignCast(condition));
                const node = try self.createNode(.Switch);
                node.data = .{ .toggle = .{
                    .title = field_name,
                    .condition = opaque_condition,
                } };
                self.attachChild(current_parent.?, node);
            } else {
                var struct_node: *Node = undefined;
                if (std.mem.eql(u8, field_name, "root")) {
                    struct_node = try self.createNode(.Box);
                } else {
                    var local_parent = current_parent.?;
                    struct_node = try self.createNode(.Box);
                    self.attachChild(local_parent, struct_node);
                    local_parent = struct_node;

                    // struct_node = try self.createNode(.FormSectionTitle);
                    // struct_node.data = .{ .text = .{ .content = field_name } };
                    // self.attachChild(local_parent, struct_node);
                    // local_parent = struct_node;

                    struct_node = try self.createNode(.FormSection);
                    struct_node.data = .{ .formsection = .{ .title = field_name } };
                }
                self.attachChild(current_parent.?, struct_node);
                current_parent = struct_node;
                const fields = @typeInfo(VT).@"struct".fields;
                inline for (fields) |field| {
                    const FT = field.type;
                    var field_value: getUnderlyingType(FT) = undefined;
                    field_value = field.defaultValue() orelse {
                        try self.generateForm(current_parent.?, field.name, field.type, {}, form_type, form_value, null);
                        continue;
                    };
                    var field_default_value: ?getUnderlyingType(FT) = null;
                    if (default_value) |default| {
                        field_default_value = @field(default, field.name);
                    }

                    try self.generateForm(current_parent.?, field.name, field.type, field_value, form_type, form_value, field_default_value);
                    field_index += 1;
                }
                current_parent = parent;
            }
        },
        .pointer => |ptr| {
            // switch (VT) {
            //     []const u8 => {
            //         Vapor.print("[]const u8 slice\n", .{});
            //         const node = try self.createNode(.Text);
            //         node.data = .{ .text = .{ .content = value } };
            //         self.attachChild(current_parent.?, node);
            //     },
            //     else => {},
            // }
            switch (ptr.size) {
                .c => {
                    Vapor.print("c\n", .{});
                },
                .many => {
                    Vapor.print("many\n", .{});
                },
                .one => {
                    Vapor.print("one\n", .{});
                    switch (ptr.child) {
                        fn () void => {
                            const node = try self.createNode(.Button);
                            node.data = .{ .button = .{ .text = field_name, .on_click = value } };
                            current_parent = node;
                            try self.generateForm(current_parent.?, field_name, []const u8, field_name, form_type, form_value, default_value);
                            current_parent = parent;
                            self.attachChild(current_parent.?, node);
                        },
                        else => {
                            const node = try self.createNode(.TextField);
                            node.data = .{ .textfield = .{
                                .title = field_name,
                            } };
                            self.attachChild(current_parent.?, node);
                        },
                    }
                },
                .slice => {
                    if (ptr.child == u8) {
                        // Here we switch on the validation value
                        var _type: FieldType = .string;
                        var placeholder: ?[]const u8 = null;
                        const fields = @typeInfo(validations).@"struct".fields; // this is like username password ect
                        inline for (fields) |field| blk: {
                            if (std.mem.eql(u8, field_name, field.name)) { // this checks that we are looping through the right field ie username
                                const field_validation = field.defaultValue() orelse continue; // This is the Validation struct
                                const field_validation_type = @field(field_validation, "field_type");
                                _type = field_validation_type.?;
                                placeholder = @field(field_validation, "placeholder");
                                break :blk;
                            }
                        }
                        const node = try self.createNode(.TextField);

                        node.data = .{ .textfield = .{
                            .title = field_name,
                            .type = _type,
                            .err = form_value.validation_error,
                            .err_index = field_index,
                            .default_value = .{ .string = default_value orelse value },
                            .placeholder = placeholder,
                        } };
                        self.attachChild(current_parent.?, node);
                    } else if (ptr.child == []const u8) {
                        // Here we switch on the validation value
                        const node = try self.createNode(.TextArea);
                        node.data = .{ .textarea = .{
                            .title = field_name,
                            .err = form_value.validation_error,
                            .err_index = field_index,
                        } };
                        self.attachChild(current_parent.?, node);
                    }
                },
            }
        },
        .int => {
            const node = try self.createNode(.TextField);
            node.data = .{ .textfield = .{
                .title = field_name,
                .type = .number,
                .err = form_value.validation_error,
                .err_index = field_index,
                .config = .{ .min = 0, .max = std.math.maxInt(VT) },
                .default_value = .{ .number = 0 },
            } };
            self.attachChild(current_parent.?, node);
        },
        .@"enum" => {
            const node = try self.createNode(.Dropdown);
            node.data = .{ .dropdown = .{
                .title = field_name,
            } };
            self.attachChild(current_parent.?, node);
        },
        // .bool => {
        //     const node = try self.createNode(.Switch);
        //     node.data = .{ .toggle = .{
        //         .title = field_name,
        //         .condition = .{ .callback = null },
        //     } };
        //     self.attachChild(current_parent.?, node);
        // },
        // .float => {
        //     const node = try self.createNode(.Text);
        //     node.data = .{ .text = .{ .content = std.fmt.allocPrint(self.allocator, "{d}", .{value}) catch unreachable } };
        //     self.attachChild(current_parent.?, node);
        // },
        // .array => {
        //     const node = try self.createNode(.List);
        //     node.data = .{ .list = .{ .list_type = .disc } };
        //     self.attachChild(current_parent.?, node);
        //     current_parent = node;
        //     for (value) |item| {
        //         const list_item_node = try self.createNode(.ListItem);
        //         current_parent = list_item_node;
        //         try self.generate(current_parent.?, field_name, item);
        //         self.attachChild(node, list_item_node);
        //     }
        //     current_parent = parent;
        // },
        else => {},
    }
}

pub fn traverseForm(self: *Self, node: ?*Node, value: anytype) !void {
    var current = node;
    while (current) |n| {
        switch (n.tag) {
            .Form => {
                FormComponent(validateForm, value)
                    .layout(.top_left)
                    .direction(.column)
                    .spacing(8)
                    .padding(.tb(8, 8))
                    .width(.percent(100))
                    .children({
                    // .baseStyle(&.{
                    //     .size = .{ .width = .percent(100) },
                    //     .layout = .top_left,
                    //     .padding = .tb(8, 8),
                    //     .direction = .column,
                    //     .child_gap = 8,
                    // }).children({
                    self.traverseForm(n.child, .{}, value) catch {
                        Text("Failed to Parse Form").end();
                        return error.TraverseForm;
                    };

                    const button_style: Vapor.Types.Style = self.style_config.submit_style;
                    SubmitButton().style(&button_style).children({
                        Text("Submit").end();
                    });
                });
            },
            else => {},
        }
        current = n.next;
    }
}
