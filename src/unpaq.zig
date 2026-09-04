//! `[unpack]` with `anything` outlets and passive mismatch error handling.

const Unpaq = @This();
const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;

const gpa = pd.gpa;

ptr: [*]Outlet,
len: usize,

const name = "unpaq";
var class: *pd.Class = undefined;
var dot: *Symbol = undefined; // skips args
const Box = pd.Box(pd.Object, Unpaq);

const Outlet = struct {
	out: *pd.Outlet,
	type: Atom.Type,
};

fn anyC(p: *const Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.stateConst(p);
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

fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
inline fn create(argv: []const Atom) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	const av: []const Atom = if (argv.len > 0) argv else &.{ .float(0), .float(0) };
	const vec = try gpa.alloc(Outlet, av.len);
	errdefer gpa.free(vec);

	for (vec, av) |*v, *a| {
		v.* = if (a.getSymbol()) |s| switch (s.name[0]) {
			'f' => .{ .out = try .create(obj, pd.s.float()), .type = .float },
			's' => .{ .out = try .create(obj, pd.s.symbol()), .type = .symbol },
			'p' => .{ .out = try .create(obj, pd.s.pointer()), .type = .pointer },
			else => .{ .out = try .create(obj, null), .type = .gimme },
		} else .{ .out = try .create(obj, null), .type = .gimme };
	}
	self.* = .{
		.ptr = vec.ptr,
		.len = vec.len,
	};
	return &obj.g.pd;
}

fn destroyC(p: *const Pd) callconv(.c) void {
	const self = Box.stateConst(p);
	gpa.free(self.ptr[0..self.len]);
}

inline fn setup() pd.Class.Error!void {
	dot = .gen(".");
	class = try .create(name, &.{ .gimme }, createC, destroyC, @sizeOf(Box), .{});
	class.addAnything(anyC);
	class.setHelpSymbol(.gen("paq"));
}

export fn unpaq_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
