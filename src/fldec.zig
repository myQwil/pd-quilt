const pd = @import("ufloat.zig");

// -------------------------- flenc --------------------------
const FlDec = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	mantissa: *pd.Outlet,
	exponent: *pd.Outlet,
	sign: *pd.Outlet,
	f: pd.Float,

	fn print(self: *const Self, sym: *pd.Symbol) void {
		if (sym.name[0] != '\x00') {
			pd.startpost("%s: ", sym.name);
		}
		pd.post("f=%g", self.f);
	}

	fn set_f(self: *Self, f: pd.Float) void {
		self.f = f;
	}

	fn bang(self: *const Self) void {
		const uf: pd.UFloat = .{ .f = self.f };
		self.sign.float(@floatFromInt(uf.b.sign));
		self.exponent.float(@floatFromInt(uf.b.exponent));
		self.mantissa.float(@floatFromInt(uf.b.mantissa));
	}

	fn float(self: *Self, f: pd.Float) void {
		self.f = f;
		self.bang();
	}

	fn new(f: pd.Float) *Self {
		const self: *Self = @ptrCast(class.new());
		const obj = &self.obj;
		self.mantissa = obj.outlet(pd.s.float);
		self.exponent = obj.outlet(pd.s.float);
		self.sign = obj.outlet(pd.s.float);
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("set"));
		self.set_f(f);
		return self;
	}

	fn setup() void {
		const A = pd.AtomType;
		class = pd.class(pd.symbol("fldec"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.DEFFLOAT, A.NULL);

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&set_f), pd.symbol("set"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&print), pd.symbol("print"), A.DEFSYM, A.NULL);
		class.setHelpSymbol(pd.symbol("flenc"));
	}
};

export fn fldec_setup() void {
	FlDec.setup();
}
