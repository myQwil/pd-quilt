pub usingnamespace @import("pd.zig");
const pd = @This();
const A = pd.AtomType;

pub const Tet = extern struct {
	const Self = @This();
	pub var class: *pd.Class = undefined;
	pub var set_k: *const fn(*Self) void = undefined;
	pub var set_min: *const fn(*Self) void = undefined;

	obj: pd.Object,
	ref: pd.Float, // reference pitch
	tet: pd.Float, // number of tones
	min: f64,       // frequency at index 0
	k: f64,         // slope

	fn set_ref(self: *Self, f: pd.Float) void {
		self.ref = f;
		set_min(self);
	}

	fn set_tet(self: *Self, f: pd.Float) void {
		self.tet = f;
		set_k(self);
		set_min(self);
	}

	inline fn do_list(self: *Self, j: u32, av: []pd.Atom) void {
		const props = [_]*pd.Float{ &self.ref, &self.tet };
		const n = @min(av.len, props.len - j);
		for (0..n) |i| {
			if (av[i].type == A.FLOAT) {
				props[i + j].* = av[i].w.float;
			}
		}
		set_k(self);
		set_min(self);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.do_list(0, av[0..ac]);
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.do_list(1, av[0..ac]);
	}

	pub fn new(_: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		const obj = &self.obj;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ref"));
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("tet"));
		_ = obj.outlet(pd.s.float);

		self.ref = if (ac >= 1 and av[0].type == A.FLOAT) av[0].w.float else 440;
		self.tet = if (ac >= 2 and av[1].type == A.FLOAT) av[1].w.float else 12;
		set_k(self);
		set_min(self);
		return self;
	}

	pub fn setup(s: *pd.Symbol, fmet: pd.Method) void {
		class = pd.class(s, @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);

		class.addFloat(fmet);
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&set_ref), pd.symbol("ref"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set_tet), pd.symbol("tet"), A.FLOAT, A.NULL);
		class.setHelpSymbol(pd.symbol("tone"));
	}
};
