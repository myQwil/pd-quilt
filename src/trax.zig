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

	const Dict = std.array_hash_map.Auto(*Symbol, *Symbol);

	fn init(lang: *Symbol, value: *Symbol) !LangDict {
		var dict: Dict = .empty;
		try dict.put(gpa, lang, value);
		return .{ .dict = dict, .default = lang };
	}

	fn add(self: *LangDict, lang: *Symbol, value: *Symbol) !void {
		try self.dict.put(gpa, lang, value);
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

pub const MetaHashMap = struct {
	map: std.array_hash_map.Auto(*Symbol, LangDict) = .empty,

	pub fn deinit(self: *MetaHashMap) void {
		var iter = self.map.iterator();
		while (iter.next()) |kv| {
			kv.value_ptr.dict.deinit(gpa);
		}
		self.map.deinit(gpa);
	}

	fn add(self: *MetaHashMap, key: *Symbol, lang: *Symbol, value: *Symbol) !void {
		if (self.map.getPtr(key)) |ld| {
			try ld.add(lang, value);
		} else {
			try self.map.put(gpa, key, try .init(lang, value));
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
	const a: usize = trimStart(line, " \t");
	const r: usize = if (line.len > 0 and line[line.len - 1] == '\r') 1 else 0;
	return .{ offset + a, offset + (line.len - r) };
}

fn makeLowerCase(s: []u8) void {
	for (s, 0..) |c, i| {
		s[i] = std.ascii.toLower(c);
	}
}

fn keyLang(line: []u8, end: usize) struct { key: *Symbol, lang: *Symbol } {
	var lang: [:0]const u8 = "";
	const kend = if (find(line[0..end], '[')) |brac| blk: {
		const lbeg = brac + 1;
		const lend = if (find(line[lbeg..end], ']')) |b| lbeg + b else end;
		makeLowerCase(line[lbeg..lend]);
		line[lend] = 0;
		lang = line[lbeg..lend :0];
		break :blk brac;
	} else end;
	makeLowerCase(line[0..kend]);
	line[kend] = 0;
	return .{ .key = .gen(line[0..kend :0]), .lang = .gen(lang) };
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
	while (r.interface.takeDelimiterExclusive('\n')) |slice| {
		defer _ = r.interface.take(1) catch {};
		const line = blk: {
			const trim = trimRange(slice, 0);
			break :blk slice[trim[0]..trim[1]];
		};

		// empty or not @path
		if (line.len == 0 or line[0] != '@') {
			continue;
		}

		const resolved = try resolveZ(gpa, &.{ base_dir, line[1..] });
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

	var vpos: usize = 0;
	var multiline: std.ArrayList(u8) = .empty;
	defer multiline.deinit(gpa);

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	const base_dir = std.fs.path.dirname(file_path) orelse ".";
	while (r.interface.takeDelimiterExclusive('\n')) |slice| {
		defer _ = r.interface.take(1) catch {};
		const line: [:0]u8 = blk: {
			const trim = trimRange(slice, r.interface.seek - slice.len);
			buf[trim[1]] = 0;
			break :blk buf[trim[0]..trim[1] :0];
		};

		// empty or #comment
		if (line.len == 0 or line[0] == '#') {
			continue;
		}

		// :multiline
		if (multiline.items.len > 0) {
			if (line[0] == ':') {
				if (multiline.items.len > vpos) {
					try multiline.append(gpa, '\n');
				}
				try multiline.appendSlice(gpa, line[1..]);
				continue;
			} else {
				const kl = keyLang(multiline.items, vpos - 1);
				try multiline.append(gpa, 0);
				const value = multiline.items[vpos .. multiline.items.len - 1 :0];
				try meta.add(kl.key, kl.lang, .gen(value));
				multiline.items.len = 0;
			}
		}

		// @path
		if (line[0] == '@') {
			break;
		}

		// key[lang]=value
		if (line[0] != '!') {
			const eql = find(line, '=') orelse continue;
			vpos = trimEnd(line[0..eql], " \t") + 1;
			try multiline.appendSlice(gpa, line[0 .. vpos - 1]);
			try multiline.append(gpa, 0);
			const value = line[eql + 1 ..];
			if (value.len > 0) {
				try multiline.appendSlice(gpa, value);
			}
			continue;
		}

		// !include @path
		const cmd = line[1..];
		const inc = "include";
		if (std.mem.startsWith(u8, cmd, inc)) {
			const arg = blk: {
				const arg = cmd[inc.len..];
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

	if (multiline.items.len > 0) {
		const kl = keyLang(multiline.items, vpos - 1);
		try multiline.append(gpa, 0);
		const value = multiline.items[vpos .. multiline.items.len - 1 :0];
		try meta.add(kl.key, kl.lang, .gen(value));
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
	var meta: MetaHashMap = .{};
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

	fn asArrayList(self: Playlist) ArrayList {
		return ArrayList{
			.items = self.ptr[0..self.len],
			.capacity = self.cap,
		};
	}

	pub fn deinit(self: *Playlist) void {
		var list = self.asArrayList();
		list.deinit(gpa);
	}

	pub fn append(self: *Playlist, av: []const pd.Atom) !void {
		var list = self.asArrayList();
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
