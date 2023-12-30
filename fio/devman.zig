const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const dtree = @import("dtree");
const pci = @import("pci.zig");
const rtc = @import("rtc.zig");
const uart = @import("uart.zig");
const Self = @This();

pub const Device = union(enum) {
    pci: pci.Device,
    rtc: rtc,
    uart: uart,
};

pub const Bus = union(enum) {
    pci: *pci.bus.Base,

    pub fn deinit(self: Bus) void {
        return switch (self) {
            .pci => |p| p.deinit(),
        };
    }
};

pub const Enumerated = union(enum) {
    bus: Bus,
    dev: Device,
};

pub const Options = struct {
    allocator: Allocator,
    dtb: ?dtree.Reader = null,
};

allocator: Allocator,
dtb: ?dtree.Reader = null,

pub fn create(options: Options) Allocator.Error!*Self {
    const self = try options.allocator.create(Self);
    errdefer options.allocator.destroy(self);

    self.* = .{
        .allocator = options.allocator,
        .dtb = options.dtb,
    };
    return self;
}

pub fn deinit(self: *const Self) void {
    self.allocator.destroy(self);
}

pub fn enumerateDeviceTree(self: *const Self) !std.ArrayList(Enumerated) {
    var list = std.ArrayList(Enumerated).init(self.allocator);
    errdefer list.deinit();

    if (self.dtb) |dtb| {
        if (@as(?[]const u8, comptime switch (builtin.cpu.arch) {
            .aarch64 => "pcie@",
            .riscv64 => "pci@",
            else => null,
        })) |pciNodeName| {
            if (dtb.findLoose(&.{ "", "soc", pciNodeName, "reg" }) catch null) |pciBlob| {
                const pciBarBlob = try dtb.findLoose(&.{ "", "soc", pciNodeName, "ranges" });
                try list.append(.{
                    .bus = .{
                        .pci = try pci.bus.Mmio.create(.{
                            .allocator = self.allocator,
                            .baseAddress = std.mem.readInt(u64, pciBlob[0..8], .big),
                            .size = std.mem.readInt(u64, pciBlob[8..16], .big),
                            .base32 = std.mem.readInt(u64, pciBarBlob[0x28..][0..8], .big),
                            .base64 = std.mem.readInt(u64, pciBarBlob[0x3C..][0..8], .big),
                        }),
                    },
                });
            }
        }
    }
    return list;
}
