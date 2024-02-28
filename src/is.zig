const pd = @import("pd");

const Atom = pd.Atom;
const Symbol = pd.Symbol;

const Proxy = extern struct {
	obj: pd.Object = undefined,
	owner: *Is,

	const name = "_is_pxy";
	var class: *pd.Class = undefined;

	fn anythingC(
		self: *const Proxy,
		s: *Symbol, _: c_uint, _: [*]const Atom,
	) callconv(.c) void {
		self.owner.type = s;
	}

	inline fn init(owner: *Is) !*Proxy {
		const self: *Proxy = @ptrCast(try class.pd());
		self.* = .{ .owner = owner };
		return self;
	}

	inline fn setup() !void {
		class = try .init(Proxy, name, &.{}, null, null, .{
			.bare = true,
			.no_inlet = true,
		});
		class.addAnything(@ptrCast(&anythingC));
	}
};

const Is = extern struct {
	obj: pd.Object = undefined,
	out: *pd.Outlet,
	type: *Symbol,
	proxy: *Proxy,

	const name = "is";
	var class: *pd.Class = undefined;

	fn printC(self: *const Is) callconv(.c) void {
		pd.post.log(self, .normal, name ++ ": %s", .{ self.type.name });
	}

	fn bangC(self: *const Is) callconv(.c) void {
		self.out.float(if (self.type == &pd.s_bang) 1.0 else 0.0);
	}

	fn anythingC(
		self: *const Is,
		s: *Symbol, ac: c_uint, _: [*]const Atom,
	) callconv(.c) void {
		const t: *Symbol = if (ac > 0) s else &pd.s_symbol;
		self.out.float(if (self.type == t) 1 else 0);
	}

	fn setC(self: *Is, s: *Symbol) callconv(.c) void {
		self.type = s;
	}

	fn initC(s: *Symbol) callconv(.c) ?*Is {
		return pd.wrap(*Is, init(s), name);
	}
	inline fn init(s: *Symbol) !*Is {
		const self: *Is = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const proxy: *Proxy = try .init(self);
		errdefer proxy.obj.g.pd.deinit();

		_ = try obj.inlet(@ptrCast(proxy), null, null);
		self.* = .{
			.out = try .init(obj, &pd.s_float),
			.type = if (s != &pd.s_) s else &pd.s_float,
			.proxy = proxy,
		};
		return self;
	}

	fn deinitC(self: *const Is) callconv(.c) void {
		self.proxy.obj.g.pd.deinit();
	}

	inline fn setup() !void {
		class = try .init(Is, name, &.{ .defsymbol }, &initC, &deinitC, .{});
		class.addBang(@ptrCast(&bangC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .symbol });
		try Proxy.setup();
	}
};

export fn is_setup() void {
	_ = pd.wrap(void, Is.setup(), @src().fn_name);
}
