const builtin = @import("builtin");
const std = @import("std");

pub fn read(comptime T: type, addr: usize) T {
    const ptr = @as(@Type(.{
        .Pointer = .{
            .size = .Slice,
            .is_const = false,
            .is_volatile = true,
            .alignment = 0,
            .address_space = .generic,
            .child = T,
            .is_allowzero = false,
            .sentinel = null,
        },
    }), @ptrFromInt(addr));
    return switch (@typeInfo(T)) {
        .Int => std.mem.readInt(T, ptr, builtin.os.cpu.endian()),
        .Float => |f| @bitCast(std.mem.readInt(std.meta.Int(.unsigned, f.bits), ptr, builtin.os.cpu.endian())),
        .Array => |a| blk: {
            var buf: [a.len]a.child = undefined;
            @memcpy(std.mem.asBytes(&buf), ptr);
            break :blk buf;
        },
        else => @compileError("Incompatible type: " ++ @typeName(T)),
    };
}

pub fn write(addr: usize, data: anytype) void {
    const ptr = @as(@Type(.{
        .Pointer = .{
            .size = .Slice,
            .is_const = false,
            .is_volatile = true,
            .alignment = 0,
            .address_space = .generic,
            .child = @TypeOf(data),
            .is_allowzero = false,
            .sentinel = null,
        },
    }), @ptrFromInt(addr));
    @memcpy(ptr, data);
}
