const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const dtree = @import("dtree");
const Nvme = @import("nvme.zig");
const pci = @import("pci.zig");
const rtc = @import("rtc.zig");
const uart = @import("uart.zig");
const Self = @This();

pub const Device = union(enum) {
    pci: pci.Device,
    rtc: rtc.Base,
    uart: uart.Base,
    nvme: Nvme,
};

pub const Bus = union(enum) {
    pci: *pci.bus.Base,

    pub fn enumerate(self: Bus) !std.ArrayList(Entry) {
        return switch (self) {
            .pci => |p| blk: {
                const devs = try p.enumerate();
                defer devs.deinit();

                var list = try std.ArrayList(Entry).initCapacity(devs.allocator, devs.items.len);
                errdefer list.deinit();

                for (devs.items) |d| {
                    if (d.read(.class) == 1 and d.read(.subclass) == 8) {
                        list.appendAssumeCapacity(.{
                            .dev = .{
                                .nvme = .{
                                    .baseAddress = d.readBar(0).?.@"64".mem.addr,
                                },
                            },
                        });
                    } else {
                        list.appendAssumeCapacity(.{
                            .dev = .{
                                .pci = d,
                            },
                        });
                    }
                }

                break :blk list;
            },
        };
    }

    pub fn deinit(self: Bus) void {
        return switch (self) {
            .pci => |p| p.deinit(),
        };
    }
};

pub const Entry = union(enum) {
    bus: Bus,
    dev: Device,

    pub fn deinit(self: Entry) void {
        return switch (self) {
            .bus => |bus| bus.deinit(),
            .dev => {},
        };
    }
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

pub fn enumeratePlatform(self: *const Self) !std.ArrayList(Entry) {
    var list = std.ArrayList(Entry).init(self.allocator);
    errdefer {
        for (list.items) |e| e.deinit();
        list.deinit();
    }

    if (builtin.os.tag == .linux) {
        try list.append(.{
            .bus = .{
                .pci = try pci.bus.Sysfs.create(.{
                    .allocator = self.allocator,
                }),
            },
        });
    } else if (builtin.os.tag == .freestanding and builtin.cpu.arch.isX86()) {
        try list.append(.{
            .bus = .{
                .pci = try pci.bus.x86.create(.{
                    .allocator = self.allocator,
                }),
            },
        });
    }

    for (list.items) |e| {
        if (e == .bus) {
            const sublist = try e.bus.enumerate();
            defer sublist.deinit();
            try list.appendSlice(sublist.items);
        }
    }
    return list;
}

pub fn enumerateDeviceTree(self: *const Self) !std.ArrayList(Entry) {
    var list = std.ArrayList(Entry).init(self.allocator);
    errdefer {
        for (list.items) |e| e.deinit();
        list.deinit();
    }

    if (self.dtb) |dtb| {
        if (@as(?[]const u8, comptime switch (builtin.cpu.arch) {
            .aarch64 => "pcie@",
            .riscv64 => "pci@",
            else => null,
        })) |pciNodeName| {
            if (dtb.findLoose(&.{ "", "soc", pciNodeName, "reg" }) catch null) |pciBlob| {
                const pciBarBlob = try dtb.findLoose(&.{ "", "soc", pciNodeName, "ranges" });
                if (pciBarBlob.len == 84) {
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

        if (dtb.findLoose(&.{ "", "soc", "serial@", "compatible" }) catch null) |serialKind| {
            if (std.meta.stringToEnum(uart.Device, serialKind)) |serialDevice| {
                try list.append(.{
                    .dev = .{
                        .uart = .{
                            .baseAddress = std.mem.readInt(u64, (try dtb.findLoose(&.{ "", "soc", "serial@", "reg" }))[0..8], .big),
                            .vtable = &uart.vtables[@intFromEnum(serialDevice)],
                        },
                    },
                });
            }
        }

        if (dtb.findLoose(&.{ "", "soc", "rtc@", "compatible" }) catch null) |rtcKind| {
            if (std.mem.eql(u8, rtcKind[0..(rtcKind.len - 1)], "google,goldfish-rtc")) {
                try list.append(.{
                    .dev = .{
                        .rtc = rtc.init(.goldfish, .{
                            .baseAddress = std.mem.readInt(u64, (try dtb.findLoose(&.{ "", "soc", "rtc@", "reg" }))[0..8], .big),
                        }),
                    },
                });
            }
        }
    }

    for (list.items) |e| {
        if (e == .bus) {
            const sublist = try e.bus.enumerate();
            defer sublist.deinit();
            try list.appendSlice(sublist.items);
        }
    }
    return list;
}

pub fn enumerate(self: *const Self) !std.ArrayList(Entry) {
    const plat = try self.enumeratePlatform();
    defer plat.deinit();

    const dt = try self.enumerateDeviceTree();
    defer dt.deinit();

    var list = std.ArrayList(Entry).init(self.allocator);
    errdefer list.deinit();

    try list.appendSlice(plat.items);
    try list.appendSlice(dt.items);
    return list;
}
