const std = @import("std");
const win = std.os.windows;
const w32 = @import("win32").everything;
const hooking = @import("hooking.zig");
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
                std.log.err("Failed to attach dll: {any}", .{err});
                _ = w32.MessageBoxA(null, "Game crashed due to failed dll attach. Check log file for more data.", "Chrono Trigger crash", w32.MB_ICONERROR);
                return 0;
            };
            std.log.info("ChronoTrigger dll attached successfully!", .{});
            return 1;
        },
        w32.DLL_PROCESS_DETACH => {
            detach() catch |err| {
                std.log.err("Failed to detach dll: {any}", .{err});
                return 0;
            };
            std.log.info("ChronoTrigger dll detached successfully!", .{});
            return 1;
        },
        else => return 0,
    }
}

fn attach() !void {
    try startFileLogging();
    try version.loadVersionLib();
    try hooking.hooking.init();
    const base_module_opt = w32.GetModuleHandleW(null);
    if (base_module_opt) |base_module| {
        const base_module_int = @intFromPtr(base_module);
        hooks.win_main_hook = try .create(@ptrFromInt(base_module_int + 0x2D8830), win_main);
        try hooks.win_main_hook.enable();
    }
}

fn detach() !void {
    try hooking.hooking.deinit();
    FileLogger.deinit();
}

fn startFileLogging() !void {
    var currDirBuffer: [sdk.MAX_PATH:0]u8 = undefined;
    var currDirWBuffer: [sdk.MAX_PATH:0]u16 = undefined;
    const wLen = w32.GetCurrentDirectoryW(sdk.MAX_PATH, &currDirWBuffer);
    const len = try std.unicode.utf16LeToUtf8(&currDirBuffer, currDirWBuffer[0..wLen]);
    var pathBuffer: [sdk.MAX_PATH]u8 = undefined;
    const path = try std.fmt.bufPrint(&pathBuffer, "{s}\\{s}", .{currDirBuffer[0..len], log_file_name});
    try FileLogger.init(path);
}

const hooks = struct {
    var win_main_hook: hooking.Hook(@TypeOf(win_main)) = undefined;
};

fn win_main(
    h_instance: win.HINSTANCE,
    h_prev_instance: win.HINSTANCE,
    cmd_line: win.PCWSTR,
    num_show_cmd: i32
) callconv(.c) i32 {
    std.log.info("executing custom WinMain function", .{});
    return hooks.win_main_hook.original(h_instance, h_prev_instance, cmd_line, num_show_cmd);
}
