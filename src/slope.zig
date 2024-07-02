const rt = @import("root");
const pd = @import("pd");

pub fn floatArgDef(av: []const pd.Atom, i: usize, def: pd.Float) pd.Float {
	return if (i < av.len and av[i].type == .float) av[i].w.float else def;
}

pub const Slope = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;
	const setK = rt.setK;

	obj: pd.Object,
	out: *pd.Outlet,
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

	fn setMin(self: *Self, f: pd.Float) void {
		self.min = f;
		self.setK();
	}

	fn setMax(self: *Self, f: pd.Float) void {
		self.max = f;
		self.setK();
	}

	fn setRun(self: *Self, f: pd.Float) void {
		self.run = f;
		self.setK();
	}

	fn setLog(self: *Self, f: pd.Float) void {
		self.log = (f != 0);
		self.setK();
	}

	fn _list(self: *Self, j: u32, av: []const pd.Atom) void {
		const props = [_]*f64{ &self.min, &self.max, &self.run };
		const n = @min(av.len, props.len - j);
		for (props[j..j+n], av[0..n]) |p, *a| {
			if (a.type == .float) {
				p.* = a.w.float;
			}
		}
		self.setK();
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self._list(0, av[0..ac]);
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self._list(1, av[0..ac]);
	}

	pub fn new(_: *pd.Symbol, argc: c_uint, argv: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj: *pd.Object = &self.obj;
		self.out = obj.outlet(pd.s.float).?;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("min"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("max"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("run"));

		self.log = (argc >= 1 and argv[0].type == .symbol
			and argv[0].w.symbol == pd.symbol("log"));
		const i = @intFromBool(self.log);
		const av = argv[i..i+argc];

		self.min = if (av.len == 1) 0 else floatArgDef(av, 0, 0);
		self.max = floatArgDef(av, if (av.len == 1) 0 else 1, 1);
		self.run = floatArgDef(av, 2, 1);
		self.setK();

		return self;
	}

	pub fn setup(s: *pd.Symbol, fmet: pd.Method) void {
		class = pd.class(s, @ptrCast(&new), null, @sizeOf(Self), .{}, &.{ .gimme }).?;
		class.addFloat(fmet);
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&setMin), pd.symbol("min"), &.{ .float });
		class.addMethod(@ptrCast(&setMax), pd.symbol("max"), &.{ .float });
		class.addMethod(@ptrCast(&setRun), pd.symbol("run"), &.{ .float });
		class.addMethod(@ptrCast(&setLog), pd.symbol("log"), &.{ .float });
		class.setHelpSymbol(pd.symbol("slope"));
	}
};
