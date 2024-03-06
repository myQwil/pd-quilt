pub usingnamespace @import("pd.zig");
const pd = @This();
const A = pd.AtomType;

pub const Slope = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;
	pub var set_k: *const fn(*Self) void = undefined;

	obj: pd.Object,
	min: f64,
	max: f64,
	run: f64,
	k: f64,
	log: bool,

	pub fn minmax(self: *Self) void {
		var min = self.min;
		var max = self.max;
		if (min == 0 and max == 0) {
			max = 1;
		}
		if (max > 0) {
			if (min <= 0) {
				min = 0.01 * max;
			}
		} else {
			if (min > 0) {
				max = 0.01 * min;
			}
		}
		self.min = min;
		self.max = max;
	}

	fn set_min(self: *Self, f: pd.Float) void {
		self.min = f;
		set_k(self);
	}

	fn set_max(self: *Self, f: pd.Float) void {
		self.max = f;
		set_k(self);
	}

	fn set_run(self: *Self, f: pd.Float) void {
		self.run = f;
		set_k(self);
	}

	fn set_log(self: *Self, f: pd.Float) void {
		self.log = (f != 0);
		set_k(self);
	}

	inline fn do_list(self: *Self, j: u32, av: []pd.Atom) void {
		const props = [_]*f64{ &self.min, &self.max, &self.run };
		const n = @min(av.len, props.len - j);
		for (0..n) |i| {
			if (av[i].type == A.FLOAT) {
				props[i + j].* = av[i].w.float;
			}
		}
		set_k(self);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.do_list(0, av[0..ac]);
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.do_list(1, av[0..ac]);
	}

	pub fn new(_: *pd.Symbol, argc: u32, argv: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		const obj: *pd.Object = &self.obj;
		_ = obj.outlet(pd.s.float);
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("min"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("max"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("run"));

		var ac = argc;
		var av = argv;
		if (ac >= 1 and av[0].type == A.SYMBOL) {
			const s = av[0].w.symbol.name;
			if (s[0] == 'l' and s[1] == 'o' and s[2] == 'g') {
				self.log = true;
				ac -= 1;
				av += 1;
			}
		}

		self.min = 0;
		self.max = 1;
		self.run = 128;
		switch (ac) {
			0 => set_k(self),
			1 => {
				self.max = av[0].getFloat();
				set_k(self);
			},
			else => self.do_list(0, av[0..ac]),
		}

		return self;
	}

	pub fn setup(s: *pd.Symbol, fmet: pd.Method) void {
		class = pd.class(s, @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);

		class.addFloat(fmet);
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&set_min), pd.symbol("min"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_max), pd.symbol("max"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_run), pd.symbol("run"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_log), pd.symbol("log"), A.FLOAT, A.NULL);
		class.setHelpSymbol(pd.symbol("slope"));
	}
};
