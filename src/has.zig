const pd = @import("pd");

const Has = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: *pd.Outlet,
	atom: pd.Atom,

	fn bang(self: *const Self) void {
		const atom = self.atom;
		self.out.float(
			if (atom.type == .symbol and atom.w.symbol == pd.s.bang) 1.0 else 0.0);
	}

	fn list(self: *const Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.out.float(blk: {
			const atom = self.atom;
			for (av[0..ac]) |*a| {
				if (a.type == atom.type) {
					if ((atom.type == .float and a.w.float == atom.w.float)
					 or a.w.symbol == atom.w.symbol) {
						break :blk 1;
					}
				}
			}
			break :blk 0;
		});
	}

	fn set(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac >= 1) {
			self.atom = av[0];
		}
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj = &self.obj;
		self.out = obj.outlet(pd.s.float).?;
		_ = obj.inlet(&obj.g.pd, pd.s.list, pd.symbol("set"));
		self.atom = if (ac >= 1) av[0] else .{ .type = .float, .w = .{.float = 0} };
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("has"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .gimme }).?;

		class.addBang(@ptrCast(&bang));
		class.addList(@ptrCast(&list));
		class.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .gimme });
	}
};

export fn has_setup() void {
	Has.setup();
}
