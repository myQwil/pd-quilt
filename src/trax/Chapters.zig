const Chapters = @This();

const std = @import("std");
const tx = @import("trax.zig");
const iParse = @import("../misc/numparse.zig").iParse;

const Io = std.Io;
const Allocator = std.mem.Allocator;
const StringMap = tx.StringMap;

/// byte array
buf: tx.Buffer = .empty,
/// list of chapter entries
tbl: std.ArrayList(Entry) = .empty,

const Entry = struct {
	time: f64,
	trax: tx.Offset,
	title: ?tx.Offset = null,
};
const Chapter = struct {
	time: f64,
	trax: [:0]const u8,
	title: ?[:0]const u8,
};

pub fn get(self: *const Chapters, index: usize) Chapter {
	const chap = self.tbl.items[index];
	return .{
		.time = chap.time,
		.trax = self.buf.items[chap.trax.start..][0..chap.trax.len :0],
		.title = if (chap.title) |t| self.buf.items[t.start..][0..t.len :0] else null,
	};
}

pub fn deinit(self: *Chapters, gpa: Allocator) void {
	self.buf.deinit(gpa);
	self.tbl.deinit(gpa);
}

fn traverse(
	self: *Chapters,
	gpa: Allocator,
	io: Io,
	parents: *StringMap,
	path: [:0]const u8,
	time: f64,
) tx.TravError!void {
	const file = tx.pathCheck(parents, gpa, io, path)
		catch |e| return tx.err(0, e, path.ptr, "chapter");
	defer _ = parents.remove(path);
	defer file.close(io);
	const dir = std.fs.path.dirname(path) orelse ".";
	const trax = try tx.appendSliceZ(&self.buf, gpa, path);
	if (self.tbl.items.len > 0) {
		self.tbl.items[self.tbl.items.len - 1].trax = trax;
	}

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	while (r.interface.takeDelimiterExclusive('\n')) |slice| {
		defer _ = r.interface.take(1) catch {};
		var line: [:0]u8 = blk: {
			const trim = tx.trimRange(slice, r.interface.seek - slice.len);
			buf[trim[1]] = 0;
			break :blk buf[trim[0]..trim[1] :0];
		};

		// empty or not [01:23.456]
		if (line.len == 0 or line[0] != '[') {
			continue;
		}
		line = line[1..];
		line = line[tx.trimStart(line, " \t")..];

		// chapter start time in seconds
		var sec: f64 = -1;
		var end: usize = undefined;
		if (iParse(line, &end)) |i| {
			sec = @floatFromInt(i);
			line = line[end..];
		}

		// minute/hour syntax
		while (line[0] == ':') {
			line = line[1..];
			if (iParse(line, &end)) |i| {
				sec = (sec * 60) + @as(f64, @floatFromInt(i));
				line = line[end..];
			}
		}

		// milliseconds
		if (line[0] == '.') {
			line = line[1..];
			if (iParse(line, &end)) |i| {
				const scale: f64 = @floatFromInt(std.math.powi(usize, 10, end) catch 1);
				sec += @as(f64, @floatFromInt(i)) / scale;
				line = line[end..];
			}
		}
		line = line[1..];
		line = line[tx.trimStart(line, " \t")..];

		if (sec == 0 and self.tbl.items.len > 0) {
			self.tbl.items.len -= 1;
		}
		const agg = time + sec;
		if (line[0] == '>') {
			const resolved = try tx.resolveZ(gpa, &.{ dir, line[1..] });
			defer gpa.free(resolved);
			try self.tbl.append(gpa, .{ .time = agg, .trax = .{} });
			try self.traverse(gpa, io, parents, resolved, agg);
		} else {
			if (line[0] == '=') {
				const title = try tx.appendSliceZ(&self.buf, gpa, line[1..]);
				try self.tbl.append(gpa, .{ .time = agg, .trax = trax, .title = title });
			} else {
				try self.tbl.append(gpa, .{ .time = agg, .trax = trax });
			}
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub fn fromPath(gpa: Allocator, io: Io, path: [*:0]const u8) tx.TravError!Chapters {
	const sc = try tx.getSidecar(gpa, io, std.mem.sliceTo(path, 0)) orelse return .{};
	defer gpa.free(sc);
	var parents: StringMap = .empty;
	defer parents.deinit(gpa);
	var self: Chapters = .{};
	errdefer self.deinit(gpa);
	try self.traverse(gpa, io, &parents, sc, 0);
	return self;
}
