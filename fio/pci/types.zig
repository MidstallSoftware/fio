pub const Header = union(enum) {
    @"0": packed struct {
        vendor: u16,
        device: u16,

        command: u16,
        status: u16,

        rev: u8,
        prog: u8,
        subclass: u8,
        class: u8,

        cls: u8,
        latency_timer: u8,
        type: u8,
        bist: u8,

        bar0: u32,
        bar1: u32,
        bar2: u32,
        bar3: u32,
        bar4: u32,
        bar5: u32,

        cardbus: u32,

        subsys_vendor: u16,
        subsys: u16,
        erom: u32,
        cap: u8,
        reserved: u56,

        int_line: u8,
        int_pin: u8,
        min_grant: u8,
        max_latency: u8,
    },
    @"1": packed struct {
        vendor: u16,
        device: u16,

        command: u16,
        status: u16,

        rev: u8,
        prog: u8,
        subclass: u8,
        class: u8,

        cls: u8,
        latency_timer: u8,
        type: u8,
        bist: u8,

        bar0: u32,
        bar1: u32,

        primary_bus_no: u8,
        secondary_bus_no: u8,
        subord_bus_no: u8,
        secondary_latency_timer: u8,

        iobase: u8,
        iolimit: u8,
        secondary_status: u16,

        membase: u16,
        memlimit: u16,

        prefetch_membase: u16,
        prefetch_memlimit: u16,

        prefetch_base: u32,
        prefetch_limit: u32,

        iobase_upper: u16,
        iolimit_upper: u16,

        cap: u8,
        reserved: u24,

        erom: u32,

        int_line: u8,
        int_pin: u8,
        bridge: u16,
    },
    @"2": packed struct {
        vendor: u16,
        device: u16,

        command: u16,
        status: u16,

        rev: u8,
        prog: u8,
        subclass: u8,
        class: u8,

        cls: u8,
        latency_timer: u8,
        type: u8,
        bist: u8,

        cardbus_base_addr: u32,
        capoffset: u8,
        reserved: u8,

        secondary_status: u16,

        bus_no: u8,
        cardbus_no: u8,
        subord_bus_no: u8,
        cardbus_latency: u8,

        membase0: u32,
        memlimit0: u32,

        membase1: u32,
        memlimit1: u32,

        iobase0: u32,
        iolimit0: u32,

        iobase1: u32,
        iolimit1: u32,

        int_line: u8,
        int_pin: u8,
        bridge: u24,

        subsys_device: u16,
        subsys_vendor: u16,

        legacy: u32,
    },
};

pub const Bar = union(enum) {
    mem: packed struct { always0: u1, type: u1, prefetch: u1, address: u29 },
    io: packed struct {
        always1: u1,
        reserved: u1,
        address: u30,
    },
};
