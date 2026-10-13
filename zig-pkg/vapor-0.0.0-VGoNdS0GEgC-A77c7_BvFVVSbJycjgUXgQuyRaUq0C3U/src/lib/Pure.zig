const std = @import("std");
const types = @import("types.zig");
const Vapor = @import("Vapor.zig");
const println = Vapor.println;
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const CommandsTree = UIContext.CommandsTree;
const Transition = @import("Transition.zig").Transition;
const TransitionState = @import("Transition.zig").TransitionState;
const Element = @import("Element.zig").Element;
const LifeCycle = Vapor.LifeCycle;
const Static = @import("Static.zig");
const Binded = @import("Binded.zig");
const Types = @import("types.zig");
const IconTokens = @import("user_config").IconTokens;
const Color = types.Color;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;

const Style = types.Style;
const EventType = types.EventType;
const Active = types.Active;
const BoundingBox = types.BoundingBox;
const InputDetails = types.InputDetails;
const Dimensions = types.Dimensions;
const InputParams = types.InputParams;
const ElementDecl = types.ElementDeclaration;
const RenderCommand = types.RenderCommand;
const ElementType = types.ElementType;
const Hover = types.Hover;
const Transform = types.Transform;
const TransformType = types.TransformType;

const HeaderSize = enum(u32) {
    XXLarge = 12,
    XLarge = 8,
    Large = 4,
    Medium = 2,
    Small = 1,
};

const IconOptions = struct {
    icon_name: []const u8,
    style: ?*const Style = null,
};

pub inline fn Icon(options: IconOptions) void {
    const local = struct {
        fn CloseElement() void {
            _ = Vapor.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Vapor.current_ctx.configure(elem_decl);
            return;
        }
    };

    const elem_decl = ElementDecl{
        ._href = options.icon_name,
        .elem_type = .Icon,
        .style = options.style,
        .state_type = .pure,
    };

    // if (style.style_id == null) {
    //     elem_decl.style.style_id = icon_name;
    // }

    _ = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
}

pub inline fn Header(text: []const u8, size: HeaderSize, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Vapor.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Vapor.current_ctx.configure(elem_decl);
            return;
        }
    };

    var elem_decl = ElementDecl{
        .style = style,
        .state_type = .pure,
        .elem_type = .Header,
        ._text = text,
    };
    // const dimensions = measureText(text, &elem_decl.style);
    // // Make sure this is the right order of ops
    // elem_decl.style.width = dimensions.width;
    // elem_decl.style.height = dimensions.height;
    elem_decl.style.width.type = .elastic;
    if (style.font_size == 0) {
        switch (size) {
            .XXLarge => elem_decl.style.font_size = 12 * 12,
            .XLarge => elem_decl.style.font_size = 12 * 8,
            .Large => elem_decl.style.font_size = 12 * 4,
            .Medium => elem_decl.style.font_size = 12 * 2,
            .Small => elem_decl.style.font_size = 12 * 1,
        }
    }
    _ = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    _ = local.CloseElement();
    return;
}
pub inline fn Hooks(hooks: Vapor.HooksFuncs) fn (void) void {
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Vapor.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *const fn (void) void {
            _ = Vapor.current_ctx.configure(elem_decl);
            return CloseElement;
        }
    };

    var elem_decl = ElementDecl{
        .elem_type = .Hooks,
    };

    if (hooks.mounted) |f| {
        const id = Vapor.mounted_funcs.count();
        elem_decl.hooks.mounted_id += id + 1;
        Vapor.mounted_funcs.put(elem_decl.hooks.mounted_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.created) |f| {
        const id = Vapor.created_funcs.count();
        elem_decl.hooks.created_id += id + 1;
        Vapor.created_funcs.put(elem_decl.hooks.created_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.updated) |f| {
        const id = Vapor.updated_funcs.count();
        elem_decl.hooks.updated_id += id + 1;
        Vapor.updated_funcs.put(elem_decl.hooks.updated_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.destroy) |f| {
        const id = Vapor.destroy_funcs.count();
        elem_decl.hooks.destroy_id += id + 1;
        Vapor.destroy_funcs.put(elem_decl.hooks.destroy_id, f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }

    _ = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
    };
    _ = local.ConfigureElement(elem_decl);
    return local.CloseElement;
}

pub inline fn Draggable(element: *Element, style: Style) fn (void) void {
    const local = struct {
        fn CloseElement(_: void) void {
            _ = Vapor.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) *UINode {
            return Vapor.current_ctx.configure(elem_decl);
        }
    };

    var elem_decl = ElementDecl{
        .style = style,
        .state_type = .pure,
        .elem_type = .Draggable,
    };

    elem_decl.style.position.type = .absolute;

    _ = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    const ui_node = local.ConfigureElement(elem_decl);
    element.uuid = ui_node.uuid;
    element.draggable = true;
    element.element_type = .Draggable;
    return local.CloseElement;
}

const FlexType = enum(u8) {
    Flex = 0, // "flex"
    Center = 1,
    Stack = 2, // "inline-flex"
    Flow = 3, // "inherit"
    // Initial = 3, // "initial"
    // Revert = 4, // "revert"
    // Unset = 5, // "unset"
    // InlineBlock = 7, // "inline-block"
    // Inline = 8, // "inline-flex"
    None = 4, // "centers the child content"
};

const ButtonOptions = struct {
    on_press: ?*const fn () void = null,
    onRelease: ?*const fn () void = null,
    aria_label: ?[]const u8 = null,
};

pub fn VirtualList(comptime T: type) type {
    return struct {
        var total_height: f32 = 0;
        var list_height: f32 = 0;
        var total_items: f32 = 0;
        var scroll_top_max: f32 = 0;
        var total_window_items: usize = 0;
        const VirtualListOptions = struct {
            data: []const T,
            render: *const fn (T, usize) void,
            buffer_size: usize = 10,
            item_height: Types.Sizing,
            item_width: Types.Sizing,
        };
        const ScrollDirection = enum {
            up,
            down,
            none,
        };
        const Self = @This();
        data: []const T,
        render: *const fn (T, usize) void,
        buffer_size: f32 = 10,
        item_height: f32,
        item_width: f32,
        _internal_slice: []T,
        list_element: Element = undefined,
        inner_container: Element = undefined,
        window_element: Element = undefined,
        current_scroll: f32 = 0, // the current scroll of the list
        current_item_index: usize = 0, // the current item index

        // Add these fields to your struct
        prev_scroll_top: f32 = 0,
        prev_item_index: f32 = 0,
        up_threshold: f32 = 0,
        down_threshold: f32 = 0,

        pub fn init(options: VirtualListOptions) Self {
            const calculated_item_height = options.item_height.size.minmax.min;
            const calculated_item_width = options.item_width.size.minmax.min;

            var item_height: f32 = 0;
            var item_width: f32 = 0;
            switch (options.item_height.type) {
                .fit => item_height = calculated_item_height,
                .min_max_vp => item_height = calculated_item_height,
                .grow => item_height = calculated_item_height,
                .percent => item_height = calculated_item_height * Vapor.browser_height / 100,
                .fixed => item_height = options.item_height.size.minmax.min,
                .elastic => item_height = calculated_item_height,
                .elastic_percent => item_height = calculated_item_height,
                .clamp_px => item_height = calculated_item_height,
                .clamp_percent => item_height = calculated_item_height,
                .none => {},
            }
            switch (options.item_width.type) {
                .fit => item_width = calculated_item_width,
                .min_max_vp => item_width = calculated_item_width,
                .grow => item_width = calculated_item_width,
                .percent => item_width = calculated_item_width * Vapor.browser_width / 100,
                .fixed => item_width = options.item_width.size.minmax.min,
                .elastic => item_width = calculated_item_width,
                .elastic_percent => item_width = calculated_item_width,
                .clamp_px => item_width = calculated_item_width,
                .clamp_percent => item_width = calculated_item_width,
                .none => {},
            }

            total_height = @as(f32, @floatFromInt(options.data.len)) * item_height;
            total_items = @as(f32, @floatFromInt(options.data.len));
            scroll_top_max = total_height - Vapor.browser_height;

            const number_of_items_fit = @as(usize, @intFromFloat(@floor(Vapor.browser_height / item_height)));
            const min_buffer: usize = 20;
            const max_buffer: usize = 100;

            // Use larger buffer for smaller visible counts, smaller buffer for larger visible counts
            const buffer_size = if (number_of_items_fit <= 5)
                @min(number_of_items_fit * 5, max_buffer)
            else if (number_of_items_fit <= 20)
                @min(number_of_items_fit * 3, max_buffer)
            else
                @min(number_of_items_fit * 2, max_buffer);

            total_window_items = @max(min_buffer, @min(buffer_size, options.data.len));
            Vapor.println("total_window_items {d}", .{total_window_items});

            list_height = @as(f32, @floatFromInt(total_window_items)) * item_height;

            var internal_slice: []T = Vapor.allocator_global.alloc(T, total_window_items) catch unreachable;
            for (0..total_window_items) |i| {
                internal_slice[i] = options.data[i];
            }

            return Self{
                .data = options.data,
                .render = options.render,
                .buffer_size = @as(f32, @floatFromInt(options.buffer_size)),
                .item_height = item_height,
                .item_width = item_width,
                ._internal_slice = internal_slice,
                .list_element = Element{},
                .inner_container = Element{},
                .window_element = Element{},
                .current_scroll = 0,
                .current_item_index = 0,
            };
        }

        fn mount(self: *Self) void {
            Vapor.println("Mount {s}\n", .{self.inner_container._get_id().?});
            _ = self.inner_container.addInstListener(.scroll, self, trackScroll);
        }

        fn rerender_list(self: *Self, current_index: f32, direction: ScrollDirection) void {
            const start_index: usize = @max(0, @as(usize, @intFromFloat(@max(0, current_index - self.buffer_size))));
            // Add 1 to include the end_index item, but cap at data length
            const end_index: usize = @min(self.data.len, @as(usize, @intFromFloat(@min(total_items, current_index + self.buffer_size + 1))));

            if (start_index >= self.data.len) return;

            // Optional: Add momentum-based preloading
            const preload_extra = switch (direction) {
                .down => @min(5, self.data.len - end_index), // Preload 5 more items when scrolling down
                .up => 0, // Less preloading when scrolling up
                .none => 0,
            };

            const final_end = @min(self.data.len, end_index + preload_extra);

            for (start_index..final_end, 0..) |data_index, i| {
                self._internal_slice[i] = self.data[data_index];
            }

            // for (start_index..end_index, 0..) |data_index, i| {
            //     self._internal_slice[i] = self.data[data_index];
            // }

            const translation = Vapor.fmtln("translateY({d}px)", .{start_index * @as(usize, @intFromFloat(self.item_height))});
            self.window_element.mutateStyle("transform", .{ .string = translation });
            Vapor.cycle();
        }

        pub fn trackScroll(self: *Self, _: *Vapor.Event) void {
            const scroll_top: f32 = @floatFromInt(self.inner_container.getAttributeNumber("scrollTop"));
            const current_item_index = @floor(@divExact(scroll_top, self.item_height));

            // Determine scroll direction
            const direction: ScrollDirection = if (scroll_top > self.prev_scroll_top) .down else if (scroll_top < self.prev_scroll_top) .up else .none;

            // Check if we need to rerender based on direction and thresholds
            const should_rerender = switch (direction) {
                .down => scroll_top > self.down_threshold and !self.isAtEnd(current_item_index),
                .up => scroll_top < self.up_threshold and !self.isAtStart(current_item_index),
                .none => false,
            };
            if (should_rerender) {
                self.rerender_list(current_item_index, direction);

                // Update thresholds based on direction
                switch (direction) {
                    .down => {
                        self.down_threshold = scroll_top + (5 * self.item_height); // Next rerender point
                        self.up_threshold = scroll_top - (5 * self.item_height); // Reverse direction threshold
                    },
                    .up => {
                        self.up_threshold = scroll_top - (5 * self.item_height); // Next rerender point
                        self.down_threshold = scroll_top + (5 * self.item_height); // Reverse direction threshold
                    },
                    .none => {},
                }
            }

            // Store current state for next comparison
            self.prev_scroll_top = scroll_top;
            self.prev_item_index = current_item_index;
        }

        fn isAtEnd(self: *Self, current_item_index: f32) bool {
            return current_item_index + self.buffer_size - 1 >= @as(f32, @floatFromInt(self.data.len));
        }

        fn isAtStart(_: *Self, current_item_index: f32) bool {
            return current_item_index <= 0;
        }

        pub fn generate(self: *Self) void {
            Static.CtxHooks(.mounted, mount, .{self}, &.{
                .size = .{ .width = .percent(100) },
            })({
                Binded.List(.{
                    .element = &self.inner_container,
                    .style = &.{
                        .size = .{
                            .height = .px(Vapor.browser_height),
                            .width = .percent(100),
                        },
                        .direction = .column,
                        .scroll = .scroll_y(),
                        .padding = .all(0),
                        .list_style = .none,
                        .show_scrollbar = false,
                    },
                })({
                    Binded.Box(.{
                        .element = &self.list_element,
                        .style = &.{
                            .size = .{
                                .height = .px(total_height),
                                .width = .percent(100),
                            },
                            .direction = .column,
                        },
                    })({
                        Binded.List(.{
                            .element = &self.window_element,
                            .style = &.{
                                .position = .{
                                    .type = .absolute,
                                    .top = .px(0),
                                },
                                .list_style = .none,
                                .size = .{
                                    .height = .px(list_height),
                                    .width = .percent(100),
                                },
                                .direction = .column,
                                .scroll = .none(),
                                .padding = .all(0),
                            },
                        })({
                            for (self._internal_slice, 0..) |item, i| {
                                Static.ListItem(.{ .style = &.{
                                    .size = .{
                                        .height = .px(self.item_height),
                                        .width = .percent(self.item_width),
                                    },
                                } })({
                                    @call(.auto, self.render, .{ item, i });
                                });
                            }
                        });
                    });
                });
            });
        }
    };
}

pub const ChainClose = struct {
    const Self = @This();
    _elem_type: Vapor.ElementType,
    _state_type: Types.StateType = .pure,
    _flex_type: FlexType = .Flex,
    _text: ?[]const u8 = null,
    _href: ?[]const u8 = null,
    _svg: []const u8 = "",
    _aria_label: ?[]const u8 = null,
    _options: ?ButtonOptions = null,
    _input_params: ?*const InputParams = null,
    _ui_node: ?*UINode = null,
    _id: ?[]const u8 = null,
    _style: ?*const Vapor.Style = null,

    _animation_enter: ?*const Vapor.Animation = null,
    _animation_exit: ?*const Vapor.Animation = null,

    // Style props
    _pos: ?types.Position = null,
    _font_size: ?u8 = null,
    _font_weight: ?u16 = null,
    _text_color: ?Color = null,
    _padding: ?types.Padding = null,
    _layout: ?types.Layout = null,
    _background: ?types.Background = null,
    _border: ?types.BorderGrouped = null,
    _border_radius: ?types.BorderRadius = null,
    _margin: ?types.Margin = null,
    _size: ?types.Size = null,
    _child_gap: ?u8 = null,
    _text_decoration: ?types.TextDecoration = null,
    _interactive: ?types.Interactive = null,
    _transition: ?types.Transition = null,
    _z_index: ?i16 = null,
    _blur: ?u8 = null,
    _direction: types.Direction = .row,
    _list_style: ?types.ListStyle = null,

    pub fn Text(text: []const u8) Self {
        return Self{ .elem_type = .Text, ._text = if (Vapor.isGenerated) "" else text };
    }

    pub fn id(self: *const Self, element_id: []const u8) Self {
        var new_self: Self = self.*;
        new_self._id = element_id;
        return new_self;
    }

    /// TextFmt takes a format string and a array of arguments and allocates a new string
    /// This string is handled by the Vapor engine and is not freed by the user
    pub fn TextFmt(comptime fmt: []const u8, args: anytype) Self {
        const allocator = Vapor.arena(.frame);
        const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
            Vapor.printlnColor(
                \\Error formatting text: {any}\n"
                \\FMT: {s}\n"
                \\ARGS: {any}\n"
            , .{ err, fmt, args }, .hex("#FF3029"));
            return Self{ ._elem_type = .Text, ._text = "ERROR", ._state_type = .err };
        };
        Vapor.frame_arena.addBytesUsed(text.len);
        return Self{ ._elem_type = .TextFmt, ._text = text };
    }

    /// TextFmt takes a format string and a array of arguments and allocates a new string
    /// This string is handled by the Vapor engine and is not freed by the user
    pub inline fn TextFmtErr(fmt: []const u8, args: anytype) Self {
        // const allocator = Vapor.arena(.frame);
        // const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        //     std.debug.print("Error formatting text: {any}\n", .{err});
        Vapor.printlnColor(
            \\Error formatting text: {any}
            \\FMT: {s}
            \\ARGS: {any}
        , .{ error.CouldNotAllocate, fmt, args }, .hex("#FF3029"));
        return Self{ ._elem_type = .Text, ._text = "ERROR", ._state_type = .err };
        // };
        // Vapor.frame_arena.addBytesUsed(text.len);
        // return Self{ ._elem_type = .TextFmt, ._text = text };
    }
    pub fn Icon(token: *const IconTokens) Self {
        if (Vapor.isWasi) {
            return Self{ ._elem_type = .Icon, ._href = token.web orelse "" };
        } else {
            return Self{ ._elem_type = .Icon, ._href = token.svg orelse "" };
        }
    }

    pub fn Image(options: struct { src: []const u8 }) Self {
        return Self{ ._elem_type = .Image, ._href = options.src };
    }

    pub fn Svg(options: struct { svg: []const u8 }) Self {
        return Self{ ._elem_type = .Svg, .svg = options.svg };
    }

    pub fn style(self: *const Self, style_ptr: *const Vapor.Style) void {
        var elem_decl = Vapor.ElementDecl{
            .state_type = self._state_type,
            .elem_type = self._elem_type,
            .text = self._text,
            .style = style_ptr,
            .href = self._href,
            .svg = self._svg,
            .aria_label = self._aria_label,
        };

        if (self._id) |_id| {
            var mutable_style = style_ptr.*;
            mutable_style.id = _id;
            elem_decl.style = &mutable_style;
        }

        _ = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close({});
    }

    pub fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
        var new_self: Self = self.*;
        new_self._font_size = font_size;
        new_self._font_weight = weight;
        new_self._text_color = color;
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

    pub fn blur(self: *const Self, value: ?u32) Self {
        var new_self: Self = self.*;
        new_self._blur = value;
        return new_self;
    }

    pub fn layout(self: *const Self, value: types.Layout) Self {
        var new_self: Self = self.*;
        new_self._layout = value;
        return new_self;
    }

    pub fn background(self: *const Self, value: types.Background) Self {
        var new_self: Self = self.*;
        new_self._background = value;
        return new_self;
    }

    pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
        var new_self: Self = self.*;
        new_self._text_decoration = value;
        return new_self;
    }

    pub fn hoverScale(self: *const Self) Self {
        var new_self: Self = self.*;
        new_self._interactive = .hover_scale();
        return new_self;
    }

    pub fn hoverText(self: *const Self, color: Color) Self {
        var new_self: Self = self.*;
        new_self._interactive = .hover_text(color);
        return new_self;
    }

    pub fn childGap(self: *const Self, value: u32) Self {
        var new_self: Self = self.*;
        new_self._child_gap = value;
        return new_self;
    }

    pub fn padding(self: *const Self, value: types.Padding) Self {
        var new_self: Self = self.*;
        new_self._padding = value;
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
        new_self._border = value;
        return new_self;
    }

    pub fn radius(self: *const Self, value: types.BorderRadius) Self {
        var new_self: Self = self.*;
        new_self._border_radius = value;
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

    pub fn close(self: *const Self) void {
        var mutable_style = Style{};
        if (self._style) |style_ptr| {
            mutable_style = style_ptr.*;
        }
        if (mutable_style.position == null) mutable_style.position = self._pos;
        if (mutable_style.visual == null) mutable_style.visual = .{
            .font_size = self._font_size,
            .font_weight = self._font_weight,
            .text_color = self._text_color,
            .background = self._background,
            .border = self._border,
            .border_radius = self._border_radius,
            .text_decoration = self._text_decoration,
            .blur = self._blur,
        };
        if (mutable_style.interactive == null) mutable_style.interactive = self._interactive;
        if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
        if (mutable_style.padding == null) mutable_style.padding = self._padding;
        if (mutable_style.layout == null) mutable_style.layout = self._layout;
        if (mutable_style.margin == null) mutable_style.margin = self._margin;
        if (mutable_style.size == null) mutable_style.size = self._size;
        if (mutable_style.transition == null) mutable_style.transition = self._transition;
        mutable_style.direction = self._direction;
        mutable_style.list_style = self._list_style;

        // if (self._tooltip) |_tooltip| {
        //     elem_decl.tooltip = &_tooltip;
        // }

        if (self._flex_type == .Center) {
            mutable_style.layout = .center;
        } else if (self._flex_type == .Stack) {
            mutable_style.direction = .column;
        }

        if (self._id) |_id| {
            mutable_style.id = _id;
        }

        const elem_decl = Vapor.ElementDecl{
            .elem_type = self._elem_type,
            .state_type = self._state_type,
            .text = self._text,
            .style = &mutable_style,
            .href = self._href,
            .svg = self._svg,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
        };

        if (self._elem_type != .CtxButton) {
            const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
            if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                if (self._options.?.on_press) |on_press| {
                    Vapor.btn_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }
        } else if (self._elem_type == .CtxButton) {
            const ui_node = self._ui_node orelse unreachable;
            if (elem_decl.style.?.style_id) |element_id| {
                const kv = Vapor.ctx_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                Vapor.ctx_registry.put(hashKey(element_id), kv.value) catch |err| {
                    println("Button Function Registry {any}\n", .{err});
                    unreachable;
                };
            }
        }

        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close({});
    }
};

const Tooltip = struct {
    text: []const u8,
    position: types.Position,
    layout: types.Layout,
    color: ?Vapor.Types.Color = null,
    background: ?Vapor.Types.Background = null,
    border: ?Vapor.Types.BorderGrouped = null,
    delay: u32 = 300,
};

pub const Chain = struct {
    const Self = @This();
    _elem_type: Vapor.ElementType,
    _flex_type: FlexType = .Flex,
    _text: ?[]const u8 = null,
    _href: ?[]const u8 = null,
    _svg: []const u8 = "",
    _aria_label: ?[]const u8 = null,
    _options: ?ButtonOptions = null,
    _input_params: ?*const InputParams = null,
    _ui_node: ?*UINode = null,
    _id: ?[]const u8 = null,
    _style: ?*const Vapor.Style = null,

    _animation_enter: ?*const Vapor.Animation = null,
    _animation_exit: ?*const Vapor.Animation = null,

    // Style props
    _pos: ?types.Position = null,
    _font_size: ?u8 = null,
    _font_weight: ?usize = null,
    _text_color: ?Color = null,
    _padding: ?types.Padding = null,
    _layout: ?types.Layout = null,
    _background: ?types.Background = null,
    _border: ?types.BorderGrouped = null,
    _border_radius: ?types.BorderRadius = null,
    _margin: ?types.Margin = null,
    _size: ?types.Size = null,
    _child_gap: ?u8 = null,
    _text_decoration: ?types.TextDecoration = null,
    _interactive: ?types.Interactive = null,
    _transition: ?types.Transition = null,
    _z_index: ?i16 = null,
    _blur: ?u32 = null,

    // _tooltip: ?types.Tooltip = null,

    pub fn TextArea(text: []const u8) Self {
        return Self{ ._elem_type = .TextArea, ._text = text };
    }

    pub fn Label(text: []const u8, tag: []const u8) Self {
        return Self{ ._elem_type = .Text, ._text = text, ._href = tag };
    }

    pub fn Input(params: InputParams) Self {
        return Self{ ._elem_type = .Input, ._input_params = params, .style = style };
    }

    pub fn Button(options: ButtonOptions) Self {
        return Self{ ._elem_type = .Button, ._aria_label = options.aria_label, ._options = options };
    }

    pub fn CtxButton(func: anytype, args: anytype) Self {
        const elem_decl = ElementDecl{
            .state_type = .static,
            ._elem_type = .CtxButton,
        };

        const ui_node = Vapor.current_ctx.open(elem_decl) catch |err| {
            println("{any}\n", .{err});
            unreachable;
        };
        const Args = @TypeOf(args);
        const Closure = struct {
            arguments: Args,
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
                @call(.auto, func, closure.arguments);
            }
            fn deinitFn(node: *Vapor.Node) void {
                const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
                Vapor.allocator_global.destroy(closure);
            }
        };

        const closure = Vapor.allocator_global.create(Closure) catch |err| {
            println("Error could not create closure {any}\n ", .{err});
            unreachable;
        };
        closure.* = .{
            .arguments = args,
        };

        Vapor.ctx_registry.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
            println("Button Function Registry {any}\n", .{err});
            unreachable;
        };

        return Self{ ._elem_type = .CtxButton, ._ui_node = ui_node };
    }

    pub fn ButtonCycle(options: ButtonOptions) Self {
        return Self{ ._elem_type = .ButtonCycle, ._aria_label = options.aria_label, ._options = options };
    }

    pub const Box = Self{ ._elem_type = .FlexBox };
    pub const Center = Self{ ._elem_type = .FlexBox, ._flex_type = .Center };
    pub const Stack = Self{ ._elem_type = .FlexBox, ._flex_type = .Stack };
    pub const List = Self{ ._elem_type = .List };
    pub const ListItem = Self{ ._elem_type = .ListItem };

    pub fn Link(options: struct { url: []const u8, aria_label: ?[]const u8 }) Self {
        return Self{
            ._elem_type = .Link,
            ._aria_label = options.aria_label,
            // ._href = options.url,
            ._href = if (Vapor.isGenerated) "" else options.url,
        };
    }

    pub fn RedirectLink(options: struct { url: []const u8, aria_label: ?[]const u8 }) Self {
        return Self{
            ._elem_type = .RedirectLink,
            ._href = options.url,
            // ._href = if (Vapor.isGenerated) "" else options.url,
            ._aria_label = options.aria_label,
        };
    }

    pub fn Image(options: struct { src: []const u8 }) Self {
        return Self{ ._elem_type = .Image, ._href = options.src };
    }

    pub fn id(self: *const Self, element_id: []const u8) Self {
        var new_self: Self = self.*;
        new_self._id = element_id;
        return new_self;
    }

    pub fn bind(self: *const Self, element: *Element) *const Self {
        element._node_ptr = self._ui_node orelse unreachable;
        return self;
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

    // pub fn tooltip(self: *const Self, tool_tip: *const Tooltip) Self {
    //     var new_self: Self = self.*;
    //     var tooltip_style: Vapor.Style = .{
    //         .layout = .center,
    //         .position = .{ .type = .absolute },
    //         .padding = .tblr(4, 4, 8, 8),
    //         .visual = .{
    //             .opacity = 0,
    //             .font_size = 14,
    //             .background = tool_tip.background,
    //             ._text_color = tool_tip.color,
    //             .border = tool_tip.border,
    //         },
    //         .transition = .{ .duration = tool_tip.delay, .properties = &.{.opacity} },
    //         .white_space = .nowrap,
    //     };
    //
    //     switch (tool_tip.position) {
    //         .top => {
    //             tooltip_style.position.?.bottom = .percent(100);
    //             tooltip_style.margin = .b(8);
    //             switch (tool_tip.layout) {
    //                 .center => {
    //                     tooltip_style.position.?.left = .percent(50);
    //                     tooltip_style.visual.?.transform = .left_percent(-50); // Centers the tooltip horizontally
    //                 },
    //                 .start => {},
    //                 .end => {},
    //             }
    //         },
    //         .bottom => {
    //             tooltip_style.position.?.top = .percent(125);
    //         },
    //         .left => {
    //             tooltip_style.position.?.right = .percent(100);
    //             tooltip_style.margin = .r(8);
    //             switch (tool_tip.layout) {
    //                 .center => {
    //                     tooltip_style.position.?.top = .percent(50);
    //                     tooltip_style.visual.?.transform = .top_percent(-50); // Centers the tooltip horizontally
    //                 },
    //                 .start => {},
    //                 .end => {},
    //             }
    //         },
    //         .right => {
    //             tooltip_style.position.?.left = .percent(100);
    //             tooltip_style.margin = .l(8);
    //             switch (tool_tip.layout) {
    //                 .center => {
    //                     tooltip_style.position.?.top = .percent(50);
    //                     tooltip_style.visual.?.transform = .top_percent(-50); // Centers the tooltip horizontally
    //                 },
    //                 .start => {},
    //                 .end => {},
    //             }
    //         },
    //     }
    //
    //     new_self._tooltip = types.Tooltip{
    //         .text = tool_tip.text,
    //         .style = tooltip_style,
    //     };
    //     return new_self;
    // }

    pub fn baseStyle(self: *const Self, style_ptr: *const Vapor.Style) Self {
        var new_self: Self = self.*;
        new_self._style = style_ptr;
        return new_self;
    }

    /// This function takes a const pointer to a Style Struct, and returns the body function callback
    /// This function is static, so any styles added via chaining methods will not be applied
    /// Use baseStyle to keep all chained additions
    pub fn style(self: *const Self, style_ptr: *const Vapor.Style) *const fn (void) void {
        var elem_decl = Vapor.ElementDecl{
            .state_type = .static,
            .elem_type = self._elem_type,
            .text = self._text,
            .style = style_ptr,
            .href = self._href,
            .svg = self._svg,
            .aria_label = self._aria_label,
            .input_params = self._input_params,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
        };

        // if (self._tooltip) |_tooltip| {
        //     elem_decl.tooltip = &_tooltip;
        // }

        if (self._flex_type == .Center) {
            // Create a mutable copy of the style struct
            var mutable_style = style_ptr.*;

            // Now you can safely modify the local, mutable copy
            mutable_style.layout = .center;
            elem_decl.style = &mutable_style;
        } else if (self._flex_type == .Stack) {
            var mutable_style = style_ptr.*;
            mutable_style.direction = .column;
            elem_decl.style = &mutable_style;
        }

        if (self._id) |_id| {
            var mutable_style = style_ptr.*;
            mutable_style.id = _id;
            elem_decl.style = &mutable_style;
        }

        if (self._elem_type != .CtxButton) {
            const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
            if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                if (self._options.?.on_press) |on_press| {
                    Vapor.btn_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }
        } else if (self._elem_type == .CtxButton) {
            const ui_node = self._ui_node orelse unreachable;
            if (style_ptr.id) |element_id| {
                const kv = Vapor.ctx_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                Vapor.ctx_registry.put(hashKey(element_id), kv.value) catch |err| {
                    println("Button Function Registry {any}\n", .{err});
                    unreachable;
                };
            }
        }

        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close;
    }

    pub fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
        var new_self: Self = self.*;
        new_self._font_size = font_size;
        new_self._font_weight = weight;
        new_self._text_color = color;
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

    pub fn blur(self: *const Self, value: ?u32) Self {
        var new_self: Self = self.*;
        new_self._blur = value;
        return new_self;
    }

    pub fn layout(self: *const Self, value: types.Layout) Self {
        var new_self: Self = self.*;
        new_self._layout = value;
        return new_self;
    }

    pub fn background(self: *const Self, value: types.Background) Self {
        var new_self: Self = self.*;
        new_self._background = value;
        return new_self;
    }

    pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
        var new_self: Self = self.*;
        new_self._text_decoration = value;
        return new_self;
    }

    pub fn hoverScale(self: *const Self) Self {
        var new_self: Self = self.*;
        new_self._interactive = .hover_scale();
        return new_self;
    }

    pub fn hoverText(self: *const Self, color: Color) Self {
        var new_self: Self = self.*;
        new_self._interactive = .hover_text(color);
        return new_self;
    }

    pub fn childGap(self: *const Self, value: u32) Self {
        var new_self: Self = self.*;
        new_self._child_gap = value;
        return new_self;
    }

    pub fn padding(self: *const Self, value: types.Padding) Self {
        var new_self: Self = self.*;
        new_self._padding = value;
        return new_self;
    }

    pub fn margin(self: *const Self, top: u32, bottom: u32, left: u32, right: u32) Self {
        var new_self: Self = self.*;
        new_self._margin = .tblr(top, bottom, left, right);
        return new_self;
    }

    pub fn size(self: *const Self, dim: types.Size) Self {
        var new_self: Self = self.*;
        new_self._size = dim;
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
        new_self._border = value;
        return new_self;
    }

    pub fn radius(self: *const Self, value: types.BorderRadius) Self {
        var new_self: Self = self.*;
        new_self._border_radius = value;
        return new_self;
    }

    pub fn duration(self: *const Self, value: u32) Self {
        var new_self: Self = self.*;
        new_self._transition = .{ .duration = value };
        return new_self;
    }

    pub fn body(self: *const Self) *const fn (void) void {
        var mutable_style = Style{};
        if (self._style) |style_ptr| {
            mutable_style = style_ptr.*;
        }
        if (mutable_style.position == null) mutable_style.position = self._pos;
        if (mutable_style.visual == null) mutable_style.visual = .{
            .font_size = self._font_size,
            .font_weight = self._font_weight,
            .text_color = self._text_color,
            .background = self._background,
            .border = self._border,
            .border_radius = self._border_radius,
            .text_decoration = self._text_decoration,
        };
        if (mutable_style.interactive == null) mutable_style.interactive = self._interactive;
        if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
        if (mutable_style.padding == null) mutable_style.padding = self._padding;
        if (mutable_style.layout == null) mutable_style.layout = self._layout;
        if (mutable_style.margin == null) mutable_style.margin = self._margin;
        if (mutable_style.size == null) mutable_style.size = self._size;
        if (mutable_style.transition == null) mutable_style.transition = self._transition;
        if (mutable_style.blur == null) mutable_style.blur = self._blur;

        // if (self._tooltip) |_tooltip| {
        //     elem_decl.tooltip = &_tooltip;
        // }

        if (self._flex_type == .Center) {
            mutable_style.layout = .center;
        } else if (self._flex_type == .Stack) {
            mutable_style.direction = .column;
        }

        if (self._id) |_id| {
            mutable_style.id = _id;
        }

        const elem_decl = Vapor.ElementDecl{
            .state_type = .static,
            ._elem_type = self._elem_type,
            ._text = self._text,
            .style = &mutable_style,
            ._href = self._href,
            .svg = self._svg,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
        };

        if (self._elem_type != .CtxButton) {
            const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
            if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                if (self._options.?.on_press) |on_press| {
                    Vapor.btn_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }
        } else if (self._elem_type == .CtxButton) {
            const ui_node = self._ui_node orelse unreachable;
            if (elem_decl.style.?.style_id) |element_id| {
                const kv = Vapor.ctx_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                Vapor.ctx_registry.put(hashKey(element_id), kv.value) catch |err| {
                    println("Button Function Registry {any}\n", .{err});
                    unreachable;
                };
            }
        }

        Vapor.LifeCycle.configure(elem_decl);
        return Vapor.LifeCycle.close;
    }

    pub fn plain(self: *const Self) void {
        const elem_decl = Vapor.ElementDecl{
            ._state_type = self._state_type,
            ._elem_type = self._elem_type,
            ._text = self._text,
        };
        _ = Vapor.LifeCycle.open(elem_decl);
        Vapor.LifeCycle.configure(elem_decl);
        Vapor.LifeCycle.close({});
    }
};
