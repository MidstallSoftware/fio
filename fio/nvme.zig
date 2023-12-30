pub const Mmio = @import("nvme/mmio.zig");

pub const Device = union(enum) {
    mmio: Mmio,

    pub fn deinit(self: Device) void {
        return switch (self) {
            .mmio => |mmio| mmio.deinit(),
        };
    }
};
