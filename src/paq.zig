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

const Proxy = extern struct {
	obj: pd.Pd,
	ptr: [*]Atom,
	len: usize,

	const name = "_paq_pxy";
	var class: *pd.Class = undefined;

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		const self: *Proxy = @fieldParentPtr("obj", p);
		self.ptr[0] = .float(f);
	}
	fn symbolC(p: *Pd, s: *Symbol) callconv(.c) void {
		const self: *Proxy = @fieldParentPtr("obj", p);
		self.ptr[0] = .symbol(s);
	}
	fn pointerC(p: *Pd, gp: *pd.GPointer) callconv(.c) void {
		const self: *Proxy = @fieldParentPtr("obj", p);
		self.ptr[0] = .pointer(gp);
	}

	fn anythingC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self: *Proxy = @fieldParentPtr("obj", p);
		set(self.ptr[0..self.len], s, av[0..ac]);
	}

	fn init(vec: []Atom) !*Proxy {
		const self: *Proxy = try gpa.create(Proxy);
		self.* = .{
			.obj = .{ .class = class },
			.ptr = vec.ptr,
			.len = vec.len,
		};
		return self;
	}

	inline fn setup() !void {
		dot = .gen(".");
		const opts: pd.Class.Options = .{ .bare = true, .no_inlet = true };
		class = try .init(Proxy, name, &.{}, null, null, opts);
		class.addFloat(floatC);
		class.addSymbol(symbolC);
		class.addPointer(pointerC);
		class.addAnything(anythingC);
	}
};

const Paq = extern struct {
	obj: pd.Object,
	ptr: [*]Atom,
	len: usize,
	out: *pd.Outlet,
	ins: [*]*Proxy,

	const name = "paq";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Paq);
	const parentConstPtr = pd.parentConstPtr(Paq);

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		const vec = gpa.dupe(Atom, self.ptr[0..self.len]) catch |e|
			return pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
		defer gpa.free(vec);
		self.out.list(pd.s.list(), vec);
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).ptr[0] = .float(f);
		bangC(p);
	}

	fn symbolC(p: *Pd, s: *Symbol) callconv(.c) void {
		parentPtr(p).ptr[0] = .symbol(s);
		bangC(p);
	}

	fn pointerC(p: *Pd, gp: *pd.GPointer) callconv(.c) void {
		parentPtr(p).ptr[0] = .pointer(gp);
		bangC(p);
	}

	fn anythingC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		set(self.ptr[0..self.len], s, av[0..ac]);
		bangC(p);
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(argv: []const Atom) !*Pd {
		const av: []const Atom = if (argv.len > 0)
			argv
		else &.{ .float(0), .float(0) };
		const vec = try gpa.alloc(Atom, av.len);
		errdefer gpa.free(vec);
		vec[0] = av[0];

		const self: *Paq = try gpa.create(Paq);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const ins = try gpa.alloc(*Proxy, av.len - 1);
		errdefer gpa.free(ins);

		var n: u32 = 0; // proxies allocated
		errdefer for (ins[0..n]) |pxy| {
			pxy.obj.deinit();
		};
		while (n < ins.len) {
			const i = n + 1;
			vec[i] = av[i];
			ins[n] = try .init(vec[i..]);
			_ = try obj.inlet(&ins[n].obj, null, null);
			n = i;
		}
		self.* = .{
			.obj = self.obj,
			.ptr = vec.ptr,
			.len = vec.len,
			.out = try .init(obj, pd.s.list()),
			.ins = ins.ptr,
		};
		return &obj.g.pd;
	}

	fn deinitC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		const n = self.len - 1;
		for (self.ins[0..n]) |pxy| {
			pxy.obj.deinit();
		}
		gpa.free(self.ins[0..n]);
		gpa.free(self.ptr[0..self.len]);
	}

	inline fn setup() !void {
		class = try .init(Paq, name, &.{ .gimme }, initC, deinitC, .{});
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
