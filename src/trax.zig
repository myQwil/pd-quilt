const std = @import("std");
const pd = @import("pd");
const wr = @import("write.zig");
const iParse = @import("numparse.zig").iParse;

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Outlet = pd.Outlet;
const StringMap = std.StringHashMapUnmanaged(void);
pub const SymbolList = std.ArrayList(*Symbol);

const Allocator = std.mem.Allocator;
const Oom = Allocator.Error;
const Io = std.Io;
const Writer = Io.Writer;
const WriteError = Writer.Error;
const TraverseError = Oom || std.Io.Reader.DelimiterError;

const trext = ".trax";

pub const Pile = struct {
	/// byte array
	buf: std.ArrayList(u8) = .empty,
	/// ending offsets and types of each item
	tbl: std.ArrayList(Entry) = .empty,

	const Enum = enum(u1) { float, string };

	const Entry = packed struct(u32) {
		end: @Int(.unsigned, @bitSizeOf(u32) - @bitSizeOf(Enum)),
		typ: Enum,
	};

	fn deinit(self: *Pile, gpa: Allocator) void {
		self.buf.deinit(gpa);
		self.tbl.deinit(gpa);
	}

	fn erase(self: *Pile) void {
		self.buf.items.len = 0;
		self.tbl.items.len = 0;
	}

	fn grow(self: *Pile, gpa: Allocator, amount: usize, t: Enum) Oom!usize {
		try self.buf.ensureUnusedCapacity(gpa, amount);
		try self.tbl.ensureUnusedCapacity(gpa, 1);

		const old_len = self.buf.items.len;
		const new_len = old_len + amount;

		self.buf.items.len = new_len;
		self.tbl.appendAssumeCapacity(.{ .typ = t, .end = @intCast(new_len) });
		return old_len;
	}

	fn append(self: *Pile, gpa: Allocator, str: []const u8) Oom!void {
		if (std.fmt.parseFloat(Float, str)) |f| {
			const start = try self.grow(gpa, @sizeOf(Float), .float);
			@memcpy(self.buf.items[start..][0..@sizeOf(Float)], std.mem.asBytes(&f));
		} else |_| {
			const start = try self.grow(gpa, str.len + 1, .string);
			@memcpy(self.buf.items[start..][0..str.len], str);
			self.buf.items[self.buf.items.len - 1] = 0;
		}
	}

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

	pub fn get(self: *const Pile, index: usize) Union {
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

	fn doSend(self: *const Pile, outlet: *Outlet, key: *Symbol, atoms: []Atom) void {
		for (0..self.tbl.items.len) |i| {
			atoms[i] = self.get(i).asAtom();
		}
		outlet.anything(key, atoms[0..self.tbl.items.len]);
	}

	pub fn send(
		self: *const Pile,
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

	pub fn print(self: *const Pile, p: *pd.Pd, key: [*:0]const u8) void {
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
		pd.post.log(p, .normal, "", .{});
	}

	pub fn write(self: *const Pile, w: *Writer) WriteError!void {
		if (self.tbl.items.len <= 0) {
			return;
		}
		try self.get(0).write(w);
		for (1..self.tbl.items.len) |i| {
			try w.writeByte('/');
			try self.get(i).write(w);
		}
	}

	const one = struct {
		var entry: Entry = .{ .end = 0, .typ = .float };
		var pile: Pile = .{ .tbl = .{ .items = (&entry)[0..1], .capacity = 0 }};
		var float: Float = 0;
	};

	pub fn float(f: Float) *const Pile {
		one.float = f;
		one.pile.buf.items = @constCast(std.mem.asBytes(&one.float));
		one.entry = .{ .typ = .float, .end = @truncate(one.pile.buf.items.len) };
		return &one.pile;
	}

	pub fn string(str: [:0]const u8) *const Pile {
		one.pile.buf.items.len = str.len + 1;
		one.pile.buf.items.ptr = @constCast(str.ptr);
		one.entry = .{ .typ = .string, .end = @truncate(one.pile.buf.items.len) };
		return &one.pile;
	}

	pub fn parse(str: [:0]const u8) *const Pile {
		return if (std.fmt.parseFloat(Float, str)) |f| .float(f) else |_| .string(str);
	}
};

const Tag = struct {
	dict: Dict = .empty,
	/// index of default entry
	default: usize = 0,

	const Dict = std.array_hash_map.Auto(*Symbol, Pile);

	fn deinit(self: *Tag, gpa: Allocator) void {
		var iter = self.dict.iterator();
		while (iter.next()) |kv| {
			kv.value_ptr.deinit(gpa);
		}
		self.dict.deinit(gpa);
	}

	pub fn get(self: *const Tag, prefs: []const *Symbol) *const Pile {
		for (prefs) |s| {
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
	data: Data = .empty,

	const Data = std.array_hash_map.Auto(*Symbol, Tag);
	const traverse = traverseMeta;

	pub fn deinit(self: *Meta, gpa: Allocator) void {
		var iter = self.data.iterator();
		while (iter.next()) |kv| {
			kv.value_ptr.deinit(gpa);
		}
		self.data.deinit(gpa);
	}

	pub fn fromPath(gpa: Allocator, io: Io, path: [*:0]const u8) TraverseError!Meta {
		const sidecar = try getSidecar(gpa, io, std.mem.sliceTo(path, 0))
			orelse return .{};
		defer gpa.free(sidecar);
		var self: Meta = .{};
		errdefer self.deinit(gpa);
		var parents: StringMap = .empty;
		defer parents.deinit(gpa);
		try self.traverse(gpa, io, &parents, sidecar);
		return self;
	}

	pub fn get(self: *const Meta, key: *Symbol, langs: []const *Symbol) ?*const Pile {
		const ldict = self.data.get(key) orelse return null;
		return ldict.get(langs);
	}
};

const Result = union(enum) {
	dict: *Tag.Dict,
	pile: *Pile,

	fn put(result: Result, gpa: Allocator, value: ?[]const u8) Oom!void {
		const v = value orelse return;
		switch (result) {
			.dict => |d| {
				var iter = d.iterator();
				while (iter.next()) |kv| {
					try kv.value_ptr.append(gpa, v);
				}
			},
			.pile => |p| try p.append(gpa, v),
		}
	}
};

pub fn putGet(
	data: *Meta.Data,
	gpa: Allocator,
	key: *Symbol,
	lang: *Symbol,
	value: ?[]const u8,
	erase: bool,
) Oom!Result {
	const result: Result = blk: {
		const tag_gop = try data.getOrPut(gpa, key);
		if (tag_gop.found_existing) {
			const dict = &tag_gop.value_ptr.dict;
			if (lang == Symbol.gen("*")) {
				if (erase) {
					var iter = dict.iterator();
					while (iter.next()) |kv| {
						kv.value_ptr.erase();
					}
				}
				break :blk .{ .dict = dict };
			}
			const pile_gop = try dict.getOrPut(gpa, lang);
			if (!pile_gop.found_existing) {
				pile_gop.value_ptr.* = .{};
				if (lang == pd.s.empty()) {
					tag_gop.value_ptr.default = dict.entries.len - 1;
				}
			} else if (erase) {
				pile_gop.value_ptr.erase();
			}
			break :blk .{ .pile = pile_gop.value_ptr };
		} else {
			const l = if (lang == Symbol.gen("*")) pd.s.empty() else lang;
			tag_gop.value_ptr.* = .{};
			const pile_gop = try tag_gop.value_ptr.dict.getOrPut(gpa, l);
			pile_gop.value_ptr.* = .{};
			break :blk .{ .pile = pile_gop.value_ptr };
		}
	};
	try result.put(gpa, value);
	return result;
}

inline fn find(slice: []const u8, value: u8) ?usize {
	return std.mem.findScalar(u8, slice, value);
}

inline fn findLast(slice: []const u8, value: u8) ?usize {
	return std.mem.findScalarLast(u8, slice, value);
}

inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, trext);
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

pub fn makeLowerCase(s: []u8) void {
	for (s) |*c| {
		c.* = std.ascii.toLower(c.*);
	}
}

fn keyLangVal(line: [:0]u8) struct { *Symbol, *Symbol, ?[]const u8 } {
	const eq = find(line, '=');
	const value = if (eq) |i| line[i + 1 ..] else null;
	const end = trimEnd(line[0..(eq orelse line.len)], " \t");
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
	if (kend < line.len) {
		line[kend] = 0;
	}
	return .{ .gen(line[0..kend :0]), .gen(lang), value };
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

/// Print message and skip, do not fail completely by returning error.
inline fn err(len: usize, e: anyerror, s: [*:0]const u8, t: [*:0]const u8) void {
	pd.post.err(null, "%u:%s (%s): \"%s\"", .{ len, @errorName(e).ptr, t, s });
}

fn pathCheck(
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

fn traverseList(
	list: *SymbolList,
	gpa: Allocator,
	io: Io,
	parents: *StringMap,
	path: [:0]const u8,
) TraverseError!void {
	const file = pathCheck(parents, gpa, io, path)
		catch |e| return err(list.items.len, e, path.ptr, "list");
	defer _ = parents.remove(path);
	defer file.close(io);
	const dir = std.fs.path.dirname(path) orelse ".";

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	while (r.interface.takeDelimiterExclusive('\n')) |slice| {
		defer _ = r.interface.take(1) catch {};
		const line = blk: {
			const trim = trimRange(slice, 0);
			break :blk slice[trim[0]..trim[1]];
		};

		// empty or not >path
		if (line.len == 0 or line[0] != '>') {
			continue;
		}

		const resolved = try resolveZ(gpa, &.{ dir, line[1..] });
		defer gpa.free(resolved);
		if (isTrax(resolved)) {
			try traverseList(list, gpa, io, parents, resolved);
		} else {
			try list.append(gpa, .gen(resolved.ptr));
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

fn traverseMeta(
	meta: *Meta,
	gpa: Allocator,
	io: Io,
	parents: *StringMap,
	path: [:0]const u8,
) TraverseError!void {
	const file = pathCheck(parents, gpa, io, path)
		catch |e| return err(0, e, path.ptr, "meta");
	defer _ = parents.remove(path);
	defer file.close(io);
	const dir = std.fs.path.dirname(path) orelse ".";

	var result: ?Result = null;
	var typ: enum { tag, include } = .tag;
	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	while (r.interface.takeDelimiterExclusive('\n')) |slice| {
		defer _ = r.interface.take(1) catch {};
		var line: [:0]u8 = blk: {
			const trim = trimRange(slice, r.interface.seek - slice.len);
			buf[trim[1]] = 0;
			break :blk buf[trim[0]..trim[1] :0];
		};

		// empty or #comment
		if (line.len == 0 or line[0] == '#') {
			continue;
		}

		// =multiline
		if (line[0] == '=') {
			if (typ == .include) {
				const resolved = try resolveZ(gpa, &.{ dir, line[1..] });
				defer gpa.free(resolved);
				try meta.traverse(gpa, io, parents, resolved);
			} else if (result) |res| {
				try res.put(gpa, line[1..]);
			}
			continue;
		} else {
			result = null;
		}

		// >path or [01:23.456]
		if (line[0] == '>' or line[0] == '[') {
			break;
		}

		// !control
		if (line[0] == '!') {
			const key, _, const val = keyLangVal(line[1..]);
			if (key == Symbol.gen("include")) {
				typ = .include;
				if (val) |v| {
					const resolved = try resolveZ(gpa, &.{ dir, v });
					defer gpa.free(resolved);
					try meta.traverse(gpa, io, parents, resolved);
				}
			}
			continue;
		}

		// ~erase
		const erase = line[0] == '~';
		line = if (erase) line[1..] else line;

		// @import (not implemented)
		if (line[0] == '@') {
			continue;
		}

		// key[lang]=value
		typ = .tag;
		const key, const lang, const val = keyLangVal(line);
		result = try putGet(&meta.data, gpa, key, lang, val, erase);
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

const Chapter = struct {
	trax: *Symbol,
	title: ?*Symbol = null,
	time: f64,
};
const ChapterList = std.ArrayList(Chapter);

fn traverseChapters(
	gpa: Allocator,
	io: Io,
	parents: *StringMap,
	path: [:0]const u8,
	time: f64,
) TraverseError!ChapterList {
	var list: ChapterList = .empty;
	errdefer list.deinit(gpa);
	const file = pathCheck(parents, gpa, io, path) catch |e| {
		err(0, e, path.ptr, "chapter");
		return list;
	};
	defer _ = parents.remove(path);
	defer file.close(io);
	const dir = std.fs.path.dirname(path) orelse ".";

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	while (r.interface.takeDelimiterExclusive('\n')) |slice| {
		defer _ = r.interface.take(1) catch {};
		var line: [:0]u8 = blk: {
			const trim = trimRange(slice, r.interface.seek - slice.len);
			buf[trim[1]] = 0;
			break :blk buf[trim[0]..trim[1] :0];
		};

		// not [01:23.456]
		if (line[0] != '[') {
			continue;
		}
		line = line[1..];
		line = line[trimStart(line, " \t")..];

		// chapter start time in seconds
		var sec: f64 = -1;
		var end: usize = undefined;
		if (iParse(line, &end)) |i| {
			sec = @floatFromInt(i);
			line = line[end..];
		}

		// minute/hour syntax
		while (line[0] == ':') {
			line = line[1..];
			if (iParse(line, &end)) |i| {
				sec = (sec * 60) + @as(f64, @floatFromInt(i));
				line = line[end..];
			}
		}

		// milliseconds
		if (line[0] == '.') {
			line = line[1..];
			if (iParse(line, &end)) |i| {
				const scale: f64 = @floatFromInt(std.math.powi(usize, 10, end) catch 1);
				sec += @as(f64, @floatFromInt(i)) / scale;
				line = line[end..];
			}
		}
		line = line[1..];
		line = line[trimStart(line, " \t")..];

		const agg = time + sec;
		if (line[0] == '>') {
			const resolved = try resolveZ(gpa, &.{ dir, line[1..] });
			defer gpa.free(resolved);
			var chaps = try traverseChapters(gpa, io, parents, resolved, agg);
			defer chaps.deinit(gpa);
			if (chaps.items.len == 0 or chaps.items[0].time > agg) {
				try list.append(gpa, .{ .time = agg, .trax = .gen(resolved) });
			}
			for (chaps.items) |chap| {
				try list.append(gpa, chap);
			}
		} else {
			const title: ?*Symbol = if (line[0] == '=') .gen(line[1..]) else null;
			try list.append(gpa, .{ .time = agg, .trax = .gen(path), .title = title });
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
	return list;
}

pub fn getChapters(
	gpa: Allocator,
	io: Io,
	path: [*:0]const u8,
) TraverseError!ChapterList {
	const sidecar = try getSidecar(gpa, io, std.mem.sliceTo(path, 0))
		orelse return .empty;
	defer gpa.free(sidecar);
	var parents: StringMap = .empty;
	defer parents.deinit(gpa);
	return traverseChapters(gpa, io, &parents, sidecar, 0);
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

	const base = path[start..dot];
	var i: usize = start;
	while (true) {
		// try `dir/file.trax`
		@memcpy(trx_path[i..][0..base.len], base);
		i += base.len;
		@memcpy(trx_path[i..][0..trext.len], trext);
		i += trext.len;
		if (Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true })) {
			break;
		} else |_| {}

		// try `dir/.trax/file.trax`
		i = start;
		@memcpy(trx_path[i..][0..txdir.len], txdir);
		i += txdir.len;
		@memcpy(trx_path[i..][0..base.len], base);
		i += base.len;
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

pub const AppendError = TraverseError || error{NotASymbol};

pub fn listAppend(
	self: *SymbolList,
	gpa: Allocator,
	io: Io,
	av: []const Atom,
) AppendError!void {
	for (av) |arg| {
		const sym = arg.getSymbol() orelse return error.NotASymbol;
		const name = std.mem.sliceTo(sym.name, 0);
		if (isTrax(name)) {
			var parents: StringMap = .empty;
			defer parents.deinit(gpa);
			try traverseList(self, gpa, io, &parents, name);
		} else {
			try self.append(gpa, sym);
		}
	}
}

pub fn listReplace(
	self: *SymbolList,
	gpa: Allocator,
	io: Io,
	av: []const Atom,
) AppendError!void {
	var list: SymbolList = .empty;
	errdefer list.deinit(gpa);
	try listAppend(&list, gpa, io, av);
	// on success, replace old list with new one
	self.deinit(gpa);
	self.* = list;
}

pub fn langReplace(
	self: *[]*Symbol,
	gpa: Allocator,
	args: []const Atom,
) (Oom || error{NotASymbol})!void {
	var arr: SymbolList = .empty;
	errdefer arr.deinit(gpa);
	var map: std.AutoHashMap(*Symbol, void) = .init(gpa);
	defer map.deinit();

	for (args) |arg| {
		const s = arg.getSymbol() orelse return error.NotASymbol;
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
