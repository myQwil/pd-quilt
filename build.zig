const std = @import("std");

pub fn build(b: *std.Build) !void {
	var buf: [64]u8 = undefined;

	{
		const target = b.standardTargetOptions(.{});
		const optimize = b.standardOptimizeOption(.{});

		const externals = [_][]const u8 {
			"fldec",
			"flenc",
			"has",
			"is",
			"rind",
			"same",
			"slx",
			"sly",
			"tabosc2~",
			"tabread2~",
		};
		for (externals) |e| {
			var s = try std.fmt.bufPrint(&buf, "src/{s}.zig", .{e});
			const artifact = b.addSharedLibrary(.{
				.name = e,
				.root_source_file = .{ .path = s },
				.target = target,
				.optimize = optimize,
				.link_libc = true,
				.pic = true,
			});
			artifact.addIncludePath(.{ .cwd_relative = "src" });
			artifact.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });

			s = try std.fmt.bufPrint(&buf, "{s}.pd_linux", .{e});
			const install = b.addInstallFile(artifact.getEmittedBin(), s);
			install.step.dependOn(&artifact.step);
			b.getInstallStep().dependOn(&install.step);
		}
	}

	// {
	// 	const dir = try std.fs.cwd().openDir("help", .{ .iterate = true });
	// 	var iter = dir.iterate();
	// 	while (try iter.next()) |file| {
	// 		if (file.kind != .file) {
	// 			continue;
	// 		}
	// 		const s = try std.fmt.bufPrint(&buf, "help/{s}", .{file.name});
	// 		b.installFile(s, file.name);
	// 	}
	// }
}
