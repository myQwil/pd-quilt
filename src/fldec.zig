const pd = @import("pd");
const UnFloat = @import("bitfloat.zig").UnFloat;

const Float = pd.Float;

const FlDec = extern struct {
	obj: pd.Object = undefined,
	out_m: *pd.Outlet,
	out_e: *pd.Outlet,
	out_s: *pd.Outlet,
	f: Float,

	const name = "fldec";
	var class: *pd.Class = undefined;

	fn printC(self: *const FlDec) callconv(.c) void {
		pd.post.log(self, .normal, "%g", .{ self.f });
	}

	fn setC(self: *FlDec, f: Float) callconv(.c) void {
		self.f = f;
	}

	fn bangC(self: *const FlDec) callconv(.c) void {
		const uf: UnFloat = .{ .f = self.f };
		self.out_s.float(@floatFromInt(uf.b.sign));
		self.out_e.float(@floatFromInt(uf.b.exponent));
		self.out_m.float(@floatFromInt(uf.b.mantissa));
	}

	fn floatC(self: *FlDec, f: Float) callconv(.c) void {
		self.f = f;
		self.bangC();
	}

	fn initC(f: Float) callconv(.c) ?*FlDec {
		return pd.wrap(*FlDec, init(f), name);
	}
	inline fn init(f: Float) !*FlDec {
		const self: *FlDec = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("set"));
		self.* = .{
			.out_m = try .init(obj, &pd.s_float),
			.out_e = try .init(obj, &pd.s_float),
			.out_s = try .init(obj, &pd.s_float),
			.f = f,
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(FlDec, name, &.{ .deffloat }, &initC, null, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .float });
		class.setHelpSymbol(.gen("flenc"));
	}
};

export fn fldec_setup() void {
	_ = pd.wrap(void, FlDec.setup(), @src().fn_name);
}
