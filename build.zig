const std = @import("std");
const installLink = @import("InstallLink.zig").installLink;

const Options = struct {
	shared: bool = false,
};

const Link = enum {
	gme,
	rabbit,
};

const External = struct {
	name: []const u8,
	links: []const Link = &.{},
};

const externals = [_]External{
	.{ .name = "arp" },
	.{ .name = "blunt" },
	.{ .name = "chrono" },
	.{ .name = "delp" },
	.{ .name = "fldec" },
	.{ .name = "flenc" },
	.{ .name = "fton" },
	.{ .name = "gme~", .links = &.{ .gme, .rabbit } },
	.{ .name = "gmes~", .links = &.{ .gme, .rabbit } },
	.{ .name = "has" },
	.{ .name = "hsv" },
	.{ .name = "is" },
	.{ .name = "linp" },
	.{ .name = "linp~" },
	.{ .name = "metro~" },
	.{ .name = "ntof" },
	.{ .name = "paq" },
	.{ .name = "rand" },
	.{ .name = "rind" },
	.{ .name = "same" },
	.{ .name = "slx" },
	.{ .name = "sly" },
	.{ .name = "tabosc2~" },
	.{ .name = "tabread2~" },
	.{ .name = "unpaq" },
};

fn rabbitModule(
	b: *std.Build,
	target: std.Build.ResolvedTarget,
	optimize: std.builtin.OptimizeMode,
	shared: bool,
) !*std.Build.Module {
	const lib = if (shared) b.addSharedLibrary(.{
		.name="rabbit", .target=target, .optimize=optimize, .pic=true,
	}) else b.addStaticLibrary(.{
		.name="rabbit", .target=target, .optimize=optimize,
	});
	lib.linkLibC();

	var files = std.ArrayList([]const u8).init(b.allocator);
	defer files.deinit();
	for ([_][]const u8{ "samplerate", "src_linear", "src_sinc", "src_zoh" }) |s|
		try files.append(b.fmt("{s}.c", .{ s }));
	const dep = b.dependency("rabbit", .{ .target=target, .optimize=optimize });
	lib.defineCMacro("HAVE_STDBOOL_H", null);
	lib.defineCMacro("PACKAGE", "\"libsamplerate\"");
	lib.defineCMacro("VERSION", "\"0.2.2\"");

	lib.defineCMacro("ENABLE_SINC_FAST_CONVERTER", null);
	lib.defineCMacro("ENABLE_SINC_MEDIUM_CONVERTER", null);
	lib.defineCMacro("ENABLE_SINC_BEST_CONVERTER", null);

	lib.addCSourceFiles(.{ .root=dep.path("src"), .files=files.items });

	const mod = b.addModule("rabbit", .{
		.root_source_file = b.path("lib/rabbit/main.zig"),
		.target = target,
		.optimize = optimize,
	});
	mod.linkLibrary(lib);
	return mod;
}

pub fn build(b: *std.Build) !void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const pd = b.addModule("pd", .{
		.root_source_file = b.path("lib/pd/main.zig"),
		.target = target,
		.optimize = optimize,
	});

	const defaults = Options{};
	const opt = Options{
		.shared = b.option(bool, "shared", "Build shared libraries")
			orelse defaults.shared,
	};

	const gme = b.dependency("gme", .{
		.target=target, .optimize=optimize, .shared=opt.shared, .ym2612_emu=.mame,
	}).module("gme");
	const unrar = b.dependency("unrar", .{
		.target=target, .optimize=optimize, .shared=opt.shared,
	}).module("unrar");
	const rabbit = try rabbitModule(b, target, optimize, opt.shared);

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

	for (externals) |x| {
		const lib = b.addSharedLibrary(.{
			.name = x.name,
			.root_source_file = b.path(b.fmt("src/{s}.zig", .{x.name})),
			.target = target,
			.optimize = optimize,
			.link_libc = true,
			.pic = true,
		});
		lib.addIncludePath(b.path("src"));
		lib.root_module.addImport("pd", pd);

		for (x.links) |link| switch (link) {
			.gme => {
				lib.root_module.addImport("gme", gme);
				lib.root_module.addImport("unrar", unrar);
			},
			.rabbit => lib.root_module.addImport("rabbit", rabbit),
		};

		const install = b.addInstallFile(lib.getEmittedBin(),
			b.fmt("{s}{s}", .{ x.name, extension }));
		install.step.dependOn(&lib.step);
		b.getInstallStep().dependOn(&install.step);
	}

	const symlink = if (target.result.os.tag != .windows)
		b.option(bool, "symlink", "Install symbolic links of Pd patches.")
		orelse false else false;
	const installFile = if (symlink) &installLink else &std.Build.installFile;

	for (&[_][]const u8{"help", "abstractions"}) |dir_name| {
		const dir = try std.fs.cwd().openDir(dir_name, .{ .iterate = true });
		var iter = dir.iterate();
		while (try iter.next()) |file| {
			if (file.kind != .file)
				continue;
			installFile(b, b.fmt("{s}/{s}", .{dir_name, file.name}), file.name);
		}
	}
}
