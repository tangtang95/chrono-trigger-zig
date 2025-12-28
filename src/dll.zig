const std = @import("std");
const win = std.os.windows;
const w32 = @import("win32").everything;
const minhook = @import("minhook");
const version = @import("version.zig");
const sdk = @import("sdk.zig");

const FileLogger = @import("logger.zig").FileLogger;

const log_file_name = "ChronoTrigger.log";
pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = FileLogger.logFn,
};

pub fn DllMain(
    module_handle: w32.HINSTANCE,
    forward_reason: u32,
    reserved: *anyopaque,
) callconv(.winapi) w32.BOOL {
    _ = module_handle;
    _ = reserved;
    switch (forward_reason) {
        w32.DLL_PROCESS_ATTACH => {
            attach() catch |err| {
                var buffer: [sdk.MAX_PATH:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&buffer, "Error: {any}", .{err}) catch {
                    return 0;
                };
                _ = w32.MessageBoxA(null, &buffer, "Chrono Trigger error", w32.MB_ICONERROR);
                std.log.err("Failed to attach dll: {any}", .{err});
                return 0;
            };
            std.log.info("ChronoTrigger dll attached successfully!", .{});
            return 1;
        },
        w32.DLL_PROCESS_DETACH => {
            std.log.info("ChronoTrigger dll detached successfully!", .{});
            detach();
            return 1;
        },
        else => return 0,
    }
}

fn attach() !void {
    try startFileLogging();
    try version.loadVersionLib();
}

fn detach() void {
    FileLogger.deinit();
}

fn startFileLogging() !void {
    var currDirBuffer: [sdk.MAX_PATH:0]u8 = undefined;
    const len = w32.GetCurrentDirectoryA(sdk.MAX_PATH, &currDirBuffer);
    var pathBuffer: [sdk.MAX_PATH]u8 = undefined;
    const path = try std.fmt.bufPrint(&pathBuffer, "{s}\\{s}", .{currDirBuffer[0..len], log_file_name});
    try FileLogger.init(path);
}
