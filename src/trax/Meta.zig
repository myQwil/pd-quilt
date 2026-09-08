const Meta = @This();

const pd = @import("pd");
const std = @import("std");
const tx = @import("trax.zig");
const Pile = @import("Pile.zig");

const Symbol = pd.Symbol;
const Io = std.Io;
const Allocator = std.mem.Allocator;
const StringMap = tx.StringMap;

data: Data = .empty,

const Data = std.array_hash_map.Auto(*Symbol, Tag);

pub fn deinit(self: *Meta, gpa: Allocator) void {
	var iter = self.data.iterator();
	while (iter.next()) |kv| {
		kv.value_ptr.deinit(gpa);
	}
	self.data.deinit(gpa);
}

pub fn get(self: *const Meta, key: *Symbol, langs: []const *Symbol) ?*const Pile {
	const ldict = self.data.get(key) orelse return null;
	return ldict.get(langs);
}

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

const Result = union(enum) {
	dict: *Tag.Dict,
	pile: *Pile,

	fn put(result: Result, gpa: Allocator, value: ?[]const u8) Allocator.Error!void {
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
) Allocator.Error!Result {
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

fn keyLangVal(line: [:0]u8) struct { *Symbol, *Symbol, ?[]const u8 } {
	const eq = tx.find(line, '=');
	const value = if (eq) |i| line[i + 1 ..] else null;
	const end = tx.trimEnd(line[0..(eq orelse line.len)], " \t");
	var lang: [:0]const u8 = "";
	const kend = if (tx.find(line[0..end], '[')) |brac| blk: {
		const lbeg = brac + 1;
		const lend = if (tx.find(line[lbeg..end], ']')) |b| lbeg + b else end;
		tx.makeLowerCase(line[lbeg..lend]);
		line[lend] = 0;
		lang = line[lbeg..lend :0];
		break :blk brac;
	} else end;
	tx.makeLowerCase(line[0..kend]);
	if (kend < line.len) {
		line[kend] = 0;
	}
	return .{ .gen(line[0..kend :0]), .gen(lang), value };
}

fn traverse(
	self: *Meta,
	gpa: Allocator,
	io: Io,
	parents: *StringMap,
	path: [:0]const u8,
) tx.TravError!void {
	const file = tx.pathCheck(parents, gpa, io, path)
		catch |e| return tx.err(0, e, path.ptr, "meta");
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
			const trim = tx.trimRange(slice, r.interface.seek - slice.len);
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
				const resolved = try tx.resolveZ(gpa, &.{ dir, line[1..] });
				defer gpa.free(resolved);
				try self.traverse(gpa, io, parents, resolved);
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
					const resolved = try tx.resolveZ(gpa, &.{ dir, v });
					defer gpa.free(resolved);
					try self.traverse(gpa, io, parents, resolved);
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
		result = try putGet(&self.data, gpa, key, lang, val, erase);
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub fn fromPath(gpa: Allocator, io: Io, path: [*:0]const u8) tx.TravError!Meta {
	const sidecar = try tx.getSidecar(gpa, io, std.mem.sliceTo(path, 0))
		orelse return .{};
	defer gpa.free(sidecar);
	var parents: StringMap = .empty;
	defer parents.deinit(gpa);
	var self: Meta = .{};
	errdefer self.deinit(gpa);
	try self.traverse(gpa, io, &parents, sidecar);
	return self;
}
