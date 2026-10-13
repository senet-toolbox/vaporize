pub fn Builder(comptime state_type: types.StateType) type {
    return struct {
        const Self = @This();
        const _state_type: types.StateType = state_type;

        _input: ?Input = null,
        _level: ?u8 = null,
        _video: ?*const types.Video = null,
        _font_family: []const u8 = "",
        _value: ?*anyopaque = null,

        _elem_type: Vapor.ElementType,
        _flex_type: FlexType = .Flex,
        _text: ?[]const u8 = null,
        _href: ?[]const u8 = null,
        _svg: []const u8 = "",
        _aria_label: ?[]const u8 = null,
        _options: ?ButtonOptions = null,
        _ui_node: ?*UINode = null,
        _id: ?[]const u8 = null,
        _style: ?*const Vapor.Style = null,
        _draggable: ?*Draggable = null,
        _element: ?*Element = null,

        _animation_enter: ?*const Vapor.Animation = null,
        _animation_exit: ?*const Vapor.Animation = null,

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

        pub fn Button(options: ButtonOptions) Self {
            const elem_decl = ElementDecl{
                .elem_type = .Button,
                .aria_label = options.aria_label,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .Button,
                ._aria_label = options.aria_label,
                ._options = options,
                ._ui_node = ui_node,
            };
        }

        pub fn SubmitButton() Self {
            const elem_decl = ElementDecl{
                .elem_type = .SubmitButton,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._elem_type = .SubmitButton,
                ._ui_node = ui_node,
            };
        }

        pub fn CtxButton(func: anytype, args: anytype) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .CtxButton,
            };

            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("LifeCycle open could not allocate {any}\n", .{error.CouldNotAllocate}, @src());
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
                fn deinitFn(_: *Vapor.Node) void {
                    // _ = @alignCast(@fieldParentPtr("run_node", node));
                    // Vapor.allocator_global.destroy(closure);
                }
            };

            const closure = Vapor.arena(.frame).create(Closure) catch |err| {
                println("Error could not create closure {any}\n ", .{err});
                unreachable;
            };
            closure.* = .{
                .arguments = args,
            };

            Vapor.ctx_callback_registry.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
                println("Button Function Registry {any}\n", .{err});
                unreachable;
            };

            return Self{ ._elem_type = .CtxButton, ._ui_node = ui_node };
        }

        pub fn ariaLabel(self: *const Self, label: []const u8) Self {
            var new_self: Self = self.*;
            new_self._aria_label = label;
            return new_self;
        }

        pub fn Box() Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .FlexBox };
            const ui_node = createNode(elem_decl);
            return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox };
        }

        pub fn Form(submit: anytype, args: anytype) Self {
            const elem_decl = ElementDecl{ .state_type = _state_type, .elem_type = .Form };
            const ui_node = createNode(elem_decl);

            // If we have a binded value we instead create a wrapper ctx around the cb passed in
            // this way we can update the binded values from the callback and call the developer's
            // cb with the updated value
            Vapor.attachEventCtxCallback(ui_node, .submit, submit, args) catch |err| {
                Vapor.println("ONSUBMIT: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return Self{ ._ui_node = ui_node, ._elem_type = .Form };
        }

        pub fn Section() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Intersection,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .Intersection,
            };
        }

        pub fn List() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .List,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .List,
            };
        }

        pub fn ListItem() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .ListItem,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .ListItem,
            };
        }

        pub fn Center() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .FlexBox,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .FlexBox,
                ._flex_type = .Center,
            };
        }
        pub fn Stack() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .FlexBox,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .FlexBox,
                ._flex_type = .Stack,
            };
        }
        pub fn Link(options: LinkOptions) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Link,
                .href = options.url,
                .aria_label = options.aria_label,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{
                ._ui_node = ui_node,
                ._elem_type = .Link,
                ._aria_label = options.aria_label,
                ._href = options.url,
            };
        }

        pub fn Null() void {
            _ = LifeCycle.open(.{
                .elem_type = .Noop,
                .state_type = _state_type,
            });
            LifeCycle.configure(.{
                .elem_type = .Noop,
                .state_type = _state_type,
            });
            LifeCycle.close({});
        }
        pub fn Heading(level: u8, text: []const u8) Self {
            return Self{ ._elem_type = .Heading, ._text = text, ._level = level };
        }

        pub fn Video(options: *const types.Video) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                ._elem_type = .Video,
            };
            const ui_node = Vapor.current_ctx.open(elem_decl) catch |err| {
                println("{any}\n", .{err});
                unreachable;
            };
            return Self{
                ._elem_type = .Video,
                ._video = options,
                ._ui_node = ui_node,
            };
        }

        pub fn TextFmt(comptime fmt: []const u8, args: anytype) Self {
            const allocator = Vapor.arena(.frame);
            const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
                Vapor.printlnColor(
                    \\Error formatting text: {any}\n"
                    \\FMT: {s}\n"
                    \\ARGS: {any}\n"
                , .{ err, fmt, args }, .hex("#FF3029"));
                return Self{ ._elem_type = .Text, ._text = "ERROR" };
            };
            Vapor.frame_arena.addBytesUsed(text.len);

            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .Text,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            return Self{ ._elem_type = .TextFmt, ._text = text, ._ui_node = ui_node };
        }

        pub fn bind(self: *const Self, value: anytype) Self {
            var new_self: Self = self.*;
            if (self._elem_type != .TextField) {
                Vapor.printlnErr("bindValue only works on TextField", .{});
                return self.*;
            }
            if (@typeInfo(@TypeOf(value)) != .pointer) {
                Vapor.printlnErr("bindValue only works on pointer types", .{});
                return self.*;
            }

            const ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
                unreachable;
            };

            switch (self._text_field_type) {
                .string => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                    Vapor.attachEventCtxCallback(ui_node, .input, struct {
                        pub fn updateText(value_opaque: *anyopaque, evt: *Vapor.Event) void {
                            const value_type: *[]const u8 = @ptrCast(@alignCast(value_opaque));
                            value_type.* = evt.text();
                            Vapor.print("No onChange updateText: {s}\n", .{value_type.*});
                        }
                    }.updateText, value) catch |err| {
                        Vapor.println("bindValue: Could not attach event callback {any}\n", .{err});
                        unreachable;
                    };
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
            if (self._value) |value| {
                switch (self._text_field_type) {
                    .string => {
                        Vapor.attachEventCtxCallback(ui_node, .input, struct {
                            pub fn updateText(value_opaque: *anyopaque, evt: *Vapor.Event) void {
                                const value_type: *[]const u8 = @ptrCast(@alignCast(value_opaque));
                                value_type.* = evt.text();
                                Vapor.print("updateText: {s}\n", .{value_type.*});
                                @call(.auto, cb, .{evt});
                            }
                        }.updateText, value) catch |err| {
                            Vapor.println("bindValue: Could not attach event callback {any}\n", .{err});
                            unreachable;
                        };
                    },
                    else => return self.*,
                }
            } else {
                Vapor.attachEventCallback(ui_node, .input, cb) catch |err| {
                    Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                    unreachable;
                };
            }

            return new_self;
        }

        /// Graphic takes a url to a svg file, during client side rendering it will be fetched and inlined
        /// Graphic(.{ .src = "https://example.com/image.svg" }).style(...);
        /// # Parameters:
        /// - `src`: []const u8,
        ///
        /// # Returns:
        /// Self: Component
        pub fn Graphic(options: struct { src: []const u8 }) Self {
            return Self{ ._elem_type = .Graphic, ._href = options.src };
        }

        pub fn Icon(token: *const IconTokens) Self {
            return Self{ ._elem_type = .Icon, ._href = token.web orelse "" };
        }

        pub fn Svg(options: struct { svg: []const u8 }) Self {
            if (options.svg.len > 2048 and Vapor.build_options.enable_debug) {
                Vapor.printlnErr("Svg is too large inlining: {d}B, use Graphic;\nSVG Content:\n{s}...", .{ options.svg.len, options.svg[0..100] });
                if (!Vapor.isWasi) {
                    @panic("Svg is too large, crashing!");
                } else return Self{ ._elem_type = .Svg, ._svg = "" };
            }
            return Self{ ._elem_type = .Svg, ._svg = if (options.svg.len < 128) options.svg else "" };
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

        pub fn onDragStart(self: *const Self, cb: fn (*Vapor.Event) void) Self {
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
            Vapor.attachEventCallback(ui_node, .pointerdown, cb) catch |err| {
                Vapor.println("ONDRAGSTART: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn createDraggable(self: *const Self, draggable_ptr: *Draggable) *const Self {
            var new_self: Self = self.*;
            var element = draggable_ptr.element;

            var ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
                unreachable;
            };

            ui_node.hooks.created_id = 1;
            element.element_type = self._elem_type;
            element._node_ptr = ui_node;
            new_self._element = &element;
            draggable_ptr.element = element;

            onCreateNode(ui_node, struct {
                pub fn attachDraggable(draggable: *Draggable) void {
                    draggable.addStartListener();
                }
            }.attachDraggable, .{draggable_ptr});
            return self;
        }

        pub fn RedirectLink(options: LinkOptions) Self {
            return Self{
                ._elem_type = .RedirectLink,
                ._href = options.url,
                // ._href = if (Vapor.isGenerated) "" else options.url,
                ._aria_label = options.aria_label,
            };
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

        pub fn tooltip(self: *const Self, tool_tip: *const Tooltip) Self {
            var new_self: Self = self.*;
            var tooltip_style: Vapor.Style = .{
                .layout = .center,
                .position = .{ .type = .absolute },
                .padding = .tblr(4, 4, 8, 8),
                .visual = .{
                    .opacity = 0,
                    .font_size = 14,
                    .background = tool_tip.background,
                    .text_color = tool_tip.color,
                    .border = tool_tip.border,
                },
                .transition = .{ .duration = tool_tip.delay, .properties = &.{.opacity} },
                .white_space = .nowrap,
            };

            switch (tool_tip.position) {
                .top => {
                    tooltip_style.position.?.bottom = .percent(100);
                    tooltip_style.margin = .b(8);
                    switch (tool_tip.layout) {
                        .center => {
                            tooltip_style.position.?.left = .percent(50);
                            tooltip_style.visual.?.transform = .left_percent(-50); // Centers the tooltip horizontally
                        },
                        .start => {},
                        .end => {},
                    }
                },
                .bottom => {
                    tooltip_style.position.?.top = .percent(125);
                },
                .left => {
                    tooltip_style.position.?.right = .percent(100);
                    tooltip_style.margin = .r(8);
                    switch (tool_tip.layout) {
                        .center => {
                            tooltip_style.position.?.top = .percent(50);
                            tooltip_style.visual.?.transform = .top_percent(-50); // Centers the tooltip horizontally
                        },
                        .start => {},
                        .end => {},
                    }
                },
                .right => {
                    tooltip_style.position.?.left = .percent(100);
                    tooltip_style.margin = .l(8);
                    switch (tool_tip.layout) {
                        .center => {
                            tooltip_style.position.?.top = .percent(50);
                            tooltip_style.visual.?.transform = .top_percent(-50); // Centers the tooltip horizontally
                        },
                        .start => {},
                        .end => {},
                    }
                },
            }

            new_self._tooltip = types.Tooltip{
                .text = tool_tip.text,
                .style = tooltip_style,
            };
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
        pub fn style(self: *const Self, style_ptr: *const Vapor.Style) *const fn (void) void {
            var elem_decl = Vapor.ElementDecl{
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
                .style = style_ptr,
                .href = self._href,
                .svg = self._svg,
                .aria_label = self._aria_label,
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

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._options.?.on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                const ui_node = self._ui_node orelse unreachable;
                if (style_ptr.id) |element_id| {
                    const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                    Vapor.ctx_callback_registry.put(hashKey(element_id), kv.value) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                        unreachable;
                    };
                }
            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._options.?.on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            Vapor.LifeCycle.configure(elem_decl);
            return Vapor.LifeCycle.close;
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

        pub fn gradient(self: *const Self, value: types.Background) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.background = value;
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

        pub fn hoverText(self: *const Self, color: Color) Self {
            var new_self: Self = self.*;
            new_self._interactive = .hover_text(color);
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
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
                .style = &mutable_style,
                .href = self._href,
                .svg = self._svg,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
            };

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._options.?.on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                const ui_node = self._ui_node orelse unreachable;
                if (elem_decl.style.?.style_id) |element_id| {
                    const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                    Vapor.ctx_callback_registry.put(hashKey(element_id), kv.value) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                        unreachable;
                    };
                }
            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._options.?.on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            Vapor.LifeCycle.configure(elem_decl);
            return Vapor.LifeCycle.close({});
        }

        pub fn children(self: *const Self, _: void) void {
            var mutable_style = Style{};
            if (self._style) |style_ptr| {
                mutable_style = style_ptr.*;
            }
            if (mutable_style.position == null) mutable_style.position = self._pos;
            if (mutable_style.visual != null and self._visual != null) {
                var visual = mutable_style.visual.?;
                const _visual = self._visual.?;

                if (_visual.background != null) visual.background = _visual.background;
                if (_visual.fill != null) visual.fill = _visual.fill;
                if (_visual.stroke != null) visual.stroke = _visual.stroke;
                if (_visual.border != null) visual.border = _visual.border;
                if (_visual.border_radius != null) visual.border_radius = _visual.border_radius;
                if (_visual.border_thickness != null) visual.border_thickness = _visual.border_thickness;
                if (_visual.border_color != null) visual.border_color = _visual.border_color;
                if (_visual.text_color != null) visual.text_color = _visual.text_color;
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.font_weight != null) visual.font_weight = _visual.font_weight;
                if (_visual.letter_spacing != null) visual.letter_spacing = _visual.letter_spacing;
                if (_visual.line_height != null) visual.line_height = _visual.line_height;
                if (_visual.font_size != null) visual.font_size = _visual.font_size;
                if (_visual.opacity != null) visual.opacity = _visual.opacity;
                if (_visual.ellipsis != null) visual.ellipsis = _visual.ellipsis;
                if (_visual.shadow != null) visual.shadow = _visual.shadow;
                if (_visual.cursor != null) visual.cursor = _visual.cursor;
                mutable_style.visual = visual;
            } else mutable_style.visual = self._visual;

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
                .state_type = _state_type,
                .elem_type = self._elem_type,
                .text = self._text,
                .style = &mutable_style,
                .href = self._href,
                .svg = self._svg,
                .aria_label = self._aria_label,
                .animation_enter = self._animation_enter,
                .animation_exit = self._animation_exit,
            };

            if (self._ui_node == null) {
                const ui_node = Vapor.LifeCycle.open(elem_decl) orelse unreachable;
                if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                    if (self._options.?.on_press) |on_press| {
                        Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                            println("Button Function Registry {any}\n", .{err});
                        };
                    }
                }
            } else if (self._elem_type == .CtxButton) {
                const ui_node = self._ui_node orelse unreachable;
                if (elem_decl.style.?.style_id) |element_id| {
                    const kv = Vapor.ctx_callback_registry.fetchRemove(hashKey(ui_node.uuid)) orelse unreachable;
                    Vapor.ctx_callback_registry.put(hashKey(element_id), kv.value) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                        unreachable;
                    };
                }
            } else if (self._elem_type == .Button or self._elem_type == .ButtonCycle) {
                const ui_node = self._ui_node orelse unreachable;
                if (self._options.?.on_press) |on_press| {
                    Vapor.callback_registry.put(hashKey(ui_node.uuid), on_press) catch |err| {
                        println("Button Function Registry {any}\n", .{err});
                    };
                }
            }

            Vapor.println("UUID {s}", .{self._ui_node.?.uuid});
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


