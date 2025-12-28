const std = @import("std");
const w32 = @import("win32").everything;

pub const FileLogger = struct {
    var log_file: ?std.fs.File = null;
    var log_writer: ?std.fs.File.Writer = null;
    var buffer: [4096]u8 = undefined;
    var mutex = std.Thread.Mutex{};

    pub fn init(file_path: []const u8) !void {
        const file = std.fs.createFileAbsolute(file_path, .{}) catch |err| {
            return err;
        };
        log_file = file;
        log_writer = file.writerStreaming(&buffer);
    }

    pub fn deinit() void {
        if (log_writer) |*writer| {
            writer.interface.flush() catch |err| {
                std.debug.print("Failed to flush buffer before closing the file logger. Cause: {}\n", .{err});
            };
            log_writer = null;
        }
        if (log_file) |*file| {
            file.close();
            log_file = null;
        }
    }

    pub fn logFn(
        comptime level: std.log.Level,
        comptime scope: @TypeOf(.EnumLiteral),
        comptime format: []const u8,
        args: anytype,
    ) void {
        const timestamp = std.time.microTimestamp();
        const scope_prefix = if (scope != std.log.default_log_scope) "(" ++ @tagName(scope) ++ ") " else "";
        const level_prefix = "[" ++ comptime level.asText() ++ "] ";
        var writer = if (log_writer) |*w| &w.interface else return;
        mutex.lock();
        defer mutex.unlock();
        writer.print("{d} " ++ level_prefix ++ scope_prefix ++ format ++ "\n", .{timestamp} ++ args) catch {
            return;
        };
        writer.flush() catch {};
    }
};
