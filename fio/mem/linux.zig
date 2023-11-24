const builtin = @import("builtin");
const std = @import("std");

threadlocal var fd: ?std.fs.File = null;

fn init() void {
    if (fd == null) {
        fd = std.fs.openFileAbsolute("/dev/mem", .{
            .mode = .read_write,
        }) catch |e| std.debug.panic("Failed to open /dev/mem: {s}", .{@errorName(e)});
    }
}

pub fn read(comptime T: type, alloc: std.mem.Allocator, addr: usize) T {
    init();
    return switch (@typeInfo(T)) {
        .Int => |i| blk: {
            const buf: [@divExact(i.bits, 8)]u8 = undefined;
            _ = fd.?.pread(buf, addr) catch |e| std.debug.panic("Failed to read 0x{x}: {s}", .{ addr, @errorName(e) });
            break :blk std.mem.readInt(T, buf, builtin.os.cpu.endian());
        },
        .Float => |f| blk: {
            const buf: [@divExact(f.bits, 8)]u8 = undefined;
            _ = fd.?.pread(buf, addr) catch |e| std.debug.panic("Failed to read 0x{x}: {s}", .{ addr, @errorName(e) });
            break :blk @bitCast(std.mem.readInt(u64, buf, builtin.os.cpu.endian()));
        },
        .Array => |a| blk: {
            const buf = alloc.alloc(a.child, a.len) catch @panic("OOM");
            errdefer alloc.free(buf);
            _ = fd.?.pread(buf, addr) catch |e| std.debug.panic("Failed to read 0x{x}: {s}", .{ addr, @errorName(e) });
            break :blk buf[0..a.len];
        },
        else => @compileError("Incompatible type: " ++ @typeName(T)),
    };
}

pub fn write(addr: usize, data: anytype) void {
    init();
    switch (@typeInfo(@TypeOf(data))) {
        .Int => |i| {
            const buf: [@divExact(i.bits, 8)]u8 = undefined;
            std.mem.writeInt(@TypeOf(data), buf, data, builtin.os.cpu.endian());
            _ = fd.?.pwrite(buf, addr) catch |e| std.debug.panic("Failed to write 0x{x}: {s}", .{ addr, @errorName(e) });
        },
        .Float => |f| {
            const buf: [@divExact(f.bits, 8)]u8 = undefined;
            std.mem.writeInt(std.meta.Int(.unsigned, f.bits), buf, @bitCast(data), builtin.os.cpu.endian());
            _ = fd.?.pwrite(buf, addr) catch |e| std.debug.panic("Failed to write 0x{x}: {s}", .{ addr, @errorName(e) });
        },
        .Array => {
            _ = fd.?.pwrite(@ptrCast(data), addr) catch |e| std.debug.panic("Failed to write 0x{x}: {s}", .{ addr, @errorName(e) });
        },
        else => @compileError("Incompatible type: " ++ @typeName(@TypeOf(data))),
    }
}
