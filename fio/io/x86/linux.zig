const builtin = @import("builtin");
const std = @import("std");

var iofd: ?std.fs.File = null;

fn init() std.fs.File.OpenError!void {
    if (iofd == null) {
        iofd = try std.fs.openFileAbsolute("/dev/port", .{
            .mode = .read_write,
        });
    }
}

pub fn in(comptime T: type, port: u16) T {
    init() catch |e| std.debug.panic("Failed to open /dev/io or /dev/iopl: {s}", .{@errorName(e)});

    var buf: [@typeInfo(T).Int.bits]u8 = undefined;
    _ = iofd.?.pread(buf, port) catch |e| std.debug.panic("Failed to read IO: {s}", .{@errorName(e)});
    return std.mem.readInt(T, buf, builtin.cpu.arch.endian());
}

pub fn out(port: u16, data: anytype) void {
    init() catch |e| std.debug.panic("Failed to open /dev/io or /dev/iopl: {s}", .{@errorName(e)});

    var buf: [@typeInfo(@TypeOf(data)).Int.bits]u8 = undefined;
    std.mem.writeInt(@TypeOf(data), buf, data, builtin.cpu.arch.endian());
    _ = iofd.?.pwrite(buf, port) catch |e| std.debug.panic("Failed to write IO: {s}", .{@errorName(e)});
}
