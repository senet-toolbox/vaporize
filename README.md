# vaporize

Higher-level pieces for [vapor](https://github.com/senet-toolbox/vapor)
apps, written in Zig and rendered with vapor's builders:

- **`MarkDown`**: compiles markdown to a tree and renders it as vapor UI.
  It powers [Assembler](https://github.com/vic-Rokx/assembler-chat)'s
  Planner.
- **`SyntaxHighlighter`**: a Zig code view and editor model. It tokenizes
  and parses the source, groups tokens into styled spans, renders only the
  visible lines, and checks the code itself (unterminated strings, stray
  semicolons and more). It powers Assembler's playground editor.
  `addExternalError(line, column, message)` underlines a token with a
  diagnostic from elsewhere, such as the compiler's, until
  `clearExternalErrors`.
- **Forms**: `Form`, field components and `Validation`, for generated
  forms that check their input.

## Use

vaporize renders with your app's vapor, so it takes vapor from you rather
than pinning its own:

```zig
const vaporize_dep = b.dependency("vaporize", .{ .target = target, .optimize = optimize });
const vaporize_module = vaporize_dep.module("vaporize");
vaporize_module.addImport("vapor", vapor_module);
exe.root_module.addImport("vaporize", vaporize_module);
```

```zig
const Vaporize = @import("vaporize");

var markdown: Vaporize.MarkDown(.{}) = .{};

fn render() void {
    markdown.compile(source) catch return;
    markdown.render() catch return;
}
```

Zig 0.16.0 and vapor 3.x.

## Status

The editor's unit tests in `src/ZigParser.zig` do not run under
`zig build test` yet: they need an app's vapor, with its `config` and
`theme` modules, to build. The editor is exercised end to end by
assembler-backend's browser tests instead.
