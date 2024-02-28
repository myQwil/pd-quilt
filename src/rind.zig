const pd = @import("pd");
const h = @import("rng.zig");

pub const Rind = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: h.Rng,
	out: *pd.Outlet,
	min: pd.Float,
	max: pd.Float,

	fn print(self: *const Self) void {
		pd.post.log(self, .normal, "%g..%g", self.min, self.max);
	}

	fn bang(self: *Self) void {
		const min = self.min;
		const range = self.max - min;
		self.out.float(self.base.next() * range + min);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac >= 2 and av[1].type == .float) {
			self.min = av[1].w.float;
		}
		if (ac >= 1 and av[0].type == .float) {
			self.max = av[0].w.float;
		}
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac >= 1 and av[0].type == .float) {
			self.min = av[0].w.float;
		}
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.base.init();
		const obj = &self.base.obj;
		self.out = obj.outlet(pd.s.float).?;

		const vec = av[0..ac];
		switch (ac) {
			1 => _ = obj.inletFloatArg(&self.max, vec, 0),
			0 => {
				_ = obj.inletFloat(&self.min);
				_ = obj.inletFloat(&self.max);
				self.max = 1;
			},
			else => {
				_ = obj.inletFloatArg(&self.min, vec, 0);
				_ = obj.inletFloatArg(&self.max, vec, 1);
			}
		}
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("rind"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .gimme }).?;

		h.Rng.extend(class);
		class.addBang(@ptrCast(&bang));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
	}
};

export fn rind_setup() void {
	Rind.setup();
}
