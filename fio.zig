pub const io = switch (@import("builtin").cpu.arch) {
    .x86, .x86_64, => @import("fio/io/x86.zig"),
    else => struct {},
};
