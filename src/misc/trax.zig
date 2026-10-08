const pd = @import("pd");
const std = @import("std");
pub const Pile = @import("trax.Pile.zig");
pub const Meta = @import("trax.Meta.zig");
pub const Playlist = @import("trax.Playlist.zig");
pub const Chapters = @import("trax.Chapters.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
pub const StringMap = std.StringHashMapUnmanaged(void);
pub const Buffer = std.ArrayList(u8);
pub const putGet = Meta.putGet;

const Oom = Allocator.Error;
pub const TravError = Oom || std.Io.Reader.DelimiterError;
pub const AppendError = Playlist.AppendError;

const trext = ".trax";

pub inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, trext);
}

pub const wspace = " \t";

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
pub inline fn err(len: usize, e: anyerror, str: [*:0]const u8, typ: [*:0]const u8) void {
	pd.post.err(null, "%u:%s (%s): \"%s\"", .{ len, @errorName(e).ptr, typ, str });
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
	const dirname = std.fs.path.dirname(path);
	const start = if (dirname) |dir| dir.len + 1 else 0;
	const name = path[start..];
	const stem = name[0 .. std.mem.findScalarLast(u8, name, '.') orelse name.len];

	var trx_path = try gpa.alloc(u8, start + stem.len + txdir.len + trext.len + 1);
	if (dirname) |dir| {
		@memcpy(trx_path[0..dir.len], dir);
		trx_path[dir.len] = sep;
	}
	var i: usize = start;
	while (true) {
		// try `file.trax`
		@memcpy(trx_path[i..][0..stem.len], stem);
		i += stem.len;
		@memcpy(trx_path[i..][0..trext.len], trext);
		i += trext.len;
		if (Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true })) {
			trx_path = try gpa.realloc(trx_path, i + 1);
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
	return trx_path[0..i :0];
}

test getSidecar {
	const gpa = std.testing.allocator;
	const io = std.testing.io;

	var sidecar = try getSidecar(gpa, io, "help/plist/trax/hello")
		orelse return error.FileNotFound;
	try std.testing.expectEqualStrings("help/plist/trax/.trax/hello.trax", sidecar);
	gpa.free(sidecar);

	sidecar = try getSidecar(gpa, io, "help/plist/trax/world")
		orelse return error.FileNotFound;
	try std.testing.expectEqualStrings("help/plist/trax/world.trax", sidecar);
	gpa.free(sidecar);
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
