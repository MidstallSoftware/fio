const std = @import("std");
const Base = @import("../base.zig");

fn setFcr(baseAddress: usize, dmaMode: u8) void {
    const ptr: *volatile u8 = @ptrFromInt(baseAddress + 2);
    ptr.* = @as(usize, 1) << (dmaMode << 3);
}

fn setLcr(
    baseAddress: usize,
    wordLength: Base.WordLength,
    stopBits: Base.StopBits,
    parityBit: bool,
    paritySelect: Base.ParitySelect,
    stickyParity: bool,
    breakSet: bool,
    dlabSet: bool,
) void {
    const ptr: *volatile u8 = @ptrFromInt(baseAddress + 3);
    ptr.* = @as(u8, @intFromEnum(wordLength))
        | (@as(u8, @intFromEnum(stopBits)) << 2)
        | (if (parityBit) @as(u8, 1) else @as(u8, 0) << 3)
        | (@as(u8, @intFromEnum(paritySelect)) << 4)
        | (if (stickyParity) @as(u8, 1) else @as(u8, 0) << 5)
        | (if (breakSet) @as(u8, 1) else @as(u8, 0) << 6)
        | (if (dlabSet) @as(u8, 1) else @as(u8, 0) << 7);
}

pub fn init(options: Base.Options) Base.Error!void {
    setLcr(
        options.baseAddress,
        options.wordLength,
        options.stopBits,
        options.parityBit,
        options.paritySelect,
        options.stickyParity,
        options.breakSet,
        true,
    );

    const ptr: *volatile u16 = @ptrFromInt(options.baseAddress);
    ptr.* = options.divisor;

    setLcr(
        options.baseAddress,
        options.wordLength,
        options.stopBits,
        options.parityBit,
        options.paritySelect,
        options.stickyParity,
        options.breakSet,
        false,
    );
}

pub fn write(baseAddress: usize, byte: u8) Base.Error!void {
    const ptr: *volatile u8 = @ptrFromInt(baseAddress);
    ptr.* = byte;
}

pub fn read(baseAddress: usize) Base.Error!u8 {
    const ptr: *volatile u8 = @ptrFromInt(baseAddress);
    const ptrReady: *volatile u8 = @ptrFromInt(baseAddress + 5);

    while (ptrReady.* & 1 == 0) {}
    return ptr.*;
}
