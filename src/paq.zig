//! `[pack]` with `anything` inlets and passive mismatch error handling.

const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const gpa = pd.gpa;
var dot: *Symbol = undefined; // skips args

fn set(self: []Atom, s: *Symbol, source: []const Atom) void {
	const firstarg = (s != pd.s.list());
	if (firstarg and s != dot) {
		self[0] = .symbol(s);
	}
	const i = @intFromBool(firstarg);
	const n = @min(source.len, self.len - i);
	for (self[i..][0..n], source[0..n]) |*v, *a| {
		if (!(a.type == .symbol and a.w.symbol == dot)) {
			v.* = a.*;
		}
	}
}

const Proxy = struct {
	vec: []Atom,

	const name = "_paq_pxy";
	var class: *pd.Class = undefined;
	const Box = pd.Box(Pd, Proxy);

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		Box.state(p).vec[0] = .float(f);
	}
	fn symbolC(p: *Pd, s: *Symbol) callconv(.c) void {
		Box.state(p).vec[0] = .symbol(s);
	}
	fn pointerC(p: *Pd, gp: *pd.GPointer) callconv(.c) void {
		Box.state(p).vec[0] = .pointer(gp);
	}

	fn anythingC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		set(Box.state(p).vec, s, av[0..ac]);
	}

	fn create(vec: []Atom) pd.Oom!*Pd {
		const p: *Pd = try class.pd();
		Box.state(p).* = .{ .vec = vec };
		return p;
	}

	inline fn setup() pd.Class.Error!void {
		dot = .gen(".");
		const opts: pd.Class.Options = .{ .bare = true, .no_inlet = true };
		class = try .create(name, &.{}, null, null, @sizeOf(Box), opts);
		class.addFloat(floatC);
		class.addSymbol(symbolC);
		class.addPointer(pointerC);
		class.addAnything(anythingC);
	}
};

const Paq = struct {
	vec: []Atom,
	out: *pd.Outlet,
	ins: [*]*Pd,

	const name = "paq";
	var class: *pd.Class = undefined;
	const Box = pd.Box(pd.Object, Paq);

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = Box.stateConst(p);
		const vec = gpa.dupe(Atom, self.vec) catch |e|
			return pd.post.err(p, name ++ ": %s", .{ @errorName(e).ptr });
		defer gpa.free(vec);
		self.out.list(pd.s.list(), vec);
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		Box.state(p).vec[0] = .float(f);
		bangC(p);
	}

	fn symbolC(p: *Pd, s: *Symbol) callconv(.c) void {
		Box.state(p).vec[0] = .symbol(s);
		bangC(p);
	}

	fn pointerC(p: *Pd, gp: *pd.GPointer) callconv(.c) void {
		Box.state(p).vec[0] = .pointer(gp);
		bangC(p);
	}

	fn anythingC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = Box.state(p);
		set(self.vec, s, av[0..ac]);
		bangC(p);
	}

	fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, create(av[0..ac]), name);
	}
	inline fn create(argv: []const Atom) pd.Oom!*Pd {
		const av: []const Atom = if (argv.len > 0) argv else &.{ .float(0), .float(0) };
		const vec = try gpa.alloc(Atom, av.len);
		errdefer gpa.free(vec);
		vec[0] = av[0];

		const obj: *pd.Object = @ptrCast(try class.pd());
		const self = Box.state(&obj.g.pd);
		errdefer obj.g.pd.destroy();

		const ins = try gpa.alloc(*Pd, av.len - 1);
		errdefer gpa.free(ins);

		var n: u32 = 0; // proxies allocated
		errdefer for (ins[0..n]) |pxy| {
			pxy.destroy();
		};
		while (n < ins.len) {
			const i = n + 1;
			vec[i] = av[i];
			ins[n] = try Proxy.create(vec[i..]);
			_ = try obj.inlet(ins[n], null, null);
			n = i;
		}
		self.* = .{
			.vec = vec,
			.out = try .create(obj, pd.s.list()),
			.ins = ins.ptr,
		};
		return &obj.g.pd;
	}

	fn destroyC(p: *const Pd) callconv(.c) void {
		const self = Box.stateConst(p);
		const n = self.vec.len - 1;
		for (self.ins[0..n]) |pxy| {
			pxy.destroy();
		}
		gpa.free(self.ins[0..n]);
		gpa.free(self.vec);
	}

	inline fn setup() pd.Class.Error!void {
		class = try .create(name, &.{ .gimme }, createC, destroyC, @sizeOf(Box), .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addSymbol(symbolC);
		class.addPointer(pointerC);
		class.addAnything(anythingC);
		try Proxy.setup();
	}
};

export fn paq_setup() void {
	_ = pd.wrap(void, Paq.setup(), @src().fn_name);
}
