//! Reverse `[moses]`. Outputs numbers to the left if they're greater than control value.

const pd = @import("pd");

const Pd = pd.Pd;
const Float = pd.Float;

out_l: *pd.Outlet,
out_r: *pd.Outlet,
f: Float,

const name = "sesom";
var class: *pd.Class = undefined;
const Box = pd.Box(pd.Object, @This());

fn createC(f: Float) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(f), name);
}
inline fn create(f: Float) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	_ = try obj.inletFloat(&self.f);
	self.* = .{
		.out_l = try .create(obj, pd.s.float()),
		.out_r = try .create(obj, pd.s.float()),
		.f = f,
	};
	return &obj.g.pd;
}

fn floatC(p: *const Pd, f: Float) callconv(.c) void {
	const self = Box.stateConst(p);
	(if (f > self.f) self.out_l else self.out_r).float(f);
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .deffloat }, createC, null, @sizeOf(Box), .{});
	class.addFloat(floatC);
}

export fn sesom_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
