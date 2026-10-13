const std = @import("std");
const Vapor = @import("Vapor.zig");
const TimingFunction = @import("types.zig").TimingFunction;

pub const TransformType = enum {
    none,
    translateX,
    translateY,
    scale,
    scaleY,
    scaleX,
    opacity,
};

pub const Specs = struct {
    tag: []const u8 = "",
    delay: f32 = 0,
    // direction: AnimDir = .normal,
    duration: f32 = 0,
    // iteration_count: Iteration = .count(1),
    // timing_function: TimingFunction = .ease,
};

pub const Animation = @This();
_name: []const u8,
_type: TransformType,
from_value: f32 = 0,
to_value: f32 = 1,
duration_ms: u32 = 1000,
delay_ms: u32 = 0,
easing_fn: Easing = .linear,
pub fn init(name: []const u8, transform_type: TransformType) Animation {
    return Animation{
        ._name = name,
        ._type = transform_type,
    };
}

pub fn duration(self: Animation, milliseconds: u32) Animation {
    var new_animation = self;
    new_animation.duration_ms = milliseconds;
    return new_animation;
}

pub fn delay(self: Animation, milliseconds: f32) Animation {
    var new_animation = self;
    new_animation.delay_ms = milliseconds;
    return new_animation;
}

pub fn from(self: Animation, from_value: f32) Animation {
    var new_animation = self;
    new_animation.from_value = from_value;
    return new_animation;
}

pub fn to(self: Animation, to_value: f32) Animation {
    var new_animation = self;
    new_animation.to_value = to_value;
    return new_animation;
}

pub fn easing(self: Animation, easing_value: Easing) Animation {
    var new_animation = self;
    new_animation.easing_fn = easing_value;
    return new_animation;
}

pub fn build(self: Animation) void {
    Vapor.animations.put(self._name, self) catch |err| {
        Vapor.println("Could not create animation {any}\n", .{err});
    };
}

// pub const Motion = struct {
//     tag: []const u8,
//     from: Transform = .{},
//     to: Transform = .{},
// };

/// Defines the easing curve for an animation's timing.
/// This would map to a function that calculates the progress.
pub const Easing = enum {
    linear,
    easeIn,
    easeOut,
    easeInOut,
};

//
// pub const Transform = struct {
//     scale_size: f32 = 1,
//     dist: f32 = 0,
//     type: TransformType = .none,
//     opacity: ?u32 = null,
//     height: ?Vapor.Types.Sizing = null,
//     width: ?Vapor.Types.Sizing = null,
// };
//
// pub const AnimDir = enum {
//     normal,
//     reverse,
//     forwards,
//     pingpong,
// };
//
// const Iteration = struct {
//     iter_count: u32 = 1,
//     pub fn infinite() Iteration {
//         return .{
//             .iter_count = 0,
//         };
//     }
//     pub fn count(c: u32) Iteration {
//         return .{
//             .iter_count = c,
//         };
//     }
// };
//
// pub const Motion = struct {
//     tag: []const u8,
//     from: Transform = .{},
//     to: Transform = .{},
// };
//

//
// const Animation = @This();
// motion: Motion = undefined,
// specs: Specs = undefined,
//
// pub fn createMotion(specs_tag: []const u8, motion: Motion) void {
//     std.debug.assert(std.mem.eql(u8, specs_tag, motion.tag));
//     Vapor.motions.append(motion) catch |err| {
//         Vapor.println("Could not create motion {any}\n", .{err});
//     };
// }
//
// const Fade = struct {};
//
// pub const FadeInOut = struct {
//     exit_animation: []const u8 = "fadeOut",
//     child_styles: []const Vapor.Types.ChildStyle = &.{
//         .{
//             .style_id = "fade-in",
//             .animation = Animation.Specs{
//                 .duration_s = 0.5,
//                 .tag = "fadeIn",
//                 .direction = .forwards,
//             },
//         },
//         .{
//             .style_id = "fade-out",
//             .animation = Animation.Specs{
//                 .duration_s = 0.5,
//                 .tag = "fadeOut",
//                 .direction = .forwards,
//             },
//         },
//     },
//     pub fn init() void {
//         createMotion("fadeIn", .{
//             .tag = "fadeIn",
//             .from = .{ .type = .translateY, .dist = 40, .opacity = 0 },
//             .to = .{ .type = .translateY, .dist = 0, .opacity = 1 },
//         });
//         createMotion("fadeOut", .{
//             .tag = "fadeOut",
//             .from = .{ .type = .translateY, .dist = 0, .opacity = 1 },
//             .to = .{ .type = .translateY, .dist = 40, .opacity = 0 },
//         });
//     }
// };
//
// pub const SlideInOut = struct {
//     exit_animation: []const u8 = "slideOut",
//     child_styles: []const Vapor.Types.ChildStyle = &.{
//         .{
//             .style_id = "slide-in",
//             .animation = Animation.Specs{
//                 .duration_s = 0.2,
//                 .tag = "slideIn",
//                 .direction = .forwards,
//             },
//         },
//         .{
//             .style_id = "slide-out",
//             .animation = Animation.Specs{
//                 .duration_s = 0.2,
//                 .tag = "slideOut",
//                 .direction = .forwards,
//             },
//         },
//     },
//     pub fn init() void {
//         createMotion("slideIn", .{
//             .tag = "slideIn",
//             .from = .{
//                 .height = .percent(0),
//             },
//             .to = .{
//                 .height = .percent(1),
//             },
//         });
//         createMotion("slideOut", .{
//             .tag = "slideOut",
//             .from = .{
//                 .height = .percent(1),
//             },
//             .to = .{
//                 .height = .percent(0),
//             },
//         });
//     }
// };
//
// pub const FoldInOut = struct {
//     exit_animation: []const u8 = "foldDown",
//     child_styles: []const Vapor.Types.ChildStyle = &.{
//         .{
//             .style_id = "fold-up",
//             .animation = Animation.Specs{
//                 .duration_s = 0.2,
//                 .tag = "foldUp",
//                 .direction = .forwards,
//             },
//         },
//         .{
//             .style_id = "fold-out",
//             .animation = Animation.Specs{
//                 .duration_s = 0.2,
//                 .tag = "foldDown",
//                 .direction = .forwards,
//             },
//         },
//     },
//     pub fn init() void {
//         createMotion("foldUp", .{
//             .tag = "foldUp",
//             .from = .{
//                 .type = .scaleY,
//                 .scale_size = 0,
//                 .opacity = 0,
//             },
//             .to = .{
//                 .type = .scaleY,
//                 .scale_size = 1,
//                 .opacity = 1,
//             },
//         });
//         createMotion("foldDown", .{
//             .tag = "foldDown",
//             .from = .{
//                 .type = .scaleY,
//                 .scale_size = 1,
//                 .opacity = 1,
//             },
//             .to = .{
//                 .type = .scaleY,
//                 .scale_size = 0,
//                 .opacity = 0,
//             },
//         });
//     }
// };
//
// const TransitionType = enum {
//     custom,
//     fade,
//     fadeInOutY,
//     slideInOutY,
//     foldUpDownY,
// };
//
// pub inline fn CustomFlexBox(style: Vapor.Style) fn (void) void {
//     const local = struct {
//         fn CloseElement(_: void) void {
//             _ = Vapor.current_ctx.close();
//             return;
//         }
//         fn ConfigureElement(elem_decl: Vapor.Types.ElementDeclaration) *const fn (void) void {
//             _ = Vapor.current_ctx.configure(elem_decl);
//             return CloseElement;
//         }
//     };
//
//     const elem_decl = Vapor.Types.ElementDeclaration{
//         .style = style,
//         .dynamic = .animation,
//         .elem_type = .FlexBox,
//     };
//
//     _ = Vapor.current_ctx.open(elem_decl) catch |err| {
//         Vapor.println("{any}\n", .{err});
//     };
//     _ = local.ConfigureElement(elem_decl);
//     return local.CloseElement;
// }
//
// pub inline fn FlexBox(style: Vapor.Style, transition_type: TransitionType) fn (void) void {
//     const local = struct {
//         fn CloseElement(_: void) void {
//             _ = Vapor.current_ctx.close();
//             return;
//         }
//         fn ConfigureElement(elem_decl: Vapor.Types.ElementDeclaration) *const fn (void) void {
//             _ = Vapor.current_ctx.configure(elem_decl);
//             return CloseElement;
//         }
//     };
//
//     var elem_decl = Vapor.Types.ElementDeclaration{
//         .style = style,
//         .dynamic = .animation,
//         .elem_type = .FlexBox,
//     };
//
//     switch (transition_type) {
//         .custom => {},
//         .fade => {},
//         .fadeInOutY => {
//             const tr = FadeInOut{};
//             elem_decl.style.child_styles = tr.child_styles;
//             elem_decl.style.exit_animation = tr.exit_animation;
//         },
//         .slideInOutY => {
//             const tr = SlideInOut{};
//             elem_decl.style.child_styles = tr.child_styles;
//             elem_decl.style.exit_animation = tr.exit_animation;
//         },
//         .foldUpDownY => {
//             const tr = FoldInOut{};
//             elem_decl.style.child_styles = tr.child_styles;
//             elem_decl.style.exit_animation = tr.exit_animation;
//         },
//     }
//
//     _ = Vapor.current_ctx.open(elem_decl) catch |err| {
//         Vapor.println("{any}\n", .{err});
//     };
//     _ = local.ConfigureElement(elem_decl);
//     return local.CloseElement;
// }
