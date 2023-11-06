const std = @import("std");
const Bus = @import("bus/base.zig");
const types = @import("types.zig");
const Self = @This();

base: *Bus,
bus: u8,
dev: u5,
func: u3,

pub fn address(self: Self, comptime reg: types.Register) types.Address {
    return .{
        .bus = self.bus,
        .dev = self.dev,
        .func = self.func,
        .reg = @intFromEnum(reg),
    };
}

pub fn read(self: Self, comptime reg: types.Register) reg.type() {
    const addr = self.address(reg);
    const res = self.base.read(addr);

    const shift = switch (reg.type()) {
        u8 => @as(u5, @intCast(addr.reg & 0x3)) * 8,
        u16 => @as(u5, @intCast(addr.reg & 0x2)) * 8,
        u32 => 0,
        else => |T| @compileError("Invalid type: " ++ @typeName(T)),
    };
    return @as(reg.type(), @truncate(res >> shift));
}

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    try writer.print("{s} {{ .address = {{ .bus = {}, .dev = {}, .func = {} }}", .{
        @typeName(Self),
        self.bus,
        self.dev,
        self.func,
    });

    inline for (@typeInfo(types.Register).Enum.fields) |f| {
        try writer.print(", .{s} = 0x{x}", .{ f.name, self.read(@enumFromInt(f.value)) });
    }

    try writer.writeAll(" }");
}
