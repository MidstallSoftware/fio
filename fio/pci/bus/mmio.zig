const std = @import("std");
const Allocator = std.mem.Allocator;
const fio = @import("../../../fio.zig");
const Base = @import("base.zig");
const types = @import("../types.zig");
const Device = @import("../device.zig");
const Mmio = @This();

const BarMem64Entry = struct {
    bus: u8,
    dev: u5,
    func: u3,
    i: u8,
    value: types.Bar64.BarMem64,
};

pub const Options = struct {
    allocator: Allocator,
    baseAddress: usize,
    size: usize,
    base32: usize,
    base64: usize,
};

allocator: Allocator,
baseAddress: usize,
size: usize,
base32: usize,
base64: usize,
base: Base,

pub fn create(options: Options) Allocator.Error!*Base {
    const self = try options.allocator.create(Mmio);
    errdefer options.allocator.destroy(self);

    self.* = .{
        .allocator = options.allocator,
        .baseAddress = options.baseAddress,
        .size = options.size,
        .base32 = options.base32,
        .base64 = options.base64,
        .base = .{
            .ptr = self,
            .type = @typeName(Mmio),
            .vtable = &.{
                .read = read,
                .write = write,
                .readBar = readBar,
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

fn readBar(ctx: *anyopaque, bus: u8, dev: u5, func: u3, i: u8) ?types.Bar {
    const self: *Mmio = @ptrCast(@alignCast(ctx));

    const bits = self.base.read(.{
        .bus = bus,
        .dev = dev,
        .func = func,
        .reg = 0x10 + (i * 4),
    });

    if (bits & 1 != 0) {
        return .{ .@"32" = types.Bar32.decode(bits) };
    }

    const list = self.enumerateBar() catch return null;
    defer list.deinit();

    for (list.items) |entry| {
        if (entry.bus == bus and entry.dev == dev and entry.func == func and entry.i == i) {
            return .{ .@"64" = .{ .mem = entry.value } };
        }
    }
    return null;
}

fn enumerateBar(self: *Mmio) !std.ArrayList(BarMem64Entry) {
    const devices = try self.base.enumerate();
    defer devices.deinit();

    var list = std.ArrayList(BarMem64Entry).init(self.allocator);
    errdefer list.deinit();

    var base32 = self.base32;
    var base64 = self.base64;

    for (devices.items) |dev| {
        const headerType = dev.read(.headerType);
        const numBars: u8 = switch (headerType & 0x7F) {
            0 => 6,
            1 => 2,
            else => 0,
        };

        var i: u8 = 0;
        while (i < numBars) : (i += 1) {
            const bits = self.base.read(.{
                .bus = dev.bus,
                .dev = dev.dev,
                .func = dev.func,
                .reg = 0x10 + (i * 4),
            });

            self.base.write(.{
                .bus = dev.bus,
                .dev = dev.dev,
                .func = dev.func,
                .reg = 0x10 + (i * 4),
            }, @as(u32, 0xFFFFFFFF));

            const value = self.base.read(.{
                .bus = dev.bus,
                .dev = dev.dev,
                .func = dev.func,
                .reg = 0x10 + (i * 4),
            });

            if (bits & 1 != 0) continue;

            const is64 = ((value & 0b110) >> 1) == 2;

            var size = @as(u64, value & 0xFFFFFFF0);
            if (is64) {
                self.base.write(.{
                    .bus = dev.bus,
                    .dev = dev.dev,
                    .func = dev.func,
                    .reg = 0x10 + ((i + 1) * 4),
                }, @as(u32, 0xFFFFFFFF));

                size |= @as(u64, self.base.read(.{
                    .bus = dev.bus,
                    .dev = dev.dev,
                    .func = dev.func,
                    .reg = 0x10 + ((i + 1) * 4),
                })) << 32;
            }

            size = ~size +% 1;

            if (!is64) size &= (1 << 32) - 1;
            if (size == 0) continue;

            const base = if (is64) &base64 else &base32;

            base.* += size - 1;
            base.* &= ~(size - 1);

            try list.append(.{
                .bus = dev.bus,
                .dev = dev.dev,
                .func = dev.func,
                .i = i,
                .value = .{
                    .bits = bits,
                    .size = size,
                    .addr = base.*,
                },
            });

            self.base.write(.{
                .bus = dev.bus,
                .dev = dev.dev,
                .func = dev.func,
                .reg = 0x10 + i * 4,
            }, @as(u32, @truncate(base.*)) | bits);

            if (is64) {
            self.base.write(.{
                .bus = dev.bus,
                .dev = dev.dev,
                .func = dev.func,
                .reg = 0x10 + (i + 1) * 4,
            }, @as(u32, @truncate(base.* >> 32)));
            }

            self.base.write(.{
                .bus = dev.bus,
                .dev = dev.dev,
                .func = dev.func,
                .reg = 4,
            }, @as(u16, 1 << 1));

            base.* += size;
            i += @intFromBool(is64);
        }
    }
    return list;
}

fn enumerate(ctx: *anyopaque) anyerror!std.ArrayList(Device) {
    const self: *Mmio = @ptrCast(@alignCast(ctx));

    var devices = std.ArrayList(Device).init(self.allocator);
    errdefer devices.deinit();

    var _dev: u32 = 0;
    while (_dev < 32) : (_dev += 1) {
        const dev: u5 = @intCast(_dev);

        var entry = Device{
            .base = &self.base,
            .bus = 0,
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
    return devices;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Mmio = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}
