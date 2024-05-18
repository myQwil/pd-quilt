const std = @import("std");

const externals = [_][]const u8{
	"arp",
	"blunt",
	"chrono",
	"delp",
	"fldec",
	"flenc",
	"fton",
	"has",
	"hsv",
	"is",
	"linp",
	"linp~",
	"metro~",
	"ntof",
	"paq",
	"rand",
	"rind",
	"same",
	"slx",
	"sly",
	"tabosc2~",
	"tabread2~",
	"unpaq",
};

fn installFolder(b: *std.Build, dir_name: []const u8, symlink: bool) !void {
	const dir = try std.fs.cwd().openDir(dir_name, .{ .iterate = true });
	var iter = dir.iterate();

	if (symlink) {
		const out = try std.fs.cwd().openDir(b.install_path, .{});
		while (try iter.next()) |file| {
			if (file.kind != .file) continue;
			const link = b.fmt("{s}/{s}", .{b.install_path, file.name});
			try out.symLink(b.fmt("../{s}/{s}", .{dir_name, file.name}), link, .{});
		}
	} else {
		while (try iter.next()) |file| {
			if (file.kind != .file) continue;
			b.installFile(b.fmt("{s}/{s}", .{dir_name, file.name}), file.name);
		}
	}
}

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const pd = b.addModule("pd", .{
		.root_source_file = b.path("lib/pd/main.zig"),
		.target = target,
		.optimize = optimize,
	});

	const extension = b.fmt(".{s}_{s}", .{
		switch (target.result.os.tag) {
			.ios, .macos, .watchos, .tvos => "d",
			.windows => "m",
			else => "l",
		},
		switch (target.result.cpu.arch) {
			.x86_64 => "amd64",
			.x86 => "i386",
			.arm, .armeb => "arm",
			.aarch64, .aarch64_be, .aarch64_32 => "arm64",
			.powerpc, .powerpcle => "ppc",
			else => @tagName(target.result.cpu.arch),
		},
	});

	for (externals) |name| {
		const lib = b.addSharedLibrary(.{
			.name = name,
			.root_source_file = b.path(b.fmt("src/{s}.zig", .{name})),
			.target = target,
			.optimize = optimize,
			.link_libc = true,
			.pic = true,
		});
		lib.addIncludePath(b.path("src"));
		lib.root_module.addImport("pd", pd);

		const install = b.addInstallFile(lib.getEmittedBin(),
			b.fmt("{s}{s}", .{ name, extension }));
		install.step.dependOn(&lib.step);
		b.getInstallStep().dependOn(&install.step);
	}

	const symlink = b.option(bool, "symlink", "Install symbolic links of Pd patches.")
		orelse false;
	installFolder(b, "help", symlink) catch {};
	installFolder(b, "abstractions", symlink) catch {};
}
