const std = @import("std");
const fio = @import("../fio.zig");
const pci = @import("pci.zig");
const Self = @This();

baseAddress: usize,

pub fn init(dev: pci.Device) Self {
    const self = Self{
        .baseAddress = dev.readBar(0).?.@"64".mem.addr,
    };

    var cmd: pci.types.Command = @bitCast(dev.read(.command));
    cmd.master = 1;
    cmd.mem = 1;
    cmd.io = 0;
    dev.write(.command, @bitCast(cmd));
    return self;
}

pub fn version(self: *const Self) u32 {
    return fio.mem.read(u32, self.baseAddress + 0x8);
}

pub fn format(self: *const Self, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = options;

    try writer.writeAll(@typeName(Self));
    try writer.print("{{ .baseAddress = 0x{x}, .version = {} }}", .{
        self.baseAddress,
        self.version(),
    });
}
