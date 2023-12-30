pub const Version = packed struct(u32) {
    tertiary: u8,
    minor: u8,
    major: u16,
};

pub const AdminQueueAttributes = packed struct(u32) {
    submissionQueueSize: u12,
    reserved0: u4,
    completionQueueSize: u12,
    reserved1: u4,
};

pub const AdminQueueBaseAddress = packed struct(u64) {
    reserved: u12,
    addr: u52,
};

pub const Capabilities = packed struct(u64) {
    maxQueueEntries: u16,
    contigQueuesReq: u1,
    arbitMechSupported: u2,
    reserved0: u5,
    timeout: u8,
    doorbellStride: u4,
    subsysResetSupport: u1,
    commandSetSupported: u8,
    bootPartSupported: u1,
    powerScope: u2,
    pageSizeMin: u4,
    pageSizeMax: u4,
    persistMemRegionSupported: u1,
    memBufferSupported: u1,
    subsysShutdownSupported: u1,
    readyModesSupported: u2,
    reserved1: u3,
};

pub const ControllerConfiguration = packed struct(u32) {
    enable: u1,
    reserved0: u3,
    ioCommandSetSel: u3,
    memoryPageSize: u4,
    arbitMechSel: u3,
    shutdownNotif: u2,
    ioSubmissionQueueEntrySize: u4,
    ioCompletionQueueEntrySize: u4,
    readyIndepMediaEnable: u1,
    reserved1: u7,
};

pub const ControllerStatus = packed struct(u32) {
    ready: u1,
    fatalStatus: u1,
    shutdownStatus: u2,
    subsysReset: u1,
    procPaused: u1,
    shutdownType: u1,
    reserved: u25,
};
