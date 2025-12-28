const std = @import("std");

pub fn build(b: *std.Build) !void {
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
    const optimize_internal = b.standardOptimizeOption(.{});
    const optimize = switch (optimize_internal) {
        .Debug => .ReleaseSafe,
        else => optimize_internal,
    };

    // Dependencies
    const win32 = b.dependency("zigwin32", .{}).module("win32");
    const minhook = minhookDependency(b, target, optimize);

    const dll = b.addLibrary(.{
        .name = "chrono_trigger",
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

    const game_path_opt = b.option([]const u8, "game-path", "Game executable absolute path");
    const install_step = b.step("dll-install", "Install the dynamic library to game executable path");
    if (game_path_opt) |game_path| {
        const path = try std.fmt.allocPrint(b.allocator, "{s}//version.dll", .{game_path});
        const install_command = CopyFile.create(b, dll.getEmittedBin(), path);
        install_command.step.dependOn(b.getInstallStep());
        install_step.dependOn(&install_command.step);
    } else {
        install_step.dependOn(&b.addFail("game-path option is required!").step);
    }

    const run_command = b.addSystemCommand(&.{ "steam", "steam://rungameid/613830" });
    run_command.step.dependOn(install_step);
    const run_step = b.step("run", "Run game via steam");
    run_step.dependOn(&run_command.step);
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

const CopyFile = struct {
    const Step = std.Build.Step;

    step: Step,
    source: std.Build.LazyPath,
    dest_abs_path: []const u8,

    pub fn create(
        owner: *std.Build,
        source: std.Build.LazyPath,
        dest_abs_path: []const u8,
    ) *CopyFile {
        std.debug.assert(dest_abs_path.len != 0);
        std.debug.assert(std.fs.path.isAbsolute(dest_abs_path));
        const copy_file = owner.allocator.create(CopyFile) catch @panic("OOM");
        copy_file.* = .{
            .step = Step.init(.{
                .id = .custom,
                .name = owner.fmt("copy {s} to {s}", .{ source.getDisplayName(), dest_abs_path }),
                .owner = owner,
                .makeFn = make,
            }),
            .source = source.dupe(owner),
            .dest_abs_path = owner.dupePath(dest_abs_path),
        };
        source.addStepDependencies(&copy_file.step);
        return copy_file;
    }

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
        _ = options;
        const copy_file: *CopyFile = @fieldParentPtr("step", step);

        try step.singleUnchangingWatchInput(copy_file.source);
        const p = try step.installFile(copy_file.source, copy_file.dest_abs_path);
        step.result_cached = p == .fresh;
    }
};
