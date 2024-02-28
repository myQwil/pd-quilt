const pd = @import("pd");

const Float = pd.Float;

const Same = extern struct {
	obj: pd.Object = undefined,
	/// outlet used when `f` has changed
	out_diff: *pd.Outlet,
	/// outlet used when `f` has not changed
	out_same: *pd.Outlet,
	f: Float,

	const name = "same";
	var class: *pd.Class = undefined;

	fn bangC(self: *const Same) callconv(.c) void {
		self.out_diff.float(self.f);
	}

	fn floatC(self: *Same, f: Float) callconv(.c) void {
		if (self.f != f) {
			self.f = f;
			self.out_diff.float(f);
		} else {
			self.out_same.float(f);
		}
	}

	fn setC(self: *Same, f: Float) callconv(.c) void {
		self.f = f;
	}

	fn initC(f: Float) callconv(.c) ?*Same {
		return pd.wrap(*Same, init(f), name);
	}
	inline fn init(f: Float) !*Same {
		const self: *Same = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{
			.out_diff = try .init(obj, &pd.s_float),
			.out_same = try .init(obj, &pd.s_float),
			.f = f,
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(Same, name, &.{ .deffloat }, &initC, null, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .deffloat });
	}
};

export fn same_setup() void {
	_ = pd.wrap(void, Same.setup(), @src().fn_name);
}
