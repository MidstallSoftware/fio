const std = @import("std");
const fio = @import("../fio.zig");
const pci = @import("pci.zig");
const Self = @This();

pub const Version = packed struct(u32) {
    tertiary: u8,
    minor: u8,
    major: u16,
};

pub const ControllerStatus = packed struct(u32) {
    ready: u1,
    fatalStatus: u1,
    shutdownStatus: u2,
    subsysReset: u1,
    procPaused: u1,
    shutdownType: u1,
    reserved: u25,
};

baseAddress: usize,

pub fn init(self: *Self) void {
    while (self.controllerStatus().ready != 0) {}
}

pub fn controllerStatus(self: *const Self) ControllerStatus {
    return @bitCast(fio.mem.read(u32, self.baseAddress + 0x1C));
}

pub fn version(self: *const Self) std.SemanticVersion {
    const value: Version = @bitCast(fio.mem.read(u32, self.baseAddress + 0x8));
    return .{
        .major = value.major,
        .minor = value.minor,
        .patch = value.tertiary,
    };
}

pub fn format(self: *const Self, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = options;

    try writer.writeAll(@typeName(Self));
    try writer.print("{{ .baseAddress = 0x{x}, .controllerStatus = {}, .version = {} }}", .{
        self.baseAddress,
        self.controllerStatus(),
        self.version(),
    });
}
