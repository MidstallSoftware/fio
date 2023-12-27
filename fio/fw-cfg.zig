const std = @import("std");
const fio = @import("../fio.zig");
const Self = @This();

const File = extern struct {
    size: u32,
    select: u16,
    reserved: u16,
    name: [56]u8,

    pub fn write(self: *const File, fwcfg: *const Self, buff: []const u8) !void {
        return fwcfg.dma(@constCast(buff), (1 << 4) | (1 << 3) | (@as(u32, self.select) << 16));
    }

    pub fn read(self: *const File, fwcfg: *const Self, buff: []u8) !void {
        return fwcfg.dma(buff, (1 << 1) | (1 << 3) | (@as(u32, self.select) << 16));
    }

    pub fn format(self: *const File, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;

        try writer.writeAll(@typeName(File));
        try writer.print("{{ .size = {}, .select = {}, .name = \"{s}\" }}", .{
            std.fmt.fmtIntSizeDec(self.size),
            self.select,
            self.name,
        });
    }
};

const DmaAccess = packed struct {
    ctrl: u32,
    len: u32,
    addr: u64,
};

pub const FileAccess = struct {
    fwcfg: *const Self,
    file: File,

    pub inline fn write(self: *const FileAccess, buff: []const u8) !void {
        return self.file.write(self.fwcfg, buff);
    }

    pub inline fn read(self: *const FileAccess, buff: []u8) !void {
        return self.file.read(self.fwcfg, buff);
    }
};

pub const FileIterator = struct {
    fwcfg: *const Self,
    index: u32,
    count: u32,

    pub fn next(self: *FileIterator) !?File {
        if (self.index == self.count) return null;
        self.index += 1;

        var f = try self.fwcfg.getVariable(File, null);
        f.size = std.mem.toNative(u32, f.size, .big);
        f.select = std.mem.toNative(u16, f.select, .big);
        return f;
    }
};

pub const FileAccessIterator = struct {
    iter: FileIterator,

    pub fn next(self: *FileAccessIterator) !?FileAccess {
        if (try self.iter.next()) |file| {
            return .{
                .fwcfg = self.iter.fwcfg,
                .file = file,
            };
        }
        return null;
    }
};

baseAddress: usize,

pub fn init(baseAddress: usize) !Self {
    const self = Self{
        .baseAddress = baseAddress,
    };

    fio.mem.write(self.baseAddress + 8, std.mem.nativeTo(u16, 0, .big));
    if (@as(u32, @truncate(fio.mem.read(u64, self.baseAddress))) != 0x554D4551) return error.InvalidId;

    fio.mem.write(self.baseAddress + 8, std.mem.nativeTo(u16, 1, .big));
    if (@as(u32, @truncate(fio.mem.read(u64, self.baseAddress))) == 0) return error.DmaFailure;
    if (std.mem.toNative(u64, fio.mem.read(u64, self.baseAddress + 16), .big) != 0x51454d5520434647) return error.DmaFailure;
    return self;
}

pub fn dma(self: *const Self, buf: []u8, ctrl: u32) !void {
    var access = DmaAccess{
        .ctrl = std.mem.nativeTo(u32, ctrl, .big),
        .len = std.mem.nativeTo(u32, @intCast(buf.len), .big),
        .addr = std.mem.nativeTo(u64, @intFromPtr(buf.ptr), .big),
    };

    fio.mem.write(self.baseAddress + 16, std.mem.nativeTo(u64, @intFromPtr(&access), .big));
    asm volatile ("" ::: "memory");

    while (true) {
        const c = std.mem.toNative(u64, access.ctrl, .big);
        if (c & 1 != 0) return error.DmaFailure;
        if (c == 0) return;
    }
}

pub fn getVariable(self: *const Self, comptime T: type, selector: ?u16) !T {
    var result: T = undefined;
    var ctrl: u32 = 1 << 1;

    if (selector) |sel| {
        ctrl |= (1 << 3) | (@as(u32, sel) << 16);
    }

    try self.dma(std.mem.asBytes(&result), ctrl);
    return result;
}

pub fn findFile(self: *const Self, filename: []const u8) !?File {
    var iter = try self.fileIterator();

    while (try iter.next()) |file| {
        if (std.mem.eql(u8, filename, file.name[0..filename.len]) and file.name[filename.len] == 0) return file;
    }
    return null;
}

pub fn accessFile(self: *const Self, filename: []const u8) !?FileAccess {
    if (try self.findFile(filename)) |file| {
        return .{
            .fwcfg = self,
            .file = file,
        };
    }
    return null;
}

pub fn fileIterator(self: *const Self) !FileIterator {
    const fileCount = std.mem.toNative(u32, try self.getVariable(u32, 0x19), .big);
    return .{
        .fwcfg = self,
        .index = 0,
        .count = fileCount,
    };
}

pub fn fileAccessIterator(self: *const Self) !FileAccessIterator {
    return .{
        .iter = try self.fileIterator(),
    };
}

pub fn format(self: *const Self, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = options;

    try writer.writeAll(@typeName(Self));
    try writer.print("{{ .baseAddress = 0x{x} }}", .{
        self.baseAddress,
    });
}
