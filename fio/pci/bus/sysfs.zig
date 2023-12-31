const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Base = @import("base.zig");
const types = @import("../types.zig");
const Device = @import("../device.zig");
const Sysfs = @This();

pub const Options = struct {
    allocator: Allocator,
    domain: u32 = 0,
};

allocator: Allocator,
domain: u32,
base: Base,

pub fn create(options: Options) Allocator.Error!*Base {
    const self = try options.allocator.create(Sysfs);
    errdefer options.allocator.destroy(self);

    self.* = .{
        .allocator = options.allocator,
        .domain = options.domain,
        .base = .{
            .ptr = self,
            .type = @typeName(Sysfs),
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

fn read(ctx: *anyopaque, addr: types.Address) u32 {
    const self: *Sysfs = @ptrCast(@alignCast(ctx));

    const reg: types.Register = @enumFromInt(addr.reg);

    const shift = switch (reg.width()) {
        8 => @as(u5, @intCast(addr.reg & 0x3)) * 8,
        16 => @as(u5, @intCast(addr.reg & 0x2)) * 8,
        32 => 0,
        else => @panic("Invalid width"),
    };

    const default: u32 = switch (reg) {
        .device, .vendor, .subsysId, .subsysVendor => 0xffff,
        else => 0,
    };

    const path = std.fmt.allocPrint(self.allocator, "/sys/bus/pci/devices/{d:0>4}:{d:0>2}:{d:0>2}.{d:1}/config", .{
        self.domain,
        addr.bus,
        addr.dev,
        addr.func,
    }) catch |e| std.debug.panic("Failed to allocate PCI device path: {s}", .{@errorName(e)});
    defer self.allocator.free(path);

    const file = std.fs.openFileAbsolute(path, .{}) catch return default << shift;
    defer file.close();

    const metadata = file.metadata() catch return default << shift;

    const buf = file.readToEndAlloc(self.allocator, metadata.size()) catch return default << shift;
    defer self.allocator.free(buf);

    return (switch (reg.width()) {
        8 => buf[addr.reg],
        16 => std.mem.readInt(u16, buf[addr.reg..][0..2], builtin.cpu.arch.endian()),
        32 => std.mem.readInt(u32, buf[addr.reg..][0..4], builtin.cpu.arch.endian()),
        else => @panic("Invalid width"),
    }) << shift;
}

fn write(ctx: *anyopaque, addr: types.Address, value: u32) void {
    _ = ctx;
    _ = addr;
    _ = value;
    // TODO: implement this
}

fn enumerate(ctx: *anyopaque) anyerror!std.ArrayList(Device) {
    const self: *Sysfs = @ptrCast(@alignCast(ctx));
    var devices = std.ArrayList(Device).init(self.allocator);
    errdefer devices.deinit();

    var dir = try std.fs.openDirAbsolute("/sys/bus/pci/devices", .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const domain = try std.fmt.parseInt(u32, entry.name[0..4], 16);
        if (self.domain != domain) continue;

        const bus = try std.fmt.parseInt(u8, entry.name[5..7], 16);
        const dev = try std.fmt.parseInt(u5, entry.name[8..10], 16);
        const func = try std.fmt.parseInt(u3, entry.name[11..12], 16);

        try devices.append(.{
            .base = &self.base,
            .bus = bus,
            .dev = dev,
            .func = func,
        });
    }
    return devices;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Sysfs = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}
