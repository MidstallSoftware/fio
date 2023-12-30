const std = @import("std");
const dtree = @import("dtree");
const fio = @import("fio");

const alloc = std.heap.page_allocator;

pub fn main() !void {
    const devMan = try fio.DeviceManager.create(.{
        .allocator = alloc,
        .dtb = blk: {
            const file = std.fs.openFileAbsolute("/sys/firmware/fdt", .{}) catch break :blk null;
            defer file.close();
            break :blk try dtree.Reader.initFile(alloc, file);
        },
    });
    defer devMan.deinit();

    const devices = try devMan.enumerate();
    defer devices.deinit();

    for (devices.items) |dev| {
        std.debug.print("{}\n", .{dev});
    }
}
