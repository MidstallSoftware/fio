const std = @import("std");
const metap = @import("metaplus").@"meta+";

pub const PlatformType = metap.enums.fromDecls(@import("fio/platforms.zig"));

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_tests = b.option(bool, "no-tests", "skip building tests") orelse false;
    const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;
    const platform = b.option(PlatformType, "platform", "The target platform");

    const options = b.addOptions();
    if (platform) |p| options.addOption(PlatformType, "platform", p);

    const fio = b.addModule("fio", .{
        .source_file = .{ .path = b.pathFromRoot("fio.zig") },
        .dependencies = &.{
            .{
                .name = "fio.options",
                .module = options.createModule(),
            },
        },
    });

    if (!no_tests) {
        const step_test = b.step("test", "Run all unit tests");

        const unit_tests = b.addTest(.{
            .root_source_file = .{
                .path = b.pathFromRoot("fio.zig"),
            },
            .target = target,
            .optimize = optimize,
        });

        unit_tests.addModule("fio.options", options.createModule());

        const run_unit_tests = b.addRunArtifact(unit_tests);
        step_test.dependOn(&run_unit_tests.step);

        if (!no_docs) {
            const docs = b.addInstallDirectory(.{
                .source_dir = unit_tests.getEmittedDocs(),
                .install_dir = .prefix,
                .install_subdir = "docs",
            });

            b.getInstallStep().dependOn(&docs.step);
        }
    }

    const exe_example = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{
            .path = b.pathFromRoot("example.zig"),
        },
        .target = target,
        .optimize = optimize,
    });

    exe_example.addModule("fio", fio);
    b.installArtifact(exe_example);
}
