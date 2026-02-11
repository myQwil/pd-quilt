const std = @import("std");
const pd = @import("pd");

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.ioBasic();

const Symbol = pd.Symbol;
const StringHashMap = std.StringHashMapUnmanaged(void);
const MetaHashMap = std.AutoArrayHashMapUnmanaged(*Symbol, *Symbol);

inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, ".trax");
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

fn putAll(old: *MetaHashMap, new: MetaHashMap) !void {
	var it = new.iterator();
	while (it.next()) |kv| {
		try old.put(gpa, kv.key_ptr.*, kv.value_ptr.*);
	}
}

const Metadata = extern struct {
	bytes: [*]align(@alignOf(MetaHashMap.Data)) u8 = undefined,
	len: usize = 0,
	capacity: usize = 0,
	bit_index: ?*align(@alignOf(u32)) anyopaque = null,

	fn asHashMap(self: Metadata) MetaHashMap {
		return .{
			.entries = .{
				.bytes = self.bytes,
				.len = self.len,
				.capacity = self.capacity,
			},
			.index_header = @ptrCast(self.bit_index),
		};
	}

	fn fromHashMap(map: MetaHashMap) Metadata {
		return .{
			.bytes = map.entries.bytes,
			.len = map.entries.len,
			.capacity = map.entries.capacity,
			.bit_index = map.index_header,
		};
	}

	pub fn get(self: Metadata, key: *Symbol) ?*Symbol {
		return self.asHashMap().get(key);
	}

	pub fn iterator(self: Metadata) MetaHashMap.Iterator {
		return self.asHashMap().iterator();
	}
};

const Entry = extern struct {
	/// path to the file
	file: *Symbol,
	/// file metadata
	meta: Metadata = .{},
};
const EntryList = std.ArrayList(Entry);

pub const Trax = struct {
	/// list of entries/traxs
	list: std.ArrayListUnmanaged(Union) = .{},
	/// global metadata
	meta: MetaHashMap = .{},

	const Union = union(enum) {
		media: Media,
		trax: Trax,
	};

	const Media = struct {
		/// path to the file
		file: *Symbol,
		/// file metadata
		meta: MetaHashMap = .{},
	};

	fn deinit(self: *Trax) void {
		for (self.list.items) |un| switch (un) {
			.media => |m| { var v = m; v.meta.deinit(gpa); },
			.trax  => |t| { var v = t; v.deinit(); },
		};
		self.list.deinit(gpa);
		self.meta.deinit(gpa);
	}

	fn traverse(
		self: *Trax,
		parents: *StringHashMap,
		file_path: []const u8,
	) !void {
		if (parents.contains(file_path)) {
			return err(self.list.items.len, error.InfiniteRecursion, file_path.ptr);
		}
		try parents.put(gpa, file_path, {});
		defer _ = parents.remove(file_path);

		const file = std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
			catch |e| return err(self.list.items.len, e, file_path.ptr);
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

			// empty or comment
			if (begin >= end or buf[begin] == '#') {
				continue;
			}

			// file path
			if (buf[begin] == '@') {
				const trimmed = buf[begin + 1 .. end];
				const resolved = if (std.fs.path.isAbsolute(trimmed))
					try resolveZ(&.{ trimmed })
				else try resolveZ(&.{ base_dir, trimmed });
				defer gpa.free(resolved);

				if (isTrax(resolved)) {
					var trax: Trax = .{};
					try trax.traverse(parents, resolved);
					try self.list.append(gpa, .{ .trax = trax });
				} else {
					try self.list.append(gpa, .{ .media = .{ .file = .gen(resolved.ptr) } });
				}
				continue;
			}

			// key=value
			const eql = std.mem.findScalar(u8, buf[begin..end], '=') orelse continue;
			const kend = trimEnd(buf[begin..][0..eql], " \t");
			buf[end] = 0;
			buf[begin + kend] = 0;
			const key = buf[begin..][0..kend :0];
			const val = buf[begin + eql + 1 .. end :0];
			if (self.list.items.len == 0) {
				try self.meta.put(gpa, .gen(key), .gen(val));
			} else switch (self.list.items[self.list.items.len - 1]) {
				inline else => |*v| try v.meta.put(gpa, .gen(key), .gen(val)),
			}
		} else |e| if (e != error.EndOfStream) {
			return e;
		}
	}

	fn flatten(self: Trax, list: *EntryList) !void {
		for (self.list.items) |*item| {
			var meta: MetaHashMap = try self.meta.clone(gpa);
			switch (item.*) {
				.media => |m| {
					try putAll(&meta, m.meta);
					try list.append(gpa, .{ .file = m.file, .meta = .fromHashMap(meta) });
				},
				.trax => |t| {
					try putAll(&meta, t.meta);
					item.*.trax.meta.deinit(gpa);
					item.*.trax.meta = meta;
					try item.*.trax.flatten(list);
				}
			}
		}
	}
};

pub const Playlist = extern struct {
	/// list of tracks
	ptr: [*]Entry = &.{},
	/// length of the list
	len: usize = 0,

	pub fn deinit(self: *Playlist) void {
		for (self.ptr[0..self.len]) |entry| {
			var map = entry.meta.asHashMap();
			map.deinit(gpa);
		}
		gpa.free(self.ptr[0..self.len]);
	}

	pub fn fromArgs(av: []const pd.Atom) !Playlist {
		var trax: Trax = .{};
		defer trax.deinit();
		var parents: StringHashMap = .{};
		defer parents.deinit(gpa);

		for (av) |arg| {
			const sym = arg.getSymbol() orelse return error.NotASymbol;
			const name = std.mem.sliceTo(sym.name, 0);
			if (isTrax(name)) {
				try trax.traverse(&parents, name);
			} else {
				try trax.list.append(gpa, .{ .media = .{ .file = .gen(name) } });
			}
		}

		var list: EntryList = .{};
		errdefer list.deinit(gpa);
		try trax.flatten(&list);
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
