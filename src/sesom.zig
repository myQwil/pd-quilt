//! Reverse `[moses]`. Outputs numbers to the left if they're greater than control value.

const pd = @import("pd");

const Pd = pd.Pd;
const Float = pd.Float;

const Sesom = extern struct {
	obj: pd.Object,
	out_l: *pd.Outlet,
	out_r: *pd.Outlet,
	f: Float,

	const name = "sesom";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Sesom, "obj");

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		(if (f > self.f) self.out_l else self.out_r).float(f);
	}

	fn createC(f: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, create(f), name);
	}
	inline fn create(f: Float) pd.Oom!*Pd {
		const self: *Sesom = try pd.gpa.create(Sesom);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.destroy();

		_ = try obj.inletFloat(&self.f);
		self.* = .{
			.obj = self.obj,
			.out_l = try .create(obj, pd.s.float()),
			.out_r = try .create(obj, pd.s.float()),
			.f = f,
		};
		return &obj.g.pd;
	}

	inline fn setup() pd.Class.Error!void {
		class = try .create(name, &.{ .deffloat }, createC, null, @sizeOf(Sesom), .{});
		class.addFloat(floatC);
	}
};

export fn sesom_setup() void {
	_ = pd.wrap(void, Sesom.setup(), @src().fn_name);
}
