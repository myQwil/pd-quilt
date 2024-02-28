const pd = @import("pd");

const Atom = pd.Atom;
const Symbol = pd.Symbol;

const Has = extern struct {
	obj: pd.Object = undefined,
	out: *pd.Outlet,
	atom: Atom,

	const name = "has";
	var class: *pd.Class = undefined;

	fn bangC(self: *const Has) callconv(.c) void {
		const a = self.atom;
		self.out.float(if (a.type == .symbol and a.w.symbol == &pd.s_bang) 1 else 0);
	}

	fn listC(
		self: *const Has,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const a = self.atom;
		self.out.float(for (av[0..ac]) |b| {
			if (a.type == b.type and a.w.array == b.w.array) {
				break 1;
			}
		} else 0);
	}

	fn setC(
		self: *Has,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (ac >= 1) {
			self.atom = av[0];
		}
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Has {
		return pd.wrap(*Has, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Has {
		const self: *Has = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, &pd.s_list, .gen("set"));
		self.* = .{
			.out = try .init(obj, &pd.s_float),
			.atom = if (av.len > 0) av[0] else .float(0),
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(Has, name, &.{ .gimme }, &initC, null, .{});
		class.addBang(@ptrCast(&bangC));
		class.addList(@ptrCast(&listC));
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .gimme });
	}
};

export fn has_setup() void {
	_ = pd.wrap(void, Has.setup(), @src().fn_name);
}
