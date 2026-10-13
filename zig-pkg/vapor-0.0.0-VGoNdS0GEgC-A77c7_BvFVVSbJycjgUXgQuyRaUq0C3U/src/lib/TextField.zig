const std = @import("std");
const types = @import("types.zig");
const Vapor = @import("Vapor.zig");
const UINode = @import("UITree.zig").UINode;
const LifeCycle = @import("Vapor.zig").LifeCycle;
const println = Vapor.println;
const Style = types.Style;
const InputParams = types.InputParams;
const ElementDecl = types.ElementDeclaration;
const ElementType = types.Elements.ElementType;
const Color = types.Color;
const Element = @import("Element.zig").Element;
pub const IconTokens = @import("user_config").IconTokens;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Draggable = @import("Draggable.zig").Draggable;
const onCreateNode = @import("Hooks.zig").onCreateNode;

pub fn BuilderClose(comptime state_type: types.StateType) type {
    return struct {
        const Self = @This();
        const _state_type: types.StateType = state_type;

        _level: ?u8 = null,
        _video: ?*const types.Video = null,
        _font_family: []const u8 = "",
        _value: ?*anyopaque = null,
        _text_field_type: types.InputTypes = .none,
        _text_field_params: ?types.TextFieldParams = null,

        _elem_type: Vapor.ElementType,
        _text: ?[]const u8 = null,
        _href: ?[]const u8 = null,
        _alt: ?[]const u8 = null,
        _svg: []const u8 = "",
        _aria_label: ?[]const u8 = null,
        _ui_node: ?*UINode = null,
        _id: ?[]const u8 = null,
        _style: ?*const Vapor.Style = null,
        _draggable: ?*Draggable = null,
        _element: ?*Element = null,

        _animation_enter: ?*const Vapor.Animation = null,
        _animation_exit: ?*const Vapor.Animation = null,
        _name: ?[]const u8 = null,

        // Style props
        _pos: ?types.Position = null,
        _padding: ?types.Padding = null,
        _layout: ?types.Layout = null,
        _margin: ?types.Margin = null,
        _size: ?types.Size = null,
        _child_gap: ?u8 = null,
        _visual: ?types.Visual = null,
        _text_decoration: ?types.TextDecoration = null,
        _flex_wrap: ?types.FlexWrap = null,
        _interactive: ?types.Interactive = null,
        _transition: ?types.Transition = null,
        _direction: types.Direction = .row,
        _list_style: ?types.ListStyle = null,

        pub fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
            if (self._elem_type != .Text) {
                Vapor.printWarn("Ellipsis can only be used on Text, not {any}", .{self._elem_type});
                return self.*;
            }
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.ellipsis = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn TextArea() Self {
            // const text = blk: switch (@typeInfo(@TypeOf(value))) {
            //     .pointer => |_| {
            //         break :blk value;
            //     },
            //     .int => {
            //         break :blk Vapor.fmtln("{any}", .{value});
            //     },
            //     else => {
            //         Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
            //         return Self{ ._elem_type = .Text, .text = "" };
            //     },
            // };
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Text,
            };

            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .TextArea,
                ._ui_node = ui_node,
                ._text_field_type = .string,
                ._text_field_params = .{ .string = .{} },
            };
        }

        pub fn TextField(textfield_type: types.InputTypes) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .TextField,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("{any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            switch (textfield_type) {
                .string => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .string,
                        ._text_field_params = .{ .string = .{} },
                    };
                },
                .int => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .int,
                        ._text_field_params = .{ .int = .{} },
                    };
                },
                .password => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .password,
                        ._text_field_params = .{ .password = .{} },
                    };
                },
                .email => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .email,
                        ._text_field_params = .{ .email = .{} },
                    };
                },
                .telephone => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .telephone,
                        ._text_field_params = .{ .telephone = .{} },
                    };
                },
                .file => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .file,
                        ._text_field_params = .{ .file = .{} },
                    };
                },
                else => {
                    Vapor.printlnSrcErr("Error: TextField only accepts valid types, Not valid: {any}", .{textfield_type}, @src());
                    unreachable;
                    // @compileError("TextField only accepts []const u8 or TextInput");
                },
            }
        }

        pub fn placeholder(self: *const Self, value: anytype) Self {
            var new_self: Self = self.*;
            var text_field_params = new_self._text_field_params orelse {
                Vapor.printlnSrcErr("TextFieldParams is null", .{}, @src());
                return self.*;
            };

            const V = @TypeOf(value);

            // Switch on the type of the value passed in
            switch (@typeInfo(V)) {
                .pointer => { // This correctly covers []const u8 (which is a *two-part* pointer type in memory)
                    if (@typeInfo(V).pointer.size == .slice or @typeInfo(V).pointer.size == .one) {
                        // The value is a []const u8 slice

                        // Now, safely switch on the TextField's type to update the correct union field
                        // All these fields expect a string (slice) value
                        switch (self._text_field_type) {
                            .string => {
                                text_field_params.string.default_ptr = value.ptr;
                                text_field_params.string.default_len = value.len;
                            },
                            .password => {
                                text_field_params.password.default_ptr = value.ptr;
                                text_field_params.password.default_len = value.len;
                            },
                            .email => {
                                text_field_params.email.default_ptr = value.ptr;
                                text_field_params.email.default_len = value.len;
                            },
                            .telephone => {
                                text_field_params.telephone.default_ptr = value.ptr;
                                text_field_params.telephone.default_len = value.len;
                            },
                            .file => {
                                text_field_params.file.default_ptr = value.ptr;
                                text_field_params.file.default_len = value.len;
                            },
                            else => {
                                Vapor.printlnSrcErr("Error: TextField only accepts valid types, Not valid: {any}", .{self._text_field_type}, @src());
                                unreachable;
                                // @compileError("TextField only accepts []const u8 or TextInput");
                            },
                        }
                    } else {
                        Vapor.printlnErr("Cannot set integer placeholder on type: {any}", .{@typeInfo(V).pointer});
                        // @compileError("Placeholder received a generic pointer that is not a []const u8 string slice.");
                    }
                },
                .int, .comptime_int => {
                    // The value is an integer
                    switch (self._text_field_type) {
                        .int => {
                            text_field_params.int.default = value;
                        },
                        else => {
                            Vapor.printlnErr("Cannot set integer placeholder on type: " ++ @typeName(V), .{});
                        },
                        // else => @compileError("Cannot set integer placeholder on type: " ++ @typeName(V)),
                    }
                },
                // Add other types (e.g., .Float for float input fields) as needed
                else => {
                    @compileError("Unsupported placeholder type: " ++ @typeName(V));
                },
            }

            new_self._text_field_params = text_field_params;
            return new_self;
        }

        pub fn fieldName(self: *const Self, name: []const u8) Self {
            var new_self: Self = self.*;
            new_self._name = name;
            return new_self;
        }

        pub fn bind(self: *const Self, value: anytype) Self {
            var new_self: Self = self.*;
            if (self._elem_type != .TextField and self._elem_type != .TextArea) {
                Vapor.printlnErr("bindValue only works on TextField", .{});
                return self.*;
            }
            if (@typeInfo(@TypeOf(value)) != .pointer) {
                Vapor.printlnErr("bindValue only works on pointer types", .{});
                return self.*;
            }

            // const ui_node = self._ui_node orelse {
            //     Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
            //     unreachable;
            // };

            switch (self._text_field_type) {
                .string => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                    new_self._text_field_params.?.string.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.string.value_len = value.*.len;
                    // Vapor.attachEventCtxCallback(ui_node, .input, struct {
                    //     pub fn updateText(value_type: *[]const u8, evt: *Vapor.Event) void {
                    //         value_type.* = evt.text();
                    //     }
                    // }.updateText, value) catch |err| {
                    //     Vapor.println("bindValue: Could not attach event callback {any}\n", .{err});
                    //     unreachable;
                    // };
                },
                .int => {
                    if (@TypeOf(value.*) != i32) {
                        Vapor.printlnErr("bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                },
                .float => {
                    if (@TypeOf(value.*) != f32) {
                        Vapor.printlnErr("bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                },
                else => {
                    Vapor.printlnErr("NOT IMPLEMENTED", .{});
                    return self.*;
                },
            }
            new_self._value = @ptrCast(@alignCast(value));

            return new_self;
        }

        pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;
            var element = self._element orelse {
                Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
                unreachable;
            };

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    ._elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            const uuid = ui_node.uuid;
            var onid = hashKey(uuid);
            onid +%= hashKey(Vapor.on_change_hash);
            element.on_focus = cb;
            Vapor.events_callbacks.put(onid, cb) catch |err| {
                Vapor.println("Event Callback Error: {any}\n", .{err});
            };
            return new_self;
        }

        pub fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;
            var element = self._element orelse {
                Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
                unreachable;
            };

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    ._elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            const uuid = ui_node.uuid;
            var onid = hashKey(uuid);
            onid +%= hashKey(Vapor.on_blur_hash);
            element.on_blur = cb;
            Vapor.events_callbacks.put(onid, cb) catch |err| {
                Vapor.println("Event Callback Error: {any}\n", .{err});
            };
            return new_self;
        }

        pub fn onChange(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            // If we have a binded value we instead create a wrapper ctx around the cb passed in
            // this way we can update the binded values from the callback and call the developer's
            // cb with the updated value
            // if (self._value) |value| {
            //     switch (self._text_field_type) {
            //         .string => {
            //             Vapor.attachEventCtxCallback(ui_node, .input, struct {
            //                 pub fn updateText(value_opaque: *anyopaque, evt: *Vapor.Event) void {
            //                     const value_type: *[]const u8 = @ptrCast(@alignCast(value_opaque));
            //                     value_type.* = evt.text();
            //                     Vapor.print("updateText: {s}\n", .{value_type.*});
            //                     @call(.auto, cb, .{evt});
            //                 }
            //             }.updateText, value) catch |err| {
            //                 Vapor.println("bindValue: Could not attach event callback {any}\n", .{err});
            //                 unreachable;
            //             };
            //         },
            //         else => return self.*,
            //     }
            // } else {
            Vapor.attachEventCallback(ui_node, .input, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };
            // }

            return new_self;
        }

        pub fn onKeyDown(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            // If we have a binded value we instead create a wrapper ctx around the cb passed in
            // this way we can update the binded values from the callback and call the developer's
            // cb with the updated value
            Vapor.attachEventCallback(ui_node, .keydown, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn whitespace(self: *const Self, value: types.WhiteSpace) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.white_space = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn fontSize(self: *const Self, font_size: u8) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            new_self._visual = visual;
            return new_self;
        }

        pub fn fontFamily(self: *const Self, font_family: []const u8) Self {
            var new_self: Self = self.*;
            new_self._font_family = font_family;
            return new_self;
        }

        pub fn onHover(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCallback(ui_node, .pointerenter, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onLeave(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };
            Vapor.attachEventCallback(ui_node, .mouseleave, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn id(self: *const Self, element_id: []const u8) Self {
            var new_self: Self = self.*;
            new_self._id = element_id;
            return new_self;
        }

        pub fn animationEnter(self: *const Self, animation_ptr: *const Vapor.Animation) Self {
            var new_self: Self = self.*;
            new_self._animation_enter = animation_ptr;
            return new_self;
        }

        pub fn animationExit(self: *const Self, animation_ptr: *const Vapor.Animation) Self {
            var new_self: Self = self.*;
            new_self._animation_exit = animation_ptr;
            return new_self;
        }

        pub fn ref(self: *const Self, element: *Element) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            element.element_type = self._elem_type;
            element._node_ptr = ui_node;
            new_self._element = element;

            const uuid = ui_node.uuid;
            Vapor.element_registry.put(hashKey(uuid), element) catch unreachable;
            return new_self;
        }

        pub fn baseStyle(self: *const Self, style_ptr: *const Vapor.Style) Self {
            var new_self: Self = self.*;
            new_self._style = style_ptr;
            return new_self;
        }

        pub fn interaction(self: *const Self, interactive: types.Interactive) Self {
            var new_self: Self = self.*;
            new_self._interactive = interactive;
            return new_self;
        }

        /// This function takes a const pointer to a Style Struct, and returns the body function callback
        /// This function is static, so any styles added via chaining methods will not be applied
        /// Use baseStyle to keep all chained additions
        pub fn style(self: *const Self, style_ptr: *const Vapor.Style) void {
            var elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
                .style = style_ptr,
                .href = self._href,
                .svg = self._svg,
                .alt = self._alt,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .name = self._name,
            };

            if (self._text_field_params) |params| {
                elem_decl.text_field_params = params;
            }

            if (self._id) |_id| {
                var mutable_style = style_ptr.*;
                mutable_style.id = _id;
                elem_decl.style = &mutable_style;
            }

            Vapor.LifeCycle.configure(elem_decl);
            return Vapor.LifeCycle.close({});
        }

        pub fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            visual.font_weight = weight;
            visual.text_color = color;
            new_self._visual = visual;
            return new_self;
        }

        pub fn bold(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_weight = 700;
            new_self._visual = visual;
            return new_self;
        }

        pub fn pos(self: *const Self, position: types.Position) Self {
            var new_self: Self = self.*;
            var new_position = new_self._pos orelse types.Position{};
            new_position.top = position.top;
            new_position.right = position.right;
            new_position.bottom = position.bottom;
            new_position.left = position.left;
            new_position.type = position.type;
            new_self._pos = new_position;
            return new_self;
        }

        pub fn zIndex(self: *const Self, z_index: ?i16) Self {
            var new_self: Self = self.*;
            var position = new_self._pos orelse types.Position{};
            position.z_index = z_index;
            new_self._pos = position;
            return new_self;
        }

        pub fn blur(self: *const Self, value: ?u8) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.blur = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn layout(self: *const Self, value: types.Layout) Self {
            var new_self: Self = self.*;
            new_self._layout = value;
            return new_self;
        }

        pub fn center(self: *const Self) Self {
            var new_self: Self = self.*;
            new_self._layout = .center;
            return new_self;
        }

        pub fn background(self: *const Self, value: types.Background) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.background = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn shadow(self: *const Self, value: types.Shadow) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.shadow = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn layer(self: *const Self, value: types.BackgroundLayer) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.layer = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
            var new_self: Self = self.*;
            new_self._flex_wrap = value;
            return new_self;
        }

        pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_decoration = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverScale(self: *const Self) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var hover = _interactive.hover orelse types.Visual{};
            hover.transform = .scale();
            _interactive.hover = hover;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn outline(self: *const Self, value: types.Outline) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.outline = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn caret(self: *const Self, value: types.Caret) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.caret = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn resize(self: *const Self, value: types.Resize) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.resize = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverBackground(self: *const Self, color: types.Background) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var hover = _interactive.hover orelse types.Visual{};
            hover.background = color;
            _interactive.hover = hover;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn pointer(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.cursor = .pointer;
            new_self._visual = visual;
            return new_self;
        }

        pub fn noDecoration(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_decoration = .none;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverText(self: *const Self, color: types.Color) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var hover = _interactive.hover orelse types.Visual{};
            hover.text_color = color;
            _interactive.hover = hover;
            new_self._interactive = _interactive;
            return new_self;
        }
        pub fn childGap(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            new_self._child_gap = value;
            return new_self;
        }

        pub fn spacing(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            new_self._child_gap = value;
            return new_self;
        }

        pub fn padding(self: *const Self, value: types.Padding) Self {
            var new_self: Self = self.*;
            new_self._padding = value;
            return new_self;
        }

        pub fn pl(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.left = value;
            return new_self;
        }

        pub fn pr(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.right = value;
            return new_self;
        }

        pub fn pt(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.top = value;
            return new_self;
        }

        pub fn pb(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?.bottom = value;
            return new_self;
        }

        pub fn cursor(self: *const Self, value: types.Cursor) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.cursor = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn margin(self: *const Self, value: types.Margin) Self {
            var new_self: Self = self.*;
            new_self._margin = value;
            return new_self;
        }

        pub fn size(self: *const Self, dim: types.Size) Self {
            var new_self: Self = self.*;
            new_self._size = dim;
            return new_self;
        }

        pub fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .width = width_value, .height = height_value };
            } else {
                new_self._size.?.width = width_value;
                new_self._size.?.height = height_value;
            }
            return new_self;
        }

        pub fn width(self: *const Self, length: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .width = length };
            } else {
                new_self._size.?.width = length;
            }
            return new_self;
        }

        pub fn height(self: *const Self, length: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .height = length };
            } else {
                new_self._size.?.height = length;
            }
            return new_self;
        }

        pub fn border(self: *const Self, value: types.BorderGrouped) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.border = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn radius(self: *const Self, value: types.BorderRadius) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.border_radius = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn duration(self: *const Self, value: u32) Self {
            var new_self: Self = self.*;
            new_self._transition = .{ .duration = value };
            return new_self;
        }

        pub fn direction(self: *const Self, value: types.Direction) Self {
            var new_self: Self = self.*;
            new_self._direction = value;
            return new_self;
        }

        pub fn listStyle(self: *const Self, value: types.ListStyle) Self {
            var new_self: Self = self.*;
            new_self._list_style = value;
            return new_self;
        }

        pub fn end(self: *const Self) void {
            var mutable_style = Style{};
            if (self._style) |style_ptr| {
                mutable_style = style_ptr.*;
            }
            if (mutable_style.position == null) mutable_style.position = self._pos;
            if (mutable_style.visual == null) mutable_style.visual = self._visual;
            if (mutable_style.interactive == null) mutable_style.interactive = self._interactive;
            if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
            if (mutable_style.padding == null) mutable_style.padding = self._padding;
            if (mutable_style.layout == null) mutable_style.layout = self._layout;
            if (mutable_style.margin == null) mutable_style.margin = self._margin;
            if (mutable_style.size == null) mutable_style.size = self._size;
            if (mutable_style.transition == null) mutable_style.transition = self._transition;
            if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
            mutable_style.direction = self._direction;
            if (mutable_style.list_style == null) mutable_style.list_style = self._list_style;
            if (mutable_style.font_family == null) mutable_style.font_family = self._font_family;

            if (self._id) |_id| {
                mutable_style.id = _id;
            }

            var elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
                .style = &mutable_style,
                .href = self._href,
                .svg = self._svg,
                .alt = self._alt,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
                .name = self._name,
            };

            if (self._text_field_params) |params| {
                elem_decl.text_field_params = params;
            }

            Vapor.LifeCycle.configure(elem_decl);
            return Vapor.LifeCycle.close({});
        }

        pub fn plain(self: *const Self) void {
            const elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
            };
            _ = Vapor.LifeCycle.open(elem_decl);
            Vapor.LifeCycle.configure(elem_decl);
            Vapor.LifeCycle.close({});
        }
    };
}

var name_len: usize = 0;
pub export fn getFieldName(node_ptr: *UINode) ?[*]const u8 {
    if (node_ptr.name) |name| {
        name_len = name.len;
        return name.ptr;
    }
    return null;
}

pub export fn getFieldNameLen() usize {
    return name_len;
}

const FieldExportString = Vapor.exportStruct(types.InputParamsString);
const FieldExportInt = Vapor.exportStruct(types.InputParamsInt);
const FieldExportPassword = Vapor.exportStruct(types.InputParamsPassword);
const FieldExportEmail = Vapor.exportStruct(types.InputParamsEmail);
const FieldExportTelephone = Vapor.exportStruct(types.InputParamsTelephone);
const FieldExportFile = Vapor.exportStruct(types.InputParamsFile);

pub export fn getTextFieldParams(node_ptr: ?*UINode) ?[*]const u8 {
    const text_field_params = node_ptr.?.text_field_params orelse return null;
    switch (text_field_params) {
        .string => |string| {
            FieldExportString.init();
            FieldExportString.instance = string;
            return FieldExportString.getInstancePtr();
        },
        .int => |int| {
            FieldExportInt.init();
            FieldExportInt.instance = int;
            return FieldExportInt.getInstancePtr();
        },
        .password => |password| {
            FieldExportPassword.init();
            FieldExportPassword.instance = password;
            return FieldExportPassword.getInstancePtr();
        },
        .email => |email| {
            FieldExportEmail.init();
            FieldExportEmail.instance = email;
            return FieldExportEmail.getInstancePtr();
        },
        .telephone => |telephone| {
            FieldExportTelephone.init();
            FieldExportTelephone.instance = telephone;
            return FieldExportTelephone.getInstancePtr();
        },
        .file => |file| {
            FieldExportFile.init();
            FieldExportFile.instance = file;
            return FieldExportFile.getInstancePtr();
        },
    }
    return null;
}

pub export fn getTextFieldCount(node_ptr: *UINode) u32 {
    const text_field_params = node_ptr.text_field_params orelse {
        Vapor.printErr("Error: No text_field_params found {any}", .{node_ptr.type});
        return 0;
    };
    switch (text_field_params) {
        .string => {
            return FieldExportString.getFieldCount();
        },
        .int => {
            return FieldExportInt.getFieldCount();
        },
        .password => {
            return FieldExportPassword.getFieldCount();
        },
        .email => {
            return FieldExportEmail.getFieldCount();
        },
        .telephone => {
            return FieldExportTelephone.getFieldCount();
        },
        .file => {
            return FieldExportFile.getFieldCount();
        },
    }
    return 0;
}

pub export fn getTextFieldDescriptor(node_ptr: ?*UINode, index: u32) ?*const Vapor.FieldDescriptor() {
    const text_field_params = node_ptr.?.text_field_params orelse return null;
    switch (text_field_params) {
        .string => {
            return FieldExportString.getFieldDescriptor(index);
        },
        .int => {
            return FieldExportInt.getFieldDescriptor(index);
        },
        .password => {
            return FieldExportPassword.getFieldDescriptor(index);
        },
        .email => {
            return FieldExportEmail.getFieldDescriptor(index);
        },
        .telephone => {
            return FieldExportTelephone.getFieldDescriptor(index);
        },
        .file => {
            return FieldExportFile.getFieldDescriptor(index);
        },
    }
    return null;
}
