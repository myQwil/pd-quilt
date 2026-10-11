const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const np = @import("numparse.zig");
const iParse = np.iParse;
const fParse = np.fParse;
const tx = @import("trax.zig");
const StringMap = tx.StringMap;

const Chapters = @This();

/// byte array
buf: tx.Buffer = .empty,
/// list of chapter entries
tbl: std.ArrayList(Entry) = .empty,

const Entry = struct {
	time: i64,
	trax: tx.Offset,
	title: ?tx.Offset = null,
};

const Chapter = struct {
	/// start time in microseconds
	time: i64,
	/// chapter metadata trax file
	trax: [:0]const u8,
	/// chapter title
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

const to_usec = 1_000_000;

fn parseTime(str: []const u8, len: ?*usize) ?i64 {
	if (str.len == 0) {
		return null;
	}
	var s = str;

	// chapter start time in seconds
	var l: usize = undefined;
	var no_digits: bool = true;
	var usec: i64 = if (iParse(s, &l)) |i| blk: {
		s = s[l..];
		no_digits = false;
		break :blk i * to_usec;
	} else |_| 0;

	// minute/hour syntax
	while (s.len > 0 and s[0] == ':') {
		s = s[1..];
		usec *= 60;
		if (iParse(s, &l)) |i| {
			usec += i * to_usec;
			no_digits = false;
			s = s[l..];
		} else |_| {}
	}

	// milliseconds
	if (s.len > 0 and s[0] == '.') {
		s = s[1..];
		if (iParse(s, &l)) |i| {
			const ilen: i64 = @intCast(l);
			if (ilen > 6) {
				usec += @divTrunc(i, std.math.powi(i64, 10, ilen - 6) catch 1);
			} else {
				usec += i * (std.math.powi(i64, 10, 6 - ilen) catch 1);
			}
			no_digits = false;
			s = s[l..];
		} else |_| {}
	}

	if (no_digits) {
		return null;
	}
	if (len) |length| {
		length.* = str.len - s.len;
	}
	return usec;
}

test parseTime {
	for ([_]struct { str: []const u8, num: ?i64, len: usize }{
		.{ .str = "123.", .num = 123_000_000, .len = 4 },
		.{ .str = ".125", .num = 125_000, .len = 4 },
		.{ .str = "01:23.125432", .num = 83_125_432, .len = 12 },
		.{ .str = "1:2:34.125", .num = 3_754_125_000, .len = 10 },
		.{ .str = "1::34.125", .num = 3_634_125_000, .len = 9 },
		.{ .str = "0.123456789", .num = 123_456, .len = 11 },
		.{ .str = ":.", .num = null, .len = 0 },
		.{ .str = "2562047788::54.775807", .num = std.math.maxInt(i64), .len = 21 },
	}) |case| {
		var len: usize = 0;
		const num = parseTime(case.str, &len);
		try std.testing.expectEqual(case.num, num);
		try std.testing.expectEqual(case.len, len);
	}
}

fn traverse(
	self: *Chapters,
	gpa: Allocator,
	io: Io,
	parents: *StringMap,
	path: [:0]const u8,
	time: i64,
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
	while (r.interface.takeDelimiterExclusive('\n')) |slc| {
		defer _ = r.interface.take(1) catch {};
		var line = std.mem.trimStart(u8, std.mem.trimEnd(u8, slc, "\r"), tx.wspace);

		// empty or not [01:23.456]
		if (line.len == 0 or line[0] != '[') {
			continue;
		}
		line = std.mem.trimStart(u8, line[1..], tx.wspace);

		var len: usize = undefined;
		const usec = parseTime(line, &len) orelse -1;
		line = std.mem.trimStart(u8, line[len + 1 ..], tx.wspace);

		if (usec == 0 and self.tbl.items.len > 0) {
			self.tbl.items.len -= 1;
		}
		const agg = time + usec;
		if (line[0] == '>') {
			const resolved = try tx.resolveZ(gpa, &.{ dir, line[1..] });
			defer gpa.free(resolved);
			try self.tbl.append(gpa, .{ .time = agg, .trax = .{} });
			try self.traverse(gpa, io, parents, resolved, agg);
		} else if (line[0] == '=') {
			const title = try tx.appendSliceZ(&self.buf, gpa, line[1..]);
			try self.tbl.append(gpa, .{ .time = agg, .trax = trax, .title = title });
		} else {
			try self.tbl.append(gpa, .{ .time = agg, .trax = trax });
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub fn fromPath(gpa: Allocator, io: Io, path: []const u8) tx.TravError!Chapters {
	const sc = try tx.getSidecar(gpa, io, path) orelse return .{};
	defer gpa.free(sc);
	var parents: StringMap = .empty;
	defer parents.deinit(gpa);
	var self: Chapters = .{};
	errdefer self.deinit(gpa);
	try self.traverse(gpa, io, &parents, sc, 0);
	return self;
}
