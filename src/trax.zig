const std = @import("std");
const pd = @import("pd");
const wr = @import("write.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Outlet = pd.Outlet;
const StringMap = std.StringHashMap(void);
const SymbolList = std.ArrayList(*Symbol);
const Allocator = std.mem.Allocator;
const Oom = Allocator.Error;
const Io = std.Io;
const Writer = Io.Writer;
const WriteError = Writer.Error;
const TraverseError = Oom || std.Io.Reader.DelimiterError;

const trext = ".trax";

pub const Arena = struct {
	/// byte array
	buf: std.ArrayList(u8) = .empty,
	/// ending offsets and types of each item
	tbl: std.ArrayList(Entry) = .empty,

	const Enum = enum(u1) { float, string };

	const Entry = packed struct(usize) {
		end: @Int(.unsigned, @bitSizeOf(usize) - @bitSizeOf(Enum)) = 0,
		typ: Enum = .float,
	};

	const Union = union(Enum) {
		float: Float,
		string: [:0]const u8,

		pub fn asAtom(self: Union) Atom {
			return switch (self) {
				.float => |f| .float(f),
				.string => |s| .symbol(.gen(s)),
			};
		}

		pub fn print(self: Union) void {
			switch (self) {
				.float => |f| pd.post.start("%g", .{ f }),
				.string => |s| pd.post.start(s, .{}),
			}
		}

		pub fn write(self: Union, w: *Writer) WriteError!void {
			switch (self) {
				.float => |f| try wr.fmtG(w, f),
				.string => |s| try w.writeAll(s),
			}
		}
	};

	fn init(gpa: Allocator, str: []const u8) Oom!Arena {
		var arena: Arena = .{};
		if (str.len > 0) {
			try arena.append(gpa, str);
		}
		return arena;
	}

	fn deinit(self: *Arena, gpa: Allocator) void {
		self.buf.deinit(gpa);
		self.tbl.deinit(gpa);
	}

	const one = struct {
		var entry: Entry = .{};
		var arena: Arena = .{ .tbl = .{ .items = (&entry)[0..1], .capacity = 0 }};
		var float: Float = 0;
	};

	pub fn float(f: Float) *const Arena {
		one.float = f;
		one.arena.buf.items = @constCast(std.mem.asBytes(&one.float));
		one.entry = .{ .typ = .float, .end = @truncate(one.arena.buf.items.len) };
		return &one.arena;
	}

	pub fn string(str: [:0]const u8) *const Arena {
		one.arena.buf.items.len = str.len + 1;
		one.arena.buf.items.ptr = @constCast(str.ptr);
		one.entry = .{ .typ = .string, .end = @truncate(one.arena.buf.items.len) };
		return &one.arena;
	}

	pub fn parse(str: [:0]const u8) *const Arena {
		return if (std.fmt.parseFloat(Float, str)) |f| .float(f) else |_| .string(str);
	}

	fn grow(self: *Arena, gpa: Allocator, amount: usize, t: Enum) Oom!usize {
		try self.buf.ensureUnusedCapacity(gpa, amount);
		try self.tbl.ensureUnusedCapacity(gpa, 1);

		const old_len = self.buf.items.len;
		const new_len = old_len + amount;

		self.buf.items.len = new_len;
		self.tbl.appendAssumeCapacity(.{ .typ = t, .end = @intCast(new_len) });
		return old_len;
	}

	fn append(self: *Arena, gpa: Allocator, str: []const u8) Oom!void {
		if (std.fmt.parseFloat(Float, str)) |f| {
			const start = try self.grow(gpa, @sizeOf(Float), .float);
			@memcpy(self.buf.items[start..][0..@sizeOf(Float)], std.mem.asBytes(&f));
		} else |_| {
			const start = try self.grow(gpa, str.len + 1, .string);
			@memcpy(self.buf.items[start..][0..str.len], str);
			self.buf.items[self.buf.items.len - 1] = 0;
		}
	}

	pub fn get(self: *const Arena, index: usize) Union {
		std.debug.assert(index < self.tbl.items.len);
		const start = if (index == 0) 0 else self.tbl.items[index - 1].end;
		return switch (self.tbl.items[index].typ) {
			.float => blk: {
				const bytes = self.buf.items[start..][0..@sizeOf(Float)];
				break :blk .{ .float = std.mem.bytesToValue(Float, bytes) };
			},
			.string => .{
				.string = self.buf.items[start .. self.tbl.items[index].end - 1 :0],
			},
		};
	}

	pub fn send(
		self: *const Arena,
		gpa: Allocator,
		outlet: *Outlet,
		key: *Symbol,
	) Oom!void {
		var arr: [8]Atom = undefined;
		if (self.tbl.items.len > arr.len) {
			const atoms = try gpa.alloc(Atom, self.tbl.items.len);
			defer gpa.free(atoms);
			self.doSend(outlet, key, atoms);
		} else {
			self.doSend(outlet, key, &arr);
		}
	}
	fn doSend(self: *const Arena, outlet: *Outlet, key: *Symbol, atoms: []Atom) void {
		for (0..self.tbl.items.len) |i| {
			atoms[i] = self.get(i).asAtom();
		}
		outlet.anything(key, atoms[0..self.tbl.items.len]);
	}

	pub fn print(self: *const Arena, obj: *pd.Object, key: [*:0]const u8) void {
		pd.post.start("%s:", .{ key });
		if (self.tbl.items.len > 1) {
			for (0..self.tbl.items.len) |i| {
				pd.post.start("\n  ", .{});
				self.get(i).print();
			}
		} else if (self.tbl.items.len > 0) {
			pd.post.start(" ", .{});
			self.get(0).print();
		}
		pd.post.log(obj, .normal, "", .{});
	}

	pub fn write(self: *const Arena, w: *Writer) WriteError!void {
		if (self.tbl.items.len <= 0) {
			return;
		}
		try self.get(0).write(w);
		for (1..self.tbl.items.len) |i| {
			try w.writeByte('/');
			try self.get(i).write(w);
		}
	}
};

const LangDict = struct {
	dict: Dict,
	/// index of default entry
	default: usize = 0,

	const Dict = std.array_hash_map.Auto(*Symbol, Arena);

	fn init(gpa: Allocator, lang: *Symbol, value: []u8) Oom!LangDict {
		var arena: Arena = try .init(gpa, value);
		errdefer arena.deinit(gpa);
		var dict: Dict = .empty;
		try dict.put(gpa, lang, arena);
		return .{ .dict = dict };
	}

	fn deinit(self: *LangDict, gpa: Allocator) void {
		var iter = self.dict.iterator();
		while (iter.next()) |kv| {
			kv.value_ptr.deinit(gpa);
		}
		self.dict.deinit(gpa);
	}

	fn add(
		self: *LangDict,
		gpa: Allocator,
		lang: *Symbol,
		value: []u8,
	) Oom!*Arena {
		const gop = try self.dict.getOrPut(gpa, lang);
		if (gop.found_existing) {
			try gop.value_ptr.append(gpa, value);
		} else {
			gop.value_ptr.* = try .init(gpa, value);
			if (lang == pd.s.empty()) {
				self.default = self.dict.entries.len - 1;
			}
		}
		return gop.value_ptr;
	}

	pub fn get(self: *const LangDict, pref_langs: []*Symbol) *const Arena {
		for (pref_langs) |s| {
			// exact match
			if (self.dict.getPtr(s)) |value| {
				return value;
			}
			// prefix match (fuzzy)
			const pref = std.mem.sliceTo(s.name, 0);
			var iter = self.dict.iterator();
			while (iter.next()) |kv| {
				const lang = std.mem.sliceTo(kv.key_ptr.*.name, 0);
				if (std.mem.startsWith(u8, lang, pref)) {
					return kv.value_ptr;
				}
			}
		}
		return &self.dict.entries.slice().items(.value)[self.default];
	}
};

pub const Meta = struct {
	map: Map = .empty,

	const Map = std.array_hash_map.Auto(*Symbol, LangDict);

	pub fn deinit(self: *Meta, gpa: Allocator) void {
		var iter = self.map.iterator();
		while (iter.next()) |kv| {
			kv.value_ptr.deinit(gpa);
		}
		self.map.deinit(gpa);
	}

	pub fn add(
		self: *Meta,
		gpa: Allocator,
		key: *Symbol,
		lang: *Symbol,
		value: []u8,
	) Oom!*Arena {
		const gop = try self.map.getOrPut(gpa, key);
		if (gop.found_existing) {
			return try gop.value_ptr.add(gpa, lang, value);
		} else {
			gop.value_ptr.* = try .init(gpa, lang, value);
			return &gop.value_ptr.dict.entries.slice().items(.value)[0];
		}
	}

	pub fn traverse(
		self: *Meta,
		gpa: Allocator,
		io: Io,
		sidecar: [:0]const u8,
	) TraverseError!void {
		var parents: StringMap = .init(gpa);
		defer parents.deinit();
		try traverseMeta(gpa, io, self, &parents, sidecar);
	}

	pub fn fromPath(gpa: Allocator, io: Io, path: [*:0]const u8) TraverseError!?Meta {
		const sidecar = try getSidecar(gpa, io, std.mem.sliceTo(path, 0))
			orelse return null;
		defer gpa.free(sidecar);
		var self: Meta = .{};
		errdefer self.deinit(gpa);
		try self.traverse(gpa, io, sidecar);
		return self;
	}

	pub fn get(self: *const Meta, key: *Symbol, pref_langs: []*Symbol) ?*const Arena {
		const ldict = self.map.get(key) orelse return null;
		return ldict.get(pref_langs);
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
	for (s) |*c| {
		c.* = std.ascii.toLower(c.*);
	}
}

fn keyLang(line: []u8) struct { key: *Symbol, lang: *Symbol } {
	const end = line.len - 1;
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

fn resolveZ(gpa: Allocator, paths: []const []const u8) Oom![:0]u8 {
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

fn traverseList(
	gpa: Allocator,
	io: Io,
	list: *SymbolList,
	parents: *StringMap,
	file_path: [:0]const u8,
) TraverseError!void {
	if (parents.contains(file_path)) {
		return err(list.items.len, error.InfiniteRecursion, file_path.ptr);
	}
	try parents.put(file_path, {});
	defer _ = parents.remove(file_path);

	const file = Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
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
			try traverseList(gpa, io, list, parents, resolved);
		} else {
			try list.append(gpa, .gen(resolved.ptr));
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

fn traverseMeta(
	gpa: Allocator,
	io: Io,
	meta: *Meta,
	parents: *StringMap,
	file_path: [:0]const u8,
) TraverseError!void {
	if (parents.contains(file_path)) {
		return err(meta.map.count(), error.InfiniteRecursion, file_path.ptr);
	}
	try parents.put(file_path, {});
	defer _ = parents.remove(file_path);

	const file = Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
		catch |e| return err(meta.map.count(), e, file_path.ptr);
	defer file.close(io);

	var value: ?*Arena = null;
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
		if (line[0] == ':') {
			if (value) |v| {
				try v.append(gpa, line[1..]);
			}
			continue;
		} else {
			value = null;
		}

		// @path
		if (line[0] == '@') {
			break;
		}

		// key[lang]=value
		if (line[0] != '!') {
			const eql = find(line, '=') orelse continue;
			const kl = keyLang(line[0 .. trimEnd(line[0..eql], " \t") + 1]);
			value = try meta.add(gpa, kl.key, kl.lang, line[eql + 1 ..]);
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
			try traverseMeta(gpa, io, meta, parents, resolved);
			continue;
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub fn getSidecar(gpa: Allocator, io: Io, path: []const u8) Oom!?[:0]const u8 {
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
	Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true }) catch {
		@memcpy(trx_path[0..dot], path[0..dot]);
		@memcpy(trx_path[dot..][0..trext.len], trext);
		i = dot + trext.len;
		Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true }) catch {
			gpa.free(trx_path);
			return null;
		};
	};
	trx_path[i] = 0;

	std.debug.assert(i + 1 <= trx_path.len);
	trx_path = gpa.realloc(trx_path, i + 1) catch unreachable;
	return trx_path[0..i :0];
}

pub const Playlist = extern struct {
	/// list of tracks
	ptr: [*]*Symbol = &.{},
	/// length of the list
	len: usize = 0,
	/// allocated length
	cap: usize = 0,

	pub const AppendError = TraverseError || error{NotASymbol};

	fn asSymbolList(self: Playlist) SymbolList {
		return SymbolList{
			.items = self.ptr[0..self.len],
			.capacity = self.cap,
		};
	}

	pub fn deinit(self: *Playlist, gpa: Allocator) void {
		var list = self.asSymbolList();
		list.deinit(gpa);
	}

	pub fn append(
		self: *Playlist,
		gpa: Allocator,
		io: Io,
		av: []const Atom,
	) AppendError!void {
		var list = self.asSymbolList();
		defer self.* = .{
			.ptr = list.items.ptr,
			.len = list.items.len,
			.cap = list.capacity,
		};

		for (av) |arg| {
			const sym = arg.getSymbol() orelse return error.NotASymbol;
			const name = std.mem.sliceTo(sym.name, 0);
			if (isTrax(name)) {
				var parents: StringMap = .init(gpa);
				defer parents.deinit();
				try traverseList(gpa, io, &list, &parents, name);
			} else {
				try list.append(gpa, sym);
			}
		}
	}

	pub fn replaceWith(
		self: *Playlist,
		gpa: Allocator,
		io: Io,
		av: []const Atom,
	) AppendError!void {
		var playlist: Playlist = .{};
		errdefer playlist.deinit(gpa);
		try playlist.append(gpa, io, av);
		// on success, replace old list with new one
		self.deinit(gpa);
		self.* = playlist;
	}
};

pub const LangSet = extern struct {
	/// list of preferred language codes
	ptr: [*]*Symbol = &.{},
	/// length of the list
	len: usize = 0,

	pub inline fn slice(self: LangSet) []*Symbol {
		return self.ptr[0..self.len];
	}

	pub fn deinit(self: *LangSet, gpa: Allocator) void {
		gpa.free(self.ptr[0..self.len]);
	}

	pub fn replaceWith(self: *LangSet, gpa: Allocator, args: []const Atom) Oom!void {
		var arr: SymbolList = .empty;
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
		const slc = try arr.toOwnedSlice(gpa);
		// on success, replace old list with new one
		self.deinit(gpa);
		self.ptr = slc.ptr;
		self.len = slc.len;
	}
};
