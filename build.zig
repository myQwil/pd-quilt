const std = @import("std");
const LinkMode = std.builtin.LinkMode;
const Build = std.Build;

const pd = @import("pd");

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

	fn init(b: *Build) Options {
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
	deps: []const Dependency = &.{},
};

const externals = [_]External{
	.{ .name = "ad~" },
	.{ .name = "adsr~" },
	.{ .name = "arp" },
	.{ .name = "av~", .deps = &.{ .ffmpeg, .rabbit } },
	.{ .name = "avr~", .deps = &.{ .ffmpeg, .rabbit, .rubber } },
	.{ .name = "blunt" },
	.{ .name = "chrono" },
	.{ .name = "delp" },
	.{ .name = "fldec" },
	.{ .name = "flenc" },
	.{ .name = "fton" },
	.{ .name = "gme~", .deps = &.{ .gme, .rabbit } },
	.{ .name = "gmer~", .deps = &.{ .gme, .rabbit, .rubber } },
	.{ .name = "gmes~", .deps = &.{ .gme, .rabbit } },
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

fn installDynamicLib(
	b: *Build,
	dep: *Build.Dependency,
	name: []const u8,
	target: std.Target,
) void {
	const lib = dep.artifact(name);
	const install = b.addInstallFile(lib.getEmittedBin(), b.fmt("{s}{s}{s}", .{
		target.os.tag.libPrefix(target.abi), name, target.dynamicLibSuffix(),
	}));
	install.step.dependOn(&lib.step);
	b.getInstallStep().dependOn(&install.step);
}

pub fn installLink(b: *Build, symlink: *Build.Step.Compile, src: []const u8) void {
	const run = b.addRunArtifact(symlink);
	run.addFileArg2(b.graph.path(.install_prefix, ""), .{});
	run.addFileArg2(b.path(src), .{});
	b.getInstallStep().dependOn(&run.step);
}

pub fn build(b: *Build) !void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
	const opt: Options = .init(b);

	//---------------------------------------------------------------------------
	// Dependencies and modules
	const pd_dep = b.dependency("pd", .{
		.target = target,
		.optimize = optimize,
		.float_size = opt.float_size,
	});
	const pd_mod = pd_dep.module("pd");

	const av = b.dependency("ffmpeg", .{
		.target = target,
		.optimize = optimize,
	}).module("av");

	const gme_dep = b.dependency("gme", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
		.ym2612_emu = .mame,
	});
	const gme = gme_dep.module("gme");

	const unrar_dep = gme_dep.builder.dependency("unrar", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
	});
	const unrar = unrar_dep.module("unrar");

	const rabbit_dep = b.dependency("samplerate", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
	});
	const rabbit = rabbit_dep.module("samplerate");

	const rubber_dep = b.dependency("rubberband", .{
		.target = target,
		.optimize = .ReleaseFast,
		.linkage = opt.linkage,
	});
	const rubber = rubber_dep.module("rubberband");

	if (opt.linkage == .dynamic) {
		installDynamicLib(b, gme_dep, "gme", target.result);
		installDynamicLib(b, unrar_dep, "unrar", target.result);
		installDynamicLib(b, rabbit_dep, "samplerate", target.result);
		installDynamicLib(b, rubber_dep, "rubberband", target.result);
	}

	//---------------------------------------------------------------------------
	// Install externals
	const os = target.result.os.tag;
	const extension = pd.extension(b, target, opt.float_size);
	for (externals) |x| {
		const mod = b.createModule(.{
			.target = target,
			.optimize = optimize,
			.root_source_file = b.path(b.fmt("src/{s}.zig", .{ x.name })),
			.imports = &.{.{ .name = "pd", .module = pd_mod }},
		});
		for (x.deps) |dep| switch (dep) {
			.libc => mod.link_libc = true,
			.gme => {
				mod.addImport("gme", gme);
				mod.addImport("unrar", unrar);
			},
			.rabbit => mod.addImport("rabbit", rabbit),
			.rubber => mod.addImport("rubber", rubber),
			.ffmpeg => {
				// un-comment this to help with cross-compilation
				// if (os == .windows) {
					// mod.addLibraryPath(b.path("build-win/av"));
				// } else if (os.isDarwin()) {
					// mod.addLibraryPath(b.path("build-mac/av"));
				// }
				const linkopt: std.Build.Module.LinkSystemLibraryOptions = .{
					.preferred_link_mode = opt.linkage
				};
				mod.linkSystemLibrary("avutil", linkopt);
				mod.linkSystemLibrary("avcodec", linkopt);
				mod.linkSystemLibrary("avformat", linkopt);
				mod.linkSystemLibrary("swresample", linkopt);
				mod.addImport("av", av);
			},
		};
		if (os == .windows) {
			mod.addObjectFile(b.path("build-win/pd/bin/pd.dll"));
		}
		if (opt.linkage == .dynamic and x.deps.len > 0) {
			mod.addRPathSpecial(if (os.isDarwin()) "@loader_path" else "$ORIGIN");
		}

		const lib = b.addLibrary(.{
			.name = x.name,
			.linkage = .dynamic,
			.root_module = mod,
			// use llvm until self-hosted backend has better debugger support
			.use_llvm = if (optimize == .debug) true else null,
		});
		if (os.isDarwin()) {
			lib.linker_allow_shlib_undefined = true;
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
	if (opt.patches == .skip) {
		return;
	}
	const io = b.graph.io;
	if (opt.patches == .copy) {
		b.installDirectory(.{
			.source_dir = b.path("help/plist"),
			.install_dir = .prefix,
			.install_subdir = "plist",
		});
		for ([_][]const u8{ "help", "abstractions" }) |dir_name| {
			var dir = try std.Io.Dir.cwd().openDir(io, dir_name, .{ .iterate = true });
			defer dir.close(io);
			var iter = dir.iterate();
			while (try iter.next(io)) |file| {
				if (file.kind == .file) {
					b.installFile(b.fmt("{s}/{s}", .{ dir_name, file.name }), file.name);
				}
			}
		}
	} else {
		const symlink = b.addExecutable(.{
			.name = "symlink",
			.root_module = b.createModule(.{
				.root_source_file = pd_dep.path("src/build/symlink.zig"),
				.target = b.graph.host,
			}),
		});
		installLink(b, symlink, "help/plist");
		for ([_][]const u8{ "help", "abstractions" }) |dir_name| {
			var dir = try std.Io.Dir.cwd().openDir(io, dir_name, .{ .iterate = true });
			defer dir.close(io);
			var iter = dir.iterate();
			while (try iter.next(io)) |file| {
				if (file.kind == .file) {
					installLink(b, symlink, b.fmt("{s}/{s}", .{ dir_name, file.name }));
				}
			}
		}
	}
}
