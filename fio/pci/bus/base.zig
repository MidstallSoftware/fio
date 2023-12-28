const std = @import("std");
const types = @import("../types.zig");
const Device = @import("../device.zig");
const Self = @This();

pub const VTable = struct {
    read: *const fn (*anyopaque, types.Address) u32,
    write: *const fn (*anyopaque, types.Address, u32) void,
    enumerate: *const fn (*anyopaque) anyerror!std.ArrayList(Device),
    deinit: ?*const fn (*anyopaque) void,
};

vtable: *const VTable,
ptr: *anyopaque,
type: []const u8,

pub inline fn read(self: *Self, addr: types.Address) u32 {
    return self.vtable.read(self.ptr, addr);
}

pub inline fn write(self: *Self, addr: types.Address, value: u32) void {
    return self.vtable.write(self.ptr, addr, value);
}

pub inline fn enumerate(self: *Self) anyerror!std.ArrayList(Device) {
    return self.vtable.enumerate(self.ptr);
}

pub inline fn deinit(self: *Self) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
