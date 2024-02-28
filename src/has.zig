const pd = @import("pd.zig");
const A = pd.AtomType;

// -------------------------- has --------------------------
const Has = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	atom: pd.Atom,

	fn bang(self: *const Self) void {
		const atom = self.atom;
		self.obj.out.float(
			if (atom.type == A.SYMBOL and atom.w.symbol == pd.s.bang) 1.0 else 0.0);
	}

	fn list(self: *const Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.obj.out.float(blk: {
			const atom = self.atom;
			for (av[0..ac]) |a| {
				if (a.type == atom.type) {
					if ((atom.type == A.FLOAT and a.w.float == atom.w.float)
					 or a.w.symbol == atom.w.symbol) {
						break :blk 1;
					}
				}
			}
			break :blk 0;
		});
	}

	fn set(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (ac >= 1) {
			self.atom = av[0];
		}
	}

	fn new(_: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		const obj = &self.obj;
		_ = obj.outlet(pd.s.float);
		_ = obj.inlet(&obj.g.pd, pd.s.list, pd.symbol("set"));
		self.atom = if (ac >= 1) av[0] else .{ .type = A.FLOAT, .w = .{.float = 0} };
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("has"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);

		class.addBang(@ptrCast(&bang));
		class.addList(@ptrCast(&list));
		class.addMethod(@ptrCast(&set), pd.symbol("set"), A.GIMME, A.NULL);
	}
};

export fn has_setup() void {
	Has.setup();
}
