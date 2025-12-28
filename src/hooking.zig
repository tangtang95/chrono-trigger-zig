const std = @import("std");
const minhook = @import("minhook");

pub const hooking = struct {
    pub fn init() !void {
        const status = minhook.MH_Initialize();
        if (status != minhook.MH_OK) {
            return minHookStatusToError(status);
        }
    }

    pub fn deinit() !void {
        const status = minhook.MH_Uninitialize();
        if (status != minhook.MH_OK) {
            return minHookStatusToError(status);
        }
    }
};

pub fn Hook(comptime Function: type) type {
    switch (@typeInfo(Function)) {
        .@"fn" => {},
        else => @compileError("Hook's Function must be a function type."),
    }

    return struct {
        target: *const Function,
        detour: *const Function,
        original: *const Function,

        const Self = @This();

        pub fn create(target: *const Function, detour: *const Function) !Self {
            var original: *Function = undefined;
            const status = minhook.MH_CreateHook(@constCast(target), @constCast(detour), @ptrCast(&original));
            if (status != minhook.MH_OK) {
                return minHookStatusToError(status);
            }
            return Self{
                .target = target,
                .detour = detour,
                .original = original,
            };
        }

        pub fn destroy(self: *const Self) !void {
            const status = minhook.MH_RemoveHook(@constCast(self.target));
            if (status != minhook.MH_OK) {
                return minHookStatusToError(status);
            }
        }

        pub fn enable(self: *const Self) !void {
            const status = minhook.MH_EnableHook(@constCast(self.target));
            if (status != minhook.MH_OK) {
                return minHookStatusToError(status);
            }
        }

        pub fn disable(self: *const Self) !void {
            const status = minhook.MH_DisableHook(@constCast(self.target));
            if (status != minhook.MH_OK) {
                return minHookStatusToError(status);
            }
        }
    };
}

fn minHookStatusToError(status: minhook.MH_STATUS) anyerror {
    return switch (status) {
        minhook.MH_ERROR_ALREADY_INITIALIZED => error.HookingAlreadyInitialized,
        minhook.MH_ERROR_NOT_INITIALIZED => error.HookingNotInitialized,
        minhook.MH_ERROR_ALREADY_CREATED => error.HookAlreadyCreated,
        minhook.MH_ERROR_NOT_CREATED => error.HookNotCreated,
        minhook.MH_ERROR_ENABLED => error.HookEnabled,
        minhook.MH_ERROR_DISABLED => error.HookDisabled,
        minhook.MH_ERROR_NOT_EXECUTABLE => error.MemoryNotExecutable,
        minhook.MH_ERROR_UNSUPPORTED_FUNCTION => error.UnsupportedFunction,
        minhook.MH_ERROR_MEMORY_ALLOC => error.MemoryAllocationFailed,
        minhook.MH_ERROR_MEMORY_PROTECT => error.MemoryProtectionChangeFailed,
        minhook.MH_ERROR_MODULE_NOT_FOUND => error.ModuleNotFound,
        minhook.MH_ERROR_FUNCTION_NOT_FOUND => error.FunctionNotFound,
        else => error.Unknown,
    };
}

