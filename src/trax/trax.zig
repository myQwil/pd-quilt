const pd = @import("pd");
const std = @import("std");
pub const Pile = @import("Pile.zig");
pub const Meta = @import("Meta.zig");
pub const Playlist = @import("Playlist.zig");
pub const Chapters = @import("Chapters.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
pub const StringMap = std.StringHashMapUnmanaged(void);
pub const Buffer = std.ArrayList(u8);
pub const putGet = Meta.putGet;

const Oom = Allocator.Error;
pub const TravError = Oom || std.Io.Reader.DelimiterError;
pub const AppendError = Playlist.AppendError;

const trext = ".trax";

pub inline fn find(slice: []const u8, value: u8) ?usize {
	return std.mem.findScalar(u8, slice, value);
}

inline fn findLast(slice: []const u8, value: u8) ?usize {
	return std.mem.findScalarLast(u8, slice, value);
}

pub inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, trext);
}

pub fn trimStart(s: []const u8, exclude: []const u8) usize {
	var a: usize = 0;
	while (a < s.len and find(exclude, s[a]) != null) : (a += 1) {}
	return a;
}

pub fn trimEnd(s: []const u8, exclude: []const u8) usize {
	var z: usize = s.len;
	while (z > 0 and find(exclude, s[z - 1]) != null) : (z -= 1) {}
	return z;
}

pub fn trimRange(line: []const u8, offset: usize) [2]usize {
	const a: usize = trimStart(line, " \t");
	const r: usize = if (line.len > 0 and line[line.len - 1] == '\r') 1 else 0;
	return .{ offset + a, offset + (line.len - r) };
}

pub fn makeLowerCase(s: []u8) void {
	for (s) |*c| {
		c.* = std.ascii.toLower(c.*);
	}
}

pub const Offset = struct { start: u32 = 0, len: u32 = 0 };

pub fn appendSliceZ(buf: *Buffer, gpa: Allocator, str: []const u8) Oom!Offset {
	const amount = str.len + 1;
	try buf.ensureUnusedCapacity(gpa, amount);
	const old_len = buf.items.len;
	buf.items.len += amount;
	@memcpy(buf.items[old_len..][0..str.len], str);
	buf.items[buf.items.len - 1] = 0;
	return .{ .start = @truncate(old_len), .len = @truncate(str.len) };
}

pub fn resolveZ(gpa: Allocator, paths: []const []const u8) Oom![:0]u8 {
	var res = try std.fs.path.resolve(gpa, paths);
	errdefer gpa.free(res);
	if (gpa.resize(res, res.len + 1)) {
		res.len += 1;
	} else {
		res = try gpa.realloc(res, res.len + 1);
	}
	res[res.len - 1] = 0;
	return res[0 .. res.len - 1 :0];
}

/// Print message and skip, do not fail completely by returning error.
pub inline fn err(len: usize, e: anyerror, s: [*:0]const u8, t: [*:0]const u8) void {
	pd.post.err(null, "%u:%s (%s): \"%s\"", .{ len, @errorName(e).ptr, t, s });
}

pub fn pathCheck(
	parents: *StringMap,
	gpa: Allocator,
	io: Io,
	path: [:0]const u8,
) (Oom || Io.File.OpenError || error{InfiniteRecursion})!Io.File {
	if (parents.contains(path)) {
		return error.InfiniteRecursion;
	}
	try parents.put(gpa, path, {});
	errdefer _ = parents.remove(path);
	return try Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
}

pub fn getSidecar(gpa: Allocator, io: Io, path: []const u8) Oom!?[:0]const u8 {
	const sep = std.fs.path.sep;
	const txdir = trext ++ (&sep)[0..1];
	const dot = findLast(path, '.') orelse path.len;
	var trx_path = try gpa.alloc(u8, dot + txdir.len + trext.len + 1);

	const start = if (std.fs.path.dirname(path)) |dir| blk: {
		@memcpy(trx_path[0..dir.len], dir);
		trx_path[dir.len] = sep;
		break :blk dir.len + 1;
	} else 0;

	const stem = path[start..dot];
	var i: usize = start;
	while (true) {
		// try `file.trax`
		@memcpy(trx_path[i..][0..stem.len], stem);
		i += stem.len;
		@memcpy(trx_path[i..][0..trext.len], trext);
		i += trext.len;
		if (Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true })) {
			break;
		} else |_| {}

		// try `.trax/file.trax`
		i = start;
		@memcpy(trx_path[i..][0..txdir.len], txdir);
		i += txdir.len;
		@memcpy(trx_path[i..][0..stem.len], stem);
		i += stem.len;
		@memcpy(trx_path[i..][0..trext.len], trext);
		i += trext.len;
		if (Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true })) {
			break;
		} else |_| {}

		gpa.free(trx_path);
		return null;
	}
	trx_path[i] = 0;
	trx_path = try gpa.realloc(trx_path, i + 1);
	return trx_path[0..i :0];
}

pub fn langReplace(
	self: *[]*pd.Symbol,
	gpa: Allocator,
	args: []const pd.Atom,
) (Oom || error{WrongAtomType})!void {
	var arr: std.ArrayList(*pd.Symbol) = .empty;
	errdefer arr.deinit(gpa);
	var map: std.AutoHashMap(*pd.Symbol, void) = .init(gpa);
	defer map.deinit();

	for (args) |arg| {
		const s = arg.getSymbol() orelse return error.WrongAtomType;
		if (map.get(s) == null) {
			try arr.append(gpa, s);
			try map.put(s, {});
		}
	}
	const slc = try arr.toOwnedSlice(gpa);
	// on success, replace old list with new one
	gpa.free(self.*);
	self.* = slc;
}
