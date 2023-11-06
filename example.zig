const std = @import("std");
const fio = @import("fio");

pub fn main() !void {
    var pci = try fio.pci.bus.Sysfs.create(.{
        .allocator = std.heap.page_allocator,
    });
    defer pci.deinit();

    const devices = try pci.enumerate();
    defer devices.deinit();

    for (devices.items) |dev| {
        std.debug.print("{}\n", .{dev});
    }
}
