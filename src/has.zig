//! Checks if a list contains a specific atom value.

const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;
const Uf = @import("bitfloat.zig").Uf;

const Has = extern struct {
	obj: pd.Object,
	out: *pd.Outlet,
	atom: Atom,

	const name = "has";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Has);
	const parentConstPtr = pd.parentConstPtr(Has);

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		const a = self.atom;
		self.out.float(if (a.type == .symbol and a.w.symbol == pd.s.bang()) 1 else 0);
	}

	fn listC(p: *const Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentConstPtr(p);
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
			parentPtr(p).atom = av[0];
		}
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Pd {
		const self: *Has = try pd.gpa.create(Has);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, pd.s.list(), .gen("set"));
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.float()),
			.atom = if (av.len > 0) av[0] else .float(0),
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(Has, name, &.{ .gimme }, &initC, null, .{});
		class.addBang(&bangC);
		class.addList(&listC);
		class.addMethod(&.{ .gimme }, &setC, .gen("set"));
	}
};

export fn has_setup() void {
	_ = pd.wrap(void, Has.setup(), @src().fn_name);
}
