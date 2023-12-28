pub const Address = packed struct {
    reg: u8,
    func: u3,
    dev: u5,
    bus: u8,
    reserved: u7 = 0,
    enable: u1 = 1,
};

pub const Register = enum(u8) {
    vendor = 0x0,
    device = 0x2,
    command = 0x4,
    status = 0x6,
    revision = 0x8,
    progIface = 0x9,
    subclass = 0xa,
    class = 0xb,
    cacheLineSize = 0xc,
    latencyTimer = 0xd,
    headerType = 0xe,
    bist = 0xf,

    bar0 = 0x10,
    bar1 = 0x14,
    bar2 = 0x18,
    bar3 = 0x1c,
    bar4 = 0x20,
    bar5 = 0x24,

    cardbusCis = 0x28,
    subsysVendor = 0x2c,
    subsysId = 0x2e,
    erom = 0x30,
    cap = 0x34,
    intLine = 0x3c,
    intPin = 0x3d,
    minGrant = 0x3e,
    maxLatency = 0x3f,

    pub fn width(v: Register) usize {
        return switch (v) {
            .revision, .progIface, .subclass, .class, .cacheLineSize, .latencyTimer, .headerType, .bist, .intLine, .intPin, .minGrant, .maxLatency, .cap => 8,
            .bar0, .bar1, .bar2, .bar3, .bar4, .bar5, .cardbusCis, .erom => 32,
            .vendor, .device, .command, .status, .subsysVendor, .subsysId => 16,
        };
    }

    pub fn @"type"(comptime v: Register) type {
        return @Type(.{
            .Int = .{
                .signedness = .unsigned,
                .bits = v.width(),
            },
        });
    }
};

pub const Bar32 = union(enum) {
    mem: BarMem32,
    io: BarIo32,

    pub const BarMem32 = packed struct { always0: u1, type: u1, prefetch: u1, addr: u29 };

    pub const BarIo32 = packed struct {
        always1: u1,
        reserved: u1,
        address: u30,
    };

    pub fn decode(v: u32) Bar32 {
        return if (v & 0x1 != 0) .{ .io = @bitCast(v) } else .{ .mem = @bitCast(v) };
    }
};

pub const Bar64 = union(enum) {
    mem: BarMem64,

    pub const BarMem64 = struct {
        bits: u32,
        size: u64,
        addr: u64,
    };
};

pub const Bar = union(enum) {
    @"32": Bar32,
    @"64": Bar64,
};
