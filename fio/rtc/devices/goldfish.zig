const Base = @import("../base.zig");
const fio = @import("../../../fio.zig");

pub fn readTime(baseAddress: usize) u64 {
    return fio.mem.read(u64, baseAddress);
}

pub fn setTime(baseAddress: usize, value: u64) void {
    fio.mem.write(baseAddress, value);
}
