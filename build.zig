const std = @import("std");
const pd = @import("pd");
const LinkMode = std.builtin.LinkMode;

const PatchMode = enum {
	/// Install copies of patches.
	copy,
	/// Install symbolic links to patches.
	/// This makes it easier to track changes made to the patches.
	symbolic,
	/// Don't install any patches.
	skip,
};

const Options = struct {
	float_size: u8 = 32,
	patches: PatchMode = .copy,
	linkage: LinkMode = .dynamic,

	fn init(b: *std.Build) Options {
		const default: Options = .{};
		return .{
			.float_size = b.option(u8, "float_size",
				"Size of a floating-point number"
			) orelse default.float_size,

			.patches = b.option(PatchMode, "patches",
				"Method for installing Pd patches"
			) orelse default.patches,

			.linkage = b.option(LinkMode, "linkage",
				"Library linking method"
			) orelse default.linkage,
		};
	}
};

const Dependency = enum {
	libc,
	gme,
	rabbit,
	rubber,
	ffmpeg,
};

const External = struct {
	name: []const u8,
	deps: []const Dependency = &.{ .libc },
};

const externals = [_]External{
	.{ .name = "arp" },
	.{ .name = "av~", .deps = &.{ .libc, .ffmpeg, .rabbit } },
	.{ .name = "avr~", .deps = &.{ .libc, .ffmpeg, .rabbit, .rubber } },
	.{ .name = "blunt" },
	.{ .name = "chrono" },
	.{ .name = "delp" },
	.{ .name = "fldec" },
	.{ .name = "flenc" },
	.{ .name = "fton" },
	.{ .name = "gmer~", .deps = &.{ .libc, .gme, .rabbit, .rubber } },
	.{ .name = "gmes~", .deps = &.{ .libc, .gme, .rabbit } },
	.{ .name = "gme~", .deps = &.{ .libc, .gme, .rabbit } },
	.{ .name = "has" },
	.{ .name = "hsv" },
	.{ .name = "is" },
	.{ .name = "linp" },
	.{ .name = "linp~" },
	.{ .name = "metro~" },
	.{ .name = "ntof" },
	.{ .name = "paq" },
	.{ .name = "plist" },
	.{ .name = "pulse~" },
	.{ .name = "radix" },
	.{ .name = "rand" },
	.{ .name = "rind" },
	.{ .name = "same" },
	.{ .name = "sesom" },
	.{ .name = "slx" },
	.{ .name = "sly" },
	.{ .name = "tabosc2~" },
	.{ .name = "tabread2~" },
	.{ .name = "unpaq" },
};

fn getModule(
	b: *std.Build,
	name: []const u8,
	args: anytype,
) *std.Build.Module {
	const dep = b.dependency(name, args);
	const linkage: LinkMode = args.linkage;
	const target: std.Build.ResolvedTarget = args.target;

	if (linkage == .dynamic) {
		const lib = dep.artifact(name);
		const install = b.addInstallFile(lib.getEmittedBin(),
			b.fmt("lib{s}{s}", .{ name, target.result.dynamicLibSuffix() }));
		install.step.dependOn(&lib.step);
		b.getInstallStep().dependOn(&install.step);
	}
	return dep.module(name);
}

pub fn build(b: *std.Build) !void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
	const opt: Options = .init(b);

	//---------------------------------------------------------------------------
	// Dependencies and modules
	const pd_mod = b.dependency("pd", .{ .float_size = opt.float_size }).module("pd");

	const gme = getModule(b, "gme", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
		.ym2612_emu = .mame,
	});
	const unrar = getModule(b, "unrar", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
	});
	const rabbit = getModule(b, "samplerate", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
	});
	const rubber = getModule(b, "rubberband", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
	});
	const av = b.dependency("ffmpeg", .{}).module("av");

	//---------------------------------------------------------------------------
	// Install externals
	const extension = pd.extension(b, target);
	for (externals) |x| {
		const mod = b.createModule(.{
			.target = target,
			.optimize = optimize,
			.root_source_file = b.path(b.fmt("src/{s}.zig", .{ x.name })),
			.imports = &.{.{ .name = "pd", .module = pd_mod }},
		});
		const lib = blk: {
			var l = b.addLibrary(.{
				.name = x.name,
				.linkage = .dynamic,
				.root_module = mod,
			});
			// use llvm until self-hosted backend has better debugger support
			if (optimize == .Debug) {
				l.use_llvm = true;
			}
			break :blk l;
		};

		for (x.deps) |dep| switch (dep) {
			.libc => mod.link_libc = true,
			.gme => {
				mod.addImport("gme", gme);
				mod.addImport("unrar", unrar);
			},
			.rabbit => mod.addImport("rabbit", rabbit),
			.rubber => mod.addImport("rubber", rubber),
			.ffmpeg => {
				mod.linkSystemLibrary("avutil", .{});
				mod.linkSystemLibrary("avcodec", .{});
				mod.linkSystemLibrary("avformat", .{});
				mod.linkSystemLibrary("swresample", .{});
				mod.addImport("av", av);
			}
		};
		if (opt.linkage == .dynamic and x.deps.len > 0) {
			mod.addRPathSpecial("$ORIGIN");
		}

		const install = b.addInstallFile(lib.getEmittedBin(),
			b.fmt("{s}{s}", .{ x.name, extension }));
		install.step.dependOn(&lib.step);
		b.getInstallStep().dependOn(&install.step);

		const step_install = b.step(x.name, b.fmt("Build {s}", .{ x.name }));
		step_install.dependOn(&install.step);
	}

	//---------------------------------------------------------------------------
	// Install help patches and abstractions
	const io = b.graph.io;
	const InstallFunc = fn(*std.Build, []const u8, []const u8) void;
	const installFile: *const InstallFunc = switch (opt.patches) {
		.symbolic => &pd.InstallLink.install,
		.copy => &std.Build.installFile,
		.skip => return,
	};

	for ([_][]const u8{ "help", "abstractions" }) |dir_name| {
		var dir = try std.Io.Dir.cwd().openDir(io, dir_name, .{ .iterate = true });
		defer dir.close(io);

		var iter = dir.iterate();
		while (try iter.next(io)) |file| {
			if (file.kind != .file) {
				continue;
			}
			installFile(b, b.fmt("{s}/{s}", .{ dir_name, file.name }), file.name);
		}
	}
}
