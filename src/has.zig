//! Checks if a list contains a specific atom value.

const pd = @import("pd");
const Uf = @import("misc/bitfloat.zig").Uf;

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;

out: *pd.Outlet,
atom: Atom,

const name = "has";
var class: *pd.Class = undefined;
const Box = pd.Box(pd.Object, @This());

fn bangC(p: *const Pd) callconv(.c) void {
	const self = Box.stateConst(p);
	const a = self.atom;
	self.out.float(if (a.type == .symbol and a.w.symbol == pd.s.bang()) 1 else 0);
}

fn listC(p: *const Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.stateConst(p);
	const a = self.atom;
	self.out.float(for (av[0..ac]) |b| {
		if (a.type != b.type) {
			continue;
		}
		// pointer comparison for float types results in false negatives
		if (
			(a.type == .float // compare float-size number of bits
			and @as(Uf, @bitCast(a.w.float)) == @as(Uf, @bitCast(b.w.float)))
			or a.w.gpointer == b.w.gpointer // compare pointer-size number of bits
		) {
			break 1;
		}
	} else 0);
}

fn setC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	if (ac >= 1) {
		Box.state(p).atom = av[0];
	}
}

fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
inline fn create(av: []const Atom) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	_ = try obj.inlet(&obj.g.pd, pd.s.list(), .gen("set"));
	self.* = .{
		.out = try .create(obj, pd.s.float()),
		.atom = if (av.len > 0) av[0] else .float(0),
	};
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .gimme }, &createC, null, @sizeOf(Box), .{});
	class.addBang(&bangC);
	class.addList(&listC);
	class.addMethod(&.{ .gimme }, &setC, .gen("set"));
}

export fn has_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
