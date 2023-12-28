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

pub inline fn readBar(self: Self, i: u8) ?types.Bar {
    return self.base.readBar(self.bus, self.dev, self.func, @intCast(i));
}

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    const headerType = self.read(.headerType);
    const numBars: u8 = switch (headerType & 0x7F) {
        0 => 6,
        1 => 2,
        else => 0,
    };

    try writer.print("{s} {{ .address = {{ .bus = {}, .dev = {}, .func = {} }}", .{
        @typeName(Self),
        self.bus,
        self.dev,
        self.func,
    });

    inline for (@typeInfo(types.Register).Enum.fields) |f| {
        if (!std.mem.startsWith(u8, f.name, "bar")) {
            const value = self.read(@enumFromInt(f.value));
            try writer.print(", .{s} = ", .{f.name});
            try writer.print("0x{x}", .{value});
        }
    }

    for (0..numBars) |i| {
        try writer.print(", .bar{} = {?}", .{ i, self.readBar(@intCast(i)) });
    }

    try writer.writeAll(" }");
}
