//! `[pack]` with `anything` inlets and passive mismatch error handling.

const pd = @import("pd");

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

	fn floatC(self: *Proxy, f: Float) callconv(.c) void {
		self.ptr[0] = .float(f);
	}
	fn symbolC(self: *Proxy, s: *Symbol) callconv(.c) void {
		self.ptr[0] = .symbol(s);
	}
	fn pointerC(self: *Proxy, p: *pd.GPointer) callconv(.c) void {
		self.ptr[0] = .pointer(p);
	}

	fn anythingC(
		self: *Proxy,
		s: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		set(self.ptr[0..self.len], s, av[0..ac]);
	}

	fn init(vec: []Atom) !*Proxy {
		const self: *Proxy = @ptrCast(try class.pd());
		self.* = .{
			.obj = self.obj,
			.ptr = vec.ptr,
			.len = vec.len,
		};
		return self;
	}

	inline fn setup() !void {
		dot = .gen(".");
		class = try .init(Proxy, name, &.{}, null, null, .{
			.bare = true,
			.no_inlet = true,
		});
		class.addFloat(@ptrCast(&Proxy.floatC));
		class.addSymbol(@ptrCast(&Proxy.symbolC));
		class.addPointer(@ptrCast(&Proxy.pointerC));
		class.addAnything(@ptrCast(&Proxy.anythingC));
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

	fn bangC(self: *const Paq) callconv(.c) void {
		const vec = gpa.dupe(Atom, self.ptr[0..self.len]) catch
			return pd.post.err(self, name ++ ": Out of memory", .{});
		defer gpa.free(vec);
		self.out.list(pd.s.list(), vec);
	}

	fn floatC(self: *Paq, f: Float) callconv(.c) void {
		self.ptr[0] = .float(f);
		self.bangC();
	}

	fn symbolC(self: *Paq, s: *Symbol) callconv(.c) void {
		self.ptr[0] = .symbol(s);
		self.bangC();
	}

	fn pointerC(self: *Paq, p: *pd.GPointer) callconv(.c) void {
		self.ptr[0] = .pointer(p);
		self.bangC();
	}

	fn anythingC(
		self: *Paq,
		s: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		set(self.ptr[0..self.len], s, av[0..ac]);
		self.bangC();
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Paq {
		return pd.wrap(*Paq, init(av[0..ac]), name);
	}
	inline fn init(argv: []const Atom) !*Paq {
		const av: []const Atom = if (argv.len > 0)
			argv
		else &.{ .float(0), .float(0) };
		const vec = try gpa.alloc(Atom, av.len);
		errdefer gpa.free(vec);
		vec[0] = av[0];

		const self: *Paq = @ptrCast(try class.pd());
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
			_ = try obj.inlet(@ptrCast(ins[n]), null, null);
			n = i;
		}
		self.* = .{
			.obj = self.obj,
			.ptr = vec.ptr,
			.len = vec.len,
			.out = try .init(obj, pd.s.list()),
			.ins = ins.ptr,
		};
		return self;
	}

	fn deinitC(self: *const Paq) callconv(.c) void {
		const n = self.len - 1;
		for (self.ins[0..n]) |pxy| {
			pxy.obj.deinit();
		}
		gpa.free(self.ins[0..n]);
		gpa.free(self.ptr[0..self.len]);
	}

	inline fn setup() !void {
		class = try .init(Paq, name, &.{ .gimme }, &initC, &deinitC, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addSymbol(@ptrCast(&symbolC));
		class.addPointer(@ptrCast(&pointerC));
		class.addAnything(@ptrCast(&anythingC));
		try Proxy.setup();
	}
};

export fn paq_setup() void {
	_ = pd.wrap(void, Paq.setup(), @src().fn_name);
}
