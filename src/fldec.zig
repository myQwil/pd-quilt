//! Float-decode. Splits the sign, exponent, and mantissa of a float.

const FlDec = @This();
const pd = @import("pd");
const UnFloat = @import("bitfloat.zig").UnFloat;

const Pd = pd.Pd;
const Float = pd.Float;

out_m: *pd.Outlet,
out_e: *pd.Outlet,
out_s: *pd.Outlet,
f: Float,

const name = "fldec";
var class: *pd.Class = undefined;
const Box = pd.Box(pd.Object, FlDec);

fn printC(p: *const Pd) callconv(.c) void {
	pd.post.log(p, .normal, "%g", .{ Box.stateConst(p).f });
}

fn setC(p: *Pd, f: Float) callconv(.c) void {
	Box.state(p).f = f;
}

fn bangC(p: *const Pd) callconv(.c) void {
	const self = Box.stateConst(p);
	const uf: UnFloat = .{ .f = self.f };
	self.out_s.float(@floatFromInt(uf.b.sign));
	self.out_e.float(@floatFromInt(uf.b.exponent));
	self.out_m.float(@floatFromInt(uf.b.mantissa));
}

fn floatC(p: *Pd, f: Float) callconv(.c) void {
	Box.state(p).f = f;
	bangC(p);
}

fn createC(f: Float) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(f), name);
}
inline fn create(f: Float) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("set"));
	self.* = .{
		.out_m = try .create(obj, pd.s.float()),
		.out_e = try .create(obj, pd.s.float()),
		.out_s = try .create(obj, pd.s.float()),
		.f = f,
	};
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .deffloat }, createC, null, @sizeOf(Box), .{});
	class.addBang(bangC);
	class.addFloat(floatC);
	class.addMethod(&.{}, printC, .gen("print"));
	class.addMethod(&.{ .float }, setC, .gen("set"));
	class.setHelpSymbol(.gen("flenc"));
}

export fn fldec_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
