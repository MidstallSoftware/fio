const std = @import("std");

pub usingnamespace @import("freestanding.zig");

pub fn ioperm(from: u32, num: u32, turn_on: bool) error{ InputOutput, OutOfMemory, PermissionDenied }!void {
    return switch (std.os.errno(std.os.syscall3(101, from, num, @intFromBool(turn_on)))) {
        .SUCCESS => void,
        .IO => error.InputOutput,
        .NOMEM => error.OutOfMemory,
        .PERM => error.PermissionDenied,
        else => |err| std.os.unexpectedErrno(err),
    };
}
