// Port IO
pub const port = switch (@import("builtin").cpu.arch) {
    .x86,
    .x86_64,
    => @import("fio/port/x86.zig"),
    else => struct {},
};

// Memory mapped IO
pub const mem = @import("fio/mem.zig");

pub const IO = union(enum) {
    port: u16,
    mem: usize,

    pub inline fn read(self: IO, comptime T: type) T {
        return switch (self) {
            .port => |p| port.in(T, p),
            .mem => |a| mem.read(T, a),
        };
    }

    pub inline fn write(self: IO, data: anytype) void {
        switch (self) {
            .port => |p| port.out(p, data),
            .mem => |a| mem.write(a, data),
        }
    }
};
