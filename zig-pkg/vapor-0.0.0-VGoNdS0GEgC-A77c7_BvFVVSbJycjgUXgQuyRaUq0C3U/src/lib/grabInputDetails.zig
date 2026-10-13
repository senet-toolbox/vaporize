const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Vapor = @import("Vapor.zig");
const types = @import("types.zig");
const InputParams = types.InputParams;
var input: []const u8 = "";
var input_buffer: [4096]u8 = undefined;

// Allocate a string in WASM memory and return pointer and length
fn allocString(str: ?[]const u8) struct { ptr: [*]const u8, len: usize } {
    if (str) |s| {
        return .{ .ptr = s.ptr, .len = s.len };
    } else {
        return .{ .ptr = undefined, .len = 0 };
    }
}

// Import JavaScript function
const InputText = struct {
    type: ?u32 = null,
    tagPtr: ?[*]const u8 = null,
    tagLen: ?usize = null,
    placeholderPtr: ?[*]const u8 = null,
    placeholderLen: ?usize = null,
    valuePtr: ?[*]const u8 = null,
    valueLen: ?usize = null,
    minLen: ?u32 = null,
    maxLen: ?u32 = null,
    hasRequired: bool = false,
    required: ?bool = null,
    srcPtr: ?[*]const u8 = null,
    srcLen: ?usize = null,
    altPtr: ?[*]const u8 = null,
    altLen: ?usize = null,
    hasDisabled: bool = false,
    disabled: ?bool = null,
};

// Import JavaScript function
const InputInt = struct {
    type: ?u32 = null,
    tagPtr: ?[*]const u8 = null,
    tagLen: ?usize = null,
    placeholder: ?i32 = null,
    value: ?i32 = null,
    minLen: ?u32 = null,
    maxLen: ?u32 = null,
    hasRequired: bool = false,
    required: ?bool = null,
    srcPtr: ?[*]const u8 = null,
    srcLen: ?usize = null,
    altPtr: ?[*]const u8 = null,
    altLen: ?usize = null,
    hasDisabled: bool = false,
    disabled: ?bool = null,
};

const InputCheckBox = struct {
    type: ?u32 = null,
    tagPtr: ?[*]const u8 = null,
    tagLen: ?usize = null,
    checked: bool = false,
    hasRequired: bool = false,
    required: ?bool = null,
    // altPtr: ?[*]const u8 = null,
    // altLen: ?usize = null,
    // hasDisabled: bool = false,
    // disabled: ?bool = null,
};

// Import JavaScript function
const InputRadio = struct {
    type: ?u32 = null,
    tagPtr: [*]const u8 = undefined,
    tagLen: usize = undefined,
    valuePtr: [*]const u8 = undefined,
    valueLen: usize = undefined,
    hasRequired: bool = false,
    required: ?bool = null,
    srcPtr: ?[*]const u8 = null,
    srcLen: ?usize = null,
    altPtr: ?[*]const u8 = null,
    altLen: ?usize = null,
    hasDisabled: bool = false,
    disabled: ?bool = null,
};

// Import JavaScript function
const InputFile = struct {
    type: ?u32 = null,
    tagPtr: ?[*]const u8 = null,
    tagLen: ?usize = null,
    placeholderPtr: ?[*]const u8 = null,
    placeholderLen: ?usize = null,
    valuePtr: ?[*]const u8 = null,
    valueLen: ?usize = null,
    minLen: ?u32 = null,
    maxLen: ?u32 = null,
    hasRequired: bool = false,
    required: ?bool = null,
    srcPtr: ?[*]const u8 = null,
    srcLen: ?usize = null,
    altPtr: ?[*]const u8 = null,
    altLen: ?usize = null,
    hasDisabled: bool = false,
    disabled: ?bool = null,
};



pub export fn getOnInputCallback(ptr: ?*UINode) u32 {
    _ = ptr orelse return 0;
    // const input_params = node_ptr.input_params orelse return 0;
    // switch (input_params.*) {
    //     else => return 0,
    // //     .int => {
    // //         return 0;
    // //     },
    // //     .float => {
    // //         return 0;
    // //     },
    //     // .string => {
    //     //     if (input_params.string.onInput) |cb| {
    //     //         const id = Vapor.events_callbacks.count() + 1;
    //     //         Vapor.events_callbacks.put(id, cb) catch |err| {
    //     //             Vapor.println("Event Callback Error: {any}\n", .{err});
    //     //             return 0;
    //     //         };
    //     //         return id;
    //     //     }
    //     //     return 0;
    //     // },
    // //     .checkbox => {
    // //         return 0;
    // //     },
    // //     .radio => {
    // //         return 0;
    // //     },
    // //     .password => {
    // //         return 0;
    // //     },
    // //     .email => {
    // //         return 0;
    // //     },
    // //     .file => {
    // //         return 0;
    // //     },
    // }
}

// pub export fn getInputType(node_ptr: ?*UINode) usize {
//     if (node_ptr == null) {
//         return 0;
//     }
//     const input_params = node_ptr.?.input_params.?;
//     switch (input_params.*) {
//         .int => {
//             return 0;
//         },
//         .float => {
//             return 1;
//         },
//         .string => {
//             return 2;
//         },
//         .checkbox => {
//             return 3;
//         },
//         .radio => {
//             return 4;
//         },
//         .password => {
//             return 5;
//         },
//         .email => {
//             return 6;
//         },
//         .file => {
//             return 7;
//         },
//     }
// }
var input_struct_text = InputText{};
var input_struct_password = InputText{};
var input_struct_radio = InputRadio{};
var input_struct_int = InputInt{};
var input_struct_checkbox = InputCheckBox{};
var input_struct_file = InputFile{};
// Export function to create a text input
// pub export fn createInput(node_ptr: ?*UINode) *u8 {
//     if (node_ptr == null) {
//         return undefined;
//     }
//     const input_params = node_ptr.?.input_params.?;
//
//     switch (input_params.*) {
//         .int => {
//             input_struct_int.type = 0;
//             const params = input_params.int;
//             if (params.tag) |tag| {
//                 input_struct_int.tagPtr = tag.ptr;
//                 input_struct_int.tagLen = tag.len;
//             }
//             if (params.src) |src| {
//                 input_struct_int.srcPtr = src.ptr;
//                 input_struct_int.srcLen = src.len;
//             }
//             if (params.default) |def| {
//                 input_struct_int.placeholder = def;
//             }
//             if (params.value) |val| {
//                 input_struct_int.value = val;
//             }
//             if (params.min_len) |min_len| {
//                 input_struct_int.minLen = min_len;
//             }
//             if (params.max_len) |max_len| {
//                 input_struct_int.maxLen = max_len;
//             }
//             if (params.required) |req| {
//                 input_struct_int.hasRequired = true;
//                 input_struct_int.required = req;
//             }
//             if (params.disabled) |disabled| {
//                 input_struct_int.hasDisabled = true;
//                 input_struct_int.disabled = disabled;
//             }
//             if (params.alt) |alt| {
//                 input_struct_int.altPtr = alt.ptr;
//                 input_struct_int.altLen = alt.len;
//             }
//             const input_struct_ptr: *u8 = @ptrCast(&input_struct_int);
//             return input_struct_ptr;
//         },
//         .float => {
//             return undefined;
//         },
//         .string => {
//             input_struct_text.type = 2;
//             const params = input_params.string;
//             if (params.tag) |tag| {
//                 input_struct_text.tagPtr = tag.ptr;
//                 input_struct_text.tagLen = tag.len;
//             }
//             if (params.src) |src| {
//                 input_struct_text.srcPtr = src.ptr;
//                 input_struct_text.srcLen = src.len;
//             }
//             if (params.default) |def| {
//                 input_struct_text.placeholderPtr = def.ptr;
//                 input_struct_text.placeholderLen = def.len;
//             }
//             if (params.value) |val| {
//                 input_struct_text.valuePtr = val.ptr;
//                 input_struct_text.valueLen = val.len;
//             }
//             if (params.min_len) |min_len| {
//                 input_struct_text.minLen = min_len;
//             }
//             if (params.max_len) |max_len| {
//                 input_struct_text.maxLen = max_len;
//             }
//             if (params.required) |req| {
//                 input_struct_text.hasRequired = true;
//                 input_struct_text.required = req;
//             }
//             if (params.disabled) |disabled| {
//                 input_struct_text.hasDisabled = true;
//                 input_struct_text.disabled = disabled;
//             }
//             if (params.alt) |alt| {
//                 input_struct_text.altPtr = alt.ptr;
//                 input_struct_text.altLen = alt.len;
//             }
//             const input_struct_ptr: *u8 = @ptrCast(&input_struct_text);
//             return input_struct_ptr;
//         },
//         .checkbox => {
//             input_struct_checkbox.type = 3;
//             const params = input_params.checkbox;
//             if (params.tag) |tag| {
//                 input_struct_checkbox.tagPtr = tag.ptr;
//                 input_struct_checkbox.tagLen = tag.len;
//             }
//             input_struct_checkbox.checked = params.checked;
//             if (params.required) |req| {
//                 input_struct_checkbox.hasRequired = true;
//                 input_struct_checkbox.required = req;
//             }
//             // if (params.disabled) |disabled| {
//             //     input_struct_checkbox.hasDisabled = true;
//             //     input_struct_checkbox.disabled = disabled;
//             // }
//             // if (params.alt) |alt| {
//             //     input_struct_checkbox.altPtr = alt.ptr;
//             //     input_struct_checkbox.altLen = alt.len;
//             // }
//             const input_struct_ptr: *u8 = @ptrCast(&input_struct_checkbox);
//             return input_struct_ptr;
//         },
//         .radio => {
//             input_struct_radio.type = 4;
//             const params = input_params.radio;
//             input_struct_radio.tagPtr = params.tag.ptr;
//             input_struct_radio.tagLen = params.tag.len;
//             if (params.src) |src| {
//                 input_struct_radio.srcPtr = src.ptr;
//                 input_struct_radio.srcLen = src.len;
//             }
//             input_struct_radio.valuePtr = params.value.ptr;
//             input_struct_radio.valueLen = params.value.len;
//             if (params.required) |req| {
//                 input_struct_radio.hasRequired = true;
//                 input_struct_radio.required = req;
//             }
//             if (params.disabled) |disabled| {
//                 input_struct_radio.hasDisabled = true;
//                 input_struct_radio.disabled = disabled;
//             }
//             if (params.alt) |alt| {
//                 input_struct_radio.altPtr = alt.ptr;
//                 input_struct_radio.altLen = alt.len;
//             }
//             const input_struct_ptr: *u8 = @ptrCast(&input_struct_radio);
//             return input_struct_ptr;
//         },
//         .password => {
//             input_struct_text.type = 5;
//             const params = input_params.password;
//             if (params.tag) |tag| {
//                 input_struct_text.tagPtr = tag.ptr;
//                 input_struct_text.tagLen = tag.len;
//             }
//             if (params.src) |src| {
//                 input_struct_text.srcPtr = src.ptr;
//                 input_struct_text.srcLen = src.len;
//             }
//             if (params.default) |def| {
//                 input_struct_text.placeholderPtr = def.ptr;
//                 input_struct_text.placeholderLen = def.len;
//             }
//             if (params.value) |val| {
//                 input_struct_text.valuePtr = val.ptr;
//                 input_struct_text.valueLen = val.len;
//             }
//             if (params.min_len) |min_len| {
//                 input_struct_text.minLen = min_len;
//             }
//             if (params.max_len) |max_len| {
//                 input_struct_text.maxLen = max_len;
//             }
//             if (params.required) |req| {
//                 input_struct_text.hasRequired = true;
//                 input_struct_text.required = req;
//             }
//             if (params.disabled) |disabled| {
//                 input_struct_text.hasDisabled = true;
//                 input_struct_text.disabled = disabled;
//             }
//             if (params.alt) |alt| {
//                 input_struct_text.altPtr = alt.ptr;
//                 input_struct_text.altLen = alt.len;
//             }
//             const input_struct_ptr: *u8 = @ptrCast(&input_struct_text);
//             return input_struct_ptr;
//         },
//         .email => {
//             input_struct_text.type = 6;
//             const params = input_params.email;
//             if (params.tag) |tag| {
//                 input_struct_text.tagPtr = tag.ptr;
//                 input_struct_text.tagLen = tag.len;
//             }
//             if (params.src) |src| {
//                 input_struct_text.srcPtr = src.ptr;
//                 input_struct_text.srcLen = src.len;
//             }
//             if (params.default) |def| {
//                 input_struct_text.placeholderPtr = def.ptr;
//                 input_struct_text.placeholderLen = def.len;
//             }
//             if (params.value) |val| {
//                 input_struct_text.valuePtr = val.ptr;
//                 input_struct_text.valueLen = val.len;
//             }
//             if (params.min_len) |min_len| {
//                 input_struct_text.minLen = min_len;
//             }
//             if (params.max_len) |max_len| {
//                 input_struct_text.maxLen = max_len;
//             }
//             if (params.required) |req| {
//                 input_struct_text.hasRequired = true;
//                 input_struct_text.required = req;
//             }
//             if (params.disabled) |disabled| {
//                 input_struct_text.hasDisabled = true;
//                 input_struct_text.disabled = disabled;
//             }
//             if (params.alt) |alt| {
//                 input_struct_text.altPtr = alt.ptr;
//                 input_struct_text.altLen = alt.len;
//             }
//             const input_struct_ptr: *u8 = @ptrCast(&input_struct_text);
//             return input_struct_ptr;
//         },
//         .file => {
//             input_struct_file.type = 7;
//             const params = input_params.file;
//             if (params.tag) |tag| {
//                 input_struct_file.tagPtr = tag.ptr;
//                 input_struct_file.tagLen = tag.len;
//             }
//             if (params.required) |req| {
//                 input_struct_file.hasRequired = true;
//                 input_struct_file.required = req;
//             }
//             if (params.disabled) |disabled| {
//                 input_struct_file.hasDisabled = true;
//                 input_struct_file.disabled = disabled;
//             }
//             const input_struct_ptr: *u8 = @ptrCast(&input_struct_file);
//             return input_struct_ptr;
//         },
//     }
//
//     // if (params.tag) |tag| {
//     //     input_struct.tagPtr = tag.ptr;
//     //     input_struct.tagLen = tag.len;
//     // }
//     // if (params.src) |src| {
//     //     input_struct.srcPtr = src.ptr;
//     //     input_struct.srcLen = src.len;
//     // }
//     // if (params.default) |def| {
//     //     input_struct.placeholderPtr = def.ptr;
//     //     input_struct.placeholderLen = def.len;
//     // }
//     // if (params.value) |val| {
//     //     input_struct.valuePtr = val.ptr;
//     //     input_struct.valueLen = val.len;
//     // }
//     // if (params.min_len) |min_len| {
//     //     input_struct.minLen = min_len;
//     // }
//     // if (params.max_len) |max_len| {
//     //     input_struct.maxLen = max_len;
//     // }
//     // if (params.required) |req| {
//     //     input_struct.hasRequired = true;
//     //     input_struct.required = req;
//     // }
//     // if (params.disabled) |disabled| {
//     //     input_struct.hasDisabled = true;
//     //     input_struct.disabled = disabled;
//     // }
//     // if (params.alt) |alt| {
//     //     input_struct.altPtr = alt.ptr;
//     //     input_struct.altLen = alt.len;
//     // }
//     //
// }
// export fn checkBoxInputSize() u32 {
//     return @sizeOf(InputCheckBox);
// }
//
// export fn textInputSize() u32 {
//     return @sizeOf(InputText);
// }
//
// pub export fn getInputSize(node_ptr: ?*UINode) u32 {
//     if (node_ptr == null) {
//         return 0;
//     }
//     const input_params = node_ptr.?.input_params.?;
//
//     switch (input_params.*) {
//         .int => {
//             return @sizeOf(InputInt);
//         },
//         .float => {
//             return 1;
//         },
//         .string => {
//             return @sizeOf(InputText);
//         },
//         .checkbox => {
//             return @sizeOf(InputCheckBox);
//         },
//         .radio => {
//             return @sizeOf(InputRadio);
//         },
//         .password => {
//             return @sizeOf(InputText);
//         },
//         .email => {
//             return @sizeOf(InputText);
//         },
//         .file => {
//             return @sizeOf(InputFile);
//         },
//     }
// }
