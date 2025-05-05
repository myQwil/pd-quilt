const pd = @import("pd");

const Atom = pd.Atom;
const Symbol = pd.Symbol;

const Unpaq = extern struct {
	obj: pd.Object = undefined,
	ptr: [*]Outlet,
	len: usize,

	const name = "unpaq";
	var class: *pd.Class = undefined;
	var dot: *Symbol = undefined; // skips args

	const Outlet = struct {
		out: *pd.Outlet,
		type: Atom.Type,
	};

	fn anythingC(
		self: *const Unpaq,
		s: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const firstarg = (s != &pd.s_list);
		const j = @intFromBool(firstarg);
		var i = @min(ac, self.len - j);
		while (i > 0) {
			i -= 1;
			const v = &self.ptr[i + j];
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

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Unpaq {
		return pd.wrap(*Unpaq, init(av[0..ac]), name);
	}
	inline fn init(argv: []const Atom) !*Unpaq {
		const self: *Unpaq = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const av: []const Atom = if (argv.len > 0) argv else &.{ .float(0), .float(0) };
		const vec = try pd.mem.alloc(Outlet, av.len);
		errdefer pd.mem.free(vec);

		for (vec, av) |*v, *a| {
			v.* = if (a.getSymbol()) |s| switch (s.name[0]) {
				'f' => .{ .out = try .init(obj, &pd.s_float), .type = .float },
				's' => .{ .out = try .init(obj, &pd.s_symbol), .type = .symbol },
				'p' => .{ .out = try .init(obj, &pd.s_pointer), .type = .pointer },
				else => .{ .out = try .init(obj, null), .type = .gimme },
			} else .{ .out = try .init(obj, null), .type = .gimme };
		}
		self.* = .{
			.ptr = vec.ptr,
			.len = vec.len,
		};
		return self;
	}

	fn deinitC(self: *const Unpaq) callconv(.c) void {
		pd.mem.free(self.ptr[0..self.len]);
	}

	inline fn setup() !void {
		dot = .gen(".");
		class = try .init(Unpaq, name, &.{ .gimme }, &initC, &deinitC, .{});
		class.addAnything(@ptrCast(&anythingC));
		class.setHelpSymbol(.gen("paq"));
	}
};

export fn unpaq_setup() void {
	_ = pd.wrap(void, Unpaq.setup(), @src().fn_name);
}
