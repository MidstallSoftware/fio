const std = @import("std");
const Self = @This();

pub const Error = error {
    Overrun,
    Parity,
    Framing,
    BreakInput,
};

pub const Writer = std.io.Writer(*Self, Error, write);
pub const Reader = std.io.Reader(*Self, Error, read);

pub const WordLength = enum {
    @"5",
    @"6",
    @"7",
    @"8",
};

pub const StopBits = enum {
    @"1",
    @"2",
};

pub const ParitySelect = enum {
    even,
    odd,
};

pub const Divisor = enum(u16) {
    baud50 = 0x09_00,
    baud300 = 0x01_80,
    baud1200 = 0x00_60,
    baud2400 = 0x00_30,
    baud4800 = 0x00_18,
    baud9600 = 0x00_0c,
    baud19200 = 0x00_06,
    baud38400 = 0x00_03,
    baud57600 = 0x00_02,
    baud115200 = 0x00_01,
};

pub const Options = struct {
    baseAddress: usize,
    wordLength: WordLength,
    stopBits: StopBits,
    parityBit: bool,
    paritySelect: ParitySelect,
    stickyParity: bool,
    breakSet: bool,
    dmaMode: u8,
    divisor: u16,
};

pub const VTable = struct {
    init: *const fn (Options) Error!void,
    write: *const fn (usize, u8) Error!void,
    read: *const fn (usize) Error!u8,
};

baseAddress: usize,
vtable: *const VTable,

pub inline fn init(self: *Self, options: Options) Error!void {
    self.vtable.init(options) catch |err| return err;
    self.baseAddress = options.baseAddress;
}

pub inline fn writeByte(self: *Self, byte: u8) Error!void {
    return self.vtable.write(self.baseAddress, byte);
}

pub inline fn readByte(self: *Self) Error!u8 {
    return self.vtable.read(self.baseAddress);
}

pub fn write(self: *Self, buf: []const u8) Error!usize {
    for (buf) |c| try self.writeByte(c);
    return buf.len;
}

pub fn read(self: *Self, buf: []u8) Error!usize {
    for (buf) |*c| c.* = try self.readByte();
    return buf.len;
}

pub fn writer(self: *Self) Writer {
    return .{ .context = self };
}

pub fn reader(self: *Self) Reader {
    return .{ .context = self };
}
