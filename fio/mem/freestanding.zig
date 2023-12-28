const builtin = @import("builtin");
const std = @import("std");

pub fn read(comptime T: type, addr: usize) T {
    const ptr: *const volatile T = @ptrFromInt(addr);
    return ptr.*;
}

pub fn write(addr: usize, data: anytype) void {
    const T = @TypeOf(data);
    const ptr: *volatile T = @ptrFromInt(addr);
    ptr.* = data;
}
