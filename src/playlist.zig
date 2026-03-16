const std = @import("std");
const pd = @import("pd");
const Trax = @import("Trax.zig");

const Symbol = pd.Symbol;
const MetaHashMap = Trax.MetaHashMap;
const EntryList = std.ArrayList(Entry);

const gpa = pd.gpa;
const isTrax = Trax.isTrax;

pub const Entry = extern struct {
	/// path to the file
	file: *Symbol,
	/// file metadata
	meta: Metadata = .{},

	pub fn getMetadata(self: *Entry) !?Trax {
		const path = try Trax.trackPath(std.mem.sliceTo(self.file.name, 0))
			orelse return null;
		defer gpa.free(path);

		var trax: Trax = .{};
		errdefer trax.deinit();
		var parents: Trax.StringHashMap = .init(gpa);
		defer parents.deinit();

		try trax.traverse(&parents, path, .include);
		return trax;
	}
};

fn update(target: *MetaHashMap, source: MetaHashMap) !void {
	var it = source.iterator();
	while (it.next()) |kv| {
		try target.put(kv.key_ptr.*, kv.value_ptr.*);
	}
}

const Metadata = extern struct {
	bytes: [*]align(@alignOf(MetaHashMap.Data)) u8 = undefined,
	len: usize = 0,
	capacity: usize = 0,
	bit_index: ?*align(@alignOf(u32)) anyopaque = null,

	pub fn asHashMap(self: Metadata) MetaHashMap {
		return .{
			.allocator = gpa,
			.ctx = undefined,
			.unmanaged = .{
				.entries = .{
					.bytes = self.bytes,
					.len = self.len,
					.capacity = self.capacity,
				},
				.index_header = @ptrCast(self.bit_index),
			},
		};
	}

	pub fn fromHashMap(map: MetaHashMap) Metadata {
		return .{
			.bytes = map.unmanaged.entries.bytes,
			.len = map.unmanaged.entries.len,
			.capacity = map.unmanaged.entries.capacity,
			.bit_index = map.unmanaged.index_header,
		};
	}
};

fn flatten(self: *const Trax, meta: *const MetaHashMap, list: *EntryList) !void {
	for (self.list.items) |*item| {
		var map: MetaHashMap = try meta.clone();
		switch (item.*) {
			.media => |*m| {
				errdefer map.deinit();
				try update(&map, m.meta);
				try list.append(gpa, .{ .file = m.file, .meta = .fromHashMap(map) });
			},
			.trax => |*t| {
				defer map.deinit();
				try update(&map, t.meta);
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
			map.deinit();
		}
		gpa.free(self.ptr[0..self.len]);
	}

	pub fn fromArgs(av: []const pd.Atom) !Playlist {
		var list: EntryList = .empty;
		errdefer list.deinit(gpa);

		for (av) |arg| {
			const sym = arg.getSymbol() orelse return error.NotASymbol;
			const name = std.mem.sliceTo(sym.name, 0);
			if (isTrax(name)) {
				var trax: Trax = .{};
				defer trax.deinit();
				var parents: Trax.StringHashMap = .init(gpa);
				defer parents.deinit();

				try trax.traverse(&parents, name, .normal);
				try flatten(&trax, &trax.meta, &list);
			} else {
				try list.append(gpa, .{ .file = sym });
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
