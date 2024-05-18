const pd = @import("pd");

const Unpaq = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;
	var dot: *pd.Symbol = undefined; // skips args

	const Outlet = struct {
		out: *pd.Outlet,
		type: pd.Atom.Type,
	};

	obj: pd.Object,
	ptr: [*]Outlet,
	len: usize,

	fn anything(self: *const Self, s: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		const firstarg = (s != pd.s.list);
		const j = @intFromBool(firstarg);
		var i = @min(ac, self.len - j);
		while (i > 0) {
			i -= 1;
			const v = &self.ptr[i+j];
			const a = &av[i];
			if (v.type != .gimme and v.type != a.type) {
				continue;
			}
			switch (a.type) {
				.symbol => if (a.w.symbol != dot) {
					v.out.symbol(a.w.symbol);
				},
				.pointer => v.out.pointer(a.w.gpointer),
				else => v.out.float(a.w.float),
			}
		}
		if (firstarg and s != dot) {
			self.ptr[0].out.symbol(s);
		}
	}

	fn _new(argv: []const pd.Atom) !*Self {
		const self: *Self = @ptrCast(class.new() orelse return error.NoSetup);
		errdefer @as(*pd.Pd, @ptrCast(self)).free();
		const obj = &self.obj;

		const av = if (argv.len > 0) argv else &[2]pd.Atom{
			.{ .type=.float, .w=.{ .float=0 } },
			.{ .type=.float, .w=.{ .float=0 } },
		};
		const vec = try pd.mem.alloc(Outlet, av.len);
		errdefer pd.mem.free(vec);
		self.ptr = vec.ptr;
		self.len = vec.len;

		for (vec, av) |*v, *a| {
			v.* = if (a.type == .symbol) switch (a.w.symbol.name[0]) {
				'f' => .{ .out=obj.outlet(pd.s.float).?, .type=.float },
				's' => .{ .out=obj.outlet(pd.s.symbol).?, .type=.symbol },
				'p' => .{ .out=obj.outlet(pd.s.pointer).?, .type=.pointer },
				else => .{ .out=obj.outlet(null).?, .type=.gimme },
			} else .{ .out=obj.outlet(null).?, .type=.gimme };
		}
		return self;
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		return _new(av[0..ac]) catch null;
	}

	fn free(self: *const Self) void {
		pd.mem.free(self.ptr[0..self.len]);
	}

	fn setup() void {
		dot = pd.symbol(".");
		class = pd.class(pd.symbol("unpaq"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), .{}, &.{ .gimme }).?;
		class.addAnything(@ptrCast(&anything));
		class.setHelpSymbol(pd.symbol("paq"));
	}
};

export fn unpaq_setup() void {
	Unpaq.setup();
}
