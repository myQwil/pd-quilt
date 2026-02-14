const std = @import("std");
const pd = @import("pd");
const Trax = @import("Trax.zig");

const Symbol = pd.Symbol;
const MetaHashMap = Trax.MetaHashMap;
const StringHashMap = Trax.StringHashMap;
const EntryList = std.array_list.Aligned(Entry, null);

const gpa = pd.gpa;
const isTrax = Trax.isTrax;

const Entry = extern struct {
	/// path to the file
	file: *Symbol,
	/// file metadata
	meta: Metadata = .{},
};

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

fn flatten(self: *const Trax, meta: *const MetaHashMap, list: *EntryList) !void {
	for (self.list.items) |*item| {
		var map: MetaHashMap = try meta.clone(gpa);
		switch (item.*) {
			.media => |*m| {
				errdefer map.deinit(gpa);
				try putAll(&map, m.meta);
				try list.append(gpa, .{ .file = m.file, .meta = .fromHashMap(map) });
			},
			.trax => |*t| {
				defer map.deinit(gpa);
				try putAll(&map, t.meta);
				try flatten(t, &map, list);
			}
		}
	}
}

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
		var parents: StringHashMap = .empty;
		defer parents.deinit(gpa);

		for (av) |arg| {
			const sym = arg.getSymbol() orelse return error.NotASymbol;
			const name = std.mem.sliceTo(sym.name, 0);
			if (isTrax(name)) {
				try trax.traverse(&parents, name, .normal);
			} else {
				try trax.list.append(gpa, .{ .media = .{ .file = .gen(name) } });
			}
		}

		var list: EntryList = .empty;
		errdefer list.deinit(gpa);
		try flatten(&trax, &trax.meta, &list);
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
