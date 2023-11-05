const options = @import("fio.options");

pub const platform = if (@hasDecl(options, "platform")) @field(@import("fio/platforms.zig"), @tagName(options.platform)) else @compileError("Platform has not been set.");
