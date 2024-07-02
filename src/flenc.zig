const pd = @import("pd");
const bf = @import("bitfloat.zig");

const FlEnc = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: *pd.Outlet,
	uf: bf.UnFloat,

	fn print(self: *const Self) void {
		const m: bf.uf = self.uf.b.m;
		const e: bf.uf = self.uf.b.e;
		const s: bf.uf = self.uf.b.s;
		pd.post.log(self, .normal, "m=0x%x e=%u s=%u u=%u", m, e, s, self.uf.u);
	}

	fn setMantissa(self: *Self, f: pd.Float) void {
		self.uf.b.m = @intFromFloat(f);
	}

	fn setExponent(self: *Self, f: pd.Float) void {
		self.uf.b.e = @intFromFloat(f);
	}

	fn setSign(self: *Self, f: pd.Float) void {
		self.uf.b.s = @intFromFloat(f);
	}

	fn setInt(self: *Self, f: pd.Float) void {
		self.uf = .{ .u = @intFromFloat(f) };
	}

	fn setFloat(self: *Self, f: pd.Float) void {
		self.uf = .{ .f = f };
	}

	fn bang(self: *const Self) void {
		self.out.float(self.uf.f);
	}

	fn float(self: *Self, f: pd.Float) void {
		self.setMantissa(f);
		self.bang();
	}

	fn _set(self: *Self, offset: u32, av: []const pd.Atom) void {
		if (offset == 0 and av.len >= 1 and av[0].type == .float) {
			self.uf.b.m = @intFromFloat(av[0].w.float);
		}
		if (av.len >= 2 and av[1 - offset].type == .float) {
			self.uf.b.e = @intFromFloat(av[1 - offset].w.float);
		}
		if (av.len >= 3 and av[2 - offset].type == .float) {
			self.uf.b.s = @intFromFloat(av[2 - offset].w.float);
		}
	}

	fn set(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self._set(0, av[0..ac]);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self._set(0, av[0..ac]);
		self.bang();
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self._set(1, av[0..ac]);
		self.bang();
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj = &self.obj;
		self.out = obj.outlet(pd.s.float).?;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("e"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("s"));
		self._set(0, av[0..ac]);
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("flenc"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .gimme }).?;

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
		class.addMethod(@ptrCast(&setMantissa), pd.symbol("m"), &.{ .float });
		class.addMethod(@ptrCast(&setExponent), pd.symbol("e"), &.{ .float });
		class.addMethod(@ptrCast(&setSign), pd.symbol("s"), &.{ .float });
		class.addMethod(@ptrCast(&setFloat), pd.symbol("f"), &.{ .float });
		class.addMethod(@ptrCast(&setInt), pd.symbol("u"), &.{ .float });
		class.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .gimme });
	}
};

export fn flenc_setup() void {
	FlEnc.setup();
}
