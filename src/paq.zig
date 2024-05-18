const pd = @import("pd");
var dot: *pd.Symbol = undefined; // skips args

const Paq = extern struct {
	const Self = @This();

	obj: pd.Object,
	ptr: [*]pd.Atom,
	len: usize,

	fn float(self: *Self, f: pd.Float) void {
		self.ptr[0] = .{ .type=.float, .w=.{ .float=f } };
	}
	fn symbol(self: *Self, s: *pd.Symbol) void {
		self.ptr[0] = .{ .type=.symbol, .w=.{ .symbol=s } };
	}
	fn pointer(self: *Self, p: *pd.GPointer) void {
		self.ptr[0] = .{ .type=.pointer, .w=.{ .gpointer=p } };
	}

	fn anything(self: *Self, s: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		const firstarg = (s != pd.s.list);
		if (firstarg and s != dot) {
			self.ptr[0] = .{ .type=.symbol, .w=.{ .symbol=s } };
		}
		const i = @intFromBool(firstarg);
		const n = @min(ac, self.len - i);
		for (self.ptr[i..i+n], av[0..n]) |*v, *a| {
			if (!(a.type == .symbol and a.w.symbol == dot)) {
				v.* = a.*;
			}
		}
	}

	fn new(class: *pd.Class, vec: []pd.Atom) !*Self {
		const self: *Self = @ptrCast(class.new() orelse return error.NoSetup);
		self.ptr = vec.ptr;
		self.len = vec.len;
		return self;
	}
};

const Proxy = struct {
	var class: *pd.Class = undefined;
	fn setup() void {
		class = pd.class(pd.symbol("_paq_pxy"), null, null,
			@sizeOf(Paq), .{ .bare=true, .no_inlet=true }, &.{}).?;
		class.addFloat(@ptrCast(&Paq.float));
		class.addSymbol(@ptrCast(&Paq.symbol));
		class.addPointer(@ptrCast(&Paq.pointer));
		class.addAnything(@ptrCast(&Paq.anything));
	}
};

const Owner = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: Paq,
	out: *pd.Outlet,
	ins: [*]*Paq,

	fn bang(self: *const Self) void {
		const vec = pd.mem.dupe(pd.Atom, self.base.ptr[0..self.base.len])
			catch return pd.post.do("Out of memory");
		defer pd.mem.free(vec);
		self.out.list(pd.s.list, @intCast(vec.len), vec.ptr);
	}

	fn float(self: *Self, f: pd.Float) void {
		self.base.float(f);
		self.bang();
	}
	fn symbol(self: *Self, s: *pd.Symbol) void {
		self.base.symbol(s);
		self.bang();
	}
	fn pointer(self: *Self, p: *pd.GPointer) void {
		self.base.pointer(p);
		self.bang();
	}
	fn anything(self: *Self, s: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.base.anything(s, ac, av);
		self.bang();
	}

	fn tryNew(argv: []const pd.Atom) !*Self {
		const av = if (argv.len > 0) argv else &[2]pd.Atom{
			.{ .type=.float, .w=.{ .float=0 } },
			.{ .type=.float, .w=.{ .float=0 } },
		};
		const vec = try pd.mem.alloc(pd.Atom, av.len);
		errdefer pd.mem.free(vec);
		vec[0] = av[0];

		const self: *Self = @ptrCast(try Paq.new(class, vec));
		errdefer @as(*pd.Pd, @ptrCast(self)).free();
		const obj = &self.base.obj;
		self.out = obj.outlet(pd.s.list).?;

		const ins = try pd.mem.alloc(*Paq, av.len - 1);
		errdefer pd.mem.free(ins);
		self.ins = ins.ptr;

		var n: u32 = 0; // proxies allocated
		errdefer for (ins[0..n]) |pxy| {
			@as(*pd.Pd, @ptrCast(pxy)).free();
		};
		while (n < ins.len) {
			const i = n + 1;
			vec[i] = av[i];
			ins[n] = try Paq.new(Proxy.class, vec[i..]);
			_ = obj.inlet(@ptrCast(ins[n]), null, null);
			n = i;
		}
		return self;
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		return tryNew(av[0..ac]) catch null;
	}

	fn free(self: *const Self) void {
		const paq = self.base;
		const n = paq.len - 1;
		for (self.ins[0..n]) |pxy| {
			@as(*pd.Pd, @ptrCast(pxy)).free();
		}
		pd.mem.free(self.ins[0..n]);
		pd.mem.free(paq.ptr[0..paq.len]);
	}

	fn setup() void {
		class = pd.class(pd.symbol("paq"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), .{}, &.{ .gimme }).?;
		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addSymbol(@ptrCast(&symbol));
		class.addPointer(@ptrCast(&pointer));
		class.addAnything(@ptrCast(&anything));
	}
};

export fn paq_setup() void {
	dot = pd.symbol(".");
	Proxy.setup();
	Owner.setup();
}
