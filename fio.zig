const builtin = @import("builtin");
const std = @import("std");

// Port IO
pub const port = switch (builtin.cpu.arch) {
    .x86,
    .x86_64,
    => @import("fio/port/x86.zig"),
    else => struct {},
};

// Memory mapped IO
pub const mem = switch (builtin.os.tag) {
    .linux => @import("fio/mem/linux.zig"),
    else => @import("fio/mem/freestanding.zig"),
};

pub const IO = union(enum) {
    port: u16,
    mem: struct {
        allocator: std.mem.Allocator,
        address: usize,
    },

    pub inline fn read(self: IO, comptime T: type) T {
        return switch (self) {
            .port => |p| port.in(T, p),
            .mem => |m| mem.read(T, m.allocator, m.address),
        };
    }

    pub inline fn write(self: IO, data: anytype) void {
        switch (self) {
            .port => |p| port.out(p, data),
            .mem => |m| mem.write(m.address, data),
        }
    }
};

pub const FwCfg = @import("fio/fw-cfg.zig");
pub const pci = @import("fio/pci.zig");
pub const rtc = @import("fio/rtc.zig");
pub const uart = @import("fio/uart.zig");
