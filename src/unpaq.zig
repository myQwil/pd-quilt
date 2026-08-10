//! `[unpack]` with `anything` outlets and passive mismatch error handling.

const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;

const gpa = pd.gpa;

const Unpaq = extern struct {
	obj: pd.Object,
	ptr: [*]Outlet,
	len: usize,

	const name = "unpaq";
	var class: *pd.Class = undefined;
	var dot: *Symbol = undefined; // skips args
	const parentConstPtr = pd.parentConstPtr(Unpaq);

	const Outlet = struct {
		out: *pd.Outlet,
		type: Atom.Type,
	};

	fn anyC(p: *const Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentConstPtr(p);
		const firstarg = (s != pd.s.list());
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

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(argv: []const Atom) pd.Oom!*Pd {
		const self: *Unpaq = try gpa.create(Unpaq);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const av: []const Atom = if (argv.len > 0) argv else &.{ .float(0), .float(0) };
		const vec = try gpa.alloc(Outlet, av.len);
		errdefer gpa.free(vec);

		for (vec, av) |*v, *a| {
			v.* = if (a.getSymbol()) |s| switch (s.name[0]) {
				'f' => .{ .out = try .init(obj, pd.s.float()), .type = .float },
				's' => .{ .out = try .init(obj, pd.s.symbol()), .type = .symbol },
				'p' => .{ .out = try .init(obj, pd.s.pointer()), .type = .pointer },
				else => .{ .out = try .init(obj, null), .type = .gimme },
			} else .{ .out = try .init(obj, null), .type = .gimme };
		}
		self.* = .{
			.obj = self.obj,
			.ptr = vec.ptr,
			.len = vec.len,
		};
		return &obj.g.pd;
	}

	fn deinitC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		gpa.free(self.ptr[0..self.len]);
	}

	inline fn setup() pd.Class.Error!void {
		dot = .gen(".");
		class = try .init(Unpaq, name, &.{ .gimme }, initC, deinitC, .{});
		class.addAnything(anyC);
		class.setHelpSymbol(.gen("paq"));
	}
};

export fn unpaq_setup() void {
	_ = pd.wrap(void, Unpaq.setup(), @src().fn_name);
}
