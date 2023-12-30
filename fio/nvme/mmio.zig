const std = @import("std");
const fio = @import("../../fio.zig");
const pci = @import("../pci.zig");
const types = @import("types.zig");
const Self = @This();

allocator: std.mem.Allocator,
device: pci.Device,
completionQueue: []u64 = &.{},
submissionQueue: []u64 = &.{},

pub fn init(self: *Self, queueSize: u12) !void {
    while (self.controllerStatus().ready != 0) {}

    self.completionQueue = try self.allocator.alloc(u64, queueSize);
    errdefer self.allocator.free(self.completionQueue);
    @memset(self.completionQueue, 0);

    self.submissionQueue = try self.allocator.alloc(u64, queueSize);
    errdefer self.allocator.free(self.submissionQueue);
    @memset(self.submissionQueue, 0);

    var adminQueueAttribs = self.getAdminQueueAttribs();
    adminQueueAttribs.submissionQueueSize = @intCast(self.submissionQueue.len);
    adminQueueAttribs.completionQueueSize = @intCast(self.completionQueue.len);
    self.setAdminQueueAttribs(adminQueueAttribs);

    var adminSubmissionQueue = self.getAdminSubmissionQueue();
    adminSubmissionQueue.addr = @intCast(@intFromPtr(self.submissionQueue.ptr));
    self.setAdminSubmissionQueue(adminSubmissionQueue);

    var adminCompletionQueue = self.getAdminCompletionQueue();
    adminCompletionQueue.addr = @intCast(@intFromPtr(self.completionQueue.ptr));
    self.setAdminCompletionQueue(adminCompletionQueue);

    const cap = self.capabilities();
    var cfg = self.getControllerConfig();
    cfg.enable = 1;

    if (cap.commandSetSupported & (1 << 7) != 0) {
        cfg.ioCommandSetSel = 0b111;
    } else if (cap.commandSetSupported & (1 << 6) != 0) {
        cfg.ioCommandSetSel = 0b110;
    } else if (cap.commandSetSupported & (1 << 6) == 0 and cap.commandSetSupported & (1 << 0) != 0) {
        cfg.ioCommandSetSel = 0;
    }

    self.setControllerConfig(cfg);

    while (self.controllerStatus().ready != 0) {}
}

pub fn deinit(self: *Self) void {
    if (self.completionQueue.len > 0) self.allocator.free(self.completionQueue);
    if (self.submissionQueue.len > 0) self.allocator.free(self.submissionQueue);

    var cfg = self.getControllerConfig();
    cfg.enable = 0;
    self.setControllerConfig(cfg);
}

pub fn baseAddress(self: *const Self) usize {
    return self.device.readBar(0).?.@"64".mem.addr;
}

pub fn capabilities(self: *const Self) types.Capabilities {
    return @bitCast(fio.mem.read(u64, self.baseAddress()));
}

pub fn controllerStatus(self: *const Self) types.ControllerStatus {
    return @bitCast(fio.mem.read(u32, self.baseAddress() + 0x1C));
}

pub fn version(self: *const Self) std.SemanticVersion {
    const value: types.Version = @bitCast(fio.mem.read(u32, self.baseAddress() + 0x8));
    return .{
        .major = value.major,
        .minor = value.minor,
        .patch = value.tertiary,
    };
}

pub fn getAdminQueueAttribs(self: *const Self) types.AdminQueueAttributes {
    return @bitCast(fio.mem.read(u32, self.baseAddress() + 0x24));
}

pub fn setAdminQueueAttribs(self: *const Self, value: types.AdminQueueAttributes) void {
    fio.mem.write(self.baseAddress() + 0x24, @as(u32, @bitCast(value)));
}

pub fn getAdminSubmissionQueue(self: *const Self) types.AdminQueueBaseAddress {
    return @bitCast(fio.mem.read(u64, self.baseAddress() + 0x28));
}

pub fn setAdminSubmissionQueue(self: *const Self, value: types.AdminQueueBaseAddress) void {
    fio.mem.write(self.baseAddress() + 0x28, @as(u64, @bitCast(value)));
}

pub fn getAdminCompletionQueue(self: *const Self) types.AdminQueueBaseAddress {
    return @bitCast(fio.mem.read(u64, self.baseAddress() + 0x30));
}

pub fn setAdminCompletionQueue(self: *const Self, value: types.AdminQueueBaseAddress) void {
    fio.mem.write(self.baseAddress() + 0x30, @as(u64, @bitCast(value)));
}

pub fn getControllerConfig(self: *const Self) types.ControllerConfiguration {
    return @bitCast(fio.mem.read(u32, self.baseAddress() + 0x14));
}

pub fn setControllerConfig(self: *const Self, value: types.ControllerConfiguration) void {
    fio.mem.write(self.baseAddress() + 0x14, @as(u32, @bitCast(value)));
}

pub fn format(self: *const Self, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = options;

    try writer.writeAll(@typeName(Self));
    try writer.print("{{ .baseAddress = 0x{x}, .capabilities = {}, .controllerConfig = .{}, .controllerStatus = {}, .version = {}, .adminQueueAttribs = {}, .adminSubmissionQueue = {}, .adminCompletionQueue = {} }}", .{
        self.baseAddress(),
        self.capabilities(),
        self.getControllerConfig(),
        self.controllerStatus(),
        self.version(),
        self.getAdminQueueAttribs(),
        self.getAdminSubmissionQueue(),
        self.getAdminCompletionQueue(),
    });
}
