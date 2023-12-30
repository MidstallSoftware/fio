pub const Mmio = @import("nvme/mmio.zig");

pub const Device = union(enum) {
    mmio: Mmio,
};
