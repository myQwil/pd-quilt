//! Float-decode. Splits the sign, exponent, and mantissa of a float.

const pd = @import("pd");
const UnFloat = @import("bitfloat.zig").UnFloat;

const Pd = pd.Pd;
const Float = pd.Float;

const FlDec = extern struct {
	obj: pd.Object,
	out_m: *pd.Outlet,
	out_e: *pd.Outlet,
	out_s: *pd.Outlet,
	f: Float,

	const name = "fldec";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(FlDec);
	const parentConstPtr = pd.parentConstPtr(FlDec);

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		pd.post.log(self, .normal, "%g", .{ self.f });
	}

	fn setC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f = f;
	}

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		const uf: UnFloat = .{ .f = self.f };
		self.out_s.float(@floatFromInt(uf.b.sign));
		self.out_e.float(@floatFromInt(uf.b.exponent));
		self.out_m.float(@floatFromInt(uf.b.mantissa));
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f = f;
		bangC(p);
	}

	fn initC(f: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(f), name);
	}
	inline fn init(f: Float) pd.Oom!*Pd {
		const self: *FlDec = try pd.gpa.create(FlDec);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("set"));
		self.* = .{
			.obj = self.obj,
			.out_m = try .init(obj, pd.s.float()),
			.out_e = try .init(obj, pd.s.float()),
			.out_s = try .init(obj, pd.s.float()),
			.f = f,
		};
		return &obj.g.pd;
	}

	inline fn setup() pd.Class.Error!void {
		class = try .init(FlDec, name, &.{ .deffloat }, initC, null, .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .float }, setC, .gen("set"));
		class.setHelpSymbol(.gen("flenc"));
	}
};

export fn fldec_setup() void {
	_ = pd.wrap(void, FlDec.setup(), @src().fn_name);
}
