const std = @import("std");
const pd = @import("pd");
const path = std.fs.path;

const ArrayList = std.ArrayList(*pd.Symbol);
const StringHashMap = std.StringHashMap(void);

const mem = pd.mem;

inline fn isM3u(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, ".m3u");
}

/// Print message and skip, do not fail completely by returning error.
inline fn err(len: usize, e: anyerror, s: [*]const u8) void {
	pd.post.err(null, "%u:%s: \"%s\"", .{ len, @errorName(e).ptr, s });
}

fn resolveZ(paths: []const []const u8) ![:0]u8 {
	var res = try path.resolve(mem, paths);
	errdefer mem.free(res);
	if (mem.resize(res, res.len + 1)) {
		res.len += 1;
	} else {
		res = try mem.realloc(res, res.len + 1);
	}
	res[res.len - 1] = 0;
	return res[0..res.len - 1 :0];
}

fn traverse(
	list: *ArrayList,
	parents: *StringHashMap,
	file_path: []const u8,
) !void {
	if (parents.contains(file_path)) {
		return err(list.items.len, error.InfiniteRecursion, file_path.ptr);
	}
	try parents.put(file_path, {});
	defer _ = parents.remove(file_path);

	const file = std.fs.cwd().openFile(file_path, .{ .mode = .read_only })
		catch |e| return err(list.items.len, e, file_path.ptr);
	defer file.close();

	var buf: [std.fs.max_path_bytes]u8 = undefined;
	var r = file.reader(&buf);
	const base_dir = path.dirname(file_path) orelse ".";
	while (r.interface.takeDelimiterExclusive('\n')) |line| {
		defer _ = r.interface.take(1) catch {};
		const trimmed = std.mem.trim(u8, line, " \r");
		if (trimmed.len == 0 or trimmed[0] == '#') {
			continue;
		}
		const resolved = if (path.isAbsolute(trimmed))
			try resolveZ(&.{ trimmed })
		else try resolveZ(&.{ base_dir, trimmed });
		defer mem.free(resolved);

		if (isM3u(resolved)) {
			try traverse(list, parents, resolved);
		} else {
			try list.append(mem, .gen(resolved.ptr));
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub const Playlist = extern struct {
	/// m3u list of tracks
	ptr: [*]*pd.Symbol = &.{},
	/// current length of the list
	len: usize = 0,
	/// size of the allocation
	cap: usize = 0,

	inline fn asArrayList(self: *const Playlist) ArrayList {
		return .{
			.items = self.ptr[0..0],
			.capacity = self.cap,
		};
	}

	inline fn fromArrayList(list: *const ArrayList) Playlist {
		return .{
			.ptr = list.items.ptr,
			.len = list.items.len,
			.cap = list.capacity,
		};
	}

	pub fn deinit(self: *Playlist) void {
		var list = self.asArrayList();
		list.deinit(mem);
	}

	pub fn fromArgs(av: []const pd.Atom) !Playlist {
		var list: ArrayList = .{};
		errdefer list.deinit(mem);

		var parents: StringHashMap = .init(mem);
		defer parents.deinit();

		for (av) |arg| {
			if (arg.type != .symbol) {
				return error.NotASymbol;
			}
			const name = std.mem.sliceTo(arg.w.symbol.name, 0);
			if (isM3u(name)) {
				try traverse(&list, &parents, name);
			} else {
				try list.append(mem, .gen(name));
			}
		}
		return .fromArrayList(&list);
	}

	pub fn readArgs(self: *Playlist, av: []const pd.Atom) !void {
		const playlist: Playlist = try .fromArgs(av);
		// on success, replace old list with new one
		self.deinit();
		self.* = playlist;
	}
};
