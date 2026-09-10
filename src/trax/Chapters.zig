const Chapters = @This();

const std = @import("std");
const tx = @import("trax.zig");
const iParse = @import("../misc/numparse.zig").iParse;

const Io = std.Io;
const Allocator = std.mem.Allocator;
const StringMap = tx.StringMap;

/// byte array
buf: tx.Buffer = .empty,
/// ending offset of each string
tbl: std.ArrayList(Entry) = .empty,

const Enum = enum { bare, title, trax };
const Entry = struct {
	time: f64,
	typ: Enum,
	end: u32,
};

pub fn deinit(self: *Chapters, gpa: Allocator) void {
	self.buf.deinit(gpa);
	self.tbl.deinit(gpa);
}

pub fn append(
	self: *Chapters,
	gpa: Allocator,
	time: f64,
	typ: Enum,
	str: []const u8,
) Allocator.Error!void {
	try tx.appendSliceZ(&self.buf, gpa, str);
	const end: u32 = @truncate(self.buf.items.len);
	try self.tbl.append(gpa, .{ .time = time, .typ = typ, .end = end });
}

pub fn get(self: *const Chapters, index: usize) [:0]const u8 {
	std.debug.assert(index < self.tbl.items.len);
	const start = if (index == 0) 0 else self.tbl.items[index - 1].end;
	return self.buf.items[start .. self.tbl.items[index].end - 1 :0];
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
		catch |e| return tx.err(0, e, path.ptr, "meta");
	defer _ = parents.remove(path);
	defer file.close(io);
	const dir = std.fs.path.dirname(path) orelse ".";

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
			self.buf.items.len -= self.get(self.tbl.items.len - 1).len + 1;
			self.tbl.items.len -= 1;
		}
		const agg = time + sec;
		if (line[0] == '>') {
			const resolved = try tx.resolveZ(gpa, &.{ dir, line[1..] });
			defer gpa.free(resolved);
			try self.append(gpa, agg, .trax, resolved);
		} else {
			const typ: Enum = if (line[0] == '=') .title else .bare;
			const title = line[(if (typ == .bare) 0 else 1)..];
			try self.append(gpa, agg, typ, title);
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub fn fromPath(gpa: Allocator, io: Io, path: [*:0]const u8) tx.TravError!Chapters {
	const sidecar = try tx.getSidecar(gpa, io, std.mem.sliceTo(path, 0))
		orelse return .{};
	defer gpa.free(sidecar);
	var parents: StringMap = .empty;
	defer parents.deinit(gpa);
	var self: Chapters = .{};
	errdefer self.deinit(gpa);
	try self.traverse(gpa, io, &parents, sidecar, 0);
	return self;
}
