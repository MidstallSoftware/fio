const builtin = @import("builtin");
const std = @import("std");

pub fn read(comptime T: type, addr: usize) T {
    const ptr = @as(@Type(.{
        .Pointer = .{
            .size = .One,
            .is_const = false,
            .is_volatile = true,
            .alignment = 1,
            .address_space = .generic,
            .child = T,
            .is_allowzero = false,
            .sentinel = null,
        },
    }), @ptrFromInt(addr));
    return ptr.*;
}

pub fn write(addr: usize, data: anytype) void {
    const ptr = @as(@Type(.{
        .Pointer = .{
            .size = .One,
            .is_const = false,
            .is_volatile = true,
            .alignment = 1,
            .address_space = .generic,
            .child = @TypeOf(data),
            .is_allowzero = false,
            .sentinel = null,
        },
    }), @ptrFromInt(addr));
    ptr.* = data;
}
