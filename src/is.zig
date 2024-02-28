const pd = @import("pd.zig");
const A = pd.AtomType;

inline fn check(s: *pd.Symbol) *pd.Symbol {
	if (s.name[1] != '\x00') {
		return s;
	}
	return switch (s.name[0]) {
		'b' => pd.s.bang,
		'f' => pd.s.float,
		's' => pd.s.symbol,
		'p' => pd.s.pointer,
		'l' => pd.s.list,
		else => s,
	};
}

// -------------------------- is --------------------------
const Is = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	const Proxy = extern struct {
		var class: *pd.Class = undefined;

		obj: pd.Object,
		owner: *Self,

		fn anything(self: *const Proxy, s: *pd.Symbol, _: u32, _: [*]pd.Atom) void {
			self.owner.type = check(s);
		}

		fn new(owner: *Self) *Proxy {
			const self: *Proxy = @ptrCast(Proxy.class.new());
			self.owner = owner;
			owner.proxy = self;
			return self;
		}

		fn setup() void {
			Proxy.class = pd.class(pd.symbol("_is_pxy"),
				null, null, @sizeOf(Proxy), pd.Class.PD | pd.Class.NOINLET, 0);
			Proxy.class.addAnything(@ptrCast(&Proxy.anything));
		}
	};

	obj: pd.Object,
	proxy: *Proxy,
	type: *pd.Symbol,

	fn print_type(self: *const Self, s: *pd.Symbol) void {
		if (s.name[0] != '\x00') {
			pd.startpost("%s: ", s.name);
		}
		pd.post("%s", self.type.name);
	}

	fn bang(self: *const Self) void {
		self.obj.out.float(if (self.type == pd.s.bang) 1.0 else 0.0);
	}

	fn anything(self: *const Self, s: *pd.Symbol, ac: u32, _: [*]pd.Atom) void {
		self.obj.out.float(
			if (self.type == (if (ac > 0) s else pd.s.symbol)) 1.0 else 0.0);
	}

	fn set(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (ac <= 0) {
			return;
		}
		self.type = switch (av[0].type) {
			A.FLOAT => pd.s.float,
			A.POINTER => pd.s.pointer,
			else => check(av[0].w.symbol),
		};
	}

	fn new(s: *pd.Symbol) *Self {
		const self: *Self = @ptrCast(class.new());
		const proxy = Proxy.new(self);

		const obj = &self.obj;
		_ = obj.outlet(pd.s.float);
		_ = obj.inlet(@ptrCast(proxy), null, null);
		self.type = if (s.name[0] != 0) check(s) else pd.s.float;
		return self;
	}

	fn free(self: *const Self) void {
		self.proxy.obj.g.pd.free();
	}

	fn setup() void {
		Proxy.setup();
		class = pd.class(pd.symbol("is"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), pd.Class.DEFAULT, A.DEFSYM, A.NULL);

		class.addBang(@ptrCast(&bang));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&print_type), pd.symbol("print"), A.DEFSYM, A.NULL);
		class.addMethod(@ptrCast(&set), pd.symbol("set"), A.GIMME, A.NULL);
	}
};

export fn is_setup() void {
	Is.setup();
}
