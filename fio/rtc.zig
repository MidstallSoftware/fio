const std = @import("std");

pub const Base = @import("rtc/base.zig");
pub const devices = @import("rtc/devices.zig");
pub const Device = std.meta.DeclEnum(devices);

const vtables = blk: {
    var list: [std.meta.fields(Device).len]Base.VTable = undefined;
    for (std.meta.fields(Device)) |field| {
        const impl = @field(devices, field.name);
        list[field.value] = .{
            .readTime = impl.readTime,
            .setTime = impl.setTime,
        };
    }
    break :blk list;
};

pub fn init(kind: Device, options: Base.Options) Base {
    return .{
        .baseAddress = options.baseAddress,
        .vtable = &vtables[@intFromEnum(kind)],
    };
}
