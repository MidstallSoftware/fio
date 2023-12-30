const std = @import("std");

pub const Base = @import("uart/base.zig");
pub const devices = @import("uart/devices.zig");
pub const Device = enum { ns16550a };
//pub const Device = std.meta.DeclEnum(devices);

pub const vtables = blk: {
    var list: [std.meta.fields(Device).len]Base.VTable = undefined;
    for (std.meta.fields(Device)) |field| {
        const impl = @field(devices, field.name);
        list[field.value] = .{
            .init = impl.init,
            .write = impl.write,
            .read = impl.read,
        };
    }
    break :blk list;
};

pub fn init(kind: Device, options: Base.Options) !Base {
    var self = Base{
        .baseAddress = options.baseAddress,
        .vtable = &vtables[@intFromEnum(kind)],
    };

    try self.init(options);
    return self;
}
