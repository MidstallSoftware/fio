pub usingnamespace switch (@import("builtin").os.tag) {
    .freestanding => @import("x86/freestanding.zig"),
    .linux => @import("x86/linux.zig"),
    else => |e| struct {
        pub const in = @compileError("Unsupported OS: " ++ @tagName(e));
        pub const out = @compileError("Unsupported OS: " ++ @tagName(e));
    },
};
