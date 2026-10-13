//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

pub const ElementType = @import("root").ElementType;
// Global buffer to store the CSS string for returning to JavaScript
pub fn main() !void {}
