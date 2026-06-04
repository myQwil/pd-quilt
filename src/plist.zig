//! Playlist reader.

const pd = @import("pd");
const tx = @import("trax.zig");
const std = @import("std");

const Float = pd.Float;
const Symbol = pd.Symbol;

const PList = extern struct {
	obj: pd.Object,
	out_val: *pd.Outlet,
	out_idx: *pd.Outlet,
	plist: tx.Playlist = .{},
	langs: tx.LangSet = .{},

	const name = "plist";
	var class: *pd.Class = undefined;

	inline fn err(self: *const PList, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn readC(
		self: *PList,
		_: *Symbol, ac: c_uint, av: [*]const pd.Atom,
	) callconv(.c) void {
		self.plist.replaceWith(av[0..ac]) catch |e| self.err(e);
	}

	fn appendC(
		self: *PList,
		_: *Symbol, ac: c_uint, av: [*]const pd.Atom,
	) callconv(.c) void {
		self.plist.append(av[0..ac]) catch |e| self.err(e);
	}

	fn bangC(self: *PList) callconv(.c) void {
		for (0..self.plist.len) |i| {
			self.out_idx.float(@floatFromInt(i));
			self.out_val.symbol(self.plist.ptr[i]);
		}
	}

	fn floatC(self: *PList, f: Float) callconv(.c) void {
		const i: i32 = @intFromFloat(f);
		if (i < 0 or self.plist.len <= i) {
			return;
		}
		self.out_idx.float(@floatFromInt(i));
		self.out_val.symbol(self.plist.ptr[@intCast(i)]);
	}

	fn getC(self: *PList, f: Float, s: *Symbol) callconv(.c) void {
		const i: i32 = @intFromFloat(f);
		if (i < 0 or self.plist.len <= i) {
			return;
		}
		var hm = (tx.metadata(self.plist.ptr[@intCast(i)].name)
			catch |e| return self.err(e)) orelse return;
		defer hm.deinit();

		if (hm.map.get(s)) |ldict| {
			self.out_idx.float(@floatFromInt(i));
			self.out_val.symbol(ldict.get(self.langs.ptr[0..self.langs.len]));
		}
	}

	fn printC(self: *PList, f: Float) callconv(.c) void {
		const i: i32 = @intFromFloat(f);
		if (i < 0 or self.plist.len <= i) {
			return;
		}
		defer pd.post.do("", .{});
		var hm = (tx.metadata(self.plist.ptr[@intCast(i)].name)
			catch |e| return self.err(e)) orelse return;
		defer hm.deinit();

		const langs: []*Symbol = self.langs.ptr[0..self.langs.len];
		var buf: [std.fs.max_path_bytes:0]u8 = undefined;
		var iter = hm.map.iterator();
		while (iter.next()) |kv| {
			const value = std.mem.sliceTo(kv.value_ptr.*.get(langs).name, 0);
			if (std.mem.findScalar(u8, value, '\n')) |_| {
				pd.post.start("%s:", .{ kv.key_ptr.*.name });
				var r: std.Io.Reader = .fixed(value);
				while (r.takeDelimiterExclusive('\n')) |slice| {
					defer _ = r.take(1) catch {};
					pd.post.start("\n  ", .{});

					const min = @min(buf.len, slice.len);
					@memcpy(buf[0..min], slice[0..min]);
					buf[min] = 0;
					pd.post.start("%s", .{ &buf });
				} else |e| if (e != error.EndOfStream) {
					self.err(e);
				}
				pd.post.end();
			} else {
				pd.post.do("%s: %s", .{ kv.key_ptr.*.name, value.ptr });
			}
		}
	}

	fn langsC(
		self: *PList,
		_: *Symbol, ac: c_uint, args: [*]const pd.Atom,
	) callconv(.c) void {
		self.langs.replaceWith(args[0..ac]) catch |e| self.err(e);
	}

	fn initC() callconv(.c) ?*PList {
		return pd.wrap(*PList, init(), name);
	}
	inline fn init() !*PList {
		const self: *PList = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{
			.obj = self.obj,
			.out_val = try .init(obj, pd.s.symbol()),
			.out_idx = try .init(obj, pd.s.float()),
		};
		return self;
	}

	fn deinitC(self: *PList) callconv(.c) void {
		self.plist.deinit();
		self.langs.deinit();
	}

	inline fn setup() !void {
		class = try .init(PList, name, &.{}, &initC, &deinitC, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{ .float });
		class.addMethod(@ptrCast(&appendC), .gen("append"), &.{ .gimme });
		class.addMethod(@ptrCast(&langsC), .gen("langs"), &.{ .gimme });
		class.addMethod(@ptrCast(&readC), .gen("read"), &.{ .gimme });
		class.addMethod(@ptrCast(&getC), .gen("get"), &.{ .float, .symbol });
	}
};

export fn plist_setup() void {
	_ = pd.wrap(void, PList.setup(), @src().fn_name);
}
