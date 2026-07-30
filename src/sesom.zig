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
	const parentPtr = pd.parentPtr(Sesom);

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		(if (f > self.f) self.out_l else self.out_r).float(f);
	}

	fn initC(f: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(f), name);
	}
	inline fn init(f: Float) !*Pd {
		const self: *Sesom = try pd.gpa.create(Sesom);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletFloat(&self.f);
		self.* = .{
			.obj = self.obj,
			.out_l = try .init(obj, pd.s.float()),
			.out_r = try .init(obj, pd.s.float()),
			.f = f,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(Sesom, name, &.{ .deffloat }, initC, null, .{});
		class.addFloat(floatC);
	}
};

export fn sesom_setup() void {
	_ = pd.wrap(void, Sesom.setup(), @src().fn_name);
}
