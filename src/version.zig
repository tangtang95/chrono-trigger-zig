const std = @import("std");
const sdk = @import("sdk.zig");
const win = std.os.windows;
const win32 = @import("win32").everything;

export fn GetFileVersionInfoA(
    filename: win.LPCSTR,
    handle: win.DWORD,
    len: win.DWORD,
    data: win.LPVOID,
) callconv(.c) win.BOOL {
    return __GetFileVersionInfoA(filename, handle, len, data);
}

export fn GetFileVersionInfoW(
    filename: win.LPCWSTR,
    handle: win.DWORD,
    len: win.DWORD,
    data: win.LPVOID,
) callconv(.c) win.BOOL {
    return __GetFileVersionInfoW(filename, handle, len, data);
}

export fn GetFileVersionInfoSizeA(
    filename: win.LPCSTR,
    lpHandle: *win.DWORD,
) callconv(.c) win.DWORD {
    return __GetFileVersionInfoSizeA(filename, lpHandle);
}

export fn GetFileVersionInfoSizeW(
    filename: win.LPCWSTR,
    lpHandle: *win.DWORD,
) callconv(.c) win.DWORD {
    return __GetFileVersionInfoSizeW(filename, lpHandle);
}

export fn VerQueryValueA(
    block: win.LPCVOID,
    subBlock: win.LPCSTR,
    buffer: *win.LPVOID,
    len: *win.UINT,
) callconv(.c) win.BOOL {
    return __VerQueryValueA(block, subBlock, buffer, len);
}

export fn VerQueryValueW(
    block: win.LPCVOID,
    subBlock: win.LPCWSTR,
    buffer: *win.LPVOID,
    len: *win.UINT,
) callconv(.c) win.BOOL {
    return __VerQueryValueW(block, subBlock, buffer, len);
}

var __GetFileVersionInfoA: *const fn (win.LPCSTR, win.DWORD, win.DWORD, win.LPVOID) callconv(.c) win.BOOL = undefined;
var __GetFileVersionInfoW: *const fn (win.LPCWSTR, win.DWORD, win.DWORD, win.LPVOID) callconv(.c) win.BOOL = undefined;
var __GetFileVersionInfoSizeA: *const fn (win.LPCSTR, *win.DWORD) callconv(.c) win.DWORD = undefined;
var __GetFileVersionInfoSizeW: *const fn (win.LPCWSTR, *win.DWORD) callconv(.c) win.DWORD = undefined;
var __VerQueryValueA: *const fn (win.LPCVOID, win.LPCSTR, *win.LPVOID, *win.UINT) callconv(.c) win.BOOL = undefined;
var __VerQueryValueW: *const fn (win.LPCVOID, win.LPCWSTR, *win.LPVOID, *win.UINT) callconv(.c) win.BOOL = undefined;

pub fn loadVersionLib() !void {
    var systemPath: [sdk.MAX_PATH:0]u8 = undefined;
    const systemPathLen = win32.GetSystemDirectoryA(&systemPath, sdk.MAX_PATH);

    var versionPath: [sdk.MAX_PATH:0]u8 = undefined;
    _ = try std.fmt.bufPrintZ(&versionPath, "{s}\\version.dll", .{systemPath[0..systemPathLen]});
    std.log.debug("loading version library: {s}", .{@as([*:0]const u8, &versionPath)});

    const module = win32.LoadLibraryA(&versionPath);
    if (module == null) {
        return error.VersionLibraryNotFound;
    }

    __GetFileVersionInfoA = @ptrCast(win32.GetProcAddress(module, "GetFileVersionInfoA"));
    __GetFileVersionInfoW = @ptrCast(win32.GetProcAddress(module, "GetFileVersionInfoW"));
    __GetFileVersionInfoSizeA = @ptrCast(win32.GetProcAddress(module, "GetFileVersionInfoSizeA"));
    __GetFileVersionInfoSizeW = @ptrCast(win32.GetProcAddress(module, "GetFileVersionInfoSizeW"));
    __VerQueryValueA = @ptrCast(win32.GetProcAddress(module, "VerQueryValueA"));
    __VerQueryValueW = @ptrCast(win32.GetProcAddress(module, "VerQueryValueW"));
}
