const pd = @import("rng.zig");
const A = pd.AtomType;

// -------------------------- rind --------------------------
pub const Rind = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: pd.Rng,
	min: pd.Float,
	max: pd.Float,

	fn print_range(self: *const Self, s: *pd.Symbol) void {
		if (s.name[0] != '\x00') {
			pd.startpost("%s: ", s.name);
		}
		pd.post("%g..%g", self.max, self.min);
	}

	fn bang(self: *Self) void {
		const min = self.min;
		const range = self.max - min;
		self.base.obj.out.float(self.base.next() * range + min);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		const array = [_]*pd.Float{ &self.max, &self.min };
		const n = @min(ac, array.len);
		for (&array, av, 0..n) |arr, a, _| {
			if (a.type == A.FLOAT) {
				arr.* = a.w.float;
			}
		}
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (ac >= 1 and av[0].type == A.FLOAT) {
			self.min = av[0].w.float;
		}
	}

	fn new(_: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		self.base.init();

		const obj = &self.base.obj;
		_ = obj.outlet(pd.s.float);
		_ = obj.inletFloat(&self.max);
		if (ac != 1) {
			_ = obj.inletFloat(&self.min);
		}

		switch (ac) {
			2 => {
				self.max = av[0].getFloat();
				self.min = av[1].getFloat();
			},
			1 => self.max = av[0].getFloat(),
			else => self.max = 1,
		}

		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("rind"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);

		pd.Rng.extend(class);
		class.addBang(@ptrCast(&bang));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&print_range), pd.symbol("print"), A.DEFSYM, A.NULL);
	}
};

export fn rind_setup() void {
	Rind.setup();
}
