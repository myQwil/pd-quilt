const pd = @import("pd");

const Float = pd.Float;

const Sesom = extern struct {
	obj: pd.Object = undefined,
	out_l: *pd.Outlet,
	out_r: *pd.Outlet,
	f: Float,

	const name = "sesom";
	var class: *pd.Class = undefined;

	fn floatC(self: *Sesom, f: Float) callconv(.c) void {
		(if (f > self.f) self.out_l else self.out_r).float(f);
	}

	fn initC(f: Float) callconv(.c) ?*Sesom {
		return pd.wrap(*Sesom, init(f), name);
	}
	inline fn init(f: Float) !*Sesom {
		const self: *Sesom = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletFloat(&self.f);
		self.* = .{
			.out_l = try .init(obj, &pd.s_float),
			.out_r = try .init(obj, &pd.s_float),
			.f = f,
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(Sesom, name, &.{ .deffloat }, &initC, null, .{});
		class.addFloat(@ptrCast(&floatC));
	}
};

export fn sesom_setup() void {
	_ = pd.wrap(void, Sesom.setup(), @src().fn_name);
}
