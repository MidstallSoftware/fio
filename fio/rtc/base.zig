const std = @import("std");
const Self = @This();

pub const Options = struct {
    baseAddress: usize,
};

pub const VTable = struct {
    readTime: *const fn (usize) u64,
    setTime: *const fn (usize, u64) void,
};

vtable: *const VTable,
baseAddress: usize,

pub inline fn readTime(self: *Self) u64 {
    return self.vtable.readTime(self.baseAddress);
}

pub inline fn setTime(self: *Self, value: u64) void {
    return self.vtable.setTime(self.baseAddress, value);
}
