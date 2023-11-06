const std = @import("std");
const Allocator = std.mem.Allocator;
const Base = @import("base.zig");
const types = @import("../types.zig");
const Device = @import("../device.zig");
const port = @import("../../port/x86.zig");
const x86 = @This();

pub const Options = struct {
    allocator: Allocator,
    addr: u16 = 0xcf8,
    data: u16 = 0xcfc,
};

allocator: Allocator,
addr: u16,
data: u16,
base: Base,

pub fn create(options: Options) Allocator.Error!*Base {
    const self = try options.allocator.create(x86);
    errdefer options.allocator.destroy(self);

    self.* = .{
        .allocator = options.allocator,
        .addr = options.addr,
        .data = options.data,
        .base = .{
            .ptr = self,
            .vtable = &.{
                .read = read,
                .enumerate = enumerate,
                .deinit = deinit,
            },
        },
    };
    return &self.base;
}

fn read(ctx: *anyopaque, addr: types.Address) u32 {
    const self: *x86 = @ptrCast(@alignCast(ctx));

    const reg: types.Register = @enumFromInt(addr.reg);

    const shift = switch (reg.width()) {
        8 => @as(u5, @intCast(addr.reg & 0x3)) * 8,
        16 => @as(u5, @intCast(addr.reg & 0x2)) * 8,
        32 => 0,
        else => @panic("Invalid width"),
    };

    port.out(self.addr, @as(u32, @bitCast(addr)) & 0xFFFFFFFC);
    return (switch (reg.width()) {
        8 => port.in(u8, self.data),
        16 => port.in(u16, self.data),
        32 => port.in(u32, self.data),
        else => @panic("Invalid width"),
    }) << shift;
}

fn enumerate(ctx: *anyopaque) anyerror!std.ArrayList(Device) {
    const self: *x86 = @ptrCast(@alignCast(ctx));
    var devices = std.ArrayList(Device).init(self.allocator);
    errdefer devices.deinit();

    var _bus: u32 = 0;
    while (_bus < 8) : (_bus += 1) {
        const bus: u8 = @intCast(_bus);
        var _dev: u32 = 0;
        while (_dev < 32) : (_dev += 1) {
            const dev: u5 = @intCast(_dev);

            var entry = Device{
                .base = &self.base,
                .bus = bus,
                .dev = dev,
                .func = 0,
            };

            const nfuncs: u32 = if (entry.read(.headerType) & 0x80 != 0) 8 else 1;
            var _func: u32 = 0;
            while (_func < nfuncs) : (_func += 1) {
                const func: u3 = @intCast(_func);

                entry.func = func;
                if (entry.read(.vendor) == 0xffff) continue;
                try devices.append(entry);
            }
        }
    }
    return devices;
}

fn deinit(ctx: *anyopaque) void {
    const self: *x86 = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}
