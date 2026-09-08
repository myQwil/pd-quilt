//! Similar to `[change]` in that it sends different values through the left outlet,
//! but also sends repeat values through the right outlet.

const pd = @import("pd");

const Pd = pd.Pd;
const Float = pd.Float;

/// outlet used when `f` has changed
out_diff: *pd.Outlet,
/// outlet used when `f` has not changed
out_same: *pd.Outlet,
f: Float,

const name = "same";
var class: *pd.Class = undefined;
const Box = pd.Box(pd.Object, @This());

fn bangC(p: *const Pd) callconv(.c) void {
	const self = Box.stateConst(p);
	self.out_diff.float(self.f);
}

fn floatC(p: *Pd, f: Float) callconv(.c) void {
	const self = Box.state(p);
	if (self.f != f) {
		self.f = f;
		self.out_diff.float(f);
	} else {
		self.out_same.float(f);
	}
}

fn setC(p: *Pd, f: Float) callconv(.c) void {
	Box.state(p).f = f;
}

fn createC(f: Float) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(f), name);
}
inline fn create(f: Float) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	self.* = .{
		.out_diff = try .create(obj, pd.s.float()),
		.out_same = try .create(obj, pd.s.float()),
		.f = f,
	};
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .deffloat }, createC, null, @sizeOf(Box), .{});
	class.addBang(bangC);
	class.addFloat(floatC);
	class.addMethod(&.{ .deffloat }, setC, .gen("set"));
}

export fn same_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
