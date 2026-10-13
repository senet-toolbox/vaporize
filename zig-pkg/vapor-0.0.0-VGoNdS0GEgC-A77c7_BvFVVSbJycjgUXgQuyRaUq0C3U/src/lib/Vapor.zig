const std = @import("std");
const builtin = @import("builtin");
pub const isWasi = builtin.target.cpu.arch == .wasm32;
pub const debug = builtin.mode == .Debug;
// We cant use bools since they get recompiled each time, hence we use the builtin target
pub var isGenerated = !isWasi;
const types = @import("types.zig");
const UIContext = @import("UITree.zig");
const PureTree = @import("PureTree.zig");
const UINode = @import("UITree.zig").UINode;
const CommandsTree = UIContext.CommandsTree;
const Rune = @import("Rune.zig");
const GrainStruct = @import("Grain.zig");
const TransitionState = @import("Transition.zig").TransitionState;
const Router = @import("Router.zig");
pub const Element = @import("Element.zig").Element;
const KeyGenerator = @import("Key.zig").KeyGenerator;
const Reconciler = @import("Reconciler.zig");
const TrackingAllocator = @import("TrackingAllocator.zig");
pub const KeyStone = @import("keystone/KeyStone.zig");
pub const Wasm = @import("wasm");
const getVisualStyle = @import("convertStyleCustomWriter.zig").getVisualStyle;
pub const Bridge = @import("Bridge.zig");
pub const Event = @import("Event.zig");
const Canopy = @import("Canopy.zig");
const CSSGenerator = @import("CSSGenerator.zig");
const hashKey = utils.hashKey;
const Pool = @import("Pool.zig");
const mutateDomElementStyleString = @import("Element.zig").mutateDomElementStyleString;
const Static = @import("Static.zig");
const HtmlGenerator = @import("HtmlGenerator.zig");
const mode_options = @import("build_options");
const Packer = @import("Packer.zig");

const DebugLevel = enum(u8) { all = 0, debug = 1, info = 2, warn = 3, none = 4 };

pub var build_options = struct {
    enable_debug: bool = debug,
    debug_level: DebugLevel = .none,
}{};

pub var Timer = struct {
    generation_time: f64 = 0,
    reconcile_time: f64 = 0,
    commit_time: f64 = 0,
    total_time: f64 = 0,
}{};
// const getFocusStyle = @import("convertFocus.zig").getFocusStyle;
// const getFocusWithinStyle = @import("convertFocusWithin.zig").getFocusWithinStyle;
const Chain = @import("Static.zig").Chain;
const ChainPure = @import("Pure.zig").Chain;
const AllocText = ChainPure.AllocText;
const getStyle = @import("convertStyleCustomWriter.zig").getStyle;
const StyleCompiler = @import("convertStyleCustomWriter.zig");
pub const generateStyle = @import("convertStyleCustomWriter.zig").generateStyle;
const generateInputHTML = @import("grabInputDetails.zig").generateInputHTML;
const grabInputDetails = @import("grabInputDetails.zig");
const utils = @import("utils.zig");
// const createInput = grabInputDetails.createInput;
const getInputSize = grabInputDetails.getInputSize;
const getInputType = grabInputDetails.getInputType;
const getAriaLabel = utils.getAriaLabel;
pub const setGlobalStyleVariables = @import("convertStyleCustomWriter.zig").setGlobalStyleVariables;
pub const ThemeType = @import("convertStyleCustomWriter.zig").ThemeType;
const Theme = @import("theme");
const Debugger = @import("Debugger.zig");
const NodePool = @import("NodePool.zig");

pub const Component = fn (void) void;

pub const on_change_hash = "onChange";
pub const on_leave_hash = "onLeave";
pub const on_hover_hash = "onHover";
pub const on_submit_hash = "onSubmit";
pub const on_focus_hash = "onFocus";
pub const on_blur_hash = "onBlur";

const EventType = types.EventType;
const Active = types.Active;
pub const ElementDecl = types.ElementDeclaration;
const RenderCommand = types.RenderCommand;
pub const ElementType = types.ElementType;
const Hover = types.Hover;
const Focus = types.Focus;
pub var has_context: bool = false;
pub var current_ctx: *UIContext = undefined;
pub var pure_tree: PureTree = undefined;
pub var error_tree: PureTree = undefined;
pub var ctx_map: std.AutoHashMap(u32, *UIContext) = undefined;
pub var page_map: std.StringHashMap(void) = undefined;
const LayoutItem = struct {
    reset: bool = false,
    call_fn: *const fn (*const fn () void) void,
};
pub var layout_map: std.AutoHashMap(u32, LayoutItem) = undefined;
pub var page_deinit_map: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var global_rerender: bool = false;
pub var has_dirty: bool = false;
pub var rerender_everything: bool = false;
pub var grain_rerender: bool = false;
pub var grain_element_uuid: []const u8 = "";
pub var current_depth_node_id: []const u8 = "";
pub var router: Router = undefined;

pub var element_registry: std.AutoHashMap(u32, *Element) = undefined;
pub var response_registry: std.AutoHashMap(u32, Kit.Response) = undefined;

var serious_error: bool = false;

const Vapor = @This();
pub const Kit = @import("kit/Kit.zig");
// pub const Chart = @import("components/charts/Chart.zig");
pub const Style = types.Style;
pub const Signal = Rune.Signal;
pub const Grain = GrainStruct.Grain;
pub const Types = types;
pub const DateTime = @import("DateTime.zig");
pub const Animation = @import("Animation.zig");
pub const Transition = @import("Transition.zig");
// pub const Error = @import("routes/nightwatch/Error.zig");

pub fn clearPersitantStorage() void {
    if (isWasi) {
        Wasm.clearLocalStorageWasm();
    } else {}
}

pub fn getWindowPath() []const u8 {
    if (isWasi) {
        return std.mem.span(Wasm.getWindowInformationWasm());
    } else {
        return "";
    }
}

pub fn store(key: []const u8, value: anytype) void {
    if (!isWasi) return;
    switch (@typeInfo(@TypeOf(value))) {
        .int, .float => Wasm.setLocalStorageNumberWasm(key.ptr, key.len, value),
        .pointer => |ptr| {
            switch (ptr.size) {
                .slice => {
                    Wasm.setLocalStorageStringWasm(key.ptr, key.len, value.ptr, value.len);
                },
                else => {
                    Wasm.setLocalStorageStringWasm(key.ptr, key.len, value.ptr, value.len);
                },
            }
        },
        else => {
            Vapor.printlnErr("Cannot store non string or int float types TYPE: {any}", .{@TypeOf(value)});
        },
    }
}

pub const EventHandler = struct {
    type: EventType,
    ctx_aware: bool = false,
    cb_opaque: *const anyopaque,
};

pub const EventHandlers = struct { handlers: std.ArrayListUnmanaged(EventHandler) };

pub const Action = struct {
    dynamic_object: ?*DynamicObject = null,
    runFn: ActionProto,
    deinitFn: NodeProto,
};

pub const Node = struct { data: Action };

pub const ActionProto = *const fn (*Action) void;
pub const NodeProto = *const fn (*Node) void;

pub fn ArgsTuple(comptime Fn: type) type {
    const out = std.meta.ArgsTuple(Fn);
    return if (std.meta.fields(out).len == 0) @TypeOf(.{}) else out;
}

pub var callback_registry: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var ctx_callback_registry: std.AutoHashMap(u32, *Node) = undefined;

pub var fetch_registry: std.AutoHashMap(u32, *Kit.FetchNode) = undefined;
pub const EventNode = struct { cb: *const fn (*Event) void, ui_node: ?*UINode = null, evt_type: EventType };
pub var events_callbacks: std.AutoHashMap(u32, EventNode) = undefined;
pub var nodes_with_events: std.AutoHashMap(u32, *UINode) = undefined;
pub var node_events_callbacks: std.AutoHashMap(u32, *CtxAwareEventNode) = undefined;
pub var events_inst_callbacks: std.AutoHashMap(u32, *EvtInstNode) = undefined;
pub var hooks_inst_callbacks: std.AutoHashMap(u32, *const fn (HookContext) void) = undefined;
pub var mounted_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var on_end_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var on_end_ctx_funcs: std.array_list.Managed(*Node) = undefined;
pub var on_commit_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var mounted_ctx_funcs: std.AutoHashMap(u32, *Node) = undefined;
pub var created_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var updated_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var destroy_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;
const RemovedNode = struct { uuid: []const u8, index: usize };
pub const ObserverNode = union(enum) {
    type: ElementType,
    uuid: []const u8,
};
pub var removed_nodes: std.array_list.Managed(RemovedNode) = undefined;
pub var observer_nodes: std.StringHashMap(std.array_list.Managed(ObserverNode)) = undefined;
pub var added_nodes: std.array_list.Managed(RenderCommand) = undefined;
pub var dirty_nodes: std.array_list.Managed(RenderCommand) = undefined;
// Potential nodes is an set to chekc if the potential nodes that are either shifted or removed on in the dom currently
// instead of an active set, we only record the nodes that are different from the current tree
// pub var potential_nodes: std.StringHashMap(void) = undefined;
const Class = struct {
    element_id: []const u8,
    style_id: []const u8,
};
pub var component_subscribers: std.array_list.Managed(*Rune.ComponentNode) = undefined;
// pub var grain_subs: std.array_list.Managed(*GrainStruct.ComponentNode) = undefined;
pub var animations: std.StringHashMap(Animation) = undefined;
// Define a type for continuation functions
var callback_count: u32 = 0;
const ContinuationFn = *const fn () void;

// Global array to store continuations

pub var allocator_global: std.mem.Allocator = undefined;
pub var browser_width: f32 = 0;
pub var browser_height: f32 = 0;
pub var page_node_count: u32 = 256;
const FrameAllocator = @import("FrameAllocator.zig");
pub var frame_arena: FrameAllocator = undefined;

pub fn getFrameAllocator() std.mem.Allocator {
    return arena(.frame);
}

const ArenaType = enum {
    frame,
    view,
    persist,
    scratch,
    request,
};

pub fn arena(arena_type: ArenaType) std.mem.Allocator {
    return switch (arena_type) {
        .frame => frame_arena.frameAllocator(),
        .view => frame_arena.viewAllocator(),
        .persist => frame_arena.persistentAllocator(),
        .request => frame_arena.requestAllocator(),
        .scratch => {
            Vapor.printlnSrcErr("Scratch is yet to be implemented", .{}, @src());
            unreachable;
        },
    };
}

pub fn array(comptime T: type, arena_type: ArenaType) Array(T) {
    var array_list: std.array_list.Managed(T) = undefined;
    const allocator = arena(arena_type);
    array_list = std.array_list.Managed(T).init(allocator);
    return array_list;
}

pub const Array = std.array_list.Managed;

pub const VaporConfig = struct {
    // screen_width: f32,
    // screen_height: f32,
    page_node_count: u32 = 256,
    mode: Mode = .retained,
};

const Mode = enum {
    immediate,
    atomic,
    retained,
    static,
};

pub var pool: Pool = undefined;
pub var mode: Mode = .static;
pub fn init(config: VaporConfig) void {
    switch (builtin.target.cpu.arch) {
        .wasm32 => {
            allocator_global = std.heap.wasm_allocator;
        },
        else => {
            allocator_global = std.heap.c_allocator;
        },
    }
    if (isWasi) {
        browser_width = Wasm.windowWidth();
        browser_height = Wasm.windowHeight();
    }
    page_node_count = config.page_node_count;
    mode = config.mode;

    // Init the frame allocator;
    // This adds 500B
    frame_arena = FrameAllocator.init(allocator_global, page_node_count);
    // The persistent allocator is used for the Initialization of the registries as these persist over the lifetime of the program.
    var allocator = frame_arena.persistentAllocator();

    // Init Router // This adds 1kb
    router.init(&allocator) catch |err| {
        println("Could not init Router {any}\n", .{err});
    };

    // >1kb
    Packer.init(allocator);
    // initPackedData(allocator);
    // initPools(allocator);
    // 20kb
    initRegistries(allocator);
    // >1kb
    initCalls(allocator);
    // >1kb
    initContextData(allocator);
    UIContext.class_map = std.StringHashMap(Pool.StringData).init(allocator);

    // UIContext.ui_nodes = allocator.alloc(UINode, config.page_node_count) catch unreachable;

    // Init string pool adds 1kb
    pool = Pool.init(allocator, page_node_count) catch |err| {
        printlnErr("Could not init Pool {any}\n", .{err});
        unreachable;
    };
    pool.initFreelist();
    KeyGenerator.initWriter();
    // UIContext.debugPrintUINodeLayout();

    // All this below adds 3kb
    animations = std.StringHashMap(Animation).init(allocator);
    component_subscribers = std.array_list.Managed(*Rune.ComponentNode).init(allocator);
    removed_nodes = std.array_list.Managed(RemovedNode).init(allocator);
    observer_nodes = std.StringHashMap(std.array_list.Managed(ObserverNode)).init(allocator);
    added_nodes = std.array_list.Managed(RenderCommand).init(allocator);
    dirty_nodes = std.array_list.Managed(RenderCommand).init(allocator);
    // potential_nodes = std.StringHashMap(void).init(allocator);
    // grain_subs = std.array_list.Managed(*GrainStruct.ComponentNode).init(allocator);
    element_registry = std.AutoHashMap(u32, *Element).init(allocator);

    // Init Context Data
    // Reconciler.node_map = std.StringHashMap(usize).init(allocator);

    // Reconciliation styles dedupe // this is 2kb
    // UIContext.nodes = allocator.alloc(*UINode, config.page_node_count) catch unreachable;

    UIContext.indexes = std.AutoHashMap(u32, usize).init(allocator);

    // this adds 7kb
    // _ = getStyle(null); // 16kb
    // _ = getVisualStyle(null, 0); // 20kb
    _ = getAriaLabel(null); // < 1kb
    // _ = getFocusStyle(null); // 20kb
    // _ = getFocusWithinStyle(null); // 20kb
    // this adds 4kb
    // _ = createInput(null); // 20kb
    // _ = getInputType(null); // 5kb
    // _ = getInputSize(null); // 5kb

    if (build_options.enable_debug) {
        printlnColor("-----------Debug Mode----------", .{}, .hex("#F6820C"));
    }
    // printDebug() catch unreachable;
}

export fn renderUI(route: [*:0]u8) void {
    Vapor.renderCycle(route);
}

fn initRegistries(persistent_allocator: std.mem.Allocator) void {
    callback_registry = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    ctx_callback_registry = std.AutoHashMap(u32, *Node).init(persistent_allocator);
    fetch_registry = std.AutoHashMap(u32, *Kit.FetchNode).init(persistent_allocator);
    // response_registry = std.AutoHashMap(u32, Kit.Response).init(persistent_allocator);
}

fn initCalls(persistent_allocator: std.mem.Allocator) void {
    events_callbacks = std.AutoHashMap(u32, EventNode).init(persistent_allocator);
    nodes_with_events = std.AutoHashMap(u32, *UINode).init(persistent_allocator);
    node_events_callbacks = std.AutoHashMap(u32, *CtxAwareEventNode).init(persistent_allocator);
    events_inst_callbacks = std.AutoHashMap(u32, *EvtInstNode).init(persistent_allocator);
    hooks_inst_callbacks = std.AutoHashMap(u32, *const fn (HookContext) void).init(persistent_allocator);
    mounted_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    on_end_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    on_end_ctx_funcs = std.array_list.Managed(*Node).init(persistent_allocator);
    on_commit_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    mounted_ctx_funcs = std.AutoHashMap(u32, *Node).init(persistent_allocator);
    destroy_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    updated_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    created_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
}

fn initContextData(persistent_allocator: std.mem.Allocator) void {
    ctx_map = std.AutoHashMap(u32, *UIContext).init(persistent_allocator);
    page_map = std.StringHashMap(void).init(persistent_allocator);
    layout_map = std.AutoHashMap(u32, LayoutItem).init(persistent_allocator);
    page_deinit_map = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
}
/// The LifeCycle struct
/// allows control over ui node in the tree
/// exposes open, configure, and close, must be called in this order to attach the node to the tree
pub const LifeCycle = struct {
    /// open takes an element decl and return a *UINode
    /// this opens the element to allow for children
    /// within the dom tree, node this current opened node is the current top stack node, ie any children
    /// will reference this node as their parent
    pub fn open(elem_decl: ElementDecl) ?*UINode {
        const ui_node = current_ctx.open(elem_decl) catch |err| {
            println("{any}\n", .{err});
            return null;
        };
        return ui_node;
    }
    /// close, closes the current UINode
    pub fn close(_: void) void {
        _ = current_ctx.close();
        return;
    }
    /// configure is used internally to configure the UINode, used for adding text props, or hover props ect
    /// within configure, we check if the node has a id if so we use that, otherwise later we generate one
    /// we also set various props, such as text, style, is an SVG or not
    /// Any mainpulation of the node after this point is considered undefined behaviour be cautious;
    pub fn configure(elem_decl: ElementDecl) void {
        _ = current_ctx.configure(elem_decl);
    }
};

/// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
/// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn cycle() void {
    if (isWasi) {
        Vapor.global_rerender = true;
        // render_phase = .generating;
        Wasm.requestRerenderWasm();
    }
}

pub fn batch() void {
    if (isWasi) {
        Vapor.global_rerender = true;
        // render_phase = .generating;
        Wasm.requestRerenderWasm();
    }
}

// /// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
// /// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
// /// feel free to abuse force, its essentially a global signal
// pub fn cycleGrain() void {
//     Vapor.grain_rerender = true;
//     Vapor.println("Grain rerender", .{});
//     Wasm.requestRerenderWasm();
// }

/// Force rerender forces the entire dom tree to check props and rerender the entire ui
/// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn forceEverything() void {
    if (isWasi) {
        Vapor.rerender_everything = true;
        Vapor.global_rerender = true;
        Wasm.requestRerenderWasm();
    }
}

/// This function adds the route to the tether radix tree.
/// Deinitializes the tether instance recursively calls routes deinit routes from radix tree
/// # Parameters:
/// - `vapor`: *Vapor,
/// - `path`: []const u8,
/// - `page`: CommandTree
///
/// # Returns:
/// !void.
pub fn addRoute(
    path: []const u8,
    page: *CommandsTree,
) !void {
    try router.addRoute(path, page);
    return;
}

var route_segments: [][]const u8 = undefined;
var deepest_reset_layout: ?LayoutItem = null;
var deepest_reset_layout_path: []const u8 = "";
var target_min_layout_path: []const u8 = "";

fn findResetLayout() void {
    var potential_path: []const u8 = "";
    for (route_segments, 0..) |segment, i| {
        potential_path = std.fmt.allocPrint(allocator_global, "{s}/{s}", .{ potential_path, segment }) catch return;
        const target_layout = layout_map.get(hashKey(potential_path)) orelse continue;
        if (target_layout.reset) {
            deepest_reset_layout = target_layout;
            deepest_reset_layout_path = potential_path;
            route_segments = route_segments[i + 1 ..];
        }
    }
    if (deepest_reset_layout) |_| {
        target_min_layout_path = deepest_reset_layout_path;
    } else {
        target_min_layout_path = current_route;
    }
}

var next_layout_path_to_check: []const u8 = "";
fn callNestedLayouts() void {
    if (route_segments.len == 0) {
        if (deepest_reset_layout) |layout| {
            const layout_fn = layout.call_fn;
            deepest_reset_layout = null;
            deepest_reset_layout_path = "";
            layout_fn(render_page);
        } else {
            // TODO: This is taking a lot of time we need to create a better hashmap system, currently the hashmap compare
            // with the node is long and slow
            // const time = nowMs();
            render_page();
            // Vapor.println("Render time {any}", .{nowMs() - time});
        }
        return;
    }

    // Get the current layout
    next_layout_path_to_check = std.fmt.allocPrint(allocator_global, "{s}/{s}", .{ next_layout_path_to_check, route_segments[0] }) catch return;
    if (layout_map.get(hashKey(next_layout_path_to_check))) |entry| {
        const layout_path = next_layout_path_to_check; // "/root" or "/root/docs"
        const layout_fn = entry.call_fn;
        // We check if the layout path and current path are the same
        // Here we need to check if the layout_path starts with the target_min_layout_path
        // if the target path is /root/docs and the layout_path is /root
        if (std.mem.startsWith(u8, target_min_layout_path, layout_path)) {
            route_segments = route_segments[1..];
            layout_fn(callNestedLayouts);
        }
    } else {
        if (route_segments.len == 0) {
            return;
        }
        // No layout found, continue with remaining segments
        route_segments = route_segments[1..];
        callNestedLayouts();
    }
}

pub var clean_up_ctx: *UIContext = undefined;
var current_route: []const u8 = "";
var previous_route: []const u8 = "";
var render_page: *const fn () void = undefined;
pub var generator: CSSGenerator = undefined;
const RenderPhase = enum {
    generating, // Building VDOM
    committing, // Running commit hooks
    applying, // Applying to real DOM
    idle, // Done
};
// pub var render_phase: RenderPhase = .idle;
var changed_route: bool = false;
pub fn renderCycle(route_ptr: [*:0]u8) void {
    frame_arena.beginFrame(); // For double-buffered approach
    const start = nowMs();
    const route = std.mem.span(route_ptr);

    if (!std.mem.eql(u8, current_route, route)) {
        changed_route = true;
        // We need to start a new route allocator
        // otherwise we are on the same route
        frame_arena.beginView();
    }

    current_route = route;
    removed_nodes.clearRetainingCapacity();
    added_nodes.clearRetainingCapacity();
    dirty_nodes.clearRetainingCapacity();
    // potential_nodes.clearRetainingCapacity();
    node_events_callbacks.clearRetainingCapacity();
    events_callbacks.clearRetainingCapacity();
    nodes_with_events.clearRetainingCapacity();
    UIContext.indexes.clearRetainingCapacity();
    // on_end_funcs.clearRetainingCapacity();

    // var ctx_itr = ctx_callback_registry.iterator();
    // while (ctx_itr.next()) |entry| {
    //     _ = entry.value_ptr.*;
    // }
    // ctx_callback_registry.clearRetainingCapacity();

    // for (mounted_ctx_funcs.items) |node| {
    //     node.data.deinitFn(node);
    // }
    mounted_ctx_funcs.clearRetainingCapacity();

    // Get the old context for current route
    const old_route = router.searchRoute(route) orelse blk: {
        printlnSrcErr("No Route found", .{}, @src());
        break :blk router.searchRoute("/root/error") orelse {
            printlnSrcErr("No Error Route found", .{}, @src());
            return;
        };
    };
    render_page = old_route.page;
    const old_ctx = current_ctx;
    // Create new context
    const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    route_segments = allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        route_segments[count] = route_token;
        count += 1;
    }

    // Init the generator
    generator.init();
    next_layout_path_to_check = "";

    const generation_start = nowMs();
    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms
    Timer.generation_time = nowMs() - generation_start;
    // Debugger.render();

    on_commit_funcs.clearRetainingCapacity();

    const reconcile_start = nowMs();
    Reconciler.reconcile(old_ctx, new_ctx); // 3kb
    Timer.reconcile_time = nowMs() - reconcile_start;
    // We generate the render commands tree
    const commit_start = nowMs();
    endPage(new_ctx);
    Timer.commit_time = nowMs() - commit_start;
    // Vapor.println("Total {d}", .{frame_arena.queryBytesUsed()});
    if (!std.mem.eql(u8, previous_route, current_route)) {
        Vapor.has_dirty = true;
    }

    // Replace old context with new context in the map
    clean_up_ctx = old_ctx;
    Timer.total_time = nowMs() - start;
    changed_route = false;
    // _ = frame_arena.queryNodes();
    if (router.updateRouteTree(old_route.path, new_ctx)) {
        return;
    }

    allocator_global.free(route); // return host‑allocated buffer
    if (build_options.enable_debug and build_options.debug_level == .all) {
        frame_arena.printStats();
    }
    previous_route = current_route;
}

// fn renderErrorPage(_: []const u8) void {
//     // if (mode_options.static_mode) return;
//     frame_arena.beginFrame(); // For double-buffered approach
//     const start = nowMs();
//     const route = "/root/error";
//
//     if (!std.mem.eql(u8, current_route, route)) {
//         changed_route = true;
//         // We need to start a new route allocator
//         // otherwise we are on the same route
//         frame_arena.beginView();
//     }
//
//     current_route = route;
//     removed_nodes.clearRetainingCapacity();
//     added_nodes.clearRetainingCapacity();
//     dirty_nodes.clearRetainingCapacity();
//     // potential_nodes.clearRetainingCapacity();
//     node_events_callbacks.clearRetainingCapacity();
//     events_callbacks.clearRetainingCapacity();
//     nodes_with_events.clearRetainingCapacity();
//     UIContext.indexes.clearRetainingCapacity();
//
//     var ctx_itr = ctx_callback_registry.iterator();
//     while (ctx_itr.next()) |entry| {
//         _ = entry.value_ptr.*;
//     }
//     ctx_callback_registry.clearRetainingCapacity();
//
//     // for (mounted_ctx_funcs.items) |node| {
//     //     node.data.deinitFn(node);
//     // }
//     mounted_ctx_funcs.clearRetainingCapacity();
//
//     // Get the old context for current route
//     const old_route = router.searchRoute(route) orelse {
//         printlnSrcErr("No Route found", .{}, @src());
//         return;
//     };
//     render_page = old_route.page;
//     const old_ctx = current_ctx;
//     // Create new context
//     const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
//         println("Failed to allocate UIContext\n", .{});
//         return;
//     };
//
//     UIContext.initContext(new_ctx) catch |err| {
//         println("Allocator ran out of space {any}\n", .{err});
//         new_ctx.deinit();
//         allocator_global.destroy(new_ctx);
//         return;
//     };
//
//     const old_root = old_ctx.root orelse return;
//     const new_root = new_ctx.root orelse return;
//     new_ctx.root.?.uuid = old_root.uuid;
//
//     current_ctx = new_ctx;
//     var route_itr = std.mem.tokenizeScalar(u8, route, '/');
//     var count: usize = 0;
//     while (route_itr.next()) |_| {
//         count += 1;
//     }
//     route_segments = allocator_global.alloc([]const u8, count) catch return;
//     count = 0;
//     route_itr.reset();
//     while (route_itr.next()) |route_token| {
//         route_segments[count] = route_token;
//         count += 1;
//     }
//
//     // Init the generator
//     generator.init();
//     next_layout_path_to_check = "";
//
//     const generation_start = nowMs();
//     findResetLayout();
//     // This calls the render tree, with render_page as the root function call
//     // First it traverses the layouts calling them in order, and then it calls the render_page
//     callNestedLayouts(); // 4.5ms
//     Timer.generation_time = nowMs() - generation_start;
//     // Debugger.render();
//
//     on_commit_funcs.clearRetainingCapacity();
//
//     const reconcile_start = nowMs();
//     Reconciler.reconcile(old_ctx, new_ctx); // 3kb
//     Timer.reconcile_time = nowMs() - reconcile_start;
//     // We generate the render commands tree
//     const commit_start = nowMs();
//     endPage(new_ctx);
//     Timer.commit_time = nowMs() - commit_start;
//     // Vapor.println("Total {d}", .{frame_arena.queryBytesUsed()});
//     if (!std.mem.eql(u8, previous_route, current_route)) {
//         Vapor.has_dirty = true;
//     }
//
//     // Replace old context with new context in the map
//     clean_up_ctx = old_ctx;
//     Timer.total_time = nowMs() - start;
//     changed_route = false;
//     // _ = frame_arena.queryNodes();
//     if (router.updateRouteTree(old_route.path, new_ctx)) {
//         return;
//     }
//
//     allocator_global.free(route); // return host‑allocated buffer
//     if (build_options.enable_debug and build_options.debug_level == .all) {
//         frame_arena.printStats();
//     }
//     previous_route = current_route;
// }

pub fn createPage(path: []const u8, page: fn () void, page_deinit: ?fn () void) !void {
    if (isWasi) {
        has_context = true;
    }
    const path_ctx: *UIContext = try allocator_global.create(UIContext);
    // Initial render
    UIContext.initContext(path_ctx) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        return;
    };

    current_ctx = path_ctx;

    router.addRoute(path, path_ctx, page) catch |err| {
        println("Could not put route {any}\n", .{err});
    };
    page_map.put(path, {}) catch |err| {
        println("Could not put route {any}\n", .{err});
    };

    if (page_deinit) |de| {
        page_deinit_map.put(path, de) catch |err| {
            println("Could not put route {any}\n", .{err});
        };
    }
    return;
}
extern fn performance_now() f64; // imported from JS, for example
pub fn nowMs() f64 {
    if (isWasi) {
        return performance_now();
    } else {
        return 0;
    }
}
pub fn endPage(path_ctx: *UIContext) void {
    path_ctx.endContext();
    // TODO: We need to finish the layout engine for working with IOS
    // Canopy.createStack(path_ctx, path_ctx.root.?);
    // Canopy.calcWidth(path_ctx);
    // printUITree(path_ctx.root.?);

    // This adds 2kb
    // UIContext.reconcileStyles();
    if (changed_route) {
        generator.writeAllStyles();
    }
    // @memset(UIContext.seen_nodes, false);
    // UIContext.target_node_index = 0;
    // UIContext.reconcileSizes(path_ctx.root.?);
    // @memset(UIContext.seen_nodes, false);
    // UIContext.target_node_index = 0;
    // UIContext.reconcileVisuals(path_ctx.root.?);
    path_ctx.traverse();
}

pub fn end(vapor: *Vapor) !void {
    const watch_paths: []const []const u8 = &.{"src/routes"};
    for (watch_paths) |watch_path| {
        var dir = try std.fs.cwd().openDir(watch_path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(vapor.allocator.*);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            const path = try std.fs.path.join(vapor.allocator.*, &.{ watch_path, entry.path });
            println("{s}\n", .{path});
        }
    }
}

// Okay so we need to change the node in the tree depending on the page route
// for example we add the commads tree to the router tree
const Path = union(enum) {
    route: []const u8,
    src: std.builtin.SourceLocation,
};
pub fn Page(path: Path, page: fn () void, page_deinit: ?fn () void) void {
    const allocator = Vapor.frame_arena.persistentAllocator();
    var full_route: []const u8 = "";
    var itr: std.mem.TokenIterator(u8, std.mem.DelimiterType.scalar) = undefined;
    if (path == .src) {
        full_route = path.src.file[0..path.src.file.len];
        itr = std.mem.tokenizeScalar(u8, full_route[7..], '/');
    } else {
        full_route = path.route;
        itr = std.mem.tokenizeScalar(u8, full_route, '/');
    }
    var buf = std.array_list.Managed(u8).init(allocator);

    buf.appendSlice("/root") catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        return;
    };

    var file_name: []const u8 = "";
    blk: while (itr.next()) |sub| {
        if (itr.peek() == null and path == .src) {
            file_name = sub;
            break :blk;
        }
        buf.append('/') catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };

        buf.appendSlice(sub) catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    // else
    if (std.mem.startsWith(u8, file_name, "Error")) {
        buf.appendSlice("/error") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    const route = buf.toOwnedSlice() catch |err| {
        println("Could not parse route {any}\n", .{err});
        return;
    };

    createPage(route, page, page_deinit) catch |err| {
        println("Could not add page {any}\n", .{err});
        return;
    };
}
const LayoutOptions = struct {
    reset: bool = false,
};

pub fn registerLayout(path: []const u8, layout: fn (*const fn () void) void, options: LayoutOptions) !void {
    if (std.mem.eql(u8, path, "/root")) return error.CannotRegisterRootPath;
    if (std.mem.eql(u8, path, "/")) {
        layout_map.put(hashKey("/root"), .{ .call_fn = layout, .reset = options.reset }) catch |err| {
            printlnSrcErr("Could not add layout to registry {}", .{err}, @src());
        };
    } else {
        const layout_route = std.fmt.allocPrint(allocator_global, "/root{s}", .{path}) catch return;
        layout_map.put(hashKey(layout_route), .{ .call_fn = layout, .reset = options.reset }) catch |err| {
            printlnSrcErr("Could not add layout to registry {}", .{err}, @src());
        };
    }
}
pub const HooksFuncs = struct {
    created: ?*const fn () void = null,
    mounted: ?*const fn () void = null,
    destroy: ?*const fn () void = null,
    updated: ?*const fn () void = null,
};

pub const HooksCtxFuncs = enum { mounted };

pub fn toggleTheme() void {
    if (isWasi) {
        Wasm.toggleThemeWasm();
    }
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn destroyElementEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb_id: usize,
) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, cb_id);
    Vapor.printlnSrc("Callback id {}", .{cb_id}, @src());
    // if (events_callbacks.remove(cb_id)) {
    //     return true;
    // }
    return false;
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn destroyElementInstEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb_id: usize,
) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, cb_id);
    if (events_inst_callbacks.remove(cb_id)) {
        return true;
    }
    return false;
}

/// This function creates an focuses on the element.
/// # Parameters:
/// - `element_id`: []const u8,
///
/// # Returns:
/// void
pub inline fn focus(element_uuid: []const u8) void {
    Wasm.elementFocusWasm(element_uuid.ptr, element_uuid.len);
}

/// This function creates an focuses on the element.
/// # Parameters:
/// - `element_id`: []const u8,
///
/// # Returns:
/// void
pub inline fn focused(element_uuid: []const u8) bool {
    return Wasm.elementFocusedWasm(element_uuid.ptr, element_uuid.len);
}

pub fn attachEventCtxCallback(ui_node: *UINode, event_type: EventType, cb: anytype, args: anytype) !void {
    if (!isWasi) return;
    const onid = hashKey(ui_node.uuid);

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        event_type: EventType,
        ui_node: *UINode,
        run_node: Vapor.CtxAwareEventNode = .{ .data = .{ .runFn = runFn } },
        fn runFn(data: *const Vapor.CtxAwareEvent) void {
            const run_node: *const Vapor.CtxAwareEventNode = @fieldParentPtr("data", data);
            const closure: *const @This() = @alignCast(@fieldParentPtr("run_node", run_node));
            _ = Vapor.elementInstEventListener(closure.ui_node, closure.event_type, closure.arguments, cb);
        }
    };

    const closure = Vapor.getFrameAllocator().create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };

    closure.* = .{
        .ui_node = ui_node,
        .arguments = args,
        .event_type = event_type,
    };

    if (ui_node.event_handlers) |*handlers| {
        for (handlers.handlers.items) |handler| {
            if (handler.type == event_type) {
                Vapor.getFrameAllocator().destroy(closure);
                return error.EventCtxCallbackError;
            }
        }
        handlers.handlers.ensureUnusedCapacity(arena(.frame), 1) catch |err| {
            printlnSrcErr("Event Callback Error: {any}\n", .{err}, @src());
            return error.EventCallbackError;
        };
        handlers.handlers.appendAssumeCapacity(.{ .type = event_type, .cb_opaque = @ptrCast(@alignCast(&closure.run_node)), .ctx_aware = true });
    } else {
        var handlers = std.ArrayListUnmanaged(EventHandler).initCapacity(arena(.frame), 1) catch |err| {
            printlnSrcErr("Event Callback Error: {any}\n", .{err}, @src());
            return error.EventCallbackError;
        };
        handlers.appendBounded(.{ .type = event_type, .cb_opaque = @ptrCast(@alignCast(&closure.run_node)), .ctx_aware = true }) catch |err| {
            println("Event Callback Error: {any}\n", .{err});
            return error.EventCallbackError;
        };
        ui_node.event_handlers = EventHandlers{ .handlers = handlers };
    }

    nodes_with_events.put(onid, ui_node) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
        return error.EventCallbackError;
    };
}

pub fn attachEventCallback(ui_node: *UINode, event_type: EventType, cb: *const fn (event: *Event) void) !void {
    const onid = hashKey(ui_node.uuid);

    if (ui_node.event_handlers) |*handlers| {
        for (handlers.handlers.items) |handler| {
            if (handler.type == event_type) {
                return error.EventCallbackError;
            }
        }
        handlers.handlers.ensureUnusedCapacity(arena(.frame), 1) catch |err| {
            printlnSrcErr("Event Callback Error: {any}\n", .{err}, @src());
            return error.EventCallbackError;
        };
        handlers.handlers.appendAssumeCapacity(.{ .type = event_type, .cb_opaque = @ptrCast(@alignCast(cb)) });
    } else {
        var handlers = std.ArrayListUnmanaged(EventHandler).initCapacity(arena(.frame), 1) catch |err| {
            printlnSrcErr("Event Callback Error: {any}\n", .{err}, @src());
            return error.EventCallbackError;
        };
        handlers.appendBounded(.{ .type = event_type, .cb_opaque = @ptrCast(@alignCast(cb)) }) catch |err| {
            println("Event Callback Error: {any}\n", .{err});
            return error.EventCallbackError;
        };
        ui_node.event_handlers = EventHandlers{ .handlers = handlers };
    }

    nodes_with_events.put(onid, ui_node) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
        return error.EventCallbackError;
    };
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn elementEventListener(
    ui_node: *UINode,
    event_type: types.EventType,
    cb: *const fn (event: *Event) void,
) ?usize {
    var onid = hashKey(ui_node.uuid);
    onid +%= @intFromEnum(event_type);
    events_callbacks.put(onid, .{ .cb = cb, .ui_node = ui_node, .evt_type = event_type }) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.createElementEventListener(ui_node.uuid.ptr, ui_node.uuid.len, event_type_str.ptr, event_type_str.len, onid);
    return onid;
}

pub fn addGlobalListener(event_type: EventType, cb: EvtInstProto) ?usize {
    const id = events_callbacks.count() + 1;
    events_callbacks.put(id, .{ .cb = cb, .ui_node = null, .evt_type = event_type }) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
        unreachable;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return;
    if (isWasi) {
        Wasm.createEventListener(event_type_str.ptr, event_type_str.len, id);
    }
    return id;
}

pub fn removeGlobalListener(event_type: EventType, cb_idx: usize) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeEventListener(event_type_str.ptr, event_type_str.len, cb_idx);
    if (events_inst_callbacks.remove(cb_idx)) {
        return true;
    }
    return true;
}

pub fn addGlobalListenerCtx(event_type: EventType, cb: anytype, args: anytype) ?usize {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        evt_node: EvtInstNode = .{ .data = .{ .evt_cb = runFn, .deinit = deinitFn } },
        //
        fn runFn(evt_inst: *EvtInst, evt: *Event) void {
            const evt_node: *EvtInstNode = @fieldParentPtr("data", evt_inst);
            const closure: *@This() = @alignCast(@fieldParentPtr("evt_node", evt_node));
            @call(.auto, cb, .{ closure.arguments, evt });
        }
        //
        fn deinitFn(node: *EvtInstNode) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("evt_node", node));
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

    closure.evt_node.evt_type = event_type;

    const id = events_inst_callbacks.count() + 1;
    events_inst_callbacks.put(id, &closure.evt_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
        unreachable;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse unreachable;
    if (isWasi) {
        Wasm.createEventListenerCtx(event_type_str.ptr, event_type_str.len, id);
    }
    return id;
}

pub const EvtInst = struct {
    evt_cb: EvtInstProto,
    deinit: EvtInstNodeProto,
};

pub const EvtInstProto = *const fn (*EvtInst, *Event) void;
pub const EvtInstNodeProto = *const fn (*EvtInstNode) void;

pub const EvtInstNode = struct { data: EvtInst, evt_type: EventType = .none };

pub const CtxAwareEventNode = struct { data: CtxAwareEvent };

pub const CtxAwareEvent = struct {
    runFn: CtxAwareEventNodeProto,
};

pub const CtxAwareEventNodeProto = *const fn (*const CtxAwareEvent) void;

pub inline fn elementInstEventListener(
    ui_node: *UINode,
    event_type: types.EventType,
    arguments: anytype,
    cb: anytype,
) ?usize {
    const Args = @TypeOf(arguments);
    const EvtClosure = struct {
        arguments: Args,
        evt_node: EvtInstNode = .{ .data = .{ .evt_cb = runFn, .deinit = deinitFn } },

        fn runFn(evt_inst: *EvtInst, evt: *Event) void {
            const evt_node: *EvtInstNode = @fieldParentPtr("data", evt_inst);
            const closure: *@This() = @alignCast(@fieldParentPtr("evt_node", evt_node));
            @call(.auto, cb, .{ closure.arguments, evt });
        }
        fn deinitFn(_: *EvtInstNode) void {
            // const closure: *@This() = @alignCast(@fieldParentPtr("evt_node", evt_node));
            // Vapor.allocator_global.destroy(closure);
        }
    };

    const evt_closure = Vapor.arena(.frame).create(EvtClosure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    evt_closure.* = .{
        .arguments = arguments,
    };
    evt_closure.evt_node.evt_type = event_type;

    var onid = hashKey(ui_node.uuid);
    onid +%= @intFromEnum(event_type);
    events_inst_callbacks.put(onid, &evt_closure.evt_node) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.createElementEventInstListener(ui_node.uuid.ptr, ui_node.uuid.len, event_type_str.ptr, event_type_str.len, onid);
    return onid;
}

pub const HookInst = struct {
    hook_cb: HookInstProto,
};

pub const HookInstProto = *const fn (*HookInst) void;
pub const HookInstNodeProto = *const fn (*HookInstNode) void;

pub const HookInstNode = struct { data: HookInst };

pub const HookContext = struct {
    from_path: []const u8,
    to_path: []const u8,
    params: std.StringHashMap([]const u8),
    query: std.StringHashMap([]const u8),
};

pub const HookType = enum(u8) {
    before = 0,
    after = 1,
};

/// cb(Self)
pub inline fn registerHook(
    url: []const u8,
    cb: anytype,
    hook_type: HookType,
) ?usize {
    const id = hooks_inst_callbacks.count();
    hooks_inst_callbacks.put(id, cb) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    Wasm.createHookWASM(url.ptr, url.len, id, @intFromEnum(hook_type));
    return id;
}

/// This function creates an eventListener on the document.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn eventListener(
    event_type: types.EventType,
    cb: *const fn (event: *Event) void,
) void {
    const id = events_callbacks.count() + 1;
    events_callbacks.put(id, .{ .cb = cb, .ui_node = null, .evt_type = event_type }) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return;
    if (isWasi) {
        Wasm.createEventListener(event_type_str.ptr, event_type_str.len, id);
    }
    return;
}

// The first node needs to be marked as false always
pub fn markChildrenDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = true;
    }
    if (node.children) |children| {
        for (children.items) |child| {
            markChildrenDirty(child);
        }
    }
}
// The first node needs to be marked as false always
pub fn markChildrenNotDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = false;
    }
    if (node.children) |children| {
        for (children.items) |child| {
            markChildrenNotDirty(child);
        }
    }
}

var buffer: [5_000_000]u8 = undefined;
var writer: std.Io.Writer = undefined;
var generated_file: std.fs.File = undefined;
pub fn generate() void {
    std.fs.cwd().makeDir("static") catch |err| {
        switch (err) {
            error.PathAlreadyExists => {},
            else => unreachable,
        }
    };

    var css_variables = std.fs.cwd().createFile("static/style_variables.css", .{}) catch unreachable;
    css_variables.writeAll(StyleCompiler.global_style) catch unreachable;
    // // _ = frame_arena.queryNodes();
    var page_itr = page_map.iterator();
    while (page_itr.next()) |entry| {
        writer = std.io.Writer.fixed(&buffer);
        const route = entry.key_ptr.*;
        // Create the directory
        const dir = std.fmt.allocPrint(allocator_global, "static{s}", .{route[5..]}) catch unreachable;
        defer allocator_global.free(dir);

        // Create directories
        var sub_dirs = std.mem.tokenizeAny(u8, route[5..], "/");
        var current_dir: []const u8 = "";
        while (sub_dirs.next()) |sub_dir| {
            current_dir = std.fmt.allocPrint(allocator_global, "{s}/{s}", .{ current_dir, sub_dir }) catch |err| {
                std.debug.print("Error: {any}\n", .{err});
                unreachable;
            };
            const total_dir = std.fmt.allocPrint(allocator_global, "static{s}", .{current_dir}) catch |err| {
                std.debug.print("Error: {any}\n", .{err});
                unreachable;
            };
            // Make sure the directory exists
            std.fs.cwd().makeDir(total_dir) catch |err| {
                switch (err) {
                    error.PathAlreadyExists => {},
                    else => unreachable,
                }
            };
        }
        // Create the path
        const path = std.fmt.allocPrint(allocator_global, "{s}/index.html", .{dir}) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            unreachable;
        };
        defer allocator_global.free(path);

        // Create the static file
        generated_file = std.fs.cwd().createFile(path, .{}) catch |err| {
            std.debug.print("Create Error: {any} {s}\n", .{ err, path });
            unreachable;
        };
        defer generated_file.close();

        // Write the HTML
        generateHtml(route, dir);
        // Write to the file
        _ = generated_file.write(writer.buffer[0..writer.end]) catch unreachable;
    }
    // writer.flush() catch unreachable;
    // isGenerated = true;
}

pub fn generateHtml(route: []const u8, dir: []const u8) void {
    frame_arena.beginFrame(); // For double-buffered approach

    if (!std.mem.eql(u8, current_route, route)) {
        changed_route = true;
        // We need to start a new route allocator
        // otherwise we are on the same route
        frame_arena.beginView();
    }

    current_route = route;
    removed_nodes.clearRetainingCapacity();
    added_nodes.clearRetainingCapacity();
    dirty_nodes.clearRetainingCapacity();
    // potential_nodes.clearRetainingCapacity();
    node_events_callbacks.clearRetainingCapacity();
    events_callbacks.clearRetainingCapacity();
    nodes_with_events.clearRetainingCapacity();
    UIContext.indexes.clearRetainingCapacity();

    // var ctx_itr = ctx_callback_registry.iterator();
    // while (ctx_itr.next()) |entry| {
    //     _ = entry.value_ptr.*;
    // }
    // ctx_callback_registry.clearRetainingCapacity();
    // mounted_ctx_funcs.clearRetainingCapacity();

    // Get the old context for current route
    const old_route = router.searchRoute(route) orelse {
        printlnWithColor("No Router found {s}\n", .{route}, "#FF3029", "ERROR");
        printlnWithColor("Loading Error Page\n", .{}, "#FF3029", "ERROR");
        return;
    };
    render_page = old_route.page;
    const old_ctx = current_ctx;
    // Create new context
    const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    route_segments = allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        route_segments[count] = route_token;
        count += 1;
    }

    // Init the generator
    generator.init();
    next_layout_path_to_check = "";

    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms
    changed_route = false;
    generator.writeAllStyles();
    const css = generator.getCSS();
    const style_path = std.fmt.allocPrint(allocator_global, "{s}/style.css", .{dir}) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        unreachable;
    };
    defer allocator_global.free(style_path);

    var generated_css = std.fs.cwd().createFile(style_path, .{}) catch unreachable;
    defer generated_css.close();
    generated_css.writeAll(css) catch unreachable;

    HtmlGenerator.generate(new_ctx.root.?, &writer, style_path);
}

pub fn printUIRouteTree(route: u32) void {
    frame_arena.beginFrame(); // For double-buffered approach
    current_route = route;
    // Vapor.btn_registry.clearRetainingCapacity();
    // Vapor.mounted_funcs.clearRetainingCapacity();

    // ctx_callback_registry.clearRetainingCapacity();

    // mounted_ctx_funcs.clearRetainingCapacity();

    // Get the old context for current route
    const old_route = router.searchRoute(route) orelse {
        printlnWithColor("No Router found {s}\n", .{route}, "#FF3029", "ERROR");
        printlnWithColor("Loading Error Page\n", .{}, "#FF3029", "ERROR");
        return;
    };
    render_page = old_route.page;
    const old_ctx = current_ctx;
    // Create new context
    const new_ctx: *UIContext = allocator_global.create(UIContext) catch {
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.style = old_ctx.root.?.style;
    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    // Pure tree is attached to the traversal algo, ie itll be updated when the traversal algo is updated
    // pure_tree.init(new_ctx.root.?, &allocator_global) catch {};
    // error_tree.init(new_ctx.root.?, &allocator_global) catch {};
    // Here we set the current_ctx to the new_ctx
    current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    route_segments = allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        route_segments[count] = route_token;
        count += 1;
    }

    next_layout_path_to_check = "";
    // We call the routes and nested layuts
    // This finds the reset layout, if it exists
    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms

    // We reconcile the new dom
    // the reason the vapor-debugger gets remvoed is the new ui tree does not include it;

    // const valid_route = replace_dash(current_route) catch unreachable;
    // defer allocator_global.free(valid_route);

    // writer.print("\"{s}\":", .{current_route}) catch unreachable;
    // writer.writeAll("{\n") catch unreachable;
    printStaticTextNode(new_ctx.root.?);
    // writer.writeAll("}\n") catch unreachable;
}

pub fn printUITree(node: *UINode) void {
    // if (node.dirty) {
    println("UI: {s}\n", .{node.uuid});
    // }
    if (node.children) |children| {
        for (children.items) |child| {
            printUITree(child);
        }
    }
}

pub fn escapeForJson(input: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator_global);

    for (input) |c| {
        switch (c) {
            '"' => {
                // Add backslash before quote: → \"
                try list.append('\\');
                try list.append('"');
            },
            '\\' => {
                // Optional: also escape existing backslashes → \\
                try list.append('\\');
                try list.append('\\');
            },
            '\n' => {
                // Optional: also escape existing backslashes → \\
                continue;
            },
            else => {
                try list.append(c);
            },
        }
    }

    return list.toOwnedSlice();
}

pub fn replace_dash(input: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(allocator_global);

    for (input) |c| {
        switch (c) {
            '/' => {
                // Add backslash before quote: → \"
                try list.append('-');
            },
            else => {
                try list.append(c);
            },
        }
    }

    return list.toOwnedSlice();
}

fn printStaticTextNode(node: *UINode) void {
    if (node.state_type == .static) blk: {
        var valid_text: []const u8 = "";
        if (node.text) |text| {
            valid_text = escapeForJson(text) catch unreachable;
        } else if (node.href) |href| {
            valid_text = escapeForJson(href) catch unreachable;
        } else break :blk;
        defer allocator_global.free(valid_text);
        if (writer.end > current_route.len + 10) {
            _ = writer.write(",\n") catch unreachable;
        }
        writer.print("\"{s}\":\"{s}\"", .{ node.uuid, valid_text }) catch unreachable;
    }
    for (node.children.items) |child| {
        printStaticTextNode(child);
    }
}

fn collectComponentIds(node: *UINode, selected_type: ElementType, component_ids: *std.array_list.Managed([]const u8)) void {
    if (node.type == selected_type) {
        component_ids.append(node.uuid) catch unreachable;
    }
    if (node.children == null) return;
    for (node.children.?.items) |child| {
        collectComponentIds(child, selected_type, component_ids);
    }
}

pub fn queryComponentIds(target_type: ElementType) ![][]const u8 {
    const root = current_ctx.root orelse return error.NoTree;
    var component_ids = std.array_list.Managed([]const u8).init(allocator_global);
    collectComponentIds(root, target_type, &component_ids);
    return try component_ids.toOwnedSlice();
}

fn findNodeByUUID(node: *UINode, uuid: []const u8) UINode {
    if (std.mem.eql(u8, node.uuid, uuid)) {
        return node.*;
    }
    if (node.children == null) return;
    for (node.children.?.items) |child| {
        collectComponentIds(child, uuid);
    }
}

pub fn queryByUUID(uuid: []const u8) !UINode {
    const root = current_ctx.root orelse return error.NoTree;
    const node = findNodeByUUID(root, uuid);
    return node;
}

pub fn mutateById(uuid: []const u8, attribute: []const u8, value: []const u8) void {
    mutateDomElementStyleString(uuid.ptr, uuid.len, attribute.ptr, attribute.len, value.ptr, value.len);
}

pub const Bounds = struct {
    top: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub fn getComponentBounds(uuid: []const u8) ?Bounds {
    const bounds_ptr = if (isWasi) blk: {
        break :blk Wasm.getBoundingClientRectWasm(uuid.ptr, uuid.len);
    } else {
        return null;
    };

    return Bounds{
        .top = bounds_ptr[0],
        .left = bounds_ptr[1],
        .right = bounds_ptr[2],
        .bottom = bounds_ptr[3],
        .width = bounds_ptr[4],
        .height = bounds_ptr[5],
    };
}

fn iterateChildren(node: *UINode) void {
    if (node.state_type == .pure) {
        const pure_node = pure_tree.createNode(node) catch return;
        Vapor.pure_tree.openNode(pure_node) catch return;
    }

    if (node.state_type == .err) {
        const error_node = error_tree.createNode(node) catch return;
        Vapor.error_tree.openNode(error_node) catch return;
    }

    for (node.children.items) |child| {
        iterateChildren(child);
    }
    if (node.state_type == .pure and node.parent != null) {
        _ = pure_tree.popStack();
    }
    if (node.state_type == .err and node.parent != null) {
        _ = error_tree.popStack();
    }
}

pub fn iterateTreeChildren(tree: *CommandsTree) void {
    for (tree.children.items) |child| {
        iterateTreeChildren(child);
    }
}

// Export memory layout information for JavaScript to correctly read the struct
// Export function to get a pointer to the memory layout information
// Corrected layout information
pub var layout_info = packed struct {
    render_command_size: u32,

    // Offsets within RenderCommand
    elem_type_offset: u32,
    text_ptr_offset: u32,
    href_ptr_offset: u32,
    id_ptr_offset: u32,
    index_offset: u32,
    hooks_offset: u32,
    node_ptr_offset: u32,
    classname_ptr_offset: u32,

    // Offsets for fields inside the nested 'style' struct
    style_btn_id_offset: u32,
    style_dialog_id_offset: u32,
    style_exit_animation_ptr_offset: u32,

    // Offsets for fields inside the nested 'hover' struct
    hover_size: u32,
    hover_offset: u32,

    // Offsets for fields inside the nested 'focus' struct
    focus_size: u32,
    focus_offset: u32,

    // Offsets for fields inside the nested 'focus_within' struct
    focus_within_size: u32,
    focus_within_offset: u32,
    render_type_offset: u32,
    tooltip_size: u32,
    tooltip_offset: u32,
    has_children_offset: u32,
    hash_offset: u32,
    style_changed_offset: u32,
}{
    .render_command_size = @sizeOf(RenderCommand),

    // --- Direct fields of RenderCommand ---
    .elem_type_offset = @offsetOf(RenderCommand, "elem_type"),
    .text_ptr_offset = @offsetOf(RenderCommand, "text"),
    .href_ptr_offset = @offsetOf(RenderCommand, "href"),
    .id_ptr_offset = @offsetOf(RenderCommand, "id"),
    .index_offset = @offsetOf(RenderCommand, "index"),
    .hooks_offset = @offsetOf(RenderCommand, "hooks"),
    .node_ptr_offset = @offsetOf(RenderCommand, "node_ptr"),
    .classname_ptr_offset = @offsetOf(RenderCommand, "class"),

    // --- Absolute offsets for fields within the nested 'style' struct ---
    .style_btn_id_offset = @offsetOf(RenderCommand, "style") + @offsetOf(Style, "btn_id"),
    .style_dialog_id_offset = @offsetOf(RenderCommand, "style") + @offsetOf(Style, "dialog_id"),
    .style_exit_animation_ptr_offset = @offsetOf(RenderCommand, "style") + @offsetOf(Style, "exit_animation"),

    // --- Nested struct sizes and offsets ---
    .hover_offset = @offsetOf(RenderCommand, "hover"),
    .hover_size = @sizeOf(Hover),
    .focus_offset = @offsetOf(RenderCommand, "focus"),
    .focus_size = @sizeOf(Focus),
    .focus_within_offset = @offsetOf(RenderCommand, "focus_within"),
    .focus_within_size = @sizeOf(Focus),
    .render_type_offset = @offsetOf(RenderCommand, "render_type"),
    .tooltip_size = @sizeOf(types.Tooltip),
    .tooltip_offset = @offsetOf(RenderCommand, "tooltip"),
    .has_children_offset = @offsetOf(RenderCommand, "has_children"),
    .hash_offset = @offsetOf(RenderCommand, "hash"),
    .style_changed_offset = @offsetOf(RenderCommand, "style_changed"),
};

// Make sure this function is not evaluated at compile time
pub fn hexToRgba(hex_str: []const u8) [4]f32 {
    if (hex_str.len < 7 or hex_str[0] != '#') return .{ 0, 0, 0, 1 };

    // Parse at runtime instead of compile-time
    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    // Manual hex parsing to avoid compile-time evaluation issues
    r = @floatFromInt(parseHexByte(hex_str[1..3]) catch 0);
    g = @floatFromInt(parseHexByte(hex_str[3..5]) catch 0);
    b = @floatFromInt(parseHexByte(hex_str[5..7]) catch 0);

    return .{ r, g, b, 1 };
}

fn parseHexByte(hex: []const u8) !u8 {
    if (hex.len != 2) return error.InvalidLength;

    const high = try charToHex(hex[0]);
    const low = try charToHex(hex[1]);

    return (high << 4) | low;
}

fn charToHex(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidCharacter,
    };
}

/// fmtln is a wrapper around std.fmt.allocPrint that allocates memory from the frame allocator
/// this means that this slice is deallocated on each frame
/// this is useful for formatting ids passed into the style struct
pub fn fmtln(
    comptime fmt: []const u8,
    args: anytype,
) []const u8 {
    const allocator = arena(.frame);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn cloneFrame(
    value: anytype,
) []const u8 {
    const T = @TypeOf(value);
    if (T == []const u8) return fmtln("{s}", .{value});
    const allocator = arena(.frame);
    const memory: *@TypeOf(value) = allocator.create(T) catch unreachable;
    memory.* = value;
    return memory.*;
}

pub fn printlnErr(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%cERROR%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #FF3029;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printErr(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%cERROR%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #FF3029;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printWarn(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%cWARN%c] {s}", .{buf[0..]}) catch return;
        const style_1 = "color: #FFA629;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWarnWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printlnSrcErr(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%cERROR:{s}:{d}%c]\n{s}", .{ src.file, src.line, buf[0..] }) catch return;
        const style_1 = "color: #FF3029;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printlnWithColor(
    comptime fmt: []const u8,
    args: anytype,
    color: []const u8,
    title: []const u8,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const color_buf = std.fmt.allocPrint(allocator_global, "color: {s};", .{color}) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%c{s}%c] {s}", .{ title, buf[0..] }) catch return;
    // const style_2 = "";
    // _ = consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(color_buf);
    allocator_global.free(buf);
}

fn convertColorToString(color: Types.Color) []const u8 {
    return switch (color) {
        .Literal => |rgba| rgbaToString(rgba),
        else => "",
    };
}

fn rgbaToString(rgba: Types.Rgba) []const u8 {
    return std.fmt.allocPrint(allocator_global, "rgba({d},{d},{d},{d})", .{
        rgba.r,
        rgba.g,
        rgba.b,
        rgba.a,
    }) catch return "";
}

pub fn printlnColor(
    comptime fmt: []const u8,
    args: anytype,
    color: Types.Color,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const color_buf = std.fmt.allocPrint(allocator_global, "color: {s};", .{convertColorToString(color)}) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "%c{s}%c", .{buf[0..]}) catch return;
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, color_buf[0..].ptr, color_buf.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(color_buf);
        allocator_global.free(buf);
    }
}

pub fn printlnAllocation(
    comptime fmt: []const u8,
    args: anytype,
) void {
    const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
    const buf_with_src = std.fmt.allocPrint(allocator_global, "[Vapor] [%cALLOC%c] {s}", .{buf[0..]}) catch return;
    // const style_1 = "color: #744EFF;";
    // const style_2 = "";
    // _ = consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
    allocator_global.free(buf_with_src);
    allocator_global.free(buf);
}

pub fn printlnSrc(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(allocator_global, "[%c{s}:{d}%c]\n[MSG] {s}", .{ src.file, src.line, buf[0..] }) catch return;
        const style_1 = "color: #3CE98A;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        allocator_global.free(buf_with_src);
        allocator_global.free(buf);
    }
}

pub fn printDebug() !void {
    // std.debug.print("Hello World\n", .{});
    // const addr: std.builtin.StackTrace = @errorReturnTrace().?.*;
    // for (addr.instruction_addresses) |_addr| {
    //     std.debug.print("    0x{d}\n", .{_addr});
    // }
    var buffer_debug: [512]u8 = undefined;
    var stream = std.Io.Writer.fixed(&buffer_debug);
    const writer_debug = &stream;
    // // var writer_debug = std.fs.File.writer(std.fs.File.stderr(), &buffer_debug).interface;
    // // _ = addr.format(&writer_debug) catch unreachable;
    // std.debug.print("{*}", .{&addr});
    std.debug.dumpCurrentStackTraceToWriter(@returnAddress(), writer_debug) catch unreachable;
    std.debug.print("Called from: 0x{s}\n", .{writer_debug.buffer[0..writer_debug.end]});

    // try std.debug.dumpCurrentStackTraceToWriter(@returnAddress(), &writer_debug);
    // Vapor.print("{any}", .{@returnAddress()});
    // try writer_debug.print("Error\n", .{});
    // try writer_debug.flush();
    // Let's say you have an address you want to inspect
    // 1. Get the standard error writer (maps to console.error() in browser)
    // const stderr = std.io.getStdErr().writer();

    // 2. Just print the address. The browser will symbolicate it for you.
    //    You don't need printSourceAtAddress.

    // 3. Or, if you just want a full stack trace:
    //    Zig's built-in stack dumper will print the raw addresses.
    //    The browser DevTools will automatically convert this
    //    trace into file:line locations.
    // const ret_addr = @returnAddress();
    // const debug_info = std.debug.getSelfDebugInfo() catch @panic("Could not get debug_info");
    // // 1) Prepare a big enough buffer on the stack
    // var buffer_debug: [512]u8 = undefined;
    // var stream = std.Io.Writer.fixed(&buffer_debug);
    // const writer_debug = &stream;
    //
    // // 3) Call printSourceAtAddress into *your*writer_debug
    // const tty = std.io.tty.detectConfig(std.fs.File.stderr());
    // try std.debug.printSourceAtAddress(debug_info, writer_debug, ret_addr, tty);
    // std.debug.dumpStackTrace();
    // const outSlice = buffer_debug[0..stream.end];
    // const start = std.mem.indexOf(u8, outSlice, "src") orelse std.mem.indexOf(u8, outSlice, "std") orelse 0;
    // const src = buffer_debug[start..stream.end];
    // Vapor.print("{s}", .{src});
    // var sections = std.mem.splitScalar(u8, src, ':');
    // var indents = std.mem.splitScalar(u8, src, '\n');
    // const file_name = sections.next() orelse return;
    // const line = sections.next() orelse return;
    // const u32_line_n: u32 = std.fmt.parseInt(u32, line, 10) catch return;
    // _ = indents.next().?;
    // const fn_name = indents.next().?;
    // const err_str = try std.fmt.allocPrint(reverb.arena.*, "{any}", .{error.MethodNotSupported});
    // const function_name = try std.fmt.allocPrint(reverb.arena.*, "{s}", .{fn_name[0 .. fn_name.len - 2]});
    // const file_name_alloc = try std.fmt.allocPrint(reverb.arena.*, "{s}", .{file_name});
}

pub fn print(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        _ = Wasm.consoleLogWasm(buf.ptr, buf.len);
        allocator_global.free(buf);
    } else if (!isWasi) {
        std.debug.print(fmt, args);
    }
}

pub fn println(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (isWasi and build_options.enable_debug) {
        const buf = std.fmt.allocPrint(allocator_global, fmt, args) catch return;
        _ = Wasm.consoleLogWasm(buf.ptr, buf.len);
        allocator_global.free(buf);
    } else if (!isWasi) {
        std.debug.print(fmt, args);
    }
}

/// name: name of the interval
/// cb: callback function
/// args: arguments to pass to the callback function
/// delay: delay in ms
pub fn loopInterval(name: []const u8, cb: anytype, args: anytype, delay: u32) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Action) void {
            const run_node: *Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, cb, closure.arguments);
        }
        //
        fn deinitFn(node: *Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            allocator_global.destroy(closure);
        }
    };

    const closure = allocator_global.create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    callback_registry.put(hashKey(name), &closure.run_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };

    if (isWasi) {
        Wasm.createInterval(name.ptr, name.len, delay);
    } else {
        return;
    }
}

pub fn registerCtxTimeout(callback_name: []const u8, ms: u32, cb: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Action) void {
            const run_node: *Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, cb, closure.arguments);
        }
        //
        fn deinitFn(node: *Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            allocator_global.destroy(closure);
        }
    };

    const closure = allocator_global.create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        unreachable;
    };
    closure.* = .{
        .arguments = args,
    };

    const callback_id = hashKey(callback_name);
    ctx_callback_registry.put(callback_id, &closure.run_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };

    if (isWasi) {
        Wasm.timeoutCtx(ms, callback_id);
    } else {
        return;
    }
}

pub fn cancelTimeout(callback_name: []const u8) void {
    const callback_id = hashKey(callback_name);
    if (isWasi) {
        Wasm.cancelTimeoutWasm(callback_id);
    }
}

pub fn registerTimeout(ms: u32, cb: *const fn () void) void {
    const id = callback_registry.count() + 1;
    callback_registry.put(id, cb) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };
    if (isWasi) {
        Wasm.timeout(ms, id);
    } else {
        return;
    }
}

pub fn setCookie(cookie: []const u8) void {
    Wasm.setCookieWASM(cookie.ptr, cookie.len);
}

pub fn getCookies() []const u8 {
    const cookie = Wasm.getCookiesWASM();
    return std.mem.span(cookie);
}

pub fn getCookie(name: []const u8) ?[]const u8 {
    const cookie = Wasm.getCookieWASM(name.ptr, name.len);
    if (cookie == null) return null;
    return std.mem.span(cookie);
}

pub const Clipboard = struct {
    pub fn copy(text: []const u8) void {
        if (isWasi) {
            Wasm.copyTextWasm(text.ptr, text.len);
        }
    }
    fn paste(_: []const u8) void {}
};

pub fn onEnd(callback: *const fn () void) void {
    on_end_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

export fn clearOnEnd() void {
    on_end_funcs.clearRetainingCapacity();
}

pub const Binded = Element;

pub fn onEndCtx(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
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

    Vapor.on_end_ctx_funcs.append(&closure.run_node) catch |err| {
        println("Hooks Function Registry {any}\n", .{err});
    };
}

/// This hook takes a function callback and calls it after the virtual dom has been created
/// WARNING: This is a dangerous hook, and can cause infinite loops
pub fn onCommit(callback: *const fn () void) void {
    on_commit_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub export fn getRenderTreePtr() ?*UIContext.CommandsTree {
    const tree_op = Vapor.current_ctx.ui_tree;

    if (tree_op != null) {
        // iterateTreeChildren(Vapor.current_ctx.ui_tree.?);
        return Vapor.current_ctx.ui_tree.?;
    }
    return null;
}

pub export fn allocateLayoutInfo() *u8 {
    const info_ptr: *u8 = @ptrCast(&Vapor.layout_info);
    return info_ptr;
}

export fn allocUint8(length: u32) [*]const u8 {
    const slice = Vapor.allocator_global.alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

export fn allocUint8Frame(length: u32) [*]const u8 {
    const slice = Vapor.getFrameAllocator().alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

export fn getCSS() ?[*]const u8 {
    return Vapor.generator.buffer[0..Vapor.generator.end].ptr;
}

export fn getCSSLen() usize {
    return Vapor.generator.end;
}

pub export fn getRenderCommandPtr(tree: *CommandsTree) [*]u8 {
    if (std.mem.eql(u8, tree.node.id, "global-style")) {
        Vapor.println("getRenderCommandPtr {any}\n", .{tree.node.node_ptr.dirty});
    }
    return @ptrCast(tree.node);
}

export fn getTreeNodeChildrenCount(tree: *CommandsTree) usize {
    return tree.children.items.len;
}

export fn getUiNodeChildrenCount(tree: *CommandsTree) usize {
    if (tree.node.node_ptr.children == null) return 0;
    return tree.node.node_ptr.children.?.items.len;
}

export fn getTreeNodeChild(tree: *CommandsTree, index: usize) *CommandsTree {
    const child = tree.children.items[index];
    return child;
}

// The first node needs to be marked as false always
export fn markCurrentTreeNotDirty() void {
    if (!Vapor.has_context) return;
    const root = Vapor.current_ctx.root orelse return;
    Vapor.markChildrenNotDirty(root);
}

export fn getRemovedNode(index: usize) [*]const u8 {
    const node = Vapor.removed_nodes.items[index];
    return node.uuid.ptr;
}

export fn getRemovedNodeIndex(index: usize) usize {
    return Vapor.removed_nodes.items[index].index;
}

export fn getRemovedNodeLength(index: usize) usize {
    return Vapor.removed_nodes.items[index].uuid.len;
}

// Export the size of a single RenderCommand for proper memory reading
export fn getRenderCommandSize() usize {
    return @sizeOf(RenderCommand);
}

export fn shouldRerender() bool {
    return Vapor.global_rerender;
}

export fn rerenderEverything() bool {
    return Vapor.rerender_everything;
}

export fn hasDirty() bool {
    return Vapor.has_dirty;
}

export fn resetRerender() void {
    Vapor.global_rerender = false;
    Vapor.rerender_everything = false;
    Vapor.has_dirty = false;
}

/// Calling route renderCycle will mark eveything as dirty
export fn callRouteRenderCycle(ptr: [*:0]u8) void {
    Packer.animations.clearRetainingCapacity();
    Packer.layouts.clearRetainingCapacity();
    Packer.positions.clearRetainingCapacity();
    Packer.margins_paddings.clearRetainingCapacity();
    Packer.visuals.clearRetainingCapacity();
    Packer.interactives.clearRetainingCapacity();
    UIContext.class_map.clearRetainingCapacity();
    Vapor.pool.resetFreeList();
    Vapor.renderCycle(ptr);
    Vapor.markChildrenDirty(Vapor.current_ctx.root.?);
    return;
}

export fn setRouteRenderTree(ptr: [*:0]u8) void {
    Vapor.renderCycle(ptr);
    return;
}

export fn setRerenderTrue() void {
    Vapor.cycle();
}

export fn getDirtyValue(node: *UINode) bool {
    return node.dirty;
}

export fn getRemovedNodeCount() usize {
    return Vapor.removed_nodes.items.len;
}

export fn clearRemovedNodesretainingCapacity() void {
    Vapor.removed_nodes.clearRetainingCapacity();
}

export fn onEndCallback() void {
    const length = Vapor.on_end_funcs.items.len;
    if (length == 0) return;
    Vapor.println("onEndCallback {any}", .{length});
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const call = Vapor.on_end_funcs.orderedRemove(i);
        @call(.auto, call, .{});
        if (i == 0) return;
    }
}

export fn allocate(size: usize) ?[*]f32 {
    const buf = Vapor.allocator_global.alloc(f32, size) catch |err| {
        Vapor.println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}

export fn callbackCtx(callback_ptr: u32, object_ptr: ?*DynamicObject) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        Vapor.printlnSrcErr("Callback not found\n", .{}, @src());
        return;
    };
    node.data.dynamic_object = object_ptr;
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

pub fn alert(message: []const u8) void {
    if (isWasi) {
        Wasm.alertWasm(message.ptr, message.len);
    }
}

// Zig Side
const FieldType = enum {
    string,
    int,
    float,
    bool,
};

const Field = struct {
    name: []const u8,
    type: FieldType,
    value: union(enum) {
        string: []const u8,
        int: i32,
        float: f64,
        bool: bool,
    },
};

pub const DynamicObject = struct {
    fields: std.array_list.Managed(Field),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DynamicObject {
        return .{
            .fields = std.array_list.Managed(Field).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DynamicObject) void {
        self.fields.deinit();
    }
};

pub fn convertFromDynamicToType(comptime T: type, dyn_object: *DynamicObject) T {
    var new_object: T = undefined;
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        const dyn_field_value = dyn_object.fields.items[i].value;
        const dyn_field_type = dyn_object.fields.items[i].type;
        switch (@typeInfo(field.type)) {
            .pointer => |ptr| {
                if (ptr.size == .slice) {
                    @field(new_object, field.name) = dyn_field_value.string;
                } else {
                    Vapor.printlnErr("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            .int => {
                if (dyn_field_type == .int) {
                    @field(new_object, field.name) = @as(field.type, @intCast(dyn_field_value.int));
                } else {
                    Vapor.printlnErr("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            .float => {
                if (dyn_field_type == .float) {
                    @field(new_object, field.name) = @as(field.type, @intCast(dyn_field_value.float));
                } else {
                    Vapor.printlnErr("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            .bool => {
                if (dyn_field_type == .bool) {
                    @field(new_object, field.name) = dyn_field_value.bool;
                } else {
                    Vapor.printlnErr("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            .@"struct" => {
                if (dyn_field_type == .object) {
                    @field(new_object, field.name) = convertFromDynamicToType(field.type, dyn_field_value.object);
                } else {
                    Vapor.printlnErr("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            else => {},
        }
    }
    return new_object;
}

var current_object: ?*DynamicObject = null;

export fn startObject() usize {
    current_object = allocator_global.create(DynamicObject) catch return 0;
    current_object.?.* = DynamicObject.init(allocator_global);
    return @intFromPtr(current_object.?);
}

export fn addStringField(handle: i32, key_ptr: [*:0]u8, value_ptr: [*:0]u8) void {
    const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
    const key = std.mem.span(key_ptr);
    const value = std.mem.span(value_ptr);

    obj.fields.append(.{
        .name = key,
        .type = .string,
        .value = .{ .string = value },
    }) catch return;
}

export fn addIntField(handle: i32, key_ptr: [*:0]u8, value: i32) void {
    const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
    const key = std.mem.span(key_ptr);

    obj.fields.append(.{
        .name = key,
        .type = .int,
        .value = .{ .int = value },
    }) catch return;
}

export fn addFloatField(handle: i32, key_ptr: [*:0]u8, value: f32) void {
    const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
    const key = std.mem.span(key_ptr);

    obj.fields.append(.{
        .name = key,
        .type = .float,
        .value = .{ .float = value },
    }) catch return;
}

export fn addBoolField(handle: i32, key_ptr: [*:0]u8, value: bool) void {
    const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
    const key = std.mem.span(key_ptr);

    obj.fields.append(.{
        .name = key,
        .type = .bool,
        .value = .{ .bool = value },
    }) catch return;
}

// Similar for float and bool fields...

pub fn finalizeObject(handle: u32) *DynamicObject {
    const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
    return obj;
}

// Zig Side - Automatic struct introspection
pub fn FieldDescriptor() type {
    return extern struct {
        name_ptr: [*]const u8,
        name_len: u32,
        offset: u32,
        type_id: u8,
        size: u32,
        can_be_null: bool,
    };
}

pub fn exportStruct(comptime T: type) type {
    return struct {
        pub var instance: T = undefined;
        var descriptors: [@typeInfo(T).@"struct".fields.len]FieldDescriptor() = undefined;

        pub fn init() void {
            const fields = @typeInfo(T).@"struct".fields;
            inline for (fields, 0..) |field, i| {
                descriptors[i] = .{
                    .name_ptr = field.name.ptr,
                    .name_len = field.name.len,
                    .offset = @offsetOf(T, field.name),
                    .type_id = getTypeId(field.type),
                    .size = @sizeOf(Kit.getUnderlyingType(field.type)),
                    .can_be_null = @typeInfo(field.type) == .optional,
                };
            }
        }

        pub fn getInstancePtr() [*]const u8 {
            return @ptrCast(&instance);
        }

        pub fn getFieldCount() u32 {
            return @typeInfo(T).@"struct".fields.len;
        }

        pub fn getFieldDescriptor(index: u32) *const FieldDescriptor() {
            return &descriptors[index];
        }

        fn getTypeId(comptime FT: type) u8 {
            return switch (@typeInfo(Kit.getUnderlyingType(FT))) {
                .int => |info| if (info.signedness == .unsigned) 1 else 2,
                .float => 3,
                .bool => 4,
                .array => |arr| if (arr.child == u8) 5 else 6,
                .pointer => 7,
                .@"enum" => {
                    return 8;
                },
                else => {
                    return 0;
                },
            };
        }
    };
}

// // Usage
// const UserExport = exportStruct(User);
// pub fn initUser() void {
//     UserExport.init();
//     UserExport.instance = User{
//         .id = 12345,
//         .age = 25,
//         .score = 98.5,
//         .name = "John Doe".*,
//         .is_active = true,
//     };
// }

// // Export the stack pointer to JavaScript
// export fn get_stack_pointer() usize {
//     var stack_variable: u8 = 0;
//     return @intFromPtr(&stack_variable);
// }
//
// // Track heap allocations if using an allocator
// var heap_allocated: usize = 0;
//
// export fn get_heap_size() usize {
//     return heap_allocated;
// }
//
// // Get current memory pages
// export fn get_memory_pages() u32 {
//     // This is a WASM builtin
//     return @wasmMemorySize(0);
// }
//
// // Try to grow memory
// export fn try_grow_memory(pages: u32) isize {
//     return @wasmMemoryGrow(0, pages);
// }
//
// // More detailed memory info
// export fn get_memory_info() void {
//     const pages = @wasmMemorySize(0);
//     const bytes = pages * 65536;
//
//     // Get stack pointer
//     var stack_var: u8 = 0;
//     const stack_ptr = @intFromPtr(&stack_var);
//
//     // If you know your stack base (depends on your setup)
//     const STACK_BASE = 1048576; // Example: 1MB
//     const stack_used = STACK_BASE - stack_ptr;
//
//     Vapor.print("Memory Pages: {}\n", .{pages});
//     Vapor.print("Total Memory: {} KB\n", .{bytes / 1024});
//     Vapor.print("Stack Pointer: 0x{x}\n", .{stack_ptr});
//     Vapor.print("Approx Stack Used: {} KB\n", .{stack_used / 1024});
// }
