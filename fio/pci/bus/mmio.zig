const std = @import("std");
const Allocator = std.mem.Allocator;
const fio = @import("../../../fio.zig");
const Base = @import("base.zig");
const types = @import("../types.zig");
const Device = @import("../device.zig");
const Mmio = @This();

pub const Options = struct {
    allocator: Allocator,
    baseAddress: usize,
    size: usize,
};

allocator: Allocator,
baseAddress: usize,
size: usize,
base: Base,

pub fn create(options: Options) Allocator.Error!*Base {
    const self = try options.allocator.create(Mmio);
    errdefer options.allocator.destroy(self);

    self.* = .{
        .allocator = options.allocator,
        .baseAddress = options.baseAddress,
        .size = options.size,
        .base = .{
            .ptr = self,
            .vtable = &.{
                .read = read,
                .write = write,
                .enumerate = enumerate,
                .deinit = deinit,
            },
        },
    };
    return &self.base;
}

fn mmioAddress(self: *Mmio, addr: types.Address) usize {
    return self.baseAddress + (@as(usize, addr.dev) << 15 | @as(usize, addr.func) << 12 | @as(usize, addr.reg));
}

fn read(ctx: *anyopaque, addr: types.Address) u32 {
    const self: *Mmio = @ptrCast(@alignCast(ctx));

    const reg: types.Register = @enumFromInt(addr.reg);

    const shift = switch (reg.width()) {
        8 => @as(u5, @intCast(addr.reg & 0x3)) * 8,
        16 => @as(u5, @intCast(addr.reg & 0x2)) * 8,
        32 => 0,
        else => @panic("Invalid width"),
    };

    return (switch (reg.width()) {
        8 => fio.mem.read(u8, self.mmioAddress(addr)),
        16 => fio.mem.read(u16, self.mmioAddress(addr)),
        32 => fio.mem.read(u32, self.mmioAddress(addr)),
        else => @panic("Invalid width"),
    }) << shift;
}

fn write(ctx: *anyopaque, addr: types.Address, value: u32) void {
    const self: *Mmio = @ptrCast(@alignCast(ctx));

    const reg: types.Register = @enumFromInt(addr.reg);

    return switch (reg.width()) {
        8 => fio.mem.write(self.mmioAddress(addr), @as(u8, @intCast(value))),
        16 => fio.mem.write(self.mmioAddress(addr), @as(u16, @intCast(value))),
        32 => fio.mem.write(self.mmioAddress(addr), value),
        else => @panic("Invalid width"),
    };
}

fn enumerate(ctx: *anyopaque) anyerror!std.ArrayList(Device) {
    const self: *Mmio = @ptrCast(@alignCast(ctx));

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
    const self: *Mmio = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}
