const std = @import("std");
const pd = @import("pd");

const Symbol = pd.Symbol;
const StringHashMap = std.StringHashMap(void);
const ArrayList = std.ArrayList(*Symbol);

const trext = ".trax";
const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.io();

const LangDict = struct {
	dict: Dict,
	default: *Symbol,

	const Dict = std.AutoArrayHashMap(*Symbol, *Symbol);

	fn init(lang: *Symbol, value: *Symbol) !LangDict {
		var dict: Dict = .init(gpa);
		try dict.put(lang, value);
		return .{ .dict = dict, .default = lang };
	}

	fn add(self: *LangDict, lang: *Symbol, value: *Symbol) !void {
		try self.dict.put(lang, value);
		if (lang == pd.s.empty()) {
			self.default = pd.s.empty();
		}
	}

	pub fn get(self: *const LangDict, pref_langs: []*Symbol) *Symbol {
		for (pref_langs) |s| {
			// exact match
			if (self.dict.get(s)) |value| {
				return value;
			}
			// prefix match (fuzzy)
			const pref = std.mem.sliceTo(s.name, 0);
			var iter = self.dict.iterator();
			while (iter.next()) |kv| {
				const lang = std.mem.sliceTo(kv.key_ptr.*.name, 0);
				if (std.mem.startsWith(u8, lang, pref)) {
					return kv.value_ptr.*;
				}
			}
		}
		return self.dict.get(self.default).?;
	}
};

const MetaHashMap = struct {
	map: std.AutoArrayHashMap(*Symbol, LangDict),

	pub fn deinit(self: *MetaHashMap) void {
		var iter = self.map.iterator();
		while (iter.next()) |kv| {
			kv.value_ptr.dict.deinit();
		}
		self.map.deinit();
	}

	fn add(self: *MetaHashMap, key: *Symbol, lang: *Symbol, value: *Symbol) !void {
		if (self.map.getPtr(key)) |ld| {
			try ld.add(lang, value);
		} else {
			try self.map.put(key, try .init(lang, value));
		}
	}
};

inline fn find(slice: []const u8, value: u8) ?usize {
	return std.mem.findScalar(u8, slice, value);
}

inline fn findLast(slice: []const u8, value: u8) ?usize {
	return std.mem.findScalarLast(u8, slice, value);
}

inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, trext);
}

/// Print message and skip, do not fail completely by returning error.
inline fn err(len: usize, e: anyerror, s: [*:0]const u8) void {
	pd.post.err(null, "%u:%s: \"%s\"", .{ len, @errorName(e).ptr, s });
}

fn trimStart(s: []const u8, exclude: []const u8) usize {
	var a: usize = 0;
	while (a < s.len and find(exclude, s[a]) != null) : (a += 1) {}
	return a;
}

fn trimEnd(s: []const u8, exclude: []const u8) usize {
	var z: usize = s.len;
	while (z > 0 and find(exclude, s[z - 1]) != null) : (z -= 1) {}
	return z;
}

fn trimRange(line: []const u8, offset: usize) [2]usize {
	const tstart: usize = trimStart(line, " \t");
	const tend: usize = tstart + trimEnd(line[tstart..], "\r");
	return .{ offset + tstart, offset + tend };
}

fn resolveZ(allocator: std.mem.Allocator, paths: []const []const u8) ![:0]u8 {
	var res = try std.fs.path.resolve(allocator, paths);
	errdefer allocator.free(res);
	if (allocator.resize(res, res.len + 1)) {
		res.len += 1;
	} else {
		res = try allocator.realloc(res, res.len + 1);
	}
	res[res.len - 1] = 0;
	return res[0 .. res.len - 1 :0];
}

test resolveZ {
	const actual = try resolveZ(std.testing.allocator, &.{"/a/b/c", "/d/e/f"});
	defer std.testing.allocator.free(actual);
	try std.testing.expectEqualStrings("/d/e/f", actual);
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

		const resolved = try resolveZ(gpa, &.{ base_dir, trimmed[1..] });
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
		return err(meta.map.count(), error.InfiniteRecursion, file_path.ptr);
	}
	try parents.put(file_path, {});
	defer _ = parents.remove(file_path);

	const file = std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
		catch |e| return err(meta.map.count(), e, file_path.ptr);
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

		// key[lang]=value
		if (trimmed[0] != '!') {
			const eql = find(trimmed, '=') orelse continue;
			const end = trimEnd(trimmed[0..eql], " \t");
			var lang: [:0]const u8 = "";
			const kend = if (find(trimmed[0..end], '[')) |brac| blk: {
				const lbeg = brac + 1;
				const lend = if (find(trimmed[lbeg..end], ']')) |b| lbeg + b else end;
				trimmed[lend] = 0;
				lang = trimmed[lbeg..lend :0];
				break :blk brac;
			} else end;
			trimmed[kend] = 0;
			const key = trimmed[0..kend :0];

			buf[trim[1]] = 0;
			const val: [:0]const u8 = buf[trim[0] + eql + 1 .. trim[1] :0];
			try meta.add(.gen(key), .gen(lang), .gen(val));
			continue;
		}

		const command = trimmed[1..];

		// !include @path
		const inc = "include";
		if (std.mem.startsWith(u8, command, inc)) {
			const arg = blk: {
				const arg = command[inc.len..];
				break :blk arg[trimStart(arg, " \t")..];
			};
			if (arg.len == 0 or arg[0] != '@') {
				err(meta.map.count(), error.IncludeSyntaxError, file_path.ptr);
				continue;
			}
			const resolved = try resolveZ(gpa, &.{ base_dir, arg[1..] });
			defer gpa.free(resolved);
			try traverseMeta(meta, parents, resolved);
			continue;
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

inline fn getSidecar(path: []const u8) !?[:0]const u8 {
	const txdir = trext ++ "/";
	const dot = findLast(path, '.') orelse path.len;
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
	var meta: MetaHashMap = .{ .map = .init(gpa) };
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
	/// allocated length
	cap: usize = 0,

	pub fn deinit(self: *Playlist) void {
		gpa.free(self.ptr[0..self.cap]);
		self.* = undefined;
	}

	pub fn append(self: *Playlist, av: []const pd.Atom) !void {
		var list: ArrayList = .{
			.items = self.ptr[0..self.len],
			.capacity = self.cap,
		};
		defer self.* = .{
			.ptr = list.items.ptr,
			.len = list.items.len,
			.cap = list.capacity,
		};

		for (av) |arg| {
			const sym = arg.getSymbol() orelse return error.NotASymbol;
			const name = std.mem.sliceTo(sym.name, 0);
			if (isTrax(name)) {
				var parents: StringHashMap = .init(gpa);
				defer parents.deinit();
				try traverseList(&list, &parents, name);
			} else {
				try list.append(gpa, sym);
			}
		}
	}

	pub fn replaceWith(self: *Playlist, av: []const pd.Atom) !void {
		var playlist: Playlist = .{};
		errdefer playlist.deinit();
		try playlist.append(av);
		// on success, replace old list with new one
		self.deinit();
		self.* = playlist;
	}
};

pub const LangSet = extern struct {
	/// list of preferred language codes
	ptr: [*]*Symbol = &.{},
	/// length of the list
	len: usize = 0,

	pub fn deinit(self: *LangSet) void {
		gpa.free(self.ptr[0..self.len]);
	}

	pub fn replaceWith(self: *LangSet, args: []const pd.Atom) !void {
		var arr: ArrayList = .empty;
		errdefer arr.deinit(gpa);
		var set: std.AutoHashMap(*Symbol, void) = .init(gpa);
		defer set.deinit();

		for (args) |arg| {
			if (arg.getSymbol()) |s| {
				if (set.get(s) == null) {
					try arr.append(gpa, s);
					try set.put(s, {});
				}
			}
		}
		const slice = try arr.toOwnedSlice(gpa);
		// on success, replace old list with new one
		self.deinit();
		self.ptr = slice.ptr;
		self.len = slice.len;
	}
};
