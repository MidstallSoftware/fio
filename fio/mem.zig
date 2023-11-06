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
        .Float => @bitCast(std.mem.readInt(usize, ptr, builtin.os.cpu.endian())),
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
