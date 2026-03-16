//! Playlist reader.

const pd = @import("pd");
const pl = @import("playlist.zig");

const Float = pd.Float;
const Symbol = pd.Symbol;

const PList = extern struct {
	obj: pd.Object = undefined,
	out_val: *pd.Outlet,
	out_idx: *pd.Outlet,
	plist: pl.Playlist = .{},

	const name = "plist";
	var class: *pd.Class = undefined;

	inline fn err(self: *const PList, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn readC(
		self: *PList,
		_: *Symbol, ac: c_uint, av: [*]const pd.Atom,
	) callconv(.c) void {
		self.plist.readArgs(av[0..ac]) catch |e| self.err(e);
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
		var hm = (self.plist.getMetadata(@intCast(i))
			catch |e| return self.err(e)) orelse return;
		defer hm.deinit();

		if (hm.get(s)) |val| {
			self.out_idx.float(@floatFromInt(i));
			self.out_val.symbol(val);
		}
	}

	fn printC(self: *PList, f: Float) callconv(.c) void {
		const i: i32 = @intFromFloat(f);
		if (i < 0 or self.plist.len <= i) {
			return;
		}
		defer pd.post.do("", .{});
		var hm = (self.plist.getMetadata(@intCast(i))
			catch |e| return self.err(e)) orelse return;
		defer hm.deinit();

		var iter = hm.iterator();
		while (iter.next()) |kv| {
			pd.post.do("%s: %s", .{ kv.key_ptr.*.name, kv.value_ptr.*.name });
		}
	}

	fn initC() callconv(.c) ?*PList {
		return pd.wrap(*PList, init(), name);
	}
	inline fn init() !*PList {
		const self: *PList = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{
			.out_val = try .init(obj, &pd.s_symbol),
			.out_idx = try .init(obj, &pd.s_float),
		};
		return self;
	}

	fn deinitC(self: *PList) callconv(.c) void {
		self.plist.deinit();
	}

	inline fn setup() !void {
		class = try .init(PList, name, &.{}, &initC, &deinitC, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{ .float });
		class.addMethod(@ptrCast(&readC), .gen("read"), &.{ .gimme });
		class.addMethod(@ptrCast(&getC), .gen("get"), &.{ .float, .symbol });
	}
};

export fn plist_setup() void {
	_ = pd.wrap(void, PList.setup(), @src().fn_name);
}
