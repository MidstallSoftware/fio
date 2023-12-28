const std = @import("std");
const types = @import("../types.zig");
const Device = @import("../device.zig");
const Self = @This();

pub const VTable = struct {
    read: *const fn (*anyopaque, types.Address) u32,
    write: *const fn (*anyopaque, types.Address, u32) void,
    readBar: ?*const fn (*anyopaque, u8, u5, u3, u8) ?types.Bar = null,
    enumerate: *const fn (*anyopaque) anyerror!std.ArrayList(Device),
    deinit: ?*const fn (*anyopaque) void = null,
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

pub fn readBar(self: *Self, bus: u8, dev: u5, func: u3, i: u8) ?types.Bar {
    if (self.vtable.readBar) |f| return f(self.ptr, bus, dev, func, i);

    return .{ .@"32" = types.Bar32.decode(self.read(.{
        .bus = bus,
        .dev = dev,
        .func = func,
        .reg = 0x10 + i * 4,
    })) };
}

pub inline fn enumerate(self: *Self) anyerror!std.ArrayList(Device) {
    return self.vtable.enumerate(self.ptr);
}

pub inline fn deinit(self: *Self) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
