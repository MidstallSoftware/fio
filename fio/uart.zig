const std = @import("std");

pub const Base = @import("uart/base.zig");
pub const devices = @import("uart/devices.zig");
pub const Device = std.meta.DeclEnum(devices);

pub fn vTable(kind: Device) Base.VTable {
    inline for (comptime std.meta.fields(Device)) |field| {
        const e: Device = @enumFromInt(field.value);
        if (e == kind) {
            const d = @field(devices, field.name);
            return .{
                .init = d.init,
                .write = d.write,
                .read = d.read,
            };
        }
    }
    unreachable;
}

pub fn init(kind: Device, options: Base.Options) !Base {
    var self = Base {
        .baseAddress = options.baseAddress,
        .vtable = &vTable(kind),
    };

    try self.init(options);
    return self;
}
