const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const println = @import("Vapor.zig").println;
const Vapor = @import("Vapor.zig");
/// This is all very confusing, I have no idea how I came up with this solution, but it works idk, its kinda magic

// Set uses AutoHashMap underneath the hood
// this means that iterating through the set does not have consitent order
pub fn Set(comptime T: type) type {
    return struct {
        const Self = @This();
        map: std.AutoHashMap(T, void),

        pub fn init(allocator_ptr: *std.mem.Allocator) Set(T).Self {
            return .{
                .map = std.AutoHashMap(T, void).init(allocator_ptr.*),
            };
        }

        pub fn add(self: *Self, value: T) void {
            self.map.put(value, {}) catch |err| {
                Vapor.printlnSrcErr("{any}\n", .{err}, @src());
                return;
            };
        }
        pub fn get(self: *Self, value: T) ?void {
            return self.map.get(value);
        }
        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.map.clearRetainingCapacity();
        }

        pub fn count(self: *Self) usize {
            return self.map.count();
        }

        pub fn iterator(self: *Self) std.AutoHashMap(T, void).KeyIterator {
            return self.map.keyIterator();
        }
    };
}

const Action = struct {
    runFn: ActionProto,
    deinitFn: DeinitProto,
};

const ActionProto = *const fn (*Action) void;
const DeinitProto = *const fn (*std.mem.Allocator, *Node) void;

pub const Node = struct {
    data: Action,
};

const ComponentAction = struct {
    deinitFn: ComponentDeinitProto,
};
const ComponentDeinitProto = *const fn (*ComponentNode) void;

pub const ComponentNode = struct {
    data: ComponentAction,
};

/// Return a subslice of `data` containing only those elements
/// that also appear in `filterList`.
fn filterInPlace(comptime T: type, data: []*UINode, filterList: []T) void {

    // For each element in `data`, if it’s in `filterList`,
    // copy it down to `data[write_i++]`.
    for (data) |node| {
        if (contains(T, filterList, node.uuid)) {
            node.show = true;
        } else {
            node.show = false;
        }
    }

    // Now the first write_i elements are the “kept” ones.
}

fn contains(comptime T: type, arr: []T, needle: []const u8) bool {
    for (arr) |v| {
        if (std.mem.eql(u8, v.key, needle)) return true;
    }
    return false;
}

fn isSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => true,
        else => false,
    };
}

pub fn Signal(comptime T: type) type {
    return struct {
        const Self = @This();
        const Subscriber = struct {
            cb: CallbackType,
            sig: ?*Signal(T).Self = null,
            func: ?*const fn (T) T = null,
        };
        const CallbackType = union(enum) {
            with_sig: *const fn (*Signal(T).Self, *const fn (T) T, T) void,
            no_sig: *const fn (T) void,
            // effect: Signature,
        };

        const Signature = struct {
            struct_type: type = void,
        };

        const Inner = struct {
            pub fn callback(sig: *Signal(T).Self, func: *const fn (T) T, new_value: T) void {
                const resp = func(new_value);
                sig.set(resp);
            }
        };

        const SignalClosure = struct {
            signal: *Signal(T).Self = undefined,
            node: ComponentNode = .{ .data = .{
                .deinitFn = deinitFn,
            } },

            pub fn deinitFn(node: *ComponentNode) void {
                const sig_node: *@This() = @alignCast(@fieldParentPtr("node", node));
                sig_node.signal.resetComponentSubs();
            }
        };

        _value: T,
        _parent: *UINode = undefined,
        _subscribers: Set(Subscriber) = undefined,
        _effect_subscribers: std.array_list.Managed(*Node) = undefined,
        _component_subscribers: std.array_list.Managed(*UINode) = undefined,
        allocator_ptr: *std.mem.Allocator,
        _is_batching: bool = false,
        _has_pending_update: bool = false,
        _pending_value: ?T = null,
        _closure: *SignalClosure = undefined,
        _sub_index: usize = 0,

        pub fn init(sig: *Signal(T).Self, value: T) void {
            const allocator_ptr = &Vapor.allocator_global;
            const new_set = Set(Subscriber).init(allocator_ptr);
            const effects = std.array_list.Managed(*Node).init(allocator_ptr.*);
            const components_new_set = std.array_list.Managed(*UINode).init(allocator_ptr.*);

            const sig_closure = allocator_ptr.create(SignalClosure) catch unreachable;
            sig.* = Signal(T).Self{
                ._value = value,
                ._subscribers = new_set,
                ._effect_subscribers = effects,
                ._component_subscribers = components_new_set,
                .allocator_ptr = allocator_ptr,
                ._is_batching = false,
                ._has_pending_update = false,
                ._pending_value = null,
                ._closure = sig_closure,
                ._sub_index = Vapor.component_subscribers.items.len,
            };

            sig_closure.* = .{
                .signal = sig,
            };

            Vapor.component_subscribers.append(
                &sig_closure.node,
            ) catch unreachable;

            return;
        }

        pub fn initv2(value: T, _: *std.mem.Allocator) *Signal(T).Self {
            const allocator_ptr = &Vapor.allocator_global;
            const new_set = Set(Subscriber).init(allocator_ptr);
            const effects = std.array_list.Managed(*Node).init(allocator_ptr.*);
            const components_new_set = std.array_list.Managed(*UINode).init(allocator_ptr.*);

            const sig: *Signal(T).Self = allocator_ptr.create(Signal(T).Self) catch unreachable;
            const sig_closure = allocator_ptr.create(SignalClosure) catch unreachable;
            sig.* = Signal(T).Self{
                ._value = value,
                ._subscribers = new_set,
                ._effect_subscribers = effects,
                ._component_subscribers = components_new_set,
                .allocator_ptr = allocator_ptr,
                ._is_batching = false,
                ._has_pending_update = false,
                ._pending_value = null,
                ._closure = sig_closure,
                ._sub_index = Vapor.component_subscribers.items.len,
            };

            sig_closure.* = .{
                .signal = sig,
            };

            Vapor.component_subscribers.append(
                &sig_closure.node,
            ) catch unreachable;

            return sig;
        }
        pub fn deinit(self: *Self) void {
            _ = Vapor.component_subscribers.orderedRemove(self._sub_index);
            var iter = self._subscribers.iterator();
            while (iter.next()) |sub| {
                if (sub.sig) |sig| {
                    self.allocator_ptr.*.destroy(sig);
                }
            }
            self._subscribers.deinit();

            for (self._effect_subscribers.items) |node| {
                node.data.deinitFn(self.allocator_ptr, node);
            }
            self._effect_subscribers.deinit();
            self.allocator_ptr.destroy(self._closure);
            self.allocator_ptr.destroy(self);
        }

        /// force just force all effects, component and subs to be notified
        /// this doesnt update values, or change, it essentially just cause the render loop to scan for dirty values
        pub fn force(self: *Self) void {
            // If we're in a batching context, only set the pending value
            if (self._is_batching) {
                self._has_pending_update = true;
                self._pending_value = self._value;
                // Still notify subscribers but not components
                // self.notify();
                self.notifyEffects();
            } else {
                self.notify();
                self.notifyEffects();
                self.notifyComponents();
            }
        }

        /// append the current signal value
        /// must be int u32, i32, or f32 type
        /// Then calls notify, notifyEffects, notifyComponents
        pub fn updateElement(self: *Self, index: usize, element: @typeInfo(T).array.child) void {
            // if (@TypeOf(self._value) != std.array_list.Managed(@typeInfo(T).@"struct")) {
            //     return;
            // }

            self._value[index] = element;

            // If we're in a batching context, only set the pending value
            if (self._is_batching) {
                self._has_pending_update = true;
                self._pending_value = self._value;
                // Still notify subscribers but not components
                // self.notify();
                self.notifyEffects();
            } else {
                self.notify();
                self.notifyEffects();
                self.notifyComponents();
            }
        }

        /// append the current signal value
        /// must be int u32, i32, or f32 type
        /// Then calls notify, notifyEffects, notifyComponents
        pub fn getElement(self: *Self, index: usize) @typeInfo(T).array.child {
            return self._value[index];
        }

        /// append the current signal value
        /// must be int u32, i32, or f32 type
        /// Then calls notify, notifyEffects, notifyComponents
        pub fn append(self: *Self, new_item: anytype) void {
            // if (@TypeOf(self._value) != std.array_list.Managed(@typeInfo(T).@"struct")) {
            //     return;
            // }

            try self._value.append(new_item);

            // If we're in a batching context, only set the pending value
            if (self._is_batching) {
                self._has_pending_update = true;
                self._pending_value = self._value;
                // Still notify subscribers but not components
                // self.notify();
                self.notifyEffects();
            } else {
                self.notify();
                self.notifyEffects();
                self.notifyComponents();
            }
        }

        /// increment the current signal value
        /// must be int u32, i32, or f32 type
        /// Then calls notify, notifyEffects, notifyComponents
        pub fn increment(self: *Self) void {
            if (@TypeOf(self._value) != u32 and @TypeOf(self._value) != i32 and @TypeOf(self._value) != f32 and @TypeOf(self._value) != usize) {
                Vapor.printlnErr("increment only takes a u32, i32, f32, and usize", .{});
                return;
            }
            self._value = self._value + 1;

            // If we're in a batching context, only set the pending value
            if (self._is_batching) {
                self._has_pending_update = true;
                self._pending_value = self._value;
                // Still notify subscribers but not components
                // self.notify();
                self.notifyEffects();
            } else {
                self.notify();
                self.notifyEffects();
                self.notifyComponents();
            }
        }

        /// increment the current signal value
        /// must be int u32, i32, or f32 type
        /// Then calls notify, notifyEffects, notifyComponents
        pub fn decrement(self: *Self) void {
            if (@TypeOf(self._value) != u32 and @TypeOf(self._value) != i32 and @TypeOf(self._value) != f32 and @TypeOf(self._value) != usize) {
                Vapor.printlnErr("decrement only takes a u32, i32, f32, and usize", .{});
                return;
            }
            self._value = self._value - 1;

            // If we're in a batching context, only set the pending value
            if (self._is_batching) {
                self._has_pending_update = true;
                self._pending_value = self._value;
                // Still notify subscribers but not components
                // self.notify();
                self.notifyEffects();
            } else {
                self.notify();
                self.notifyEffects();
                self.notifyComponents();
            }
        }

        /// toggle the current signal value
        /// must be bool type
        /// Then calls notify, notifyEffects, notifyComponents
        pub fn toggle(self: *Self) void {
            std.debug.assert(@TypeOf(self._value) == bool);
            self._value = !self._value;

            // If we're in a batching context, only set the pending value
            if (self._is_batching) {
                self._has_pending_update = true;
                self._pending_value = self._value;
                // Still notify subscribers but not components
                // self.notify();
                self.notifyEffects();
            } else {
                self.notify();
                self.notifyEffects();
                self.notifyComponents();
            }
        }

        /// compare the current signal value with another
        /// add other compare functionality, for example equal deep
        pub fn compare(self: *Self, comptime cmp_value: T) bool {
            switch (T) {
                []const u8, []u8, ?[]const u8 => {
                    return std.mem.eql(u8, self._value, cmp_value);
                },
                else => {
                    return cmp_value == self._value;
                },
            }
        }

        /// set the current signal value to the passed argument value
        /// must be of the same type
        /// Then calls notify, notifyEffects, notifyComponents
        pub fn set(self: *Self, new_value: T) void {
            self._value = new_value;

            // If we're in a batching context, only set the pending value
            if (self._is_batching) {
                self._has_pending_update = true;
                self._pending_value = new_value;
                // Still notify subscribers but not components
                // self.notify();
                self.notifyEffects();
            } else {
                self.notify();
                self.notifyEffects();
                self.notifyComponents();
            }
        }

        /// get the current signal value
        pub fn get(self: *Self) T {
            return self._value;
        }

        pub fn getPtr(self: *Self) *T {
            return &self._value;
        }

        // Applies the function call upon the signal value then returns a copy of the old value by ptr
        // the user is responcible for removing this allocation
        // the cloned value is created via create(T)
        // takes a ptr to the singal value type
        fn update(self: *Self, op: *const fn (*T) void) *T {
            const temp = self._value;

            const _temp: *T = self.allocator_ptr.create(T) catch |err| {
                Vapor.printlnSrcErr("Failed to update, could not clone {any}", .{err}, @src());
                return;
            };
            _temp.* = self._value;

            @call(.auto, op, .{&self._value});
            self.notify();
            self.notifyEffects();
            self.notifyComponents();
            return temp;
        }

        /// Callback is run when the value changes
        /// This is just a callback function that is run when a signal changes
        pub fn tether(self: *Self, cb: *const fn (T) void) void {
            self._subscribers.add(.{
                .cb = .{ .no_sig = cb },
            });
        }

        /// Subscribe just takes a node_ptr, this meant fro internal usage and not for usage by the user
        pub fn subscribe(self: *Self, node_ptr: *UINode) void {
            self._component_subscribers.append(node_ptr) catch unreachable;
        }

        pub fn grain(_: *Self, node_ptr: *UINode) void {
            Vapor.grain_element_uuid = node_ptr.uuid;
            Vapor.cycleGrain();
        }

        /// derived takes a signals and a callback function and returns a new signal that can be subscribed to
        pub fn derived(
            self: *Self,
            cb: *const fn (T) T,
        ) !*Signal(T).Self {
            const new_sig = try self.allocator_ptr.create(Signal(T).Self);
            new_sig.* = Signal(T).init(self._value, self.allocator_ptr);

            self._subscribers.add(.{
                .cb = .{ .with_sig = Inner.callback },
                .func = cb,
                .sig = new_sig,
            });
            return new_sig;
        }

        /// effect function is a callback function that runs when a signal value is updated or changed
        /// the effect passed must be a struct with the pub fn effect_callback() attached
        /// this is the function that will be run when the signal is changed
        /// const Effect = struct {
        ///     const Self = @This();
        ///     count: usize = 0,
        ///     pub fn effect_callback(self: *Self) void {
        ///         self.count += 1;
        ///         Vapor.printlnSrc("Count {any}", .{self.count}, @src());
        ///     }
        /// };
        pub fn effect(self: *Self, comptime Effect: type) void {
            if (@typeInfo(Effect) != .@"struct") {
                Vapor.printlnSrcErr("Must be struct type", .{}, @src());
                return;
            }
            if (!std.meta.hasMethod(Effect, "effect_callback")) {
                Vapor.printlnSrcErr("Must have effect_callback() method", .{}, @src());
                return;
            }

            const effect_ptr = self.allocator_ptr.create(Effect) catch unreachable;
            effect_ptr.* = Effect{};
            const Runnable = struct {
                _effect: *Effect,
                run_node: Node = .{ .data = .{
                    .runFn = runFn,
                    .deinitFn = deinitFn,
                } },

                fn runFn(action: *Action) void {
                    const run_node: *Node = @fieldParentPtr("data", action);
                    const runnable: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
                    runnable._effect.effect_callback();
                }

                fn deinitFn(alloctor: *std.mem.Allocator, run_node: *Node) void {
                    const runnable: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
                    alloctor.destroy(runnable._effect);
                    alloctor.destroy(runnable);
                }
            };

            const runnable = self.allocator_ptr.create(Runnable) catch unreachable;
            runnable.* = .{
                ._effect = effect_ptr,
            };

            self._effect_subscribers.append(&runnable.run_node) catch unreachable;
        }

        /// Start a batch of operations - component notifications will be deferred
        pub fn startBatch(self: *Self) void {
            self._is_batching = true;
            self._has_pending_update = false;
            self._pending_value = null;
        }

        /// End a batch of operations and flush pending component notifications
        pub fn endBatch(self: *Self) void {
            self._is_batching = false;

            if (self._has_pending_update) {
                self.notifyComponents();
                self._has_pending_update = false;
                self._pending_value = null;
            }
        }
        /// Notify Components takes a signal ptr and notifies all the component subscribers of said signal,
        /// it iterates through all the component subs, and marks them as dirty for the render loop to update
        /// it also updates the values attached ie if the text is updated
        fn notifyComponents(self: *Self) void {
            for (self._component_subscribers.items) |node| {
                // if (node.state_type == .grain) {
                //     // This is broken!!!!!!!!!!!!!!!!!!!
                //     if (isNodeChild(node)) {
                //         Vapor.println("Found node", .{});
                //         // Vapor.cycleGrain();
                //         Vapor.grain_element_uuid = node.uuid;
                //         return;
                //     }
                //     continue;
                // }
                if (node.type == ._If) {
                    if (@TypeOf(self._value) == bool) {
                        node.show = self._value;
                    }
                } else if (T != []const u8 and node.type == .List and @typeInfo(@TypeOf(self._value)) == .pointer and isSlice(T)) {
                    // filterInPlace(@typeInfo(@TypeOf(self._value)).pointer.child, node.children.items, self._value);
                } else {
                    // while (iter.next()) |node| {
                    switch (T) {
                        usize, u32, i32, f32 => {
                            // node.*.text = std.fmt.allocPrint(self.allocator_ptr.*, "{any}", .{self._value}) catch |err| {
                            //     println("Error {any}\n", .{err});
                            //     unreachable;
                            // };
                            const string_value = std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{self._value}) catch |err| {
                                println("Error {any}\n", .{err});
                                unreachable;
                            };

                            node.*.text = string_value;
                        },
                        []const u8 => {
                            switch (node.type) {
                                .Icon => {
                                    Vapor.println("Setting this value", .{});
                                    node.href = self._value;
                                },
                                else => {
                                    node.*.text = self._value;
                                },
                            }
                        },
                        else => {},
                    }
                }
                self._parent = node;
                // self.markChildrenDirty(node);
            }
            Vapor.cycle();
        }

        /// Notify effect takes a signals ptr and notifies all effect subscribers,
        /// it iterates through all the effect subs, and calls there run funcs attached
        fn notifyEffects(self: *Self) void {
            for (self._effect_subscribers.items) |sub| {
                const runFn = sub.data.runFn;
                runFn(&sub.data);
            }
        }

        /// Notify takes a signals ptr and notifies all the subscribers of said signal,
        /// it iterates through all the subs, and calls there respective callbacks
        /// with or without a signature
        fn notify(self: *Self) void {
            var iter = self._subscribers.iterator();
            while (iter.next()) |sub| {
                switch (sub.cb) {
                    .no_sig => |cb| cb(self._value),
                    .with_sig => |cb| {
                        if (sub.sig != null and sub.func != null) {
                            cb(sub.sig.?, sub.func.?, self._value);
                        }
                    },
                }
            }
        }

        pub fn resetComponentSubs(self: *Self) void {
            self._component_subscribers.clearRetainingCapacity();
        }

        fn markChildrenDirty(self: *Self, node: *UINode) void {
            node.dirty = true;
            for (node.children.items) |child| {
                if (self._parent.type == ._If) {
                    // we set the values to the parent;
                    child.show = node.show;
                }
                self.markChildrenDirty(child);
            }
        }
        // This is broken
        fn isNodeChild(node: *UINode) bool {
            // Here we find the node which was clicked;
            const starting_node = findNodeByUUID(Vapor.current_ctx.root.?, Vapor.current_depth_node_id) orelse return false;
            //Now we search said node if it has children that includes the grain component.
            if (findNodeByUUID(starting_node, node.uuid)) |_| {
                return true;
            }
            return false;
        }
    };
}
pub fn findNodeByUUID(ui_node: *UINode, uuid: []const u8) ?*UINode {
    for (ui_node.children.items) |node| {
        if (std.mem.eql(u8, node.uuid, uuid)) {
            return node;
        }
        return findNodeByUUID(ui_node, uuid);
    }
    return null;
}
