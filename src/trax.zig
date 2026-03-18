const std = @import("std");
const pd = @import("pd");

const Symbol = pd.Symbol;
const StringHashMap = std.StringHashMap(void);
const MetaHashMap = std.AutoArrayHashMap(*Symbol, *Symbol);
const ArrayList = std.ArrayList(*Symbol);

const trext = ".trax";
const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.io();

inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, trext);
}

/// Print message and skip, do not fail completely by returning error.
inline fn err(len: usize, e: anyerror, s: [*:0]const u8) void {
	pd.post.err(null, "%u:%s: \"%s\"", .{ len, @errorName(e).ptr, s });
}

fn trimStart(s: []const u8, exclude: []const u8) usize {
	var a: usize = 0;
	while (a < s.len and std.mem.findScalar(u8, exclude, s[a]) != null) : (a += 1) {}
	return a;
}

fn trimEnd(s: []const u8, exclude: []const u8) usize {
	var z: usize = s.len;
	while (z > 0 and std.mem.findScalar(u8, exclude, s[z - 1]) != null) : (z -= 1) {}
	return z;
}

fn trimRange(line: []const u8, offset: usize) [2]usize {
	const tstart: usize = trimStart(line, " \t");
	const tend: usize = tstart + trimEnd(line[tstart..], "\r");
	return .{ offset + tstart, offset + tend };
}

fn resolveZ(paths: []const []const u8) ![:0]u8 {
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

inline fn getResolved(base_dir: []const u8, path: []const u8) ![:0]u8 {
	return if (std.fs.path.isAbsolute(path))
		try resolveZ(&.{ path })
	else
		try resolveZ(&.{ base_dir, path });
}

fn traverseList(
	list: *ArrayList,
	parents: *StringHashMap,
	file_path: [:0]const u8,
) !void {
	if (parents.contains(file_path)) {
		return err(list.items.len, error.InfiniteRecursion, file_path.ptr);
	}
	try parents.put(file_path, {});
	defer _ = parents.remove(file_path);

	const file = std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
		catch |e| return err(list.items.len, e, file_path.ptr);
	defer file.close(io);

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	const base_dir = std.fs.path.dirname(file_path) orelse ".";
	while (r.interface.takeDelimiterExclusive('\n')) |line| {
		defer _ = r.interface.take(1) catch {};
		const trimmed = blk: {
			const trim = trimRange(line, 0);
			break :blk line[trim[0]..trim[1]];
		};

		// empty or not @path
		if (trimmed.len == 0 or trimmed[0] != '@') {
			continue;
		}

		const resolved = try getResolved(base_dir, trimmed[1..]);
		defer gpa.free(resolved);
		if (isTrax(resolved)) {
			try traverseList(list, parents, resolved);
		} else {
			try list.append(gpa, .gen(resolved.ptr));
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

fn traverseMeta(
	meta: *MetaHashMap,
	parents: *StringHashMap,
	file_path: [:0]const u8,
) !void {
	if (parents.contains(file_path)) {
		return err(meta.count(), error.InfiniteRecursion, file_path.ptr);
	}
	try parents.put(file_path, {});
	defer _ = parents.remove(file_path);

	const file = std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
		catch |e| return err(meta.count(), e, file_path.ptr);
	defer file.close(io);

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	const base_dir = std.fs.path.dirname(file_path) orelse ".";
	while (r.interface.takeDelimiterExclusive('\n')) |line| {
		defer _ = r.interface.take(1) catch {};
		const trim = trimRange(line, r.interface.seek - line.len);
		const trimmed = buf[trim[0]..trim[1]];

		// empty or comment
		if (trimmed.len == 0 or trimmed[0] == '#') {
			continue;
		}

		// @path
		if (trimmed[0] == '@') {
			break;
		}

		// !include @path
		const inc = "!include";
		if (std.mem.startsWith(u8, trimmed, inc)) {
			const arg = blk: {
				const arg = trimmed[inc.len..];
				break :blk arg[trimStart(arg, " \t")..];
			};
			if (arg.len == 0 or arg[0] != '@') {
				err(meta.count(), error.IncludeSyntaxError, file_path.ptr);
				continue;
			}
			const resolved = try getResolved(base_dir, arg[1..]);
			defer gpa.free(resolved);
			try traverseMeta(meta, parents, resolved);
			continue;
		}

		// key=value
		const eql = std.mem.findScalar(u8, trimmed, '=') orelse continue;
		const kend = trimEnd(trimmed[0..eql], " \t");
		buf[trim[1]] = 0;
		buf[trim[0] + kend] = 0;
		const key = buf[trim[0]..][0..kend :0];
		const val = buf[trim[0] + eql + 1 .. trim[1] :0];
		try meta.put(.gen(key), .gen(val));
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

inline fn getSidecar(path: []const u8) !?[:0]const u8 {
	const txdir = trext ++ "/";
	const dot = std.mem.findScalarLast(u8, path, '.') orelse path.len;
	var trx_path = try gpa.alloc(u8, dot + txdir.len + trext.len + 1);

	// first try `dir/.trax/file.trax`, then `dir/file.trax`
	var i: usize = 0;
	if (std.fs.path.dirname(path)) |dir| {
		@memcpy(trx_path[0..dir.len], dir);
		trx_path[dir.len] = '/';
		i += dir.len + 1;
	}
	const base = path[i..dot];
	@memcpy(trx_path[i..][0..txdir.len], txdir);
	i += txdir.len;
	@memcpy(trx_path[i..][0..base.len], base);
	i += base.len;
	@memcpy(trx_path[i..][0..trext.len], trext);
	i += trext.len;
	std.Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true }) catch {
		@memcpy(trx_path[0..dot], path[0..dot]);
		@memcpy(trx_path[dot..][0..trext.len], trext);
		i = dot + trext.len;
		std.Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true }) catch {
			gpa.free(trx_path);
			return null;
		};
	};
	trx_path[i] = 0;

	std.debug.assert(i + 1 <= trx_path.len);
	trx_path = gpa.realloc(trx_path, i + 1) catch unreachable;
	return trx_path[0..i :0];
}

pub fn metadata(path: [*:0]const u8) !?MetaHashMap {
	const sidecar = try getSidecar(std.mem.sliceTo(path, 0)) orelse return null;
	defer gpa.free(sidecar);
	var meta: MetaHashMap = .init(gpa);
	errdefer meta.deinit();
	var parents: StringHashMap = .init(gpa);
	defer parents.deinit();

	try traverseMeta(&meta, &parents, sidecar);
	return meta;
}

pub const Playlist = extern struct {
	/// list of tracks
	ptr: [*]*Symbol = &.{},
	/// length of the list
	len: usize = 0,

	pub fn deinit(self: *Playlist) void {
		gpa.free(self.ptr[0..self.len]);
	}

	pub fn fromArgs(av: []const pd.Atom) !Playlist {
		var list: ArrayList = .empty;
		errdefer list.deinit(gpa);
		var parents: StringHashMap = .init(gpa);
		defer parents.deinit();

		for (av) |arg| {
			const sym = arg.getSymbol() orelse return error.NotASymbol;
			const name = std.mem.sliceTo(sym.name, 0);
			if (isTrax(name)) {
				try traverseList(&list, &parents, name);
			} else {
				try list.append(gpa, sym);
			}
		}

		const owned = try list.toOwnedSlice(gpa);
		return .{
			.ptr = owned.ptr,
			.len = owned.len,
		};
	}

	pub fn readArgs(self: *Playlist, av: []const pd.Atom) !void {
		const playlist: Playlist = try .fromArgs(av);
		// on success, replace old list with new one
		self.deinit();
		self.* = playlist;
	}
};
