const pd = @import("pd");

const Proxy = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	owner: *Owner,

	fn anything(self: *const Self, s: *pd.Symbol, _: u32, _: [*]const pd.Atom) void {
		self.owner.type = s;
	}

	fn new(owner: *Owner) !*Self {
		const self: *Self = @ptrCast(class.new() orelse return error.NoSetup);
		self.owner = owner;
		owner.proxy = self;
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("_is_pxy"), null, null,
			@sizeOf(Self), .{ .bare=true, .no_inlet=true }, &.{}).?;
		class.addAnything(@ptrCast(&anything));
	}
};

const Owner = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: *pd.Outlet,
	type: *pd.Symbol,
	proxy: *Proxy,

	fn print(self: *const Self) void {
		pd.post.log(self, .normal, "%s", self.type.name);
	}

	fn bang(self: *const Self) void {
		self.out.float(if (self.type == pd.s.bang) 1.0 else 0.0);
	}

	fn anything(self: *const Self, s: *pd.Symbol, ac: c_uint, _: [*]const pd.Atom) void {
		self.out.float(if (self.type == (if (ac > 0) s else pd.s.symbol)) 1.0 else 0.0);
	}

	fn set(self: *Self, s: *pd.Symbol) void {
		self.type = s;
	}

	fn _new(s: *pd.Symbol) !*Self {
		const self: *Self = @ptrCast(class.new() orelse return error.NoSetup);
		errdefer @as(*pd.Pd, @ptrCast(self)).free();
		const proxy = try Proxy.new(self);

		const obj = &self.obj;
		self.out = obj.outlet(pd.s.float).?;
		_ = obj.inlet(@ptrCast(proxy), null, null);
		self.type = if (s != pd.s._) s else pd.s.float;
		return self;
	}

	fn new(s: *pd.Symbol) ?*Self {
		return _new(s) catch null;
	}

	fn free(self: *const Self) void {
		@as(*pd.Pd, @ptrCast(self.proxy)).free();
	}

	fn setup() void {
		class = pd.class(pd.symbol("is"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), .{}, &.{ .defsymbol }).?;

		class.addBang(@ptrCast(&bang));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
		class.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .symbol });
	}
};

export fn is_setup() void {
	Proxy.setup();
	Owner.setup();
}
