const pd = @import("pd");
const Playlist = @import("playlist.zig").Playlist;

const PList = extern struct {
	obj: pd.Object = undefined,
	out_val: *pd.Outlet,
	out_idx: *pd.Outlet,
	plist: Playlist = .{},

	const name = "plist";
	var class: *pd.Class = undefined;

	fn readC(
		self: *PList,
		_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom,
	) callconv(.c) void {
		self.plist.readArgs(av[0..ac]) catch |e|
			pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn bangC(self: *PList) callconv(.c) void {
		for (0..self.plist.len) |i| {
			self.out_idx.float(@floatFromInt(i));
			self.out_val.symbol(self.plist.ptr[i]);
		}
	}

	fn floatC(self: *PList, f: pd.Float) callconv(.c) void {
		const i: i32 = @intFromFloat(f);
		if (i < 0 or self.plist.len <= i) {
			return;
		}
		self.out_idx.float(@floatFromInt(i));
		self.out_val.symbol(self.plist.ptr[@intCast(i)]);
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
		class.addMethod(@ptrCast(&readC), .gen("read"), &.{ .gimme });
	}
};

export fn plist_setup() void {
	_ = pd.wrap(void, PList.setup(), @src().fn_name);
}
