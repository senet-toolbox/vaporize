const std = @import("std");
const types = @import("types.zig");
const Vapor = @import("Vapor.zig");
const LifeCycle = Vapor.LifeCycle;
const println = Vapor.println;
const Element = @import("Element.zig").Element;

const Style = types.Style;
const InputDetails = types.InputDetails;
const InputParams = types.InputParams;
const ElementDecl = types.ElementDeclaration;

const CenterOptions = struct {
    element: *Element,
    style: ?*const Style = null,
};

pub inline fn Center(options: CenterOptions) fn (void) void {

    // Create a mutable copy of the style struct
    var mutable_style = options.style.*;

    // Now you can safely modify the local, mutable copy
    mutable_style.child_alignment.x = .center;
    mutable_style.child_alignment.y = .center;

    const elem_decl = ElementDecl{
        .style = &mutable_style, // Pass the mutable pointer to ElementDecl
        .dynamic = .static,
        .elem_type = .FlexBox,
    };
    const ui_node = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    options.element._node_ptr = ui_node;
    return LifeCycle.close;
}

const ListOptions = struct {
    element: *Element,
    style: ?*const Style = null,
};

pub inline fn List(options: ListOptions) fn (void) void {
    const elem_decl = ElementDecl{
        .style = options.style,
        .dynamic = .static,
        .elem_type = .List,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse unreachable;
    _ = LifeCycle.configure(elem_decl);
    options.element._node_ptr = ui_node;
    return LifeCycle.close;
}

const BoxOptions = struct {
    element: *Element,
    style: ?*const Style = null,
};

pub inline fn Box(options: BoxOptions) fn (void) void {
    const elem_decl = ElementDecl{
        .style = options.style,
        .dynamic = .dynamic,
        .elem_type = .FlexBox,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse unreachable;
    _ = LifeCycle.configure(elem_decl);
    options.element._node_ptr = ui_node;
    return LifeCycle.close;
}

pub inline fn FlexBox(element: *Element, style: Style) fn (void) void {
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

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .FlexBox,
    };
    const ui_node = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    _ = local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    return local.CloseElement;
}

pub inline fn JsonEditor(element: *Element, text: []const u8, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Vapor.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Vapor.current_ctx.configure(elem_decl);
        }
    };

    var elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .JsonEditor,
        .text = text,
    };
    elem_decl.style.id = element.id.?;

    const ui_node = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    local.CloseElement();
    return;
}

pub inline fn InputV2(element: *Element, params: InputParams, style: Style) void {
    const local = struct {
        fn CloseElement() void {
            _ = Vapor.current_ctx.close();
            return;
        }
        fn ConfigureElement(elem_decl: ElementDecl) void {
            _ = Vapor.current_ctx.configure(elem_decl);
        }
    };

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .Input,
        .input_params = params,
    };

    const ui_node = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    element.element_type = elem_decl.elem_type;

    // if (params == .string) {
    //     if (params.string.onInput) |func| {
    //         const id = Vapor.events_callbacks.count();
    //         Vapor.events_callbacks.put(id, func) catch |err| {
    //             println("Event Callback Error: {any}\n", .{err});
    //         };
    //     }
    // }

    local.CloseElement();
    return;
}

const InputOptions = struct {
    element: *Element,
    params: *const InputParams,
    style: ?*const Style = null,
};

pub inline fn Input(options: InputOptions) void {
    const elem_decl = ElementDecl{
        .style = options.style,
        .dynamic = .dynamic,
        .elem_type = .Input,
        .input_params = options.params,
    };
    options.element.element_type = .Input;

    const ui_node = LifeCycle.open(elem_decl) orelse unreachable;
    _ = LifeCycle.configure(elem_decl);
    options.element._node_ptr = ui_node;
    LifeCycle.close({});
    return;
}

pub inline fn Dialog(element: *Element, style: Style) fn (void) void {
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

    const elem_decl = ElementDecl{
        .style = style,
        .dynamic = .dynamic,
        .elem_type = .Dialog,
    };

    const ui_node = Vapor.current_ctx.open(elem_decl) catch |err| {
        println("{any}\n", .{err});
        unreachable;
    };
    _ = local.ConfigureElement(elem_decl);
    element._node_ptr = ui_node;
    element.element_type = .Dialog;
    return local.CloseElement;
}
