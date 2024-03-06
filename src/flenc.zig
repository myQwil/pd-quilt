const pd = @import("ufloat.zig");
const A = pd.AtomType;

// -------------------------- flenc --------------------------
const FlEnc = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	mantissa: pd.FloatUInt,
	exponent: u16,
	sign: u8,

	fn print(self: *const Self, sym: *pd.Symbol) void {
		if (sym.name[0] != '\x00') {
			pd.startpost("%s: ", sym.name);
		}
		const m = self.mantissa & ~@as(pd.um, 0);
		const e = self.exponent & ~@as(pd.ue, 0);
		const s = self.sign & ~@as(u1, 0);
		pd.post("m=0x%x e=%u s=%u", m, e, s);
	}

	fn set_mantissa(self: *Self, f: pd.Float) void {
		self.mantissa = @intFromFloat(f);
	}

	fn set_exponent(self: *Self, f: pd.Float) void {
		self.exponent = @intFromFloat(f);
	}

	fn set_sign(self: *Self, f: pd.Float) void {
		self.sign = @intFromFloat(f);
	}

	inline fn compose(self: *Self, uf: pd.UFloat) void {
		self.mantissa = uf.b.mantissa;
		self.exponent = uf.b.exponent;
		self.sign = uf.b.sign;
	}

	fn set_u(self: *Self, f: pd.Float) void {
		self.compose(.{ .u = @intFromFloat(f) });
	}

	fn set_f(self: *Self, f: pd.Float) void {
		self.compose(.{ .f = f });
	}

	fn bang(self: *const Self) void {
		const uf: pd.UFloat = .{ .b = .{
			.mantissa = @intCast(self.mantissa),
			.exponent = @intCast(self.exponent),
			.sign = @intCast(self.sign),
		}};
		self.obj.out.float(uf.f);
	}

	fn float(self: *Self, f: pd.Float) void {
		self.set_mantissa(f);
		self.bang();
	}

	inline fn do_set(self: *Self, offset: u32, av: []pd.Atom) void {
		if (offset == 0 and av.len >= 1 and av[0].type == A.FLOAT) {
			self.mantissa = @intFromFloat(av[0].w.float);
		}
		if (av.len >= 2 and av[1 - offset].type == A.FLOAT) {
			self.exponent = @intFromFloat(av[1 - offset].w.float);
		}
		if (av.len >= 3 and av[2 - offset].type == A.FLOAT) {
			self.sign = @intFromFloat(av[2 - offset].w.float);
		}
	}

	fn set(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.do_set(0, av[0..ac]);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.do_set(0, av[0..ac]);
		self.bang();
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.do_set(1, av[0..ac]);
		self.bang();
	}

	fn new(_: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		const obj = &self.obj;
		_ = obj.outlet(pd.s.float);
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("e"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("s"));
		self.do_set(0, av[0..ac]);
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("flenc"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&set_mantissa), pd.symbol("m"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_exponent), pd.symbol("e"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_sign), pd.symbol("s"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_f), pd.symbol("f"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_u), pd.symbol("u"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set), pd.symbol("set"), A.GIMME, A.NULL);
		class.addMethod(@ptrCast(&print), pd.symbol("print"), A.DEFSYM, A.NULL);
	}
};

export fn flenc_setup() void {
	FlEnc.setup();
}
