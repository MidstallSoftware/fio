const std = @import("std");
const metap = @import("metaplus").@"meta+";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_tests = b.option(bool, "no-tests", "skip building tests") orelse false;
    const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;

    const dtree = b.dependency("dtree", .{
        .target = target,
        .optimize = optimize,
    });

    const fio = b.addModule("fio", .{
        .root_source_file = .{ .path = b.pathFromRoot("fio.zig") },
        .imports = &.{
            .{
                .name = "dtree",
                .module = dtree.module("dtree"),
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

        unit_tests.root_module.addImport("dtree", dtree.module("dtree"));

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

    exe_example.root_module.addImport("fio", fio);
    exe_example.root_module.addImport("dtree", dtree.module("dtree"));
    b.installArtifact(exe_example);
}
