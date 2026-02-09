const std = @import("std");
const pd = @import("pd");

const Symbol = pd.Symbol;
const Entry = extern struct {
	/// path to the file
	file: *Symbol,
};

const EntryList = std.ArrayList(Entry);
const StringHashMap = std.StringHashMapUnmanaged(void);

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.ioBasic();

inline fn isPList(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, ".plist");
}

/// Print message and skip, do not fail completely by returning error.
inline fn err(len: usize, e: anyerror, s: [*]const u8) void {
	pd.post.err(null, "%u:%s: \"%s\"", .{ len, @errorName(e).ptr, s });
}

pub fn trimRange(
	s: []const u8,
	exclude_begin: []const u8,
	exclude_end: []const u8,
) struct { usize, usize } {
	var a: usize = 0;
	var z: usize = s.len;
	while (a < z and std.mem.findScalar(u8, exclude_begin, s[a]) != null) : (a += 1) {}
	while (z > a and std.mem.findScalar(u8, exclude_end, s[z - 1]) != null) : (z -= 1) {}
	return .{ a, z };
}

pub fn trimEnd(s: []const u8, exclude: []const u8) usize {
	var z: usize = s.len;
	while (z > 0 and std.mem.findScalar(u8, exclude, s[z - 1]) != null) : (z -= 1) {}
	return z;
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
	return res[0..res.len - 1 :0];
}

fn traverse(
	list: *EntryList,
	parents: *StringHashMap,
	file_path: []const u8,
) !void {
	if (parents.contains(file_path)) {
		return err(list.items.len, error.InfiniteRecursion, file_path.ptr);
	}
	try parents.put(gpa, file_path, {});
	defer _ = parents.remove(file_path);

	const file = std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
		catch |e| return err(list.items.len, e, file_path.ptr);
	defer file.close(io);

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	const base_dir = std.fs.path.dirname(file_path) orelse ".";
	while (r.interface.takeDelimiterExclusive('\n')) |line| {
		defer _ = r.interface.take(1) catch {};
		const line_start = r.interface.seek - line.len;
		const trim = trimRange(line, " \t", "\r");
		const begin = line_start + trim[0];
		const end = line_start + trim[1];
		if (begin >= end or buf[begin] == '#') {
			continue;
		}

		if (buf[begin] != '@') {
			continue;
		}

		// new list item starts with '@'
		const trimmed = buf[begin + 1 .. end];
		const resolved = if (std.fs.path.isAbsolute(trimmed))
			try resolveZ(&.{ trimmed })
		else try resolveZ(&.{ base_dir, trimmed });
		defer gpa.free(resolved);

		if (isPList(resolved)) {
			try traverse(list, parents, resolved);
		} else {
			try list.append(gpa, .{ .file = .gen(resolved.ptr) });
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub const Playlist = extern struct {
	/// list of tracks
	ptr: [*]Entry = &.{},
	/// length of the list
	len: usize = 0,

	pub fn deinit(self: *Playlist) void {
		gpa.free(self.ptr[0..self.len]);
	}

	pub fn fromArgs(av: []const pd.Atom) !Playlist {
		var list: EntryList = .{};
		errdefer list.deinit(gpa);

		var parents: StringHashMap = .{};
		defer parents.deinit(gpa);

		for (av) |arg| {
			const sym = arg.getSymbol() orelse return error.NotASymbol;
			const name = std.mem.sliceTo(sym.name, 0);
			if (isPList(name)) {
				try traverse(&list, &parents, name);
			} else {
				try list.append(gpa, .{ .file = .gen(name) });
			}
		}
		list.shrinkAndFree(gpa, list.items.len);
		return .{
			.ptr = list.items.ptr,
			.len = list.capacity,
		};
	}

	pub fn readArgs(self: *Playlist, av: []const pd.Atom) !void {
		const playlist: Playlist = try .fromArgs(av);
		// on success, replace old list with new one
		self.deinit();
		self.* = playlist;
	}
};
