const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .whitelist = &.{.{
            .cpu_arch = .x86,
            .os_tag = .windows,
            .abi = .gnu,
        }},
        .default_target = .{
            .cpu_arch = .x86,
            .os_tag = .windows,
            .abi = .gnu,
        },
    });
    // NOTE: Debug mode does not work as it crashes in creating the log file
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });
 
    // Dependencies
    const win32 = b.dependency("zigwin32", .{}).module("win32");
    const minhook = minhookDependency(b, target, optimize);

    const dll = b.addLibrary(.{
        .name = "zig-dll",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/dll.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    dll.root_module.addImport("win32", win32);
    dll.root_module.addImport("minhook", minhook);
    b.installArtifact(dll);
}

fn minhookDependency(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const dependency = b.dependency("minhook", .{});
    const translate_c = b.addTranslateC(.{
        .root_source_file = dependency.path("include/MinHook.h"),
        .target = target,
        .optimize = optimize,
    });
    const module = translate_c.createModule();
    module.addIncludePath(dependency.path("include"));
    module.addCSourceFiles(.{
        .root = dependency.path("src"),
        .files = &.{
            "buffer.c",
            "hook.c",
            "trampoline.c",
            "hde/hde32.c",
            "hde/hde64.c",
        },
    });
    return module;
}
