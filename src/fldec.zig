const pd = @import("pd");
const bf = @import("bitfloat.zig");

const FlDec = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: [3]*pd.Outlet,
	f: pd.Float,

	fn print(self: *const Self) void {
		pd.post.log(self, .normal, "f=%g", self.f);
	}

	fn setFloat(self: *Self, f: pd.Float) void {
		self.f = f;
	}

	fn bang(self: *const Self) void {
		const uf: bf.UnFloat = .{ .f = self.f };
		self.out[2].float(@floatFromInt(uf.b.s));
		self.out[1].float(@floatFromInt(uf.b.e));
		self.out[0].float(@floatFromInt(uf.b.m));
	}

	fn float(self: *Self, f: pd.Float) void {
		self.f = f;
		self.bang();
	}

	fn new(f: pd.Float) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj = &self.obj;
		self.out[0] = obj.outlet(pd.s.float).?;
		self.out[1] = obj.outlet(pd.s.float).?;
		self.out[2] = obj.outlet(pd.s.float).?;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("set"));
		self.setFloat(f);
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("fldec"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .deffloat }).?;

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
		class.addMethod(@ptrCast(&setFloat), pd.symbol("set"), &.{ .float });
		class.setHelpSymbol(pd.symbol("flenc"));
	}
};

export fn fldec_setup() void {
	FlDec.setup();
}
