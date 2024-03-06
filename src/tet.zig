const rt = @import("root");
const pd = @import("pd");

pub const Tet = extern struct {
	const Self = @This();
	pub var class: *pd.Class = undefined;
	const setK = rt.setK;
	const setMin = rt.setMin;

	obj: pd.Object,
	out: *pd.Outlet,
	k: f64,         // slope
	min: f64,       // frequency at index 0
	ref: pd.Float,  // reference pitch
	tet: pd.Float,  // number of tones

	fn setRef(self: *Self, f: pd.Float) void {
		self.ref = if (f == 0) 1 else f;
		self.setMin();
	}

	fn setTet(self: *Self, f: pd.Float) void {
		self.tet = if (f == 0) 1 else f;
		self.setK();
		self.setMin();
	}

	fn _list(self: *Self, j: u32, av: []const pd.Atom) void {
		const props = [_]*pd.Float{ &self.ref, &self.tet };
		const n = @min(av.len, props.len - j);
		for (0..n) |i| {
			if (av[i].type == .float) {
				props[i + j].* = av[i].w.float;
			}
		}
		self.setK();
		self.setMin();
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self._list(0, av[0..ac]);
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self._list(1, av[0..ac]);
	}

	pub fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj = &self.obj;
		self.out = obj.outlet(pd.s.float).?;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ref"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("tet"));

		self.ref = if (ac >= 1 and av[0].type == .float) av[0].w.float else 440;
		self.tet = if (ac >= 2 and av[1].type == .float) av[1].w.float else 12;
		self.setK();
		self.setMin();
		return self;
	}

	pub fn setup(s: *pd.Symbol, fmet: pd.Method) void {
		class = pd.class(s, @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .gimme }).?;

		class.addFloat(fmet);
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&setRef), pd.symbol("ref"), &.{ .float });
		class.addMethod(@ptrCast(&setTet), pd.symbol("tet"), &.{ .float });
		class.setHelpSymbol(pd.symbol("tone"));
	}
};
