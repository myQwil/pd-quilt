const Playlist = @This();

const pd = @import("pd");
const std = @import("std");
const tx = @import("trax.zig");

const Atom = pd.Atom;
const Io = std.Io;
const Allocator = std.mem.Allocator;
const StringMap = tx.StringMap;

/// byte array
buf: tx.Buffer = .empty,
/// ending offset of each string
tbl: std.ArrayList(u32) = .empty,

pub fn deinit(self: *Playlist, gpa: Allocator) void {
	self.buf.deinit(gpa);
	self.tbl.deinit(gpa);
}

pub fn append(self: *Playlist, gpa: Allocator, str: []const u8) Allocator.Error!void {
	_ = try tx.appendSliceZ(&self.buf, gpa, str);
	try self.tbl.append(gpa, @truncate(self.buf.items.len));
}

pub fn get(self: *const Playlist, index: usize) [:0]const u8 {
	std.debug.assert(index < self.tbl.items.len);
	const start = if (index == 0) 0 else self.tbl.items[index - 1];
	return self.buf.items[start .. self.tbl.items[index] - 1 :0];
}

fn traverse(
	self: *Playlist,
	gpa: Allocator,
	io: Io,
	parents: *StringMap,
	path: [:0]const u8,
) tx.TravError!void {
	const file = tx.pathCheck(parents, gpa, io, path)
		catch |e| return tx.err(self.tbl.items.len, e, path.ptr, "list");
	defer _ = parents.remove(path);
	defer file.close(io);
	const dir = std.fs.path.dirname(path) orelse ".";

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	while (r.interface.takeDelimiterExclusive('\n')) |slice| {
		defer _ = r.interface.take(1) catch {};
		const line = blk: {
			const trim = tx.trimRange(slice, 0);
			break :blk slice[trim[0]..trim[1]];
		};

		// empty or not >path
		if (line.len == 0 or line[0] != '>') {
			continue;
		}

		const resolved = try tx.resolveZ(gpa, &.{ dir, line[1..] });
		defer gpa.free(resolved);
		if (tx.isTrax(resolved)) {
			try self.traverse(gpa, io, parents, resolved);
		} else {
			try self.append(gpa, resolved);
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub const AppendError = tx.TravError || error{WrongAtomType};

pub fn appendArgs(
	self: *Playlist,
	gpa: Allocator,
	io: Io,
	av: []const Atom,
) AppendError!void {
	for (av) |arg| {
		const sym = arg.getSymbol() orelse return error.WrongAtomType;
		const name = std.mem.sliceTo(sym.name, 0);
		if (tx.isTrax(name)) {
			var parents: StringMap = .empty;
			defer parents.deinit(gpa);
			try self.traverse(gpa, io, &parents, name);
		} else {
			try self.append(gpa, name);
		}
	}
}

pub fn replace(
	self: *Playlist,
	gpa: Allocator,
	io: Io,
	av: []const Atom,
) AppendError!void {
	var list: Playlist = .{};
	errdefer list.deinit(gpa);
	try list.appendArgs(gpa, io, av);
	// on success, replace old list with new one
	self.deinit(gpa);
	self.* = list;
}
