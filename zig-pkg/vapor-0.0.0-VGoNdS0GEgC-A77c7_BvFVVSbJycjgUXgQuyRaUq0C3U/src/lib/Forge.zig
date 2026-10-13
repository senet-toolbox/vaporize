const std = @import("std");
const Vapor = @import("Vapor.zig");
const Element = @import("Element.zig").Element;
const Signal = Vapor.Signal;
const Static = Vapor.Static;
const Pure = Vapor.Pure;
const Dynamic = Vapor.Dynamic;
const InputParams = Vapor.Types.InputParams;

pub const InputType = struct {
    id: ?[]const u8 = null,
    label: []const u8,
    tag: []const u8,
    params: Vapor.Types.InputParams,
};

const ValidationError = enum {
    Required,
    Min,
    Max,
    ParseFloat,
    ParseInt,
    SymbolCount,
    DigitCount,
    CapitalCount,
    Email,
    InputValueNull,
};

const FieldError = struct {
    field: []const u8,
    err: ValidationError,
};

pub const ValidateResult = union(enum) {
    Ok, // “no error”
    Err: FieldError, // carries your struct
};

const Forge = @This();
id: []const u8,
fields: []const InputType = &.{},
_elements: []const Element = undefined,
elements: []*Element = undefined,
elements_map: std.AutoHashMap(usize, *const Element) = undefined,
_errors: [][]const ValidateResult = &.{},

// we need to ensure the total capacity since if the elements of the array get a resize call then the copy of the pointers changes,
// hence then the underlying value gets changed
pub fn init(forge: *Forge) void {
    // We create a list to store all the element decls, then we use a map to have O(1) space time lookup
    var _dynamic_element: std.ArrayList(*Element) = std.ArrayList(*Element).init(Vapor.allocator_global);
    forge._errors = Vapor.allocator_global.alloc([]const ValidateResult, forge.fields.len) catch return;
    forge.elements = Vapor.allocator_global.alloc(*Element, forge.fields.len) catch return;
    forge.elements_map = std.AutoHashMap(usize, *const Element).init(Vapor.allocator_global);

    for (forge.fields) |field| {
        const element: *Element = Vapor.allocator_global.create(Element) catch return;
        element.* = .{
            .element_type = .Input,
        };

        switch (field.params) {
            .int => {
                _dynamic_element.append(element) catch {};
            },
            .string, .password, .email => {
                _dynamic_element.append(element) catch {};
            },
            .checkbox => {
                _dynamic_element.append(element) catch {};
            },
            .float => {
                _dynamic_element.append(element) catch {};
            },
            .radio => {
                _dynamic_element.append(element) catch {};
            },
        }
    }

    forge.elements = _dynamic_element.toOwnedSlice() catch |err| {
        Vapor.printlnSrc("Elements Error: {any}", .{err}, @src());
        return;
    };
}

pub fn deinit(forge: *Forge) void {
    for (forge.elements) |e| {
        Vapor.allocator_global.destroy(e);
    }
    Vapor.allocator_global.free(forge.elements);
    Vapor.allocator_global.free(forge._errors);
    forge.elements_map.deinit();
}

pub fn isValidEmail(email: []const u8) bool {
    // Basic validation criteria:
    // 1. Must contain exactly one @ symbol
    // 2. Must have characters before and after @
    // 3. Must have at least one . after @
    // 4. Must have characters after the last .

    const atIndex = std.mem.indexOf(u8, email, "@") orelse return false;

    // Check if @ is not the first character and there are characters after it
    if (atIndex == 0 or atIndex == email.len - 1)
        return false;

    // Get the domain part after @
    const domain = email[atIndex + 1 ..];

    // Check if domain has at least one dot
    const dotIndex = std.mem.indexOf(u8, domain, ".") orelse return false;

    // Make sure dot is not the last character
    if (dotIndex >= domain.len - 1)
        return false;

    // Additional checks could include verifying no spaces, valid characters, etc.

    return true;
}

pub fn validate(forge: *Forge) [][]const ValidateResult {
    var errors = std.ArrayList(ValidateResult).init(Vapor.allocator_global);
    for (forge.fields, 0..) |field, i| {
        const input_value = forge.elements[i].getInputValue() orelse {
            errors.append(ValidateResult{
                .Err = .{
                    .field = "",
                    .err = ValidationError.InputValueNull,
                },
            }) catch {};
            forge._errors[i] = errors.toOwnedSlice() catch &.{};
            return forge._errors;
        };
        switch (field.params) {
            .int => |params| {
                const input_parsed_int = std.fmt.parseInt(i32, input_value, 10) catch return &.{};
                if (params.required) |required| {
                    if (required) {
                        if (input_value.len == 0) {
                            errors.append(ValidateResult{
                                .Err = .{
                                    .field = params.tag.?,
                                    .err = ValidationError.Required,
                                },
                            }) catch {};
                        } else {
                            errors.append(ValidateResult.Ok) catch {};
                        }
                    }
                }
                if (params.min_len) |min_len| {
                    if (input_parsed_int < min_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Min,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.max_len) |max_len| {
                    if (input_parsed_int < max_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Max,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
            },
            .float => |params| {
                const input_parsed_float = std.fmt.parseFloat(f32, input_value) catch return &.{};
                if (params.required) |required| {
                    if (required) {
                        if (input_value.len == 0) {
                            errors.append(ValidateResult{
                                .Err = .{
                                    .field = params.tag.?,
                                    .err = ValidationError.Required,
                                },
                            }) catch {};
                        } else {
                            errors.append(ValidateResult.Ok) catch {};
                        }
                    }
                }
                if (params.min_len) |min_len| {
                    if (input_parsed_float < @as(f32, @floatFromInt(min_len))) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Min,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.max_len) |max_len| {
                    if (input_parsed_float < @as(f32, @floatFromInt(max_len))) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Max,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
            },
            .email => |params| {
                if (params.required) |required| {
                    if (required) {
                        if (input_value.len == 0) {
                            errors.append(ValidateResult{
                                .Err = .{
                                    .field = params.tag.?,
                                    .err = ValidationError.Required,
                                },
                            }) catch {};
                        }
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.min_len) |min_len| {
                    if (input_value.len < min_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Min,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.max_len) |max_len| {
                    if (input_value.len < max_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Max,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.include_pattern) |pattern| {
                    if (pattern and !isValidEmail(input_value)) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Email,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
            },

            .string => |params| {
                if (params.required) |required| {
                    if (required) {
                        if (input_value.len == 0) {
                            errors.append(ValidateResult{
                                .Err = .{
                                    .field = params.tag.?,
                                    .err = ValidationError.Required,
                                },
                            }) catch {};
                        }
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.min_len) |min_len| {
                    if (input_value.len < min_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Min,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.max_len) |max_len| {
                    if (input_value.len < max_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Max,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
            },

            .password => |params| {
                if (params.required) |required| {
                    if (required) {
                        if (input_value.len == 0) {
                            errors.append(ValidateResult{
                                .Err = .{
                                    .field = params.tag.?,
                                    .err = ValidationError.Required,
                                },
                            }) catch {};
                        }
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.min_len) |min_len| {
                    if (input_value.len < min_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Min,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.max_len) |max_len| {
                    if (input_value.len < max_len) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.Max,
                            },
                        }) catch {};
                    } else {
                        errors.append(ValidateResult.Ok) catch {};
                    }
                }
                if (params.include_symbol) |symbol_count| {
                    var count: u32 = 0;
                    for (input_value) |c| {
                        if (!std.ascii.isAlphanumeric(c)) {
                            count += 1;
                        }
                    }
                    if (count < symbol_count) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.SymbolCount,
                            },
                        }) catch {};
                    }
                }
                if (params.include_digit) |digit_count| {
                    var count: u32 = 0;
                    for (input_value) |c| {
                        if (std.ascii.isDigit(c)) {
                            count += 1;
                        }
                    }
                    if (count < digit_count) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.DigitCount,
                            },
                        }) catch {};
                    }
                }
                if (params.include_capital) |capital_count| {
                    var count: u32 = 0;
                    for (input_value) |c| {
                        if (std.ascii.isUpper(c)) {
                            count += 1;
                        }
                    }
                    if (count < capital_count) {
                        errors.append(ValidateResult{
                            .Err = .{
                                .field = params.tag.?,
                                .err = ValidationError.CapitalCount,
                            },
                        }) catch {};
                    }
                }
            },
            else => {},
        }
        forge._errors[i] = errors.toOwnedSlice() catch &.{};
    }
    return forge._errors;
}
